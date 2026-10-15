import 'package:PiliPlus/features/shielding/recommendation_tag_store.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

// The tag-cache settings live with the store that spends the budget; they are
// re-exported here because this file is the entry point callers already import.
export 'package:PiliPlus/features/shielding/recommendation_tag_store.dart'
    show tagEnrichCacheMaxBytes, tagEnrichCacheMaxMb;

// -- internal constants (not user-facing) ---------------------------
const bool _tagEnrichmentEnabled = true;
const int _defaultConcurrency = 5;
const int _defaultTimeoutSeconds = 3;

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

/// Drives detail-tag enrichment + tag-only second-pass shielding for
/// recommendation survivors.
///
/// Fetching, caching and de-duplication all live in [RecommendationTagStore],
/// which the recommendation surface and the video detail page share; this class
/// only does "get the tags, then judge *those* tags with the current batch".
/// The default [fetchTags] is [defaultVideoTagFetch] (which calls
/// `UserHttp.videoTags`); tests inject a stub so they never hit the network.
class RecommendationTagEnricher {
  RecommendationTagEnricher({
    TagFetchFn? fetchTags,
    RecommendationTagStore? store,
  }) : _fetchTags = fetchTags ?? defaultVideoTagFetch,
       _store = store ?? _sharedStore;

  final TagFetchFn _fetchTags;
  final RecommendationTagStore _store;

  static final RecommendationTagStore _sharedStore =
      RecommendationTagStore.instance;

  // ---- public API --------------------------------------------------

  /// The one shared tag entry point: recommendation surfaces and the video
  /// detail page both go through it, so a tag fetched for one is reused by the
  /// other within the cache lifetime.
  ///
  /// No request is issued on a cache hit or when the call merges into an
  /// in-flight request. [fetcher] overrides the transport for this call and is
  /// only consulted by the caller that actually starts the request.
  static Future<List<VideoTagItem>?> fetchSharedTags({
    required String bvid,
    Object? cid,
    TagFetchFn? fetcher,
  }) => _sharedStore.fetch(bvid, cid, fetcher: fetcher);

  /// Clears the shared tag cache. Intended for tests and the settings page's
  /// "clear cache" action.
  static void resetCache() => _sharedStore.clear();

  /// Returns the current number of cached entries. Intended for tests.
  static int get cacheEntryCount => _sharedStore.entryCount;

  /// Returns estimated cache bytes. This is a deterministic capacity
  /// budget, not exact Dart heap accounting.
  static int get cacheEstimatedBytes => _sharedStore.estimatedBytes;

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

    // We use a dense result array indexed by the survivor position so
    // that ordering is preserved; a null slot means "dropped".
    final results = List<T?>.filled(survivors.length, null);
    final pendingIndices = <int>[];

    for (int i = 0; i < survivors.length; i++) {
      final item = survivors[i];
      if (getBvid(item) == null) {
        // No bvid → nothing to fetch → fail-open (keep the item).
        results[i] = item;
      } else {
        pendingIndices.add(i);
      }
    }

    await _enrichSurvivors(
      survivors,
      pendingIndices,
      results,
      shieldRuleSet,
      getBvid,
      getCid,
    );

    return results.whereType<T>().toList();
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

  Future<void> _enrichSurvivors<T>(
    List<T> survivors,
    List<int> pendingIndices,
    List<T?> results,
    ShieldRuleSet shieldRuleSet,
    String? Function(T item) getBvid,
    Object? Function(T item) getCid,
  ) async {
    if (pendingIndices.isEmpty) return;

    // Workers pop from the tail of this local copy, so no two workers ever
    // take the same index.
    final queue = pendingIndices.toList();

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        final item = survivors[index];
        final bvid = getBvid(item)!; // safe: null-bvid items never reach here

        final tagNames = await _loadTagNames(bvid, getCid(item));
        if (tagNames == null) {
          // No usable tags (negative cache hit, failure, empty, timeout)
          // → fail-open.
          results[index] = item;
        } else if (_tagOnlySecondPass(tagNames, shieldRuleSet)) {
          results[index] = item;
        }
        // else: blocked by detail tags → dropped.
      }
    }

    final concurrency = tagEnrichConcurrency;
    final workerCount = concurrency < queue.length ? concurrency : queue.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  /// The usable tag names of one video part, or null when there are none.
  ///
  /// Duplicate keys inside one batch — and identical keys in another batch
  /// still in flight — share a single upstream request through the store.
  ///
  /// The timeout only stops *this* caller from waiting: the shared request
  /// keeps running and still writes its result into the shared cache.
  Future<List<String>?> _loadTagNames(String bvid, Object? cid) async {
    try {
      final tags = await _store
          .fetch(bvid, cid, fetcher: _fetchTags)
          .timeout(tagEnrichTimeout);
      if (tags == null || tags.isEmpty) return null;
      final tagNames = tags
          .map((t) => t.tagName)
          .whereType<String>()
          .where((n) => n.trim().isNotEmpty)
          .toList();
      return tagNames.isEmpty ? null : tagNames;
    } catch (_) {
      // Timeout (or anything unexpected) → fail-open: no tags, keep the item.
      return null;
    }
  }
}
