import 'package:PiliPlus/features/shielding/shielding_models.dart';

/// Matches [ShieldCandidate]s against a [ShieldRuleSet].
///
/// The recommendation surfaces call this once per candidate per page pass, so
/// the work scales with `candidates * rules`. The matcher therefore keeps every
/// derived value on the side instead of rebuilding it per evaluation:
///
/// * [_CompiledRule] caches the lower-cased pattern, the blank-pattern check,
///   the normalised enum pattern, the compiled [RegExp] and the parsed
///   [_ParsedRange] of a [ShieldRule] (failures included, and rethrown so a
///   broken rule keeps reporting exactly one error per evaluation).
/// * [_ScopedRules] caches the enabled + scope-filtered rule list per
///   [ShieldRuleSet] instance and [ShieldScope].
/// * [_MatchContext] caches the candidate values, their lower-cased and
///   enum-normalised forms and their token splits for the duration of a single
///   [match] call.
///
/// Both instance caches are [Expando]s keyed by object identity, and the models
/// are deeply immutable ([ShieldRuleSet.rules] is unmodifiable, every field of
/// [ShieldRule] and [ShieldRuleSet] is `final`), so a cached entry can never
/// describe stale data: replacing a rule or a rule set simply misses once.
abstract final class ShieldMatcher {
  /// Rule-side artefacts, keyed by [ShieldRule] identity.
  static final Expando<_CompiledRule> _compiledRules = Expando<_CompiledRule>(
    'ShieldMatcher._compiledRules',
  );

  /// Scope-filtered rule lists, keyed by [ShieldRuleSet] identity.
  static final Expando<_ScopedRules> _scopedRules = Expando<_ScopedRules>(
    'ShieldMatcher._scopedRules',
  );

  static ShieldMatchResult match(
    ShieldCandidate candidate,
    ShieldRuleSet ruleSet,
  ) {
    if (!ruleSet.isScopeEnabled(candidate.scope)) {
      return ShieldMatchResult.visibleResult;
    }

    final rules = _scopedRulesOf(ruleSet).forScope(candidate.scope);
    if (rules.isEmpty) {
      // No applicable rule can match, and no applicable rule can raise.
      return ShieldMatchResult.visibleResult;
    }

    final context = _MatchContext(candidate);
    final errors = <ShieldMatchError>[];
    ShieldRule? allowedBy;
    ShieldRule? blockedBy;

    for (final rule in rules) {
      bool matched;
      try {
        matched = _matches(rule, context);
      } catch (e) {
        errors.add(ShieldMatchError(rule: rule, message: e.toString()));
        continue;
      }
      if (!matched) continue;

      if (rule.action == ShieldAction.allow) {
        allowedBy ??= rule;
      } else {
        blockedBy ??= rule;
      }
    }

    if (allowedBy != null) {
      return ShieldMatchResult(
        visible: true,
        allowedBy: allowedBy,
        blockedBy: blockedBy,
        errors: errors,
      );
    }

    return ShieldMatchResult(
      visible: blockedBy == null,
      blockedBy: blockedBy,
      errors: errors,
    );
  }

  static _ScopedRules _scopedRulesOf(ShieldRuleSet ruleSet) =>
      _scopedRules[ruleSet] ??= _ScopedRules(ruleSet);

  static _CompiledRule _compiledRule(ShieldRule rule) =>
      _compiledRules[rule] ??= _CompiledRule(rule);

  static bool _scopeMatches(
    ShieldScope ruleScope,
    ShieldScope candidateScope,
  ) =>
      ruleScope == candidateScope ||
      (ruleScope == ShieldScope.both &&
          (candidateScope == ShieldScope.recommendation ||
              candidateScope == ShieldScope.comment));

  static bool _matches(ShieldRule rule, _MatchContext context) {
    final compiled = _compiledRule(rule);
    if (compiled.patternIsBlank) return false;

    switch (compiled.matchMode) {
      case ShieldMatchMode.exact:
        return context
            .valuesFor(compiled.type)
            .any((value) => context.lower(value) == compiled.pattern);

      case ShieldMatchMode.contains:
        return context
            .valuesFor(compiled.type)
            .any((value) => context.lower(value).contains(compiled.pattern));

      case ShieldMatchMode.regex:
        // Resolved before `any` runs, exactly like the uncached form, so an
        // invalid pattern still reports an error for candidates without values.
        final regex = compiled.regex;
        return context.valuesFor(compiled.type).any(regex.hasMatch);

      case ShieldMatchMode.range:
        // Parsed before `any` runs, for the same reason as the regex branch.
        final rangeMatcher = compiled.rangeMatcher;
        return _matchNumbers(compiled.type, context.candidate).any(rangeMatcher);

      case ShieldMatchMode.enumValue:
        return context
            .valuesFor(compiled.type)
            .any(
              (value) =>
                  context.normalizeEnum(value) == compiled.normalizedPattern,
            );

      case ShieldMatchMode.token:
        return context
            .tokenValuesFor(compiled.type)
            .any((token) => context.lower(token) == compiled.pattern);
    }
  }

