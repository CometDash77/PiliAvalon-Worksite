import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;

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

/// 命中之后的动作（issue #115）：hide 是既有语义（命中即隐藏）；
/// keep 只对直播开放——存在保留规则时，标题至少要命中一条保留规则
/// 才会展示。旧记录没有该字段，默认 hide，行为不变。
enum JevRuleAction { hide, keep }

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
    this.action = JevRuleAction.hide,
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

  /// 命中后的动作；keep 仅直播可用（issue #115）。
  final JevRuleAction action;
  final bool enabled;
  final double threshold;
  final bool hideOnYes;
  final String yesMeaning;
  final String noMeaning;
  final List<JevRuleOption> options;
  final Set<String> hiddenOptions;

  String? validate() {
    if (id.trim().isEmpty) return '规则标识不能为空';
    if (action == JevRuleAction.keep && target != JevRuleTarget.live) {
      return '目前仅直播规则支持保留动作';
    }
    if (question.trim().isEmpty || question.length > JevLimits.maxQuestionChars) {
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
    JevRuleAction? action,
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
    action: action ?? this.action,
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
    'action': action.name,
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
    action: json['action'] is String
        ? (JevRuleAction.values.any(
              (a) => a.name == json['action'],
            )
            ? JevRuleAction.values.byName(json['action'] as String)
            : JevRuleAction.hide)
        : JevRuleAction.hide,
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
    this.videoTextRules = const [],
  });
  final List<JevRule> rules;
  final Set<JevRuleTarget> disabledBuiltins;

  /// Natural-language video rules migrated from the retired standalone
  /// LlmVideoRuleStore (#141). No threshold: the generic model decides and
  /// must return the rule id plus a reason.
  final List<LlmVideoRule> videoTextRules;
  bool builtinEnabled(JevRuleTarget target) =>
      target != JevRuleTarget.comment && !disabledBuiltins.contains(target);
  List<JevRule> activeFor(JevRuleTarget target) => rules
      .where((r) => r.target == target && r.enabled && r.validate() == null)
      .take(JevRule.maxRulesPerTarget)
      .toList();

  /// Active video-text rules for the generic line — mirrors the retired
  /// LlmVideoRuleConfig.activeFor semantics (enabled, valid, capped).
  List<LlmVideoRule> activeVideoTextRules() => videoTextRules
      .where((r) => r.enabled && r.validate() == null)
      .take(LlmVideoRule.maxRulesPerSurface)
      .toList();

  JevRuleConfig copyWith({
    List<JevRule>? rules,
    Set<JevRuleTarget>? disabledBuiltins,
    List<LlmVideoRule>? videoTextRules,
  }) => JevRuleConfig(
    rules: rules ?? this.rules,
    disabledBuiltins: disabledBuiltins ?? this.disabledBuiltins,
    videoTextRules: videoTextRules ?? this.videoTextRules,
  );
}

/// A generic-line natural-language hide rule for the video surface.
///
/// 命中即屏蔽：unlike Jev typed rules there is no threshold — the model
/// decides and must return the rule id plus a short reason. Lives in the
/// unified rule model since #141 as the video-text rule type; the 4000-rune
/// budget survives migration losslessly (typed questions stay ≤1000).
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

  Map<String, Object?> toJson() => {'id': id, 'text': text, 'enabled': enabled};

  factory LlmVideoRule.fromJson(Map json) => LlmVideoRule(
    id: json['id'] as String,
    text: json['text'] as String,
    enabled: json['enabled'] == true,
  );
}

/// Enabled-and-valid video rules, capped per surface.
@immutable
class LlmVideoRuleConfig {
  const LlmVideoRuleConfig({this.rules = const []});
  final List<LlmVideoRule> rules;

  List<LlmVideoRule> activeFor() => rules
      .where((r) => r.enabled && r.validate() == null)
      .take(LlmVideoRule.maxRulesPerSurface)
      .toList();
}

/// Retired standalone store of the generic video line (#141): no longer a
/// formal rule source — UI and pipeline read/write [JevRuleStore] instead.
/// Kept so the one-shot migration and its tests can parse the legacy blob.
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
      throw ArgumentError('视频规则最多 ${LlmVideoRule.maxRulesPerSurface} 条');
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

/// A single non-secret blob keeps rule edits and builtin switches atomic.
class JevRuleStore {
  JevRuleStore({JevSettingsBox? box}) : _boxOrNull = box;

