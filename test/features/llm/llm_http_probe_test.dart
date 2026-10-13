import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/features/llm/llm.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses, {this.error});
  final List<MapEntry<int, Object?>> responses;
  final DioException? error;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final thrown = error;
    if (thrown != null) throw thrown;
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
  test(
    'OpenAI probe hits chat completions with the configured model',
    () async {
      final adapter = _QueueAdapter([
        const MapEntry(200, {
          'choices': [
            {
              'message': {'content': 'OK'},
            },
          ],
        }),
      ]);
      final result = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
          .call(config: _openai(), apiKey: 'k1');
      expect(result.outcome, LlmProbeOutcome.ok);
      expect(result.detail, isNull);
      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://api.example.com/v1/chat/completions',
      );
      expect(request.headers['authorization'], 'Bearer k1');
      final body = request.data as Map;
      expect(body['model'], 'm1');
      expect(body['max_tokens'], 16);
    },
  );

  test('Anthropic probe hits native messages with versioned headers', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {
        'content': [
          {'type': 'text', 'text': 'OK'},
        ],
      }),
    ]);
    final result = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: _anthropic(), apiKey: 'k2');
    expect(result.outcome, LlmProbeOutcome.ok);
    final request = adapter.requests.single;
    expect(request.uri.toString(), 'https://api.example.com/v1/messages');
    expect(request.headers['x-api-key'], 'k2');
    expect(request.headers['anthropic-version'], '2023-06-01');
    expect(request.headers.containsKey('authorization'), isFalse);
    final body = request.data as Map;
    expect(body['model'], 'm1');
    expect(body['max_tokens'], 16);
  });

  test('a 401 keeps the key verdict and quotes the upstream message', () async {
    final adapter = _QueueAdapter([
      const MapEntry(401, {
        'error': {'message': 'invalid x-api-key'},
      }),
    ]);
    final result = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: _anthropic(), apiKey: 'secret-key-123');
    expect(result.outcome, LlmProbeOutcome.invalidKey);
    expect(result.detail, 'HTTP 401：invalid x-api-key');
    expect(result.detail!.contains('secret-key-123'), isFalse);
  });

  test('a missing model gets a targeted outcome', () async {
    final adapter = _QueueAdapter([
      const MapEntry(404, {
        'error': {'message': 'Model m1 does not exist'},
      }),
    ]);
    final result = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: _openai(), apiKey: 'k');
    expect(result.outcome, LlmProbeOutcome.modelNotFound);
    expect(result.detail, 'HTTP 404：Model m1 does not exist');
  });

  test(
    'rate limits, request rejections and server errors map by status',
    () async {
      Future<LlmProbeOutcome> at(int status) async {
        final adapter = _QueueAdapter([
          MapEntry(status, {
            'error': {'message': 'x'},
          }),
        ]);
        return (await LlmHttpProbe(
              dio: Dio()..httpClientAdapter = adapter,
            ).call(config: _openai(), apiKey: 'k')).outcome
            as LlmProbeOutcome;
      }

      expect(await at(429), LlmProbeOutcome.rateLimited);
      expect(await at(400), LlmProbeOutcome.rejectedRequest);
      expect(await at(500), LlmProbeOutcome.serverError);
    },
  );

  test('a 2xx body without extractable text is malformed', () async {
    final adapter = _QueueAdapter([const MapEntry(200, <String, Object?>{})]);
    final result = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: _openai(), apiKey: 'k');
    expect(result.outcome, LlmProbeOutcome.malformedResponse);
    expect(result.detail, 'HTTP 200');
  });

  test('timeouts and network failures map without inventing details', () async {
    final timeout = _QueueAdapter(
      [const MapEntry(200, {})],
      error: DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      ),
    );
    final timedOut = await LlmHttpProbe(
      dio: Dio()..httpClientAdapter = timeout,
    ).call(config: _openai(), apiKey: 'k');
    expect(timedOut.outcome, LlmProbeOutcome.timeout);
    expect(timedOut.detail, isNull);

    final network = _QueueAdapter(
      [const MapEntry(200, {})],
      error: DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
    );
    final failed = await LlmHttpProbe(
      dio: Dio()..httpClientAdapter = network,
    ).call(config: _openai(), apiKey: 'k');
    expect(failed.outcome, LlmProbeOutcome.networkError);
  });

  test('very long upstream summaries are truncated with an ellipsis', () async {
    final adapter = _QueueAdapter([
      MapEntry(400, {
        'error': {'message': 'x' * 500},
      }),
    ]);
    final result = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: _openai(), apiKey: 'k');
    expect(result.outcome, LlmProbeOutcome.rejectedRequest);
    expect(result.detail, isNotNull);
    expect(result.detail!.runes.length, lessThanOrEqualTo(210));
    expect(result.detail!.endsWith('…'), isTrue);
  });

  test('a structurally blocked config never sends a request', () async {
    final adapter = _QueueAdapter([const MapEntry(200, {})]);

    final noModel = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(
          config: _openai().copyWith(model: ''),
          apiKey: 'k',
        );
    expect(noModel.outcome, isNull);
    expect(noModel.detail, LlmConfigIssue.missingModel.message);

    const insecure = LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'http://192.168.1.10:1234/v1',
      model: 'm1',
    );
    final blocked = await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: insecure, apiKey: 'k');
    expect(blocked.outcome, isNull);
    expect(blocked.detail, LlmConfigIssue.insecureBaseUrl.message);
    expect(adapter.requests, isEmpty);
  });

  test('an explicit model override wins over the stored one', () async {
    final adapter = _QueueAdapter([
      const MapEntry(200, {
        'choices': [
          {
            'message': {'content': 'OK'},
          },
        ],
      }),
    ]);
    await LlmHttpProbe(dio: Dio()..httpClientAdapter = adapter)
        .call(config: _openai(), apiKey: 'k', model: 'm2');
    expect((adapter.requests.single.data as Map)['model'], 'm2');
  });
}
