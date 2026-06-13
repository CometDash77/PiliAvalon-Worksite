import 'dart:io';

import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_store.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  setUp(() async {
    // Reset settings to defaults between tests.
    GStorage.setting.delete(SettingBoxKey.tagEnrichConcurrency);
    GStorage.setting.delete(SettingBoxKey.tagEnrichTimeout);
    GStorage.setting.delete(SettingBoxKey.tagEnrichCacheMaxMb);
    GStorage.setting.delete(SettingBoxKey.repeatExposureFilterEnabled);
    GStorage.setting.delete(SettingBoxKey.repeatExposureWindowDays);
    GStorage.setting.delete(SettingBoxKey.repeatExposureThreshold);
    GStorage.setting.delete(SettingBoxKey.repeatExposureCoolingDays);
    GStorage.setting.delete(SettingBoxKey.repeatExposureMaxCacheSize);
    await ShieldSettingsStore().clear();
  });

  tearDown(() async {
    await ShieldSettingsStore().clear();
  });

  group('recommendSettings', () {
    test('contains entries for tag enrichment', () {
      final list = recommendSettings;

      final titles = list.map((e) => e.effectiveTitle).toList();
      expect(titles, contains('标签获取并发数'));
      expect(titles, contains('标签获取超时'));
      expect(titles, contains('标签缓存上限'));
      expect(titles, contains('标签缓存状态'));
      expect(titles, isNot(contains('标签获取并发数（调试）')));
      expect(titles, isNot(contains('标签获取超时（调试）')));
      expect(titles, isNot(contains('标签缓存（调试）')));
    });

    test('tag enrichment entries appear after filter settings', () {
      final list = recommendSettings;

      final filterIdx = list.indexWhere(
        (e) => e.effectiveTitle == '过滤器也应用于相关视频',
      );
      expect(filterIdx, isNot(-1));

      final tagIdx1 = list.indexWhere(
        (e) => e.effectiveTitle == '标签获取并发数',
      );
      expect(tagIdx1, greaterThan(filterIdx));
    });

    test('concurrency entry shows default value of 5', () {
      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签获取并发数',
      );
      expect(entry.effectiveSubtitle, contains('当前: 5'));
      expect(entry.effectiveSubtitle, contains('默认5'));
      expect(entry.effectiveSubtitle, contains('范围1–10'));
    });

    test('timeout entry shows default value of 3s', () {
      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签获取超时',
      );
      expect(entry.effectiveSubtitle, contains('当前: 3s'));
      expect(entry.effectiveSubtitle, contains('默认3s'));
      expect(entry.effectiveSubtitle, contains('范围1–10'));
    });

    test('cache limit entry shows default value of 10MB', () {
      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签缓存上限',
      );
      expect(entry.effectiveSubtitle, contains('当前: 10MB'));
      expect(entry.effectiveSubtitle, contains('默认10MB'));
      expect(entry.effectiveSubtitle, contains('范围1–50'));
    });

    test('cache status entry shows estimated size and count', () {
      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签缓存状态',
      );
      expect(entry.effectiveSubtitle, contains('/ 10 MB'));
      expect(entry.effectiveSubtitle, isNot(contains('/ 200')));
      expect(entry.effectiveSubtitle, contains('点击可清空缓存'));
    });

    test('concurrency entry reflects stored setting', () {
      GStorage.setting.put(SettingBoxKey.tagEnrichConcurrency, 7);

      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签获取并发数',
      );
      expect(entry.effectiveSubtitle, contains('当前: 7'));
    });

    test('timeout entry reflects stored setting', () {
      GStorage.setting.put(SettingBoxKey.tagEnrichTimeout, 5);

      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签获取超时',
      );
      expect(entry.effectiveSubtitle, contains('当前: 5s'));
    });

    test('cache status reflects stored max size setting', () {
      GStorage.setting.put(SettingBoxKey.tagEnrichCacheMaxMb, 25);

      final list = recommendSettings;
      final entry = list.firstWhere(
        (e) => e.effectiveTitle == '标签缓存状态',
      );
      expect(entry.effectiveSubtitle, contains('/ 25 MB'));
    });

    test('total settings count includes new inline range filtering entries', () {
      final list = recommendSettings;
      expect(list.length, 17);
    });

    test('contains inline range filtering entries', () {
      final list = recommendSettings;
      final titles = list.map((e) => e.effectiveTitle).toList();

      expect(titles, contains('时长过滤'));
      expect(titles, contains('播放量过滤'));
      expect(titles, contains('弹幕量过滤'));
    });

    test('range filtering entries show default subtitle', () {
      final list = recommendSettings;

      for (final title in ['时长过滤', '播放量过滤', '弹幕量过滤']) {
        final entry = list.firstWhere((e) => e.effectiveTitle == title);
        expect(entry.effectiveSubtitle, '未设置');
      }
    });

    test('upstream filter entries are hidden from UI', () {
      final list = recommendSettings;
      final titles = list.map((e) => e.effectiveTitle).toList();

      expect(titles, isNot(contains('点赞率')));
      expect(titles, isNot(contains('视频时长')));
      expect(titles, isNot(contains('播放量')));
    });

    test('old recommend range shielding sub-page entry is removed', () {
      final list = recommendSettings;
      final titles = list.map((e) => e.effectiveTitle).toList();
      expect(titles, isNot(contains('推荐流范围屏蔽')));
    });

    test('range filtering entries appear before exposure tracker', () {
      final list = recommendSettings;

      final rangeIdx = list.indexWhere(
        (e) => e.effectiveTitle == '时长过滤',
      );
      expect(rangeIdx, isNot(-1));

      final exposureIdx = list.indexWhere(
        (e) => e.effectiveTitle == '启用重复曝光过滤',
      );
      expect(exposureIdx, isNot(-1));
      expect(rangeIdx, lessThan(exposureIdx));
    });

    test('contains repeat exposure filter settings', () {
      final list = recommendSettings;
      final titles = list.map((e) => e.effectiveTitle).toList();

      expect(titles, contains('启用重复曝光过滤'));
      expect(titles, contains('重复曝光统计窗口'));
      expect(titles, contains('重复曝光阈值'));
      expect(titles, contains('重复曝光冷却期'));
      expect(titles, contains('重复曝光缓存状态'));
    });

    test('repeat exposure settings show default values', () {
      final list = recommendSettings;

      expect(
        list
            .firstWhere((e) => e.effectiveTitle == '重复曝光统计窗口')
            .effectiveSubtitle,
        contains('当前: 7天'),
      );
      expect(
        list
            .firstWhere((e) => e.effectiveTitle == '重复曝光阈值')
            .effectiveSubtitle,
        contains('当前: 10次'),
      );
      expect(
        list
            .firstWhere((e) => e.effectiveTitle == '重复曝光冷却期')
            .effectiveSubtitle,
        contains('当前: 30天'),
      );
    });
  });

  group('range shielding boundary semantics', () {
    late ShieldSettingsStore store;

    setUp(() async {
      store = ShieldSettingsStore();
      final empty = ShieldRuleSet(rules: []);
      await store.save(empty);
    });

    tearDown(() async {
      final empty = ShieldRuleSet(rules: []);
      await store.save(empty);
    });

    test('lower-only rule shows lower-than subtitle', () async {
      final ruleSet = await store.load();
      final rule = ShieldRule(
        id: 'test-lo',
        type: ShieldRuleType.duration,
        matchMode: ShieldMatchMode.range,
        scope: ShieldScope.recommendation,
        action: ShieldAction.block,
        pattern: '..30',
        enabled: true,
        updatedAt: DateTime.now(),
      );
      await store.save(ruleSet.copyWith(rules: [rule]));

      final list = recommendSettings;
      final entry = list.firstWhere((e) => e.effectiveTitle == '时长过滤');
      expect(entry.effectiveSubtitle, '屏蔽 ≤ 30');
    });

    test('upper-only rule shows higher-than subtitle', () async {
      final ruleSet = await store.load();
      final rule = ShieldRule(
        id: 'test-hi',
        type: ShieldRuleType.playbackCount,
        matchMode: ShieldMatchMode.range,
        scope: ShieldScope.recommendation,
        action: ShieldAction.block,
        pattern: '500..',
        enabled: true,
        updatedAt: DateTime.now(),
      );
      await store.save(ruleSet.copyWith(rules: [rule]));

      final list = recommendSettings;
      final entry =
          list.firstWhere((e) => e.effectiveTitle == '播放量过滤');
      expect(entry.effectiveSubtitle, '屏蔽 ≥ 500');
    });

    test('both rules aggregate to combined subtitle', () async {
      final ruleSet = await store.load();
      final lo = ShieldRule(
        id: 'test-lo',
        type: ShieldRuleType.danmakuCount,
        matchMode: ShieldMatchMode.range,
        scope: ShieldScope.recommendation,
        action: ShieldAction.block,
        pattern: '..30',
        enabled: true,
        updatedAt: DateTime.now(),
      );
      final hi = ShieldRule(
        id: 'test-hi',
        type: ShieldRuleType.danmakuCount,
        matchMode: ShieldMatchMode.range,
        scope: ShieldScope.recommendation,
        action: ShieldAction.block,
        pattern: '200..',
        enabled: true,
        updatedAt: DateTime.now(),
      );
      await store.save(ruleSet.copyWith(rules: [lo, hi]));

      final list = recommendSettings;
      final entry =
          list.firstWhere((e) => e.effectiveTitle == '弹幕量过滤');
      expect(entry.effectiveSubtitle, '屏蔽 ≤ 30 及 ≥ 200');
    });

    test('empty rules default to 未设置', () async {
      final list = recommendSettings;
      for (final title in ['时长过滤', '播放量过滤', '弹幕量过滤']) {
        final entry = list.firstWhere((e) => e.effectiveTitle == title);
        expect(entry.effectiveSubtitle, '未设置');
      }
    });

    test('non-range rules for same type do not affect subtitle', () async {
      final ruleSet = await store.load();
      final nonRange = ShieldRule(
        id: 'test-keyword',
        type: ShieldRuleType.duration,
        matchMode: ShieldMatchMode.contains,
        scope: ShieldScope.recommendation,
        action: ShieldAction.block,
        pattern: 'test',
        enabled: true,
        updatedAt: DateTime.now(),
      );
      await store.save(ruleSet.copyWith(rules: [nonRange]));

      final list = recommendSettings;
      final entry = list.firstWhere((e) => e.effectiveTitle == '时长过滤');
      // Non-range rule should be ignored by _findRangeThresholds.
      expect(entry.effectiveSubtitle, '未设置');
    });
  });
}
