import 'package:PiliPlus/features/shielding/recommendation_filter_config.dart';
import 'package:PiliPlus/features/shielding/recommendation_pipeline.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_store.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 第二层：屏蔽栈读取规则集与设置的唯一注入点。
///
/// 第一层不认识这个类——判定拿到的是它产出的值。`RecommendFilter` 与
/// `ReplyGrpc` 上旧的 `shieldRuleSetProvider` 名字保留为兼容转发（都指向
/// [shieldRuleSetProvider] 这一个槽位），因此不存在第二份规则来源。
class ShieldingRuntime {
  const ShieldingRuntime({this.ruleSetProvider, this.configProvider});

  /// 测试/嵌入时覆盖 [ruleSet]；为空则走共享 provider 槽位，最后才落库读取。
  final ShieldRuleSet Function()? ruleSetProvider;

  /// 覆盖 [config]；为空则读持久化设置。
  final RecommendationFilterConfig Function()? configProvider;

  /// 所有旧名字共用的那一个规则集槽位。
  static ShieldRuleSet Function()? shieldRuleSetProvider;

  /// 生产调用点使用的默认运行时。
  static const ShieldingRuntime instance = ShieldingRuntime();

  ShieldRuleSet ruleSet() =>
      ruleSetProvider?.call() ??
      shieldRuleSetProvider?.call() ??
      ShieldSettingsStore().snapshot();

  RecommendationFilterConfig config() =>
      configProvider?.call() ?? _configFromPrefs();

  /// 整批共用的一份快照：一次规则读取 + 一次设置读取。
  RecommendationBatch batch() =>
      RecommendationBatch(ruleSet: ruleSet(), config: config());
}

/// 读取持久化的推荐过滤设置。
///
/// 放在这一层而不是 [RecommendationFilterConfig] 上，是为了让那个类保持无 IO；
/// 每个值都来自 `Pref`，与旧静态量的初值同源。
RecommendationFilterConfig _configFromPrefs() => RecommendationFilterConfig(
  minDurationForRcmd: Pref.minDurationForRcmd,
  minPlayForRcmd: Pref.minPlayForRcmd,
  minLikeRatioForRecommend: Pref.minLikeRatioForRecommend,
  filterInteractionRateForRecommend: Pref.filterInteractionRateForRecommend,
  minInteractionRateForRecommend: Pref.minInteractionRateForRecommend,
  filterTripleRateForRecommend: Pref.filterTripleRateForRecommend,
  minTripleRateForRecommend: Pref.minTripleRateForRecommend,
  filterContentValueForRecommend: Pref.filterContentValueForRecommend,
  minContentValueForRecommend: Pref.minContentValueForRecommend,
  exemptFilterForFollowed: Pref.exemptFilterForFollowed,
  applyFilterToRelatedVideos: Pref.applyFilterToRelatedVideos,
  rcmdRegExp: RegExp(Pref.banWordForRecommend, caseSensitive: false),
);
