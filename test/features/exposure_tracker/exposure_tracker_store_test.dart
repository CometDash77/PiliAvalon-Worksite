import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_models.dart';
import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_store.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('ExposureRecord', () {
    test('copyWith preserves unchanged fields and updates cooling state', () {
      final first = DateTime.fromMillisecondsSinceEpoch(1000);
      final last = DateTime.fromMillisecondsSinceEpoch(2000);
      final cooling = DateTime.fromMillisecondsSinceEpoch(3000);
      final record = ExposureRecord(
        bvid: 'BV1',
        exposureCount: 2,
        firstExposedAt: first,
        lastExposedAt: last,
      );

      final updated = record.copyWith(
        exposureCount: 3,
        coolingStartAt: cooling,
      );

      expect(updated.bvid, 'BV1');
      expect(updated.exposureCount, 3);
      expect(updated.firstExposedAt, first);
      expect(updated.lastExposedAt, last);
      expect(updated.coolingStartAt, cooling);
      expect(updated.isCooling, isTrue);
    });

    test('config clamps invalid stored values to supported ranges', () {
      final config = const ExposureTrackerConfig(
        enabled: true,
        windowDays: -1,
        threshold: 1,
        coolingDays: 999,
        maxCacheSize: 0,
      ).normalized();

      expect(config.windowDays, 1);
      expect(config.threshold, 2);
      expect(config.coolingDays, 90);
      expect(config.maxCacheSize, 1);
    });
  });

  group('ExposureTrackerStore', () {
    final base = DateTime.fromMillisecondsSinceEpoch(1000000);
    const enabled = ExposureTrackerConfig(
      enabled: true,
      windowDays: 7,
      threshold: 3,
      coolingDays: 30,
      maxCacheSize: 5000,
    );
    const disabled = ExposureTrackerConfig(enabled: false);

    // ---- Disabled -------------------------------------------------------

    test('disabled config returns true and writes nothing', () {
      final box = _MemoryExposureBox();
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('BV1', disabled);

      expect(visible, isTrue);
      expect(box.valuesByKey.isEmpty, isTrue);
    });

    // ---- First exposure --------------------------------------------------

    test('records first exposure and keeps item visible', () {
      final box = _MemoryExposureBox();
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('BV1', enabled);

      expect(visible, isTrue);
      expect(box.valuesByKey['BV1']!.exposureCount, 1);
      expect(box.valuesByKey['BV1']!.firstExposedAt, base);
      expect(box.valuesByKey['BV1']!.lastExposedAt, base);
      expect(box.valuesByKey['BV1']!.coolingStartAt, isNull);
    });

    // ---- Empty/missing BV -----------------------------------------------

    test('empty BV is kept and not recorded', () {
      final box = _MemoryExposureBox();
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('', enabled);

      expect(visible, isTrue);
      expect(box.valuesByKey.isEmpty, isTrue);
    });

    test('whitespace BV is kept and not recorded', () {
      final box = _MemoryExposureBox();
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('   ', enabled);

      expect(visible, isTrue);
      expect(box.valuesByKey.isEmpty, isTrue);
    });

    // ---- Counting / threshold crossing ----------------------------------

    test('increments count inside window without crossing threshold', () {
      final box = _MemoryExposureBox();
      final store = ExposureTrackerStore(box: box, clock: () => base);

      store.recordAndShouldKeep('BV1', enabled); // 1
      final t2 = base.add(const Duration(seconds: 1));
      final store2 = ExposureTrackerStore(box: box, clock: () => t2);
      final visible = store2.recordAndShouldKeep('BV1', enabled); // 2

      expect(visible, isTrue);
      expect(box.valuesByKey['BV1']!.exposureCount, 2);
    });

    test('threshold crossing starts cooling and removes item', () {
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
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('BV1', enabled);

      expect(visible, isFalse);
      expect(box.valuesByKey['BV1']!.exposureCount, 3);
      expect(box.valuesByKey['BV1']!.coolingStartAt, base);
      expect(box.valuesByKey['BV1']!.isCooling, isTrue);
    });

    // ---- Active cooling -------------------------------------------------

    test('active cooling removes item without incrementing', () {
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
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('BV1', enabled);

      expect(visible, isFalse);
      // Count should NOT have changed.
      expect(box.valuesByKey['BV1']!.exposureCount, 3);
    });

    // ---- Cooling expiry -------------------------------------------------

    test('cooling expiry deletes record and treats as first exposure', () {
      final box = _MemoryExposureBox();
      final coolingStart = base.subtract(const Duration(days: 31));
      box.put(
        'BV1',
        ExposureRecord(
          bvid: 'BV1',
          exposureCount: 5,
          firstExposedAt: base.subtract(const Duration(days: 33)),
          lastExposedAt: base.subtract(const Duration(days: 31)),
          coolingStartAt: coolingStart,
        ),
      );
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('BV1', enabled);

      expect(visible, isTrue);
      expect(box.valuesByKey['BV1']!.exposureCount, 1);
      expect(box.valuesByKey['BV1']!.coolingStartAt, isNull);
    });

    // ---- Counting-window expiry -----------------------------------------

    test('counting-window expiry deletes record and treats as first exposure', () {
      final box = _MemoryExposureBox();
      box.put(
        'BV1',
        ExposureRecord(
          bvid: 'BV1',
          exposureCount: 2,
          firstExposedAt: base.subtract(const Duration(days: 8)),
          lastExposedAt: base.subtract(const Duration(days: 6)),
        ),
      );
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('BV1', enabled);

      expect(visible, isTrue);
      expect(box.valuesByKey['BV1']!.exposureCount, 1);
      expect(box.valuesByKey['BV1']!.firstExposedAt, base);
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
      final store = ExposureTrackerStore(box: box, clock: () => base);

      store.clearExposure('BV1');

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
      final store = ExposureTrackerStore(box: box, clock: () => base);

      store.clearExposure('BV1');

      expect(box.valuesByKey.containsKey('BV1'), isTrue);
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
        'BV2': ExposureRecord(
          bvid: 'BV2',
          exposureCount: 5,
          firstExposedAt: base,
          lastExposedAt: base,
          coolingStartAt: base,
        ),
      });
      final store = ExposureTrackerStore(box: box, clock: () => base);

      store.clearAll();

      expect(box.valuesByKey.isEmpty, isTrue);
    });

    // ---- cacheCount -----------------------------------------------------

    test('cacheCount returns number of records', () {
      final box = _MemoryExposureBox({
        'BV1': ExposureRecord(
          bvid: 'BV1',
          exposureCount: 1,
          firstExposedAt: base,
          lastExposedAt: base,
        ),
      });
      final store = ExposureTrackerStore(box: box, clock: () => base);

      expect(store.cacheCount, 1);
    });

    // ---- activeCoolingCount ---------------------------------------------

    test('activeCoolingCount returns number of cooling records', () {
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
        'BV3': ExposureRecord(
          bvid: 'BV3',
          exposureCount: 10,
          firstExposedAt: base,
          lastExposedAt: base,
          coolingStartAt: base,
        ),
      });
      final store = ExposureTrackerStore(box: box, clock: () => base);

      expect(store.activeCoolingCount, 2);
    });

    // ---- LRU eviction ---------------------------------------------------

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
      const smallConfig = ExposureTrackerConfig(
        enabled: true,
        windowDays: 7,
        threshold: 3,
        coolingDays: 30,
        maxCacheSize: 2,
      );
      final store = ExposureTrackerStore(box: box, clock: () => base);

      store.recordAndShouldKeep('BV4', smallConfig);

      // LRU should have evicted BV1 (oldest lastExposedAt).
      expect(box.valuesByKey.length, lessThanOrEqualTo(2));
      expect(box.valuesByKey.containsKey('BV1'), isFalse);
      expect(box.valuesByKey.containsKey('BV4'), isTrue);
    });

    // ---- Config normalization inside store ------------------------------

    test('store normalizes config on each call', () {
      final box = _MemoryExposureBox();
      const badConfig = ExposureTrackerConfig(
        enabled: true,
        windowDays: 0, // below min
        threshold: 1, // below min
        coolingDays: 100, // above max
        maxCacheSize: 0, // below min
      );
      final store = ExposureTrackerStore(box: box, clock: () => base);

      // Should not throw — normalised to valid range.
      final visible = store.recordAndShouldKeep('BV1', badConfig);

      expect(visible, isTrue);
      expect(box.valuesByKey['BV1']!.exposureCount, 1);
    });

    // ---- BV with leading/trailing whitespace ----------------------------

    test('BV with surrounding whitespace is trimmed', () {
      final box = _MemoryExposureBox();
      final store = ExposureTrackerStore(box: box, clock: () => base);

      final visible = store.recordAndShouldKeep('  BV1  ', enabled);

      expect(visible, isTrue);
      expect(box.valuesByKey.containsKey('BV1'), isTrue);
    });
  });
}
