import 'dart:async';

import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/utils/recommendation_metrics.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

// -- internal constants (not user-facing) ---------------------------
const bool _tagEnrichmentEnabled = true;
const int _defaultConcurrency = 5;
const int _defaultTimeoutSeconds = 3;
const Duration _tagCacheTTL = Duration(minutes: 30);
const Duration _negativeTagCacheTTL = Duration(seconds: 30);
const int _defaultTagCacheMaxMb = 10;
const int _maxTagCacheMaxMb = 50;
const int _bytesPerMb = 1024 * 1024;
const int _estimatedEntryOverheadBytes = 96;

/// Reads the configured concurrency cap from settings, clamping to [1, 10].
int get tagEnrichConcurrency {
  final raw = GStorage.setting.get(
    SettingBoxKey.tagEnrichConcurrency,
    defaultValue: _defaultConcurrency,
  );
  if (raw is! int) return _defaultConcurrency;
  return raw.clamp(1, 10);
}

/// Reads the configured per-request timeout from settings, clamping to [1, 10]
/// seconds.
Duration get tagEnrichTimeout {
  final raw = GStorage.setting.get(
    SettingBoxKey.tagEnrichTimeout,
    defaultValue: _defaultTimeoutSeconds,
  );
  if (raw is! int) return const Duration(seconds: _defaultTimeoutSeconds);
  return Duration(seconds: raw.clamp(1, 10));
}

/// Reads the configured estimated tag-cache budget in MB, clamped to [1, 50].
int get tagEnrichCacheMaxMb {
  final raw = GStorage.setting.get(
    SettingBoxKey.tagEnrichCacheMaxMb,
    defaultValue: _defaultTagCacheMaxMb,
  );
  if (raw is! int) return _defaultTagCacheMaxMb;
  return raw.clamp(1, _maxTagCacheMaxMb);
}

int get tagEnrichCacheMaxBytes => tagEnrichCacheMaxMb * _bytesPerMb;

// -- cache entry -----------------------------------------------------

class _TagCacheEntry {
  const _TagCacheEntry({
    required this.tags,
    required this.fetchedAt,
    required this.estimatedBytes,
  });

  final List<VideoTagItem>? tags;
  final DateTime fetchedAt;
  final int estimatedBytes;

  bool get isNegative => tags == null;
}

/// Drives detail-tag enrichment + tag-only second-pass shielding for
/// recommendation survivors.
///
/// The default [fetchTags] uses [UserHttp.videoTags].  Tests inject a
/// stub so they never hit the network.
class RecommendationTagEnricher {
  RecommendationTagEnricher({
    Future<LoadingState<List<VideoTagItem>?>> Function(
      String bvid,
      Object? cid,
    )?
    fetchTags,
  }) : _fetchTags =
           fetchTags ??
           ((String bvid, Object? cid) =>
               UserHttp.videoTags(bvid: bvid, cid: cid));

  final Future<LoadingState<List<VideoTagItem>?>> Function(
    String bvid,
    Object? cid,
  )
  _fetchTags;

  static final Map<(String, Object?), _TagCacheEntry> _cache = {};
  static final Map<(String, Object?), Future<LoadingState<List<VideoTagItem>?>>>
  _inFlight = {};
  static int _cacheBytes = 0;

  /// Clears the shared static cache. Intended for tests; production
  /// code should not need to call this.
  static void resetCache() {
    _cache.clear();
    _inFlight.clear();
    _cacheBytes = 0;
  }

  /// Returns the current number of cached entries. Intended for tests.
  static int get cacheEntryCount => _cache.length;

  /// Returns estimated cache bytes. This is a deterministic capacity
  /// budget, not exact Dart heap accounting.
  static int get cacheEstimatedBytes => _cacheBytes;

  // ---- public API --------------------------------------------------

