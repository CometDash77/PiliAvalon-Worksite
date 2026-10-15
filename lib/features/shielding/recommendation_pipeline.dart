import 'dart:async';

import 'package:PiliPlus/features/shielding/recommendation_filter_config.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';

/// 一批候选人共用的一份快照：规则集 + 设置。
///
/// 由流水线在批次开始时取一次，批次内所有判定与后续阶段都读这一份，避免每条
/// 候选各读一次规则集/设置。
class RecommendationBatch {
  const RecommendationBatch({required this.ruleSet, required this.config});

  final ShieldRuleSet ruleSet;
  final RecommendationFilterConfig config;
}

/// 取列表：把一个面的载荷变成候选人。载荷里的旧派生指标前置判断也在这里，
/// 因此它需要批次快照。
typedef RecommendationCandidateSource<T> = List<T> Function(
  RecommendationBatch batch,
);

/// 判候选：这一条是否留下。
typedef RecommendationJudge<T> = bool Function(
  T item,
  RecommendationBatch batch,
);

/// 命中后行为的一步：标签富集、评论门或曝光记录。返回新的列表，便于按固定
/// 顺序串联；某个面没有这一步就不传。
typedef RecommendationStage<T> = FutureOr<List<T>> Function(
  List<T> kept,
  RecommendationBatch batch,
);

/// 一个推荐面的“面差异”：判候选 + 三步命中后行为。
///
/// 取列表因为要抓 HTTP 载荷，在调用点作为闭包交给 [RecommendationPipeline]；
/// 判定与后续阶段按面复用，所以五个调用点共享同一份策略。
class RecommendationSurface<T> {
  const RecommendationSurface({
    required this.judge,
    this.enrichTags,
    this.gateComments,
    this.finalScreen,
    this.recordExposure,
  });

  final RecommendationJudge<T> judge;
  final RecommendationStage<T>? enrichTags;
  final RecommendationStage<T>? gateComments;

  /// 所有更便宜的过滤之后的最后一道判定（#65 的 Jev；#51 要的挂载点）。
  ///
  /// 固定运行在 [gateComments] 之后、[recordExposure] 之前：曝光记录不得看到
  /// 被隐藏的候选。失败必须在本阶段内部 fail-open——原样返回列表，绝不把异常
  /// 穿过流水线打挂整个面。
  final RecommendationStage<T>? finalScreen;

  final RecommendationStage<T>? recordExposure;
}

/// 把任意推荐面按同一条流水线跑完：
///
/// 1. 取规则集 + 设置（整批只有这一次）；2. 取列表；3. 逐条判定；4. 标签富集；
/// 5. 评论门；6. 终审（#65 的 Jev）；7. 曝光记录。
///
/// 阶段 3-6 由面自己提供，没有这一行为的面直接不传，而不是在流水线里分叉。
/// 没有任何阶段提前返回：空列表也照样走完全程，与它替换掉的手写调用点一致。
class RecommendationPipeline<T> {
  const RecommendationPipeline({
    required this.supplyBatch,
    required this.surface,
    required this.candidateSource,
  });

  /// 读取规则与设置，[run] 内只调用一次。
  final RecommendationBatch Function() supplyBatch;

  final RecommendationSurface<T> surface;

  /// 本面的取列表步骤，在快照之后、判定之前执行。
  final RecommendationCandidateSource<T> candidateSource;

  Future<List<T>> run() async {
    final batch = supplyBatch();
    var kept = candidateSource(
      batch,
    ).where((item) => surface.judge(item, batch)).toList();

    final enrichTags = surface.enrichTags;
    if (enrichTags != null) {
      kept = await enrichTags(kept, batch);
    }

    final gateComments = surface.gateComments;
    if (gateComments != null) {
      kept = await gateComments(kept, batch);
    }

    final finalScreen = surface.finalScreen;
    if (finalScreen != null) {
      kept = await finalScreen(kept, batch);
    }

    final recordExposure = surface.recordExposure;
    if (recordExposure != null) {
      kept = await recordExposure(kept, batch);
    }

    return kept;
  }
}
