import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:flutter/foundation.dart';

/// Issue #144: 上游预设与提供方配置管理。
///
/// 纯数据 + 纯函数层：预设清单、路线协议枚举、端点拼接与兼容性判定。
/// 持久化在 [LlmProviderConfigStore]（llm_provider_config_store.dart）。
///
/// 数据来源：issue #139（上游预设调研）的结论文档。所有默认值只收录
/// 该文档已验证的条目；未验证项一律不进默认值。

/// 请求路线协议（#139：五族协议，不假设所有上游都是 OpenAI Chat Completions）。
enum LlmRouteProtocol {
  openaiChat('openai_chat', 'OpenAI Chat Completions'),
  openaiResponses('openai_responses', 'OpenAI Responses'),
  anthropicMessages('anthropic_messages', 'Anthropic Messages'),
  google('google', 'Google generateContent'),
  systemone('systemone', 'SystemOne');

  const LlmRouteProtocol(this.id, this.displayName);

  final String id;
  final String displayName;

  static LlmRouteProtocol? tryFromId(String? id) {
    if (id == null) return null;
    for (final value in LlmRouteProtocol.values) {
      if (value.id == id) return value;
    }
    return null;
  }

  /// 语义筛选引擎（#141/#142）当前仅实现这两条路线。
  bool get screenable =>
      this == LlmRouteProtocol.openaiChat ||
      this == LlmRouteProtocol.anthropicMessages;

}

/// 鉴权方式。按 #139：自定义 Anthropic 兼容端点统一发 Bearer，
/// anthropicNative 保留给「自定义提供方全字段可编辑」场景。
enum LlmPresetAuth {
  bearer('bearer'),
  anthropicNative('anthropic_native');

  const LlmPresetAuth(this.id);

  final String id;

  static LlmPresetAuth? tryFromId(String? id) {
    if (id == null) return null;
    for (final value in LlmPresetAuth.values) {
      if (value.id == id) return value;
    }
    return null;
  }

  /// Key 为空（匿名调用，如 Zen 免费聊天）时不发鉴权头。
  Map<String, String> headers(String apiKey) {
    if (apiKey.isEmpty) return const <String, String>{};
    return switch (this) {
      LlmPresetAuth.bearer => <String, String>{
          'authorization': 'Bearer $apiKey',
        },
      LlmPresetAuth.anthropicNative => <String, String>{
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
    };
  }
}

/// 模型目录的响应形态（#139：各上游目录字段集差异大，最小集也要能渲染）。
enum LlmCatalogShape {
  /// 无文档化目录（MiMo 用静态表；自定义 Anthropic 兼容无目录）。
  none,

  /// 单页 {"data":[{"id":...}]}（也兼容 "models" 键）。
  openaiData,

  /// 百炼分页 {"data":[...], "page_no", "page_size", "total"}。
  dashscopePages,
}

/// 兼容性 / 配置问题。与路线、端点相关的判定集中在这里，
/// UI 层（#146）直接展示 [message]。
enum LlmPresetIssue {
  missingBaseUrl('请填写服务地址 Base URL'),
  invalidBaseUrl('服务地址格式无效，需要合法的 http(s) 地址'),
  insecureBaseUrl('HTTP 地址不安全，需在设置中显式确认后才能使用'),
  missingModel('请填写或选择模型'),
  unsupportedRoute('该提供方未定义所选请求路线，请改用其支持的协议族'),
  routeNotScreenable('该请求路线暂不支持语义筛选，请改用 OpenAI Chat Completions 或 Anthropic Messages'),
  catalogUnavailable('该提供方没有可用的模型目录，请手动填写模型或改用其 OpenAI 兼容地址'),
  jsonModeUnavailable('JSON 结构化输出仅 OpenAI 族路线支持');

  const LlmPresetIssue(this.message);

  final String message;
}

/// 上游提供方预设（数据驱动，来自 #139 调研结论）。
@immutable
class LlmProviderPreset {
  const LlmProviderPreset({
    required this.id,
    required this.displayName,
    this.isCustom = false,
    required this.baseUrl,
    required this.baseIncludesV1,
    required this.chatPaths,
    required this.primaryProtocol,
    this.defaultAuth = LlmPresetAuth.bearer,
    this.keyRequired = true,
    this.catalogShape = LlmCatalogShape.openaiData,
    this.catalogPathSuffix = '/models',
    this.catalogOriginRooted = false,
    this.verifiedDefaultModels = const <String>[],
    this.jsonMode = false,
  });

