export 'package:PiliPlus/features/jev/jev_rules.dart'
    show LlmVideoRule, LlmVideoRuleConfig, LlmVideoRuleStore;

import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_rules.dart';

/// FNV-1a over the UTF-8 bytes of the canonical JSON.
///
/// ponytail: relies on Dart VM 64-bit wraparound; a web build would need a
/// table-driven variant. Versions stay on-device, so VM determinism suffices.
String ruleVersion(String canonicalJson) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(canonicalJson)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  // 64-bit two's complement hex: a bare toRadixString(16) prints a
  // negative VM int with a leading '-', which breaks the 16-hex shape.
  return (hash >>> 32).toRadixString(16).padLeft(8, '0') +
      (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}

Map<String, Object?> _videoEntry(LlmVideoRule rule) => {
  'id': rule.id,
  'text': rule.text.trim(),
};

/// rule_version of the ACTIVE video rule set: only what the model actually
/// sees may invalidate cached verdicts. Disabled or invalid rules are
/// invisible to the pipeline and therefore excluded.
String videoRuleVersion(List<LlmVideoRule> activeRules) => ruleVersion(
  jsonEncode([
    for (final r in activeRules)
      if (r.enabled && r.validate() == null) _videoEntry(r),
  ]),
);

/// The shared comment rule set, rendered for the generic line (spec §2:
/// typed 判断规则 remain the single comment config source; the generic line
/// extends on top and never edits them).
///
/// Rendering is deliberately threshold-free: a generic chat model returns a
/// qualitative hit with a reason, not a calibrated probability, so the typed
/// threshold has no faithful translation here.
class LlmCommentRuleView {
  const LlmCommentRuleView({required this.id, required this.criteria});
  final String id;
  final String criteria;

  static List<LlmCommentRuleView> of(List<JevRule> activeCommentRules) => [
    for (final rule in activeCommentRules)
      LlmCommentRuleView(id: rule.id, criteria: _render(rule)),
  ];

  static String _render(JevRule rule) {
    final question = rule.question.trim();
    if (rule.type == JevRuleType.noul) {
      final yes = rule.yesMeaning.trim();
      final no = rule.noMeaning.trim();
      return '问题：$question；回答为 Yes 时隐藏${yes.isEmpty ? '' : '（Yes 含义：$yes）'}${no.isEmpty ? '' : '；回答为 No 时保留（No 含义：$no）'}。';
    }
    final hidden = rule.options
        .where((o) => rule.hiddenOptions.contains(o.id))
        .map((o) => o.label.trim())
        .toList();
    return '问题：$question；当结论属于以下情形时隐藏：${hidden.join('、')}。';
  }

  /// Canonical content of the ACTIVE comment rules as the generic line sees
  /// them — the basis of the shared comment rule_version.
  static String canonicalJson(List<LlmCommentRuleView> views) => jsonEncode([
    for (final v in views) {'id': v.id, 'criteria': v.criteria},
  ]);
}