  /// Returns the subset of [survivors] that pass the tag-only second
  /// shielding pass after their detail tags are enriched.
  ///
  /// [getBvid] / [getCid] extract the identifiers from a survivor item.
  /// Items whose bvid is `null` or whose tag fetch fails are kept
  /// (fail-open).
  Future<List<T>> enrichAndFilter<T>(
    List<T> survivors,
    ShieldRuleSet shieldRuleSet, {
    required String? Function(T item) getBvid,
    required Object? Function(T item) getCid,
  }) async {
    if (!_tagEnrichmentEnabled || survivors.isEmpty) return survivors;

    final measurement = RecommendationMetrics.startPhase(
      RecommendationPhase.tagEnrichment,
      inputCount: survivors.length,
    );
    _evictExpiredCache();
    _evictOverflow();

    // We use a dense result array indexed by the survivor position so
    // that ordering is preserved.
    final results = List<T?>.filled(survivors.length, null);
    final pendingIndices = <int>[];

    for (int i = 0; i < survivors.length; i++) {
      final item = survivors[i];
      final bvid = getBvid(item);
      if (bvid == null) {
        // No bvid → cannot fetch → fail-open (keep the item).
        results[i] = item;
        continue;
      }

      final cached = _cache[(bvid, getCid(item))];
      if (cached != null) {
        final tagNames = _tagNames(cached.tags);
        if (tagNames == null || _tagOnlySecondPass(tagNames, shieldRuleSet)) {
          results[i] = item;
        }
        // else: blocked by detail tags → drop
      } else {
        pendingIndices.add(i);
      }
    }

    if (pendingIndices.isNotEmpty) {
      await _fetchWithConcurrency(
        survivors,
        pendingIndices,
        results,
        shieldRuleSet,
        getBvid,
        getCid,
      );
      _evictOverflow();
    }

    final filtered = results.whereType<T>().toList();
    RecommendationMetrics.finishPhase(
      measurement,
      outputCount: filtered.length,
    );
    return filtered;
  }

  // ---- internals ---------------------------------------------------

  bool _tagOnlySecondPass(
    List<String> tagNames,
    ShieldRuleSet shieldRuleSet,
  ) {
    final candidate = ShieldCandidate(
      scope: ShieldScope.recommendation,
      tags: tagNames,
    );
    return ShieldMatcher.match(candidate, shieldRuleSet).visible;
  }

