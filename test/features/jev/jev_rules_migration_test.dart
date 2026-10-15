import 'dart:convert';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/llm/llm_rules.dart' show videoRuleVersion;
import 'package:flutter_test/flutter_test.dart';

class MemoryBox implements JevSettingsBox {
  final values = <String, Object?>{};
  @override
  Object? get(String key, {Object? defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

LlmVideoRule video(String id, {String? text, bool enabled = true}) =>
    LlmVideoRule(id: id, text: text ?? '屏蔽$id 类视频', enabled: enabled);

Map<String, Object?> legacyBlob(List<LlmVideoRule> rules) => {
  'version': 1,
  'rules': rules.map((r) => r.toJson()).toList(),
};

void main() {

  test('migrates the legacy blob losslessly and retires the key', () async {
    final box = MemoryBox();
    // 4000 runes：旧版上限原文无损。
    // ponytail: non-const to keep analyzer's const evaluator happy.
    final longText = '剧' * 4000;
    final legacy = LlmVideoRuleStore(box: box);
    await legacy.save(
      LlmVideoRuleConfig(rules: [video('v1', text: longText, enabled: false)]),
    );
    final store = JevRuleStore(box: box);
    await store.migrateLegacyLlmVideoRules();
    final config = await store.load();
    expect(config.videoTextRules.single.id, 'v1');
    expect(config.videoTextRules.single.text, longText);
    expect(config.videoTextRules.single.enabled, isFalse);
    expect(config.rules, isEmpty); // typed 规则不受迁移影响。
    expect(box.values[LlmVideoRuleStore.key], isNull);
  });

  test('migration is idempotent across repeated calls', () async {
    final box = MemoryBox();
    await LlmVideoRuleStore(box: box)
        .save(LlmVideoRuleConfig(rules: [video('v1'), video('v2')]));
    final store = JevRuleStore(box: box);
    await store.migrateLegacyLlmVideoRules();
    final once = await store.load();
    // 同实例重复调用被实例级一次性守卫短路；旧键已删，再次迁移是 no-op。
    await store.migrateLegacyLlmVideoRules();
    final twice = await store.load();
    expect(twice.videoTextRules.length, 2);
    expect(twice.videoTextRules.first.id, once.videoTextRules.first.id);
    expect(box.values[LlmVideoRuleStore.key], isNull);
  });

  test('a corrupt legacy blob fails open and is kept for inspection', () async {
    final box = MemoryBox();
    await JevRuleStore(box: box)
        .save(JevRuleConfig(videoTextRules: [video('u1')]));
    box.values[LlmVideoRuleStore.key] = '{not json';
    final store = JevRuleStore(box: box);
    await store.migrateLegacyLlmVideoRules();
    expect((await store.load()).videoTextRules.single.id, 'u1');
    expect(box.values[LlmVideoRuleStore.key], '{not json');
  });

  test(
    'a corrupt unified blob is never overwritten by the legacy set',
    () async {
      final box = MemoryBox();
      await LlmVideoRuleStore(box: box)
          .save(LlmVideoRuleConfig(rules: [video('v1')]));
      box.values[JevRuleStore.key] = '{corrupt';
      final store = JevRuleStore(box: box);
      await store.migrateLegacyLlmVideoRules();
      expect(box.values[JevRuleStore.key], '{corrupt');
      expect(box.values[LlmVideoRuleStore.key], isNotNull);
    },
  );

  test(
    'a merged set beyond the cap migrates nothing and keeps both keys',
    () async {
      final box = MemoryBox();
      await JevRuleStore(box: box).save(
        JevRuleConfig(
          videoTextRules: [for (var i = 0; i < 5; i++) video('u$i')],
        ),
      );
      await LlmVideoRuleStore(box: box).save(
        LlmVideoRuleConfig(
          rules: [
            for (var i = 0; i < LlmVideoRule.maxRulesPerSurface; i++)
              video('v$i'),
          ],
        ),
      );
      final store = JevRuleStore(box: box);
      await store.migrateLegacyLlmVideoRules();
      expect((await store.load()).videoTextRules.length, 5);
      expect(box.values[LlmVideoRuleStore.key], isNotNull);
    },
  );

  test('upsert merge: unified side wins on id collision', () async {
    final box = MemoryBox();
    await JevRuleStore(box: box)
        .save(JevRuleConfig(videoTextRules: [video('v1', text: '统一侧文本')]));
    await LlmVideoRuleStore(box: box).save(
      LlmVideoRuleConfig(
        rules: [
          video('v1', text: '旧侧文本'),
          video('v2'),
        ],
      ),
    );
    final store = JevRuleStore(box: box);
    await store.migrateLegacyLlmVideoRules();
    final rules = (await store.load()).videoTextRules;
    expect(rules.length, 2);
    expect(rules.singleWhere((r) => r.id == 'v1').text, '统一侧文本');
    expect(rules.singleWhere((r) => r.id == 'v2').text, '屏蔽v2 类视频');
    expect(box.values[LlmVideoRuleStore.key], isNull);
  });

  test('cache generation is stable across the migration', () async {
    final box = MemoryBox();
    final legacy = LlmVideoRuleStore(box: box);
    await legacy.save(
      LlmVideoRuleConfig(rules: [video('v1'), video('v2', enabled: false)]),
    );
    final before = videoRuleVersion((await legacy.load()).activeFor());
    final store = JevRuleStore(box: box);
    await store.migrateLegacyLlmVideoRules();
    final after = videoRuleVersion((await store.load()).activeVideoTextRules());
    expect(after, before);
  });

  test('one snapshot feeds both backends', () async {
    final box = MemoryBox();
    final store = JevRuleStore(box: box);
    await store.save(
      const JevRuleConfig(
        rules: [
          JevRule(id: 'c1', target: JevRuleTarget.comment, question: '是否人身攻击？'),
        ],
        videoTextRules: [LlmVideoRule(id: 'v1', text: '屏蔽标题党')],
      ),
    );
    final config = await store.load();
    // Decision 后端消费 typed 判断规则，LLM 后端消费视频文本规则——同一快照。
    expect(config.activeFor(JevRuleTarget.comment).single.id, 'c1');
    expect(config.activeVideoTextRules().single.id, 'v1');
    expect(jsonDecode(box.values[JevRuleStore.key] as String), isMap);
  });
}
