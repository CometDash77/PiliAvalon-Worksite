import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/llm/llm_credential_store.dart';
import 'package:PiliPlus/features/llm/llm_provider_presets.dart';

/// Issue #144: 每提供方独立配置的持久化（v2 命名空间）。
///
/// - 每个提供方一份 [LlmProviderAccount]（JSON blob，键含 providerId）；
/// - API Key 只进安全存储（[LlmProviderCredentialStore]，llm_credential_store.dart），
///   绝不进 Hive / 设置导出 / 日志；
/// - 协议/地址/模型/includesV1/鉴权方式 任一变更 → 旧验证状态失效（confirmed
///   置 false）+ 配置代数 +1（供上层缓存随代数失效）。
class LlmProviderConfigStore {
  /// [box] is required: the default Hive-backed instance is built by
  /// createDefaultLlmProviderConfigStore() in llm_provider_config_store_hive.dart,
  /// keeping this file free of the storage/UI dependency chain (issue #144).
  LlmProviderConfigStore({required JevSettingsBox box, LlmProviderCredentialStore? credentials})
      : _box = box,
        _credentialsOrNull = credentials;

  static const String namespace = 'piliavalon.llm.v2';

  static String accountKey(String providerId) =>
      '$namespace.account.$providerId';

  /// JevSettingsBox 没有键枚举，靠一个注册表键记住有哪些提供方。
  static const String registryKey = '$namespace.accounts';
  static const String activeKey = '$namespace.active_provider';
  static const String generationKey = '$namespace.config_generation';

  final JevSettingsBox _box;
  final LlmProviderCredentialStore? _credentialsOrNull;

  LlmProviderCredentialStore get _credentials =>
      _credentialsOrNull ?? SecureLlmProviderCredentialStore();

  Future<LlmProviderAccount?> load(String providerId) async {
    final raw = _box.get(accountKey(providerId));
    // save() 以 JSON 字符串落盘；Hive 读回的也是字符串，先解码再解析。
    final decoded = raw is String ? jsonDecode(raw) : raw;
    return LlmProviderAccount.tryFromJson(decoded);
  }

  Future<Map<String, LlmProviderAccount>> loadAll() async {
    final ids = _registeredIds();
    final result = <String, LlmProviderAccount>{};
    for (final id in ids) {
      final account = await load(id);
      if (account != null) result[id] = account;
    }
    return result;
  }

  List<String> _registeredIds() {
    final raw = _box.get(registryKey);
    if (raw is! List) return const <String>[];
    return raw.whereType<String>().toList(growable: false);
  }

  Future<void> _register(String providerId) async {
    final ids = _registeredIds();
    if (ids.contains(providerId)) return;
    await _box.put(registryKey, [...ids, providerId]);
  }

  Future<void> _unregister(String providerId) async {
    final ids = _registeredIds();
    if (!ids.contains(providerId)) return;
    await _box.put(
        registryKey, ids.where((id) => id != providerId).toList());
  }

  /// 保存账户配置。协议/地址/模型/includesV1/鉴权方式 相对已存配置发生
  /// 变化时：confirmed 强制置 false（旧验证状态失效）+ 配置代数 +1。
  /// 首次保存不算变更（调用方在探活通过后自带 confirmed）。
  Future<void> save(LlmProviderAccount account) async {
    final existing = await load(account.providerId);
    var effective = account;
    if (existing != null) {
      final upstreamChanged = existing.protocol != account.protocol ||
          existing.baseUrl != account.baseUrl ||
          existing.model != account.model ||
          existing.includesV1Override != account.includesV1Override ||
          existing.authOverride != account.authOverride;
      if (upstreamChanged && account.confirmed) {
        effective = account.copyWith(confirmed: false);
      }
      if (upstreamChanged) {
        await _bumpGeneration();
      }
    }
    await _box.put(accountKey(account.providerId), jsonEncode(effective.toJson()));
    await _register(account.providerId);
  }

  Future<void> remove(String providerId) async {
    await _box.delete(accountKey(providerId));
    await _unregister(providerId);
    if (await activeProvider() == providerId) {
      await _box.delete(activeKey);
    }
    try {
      await _credentials.delete(providerId);
    } catch (_) {
      // ponytail: 删配置时清 Key 失败不吞配置删除；Key 残留可由设置页单独清除。
    }
    await _bumpGeneration();
  }

  Future<String?> activeProvider() async {
    final raw = _box.get(activeKey);
    return raw is String ? raw : null;
  }

  Future<void> setActive(String? providerId) async {
    if (providerId == null) {
      await _box.delete(activeKey);
    } else {
      await _box.put(activeKey, providerId);
    }
  }

  int get generation {
    final raw = _box.get(generationKey);
    return raw is int ? raw : 0;
  }

  Future<void> _bumpGeneration() async {
    await _box.put(generationKey, generation + 1);
  }

  Future<String?> readKey(String providerId) => _credentials.read(providerId);

  /// 写入 Key：立即失效该提供方的验证状态（Key 属于失效触发项），
  /// 并推进配置代数。
  Future<void> writeKey(String providerId, String apiKey) async {
    await _credentials.write(providerId, apiKey);
    await _invalidateConfirmed(providerId);
    await _bumpGeneration();
  }

  Future<void> deleteKey(String providerId) async {
    await _credentials.delete(providerId);
    await _invalidateConfirmed(providerId);
    await _bumpGeneration();
  }

  Future<void> _invalidateConfirmed(String providerId) async {
    final existing = await load(providerId);
    if (existing == null || !existing.confirmed) return;
    await _box.put(
        accountKey(providerId),
        jsonEncode(existing.copyWith(confirmed: false).toJson()));
  }
}