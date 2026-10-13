import 'package:PiliPlus/features/llm/llm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenAI extraction reads the first message content', () {
    expect(
      LlmResponseText.extract(LlmProtocol.openAICompatible, {
        'choices': [
          {
            'message': {'content': 'hello'},
          },
        ],
      }),
      'hello',
    );
    expect(LlmResponseText.extract(LlmProtocol.openAICompatible, null), isNull);
    expect(
      LlmResponseText.extract(LlmProtocol.openAICompatible, {'choices': []}),
      isNull,
    );
    expect(
      LlmResponseText.extract(LlmProtocol.openAICompatible, {
        'choices': [
          {
            'message': {'content': null},
          },
        ],
      }),
      isNull,
    );
  });

  test('Anthropic extraction joins text blocks and skips the rest', () {
    final newline = String.fromCharCode(10);
    expect(
      LlmResponseText.extract(LlmProtocol.anthropicCompatible, {
        'content': [
          {'type': 'text', 'text': 'a'},
          {'type': 'thinking', 'text': 'nope'},
          {'type': 'tool_use', 'id': 't'},
          {'type': 'text', 'text': 'c'},
        ],
      }),
      'a${newline}c',
    );
    expect(
      LlmResponseText.extract(LlmProtocol.anthropicCompatible, {
        'content': 'plain',
      }),
      'plain',
    );
    expect(
      LlmResponseText.extract(LlmProtocol.anthropicCompatible, {
        'content': [
          {'type': 'thinking', 'text': 'only thinking'},
        ],
      }),
      isNull,
    );
    expect(
      LlmResponseText.extract(LlmProtocol.anthropicCompatible, null),
      isNull,
    );
  });
}
