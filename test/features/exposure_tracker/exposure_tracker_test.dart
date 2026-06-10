// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:PiliPlus/features/exposure_tracker/exposure_tracker.dart';
import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_models.dart';
import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_store.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// ---------------------------------------------------------------------------
// In-memory box for deterministic testing
// ---------------------------------------------------------------------------

class _MemoryExposureBox implements ExposureTrackerBox {
  _MemoryExposureBox([Map<String, ExposureRecord>? seed])
    : valuesByKey = {...?seed};

  final Map<String, ExposureRecord> valuesByKey;

  @override
  Iterable<String> get keys => valuesByKey.keys;

  @override
  Iterable<ExposureRecord> get values => valuesByKey.values;

  @override
  int get length => valuesByKey.length;

  @override
  ExposureRecord? get(String key) => valuesByKey[key];

  @override
  void put(String key, ExposureRecord value) {
    valuesByKey[key] = value;
  }

  @override
  void delete(String key) {
    valuesByKey.remove(key);
  }

  @override
  void clear() {
    valuesByKey.clear();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('ExposureTracker', () {
    final base = DateTime.fromMillisecondsSinceEpoch(1000000);

    setUp(() {
      // Ensure settings are clean for each test.
      GStorage.setting.delete(SettingBoxKey.repeatExposureFilterEnabled);
      GStorage.setting.delete(SettingBoxKey.repeatExposureWindowDays);
      GStorage.setting.delete(SettingBoxKey.repeatExposureThreshold);
      GStorage.setting.delete(SettingBoxKey.repeatExposureCoolingDays);
      GStorage.setting.delete(SettingBoxKey.repeatExposureMaxCacheSize);
    });

    tearDown(() {
      ExposureTracker.instance.testStore = null;
    });

    ExposureTrackerStore storeWithBox(_MemoryExposureBox box) {
      return ExposureTrackerStore(box: box, clock: () => base);
    }

    // ---- Disabled -------------------------------------------------------

    test('disabled config returns same list object and writes nothing', () {
      final box = _MemoryExposureBox();
      ExposureTracker.instance.testStore = storeWithBox(box);

      final items = ['BV1', 'BV2', 'BV3'];

      // Feature off by default (no setting put).
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s,
      );

      // Same list object returned — nothing filtered, nothing written.
      expect(identical(result, items), isTrue);
      expect(box.valuesByKey.isEmpty, isTrue);
    });

    // ---- Enabled, first exposure ----------------------------------------

    test('first exposure is kept and counted', () {
      final box = _MemoryExposureBox();
      ExposureTracker.instance.testStore = storeWithBox(box);

      // Enable the feature.
      GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);

      final items = ['BV1', 'BV2'];
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s,
      );

      expect(result, items);
      expect(box.valuesByKey['BV1']!.exposureCount, 1);
      expect(box.valuesByKey['BV2']!.exposureCount, 1);
    });

    // ---- Empty BV -------------------------------------------------------

    test('empty BV is kept and not recorded', () {
      final box = _MemoryExposureBox();
      ExposureTracker.instance.testStore = storeWithBox(box);
      GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);

      final items = ['', 'BV2'];
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s,
      );

