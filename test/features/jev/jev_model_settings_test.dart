import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryModelBox implements JevSettingsBox {
  final values = <String, Object?>{};
  @override
  Object? get(String key, {Object? defaultValue}) =>
      values[key] ?? defaultValue;
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
  test('OpenRouter official alias preserves leading tilde', () {
    expect(JevProvider.openRouter.model, '~typesafe/jev-latest');
  });
  test('provider overrides survive restart and reset independently', () async {
    final box = MemoryModelBox();
    dynamic settings = const JevSettings(provider: JevProvider.openRouter);
    settings = settings.withModel(JevProvider.openRouter, '  ~vendor/model  ');
    settings = settings.withModel(JevProvider.typeSafe, 'jev-preview');
    await JevSettingsStore(box: box).save(settings as JevSettings);
    JevSettingsStore.resetCache();
    dynamic restored = await JevSettingsStore(box: box).load();
    expect(restored.modelFor(JevProvider.openRouter), '~vendor/model');
    expect(restored.modelFor(JevProvider.typeSafe), 'jev-preview');
    restored = restored.withDefaultModel(JevProvider.openRouter);
    await JevSettingsStore(box: box).save(restored as JevSettings);
    restored = await JevSettingsStore(box: box).load();
    expect(restored.modelFor(JevProvider.openRouter), '~typesafe/jev-latest');
    expect(restored.modelFor(JevProvider.typeSafe), 'jev-preview');
  });
  test('blank override is rejected without silently choosing a model', () {
    dynamic settings = JevSettings.disabled;
    expect(
      () => settings.withModel(JevProvider.openRouter, '  '),
      throwsArgumentError,
    );
  });
}
