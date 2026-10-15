import 'package:PiliPlus/features/shielding/recommendation_filter_config.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';

/// 第一层：不碰 IO 的推荐过滤判定。
///
/// 判定表达式逐字转写自旧 `RecommendFilter` 静态路径：阈值设置从静态量改成
/// [RecommendationFilterConfig]，是否启用从 [ShieldRuleSet] 的 scope 得出。
/// 一条候选的完整判定只走 [visible] 一遍：阈值链按（时长 → 点赞率 → 派生指标
/// → 标题）的旧顺序短路，通过后交 [ShieldMatcher] 判规则可见性。链条内部不再
/// 重复查询 scope——规则集整批不可变，同一批里重复查询只会得到同一个值。与旧
/// 「两遍判定」表达式（`!filter && isVisible`）的逐位等价由差分 sweep 佐证：
/// test/features/shielding/recommendation_judgement_equivalence_test.dart。
abstract final class RecommendationFilter {
  /// 推荐 scope 是否启用。
  static bool scopeEnabled(ShieldRuleSet ruleSet) =>
      ruleSet.isScopeEnabled(ShieldScope.recommendation);

  /// 合并后的单遍判定入口：阈值前置链 + 规则引擎，一条候选只判定一遍。
  ///
  /// 返回 true = 候选可见（进入后续流水线阶段），false = 被阈值链或规则屏蔽。
  /// scope 关闭时阈值链与规则都不生效，候选可见（与 matcher 的 visibleResult
  /// 一致）。
  static bool visible(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config, {
    required BaseVideoItemModel item,
    required ShieldCandidate candidate,
  }) {
    // 阈值链：scope 关闭或已关注豁免时不生效。
    if (scopeEnabled(ruleSet) &&
        !(item.isFollowed && config.exemptFilterForFollowed) &&
        _filterAll(config, item)) {
      return false;
    }
    // 规则引擎：scope 门与 allow 优先语义由 matcher 自己把关。
    return ShieldMatcher.match(candidate, ruleSet).visible;
  }

  /// 阈值链整体（时长/点赞率/派生指标/标题，顺序不变）。
  ///
  /// 返回 true = 应被阈值过滤掉。scope 关闭时不过滤。
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
    return _filterAll(config, videoItem);
  }

  /// 播放量/点赞率前置过滤（相关视频候选与热门/排行取数在源级调用）。
  static bool filterLikeRatio(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    int? like,
    int? view,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    return _filterLikeRatio(config, like, view);
  }

  /// 互动率/三连率/内容价值。
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
    return _filterDerivedMetrics(config, videoItem);
  }

  /// 仅旧文本过滤模式下生效的关键词过滤。
  static bool filterTitle(
    ShieldRuleSet ruleSet,
    RecommendationFilterConfig config,
    String title,
  ) {
    if (!scopeEnabled(ruleSet)) {
      return false;
    }
    return _filterTitle(config, title);
  }

  /// 时长过滤（兼容层单取这一段时保持独立入口）。
  static bool isTooShort(
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) => videoItem.duration > 0 && videoItem.duration < config.minDurationForRcmd;

  static bool _filterAll(
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) => isTooShort(config, videoItem) ||
      _filterLikeRatio(config, videoItem.stat.like, videoItem.stat.view) ||
      _filterDerivedMetrics(config, videoItem) ||
      _filterTitle(config, videoItem.title);

  static bool _filterLikeRatio(
    RecommendationFilterConfig config,
    int? like,
    int? view,
  ) {
    if (view != null) {
      return (view > -1 && view < config.minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < config.minLikeRatioForRecommend * view);
    }
    return false;
  }

  static bool _filterDerivedMetrics(
    RecommendationFilterConfig config,
    BaseVideoItemModel videoItem,
  ) {
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

  static bool _filterTitle(RecommendationFilterConfig config, String title) {
    if (!config.useLegacyTextFilter) {
      return false;
    }
    return config.enableFilter && config.rcmdRegExp.hasMatch(title);
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
