import 'package:PiliPlus/features/exposure_tracker/exposure_tracker.dart';
import 'package:PiliPlus/features/jev/jev_models.dart';
import 'package:PiliPlus/features/jev/jev_recommendation_screening.dart';
import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/recommendation_pipeline.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_recommend_tag_enricher.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/shielding_runtime.dart';

/// Production wiring lives beside the transport layer, outside pure filters.
class VideoRecommendationScreening {
  VideoRecommendationScreening()
    : _pipeline = const RecommendationPipeline(
        ruleSetProvider: ShieldingRuntime.snapshot,
        filterConfigProvider: RecommendFilter.snapshot,
      ),
      _jev = JevRecommendationScreening.create();

  final RecommendationPipeline _pipeline;
  final JevRecommendationScreening _jev;

  Future<List<T>> run<T extends BaseVideoItemModel>(
    List<T> items, {
    required JevSurface surface,
    required ShieldCandidate Function(T item) toCandidate,
  }) {
    final home = surface == JevSurface.homeWeb || surface == JevSurface.homeApp;
    // Capture comment settings before the asynchronous tag stage.
    final comments = home ? CommentShieldingStore().snapshot() : null;
    return _pipeline.run(
      items,
      legacyPolicy: home
          ? RecommendationLegacyPolicy.home
          : surface == JevSurface.related
          ? RecommendationLegacyPolicy.related
          : RecommendationLegacyPolicy.popular,
      toCandidate: toCandidate,
      enrichTags: home
          ? (list, rules) => RecommendationTagEnricher().enrichAndFilter(
              list,
              rules,
              getBvid: (item) => item.bvid,
              getCid: (item) => item.cid,
            )
          : null,
      gateComments: home
          ? (list, rules) => HomeFeedCommentGate.filter(
              list,
              config: comments!,
              ruleSet: rules,
              getAid: (item) => item.aid,
            )
          : null,
      filterExisting: home
          ? (list) => ExposureTracker.instance.filterExisting(
              list,
              getBvid: (item) => item.bvid,
            )
          : null,
      screen: (list, _) => _jev.filter(
        candidates: list,
        surface: surface,
        toCandidate: (item) => JevCandidate(
          title: item.title,
          description: item.desc,
          category: item is HotVideoItemModel ? item.tname : null,
        ),
        runLowerCostFilters: (items) => items,
      ),
      recordVisible: home
          ? (list) => ExposureTracker.instance.recordVisible(
              list,
              getBvid: (item) => item.bvid,
            )
          : null,
    );
  }
}
