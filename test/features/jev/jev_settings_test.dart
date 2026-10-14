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
  setUp(JevSettingsStore.resetCache);

  test('defaults to Decision with no configured surfaces', () async {
    final settings = await JevSettingsStore(box: _MemoryBox()).load();
    expect(settings.mode, ScreeningEngineMode.decision);
    expect(settings.provider, isNull);
    expect(settings.providerConfirmed, isFalse);
    expect(settings.surfaces, isEmpty);
    for (final surface in JevSurface.values) {
      expect(settings.isSurfaceEnabled(surface), isFalse);
    }
  });

  test('legacy migration preserves config and requires an explicit LLM choice', () async {
    for (final enabled in [true, false]) {
      for (final llmKey in [null, 'piliavalon.llm.v1.model', 'piliavalon.llm.v2.accounts']) {
        final box = _MemoryBox();
        box.values.addAll({
          JevSettingsStore.enabledKey: enabled,
          JevSettingsStore.providerKey: 'typesafe',
          'piliavalon.jev.v1.rules.v1': 'legacy-rule-blob',
          if (llmKey != null) llmKey: 'saved-config',
        });
        final before = Map<String, Object?>.of(box.values);
        final store = JevSettingsStore(box: box);
        final first = await store.load();
        expect(first.mode, llmKey != null || !enabled
            ? ScreeningEngineMode.off : ScreeningEngineMode.decision);
        expect(store.modes.needsChoice, llmKey != null);
        expect(await store.load(), first);
        for (final entry in before.entries) {
          expect(box.values[entry.key], entry.value);
        }
        // A config save is not an explicit mode choice.
        await store.save(first.withSurface(JevSurface.hot, value: true));
        expect(store.modes.needsChoice, llmKey != null);
        await store.modes.save(ScreeningEngineMode.llm);
        expect((await store.load()).mode, ScreeningEngineMode.llm);
        expect(store.modes.needsChoice, isFalse);
        expect(box.values['piliavalon.jev.v1.rules.v1'], 'legacy-rule-blob');
      }
    }
  });

  test('unknown mode fails open without rewriting future data', () async {
    final box = _MemoryBox()..values[ScreeningModeStore.key] = 'future-mode';
    final store = JevSettingsStore(box: box);
    final settings = await store.load();
    expect(settings.mode, ScreeningEngineMode.off);
    await store.save(settings.withSurface(JevSurface.hot, value: true));
    expect(box.values[ScreeningModeStore.key], 'future-mode');
    await store.modes.save(ScreeningEngineMode.off);
    expect(store.modes.needsChoice, isFalse);
  });

  test('mode switches serialize and invalidate old snapshots even after ABA', () async {
    final store = ScreeningModeStore(box: _MemoryBox());
    final before = await store.load();
    final off = store.save(ScreeningEngineMode.off);
    expect(before.isCurrent, isFalse);
    final back = store.save(ScreeningEngineMode.decision);
    await Future.wait([off, back]);
    final after = await store.load();
    expect(after.mode, ScreeningEngineMode.decision);
    expect(after.isCurrent, isTrue);
    expect(before.isCurrent, isFalse);
  });

  test('saving an old configuration draft cannot restore its old mode', () async {
    final box = _MemoryBox();
    final store = JevSettingsStore(box: box);
    final draft = await store.load();
    await store.modes.save(ScreeningEngineMode.off);
    await store.save(draft.withSurface(JevSurface.hot, value: true), saveMode: false);
    expect((await store.load()).mode, ScreeningEngineMode.off);
    expect((await store.load()).surfaces, contains(JevSurface.hot));
  });

  test('round-trips the non-secret configuration', () async {
    final box = _MemoryBox();
    await JevSettingsStore(box: box).save(
      const JevSettings(
        enabled: true,
        provider: JevProvider.openRouter,
        surfaces: <JevSurface>{JevSurface.homeWeb, JevSurface.live},
        providerConfirmed: true,
      ),
    );

    final reloaded = await JevSettingsStore(box: box).load();
    expect(reloaded.enabled, isTrue);
    expect(reloaded.provider, JevProvider.openRouter);
    expect(reloaded.providerConfirmed, isTrue);
    expect(
      reloaded.surfaces,
      <JevSurface>{JevSurface.homeWeb, JevSurface.live},
    );
    expect(reloaded.isSurfaceEnabled(JevSurface.homeWeb), isTrue);
    expect(reloaded.isSurfaceEnabled(JevSurface.related), isFalse);
  });

  test('an enabled surface stays off while the master switch is off', () {
    const settings = JevSettings(surfaces: <JevSurface>{JevSurface.hot});
    expect(settings.isSurfaceEnabled(JevSurface.hot), isFalse);
    expect(
      settings.copyWith(enabled: true).isSurfaceEnabled(JevSurface.hot),
      isTrue,
    );
  });

  test('an unwired surface never screens, whatever the stored set says', () {
    const settings = JevSettings(
      enabled: true,
      surfaces: <JevSurface>{JevSurface.homeWeb, JevSurface.live},
    );
    expect(JevSurface.live.screeningWired, isFalse);
    expect(settings.isSurfaceEnabled(JevSurface.homeWeb), isTrue);
    expect(settings.isSurfaceEnabled(JevSurface.live), isFalse);
  });

  test('clearing the provider deletes the provider keys', () async {
    final box = _MemoryBox();
    final store = JevSettingsStore(box: box);
    await store.save(
      const JevSettings(
        enabled: true,
        provider: JevProvider.typeSafe,
        providerConfirmed: true,
      ),
    );
    expect(box.values[JevSettingsStore.providerKey], 'typesafe');
    expect(box.values[JevSettingsStore.providerConfirmedKey], isTrue);

    await store.save(const JevSettings(enabled: true));
    expect(box.values.containsKey(JevSettingsStore.providerKey), isFalse);
    expect(
      box.values.containsKey(JevSettingsStore.providerConfirmedKey),
      isFalse,
    );
  });

  test('a confirmation latch never survives without a provider', () async {
    final box = _MemoryBox();
    await JevSettingsStore(
      box: box,
    ).save(const JevSettings(enabled: true, providerConfirmed: true));
    final reloaded = await JevSettingsStore(box: box).load();
    expect(reloaded.providerConfirmed, isFalse);
  });

  test('garbage instead of a bool reads back as off', () async {
    final box = _MemoryBox();
    box.values[JevSettingsStore.enabledKey] = 'yes';
    box.values[JevSettingsStore.providerKey] = 42;
    box.values[JevSettingsStore.surfaceKey(JevSurface.hot)] = 1;
    final settings = await JevSettingsStore(box: box).load();
    expect(settings.enabled, isFalse);
    expect(settings.provider, isNull);
    expect(settings.surfaces, isEmpty);
  });

  test('every stored key lives under the jev namespace', () async {
    final box = _MemoryBox();
    await JevSettingsStore(box: box).save(
      const JevSettings(enabled: true, provider: JevProvider.typeSafe),
    );
    expect(box.values, isNotEmpty);
    for (final key in box.values.keys) {
      expect(key == ScreeningModeStore.key || key.startsWith(JevSettingsStore.namespace), isTrue, reason: key);
    }
    expect(box.values.containsKey('piliavalon.jev.v1.surface.music'), isTrue);
    expect(box.values['piliavalon.jev.v1.surface.music'], isFalse);
  });

  test('no secret can reach the settings box', () async {
    final box = _MemoryBox();
    const secret = 'sk-or-v1-super-secret';
    await JevSettingsStore(box: box).save(
      const JevSettings(
        enabled: true,
        provider: JevProvider.openRouter,
        providerConfirmed: true,
      ),
    );
    expect(box.values.toString().contains(secret), isFalse);
    expect(box.values.values.whereType<String>(), isNot(contains(secret)));
  });
}