  Future<void> _fetchWithConcurrency<T>(
    List<T> survivors,
    List<int> pendingIndices,
    List<T?> results,
    ShieldRuleSet shieldRuleSet,
    String? Function(T item) getBvid,
    Object? Function(T item) getCid,
  ) async {
    // Protect against mutation during concurrent work.
    final queue = pendingIndices.toList();

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        final item = survivors[index];
        final bvid = getBvid(item)!; // safe: null-bvid items never reach here
        final cid = getCid(item);
        final key = (bvid, cid);
        final res = await _fetchSharedTags(key, _fetchTags);
        final tags = res.dataOrNull;
        final tagNames = _tagNames(tags);

        if (tagNames != null && tagNames.isNotEmpty) {
          // Success: cache and then run second pass.
          if (_tagOnlySecondPass(tagNames, shieldRuleSet)) {
            results[index] = item;
          }
          // else: blocked by detail tags → drop
        } else {
          // No usable tags (empty, fetch failed, etc.) → fail-open.
          results[index] = item;
        }
      }
    }

    final concurrency = tagEnrichConcurrency;
    final workerCount = concurrency < pendingIndices.length
        ? concurrency
        : pendingIndices.length;
    await Future.wait(
      List.generate(workerCount, (_) => worker()),
    );
  }

  /// Shared by recommendation enrichment and the video detail page so both
  /// surfaces use the same cache and coalesce concurrent requests.
  static Future<LoadingState<List<VideoTagItem>?>> fetchSharedTags({
    required String bvid,
    Object? cid,
  }) => _fetchSharedTags(
    (bvid, cid),
    (keyBvid, keyCid) => UserHttp.videoTags(bvid: keyBvid, cid: keyCid),
  );

  static Future<LoadingState<List<VideoTagItem>?>> _fetchSharedTags(
    (String, Object?) key,
    Future<LoadingState<List<VideoTagItem>?>> Function(String, Object?) fetch,
  ) {
    _evictExpiredCache();
    final cached = _cache[key];
    if (cached != null) {
      return Future.value(
        cached.isNegative
            ? const Error('Temporarily cached tag lookup failure')
            : Success(cached.tags),
      );
    }
    final existing = _inFlight[key];
    if (existing != null) return existing;

    late final Future<LoadingState<List<VideoTagItem>?>> request;
    request = () async {
      LoadingState<List<VideoTagItem>?> result;
      try {
        result = await Future<LoadingState<List<VideoTagItem>?>>.sync(
          () => fetch(key.$1, key.$2),
        ).timeout(tagEnrichTimeout);
      } catch (error) {
        result = Error(error.toString());
      }

      final tags = result.dataOrNull;
      if (tags != null && tags.isNotEmpty) {
        _putCacheEntry(key, tags);
      } else {
        _putNegativeCacheEntry(key);
      }
      _inFlight.remove(key);
      _evictOverflow();
      return result;
    }();
    _inFlight[key] = request;
    return request;
  }

  static List<String>? _tagNames(List<VideoTagItem>? tags) {
    if (tags == null || tags.isEmpty) return null;
    final names = tags
        .map((tag) => tag.tagName)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
    return names.isEmpty ? null : names;
  }

  static void _putCacheEntry((String, Object?) key, List<VideoTagItem> tags) {
    final estimatedBytes = _estimateEntryBytes(key.$1, tags);
    final previous = _cache[key];
    if (previous != null) {
      _cacheBytes -= previous.estimatedBytes;
    }
    _cache[key] = _TagCacheEntry(
      tags: List.unmodifiable(tags),
      fetchedAt: DateTime.now(),
      estimatedBytes: estimatedBytes,
    );
    _cacheBytes += estimatedBytes;
  }

  static void _putNegativeCacheEntry((String, Object?) key) {
    final previous = _cache.remove(key);
    if (previous != null) _cacheBytes -= previous.estimatedBytes;
    _cache[key] = _TagCacheEntry(
      tags: null,
      fetchedAt: DateTime.now(),
      estimatedBytes: _estimatedEntryOverheadBytes + key.$1.length * 3,
    );
    _cacheBytes += _cache[key]!.estimatedBytes;
  }

  static int _estimateEntryBytes(String bvid, List<VideoTagItem> tags) {
    var bytes = _estimatedEntryOverheadBytes + bvid.length * 3;
    for (final tag in tags) {
      bytes += _estimatedEntryOverheadBytes ~/ 4;
      bytes += (tag.tagName?.length ?? 0) * 3;
      bytes += (tag.tagType?.length ?? 0) * 3;
    }
    return bytes;
  }

  static void _evictExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <(String, Object?)>[];
    for (final entry in _cache.entries) {
      final ttl = entry.value.isNegative ? _negativeTagCacheTTL : _tagCacheTTL;
      if (entry.value.fetchedAt.add(ttl).isBefore(now)) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      final removed = _cache.remove(key);
      if (removed != null) {
        _cacheBytes -= removed.estimatedBytes;
      }
    }
    if (_cacheBytes < 0) _cacheBytes = 0;
  }

  static void _evictOverflow() {
    final maxBytes = tagEnrichCacheMaxBytes;
    if (_cacheBytes <= maxBytes) return;
    final sorted = _cache.entries.toList()
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
    for (final entry in sorted) {
      if (_cacheBytes <= maxBytes) break;
      _cache.remove(entry.key);
      _cacheBytes -= entry.value.estimatedBytes;
    }
    if (_cacheBytes < 0) _cacheBytes = 0;
  }
}