  /// 稳定 provider ID（用于存储命名空间与凭据条目键）。
  final String id;
  final String displayName;

  /// 两个自定义预设：全字段可编辑。
  final bool isCustom;

  /// 默认 Base URL（版本号前的基础地址，#139 硬约束）。
  final String baseUrl;

  /// 是否在 base 之后补 /v1（#139：DeepSeek 是唯一 false 的 OpenAI 族上游）。
  final bool baseIncludesV1;

  /// 各路线的调用路径（字面量，含版本段）。自定义预设的路径在
  /// [chatPath] 里按 includesV1 推导。
  final Map<LlmRouteProtocol, String> chatPaths;

  /// 未显式选择路线时的默认路线。
  final LlmRouteProtocol primaryProtocol;

  final LlmPresetAuth defaultAuth;

  /// Zen 免费聊天可匿名调用。
  final bool keyRequired;

  final LlmCatalogShape catalogShape;
  final String catalogPathSuffix;

  /// 百炼目录挂在站点根（/api/v1/models），不随 workspace base 变。
  final bool catalogOriginRooted;

  /// 仅收录 #139 已验证的模型 ID（§9：未验证项不进默认值）。
  final List<String> verifiedDefaultModels;

  /// JSON 结构化输出（#139：仅 OpenAI 族上游验证过）。
  final bool jsonMode;

  bool get hasCatalog => catalogShape != LlmCatalogShape.none;

  /// 该预设可选的路线。内置预设只能用其文档化的路线；
  /// 自定义预设五族全开（不兼容组合由解析层给出明确错误）。
  Set<LlmRouteProtocol> get selectableProtocols => isCustom
      ? LlmRouteProtocol.values.toSet()
      : chatPaths.keys.toSet();

  /// 生效的调用路径。内置预设直接查表；自定义预设按 includesV1 推导
  /// OpenAI 族的 Chat Completions 路径（Anthropic Messages 固定 /v1/messages）。
  String? chatPath(LlmRouteProtocol protocol, bool includesV1) {
    final literal = chatPaths[protocol];
    if (literal != null) return literal;
    if (isCustom) {
      return switch (protocol) {
        LlmRouteProtocol.openaiChat =>
          includesV1 ? '/v1/chat/completions' : '/chat/completions',
        LlmRouteProtocol.anthropicMessages => '/v1/messages',
        LlmRouteProtocol _ => null,
      };
    }
    return null;
  }
}

/// 九个上游预设（#139 结论文档）。
const List<LlmProviderPreset> kLlmProviderPresets = <LlmProviderPreset>[
  LlmProviderPreset(
    id: 'deepseek',
    displayName: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    baseIncludesV1: false,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/chat/completions',
      LlmRouteProtocol.anthropicMessages: '/anthropic/v1/messages',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    jsonMode: true,
  ),
  LlmProviderPreset(
    id: 'openrouter',
    displayName: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/v1/chat/completions',
      LlmRouteProtocol.openaiResponses: '/v1/responses',
      LlmRouteProtocol.anthropicMessages: '/v1/messages',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    jsonMode: true,
  ),
  LlmProviderPreset(
    id: 'xiaomimimo',
    displayName: '小米 MiMo',
    baseUrl: 'https://api.xiaomimimo.com',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/v1/chat/completions',
      LlmRouteProtocol.anthropicMessages: '/anthropic/v1/messages',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    catalogShape: LlmCatalogShape.none,
    verifiedDefaultModels: <String>['mimo-v2.6-pro', 'mimo-v2.6-flash'],
  ),
  LlmProviderPreset(
    id: 'aliyun-bailian',
    displayName: '阿里云百炼 Model Studio',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/v1/chat/completions',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    catalogShape: LlmCatalogShape.dashscopePages,
    catalogPathSuffix: '/api/v1/models',
    catalogOriginRooted: true,
    jsonMode: true,
  ),
  LlmProviderPreset(
    id: 'siliconflow',
    displayName: '硅基流动',
    baseUrl: 'https://api.siliconflow.cn',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/v1/chat/completions',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    jsonMode: true,
  ),
  LlmProviderPreset(
    id: 'opencode-zen',
    displayName: 'OpenCode Zen',
    baseUrl: 'https://opencode.ai/inference',
    // 家族根路径各自带版本段（openai/v1/...、anthropic/v1/...），
    // base 不补 /v1；目录用显式 /v1/models。
    baseIncludesV1: false,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/openai/v1/chat/completions',
      LlmRouteProtocol.openaiResponses: '/openai/v1/responses',
      LlmRouteProtocol.anthropicMessages: '/anthropic/v1/messages',
      LlmRouteProtocol.google: '/google/v1beta',
      LlmRouteProtocol.systemone: '/systemone',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    keyRequired: false,
    catalogPathSuffix: '/v1/models',
  ),
  LlmProviderPreset(
    id: 'commandcode',
    displayName: 'Command Code',
    baseUrl: 'https://api.commandcode.ai/provider',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/chat/completions',
      LlmRouteProtocol.anthropicMessages: '/v1/messages',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
  ),
  LlmProviderPreset(
    id: 'custom-openai',
    displayName: '自定义 OpenAI Compatible',
    isCustom: true,
    baseUrl: '',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.openaiChat: '/chat/completions',
    },
    primaryProtocol: LlmRouteProtocol.openaiChat,
    jsonMode: true,
  ),
  LlmProviderPreset(
    id: 'custom-anthropic',
    displayName: '自定义 Anthropic Compatible',
    isCustom: true,
    baseUrl: '',
    baseIncludesV1: true,
    chatPaths: <LlmRouteProtocol, String>{
      LlmRouteProtocol.anthropicMessages: '/v1/messages',
    },
    primaryProtocol: LlmRouteProtocol.anthropicMessages,
    catalogShape: LlmCatalogShape.none,
  ),
];

