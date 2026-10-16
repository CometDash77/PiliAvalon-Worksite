import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:PiliPlus/utils/storage.dart';

/// 思考开关/强度的显式选择（issue #176）。
/// 未选择（null）= 跟随上游默认，不发任何字段。
enum LlmThinkingChoice { off, low, high, max }

/// DeepSeek 两条可筛选路线各有一套思考字段词表。
enum LlmThinkingFlavor { deepseekOpenaiChat, deepseekAnthropicCompat }

/// 思考能力证据仅覆盖官方文档确认的 DeepSeek 双路线；其余上游一律
/// 返回 null（控件隐藏、不发字段，不做网关透传猜测）。
abstract final class LlmThinking {
  /// host 为 api.deepseek.com（大小写不敏感）才受支持；否则 null。
  static LlmThinkingFlavor? flavorFor({
    required bool anthropicRoute,
    required String baseUrl,
  }) {
    final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase();
    if (host != 'api.deepseek.com') return null;
    return anthropicRoute
        ? LlmThinkingFlavor.deepseekAnthropicCompat
        : LlmThinkingFlavor.deepseekOpenaiChat;
  }

  /// 一次请求携带的思考字段。
  static Map<String, Object?> fieldsFor(
    LlmThinkingFlavor flavor,
    LlmThinkingChoice choice,
  ) => switch (flavor) {
        LlmThinkingFlavor.deepseekOpenaiChat =>
          choice == LlmThinkingChoice.off
              ? <String, Object?>{
                  'thinking': <String, Object?>{'type': 'disabled'},
                }
              : <String, Object?>{
                  'thinking': <String, Object?>{'type': 'enabled'},
                  'reasoning_effort': choice.name,
                },
        LlmThinkingFlavor.deepseekAnthropicCompat =>
          choice == LlmThinkingChoice.off
              ? <String, Object?>{
                  'reasoning': <String, Object?>{'effort': 'none'},
                }
              : <String, Object?>{
                  'output_config': <String, Object?>{'effort': choice.name},
                },
      };

  /// 注册表身份：以「筛选线将消费的 v1 legacy config」计算，探活写与
  /// 筛选读天然同源。路线词表统一取 LlmRouteProtocol.id
  /// （'openai_chat'/'anthropic_messages'），避免与 LlmProtocol.id 错位。
  static String identityFor(LlmProviderConfig config) {
    final route = config.protocol == LlmProtocol.anthropicCompatible
        ? 'anthropic_messages'
        : 'openai_chat';
    return '$route|${config.normalizedBaseUrl}|${config.model}';
  }

  /// 筛选线入口：路线不受支持或注册表未选择时返回 null（不发字段）。
  static LlmThinkingPlan? planFor({
    required LlmProviderConfig config,
    required LlmThinkingStore store,
  }) {
    final flavor = flavorFor(
      anthropicRoute: config.protocol == LlmProtocol.anthropicCompatible,
      baseUrl: config.normalizedBaseUrl,
    );
    if (flavor == null) return null;
    final choice = store.choiceFor(identityFor(config));
    if (choice == null) return null;
    return LlmThinkingPlan(choice: choice, flavor: flavor);
  }
}

/// 一次筛选会话解出的思考计划（choice + flavor → 线上字段）。
class LlmThinkingPlan {
  const LlmThinkingPlan({required this.choice, required this.flavor});

  final LlmThinkingChoice choice;
  final LlmThinkingFlavor flavor;

  Map<String, Object?> get fields => LlmThinking.fieldsFor(flavor, choice);
}

/// 思考选择注册表：identity → choice，JSON 存 v1 box。只在探活成功后
/// 写穿（保存配置不写），保证发上线的字段已被真实请求验证过。
class LlmThinkingStore {
  LlmThinkingStore({JevSettingsBox? box}) : _boxOrNull = box;

  static const String key = 'piliavalon.llm.v1.thinking.v1';

  // 构造期不触碰 GStorage（同 LlmSettingsStore/#130）：解析推迟到首次读写。
  final JevSettingsBox? _boxOrNull;
  JevSettingsBox? _lazyBox;
  JevSettingsBox get _box =>
      _lazyBox ??= _boxOrNull ?? HiveJevSettingsBox(GStorage.setting);

  Map<String, String> _load() {
    try {
      final raw = _box.get(key);
      if (raw is! String || raw.isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      final out = <String, String>{};
      decoded.forEach((k, v) {
        if (k is String && v is String) out[k] = v;
      });
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  LlmThinkingChoice? choiceFor(String identity) {
    final name = _load()[identity];
    for (final choice in LlmThinkingChoice.values) {
      if (choice.name == name) return choice;
    }
    return null;
  }

  Future<void> write(String identity, LlmThinkingChoice? choice) async {
    final map = _load();
    if (choice == null) {
      if (!map.containsKey(identity)) return;
      map.remove(identity);
    } else {
      map[identity] = choice.name;
    }
    await _box.put(key, jsonEncode(map));
  }
}
