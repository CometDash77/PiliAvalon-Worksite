import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/foundation.dart' show immutable, setEquals, mapEquals;

/// Persisted, non-secret Jev configuration (issues #32/#35).
@immutable
class JevSettings {
  const JevSettings({
    this.enabled = false,
    this.provider,
    this.surfaces = const <JevSurface>{},
    this.providerConfirmed = false,
    this.modelOverrides = const <JevProvider, String>{},
  });

  final Map<JevProvider, String> modelOverrides;

  String modelFor(JevProvider provider) =>
      modelOverrides[provider] ?? provider.model;

  JevSettings withModel(JevProvider provider, String rawModel) {
    final model = rawModel.trim();
    if (model.isEmpty) throw ArgumentError('模型 ID 不能为空');
    return copyWith(
      modelOverrides: Map.unmodifiable({...modelOverrides, provider: model}),
    );
  }

  JevSettings withDefaultModel(JevProvider provider) {
    final next = {...modelOverrides}..remove(provider);
    return copyWith(modelOverrides: Map.unmodifiable(next));
  }

  /// Default state: Jev off, no provider chosen, no surface enabled.
  static const JevSettings disabled = JevSettings();

  /// Master switch; off means no collection and no evaluation.
  final bool enabled;

  /// Explicit provider choice. The credential itself lives in the credential
  /// store and never here.
  final JevProvider? provider;

  /// Per-surface switches.
  final Set<JevSurface> surfaces;

  /// True once the user confirmed the provider choice for the stored key
  /// (issue #38: a format hint neither selects nor switches a provider).
  final bool providerConfirmed;

  /// A surface screens candidates only when the master switch is on too.
  bool isSurfaceEnabled(JevSurface surface) =>
      enabled && surfaces.contains(surface);

  JevSettings copyWith({
    bool? enabled,
    JevProvider? provider,
    Set<JevSurface>? surfaces,
    bool? providerConfirmed,
    Map<JevProvider, String>? modelOverrides,
  }) => JevSettings(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    surfaces: surfaces ?? this.surfaces,
    providerConfirmed: providerConfirmed ?? this.providerConfirmed,
    modelOverrides: modelOverrides ?? this.modelOverrides,
  );

  JevSettings withSurface(JevSurface surface, {required bool value}) {
    final next = <JevSurface>{...surfaces};
    if (value) {
      next.add(surface);
    } else {
      next.remove(surface);
    }
    return copyWith(surfaces: next);
  }

  /// Drops the provider choice and the confirmation latch of the stored key.
  JevSettings withoutProvider() => JevSettings(
    enabled: enabled,
    surfaces: surfaces,
    modelOverrides: modelOverrides,
  );

  @override
  bool operator ==(Object other) =>
      other is JevSettings &&
      other.enabled == enabled &&
      other.provider == provider &&
      other.providerConfirmed == providerConfirmed &&
      setEquals(other.surfaces, surfaces) &&
      mapEquals(other.modelOverrides, modelOverrides);

  @override
  int get hashCode => Object.hash(
    enabled,
    provider,
    providerConfirmed,
    Object.hashAllUnordered(surfaces),
    Object.hashAllUnordered(
      modelOverrides.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'JevSettings(enabled: $enabled, provider: ${provider?.id}, '
      'surfaces: ${surfaces.map((surface) => surface.id).toList()..sort()}, '
      'providerConfirmed: $providerConfirmed)';
}

/// Storage seam so tests never touch Hive.
abstract interface class JevSettingsBox {
  Object? get(String key, {Object? defaultValue});
  Future<void> put(String key, Object? value);
  Future<void> delete(String key);
}

class HiveJevSettingsBox implements JevSettingsBox {
  HiveJevSettingsBox(this._box);

  final dynamic _box;

  @override
  Object? get(String key, {Object? defaultValue}) =>
      _box.get(key, defaultValue: defaultValue);

  @override
  Future<void> put(String key, Object? value) async {
    await _box.put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }
}

/// Reads and writes the non-secret Jev settings.
///
/// Only the master switch, the provider id, the confirmation latch, and the
/// per-surface switches are stored: the API key never reaches this box (issue
/// #32), which keeps it out of Hive exports and WebDAV backups.
class JevSettingsStore {
  JevSettingsStore({JevSettingsBox? box})
    : _box = box ?? HiveJevSettingsBox(GStorage.setting) {
    if (box != null) {
      _cache = null;
    }
  }

  /// The non-secret settings box. The preference store shares this box, so a
  /// caller that injects a settings store never reaches the other one.
  JevSettingsBox get box => _box;

  static const String namespace = 'piliavalon.jev.v1';
  static const String enabledKey = '$namespace.enabled';
  static const String providerKey = '$namespace.provider';
  static const String providerConfirmedKey = '$namespace.provider_confirmed';
  static const String surfacePrefix = '$namespace.surface.';

  static String modelKey(JevProvider provider) =>
      '$namespace.model.${provider.id}';

  static String surfaceKey(JevSurface surface) => '$surfacePrefix${surface.id}';

  /// Hive can hand back non-bool garbage after a bad migration: treat as off.
  static bool _flag(Object? value) => value is bool && value;

  final JevSettingsBox _box;

  static JevSettings? _cache;

  /// Last loaded settings, or the disabled default before any load.
  static JevSettings get snapshot => _cache ?? JevSettings.disabled;

  /// Drops the cached snapshot (used when a settings export is restored).
  static void resetCache() => _cache = null;

  Future<JevSettings> load() async {
    final surfaces = <JevSurface>{};
    for (final surface in JevSurface.values) {
      if (_flag(_box.get(surfaceKey(surface), defaultValue: false))) {
        surfaces.add(surface);
      }
    }
    final rawProvider = _box.get(providerKey);
    final provider = JevProvider.tryFromId(
      rawProvider is String ? rawProvider : null,
    );
    final models = <JevProvider, String>{};
    for (final entry in JevProvider.values) {
      final raw = _box.get(modelKey(entry));
      if (raw is String && raw.trim().isNotEmpty) models[entry] = raw.trim();
    }
    final settings = JevSettings(
      modelOverrides: Map.unmodifiable(models),
      enabled: _flag(_box.get(enabledKey, defaultValue: false)),
      provider: provider,
      surfaces: surfaces,
      providerConfirmed:
          provider != null &&
          _flag(_box.get(providerConfirmedKey, defaultValue: false)),
    );
    _cache = settings;
    return settings;
  }

  Future<void> save(JevSettings settings) async {
    await _box.put(enabledKey, settings.enabled);
    final provider = settings.provider;
    if (provider == null) {
      await _box.delete(providerKey);
      await _box.delete(providerConfirmedKey);
    } else {
      await _box.put(providerKey, provider.id);
      await _box.put(providerConfirmedKey, settings.providerConfirmed);
    }
    for (final entry in JevProvider.values) {
      final model = settings.modelOverrides[entry];
      if (model == null) {
        await _box.delete(modelKey(entry));
      } else {
        await _box.put(modelKey(entry), model);
      }
    }
    for (final surface in JevSurface.values) {
      await _box.put(surfaceKey(surface), settings.surfaces.contains(surface));
    }
    _cache = settings;
  }
}
