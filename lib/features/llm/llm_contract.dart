// Generic LLM line contract (issue #127 spec section 1, verified in
// .scratch/research/issue114-llm-dual-protocol.md).
//
// The generic line talks to user-configured OpenAI-compatible or
// Anthropic-compatible services. The production semantic for Anthropic is the
// native /v1/messages protocol, not the vendor's OpenAI compatibility layer
// (response_format is ignored there and choices is always 1).
enum LlmProtocol {
  openAICompatible(id: 'openai_compatible', label: 'OpenAI Compatible'),
  anthropicCompatible(
    id: 'anthropic_compatible',
    label: 'Anthropic Compatible',
  );

  const LlmProtocol({required this.id, required this.label});

  // Stable id persisted in settings.
  final String id;

  // User-facing protocol name.
  final String label;

  static LlmProtocol? tryFromId(String? id) {
    for (final protocol in values) {
      if (protocol.id == id) return protocol;
    }
    return null;
  }

  // Path appended to the user's base URL for one chat call.
  //
  // Base URL semantics follow the verified contracts: OpenAI-compatible
  // {base}/chat/completions, Anthropic {base}/v1/messages - the /v1 segment
  // belongs to the Anthropic path, never to the stored base URL.
  String get chatPath => switch (this) {
    openAICompatible => '/chat/completions',
    anthropicCompatible => '/v1/messages',
  };

  // Path appended to the user's base URL for the model catalog.
  String get catalogPath => switch (this) {
    openAICompatible => '/models',
    anthropicCompatible => '/v1/models',
  };

  // Per-request authentication headers. These never reach a log, a cache
  // entry, or a redirect target (probes and catalogs disable redirects).
  Map<String, String> authHeaders(String apiKey) => switch (this) {
    openAICompatible => {'authorization': 'Bearer $apiKey'},
    anthropicCompatible => {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
  };
}

// Conservative limits of the generic line.
abstract final class LlmLimits {
  // Shared per-page screening budget (issue #113): the generic line fits in
  // the same 8s window as Jev; how the two lines split it is pipeline
  // orchestration (spec section 3), not a protocol concern.
  static const Duration requestTimeout = Duration(seconds: 8);

  // Catalog safety cap: Anthropic paginates via has_more; the loop stops here
  // even when a service keeps reporting more pages.
  static const int maxCatalogModels = 1000;

  // Probe and upstream summaries never exceed this many runes (spec 1).
  static const int maxDetailRunes = 200;
}
