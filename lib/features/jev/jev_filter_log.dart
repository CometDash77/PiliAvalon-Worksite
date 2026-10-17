import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:flutter/foundation.dart';

/// 一条真实 Jev 筛除记录(issue #105):只有展示层已有的标题/摘要/标签,
/// 加上本次判定的实际数值。不含 id、链接、账号信息或原始响应。
class JevFilterLogEntry {
  const JevFilterLogEntry({
    required this.time,
    required this.surface,
    required this.title,
    this.snippet,
    this.tags = const <String>[],
    this.noul,
    this.confidence,
    this.threshold,
    this.ruleId,
    this.reason,
  });

  factory JevFilterLogEntry.fromJson(Map json) => JevFilterLogEntry(
    time: json['time'] is int ? json['time'] as int : 0,
    surface: json['surface'] is String ? json['surface'] as String : '',
    title: json['title'] is String ? json['title'] as String : '',
    snippet: json['snippet'] is String ? json['snippet'] as String : null,
    tags: [
      if (json['tags'] is List)
        for (final tag in json['tags'] as List)
          if (tag is String) tag,
    ],
    noul: _score(json['noul']),
    confidence: _score(json['confidence']),
    threshold: _score(json['threshold']),
    ruleId: json['ruleId'] is String ? json['ruleId'] as String : null,
    reason: json['reason'] is String ? json['reason'] as String : null,
  );

  /// epoch 毫秒。
  final int time;

  /// [JevSurface.id],页面显示时映射回 label。
  final String surface;

  final String title;

  /// 候选摘要;候选未提供时为 null。
  final String? snippet;

  final List<String> tags;

  /// 本次判定的实际数值;命中本地判定缓存或数值无效时为 null,
  /// 界面如实说明缺失,不编造。
  final double? noul;

  final double? confidence;

  final double? threshold;

  /// 命中的自定义规则标识;内置阈值筛除为 null。
  final String? ruleId;

  /// 本地生成的复合筛除原因(issue #115,如保留规则未命中);单规则命中时
  /// 为 null,数值字段已说明。从不来自模型调用。
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'time': time,
    'surface': surface,
    'title': title,
    if (snippet != null) 'snippet': snippet,
    if (tags.isNotEmpty) 'tags': tags,
    if (noul != null) 'noul': noul,
    if (confidence != null) 'confidence': confidence,
    if (threshold != null) 'threshold': threshold,
    if (ruleId != null) 'ruleId': ruleId,
    if (reason != null) 'reason': reason,
  };

  static double? _score(Object? value) {
    if (value is! num) return null;
    final v = value.toDouble();
    if (!v.isFinite) return null;
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }
}

/// 真实 Jev 筛除的本地日志(issue #105):设置页展示最近 5 条。
///
/// 红线:只写本机设置 box,不进任何遥测;只承载真实推荐列表被筛除的
/// 候选(连接验证/合成样例/独立测试不会写入);环形上限自动裁剪;
/// 读取/写入的任何失败都被吞掉,绝不影响筛选主流程(fail-open)。
class JevFilterLog {
  /// [storageKey]/[capacity] 用于派生独立实例(issue #115 直播 500 条):
  /// 与默认实例不同 key、互不覆盖;默认参数行为与 #105 完全一致。
  JevFilterLog({JevSettingsBox? box, String? storageKey, this.capacity = maxEntries})
    : _box = box ?? JevSettingsStore().box,
      _key = storageKey ?? key;

  final JevSettingsBox _box;
  final String _key;

  /// 实例环形上限。
  final int capacity;

  /// 默认实例;screen() 埋点与设置区块共用,测试可整体替换。
  static JevFilterLog instance = JevFilterLog();

  /// 直播筛除记录(issue #115):独立存储,最近 500 条,可清空。
  static JevFilterLog live = JevFilterLog(
    storageKey: '${JevSettingsStore.namespace}.live_filter_log.v1',
    capacity: 500,
  );

  /// 有记录写入成功时自增;设置区块据此自动刷新。
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const String key = '${JevSettingsStore.namespace}.filter_log.v1';

  /// 环形上限:用户要求的「最近 5 条」。
  static const int maxEntries = 5;

  /// 单条文本上限:标题或摘要超长时截断。
  static const int maxTextLength = 200;

  // 串行化并发写入:每条 record 排在前一条之后,读改写不互相踩。
  Future<void> _tail = Future<void>.value();

  /// 读取全部记录,新的在前。单条损坏跳过,整体损坏返回空。
  List<JevFilterLogEntry> load() {
    final raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) return const <JevFilterLogEntry>[];
    try {
      final list = jsonDecode(raw) as List;
      final entries = <JevFilterLogEntry>[];
      for (final item in list) {
        try {
          entries.add(JevFilterLogEntry.fromJson(item as Map));
        } catch (_) {
          // 单条损坏不影响其余记录。
        }
      }
      return entries;
    } catch (_) {
      return const <JevFilterLogEntry>[];
    }
  }

  /// 追加记录(调用方按发生顺序传入,旧→新)并裁剪到最近 [maxEntries]
  /// 条;任何失败都被吞掉。
  Future<void> record(Iterable<JevFilterLogEntry> entries) {
    final all = [
      for (final e in entries)
        JevFilterLogEntry(
          time: e.time,
          surface: e.surface,
          title: _clip(e.title),
          snippet: e.snippet == null ? null : _clip(e.snippet!),
          tags: [for (final tag in e.tags) _clip(tag)],
          noul: e.noul,
          confidence: e.confidence,
          threshold: e.threshold,
          ruleId: e.ruleId,
          reason: e.reason,
        ),
    ];
    // 单次批量本身也可能超限:超出时只保留最新的一段。
    final recent = all.length > capacity
        ? all.sublist(all.length - capacity)
        : all;
    if (recent.isEmpty) return Future<void>.value();
    final task = _tail.then((_) => _write(recent));
    // 链条本身吞错,一次失败不影响后续写入。
    _tail = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _write(List<JevFilterLogEntry> fresh) async {
    try {
      // 展示时最新的在最前。
      final merged = <JevFilterLogEntry>[...fresh.reversed, ...load()];
      await _box.put(
        _key,
        jsonEncode([
          for (final e in merged.take(capacity)) e.toJson(),
        ]),
      );
      revision.value++;
    } catch (_) {
      // 日志失败不影响筛选。
    }
  }

  /// 清空全部记录。
  Future<void> clear() async {
    try {
      await _box.delete(_key);
    } catch (_) {
      // 清理失败不影响筛选。
    }
  }

  static String _clip(String text) =>
      text.length <= maxTextLength ? text : text.substring(0, maxTextLength);
}