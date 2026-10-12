import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'dart:math' as math;

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart';
import 'package:PiliPlus/features/jev/jev_preference_store.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_verdict_cache.dart';
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
    this.localKey,
  });

  final String title;

  final String? snippet;

  final List<String> tags;

  /// Local-only cache identity for the final-review verdict cache (issue
  /// #123): callers whose card carries a stable id pass 'bvid:…' / 'aid:…';
  /// surfaces without ids stay null and fall back to a normalized-title
  /// identity inside the evaluator. Never leaves the process: toContext()
  /// and _boundedContext keep the upstream payload free of any id (issue
  /// #34).
  final String? localKey;

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

  /// At least one slot was answered (by the provider or by the verdict
  /// cache); decisions reflect only those answers.
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
  /// A repeat visit answered entirely from the verdict cache reports 0
  /// (issue #123).
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
///
/// Issue #123 layers a configurable verdict cache under the batches:
/// definite decisions are remembered per policy generation and answered
/// locally on repeat visits, so the same video no longer re-posts to the
/// provider. Uncertain outcomes (timeouts, transport errors, malformed
/// payloads, low-confidence keeps) are never cached, keeping fail-open
/// semantics intact.
class JevEvaluator {
  JevEvaluator({
    JevTransport? transport,
    JevCredentialStore? credentials,
    JevSettingsStore? settings,
    JevPreferenceStore? preferences,
    JevRuleStore? rules,
    JevVerdictCache? verdictCache,
  }) : _transport = transport ?? JevHttpTransport().call,
       _credentials = credentials ?? SecureJevCredentialStore(),
       _settings = settings ?? JevSettingsStore(),
       _preferences = preferences ?? JevPreferenceStore(box: settings?.box),
       _rules = rules ?? JevRuleStore(box: settings?.box),
       _verdictCache = verdictCache ?? JevVerdictCache(box: settings?.box);

  final JevTransport _transport;
  final JevCredentialStore _credentials;
  final JevSettingsStore _settings;
  final JevPreferenceStore _preferences;
  final JevRuleStore _rules;
  final JevVerdictCache _verdictCache;

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

    // Issue #123: the verdict cache answers definite decisions locally so a
    // repeat visit sends zero provider requests. The comment face stays out
    // of scope this round (issue #124); a config-read failure keeps today's
    // behavior (no cache).
    final cacheEnabled = _cacheEnabled(surface);
    final generation = cacheEnabled
        ? _generationKey(
            provider: provider,
            model: settings.modelFor(provider),
            builtin: builtin,
            activeRules: activeRules,
            state: state,
            surface: surface,
          )
        : null;

    // Cache identity per slot; served slots are answered locally.
    final identities = List<String?>.filled(candidates.length, null);
    final served = List<bool>.filled(candidates.length, false);
    var answeredSlots = 0;
    if (cacheEnabled) {
      for (var i = 0; i < candidates.length; i++) {
        final identity = _cacheIdentity(candidates[i]);
        identities[i] = identity;
        if (identity == null) continue;
        final verdict = _verdictCache.lookup(generation!, identity);
        if (verdict == null) continue;
        hidden[i] = verdict;
        served[i] = true;
        answeredSlots++;
      }
    }

    // Group the unserved slots. Slots sharing a cache identity share one
    // batch position (aliases of the same video); slots without an identity
    // keep one position each, so the cache-off path batches exactly like
    // before this feature existed.
    final groups = <_JevSendGroup>[];
    final byIdentity = <String, _JevSendGroup>{};
    final waiters = <Future<void>>[];
    for (var i = 0; i < candidates.length; i++) {
      if (served[i]) continue;
      final identity = identities[i];
      if (identity == null) {
        groups.add(_JevSendGroup(<int>[i]));
        continue;
      }
      // A concurrent pass may already be judging the same identity: attach
      // instead of sending twice (single-flight, tag-store precedent).
      final external = _verdictCache.inFlightFuture(generation!, identity);
      if (external != null) {
        final slot = i;
        waiters.add(external.then((verdict) {
          if (verdict != null) {
            hidden[slot] = verdict;
            answeredSlots++;
          }
        }));
        continue;
      }
      final existing = byIdentity[identity];
      if (existing != null) {
        existing.slots.add(i);
      } else {
        final group = _JevSendGroup(<int>[i], identity: identity);
        byIdentity[identity] = group;
        groups.add(group);
      }
    }

