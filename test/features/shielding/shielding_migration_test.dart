// ignore_for_file: prefer_const_declarations

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:flutter_test/flutter_test.dart';

/// 旧过滤配置的零值基线：等价于旧测试 setUp 里重置后的 RecommendFilter 静态量。
RecommendationFilterConfig zeroConfig({
  RegExp? rcmdRegExp,
  int minDurationForRcmd = 0,
  int minPlayForRcmd = 0,
  int minLikeRatioForRecommend = 0,
  bool exemptFilterForFollowed = false,
  bool applyFilterToRelatedVideos = false,
}) {
  return RecommendationFilterConfig(
    rcmdRegExp: rcmdRegExp,
    minDurationForRcmd: minDurationForRcmd,
    minPlayForRcmd: minPlayForRcmd,
    minLikeRatioForRecommend: minLikeRatioForRecommend,
    exemptFilterForFollowed: exemptFilterForFollowed,
    applyFilterToRelatedVideos: applyFilterToRelatedVideos,
  );
}

void main() {
  group('RecommendFilterAnalyzer', () {
    test('all-zero config produces no direct migration rules', () {
      final report = RecommendFilterAnalyzer.analyze(zeroConfig());

      // All zero-value settings should have suggestedRule == null
      for (final candidate in report.candidates) {
        if (candidate.confidence == 0.0) {
          expect(
            candidate.suggestedRule,
            isNull,
            reason: '${candidate.oldSettingKey} should have no suggested rule',
          );
          expect(candidate.toBeApplied(), isNull);
        }
      }
    });

    test('pipe-separated ban words produce one keyword rule per word', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(rcmdRegExp: RegExp('猫|狗|鱼', caseSensitive: false)),
      );
      final banCandidates = report.candidates
          .where((c) => c.oldSettingKey == 'banWordForRecommend')
          .toList();

      // 3 words → 3 candidates
      expect(banCandidates, hasLength(3));
      for (final candidate in banCandidates) {
        expect(candidate.feasibility, MigrationFeasibility.direct);
        expect(candidate.suggestedRule, isNotNull);
        expect(candidate.suggestedRule!.type, ShieldRuleType.keyword);
        expect(candidate.suggestedRule!.matchMode, ShieldMatchMode.contains);
        expect(candidate.suggestedRule!.action, ShieldAction.block);
        expect(candidate.suggestedRule!.scope, ShieldScope.recommendation);
        expect(candidate.suggestedRule!.source, ShieldRuleSource.imported);
        expect(candidate.suggestedRule!.enabled, isTrue);

        // toBeApplied returns the rule without side effects
        final applied = candidate.toBeApplied();
        expect(applied, same(candidate.suggestedRule));
      }

      // Each word is a separate rule
      expect(
        banCandidates.map((c) => c.suggestedRule!.pattern),
        containsAll(['猫', '狗', '鱼']),
      );
    });

    test('complex regex ban word produces single regex rule', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(rcmdRegExp: RegExp(r'测试\d{3,}', caseSensitive: false)),
      );
      final banCandidates = report.candidates
          .where((c) => c.oldSettingKey == 'banWordForRecommend')
          .toList();

      // Complex regex → single regex rule
      expect(banCandidates, hasLength(1));
      final candidate = banCandidates.single;
      expect(candidate.feasibility, MigrationFeasibility.direct);
      expect(candidate.suggestedRule!.matchMode, ShieldMatchMode.regex);
      expect(candidate.suggestedRule!.pattern, r'测试\d{3,}');
    });

    test('duration threshold is unsupported and has no suggested rule', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(minDurationForRcmd: 60),
      );
      final durCandidate = report.candidates.firstWhere(
        (c) => c.oldSettingKey == 'minDurationForRcmd',
      );

      expect(durCandidate.feasibility, MigrationFeasibility.unsupported);
      expect(durCandidate.suggestedRule, isNull);
      expect(durCandidate.toBeApplied(), isNull);
    });

    test('play count threshold is unsupported', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(minPlayForRcmd: 100),
      );
      final playCandidate = report.candidates.firstWhere(
        (c) => c.oldSettingKey == 'minPlayForRcmd',
      );

      expect(playCandidate.feasibility, MigrationFeasibility.unsupported);
      expect(playCandidate.suggestedRule, isNull);
    });

    test('like ratio threshold is unsupported', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(minLikeRatioForRecommend: 2),
      );
      final likeCandidate = report.candidates.firstWhere(
        (c) => c.oldSettingKey == 'minLikeRatioForRecommend',
      );

      expect(likeCandidate.feasibility, MigrationFeasibility.unsupported);
      expect(likeCandidate.suggestedRule, isNull);
    });

    test('exemptFollowed is partial and notes mention isFollowed gap', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(exemptFilterForFollowed: true),
      );
      final exemptCandidate = report.candidates.firstWhere(
        (c) => c.oldSettingKey == 'exemptFilterForFollowed',
      );

      expect(exemptCandidate.feasibility, MigrationFeasibility.partial);
      expect(exemptCandidate.notes, contains('isFollowed'));
    });

    test('applyToRelatedVideos notes Phase 1 behavior', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(applyFilterToRelatedVideos: true),
      );
      final relatedCandidate = report.candidates.firstWhere(
        (c) => c.oldSettingKey == 'applyFilterToRelatedVideos',
      );

      expect(relatedCandidate.feasibility, MigrationFeasibility.partial);
      expect(relatedCandidate.notes, contains('Phase 1'));
    });

    test(
      'tag capability analysis reports ready state regardless of config',
      () {
        final report = RecommendFilterAnalyzer.analyze(zeroConfig());
        final tagCandidate = report.candidates.firstWhere(
          (c) => c.oldSettingKey == 'tag',
        );

        expect(tagCandidate.feasibility, MigrationFeasibility.direct);
        expect(tagCandidate.suggestedRule, isNull); // no old data to map
        expect(tagCandidate.notes, contains('ShieldRuleType.tag'));
      },
    );

    test('report aggregates counts correctly', () {
      final report = RecommendFilterAnalyzer.analyze(
        zeroConfig(
          rcmdRegExp: RegExp('猫|狗', caseSensitive: false),
          minDurationForRcmd: 60,
          minPlayForRcmd: 100,
          minLikeRatioForRecommend: 2,
        ),
      );

      // 2 ban words → 2 direct + tag direct
      expect(report.directCount, greaterThanOrEqualTo(2));
      // duration + play + like → 3 unsupported
      expect(report.unsupportedCount, greaterThanOrEqualTo(3));
      expect(report.candidates, isNotEmpty);
    });
  });

  group('ShieldMigrationCandidate', () {
    test('direct candidate toBeApplied returns suggestedRule', () {
      final candidate = ShieldMigrationCandidate(
        oldSettingKey: 'banWordForRecommend',
        oldSettingValue: 'test',
        feasibility: MigrationFeasibility.direct,
        suggestedRule: ShieldRule(
          id: 'test',
          type: ShieldRuleType.keyword,
          matchMode: ShieldMatchMode.contains,
          scope: ShieldScope.recommendation,
          action: ShieldAction.block,
          pattern: 'test',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          source: ShieldRuleSource.imported,
        ),
      );

      expect(candidate.toBeApplied(), isNotNull);
      expect(candidate.toBeApplied()!.pattern, 'test');
    });

    test('unsupported candidate toBeApplied returns null', () {
      final candidate = const ShieldMigrationCandidate(
        oldSettingKey: 'minDurationForRcmd',
        oldSettingValue: '60',
        feasibility: MigrationFeasibility.unsupported,
      );

      expect(candidate.toBeApplied(), isNull);
    });
  });
}
