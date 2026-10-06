/// What an API key's shape is allowed to tell the product (issue #31/#38).
///
/// A prefix is a hint for the person typing, never a routing decision: no format
/// identifies a provider reliably, so the provider stays an explicit choice and
/// every credential is validated against that choice alone.
enum JevKeyHint {
  /// Nothing typed yet.
  empty,

  /// Looks like an OpenRouter key; the user still has to confirm OpenRouter.
  openRouterSuggested,

  /// Shape carries no usable signal; the user picks the provider manually.
  unrecognized,
}

abstract final class JevKeyFormat {
  /// The only prefix the product is allowed to comment on.
  static const String openRouterPrefix = 'sk-or-v1-';

  static JevKeyHint hintFor(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) return JevKeyHint.empty;
    if (key.startsWith(openRouterPrefix)) return JevKeyHint.openRouterSuggested;
    return JevKeyHint.unrecognized;
  }
}
