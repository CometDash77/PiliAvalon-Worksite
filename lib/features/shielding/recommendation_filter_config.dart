import 'package:flutter/foundation.dart' show immutable;

/// 推荐过滤的全部设置项，不可变、无 IO。
///
/// 第一层（纯判定）只认识这个对象：持久化的值由第二层拿到后交进来，所以本文件
/// 既不 import 设置层，也不 import HTTP 层。字段默认值与 `Pref` 默认值一致，
/// 即 `RecommendationFilterConfig()` 等于全新安装。
@immutable
class RecommendationFilterConfig {
  RecommendationFilterConfig({
    this.minDurationForRcmd = 0,
    this.minPlayForRcmd = 0,
    this.minLikeRatioForRecommend = 0,
    this.filterInteractionRateForRecommend = false,
    this.minInteractionRateForRecommend = 1.0,
    this.filterTripleRateForRecommend = false,
    this.minTripleRateForRecommend = 3.0,
    this.filterContentValueForRecommend = false,
    this.minContentValueForRecommend = 10.0,
    this.exemptFilterForFollowed = true,
    this.applyFilterToRelatedVideos = true,
    RegExp? rcmdRegExp,
    bool? enableFilter,
    this.useLegacyTextFilter = false,
  }) : rcmdRegExp = rcmdRegExp ?? emptyRegExp,
       enableFilter =
           enableFilter ?? (rcmdRegExp ?? emptyRegExp).pattern.isNotEmpty;

  /// 未配置屏蔽词时使用的空模式，与旧静态量的 `RegExp('')` 一致。
  static final RegExp emptyRegExp = RegExp('');

  /// 旧的 `Pref.banWordForRecommend` 关键词表。
  final RegExp rcmdRegExp;

  /// 旧的 `enableFilter`；正常情况下由 [rcmdRegExp] 推导，但旧静态量可以单独
  /// 改写，所以这里保留独立字段，默认只在没有显式传入时才推导。
  final bool enableFilter;

  /// 旧的 `useLegacyTextFilter`。
  final bool useLegacyTextFilter;

  /// 视频时长下限（秒），0 表示关闭。
  final int minDurationForRcmd;

  /// 播放量下限，0 表示关闭。
  final int minPlayForRcmd;

  /// 点赞率下限（百分比），0 表示关闭。
  final int minLikeRatioForRecommend;

  /// 互动率过滤开关与阈值（百分比）。
  final bool filterInteractionRateForRecommend;
  final double minInteractionRateForRecommend;

  /// 三连率过滤开关与阈值（百分比）。
  final bool filterTripleRateForRecommend;
  final double minTripleRateForRecommend;

  /// 投币/点赞内容价值过滤开关与阈值（百分比）。
  final bool filterContentValueForRecommend;
  final double minContentValueForRecommend;

  /// 已关注视频豁免。
  final bool exemptFilterForFollowed;

  /// 相关视频是否套用旧的时长/点赞率前置过滤（与规则集里的相关视频开关是两件事）。
  final bool applyFilterToRelatedVideos;
}
