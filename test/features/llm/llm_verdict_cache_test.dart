import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart' show JevSettingsBox;
import 'package:PiliPlus/features/llm/llm.dart';
import 'package:PiliPlus/utils/storage_key.dart';

class _FakeBox implements JevSettingsBox {
  final map = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) => map[key] ?? defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

DateTime _now = DateTime.utc(2026, 1, 1);

LlmVerdictCache _cache(_FakeBox box) =>
    LlmVerdictCache(box: box, clock: () => _now);

void main() {
  setUp(() {
    _now = DateTime.utc(2026, 1, 1);
    LlmVerdictCache.resetCache();
  });

  test('a miss returns null and a put round-trips', () {
    final cache = _cache(_FakeBox());
    expect(cache.lookup('gen', 'k1'), isNull);
    cache.put('gen', 'k1', hide: true);
    expect(cache.lookup('gen', 'k1'), isTrue);
  });

  test('keep verdicts are cached too', () {
    final cache = _cache(_FakeBox())..put('gen', 'k1', hide: false);
    expect(cache.lookup('gen', 'k1'), isFalse);
  });

  test('entries expire after the configured ttl', () {
    final cache = _cache(_FakeBox())..put('gen', 'k1', hide: true);
    _now = _now.add(const Duration(minutes: 1440));
    expect(cache.lookup('gen', 'k1'), isTrue);
    _now = _now.add(const Duration(minutes: 1));
    expect(cache.lookup('gen', 'k1'), isNull);
  });

  test('a new generation invalidates every older generation', () {
    final cache = _cache(_FakeBox())
      ..put('gen1', 'k1', hide: true)
      ..put('gen2', 'k2', hide: true);
    expect(cache.lookup('gen1', 'k1'), isNull);
    expect(cache.lookup('gen2', 'k2'), isTrue);
    expect(LlmVerdictCache.cachedEntryCount, 1);
  });

  test('capacity evicts the oldest writes', () {
    final box = _FakeBox();
    box.map[SettingBoxKey.jevVerdictCacheMaxEntries] = 2;
    final cache = _cache(box)
      ..put('gen', 'a', hide: true)
      ..put('gen', 'b', hide: true)
      ..put('gen', 'c', hide: true);
    expect(cache.lookup('gen', 'a'), isNull);
    expect(cache.lookup('gen', 'b'), isTrue);
    expect(cache.lookup('gen', 'c'), isTrue);
  });

  test('re-putting the same identity refreshes instead of duplicating', () {
    final cache = _cache(_FakeBox())
      ..put('gen', 'k1', hide: true)
      ..put('gen', 'k1', hide: false);
    expect(LlmVerdictCache.cachedEntryCount, 1);
    expect(cache.lookup('gen', 'k1'), isFalse);
  });

  test('the switch, ttl and capacity share the #123 settings source', () {
    final box = _FakeBox();
    box.map[SettingBoxKey.jevVerdictCacheEnabled] = false;
    box.map[SettingBoxKey.jevVerdictCacheTtlMinutes] = 10;
    box.map[SettingBoxKey.jevVerdictCacheMaxEntries] = 7;
    final cache = _cache(box);
    expect(cache.enabled, isFalse);
    expect(cache.ttl, const Duration(minutes: 10));
    expect(cache.maxEntries, 7);
  });

  test('resetCache clears everything', () {
    final cache = _cache(_FakeBox())..put('gen', 'k1', hide: true);
    LlmVerdictCache.resetCache();
    expect(cache.lookup('gen', 'k1'), isNull);
    expect(LlmVerdictCache.cachedEntryCount, 0);
  });
}
