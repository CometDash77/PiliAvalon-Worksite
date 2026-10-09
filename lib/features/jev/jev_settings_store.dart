import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_models.dart';
import 'package:PiliPlus/utils/storage.dart';

abstract interface class JevSettingsBox {
  Object? get(String key);
  Future<void> put(String key, Object? value);
}

class JevHiveSettingsBox implements JevSettingsBox {
  JevHiveSettingsBox(this.box);
  final dynamic box;
  @override
  Object? get(String key) => box.get(key);
  @override
  Future<void> put(String key, Object? value) async => box.put(key, value);
}

class JevSettingsStore {
  JevSettingsStore({JevSettingsBox? box})
    : _box = box ?? JevHiveSettingsBox(GStorage.setting);

  static const settingsKey = 'piliavalon.jev.settings.v1';
  final JevSettingsBox _box;

  JevSettings load() {
    try {
      final raw = _box.get(settingsKey);
      if (raw is! String) return const JevSettings();
      return JevSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const JevSettings();
    }
  }

  Future<void> save(JevSettings settings) =>
      _box.put(settingsKey, jsonEncode(settings.toJson()));
}
