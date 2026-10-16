import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_settings.dart';

/// 被屏蔽条目的种类:视频面(推荐/热门/PGC/音乐/直播)或评论面。
enum JevScreenLogKind { video, comment }

/// 记录来源线:Jev(专用模型)或通用 LLM 线(issue #131)。
enum JevScreenLogLine { jev, llm }

/// 一条被屏蔽记录:只有展示层已有的标题/摘要/标签,不含 id、链接或账号信息。
class JevScreenLogEntry {
  const JevScreenLogEntry({
    required this.time,
    required this.kind,
    required this.surface,
    required this.title,
    this.line = JevScreenLogLine.jev,
    this.snippet,
    this.ruleId,
    this.modelId,
    this.reason,
    this.elapsedMs,
    this.failure,
    this.llmInputTokens,
    this.llmCacheHitTokens,
    this.llmCacheMissTokens,
  });

  factory JevScreenLogEntry.fromJson(Map json) => JevScreenLogEntry(
    time: json['time'] is int ? json['time'] as int : 0,
    kind: JevScreenLogKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => JevScreenLogKind.video,
    ),
    surface: json['surface'] is String ? json['surface'] as String : '',
    title: json['title'] is String ? json['title'] as String : '',
    line: JevScreenLogLine.values.firstWhere(
      (l) => l.name == json['line'],
      orElse: () => JevScreenLogLine.jev,
    ),
    snippet: json['snippet'] is String ? json['snippet'] as String : null,
    ruleId: json['ruleId'] is String ? json['ruleId'] as String : null,
    modelId: json['modelId'] is String ? json['modelId'] as String : null,
    reason: json['reason'] is String ? json['reason'] as String : null,
    elapsedMs: json['elapsedMs'] is int ? json['elapsedMs'] as int : null,
    failure: json['failure'] is String ? json['failure'] as String : null,
    llmInputTokens:
        json['llmInputTokens'] is int ? json['llmInputTokens'] as int : null,
    llmCacheHitTokens:
        json['llmCacheHitTokens'] is int
        ? json['llmCacheHitTokens'] as int
        : null,
    llmCacheMissTokens:
        json['llmCacheMissTokens'] is int
        ? json['llmCacheMissTokens'] as int
        : null,
  );

  /// epoch 毫秒。
  final int time;

  final JevScreenLogKind kind;

  /// 记录来源线;旧记录(无该字段)按 Jev 线读取。
  final JevScreenLogLine line;

  /// [JevSurface.id],页面显示时映射回 label。
  final String surface;

  /// 视频标题或评论正文;通用线整轮失败的行为空串。
  final String title;

  /// 评论:父评论正文;视频:分区/标签摘要。
  final String? snippet;

  /// 触发隐藏的判断规则标识;旧记录与视频面记录为 null。
  final String? ruleId;

  /// 通用线提供方的模型标识;Jev 线记录为 null。
  final String? modelId;

  /// 通用线命中理由(verdict reason,超长截断);Jev 线为 null。
  final String? reason;

  /// 通用线该轮判定耗时(毫秒)。
  final int? elapsedMs;

  /// 通用线整轮失败类别:timeout/upstream/parse/drift;成功命中行为 null。
  final String? failure;

  /// 通用线上游 usage 观测(#176):输入/缓存命中/缓存未命中 token;Jev 线为 null。
  final int? llmInputTokens;
  final int? llmCacheHitTokens;
  final int? llmCacheMissTokens;

  Map<String, Object?> toJson() => <String, Object?>{
    'time': time,
    'kind': kind.name,
    'surface': surface,
    'title': title,
    if (line != JevScreenLogLine.jev) 'line': line.name,
    if (snippet != null) 'snippet': snippet,
    if (ruleId != null) 'ruleId': ruleId,
    if (modelId != null) 'modelId': modelId,
    if (reason != null) 'reason': reason,
    if (elapsedMs != null) 'elapsedMs': elapsedMs,
    if (failure != null) 'failure': failure,
    if (llmInputTokens != null) 'llmInputTokens': llmInputTokens,
    if (llmCacheHitTokens != null) 'llmCacheHitTokens': llmCacheHitTokens,
    if (llmCacheMissTokens != null) 'llmCacheMissTokens': llmCacheMissTokens,
  };
}

