import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/llm/llm_chat.dart';
import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_credential_store.dart';
import 'package:PiliPlus/features/llm/llm_prompt.dart';
import 'package:PiliPlus/features/llm/llm_rules.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:PiliPlus/features/llm/llm_verdict.dart';
import 'package:PiliPlus/features/llm/llm_verdict_cache.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;

/// Resolved context of one generic-line pass: provider config + credential.
class _LlmPassContext {
  const _LlmPassContext({required this.config, required this.apiKey});

  final LlmProviderConfig config;
  final String apiKey;
}

/// Thrown when the generic line cannot run at all: config incomplete,
/// unconfirmed, or the key is missing/unreadable. Fail-open upstream.
class _LlmUnavailable implements Exception {
  const _LlmUnavailable();
}

/// Resolves provider config + credential, or throws [_LlmUnavailable].
Future<_LlmPassContext> _resolve({
  required LlmSettingsStore settings,
  required LlmCredentialStore credentials,
}) async {
  final config = await settings.load();
  if (config.issues.isNotEmpty ||
      !config.confirmed ||
      config.protocol == null) {
    throw const _LlmUnavailable();
  }
  final apiKey = await credentials.read(config.protocol!);
  if (apiKey == null || apiKey.isEmpty) {
    throw const _LlmUnavailable();
  }
  return _LlmPassContext(config: config, apiKey: apiKey);
}

class LlmCommentResult {
  const LlmCommentResult({required this.replies, required this.cacheable});

  final List<ReplyInfo> replies;

  /// False when the pass could not produce confident verdicts for every
  /// candidate; callers must not cache a keep decision built on it.
  final bool cacheable;
}

/// Generic-line COMMENT pipeline (spec 3): Jev runs first, this pass sees
/// only the survivors. Serial batches of [JevLimits.batchSize] candidates,
/// one request per batch, no retries; a failed batch fails open; the page
/// budget arrives via [filter]'s [timeout], tightened by the controller
/// that runs both lines. Mid-pass policy drift voids the whole page.
class LlmCommentScreening {
  LlmCommentScreening({
    LlmChatClient? client,
    LlmSettingsStore? settings,
    LlmCredentialStore? credentials,
    JevRuleStore? rules,
    LlmVerdictCache? cache,
  }) : _client = client ?? LlmChatClient(),
       _settings = settings ?? LlmSettingsStore(),
       _credentials = credentials ?? SecureLlmCredentialStore(),
       _rules = rules ?? JevRuleStore(),
       _cache = cache ?? LlmVerdictCache();

  final LlmChatClient _client;
  final LlmSettingsStore _settings;
  final LlmCredentialStore _credentials;
  final JevRuleStore _rules;
  final LlmVerdictCache _cache;

  /// A comment body never leaves the device beyond this many runes.
  static const int maxTextChars = LlmPrompt.maxTextChars;

