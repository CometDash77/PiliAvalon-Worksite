import 'dart:async';
import 'dart:collection';

import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

/// Issue #123: in-process cache for Jev final-review verdicts.
///
/// 只缓存「确定」的终审判定（隐藏或保留）：命中即不再发送上游请求；超时、
/// 传输失败、解析失败、低置信等不确定结果一律不入缓存，fail-open 不变。
///
/// 缓存按「策略代」组织：provider、模型、内置开关、启用的规则集、偏好档
/// 任一变化都会换新代键，旧代整体作废（与评论门代际失效同型）。条目有
/// TTL 与条目上限，均可在设置里配置并钳制到合理边界；写后超限从旧到新
/// 滚动淘汰，读时顺手清掉已过期条目。
class JevVerdictCache {
  JevVerdictCache({JevSettingsBox? box, DateTime Function()? clock})
      : _box = box ?? HiveJevSettingsBox(GStorage.setting),
        _clock = clock ?? DateTime.now;

  final JevSettingsBox _box;
  final DateTime Function() _clock;

  static const int ttlMinutesDefault = 1440; // 24h
  static const int ttlMinutesMin = 1;
  static const int ttlMinutesMax = 10080; // 7 days
  static const int maxEntriesDefault = 500;
  static const int maxEntriesMin = 1;
  static const int maxEntriesMax = 5000;

  /// generation → entries/in-flight。与标签缓存、评论门一致随进程存活；
  /// 测试用 [resetCache] 清空。
  static final Map<String, _JevGeneration> _generations =
      <String, _JevGeneration>{};

  // ---- 可配置边界（设置页与导入导出共用同一读取口径） ----

  static bool _readBool(JevSettingsBox box, String key, bool fallback) {
    final raw = box.get(key, defaultValue: fallback);
    return raw is bool ? raw : fallback;
  }

  static int _readInt(
    JevSettingsBox box,
    String key,
    int fallback,
    int min,
    int max,
  ) {
    final raw = box.get(key, defaultValue: fallback);
    if (raw is! int) return fallback;
    if (raw < min) return min;
    if (raw > max) return max;
    return raw;
  }

  static bool enabledIn(JevSettingsBox box) =>
      _readBool(box, SettingBoxKey.jevVerdictCacheEnabled, true);

  static int ttlMinutesIn(JevSettingsBox box) => _readInt(
        box,
        SettingBoxKey.jevVerdictCacheTtlMinutes,
        ttlMinutesDefault,
        ttlMinutesMin,
        ttlMinutesMax,
      );

  static int maxEntriesIn(JevSettingsBox box) => _readInt(
        box,
        SettingBoxKey.jevVerdictCacheMaxEntries,
        maxEntriesDefault,
        maxEntriesMin,
        maxEntriesMax,
      );

  bool get enabled => enabledIn(_box);
  Duration get ttl => Duration(minutes: ttlMinutesIn(_box));
  int get maxEntries => maxEntriesIn(_box);

  // ---- 判定读写 ----

  /// 命中返回终审判定（true=隐藏）；未命中或已过期返回 null，过期项顺手
  /// 清掉。
  bool? lookup(String generation, String identity) {
    final gen = _generations[generation];
    if (gen == null) return null;
    final entry = gen.entries[identity];
    if (entry == null) return null;
    if (_clock().isAfter(entry.storedAt.add(ttl))) {
      gen.entries.remove(identity);
      return null;
    }
    return entry.hide;
  }

  /// 写入一条确定判定。写入序即新旧序：写后超限从旧到新淘汰。
  void put(String generation, String identity, {required bool hide}) {
    var gen = _generations[generation];
    if (gen == null) {
      // 换代即作废旧代：旧代判定与在飞一并脱离（评论门同型）。
      _generations.removeWhere((key, _) => key != generation);
      gen = _JevGeneration();
      _generations[generation] = gen;
    }
    final now = _clock();
    gen.entries.removeWhere((_, entry) => now.isAfter(entry.storedAt.add(ttl)));
    gen.entries.remove(identity); // 重复写入视为最新
    gen.entries[identity] = _JevVerdictEntry(hide: hide, storedAt: now);
    final max = maxEntries;
    while (gen.entries.length > max) {
      gen.entries.remove(gen.entries.keys.first);
    }
  }

