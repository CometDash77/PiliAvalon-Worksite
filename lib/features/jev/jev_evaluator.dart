import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:PiliPlus/features/jev/jev_models.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

const jevRecommendationQuestion =
    '这条推荐的核心内容，是否与用户明确不喜欢的主题存在足够强的语义匹配，以至于应在展示前屏蔽？只有负面主题实质上属于候选的核心内容时才回答是；偶然提及、泛化标签或仅共享单一元素均为弱关联，应回答否。';

/// OpenRouter-side pinned model id (issue #101: `typesafe/jev-1.13` does not
/// exist upstream; the maintainer pinned `typesafe/jev-latest`).
const jevModelId = 'typesafe/jev-latest';

/// TypeSafe direct-call pinned model id: the documented alias (issue #101).
const typeSafeModelId = 'jev-latest';

/// Extracts a short upstream error summary (status + message) from one failed
/// provider response, for user-facing validation copy (issue #101). Returns
/// null when nothing presentable exists so callers fall back to generic copy.
String? jevUpstreamErrorDetail(int? statusCode, Object? responseData) {
  final message = switch (responseData) {
    final Map data => _upstreamMessageFromMap(data),
    final String text => text.trim(),
    _ => null,
  };
  final summary = (message == null || message.isEmpty) ? null : _truncateUpstream(message);
  if (summary == null) return statusCode == null ? null : 'HTTP $statusCode';
  return statusCode == null ? summary : 'HTTP $statusCode：$summary';
}

String? _upstreamMessageFromMap(Map data) {
  final error = data['error'];
  if (error is Map) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  for (final key in const ['message', 'detail', 'error']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _truncateUpstream(String text) {
  final runes = text.runes.toList();
  if (runes.length <= 200) return text;
  return '${String.fromCharCodes(runes.take(200))}…';
}

class JevDecision {
  const JevDecision({required this.hideProbability});
  final double hideProbability;
}

abstract interface class JevBatchEvaluator {
  Future<Map<int, JevDecision>> evaluate({
    required JevProvider provider,
    required String key,
    required List<JevCandidate> candidates,
    required List<Map<String, Object?>> negativeThemes,
    required Duration timeout,
  });
}

class JevHttpEvaluator implements JevBatchEvaluator {
  JevHttpEvaluator({Dio? dio}) : _dio = dio ?? _createIsolatedDio();
  final Dio _dio;

  static const typeSafeEndpoint = 'https://api.typesafe.ai/v1/systemone';
  static const openRouterEndpoint = 'https://openrouter.ai/api/alpha/decisions';

  static Dio _createIsolatedDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
    ));
    final proxyHost = Pref.systemProxyHost;
    final proxyPort = int.tryParse(Pref.systemProxyPort);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..findProxy = Pref.enableSystemProxy && proxyPort != null && proxyHost.isNotEmpty
            ? (_) => 'PROXY $proxyHost:$proxyPort'
            : null,
    );
    return dio;
  }

  @override
  Future<Map<int, JevDecision>> evaluate({
    required JevProvider provider,
    required String key,
    required List<JevCandidate> candidates,
    required List<Map<String, Object?>> negativeThemes,
    required Duration timeout,
  }) async {
    if (key.trim().isEmpty || candidates.isEmpty) return const {};
    final questions = <String, Object?>{};
    final candidateState = <String, Object?>{};
    for (var index = 0; index < candidates.length; index++) {
      final questionId = 'candidate_$index';
      candidateState[questionId] = candidates[index].toProviderJson();
      questions[questionId] = {
        'type': 'noul',
        'instructions': '$jevRecommendationQuestion 评估 state.candidates.$questionId。',
        'criteria': {
          'true': '负面主题实质上属于候选核心内容，应在展示前隐藏',
          'false': '关联弱、偶然提及或并非核心内容，保留候选',
        },
      };
    }
    final body = {
      'state': {
        'negative_themes': negativeThemes.take(20).toList(growable: false),
        'candidates': candidateState,
      },
      'model': provider == JevProvider.typeSafe ? typeSafeModelId : jevModelId,
      'questions': questions,
    };
    final endpoint = provider == JevProvider.typeSafe
        ? typeSafeEndpoint
        : openRouterEndpoint;
    final response = await _dio
        .post<Object?>(
          endpoint,
          data: body,
          options: Options(
            headers: {'Authorization': 'Bearer ${key.trim()}'},
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            receiveDataWhenStatusError: false,
          ),
        )
        .timeout(timeout);
    final payload = response.data;
    if (payload is! Map || payload['answers'] is! Map) return const {};
    final answers = payload['answers'] as Map;
    final result = <int, JevDecision>{};
    for (var index = 0; index < candidates.length; index++) {
      final answer = answers['candidate_$index'];
      if (answer is! Map || answer['type'] != 'noul') continue;
      final probability = answer['noul'];
      if (probability is num && probability >= 0 && probability <= 1) {
        result[index] = JevDecision(hideProbability: probability.toDouble());
      }
    }
    return result;
  }
}

class JevRecommendationPipeline {
  JevRecommendationPipeline({
    required this.evaluator,
    required this.loadKey,
    this.timeout = const Duration(seconds: 8),
  });

  final JevBatchEvaluator evaluator;
  final Future<String?> Function(JevProvider provider) loadKey;
  final Duration timeout;

  Future<List<T>> filter<T>({
    required List<T> candidates,
    required JevSettings settings,
    required JevSurface surface,
    required List<Map<String, Object?>> negativeThemes,
    required JevCandidate Function(T item) toJevCandidate,
    required List<T> Function(List<T> input) runLowerCostFilters,
  }) async {
    final survivors = runLowerCostFilters(candidates);
    final provider = settings.provider;
    if (!settings.enabledFor(surface) || provider == null ||
        negativeThemes.isEmpty || survivors.isEmpty) return survivors;

    String? key;
    try {
      key = await loadKey(provider);
    } catch (_) {
      return survivors;
    }
    if (key == null || key.trim().isEmpty) return survivors;
    final batchSize = settings.batchSize.clamp(1, 5).toInt();
    final hidden = <int>{};
    final totalDeadline = Stopwatch()..start();
    for (var start = 0; start < survivors.length; start += batchSize) {
      final remaining = timeout - totalDeadline.elapsed;
      if (remaining <= Duration.zero) break;
      final end = (start + batchSize).clamp(0, survivors.length);
      final batch = survivors.sublist(start, end);
      try {
        final decisions = await evaluator
            .evaluate(
              provider: provider,
              key: key,
              candidates: batch.map(toJevCandidate).toList(growable: false),
              negativeThemes: negativeThemes,
              timeout: remaining,
            )
            .timeout(remaining);
        for (final entry in decisions.entries) {
          if (entry.key >= 0 && entry.key < batch.length &&
              entry.value.hideProbability >= settings.hideThreshold) {
            hidden.add(start + entry.key);
          }
        }
      } catch (_) {
        // Missing, invalid, weak, timed-out, throttled, or failed results fail open.
      }
    }
    return [for (var index = 0; index < survivors.length; index++) if (!hidden.contains(index)) survivors[index]];
  }
}
