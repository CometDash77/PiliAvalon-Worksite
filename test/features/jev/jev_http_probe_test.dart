import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.statusCode = 200, this.body, this.error});

  final int statusCode;
  final Object? body;
  final DioException? error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final error = this.error;
    if (error != null) throw error;
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

JevHttpProbe _probe({_StubAdapter? adapter}) {
  final dio = Dio()..httpClientAdapter = adapter ?? _StubAdapter();
  return JevHttpProbe(dio: dio);
}

void main() {
  test('a 401 keeps the key verdict and carries the upstream message', () async {
    final result = await _probe(
      adapter: _StubAdapter(
        statusCode: 401,
        body: {
          'error': {'message': 'User not found.', 'code': 401},
        },
      ),
    ).call(provider: JevProvider.openRouter, apiKey: 'sk-or-v1-abc');

    expect(result.outcome, JevProbeOutcome.invalidKey);
    expect(result.detail, 'HTTP 401：User not found.');
  });

  test('a 400 is a rejected request and explains the shape problem', () async {
    final result = await _probe(
      adapter: _StubAdapter(
        statusCode: 400,
        body: {
          'error': {'message': 'No endpoint found.', 'code': 400},
        },
      ),
    ).call(provider: JevProvider.openRouter, apiKey: 'sk-or-v1-abc');

    expect(result.outcome, JevProbeOutcome.rejectedRequest);
    expect(result.detail, 'HTTP 400：No endpoint found.');
  });

  test('a rate limit without a message still reports the bare status', () async {
    final result = await _probe(
      adapter: _StubAdapter(statusCode: 429, body: null),
    ).call(provider: JevProvider.openRouter, apiKey: 'sk-or-v1-abc');

    expect(result.outcome, JevProbeOutcome.rateLimited);
    expect(result.detail, 'HTTP 429');
  });

  test('an unparseable 2xx body carries a status-only summary on malformedResponse', () async {
    final result = await _probe(
      adapter: _StubAdapter(statusCode: 200, body: null),
    ).call(provider: JevProvider.openRouter, apiKey: 'sk-or-v1-abc');

    // dio json-decodes 'null' into a null body - nothing to quote.
    expect(result.outcome, JevProbeOutcome.malformedResponse);
    expect(result.detail, 'HTTP 200');
  });

  test('an accepted probe keeps detail empty', () async {
    final result = await _probe(
      adapter: _StubAdapter(statusCode: 200, body: {'answers': {}}),
    ).call(provider: JevProvider.openRouter, apiKey: 'sk-or-v1-abc');

    expect(result.outcome, JevProbeOutcome.ok);
    expect(result.detail, isNull);
  });

  test('timeouts stay timeouts without inventing a detail', () async {
    final result = await _probe(
      adapter: _StubAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/decisions'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    ).call(provider: JevProvider.openRouter, apiKey: 'sk-or-v1-abc');

    expect(result.outcome, JevProbeOutcome.timeout);
    expect(result.detail, isNull);
  });
}
