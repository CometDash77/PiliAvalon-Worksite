import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';

enum JevRuleTarget {
  video('视频'),
  comment('评论'),
  live('直播');

  const JevRuleTarget(this.label);
  final String label;

  static JevRuleTarget forSurface(JevSurface surface) => switch (surface) {
    JevSurface.comment => comment,
    JevSurface.live => live,
    _ => video,
  };
}

enum JevRuleType { noul, choice }

class JevRuleOption {
  const JevRuleOption({
    required this.id,
    required this.label,
    this.description = '',
  });
  final String id;
  final String label;
  final String description;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'description': description,
  };
}

/// Natural-language fields are compiled locally; no second model rewrites them.
class JevRule {
  const JevRule({
    required this.id,
    required this.target,
    required this.question,
    this.type = JevRuleType.noul,
    this.enabled = true,
    this.threshold = .95,
    this.hideOnYes = true,
    this.yesMeaning = '',
    this.noMeaning = '',
    this.options = const [],
    this.hiddenOptions = const {},
  });

  static const maxRulesPerTarget = 20;
  static const maxOptions = 20;
  final String id;
  final JevRuleTarget target;
  final String question;
  final JevRuleType type;
  final bool enabled;
  final double threshold;
  final bool hideOnYes;
  final String yesMeaning;
  final String noMeaning;
  final List<JevRuleOption> options;
  final Set<String> hiddenOptions;

  String? validate() {
    if (id.trim().isEmpty) return '规则标识不能为空';
    if (question.trim().isEmpty || question.length > 1000) {
      return '问题需要 1–1000 个字符';
    }
    if (!threshold.isFinite || threshold < .5 || threshold > 1) {
      return '执行阈值需要在 50%–100% 之间';
    }
    if (yesMeaning.length > 400 || noMeaning.length > 400) {
      return '答案含义最多 400 个字符';
    }
    if (type == JevRuleType.choice) {
      if (options.length < 2 || options.length > maxOptions) {
        return '选择题需要 2–20 个选项';
      }
      final ids = <String>{};
      final labels = <String>{};
      for (final option in options) {
        if (option.id.isEmpty || !ids.add(option.id)) return '选项标识不能重复或为空';
        if (option.label.trim().isEmpty ||
            option.label.length > 80 ||
            !labels.add(option.label.trim())) {
          return '选项名称需要 1–80 个字符且不能重复';
        }
        if (option.description.length > 400) return '选项说明最多 400 个字符';
      }
      if (hiddenOptions.isEmpty || !ids.containsAll(hiddenOptions)) {
        return '请选择有效的隐藏选项';
      }
    }
    return null;
  }

  JevRule copyWith({
    String? question,
    JevRuleType? type,
    bool? enabled,
    double? threshold,
    bool? hideOnYes,
    String? yesMeaning,
    String? noMeaning,
    List<JevRuleOption>? options,
    Set<String>? hiddenOptions,
  }) => JevRule(
    id: id,
    target: target,
    question: question ?? this.question,
    type: type ?? this.type,
    enabled: enabled ?? this.enabled,
    threshold: threshold ?? this.threshold,
    hideOnYes: hideOnYes ?? this.hideOnYes,
    yesMeaning: yesMeaning ?? this.yesMeaning,
    noMeaning: noMeaning ?? this.noMeaning,
    options: options ?? this.options,
    hiddenOptions: hiddenOptions ?? this.hiddenOptions,
  );

  Map<String, Object?> compile(String candidateKey) => {
    'type': type.name,
    'instructions':
        '只评估 `state.candidates.$candidateKey`。以下是用户的问题：${question.trim()}。只使用提供的内容，不推断缺失信息。',
    'criteria': type == JevRuleType.noul
        ? {
            'true': yesMeaning.trim().isEmpty
                ? '问题的回答为 Yes。'
                : yesMeaning.trim(),
            'false': noMeaning.trim().isEmpty ? '问题的回答为 No。' : noMeaning.trim(),
          }
        : {
            for (final option in options)
              option.id:
                  '${option.label.trim()}${option.description.trim().isEmpty ? '' : '：${option.description.trim()}'}',
          },
  };

  /// Only a well-typed, finite answer can trigger an action.
  bool hides(Object? answer) {
    if (!enabled ||
        validate() != null ||
        answer is! Map ||
        answer['type'] != type.name) {
      return false;
    }
    if (type == JevRuleType.noul) {
      final p = _probability(answer['noul']);
      return p != null && (hideOnYes ? p : 1 - p) >= threshold;
    }
    final choice = answer['choice'];
    final confidence = _probability(answer['confidence']);
    final probabilities = answer['probabilities'];
    if (choice is! String ||
        confidence == null ||
        probabilities is! Map ||
        probabilities.length != options.length ||
        !options.every((o) => _probability(probabilities[o.id]) != null)) {
      return false;
    }
    final sum = probabilities.values.fold<double>(
      0,
      (sum, p) => sum + (p as num).toDouble(),
    );
    if ((sum - 1).abs() > .001) return false;
    final chosen = _probability(probabilities[choice]);
    if (chosen == null || probabilities.values.any((p) => (p as num) > chosen)) {
      return false;
    }
    return hiddenOptions.contains(choice) && confidence >= threshold;
  }

