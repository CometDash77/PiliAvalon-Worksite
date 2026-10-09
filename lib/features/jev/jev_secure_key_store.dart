import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:PiliPlus/features/jev/jev_models.dart';

abstract interface class JevSecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterJevSecretStorage implements JevSecretStorage {
  FlutterJevSecretStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? _platformStorage();

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _platformStorage() => FlutterSecureStorage(
    mOptions: const MacOsOptions(usesDataProtectionKeychain: false),
  );

  static const _probeKey = 'piliavalon.jev.secure_store_probe';
  bool get supported => !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS || Platform.isWindows ||
          Platform.isMacOS || Platform.isLinux);

  Future<bool> isAvailable() async {
    if (!supported) return false;
    try {
      await _storage.write(key: _probeKey, value: 'ok');
      final value = await _storage.read(key: _probeKey);
      await _storage.delete(key: _probeKey);
      return value == 'ok';
    } catch (_) {
      try {
        await _storage.delete(key: _probeKey);
      } catch (_) {}
      return false;
    }
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class JevCredentialStore {
  JevCredentialStore(this.storage);
  static String keyNameFor(JevProvider provider) =>
      'piliavalon.jev.provider_key.${provider.name}';
  final JevSecretStorage storage;

  Future<bool> get available async =>
      storage is FlutterJevSecretStorage
          ? (storage as FlutterJevSecretStorage).isAvailable()
          : _probe();

  Future<bool> _probe() async {
    try {
      await storage.write('piliavalon.jev.secure_store_probe', 'ok');
      final value = await storage.read('piliavalon.jev.secure_store_probe');
      await storage.delete('piliavalon.jev.secure_store_probe');
      return value == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<void> save({required JevProvider provider, required String value}) async {
    if (!await available) throw StateError('Secure storage is unavailable');
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(value, 'value', 'must not be empty');
    await storage.write(keyNameFor(provider), trimmed);
  }

  Future<String?> read(JevProvider provider) async {
    if (!await available) return null;
    try {
      return await storage.read(keyNameFor(provider));
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(JevProvider provider) => storage.delete(keyNameFor(provider));
}
