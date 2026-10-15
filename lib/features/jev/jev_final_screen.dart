import 'dart:async';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_filter_log.dart';
import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_screening.dart';
import 'package:PiliPlus/features/screening/screening_mode.dart';
import 'package:PiliPlus/features/screening/screening_mode_migration.dart';
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
/// 都返回原列表原顺序，绝不因为筛选故障吞掉正常内容。
/// 单引擎模式（issue #142）：每轮筛选按全局 [ScreeningEngineMode] 只调度
/// 一个后端——`decision` 只跑 Jev 评测器（满页预算），`llm` 只跑通用
/// LLM 线（全量候选），`off` 直接原样返回（上游 0 次请求）。顺序兜底与
/// 双线预算拆分已移除。模式在页面加载后被切换时，在途旧模式的结果整页
/// 作废（代际守卫），新模式立即对下一轮生效。
class JevFinalScreen<T> {
  JevFinalScreen({
    required this.surface,
    required this.toCandidate,
    this.evaluator,
    this.videoScreening,
    this.modeStore,
  });

  final JevSurface surface;

  /// item → JevCandidate；返回 null 表示该条没有可送审的语义（不送）。
  final JevCandidate? Function(T item) toCandidate;

  final JevEvaluator? evaluator;

  /// 通用 LLM 视频线；测试整体注入，null 时用进程内共享实例。
  final LlmVideoScreening? videoScreening;

  /// 全局模式存储；测试注入，null 时借评测器的设置 box。
  final ScreeningModeStore? modeStore;

  static JevEvaluator? _shared;

  static LlmVideoScreening? _sharedVideo;

  static LlmVideoScreening get sharedVideoScreening =>
      _sharedVideo ??= LlmVideoScreening();

  /// 进程内共享评测器：各面共用同一套设置/凭据/偏好档。测试整体注入。
  static JevEvaluator get sharedEvaluator => _shared ??= JevEvaluator();

  JevEvaluator get _effectiveEvaluator => evaluator ?? sharedEvaluator;

  LlmVideoScreening get _effectiveVideoScreening =>
      videoScreening ?? sharedVideoScreening;

