import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart'
    show JevCredentialException, JevKeyStoreStatus;
import 'package:PiliPlus/features/jev/jev_settings.dart' show JevSettingsBox;
import 'package:PiliPlus/features/llm/llm.dart';

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

class _FakeCredentials implements LlmCredentialStore {
  _FakeCredentials([Map<LlmProtocol, String>? keys]) : _keys = keys;
  Map<LlmProtocol, String>? _keys;
  bool fail = false;

  @override
  Future<JevKeyStoreStatus> status(LlmProtocol protocol) async =>
      JevKeyStoreStatus.available;

  @override
  Future<String?> read(LlmProtocol protocol) async {
    if (fail) throw const JevCredentialException('locked');
    return _keys?[protocol];
  }

  @override
  Future<void> write(LlmProtocol protocol, String apiKey) async {
    (_keys ??= {})[protocol] = apiKey;
  }

  @override
  Future<void> delete(LlmProtocol protocol) async {
    _keys?.remove(protocol);
  }
}

class _Call {
  _Call(this.endpoint, this.headers, this.body, this.timeout);
  final String endpoint;
  final Map<String, String> headers;
  final Map<String, Object?> body;
  final Duration timeout;
}

class _Stub {
  _Stub(
    this.handler,
  );
  final Future<Object?> Function(
    String endpoint,
    Map<String, String> headers,
    Map<String, Object?> body,
  )
  handler;
  final calls = <_Call>[];

  LlmChatTransport get transport =>
      ({
        required String endpoint,
        required Map<String, String> headers,
        required Map<String, Object?> body,
        required Duration timeout,
      }) {
        calls.add(_Call(endpoint, headers, body, timeout));
        return handler(endpoint, headers, body);
      };
}

Future<LlmSettingsStore> _settings(
  _FakeBox box, {
  LlmProtocol protocol = LlmProtocol.openAICompatible,
  String baseUrl = 'https://api.example.com/v1',
  String model = 'm1',
  bool confirmed = true,
}) async {
  final store = LlmSettingsStore(box: box);
  await store.save(
    LlmProviderConfig(
      protocol: protocol,
      baseUrl: baseUrl,
      model: model,
      confirmed: confirmed,
    ),
  );
  return store;
}

Map<String, Object?> _openaiOk(String content, {String finish = 'stop'}) => {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': content},
      'finish_reason': finish,
    },
  ],
};

Map<String, Object?> _anthropicOk(String text, {String stop = 'end_turn'}) => {
  'content': [
    {'type': 'text', 'text': text},
  ],
  'stop_reason': stop,
};

DioException _dio(
  int? status,
  Object? data, {
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final options = RequestOptions(path: '/chat/completions');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response<Object?>(
            requestOptions: options,
            statusCode: status,
            data: data,
          ),
  );
}

