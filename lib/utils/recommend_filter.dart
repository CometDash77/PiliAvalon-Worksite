import 'package:PiliPlus/features/shielding/shielding.dart';
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
  static ShieldRuleSet Function()? shieldRuleSetProvider;
  static bool useLegacyTextFilter = false;

  static bool get legacyRecommendationEnabled {
    final ruleSet =
        shieldRuleSetProvider?.call() ?? ShieldSettingsStore().snapshot();
    return ruleSet.isScopeEnabled(ShieldScope.recommendation);
  }

  static bool filter(BaseVideoItemModel videoItem) {
    if (!legacyRecommendationEnabled) {
      return false;
    }
    //由于相关视频中没有已关注标签，只能视为非关注视频
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return filterAll(videoItem);
  }

  static bool filterLikeRatio(int? like, int? view) {
    if (!legacyRecommendationEnabled) {
      return false;
    }
    if (view != null) {
      return (view > -1 && view < minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < minLikeRatioForRecommend * view);
    }
    return false;
  }

  static bool filterDerivedMetrics(BaseVideoItemModel videoItem) {
    if (!legacyRecommendationEnabled) {
      return false;
    }
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }

    final stat = videoItem.stat;
    return _filterMetric(
          enabled: filterInteractionRateForRecommend,
          numerator: (stat.danmu ?? 0) + (stat.reply ?? 0),
          denominator: stat.view,
          threshold: minInteractionRateForRecommend,
        ) ||
        _filterMetric(
          enabled: filterTripleRateForRecommend,
          numerator: (stat.like ?? 0) + (stat.coin ?? 0) + (stat.favorite ?? 0),
          denominator: stat.view,
          threshold: minTripleRateForRecommend,
        ) ||
        _filterMetric(
          enabled: filterContentValueForRecommend,
          numerator: stat.coin ?? 0,
          denominator: stat.like,
          threshold: minContentValueForRecommend,
        );
  }

  static bool filterTitle(String title) {
    if (!legacyRecommendationEnabled) {
      return false;
    }
    if (!useLegacyTextFilter) {
      return false;
    }
    return (enableFilter && rcmdRegExp.hasMatch(title));
  }

  static bool filterAll(BaseVideoItemModel videoItem) {
    if (!legacyRecommendationEnabled) {
      return false;
    }
    return (videoItem.duration > 0 &&
            videoItem.duration < minDurationForRcmd) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterDerivedMetrics(videoItem) ||
        filterTitle(videoItem.title);
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
