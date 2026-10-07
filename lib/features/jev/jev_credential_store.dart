import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Whether the OS credential store can be used at all (issue #32).
enum JevKeyStoreStatus { available, unavailable }

/// Raised when the credential store is reachable but rejects an operation.
class JevCredentialException implements Exception {
  const JevCredentialException(this.message);

  final String message;

  @override
  String toString() => 'JevCredentialException: $message';
}

/// Credential boundary for the user's own provider key.
///
/// The key only ever lives in the OS credential store: never in Hive, never in
/// the settings export or WebDAV backup, and never in a log (issue #32).
abstract interface class JevCredentialStore {
  Future<JevKeyStoreStatus> status();

  Future<String?> read();

  Future<void> write(String apiKey);

  Future<void> delete();
}

/// [JevCredentialStore] on top of the federated `flutter_secure_storage` API.
///
/// There is no plaintext fallback: when the OS store is missing, locked, or
/// failing, [status] reports `unavailable` and the caller keeps Jev disabled.
class SecureJevCredentialStore implements JevCredentialStore {
  SecureJevCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Single namespaced entry (issue #32, gap G-02).
  static const String entryKey = 'piliavalon.jev.v1.api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<JevKeyStoreStatus> status() async {
    try {
      await _storage.read(key: entryKey);
      return JevKeyStoreStatus.available;
    } on PlatformException {
      return JevKeyStoreStatus.unavailable;
    } on MissingPluginException {
      return JevKeyStoreStatus.unavailable;
    }
  }

  @override
  Future<String?> read() async {
    try {
      final value = await _storage.read(key: entryKey);
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } on PlatformException catch (error) {
      throw JevCredentialException('无法读取安全存储（${error.code}）');
    } on MissingPluginException {
      throw const JevCredentialException('当前平台没有可用的安全存储');
    }
  }

  @override
  Future<void> write(String apiKey) async {
    try {
      await _storage.write(key: entryKey, value: apiKey.trim());
    } on PlatformException catch (error) {
      throw JevCredentialException('无法写入安全存储（${error.code}）');
    } on MissingPluginException {
      throw const JevCredentialException('当前平台没有可用的安全存储');
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: entryKey);
    } on PlatformException catch (error) {
      throw JevCredentialException('无法清除安全存储（${error.code}）');
    } on MissingPluginException {
      throw const JevCredentialException('当前平台没有可用的安全存储');
    }
  }
}
