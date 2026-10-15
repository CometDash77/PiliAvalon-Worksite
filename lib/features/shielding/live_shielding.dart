import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_list.dart';

/// Which stable identity of a live recommendation card a quick action targets.
enum LiveShieldTarget { host, room }

enum LiveShieldQuickActionOutcome { added, duplicate, failure, unavailable }

class LiveShieldQuickActionResult {
  const LiveShieldQuickActionResult({
    required this.outcome,
    required this.target,
    required this.label,
    required this.message,
    this.pattern,
  });

  final LiveShieldQuickActionOutcome outcome;
  final LiveShieldTarget target;

  /// Human readable identity of the blocked owner, used in toasts.
  final String label;
  final String message;
  final String? pattern;

  /// A duplicate rule still re-filters the loaded page: the user asked for the
  /// card to disappear, and it has to go even when the rule already existed.
  bool get refiltersCurrentPage =>
      outcome == LiveShieldQuickActionOutcome.added ||
      outcome == LiveShieldQuickActionOutcome.duplicate;
}

/// Live recommendation shielding.
///
/// The standalone live recommendation page needs a room identity that host uid
/// or title matching cannot express, so room rules use their own
/// [ShieldRuleType.roomId] type, exact matching and [ShieldScope.live].
/// Every helper here stays inert for non live candidates.
abstract final class LiveShielding {
  static const String failureMessage = '保存屏蔽规则失败，请重试';
  static const String unavailableMessage = '当前卡片缺少可屏蔽的标识';

  /// Accepts either shape the live grid stores: a raw card or the card list
  /// wrapper used by the feed index endpoint.
  static CardLiveItem? cardOf(Object? item) => switch (item) {
    CardLiveItem card => card,
    LiveCardList card => card.cardData?.smallCardV1,
    _ => null,
  };

  static ShieldCandidate? candidateOf(Object? item) {
    final card = cardOf(item);
    return card == null ? null : candidateFor(card);
  }

  static ShieldCandidate candidateFor(CardLiveItem card) => ShieldCandidate(
    scope: ShieldScope.live,
    title: card.title,
    uid: _positiveId(card.uid),
    authorName: card.uname,
    category: card.areaName,
    roomId: _positiveId(card.roomid),
  );

  /// Targets the card actually offers; a missing identity is not offered
  /// instead of being silently mapped onto another field.
  static List<LiveShieldTarget> targetsFor(CardLiveItem card) => [
    for (final target in LiveShieldTarget.values)
      if (patternFor(card, target) != null) target,
  ];

  static ShieldRuleType typeFor(LiveShieldTarget target) => switch (target) {
    LiveShieldTarget.host => ShieldRuleType.uid,
    LiveShieldTarget.room => ShieldRuleType.roomId,
  };

  static String? patternFor(CardLiveItem card, LiveShieldTarget target) =>
      switch (target) {
        LiveShieldTarget.host => _positiveId(card.uid),
        LiveShieldTarget.room => _positiveId(card.roomid),
      };

  static String targetLabel(LiveShieldTarget target) => switch (target) {
    LiveShieldTarget.host => '主播',
    LiveShieldTarget.room => '直播间',
  };

  static String? displayNameFor(CardLiveItem card, LiveShieldTarget target) {
    final name = switch (target) {
      LiveShieldTarget.host => card.uname,
      LiveShieldTarget.room => card.title,
    };
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String labelFor(CardLiveItem card, LiveShieldTarget target) {
    final name = displayNameFor(card, target);
    if (name != null) return name;
    final prefix = targetLabel(target);
    final pattern = patternFor(card, target);
    return pattern == null ? prefix : '$prefix $pattern';
  }

  /// Removes every card blocked by the live rules, in place, so the survivors
  /// keep the order the source page returned. Returns how many were removed.
  static int removeBlocked<T>(List<T> items, ShieldRuleSet ruleSet) {
    if (items.isEmpty) return 0;
    if (!ruleSet.globalEnabled) return 0;
    if (!ruleSet.isScopeEnabled(ShieldScope.live)) return 0;
    final before = items.length;
    items.removeWhere((item) {
      final candidate = candidateOf(item);
      return candidate != null &&
          !ShieldMatcher.match(candidate, ruleSet).visible;
    });
    return before - items.length;
  }

  /// Saves the quick rule for [target] and reports what the caller must do.
  /// The rule is written directly: no confirmation step, and a duplicate still
  /// re-filters the current page because the card has to disappear anyway.
  static Future<LiveShieldQuickActionResult> applyQuickAction({
    required CardLiveItem card,
    required LiveShieldTarget target,
    ShieldSettingsStore? store,
  }) async {
    final pattern = patternFor(card, target);
    final label = labelFor(card, target);
    if (pattern == null) {
      return LiveShieldQuickActionResult(
        outcome: LiveShieldQuickActionOutcome.unavailable,
        target: target,
        label: label,
        message: unavailableMessage,
      );
    }
    final effectiveStore = store ?? ShieldSettingsStore();
    try {
      final rule = await effectiveStore.addQuickActionRule(
        type: typeFor(target),
        scope: ShieldScope.live,
        pattern: pattern,
        matchMode: ShieldMatchMode.exact,
      );
      if (rule == null) {
        return LiveShieldQuickActionResult(
          outcome: LiveShieldQuickActionOutcome.duplicate,
          target: target,
          label: label,
          pattern: pattern,
          message: '规则已存在：$label',
        );
      }
      final targetName = targetLabel(target);
      return LiveShieldQuickActionResult(
        outcome: LiveShieldQuickActionOutcome.added,
        target: target,
        label: label,
        pattern: pattern,
        message: '已屏蔽$targetName：$label',
      );
    } catch (_) {
      return LiveShieldQuickActionResult(
        outcome: LiveShieldQuickActionOutcome.failure,
        target: target,
        label: label,
        pattern: pattern,
        message: failureMessage,
      );
    }
  }

  static String? _positiveId(int? id) =>
      id == null || id <= 0 ? null : id.toString();
}
