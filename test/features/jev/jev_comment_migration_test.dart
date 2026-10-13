import 'package:PiliPlus/features/jev/jev_comment_migration.dart';
import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryBox implements JevSettingsBox {
  final values = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late MemoryBox box;
  late JevSettingsStore settingsStore;
  late JevRuleStore ruleStore;

  setUp(() {
    JevCommentCriteriaMigration.resetForTest();
    box = MemoryBox();
    settingsStore = JevSettingsStore(box: box);
    ruleStore = JevRuleStore(box: box);
  });

  Future<JevRuleConfig> savedConfig() => ruleStore.load();
  Future<JevSettings> savedSettings() => settingsStore.load();
  bool hasRetiredKeys() =>
      box.values.containsKey(JevSettingsStore.commentEnabledKey) ||
      box.values.containsKey(JevSettingsStore.commentCriteriaKey);

  test('no retired keys is a no-op', () async {
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    expect((await savedConfig()).rules, isEmpty);
    expect((await savedSettings()).surfaces, isEmpty);
    expect(hasRetiredKeys(), isFalse);
  });

  test('switch on plus custom criteria seeds a rule and turns the surface on',
      () async {
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '  隐藏广告  ');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    final config = await savedConfig();
    expect(config.rules, hasLength(1));
    final rule = config.rules.single;
    expect(rule.id, JevCommentCriteriaMigration.migratedRuleId);
    expect(rule.target, JevRuleTarget.comment);
    expect(rule.question, '隐藏广告');
    expect(rule.type, JevRuleType.noul);
    expect(rule.threshold, JevLimits.hideNoulThreshold);
    expect(rule.enabled, isTrue);
    final settings = await savedSettings();
    expect(settings.surfaces, contains(JevSurface.comment));
    expect(hasRetiredKeys(), isFalse);
  });

  test('switch on plus retired default text still seeds the rule', () async {
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(
      JevSettingsStore.commentCriteriaKey,
      JevCommentCriteriaMigration.retiredDefaultCriteria,
    );
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    expect((await savedConfig()).rules, hasLength(1));
    expect((await savedSettings()).surfaces, contains(JevSurface.comment));
    expect(hasRetiredKeys(), isFalse);
  });

  test('switch off plus default text migrates nothing but clears the keys',
      () async {
    await box.put(JevSettingsStore.commentEnabledKey, false);
    await box.put(
      JevSettingsStore.commentCriteriaKey,
      JevCommentCriteriaMigration.retiredDefaultCriteria,
    );
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    expect((await savedConfig()).rules, isEmpty);
    expect((await savedSettings()).surfaces, isEmpty);
    expect(hasRetiredKeys(), isFalse);
  });

  test('switch off plus authored text seeds the rule but leaves the surface',
      () async {
    await box.put(JevSettingsStore.commentEnabledKey, false);
    await box.put(JevSettingsStore.commentCriteriaKey, '隐藏剧透');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    expect((await savedConfig()).rules, hasLength(1));
    expect((await savedSettings()).surfaces, isEmpty);
    expect(hasRetiredKeys(), isFalse);
  });

  test('switch on plus empty criteria only turns the surface on', () async {
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '   ');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    expect((await savedConfig()).rules, isEmpty);
    expect((await savedSettings()).surfaces, contains(JevSurface.comment));
    expect(hasRetiredKeys(), isFalse);
  });

  test('an identical rule question is not seeded twice', () async {
    await ruleStore.save(
      JevRuleConfig(
        rules: [
          JevRule(
            id: 'user-rule',
            target: JevRuleTarget.comment,
            question: '隐藏广告',
          ),
        ],
      ),
    );
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '隐藏广告');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    final config = await savedConfig();
    expect(config.rules, hasLength(1));
    expect(config.rules.single.id, 'user-rule');
    expect(hasRetiredKeys(), isFalse);
  });

  test('a full comment target keeps the retired keys for a later retry',
      () async {
    final rules = List.generate(JevRule.maxRulesPerTarget, (i) {
      return JevRule(
        id: 'r$i',
        target: JevRuleTarget.comment,
        question: '问题 $i',
      );
    });
    await ruleStore.save(JevRuleConfig(rules: rules));
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '隐藏广告');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    final config = await savedConfig();
    expect(config.rules, hasLength(JevRule.maxRulesPerTarget));
    expect(
      config.rules.every(
        (rule) => rule.id != JevCommentCriteriaMigration.migratedRuleId,
      ),
      isTrue,
    );
    expect(hasRetiredKeys(), isTrue);
  });

  test('over-long criteria keeps the retired keys for a later retry',
      () async {
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '长' * 1001);
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    expect((await savedConfig()).rules, isEmpty);
    expect(hasRetiredKeys(), isTrue);
  });

  test('the migration runs once per process', () async {
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '隐藏广告');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    // A later launch would see fresh keys again; within one process the
    // second call must not reprocess anything.
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '另一条标准');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    final config = await savedConfig();
    expect(config.rules, hasLength(1));
    expect(config.rules.single.question, '隐藏广告');
    expect(hasRetiredKeys(), isTrue);
  });

  test('existing non-comment rules are preserved', () async {
    await ruleStore.save(
      JevRuleConfig(
        rules: [
          JevRule(
            id: 'video-rule',
            target: JevRuleTarget.video,
            question: '标题党?',
          ),
        ],
      ),
    );
    await box.put(JevSettingsStore.commentEnabledKey, true);
    await box.put(JevSettingsStore.commentCriteriaKey, '隐藏广告');
    await JevCommentCriteriaMigration.ensureRun(
      settings: settingsStore,
      rules: ruleStore,
    );
    final config = await savedConfig();
    expect(config.rules.map((rule) => rule.id), containsAll([
      'video-rule',
      JevCommentCriteriaMigration.migratedRuleId,
    ]));
    expect(config.disabledBuiltins, isEmpty);
  });
}
