import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #115：直播保留/排除动作语义。
/// 保留规则命中才展示；排除命中即隐藏；上下文不足 fail-open 且不入缓存。
class _MemoryBox implements JevSettingsBox {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeCredentials implements JevCredentialStore {
  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;

  @override
  Future<String?> read() async => 'sk-test-key';

  @override
  Future<void> write(String apiKey) async {}

  @override
  Future<void> delete() async {}
}

class _ScriptedTransport {
  _ScriptedTransport(this.reply);

  /// 按请求体返回答案；返回 null 或抛出都算批次失败。
  final Object? Function(Map<String, Object?> body) reply;
  int calls = 0;

  JevTransport get transport =>
      ({required provider, required apiKey, required body}) async {
        calls++;
        return reply(body);
      };
}

Map<String, Object?> _noul(double p) => {'type': 'noul', 'noul': p};

JevRule keepRule() => const JevRule(
  id: 'keep-1',
  target: JevRuleTarget.live,
  question: '是否想看这位主播的直播？',
  action: JevRuleAction.keep,
);

JevRule hideRule() => const JevRule(
  id: 'hide-1',
  target: JevRuleTarget.live,
  question: '标题是否包含卖惨导流？',
);

Future<JevEvaluator> _evaluator(
  _MemoryBox box,
  List<JevRule> rules,
  JevTransport transport,
) async {
  await JevSettingsStore(box: box).save(
    const JevSettings(
      enabled: true,
      provider: JevProvider.typeSafe,
      providerConfirmed: true,
      surfaces: {JevSurface.live},
    ),
  );
  await JevRuleStore(box: box).save(
    JevRuleConfig(
      rules: rules,
      // 隔离内置负反馈问题，单独验证动作语义。
      disabledBuiltins: {JevRuleTarget.live},
    ),
  );
  return JevEvaluator(
    transport: transport,
    credentials: _FakeCredentials(),
    settings: JevSettingsStore(box: box),
  );
}

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevVerdictCache.resetCache();
  });

  test('keep rule hit keeps the card visible and caches the verdict', () async {
    final box = _MemoryBox();
    final transport = _ScriptedTransport(
      (body) => {
        'answers': {
          'candidate_1_rule_1': _noul(.97),
          'candidate_1_rule_1_context': _noul(.99),
        },
      },
    );
    final evaluator = await _evaluator(box, [keepRule()], transport.transport);
    final result = await evaluator.screen(
      [const JevCandidate(title: '保留命中主播')],
      surface: JevSurface.live,
    );
    expect(result.hidden, [false]);
    expect(result.status, JevScreenStatus.evaluated);

    // 已证实为可见 → 入缓存：二次访问零请求，传输层故障也不影响。
    final second = await evaluator.screen(
      [const JevCandidate(title: '保留命中主播')],
      surface: JevSurface.live,
    );
    expect(second.hidden, [false]);
    expect(second.requests, 0);
    expect(transport.calls, 1);
  });

  test('keep rule miss hides with a composite decision and caches it', () async {
    final box = _MemoryBox();
    final transport = _ScriptedTransport(
      (body) => {
        'answers': {
          'candidate_1_rule_1': _noul(.1),
          'candidate_1_rule_1_context': _noul(.99),
        },
      },
    );
    final evaluator = await _evaluator(box, [keepRule()], transport.transport);
    final result = await evaluator.screen(
      [const JevCandidate(title: '保留未命中主播')],
      surface: JevSurface.live,
    );
    expect(result.hidden, [true]);
    final decision = result.decisions.single;
    expect(decision, isNotNull);
    expect(decision!.noul, isNull);
    expect(decision.threshold, isNull);
    expect(decision.ruleId, isNull);
    expect(decision.reason, contains('保留规则'));

    final second = await evaluator.screen(
      [const JevCandidate(title: '保留未命中主播')],
      surface: JevSurface.live,
    );
    expect(second.hidden, [true]);
    expect(second.requests, 0);
    expect(transport.calls, 1);
  });

  test('exclude rule hits even when a keep rule would match', () async {
    final box = _MemoryBox();
    final transport = _ScriptedTransport(
      (body) => {
        'answers': {
          'candidate_1_rule_1': _noul(.97),
          'candidate_1_rule_1_context': _noul(.99),
          'candidate_0_rule_2': _noul(.97),
          'candidate_0_rule_2_context': _noul(.99),
        },
      },
    );
    final evaluator = await _evaluator(
      box,
      [hideRule(), keepRule()],
      transport.transport,
    );
    final result = await evaluator.screen(
      [const JevCandidate(title: '双命中主播')],
      surface: JevSurface.live,
    );
    expect(result.hidden, [true]);
    expect(result.decisions.single!.ruleId, 'hide-1');
  });

  test('insufficient keep context stays visible and never caches', () async {
    final box = _MemoryBox();
    var seen = 0;
    final transport = _ScriptedTransport((body) {
      seen++;
      return {
        'answers': {
          'candidate_1_rule_1_context': _noul(.5), // 上下文不足
          if (seen > 1) 'candidate_1_rule_1': _noul(.1),
        },
      };
    });
    final evaluator = await _evaluator(box, [keepRule()], transport.transport);
    final result = await evaluator.screen(
      [const JevCandidate(title: '信息不足主播')],
      surface: JevSurface.live,
    );
    // fail-open：保留规则无法证实，保持可见。
    expect(result.hidden, [false]);

    final second = await evaluator.screen(
      [const JevCandidate(title: '信息不足主播')],
      surface: JevSurface.live,
    );
    // 不入缓存：第二次仍然真实发问。
    expect(second.requests, 1);
    expect(transport.calls, 2);
  });

  test('hide rules keep their pre-#115 semantics alongside keep rules', () async {
    final box = _MemoryBox();
    final transport = _ScriptedTransport(
      (body) => {
        'answers': {
          'candidate_1_rule_1': _noul(.97),
          'candidate_1_rule_1_context': _noul(.99),
        },
      },
    );
    final evaluator = await _evaluator(box, [hideRule()], transport.transport);
    final result = await evaluator.screen(
      [const JevCandidate(title: '排除命中主播')],
      surface: JevSurface.live,
    );
    expect(result.hidden, [true]);
    expect(result.decisions.single!.ruleId, 'hide-1');
    expect(result.decisions.single!.threshold, .95);
  });
}