void main() {
  test('an openai call posts the documented request shape', () async {
    final box = _FakeBox();
    final settings = await _settings(box);
    final stub = _Stub((_, _, _) async => _openaiOk('ok'));
    final client = LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk-1'}),
      settings: settings,
    );
    final outcome = await client.call(system: 'S', user: 'U');
    expect(outcome.ok, isTrue);
    expect(outcome.text, 'ok');
    expect(stub.calls, hasLength(1));
    final call = stub.calls.single;
    expect(call.endpoint, 'https://api.example.com/v1/chat/completions');
    expect(call.headers['authorization'], 'Bearer sk-1');
    expect(call.headers['content-type'], 'application/json');
    expect(call.body['model'], 'm1');
    expect(call.body['max_tokens'], LlmLimits.maxCompletionTokens);
    expect(call.body['stream'], false);
    final messages = call.body['messages'] as List;
    expect((messages[0] as Map)['role'], 'system');
    expect((messages[0] as Map)['content'], 'S');
    expect((messages[1] as Map)['role'], 'user');
    expect((messages[1] as Map)['content'], 'U');
    expect(call.timeout, LlmLimits.requestTimeout);
  });

  test('thinking fields merge into the request body (#176)', () async {
    final box = _FakeBox();
    final settings = await _settings(box);
    final stub = _Stub((_, _, _) async => _openaiOk('ok'));
    final client = LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk-1'}),
      settings: settings,
    );
    final outcome = await client.call(
      system: 'S',
      user: 'U',
      thinkingFields: const {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'high',
      },
    );
    expect(outcome.ok, isTrue);
    final body = stub.calls.single.body;
    expect((body['thinking'] as Map)['type'], 'enabled');
    expect(body['reasoning_effort'], 'high');
  });

  test('without thinking fields the wire body stays clean (#176)', () async {
    final box = _FakeBox();
    final settings = await _settings(box);
    final stub = _Stub((_, _, _) async => _openaiOk('ok'));
    final client = LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk-1'}),
      settings: settings,
    );
    final outcome = await client.call(system: 'S', user: 'U');
    expect(outcome.ok, isTrue);
    expect(stub.calls.single.body.containsKey('thinking'), isFalse);
    expect(stub.calls.single.body.containsKey('reasoning_effort'), isFalse);
  });

  test('a live call carries parsed upstream usage (#176)', () async {
    final box = _FakeBox();
    final settings = await _settings(box);
    final stub = _Stub(
      (_, _, _) async => {
        ..._openaiOk('ok'),
        'usage': {
          'prompt_tokens': 100,
          'prompt_cache_hit_tokens': 64,
          'prompt_cache_miss_tokens': 36,
        },
      },
    );
    final client = LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk-1'}),
      settings: settings,
    );
    final outcome = await client.call(system: 'S', user: 'U');
    expect(outcome.ok, isTrue);
    expect(outcome.usage?.inputTokens, 100);
    expect(outcome.usage?.cacheHitTokens, 64);
    expect(outcome.usage?.cacheMissTokens, 36);
  });

  test('upstream usage parses openai and anthropic shapes (#176)', () {
    const openai = {
      'usage': {
        'prompt_tokens': 100,
        'prompt_cache_hit_tokens': 64,
        'prompt_cache_miss_tokens': 36,
      },
    };
    final a = LlmUpstreamUsage.fromBody(LlmProtocol.openAICompatible, openai);
    expect(a?.inputTokens, 100);
    expect(a?.cacheHitTokens, 64);
    expect(a?.cacheMissTokens, 36);

    const details = {
      'usage': {
        'prompt_tokens': 50,
        'prompt_tokens_details': {'cached_tokens': 20},
      },
    };
    final b = LlmUpstreamUsage.fromBody(
      LlmProtocol.openAICompatible,
      details,
    );
    expect(b?.inputTokens, 50);
    expect(b?.cacheHitTokens, 20);
    expect(b?.cacheMissTokens, isNull);

    const anthropic = {
      'usage': {
        'input_tokens': 30,
        'cache_read_input_tokens': 10,
        'cache_creation_input_tokens': 5,
      },
    };
    final c = LlmUpstreamUsage.fromBody(
      LlmProtocol.anthropicCompatible,
      anthropic,
    );
    expect(c?.inputTokens, 30);
    expect(c?.cacheHitTokens, 10);
    expect(c?.cacheMissTokens, 5);

    const junk = {
      'usage': {'prompt_tokens': 0},
    };
    expect(
      LlmUpstreamUsage.fromBody(LlmProtocol.openAICompatible, junk),
      isNull,
    );
    expect(LlmUpstreamUsage.fromBody(LlmProtocol.openAICompatible, 'x'), isNull);
    expect(
      LlmUpstreamUsage.fromBody(LlmProtocol.openAICompatible, {'no': 1}),
      isNull,
    );
  });

  test('an anthropic call posts the native messages shape', () async {
    final box = _FakeBox();
    final settings = await _settings(
      box,
      protocol: LlmProtocol.anthropicCompatible,
      baseUrl: 'https://api.anthropic.example',
    );
    final stub = _Stub((_, _, _) async => _anthropicOk('ok'));
    final client = LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.anthropicCompatible: 'sk-2'}),
      settings: settings,
    );
    final outcome = await client.call(system: 'S', user: 'U');
    expect(outcome.ok, isTrue);
    expect(outcome.text, 'ok');
    final call = stub.calls.single;
    expect(call.endpoint, 'https://api.anthropic.example/v1/messages');
    expect(call.headers['x-api-key'], 'sk-2');
    expect(call.headers['anthropic-version'], '2023-06-01');
    expect(call.body['max_tokens'], LlmLimits.maxCompletionTokens);
    expect(call.body['system'], 'S');
    expect(call.body.containsKey('stream'), isFalse);
    final messages = call.body['messages'] as List;
    expect((messages.single as Map)['role'], 'user');
    expect((messages.single as Map)['content'], 'U');
  });

  test('a missing or unconfirmed provider fails before the wire', () async {
    final stub = _Stub((_, _, _) async => _openaiOk('ok'));
    final empty = LlmSettingsStore(box: _FakeBox());
    final outcome = await LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: empty,
    ).call(system: 'S', user: 'U');
    expect(outcome.ok, isFalse);
    expect(outcome.failure, LlmChatFailureKind.config);
    expect(stub.calls, isEmpty);

    final unconfirmed = await _settings(_FakeBox(), confirmed: false);
    final outcome2 = await LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: unconfirmed,
    ).call(system: 'S', user: 'U');
    expect(outcome2.failure, LlmChatFailureKind.config);
    expect(stub.calls, isEmpty);
  });

  test('a missing or locked key fails before the wire', () async {
    final settings = await _settings(_FakeBox());
    final locked = _FakeCredentials()..fail = true;
    final outcome = await LlmChatClient(
      transport: _Stub((_, _, _) async => _openaiOk('ok')).transport,
      credentials: locked,
      settings: settings,
    ).call(system: 'S', user: 'U');
    expect(outcome.ok, isFalse);
    expect(outcome.failure, LlmChatFailureKind.credential);

    final outcome2 = await LlmChatClient(
      transport: _Stub((_, _, _) async => _openaiOk('ok')).transport,
      credentials: _FakeCredentials(),
      settings: settings,
    ).call(system: 'S', user: 'U');
    expect(outcome2.failure, LlmChatFailureKind.credential);
  });

  test('openai text is read from choices[0].message.content', () async {
    final settings = await _settings(_FakeBox());
    final client = LlmChatClient(
      transport: _Stub((_, _, _) async => _openaiOk('判定正文')).transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    );
    final outcome = await client.call(system: 'S', user: 'U');
    expect(outcome.ok, isTrue);
    expect(outcome.text, '判定正文');
  });

  test('anthropic text joins its text blocks', () async {
    final settings = await _settings(
      _FakeBox(),
      protocol: LlmProtocol.anthropicCompatible,
      baseUrl: 'https://api.anthropic.example',
    );
    final client = LlmChatClient(
      transport: _Stub((_, _, _) async {
        return {
          'content': [
            {'type': 'text', 'text': 'A'},
            {'type': 'text', 'text': 'B'},
          ],
          'stop_reason': 'end_turn',
        };
      }).transport,
      credentials: _FakeCredentials({LlmProtocol.anthropicCompatible: 'sk'}),
      settings: settings,
    );
    final outcome = await client.call(system: 'S', user: 'U');
    expect(outcome.ok, isTrue);
    expect(outcome.text, 'A\nB');
  });

  test('stop markers win over body text', () async {
    Future<LlmChatOutcome> run(
      LlmProtocol protocol,
      Object? body,
    ) async {
      return LlmChatClient(
        transport: _Stub((_, _, _) async => body).transport,
        credentials: _FakeCredentials({protocol: 'sk'}),
        settings: await _settings(
          _FakeBox(),
          protocol: protocol,
          baseUrl: protocol == LlmProtocol.anthropicCompatible
              ? 'https://api.anthropic.example'
              : 'https://api.example.com/v1',
        ),
      ).call(system: 'S', user: 'U');
    }

    expect(
      (await run(
        LlmProtocol.openAICompatible,
        _openaiOk('x', finish: 'length'),
      )).failure,
      LlmChatFailureKind.truncation,
    );
    expect(
      (await run(
        LlmProtocol.openAICompatible,
        _openaiOk('x', finish: 'content_filter'),
      )).failure,
      LlmChatFailureKind.refusal,
    );
    expect(
      (await run(
        LlmProtocol.anthropicCompatible,
        _anthropicOk('x', stop: 'max_tokens'),
      )).failure,
      LlmChatFailureKind.truncation,
    );
    expect(
      (await run(
        LlmProtocol.anthropicCompatible,
        _anthropicOk('x', stop: 'refusal'),
      )).failure,
      LlmChatFailureKind.refusal,
    );
  });

  test('empty outputs fail as emptyOutput', () async {
    final settings = await _settings(_FakeBox());
    final client = LlmChatClient(
      transport: _Stub((_, _, _) async => _openaiOk('')).transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    );
    expect(
      (await client.call(system: 'S', user: 'U')).failure,
      LlmChatFailureKind.emptyOutput,
    );
    final client2 = LlmChatClient(
      transport: _Stub((_, _, _) async => {'choices': []}).transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    );
    expect(
      (await client2.call(system: 'S', user: 'U')).failure,
      LlmChatFailureKind.emptyOutput,
    );
  });

  test('error envelopes are summarized per protocol', () async {
    final settings = await _settings(_FakeBox());
    final stub = _Stub(
      (_, _, _) async => throw _dio(429, {
        'error': {
          'message': 'rate limited',
          'type': 'requests',
          'code': '1302',
          'param': '',
        },
      }),
    );
    final outcome = await LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    ).call(system: 'S', user: 'U');
    expect(outcome.failure, LlmChatFailureKind.httpStatus);
    expect(outcome.detail, 'HTTP 429: rate limited');

    final anthropicSettings = await _settings(
      _FakeBox(),
      protocol: LlmProtocol.anthropicCompatible,
      baseUrl: 'https://api.anthropic.example',
    );
    final outcome2 = await LlmChatClient(
      transport: _Stub(
        (_, _, _) async => throw _dio(400, {
          'type': 'error',
          'error': {'type': 'invalid_request_error', 'message': 'bad key'},
          'request_id': 'req-1',
        }),
      ).transport,
      credentials: _FakeCredentials({LlmProtocol.anthropicCompatible: 'sk'}),
      settings: anthropicSettings,
    ).call(system: 'S', user: 'U');
    expect(outcome2.failure, LlmChatFailureKind.httpStatus);
    expect(outcome2.detail, 'HTTP 400: bad key');
  });

  test('dio error kinds map to failure kinds', () async {
    final settings = await _settings(_FakeBox());
    Future<LlmChatFailureKind?> kindOf(DioException error) => LlmChatClient(
      transport: _Stub((_, _, _) async => throw error).transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    ).call(system: 'S', user: 'U').then((o) => o.failure);

    expect(
      await kindOf(_dio(null, null, type: DioExceptionType.connectionTimeout)),
      LlmChatFailureKind.timeout,
    );
    expect(
      await kindOf(_dio(null, null, type: DioExceptionType.cancel)),
      LlmChatFailureKind.cancelled,
    );
    expect(
      await kindOf(_dio(null, null, type: DioExceptionType.connectionError)),
      LlmChatFailureKind.network,
    );
  });

  test('non-dio failures fall back to network', () async {
    final settings = await _settings(_FakeBox());
    final outcome = await LlmChatClient(
      transport: _Stub((_, _, _) async => throw StateError('boom')).transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    ).call(system: 'S', user: 'U');
    expect(outcome.failure, LlmChatFailureKind.network);
  });

  test('oversized error details are rune-capped', () async {
    final settings = await _settings(_FakeBox());
    final outcome = await LlmChatClient(
      transport: _Stub(
        (_, _, _) async => throw _dio(500, {
          'error': {'message': 'x' * 500},
        }),
      ).transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    ).call(system: 'S', user: 'U');
    expect(outcome.detail!.runes.length, LlmLimits.maxDetailRunes);
  });

  test('the timeout tightens but never extends the default', () async {
    final settings = await _settings(_FakeBox());
    final stub = _Stub((_, _, _) async => _openaiOk('ok'));
    final client = LlmChatClient(
      transport: stub.transport,
      credentials: _FakeCredentials({LlmProtocol.openAICompatible: 'sk'}),
      settings: settings,
    );
    await client.call(
      system: 'S',
      user: 'U',
      timeout: const Duration(seconds: 2),
    );
    expect(stub.calls.single.timeout, const Duration(seconds: 2));
  });
}
