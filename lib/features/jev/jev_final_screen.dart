import 'dart:async';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_filter_log.dart';
import 'package:PiliPlus/features/jev/screening_mode.dart';
import 'package:PiliPlus/features/llm/llm_screening.dart';
import 'package:PiliPlus/features/shielding/live_shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models_new/music/bgm_recommend_list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_rank/pgc_rank_item_model.dart';

/// 终审屏：把共享评测器接到一个具体推荐面上，在展示前丢掉用户明确不喜欢的内容。
///
/// 红线：任何失败都 fail-open——候选取不出、评测器抛异常、返回结构异常，
/// 都返回原列表原顺序，绝不因为 JEV 故障吞掉正常内容。
/// 全局模式只选择一个后端；失败不回退，切换后的旧结果不应用。
class JevFinalScreen<T> {
  JevFinalScreen({
    required this.surface,
    required this.toCandidate,
    this.evaluator,
    this.videoScreening,
  });

  final JevSurface surface;

  /// item → JevCandidate；返回 null 表示该条没有可送审的语义（不送）。
  final JevCandidate? Function(T item) toCandidate;

  final JevEvaluator? evaluator;

  /// 通用 LLM 视频线；测试整体注入，null 时用进程内共享实例。
  final LlmVideoScreening? videoScreening;

  static JevEvaluator? _shared;

  static LlmVideoScreening? _sharedVideo;

  static LlmVideoScreening get sharedVideoScreening =>
      _sharedVideo ??= LlmVideoScreening();

  /// 进程内共享评测器：各面共用同一套设置/凭据/偏好档。测试整体注入。
  static JevEvaluator get sharedEvaluator => _shared ??= JevEvaluator();

  JevEvaluator get _effectiveEvaluator => evaluator ?? sharedEvaluator;

  LlmVideoScreening get _effectiveVideoScreening =>
      videoScreening ?? sharedVideoScreening;

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
      final mode = await _effectiveEvaluator.modes.load();
      final settings = await _effectiveEvaluator.settings.load();
      if (!mode.isCurrent || !settings.isSurfaceEnabled(surface)) return items;
      final List<bool> hidden;
      JevScreening? decision;
      LlmVideoScreenOutcome? llm;
      switch (mode.mode) {
        case ScreeningEngineMode.off:
          return items;
        case ScreeningEngineMode.decision:
          decision = await _effectiveEvaluator.screen(candidates, surface: surface);
          hidden = decision.hidden;
        case ScreeningEngineMode.llm:
          llm = await _effectiveVideoScreening.screen([
            for (final candidate in candidates)
              LlmVideoCandidate(title: candidate.title, snippet: candidate.snippet,
                tags: candidate.tags, identity: candidate.localKey),
          ]);
          hidden = llm.hidden;
      }
      final current = await _effectiveEvaluator.settings.load();
      if (!mode.isCurrent || !current.isSurfaceEnabled(surface) ||
          hidden.length != candidates.length) return items;
      final keep = List<bool>.filled(items.length, true);
      final kind = T == ReplyInfo ? JevScreenLogKind.comment : JevScreenLogKind.video;
      final blocked = <JevScreenLogEntry>[];
      final filterBlocked = <JevFilterLogEntry>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var k = 0; k < indices.length; k++) {
        if (!hidden[k]) continue;
        keep[indices[k]] = false;
        final candidate = candidates[k];
        blocked.add(JevScreenLogEntry(
          time: now, kind: kind, surface: surface.id, title: candidate.title,
          snippet: candidate.snippet ?? _tagSummary(candidate.tags),
          line: llm == null ? JevScreenLogLine.jev : JevScreenLogLine.llm,
          ruleId: llm?.ruleIds[k], modelId: llm?.modelId,
          reason: llm?.reasons[k], elapsedMs: llm?.elapsedMs,
          llmInputTokens: llm?.usages[k]?.inputTokens,
          llmCacheHitTokens: llm?.usages[k]?.cacheHitTokens,
          llmCacheMissTokens: llm?.usages[k]?.cacheMissTokens,
        ));
        if (decision != null) {
          final judgment = k < decision.decisions.length ? decision.decisions[k] : null;
          filterBlocked.add(JevFilterLogEntry(
            time: now, surface: surface.id, title: candidate.title,
            snippet: candidate.snippet, tags: candidate.tags,
            noul: judgment?.noul, confidence: judgment?.confidence,
            threshold: judgment?.threshold, ruleId: judgment?.ruleId,
          ));
        }
      }
      if (blocked.isEmpty && llm?.failure != null) {
        blocked.add(JevScreenLogEntry(
          time: now, kind: kind, surface: surface.id, title: '',
          line: JevScreenLogLine.llm, modelId: llm!.modelId,
          failure: llm.failure, elapsedMs: llm.elapsedMs,
        ));
      }
      try {
        if (blocked.isNotEmpty) unawaited(JevScreenLog.instance.record(blocked));
        if (filterBlocked.isNotEmpty) unawaited(JevFilterLog.instance.record(filterBlocked));
      } catch (_) {
        // Log storage must not affect screening.
      }
      return [for (var i = 0; i < items.length; i++) if (keep[i]) items[i]];
    } catch (_) {
      return items;
    }
  }

  /// 热门/排行/相关/每周必看/入站必刷共用 HotVideoItemModel 同构映射。
  static JevFinalScreen<T> live<T>({JevEvaluator? evaluator}) =>
      JevFinalScreen<T>(
        surface: JevSurface.live,
        toCandidate: (item) {
          final card = LiveShielding.cardOf(item);
          if (card == null) return null;
          return _fromTitle(
            card.title,
            tags: [
              if (card.areaName?.trim().isNotEmpty == true)
                card.areaName!.trim(),
            ],
          );
        },
        evaluator: evaluator,
      );

  static JevFinalScreen<HotVideoItemModel> hotVideo({
    required JevSurface surface,
    JevEvaluator? evaluator,
  }) => JevFinalScreen<HotVideoItemModel>(
    surface: surface,
    toCandidate: (item) => _fromTitle(
      item.title,
      tags: [if (item.tname?.trim().isNotEmpty == true) item.tname!.trim()],
      localKey: jevVideoLocalKey(item),
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
    String? localKey,
  }) {
    final value = title?.trim();
    if (value == null || value.isEmpty) return null;
    return JevCandidate(title: value, tags: tags, localKey: localKey);
  }
}

String? _tagSummary(List<String> tags) =>
    tags.isEmpty ? null : tags.join(' / ');

/// 视频面卡片的本地缓存身份（issue #123）：bvid 优先，退回 aid；都没有就留
/// 空，评测器回退到规范化标题。仅用于本地判定缓存，绝不进上游载荷（#34）。
String? jevVideoLocalKey(BaseVideoItemModel item) {
  final bvid = item.bvid?.trim();
  if (bvid != null && bvid.isNotEmpty) return 'bvid:$bvid';
  final aid = item.aid;
  if (aid != null) return 'aid:$aid';
  return null;
}
