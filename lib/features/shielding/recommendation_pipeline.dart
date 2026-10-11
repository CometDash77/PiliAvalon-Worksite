import 'package:PiliPlus/features/shielding/recommendation_filter.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/recommendation_metrics.dart';

typedef RecommendationStage<T> = Future<List<T>> Function(
  List<T> items,
  ShieldRuleSet ruleSet,
);

enum RecommendationLegacyPolicy { home, popular, related }

/// Shared ordering for all five video surfaces. IO stages are injected by the
/// composition layer, so this module never reads settings or calls HTTP.
class RecommendationPipeline {
  const RecommendationPipeline({
    required this.ruleSetProvider,
    required this.filterConfigProvider,
  });

  final ShieldRuleSet Function() ruleSetProvider;
  final RecommendationFilterConfig Function() filterConfigProvider;

  Future<List<T>> run<T extends BaseVideoItemModel>(
    List<T> items, {
    required RecommendationLegacyPolicy legacyPolicy,
    required ShieldCandidate Function(T item) toCandidate,
    RecommendationStage<T>? enrichTags,
    RecommendationStage<T>? gateComments,
    List<T> Function(List<T>)? filterExisting,
    RecommendationStage<T>? screen,
    void Function(List<T>)? recordVisible,
  }) async {
    final ruleSet = ruleSetProvider();
    final config = filterConfigProvider();
    final legacy = RecommendationFilter(
      config,
      enabled: ruleSet.isScopeEnabled(ShieldScope.recommendation),
    );
    final phase = RecommendationMetrics.startPhase(
      RecommendationPhase.filtering,
      inputCount: items.length,
    );
    final survivors = <T>[];
    for (final item in items) {
      final blocked = switch (legacyPolicy) {
        RecommendationLegacyPolicy.home => legacy.filter(item),
        RecommendationLegacyPolicy.popular =>
          legacy.filterTitle(item.title) ||
              legacy.filterLikeRatio(item.stat.like, item.stat.view),
        // Preserve the old related-video duration check, which is independent
        // of the recommendation scope switch.
        RecommendationLegacyPolicy.related =>
          config.applyFilterToRelatedVideos &&
              (legacy.filterLikeRatio(item.stat.like, item.stat.view) ||
                  (item.duration > 0 &&
                      item.duration < config.minDurationForRcmd)),
      };
      if (!blocked && ShieldMatcher.match(toCandidate(item), ruleSet).visible) {
        survivors.add(item);
      }
    }
    RecommendationMetrics.finishPhase(phase, outputCount: survivors.length);
    var result = survivors;
    if (enrichTags != null) result = await enrichTags(result, ruleSet);
    if (gateComments != null) result = await gateComments(result, ruleSet);
    if (filterExisting != null) result = filterExisting(result);
    if (screen != null) result = await screen(result, ruleSet);
    recordVisible?.call(result);
    return result;
  }
}