/// 被屏蔽条目的本地诊断日志(用户要求的验收视图)。
///
/// 红线:只写本机设置 box,不进任何遥测;环形上限自动裁剪;
/// 读取/写入的任何失败都被吞掉,绝不影响筛选主流程(fail-open)。
class JevScreenLog {
  JevScreenLog({JevSettingsBox? box}) : _box = box ?? JevSettingsStore().box;

  final JevSettingsBox _box;

  /// 默认实例;screen() 埋点与日志页共用,测试可整体替换。
  static JevScreenLog instance = JevScreenLog();

  static const String key = '${JevSettingsStore.namespace}.screen_log.v1';

  /// 环形上限:超出后丢弃最旧的记录。
  static const int maxEntries = 300;

  /// 单条文本上限:标题或评论正文超长时截断。
  static const int maxTextLength = 200;

  /// 读取全部记录,新的在前。
  List<JevScreenLogEntry> load() {
    final raw = _box.get(key);
    if (raw is! String || raw.isEmpty) return const <JevScreenLogEntry>[];
    try {
      final list = jsonDecode(raw) as List;
      final entries = <JevScreenLogEntry>[];
      for (final item in list) {
        try {
          entries.add(JevScreenLogEntry.fromJson(item as Map));
        } catch (_) {
          // 单条损坏不影响其余记录。
        }
      }
      return entries;
    } catch (_) {
      return const <JevScreenLogEntry>[];
    }
  }

  /// 追加记录(新的在前)并裁剪到上限;任何失败都被吞掉。
  Future<void> record(Iterable<JevScreenLogEntry> entries) async {
    final all = entries.toList();
    // 单次批量本身也可能超限:超出时只保留最新的一段。
    final recent = all.length > maxEntries
        ? all.sublist(all.length - maxEntries)
        : all;
    final fresh = recent
        .map(
          (e) => JevScreenLogEntry(
            time: e.time,
            kind: e.kind,
            surface: e.surface,
            title: _clip(e.title),
            line: e.line,
            snippet: e.snippet == null ? null : _clip(e.snippet!),
            ruleId: e.ruleId,
            modelId: e.modelId,
            reason: e.reason == null ? null : _clip(e.reason!),
            elapsedMs: e.elapsedMs,
            failure: e.failure,
            llmInputTokens: e.llmInputTokens,
            llmCacheHitTokens: e.llmCacheHitTokens,
            llmCacheMissTokens: e.llmCacheMissTokens,
          ),
        )
        .toList();
    if (fresh.isEmpty) return;
    try {
      // 调用方按发生顺序传入(旧→新),展示时最新的在最前。
      final merged = <JevScreenLogEntry>[...fresh.reversed, ...load()];
      await _box.put(
        key,
        jsonEncode([
          for (final e in merged.take(maxEntries)) e.toJson(),
        ]),
      );
    } catch (_) {
      // 日志失败不影响筛选。
    }
  }

  /// 清空全部记录。
  Future<void> clear() async {
    try {
      await _box.delete(key);
    } catch (_) {
      // 清理失败不影响筛选。
    }
  }

  /// 全部条目序列化为 JSON 文本(日志导出用)。字段与页面可见信息一致:
  /// 时间/种类/来源线/入口/标题/摘要/规则/模型/理由/耗时/失败类别/usage token(输入/缓存命中/未命中),
  /// 不含密钥、认证头、Cookie 或任何账号标识。
  static String exportJson(List<JevScreenLogEntry> entries) => jsonEncode([
    for (final e in entries) e.toJson(),
  ]);

  static String _clip(String text) =>
      text.length <= maxTextLength ? text : text.substring(0, maxTextLength);
}
