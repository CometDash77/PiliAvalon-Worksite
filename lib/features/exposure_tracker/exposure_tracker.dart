import 'package:flutter/foundation.dart';

import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_models.dart';
import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_store.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

/// Public singleton for the homepage recommendation repeat-exposure prefilter.
///
/// The singleton lazily wraps [GStorage.exposureTracker] on first use, so no
/// explicit initialisation call is needed.  All public methods are synchronous
/// and safe to call before the Hive box is open — they behave as no-ops until
/// the box is available.
class ExposureTracker {
  ExposureTracker._();
  static final ExposureTracker instance = ExposureTracker._();

  ExposureTrackerStore? _store;

  /// Test-only: inject a store so tests can run without Hive.
  @visibleForTesting
  set testStore(ExposureTrackerStore? store) => _store = store;

  /// Returns the store (creating it lazily from [GStorage.exposureTracker]),
  /// or `null` when the Hive box is not yet open.
  ExposureTrackerStore? get _ensureStore {
    if (_store != null) return _store;
    try {
      _store = ExposureTrackerStore(
        box: HiveExposureTrackerBox(GStorage.exposureTracker),
        clock: DateTime.now,
      );
    } catch (_) {
      // Box not yet open — leave _store null.
    }
    return _store;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Filters the recommendation list through the exposure state machine and
  /// records new exposures.
  ///
  /// When the feature is disabled (or the store is not yet initialised) the
  /// original [items] list is returned unchanged and nothing is written.
  ///
  /// [getBvid] extracts the BV ID string from an item.  Items whose BV is
  /// null, empty, or whitespace are kept and not recorded.
  List<T> filterAndRecord<T>(
    List<T> items, {
    required String? Function(T) getBvid,
  }) {
    final store = _ensureStore;
    if (store == null) return items;

    final config = _loadConfig();
    if (!config.enabled) return items;

    // Build filtered list — the config normalization is done inside the store
    // per-call so we can pass the raw config here.
    final kept = <T>[];
    for (final item in items) {
      final bvid = getBvid(item);
      if (bvid == null || store.recordAndShouldKeep(bvid, config)) {
        kept.add(item);
      }
    }
    return kept;
  }

  /// Removes the counting record for [bvid] when it is *not* in cooling.
  ///
  /// Cooling records survive — they represent an active filter that should
  /// not be cancelled by a click from any channel.
  void clearExposure(String bvid) {
    _ensureStore?.clearExposure(bvid);
  }

  /// Total number of records in the cache (counting + cooling).
  int get cacheCount => _ensureStore?.cacheCount ?? 0;

  /// Number of records currently in cooling state.
  int get activeCoolingCount => _ensureStore?.activeCoolingCount ?? 0;

  /// Removes all records from the cache.
  void clearAll() => _ensureStore?.clearAll();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  ExposureTrackerConfig _loadConfig() {
    return ExposureTrackerConfig(
      enabled: GStorage.setting.get(
        SettingBoxKey.repeatExposureFilterEnabled,
        defaultValue: false,
      ) as bool? ?? false,
      windowDays: GStorage.setting.get(
        SettingBoxKey.repeatExposureWindowDays,
        defaultValue: 7,
      ) as int? ?? 7,
      threshold: GStorage.setting.get(
        SettingBoxKey.repeatExposureThreshold,
        defaultValue: 10,
      ) as int? ?? 10,
      coolingDays: GStorage.setting.get(
        SettingBoxKey.repeatExposureCoolingDays,
        defaultValue: 30,
      ) as int? ?? 30,
      maxCacheSize: GStorage.setting.get(
        SettingBoxKey.repeatExposureMaxCacheSize,
        defaultValue: 5000,
      ) as int? ?? 5000,
    );
  }
}