  ScreeningModeStore get _effectiveModeStore =>
      modeStore ??
      ScreeningModeStore(box: _effectiveEvaluator.settings.box);

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
      final modeStore = _effectiveModeStore;
      var mode = ScreeningEngineMode.decision;
      try {
        await ScreeningModeMigration.ensureRun(store: modeStore);
        mode = await modeStore.load();
      } catch (_) {
        mode = ScreeningEngineMode.decision; // 模式解析故障按默认模式
      }
      if (mode == ScreeningEngineMode.off) return items; // 上游 0 次
      final generation = ScreeningModeStore.generation;
      if (mode == ScreeningEngineMode.llm) {
        return await _screenLlm(items, candidates, indices, generation);
      }
      return await _screenDecision(items, candidates, indices, generation);
    } catch (_) {
      return items; // 调度层任何异常都 fail-open
    }
  }

  /// Decision 模式：只跑 Jev 评测器，独占整页预算（issue #142）。
  Future<List<T>> _screenDecision(
    List<T> items,
    List<JevCandidate> candidates,
    List<int> indices,
    int generation,
  ) async {
    final screening = await _effectiveEvaluator.screen(
      candidates,
      surface: surface,
      passTimeout: JevLimits.requestTimeout,
    );
    if (ScreeningModeStore.generation != generation) {
      return items; // 在途结果属于已被切换掉的旧模式，整页作废
    }
    var anyHidden = false;
    final keep = List<bool>.filled(items.length, true);
    final kind = T == ReplyInfo
        ? JevScreenLogKind.comment
        : JevScreenLogKind.video;
    final blocked = <JevScreenLogEntry>[];
    final filterBlocked = <JevFilterLogEntry>[];
    if (screening.status == JevScreenStatus.evaluated) {
      final hidden = screening.hidden;
      final decisions = screening.decisions;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var k = 0; k < indices.length && k < hidden.length; k++) {
        if (hidden[k]) {
          keep[indices[k]] = false;
          anyHidden = true;
          final candidate = candidates[k];
          blocked.add(
            JevScreenLogEntry(
              time: now,
              kind: kind,
              surface: surface.id,
              title: candidate.title,
              snippet: candidate.snippet ?? _tagSummary(candidate.tags),
            ),
          );
          // #105:同一真实筛除写入判定详情日志;数值只在本次判定真实产生
          // 时记录,判定缓存命中的槽位留空,由界面说明缺失,不编造。
          final JevScreenDecision? decision =
              k < decisions.length ? decisions[k] : null;
          filterBlocked.add(
            JevFilterLogEntry(
              time: now,
              surface: surface.id,
              title: candidate.title,
              snippet: candidate.snippet,
              tags: candidate.tags,
              noul: decision?.noul,
              confidence: decision?.confidence,
              threshold: decision?.threshold,
              ruleId: decision?.ruleId,
            ),
          );
        }
      }
    }
    await _recordLogs(blocked, filterBlocked);
    if (!anyHidden) return items;
    return [
      for (var i = 0; i < items.length; i++)
        if (keep[i]) items[i],
    ];
  }

  /// LLM 模式：只跑通用线，Jev 评测器 0 次调用（issue #142）。
  Future<List<T>> _screenLlm(
    List<T> items,
    List<JevCandidate> candidates,
    List<int> indices,
    int generation,
  ) async {
    // 全量候选直接进通用线（不再先过 Jev 幸存者裁剪）。
    final llmCandidates = <LlmVideoCandidate>[];
    for (final candidate in candidates) {
      llmCandidates.add(
        LlmVideoCandidate(
          title: candidate.title,
          snippet: candidate.snippet,
          tags: candidate.tags,
          identity: candidate.localKey,
        ),
      );
    }
    final outcome = await _effectiveVideoScreening.screen(
      llmCandidates,
      timeout: LlmLimits.requestTimeout,
    );
    if (ScreeningModeStore.generation != generation) {
      return items; // 在途结果属于已被切换掉的旧模式，整页作废
    }
    var anyHidden = false;
    final keep = List<bool>.filled(items.length, true);
    final kind = T == ReplyInfo
        ? JevScreenLogKind.comment
        : JevScreenLogKind.video;
    final blocked = <JevScreenLogEntry>[];
    for (var k = 0; k < indices.length && k < outcome.hidden.length; k++) {
      if (outcome.hidden[k]) {
        keep[indices[k]] = false;
        anyHidden = true;
        final candidate = candidates[k];
        blocked.add(
          JevScreenLogEntry(
            time: DateTime.now().millisecondsSinceEpoch,
            kind: kind,
            surface: surface.id,
            title: candidate.title,
            line: JevScreenLogLine.llm,
            snippet: candidate.snippet ?? _tagSummary(candidate.tags),
            ruleId: outcome.ruleIds[k],
            modelId: outcome.modelId,
            reason: outcome.reasons[k],
            elapsedMs: outcome.elapsedMs,
          ),
        );
      }
    }
    if (blocked.isEmpty && outcome.failure != null) {
      // 通用线整轮失败:只记类别/模型/耗时,不携带任何条目内容。
      blocked.add(
        JevScreenLogEntry(
          time: DateTime.now().millisecondsSinceEpoch,
          kind: kind,
          surface: surface.id,
          title: '',
          line: JevScreenLogLine.llm,
          modelId: outcome.modelId,
          failure: outcome.failure,
          elapsedMs: outcome.elapsedMs,
        ),
      );
    }
    await _recordLogs(blocked, const []);
    if (!anyHidden) return items;
    return [
      for (var i = 0; i < items.length; i++)
        if (keep[i]) items[i],
    ];
  }

  /// 日志失败不影响筛选（原双线逻辑同款）。
  Future<void> _recordLogs(
    List<JevScreenLogEntry> blocked,
    List<JevFilterLogEntry> filterBlocked,
  ) async {
    if (blocked.isNotEmpty) {
      try {
        unawaited(JevScreenLog.instance.record(blocked));
      } catch (_) {}
    }
    if (filterBlocked.isNotEmpty) {
      try {
        unawaited(JevFilterLog.instance.record(filterBlocked));
      } catch (_) {}
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
