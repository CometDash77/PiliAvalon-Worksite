import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_feedback_profile.dart';
import 'package:PiliPlus/features/jev/jev_models.dart';
import 'package:PiliPlus/features/jev/jev_secure_key_store.dart';
import 'package:PiliPlus/features/jev/jev_settings_store.dart';
import 'package:PiliPlus/pages/jev_settings/view.dart';

void main() {
  group('JevSettings', () {
    test(
      'requires an explicit provider and keeps surface switches separate',
      () {
        const initial = JevSettings(enabled: true);
        expect(initial.enabledFor(JevSurface.homeApp), isFalse);
        final configured = initial
            .copyWith(provider: JevProvider.openRouter)
            .copyWith(
              surfaceEnabled: const {JevSurface.hot: false},
            );
        expect(configured.enabledFor(JevSurface.homeWeb), isTrue);
        expect(configured.enabledFor(JevSurface.hot), isFalse);
        expect(configured.provider, JevProvider.openRouter);
        for (final surface in JevSurface.values) {
          expect(
            configured.enabledFor(surface),
            surface != JevSurface.hot && surface != JevSurface.live,
          );
        }
      },
    );

    test(
      'keeps an unwired live surface disabled even when stored as enabled',
      () {
        const settings = JevSettings(
          enabled: true,
          provider: JevProvider.typeSafe,
          surfaceEnabled: {JevSurface.live: true},
        );

        expect(settings.enabledFor(JevSurface.live), isFalse);
      },
    );

    test('persists settings without storing provider credentials', () async {
      final box = _MemorySettingsBox();
      final store = JevSettingsStore(box: box);
      final settings = const JevSettings(
        enabled: true,
        provider: JevProvider.openRouter,
        surfaceEnabled: {JevSurface.music: false},
      );
      await store.save(settings);
      expect(store.load().enabledFor(JevSurface.homeWeb), isTrue);
      expect(store.load().enabledFor(JevSurface.music), isFalse);
      expect(box.values.keys, {JevSettingsStore.settingsKey});
      expect(box.values.values.single.toString(), isNot(contains('key')));
    });

    test('round trip clamps invalid threshold and batch sizes', () {
      final decoded = JevSettings.fromJson({
        'enabled': true,
        'provider': 'typeSafe',
        'hideThreshold': 1.5,
        'batchSize': 50,
      });
      expect(decoded.hideThreshold, 0.95);
      expect(decoded.batchSize, 3);
      expect(decoded.provider, JevProvider.typeSafe);
    });
  });

  group('JevCredentialStore', () {
    test('uses its injected secure store, writes only the credential slot and deletes it', () async {
      final backend = _MemorySecrets();
      final store = JevCredentialStore(backend);
      await store.save(
        provider: JevProvider.openRouter,
        value: 'user-supplied-test-key',
      );
      expect(backend.values.keys, {
        JevCredentialStore.keyNameFor(JevProvider.openRouter),
      });
      expect(
        await store.read(JevProvider.openRouter),
        'user-supplied-test-key',
      );
      expect(await store.read(JevProvider.typeSafe), isNull);
      await store.delete(JevProvider.openRouter);
      expect(
        backend.values.containsKey(
          JevCredentialStore.keyNameFor(JevProvider.openRouter),
        ),
        isFalse,
      );
    });

    test('refuses to save when secure storage probe fails', () async {
      final store = JevCredentialStore(_MemorySecrets(fail: true));
      await expectLater(
        store.save(provider: JevProvider.typeSafe, value: 'key'),
        throwsStateError,
      );
    });
  });

  group('JevFeedbackProfile', () {
    test(
      'pauses collection while Jev is disabled and retains themes for resume',
      () async {
        final box = _MemoryProfileBox();
        final profile = JevFeedbackProfile(
          box,
          clock: () => DateTime.utc(2026, 10, 2),
        );
        await profile.recordExplicitDislike(
          jevEnabled: true,
          displayedReason: '根据你的兴趣推荐',
          selectedReason: '旅行攻略',
          at: DateTime.utc(2026, 10, 1),
        );
        final before = profile.load();
        await profile.recordExplicitDislike(
          jevEnabled: false,
          selectedReason: '不应收集的内容',
          at: DateTime.utc(2026, 10, 2),
        );
        expect(
          profile.load().map((theme) => theme.toJson()).toList(),
          before.map((theme) => theme.toJson()).toList(),
        );
        expect(
          profile.providerSummary().every(
            (item) =>
                item.keys.toSet().containsAll({'label', 'approximate_count'}),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not store an empty dislike as a feedback theme',
      () async {
        final box = _MemoryProfileBox();
        final profile = JevFeedbackProfile(
          box,
          clock: () => DateTime.utc(2026, 10, 2),
        );

        await profile.recordExplicitDislike(
          jevEnabled: true,
          displayedReason: '!!!',
        );

        expect(profile.load(), isEmpty);
      },
    );

    test(
      'selected reason wins over displayed reason and falls back when absent',
      () async {
        final box = _MemoryProfileBox();
        final profile = JevFeedbackProfile(
          box,
          clock: () => DateTime.utc(2026, 10, 2),
        );

        await profile.recordExplicitDislike(
          jevEnabled: true,
          displayedReason: '展示主题',
          selectedReason: '选中主题',
        );
        expect(profile.load().map((theme) => theme.label), ['选中主题']);

        await profile.recordExplicitDislike(
          jevEnabled: true,
          displayedReason: '回退主题',
        );
        expect(
          profile.load().map((theme) => theme.label),
          ['回退主题', '选中主题'],
        );

        await profile.recordExplicitDislike(
          jevEnabled: true,
          displayedReason: '不应保存的展示主题',
          selectedReason: '  ',
        );
        expect(
          profile.load().map((theme) => theme.label),
          ['回退主题', '选中主题'],
        );
      },
    );

    test('expires themes, caps profile at twenty and supports individual and full deletion', () async {
      final box = _MemoryProfileBox();
      final now = DateTime.utc(2026, 10, 2);
      final profile = JevFeedbackProfile(box, clock: () => now);
      for (var index = 0; index < 22; index++) {
        await profile.recordExplicitDislike(
          jevEnabled: true,
          selectedReason: 'theme $index',
          at: now.subtract(Duration(days: index)),
        );
      }
      expect(profile.load(), hasLength(20));
      expect(profile.load().any((theme) => theme.label == 'theme 0'), isTrue);
      await profile.deleteTheme('theme 0');
      expect(profile.load().any((theme) => theme.label == 'theme 0'), isFalse);
      await profile.deleteAll();
      expect(profile.load(), isEmpty);
    });

    test('does not retain expired feedback themes', () async {
      final box = _MemoryProfileBox();
      final now = DateTime.utc(2026, 10, 2);
      final profile = JevFeedbackProfile(box, clock: () => now);
      await profile.recordExplicitDislike(
        jevEnabled: true,
        displayedReason: 'old theme',
        at: now.subtract(const Duration(days: 200)),
      );
      expect(profile.load(), isEmpty);
    });
  });

  group('JevRecommendationPipeline', () {
    test(
      'runs lower-cost filters before Jev and preserves survivor order',
      () async {
        final log = <String>[];
        final evaluator = _FakeEvaluator((candidates, _, __) {
          log.add('jev:${candidates.map((item) => item.title).join(',')}');
          return {0: const JevDecision(hideProbability: 0.96)};
        });
        final pipeline = JevRecommendationPipeline(
          evaluator: evaluator,
          loadKey: (_) async => 'key',
        );
        final output = await pipeline.filter<String>(
          candidates: const ['a', 'low-cost-blocked', 'b'],
          settings: const JevSettings(
            enabled: true,
            provider: JevProvider.typeSafe,
            batchSize: 2,
          ),
          surface: JevSurface.homeApp,
          negativeThemes: const [
            {'label': 'theme', 'approximate_count': 1},
          ],
          toJevCandidate: (item) => JevCandidate(title: item),
          runLowerCostFilters: (items) {
            log.add('deterministic');
            return items.where((item) => item != 'low-cost-blocked').toList();
          },
        );
        expect(log.first, 'deterministic');
        expect(output, ['b']);
        expect(evaluator.calls, 1);
      },
    );

    test('keeps candidates visible for missing keys, evaluator errors and disabled surfaces', () async {
      final survivors = const ['a', 'b'];
      for (final scenario in [
        (key: null, enabled: true),
        (key: 'key', enabled: true),
        (key: 'key', enabled: false),
      ]) {
        final pipeline = JevRecommendationPipeline(
          evaluator: _FakeEvaluator(
            (_, __, ___) => throw StateError('provider error'),
          ),
          loadKey: (_) async => scenario.key,
        );
        final actual = await pipeline.filter<String>(
          candidates: survivors,
          settings: JevSettings(
            enabled: scenario.enabled,
            provider: JevProvider.openRouter,
          ),
          surface: JevSurface.homeApp,
          negativeThemes: const [
            {'label': 'theme', 'approximate_count': 1},
          ],
          toJevCandidate: (item) => JevCandidate(title: item),
          runLowerCostFilters: (items) => items,
        );
        expect(actual, survivors);
      }
    });

    test(
      'keeps a batch visible when the provider times out or rate-limits',
      () async {
        final candidates = const ['a', 'b'];
        final timeoutPipeline = JevRecommendationPipeline(
          evaluator: _FakeEvaluator((_, __, ___) => const {})
              .withDelay(const Duration(milliseconds: 20)),
          loadKey: (_) async => 'key',
          timeout: const Duration(milliseconds: 1),
        );
        final providerFailurePipelines = [401, 429, 529].map(
          (status) => JevRecommendationPipeline(
            evaluator: _FakeEvaluator(
              (_, __, ___) => throw DioException(
                requestOptions: RequestOptions(path: '/decisions'),
                response: Response(
                  requestOptions: RequestOptions(path: '/decisions'),
                  statusCode: status,
                ),
              ),
            ),
            loadKey: (_) async => 'key',
          ),
        );
        for (final pipeline in [timeoutPipeline, ...providerFailurePipelines]) {
          final actual = await pipeline.filter<String>(
            candidates: candidates,
            settings: const JevSettings(
              enabled: true,
              provider: JevProvider.typeSafe,
            ),
            surface: JevSurface.homeApp,
            negativeThemes: const [
              {'label': 'theme', 'approximate_count': 1},
            ],
            toJevCandidate: (item) => JevCandidate(title: item),
            runLowerCostFilters: (items) => items,
          );
          expect(actual, candidates);
        }
      },
    );

    test('keeps candidates visible when secure-store access throws', () async {
      final pipeline = JevRecommendationPipeline(
        evaluator: _FakeEvaluator(
          (_, __, ___) => throw StateError('must not be called'),
        ),
        loadKey: (_) async => throw StateError('secure store unavailable'),
      );
      final candidates = const ['a'];
      final actual = await pipeline.filter<String>(
        candidates: candidates,
        settings: const JevSettings(
          enabled: true,
          provider: JevProvider.typeSafe,
        ),
        surface: JevSurface.homeApp,
        negativeThemes: const [
          {'label': 'theme', 'approximate_count': 1},
        ],
        toJevCandidate: (item) => JevCandidate(title: item),
        runLowerCostFilters: (items) => items,
      );
      expect(actual, candidates);
    });

    test('low-probability, absent and invalid answers fail open', () async {
      final pipeline = JevRecommendationPipeline(
        evaluator: _FakeEvaluator(
          (_, __, ___) => {
            0: const JevDecision(hideProbability: 0.949),
            1: const JevDecision(hideProbability: double.nan),
          },
        ),
        loadKey: (_) async => 'key',
      );
      final actual = await pipeline.filter<String>(
        candidates: const ['a', 'b', 'c'],
        settings: const JevSettings(
          enabled: true,
          provider: JevProvider.typeSafe,
        ),
        surface: JevSurface.homeApp,
        negativeThemes: const [
          {'label': 'theme', 'approximate_count': 1},
        ],
        toJevCandidate: (item) => JevCandidate(title: item),
        runLowerCostFilters: (items) => items,
      );
      expect(actual, ['a', 'b', 'c']);
    });

    test('uses bounded batches no larger than five', () async {
      final evaluator = _FakeEvaluator((_, __, ___) => const {});
      final pipeline = JevRecommendationPipeline(
        evaluator: evaluator,
        loadKey: (_) async => 'key',
      );
      final actual = await pipeline.filter<String>(
        candidates: List.generate(12, (index) => 'candidate-$index'),
        settings: const JevSettings(
          enabled: true,
          provider: JevProvider.typeSafe,
          batchSize: 5,
        ),
        surface: JevSurface.homeApp,
        negativeThemes: const [
          {'label': 'topic', 'approximate_count': 1},
        ],
        toJevCandidate: (item) => JevCandidate(title: item),
        runLowerCostFilters: (items) => items,
      );
      expect(actual, hasLength(12));
      expect(evaluator.calls, 3);
    });
  });

  group('JevHttpEvaluator routing and privacy', () {
    test(
      'sends one pinned request only to the explicitly selected provider',
      () async {
        final dio = Dio();
        final requests = <RequestOptions>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'answers': {
                      'candidate_0': {'type': 'noul', 'noul': 0.12},
                    },
                  },
                ),
              );
            },
          ),
        );
        final evaluator = JevHttpEvaluator(dio: dio);
        for (final provider in JevProvider.values) {
          final before = requests.length;
          final decisions = await evaluator.evaluate(
            provider: provider,
            key: 'synthetic-test-key',
            candidates: const [
              JevCandidate(
                title: 'video title',
                description: 'short description',
                category: 'education',
                tags: ['language'],
              ),
            ],
            negativeThemes: const [
              {'label': 'topic', 'approximate_count': 1},
            ],
            timeout: const Duration(seconds: 1),
          );
          expect(decisions[0]?.hideProbability, 0.12);
          expect(requests.length, before + 1);
          final request = requests.last;
          expect(
            request.uri.host,
            provider == JevProvider.typeSafe
                ? 'api.typesafe.ai'
                : 'openrouter.ai',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic-test-key');
          expect(
            request.headers.keys.any((name) => name.toLowerCase() == 'cookie'),
            isFalse,
          );
          final data = request.data as Map<String, Object?>;
          expect(
            data['model'],
            provider == JevProvider.typeSafe
                ? 'jev-latest'
                : 'typesafe/jev-latest',
          );
          final state = data['state'] as Map<String, Object?>;
          final candidates = state['candidates'] as Map<String, Object?>;
          final candidate = candidates['candidate_0'] as Map<String, Object?>;
          expect(candidate.keys.toSet(), {
            'title',
            'description',
            'category',
            'tags',
          });
        }
        expect(requests, hasLength(2));
      },
    );
  });

  group('Jev upstream error detail (issue #101)', () {
    test('extracts status and message from the OpenRouter error envelope', () {
      final detail = jevUpstreamErrorDetail(401, {
        'error': {'message': 'User not found.', 'code': 401},
      });
      expect(detail, 'HTTP 401：User not found.');
    });

    test('falls back to generic copy when no status and no message exist', () {
      expect(jevUpstreamErrorDetail(null, null), isNull);
      expect(jevUpstreamErrorDetail(null, <String, Object?>{}), isNull);
      expect(jevUpstreamErrorDetail(null, ''), isNull);
    });

    test('reports a bare status when the body carries no message', () {
      expect(jevUpstreamErrorDetail(502, null), 'HTTP 502');
      expect(jevUpstreamErrorDetail(400, {'unexpected': true}), 'HTTP 400');
    });

    test('truncates very long upstream messages', () {
      final detail = jevUpstreamErrorDetail(400, {
        'error': {'message': 'x' * 500},
      });
      expect(detail, isNotNull);
      expect(detail!.runes.length, lessThanOrEqualTo(210));
      expect(detail.endsWith('…'), isTrue);
    });

    test('validation copy keeps its classification and appends the detail', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/decisions'),
        response: Response(
          requestOptions: RequestOptions(path: '/decisions'),
          statusCode: 400,
          data: {
            'error': {'message': 'No endpoint found.', 'code': 400},
          },
        ),
      );
      final message = jevValidationFailureMessage(error);
      expect(message, contains('拒绝了验证请求'));
      expect(message, contains('HTTP 400：No endpoint found.'));
      expect(message, contains('密钥不会尝试发送给其他 Provider'));
    });

    test(
      'validation copy falls back unchanged when nothing is presentable',
      () {
        final offline = DioException(
          requestOptions: RequestOptions(path: '/decisions'),
          type: DioExceptionType.connectionError,
        );
        final message = jevValidationFailureMessage(offline);
        expect(message, contains('无法连接当前 Provider'));
        expect(message, isNot(contains('上游响应')));
        expect(message, contains('密钥不会尝试发送给其他 Provider'));
      },
    );

    test('a 400 is classified as a rejected request, never as offline', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/decisions'),
        response: Response(
          requestOptions: RequestOptions(path: '/decisions'),
          statusCode: 400,
        ),
      );
      expect(jevValidationFailureMessage(error), contains('拒绝了验证请求'));
    });

    test('a real 4xx response carries the upstream message through the dio error channel', () async {
      final dio = Dio()
        ..httpClientAdapter = _StatusAdapter(
          statusCode: 400,
          body: {
            'error': {'message': 'No endpoint found.', 'code': 400},
          },
        );
      final evaluator = JevHttpEvaluator(dio: dio);
      DioException? failure;
      try {
        await evaluator.evaluate(
          provider: JevProvider.openRouter,
          key: 'synthetic-test-key',
          candidates: const [
            JevCandidate(
              title: 'video title',
              description: 'short description',
              category: 'education',
              tags: ['language'],
            ),
          ],
          negativeThemes: const [
            {'label': 'topic', 'approximate_count': 1},
          ],
          timeout: const Duration(seconds: 1),
        );
      } on DioException catch (error) {
        failure = error;
      }
      expect(failure, isNotNull);
      final message = jevValidationFailureMessage(failure!);
      expect(message, contains('拒绝了验证请求'));
      expect(message, contains('HTTP 400：No endpoint found.'));
    });
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter({required this.statusCode, this.body});

  final int statusCode;
  final Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: const {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemorySecrets implements JevSecretStorage {
  _MemorySecrets({this.fail = false});
  final bool fail;
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async {
    if (fail) throw StateError('unavailable');
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (fail) throw StateError('unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('unavailable');
    values[key] = value;
  }
}

class _MemorySettingsBox implements JevSettingsBox {
  final values = <String, Object?>{};
  @override
  Object? get(String key) => values[key];
  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }
}

class _MemoryProfileBox implements JevProfileBox {
  final values = <String, Object?>{};
  @override
  Object? get(String key) => values[key];
  @override
  Future<void> put(String key, Object? value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeEvaluator implements JevBatchEvaluator {
  _FakeEvaluator(this.callback, {this.delay = Duration.zero});
  final Map<int, JevDecision> Function(List<JevCandidate>, JevProvider, String)
  callback;
  final Duration delay;
  int calls = 0;
  _FakeEvaluator withDelay(Duration duration) =>
      _FakeEvaluator(callback, delay: duration);
  @override
  Future<Map<int, JevDecision>> evaluate({
    required JevProvider provider,
    required String key,
    required List<JevCandidate> candidates,
    required List<Map<String, Object?>> negativeThemes,
    required Duration timeout,
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return callback(candidates, provider, key);
  }
}