  static List<String> _rawValues(
    ShieldRuleType type,
    ShieldCandidate candidate,
  ) => switch (type) {
    ShieldRuleType.keyword => [
      ifNullEmpty(candidate.title),
      ifNullEmpty(candidate.body),
    ],
    ShieldRuleType.userKeyword => [ifNullEmpty(candidate.authorName)],
    ShieldRuleType.reasonKeyword => [ifNullEmpty(candidate.reason)],
    ShieldRuleType.uid => [ifNullEmpty(candidate.uid)],
    ShieldRuleType.category => [ifNullEmpty(candidate.category)],
    ShieldRuleType.tag => candidate.tags,
    ShieldRuleType.avatarPendant => candidate.avatarPendantValues,
    ShieldRuleType.garb => candidate.garbValues,
    ShieldRuleType.commentMemberSex => [ifNullEmpty(candidate.commentMemberSex)],
    ShieldRuleType.descriptionKeyword => [ifNullEmpty(candidate.description)],
    ShieldRuleType.isUpowerExclusive => [
      candidate.isUpowerExclusive == true
          ? 'true'
          : (candidate.isUpowerExclusive == false ? 'false' : ''),
    ],
    ShieldRuleType.staffKeyword => candidate.staffNames,
    ShieldRuleType.duration ||
    ShieldRuleType.playbackCount ||
    ShieldRuleType.danmakuCount ||
    ShieldRuleType.commentMemberLevel ||
    ShieldRuleType.publishTime => const [],
  };

  static Iterable<num> _matchNumbers(
    ShieldRuleType type,
    ShieldCandidate candidate,
  ) sync* {
    final value = switch (type) {
      ShieldRuleType.duration => candidate.durationSeconds,
      ShieldRuleType.playbackCount => candidate.playbackCount,
      ShieldRuleType.danmakuCount => candidate.danmakuCount,
      ShieldRuleType.commentMemberLevel => candidate.commentMemberLevel,
      ShieldRuleType.publishTime => candidate.pubdate,
      _ => null,
    };
    if (value != null) yield value;
  }

  static final RegExp _enumSeparators = RegExp(r'[\s_\-]+');

  static final RegExp _tokenSeparators = RegExp(r'[\s,，。！？!?:：;；_\-]+');

  static String _normalizeEnumValue(String value) =>
      value.trim().toLowerCase().replaceAll(_enumSeparators, '');
}

String ifNullEmpty(String? value) => value ?? '';

/// Candidate-side memoisation for a single [ShieldMatcher.match] call.
class _MatchContext {
  _MatchContext(this.candidate);

  final ShieldCandidate candidate;

  final Map<ShieldRuleType, List<String>> _rawValues = {};
  final Map<ShieldRuleType, List<String>> _matchValues = {};
  final Map<ShieldRuleType, List<String>> _tokenValues = {};
  final Map<String, String> _lowerCased = {};
  final Map<String, String> _enumNormalized = {};
  final Map<String, List<String>> _tokens = {};

  /// Candidate values backing [type], non-blank entries only.
  List<String> valuesFor(ShieldRuleType type) =>
      _matchValues[type] ??= rawValuesFor(
        type,
      ).where((value) => value.trim().isNotEmpty).toList();

  /// Candidate values backing [type], blanks included.
  List<String> rawValuesFor(ShieldRuleType type) =>
      _rawValues[type] ??= ShieldMatcher._rawValues(type, candidate);

  /// Values consumed by [ShieldMatchMode.token] rules of [type].
  List<String> tokenValuesFor(ShieldRuleType type) =>
      _tokenValues[type] ??= _buildTokenValues(type);

  String lower(String value) => _lowerCased[value] ??= value.toLowerCase();

  String normalizeEnum(String value) =>
      _enumNormalized[value] ??= ShieldMatcher._normalizeEnumValue(value);

  /// Tokens of [value], split by the matcher token separators.
  List<String> tokensOf(String value) => _tokens[value] ??= value
      .split(ShieldMatcher._tokenSeparators)
      .where((token) => token.trim().isNotEmpty)
      .toList();

