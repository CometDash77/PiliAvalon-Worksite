import 'package:PiliPlus/features/jev/jev_settings.dart'
    show HiveJevSettingsBox, JevSettingsBox;
import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/foundation.dart' show immutable;

// Reasons a generic-line provider configuration is not usable yet (spec 1).
enum LlmConfigIssue {
  missingProtocol('请选择协议类型'),
  missingBaseUrl('请填写服务地址 Base URL'),
  invalidBaseUrl('服务地址格式无效，需为 http(s) 地址'),
  insecureBaseUrl('HTTP 地址不安全，需在设置中显式确认后才能使用'),
  missingModel('请填写或选择模型');

  const LlmConfigIssue(this.message);

  final String message;
}

// Non-secret configuration of one generic-line provider (spec 1).
//
// One active configuration: protocol choice, base URL, model. The credential
// lives in the credential store keyed by protocol and never here. The
// confirmed latch mirrors Jev's provider confirmation: saving a config is not
// the same as the user confirming it works (catalog success does not imply
// callable, and callable does not imply filtering).
@immutable
class LlmProviderConfig {
  const LlmProviderConfig({
    this.protocol,
    this.baseUrl = '',
    this.model = '',
    this.confirmed = false,
    this.httpInsecureConfirmed = false,
  });

  final LlmProtocol? protocol;

  // Everything before the protocol-specific path: e.g.
  // https://api.example.com/v1 for OpenAI-compatible services or
  // https://api.anthropic.com for Anthropic-compatible ones.
  final String baseUrl;
  final String model;

  // True once the user confirmed this configuration for the stored key.
  final bool confirmed;

  // http base URLs are rejected until the user explicitly confirms (spec 1:
  // https-only default, http needs an explicit UI confirmation).
  final bool httpInsecureConfirmed;

  static const LlmProviderConfig empty = LlmProviderConfig();

  // Base URL without trailing slashes, as used to build endpoints.
  String get normalizedBaseUrl {
    var raw = baseUrl.trim();
    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }
    return raw;
  }

  bool get hasValidBaseUrl {
    final uri = Uri.tryParse(normalizedBaseUrl);
    final scheme = uri?.scheme.toLowerCase();
    return uri != null &&
        uri.host.isNotEmpty &&
        (scheme == 'https' || scheme == 'http');
  }

  // Structural completeness only. Confirmation and probe results are not
  // structural: they live in their own latches (spec 1 and 10).
  List<LlmConfigIssue> get issues {
    final result = <LlmConfigIssue>[];
    if (protocol == null) result.add(LlmConfigIssue.missingProtocol);
    if (baseUrl.trim().isEmpty) {
      result.add(LlmConfigIssue.missingBaseUrl);
    } else {
      final uri = Uri.tryParse(normalizedBaseUrl);
      final scheme = uri?.scheme.toLowerCase();
      if (uri == null ||
          uri.host.isEmpty ||
          (scheme != 'https' && scheme != 'http')) {
        result.add(LlmConfigIssue.invalidBaseUrl);
      } else if (scheme == 'http' && !httpInsecureConfirmed) {
        result.add(LlmConfigIssue.insecureBaseUrl);
      }
    }
    if (model.trim().isEmpty) result.add(LlmConfigIssue.missingModel);
    return result;
  }

  // Full chat endpoint, or null when protocol or base URL is unusable.
  String? get chatEndpoint => _endpoint(protocol?.chatPath);

  // Full catalog endpoint, or null when protocol or base URL is unusable.
  String? get catalogEndpoint => _endpoint(protocol?.catalogPath);

  String? _endpoint(String? path) {
    final p = protocol;
    if (p == null || path == null || !hasValidBaseUrl) return null;
    return normalizedBaseUrl + path;
  }

  LlmProviderConfig copyWith({
    LlmProtocol? protocol,
    String? baseUrl,
    String? model,
    bool? confirmed,
    bool? httpInsecureConfirmed,
  }) => LlmProviderConfig(
    protocol: protocol ?? this.protocol,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    confirmed: confirmed ?? this.confirmed,
    httpInsecureConfirmed: httpInsecureConfirmed ?? this.httpInsecureConfirmed,
  );

  @override
  bool operator ==(Object other) =>
      other is LlmProviderConfig &&
      other.protocol == protocol &&
      other.baseUrl == baseUrl &&
      other.model == model &&
      other.confirmed == confirmed &&
      other.httpInsecureConfirmed == httpInsecureConfirmed;

  @override
  int get hashCode => Object.hash(
    protocol,
    baseUrl,
    model,
    confirmed,
    httpInsecureConfirmed,
  );
}

// Reads and writes the non-secret generic-line configuration.
//
// Shares the Jev non-secret settings box via the same [JevSettingsBox] seam.
// The API key never reaches this box (spec 1), which keeps it out of Hive
// exports and backups.
class LlmSettingsStore {
  LlmSettingsStore({JevSettingsBox? box}) : _boxOrNull = box;

  // 构造期不触碰 GStorage（#130）：flutter test 等未初始化环境里 late 字段
  // 会同步抛错；解析推迟到首次读写，失败由调用方 try/catch 兜住。
  final JevSettingsBox? _boxOrNull;
  JevSettingsBox? _lazyBox;
  JevSettingsBox get _box =>
      _lazyBox ??= _boxOrNull ?? HiveJevSettingsBox(GStorage.setting);

  static const String namespace = 'piliavalon.llm.v1';
  static const String protocolKey = 'piliavalon.llm.v1.protocol';
  static const String baseUrlKey = 'piliavalon.llm.v1.base_url';
  static const String modelKey = 'piliavalon.llm.v1.model';
  static const String confirmedKey = 'piliavalon.llm.v1.confirmed';
  static const String insecureConfirmedKey =
      'piliavalon.llm.v1.http_insecure_confirmed';

  static LlmProviderConfig? _cache;

  // Last loaded configuration, or [LlmProviderConfig.empty] before any load.
  static LlmProviderConfig get snapshot => _cache ?? LlmProviderConfig.empty;

  // Drops the cached snapshot (used when a settings export is restored).
  static void resetCache() => _cache = null;

  // Hive can hand back non-bool garbage after a bad migration: treat as off.
  static bool _flag(Object? value) => value is bool && value;

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  Future<LlmProviderConfig> load() async {
    final config = LlmProviderConfig(
      protocol: LlmProtocol.tryFromId(_string(_box.get(protocolKey))),
      baseUrl: _string(_box.get(baseUrlKey)) ?? '',
      model: _string(_box.get(modelKey)) ?? '',
      confirmed: _flag(_box.get(confirmedKey)),
      httpInsecureConfirmed: _flag(_box.get(insecureConfirmedKey)),
    );
    _cache = config;
    return config;
  }

  Future<void> save(LlmProviderConfig config) async {
    final protocol = config.protocol;
    if (protocol == null) {
      await _box.delete(protocolKey);
    } else {
      await _box.put(protocolKey, protocol.id);
    }
    await _box.put(baseUrlKey, config.baseUrl);
    await _box.put(modelKey, config.model);
    await _box.put(confirmedKey, config.confirmed);
    await _box.put(insecureConfirmedKey, config.httpInsecureConfirmed);
    _cache = config;
  }
}
