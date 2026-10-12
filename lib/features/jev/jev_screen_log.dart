import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_settings.dart';

/// 被屏蔽条目的种类:视频面(推荐/热门/PGC/音乐/直播)或评论面。
enum JevScreenLogKind { video, comment }

/// 一条被屏蔽记录:只有展示层已有的标题/摘要/标签,不含 id、链接或账号信息。
class JevScreenLogEntry {
  const JevScreenLogEntry({
    required this.time,
    required this.kind,
    required this.surface,
    required this.title,
    this.snippet,
    this.ruleId,
  });

  factory JevScreenLogEntry.fromJson(Map json) => JevScreenLogEntry(
    time: json['time'] is int ? json['time'] as int : 0,
    kind: JevScreenLogKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => JevScreenLogKind.video,
    ),
    surface: json['surface'] is String ? json['surface'] as String : '',
    title: json['title'] is String ? json['title'] as String : '',
    snippet: json['snippet'] is String ? json['snippet'] as String : null,
    ruleId: json['ruleId'] is String ? json['ruleId'] as String : null,
  );

  /// epoch 毫秒。
  final int time;

  final JevScreenLogKind kind;

  /// [JevSurface.id],页面显示时映射回 label。
  final String surface;

  /// 视频标题或评论正文。
  final String title;

  /// 评论:父评论正文;视频:分区/标签摘要。
  final String? snippet;

  /// 触发隐藏的判断规则标识;旧记录与视频面记录为 null。
  final String? ruleId;

  Map<String, Object?> toJson() => <String, Object?>{
    'time': time,
    'kind': kind.name,
    'surface': surface,
    'title': title,
    if (snippet != null) 'snippet': snippet,
    if (ruleId != null) 'ruleId': ruleId,
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
            snippet: e.snippet == null ? null : _clip(e.snippet!),
            ruleId: e.ruleId,
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

  static String _clip(String text) =>
      text.length <= maxTextLength ? text : text.substring(0, maxTextLength);
}