  static double? _probability(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 1
      ? value.toDouble()
      : null;

  Map<String, Object?> toJson() => {
    'id': id,
    'target': target.name,
    'question': question,
    'type': type.name,
    'enabled': enabled,
    'threshold': threshold,
    'hideOnYes': hideOnYes,
    'yesMeaning': yesMeaning,
    'noMeaning': noMeaning,
    'options': options.map((o) => o.toJson()).toList(),
    'hiddenOptions': hiddenOptions.toList(),
  };

  factory JevRule.fromJson(Map json) => JevRule(
    id: json['id'] as String,
    target: JevRuleTarget.values.byName(json['target'] as String),
    question: json['question'] as String,
    type: JevRuleType.values.byName(json['type'] as String),
    enabled: json['enabled'] == true,
    threshold: (json['threshold'] as num).toDouble(),
    hideOnYes: json['hideOnYes'] == true,
    yesMeaning: json['yesMeaning'] as String? ?? '',
    noMeaning: json['noMeaning'] as String? ?? '',
    options: (json['options'] as List)
        .map(
          (o) => JevRuleOption(
            id: o['id'] as String,
            label: o['label'] as String,
            description: o['description'] as String? ?? '',
          ),
        )
        .toList(),
    hiddenOptions: (json['hiddenOptions'] as List).cast<String>().toSet(),
  );
}

class JevRuleConfig {
  const JevRuleConfig({
    this.rules = const [],
    this.disabledBuiltins = const {},
  });
  final List<JevRule> rules;
  final Set<JevRuleTarget> disabledBuiltins;
  bool builtinEnabled(JevRuleTarget target) =>
      target != JevRuleTarget.comment && !disabledBuiltins.contains(target);
  List<JevRule> activeFor(JevRuleTarget target) => rules
      .where((r) => r.target == target && r.enabled && r.validate() == null)
      .take(JevRule.maxRulesPerTarget)
      .toList();
}

/// A single non-secret blob keeps rule edits and builtin switches atomic.
class JevRuleStore {
  JevRuleStore({JevSettingsBox? box}) : _box = box ?? JevSettingsStore().box;
  final JevSettingsBox _box;
  static const key = '${JevSettingsStore.namespace}.rules.v1';
  Future<JevRuleConfig> load() async {
    final raw = _box.get(key);
    if (raw == null) {
      return const JevRuleConfig(); // Existing users retain the builtin.
    }
    try {
      final json = jsonDecode(raw as String) as Map;
      if (json['version'] != 1) {
        throw const FormatException('Unknown rule version');
      }
      final rules = <JevRule>[];
      final ids = <String>{};
      for (final entry in json['rules'] as List) {
        try {
          final rule = JevRule.fromJson(entry as Map);
          if (rule.validate() == null &&
              ids.add(rule.id) &&
              rules.where((r) => r.target == rule.target).length <
                  JevRule.maxRulesPerTarget) {
            rules.add(rule);
          }
        } catch (_) {
          /* Invalid individual rules cannot hide content. */
        }
      }
      final disabled = (json['disabledBuiltins'] as List)
          .map((s) => JevRuleTarget.values.byName(s as String))
          .toSet();
      return JevRuleConfig(
        rules: List.unmodifiable(rules),
        disabledBuiltins: Set.unmodifiable(disabled),
      );
    } catch (_) {
      // Corruption must not silently re-enable a previously disabled builtin.
      return JevRuleConfig(disabledBuiltins: JevRuleTarget.values.toSet());
    }
  }

  Future<void> save(JevRuleConfig config) async {
    final ids = <String>{};
    for (final rule in config.rules) {
      final error = rule.validate();
      if (error != null || !ids.add(rule.id)) {
        throw ArgumentError(error ?? '规则标识重复');
      }
    }
    for (final target in JevRuleTarget.values) {
      if (config.rules.where((r) => r.target == target).length >
          JevRule.maxRulesPerTarget) {
        throw ArgumentError('每个场景最多 20 条规则');
      }
    }
    await _box.put(
      key,
      jsonEncode({
        'version': 1,
        'rules': config.rules.map((r) => r.toJson()).toList(),
        'disabledBuiltins': config.disabledBuiltins.map((t) => t.name).toList(),
      }),
    );
  }
}
