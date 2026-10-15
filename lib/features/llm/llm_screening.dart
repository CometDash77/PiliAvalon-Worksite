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

double _bandLowerBound(LlmConfidenceBand band) => switch (band) {
  LlmConfidenceBand.high => .95,
  LlmConfidenceBand.medium => .80,
  LlmConfidenceBand.low => 0,
};

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
    final hiddenReasons = <int, String>{};
    String? modelId;
    String? failure;
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
      modelId = context.config.model;
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
          final thresholds = <String, double>{
            for (var b = 0; b < batch.length; b++)
              for (final rule in views)
                LlmPrompt.commentRuleId(
                  LlmPrompt.candidateKey(b),
                  rule.id,
                ): rule.threshold,
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
            failure ??= 'upstream';
            cacheable = false;
            continue;
          }
          final verdict = LlmVerdictParser.parseCanonical(
            outcome.text,
            knownIds.keys.toSet(),
          );
          if (!verdict.valid) {
            failure ??= 'parse';
            cacheable = false;
            continue;
          }
          for (final hit in verdict.hits) {
            final b = knownIds[hit.ruleId];
            if (b == null) continue; // unreachable: parser drops unknown ids
            final index = batch[b];
            final band = hit.band;
            final threshold = thresholds[hit.ruleId];
            if (band == null || threshold == null ||
                _bandLowerBound(band) < threshold) {
              continue;
            }
            hidden[index] = true;
            hiddenByRule[index] = hit.ruleId;
            hiddenReasons[index] = hit.reason;
          }
          if (cacheOn) {
            for (var b = 0; b < batch.length; b++) {
              final identity = _commentIdentity(replies[batch[b]]);
              if (identity == null) continue;
              _cache.put(generation, identity, hide: hidden[batch[b]]);
            }
          }
        } catch (e) {
          // Fail-open: this whole batch stays visible (Jev precedent).
          failure ??= e is TimeoutException ? 'timeout' : 'upstream';
          cacheable = false;
        }
      }
    } catch (e) {
      if (e is! _LlmUnavailable) {
        failure ??= e is TimeoutException ? 'timeout' : 'upstream';
      }
      expired = true;
      cacheable = false;
    }
    if (!expired) {
      final remaining = budget - watch.elapsed;
      if (remaining <= Duration.zero) {
        // The pass overran its budget: no verdict may be applied or cached.
        failure ??= 'timeout';
        _recordPassFailure(
          modelId: modelId,
          failure: failure,
          elapsedMs: watch.elapsedMilliseconds,
        );
        return LlmCommentResult(replies: replies, cacheable: false);
      }
      try {
        final config = await _settings.load().timeout(remaining);
        final ruleConfig = await _rules.load().timeout(remaining);
        final views = LlmCommentRuleView.of(
          ruleConfig.activeFor(JevRuleTarget.comment),
        );
        if (initialFingerprint != _fingerprint(config, views)) {
          // Decisions compiled under a stale policy are void.
          failure ??= 'drift';
          _recordPassFailure(
            modelId: modelId ?? config.model,
            failure: failure,
            elapsedMs: watch.elapsedMilliseconds,
          );
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
          line: JevScreenLogLine.llm,
          snippet: parent == null || parent.isEmpty ? null : parent,
          ruleId: hiddenByRule[i],
          modelId: modelId,
          reason: hiddenReasons[i],
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
    }
    if (blocked.isNotEmpty && screenLog) {
      try {
        unawaited(JevScreenLog.instance.record(blocked));
      } catch (_) {
        // Log failures never affect screening.
      }
    } else if (blocked.isEmpty && failure != null && screenLog) {
      _recordPassFailure(
        modelId: modelId,
        failure: failure,
        elapsedMs: watch.elapsedMilliseconds,
      );
    }
    return LlmCommentResult(replies: visible, cacheable: cacheable);
  }

  /// Records one pass-level failure line (empty title, no entry content)
  /// when the generic comment line produced no hidden entries but failed.
  static void _recordPassFailure({
    required String? modelId,
    required String? failure,
    required int elapsedMs,
  }) {
    if (failure == null) return;
    try {
      unawaited(
        JevScreenLog.instance.record([
          JevScreenLogEntry(
            time: DateTime.now().millisecondsSinceEpoch,
            kind: JevScreenLogKind.comment,
            surface: JevSurface.comment.id,
            title: '',
            line: JevScreenLogLine.llm,
            modelId: modelId,
            failure: failure,
            elapsedMs: elapsedMs,
          ),
        ]),
      );
    } catch (_) {
      // Log failures never affect screening.
    }
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

/// Result of one generic-line video pass: the parallel hidden[] list plus
/// log-facing facts (per-hit rule/reason, model id, failure category,
/// elapsed time). Hidden entries answered from the cache carry no
/// rule/reason.
class LlmVideoScreenOutcome {
  const LlmVideoScreenOutcome({
    required this.hidden,
    this.ruleIds = const <int, String>{},
    this.reasons = const <int, String>{},
    this.modelId,
    this.failure,
    this.elapsedMs = 0,
  });

  final List<bool> hidden;

  /// index → triggering rule id (live hits only; cache hits absent).
  final Map<int, String> ruleIds;

  /// index → verdict reason, already clipped upstream.
  final Map<int, String> reasons;

  final String? modelId;

  /// Pass-level failure category: timeout/upstream/parse/drift; null when
  /// the pass completed (even with per-item fail-opens recorded above).
  final String? failure;

  final int elapsedMs;
}

/// Generic-line VIDEO pipeline (spec 3): runs after the Jev evaluation on
/// the unhit survivors. One request per candidate, no retries; a failed
/// item fails open. Returns an [LlmVideoScreenOutcome] and never throws.
class LlmVideoScreening {
  LlmVideoScreening({
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

  // Unified rule source (#141): typed rules and video-text rules live in
  // one blob, so switching backends never re-asks for the same rule.
  final JevRuleStore _rules;
  final LlmSettingsStore _settings;
  final LlmCredentialStore _credentials;
  final LlmVerdictCache _cache;

  /// One-shot legacy-blob migration (#141); a failed migration fails open
  /// downstream (legacy rules simply stay invisible this pass).
  Future<void> _migrateRules() async {
    try {
      await _rules.migrateLegacyLlmVideoRules();
    } catch (_) {}
  }

  /// Whether the generic video line would run at all.
  Future<bool> isEnabled() async {
    try {
      await _migrateRules();
      final rules = (await _rules.load()).activeVideoTextRules();
      if (rules.isEmpty) return false;
      await _resolve(settings: _settings, credentials: _credentials);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Screens [candidates] and returns an [LlmVideoScreenOutcome]: the
  /// parallel hidden[] list plus log-facing facts for the screen log
  /// (#131). [timeout] tightens, never extends, the 8s page budget.
  /// Never throws.
  Future<LlmVideoScreenOutcome> screen(
    List<LlmVideoCandidate> candidates, {
    Duration? timeout,
  }) async {
    final hidden = List<bool>.filled(candidates.length, false);
    if (candidates.isEmpty) {
      return LlmVideoScreenOutcome(hidden: hidden);
    }
    final budget = timeout == null || timeout >= LlmLimits.requestTimeout
        ? LlmLimits.requestTimeout
        : timeout;
    if (budget <= Duration.zero) {
      return LlmVideoScreenOutcome(hidden: hidden);
    }
    final watch = Stopwatch()..start();
    LlmVideoScreenOutcome done(
      List<bool> hidden, {
      Map<int, String> ruleIds = const {},
      Map<int, String> reasons = const {},
      String? modelId,
      String? failure,
    }) => LlmVideoScreenOutcome(
      hidden: hidden,
      ruleIds: ruleIds,
      reasons: reasons,
      modelId: modelId,
      failure: failure,
      elapsedMs: watch.elapsedMilliseconds,
    );
    final ruleIds = <int, String>{};
    final reasons = <int, String>{};
    String? modelId;
    String? failure;
    try {
      await _migrateRules();
      final rules = (await _rules.load()).activeVideoTextRules();
      if (rules.isEmpty) return done(hidden);
      final context = await _resolve(
        settings: _settings,
        credentials: _credentials,
      );
      modelId = context.config.model;
      final fingerprint = _fingerprint(context.config, rules);
      final knownIds = {for (final rule in rules) rule.id};
      final cacheOn = _cache.enabled;
      final pendingCache = <String, bool>{};
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
          return done(
            List<bool>.filled(candidates.length, false),
            modelId: modelId,
            failure: failure ?? 'timeout',
          );
        }
        try {
          final remaining = budget - watch.elapsed;
          final outcome = await _client
              .call(
                system: llmVideoSystemPrompt,
                user: LlmPrompt.videoUserMessage(
                  rules: rules,
                  title: title,
                  snippet: candidate.snippet,
                  tags: candidate.tags,
                ),
                timeout: remaining,
              )
              .timeout(remaining);
          if (!outcome.ok) {
            failure ??= 'upstream';
            continue;
          }
          final verdict = LlmVerdictParser.parse(outcome.text, knownIds);
          if (!verdict.valid) {
            failure ??= 'parse';
            continue;
          }
          // rule ids are plain here: one candidate per request.
          if (verdict.hits.isNotEmpty) {
            hidden[i] = true;
            ruleIds[i] = verdict.hits.first.ruleId;
            reasons[i] = verdict.hits.first.reason;
          }
          if (cacheOn) {
            final identity = _videoIdentity(candidate);
            if (identity != null) {
              pendingCache[identity] = hidden[i];
            }
          }
        } catch (e) {
          // Fail-open: this item stays visible.
          failure ??= e is TimeoutException ? 'timeout' : 'upstream';
        }
      }
      // Mid-pass policy drift voids the whole pass (Jev precedent).
      final remaining = budget - watch.elapsed;
      if (remaining <= Duration.zero) {
        return done(
          List<bool>.filled(candidates.length, false),
          modelId: modelId,
          failure: failure ?? 'timeout',
        );
      }
      final config = await _settings.load().timeout(remaining);
      final rulesNow = (await _rules.load().timeout(remaining))
          .activeVideoTextRules();
      if (_fingerprint(config, rulesNow) != fingerprint) {
        return done(
          List<bool>.filled(candidates.length, false),
          modelId: modelId,
          failure: failure ?? 'drift',
        );
      }
      for (final entry in pendingCache.entries) {
        _cache.put(fingerprint, entry.key, hide: entry.value);
      }
      return done(
        hidden,
        ruleIds: ruleIds,
        reasons: reasons,
        modelId: modelId,
        failure: failure,
      );
    } catch (e) {
      if (e is _LlmUnavailable) {
        // Line disabled mid-pass: a gate, not an operational failure.
        return done(List<bool>.filled(candidates.length, false));
      }
      return done(
        List<bool>.filled(candidates.length, false),
        failure: failure ?? (e is TimeoutException ? 'timeout' : 'upstream'),
      );
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
