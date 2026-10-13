import 'package:flutter/foundation.dart' show immutable;

import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';

/// A generic-line natural-language hide rule for the video surface.
///
/// 命中即屏蔽：unlike Jev typed rules there is no threshold — the model
/// decides and must return the rule id plus a short reason.
@immutable
class LlmVideoRule {
  const LlmVideoRule({
    required this.id,
    required this.text,
    this.enabled = true,
  });

  static const maxRulesPerSurface = 20;
  static const maxTextRunes = 4000;

  final String id;
  final String text;
  final bool enabled;

  String? validate() {
    if (id.trim().isEmpty) return '规则标识不能为空';
    final runes = text.trim().runes.length;
    if (runes < 1 || runes > maxTextRunes) {
      return '规则内容需要 1-$maxTextRunes 个字符';
    }
    return null;
  }

  LlmVideoRule copyWith({String? text, bool? enabled}) => LlmVideoRule(
    id: id,
    text: text ?? this.text,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'enabled': enabled,
  };

  factory LlmVideoRule.fromJson(Map json) => LlmVideoRule(
    id: json['id'] as String,
    text: json['text'] as String,
    enabled: json['enabled'] == true,
  );
}

/// Enabled-and-valid video rules, capped per surface (spec §2).
@immutable
class LlmVideoRuleConfig {
  const LlmVideoRuleConfig({this.rules = const []});
  final List<LlmVideoRule> rules;

  List<LlmVideoRule> activeFor() => rules
      .where((r) => r.enabled && r.validate() == null)
      .take(LlmVideoRule.maxRulesPerSurface)
      .toList();
}

/// A single non-secret blob keeps generic-line video rule edits atomic.
class LlmVideoRuleStore {
  LlmVideoRuleStore({JevSettingsBox? box}) : _boxOrNull = box;

  // 构造期不触碰 JevSettingsStore/GStorage（#130）：解析推迟到首次读写。
  final JevSettingsBox? _boxOrNull;
  JevSettingsBox? _lazyBox;
  JevSettingsStore? _store;
  JevSettingsBox get _box =>
      _lazyBox ??= _boxOrNull ?? (_store ??= JevSettingsStore()).box;
  static const key = 'piliavalon.llm.v1.video_rules.v1';

  Future<LlmVideoRuleConfig> load() async {
    final raw = _box.get(key);
    if (raw == null) return const LlmVideoRuleConfig();
    try {
      final json = jsonDecode(raw as String) as Map;
      if (json['version'] != 1) {
        throw const FormatException('Unknown rule version');
      }
      final rules = <LlmVideoRule>[];
      final ids = <String>{};
      for (final entry in json['rules'] as List) {
        try {
          final rule = LlmVideoRule.fromJson(entry as Map);
          if (rule.validate() == null &&
              ids.add(rule.id) &&
              rules.length < LlmVideoRule.maxRulesPerSurface) {
            rules.add(rule);
          }
        } catch (_) {
          /* 无效单条规则不能隐藏内容。 */
        }
      }
      return LlmVideoRuleConfig(rules: List.unmodifiable(rules));
    } catch (_) {
      // 损坏配置按空配置处理：宁可漏屏蔽，不可错屏蔽。
      return const LlmVideoRuleConfig();
    }
  }

  Future<void> save(LlmVideoRuleConfig config) async {
    final ids = <String>{};
    for (final rule in config.rules) {
      final error = rule.validate();
      if (error != null || !ids.add(rule.id)) {
        throw ArgumentError(error ?? '规则标识重复');
      }
    }
    if (config.rules.length > LlmVideoRule.maxRulesPerSurface) {
      throw ArgumentError(
        '视频规则最多 ${LlmVideoRule.maxRulesPerSurface} 条',
      );
    }
    await _box.put(
      key,
      jsonEncode({
        'version': 1,
        'rules': config.rules.map((r) => r.toJson()).toList(),
      }),
    );
  }
}

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
@immutable
class LlmCommentRuleView {
  const LlmCommentRuleView({required this.id, required this.criteria});
  final String id;
  final String criteria;

  static List<LlmCommentRuleView> of(List<JevRule> activeCommentRules) => [
    for (final rule in activeCommentRules)
      LlmCommentRuleView(
        id: rule.id,
        criteria: _render(rule),
      ),
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
