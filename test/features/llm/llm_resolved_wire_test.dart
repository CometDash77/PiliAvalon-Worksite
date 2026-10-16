import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/features/jev/jev_contract.dart' show JevSettingsBox;
import 'package:PiliPlus/features/llm/llm.dart';
import 'package:PiliPlus/features/llm/llm_http_probe.dart';
import 'package:PiliPlus/features/llm/llm_model_catalog.dart';
import 'package:PiliPlus/features/llm/llm_provider_presets.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);
  final List<MapEntry<int, Object?>> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final next = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(next.value),
      next.key,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeBox implements JevSettingsBox {
  final map = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) => map[key] ?? defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

LlmResolvedProvider _resolved(
  String presetId, {
  LlmRouteProtocol? protocol,
  String baseUrl = '',
  bool? includesV1Override,
  LlmPresetAuth? authOverride,
  String model = 'm1',
}) {
  final preset = kLlmProviderPresets.firstWhere((p) => p.id == presetId);
  return LlmResolvedProvider(
    preset: preset,
    account: LlmProviderAccount(
      providerId: preset.id,
      protocol: protocol,
      baseUrl: baseUrl,
      includesV1Override: includesV1Override,
      authOverride: authOverride,
      model: model,
    ),
  );
}

void main() {
  group('llmLegacyMappingFor', () {
    test('openrouter default route maps to the versioned openai base', () async {
      final mapping = llmLegacyMappingFor(
        _resolved('openrouter', model: 'm/or'),
        confirmed: true,
      );
      expect(mapping.error, isNull);
      final config = mapping.config!;
      expect(config.protocol, LlmProtocol.openAICompatible);
      expect(config.baseUrl, 'https://openrouter.ai/api/v1');
      expect(config.model, 'm/or');
      expect(config.confirmed, isTrue);
      expect(config.bearerAuth, isFalse);
    });

    test('deepseek anthropic route maps with bearerAuth set', () async {
      final mapping = llmLegacyMappingFor(
        _resolved('deepseek', protocol: LlmRouteProtocol.anthropicMessages),
      );
      expect(mapping.error, isNull);
      final config = mapping.config!;
      expect(config.protocol, LlmProtocol.anthropicCompatible);
      expect(config.baseUrl, 'https://api.deepseek.com/anthropic');
      expect(config.bearerAuth, isTrue);
    });

    test('anthropic native auth drops bearerAuth', () async {
      final mapping = llmLegacyMappingFor(_resolved(
        'deepseek',
        protocol: LlmRouteProtocol.anthropicMessages,
        authOverride: LlmPresetAuth.anthropicNative,
      ));
      expect(mapping.error, isNull);
      expect(mapping.config!.bearerAuth, isFalse);
    });

    test('zen openai route maps to the openai subpath', () async {
      final mapping = llmLegacyMappingFor(_resolved('opencode-zen'));
      expect(mapping.error, isNull);
      expect(
        mapping.config!.baseUrl,
        'https://opencode.ai/inference/openai/v1',
      );
    });

    test('non-screenable routes refuse with the preset error', () async {
      final mapping = llmLegacyMappingFor(_resolved(
        'opencode-zen',
        protocol: LlmRouteProtocol.openaiResponses,
      ));
      expect(mapping.config, isNull);
      expect(mapping.error, LlmPresetIssue.routeNotScreenable.message);
    });

    test('custom openai endpoint without /v1 maps verbatim', () async {
      final mapping = llmLegacyMappingFor(_resolved(
        'custom-openai',
        baseUrl: 'https://x.example/api',
        includesV1Override: false,
      ));
      expect(mapping.error, isNull);
      expect(mapping.config!.baseUrl, 'https://x.example/api');
    });

    test('custom anthropic endpoint keeps bearerAuth under bearer', () async {
      final mapping = llmLegacyMappingFor(
        _resolved('custom-anthropic', baseUrl: 'https://x.example'),
      );
      expect(mapping.error, isNull);
      final config = mapping.config!;
      expect(config.protocol, LlmProtocol.anthropicCompatible);
      expect(config.baseUrl, 'https://x.example/v1');
      expect(config.bearerAuth, isTrue);
    });

    test('an openai route with anthropic auth refuses', () async {
      final mapping = llmLegacyMappingFor(_resolved(
        'deepseek',
        protocol: LlmRouteProtocol.openaiChat,
        authOverride: LlmPresetAuth.anthropicNative,
      ));
      expect(mapping.config, isNull);
      expect(mapping.error, contains('鉴权方式'));
    });

    test('model ids with special characters survive verbatim', () async {
      final mapping = llmLegacyMappingFor(
        _resolved('openrouter', model: '~/a b/c'),
      );
      expect(mapping.error, isNull);
      expect(mapping.config!.model, '~/a b/c');
    });
  });

  group('loadResolved', () {
    test('openai-shaped catalog hits the catalog endpoint with bearer', () async {
      final resolved = _resolved('deepseek');
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'data': [
            {'id': 'deepseek-chat'},
            {'id': 'deepseek-reasoner'},
          ],
        }),
      ]);
      final catalog = LlmModelCatalog(dio: Dio()..httpClientAdapter = adapter);
      final result = await catalog.loadResolved(resolved: resolved, apiKey: 'k');
      expect(result.error, isNull);
      expect(result.models, ['deepseek-chat', 'deepseek-reasoner']);
      expect(adapter.requests.single.uri.toString(), resolved.catalogEndpoint);
      expect(adapter.requests.single.headers['authorization'], 'Bearer k');
    });

    test('dashscope pages follow pagination until total is covered', () async {
      final resolved = _resolved('aliyun-bailian', model: 'qwen-max');
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'data': [
            {'id': 'qwen-a'},
          ],
          'page_no': 1,
          'page_size': 100,
          'total': 2,
        }),
        const MapEntry(200, {
          'data': [
            {'id': 'qwen-b'},
          ],
          'page_no': 2,
          'page_size': 100,
          'total': 2,
        }),
      ]);
      final catalog = LlmModelCatalog(dio: Dio()..httpClientAdapter = adapter);
      final result = await catalog.loadResolved(resolved: resolved, apiKey: 'k');
      expect(result.error, isNull);
      expect(result.models, ['qwen-a', 'qwen-b']);
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.uri.toString(),
        'https://dashscope.aliyuncs.com/api/v1/models?page_no=1&page_size=100',
      );
      expect(adapter.requests.last.uri.queryParameters['page_no'], '2');
    });

    test('shape none never issues a request', () async {
      final adapter = _QueueAdapter([]);
      final catalog = LlmModelCatalog(dio: Dio()..httpClientAdapter = adapter);
      final result = await catalog.loadResolved(
        resolved: _resolved('xiaomimimo'),
        apiKey: 'k',
      );
      expect(result.models, isEmpty);
      expect(result.error, LlmPresetIssue.catalogUnavailable.message);
      expect(adapter.requests, isEmpty);
    });

    test('anonymous providers send no auth header', () async {
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'data': [
            {'id': 'kimi-k2'},
          ],
        }),
      ]);
      final catalog = LlmModelCatalog(dio: Dio()..httpClientAdapter = adapter);
      final result = await catalog.loadResolved(
        resolved: _resolved('opencode-zen'),
        apiKey: '',
      );
      expect(result.error, isNull);
      expect(result.models, ['kimi-k2']);
      expect(
        adapter.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });
  });

  group('callResolved', () {
    test('ok probe hits the saved chat endpoint', () async {
      final resolved = _resolved('deepseek', model: 'm1');
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'choices': [
            {
              'message': {'content': 'OK'},
            },
          ],
        }),
      ]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(resolved: resolved, apiKey: 'k');
      expect(result.outcome, LlmProbeOutcome.ok);
      expect(result.detail, isNull);
      final request = adapter.requests.single;
      expect(request.uri.toString(), resolved.chatEndpoint);
      expect(request.headers['authorization'], 'Bearer k');
      expect((request.data as Map)['model'], 'm1');
    });

    test('anthropic route probes messages with bearer auth', () async {
      final resolved = _resolved(
        'deepseek',
        protocol: LlmRouteProtocol.anthropicMessages,
        model: 'm1',
      );
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'content': [
            {'type': 'text', 'text': 'OK'},
          ],
        }),
      ]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(resolved: resolved, apiKey: 'k');
      expect(result.outcome, LlmProbeOutcome.ok);
      final request = adapter.requests.single;
      expect(request.headers['authorization'], 'Bearer k');
      expect(request.headers.containsKey('x-api-key'), isFalse);
      final body = request.data as Map;
      expect(body['max_tokens'], 16);
      expect(body.containsKey('stream'), isFalse);
    });

    test('non-screenable routes are blocked without a request', () async {
      final adapter = _QueueAdapter([]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(
        resolved: _resolved(
          'opencode-zen',
          protocol: LlmRouteProtocol.openaiResponses,
        ),
        apiKey: 'k',
      );
      expect(result.outcome, isNull);
      expect(result.detail, LlmPresetIssue.routeNotScreenable.message);
      expect(adapter.requests, isEmpty);
    });

    test('a missing model blocks the probe', () async {
      final adapter = _QueueAdapter([]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(
        resolved: _resolved('deepseek', model: ''),
        apiKey: 'k',
      );
      expect(result.outcome, isNull);
      expect(result.detail, LlmPresetIssue.missingModel.message);
      expect(adapter.requests, isEmpty);
    });

    test('401 maps to invalid key', () async {
      final adapter = _QueueAdapter([
        const MapEntry(401, {
          'error': {'message': 'bad key'},
        }),
      ]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(
        resolved: _resolved('deepseek'),
        apiKey: 'wrong',
      );
      expect(result.outcome, LlmProbeOutcome.invalidKey);
      expect(result.detail, contains('401'));
    });

    test('thinking fields ride the openai probe body (#176)', () async {
      final resolved = _resolved('deepseek', model: 'm1');
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'choices': [
            {
              'message': {'content': 'OK'},
            },
          ],
        }),
      ]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(
        resolved: resolved,
        apiKey: 'k',
        thinkingFields: const {
          'thinking': {'type': 'enabled'},
          'reasoning_effort': 'high',
        },
      );
      expect(result.outcome, LlmProbeOutcome.ok);
      final body = adapter.requests.single.data as Map;
      expect((body['thinking'] as Map)['type'], 'enabled');
      expect(body['reasoning_effort'], 'high');
    });

    test('thinking fields ride the anthropic probe body (#176)', () async {
      final resolved = _resolved(
        'deepseek',
        protocol: LlmRouteProtocol.anthropicMessages,
        model: 'm1',
      );
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'content': [
            {'type': 'text', 'text': 'OK'},
          ],
        }),
      ]);
      final probe = LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter);
      final result = await probe.callResolved(
        resolved: resolved,
        apiKey: 'k',
        thinkingFields: const {
          'output_config': {'effort': 'low'},
        },
      );
      expect(result.outcome, LlmProbeOutcome.ok);
      final body = adapter.requests.single.data as Map;
      expect((body['output_config'] as Map)['effort'], 'low');
    });
  });

  group('bearerAuth persistence', () {
    test('bearerAuth round-trips through the v1 store', () async {
      final store = LlmSettingsStore(box: _FakeBox());
      const config = LlmProviderConfig(
        protocol: LlmProtocol.anthropicCompatible,
        baseUrl: 'https://x.example/v1',
        model: 'm1',
        confirmed: true,
        bearerAuth: true,
      );
      await store.save(config);
      LlmSettingsStore.resetCache();
      final loaded = await store.load();
      expect(loaded.bearerAuth, isTrue);
      expect(loaded.authHeaders('k'), {
        'authorization': 'Bearer k',
      });
      expect(LlmSettingsStore.snapshot.bearerAuth, isTrue);
    });

    test('plain anthropic configs keep the native headers', () {
      const config = LlmProviderConfig(
        protocol: LlmProtocol.anthropicCompatible,
        baseUrl: 'https://x.example',
        model: 'm1',
      );
      expect(config.authHeaders('k'), {
        'x-api-key': 'k',
        'anthropic-version': '2023-06-01',
      });
    });
  });
}