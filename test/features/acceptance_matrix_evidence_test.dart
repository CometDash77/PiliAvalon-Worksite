// #182 验收矩阵自动化取证：每个用例名以矩阵行号开头（M1/M4/M5/R1-R4/L1/L2/L4），
// CI 运行记录即对应矩阵行的可审计证据；真机双模式与最终集成验收留在 #147。
// 行 → 断言速查：
//   M1  双端互斥请求计数（decision 模式 LLM=0；llm 模式 Decision=0）
//   M4  无隐式重试/回退（任一后端失败整批保留，另一端零请求）
//   M5  模式切换与 ABA 代际失效（在途迟到结果作废，新 pass 走新后端）
//   R1  同一规则库同时驱动两后端，一次保存启停联动
//   R2  规则增删改停重载一致 + 存储 blob 唯一
//   R3  双后端运行后无 legacy 规则副本键
//   R4  hideOnYes 反转 + choice hiddenOptions 映射（Decision 侧）
//   L1/L2/L4 canonical JSON → 统一判定端到端（评论线）：band×threshold 边界、
//       非法/缺 band 整批 fail-open 不污染缓存、空 hits 全保留且 keep 入缓存
//   L3  由既有用例「unknown rule ids fail the whole batch open and poison the cache」
//       （test/features/llm/llm_comment_screening_test.dart）覆盖，此处不重复。
//   U5  CI 显式记录镜像变量：.github/workflows/ci.yml「Record pub mirror (U5 evidence)」步骤。
library;

import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/screening_mode.dart';
import 'package:PiliPlus/features/llm/llm.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show Content, ReplyInfo;
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jev/decisions_schema.dart';

class _Box implements JevSettingsBox {
  final map = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      map.containsKey(key) ? map[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

class _DecisionCredentials implements JevCredentialStore {
  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;

  @override
  Future<String?> read() async => 'sk-decision';

  @override
  Future<void> write(String apiKey) async {}

  @override
  Future<void> delete() async {}
}

class _LlmCredentials implements LlmCredentialStore {
  @override
  Future<JevKeyStoreStatus> status(LlmProtocol protocol) async =>
      JevKeyStoreStatus.available;

  @override
  Future<String?> read(LlmProtocol protocol) async => 'sk-llm';

  @override
  Future<void> write(LlmProtocol protocol, String apiKey) async {}

  @override
  Future<void> delete(LlmProtocol protocol) async {}
}

/// Decision 传输计数器：记录请求体、校验 schema，可注入答复或抛错。
class _Capture {
  _Capture({this.reply});

  final Future<Object?> Function(int callIndex)? reply;
  final bodies = <Map<String, Object?>>[];
  int calls = 0;

  JevTransport get transport =>
      ({required provider, required apiKey, required body}) async {
        final index = calls++;
        bodies.add(body);
        if (!acceptsDecisionsRequest(body)) {
          throw StateError('HTTP 400: invalid Decisions request schema');
        }
        final answer = await reply?.call(index);
        if (answer == null) {
          throw StateError('transport failure');
        }
        return answer;
      };
}

/// LLM 传输计数器：记录请求体，答复由注入的 handler 决定。
class _LlmStub {
  _LlmStub(this.handler);

  final Future<Object?> Function(
    String endpoint,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) handler;
  final bodies = <Map<String, Object?>>[];
  int calls = 0;

  LlmChatTransport get transport =>
      ({
        required String endpoint,
        required Map<String, String> headers,
        required Map<String, Object?> body,
        required Duration timeout,
      }) async {
        calls++;
        bodies.add(body);
        return handler(endpoint, headers, body);
      };
}

Map<String, Object?> _answers(Map<String, Object?> entries) =>
    {'answers': entries};

Map<String, Object?> _noul(double p) => {'type': 'noul', 'noul': p};

String _legacyHits(List<Map<String, String>> hits) =>
    jsonEncode({'hits': hits});

Map<String, Object?> _openaiOk(String content) => {
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        }
      ],
    };

String _userOf(Map<String, Object?> body) {
  final messages = body['messages'] as List<Object?>;
  return ((messages.last as Map)['content'] as String);
}

Future<void> _pumpUntil(bool Function() ready) async {
  for (var i = 0; i < 2000 && !ready(); i++) {
    await pumpEventQueue();
  }
}

