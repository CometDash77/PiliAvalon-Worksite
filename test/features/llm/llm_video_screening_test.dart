import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart'
    show JevKeyStoreStatus;
import 'package:PiliPlus/features/jev/jev_rules.dart';
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

  @override
  Future<JevKeyStoreStatus> status(LlmProtocol protocol) async =>
      JevKeyStoreStatus.available;

  @override
  Future<String?> read(LlmProtocol protocol) async => _keys?[protocol];

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
  _Call(this.body, this.timeout);
  final Map<String, Object?> body;
  final Duration timeout;
}

class _Stub {
  _Stub(this.handler);
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
        calls.add(_Call(body, timeout));
        return handler(endpoint, headers, body);
      };
}

Future<_FakeBox> _confirmedBox() async {
  final box = _FakeBox();
  await LlmSettingsStore(box: box).save(
    const LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'https://api.example.com/v1',
      model: 'm1',
      confirmed: true,
    ),
  );
  return box;
}

Future<_FakeBox> _readyBox() async {
  final box = await _confirmedBox();
  // 统一 blob：视频规则写入 videoTextRules 字段（#141）。
  await JevRuleStore(box: box).save(
    const JevRuleConfig(
      videoTextRules: [LlmVideoRule(id: 'v1', text: '剧透内容')],
    ),
  );
  return box;
}

LlmVideoScreening _screening(_FakeBox box, _Stub stub, [_FakeCredentials? c]) {
  final credentials =
      c ?? _FakeCredentials({LlmProtocol.openAICompatible: 'sk'});
  return LlmVideoScreening(
    client: LlmChatClient(
      transport: stub.transport,
      credentials: credentials,
      settings: LlmSettingsStore(box: box),
    ),
    settings: LlmSettingsStore(box: box),
    credentials: credentials,
    rules: JevRuleStore(box: box),
    cache: LlmVerdictCache(box: box),
  );
}

String _llmJson(List<Map<String, String>> hits) => jsonEncode({'hits': hits});

Map<String, Object?> _openaiOk(String content) => {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': content},
      'finish_reason': 'stop',
    },
  ],
};

String _userOf(_Call call) =>
    ((call.body['messages'] as List).last as Map)['content'] as String;

