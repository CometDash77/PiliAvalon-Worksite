import 'package:PiliPlus/utils/recommend_filter.dart';

import 'shielding_models.dart';

enum MigrationFeasibility { direct, partial, unsupported }

class ShieldMigrationCandidate {
  const ShieldMigrationCandidate({
    required this.oldSettingKey,
    required this.oldSettingValue,
    required this.feasibility,
    this.description,
    this.suggestedRule,
    this.notes,
    this.confidence,
  });

  final String oldSettingKey;
  final String oldSettingValue;
  final MigrationFeasibility feasibility;
  final String? description;
  final ShieldRule? suggestedRule;
  final String? notes;
  final double? confidence;

  ShieldRule? toBeApplied() =>
      feasibility == MigrationFeasibility.unsupported ? null : suggestedRule;
}

class ShieldMigrationReport {
  const ShieldMigrationReport({required this.candidates, this.analyzedAt});

  final List<ShieldMigrationCandidate> candidates;
  final DateTime? analyzedAt;

  int get directCount => candidates
      .where(
        (candidate) => candidate.feasibility == MigrationFeasibility.direct,
      )
      .length;

  int get partialCount => candidates
      .where(
        (candidate) => candidate.feasibility == MigrationFeasibility.partial,
      )
      .length;

  int get unsupportedCount => candidates
      .where(
        (candidate) =>
            candidate.feasibility == MigrationFeasibility.unsupported,
      )
      .length;
}

abstract final class RecommendFilterAnalyzer {
  static ShieldMigrationReport analyze({DateTime? now}) {
    final analyzedAt = now ?? DateTime.now();
    return ShieldMigrationReport(
      analyzedAt: analyzedAt,
      candidates: [
        ..._analyzeBanWords(analyzedAt),
        _analyzeDuration(),
        _analyzePlayCount(),
        _analyzeLikeRatio(),
        _analyzeFollowedExemption(),
        _analyzeRelatedVideosSwitch(),
        _analyzeTagCapability(),
      ],
    );
  }

  static List<ShieldMigrationCandidate> _analyzeBanWords(DateTime now) {
    final pattern = RecommendFilter.rcmdRegExp.pattern.trim();
    if (pattern.isEmpty) {
      return const [
        ShieldMigrationCandidate(
          oldSettingKey: 'banWordForRecommend',
          oldSettingValue: '',
          feasibility: MigrationFeasibility.direct,
          description: '推荐标题关键词过滤未启用',
          notes: '无旧规则需要迁移。',
          confidence: 0,
        ),
      ];
    }

    final words = _simplePipeWords(pattern);
    if (words != null) {
      return [
        for (final word in words)
          ShieldMigrationCandidate(
            oldSettingKey: 'banWordForRecommend',
            oldSettingValue: pattern,
            feasibility: MigrationFeasibility.direct,
            description: '推荐标题关键词: $word',
            suggestedRule: _rule(
              id: 'migration-ban-word-${word.hashCode}-${now.microsecondsSinceEpoch}',
              type: ShieldRuleType.keyword,
              matchMode: ShieldMatchMode.exact,
              pattern: word,
              now: now,
            ),
            notes: '从旧推荐标题关键词过滤拆分为新屏蔽关键词规则。',
            confidence: 0.9,
          ),
      ];
    }

    return [
      ShieldMigrationCandidate(
        oldSettingKey: 'banWordForRecommend',
        oldSettingValue: pattern,
        feasibility: MigrationFeasibility.direct,
        description: '推荐标题关键词正则',
        suggestedRule: _rule(
          id: 'migration-ban-word-regex-${now.microsecondsSinceEpoch}',
          type: ShieldRuleType.keyword,
          matchMode: ShieldMatchMode.regex,
          pattern: pattern,
          now: now,
        ),
        notes: '旧配置为复杂正则，保留为新屏蔽 regex 规则候选。',
        confidence: 0.85,
      ),
    ];
  }

  static ShieldMigrationCandidate _analyzeDuration() {
    final value = RecommendFilter.minDurationForRcmd;
    if (value <= 0) {
      return const ShieldMigrationCandidate(
        oldSettingKey: 'minDurationForRcmd',
        oldSettingValue: '0',
        feasibility: MigrationFeasibility.direct,
        description: '推荐视频时长过滤未启用',
        notes: '无旧规则需要迁移。',
        confidence: 0,
      );
    }
    return ShieldMigrationCandidate(
      oldSettingKey: 'minDurationForRcmd',
      oldSettingValue: value.toString(),
      feasibility: MigrationFeasibility.unsupported,
      description: '推荐视频最小时长: ${value}s',
      notes: '新 ShieldRule 体系没有数值阈值字段，Phase 1 只能保留旧过滤兼容路径。',
      confidence: 1,
    );
  }

