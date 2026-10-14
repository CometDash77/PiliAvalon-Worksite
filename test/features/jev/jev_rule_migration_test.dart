import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBox implements JevSettingsBox {
  final values = <String, Object?>{};
  bool failWrites = false;

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failWrites) throw StateError('write failed');
    values.remove(key);
  }
}

Future<void> _seedLegacy(JevSettingsBox box, List<LlmVideoRule> rules) =>
    box.put(
      LlmVideoRuleStore.key,
      jsonEncode({
        'version': 1,
        'rules': [for (final r in rules) r.toJson()],
      }),
    );

void main() {
  late _MemoryBox box;
  late JevRuleStore store;

  setUp(() {
    box = _MemoryBox();
    store = JevRuleStore(box: box);
  });

  bool hasLegacyKey() => box.values.containsKey(LlmVideoRuleStore.key);

  test('legacy rules migrate losslessly; typed rules stay untouched', () async {
    await store.save(
      const JevRuleConfig(
        rules: [
          JevRule(id: 't1', target: JevRuleTarget.video, question: '是否剧透？'),
        ],
        disabledBuiltins: {JevRuleTarget.live},
      ),
    );
    const legacy = [
      LlmVideoRule(id: 'v1', text: '剧透内容'),
      LlmVideoRule(id: 'v2', text: '广告标题', enabled: false),
    ];
    await _seedLegacy(box, legacy);
    await store.migrateLegacyLlmVideoRules();
    final config = await store.load();
    expect(
      config.videoTextRules.map((r) => r.toJson()).toList(),
      legacy.map((r) => r.toJson()).toList(),
    );
    expect(config.rules.single.id, 't1');
    expect(config.disabledBuiltins, {JevRuleTarget.live});
    expect(hasLegacyKey(), isFalse);
  });

  test('migration is idempotent', () async {
    await _seedLegacy(box, [const LlmVideoRule(id: 'v1', text: '剧透内容')]);
    await store.migrateLegacyLlmVideoRules();
    await store.migrateLegacyLlmVideoRules();
    final config = await store.load();
    expect(config.videoTextRules, hasLength(1));
    expect(hasLegacyKey(), isFalse);
  });

  test('a unified edit wins over the legacy blob on id collision', () async {
    await store.save(
      const JevRuleConfig(
        videoTextRules: [LlmVideoRule(id: 'v1', text: '用户改写')],
      ),
    );
    await _seedLegacy(box, [const LlmVideoRule(id: 'v1', text: '原始文案')]);
    await store.migrateLegacyLlmVideoRules();
    final config = await store.load();
    expect(config.videoTextRules.single.text, '用户改写');
    expect(hasLegacyKey(), isFalse);
  });

  test('over-cap legacy sets migrate nothing and keep the legacy key', () async {
    await store.save(
      JevRuleConfig(
        videoTextRules: [
          for (var i = 0; i < 16; i++) LlmVideoRule(id: 'u$i', text: '统一 $i'),
        ],
      ),
    );
    await _seedLegacy(box, [
      for (var i = 0; i < 5; i++) LlmVideoRule(id: 'l$i', text: '旧 $i'),
    ]);
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules, hasLength(16));
    expect(hasLegacyKey(), isTrue);
  });

  test('a legacy set that fits the cap migrates fully', () async {
    await store.save(
      JevRuleConfig(
        videoTextRules: [
          for (var i = 0; i < 18; i++) LlmVideoRule(id: 'u$i', text: '统一 $i'),
        ],
      ),
    );
    await _seedLegacy(box, const [
      LlmVideoRule(id: 'l1', text: '旧一'),
      LlmVideoRule(id: 'l2', text: '旧二'),
    ]);
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules, hasLength(20));
    expect(hasLegacyKey(), isFalse);
  });

  test('a corrupt legacy blob is a no-op and is kept', () async {
    await box.put(LlmVideoRuleStore.key, 'not-json');
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules, isEmpty);
    expect(hasLegacyKey(), isTrue);
  });

  test('an unknown legacy blob version is a no-op and is kept', () async {
    await box.put(
      LlmVideoRuleStore.key,
      jsonEncode({'version': 2, 'rules': []}),
    );
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules, isEmpty);
    expect(hasLegacyKey(), isTrue);
  });

  test('a corrupt unified blob blocks the merge and stays untouched', () async {
    await box.put(JevRuleStore.key, 'not-json');
    await _seedLegacy(box, [const LlmVideoRule(id: 'v1', text: '剧透内容')]);
    await store.migrateLegacyLlmVideoRules();
    expect(box.values[JevRuleStore.key], 'not-json');
    expect(hasLegacyKey(), isTrue);
  });

  test('no legacy key is a no-op', () async {
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules, isEmpty);
  });

  test('a failed write keeps the legacy key and allows a retry', () async {
    await _seedLegacy(box, [const LlmVideoRule(id: 'v1', text: '剧透内容')]);
    box.failWrites = true;
    await expectLater(store.migrateLegacyLlmVideoRules(), throwsStateError);
    expect(hasLegacyKey(), isTrue);
    box.failWrites = false;
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules.single.text, '剧透内容');
    expect(hasLegacyKey(), isFalse);
  });

  test('one snapshot feeds both backends without re-entering rules', () async {
    await store.save(
      const JevRuleConfig(
        rules: [
          JevRule(id: 't1', target: JevRuleTarget.video, question: '是否剧透？'),
        ],
        videoTextRules: [LlmVideoRule(id: 'v1', text: '剧透内容')],
      ),
    );
    var config = await store.load();
    // Decision 编译点：typed 规则按场景取用并编译。
    expect(config.activeFor(JevRuleTarget.video), hasLength(1));
    expect(
      config.activeFor(JevRuleTarget.video).single.compile('c0'),
      isNotNull,
    );
    // 通用 LLM 编译点：视频文本规则取自同一快照。
    expect(config.activeVideoTextRules().single.id, 'v1');
    // 切换语义：停用后两编译点同步可见，无需重新录入同一条规则。
    await store.save(
      config.copyWith(
        rules: [config.rules.single.copyWith(enabled: false)],
        videoTextRules: [config.videoTextRules.single.copyWith(enabled: false)],
      ),
    );
    config = await store.load();
    expect(config.activeFor(JevRuleTarget.video), isEmpty);
    expect(config.activeVideoTextRules(), isEmpty);
  });
}