    // Register in-flight completers before the first await (tag-store
    // precedent: registration must precede the load, or a synchronous throw
    // would leave a dead entry).
    for (final group in groups) {
      if (group.identity == null) continue;
      final completer = Completer<bool?>();
      if (_verdictCache.registerInFlight(
        generation!,
        group.identity!,
        completer,
      )) {
        group.completer = completer;
      }
    }

    var requests = 0;
    for (
      var start = 0;
      start < groups.length;
      start += JevLimits.batchSize
    ) {
      final end = math.min(start + JevLimits.batchSize, groups.length);
      final chunk = groups.sublist(start, end);
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
                for (var p = 0; p < chunk.length; p++)
                  JevRequest.candidateKey(p): _boundedContext(
                    candidates[chunk[p].slots.first],
                  ),
              },
            },
            questions: <String, Map<String, Object?>>{
              for (var p = 0; p < chunk.length; p++) ...{
                if (builtin)
                  JevRequest.candidateKey(p): JevRequest.question(
                    candidateKey: JevRequest.candidateKey(p),
                  ),
                for (var r = 0; r < activeRules.length; r++) ...{
                  _ruleKey(p, r): activeRules[r].compile(
                    JevRequest.candidateKey(p),
                  ),
                  '${_ruleKey(p, r)}_context': _contextQuestion(
                    activeRules[r],
                    JevRequest.candidateKey(p),
                  ),
                },
              },
            },
          ),
        );
        if (data is! Map || data['answers'] is! Map) {
          _completeChunk(chunk);
          continue;
        }
        final rawAnswers = data['answers'] as Map;
        if (rawAnswers.isEmpty) {
          _completeChunk(chunk);
          continue;
        }
        final answers = JevAnswer.parseAll(data);
        // Structurally answered chunk: every slot in it counts toward the
        // status, exactly like the original per-batch answeredBatches.
        for (final group in chunk) {
          answeredSlots += group.slots.length;
        }
        for (var p = 0; p < chunk.length; p++) {
          final group = chunk[p];
          final first = group.slots.first;
          if (candidates[first].title.trim().isEmpty) {
            // Sent for context but never judged; keep visible.
            group.complete(null);
            continue;
          }
          final (hide, definite) = _decide(
            rawAnswers: rawAnswers,
            answers: answers,
            position: p,
            builtin: builtin,
            activeRules: activeRules,
          );
          if (hide) {
            for (final slot in group.slots) {
              hidden[slot] = true;
            }
          }
          // Only definite decisions enter the cache and reach concurrent
          // waiters; aliases share the identity, so one put covers the
          // whole group.
          final cacheable = definite && group.identity != null;
          if (cacheable) {
            _verdictCache.put(generation!, group.identity!, hide: hide);
          }
          group.complete(cacheable ? hide : null);
        }
      } catch (_) {
        // Fail-open: this whole chunk stays visible (issue #36).
        _completeChunk(chunk);
      }
    }

    // Concurrent same-identity passes land their verdicts here; release our
    // own registrations now that every completer has a verdict.
    if (waiters.isNotEmpty) {
      await Future.wait(waiters);
    }
    if (cacheEnabled) {
      for (final group in groups) {
        if (group.identity != null && group.completer != null) {
          _verdictCache.releaseInFlight(generation!, group.identity!);
        }
      }
    }

    return JevScreening(
      status: answeredSlots > 0
          ? JevScreenStatus.evaluated
          : JevScreenStatus.providerUnavailable,
      hidden: List<bool>.unmodifiable(hidden),
      requests: requests,
    );
  }

  /// The comment face stays uncached this round (issue #124). A storage
  /// failure while reading the config keeps today's behavior (no cache).
  bool _cacheEnabled(JevSurface surface) {
    if (surface == JevSurface.comment) return false;
    try {
      return _verdictCache.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Cache identity (issue #123): the caller-supplied stable card id when
  /// present, otherwise a normalized-title fallback (trim, collapse inner
  /// whitespace, lowercase). Empty titles are never cacheable. Local-only:
  /// never serialized into an upstream request (issue #34).
  static String? _cacheIdentity(JevCandidate candidate) {
    final localKey = candidate.localKey?.trim();
    if (localKey != null && localKey.isNotEmpty) {
      return 'id:$localKey';
    }
    final title = candidate.title.trim();
    if (title.isEmpty) return null;
    return 't:${title.replaceAll(_whitespace, ' ').toLowerCase()}';
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Policy generation key (issue #123): any change to provider, model,
  /// builtin switch, the active rule set, or the negative-feedback profile
  /// starts a fresh generation and voids every cached verdict. The surface
  /// id participates only while custom rules are active - mirroring the
  /// request body, which carries 'surface' only in that case.
  static String _generationKey({
    required JevProvider provider,
    required String model,
    required bool builtin,
    required List<JevRule> activeRules,
    required Object? state,
    required JevSurface surface,
  }) => jsonEncode(<Object?>[
    'jev-verdict.v1',
    provider.id,
    model,
    builtin,
    activeRules.isEmpty ? null : surface.id,
    state,
    <Object?>[for (final rule in activeRules) rule.toJson()],
  ]);

  /// One candidate's final verdict: (hide, definite). definite means the
  /// answer is well-formed enough to cache (issue #123) and to hand to
  /// concurrent waiters; hide always implies definite.
  static (bool, bool) _decide({
    required Map rawAnswers,
    required Map<String, JevAnswer>? answers,
    required int position,
    required bool builtin,
    required List<JevRule> activeRules,
  }) {
    final key = JevRequest.candidateKey(position);
    final answer = builtin && answers != null ? answers[key] : null;
    final lowConfidence =
        answer?.confidence != null &&
        (!answer!.confidence!.isFinite ||
            answer.confidence! < JevLimits.minReportedConfidence ||
            answer.confidence! > 1);
    final rawBuiltin = rawAnswers[key];
    if (answer?.noul != null &&
        answer!.noul!.isFinite &&
        answer.noul! <= 1 &&
        (rawBuiltin is Map &&
            (rawBuiltin['type'] == null ||
                rawBuiltin['type'] == 'noul')) &&
        !lowConfidence &&
        answer.noul! >= JevLimits.hideNoulThreshold) {
      return (true, true);
    }
    var definite = true;
    if (builtin) {
      // A builtin "keep" is only definite when the answer is well-formed and
      // not low-confidence; anything else keeps the candidate visible but
      // must never poison the cache.
      if (answer == null ||
          answer.noul == null ||
          !answer.noul!.isFinite ||
          answer.noul! > 1 ||
          !(rawBuiltin is Map &&
              (rawBuiltin['type'] == null ||
                  rawBuiltin['type'] == 'noul')) ||
          lowConfidence) {
        definite = false;
      }
    }
    for (var r = 0; r < activeRules.length; r++) {
      // Asking for No must never equate missing evidence with a confident No.
      final sufficient = rawAnswers['${_ruleKey(position, r)}_context'];
      final p = sufficient is Map ? sufficient['noul'] : null;
      if (sufficient is! Map ||
          sufficient['type'] != 'noul' ||
          p is! num ||
          !p.isFinite ||
          p < .95 ||
          p > 1) {
        definite = false;
        continue;
      }
      if (activeRules[r].hides(rawAnswers[_ruleKey(position, r)])) {
        return (true, true);
      }
    }
    return (false, definite);
  }

  static void _completeChunk(List<_JevSendGroup> chunk) {
    for (final group in chunk) {
      group.complete(null);
    }
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

/// One batch position within a screening pass. The first slot's candidate is
/// sent; extra slots are cache-identity aliases sharing the same verdict.
class _JevSendGroup {
  _JevSendGroup(this.slots, {this.identity});

  final List<int> slots;

  /// Non-null only when the group's identity is cacheable.
  final String? identity;
  Completer<bool?>? completer;

  void complete(bool? verdict) {
    final completer = this.completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(verdict);
    }
  }
}
