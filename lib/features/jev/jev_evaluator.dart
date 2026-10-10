import 'dart:math' as math;

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart';
import 'package:PiliPlus/features/jev/jev_preference_store.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;

/// The minimum candidate context Jev may see (issue #34): the title, plus
/// the short snippet or category/tag fields the card already carries. No id,
/// no link, no uploader, no long metadata - callers hand over exactly these
/// fields and nothing else.
@immutable
class JevCandidate {
  const JevCandidate({
    required this.title,
    this.snippet,
    this.tags = const <String>[],
  });

  final String title;

  final String? snippet;

  final List<String> tags;

  /// The per-candidate context object carried inside state.candidates.
  Map<String, Object?> toContext() => <String, Object?>{
    JevRequest.candidateTitleField: title,
    if (snippet != null && snippet!.trim().isNotEmpty)
      JevRequest.candidateSnippetField: snippet,
    if (tags.isNotEmpty) JevRequest.candidateTagsField: tags,
  };
}

/// One provider answer, normalized across the Noul and Choice/Score shapes
/// (issue #31: keep the Noul probability and the Choice/Score confidence
/// where present - a Noul answer has no separate confidence field).
@immutable
class JevAnswer {
  const JevAnswer({this.noul, this.confidence});

  final double? noul;

  final double? confidence;

  /// Parses the provider payload into per-question answers. Returns null
  /// when the payload is not a well-formed answers map, so the whole batch
  /// fails open.
  static Map<String, JevAnswer>? parseAll(Object? data) {
    if (data is! Map) return null;
    final raw = data[JevResponse.answersField];
    if (raw is! Map || raw.isEmpty) return null;
    final answers = <String, JevAnswer>{};
    raw.forEach((key, value) {
      if (key is! String || value is! Map) return;
      answers[key] = JevAnswer(
        noul: _asDouble(value[JevResponse.noulField]),
        confidence: _asDouble(value[JevResponse.confidenceField]),
      );
    });
    return answers;
  }

  static double? _asDouble(Object? value) => switch (value) {
    num value => value.toDouble(),
    _ => null,
  };
}

/// Overall outcome of one screening pass, for tests and aggregate
/// diagnostics. Per-item decisions are never logged (issue #36).
enum JevScreenStatus {
  /// The master switch or the surface switch is off - nothing was sent.
  disabled,

  /// No usable credential for a confirmed provider - nothing was sent.
  noCredential,

  /// At least one request was attempted and none was answered.
  providerUnavailable,

  /// At least one batch was answered; decisions reflect only those batches.
  evaluated,
}

/// Result of one screening pass: which candidates to hide, parallel to the
/// input order. Everything that is not a proven substantive match stays
/// visible.
class JevScreening {
  const JevScreening({
    required this.status,
    required this.hidden,
    this.requests = 0,
  });

  final JevScreenStatus status;

  /// hidden[i] == true hides the i-th candidate before render.
  final List<bool> hidden;

  /// Number of provider requests this pass issued (0..ceil(n / batchSize)).
  final int requests;
}

/// Transport seam: one POST per batch to the selected provider. Any throw is
/// a failed batch and keeps its candidates visible.
typedef JevTransport = Future<Object?> Function({
  required JevProvider provider,
  required String apiKey,
  required Map<String, Object?> body,
});