Future<_Box> _decisionBox() async {
  final box = _Box();
  box.map[JevSettingsStore.enabledKey] = true;
  box.map[JevSettingsStore.surfaceKey(JevSurface.hot)] = true;
  box.map[JevSettingsStore.providerKey] = 'typesafe';
  box.map[JevSettingsStore.providerConfirmedKey] = true;
  // 终审判定缓存是进程内静态区（#123）；本文件关注实时判定，直接关闭。
  box.map[SettingBoxKey.jevVerdictCacheEnabled] = false;
  // LLM 侧门禁预置：无 provider 配置或空 videoTextRules 时 LlmVideoScreening
  // 整体禁用（isEnabled 空 rules→false），切到 LLM 模式的用例会全保留且零请求。
  await LlmSettingsStore(box: box).save(const LlmProviderConfig(
    protocol: LlmProtocol.openAICompatible,
    baseUrl: 'https://api.example.com/v1',
    model: 'm1',
    confirmed: true,
  ));
  await JevRuleStore(box: box).save(const JevRuleConfig(videoTextRules: [
    LlmVideoRule(id: 'v1', text: '剧透内容'),
  ]));
  await ScreeningModeStore(box: box).save(ScreeningEngineMode.decision);
  return box;
}

Future<_Box> _llmVideoBox({bool decisionReady = false}) async {
  final box = _Box();
  box.map[JevSettingsStore.enabledKey] = true;
  box.map[JevSettingsStore.surfaceKey(JevSurface.hot)] = true;
  if (decisionReady) {
    box.map[JevSettingsStore.providerKey] = 'typesafe';
    box.map[JevSettingsStore.providerConfirmedKey] = true;
  }
  await LlmSettingsStore(box: box).save(const LlmProviderConfig(
    protocol: LlmProtocol.openAICompatible,
    baseUrl: 'https://api.example.com/v1',
    model: 'm1',
    confirmed: true,
  ));
  await JevRuleStore(box: box).save(const JevRuleConfig(videoTextRules: [
    LlmVideoRule(id: 'v1', text: '剧透内容'),
  ]));
  await ScreeningModeStore(box: box).save(ScreeningEngineMode.llm);
  return box;
}

Future<_Box> _commentBox() async {
  final box = _Box();
  box.map[JevSettingsStore.enabledKey] = true;
  box.map[JevSettingsStore.surfaceKey(JevSurface.comment)] = true;
  await LlmSettingsStore(box: box).save(const LlmProviderConfig(
    protocol: LlmProtocol.openAICompatible,
    baseUrl: 'https://api.example.com/v1',
    model: 'm1',
    confirmed: true,
  ));
  await JevRuleStore(box: box).save(const JevRuleConfig(rules: [
    JevRule(id: 'r95', target: JevRuleTarget.comment, question: '是垃圾评论吗'),
    JevRule(
      id: 'r50',
      target: JevRuleTarget.comment,
      question: '是广告吗',
      threshold: .5,
    ),
  ]));
  await ScreeningModeStore(box: box).save(ScreeningEngineMode.llm);
  return box;
}

JevEvaluator _evaluator(_Box box, _Capture capture) => JevEvaluator(
      transport: capture.transport,
      credentials: _DecisionCredentials(),
      settings: JevSettingsStore(box: box),
      preferences: JevPreferenceStore(box: _Box()),
      rules: JevRuleStore(box: box),
      verdictCache: JevVerdictCache(box: box),
    );

LlmVideoScreening _video(_Box box, _LlmStub stub) => LlmVideoScreening(
      client: LlmChatClient(
        transport: stub.transport,
        credentials: _LlmCredentials(),
        settings: LlmSettingsStore(box: box),
      ),
      settings: LlmSettingsStore(box: box),
      credentials: _LlmCredentials(),
      rules: JevRuleStore(box: box),
      cache: LlmVerdictCache(box: box),
    );

LlmCommentScreening _comment(_Box box, _LlmStub stub) => LlmCommentScreening(
      client: LlmChatClient(
        transport: stub.transport,
        credentials: _LlmCredentials(),
        settings: LlmSettingsStore(box: box),
      ),
      settings: LlmSettingsStore(box: box),
      credentials: _LlmCredentials(),
      rules: JevRuleStore(box: box),
      cache: LlmVerdictCache(box: box),
    );

