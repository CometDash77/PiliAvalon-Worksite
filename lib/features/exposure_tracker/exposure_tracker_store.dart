import 'package:hive_ce/hive.dart';

import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_models.dart';

/// Testable box interface so [ExposureTrackerStore] can work with
/// an in-memory box in tests or a real Hive box in production.
abstract class ExposureTrackerBox {
  Iterable<String> get keys;
  Iterable<ExposureRecord> get values;
  int get length;
  ExposureRecord? get(String key);
  void put(String key, ExposureRecord value);
  void delete(String key);
  void clear();
}

/// Hive-backed implementation of [ExposureTrackerBox].
class HiveExposureTrackerBox implements ExposureTrackerBox {
  HiveExposureTrackerBox(this._box);

  final Box<ExposureRecord> _box;

  @override
  Iterable<String> get keys => _box.keys.cast<String>();

  @override
  Iterable<ExposureRecord> get values => _box.values;

  @override
  int get length => _box.length;

  @override
  ExposureRecord? get(String key) => _box.get(key);

  @override
  void put(String key, ExposureRecord value) => _box.put(key, value);

  @override
  void delete(String key) => _box.delete(key);

  @override
  void clear() => _box.clear();
}

/// Deterministic state machine for exposure tracking with lazy cleanup.
///
/// Call [recordAndShouldKeep] for every API-returned BV in the homepage
/// recommendation feed. The method performs lazy expiry/cooling cleanup
/// before evaluating the BV, then applies the state machine rules:
///
/// - Disabled config: silently returns `true` and writes nothing.
/// - Empty/missing BV: keeps the item and writes nothing.
/// - Active cooling (not expired): removes the item, no increment.
/// - Cooling expired: deletes old record, treats this as first exposure.
/// - Non-cooling, outside the window: deletes old record, first exposure.
/// - Non-cooling, inside the window: increments count, updates lastExposedAt.
/// - Threshold crossing: sets coolingStartAt=now, removes the item.
///
/// [clearExposure] deletes only records that are *not* in cooling;
/// cooling records survive clicks from all channels.
class ExposureTrackerStore {
  ExposureTrackerStore({
    required this.box,
    required DateTime Function() clock,
  }) : _clock = clock;

  final ExposureTrackerBox box;
  final DateTime Function() _clock;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns `true` when the item should remain visible in the feed.
  ///
  /// If [config.enabled] is `false` this is a no-op that always returns `true`
  /// and does not read or write the box.
  bool recordAndShouldKeep(String bvid, ExposureTrackerConfig config) {
    if (!config.enabled) return true;

    final normalized = config.normalized();
    final bv = bvid.trim();
    if (bv.isEmpty) return true;

    _lazyCleanup(normalized);

    final existing = box.get(bv);
    final now = _clock();

    // --- Cooling record ------------------------------------------------
    if (existing != null && existing.isCooling) {
      final coolingStart = existing.coolingStartAt!;
      final coolingAge = now.difference(coolingStart);
      if (coolingAge.inDays < normalized.coolingDays) {
        // Still cooling — remove, do not increment.
        return false;
      }
      // Cooling expired — delete and treat as first exposure.
      box.delete(bv);
      _recordFirstExposure(bv, now);
      return true;
    }

    // --- Expired non-cooling record ------------------------------------
    if (existing != null) {
      final windowAge = now.difference(existing.firstExposedAt);
      if (windowAge.inDays >= normalized.windowDays) {
        // Outside the counting window — delete and treat as first exposure.
        box.delete(bv);
        _recordFirstExposure(bv, now);
        return true;
      }
    }

    // --- First exposure ------------------------------------------------
    if (existing == null) {
      _recordFirstExposure(bv, now);
      return true;
    }

    // --- Inside the counting window ------------------------------------
    final newCount = existing.exposureCount + 1;
    final crossed = newCount >= normalized.threshold;

    final updated = existing.copyWith(
      exposureCount: newCount,
      lastExposedAt: now,
      coolingStartAt: crossed ? now : null,
      clearCoolingStartAt: !crossed,
    );
    box.put(bv, updated);

    // Threshold crossed → remove this item from the feed.
    return !crossed;
  }

  /// Deletes the record for [bvid] only when it is *not* in cooling.
  ///
  /// Cooling records survive — they represent an active filter that should
  /// not be cancelled by a click from any channel.
  void clearExposure(String bvid) {
    final bv = bvid.trim();
    if (bv.isEmpty) return;
    final record = box.get(bv);
    if (record != null && !record.isCooling) {
      box.delete(bv);
    }
  }

  /// Number of stored records (including cooling).
  int get cacheCount => box.length;

  /// Number of records currently in the cooling state.
  int get activeCoolingCount {
    var count = 0;
    for (final v in box.values) {
      if (v.isCooling) count++;
    }
    return count;
  }

  /// Deletes every record from the box.
  void clearAll() => box.clear();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Lazy cleanup: expire cooling records, expire old non-cooling records,
  /// then apply LRU eviction if still over [config.maxCacheSize].
  void _lazyCleanup(ExposureTrackerConfig config) {
    final now = _clock();

    // 1. Expire cooling records whose cooling period has elapsed.
    final toDelete = <String>[];
    for (final entry in box.values) {
      if (entry.isCooling) {
        final age = now.difference(entry.coolingStartAt!);
        if (age.inDays >= config.coolingDays) {
          toDelete.add(entry.bvid);
        }
        continue;
      }
      // Non-cooling records: expire those outside the counting window.
      final age = now.difference(entry.firstExposedAt);
      if (age.inDays >= config.windowDays) {
        toDelete.add(entry.bvid);
      }
    }
    for (final bvid in toDelete) {
      box.delete(bvid);
    }

    // 2. LRU eviction by oldest lastExposedAt.
    _lruEvict(config.maxCacheSize);
  }

  void _lruEvict(int maxCacheSize) {
    while (box.length > maxCacheSize) {
      String? oldestBvid;
      DateTime? oldestLast;
      for (final entry in box.values) {
        if (oldestLast == null || entry.lastExposedAt.isBefore(oldestLast)) {
          oldestLast = entry.lastExposedAt;
          oldestBvid = entry.bvid;
        }
      }
      if (oldestBvid == null) break;
      box.delete(oldestBvid!);
    }
  }

  void _recordFirstExposure(String bvid, DateTime now) {
    box.put(
      bvid,
      ExposureRecord(
        bvid: bvid,
        exposureCount: 1,
        firstExposedAt: now,
        lastExposedAt: now,
      ),
    );
  }
}