/// Production transport: its own [Dio], like the settings-page probe - no app
/// interceptors, no cookies, no account headers (issue #32). Non-2xx answers
/// surface as [DioException] and fail open in the evaluator.
class JevHttpTransport {
  JevHttpTransport({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Object?> call({
    required JevProvider provider,
    required String apiKey,
    required Map<String, Object?> body,
  }) async {
    final response = await _dio.post<Object?>(
      provider.endpoint,
      data: body,
      options: Options(
        headers: <String, String>{
          'authorization': 'Bearer $apiKey',
          'content-type': 'application/json',
        },
        sendTimeout: JevLimits.requestTimeout,
        receiveTimeout: JevLimits.requestTimeout,
      ),
    );
    return response.data;
  }
}

/// The shared Jev evaluator (slice 3): screens survivors of every cheaper
/// filter, in bounded serial batches, and hides only a proven substantive
/// match. Fail-open everywhere: a disabled surface, a missing or unreadable
/// key, a timeout, a rate limit, a provider error, a malformed payload, or a
/// missing answer keeps every affected candidate visible
/// (issues #34/#36/#65).
class JevEvaluator {
  JevEvaluator({
    JevTransport? transport,
    JevCredentialStore? credentials,
    JevSettingsStore? settings,
    JevPreferenceStore? preferences,
    JevRuleStore? rules,
  }) : _transport = transport ?? JevHttpTransport().call,
       _credentials = credentials ?? SecureJevCredentialStore(),
       _settings = settings ?? JevSettingsStore(),
       _preferences = preferences ?? JevPreferenceStore(box: settings?.box),
       _rules = rules ?? JevRuleStore(box: settings?.box);

  final JevTransport _transport;
  final JevCredentialStore _credentials;
  final JevSettingsStore _settings;
  final JevPreferenceStore _preferences;
  final JevRuleStore _rules;

  /// Screens [candidates] for [surface]. The returned list is parallel to the
  /// input; callers drop the hidden entries before render and before
  /// exposure recording.
  Future<JevScreening> screen(
    List<JevCandidate> candidates, {
    required JevSurface surface,
  }) async {
    if (candidates.isEmpty) {
      return const JevScreening(
        status: JevScreenStatus.evaluated,
        hidden: <bool>[],
      );
    }
    final hidden = List<bool>.filled(candidates.length, false);

    final settings = await _settings.load();
    if (!settings.isSurfaceEnabled(surface)) {
      return JevScreening(status: JevScreenStatus.disabled, hidden: hidden);
    }
    // The confirmation latch is part of the routing rule (issue #38): an
    // unconfirmed selection must never carry the stored key anywhere.
    final provider = settings.provider;
    if (provider == null || !settings.providerConfirmed) {
      return JevScreening(
        status: JevScreenStatus.noCredential,
        hidden: hidden,
      );
    }
    final String? apiKey;
    try {
      apiKey = await _credentials.read();
    } catch (_) {
      // Secure storage failing is a credential failure, not a screening one.
      return JevScreening(
        status: JevScreenStatus.noCredential,
        hidden: hidden,
      );
    }
    if (apiKey == null || apiKey.isEmpty) {
      return JevScreening(
        status: JevScreenStatus.noCredential,
        hidden: hidden,
      );
    }

    final config = await _rules.load();
    final target = JevRuleTarget.forSurface(surface);
    final activeRules = config.activeFor(target);
    final builtin = config.builtinEnabled(target);
    if (!builtin && activeRules.isEmpty) {
      return JevScreening(status: JevScreenStatus.disabled, hidden: hidden);
    }
    // Custom-only judgments never send the unrelated negative-feedback profile.
    final state = builtin
        ? (await _preferences.load()).statePayload()
        : <String, Object?>{};

    var requests = 0;
    var answeredBatches = 0;
    for (
      var start = 0;
      start < candidates.length;
      start += JevLimits.batchSize
    ) {
      final end = math.min(start + JevLimits.batchSize, candidates.length);
      final batch = candidates.sublist(start, end);
      requests++;
      try {
        final data = await _transport(
          provider: provider,
          apiKey: apiKey,
          body: JevRequest.body(
            model: settings.modelFor(provider),
            state: <String, Object?>{
              ...state,
              if (activeRules.isNotEmpty) 'surface': surface.id,
              JevRequest.candidatesField: <String, Object?>{
                for (var i = 0; i < batch.length; i++)
                  JevRequest.candidateKey(i): _boundedContext(batch[i]),
              },
            },
            questions: <String, Map<String, Object?>>{
              for (var i = 0; i < batch.length; i++) ...{
                if (builtin)
                  JevRequest.candidateKey(i): JevRequest.question(
                    candidateKey: JevRequest.candidateKey(i),
                  ),
                for (var r = 0; r < activeRules.length; r++) ...{
                  _ruleKey(i, r): activeRules[r].compile(
                    JevRequest.candidateKey(i),
                  ),
                  '${_ruleKey(i, r)}_context': _contextQuestion(
                    activeRules[r],
                    JevRequest.candidateKey(i),
                  ),
                },
              },
            },
          ),
        );
        if (data is! Map || data['answers'] is! Map) continue;
        final rawAnswers = data['answers'] as Map;
        if (rawAnswers.isEmpty) continue;
        final answers = JevAnswer.parseAll(data);
        answeredBatches++;
        for (var i = 0; i < batch.length; i++) {
          if (batch[i].title.trim().isEmpty) continue;
          final answer = builtin && answers != null
              ? answers[JevRequest.candidateKey(i)]
              : null;
          final lowConfidence =
              answer?.confidence != null &&
              (!answer!.confidence!.isFinite ||
                  answer.confidence! < JevLimits.minReportedConfidence ||
                  answer.confidence! > 1);
          final rawBuiltin = rawAnswers[JevRequest.candidateKey(i)];
          if (answer?.noul != null &&
              answer!.noul!.isFinite &&
              answer.noul! <= 1 &&
              (rawBuiltin is Map &&
                  (rawBuiltin['type'] == null ||
                      rawBuiltin['type'] == 'noul')) &&
              !lowConfidence &&
              answer.noul! >= JevLimits.hideNoulThreshold) {
            hidden[start + i] = true;
          }
          for (var r = 0; r < activeRules.length; r++) {
            // Asking for No must never equate missing evidence with a confident No.
            final sufficient = rawAnswers['${_ruleKey(i, r)}_context'];
            final p = sufficient is Map ? sufficient['noul'] : null;
            if (sufficient is! Map ||
                sufficient['type'] != 'noul' ||
                p is! num ||
                !p.isFinite ||
                p < .95 ||
                p > 1) {
              continue;
            }
            if (activeRules[r].hides(rawAnswers[_ruleKey(i, r)])) {
              hidden[start + i] = true;
            }
          }
        }
      } catch (_) {
        // Fail-open: this whole batch stays visible (issue #36).
      }
    }

    return JevScreening(
      status: answeredBatches > 0
          ? JevScreenStatus.evaluated
          : JevScreenStatus.providerUnavailable,
      hidden: List<bool>.unmodifiable(hidden),
      requests: requests,
    );
  }

  static String _ruleKey(int candidate, int rule) =>
      '${JevRequest.candidateKey(candidate)}_rule_${rule + 1}';

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

  static Map<String, Object?> _boundedContext(JevCandidate candidate) => {
    'title': _limit(candidate.title, 1000),
    if (candidate.snippet?.trim().isNotEmpty == true)
      'snippet': _limit(candidate.snippet!, 800),
    if (candidate.tags.isNotEmpty)
      'tags': candidate.tags.take(12).map((tag) => _limit(tag, 80)).toList(),
  };

  static String _limit(String text, int limit) =>
      String.fromCharCodes(text.runes.take(limit));
}
