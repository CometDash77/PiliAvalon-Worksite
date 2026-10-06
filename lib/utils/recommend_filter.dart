import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 旧的推荐过滤门面（兼容层）。
///
/// 判定本体已经搬到无 IO 的 [RecommendationFilter]，这里保留旧的静态名与旧签名
/// 做转发，让既有测试与尚未迁移的调用点继续可用。设置写入统一走
/// [updateSettings]；规则集 provider 只是 [ShieldingRuntime] 那一个槽位的转发，
/// 不再存在第二份规则来源。
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

  static bool get legacyRecommendationEnabled =>
      RecommendationFilter.scopeEnabled(
        ShieldingRuntime.instance.ruleSet(),
      );

  // 下面五个旧方法保留「旧短路点 + 旧静态量的惰性读取顺序」：既有调用方与既有
  // 测试依赖这个顺序（例如 scope 关闭时一个设置字段都不读、时间过关时不再碰派生
  // 指标字段），所以局部配置只在真正走到该分支时才构造。判定本体一律来自纯层
  // [RecommendationFilter]，这里不复制任何判定表达式。

  static bool filter(BaseVideoItemModel videoItem) {
    final ruleSet = ShieldingRuntime.instance.ruleSet();
    if (!RecommendationFilter.scopeEnabled(ruleSet)) {
      return false;
    }
    //由于相关视频中没有已关注标签，只能视为非关注视频
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return filterAll(videoItem);
  }

  static bool filterLikeRatio(int? like, int? view) {
    final ruleSet = ShieldingRuntime.instance.ruleSet();
    if (!RecommendationFilter.scopeEnabled(ruleSet)) {
      return false;
    }
    // view 为 null 时旧代码不读 minPlayForRcmd/minLikeRatioForRecommend
    if (view == null) {
      return false;
    }
    return RecommendationFilter.filterLikeRatio(
      ruleSet,
      RecommendationFilterConfig(
        minPlayForRcmd: minPlayForRcmd,
        minLikeRatioForRecommend: minLikeRatioForRecommend,
      ),
      like,
      view,
    );
  }

  static bool filterDerivedMetrics(BaseVideoItemModel videoItem) {
    final ruleSet = ShieldingRuntime.instance.ruleSet();
    if (!RecommendationFilter.scopeEnabled(ruleSet)) {
      return false;
    }
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return RecommendationFilter.filterDerivedMetrics(
      ruleSet,
      RecommendationFilterConfig(
        exemptFilterForFollowed: exemptFilterForFollowed,
        filterInteractionRateForRecommend: filterInteractionRateForRecommend,
        minInteractionRateForRecommend: minInteractionRateForRecommend,
        filterTripleRateForRecommend: filterTripleRateForRecommend,
        minTripleRateForRecommend: minTripleRateForRecommend,
        filterContentValueForRecommend: filterContentValueForRecommend,
        minContentValueForRecommend: minContentValueForRecommend,
      ),
      videoItem,
    );
  }

  static bool filterTitle(String title) {
    final ruleSet = ShieldingRuntime.instance.ruleSet();
    if (!RecommendationFilter.scopeEnabled(ruleSet)) {
      return false;
    }
    // 旧文本过滤关闭时旧代码不读 enableFilter/rcmdRegExp
    if (!useLegacyTextFilter) {
      return false;
    }
    return RecommendationFilter.filterTitle(
      ruleSet,
      RecommendationFilterConfig(
        rcmdRegExp: rcmdRegExp,
        enableFilter: enableFilter,
        useLegacyTextFilter: useLegacyTextFilter,
      ),
      title,
    );
  }

  static bool filterAll(BaseVideoItemModel videoItem) {
    final ruleSet = ShieldingRuntime.instance.ruleSet();
    if (!RecommendationFilter.scopeEnabled(ruleSet)) {
      return false;
    }
    return RecommendationFilter.isTooShort(
          RecommendationFilterConfig(minDurationForRcmd: minDurationForRcmd),
          videoItem,
        ) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterDerivedMetrics(videoItem) ||
        filterTitle(videoItem.title);
  }
}
