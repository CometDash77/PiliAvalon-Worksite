import 'dart:async' show Completer;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

/// 取一个视频分 P 的原始标签。
typedef TagFetchFn = Future<LoadingState<List<VideoTagItem>?>> Function(
  String bvid,
  Object? cid,
);

/// 成功条目存活 30 分钟。
const Duration tagCacheTtl = Duration(minutes: 30);

/// 失败与空结果的负缓存 30 秒：一个坏掉的分 P 不该每批都被重试一次。
const Duration negativeTagCacheTtl = Duration(seconds: 30);

const int _defaultTagCacheMaxMb = 10;
const int _maxTagCacheMaxMb = 50;
const int _bytesPerMb = 1024 * 1024;
const int _estimatedEntryOverheadBytes = 96;

/// 读设置里的标签缓存预算（MB），钳到 [1, 50]。
int get tagEnrichCacheMaxMb {
  final raw = GStorage.setting.get(
    SettingBoxKey.tagEnrichCacheMaxMb,
    defaultValue: _defaultTagCacheMaxMb,
  );
  if (raw is! int) return _defaultTagCacheMaxMb;
  return raw.clamp(1, _maxTagCacheMaxMb);
}

int get tagEnrichCacheMaxBytes => tagEnrichCacheMaxMb * _bytesPerMb;

/// 生产传输：真实标签接口。
Future<LoadingState<List<VideoTagItem>?>> defaultVideoTagFetch(
  String bvid,
  Object? cid,
) => UserHttp.videoTags(bvid: bvid, cid: cid);

class _TagCacheEntry {
  const _TagCacheEntry({
    required this.tags,
    required this.fetchedAt,
    required this.estimatedBytes,
  });

  final List<VideoTagItem> tags;
  final DateTime fetchedAt;
  final int estimatedBytes;
}

/// 推荐面与视频详情页共用的那一份标签存储。
///
/// 三件事只在这里做，别处都不做：
/// * 成功缓存：`bvid + cid` → 原始标签，存活 30 分钟；
/// * 负缓存：失败或空结果，存活 30 秒，避免同一失败被反复重试；
/// * 在飞去重：同键的并发请求合并成一个 Future，多方共享。
///
/// 存的是原始载荷，不是判定结果：调用方拿回标签后再用**当前批次**的规则集重新
/// 匹配，所以一条缓存永远不会把上一批的判定偷渡进来（与 #73 的阶段契约一致）。
///
/// 不做单个调用方的取消：调用方不等了（页面离开、超时）那个请求照样跑完并写回
/// 共享缓存，所以这里没有订阅者计数，也没有由此产生的竞争状态。
class RecommendationTagStore {
  RecommendationTagStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// 全进程共享的那一份。
  static final RecommendationTagStore instance = RecommendationTagStore();

  final DateTime Function() _clock;
  final Map<String, _TagCacheEntry> _cache = {};
  final Map<String, Future<List<VideoTagItem>?>> _inFlight = {};
  final Map<String, DateTime> _negativeUntil = {};
  int _cacheBytes = 0;

  /// 缓存键：bvid + cid，同一视频不同分 P 不会互相复用标签。
  static String cacheKey(String bvid, Object? cid) => '$bvid|${cid ?? ''}';

