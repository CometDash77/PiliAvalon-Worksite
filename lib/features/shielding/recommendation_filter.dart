import 'package:PiliPlus/models/model_video.dart';

/// Immutable legacy settings captured at the start of a screening batch.
/// This compatibility policy stays separate from ShieldMatcher until the
/// dual-filter migration has been resolved.
class RecommendationFilterConfig {
  const RecommendationFilterConfig({
    this.minDurationForRcmd = 0,
    this.minPlayForRcmd = 0,
    this.minLikeRatioForRecommend = 0,
    this.filterInteractionRateForRecommend = false,
    this.minInteractionRateForRecommend = 1,
    this.filterTripleRateForRecommend = false,
    this.minTripleRateForRecommend = 3,
    this.filterContentValueForRecommend = false,
    this.minContentValueForRecommend = 10,
    this.exemptFilterForFollowed = false,
    this.applyFilterToRelatedVideos = false,
    this.rcmdRegExp,
    this.enableFilter = false,
    this.useLegacyTextFilter = false,
  });

  final int minDurationForRcmd;
  final int minPlayForRcmd;
  final int minLikeRatioForRecommend;
  final bool filterInteractionRateForRecommend;
  final double minInteractionRateForRecommend;
  final bool filterTripleRateForRecommend;
  final double minTripleRateForRecommend;
  final bool filterContentValueForRecommend;
  final double minContentValueForRecommend;
  final bool exemptFilterForFollowed;
  final bool applyFilterToRelatedVideos;
  final RegExp? rcmdRegExp;
  final bool enableFilter;
  final bool useLegacyTextFilter;
}

/// Pure visibility predicates: no storage, network, or mutable static state.
class RecommendationFilter {
  const RecommendationFilter(this.config, {required this.enabled});

  final RecommendationFilterConfig config;
  final bool enabled;

  bool filter(BaseVideoItemModel item) {
    if (!enabled || (item.isFollowed && config.exemptFilterForFollowed)) {
      return false;
    }
    return filterAll(item);
  }

  bool filterAll(BaseVideoItemModel item) =>
      enabled &&
      ((item.duration > 0 && item.duration < config.minDurationForRcmd) ||
          filterLikeRatio(item.stat.like, item.stat.view) ||
          filterDerivedMetrics(item) ||
          filterTitle(item.title));

  bool filterLikeRatio(int? like, int? view) =>
      enabled &&
      view != null &&
      ((view > -1 && view < config.minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < config.minLikeRatioForRecommend * view));

  bool filterTitle(String title) =>
      enabled &&
      config.useLegacyTextFilter &&
      config.enableFilter &&
      (config.rcmdRegExp?.hasMatch(title) ?? false);

  bool filterDerivedMetrics(BaseVideoItemModel item) {
    if (!enabled || (item.isFollowed && config.exemptFilterForFollowed)) {
      return false;
    }
    final stat = item.stat;
    return _filterMetric(
          config.filterInteractionRateForRecommend,
          (stat.danmu ?? 0) + (stat.reply ?? 0),
          stat.view,
          config.minInteractionRateForRecommend,
        ) ||
        _filterMetric(
          config.filterTripleRateForRecommend,
          (stat.like ?? 0) + (stat.coin ?? 0) + (stat.favorite ?? 0),
          stat.view,
          config.minTripleRateForRecommend,
        ) ||
        _filterMetric(
          config.filterContentValueForRecommend,
          stat.coin ?? 0,
          stat.like,
          config.minContentValueForRecommend,
        );
  }

  bool _filterMetric(
    bool active,
    num numerator,
    num? denominator,
    double threshold,
  ) =>
      active &&
      denominator != null &&
      denominator > 0 &&
      numerator / denominator * 100 < threshold;
}