  /// 任何 await 之前登记在飞（先登记后加载，沿标签缓存先例）。返回 false
  /// 表示同一身份已有在飞请求，调用方应挂到 [inFlightFuture] 上。
  bool registerInFlight(
    String generation,
    String identity,
    Completer<bool?> completer,
  ) {
    final gen = _generations.putIfAbsent(generation, _JevGeneration.new);
    if (gen.inFlight.containsKey(identity)) return false;
    gen.inFlight[identity] = completer.future;
    return true;
  }

  Future<bool?>? inFlightFuture(String generation, String identity) =>
      _generations[generation]?.inFlight[identity];

  void releaseInFlight(String generation, String identity) {
    _generations[generation]?.inFlight.remove(identity);
  }

  /// 清空全部代（设置页「清空判定缓存」用）。已在飞的 Future 引用仍会按
  /// 原样完成，但新的挂载会落空而自行发送——与标签缓存 clear 语义一致。
  static void resetCache() => _generations.clear();

  // ---- 落盘接缝（issue #123 Q1：本期进程内不落盘，仅预留序列化口） ----

  /// 把当前全部代的判定序列化为可 JSON 的快照。在飞请求不导出——未完成
  /// 的判定本来就不确定，落盘没有意义。进程退出前调用并持久化返回值，
  /// 下次启动用 [restoreSnapshot] 恢复；本期不接线，仅保证结构稳定。
  static Map<String, Object?> exportSnapshot() => <String, Object?>{
    'version': 1,
    'generations': <String, Object?>{
      for (final gen in _generations.entries)
        gen.key: <Object?>[
          for (final entry in gen.value.entries.entries)
            <String, Object?>{
              'identity': entry.key,
              'hide': entry.value.hide,
              'storedAt': entry.value.storedAt.millisecondsSinceEpoch,
            },
        ],
    },
  };

  /// 恢复 [exportSnapshot] 的产物：整体替换现有缓存内容。结构损坏的条目
  /// 静默跳过——快照来自本机旧进程，宁可少缓存也不恢复出脏判定。
  static void restoreSnapshot(Map<String, Object?> snapshot) {
    if (snapshot['version'] != 1) return;
    final gens = snapshot['generations'];
    if (gens is! Map) return;
    final restored = <String, _JevGeneration>{};
    for (final gen in gens.entries) {
      final key = gen.key;
      final list = gen.value;
      if (key is! String || list is! List) continue;
      final generation = _JevGeneration();
      for (final item in list) {
        if (item is! Map) continue;
        final identity = item['identity'];
        final hide = item['hide'];
        final storedAt = item['storedAt'];
        if (identity is! String || hide is! bool || storedAt is! int) continue;
        generation.entries[identity] = _JevVerdictEntry(
          hide: hide,
          storedAt: DateTime.fromMillisecondsSinceEpoch(storedAt),
        );
      }
      if (generation.entries.isNotEmpty) restored[key] = generation;
    }
    _generations
      ..clear()
      ..addAll(restored);
  }

  /// 当前全部代内的判定条数（设置页展示用）。
  static int get cachedEntryCount {
    var total = 0;
    for (final gen in _generations.values) {
      total += gen.entries.length;
    }
    return total;
  }
}

/// 同一代策略下的判定存储：LinkedHashMap 保持写入序（最旧在前）。
class _JevGeneration {
  final LinkedHashMap<String, _JevVerdictEntry> entries =
      LinkedHashMap<String, _JevVerdictEntry>();
  final Map<String, Future<bool?>> inFlight = <String, Future<bool?>>{};
}

class _JevVerdictEntry {
  const _JevVerdictEntry({required this.hide, required this.storedAt});

  final bool hide;
  final DateTime storedAt;
}
