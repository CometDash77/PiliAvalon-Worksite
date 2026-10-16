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


/// 上游响应的 usage 观测（#176）：输入/缓存命中/缓存未命中 token。
/// 解析失败或全空时返回 null（不挂观测负载）。
class LlmUpstreamUsage {
  const LlmUpstreamUsage({
    this.inputTokens,
    this.cacheHitTokens,
    this.cacheMissTokens,
  });

  final int? inputTokens;
  final int? cacheHitTokens;
  final int? cacheMissTokens;

  static LlmUpstreamUsage? fromBody(LlmProtocol protocol, Object? data) {
    if (data is! Map) return null;
    final usage = data['usage'];
    if (usage is! Map) return null;
    int? pos(Object? v) => v is int && v > 0 ? v : null;
    final LlmUpstreamUsage parsed;
    switch (protocol) {
      case LlmProtocol.openAICompatible:
        final details = usage['prompt_tokens_details'];
        parsed = LlmUpstreamUsage(
          inputTokens: pos(usage['prompt_tokens']),
          cacheHitTokens: pos(usage['prompt_cache_hit_tokens']) ??
              pos(details is Map ? details['cached_tokens'] : null),
          cacheMissTokens: pos(usage['prompt_cache_miss_tokens']),
        );
      case LlmProtocol.anthropicCompatible:
        parsed = LlmUpstreamUsage(
          inputTokens: pos(usage['input_tokens']),
          cacheHitTokens: pos(usage['cache_read_input_tokens']),
          cacheMissTokens: pos(usage['cache_creation_input_tokens']),
        );
    }
    if (parsed.inputTokens == null &&
        parsed.cacheHitTokens == null &&
        parsed.cacheMissTokens == null) {
      return null;
    }
    return parsed;
  }
}
