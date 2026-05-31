import 'dart:io';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory storageDir;
  late String originalBanPattern;
  late int originalDuration;
  late int originalPlay;
  late int originalLikeRatio;
  late bool originalExemptFollowed;
  late bool originalApplyRelated;

  final fixedNow = DateTime(2026, 5, 31, 12);

  setUpAll(() async {
    storageDir = await Directory.systemTemp.createTemp(
      'shielding_migration_test_',
    );
    appSupportDirPath = storageDir.path;
    await GStorage.init();
  });

  setUp(() {
    originalBanPattern = RecommendFilter.rcmdRegExp.pattern;
    originalDuration = RecommendFilter.minDurationForRcmd;
    originalPlay = RecommendFilter.minPlayForRcmd;
    originalLikeRatio = RecommendFilter.minLikeRatioForRecommend;
    originalExemptFollowed = RecommendFilter.exemptFilterForFollowed;
    originalApplyRelated = RecommendFilter.applyFilterToRelatedVideos;

    RecommendFilter.rcmdRegExp = RegExp('', caseSensitive: false);
    RecommendFilter.minDurationForRcmd = 0;
    RecommendFilter.minPlayForRcmd = 0;
    RecommendFilter.minLikeRatioForRecommend = 0;
    RecommendFilter.exemptFilterForFollowed = false;
    RecommendFilter.applyFilterToRelatedVideos = false;
  });

  tearDown(() {
    RecommendFilter.rcmdRegExp = RegExp(
      originalBanPattern,
      caseSensitive: false,
    );
    RecommendFilter.minDurationForRcmd = originalDuration;
    RecommendFilter.minPlayForRcmd = originalPlay;
    RecommendFilter.minLikeRatioForRecommend = originalLikeRatio;
    RecommendFilter.exemptFilterForFollowed = originalExemptFollowed;
    RecommendFilter.applyFilterToRelatedVideos = originalApplyRelated;
  });

  tearDownAll(() async {
    await GStorage.close();
    if (storageDir.existsSync()) {
      await storageDir.delete(recursive: true);
    }
  });

  group('RecommendFilterAnalyzer', () {
    test('empty legacy config produces no suggested rules', () {
      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);

      expect(report.analyzedAt, fixedNow);
      expect(report.candidates, isNotEmpty);
      expect(
        report.candidates.every((candidate) => candidate.suggestedRule == null),
        isTrue,
      );
      expect(
        report.candidates.every((candidate) => candidate.toBeApplied() == null),
        isTrue,
      );
    });

    test('pipe-separated ban words create imported exact keyword rules', () {
      RecommendFilter.rcmdRegExp = RegExp('猫|狗|鱼', caseSensitive: false);

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidates = report.candidates
          .where(
            (candidate) => candidate.oldSettingKey == 'banWordForRecommend',
          )
          .toList();

      expect(candidates, hasLength(3));
      expect(
        candidates.map((candidate) => candidate.suggestedRule?.pattern),
        unorderedEquals(['猫', '狗', '鱼']),
      );

      for (final candidate in candidates) {
        final rule = candidate.suggestedRule;
        expect(candidate.feasibility, MigrationFeasibility.direct);
        expect(candidate.oldSettingValue, '猫|狗|鱼');
        expect(rule, isNotNull);
        expect(rule!.type, ShieldRuleType.keyword);
        expect(rule.matchMode, ShieldMatchMode.exact);
        expect(rule.scope, ShieldScope.recommendation);
        expect(rule.action, ShieldAction.block);
        expect(rule.enabled, isTrue);
        expect(rule.source, ShieldRuleSource.imported);
        expect(rule.updatedAt, fixedNow);
        expect(candidate.toBeApplied(), same(rule));
      }
    });

    test('complex ban word regex creates a single imported regex rule', () {
      RecommendFilter.rcmdRegExp = RegExp(
        r'抽奖\d{3,}|(搬运|营销)号',
        caseSensitive: false,
      );

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidates = report.candidates
          .where(
            (candidate) => candidate.oldSettingKey == 'banWordForRecommend',
          )
          .toList();

      expect(candidates, hasLength(1));
      final rule = candidates.single.suggestedRule;
      expect(candidates.single.feasibility, MigrationFeasibility.direct);
      expect(rule, isNotNull);
      expect(rule!.type, ShieldRuleType.keyword);
      expect(rule.matchMode, ShieldMatchMode.regex);
      expect(rule.pattern, r'抽奖\d{3,}|(搬运|营销)号');
      expect(rule.source, ShieldRuleSource.imported);
    });

    test('duration threshold is unsupported and cannot be applied', () {
      RecommendFilter.minDurationForRcmd = 60;

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidate = report.candidates.firstWhere(
        (candidate) => candidate.oldSettingKey == 'minDurationForRcmd',
      );

      expect(candidate.oldSettingValue, '60');
      expect(candidate.feasibility, MigrationFeasibility.unsupported);
      expect(candidate.suggestedRule, isNull);
      expect(candidate.toBeApplied(), isNull);
      expect(candidate.notes, contains('数值阈值'));
    });

    test('play threshold is unsupported and cannot be applied', () {
      RecommendFilter.minPlayForRcmd = 10000;

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidate = report.candidates.firstWhere(
        (candidate) => candidate.oldSettingKey == 'minPlayForRcmd',
      );

      expect(candidate.oldSettingValue, '10000');
      expect(candidate.feasibility, MigrationFeasibility.unsupported);
      expect(candidate.suggestedRule, isNull);
      expect(candidate.toBeApplied(), isNull);
      expect(candidate.notes, contains('播放量阈值'));
    });

    test('like ratio threshold is unsupported and cannot be applied', () {
      RecommendFilter.minLikeRatioForRecommend = 3;

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidate = report.candidates.firstWhere(
        (candidate) => candidate.oldSettingKey == 'minLikeRatioForRecommend',
      );

      expect(candidate.oldSettingValue, '3');
      expect(candidate.feasibility, MigrationFeasibility.unsupported);
      expect(candidate.suggestedRule, isNull);
      expect(candidate.toBeApplied(), isNull);
      expect(candidate.notes, contains('点赞率阈值'));
    });

    test('followed exemption is partial and records isFollowed dependency', () {
      RecommendFilter.exemptFilterForFollowed = true;

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidate = report.candidates.firstWhere(
        (candidate) => candidate.oldSettingKey == 'exemptFilterForFollowed',
      );

      expect(candidate.oldSettingValue, 'true');
      expect(candidate.feasibility, MigrationFeasibility.partial);
      expect(candidate.suggestedRule, isNull);
      expect(candidate.toBeApplied(), isNull);
      expect(candidate.notes, contains('isFollowed'));
    });

    test('related videos switch is partial compatibility metadata', () {
      RecommendFilter.applyFilterToRelatedVideos = true;

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidate = report.candidates.firstWhere(
        (candidate) => candidate.oldSettingKey == 'applyFilterToRelatedVideos',
      );

      expect(candidate.oldSettingValue, 'true');
      expect(candidate.feasibility, MigrationFeasibility.partial);
      expect(candidate.suggestedRule, isNull);
      expect(candidate.toBeApplied(), isNull);
      expect(candidate.notes, contains('兼容层'));
    });

    test('tag capability has no legacy rule to import', () {
      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);
      final candidate = report.candidates.firstWhere(
        (candidate) => candidate.oldSettingKey == 'tag',
      );

      expect(candidate.feasibility, MigrationFeasibility.direct);
      expect(candidate.suggestedRule, isNull);
      expect(candidate.toBeApplied(), isNull);
      expect(candidate.notes, contains('tag/tags payload'));
    });

    test('report counts feasibility classes', () {
      RecommendFilter.rcmdRegExp = RegExp('猫|狗', caseSensitive: false);
      RecommendFilter.minDurationForRcmd = 60;
      RecommendFilter.minPlayForRcmd = 10000;
      RecommendFilter.minLikeRatioForRecommend = 3;
      RecommendFilter.exemptFilterForFollowed = true;
      RecommendFilter.applyFilterToRelatedVideos = true;

      final report = RecommendFilterAnalyzer.analyze(now: fixedNow);

      expect(report.directCount, 3);
      expect(report.partialCount, 2);
      expect(report.unsupportedCount, 3);
      expect(report.candidates, hasLength(8));
    });
  });

  group('ShieldMigrationCandidate', () {
    test('direct candidate toBeApplied returns suggested rule', () {
      final rule = ShieldRule(
        id: 'candidate-rule',
        type: ShieldRuleType.keyword,
        matchMode: ShieldMatchMode.exact,
        scope: ShieldScope.recommendation,
        action: ShieldAction.block,
        pattern: 'candidate',
        updatedAt: fixedNow,
        source: ShieldRuleSource.imported,
      );
      final candidate = ShieldMigrationCandidate(
        oldSettingKey: 'banWordForRecommend',
        oldSettingValue: 'candidate',
        feasibility: MigrationFeasibility.direct,
        suggestedRule: rule,
      );

      expect(candidate.toBeApplied(), same(rule));
    });

    test('unsupported candidate toBeApplied returns null', () {
      const candidate = ShieldMigrationCandidate(
        oldSettingKey: 'minDurationForRcmd',
        oldSettingValue: '60',
        feasibility: MigrationFeasibility.unsupported,
      );

      expect(candidate.toBeApplied(), isNull);
    });
  });
}
