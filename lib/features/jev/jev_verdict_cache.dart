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
/// 缓存按「判定面」（face，如 video/comment）与「策略代」（generation）双维
/// 组织：face 之间互不干扰（#124：评论面写入不得作废视频面的缓存）；同一
/// face 内 provider、模型、内置开关、启用的规则集、偏好档任一变化都会换新
/// 代键，旧代整体作废（与评论门代际失效同型）。条目有 TTL 与条目上限，均
/// 可在设置里配置并钳制到合理边界；写后超限从旧到新滚动淘汰，读时顺手清
/// 掉已过期条目。设置键（开关/TTL/上限）为各判定面共用。
class JevVerdictCache {
  JevVerdictCache({
    JevSettingsBox? box,
    DateTime Function()? clock,
    this.face = 'video',
  }) : _box = box ?? HiveJevSettingsBox(GStorage.setting),
       _clock = clock ?? DateTime.now;

  final JevSettingsBox _box;
  final DateTime Function() _clock;

  /// 判定面标识：面之间各存各的代，写入互不作废。
  final String face;

  static const int ttlMinutesDefault = 1440; // 24h
  static const int ttlMinutesMin = 1;
  static const int ttlMinutesMax = 10080; // 7 days
  static const int maxEntriesDefault = 500;
  static const int maxEntriesMin = 1;
  static const int maxEntriesMax = 5000;

  /// face → generation → entries/in-flight。与标签缓存、评论门一致随进程
  /// 存活；测试用 [resetCache] 清空。
  static final Map<String, Map<String, _JevGeneration>> _faces =
      <String, Map<String, _JevGeneration>>{};

  static Map<String, _JevGeneration> _faceGenerations(String faceKey) =>
      _faces.putIfAbsent(faceKey, () => <String, _JevGeneration>{});

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
    final gen = _faceGenerations(face)[generation];
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
    final generations = _faceGenerations(face);
    var gen = generations[generation];
    if (gen == null) {
      // 换代即作废旧代（仅本判定面内）：旧代判定与在飞一并脱离（评论门
      // 同型）；其他判定面的缓存不受影响（#124）。
      generations.removeWhere((key, _) => key != generation);
      gen = _JevGeneration();
      generations[generation] = gen;
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
    final gen = _faceGenerations(face).putIfAbsent(generation, _JevGeneration.new);
    if (gen.inFlight.containsKey(identity)) return false;
    gen.inFlight[identity] = completer.future;
    return true;
  }

  Future<bool?>? inFlightFuture(String generation, String identity) =>
      _faceGenerations(face)[generation]?.inFlight[identity];

  void releaseInFlight(String generation, String identity) {
    _faceGenerations(face)[generation]?.inFlight.remove(identity);
  }

  /// 清空全部判定面的全部代（设置页「清空判定缓存」用）。已在飞的 Future
  /// 引用仍会按原样完成，但新的挂载会落空而自行发送——与标签缓存 clear
  /// 语义一致。
  static void resetCache() => _faces.clear();

  // ---- 落盘接缝（issue #123 Q1：本期进程内不落盘，仅预留序列化口） ----

  /// 把当前全部判定面的判定序列化为可 JSON 的快照。在飞请求不导出——未
  /// 完成的判定本来就不确定，落盘没有意义。进程退出前调用并持久化返回值，
  /// 下次启动用 [restoreSnapshot] 恢复；本期不接线，仅保证结构稳定。
  static Map<String, Object?> exportSnapshot() => <String, Object?>{
    'version': 2,
    'faces': <String, Object?>{
      for (final faceEntry in _faces.entries)
        faceEntry.key: <String, Object?>{
          for (final gen in faceEntry.value.entries)
            gen.key: _exportGeneration(gen.value),
        },
    },
  };

  static Object? _exportGeneration(_JevGeneration gen) => <Object?>[
    for (final entry in gen.entries.entries)
      <String, Object?>{
        'identity': entry.key,
        'hide': entry.value.hide,
        'storedAt': entry.value.storedAt.millisecondsSinceEpoch,
      },
  ];

  /// 恢复 [exportSnapshot] 的产物：整体替换现有缓存内容。结构损坏的条目
  /// 静默跳过——快照来自本机旧进程，宁可少缓存也不恢复出脏判定。v1 快照
  /// 来自仅有 video 判定面的旧版本，恢复进 video 面。
  static void restoreSnapshot(Map<String, Object?> snapshot) {
    final version = snapshot['version'];
    final Map faces;
    if (version == 1) {
      if (snapshot['generations'] is! Map) return;
      faces = <String, Object?>{'video': snapshot['generations']};
    } else if (version == 2) {
      final raw = snapshot['faces'];
      if (raw is! Map) return;
      faces = raw;
    } else {
      return;
    }
    final restored = <String, Map<String, _JevGeneration>>{};
    for (final faceEntry in faces.entries) {
      final faceKey = faceEntry.key;
      if (faceKey is! String) continue;
      final generations = restored.putIfAbsent(
        faceKey,
        () => <String, _JevGeneration>{},
      );
      final gens = faceEntry.value;
      if (gens is! Map) continue;
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
          if (identity is! String || hide is! bool || storedAt is! int) {
            continue;
          }
          generation.entries[identity] = _JevVerdictEntry(
            hide: hide,
            storedAt: DateTime.fromMillisecondsSinceEpoch(storedAt),
          );
        }
        if (generation.entries.isNotEmpty) generations[key] = generation;
      }
    }
    _faces
      ..clear()
      ..addAll(restored);
  }

  /// 当前全部判定面内的判定条数（设置页展示用）。
  static int get cachedEntryCount {
    var total = 0;
    for (final generations in _faces.values) {
      for (final gen in generations.values) {
        total += gen.entries.length;
      }
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
