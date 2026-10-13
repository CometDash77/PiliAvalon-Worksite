import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:PiliPlus/features/jev/jev_comment_migration.dart';
import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;

class JevCommentResult {
  const JevCommentResult({required this.replies, required this.cacheable});

  final List<ReplyInfo> replies;

  /// False when the pass could not produce confident verdicts for every
  /// candidate; callers must not cache a keep decision built on it.
  final bool cacheable;
}

/// The single Jev comment pipeline (issue #122).
///
/// Formerly there were two parallel comment filters - a free-text criteria
/// prompt (this class) and the typed 判断规则 rules (JevFinalScreen). The
/// merged executor compiles [JevRule]s for [JevRuleTarget.comment] into the
/// typed-decision request: one semantic pass per page, no duplicate config.
///
/// Gating: the master switch, the [JevSurface.comment] surface switch, and at
/// least one active comment rule. Fail-open everywhere: a missing key, an
/// unconfirmed provider, a timeout, a provider error, a malformed payload, or
/// a mid-flight policy change keeps every affected candidate visible.
class JevCommentScreening {
  JevCommentScreening({
    JevTransport? transport,
    JevCredentialStore? credentials,
    JevSettingsStore? settings,
    JevRuleStore? rules,
    this.passTimeout = JevLimits.requestTimeout,
  }) : _transport = transport ?? JevHttpTransport().call,
       _credentials = credentials ?? SecureJevCredentialStore(),
       _settings = settings ?? JevSettingsStore(),
       _rules = rules ?? JevRuleStore(box: settings?.box);

  final JevTransport _transport;
  final JevCredentialStore _credentials;
  final JevSettingsStore _settings;
  final JevRuleStore _rules;

  /// Upper bound of the whole pass; single calls never exceed it.
  final Duration passTimeout;

  /// A comment body never leaves the device beyond this many runes.
  static const int maxTextChars = 2000;

  /// Parent-context snippet bound, mirroring JevEvaluator._boundedContext.
  static const int maxSnippetChars = 800;

  /// Runs the one-time retired-key migration, then loads settings and the
  /// active comment rules together — the shared preamble of the three
  /// entry points below.
  Future<(JevSettings, List<JevRule>)> _loadActive() async {
    await JevCommentCriteriaMigration.ensureRun(
      settings: _settings,
      rules: _rules,
    );
    final settings = await _settings.load();
    final config = await _rules.load();
    final activeRules = config.activeFor(JevRuleTarget.comment);
    return (settings, activeRules);
  }

  /// Whether the merged comment pipeline would run at all.
  Future<bool> isEnabled() async {
    final (_, activeRules) = await _loadActive();
    if (activeRules.isEmpty) return false;
    final settings = await _settings.load();
    return settings.isSurfaceEnabled(JevSurface.comment);
  }

  /// Fingerprint of everything that can change verdicts. Rule edits matter
  /// only for the comment target: video/live rule edits must not invalidate
  /// cached comment decisions.
  Future<String> policyKey() async {
    final (settings, activeRules) = await _loadActive();
    return _fingerprint(settings, activeRules);
  }