      expect(result.length, 2);
      expect(box.valuesByKey.containsKey(''), isFalse);
      expect(box.valuesByKey.containsKey('BV2'), isTrue);
    });

    test('null BV is kept and not recorded', () {
      final box = _MemoryExposureBox();
      ExposureTracker.instance.testStore = storeWithBox(box);
      GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);

      final items = ['missing', 'BV2'];
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s == 'missing' ? null : s,
      );

      expect(result.length, 2);
      expect(box.valuesByKey.containsKey('missing'), isFalse);
      expect(box.valuesByKey.containsKey('BV2'), isTrue);
    });

    // ---- Threshold crossing ---------------------------------------------

    test('threshold crossing starts cooling and removes current item', () {
      final box = _MemoryExposureBox();
      // Pre-populate at count 2 — next exposure crosses threshold 3.
      box.put(
        'BV1',
        ExposureRecord(
          bvid: 'BV1',
          exposureCount: 2,
          firstExposedAt: base,
          lastExposedAt: base,
        ),
      );
      ExposureTracker.instance.testStore = storeWithBox(box);
      GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);
      GStorage.setting.put(SettingBoxKey.repeatExposureThreshold, 3);

      final items = ['BV1', 'BV2'];
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s,
      );

      // BV1 crossed threshold — removed from result.
      expect(result, ['BV2']);
      expect(box.valuesByKey['BV1']!.isCooling, isTrue);
      expect(box.valuesByKey['BV1']!.exposureCount, 3);
    });

    // ---- Active cooling removes without incrementing --------------------

    test('active cooling removes without incrementing', () {
      final box = _MemoryExposureBox();
      final coolingStart = base.subtract(const Duration(days: 1));
      box.put(
        'BV1',
        ExposureRecord(
          bvid: 'BV1',
          exposureCount: 3,
          firstExposedAt: base.subtract(const Duration(days: 2)),
          lastExposedAt: base.subtract(const Duration(days: 1)),
          coolingStartAt: coolingStart,
        ),
      );
      ExposureTracker.instance.testStore = storeWithBox(box);
      GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);

      final items = ['BV1', 'BV2'];
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s,
      );

      // BV1 is cooling — removed from result, count unchanged.
      expect(result, ['BV2']);
      expect(box.valuesByKey['BV1']!.exposureCount, 3);
    });

    // ---- clearExposure --------------------------------------------------

    test('clearExposure deletes non-cooling record', () {
      final box = _MemoryExposureBox();
      box.put(
        'BV1',
        ExposureRecord(
          bvid: 'BV1',
          exposureCount: 2,
          firstExposedAt: base,
          lastExposedAt: base,
        ),
      );
      ExposureTracker.instance.testStore = storeWithBox(box);

      ExposureTracker.instance.clearExposure('BV1');

      expect(box.valuesByKey.containsKey('BV1'), isFalse);
    });

    test('clearExposure does not delete cooling record', () {
      final box = _MemoryExposureBox();
      box.put(
        'BV1',
        ExposureRecord(
          bvid: 'BV1',
          exposureCount: 3,
          firstExposedAt: base.subtract(const Duration(days: 2)),
          lastExposedAt: base.subtract(const Duration(days: 1)),
          coolingStartAt: base,
        ),
      );
      ExposureTracker.instance.testStore = storeWithBox(box);

      ExposureTracker.instance.clearExposure('BV1');

      expect(box.valuesByKey.containsKey('BV1'), isTrue);
    });

    // ---- cacheCount / activeCoolingCount --------------------------------

    test('cacheCount and activeCoolingCount reflect store state', () {
      final box = _MemoryExposureBox({
        'BV1': ExposureRecord(
          bvid: 'BV1',
          exposureCount: 1,
          firstExposedAt: base,
          lastExposedAt: base,
        ),
        'BV2': ExposureRecord(
          bvid: 'BV2',
          exposureCount: 5,
          firstExposedAt: base,
          lastExposedAt: base,
          coolingStartAt: base,
        ),
      });
      ExposureTracker.instance.testStore = storeWithBox(box);

      expect(ExposureTracker.instance.cacheCount, 2);
      expect(ExposureTracker.instance.activeCoolingCount, 1);
    });

    // ---- clearAll -------------------------------------------------------

    test('clearAll removes all records', () {
      final box = _MemoryExposureBox({
        'BV1': ExposureRecord(
          bvid: 'BV1',
          exposureCount: 1,
          firstExposedAt: base,
          lastExposedAt: base,
        ),
      });
      ExposureTracker.instance.testStore = storeWithBox(box);

      ExposureTracker.instance.clearAll();

      expect(box.valuesByKey.isEmpty, isTrue);
    });

    // ---- LRU eviction via tracker ---------------------------------------

    test('LRU eviction removes oldest lastExposedAt', () {
      final box = _MemoryExposureBox({
        'BV1': ExposureRecord(
          bvid: 'BV1',
          exposureCount: 1,
          firstExposedAt: base,
          lastExposedAt: base, // oldest
        ),
        'BV2': ExposureRecord(
          bvid: 'BV2',
          exposureCount: 1,
          firstExposedAt: base.add(const Duration(days: 1)),
          lastExposedAt: base.add(const Duration(days: 1)),
        ),
        'BV3': ExposureRecord(
          bvid: 'BV3',
          exposureCount: 1,
          firstExposedAt: base.add(const Duration(days: 2)),
          lastExposedAt: base.add(const Duration(days: 2)),
        ),
      });
      ExposureTracker.instance.testStore = storeWithBox(box);
      GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);
      GStorage.setting.put(SettingBoxKey.repeatExposureMaxCacheSize, 2);

      final items = ['BV4'];
      ExposureTracker.instance.filterAndRecord(items, getBvid: (s) => s);

      // LRU should have evicted BV1 (oldest lastExposedAt).
      expect(box.valuesByKey.length, lessThanOrEqualTo(2));
      expect(box.valuesByKey.containsKey('BV1'), isFalse);
      expect(box.valuesByKey.containsKey('BV4'), isTrue);
    });

    // ---- Null store (before init) ---------------------------------------

    test('returns items unchanged when store is null', () {
      ExposureTracker.instance.testStore = null;

      final items = ['BV1', 'BV2'];
      final result = ExposureTracker.instance.filterAndRecord(
        items,
        getBvid: (s) => s,
      );

      expect(identical(result, items), isTrue);
    });
  });
}