JevFinalScreen<String> _screen(_Box box, _Capture capture, _LlmStub stub) =>
    JevFinalScreen<String>(
      surface: JevSurface.hot,
      toCandidate: (title) => JevCandidate(title: title, localKey: 'bv:$title'),
      evaluator: _evaluator(box, capture),
      videoScreening: _video(box, stub),
    );

ReplyInfo _reply(String text, {int id = 1}) => ReplyInfo(
      id: Int64(id),
      mid: Int64(12345),
      content: Content(message: text),
    );

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
    LlmVerdictCache.resetCache();
  });

  group('统一模式：请求计数与互斥（M1/M4/M5）', () {
    test('M1a：Decision 模式只发 Decision 请求，LLM 传输零请求', () async {
      final box = await _decisionBox();
      final capture = _Capture(
        reply: (_) async => _answers({
          'candidate_1': {'noul': 0.95},
          'candidate_2': {'noul': 0.10},
        }),
      );
      final stub = _LlmStub((_, __, ___) async =>
          throw StateError('LLM must not run in Decision mode'));
      final result = await _screen(box, capture, stub).screen(['a', 'b']);
      expect(result, ['b']);
      expect(capture.calls, 1);
      expect(stub.calls, 0);
    });

    test('M1b：LLM 模式只发 LLM 请求，Decision 传输零请求', () async {
      final box = await _llmVideoBox();
      final capture = _Capture();
      final stub = _LlmStub((_, __, ___) async =>
          _openaiOk(_legacyHits([{'rule_id': 'v1', 'reason': '剧透'}])));
      final result = await _screen(box, capture, stub).screen(['a', 'b']);
      expect(result, isEmpty);
      expect(stub.calls, 2); // legacy 视频线一候选一请求
      expect(capture.calls, 0);
    });

    test('M4a：Decision 失败整批保留，不重试也不回退 LLM', () async {
      final box = await _decisionBox();
      final capture = _Capture(); // reply 为 null → 传输抛错
      final stub = _LlmStub((_, __, ___) async =>
          throw StateError('LLM must not run in Decision mode'));
      final result = await _screen(box, capture, stub).screen(['a', 'b']);
      expect(result, ['a', 'b']);
      expect(capture.calls, 1); // 无重试
      expect(stub.calls, 0); // 无回退
    });

    test('M4b：LLM 失败整批保留，不重试也不回退就绪的 Decision', () async {
      final box = await _llmVideoBox(decisionReady: true);
      // 若发生回退，Decision 将以 0.95 隐藏 a —— 用它当哨兵。
      final capture = _Capture(
        reply: (_) async => _answers({
          'candidate_1': {'noul': 0.95},
        }),
      );
      final stub =
          _LlmStub((_, __, ___) async => throw StateError('LLM offline'));
      final result = await _screen(box, capture, stub).screen(['a']);
      expect(result, ['a']);
      expect(stub.calls, 1); // 无重试
      expect(capture.calls, 0); // 无回退
    });

    test('M5a：在途切换模式后 Decision 迟到结果作废，新 pass 只走 LLM', () async {
      final box = await _decisionBox();
      final gate = Completer<void>();
      final capture = _Capture(reply: (_) async {
        await gate.future;
        return _answers({
          'candidate_1': {'noul': 0.95},
          'candidate_2': {'noul': 0.10},
        });
      });
      final stub = _LlmStub((_, __, ___) async =>
          _openaiOk(_legacyHits([{'rule_id': 'v1', 'reason': '剧透'}])));
      final screen = _screen(box, capture, stub);
      final pending = screen.screen(['a', 'b']);
      await _pumpUntil(() => capture.calls == 1);
      await ScreeningModeStore(box: box).save(ScreeningEngineMode.llm);
      gate.complete();
      final stale = await pending;
      expect(stale, ['a', 'b']); // 迟到的 Decision 隐藏不应用
      expect(capture.calls, 1);
      final fresh = await screen.screen(['a', 'b']);
      expect(fresh, isEmpty); // 新 pass 走 LLM 并隐藏
      expect(capture.calls, 1); // Decision 不再被调用
      expect(stub.calls, 2);
    });

    test('M5b：ABA 切回同名模式后 LLM 迟到命中仍作废', () async {
      final box = await _llmVideoBox();
      final gate = Completer<void>();
      final stub = _LlmStub((_, __, ___) async {
        await gate.future;
        return _openaiOk(_legacyHits([{'rule_id': 'v1', 'reason': '剧透'}]));
      });
      final capture = _Capture(
        reply: (_) async => _answers({
          'candidate_1': {'noul': 0.95},
        }),
      );
      final screen = _screen(box, capture, stub);
      final pending = screen.screen(['a']);
      await _pumpUntil(() => stub.calls == 1);
      final modes = ScreeningModeStore(box: box);
      await modes.save(ScreeningEngineMode.decision);
      await modes.save(ScreeningEngineMode.llm); // ABA
      gate.complete();
      final stale = await pending;
      expect(stale, ['a']); // 代际不匹配：旧命中不应用
      expect(stub.calls, 1);
      final fresh = await screen.screen(['a']);
      expect(fresh, isEmpty);
      expect(stub.calls, 2);
      expect(capture.calls, 0);
    });
  });

  group('单一规则源跨后端一致（R1-R4）', () {
    test('R1：同一规则库同时驱动两后端，一次保存启停联动', () async {
      final box = await _decisionBox();
      await JevRuleStore(box: box).save(const JevRuleConfig(
        rules: [
          JevRule(
            id: 'r1',
            target: JevRuleTarget.video,
            question: '有剧透吗',
            threshold: .9,
          ),
          JevRule(
            id: 'r2',
            target: JevRuleTarget.video,
            question: '标题党吗',
            threshold: .9,
          ),
        ],
        videoTextRules: [LlmVideoRule(id: 'v1', text: '剧透内容')],
      ));

      // Decision 侧：请求体 instructions 携带同一组规则问题。
      final capture = _Capture(
          reply: (_) async => _answers({
                'candidate_1_rule_1': _noul(0.10),
                'candidate_1_rule_1_context': _noul(0.99),
                'candidate_1_rule_2': _noul(0.90),
                'candidate_1_rule_2_context': _noul(0.99),
              }));
      final stub = _LlmStub((_, __, ___) async =>
          throw StateError('LLM must not run in Decision mode'));
      final decision = await _screen(box, capture, stub).screen(['a']);
      expect(decision, isEmpty); // r2 命中隐藏
      final questions = capture.bodies.single['questions'] as Map;
      final instructions = [
        for (final q in questions.values) (q as Map)['instructions'] as String,
      ].join('\n');
      expect(instructions, contains('有剧透吗'));
      expect(instructions, contains('标题党吗'));
      expect(capture.calls, 1);

      // LLM 侧：user message 携带同一规则库的 videoTextRule。
      final llmStub = _LlmStub((_, __, ___) async => _openaiOk(
          _legacyHits([{'rule_id': 'v1', 'reason': '剧透内容命中'}])));
      await ScreeningModeStore(box: box).save(ScreeningEngineMode.llm);
      final llm = await _screen(box, capture, llmStub).screen(['a']);
      expect(llm, isEmpty);
      expect(_userOf(llmStub.bodies.single), contains('v1'));
      expect(_userOf(llmStub.bodies.single), contains('剧透内容'));
      expect(llmStub.calls, 1);

      // 一次保存（停用 r1 + 移除 v1；v2 仅维持 LLM 管线启用）→ 两后端同步变化。
      await JevRuleStore(box: box).save(const JevRuleConfig(
        rules: [
          JevRule(
            id: 'r1',
            target: JevRuleTarget.video,
            question: '有剧透吗',
            threshold: .9,
            enabled: false,
          ),
          JevRule(
            id: 'r2',
            target: JevRuleTarget.video,
            question: '标题党吗',
            threshold: .9,
          ),
        ],
        videoTextRules: [LlmVideoRule(id: 'v2', text: '其他内容')],
      ));
      final capture2 = _Capture(
          reply: (_) async => _answers({
                'candidate_1_rule_1': _noul(0.10),
                'candidate_1_rule_1_context': _noul(0.99),
              }));
      await ScreeningModeStore(box: box).save(ScreeningEngineMode.decision);
      final decision2 = await _screen(box, capture2, stub).screen(['a']);
      expect(decision2, ['a']);
      final questions2 = capture2.bodies.single['questions'] as Map;
      final instructions2 = [
        for (final q in questions2.values) (q as Map)['instructions'] as String,
      ].join('\n');
      expect(instructions2, isNot(contains('有剧透吗')));
      expect(instructions2, contains('标题党吗'));
      expect(capture2.calls, 1);

      await ScreeningModeStore(box: box).save(ScreeningEngineMode.llm);
      final llmStub2 = _LlmStub(
          (_, __, ___) async => _openaiOk(_legacyHits([
                {'rule_id': 'v1', 'reason': 'x'},
              ])));
      final llm2 = await _screen(box, capture2, llmStub2).screen(['a']);
      expect(llm2, ['a']); // v1 已移除：命中无从谈起（未知 id 整批 fail-open）
      expect(_userOf(llmStub2.bodies.single), isNot(contains('剧透内容')));
      expect(llmStub2.calls, 1);
    });

    test('R2：增删改停一次保存后新实例重载一致，blob 键唯一', () async {
      final box = _Box();
      final store = JevRuleStore(box: box);
      await store.save(const JevRuleConfig(rules: [
        JevRule(id: 'c0', target: JevRuleTarget.comment, question: '待删除'),
        JevRule(id: 'c1', target: JevRuleTarget.comment, question: '原始问题'),
        JevRule(id: 'c2', target: JevRuleTarget.comment, question: '待停用'),
      ]));
      await store.save(const JevRuleConfig(rules: [
        JevRule(
          id: 'c1',
          target: JevRuleTarget.comment,
          question: '修改后的问题',
        ),
        JevRule(
          id: 'c2',
          target: JevRuleTarget.comment,
          question: '待停用',
          enabled: false,
        ),
        JevRule(id: 'c3', target: JevRuleTarget.comment, question: '新增问题'),
      ]));
      final reloaded = await JevRuleStore(box: box).load();
      final active = reloaded.activeFor(JevRuleTarget.comment);
      expect([for (final r in active) r.id], ['c1', 'c3']);
      expect(active.first.question, '修改后的问题');
      expect(
        box.map.keys.where((k) => k.toLowerCase().contains('rule')).toList(),
        [JevRuleStore.key],
      );
    });

    test('R3：双后端运行后无 legacy 规则副本键', () async {
      final box = await _llmVideoBox(decisionReady: true);
      final stub = _LlmStub((_, __, ___) async =>
          _openaiOk(_legacyHits([{'rule_id': 'v1', 'reason': '剧透'}])));
      final capture = _Capture();
      await _screen(box, capture, stub).screen(['a']); // LLM 后端
      await ScreeningModeStore(box: box).save(ScreeningEngineMode.decision);
      final capture2 = _Capture(
        reply: (_) async => _answers({
          'candidate_1': {'noul': 0.10},
        }),
      );
      await _screen(box, capture2, stub).screen(['a']); // Decision 后端
      expect(
        box.map.keys.where((k) => k.toLowerCase().contains('rule')).toList(),
        [JevRuleStore.key],
      );
      expect(box.map.containsKey(LlmVideoRuleStore.key), isFalse);
      expect(box.map.containsKey(ScreeningModeStore.key), isTrue);
    });

    test('R4：hideOnYes=false 的 No 反转与 choice hiddenOptions 映射', () async {
      final box = await _decisionBox();
      await JevRuleStore(box: box).save(const JevRuleConfig(rules: [
        JevRule(
          id: 'no1',
          target: JevRuleTarget.video,
          question: '是广告吗',
          threshold: .5,
          hideOnYes: false,
        ),
        JevRule(
          id: 'pick',
          target: JevRuleTarget.video,
          question: '哪类该隐藏',
          type: JevRuleType.choice,
          threshold: .9,
          options: [
            JevRuleOption(id: 'o1', label: '剧情'),
            JevRuleOption(id: 'o2', label: '广告'),
          ],
          hiddenOptions: {'o2'},
        ),
      ]));
      final capture = _Capture(
          reply: (_) async => _answers({
                'candidate_1_rule_1': _noul(0.10), // 自信的 No → 隐藏
                'candidate_1_rule_1_context': _noul(0.99),
                'candidate_1_rule_2': {
                  'type': 'choice',
                  'choice': 'o2',
                  'confidence': 0.97,
                  'probabilities': {'o1': 0.03, 'o2': 0.97},
                },
                'candidate_1_rule_2_context': _noul(0.99),
                'candidate_2_rule_1': _noul(0.90), // Yes → 1-0.9=0.1 < .5 保留
                'candidate_2_rule_1_context': _noul(0.99),
                'candidate_2_rule_2': {
                  'type': 'choice',
                  'choice': 'o1',
                  'confidence': 0.97,
                  'probabilities': {'o1': 0.97, 'o2': 0.03},
                },
                'candidate_2_rule_2_context': _noul(0.99),
              }));
      final stub = _LlmStub((_, __, ___) async =>
          throw StateError('LLM must not run in Decision mode'));
      final result = await _screen(box, capture, stub).screen(['a', 'b']);
      expect(result, ['b']);
      expect(stub.calls, 0);
      expect(capture.calls, 1);
      final criteria = jsonEncode(capture.bodies.single['questions']);
      expect(criteria, contains('广告'));
      expect(criteria, contains('剧情'));
    });
  });

  group('canonical LLM 协议端到端（L1/L2/L4，评论线）', () {
    test('L1：band 下界 × 阈值边界决定隐藏，low band 永不隐藏', () async {
      final box = await _commentBox();
      final stub = _LlmStub(
          (_, __, ___) async => _openaiOk(jsonEncode({
                'hits': [
                  {
                    'rule_id': 'candidate_1:r95',
                    'reason': '中置信',
                    'band': 'medium', // .80 < .95 保留
                  },
                  {
                    'rule_id': 'candidate_2:r95',
                    'reason': '高置信',
                    'band': 'high', // .95 >= .95 隐藏
                  },
                  {
                    'rule_id': 'candidate_3:r50',
                    'reason': '中置信',
                    'band': 'medium', // .80 >= .50 隐藏
                  },
                ],
              })));
      final r = await _comment(box, stub).filter(
        [_reply('a', id: 1), _reply('b', id: 2), _reply('c', id: 3)],
        screenLog: false,
      );
      expect(r.replies.map((x) => x.content.message), ['a']);
      expect(r.cacheable, isTrue);

      final lowStub = _LlmStub(
          (_, __, ___) async => _openaiOk(jsonEncode({
                'hits': [
                  {
                    'rule_id': 'candidate_1:r50',
                    'reason': '低置信',
                    'band': 'low', // 0 < .50 保留
                  },
                ],
              })));
      final low =
          await _comment(box, lowStub).filter([_reply('d', id: 4)], screenLog: false);
      expect(low.replies.map((x) => x.content.message), ['d']);
      expect(low.cacheable, isTrue);
    });

    test('L2：缺 band 或 band 非法整批保留，不污染缓存，下一 pass 仍发上游', () async {
      final box = await _commentBox();
      final reply = _reply('a', id: 1);
      final missing = _LlmStub(
          (_, __, ___) async => _openaiOk(jsonEncode({
                'hits': [
                  {'rule_id': 'candidate_1:r95', 'reason': '缺 band'},
                ],
              })));
      final r1 = await _comment(box, missing).filter([reply], screenLog: false);
      expect(r1.replies.map((x) => x.content.message), ['a']);
      expect(r1.cacheable, isFalse);

      final badBand = _LlmStub(
          (_, __, ___) async => _openaiOk(jsonEncode({
                'hits': [
                  {
                    'rule_id': 'candidate_1:r95',
                    'reason': 'band 非法',
                    'band': 'sure',
                  },
                ],
              })));
      final r2 = await _comment(box, badBand).filter([reply], screenLog: false);
      expect(r2.replies.map((x) => x.content.message), ['a']);
      expect(r2.cacheable, isFalse);
      expect(badBand.calls, 1); // 非法响应未写入缓存

      final good = _LlmStub(
          (_, __, ___) async => _openaiOk(jsonEncode({
                'hits': [
                  {
                    'rule_id': 'candidate_1:r95',
                    'reason': '垃圾',
                    'band': 'high',
                  },
                ],
              })));
      final r3 = await _comment(box, good).filter([reply], screenLog: false);
      expect(r3.replies, isEmpty); // 合法 high 隐藏
      expect(good.calls, 1); // 前两次未污染缓存
    });

    test('L4：合法空 hits 全保留且 keep 判定入缓存（不猜命中）', () async {
      final box = await _commentBox();
      final stub = _LlmStub(
          (_, __, ___) async => _openaiOk(jsonEncode({'hits': []})));
      final screening = _comment(box, stub);
      final r1 = await screening.filter([_reply('a', id: 1)], screenLog: false);
      expect(r1.replies.map((x) => x.content.message), ['a']);
      expect(r1.cacheable, isTrue);
      final r2 = await screening.filter([_reply('a', id: 1)], screenLog: false);
      expect(r2.replies.map((x) => x.content.message), ['a']);
      expect(stub.calls, 1); // 第二遍零上游：keep 已入缓存
    });
  });
}
