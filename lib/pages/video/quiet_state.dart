int quietControlsEffectiveTabIndex({
  required int currentIndex,
  required int previousLength,
  required int nextLength,
  required bool previousHadReply,
  required bool nextHasReply,
  required bool showIntro,
}) {
  if (nextLength <= 0) {
    return 0;
  }
  if (previousHadReply && !nextHasReply) {
    final replyIndex = showIntro ? 1 : 0;
    if (currentIndex == replyIndex) {
      return (replyIndex - 1).clamp(0, nextLength - 1);
    }
    if (currentIndex > replyIndex) {
      return (currentIndex - 1).clamp(0, nextLength - 1);
    }
  }
  if (!previousHadReply && nextHasReply) {
    final replyIndex = showIntro ? 1 : 0;
    if (currentIndex >= replyIndex && currentIndex < previousLength) {
      return (currentIndex + 1).clamp(0, nextLength - 1);
    }
  }
  return currentIndex.clamp(0, nextLength - 1);
}

/// Per-page temporary quiet gate: global show AND temporary hide.
///
/// Used by UI controls that toggle per-page hide state without affecting
/// persistent channel rules.
bool effectiveShowTemporaryContent({
  required bool globalShow,
  required bool temporaryHide,
}) => globalShow && !temporaryHide;

/// Four-level effective visibility: global gate, persistent channel rule,
/// per-page temporary hide, and Zen mode (spec #42 R22).
///
/// Global off is a hard gate that cannot be overridden by persistent,
/// temporary or Zen controls. Zen is a *separate* AND-term layered on top of
/// the user's own gates — turning Zen OFF hands control straight back to
/// whatever `globalShow` / `persistentRuleHide` / `temporaryHide` said before,
/// because Zen never writes any of them.
bool effectiveShowContent({
  required bool globalShow,
  required bool persistentRuleHide,
  required bool temporaryHide,
  required bool zenMode,
}) => globalShow && !persistentRuleHide && !temporaryHide && !zenMode;
