import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart' show JevSettingsBox;
import 'package:PiliPlus/features/llm/llm.dart';

class _FakeBox implements JevSettingsBox {
  final map = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) => map[key] ?? defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

LlmProviderConfig _config({
  LlmProtocol protocol = LlmProtocol.openAICompatible,
  String baseUrl = 'https://api.deepseek.com',
  String model = 'deepseek-chat',
}) => LlmProviderConfig(
  protocol: protocol,
  baseUrl: baseUrl,
  model: model,
  confirmed: true,
);

void main() {
  group('LlmThinking.flavorFor', () {
    test('gates on the DeepSeek host (case-insensitive)', () {
      expect(
        LlmThinking.flavorFor(
          anthropicRoute: false,
          baseUrl: 'https://API.DEEPSEEK.com',
        ),
        LlmThinkingFlavor.deepseekOpenaiChat,
      );
      expect(
        LlmThinking.flavorFor(
          anthropicRoute: true,
          baseUrl: 'https://api.deepseek.com/',
        ),
        LlmThinkingFlavor.deepseekAnthropicCompat,
      );
      expect(
        LlmThinking.flavorFor(
          anthropicRoute: false,
          baseUrl: 'https://api.openai.com/v1',
        ),
        isNull,
      );
      expect(
        LlmThinking.flavorFor(anthropicRoute: false, baseUrl: 'not a url'),
        isNull,
      );
    });
  });

  group('LlmThinking.fieldsFor', () {
    test('openai chat route sends thinking plus reasoning_effort', () {
      final off = LlmThinking.fieldsFor(
        LlmThinkingFlavor.deepseekOpenaiChat,
        LlmThinkingChoice.off,
      );
      expect((off['thinking'] as Map)['type'], 'disabled');
      expect(off.containsKey('reasoning_effort'), isFalse);

      for (final choice in [
        LlmThinkingChoice.low,
        LlmThinkingChoice.high,
        LlmThinkingChoice.max,
      ]) {
        final fields = LlmThinking.fieldsFor(
          LlmThinkingFlavor.deepseekOpenaiChat,
          choice,
        );
        expect((fields['thinking'] as Map)['type'], 'enabled');
        expect(fields['reasoning_effort'], choice.name);
      }
    });

    test('anthropic compat route uses reasoning/output_config', () {
      final off = LlmThinking.fieldsFor(
        LlmThinkingFlavor.deepseekAnthropicCompat,
        LlmThinkingChoice.off,
      );
      expect((off['reasoning'] as Map)['effort'], 'none');
      expect(off.containsKey('output_config'), isFalse);

      final low = LlmThinking.fieldsFor(
        LlmThinkingFlavor.deepseekAnthropicCompat,
        LlmThinkingChoice.low,
      );
      expect((low['output_config'] as Map)['effort'], 'low');
      expect(low.containsKey('reasoning'), isFalse);

      final max = LlmThinking.fieldsFor(
        LlmThinkingFlavor.deepseekAnthropicCompat,
        LlmThinkingChoice.max,
      );
      expect((max['output_config'] as Map)['effort'], 'max');
    });
  });

  group('LlmThinking identity', () {
    test('uses the route vocabulary and normalized base url', () {
      expect(
        LlmThinking.identityFor(
          _config(protocol: LlmProtocol.openAICompatible),
        ),
        'openai_chat|https://api.deepseek.com|deepseek-chat',
      );
      expect(
        LlmThinking.identityFor(
          _config(
            protocol: LlmProtocol.anthropicCompatible,
            baseUrl: 'https://api.deepseek.com/',
          ),
        ),
        'anthropic_messages|https://api.deepseek.com|deepseek-chat',
      );
    });
  });

  group('LlmThinking.planFor', () {
    test('returns null outside DeepSeek or without a stored choice', () {
      final store = LlmThinkingStore(box: _FakeBox());
      expect(
        LlmThinking.planFor(
          config: _config(baseUrl: 'https://api.openai.com/v1'),
          store: store,
        ),
        isNull,
      );
      expect(LlmThinking.planFor(config: _config(), store: store), isNull);
    });

    test('returns a plan with wire fields once a choice is stored', () async {
      final store = LlmThinkingStore(box: _FakeBox());
      await store.write(
        'openai_chat|https://api.deepseek.com|deepseek-chat',
        LlmThinkingChoice.high,
      );
      final plan = LlmThinking.planFor(config: _config(), store: store);
      expect(plan, isNotNull);
      expect(plan!.choice, LlmThinkingChoice.high);
      expect(
        plan.fields,
        LlmThinking.fieldsFor(
          LlmThinkingFlavor.deepseekOpenaiChat,
          LlmThinkingChoice.high,
        ),
      );
    });
  });

  group('LlmThinkingStore', () {
    test('persists choices and keeps identities isolated', () async {
      final box = _FakeBox();
      final store = LlmThinkingStore(box: box);
      await store.write(
        'openai_chat|https://api.deepseek.com|chat',
        LlmThinkingChoice.off,
      );
      await store.write(
        'anthropic_messages|https://api.deepseek.com|chat',
        LlmThinkingChoice.low,
      );
      expect(
        store.choiceFor('openai_chat|https://api.deepseek.com|chat'),
        LlmThinkingChoice.off,
      );
      expect(
        store.choiceFor('anthropic_messages|https://api.deepseek.com|chat'),
        LlmThinkingChoice.low,
      );
      expect(
        store.choiceFor('openai_chat|https://other.example.com|chat'),
        isNull,
      );
      // 第二个 store 读同一 box,看到同一注册表。
      expect(
        LlmThinkingStore(
          box: box,
        ).choiceFor('openai_chat|https://api.deepseek.com|chat'),
        LlmThinkingChoice.off,
      );
    });

    test('write(null) removes the choice; absent write is a no-op', () async {
      final box = _FakeBox();
      final store = LlmThinkingStore(box: box);
      await store.write('k1', LlmThinkingChoice.max);
      await store.write('k1', null);
      expect(store.choiceFor('k1'), isNull);
      expect(box.map.containsKey(LlmThinkingStore.key), isFalse);
      await store.write('k2', null);
      expect(box.map.containsKey(LlmThinkingStore.key), isFalse);
    });

    test('corrupt payloads fall back to an empty registry', () async {
      final box = _FakeBox();
      await box.put(LlmThinkingStore.key, '{not json');
      expect(LlmThinkingStore(box: box).choiceFor('k'), isNull);
      await box.put(LlmThinkingStore.key, 42);
      expect(LlmThinkingStore(box: box).choiceFor('k'), isNull);
      await box.put(LlmThinkingStore.key, jsonEncode({'k': 'bogus'}));
      expect(LlmThinkingStore(box: box).choiceFor('k'), isNull);
    });
  });
}