  // 构造期不触碰 JevSettingsStore/GStorage（#130）：解析推迟到首次读写，
  // 让 LlmCommentScreening 等默认构造在测试环境同样安全。
  final JevSettingsBox? _boxOrNull;
  JevSettingsBox? _lazyBox;
  JevSettingsStore? _store;
  JevSettingsBox get _box =>
      _lazyBox ??= _boxOrNull ?? (_store ??= JevSettingsStore()).box;
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
      final videoText = <LlmVideoRule>[];
      final videoIds = <String>{};
      for (final entry in json['videoTextRules'] as List? ?? const []) {
        try {
          final rule = LlmVideoRule.fromJson(entry as Map);
          if (rule.validate() == null &&
              videoIds.add(rule.id) &&
              videoText.length < LlmVideoRule.maxRulesPerSurface) {
            videoText.add(rule);
          }
        } catch (_) {
          /* Invalid individual rules cannot hide content. */
        }
      }
      return JevRuleConfig(
        rules: List.unmodifiable(rules),
        disabledBuiltins: Set.unmodifiable(disabled),
        videoTextRules: List.unmodifiable(videoText),
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
    final videoIds = <String>{};
    for (final rule in config.videoTextRules) {
      final error = rule.validate();
      if (error != null || !videoIds.add(rule.id)) {
        throw ArgumentError(error ?? '视频规则标识重复');
      }
    }
    if (config.videoTextRules.length > LlmVideoRule.maxRulesPerSurface) {
      throw ArgumentError('视频规则最多 ${LlmVideoRule.maxRulesPerSurface} 条');
    }
    await _box.put(
      key,
      jsonEncode({
        'version': 1,
        'rules': config.rules.map((r) => r.toJson()).toList(),
        'disabledBuiltins': config.disabledBuiltins.map((t) => t.name).toList(),
        'videoTextRules': config.videoTextRules.map((r) => r.toJson()).toList(),
      }),
    );
  }

  Future<void>? _legacyMigration;

  /// One-shot idempotent migration of the retired LlmVideoRuleStore blob
  /// into this unified store (#141). Lossless: id/text/enabled move verbatim
  /// into [JevRuleConfig.videoTextRules]; the legacy key is deleted only
  /// after a successful save. Re-runs are no-ops once the key is gone.
  /// A corrupt legacy blob is ignored (fail-open, key kept for inspection);
  /// a corrupt unified blob blocks the merge so a load() fallback is never
  /// persisted over it. A legacy set exceeding the per-surface cap migrates
  /// nothing and keeps the key: nothing is dropped.
  Future<void> migrateLegacyLlmVideoRules() {
    Future<void> run() async {
      try {
        await _migrateLegacy();
      } catch (_) {
        _legacyMigration = null; // allow a retry at the next entry point.
        rethrow;
      }
    }

    return _legacyMigration ??= run();
  }

  Future<void> _migrateLegacy() async {
    final Object? unifiedRaw;
    try {
      unifiedRaw = _box.get(key);
    } catch (_) {
      return; // box unavailable: leave both sources untouched.
    }
    if (unifiedRaw is String) {
      try {
        jsonDecode(unifiedRaw);
      } catch (_) {
        return; // corrupt unified blob: never persist a fallback over it.
      }
    }
    final String? legacyRaw;
    try {
      legacyRaw = _box.get(LlmVideoRuleStore.key) as String?;
    } catch (_) {
      return;
    }
    if (legacyRaw == null) return; // already migrated (or never existed).
    final List<LlmVideoRule> legacy;
    try {
      final json = jsonDecode(legacyRaw) as Map;
      if (json['version'] != 1) throw const FormatException('bad version');
      legacy = [
        for (final entry in json['rules'] as List)
          LlmVideoRule.fromJson(entry as Map),
      ];
    } catch (_) {
      return; // corrupt legacy blob: fail-open, keep it for inspection.
    }
    final config = await load();
    final merged = <String, LlmVideoRule>{
      // Verbatim lossless upsert; later entries overwrite, so unified-side
      // entries (listed last) win on id collision.
      for (final r in legacy) r.id: r,
      for (final r in config.videoTextRules) r.id: r,
    };
    if (merged.length > LlmVideoRule.maxRulesPerSurface) {
      return; // keep the legacy key: nothing is dropped, nothing persisted.
    }
    await save(config.copyWith(videoTextRules: merged.values.toList()));
    await _box.delete(LlmVideoRuleStore.key);
  }
}