LlmProviderPreset? llmProviderPresetById(String id) {
  for (final preset in kLlmProviderPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}

/// 每个提供方一份独立配置（保存到 v2 命名空间，键含 providerId）。
@immutable
class LlmProviderAccount {
  const LlmProviderAccount({
    required this.providerId,
    this.protocol,
    this.baseUrl = '',
    this.includesV1Override,
    this.authOverride,
    this.model = '',
    this.confirmed = false,
    this.httpInsecureConfirmed = false,
  });

  final String providerId;

  /// null = 使用预设的 primaryProtocol。
  final LlmRouteProtocol? protocol;

  /// 空 = 使用预设默认 Base URL。
  final String baseUrl;

  /// null = 使用预设默认值；否则覆盖是否补 /v1（自定义预设必填项之一）。
  final bool? includesV1Override;
  final LlmPresetAuth? authOverride;
  final String model;

  /// 验证状态（#139：模型/Key/地址/协议变更后失效，见配置存储）。
  final bool confirmed;

  /// 非 HTTPS 地址的显式风险确认。
  final bool httpInsecureConfirmed;

  LlmProviderAccount copyWith({
    LlmRouteProtocol? protocol,
    bool protocolSet = true,
    String? baseUrl,
    bool? includesV1Override,
    bool includesV1Set = true,
    LlmPresetAuth? authOverride,
    bool authSet = true,
    String? model,
    bool? confirmed,
    bool? httpInsecureConfirmed,
  }) {
    return LlmProviderAccount(
      providerId: providerId,
      protocol: protocolSet ? (protocol ?? this.protocol) : null,
      baseUrl: baseUrl ?? this.baseUrl,
      includesV1Override:
          includesV1Set ? (includesV1Override ?? this.includesV1Override) : null,
      authOverride: authSet ? (authOverride ?? this.authOverride) : null,
      model: model ?? this.model,
      confirmed: confirmed ?? this.confirmed,
      httpInsecureConfirmed:
          httpInsecureConfirmed ?? this.httpInsecureConfirmed,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'provider_id': providerId,
        'protocol': protocol?.id,
        'base_url': baseUrl,
        'includes_v1': includesV1Override,
        'auth': authOverride?.id,
        'model': model,
        'confirmed': confirmed,
        'insecure_confirmed': httpInsecureConfirmed,
      };

  static LlmProviderAccount? tryFromJson(Object? data) {
    if (data is! Map) return null;
    final providerId = data['provider_id'];
    if (providerId is! String || providerId.isEmpty) return null;
    return LlmProviderAccount(
      providerId: providerId,
      protocol: LlmRouteProtocol.tryFromId(data['protocol'] as String?),
      baseUrl: data['base_url'] is String ? data['base_url'] as String : '',
      includesV1Override:
          data['includes_v1'] is bool ? data['includes_v1'] as bool : null,
      authOverride: LlmPresetAuth.tryFromId(data['auth'] as String?),
      model: data['model'] is String ? data['model'] as String : '',
      confirmed: data['confirmed'] == true,
      httpInsecureConfirmed: data['insecure_confirmed'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LlmProviderAccount &&
        other.providerId == providerId &&
        other.protocol == protocol &&
        other.baseUrl == baseUrl &&
        other.includesV1Override == includesV1Override &&
        other.authOverride == authOverride &&
        other.model == model &&
        other.confirmed == confirmed &&
        other.httpInsecureConfirmed == httpInsecureConfirmed;
  }

  @override
  int get hashCode => Object.hash(providerId, protocol, baseUrl,
      includesV1Override, authOverride, model, confirmed,
      httpInsecureConfirmed);
}

String _trimTrailingSlash(String value) {
  var result = value.trim();
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

/// 在 base 上补 /v1（#139：base-before-version 存储）。
String llmVersionedBase(String base, bool includesV1) {
  final trimmed = _trimTrailingSlash(base);
  if (!includesV1) return trimmed;
  if (trimmed.toLowerCase().endsWith('/v1')) return trimmed;
  return '$trimmed/v1';
}

/// 端点拼接，防重复（#144 验收：/v1 与 /models 都不得重复）：
/// 1. base 已是完整端点（以 suffix 结尾）→ 原样返回；
/// 2. suffix 以 /v1/ 开头且 base 以 /v1 结尾 → 去掉 base 的 /v1 再拼；
/// 3. 否则直接拼接。
String llmJoinEndpoint(String base, String suffix) {
  var b = _trimTrailingSlash(base);
  final s = suffix;
  if (b.toLowerCase().endsWith(s.toLowerCase())) return b;
  if (s.toLowerCase().startsWith('/v1/') &&
      b.toLowerCase().endsWith('/v1')) {
    b = b.substring(0, b.length - 3);
  }
  return b + s;
}

/// 预设 + 账户配置的解析结果：端点、兼容性问题、鉴权头、候选模型。
/// 只产出纯数据；网络调用（探活/目录拉取）由 #145 接线。
@immutable
class LlmResolvedProvider {
  LlmResolvedProvider({
    required this.preset,
    required this.account,
  })  : baseUrl = _effectiveBaseUrl(preset, account),
        baseIncludesV1 = account.includesV1Override ?? preset.baseIncludesV1;

  final LlmProviderPreset preset;
  final LlmProviderAccount account;
  final String baseUrl;
  final bool baseIncludesV1;

  static String _effectiveBaseUrl(
      LlmProviderPreset preset, LlmProviderAccount account) {
    final custom = account.baseUrl.trim();
    if (custom.isNotEmpty) return custom;
    return preset.baseUrl;
  }

  /// null = 未显式选择路线（此时不判定路线兼容性，由 [effectiveProtocol]
  /// 给出预设默认）。
  LlmRouteProtocol? get selectedProtocol => account.protocol;

  LlmRouteProtocol get effectiveProtocol =>
      account.protocol ?? preset.primaryProtocol;

  String? get chatEndpoint {
    final path = preset.chatPath(effectiveProtocol, baseIncludesV1);
    if (path == null) return null;
    return llmJoinEndpoint(
        llmVersionedBase(baseUrl, baseIncludesV1), path);
  }

  String? get catalogEndpoint {
    if (!preset.hasCatalog) return null;
    if (preset.catalogOriginRooted) {
      final uri = Uri.tryParse(baseUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
      return '${uri.scheme}://${uri.host}${preset.catalogPathSuffix}';
    }
    return llmJoinEndpoint(
        llmVersionedBase(baseUrl, baseIncludesV1), preset.catalogPathSuffix);
  }

  LlmPresetAuth get effectiveAuth =>
      account.authOverride ?? preset.defaultAuth;

  /// 鉴权头。Key 为空时不发鉴权头（匿名调用）。
  Map<String, String> authHeaders(String apiKey) =>
      effectiveAuth.headers(apiKey);

  /// 目录不可用时（none 形态）的候选模型只剩验证过的静态表。
  List<String> get candidateModels => preset.verifiedDefaultModels;

  bool jsonModeSupported([LlmRouteProtocol? protocol]) {
    final route = protocol ?? effectiveProtocol;
    return preset.jsonMode && route == LlmRouteProtocol.openaiChat;
  }

  List<LlmPresetIssue> get issues {
    final result = <LlmPresetIssue>[];
    final base = baseUrl.trim();
    if (base.isEmpty) {
      result.add(LlmPresetIssue.missingBaseUrl);
    } else {
      final uri = Uri.tryParse(base);
      final scheme = uri?.scheme.toLowerCase();
      if (uri == null ||
          (scheme != 'http' && scheme != 'https') ||
          uri.host.isEmpty) {
        result.add(LlmPresetIssue.invalidBaseUrl);
      } else if (scheme == 'http' && !account.httpInsecureConfirmed) {
        result.add(LlmPresetIssue.insecureBaseUrl);
      }
    }
    if (account.model.trim().isEmpty) {
      result.add(LlmPresetIssue.missingModel);
    }
    final route = account.protocol;
    if (route != null) {
      if (preset.chatPath(route, baseIncludesV1) == null) {
        result.add(LlmPresetIssue.unsupportedRoute);
      }
      if (!route.screenable) {
        result.add(LlmPresetIssue.routeNotScreenable);
      }
    }
    if (!preset.hasCatalog && preset.verifiedDefaultModels.isEmpty) {
      result.add(LlmPresetIssue.catalogUnavailable);
    }
    return result;
  }
}

/// 路线展示名（设置页路线单选；#145）。
extension LlmRouteProtocolLabel on LlmRouteProtocol {
  String get label => switch (this) {
        LlmRouteProtocol.openaiChat => 'OpenAI Chat Completions',
        LlmRouteProtocol.openaiResponses => 'OpenAI Responses',
        LlmRouteProtocol.anthropicMessages => 'Anthropic Messages',
        LlmRouteProtocol.google => 'Google Gemini',
        LlmRouteProtocol.systemone => 'SystemOne',
      };
}

/// 筛选线（v1）可消费的两协议配置，或一条明确的协议不匹配原因。
class LlmLegacyMapping {
  const LlmLegacyMapping(this.config, this.error);
  final LlmProviderConfig? config;
  final String? error;
}

/// Issue #145: 把已解析的提供方配置映射为筛选线（v1）可执行的配置。
///
/// 只有 OpenAI Chat Completions / Anthropic Messages 两条路线可映射；端点
/// 必须以协议标准后缀收尾（家族根路径同样满足），鉴权方式必须与筛选线实际
/// 发送的头一致：openaiChat 需要 Bearer；anthropicMessages 接受协议默认的
/// x-api-key（anthropicNative），Bearer 则映射为 v1 的 bearerAuth 位。其余
/// 组合返回 config = null 与 [LlmLegacyMapping.error]。映射只读
/// [resolved]，不发起任何网络请求。
LlmLegacyMapping llmLegacyMappingFor(
  LlmResolvedProvider resolved, {
  bool confirmed = false,
}) {
  final route = resolved.effectiveProtocol;
  if (!route.screenable) {
    return const LlmLegacyMapping(
      null,
      '该路线不参与评论/视频筛选，请改用 OpenAI Chat Completions 或'
      ' Anthropic Messages',
    );
  }
  final endpoint = resolved.chatEndpoint;
  if (endpoint == null) {
    return const LlmLegacyMapping(
      null,
      '该路线没有可用的调用路径，请更换请求路线',
    );
  }
  final isAnthropic = route == LlmRouteProtocol.anthropicMessages;
  final suffix = isAnthropic ? '/v1/messages' : '/chat/completions';
  if (!endpoint.endsWith(suffix)) {
    return LlmLegacyMapping(
      null,
      '该路线的调用路径与筛选引擎不一致（$endpoint），'
      '请改用标准 OpenAI Chat Completions 或 Anthropic Messages 端点',
    );
  }
  if (!isAnthropic && resolved.effectiveAuth != LlmPresetAuth.bearer) {
    return const LlmLegacyMapping(
      null,
      '该路线的鉴权方式与筛选引擎不一致，请改用 Bearer 鉴权',
    );
  }
  return LlmLegacyMapping(
    LlmProviderConfig(
      protocol: isAnthropic
          ? LlmProtocol.anthropicCompatible
          : LlmProtocol.openAICompatible,
      baseUrl: endpoint.substring(0, endpoint.length - suffix.length),
      model: resolved.account.model,
      confirmed: confirmed,
      httpInsecureConfirmed: resolved.account.httpInsecureConfirmed,
      bearerAuth: isAnthropic &&
          resolved.effectiveAuth == LlmPresetAuth.bearer,
    ),
    null,
  );
}