  /// 返回 [bvid]/[cid] 的标签；拿不到时返回 null。
  ///
  /// 解析顺序：成功缓存 → 负缓存 → 在飞合并 → 真正发一次请求。
  ///
  /// [fetcher] 覆盖本次调用的传输，且只被**真正发起请求**的那一方调用——命中缓存
  /// 或合并到在飞请求的调用方永远不会碰它。生产路径不传，用 [defaultVideoTagFetch]。
  Future<List<VideoTagItem>?> fetch(
    String bvid,
    Object? cid, {
    TagFetchFn? fetcher,
  }) {
    final key = cacheKey(bvid, cid);
    final now = _clock();
    _evictExpired();

    final cached = _cache[key];
    if (cached != null) return Future.value(cached.tags);

    final negativeUntil = _negativeUntil[key];
    if (negativeUntil != null) {
      if (now.isBefore(negativeUntil)) return Future.value(null);
      _negativeUntil.remove(key);
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    // 在飞位必须在**加载开始之前**登记。fetcher 可能同步抛错，那种情况下 [_load]
    // 的函数体在返回前就跑完了（异常被它自己的 try/catch 接住），先调用后登记
    // 的话，登记进去的是一个已经完成、永远没人清理的 future，这个键从此再也发不出
    // 请求——成功缓存与负缓存都救不回来，因为它根本没走到缓存那一步。
    final completer = Completer<List<VideoTagItem>?>();
    _inFlight[key] = completer.future;
    _load(key, bvid, cid, fetcher ?? defaultVideoTagFetch).then(
      (tags) {
        // 释放与完成之间没有 await，合并进来的调用方被唤醒时缓存已经写完。
        _inFlight.remove(key);
        completer.complete(tags);
      },
      // [_load] 本身把传输层异常都兜住了，但写缓存与驱逐仍可能出错；那种情况下
      // 同样必须放掉在飞位，否则这个键会永久失效而不是失败重试。
      onError: (Object error, StackTrace stackTrace) {
        _inFlight.remove(key);
        completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  /// 当前条目数（先顺手清掉过期条目）。测试与设置页用。
  int get entryCount {
    _evictExpired();
    return _cache.length;
  }

  /// 估算字节数。这是确定性的容量预算，不是精确的 Dart 堆计量。
  int get estimatedBytes {
    _evictExpired();
    return _cacheBytes;
  }

  /// 清空成功与负缓存。在飞请求**不**动：它跑完仍会写回缓存。
  void clear() {
    _cache.clear();
    _cacheBytes = 0;
    _negativeUntil.clear();
  }

  // ---- internals ---------------------------------------------------

  /// 发一次请求并把结果落到缓存里。
  ///
  /// 这里只负责「取数 + 落缓存」：在飞位的登记与释放在 [fetch] 里做，因为登记必须
  /// 早于本函数的函数体开始跑（见那里的注释）。本函数返回时缓存一定已经写完，
  /// 所以合并进来的调用方看不到半更新状态。
  Future<List<VideoTagItem>?> _load(
    String key,
    String bvid,
    Object? cid,
    TagFetchFn fetcher,
  ) async {
    List<VideoTagItem>? tags;
    try {
      final data = (await fetcher(bvid, cid)).dataOrNull;
      // 空结果与失败等价：都当作「这个分 P 没有可用标签」。
      if (data != null && data.isNotEmpty) tags = data;
    } catch (_) {
      // 传输层任何失败都只是没有标签，负缓存下面兜住重试。
      tags = null;
    }

    if (tags == null) {
      _negativeUntil[key] = _clock().add(negativeTagCacheTtl);
    } else {
      _negativeUntil.remove(key);
      _put(key, bvid, tags);
    }
    return tags;
  }

  void _put(String key, String bvid, List<VideoTagItem> tags) {
    final previous = _cache[key];
    if (previous != null) _cacheBytes -= previous.estimatedBytes;
    final entry = _TagCacheEntry(
      tags: tags,
      fetchedAt: _clock(),
      estimatedBytes: _estimateEntryBytes(bvid, tags),
    );
    _cache[key] = entry;
    _cacheBytes += entry.estimatedBytes;
    _evictOverflow();
  }

  static int _estimateEntryBytes(String bvid, List<VideoTagItem> tags) {
    var bytes = _estimatedEntryOverheadBytes + bvid.length * 3;
    for (final tag in tags) {
      bytes += _estimatedEntryOverheadBytes ~/ 4;
      bytes += (tag.tagName?.length ?? 0) * 3;
    }
    return bytes;
  }

  void _evictExpired() {
    if (_cache.isEmpty) return;
    final cutoff = _clock().subtract(tagCacheTtl);
    final expired = <String>[];
    for (final entry in _cache.entries) {
      if (entry.value.fetchedAt.isBefore(cutoff)) expired.add(entry.key);
    }
    for (final key in expired) {
      _drop(key);
    }
  }

  void _evictOverflow() {
    final maxBytes = tagEnrichCacheMaxBytes;
    if (_cacheBytes <= maxBytes) return;
    // 按取回时间从旧到新丢，直到回到预算内。
    final sorted = _cache.entries.toList()
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
    for (final entry in sorted) {
      if (_cacheBytes <= maxBytes) break;
      _drop(entry.key);
    }
  }

  void _drop(String key) {
    final removed = _cache.remove(key);
    if (removed != null) _cacheBytes -= removed.estimatedBytes;
    if (_cacheBytes < 0) _cacheBytes = 0;
  }
}
