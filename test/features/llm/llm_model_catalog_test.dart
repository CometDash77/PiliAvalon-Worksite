import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/features/llm/llm.dart';
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

LlmProviderConfig _openai() => const LlmProviderConfig(
  protocol: LlmProtocol.openAICompatible,
  baseUrl: 'https://api.example.com/v1',
  model: 'm1',
);

LlmProviderConfig _anthropic() => const LlmProviderConfig(
  protocol: LlmProtocol.anthropicCompatible,
  baseUrl: 'https://api.example.com',
  model: 'm1',
);

void main() {
  test('OpenAI catalog reads data[].id and sends the bearer header', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {
        'data': [
          {'id': 'b-model'},
          {'id': 'a-model'},
          {'id': 'a-model'},
          {'id': '  '},
        ],
      }),
    ]);
    final result = await LlmModelCatalog(
      dio: Dio()..httpClientAdapter = adapter,
    ).load(config: _openai(), apiKey: 'k');
    expect(result.models, ['a-model', 'b-model']);
    expect(result.error, isNull);
    expect(
      adapter.requests.single.uri.toString(),
      'https://api.example.com/v1/models',
    );
    expect(adapter.requests.single.headers['authorization'], 'Bearer k');
  });

  test('Anthropic catalog follows has_more pages until exhausted', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {
        'data': [
          {'id': 'claude-b'},
          {'id': 'claude-a'},
        ],
        'has_more': true,
        'last_id': 'claude-a',
      }),
      const MapEntry(200, {
        'data': [
          {'id': 'claude-c'},
        ],
        'has_more': false,
      }),
    ]);
    final result = await LlmModelCatalog(
      dio: Dio()..httpClientAdapter = adapter,
    ).load(config: _anthropic(), apiKey: 'k');
    expect(result.models, ['claude-a', 'claude-b', 'claude-c']);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].uri.queryParameters['limit'], '1000');
    expect(adapter.requests[1].uri.queryParameters['after'], 'claude-a');
  });

  test('Anthropic pagination stops when the cursor is missing', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {
        'data': [
          {'id': 'm1'},
        ],
        'has_more': true,
      }),
    ]);
    final result = await LlmModelCatalog(
      dio: Dio()..httpClientAdapter = adapter,
    ).load(config: _anthropic(), apiKey: 'k');
    expect(result.models, ['m1']);
    expect(adapter.requests, hasLength(1));
  });

  test('error statuses and malformed bodies stay non-throwing', () async {
    final adapter = _QueueAdapter([
      const MapEntry(401, {
        'error': {'message': 'bad key'},
      }),
    ]);
    final catalog = LlmModelCatalog(dio: Dio()..httpClientAdapter = adapter);
    final failed = await catalog.load(config: _openai(), apiKey: 'k');
    expect(failed.models, isEmpty);
    expect(failed.error, isNotNull);

    adapter
      ..responses.add(const MapEntry(200, {'unexpected': 1}))
      ..responses.add(const MapEntry(200, 'not-json-map'));
    expect(
      (await catalog.load(config: _openai(), apiKey: 'k')).error,
      isNotNull,
    );
    expect(
      (await catalog.load(config: _openai(), apiKey: 'k')).error,
      isNotNull,
    );
  });

  test('a structurally blocked config never sends a request', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {'data': []}),
    ]);
    const config = LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'http://192.168.1.10:1234/v1',
    );
    final result = await LlmModelCatalog(
      dio: Dio()..httpClientAdapter = adapter,
    ).load(config: config, apiKey: 'k');
    expect(result.error, LlmConfigIssue.insecureBaseUrl.message);
    expect(adapter.requests, isEmpty);
  });

  test('the catalog does not require a model choice', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {
        'data': [
          {'id': 'm1'},
        ],
      }),
    ]);
    final result = await LlmModelCatalog(
      dio: Dio()..httpClientAdapter = adapter,
    ).load(config: _openai(), apiKey: '');
    expect(result.models, ['m1']);
  });
}
