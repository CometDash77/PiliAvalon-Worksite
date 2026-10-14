import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart'
    show JevKeyStoreStatus;
import 'package:PiliPlus/features/jev/jev_contract.dart' show JevSurface;
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/llm/llm.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/utils/storage_key.dart';

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

ReplyInfo reply(String text, {int id = 1}) => ReplyInfo(
  id: Int64(id),
  mid: Int64(12345),
  content: Content(message: text),
);

Future<_FakeBox> _readyBox() async {
  final box = _FakeBox();
  await JevSettingsStore(box: box).save(const JevSettings(
    mode: ScreeningEngineMode.llm, surfaces: {JevSurface.comment, JevSurface.hot},
  ));
  await LlmSettingsStore(box: box).save(
    const LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'https://api.example.com/v1',
      model: 'm1',
      confirmed: true,
    ),
  );
  await JevRuleStore(box: box).save(
    const JevRuleConfig(
      rules: [
        JevRule(id: 'r1', target: JevRuleTarget.comment, question: '是垃圾评论吗'),
      ],
    ),
  );
  return box;
}

LlmCommentScreening _screening(_FakeBox box, _Stub stub) {
  final credentials = _FakeCredentials({LlmProtocol.openAICompatible: 'sk'});
  return LlmCommentScreening(
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

class _LogBox implements JevSettingsBox {
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

void main() {
  setUp(LlmVerdictCache.resetCache);

  tearDown(() {
    // 默认构造会触碰 GStorage.setting(测试环境未初始化),注入空 box 隔离。
    JevScreenLog.instance = JevScreenLog(box: _LogBox());
  });

  test('no active comment rules: nothing is sent', () async {
    final box = _FakeBox();
    await LlmSettingsStore(box: box).save(
      const LlmProviderConfig(
        protocol: LlmProtocol.openAICompatible,
        baseUrl: 'https://api.example.com/v1',
        model: 'm1',
        confirmed: true,
      ),
    );
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final result = await _screening(box, stub).filter(
      [reply('a'), reply('b')],
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message).toList(), ['a', 'b']);
    expect(stub.calls, isEmpty);
  });

  test('a hit hides only the matching candidate', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, _) async => _openaiOk(
        _llmJson([
          {'rule_id': 'candidate_2:r1', 'reason': '垃圾'},
        ]),
      ),
    );
    final result = await _screening(box, stub).filter(
      [reply('a', id: 1), reply('b', id: 2), reply('c', id: 3)],
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message).toList(), ['a', 'c']);
    expect(result.cacheable, isTrue);
    final user = _userOf(stub.calls.single);
    expect(user, contains('candidate_1:r1'));
    expect(user, contains('candidate_2:r1'));
    expect(user, contains('candidate_3:r1'));
    expect(user, contains('是垃圾评论吗'));
  });

  test('every upstream failure mode fails open', () async {
    // Transport throws.
    final box1 = await _readyBox();
    final stub1 = _Stub((_, _, _) async => throw StateError('offline'));
    final r1 = await _screening(box1, stub1).filter(
      [reply('a', id: 1)],
      screenLog: false,
    );
    expect(r1.replies.map((r) => r.content.message), ['a']);
    expect(r1.cacheable, isFalse);

    // Provider not configured: config failure before the wire.
    final box2 = _FakeBox();
    await JevRuleStore(box: box2).save(
      const JevRuleConfig(
        rules: [
          JevRule(id: 'r1', target: JevRuleTarget.comment, question: '是垃圾评论吗'),
        ],
      ),
    );
    final stub2 = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final r2 = await _screening(box2, stub2).filter(
      [reply('a', id: 1)],
      screenLog: false,
    );
    expect(r2.replies.map((r) => r.content.message), ['a']);
    expect(r2.cacheable, isFalse);
    expect(stub2.calls, isEmpty);

    // Unparseable model output.
    final box3 = await _readyBox();
    final stub3 = _Stub((_, _, _) async => _openaiOk('这不是 JSON'));
    final r3 = await _screening(box3, stub3).filter(
      [reply('a', id: 1)],
      screenLog: false,
    );
    expect(r3.replies.map((r) => r.content.message), ['a']);
    expect(r3.cacheable, isFalse);
  });

  test('unknown rule ids drop the hit and poison the cache', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, _) async => _openaiOk(
        _llmJson([
          {'rule_id': 'candidate_1:ghost', 'reason': 'x'},
        ]),
      ),
    );
    final screening = _screening(box, stub);
    final r1 = await screening.filter([reply('a', id: 1)], screenLog: false);
    expect(r1.replies.map((r) => r.content.message), ['a']);
    expect(r1.cacheable, isFalse);
    // A poisoned pass wrote no cache entry: the next pass goes upstream.
    await screening.filter([reply('a', id: 1)], screenLog: false);
    expect(stub.calls, hasLength(2));
  });

  test('definite verdicts are served from cache without upstream', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, _) async => _openaiOk(
        _llmJson([
          {'rule_id': 'candidate_1:r1', 'reason': '垃圾'},
          {'rule_id': 'candidate_2:r1', 'reason': '垃圾'},
        ]),
      ),
    );
    final screening = _screening(box, stub);
    final first = await screening.filter(
      [reply('a', id: 1), reply('b', id: 2)],
      screenLog: false,
    );
    expect(first.replies, isEmpty);
    expect(first.cacheable, isTrue);
    expect(stub.calls, hasLength(1));
    final second = await screening.filter(
      [reply('a', id: 1), reply('b', id: 2)],
      screenLog: false,
    );
    expect(second.replies, isEmpty);
    expect(second.cacheable, isTrue);
    expect(stub.calls, hasLength(1));
  });

  test('the cache switch off sends every pass upstream', () async {
    final box = await _readyBox();
    box.map[SettingBoxKey.jevVerdictCacheEnabled] = false;
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final screening = _screening(box, stub);
    await screening.filter([reply('a', id: 1)], screenLog: false);
    await screening.filter([reply('a', id: 1)], screenLog: false);
    expect(stub.calls, hasLength(2));
  });

  test('repeated texts keep their own verdicts and repeat counts', () async {
    final box = await _readyBox();
    final stub = _Stub(
      (_, _, _) async => _openaiOk(
        _llmJson([
          {'rule_id': 'candidate_1:r1', 'reason': '垃圾'},
        ]),
      ),
    );
    final result = await _screening(box, stub).filter(
      [reply('dup', id: 1), reply('dup', id: 2)],
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message), ['dup']);
    final user = _userOf(stub.calls.single);
    expect('重复次数：2'.allMatches(user).length, 2);
  });

  test('oversized bodies poison the pass and are not sent', () async {
    final box = await _readyBox();
    final big = '剧' * (LlmPrompt.maxTextChars + 1);
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final result = await _screening(box, stub).filter(
      [reply(big, id: 1), reply('normal', id: 2)],
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message).toList(), [
      big,
      'normal',
    ]);
    expect(result.cacheable, isFalse);
    final user = _userOf(stub.calls.single);
    expect(user, contains('normal'));
    expect(user, isNot(contains(big)));
  });

  test('blank bodies are skipped entirely', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final result = await _screening(box, stub).filter(
      [reply('   ', id: 1)],
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message), ['   ']);
    expect(stub.calls, isEmpty);
  });

  test('a zero budget returns the page untouched', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    final result = await _screening(box, stub).filter(
      [reply('a', id: 1)],
      timeout: Duration.zero,
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message), ['a']);
    expect(result.cacheable, isFalse);
    expect(stub.calls, isEmpty);
  });

  test('the timeout tightens but never extends the 8s budget', () async {
    LlmVerdictCache.resetCache();
    final box1 = await _readyBox();
    final stub1 = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    await _screening(box1, stub1).filter([reply('a', id: 1)], screenLog: false);
    expect(stub1.calls.single.timeout, isNotNull);
    expect(
      stub1.calls.single.timeout,
      lessThanOrEqualTo(LlmLimits.requestTimeout),
    );

    LlmVerdictCache.resetCache();
    final box2 = await _readyBox();
    final stub2 = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    await _screening(box2, stub2).filter(
      [reply('b', id: 2)],
      timeout: const Duration(seconds: 2),
      screenLog: false,
    );
    expect(
      stub2.calls.single.timeout,
      lessThanOrEqualTo(const Duration(seconds: 2)),
    );
  });

  test('parent context travels with the candidate', () async {
    final box = await _readyBox();
    final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
    await _screening(box, stub).filter(
      [reply('child', id: 1)],
      parents: ['the parent floor'],
      screenLog: false,
    );
    expect(_userOf(stub.calls.single), contains('the parent floor'));
  });

  test('a mid-pass model change voids the whole page', () async {
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
          {'rule_id': 'candidate_1:r1', 'reason': '垃圾'},
        ]),
      );
    });
    final result = await _screening(box, stub).filter(
      [reply('a', id: 1)],
      screenLog: false,
    );
    expect(result.replies.map((r) => r.content.message), ['a']);
    expect(result.cacheable, isFalse);
  });

  group('screen log (#131)', () {
    test('a hidden reply records an llm line with rule/reason/model', () async {
      final box = _LogBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final ready = await _readyBox();
      final stub = _Stub(
        (_, _, _) async => _openaiOk(
          _llmJson([
            {'rule_id': 'candidate_1:r1', 'reason': '垃圾'},
          ]),
        ),
      );
      final result = await _screening(ready, stub).filter([reply('a', id: 1)]);
      await pumpEventQueue();

      expect(result.replies, isEmpty);
      final entries = JevScreenLog(box: box).load();
      expect(entries, hasLength(1));
      final row = entries.single;
      expect(row.line, JevScreenLogLine.llm);
      expect(row.kind, JevScreenLogKind.comment);
      expect(row.surface, JevSurface.comment.id);
      expect(row.title, 'a');
      expect(row.ruleId, 'candidate_1:r1');
      expect(row.reason, '垃圾');
      expect(row.modelId, 'm1');
      expect(row.failure, isNull);
      expect(row.elapsedMs, greaterThanOrEqualTo(0));
    });

    test('an upstream failure records a bare failure line', () async {
      final box = _LogBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final ready = await _readyBox();
      final stub = _Stub((_, _, _) async => throw StateError('offline'));
      final result = await _screening(ready, stub).filter([reply('a', id: 1)]);
      await pumpEventQueue();

      expect(result.replies.map((r) => r.content.message), ['a']);
      final entries = JevScreenLog(box: box).load();
      expect(entries, hasLength(1));
      final row = entries.single;
      expect(row.line, JevScreenLogLine.llm);
      expect(row.title, '');
      expect(row.snippet, isNull);
      expect(row.ruleId, isNull);
      expect(row.reason, isNull);
      expect(row.modelId, 'm1');
      expect(row.failure, 'upstream');
    });

    test('a mid-pass drift failure records a bare failure line', () async {
      final box = _LogBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final ready = await _readyBox();
      final stub = _Stub((_, _, _) async {
        await LlmSettingsStore(box: ready).save(
          const LlmProviderConfig(
            protocol: LlmProtocol.openAICompatible,
            baseUrl: 'https://api.example.com/v1',
            model: 'm2',
            confirmed: true,
          ),
        );
        return _openaiOk(
          _llmJson([
            {'rule_id': 'candidate_1:r1', 'reason': '垃圾'},
          ]),
        );
      });
      final result = await _screening(ready, stub).filter([reply('a', id: 1)]);
      await pumpEventQueue();

      expect(result.replies.map((r) => r.content.message), ['a']);
      final entries = JevScreenLog(box: box).load();
      expect(entries, hasLength(1));
      final row = entries.single;
      expect(row.line, JevScreenLogLine.llm);
      expect(row.title, '');
      expect(row.failure, 'drift');
      expect(row.modelId, 'm1');
    });

    test('an unconfigured provider is a gate, not a failure', () async {
      final box = _LogBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final ready = _FakeBox();
      await JevRuleStore(box: ready).save(
        const JevRuleConfig(
          rules: [
            JevRule(id: 'r1', target: JevRuleTarget.comment, question: 'q'),
          ],
        ),
      );
      final stub = _Stub((_, _, _) async => _openaiOk(_llmJson([])));
      final result = await _screening(ready, stub).filter([reply('a', id: 1)]);
      await pumpEventQueue();

      expect(result.replies.map((r) => r.content.message), ['a']);
      expect(JevScreenLog(box: box).load(), isEmpty);
    });

    test('screenLog=false records nothing', () async {
      final box = _LogBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final ready = await _readyBox();
      final stub = _Stub((_, _, _) async => throw StateError('offline'));
      await _screening(ready, stub).filter(
        [reply('a', id: 1)],
        screenLog: false,
      );
      await pumpEventQueue();

      expect(JevScreenLog(box: box).load(), isEmpty);
    });
  });
}
