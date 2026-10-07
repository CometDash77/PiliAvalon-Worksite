import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 设置镜像层。
///
/// 判定本体在无 IO 的纯层 `RecommendationFilter`（首页一条候选经
/// `RecommendationFilter.visible` 单遍判定），这里只保留三件事：设置静态量的
/// 内存镜像、设置层唯一写入口 [updateSettings]、与 `ReplyGrpc` 共用的
/// [shieldRuleSetProvider] 槽位转发。旧判定转发方法已删除——同一份判定只在
/// 纯层存在一份，产品与测试都直接调用纯层。
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
  static bool useLegacyTextFilter = false;

  /// 兼容转发：与 `ReplyGrpc.shieldRuleSetProvider` 指向同一个槽位。
  static ShieldRuleSet Function()? get shieldRuleSetProvider =>
      ShieldingRuntime.shieldRuleSetProvider;

  static set shieldRuleSetProvider(ShieldRuleSet Function()? provider) {
    ShieldingRuntime.shieldRuleSetProvider = provider;
  }

  /// 把当前内存镜像打成一份不可变配置，交给纯判定层。
  static RecommendationFilterConfig toConfig() => RecommendationFilterConfig(
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

  /// 设置层唯一的写入口：设置页不再直接给这些静态量赋值。
  ///
  /// 持久化仍由设置页控件自己完成（`SwitchItem` 与阈值对话框写的都是同一个
  /// `SettingBoxKey`），这里只收敛内存镜像，行为与改造前一致。只更新显式传入
  /// 的字段。
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
}