void main() {
  setUp(LlmVerdictCache.resetCache);

  test('a hit hides the candidate and quotes title and rule text', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, body) async => _openaiOk(
        (((body['messages'] as List).last as Map)['content'] as String)
                .contains('第一话')
            ? _llmJson([
                {'rule_id': 'v1', 'reason': '剧透'},
              ])
            : _llmJson([]),
      ),
    );
    final outcome = await _screening(box, stub).screen([
      const LlmVideoCandidate(title: '第一话', identity: 'BV1'),
      const LlmVideoCandidate(title: '第二话', identity: 'BV2'),
    ]);
    expect(outcome.hidden, [true, false]);
    expect(outcome.ruleIds[0], 'v1');
    expect(outcome.reasons[0], '剧透');
    expect(outcome.modelId, 'm1');
    final user = _userOf(stub.calls.first);
    expect(user, contains('第一话'));
    expect(user, contains('剧透内容'));
  });

  test('an identity hit is served from cache without upstream', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, body) async => _openaiOk(
        (((body['messages'] as List).last as Map)['content'] as String)
                .contains('第一话')
            ? _llmJson([
                {'rule_id': 'v1', 'reason': '剧透'},
              ])
            : _llmJson([]),
      ),
    );
    final screening = _screening(box, stub);
    final first = await screening.screen([
      const LlmVideoCandidate(title: '第一话', identity: 'BV1'),
    ]);
    expect(first.hidden, [true]);
    expect(stub.calls, hasLength(1));
    final second = await screening.screen([
      const LlmVideoCandidate(title: '第一话', identity: 'BV1'),
    ]);
    expect(second.hidden, [true]);
    expect(stub.calls, hasLength(1));
  });

  test('without identity the normalized title backs the cache', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, body) async => _openaiOk(
        (((body['messages'] as List).last as Map)['content'] as String)
                .contains('第一话')
            ? _llmJson([
                {'rule_id': 'v1', 'reason': '剧透'},
              ])
            : _llmJson([]),
      ),
    );
    final screening = _screening(box, stub);
    final first = await screening.screen([
      const LlmVideoCandidate(title: '  第一话  '),
    ]);
    expect(first.hidden, [true]);
    final second = await screening.screen([
      const LlmVideoCandidate(title: '第一话'),
    ]);
    expect(second.hidden, [true]);
    expect(stub.calls, hasLength(1));
  });

  test('blank titles are skipped and never sent', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, _) async => _openaiOk(
        _llmJson([
          {'rule_id': 'v1', 'reason': 'x'},
        ]),
      ),
    );
    final outcome = await _screening(
      box,
      stub,
    ).screen([const LlmVideoCandidate(title: '   ', identity: 'BV1')]);
    expect(outcome.hidden, [false]);
    expect(stub.calls, isEmpty);
    expect(LlmVerdictCache.cachedEntryCount, 0);
  });

  test('no active video rules: nothing is sent, hidden unchanged', () async {
    final box = await _confirmedBox();
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final outcome = await _screening(
      box,
      stub,
    ).screen([const LlmVideoCandidate(title: '第一话', identity: 'BV1')]);
    expect(outcome.hidden, [false]);
    expect(stub.calls, isEmpty);
  });

  test('an upstream failure fails open and caches nothing', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async => throw StateError('offline'));
    final outcome = await _screening(
      box,
      stub,
    ).screen([const LlmVideoCandidate(title: '第一话', identity: 'BV1')]);
    expect(outcome.hidden, [false]);
    expect(outcome.failure, 'upstream');
    expect(LlmVerdictCache.cachedEntryCount, 0);
  });

  test('unparseable output is not cached', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async => _openaiOk('这不是 JSON'));
    final outcome = await _screening(
      box,
      stub,
    ).screen([const LlmVideoCandidate(title: '第一话', identity: 'BV1')]);
    expect(outcome.hidden, [false]);
    expect(outcome.failure, 'parse');
    expect(LlmVerdictCache.cachedEntryCount, 0);
  });

  test('a zero budget returns all false without upstream', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final outcome = await _screening(box, stub).screen([
      const LlmVideoCandidate(title: '第一话', identity: 'BV1'),
    ], timeout: Duration.zero);
    expect(outcome.hidden, [false]);
    expect(stub.calls, isEmpty);
  });

  test(
    'a late reply past the budget voids the pass and caches nothing',
    () async {
      final box = await _readyBox();
      final stub = _Stub((_, _, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return _openaiOk(
          _llmJson([
            {'rule_id': 'v1', 'reason': '剧透'},
          ]),
        );
      });
      final outcome = await _screening(box, stub).screen([
        const LlmVideoCandidate(title: '第一话', identity: 'BV1'),
      ], timeout: const Duration(milliseconds: 50));
      expect(outcome.hidden, [false]);
      expect(outcome.failure, 'timeout');
      expect(LlmVerdictCache.cachedEntryCount, 0);
    },
  );

  test('a mid-pass model change voids the pass', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async {
      await LlmSettingsStore(box: box).save(
        const LlmProviderConfig(
          protocol: LlmProtocol.openAICompatible,
          baseUrl: 'https://api.example.com/v1',
          model: 'm2',
          confirmed: true,
        ),
      );
      return _openaiOk(
        _llmJson([
          {'rule_id': 'v1', 'reason': '剧透'},
        ]),
      );
    });
    final outcome = await _screening(
      box,
      stub,
    ).screen([const LlmVideoCandidate(title: '第一话', identity: 'BV1')]);
    expect(outcome.hidden, [false]);
    expect(outcome.failure, 'drift');
  });

  test('isEnabled gates on config, key and active rules', () async {
    Future<bool> enabled(_FakeBox box, [_FakeCredentials? c]) {
      final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
      return _screening(box, stub, c).isEnabled();
    }

    // Fully configured.
    final box1 = await _readyBox();
    expect(await enabled(box1), isTrue);

    // Unconfirmed provider.
    final box2 = await _readyBox();
    await LlmSettingsStore(box: box2).save(
      const LlmProviderConfig(
        protocol: LlmProtocol.openAICompatible,
        baseUrl: 'https://api.example.com/v1',
        model: 'm1',
        confirmed: false,
      ),
    );
    expect(await enabled(box2), isFalse);

    // Key missing.
    final box3 = await _readyBox();
    expect(await enabled(box3, _FakeCredentials()), isFalse);

    // No active rules.
    final box4 = await _confirmedBox();
    expect(await enabled(box4), isFalse);
  });

  test('corrupt stored rules do not throw', () async {
    final box = await _confirmedBox();
    box.map['piliavalon.llm.v1.video_rules.v1'] = '{corrupt';
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final outcome = await _screening(
      box,
      stub,
    ).screen([const LlmVideoCandidate(title: '第一话', identity: 'BV1')]);
    expect(outcome.hidden, [false]);
    expect(stub.calls, isEmpty);
  });
}