  /// Screens [replies] (flat, source order; callers may pass the matching
  /// [parents] context texts) and returns the visible ones. [timeout]
  /// tightens, never extends, [passTimeout].
  Future<JevCommentResult> filter(
    List<ReplyInfo> replies, {
    List<String?>? parents,
    Duration? timeout,
    bool screenLog = true,
  }) async {
    final budget = timeout == null || timeout >= passTimeout
        ? passTimeout
        : timeout;
    if (budget <= Duration.zero) {
      return JevCommentResult(replies: replies, cacheable: false);
    }
    final watch = Stopwatch()..start();
    final hidden = List<bool>.filled(replies.length, false);
    final hiddenByRule = <int, String>{};
    var cacheable = true;
    var expired = false;
    var initialPolicy = '';
    try {
      final (settings, activeRules) = await _loadActive();
      initialPolicy = _fingerprint(settings, activeRules);
      if (!settings.isSurfaceEnabled(JevSurface.comment) ||
          activeRules.isEmpty ||
          replies.isEmpty) {
        return JevCommentResult(replies: replies, cacheable: cacheable);
      }
      // The confirmation latch is part of the routing rule (issue #38).
      final provider = settings.provider;
      if (provider == null || !settings.providerConfirmed) {
        return JevCommentResult(replies: replies, cacheable: false);
      }
      final String? apiKey;
      try {
        apiKey = await _credentials.read();
      } catch (_) {
        return JevCommentResult(replies: replies, cacheable: false);
      }
      if (apiKey == null || apiKey.isEmpty) {
        return JevCommentResult(replies: replies, cacheable: false);
      }
      // repeat_count keeps duplicated texts from being billed as new
      // candidates.
      final repeats = <String, int>{};
      for (final reply in replies) {
        final text = reply.content.message.trim();
        if (text.isEmpty) continue;
        repeats[text] = (repeats[text] ?? 0) + 1;
      }
      // Blank bodies are never sent; oversized ones are not sent either but
      // still poison the decision cache because their verdict stays unknown.
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
      for (
        var start = 0;
        start < sent.length;
        start += JevLimits.batchSize
      ) {
        final end = math.min(start + JevLimits.batchSize, sent.length);
        final batch = sent.sublist(start, end);
        if (watch.elapsed >= budget) {
          expired = true;
          cacheable = false;
          break;
        }
        try {
          final data = await _transport(
            provider: provider,
            apiKey: apiKey,
            body: JevRequest.body(
              model: settings.modelFor(provider),
              state: <String, Object?>{
                JevRequest.candidatesField: <String, Object?>{
                  for (var b = 0; b < batch.length; b++)
                    JevRequest.candidateKey(b): _candidateContext(
                      replies[batch[b]],
                      _parentOf(parents, batch[b]),
                      repeats[replies[batch[b]].content.message.trim()] ?? 1,
                    ),
                },
              },
              questions: <String, Map<String, Object?>>{
                for (var b = 0; b < batch.length; b++) ...{
                  for (var r = 0; r < activeRules.length; r++) ...{
                    _ruleKey(b, r): activeRules[r].compile(
                      JevRequest.candidateKey(b),
                    ),
                    '${_ruleKey(b, r)}_context': _contextQuestion(
                      activeRules[r],
                      JevRequest.candidateKey(b),
                    ),
                  },
                },
              },
            ),
          ).timeout(budget - watch.elapsed);
          if (data is! Map || data['answers'] is! Map) {
            cacheable = false;
            continue;
          }
          final rawAnswers = data['answers'] as Map;
          if (rawAnswers.isEmpty) {
            cacheable = false;
            continue;
          }
          for (var b = 0; b < batch.length; b++) {
            final index = batch[b];
            for (var r = 0; r < activeRules.length; r++) {
              // Asking for No must never equate missing evidence with a
              // confident No (see JevEvaluator): an insufficient or malformed
              // context answer yields no usable verdict, so the keep decision
              // must not be cached.
              final sufficient = rawAnswers['${_ruleKey(b, r)}_context'];
              final p = sufficient is Map ? sufficient['noul'] : null;
              if (sufficient is! Map ||
                  sufficient['type'] != 'noul' ||
                  p is! num ||
                  !p.isFinite ||
                  p < JevLimits.minSufficientContext ||
                  p > 1) {
                cacheable = false;
                continue;
              }
              final rule = activeRules[r];
              final ruleAnswer = rawAnswers[_ruleKey(b, r)];
              if (!_isWellFormedAnswer(ruleAnswer, rule)) {
                cacheable = false;
                continue;
              }
              if (rule.hides(ruleAnswer)) {
                hidden[index] = true;
                hiddenByRule[index] = rule.id;
              } else if (rule.type == JevRuleType.noul) {
                // Mid-band noul answers sit between "clearly No" and "clearly
                // Yes": a keep verdict from that band is not reliable enough
                // to cache (same contract the retired criteria chain had).
                final value = ((ruleAnswer as Map)['noul'] as num).toDouble();
                final band = 1 - rule.threshold;
                if (value > band && value < rule.threshold) {
                  cacheable = false;
                }
              }
            }
          }
        } catch (_) {
          // Fail-open: this whole batch stays visible (issue #36).
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
        return JevCommentResult(replies: replies, cacheable: false);
      }
      try {
        final settings = await _settings.load().timeout(remaining);
        final config = await _rules.load().timeout(remaining);
        if (initialPolicy !=
            _fingerprint(
              settings,
              config.activeFor(JevRuleTarget.comment),
            )) {
          // Decisions compiled under a stale policy are void: return
          // everything untouched instead of applying stale hides.
          return JevCommentResult(replies: replies, cacheable: false);
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
        // 日志失败不影响筛选。
      }
    }
    return JevCommentResult(replies: visible, cacheable: cacheable);
  }

  String _fingerprint(JevSettings settings, List<JevRule> rules) => jsonEncode([
    settings.enabled,
    settings.isSurfaceEnabled(JevSurface.comment),
    [for (final rule in rules) rule.toJson()],
    settings.provider?.id,
    settings.providerConfirmed,
    if (settings.provider != null) settings.modelFor(settings.provider!),
  ]);

  static String? _parentOf(List<String?>? parents, int index) =>
      parents == null || index >= parents.length ? null : parents[index];

  static String _ruleKey(int candidate, int rule) =>
      '${JevRequest.candidateKey(candidate)}_rule_${rule + 1}';

  static Map<String, Object?> _candidateContext(
    ReplyInfo reply,
    String? parent,
    int repeatCount,
  ) {
    final parentText = parent?.trim();
    return <String, Object?>{
      'text': _limit(reply.content.message.trim(), maxTextChars),
      if (parentText != null && parentText.isNotEmpty)
        'snippet': _limit(parentText, maxSnippetChars),
      if (repeatCount > 1) 'repeat_count': repeatCount,
    };
  }

  /// Same sufficiency gate the evaluator uses for typed rules: the model must
  /// first prove it could actually judge the question for this candidate.
  static Map<String, Object?> _contextQuestion(
    JevRule rule,
    String candidateKey,
  ) => {
    'type': 'noul',
    'instructions':
        '只看 `state.candidates.$candidateKey`，是否有足够信息回答用户的问题“${rule.question.trim()}”？不要猜测未提供的事实。',
    'criteria': {
      'true': '现有正文或元数据足以判断该问题，无需猜测缺失资料。',
      'false': '缺少回答所需的信息或存在不确定性。',
    },
  };

  /// noul answers get the exact validity checks the old criteria chain used;
  /// choice answers get the same shape validation JevRule.hides applies, so a
  /// malformed payload can neither hide nor yield a cacheable keep verdict.
  static bool _isWellFormedAnswer(Object? answer, JevRule rule) {
    if (answer is! Map || answer['type'] != rule.type.name) return false;
    if (rule.type == JevRuleType.noul) {
      final p = answer['noul'];
      if (p is! num || !p.isFinite || p < 0 || p > 1) return false;
      final confidence = answer['confidence'];
      if (confidence != null &&
          (confidence is! num ||
              !confidence.isFinite ||
              confidence < JevLimits.minReportedConfidence ||
              confidence > 1)) {
        return false;
      }
    } else {
      final choice = answer['choice'];
      final confidence = answer['confidence'];
      if (choice is! String ||
          confidence is! num ||
          !confidence.isFinite ||
          confidence < 0 ||
          confidence > 1) {
        return false;
      }
      final probabilities = answer['probabilities'];
      if (probabilities is! Map || probabilities.length != rule.options.length) {
        return false;
      }
      var sum = 0.0;
      var top = '';
      var topValue = -1.0;
      for (final entry in probabilities.entries) {
        final value = entry.value;
        if (value is! num ||
            !value.isFinite ||
            value < 0 ||
            value > 1 ||
            rule.options.every((option) => option.id != entry.key)) {
          return false;
        }
        sum += value;
        if (value > topValue) {
          topValue = value.toDouble();
          top = entry.key as String;
        }
      }
      if ((sum - 1).abs() > .001 || top != choice) return false;
    }
    return true;
  }

  static String _limit(String text, int limit) =>
      String.fromCharCodes(text.runes.take(limit));
}