  List<String> splitAll(Iterable<String?> values) => [
    for (final value in values)
      if (value != null) ...tokensOf(value),
  ];

  List<String> _buildTokenValues(ShieldRuleType type) {
    switch (type) {
      case ShieldRuleType.userKeyword:
        return [
          ..._authorTokens(),
          ...splitAll([candidate.authorName]),
        ];
      case ShieldRuleType.reasonKeyword:
        return splitAll([candidate.reason]);
      default:
        final tokens = candidate.tokens;
        if (tokens.isNotEmpty) return tokens;
        // An empty provider result falls back to splitting the raw values, the
        // same way an empty eager list does.
        final provided = candidate.tokensProvider?.call().toList();
        if (provided != null && provided.isNotEmpty) return provided;
        return splitAll(rawValuesFor(type));
    }
  }

  List<String> _authorTokens() {
    final tokens = candidate.authorTokens;
    if (tokens.isNotEmpty) return tokens;
    return candidate.authorTokensProvider?.call().toList() ?? const [];
  }
}

/// Rule artefacts that only depend on the (immutable) [ShieldRule] itself.
class _CompiledRule {
  _CompiledRule(ShieldRule rule)
    : pattern = rule.pattern.toLowerCase(),
      patternIsBlank = rule.pattern.trim().isEmpty,
      normalizedPattern = ShieldMatcher._normalizeEnumValue(rule.pattern),
      matchMode = rule.matchMode,
      type = rule.type,
      _patternSource = rule.pattern;

  final String pattern;
  final bool patternIsBlank;
  final String normalizedPattern;
  final ShieldMatchMode matchMode;
  final ShieldRuleType type;

  /// The original pattern, still needed by [RegExp] and [_ParsedRange].
  final String _patternSource;

  RegExp? _regex;
  Object? _regexFailure;

  /// Case-insensitive [RegExp] for [ShieldMatchMode.regex]; a broken pattern
  /// caches its failure and rethrows it on every later use.
  RegExp get regex {
    final cached = _regex;
    if (cached != null) return cached;
    final failure = _regexFailure;
    if (failure != null) throw failure;
    try {
      return _regex = RegExp(_patternSource, caseSensitive: false);
    } catch (error) {
      _regexFailure = error;
      rethrow;
    }
  }

  bool Function(num)? _rangeMatcher;
  Object? _rangeFailure;

  /// Parsed range predicate for [ShieldMatchMode.range]; a broken pattern
  /// caches its failure and rethrows it on every later use.
  bool Function(num) get rangeMatcher {
    final cached = _rangeMatcher;
    if (cached != null) return cached;
    final failure = _rangeFailure;
    if (failure != null) throw failure;
    try {
      return _rangeMatcher = _ParsedRange.parse(_patternSource).matches;
    } catch (error) {
      _rangeFailure = error;
      rethrow;
    }
  }
}

/// Enabled, scope-compatible rules of one [ShieldRuleSet].
class _ScopedRules {
  _ScopedRules(this._ruleSet);

  final ShieldRuleSet _ruleSet;
  final Map<ShieldScope, List<ShieldRule>> _byScope = {};

  List<ShieldRule> forScope(ShieldScope scope) => _byScope[scope] ??= [
    for (final rule in _ruleSet.rules)
      if (rule.enabled && ShieldMatcher._scopeMatches(rule.scope, scope)) rule,
  ];
}

class _ParsedRange {
  const _ParsedRange({this.min, this.max});

  final num? min;
  final num? max;

  static final RegExp _pattern = RegExp(
    r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*\.\.\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*$',
  );

  static _ParsedRange parse(String pattern) {
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Range pattern is empty');
    }

    final match = _pattern.firstMatch(trimmed);
    if (match != null) {
      final min = _parseBound(match.group(1));
      final max = _parseBound(match.group(2));
      return _validate(_ParsedRange(min: min, max: max));
    }

    final exact = num.tryParse(trimmed);
    if (exact != null) {
      return _ParsedRange(min: exact, max: exact);
    }

    throw FormatException('Invalid range pattern: $pattern');
  }

  bool matches(num value) {
    final lower = min;
    if (lower != null && value < lower) return false;
    final upper = max;
    if (upper != null && value > upper) return false;
    return true;
  }

  static num? _parseBound(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return num.tryParse(trimmed);
  }

  static _ParsedRange _validate(_ParsedRange range) {
    if (range.min == null && range.max == null) {
      throw const FormatException('Range requires at least one bound');
    }
    if (range.min != null && range.max != null && range.min! > range.max!) {
      throw const FormatException('Range min is greater than max');
    }
    return range;
  }
}