  /// Whether the generic comment line would run at all: usable confirmed
  /// provider, readable key, and at least one active comment rule (typed
  /// rules remain the single comment config source, #113).
  Future<bool> isEnabled() async {
    try {
      final views = await _commentViews();
      if (views.isEmpty) return false;
      await _resolve(settings: _settings, credentials: _credentials);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<LlmCommentRuleView>> _commentViews() async {
    final config = await _rules.load();
    final active = config.activeFor(JevRuleTarget.comment);
    return LlmCommentRuleView.of(active);
  }

  /// Screens [replies] (flat, source order) with [parents] context texts.
  /// [timeout] tightens, never extends, the 8s page budget.
  Future<LlmCommentResult> filter(
    List<ReplyInfo> replies, {
    List<String?>? parents,
    Duration? timeout,
    bool screenLog = true,
  }) async {
    final budget = timeout == null || timeout >= LlmLimits.requestTimeout
        ? LlmLimits.requestTimeout
        : timeout;
    if (budget <= Duration.zero) {
      return LlmCommentResult(replies: replies, cacheable: false);
    }
    final watch = Stopwatch()..start();
    final hidden = List<bool>.filled(replies.length, false);
    final hiddenByRule = <int, String>{};
    var cacheable = true;
    var expired = false;
    var initialFingerprint = '';
    try {
      final views = await _commentViews();
      if (views.isEmpty || replies.isEmpty) {
        return LlmCommentResult(replies: replies, cacheable: cacheable);
      }
      final context = await _resolve(
        settings: _settings,
        credentials: _credentials,
      );
      initialFingerprint = _fingerprint(context.config, views);
      // repeat_count keeps duplicated texts from being billed as new
      // candidates (Jev precedent).
      final repeats = <String, int>{};
      for (final reply in replies) {
        final text = reply.content.message.trim();
        if (text.isEmpty) continue;
        repeats[text] = (repeats[text] ?? 0) + 1;
      }
      // Blank bodies are never sent; oversized ones are not sent either
      // but still poison the pass because their verdict stays unknown.
      final sent = <int>[];
      for (var i = 0; i < replies.length; i++) {
        final text = replies[i].content.message.trim();
        if (text.isEmpty) continue;
        if (text.runes.length > maxTextChars) {
          cacheable = false;
          continue;
        }
        sent.add(i);
      }
      // Definite cached verdicts answer without the upstream (spec 5).
      final resolved = List<bool>.filled(replies.length, false);
      final cacheOn = _cache.enabled;
      final generation = initialFingerprint;
      if (cacheOn) {
        for (final i in sent) {
          final identity = _commentIdentity(replies[i]);
          if (identity == null) continue;
          final cached = _cache.lookup(generation, identity);
          if (cached == null) continue;
          resolved[i] = true;
          if (cached) hidden[i] = true;
        }
      }
      final pending = [
        for (final i in sent)
          if (!resolved[i]) i,
      ];
      for (
        var start = 0;
        start < pending.length;
        start += JevLimits.batchSize
      ) {
        final end = math.min(start + JevLimits.batchSize, pending.length);
        final batch = pending.sublist(start, end);
        if (watch.elapsed >= budget) {
          expired = true;
          cacheable = false;
          break;
        }
        try {
          final candidates = <LlmCommentCandidate>[
            for (var b = 0; b < batch.length; b++)
              LlmCommentCandidate(
                key: LlmPrompt.candidateKey(b),
                text: replies[batch[b]].content.message.trim(),
                snippet: _parentOf(parents, batch[b]),
                repeatCount:
                    repeats[replies[batch[b]].content.message.trim()] ?? 1,
              ),
          ];
          final knownIds = <String, int>{
            for (var b = 0; b < batch.length; b++)
              for (var r = 0; r < views.length; r++)
                LlmPrompt.commentRuleId(LlmPrompt.candidateKey(b), views[r].id):
                    b,
          };
          final remaining = budget - watch.elapsed;
          final outcome = await _client
              .call(
                system: llmSystemPrompt,
                user: LlmPrompt.commentUserMessage(
                  rules: views,
                  candidates: candidates,
                ),
                timeout: remaining,
              )
              .timeout(remaining);
          if (!outcome.ok) {
            cacheable = false;
            continue;
          }
          final verdict = LlmVerdictParser.parse(
            outcome.text,
            knownIds.keys.toSet(),
          );
          if (!verdict.valid) {
            cacheable = false;
            continue;
          }
          for (final hit in verdict.hits) {
            final b = knownIds[hit.ruleId];
            if (b == null) continue; // unreachable: parser drops unknown ids
            final index = batch[b];
            hidden[index] = true;
            hiddenByRule[index] = hit.ruleId;
          }
          if (verdict.droppedHits) {
            cacheable = false;
          } else if (cacheOn) {
            for (var b = 0; b < batch.length; b++) {
              final identity = _commentIdentity(replies[batch[b]]);
              if (identity == null) continue;
              _cache.put(generation, identity, hide: hidden[batch[b]]);
            }
          }
        } catch (_) {
          // Fail-open: this whole batch stays visible (Jev precedent).
          cacheable = false;
        }
      }
    } catch (_) {
      expired = true;
      cacheable = false;
    }
    if (!expired) {
      final remaining = budget - watch.elapsed;
      if (remaining <= Duration.zero) {
        // The pass overran its budget: no verdict may be applied or cached.
        return LlmCommentResult(replies: replies, cacheable: false);
      }
      try {
        final config = await _settings.load().timeout(remaining);
        final ruleConfig = await _rules.load().timeout(remaining);
        final views = LlmCommentRuleView.of(
          ruleConfig.activeFor(JevRuleTarget.comment),
        );
        if (views.isNotEmpty &&
            initialFingerprint != _fingerprint(config, views)) {
          // Decisions compiled under a stale policy are void.
          return LlmCommentResult(replies: replies, cacheable: false);
        }
      } catch (_) {
        cacheable = false;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final blocked = <JevScreenLogEntry>[];
    final visible = <ReplyInfo>[];
    for (var i = 0; i < replies.length; i++) {
      if (!hidden[i]) {
        visible.add(replies[i]);
        continue;
      }
      final parent = _parentOf(parents, i)?.trim();
      blocked.add(
        JevScreenLogEntry(
          time: now,
          kind: JevScreenLogKind.comment,
          surface: JevSurface.comment.id,
          title: replies[i].content.message.trim(),
          snippet: parent == null || parent.isEmpty ? null : parent,
          ruleId: hiddenByRule[i],
        ),
      );
    }
    if (blocked.isNotEmpty && screenLog) {
      try {
        unawaited(JevScreenLog.instance.record(blocked));
      } catch (_) {
        // Log failures never affect screening.
      }
    }
    return LlmCommentResult(replies: visible, cacheable: cacheable);
  }

  /// Generation = policy fingerprint: protocol + base URL + model +
  /// confirmed latch + active comment rule_version (spec 5).
  static String _fingerprint(
    LlmProviderConfig config,
    List<LlmCommentRuleView> views,
  ) =>
      'llm-comment|${config.protocol?.id}|${config.normalizedBaseUrl}|${config.model}|${config.confirmed}|${LlmCommentRuleView.canonicalJson(views)}';

  static String? _parentOf(List<String?>? parents, int index) =>
      parents == null || index >= parents.length ? null : parents[index];

  /// Stable comment identity: the platform rpid. Comments without one are
  /// never cached (#124 will merge this into the shared comment cache).
  static String? _commentIdentity(ReplyInfo reply) {
    final rpid = reply.id.toInt();
    return rpid > 0 ? 'r:$rpid' : null;
  }
}

/// One video candidate extracted by the caller (spec 11-4: per-item
/// judgment over title + category/tag context).
class LlmVideoCandidate {
  const LlmVideoCandidate({
    required this.title,
    this.snippet,
    this.tags = const [],
    this.identity,
  });

  final String title;

  /// Recommendation reason / description, when available.
  final String? snippet;
  final List<String> tags;

  /// Stable local key (e.g. jevVideoLocalKey); null falls back to a
  /// normalized-title identity for the cache.
  final String? identity;
}

/// Generic-line VIDEO pipeline (spec 3): runs after the Jev evaluation on
/// the unhit survivors. One request per candidate, no retries; a failed
/// item fails open. Returns a parallel hidden[] list and never throws.
class LlmVideoScreening {
  LlmVideoScreening({
    LlmChatClient? client,
    LlmSettingsStore? settings,
    LlmCredentialStore? credentials,
    LlmVideoRuleStore? rules,
    LlmVerdictCache? cache,
  }) : _client = client ?? LlmChatClient(),
       _settings = settings ?? LlmSettingsStore(),
       _credentials = credentials ?? SecureLlmCredentialStore(),
       _rules = rules ?? LlmVideoRuleStore(),
       _cache = cache ?? LlmVerdictCache();

  final LlmChatClient _client;
  final LlmSettingsStore _settings;
  final LlmCredentialStore _credentials;
  final LlmVideoRuleStore _rules;
  final LlmVerdictCache _cache;

  /// Whether the generic video line would run at all.
  Future<bool> isEnabled() async {
    try {
      final rules = (await _rules.load()).activeFor();
      if (rules.isEmpty) return false;
      await _resolve(settings: _settings, credentials: _credentials);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Screens [candidates]; returns a parallel hidden[] list. [timeout]
  /// tightens, never extends, the 8s page budget. Never throws.
  Future<List<bool>> screen(
    List<LlmVideoCandidate> candidates, {
    Duration? timeout,
  }) async {
    final hidden = List<bool>.filled(candidates.length, false);
    if (candidates.isEmpty) return hidden;
    final budget = timeout == null || timeout >= LlmLimits.requestTimeout
        ? LlmLimits.requestTimeout
        : timeout;
    if (budget <= Duration.zero) return hidden;
    final watch = Stopwatch()..start();
    try {
      final rules = (await _rules.load()).activeFor();
      if (rules.isEmpty) return hidden;
      final context = await _resolve(
        settings: _settings,
        credentials: _credentials,
      );
      final fingerprint = _fingerprint(context.config, rules);
      final knownIds = {for (final rule in rules) rule.id};
      final cacheOn = _cache.enabled;
      final resolved = List<bool>.filled(candidates.length, false);
      if (cacheOn) {
        for (var i = 0; i < candidates.length; i++) {
          final identity = _videoIdentity(candidates[i]);
          if (identity == null) continue;
          final cached = _cache.lookup(fingerprint, identity);
          if (cached == null) continue;
          resolved[i] = true;
          if (cached) hidden[i] = true;
        }
      }
      for (var i = 0; i < candidates.length; i++) {
        if (resolved[i]) continue;
        final candidate = candidates[i];
        final title = candidate.title.trim();
        // Empty titles carry no semantic to judge; fail open, do not cache.
        if (title.isEmpty) continue;
        if (watch.elapsed >= budget) {
          // Over budget: no further verdict may be applied or cached.
          return List<bool>.filled(candidates.length, false);
        }
        try {
          final remaining = budget - watch.elapsed;
          final outcome = await _client
              .call(
                system: llmSystemPrompt,
                user: LlmPrompt.videoUserMessage(
                  rules: rules,
                  title: title,
                  snippet: candidate.snippet,
                  tags: candidate.tags,
                ),
                timeout: remaining,
              )
              .timeout(remaining);
          if (!outcome.ok) continue;
          final verdict = LlmVerdictParser.parse(outcome.text, knownIds);
          if (!verdict.valid) continue;
          // rule ids are plain here: one candidate per request.
          if (verdict.hits.isNotEmpty) {
            hidden[i] = true;
          }
          if (!verdict.droppedHits && cacheOn) {
            final identity = _videoIdentity(candidate);
            if (identity != null) {
              _cache.put(fingerprint, identity, hide: hidden[i]);
            }
          }
        } catch (_) {
          // Fail-open: this item stays visible.
        }
      }
      // Mid-pass policy drift voids the whole pass (Jev precedent).
      final remaining = budget - watch.elapsed;
      if (remaining <= Duration.zero) {
        return List<bool>.filled(candidates.length, false);
      }
      final config = await _settings.load().timeout(remaining);
      final rulesNow = (await _rules.load().timeout(remaining)).activeFor();
      if (rulesNow.isNotEmpty &&
          _fingerprint(config, rulesNow) != fingerprint) {
        return List<bool>.filled(candidates.length, false);
      }
      return hidden;
    } catch (_) {
      return List<bool>.filled(candidates.length, false);
    }
  }

  /// Generation = protocol + base URL + model + confirmed + video
  /// rule_version of the ACTIVE set (spec 5).
  static String _fingerprint(
    LlmProviderConfig config,
    List<LlmVideoRule> rules,
  ) =>
      'llm-video|${config.protocol?.id}|${config.normalizedBaseUrl}|${config.model}|${config.confirmed}|${videoRuleVersion(rules)}';

  /// Cache identity: the caller-provided stable key, else the normalized
  /// title (same whitespace/lowercase rule as JevEvaluator titles). Empty
  /// titles are never cacheable.
  static String? _videoIdentity(LlmVideoCandidate candidate) {
    final key = candidate.identity?.trim();
    if (key != null && key.isNotEmpty) return 'k:$key';
    final title = candidate.title.trim().toLowerCase();
    if (title.isEmpty) return null;
    return 't:$title';
  }
}
