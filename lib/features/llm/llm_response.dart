import 'package:PiliPlus/features/llm/llm_contract.dart';

// Lenient text extraction from one chat response body (spec section 4).
//
// Returns the visible text output, or null when the body carries no
// extractable text. Reasoning and tool-call blocks are skipped, never treated
// as output.
abstract final class LlmResponseText {
  static String? extract(LlmProtocol protocol, Object? data) =>
      switch (protocol) {
        LlmProtocol.openAICompatible => _fromOpenAi(data),
        LlmProtocol.anthropicCompatible => _fromAnthropic(data),
      };

  static String? _fromOpenAi(Object? data) {
    if (data is! Map) return null;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is! Map) return null;
    final content = message['content'];
    if (content is! String) return null;
    return content;
  }

  static String? _fromAnthropic(Object? data) {
    if (data is! Map) return null;
    final content = data['content'];
    // Lenient: a few compatible services reply with a plain string.
    if (content is String) return content;
    if (content is! List) return null;
    final parts = <String>[];
    for (final block in content) {
      if (block is! Map) continue;
      if (block['type'] != 'text') continue;
      final text = block['text'];
      if (text is String && text.isNotEmpty) parts.add(text);
    }
    if (parts.isEmpty) return null;
    return parts.join(String.fromCharCode(10));
  }
}
