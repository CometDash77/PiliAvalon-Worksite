import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models_new/music/bgm_recommend_list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_rank/pgc_rank_item_model.dart';

/// 终审屏：把共享评测器接到一个具体推荐面上，在展示前丢掉用户明确不喜欢的内容。
///
/// 红线：任何失败都 fail-open——候选取不出、评测器抛异常、返回结构异常，
/// 都返回原列表原顺序，绝不因为 JEV 故障吞掉正常内容。
/// 面开关的判定在 [JevEvaluator.screen] 内部（isSurfaceEnabled），
/// 这里不重复读设置，只负责映射与结果套用。
class JevFinalScreen<T> {
  JevFinalScreen({
    required this.surface,
    required this.toCandidate,
    this.evaluator,
  });

  final JevSurface surface;

  /// item → JevCandidate；返回 null 表示该条没有可送审的语义（不送）。
  final JevCandidate? Function(T item) toCandidate;

  final JevEvaluator? evaluator;

  static JevEvaluator? _shared;

  /// 进程内共享评测器：各面共用同一套设置/凭据/偏好档。测试整体注入。
  static JevEvaluator get sharedEvaluator => _shared ??= JevEvaluator();

  JevEvaluator get _effectiveEvaluator => evaluator ?? sharedEvaluator;

  Future<List<T>> screen(List<T> items) async {
    if (items.isEmpty) return items;
    final candidates = <JevCandidate>[];
    final indices = <int>[];
    for (var i = 0; i < items.length; i++) {
      final JevCandidate? candidate;
      try {
        candidate = toCandidate(items[i]);
      } catch (_) {
        continue; // 映射失败按"不可送审"处理，原样保留
      }
      if (candidate != null) {
        candidates.add(candidate);
        indices.add(i);
      }
    }
    if (candidates.isEmpty) return items;
    try {
      final screening = await _effectiveEvaluator.screen(
        candidates,
        surface: surface,
      );
      if (screening.status != JevScreenStatus.evaluated) return items;
      final hidden = screening.hidden;
      var anyHidden = false;
      final keep = List<bool>.filled(items.length, true);
      for (var k = 0; k < indices.length && k < hidden.length; k++) {
        if (hidden[k]) {
          keep[indices[k]] = false;
          anyHidden = true;
        }
      }
      if (!anyHidden) return items;
      return [
        for (var i = 0; i < items.length; i++)
          if (keep[i]) items[i],
      ];
    } catch (_) {
      return items; // 评测层任何异常都 fail-open
    }
  }

  /// 热门/排行/相关/每周必看/入站必刷共用 HotVideoItemModel 同构映射。
  static JevFinalScreen<HotVideoItemModel> hotVideo({
    required JevSurface surface,
    JevEvaluator? evaluator,
  }) => JevFinalScreen<HotVideoItemModel>(
    surface: surface,
    toCandidate: (item) => _fromTitle(
      item.title,
      tags: [if (item.tname?.trim().isNotEmpty == true) item.tname!.trim()],
    ),
    evaluator: evaluator,
  );

  /// PGC 排行（番剧/影视榜）：载荷只有标题可用。
  static JevFinalScreen<PgcRankItemModel> pgcRank({JevEvaluator? evaluator}) =>
      JevFinalScreen<PgcRankItemModel>(
        surface: JevSurface.pgc,
        toCandidate: (item) => _fromTitle(item.title),
        evaluator: evaluator,
      );

  /// PGC 索引列表：载荷只有标题可用。
  static JevFinalScreen<PgcIndexItem> pgcIndex({JevEvaluator? evaluator}) =>
      JevFinalScreen<PgcIndexItem>(
        surface: JevSurface.pgc,
        toCandidate: (item) => _fromTitle(item.title),
        evaluator: evaluator,
      );

  /// 音乐推荐列表：标题 + 标签名（不含 UP 名/ID）。
  static JevFinalScreen<BgmRecommend> music({JevEvaluator? evaluator}) =>
      JevFinalScreen<BgmRecommend>(
        surface: JevSurface.music,
        toCandidate: (item) => _fromTitle(
          item.title,
          tags: [
            for (final label in item.labelList ?? const <LabelList>[])
              if (label.name?.trim().isNotEmpty == true) label.name!.trim(),
          ],
        ),
        evaluator: evaluator,
      );

  static JevCandidate? _fromTitle(
    String? title, {
    List<String> tags = const [],
  }) {
    final value = title?.trim();
    if (value == null || value.isEmpty) return null;
    return JevCandidate(title: value, tags: tags);
  }
}
