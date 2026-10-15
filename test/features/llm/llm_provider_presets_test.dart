import 'package:PiliPlus/features/llm/llm_provider_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preset data (issue #139 conclusions)', () {
    test('nine presets with stable provider ids', () {
      expect(kLlmProviderPresets.map((p) => p.id).toList(), [
        'deepseek',
        'openrouter',
        'xiaomimimo',
        'aliyun-bailian',
        'siliconflow',
        'opencode-zen',
        'commandcode',
        'custom-openai',
        'custom-anthropic',
      ]);
      expect(
        kLlmProviderPresets.where((p) => p.isCustom).map((p) => p.id),
        ['custom-openai', 'custom-anthropic'],
      );
    });

    test('deepseek is the only plain-versioned base without /v1', () {
      final flags = {
        for (final p in kLlmProviderPresets) p.id: p.baseIncludesV1,
      };
      expect(flags['deepseek'], isFalse);
      // opencode-zen 家族根路径自带版本段，base 不补 /v1。
      expect(flags['opencode-zen'], isFalse);
      for (final entry in flags.entries) {
        if (entry.key == 'deepseek' || entry.key == 'opencode-zen') continue;
        expect(entry.value, isTrue, reason: entry.key);
      }
    });

    test('only the verified MiMo models enter defaults (§9)', () {
      for (final preset in kLlmProviderPresets) {
        if (preset.id == 'xiaomimimo') {
          expect(preset.verifiedDefaultModels,
              ['mimo-v2.6-pro', 'mimo-v2.6-flash']);
        } else {
          expect(preset.verifiedDefaultModels, isEmpty,
              reason: '${preset.id} has no verified models in #139');
        }
      }
    });

    test('every preset defaults to Bearer auth (#139 custom rule)', () {
      expect(kLlmProviderPresets.map((p) => p.defaultAuth),
          everyElement(LlmPresetAuth.bearer));
    });

    test('zen exposes all five protocol families, commandcode two', () {
      final zen = llmProviderPresetById('opencode-zen')!;
      expect(zen.chatPaths.keys, {
        LlmRouteProtocol.openaiChat,
        LlmRouteProtocol.openaiResponses,
        LlmRouteProtocol.anthropicMessages,
        LlmRouteProtocol.google,
        LlmRouteProtocol.systemone,
      });
      expect(zen.keyRequired, isFalse);

      final cc = llmProviderPresetById('commandcode')!;
      expect(cc.chatPaths.keys, {
        LlmRouteProtocol.openaiChat,
        LlmRouteProtocol.anthropicMessages,
      });
    });

    test('catalog shapes: mimo/custom-anthropic none, bailian origin-rooted', () {
      expect(llmProviderPresetById('xiaomimimo')!.catalogShape,
          LlmCatalogShape.none);
      expect(llmProviderPresetById('custom-anthropic')!.catalogShape,
          LlmCatalogShape.none);
      final bailian = llmProviderPresetById('aliyun-bailian')!;
      expect(bailian.catalogShape, LlmCatalogShape.dashscopePages);
      expect(bailian.catalogOriginRooted, isTrue);
      expect(bailian.catalogPathSuffix, '/api/v1/models');
      for (final id in ['deepseek', 'openrouter', 'siliconflow', 'commandcode']) {
        expect(llmProviderPresetById(id)!.catalogShape,
            LlmCatalogShape.openaiData,
            reason: id);
      }
    });

    test('json mode only on presets where #139 verified it', () {
      final jsonModeIds = kLlmProviderPresets
          .where((p) => p.jsonMode)
          .map((p) => p.id)
          .toList();
      expect(jsonModeIds,
          ['deepseek', 'openrouter', 'aliyun-bailian', 'siliconflow', 'custom-openai']);
    });
  });

  group('endpoint building', () {
    test('llmJoinEndpoint dedups /v1 and full endpoints', () {
      expect(
        llmJoinEndpoint('https://x.example/v1', '/v1/chat/completions'),
        'https://x.example/v1/chat/completions',
      );
      expect(
        llmJoinEndpoint('https://x.example/v1/chat/completions/',
            '/chat/completions'),
        'https://x.example/v1/chat/completions',
      );
      expect(
        llmJoinEndpoint('https://x.example/v1/models', '/models'),
        'https://x.example/v1/models',
      );
      expect(
        llmJoinEndpoint('https://x.example/api/', '/v1/models'),
        'https://x.example/api/v1/models',
      );
    });

    test('deepseek: no /v1 anywhere', () {
      final preset = llmProviderPresetById('deepseek')!;
      final resolved = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(providerId: 'deepseek'),
      );
      expect(resolved.baseUrl, 'https://api.deepseek.com');
      expect(resolved.chatEndpoint,
          'https://api.deepseek.com/chat/completions');
      expect(resolved.catalogEndpoint, 'https://api.deepseek.com/models');
    });

    test('openrouter: override base ending in /v1 stays single-versioned', () {
      final preset = llmProviderPresetById('openrouter')!;
      final resolved = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(
          providerId: 'openrouter',
          baseUrl: 'https://openrouter.ai/api/v1/',
        ),
      );
      expect(resolved.chatEndpoint,
          'https://openrouter.ai/api/v1/chat/completions');
      expect(resolved.catalogEndpoint, 'https://openrouter.ai/api/v1/models');
    });

    test('zen: per-family paths and root catalog', () {
      final preset = llmProviderPresetById('opencode-zen')!;
      LlmResolvedProvider resolve(LlmRouteProtocol protocol) =>
          LlmResolvedProvider(
            preset: preset,
            account: LlmProviderAccount(
              providerId: 'opencode-zen',
              protocol: protocol,
            ),
          );
      expect(resolve(LlmRouteProtocol.openaiChat).chatEndpoint,
          'https://opencode.ai/inference/openai/v1/chat/completions');
      expect(resolve(LlmRouteProtocol.openaiResponses).chatEndpoint,
          'https://opencode.ai/inference/openai/v1/responses');
      expect(resolve(LlmRouteProtocol.anthropicMessages).chatEndpoint,
          'https://opencode.ai/inference/anthropic/v1/messages');
      expect(resolve(LlmRouteProtocol.google).chatEndpoint,
          'https://opencode.ai/inference/google/v1beta');
      expect(resolve(LlmRouteProtocol.systemone).chatEndpoint,
          'https://opencode.ai/inference/systemone');
      final resolved = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(providerId: 'opencode-zen'),
      );
      expect(resolved.catalogEndpoint,
          'https://opencode.ai/inference/v1/models');
    });

    test('commandcode: /provider/v1 routes', () {
      final preset = llmProviderPresetById('commandcode')!;
      LlmResolvedProvider resolve(LlmRouteProtocol protocol) =>
          LlmResolvedProvider(
            preset: preset,
            account: LlmProviderAccount(
              providerId: 'commandcode',
              protocol: protocol,
            ),
          );
      expect(resolve(LlmRouteProtocol.openaiChat).chatEndpoint,
          'https://api.commandcode.ai/provider/v1/chat/completions');
      expect(resolve(LlmRouteProtocol.anthropicMessages).chatEndpoint,
          'https://api.commandcode.ai/provider/v1/messages');
      expect(resolve(LlmRouteProtocol.openaiChat).catalogEndpoint,
          'https://api.commandcode.ai/provider/v1/models');
    });

    test('bailian: workspace override keeps catalog on the workspace origin', () {
      final preset = llmProviderPresetById('aliyun-bailian')!;
      final resolved = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(
          providerId: 'aliyun-bailian',
          baseUrl: 'https://ws123.cn-beijing.maas.aliyuncs.com/compatible-mode',
        ),
      );
      expect(resolved.chatEndpoint,
          'https://ws123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions');
      expect(resolved.catalogEndpoint,
          'https://ws123.cn-beijing.maas.aliyuncs.com/api/v1/models');
    });

    test('siliconflow: /v1/models catalog path', () {
      final preset = llmProviderPresetById('siliconflow')!;
      final resolved = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(providerId: 'siliconflow'),
      );
      expect(resolved.catalogEndpoint, 'https://api.siliconflow.cn/v1/models');
    });
  });

  group('compatibility errors (acceptance: explicit, no guessing)', () {
    test('non-screenable routes get the explicit fallback message', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('openrouter')!,
        account: const LlmProviderAccount(
          providerId: 'openrouter',
          protocol: LlmRouteProtocol.openaiResponses,
        ),
      );
      expect(resolved.issues, contains(LlmPresetIssue.routeNotScreenable));
    });

    test('routes outside the preset family are rejected explicitly', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('deepseek')!,
        account: const LlmProviderAccount(
          providerId: 'deepseek',
          protocol: LlmRouteProtocol.systemone,
        ),
      );
      expect(resolved.issues, contains(LlmPresetIssue.unsupportedRoute));
      expect(resolved.chatEndpoint, isNull);
    });

    test('custom anthropic without catalog says so explicitly', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('custom-anthropic')!,
        account: const LlmProviderAccount(
          providerId: 'custom-anthropic',
          baseUrl: 'https://relay.example.com',
        ),
      );
      expect(resolved.catalogEndpoint, isNull);
      expect(resolved.issues, contains(LlmPresetIssue.catalogUnavailable));
    });

    test('json mode is refused outside the OpenAI chat route', () {
      final preset = llmProviderPresetById('deepseek')!;
      final openai = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(providerId: 'deepseek'),
      );
      expect(openai.jsonModeSupported(), isTrue);
      expect(openai.jsonModeSupported(LlmRouteProtocol.openaiChat), isTrue);
      expect(
        openai.jsonModeSupported(LlmRouteProtocol.anthropicMessages),
        isFalse,
      );
      final mimo = LlmResolvedProvider(
        preset: llmProviderPresetById('xiaomimimo')!,
        account: const LlmProviderAccount(providerId: 'xiaomimimo'),
      );
      expect(mimo.jsonModeSupported(), isFalse);
    });

    test('custom presets may pick every route; built-ins stay documented', () {
      expect(llmProviderPresetById('custom-openai')!.selectableProtocols,
          LlmRouteProtocol.values.toSet());
      expect(llmProviderPresetById('deepseek')!.selectableProtocols, {
        LlmRouteProtocol.openaiChat,
        LlmRouteProtocol.anthropicMessages,
      });
    });

    test('structural issues: missing base/model, invalid and http bases', () {
      LlmResolvedProvider resolve(LlmProviderAccount account) =>
          LlmResolvedProvider(
            preset: llmProviderPresetById('custom-openai')!,
            account: account,
          );
      final empty = resolve(const LlmProviderAccount(providerId: 'custom-openai'));
      expect(empty.issues, contains(LlmPresetIssue.missingBaseUrl));
      expect(empty.issues, contains(LlmPresetIssue.missingModel));
      final bad = resolve(const LlmProviderAccount(
        providerId: 'custom-openai',
        baseUrl: 'not a url',
      ));
      expect(bad.issues, contains(LlmPresetIssue.invalidBaseUrl));
      final http = resolve(const LlmProviderAccount(
        providerId: 'custom-openai',
        baseUrl: 'http://192.168.1.10:1234',
      ));
      expect(http.issues, contains(LlmPresetIssue.insecureBaseUrl));
      final confirmed = resolve(const LlmProviderAccount(
        providerId: 'custom-openai',
        baseUrl: 'http://192.168.1.10:1234',
        httpInsecureConfirmed: true,
      ));
      expect(
        confirmed.issues.where((i) => i == LlmPresetIssue.insecureBaseUrl),
        isEmpty,
      );
    });
  });

  group('auto-fill and override', () {
    test('empty account base falls back to the preset default', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('deepseek')!,
        account: const LlmProviderAccount(providerId: 'deepseek'),
      );
      expect(resolved.baseUrl, 'https://api.deepseek.com');
      expect(resolved.baseIncludesV1, isFalse);
    });

    test('custom openai: includesV1 override flips the chat path', () {
      final preset = llmProviderPresetById('custom-openai')!;
      final withoutV1 = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(
          providerId: 'custom-openai',
          baseUrl: 'https://relay.example.com',
          includesV1Override: false,
        ),
      );
      expect(
        withoutV1.chatEndpoint,
        'https://relay.example.com/chat/completions',
      );
      final withV1 = LlmResolvedProvider(
        preset: preset,
        account: const LlmProviderAccount(
          providerId: 'custom-openai',
          baseUrl: 'https://relay.example.com',
          includesV1Override: true,
        ),
      );
      expect(
        withV1.chatEndpoint,
        'https://relay.example.com/v1/chat/completions',
      );
    });

    test('account JSON round-trips every field', () {
      const account = LlmProviderAccount(
        providerId: 'custom-openai',
        protocol: LlmRouteProtocol.openaiChat,
        baseUrl: 'https://relay.example.com/v1',
        includesV1Override: false,
        authOverride: LlmPresetAuth.anthropicNative,
        model: 'm1',
        confirmed: true,
        httpInsecureConfirmed: true,
      );
      final restored = LlmProviderAccount.tryFromJson(account.toJson());
      expect(restored, account);
    });

    test('account JSON ignores unknown protocol/auth ids', () {
      final restored = LlmProviderAccount.tryFromJson({
        'provider_id': 'custom-openai',
        'protocol': 'nope',
        'auth': 'nope',
      });
      expect(restored, isNotNull);
      expect(restored!.protocol, isNull);
      expect(restored.authOverride, isNull);
    });
  });

  group('auth headers', () {
    test('bearer shape', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('deepseek')!,
        account: const LlmProviderAccount(providerId: 'deepseek'),
      );
      expect(resolved.authHeaders('sk-abc'), {
        'authorization': 'Bearer sk-abc',
      });
    });

    test('anthropic native shape via override (custom editability)', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('custom-anthropic')!,
        account: const LlmProviderAccount(
          providerId: 'custom-anthropic',
          authOverride: LlmPresetAuth.anthropicNative,
        ),
      );
      expect(resolved.authHeaders('sk-abc'), {
        'x-api-key': 'sk-abc',
        'anthropic-version': '2023-06-01',
      });
    });

    test('empty key sends no auth header (anonymous zen chat)', () {
      final resolved = LlmResolvedProvider(
        preset: llmProviderPresetById('opencode-zen')!,
        account: const LlmProviderAccount(providerId: 'opencode-zen'),
      );
      expect(resolved.authHeaders(''), isEmpty);
    });
  });
}