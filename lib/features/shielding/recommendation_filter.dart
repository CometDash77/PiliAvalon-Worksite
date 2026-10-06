import 'package:PiliPlus/features/shielding/recommendation_filter_config.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';

/// 第一层：不碰 IO 的推荐过滤判定。
///
/// 每个分支都是旧 `RecommendFilter` 静态方法的逐字转写——旧设置从静态量改成
/// [RecommendationFilterConfig]，是否启用从 [ShieldRuleSet] 的 scope 得出——
/// 所以同一输入的判定结果逐位一致：这里没有加任何提前返回，三条派生指标依旧
/// 按原顺序求值，scope 的查询次数也与旧代码相同。
abstract final class RecommendationFilter {
  /// 旧 `legacyRecommendationEnabled`：推荐 scope 是否启用。
  static bool scopeEnabled(ShieldRuleSet ruleSet) =>
      ruleSet.isScopeEnabled(ShieldScope.recommendation);

  /// 旧的 `filter`：该视频是否应被过滤掉。
  static bool filter(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    //由于相关视频中没有已关注标签，只能视为非关注视频
    if (videoItem.isFollowed && config.exemptFilterForFollowed) {
      return false;
    }
    return filterAll(ruleSet, config, videoItem);
  }

  /// 旧的 `filterLikeRatio`：播放量/点赞率前置过滤。
  static bool filterLikeRatio(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    int? like,
    int? view,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    if (view != null) {
      return (view > -1 && view < config.minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < config.minLikeRatioForRecommend * view);
    }
    return false;
  }

  /// 旧的 `filterDerivedMetrics`：互动率/三连率/内容价值。
  static bool filterDerivedMetrics(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    if (videoItem.isFollowed && config.exemptFilterForFollowed) {
      return false;
    }

    final stat = videoItem.stat;
    return _filterMetric(
          enabled: config.filterInteractionRateForRecommend,
          numerator: (stat.danmu ?? 0) + (stat.reply ?? 0),
          denominator: stat.view,
          threshold: config.minInteractionRateForRecommend,
        ) ||
        _filterMetric(
          enabled: config.filterTripleRateForRecommend,
          numerator: (stat.like ?? 0) + (stat.coin ?? 0) + (stat.favorite ?? 0),
          denominator: stat.view,
          threshold: config.minTripleRateForRecommend,
        ) ||
        _filterMetric(
          enabled: config.filterContentValueForRecommend,
          numerator: stat.coin ?? 0,
          denominator: stat.like,
          threshold: config.minContentValueForRecommend,
        );
  }

  /// 旧的 `filterTitle`：仅旧文本过滤模式下生效的关键词过滤。
  static bool filterTitle(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    String title,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    if (!config.useLegacyTextFilter) {
      return false;
    }
    return config.enableFilter && config.rcmdRegExp.hasMatch(title);
  }

  /// 旧的 `filterAll` 的第一段：时长过滤（兼容层单取这一段时要保持惰性读取）。
  static bool isTooShort(
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) => videoItem.duration > 0 && videoItem.duration < config.minDurationForRcmd;

  /// 旧的 `filterAll`：时长/点赞率/派生指标/关键词，顺序不变。
  static bool filterAll(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    return isTooShort(config, videoItem) ||
        filterLikeRatio(
          ruleSet,
          config,
          videoItem.stat.like,
          videoItem.stat.view,
        ) ||
        filterDerivedMetrics(ruleSet, config, videoItem) ||
        filterTitle(ruleSet, config, videoItem.title);
  }

  static bool _filterMetric({
    required bool enabled,
    required num numerator,
    required num? denominator,
    required double threshold,
  }) {
    if (!enabled) {
      return false;
    }
    final denominatorValue = denominator?.toDouble();
    if (denominatorValue == null || denominatorValue <= 0) {
      return false;
    }
    final metricValue = numerator.toDouble() / denominatorValue * 100;
    return metricValue < threshold;
  }
}