  static ShieldMigrationCandidate _analyzePlayCount() {
    final value = RecommendFilter.minPlayForRcmd;
    if (value <= 0) {
      return const ShieldMigrationCandidate(
        oldSettingKey: 'minPlayForRcmd',
        oldSettingValue: '0',
        feasibility: MigrationFeasibility.direct,
        description: '推荐播放量过滤未启用',
        notes: '无旧规则需要迁移。',
        confidence: 0,
      );
    }
    return ShieldMigrationCandidate(
      oldSettingKey: 'minPlayForRcmd',
      oldSettingValue: value.toString(),
      feasibility: MigrationFeasibility.unsupported,
      description: '推荐最小播放量: $value',
      notes: '新 ShieldRule 体系没有播放量阈值字段，Phase 1 只能保留旧过滤兼容路径。',
      confidence: 1,
    );
  }

  static ShieldMigrationCandidate _analyzeLikeRatio() {
    final value = RecommendFilter.minLikeRatioForRecommend;
    if (value <= 0) {
      return const ShieldMigrationCandidate(
        oldSettingKey: 'minLikeRatioForRecommend',
        oldSettingValue: '0',
        feasibility: MigrationFeasibility.direct,
        description: '推荐点赞率过滤未启用',
        notes: '无旧规则需要迁移。',
        confidence: 0,
      );
    }
    return ShieldMigrationCandidate(
      oldSettingKey: 'minLikeRatioForRecommend',
      oldSettingValue: value.toString(),
      feasibility: MigrationFeasibility.unsupported,
      description: '推荐最小点赞率: $value%',
      notes: '新 ShieldRule 体系没有点赞率阈值字段，Phase 1 只能保留旧过滤兼容路径。',
      confidence: 1,
    );
  }

  static ShieldMigrationCandidate _analyzeFollowedExemption() {
    final value = RecommendFilter.exemptFilterForFollowed;
    return ShieldMigrationCandidate(
      oldSettingKey: 'exemptFilterForFollowed',
      oldSettingValue: value.toString(),
      feasibility: MigrationFeasibility.partial,
      description: '已关注 UP 豁免推荐过滤: $value',
      notes: value
          ? '新 ShieldRule 体系没有已关注豁免字段，需要继续由推荐过滤流程处理 isFollowed。'
          : '未启用，无旧规则需要迁移。',
      confidence: value ? 0.6 : 0,
    );
  }

  static ShieldMigrationCandidate _analyzeRelatedVideosSwitch() {
    final value = RecommendFilter.applyFilterToRelatedVideos;
    return ShieldMigrationCandidate(
      oldSettingKey: 'applyFilterToRelatedVideos',
      oldSettingValue: value.toString(),
      feasibility: MigrationFeasibility.partial,
      description: '旧过滤应用于相关视频: $value',
      notes: '这是旧过滤路径开关，不是具体规则；当前兼容层应跟随新全局/推荐流开关。',
      confidence: 0.9,
    );
  }

  static ShieldMigrationCandidate
  _analyzeTagCapability() => const ShieldMigrationCandidate(
    oldSettingKey: 'tag',
    oldSettingValue: '(not configured)',
    feasibility: MigrationFeasibility.direct,
    description: '标签屏蔽能力',
    notes:
        '旧 RecommendFilter 没有 tag 设置；新 tag 规则只能由原始 tag/tags payload 或用户手动规则驱动。',
    confidence: 1,
  );

  static List<String>? _simplePipeWords(String pattern) {
    final words = pattern.split('|').map((word) => word.trim()).toList();
    if (words.any((word) => word.isEmpty)) return null;
    if (words.length == 1 && words.single != pattern) return null;
    final simple = RegExp(r'^[\w\u4e00-\u9fff-]+$');
    if (words.every(simple.hasMatch)) return words;
    return null;
  }

  static ShieldRule _rule({
    required String id,
    required ShieldRuleType type,
    required ShieldMatchMode matchMode,
    required String pattern,
    required DateTime now,
  }) => ShieldRule(
    id: id,
    type: type,
    matchMode: matchMode,
    scope: ShieldScope.recommendation,
    action: ShieldAction.block,
    pattern: pattern,
    enabled: true,
    updatedAt: now,
    source: ShieldRuleSource.imported,
  );
}
