import 'package:PiliPlus/features/jev/jev_credential_store.dart'
    show JevCredentialException, JevKeyStoreStatus;
import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Credential boundary for the generic line (spec 1).
//
// One slot per protocol so switching protocols never carries a credential
// across. Keys only ever live in the OS credential store: never in Hive,
// never in the settings export or WebDAV backup, never in a log.
abstract interface class LlmCredentialStore {
  Future<JevKeyStoreStatus> status(LlmProtocol protocol);

  Future<String?> read(LlmProtocol protocol);

  Future<void> write(LlmProtocol protocol, String apiKey);

  Future<void> delete(LlmProtocol protocol);
}

// [LlmCredentialStore] on top of the federated flutter_secure_storage API.
//
// No plaintext fallback: when the OS store is missing, locked, or failing,
// [status] reports unavailable and callers keep the generic line disabled.
class SecureLlmCredentialStore implements LlmCredentialStore {
  SecureLlmCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // One namespaced entry per protocol.
  static String entryKey(LlmProtocol protocol) =>
      'piliavalon.llm.v1.api_key.${protocol.id}';

  final FlutterSecureStorage _storage;

  @override
  Future<JevKeyStoreStatus> status(LlmProtocol protocol) async {
    try {
      await _storage.read(key: entryKey(protocol));
      return JevKeyStoreStatus.available;
    } on PlatformException {
      return JevKeyStoreStatus.unavailable;
    } on MissingPluginException {
      return JevKeyStoreStatus.unavailable;
    }
  }

  @override
  Future<String?> read(LlmProtocol protocol) async {
    try {
      final value = await _storage.read(key: entryKey(protocol));
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } on PlatformException catch (error) {
      throw JevCredentialException('无法读取安全存储（${error.code}）');
    } on MissingPluginException {
      throw const JevCredentialException('当前平台没有可用的安全存储');
    }
  }

  @override
  Future<void> write(LlmProtocol protocol, String apiKey) async {
    try {
      await _storage.write(key: entryKey(protocol), value: apiKey.trim());
    } on PlatformException catch (error) {
      throw JevCredentialException('无法写入安全存储（${error.code}）');
    } on MissingPluginException {
      throw const JevCredentialException('当前平台没有可用的安全存储');
    }
  }

  @override
  Future<void> delete(LlmProtocol protocol) async {
    try {
      await _storage.delete(key: entryKey(protocol));
    } on PlatformException catch (error) {
      throw JevCredentialException('无法清除安全存储（${error.code}）');
    } on MissingPluginException {
      throw const JevCredentialException('当前平台没有可用的安全存储');
    }
  }
}
