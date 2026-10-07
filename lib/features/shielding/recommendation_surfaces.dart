import 'package:PiliPlus/features/exposure_tracker/exposure_tracker.dart';
import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/recommendation_filter.dart';
import 'package:PiliPlus/features/shielding/recommendation_pipeline.dart';
import 'package:PiliPlus/features/shielding/shielding_adapters.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_recommend_tag_enricher.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:flutter/foundation.dart' show immutable;

/// 首页条目：视频模型 + 由同一份原始载荷建出的屏蔽候选。
///
/// 首页模型的公开字段不足以重建候选（`owner`/`args`/`tag`/`rcmd_reason`/
/// `staff` 等只在原始 json 里），所以候选在载荷还在手上时建好，随条目一起穿过
/// 流水线。
@immutable
class RecommendationFeedEntry<T> {
  const RecommendationFeedEntry({required this.item, required this.candidate});

  final T item;
  final ShieldCandidate candidate;
}

/// 穿过流水线后只保留原始视频模型，交回调用点的返回类型。
extension RecommendationFeedEntries<T> on List<RecommendationFeedEntry<T>> {
  List<T> get feedItems => [for (final entry in this) entry.item];
}

/// 五个推荐调用点的“面差异”策略。
///
/// 首页 web / 首页 app 的判定与命中后行为完全同构，因此共用 [homeFeed]；
/// 热门与排行同链，共用 [hotAndRanking]；相关视频有独立开关，单独一份。
abstract final class RecommendationSurfaces {
  /// 首页推荐：单遍合并判定（阈值前置链 + 规则集可见性）→ 标签富集 → 评论门 → 曝光记录。
  static RecommendationSurface<RecommendationFeedEntry<T>>
  homeFeed<T extends BaseVideoItemModel>() => RecommendationSurface(
    judge: (entry, batch) => RecommendationFilter.visible(
      batch.ruleSet,
      batch.config,
      item: entry.item,
      candidate: entry.candidate,
    ),
    enrichTags: (entries, batch) => RecommendationTagEnricher().enrichAndFilter(
      entries,
      batch.ruleSet,
      getBvid: (entry) => entry.item.bvid,
      getCid: (entry) => entry.item.cid,
    ),
    gateComments: (entries, batch) => HomeFeedCommentGate.filter(
      entries,
      config: CommentShieldingStore().snapshot(),
      ruleSet: batch.ruleSet,
      getAid: (entry) => entry.item.aid,
    ),
    recordExposure: (entries, batch) => ExposureTracker.instance
        .filterAndRecord(entries, getBvid: (entry) => entry.item.bvid),
  );

  /// 热门与排行：两者判定链逐字相同，只有列表来源不同；旧派生指标（标题/点赞率）
  /// 在取列表时已前置判断，故此处只剩规则集可见性，没有命中后行为。
  static RecommendationSurface<HotVideoItemModel> hotAndRanking() =>
      RecommendationSurface(
        judge: (item, batch) => ShieldingAdapters.isVisible(
          ShieldingAdapters.fromRelatedVideo(item),
          batch.ruleSet,
        ),
      );

  /// 相关视频：候选用 `ShieldScope.videoDetail`，对应的就是规则集里的相关视频
  /// 独立开关。
  static RecommendationSurface<HotVideoItemModel> relatedVideos() =>
      RecommendationSurface(
        judge: (item, batch) => ShieldingAdapters.isVisible(
          ShieldingAdapters.fromRelatedVideo(
            item,
            scope: ShieldScope.videoDetail,
          ),
          batch.ruleSet,
        ),
      );

  /// 相关视频的取列表：旧的 `applyFilterToRelatedVideos` 开关下的时长/点赞率
  /// 前置过滤。
  static List<HotVideoItemModel> relatedVideoCandidates(
    List<HotVideoItemModel> items,
    RecommendationBatch batch,
  ) {
    if (!batch.config.applyFilterToRelatedVideos) {
      return items;
    }
    return items
        .where(
          (item) =>
              !RecommendationFilter.filterLikeRatio(
                batch.ruleSet,
                batch.config,
                item.stat.like,
                item.stat.view,
              ) &&
              !(item.duration > 0 &&
                  item.duration < batch.config.minDurationForRcmd),
        )
        .toList();
  }
}
