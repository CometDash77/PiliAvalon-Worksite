import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBox implements JevSettingsBox {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
  });

  const signal = JevDislikeSignal.card(
    title: '某标题碎片',
    displayedReason: '某主题解析',
  );

  _MemoryBox enabledBox(JevSurface surface) => _MemoryBox()
    ..values[JevSettingsStore.enabledKey] = true
    ..values[JevSettingsStore.surfaceKey(surface)] = true;

  test('nothing is collected while Jev is off', () async {
    final box = _MemoryBox();
    final store = JevPreferenceStore(box: box);
    expect(await store.record(signal, surface: JevSurface.homeWeb), isFalse);
    expect(box.values.containsKey(JevPreferenceStore.profileKey), isFalse);
    expect(JevPreferenceStore.snapshot.isEmpty, isTrue);
  });

  test('a switched-off surface never feeds the profile', () async {
    final box = enabledBox(JevSurface.related);
    final store = JevPreferenceStore(box: box);
    expect(await store.record(signal, surface: JevSurface.homeWeb), isFalse);
    expect(await store.record(signal, surface: JevSurface.related), isTrue);

    final stored = await JevPreferenceStore(box: box).load();
    expect(stored.length, 1);
    expect(stored.themes.single.count, 1);
    expect(stored.themes.single.theme, '某主题解析');
  });

  test('a tapped reason is what reaches the stored profile', () async {
    final box = enabledBox(JevSurface.homeApp);
    final store = JevPreferenceStore(box: box);
    expect(
      await store.record(
        const JevDislikeSignal.card(
          title: '某纪录片 第一集',
          displayedReason: '为你推荐',
          selectedReason: '不想看 游戏区',
        ),
        surface: JevSurface.homeApp,
      ),
      isTrue,
    );

    final stored = await JevPreferenceStore(box: box).load();
    expect(stored.themes.single.theme, '不想看 游戏区');
    expect(
      (box.values[JevPreferenceStore.profileKey]! as String).contains('纪录片'),
      isFalse,
    );
  });

  test('a card with no usable theme writes nothing', () async {
    final box = enabledBox(JevSurface.hot);
    final store = JevPreferenceStore(box: box);
    expect(
      await store.record(
        const JevDislikeSignal.card(title: '!!!'),
        surface: JevSurface.hot,
      ),
      isFalse,
    );
    // Issue #119: a title alone is not a theme, so a reason-less tap leaves the
    // profile untouched instead of storing a title fragment.
    expect(
      await store.record(
        const JevDislikeSignal.card(title: '某纪录片的真相 深度解析'),
        surface: JevSurface.hot,
      ),
      isFalse,
    );
    expect(box.values.containsKey(JevPreferenceStore.profileKey), isFalse);
  });

  test(
    'Jev off pauses collection but keeps the profile and its timers',
    () async {
      final box = _MemoryBox();
      var clock = DateTime(2026, 1, 1);
      final store = JevPreferenceStore(box: box, clock: () => clock);
      box.values[JevSettingsStore.enabledKey] = true;
      box.values[JevSettingsStore.surfaceKey(JevSurface.homeWeb)] = true;
      expect(await store.record(signal, surface: JevSurface.homeWeb), isTrue);

      box.values[JevSettingsStore.enabledKey] = false;
      expect(
        await store.record(
          const JevDislikeSignal.card(
            title: '某标题碎片',
            displayedReason: '另一个主题',
          ),
          surface: JevSurface.homeWeb,
        ),
        isFalse,
      );
      final kept = await JevPreferenceStore(
        box: box,
        clock: () => clock,
      ).load();
      expect(kept.themes.map((item) => item.theme), <String>['某主题解析']);

      clock = clock.add(JevLimits.themeTtl);
      expect(
        (await JevPreferenceStore(box: box, clock: () => clock).load()).isEmpty,
        isTrue,
      );
    },
  );

  test('the stored theme keeps no link and no video id', () async {
    final box = enabledBox(JevSurface.hot);
    final store = JevPreferenceStore(box: box);
    await store.record(
      const JevDislikeSignal.card(
        title: '某标题碎片',
        displayedReason: 'https://www.bilibili.com/video/BV1xx411c7mD 某主题解析',
      ),
      surface: JevSurface.hot,
    );

    const key = JevPreferenceStore.profileKey;
    expect(key.startsWith(JevSettingsStore.namespace), isTrue);
    final raw = box.values[key]! as String;
    expect(raw.contains('http'), isFalse);
    expect(raw.contains('BV'), isFalse);
    expect(raw.contains('某主题解析'), isTrue);
  });

  test('a 21st theme evicts the one with the oldest feedback', () async {
    final box = enabledBox(JevSurface.homeApp);
    var clock = DateTime(2026, 1, 1);
    final store = JevPreferenceStore(box: box, clock: () => clock);
    for (var i = 0; i < JevLimits.maxProfileThemes; i++) {
      clock = DateTime(2026, 1, 1 + i);
      await store.record(
        JevDislikeSignal.card(
          title: '某标题碎片',
          displayedReason: '主题$i',
        ),
        surface: JevSurface.homeApp,
      );
    }
    await store.record(
      const JevDislikeSignal.card(
        title: '某标题碎片',
        displayedReason: '新主题',
      ),
      surface: JevSurface.homeApp,
    );

    // Read back with the same injected clock: the widest stored feedback is
    // months old by wall-clock time and would settle away under DateTime.now.
    final stored = await JevPreferenceStore(
      box: box,
      clock: () => clock,
    ).load();
    expect(stored.length, JevLimits.maxProfileThemes);
    expect(stored.themes.map((item) => item.theme), isNot(contains('主题0')));
    expect(stored.themes.map((item) => item.theme), contains('新主题'));
  });

  test('deleting one theme and clearing the profile both persist', () async {
    final box = enabledBox(JevSurface.hot);
    final store = JevPreferenceStore(box: box);
    await store.record(
      const JevDislikeSignal.card(
        title: '某标题碎片',
        displayedReason: '甲主题',
      ),
      surface: JevSurface.hot,
    );
    await store.record(
      const JevDislikeSignal.card(
        title: '某标题碎片',
        displayedReason: '乙主题',
      ),
      surface: JevSurface.hot,
    );

    await store.deleteTheme('乙主题');
    final afterDelete = await JevPreferenceStore(box: box).load();
    expect(afterDelete.themes.map((item) => item.theme), <String>['甲主题']);

    await store.clear();
    expect(box.values.containsKey(JevPreferenceStore.profileKey), isFalse);
    expect((await JevPreferenceStore(box: box).load()).isEmpty, isTrue);
  });

  test('garbage in the box reads as an empty profile', () async {
    final box = _MemoryBox();
    box.values[JevPreferenceStore.profileKey] = 'not json at all';
    expect((await JevPreferenceStore(box: box).load()).isEmpty, isTrue);
  });
}
