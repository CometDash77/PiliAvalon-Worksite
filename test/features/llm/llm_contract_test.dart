import 'package:PiliPlus/features/llm/llm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protocol ids round-trip and unknown ids fail closed', () {
    for (final protocol in LlmProtocol.values) {
      expect(LlmProtocol.tryFromId(protocol.id), protocol);
    }
    expect(LlmProtocol.tryFromId('nope'), isNull);
    expect(LlmProtocol.tryFromId(null), isNull);
  });

  test('paths follow the verified per-protocol contracts', () {
    expect(LlmProtocol.openAICompatible.chatPath, '/chat/completions');
    expect(LlmProtocol.openAICompatible.catalogPath, '/models');
    expect(LlmProtocol.anthropicCompatible.chatPath, '/v1/messages');
    expect(LlmProtocol.anthropicCompatible.catalogPath, '/v1/models');
  });

  test('auth headers use the documented scheme per protocol', () {
    final openai = LlmProtocol.openAICompatible.authHeaders('k1');
    expect(openai['authorization'], 'Bearer k1');
    expect(openai.containsKey('anthropic-version'), isFalse);

    final anthropic = LlmProtocol.anthropicCompatible.authHeaders('k2');
    expect(anthropic['x-api-key'], 'k2');
    expect(anthropic['anthropic-version'], '2023-06-01');
    expect(anthropic.containsKey('authorization'), isFalse);
  });
}
