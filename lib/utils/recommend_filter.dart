import 'package:PiliPlus/features/shielding/recommendation_filter.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/utils/shielding_runtime.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class RecommendFilter {
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool filterInteractionRateForRecommend =
      Pref.filterInteractionRateForRecommend;
  static double minInteractionRateForRecommend =
      Pref.minInteractionRateForRecommend;
  static bool filterTripleRateForRecommend = Pref.filterTripleRateForRecommend;
  static double minTripleRateForRecommend = Pref.minTripleRateForRecommend;
  static bool filterContentValueForRecommend =
      Pref.filterContentValueForRecommend;
  static double minContentValueForRecommend = Pref.minContentValueForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static bool applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;
  static RegExp rcmdRegExp = RegExp(
    Pref.banWordForRecommend,
    caseSensitive: false,
  );
  static bool enableFilter = rcmdRegExp.pattern.isNotEmpty;
  // Compatibility aliases; there is only one persisted-rule injection point.
  static ShieldRuleSet Function()? get shieldRuleSetProvider =>
      ShieldingRuntime.ruleSetProvider;
  static set shieldRuleSetProvider(ShieldRuleSet Function()? provider) =>
      ShieldingRuntime.ruleSetProvider = provider;
  static bool useLegacyTextFilter = false;

  static RecommendationFilterConfig snapshot() => RecommendationFilterConfig(
    minDurationForRcmd: minDurationForRcmd,
    minPlayForRcmd: minPlayForRcmd,
    minLikeRatioForRecommend: minLikeRatioForRecommend,
    filterInteractionRateForRecommend: filterInteractionRateForRecommend,
    minInteractionRateForRecommend: minInteractionRateForRecommend,
    filterTripleRateForRecommend: filterTripleRateForRecommend,
    minTripleRateForRecommend: minTripleRateForRecommend,
    filterContentValueForRecommend: filterContentValueForRecommend,
    minContentValueForRecommend: minContentValueForRecommend,
    exemptFilterForFollowed: exemptFilterForFollowed,
    applyFilterToRelatedVideos: applyFilterToRelatedVideos,
    rcmdRegExp: rcmdRegExp,
    enableFilter: enableFilter,
    useLegacyTextFilter: useLegacyTextFilter,
  );

  static void updateSettings({
    int? minDurationForRcmd,
    int? minPlayForRcmd,
    int? minLikeRatioForRecommend,
    bool? filterInteractionRateForRecommend,
    double? minInteractionRateForRecommend,
    bool? filterTripleRateForRecommend,
    double? minTripleRateForRecommend,
    bool? filterContentValueForRecommend,
    double? minContentValueForRecommend,
    bool? exemptFilterForFollowed,
    bool? applyFilterToRelatedVideos,
  }) {
    if (minDurationForRcmd != null) {
      RecommendFilter.minDurationForRcmd = minDurationForRcmd;
    }
    if (minPlayForRcmd != null) {
      RecommendFilter.minPlayForRcmd = minPlayForRcmd;
    }
    if (minLikeRatioForRecommend != null) {
      RecommendFilter.minLikeRatioForRecommend = minLikeRatioForRecommend;
    }
    if (filterInteractionRateForRecommend != null) {
      RecommendFilter.filterInteractionRateForRecommend =
          filterInteractionRateForRecommend;
    }
    if (minInteractionRateForRecommend != null) {
      RecommendFilter.minInteractionRateForRecommend =
          minInteractionRateForRecommend;
    }
    if (filterTripleRateForRecommend != null) {
      RecommendFilter.filterTripleRateForRecommend =
          filterTripleRateForRecommend;
    }
    if (minTripleRateForRecommend != null) {
      RecommendFilter.minTripleRateForRecommend = minTripleRateForRecommend;
    }
    if (filterContentValueForRecommend != null) {
      RecommendFilter.filterContentValueForRecommend =
          filterContentValueForRecommend;
    }
    if (minContentValueForRecommend != null) {
      RecommendFilter.minContentValueForRecommend = minContentValueForRecommend;
    }
    if (exemptFilterForFollowed != null) {
      RecommendFilter.exemptFilterForFollowed = exemptFilterForFollowed;
    }
    if (applyFilterToRelatedVideos != null) {
      RecommendFilter.applyFilterToRelatedVideos = applyFilterToRelatedVideos;
    }
  }

  static bool get legacyRecommendationEnabled =>
      ShieldingRuntime.snapshot().isScopeEnabled(ShieldScope.recommendation);

  // Preserve lazy reads for callers still using the old entry points. Product
  // screening captures a full snapshot once and uses RecommendationPipeline.
  static bool filter(BaseVideoItemModel item) {
    if (!legacyRecommendationEnabled ||
        (item.isFollowed && exemptFilterForFollowed)) {
      return false;
    }
    return filterAll(item);
  }

  static bool filterAll(BaseVideoItemModel item) {
    if (!legacyRecommendationEnabled) {
      return false;
    }
    return (item.duration > 0 && item.duration < minDurationForRcmd) ||
        filterLikeRatio(item.stat.like, item.stat.view) ||
        filterDerivedMetrics(item) ||
        filterTitle(item.title);
  }

  static bool filterLikeRatio(int? like, int? view) {
    if (!legacyRecommendationEnabled || view == null) {
      return false;
    }
    if (view > -1 && view < minPlayForRcmd) {
      return true;
    }
    if (like == null || like < 0) {
      return false;
    }
    return RecommendationFilter(
      RecommendationFilterConfig(
        minLikeRatioForRecommend: minLikeRatioForRecommend,
      ),
      enabled: true,
    ).filterLikeRatio(like, view);
  }

  static bool filterDerivedMetrics(BaseVideoItemModel item) {
    if (!legacyRecommendationEnabled ||
        (item.isFollowed && exemptFilterForFollowed)) {
      return false;
    }
    return RecommendationFilter(
      RecommendationFilterConfig(
        filterInteractionRateForRecommend: filterInteractionRateForRecommend,
        minInteractionRateForRecommend: filterInteractionRateForRecommend
            ? minInteractionRateForRecommend
            : 0,
        filterTripleRateForRecommend: filterTripleRateForRecommend,
        minTripleRateForRecommend: filterTripleRateForRecommend
            ? minTripleRateForRecommend
            : 0,
        filterContentValueForRecommend: filterContentValueForRecommend,
        minContentValueForRecommend: filterContentValueForRecommend
            ? minContentValueForRecommend
            : 0,
      ),
      enabled: true,
    ).filterDerivedMetrics(item);
  }

  static bool filterTitle(String title) {
    if (!legacyRecommendationEnabled || !useLegacyTextFilter || !enableFilter) {
      return false;
    }
    return RecommendationFilter(
      RecommendationFilterConfig(
        rcmdRegExp: rcmdRegExp,
        enableFilter: true,
        useLegacyTextFilter: true,
      ),
      enabled: true,
    ).filterTitle(title);
  }
}
