import 'package:PiliPlus/features/shielding/shielding_models.dart';

abstract final class ShieldMatcher {
  static final _compiledRules = Expando<_CompiledShieldRule>(
    'ShieldMatcher compiled rule',
  );
  static final _scopedRules = Expando<Map<ShieldScope, List<ShieldRule>>>(
    'ShieldMatcher scoped rules',
  );

  static ShieldMatchResult match(
    ShieldCandidate candidate,
    ShieldRuleSet ruleSet,
  ) {
    if (!ruleSet.isScopeEnabled(candidate.scope)) {
      return ShieldMatchResult.visibleResult;
    }
    final scopedRules = _scopedRules[ruleSet] ??= {};
    final rules = scopedRules.putIfAbsent(
      candidate.scope,
      () => ruleSet.rules
          .where(
            (rule) =>
                rule.enabled && _scopeMatches(rule.scope, candidate.scope),
          )
          .toList(growable: false),
    );
    if (rules.isEmpty) return ShieldMatchResult.visibleResult;

    final errors = <ShieldMatchError>[];
    final context = _CandidateMatcherContext(candidate);
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

  static bool _scopeMatches(
    ShieldScope ruleScope,
    ShieldScope candidateScope,
  ) =>
      ruleScope == candidateScope ||
      (ruleScope == ShieldScope.both &&
          (candidateScope == ShieldScope.recommendation ||
              candidateScope == ShieldScope.comment));

  static bool _matches(ShieldRule rule, _CandidateMatcherContext context) {
    final compiled = _compiledRules[rule] ??= _CompiledShieldRule(rule);
    if (compiled.patternIsEmpty) return false;
    return switch (rule.matchMode) {
      ShieldMatchMode.exact =>
        context
            .lowerValues(rule.type)
            .any(
              (value) => value == compiled.lowerPattern,
            ),
      ShieldMatchMode.contains =>
        context
            .lowerValues(rule.type)
            .any(
              (value) => value.contains(compiled.lowerPattern),
            ),
      ShieldMatchMode.regex => _matchRegex(compiled, rule, context),
      ShieldMatchMode.range =>
        context
            .numbers(rule)
            .any(
              compiled.range.matches,
            ),
      ShieldMatchMode.enumValue =>
        context
            .enumValues(rule.type)
            .any(
              (value) => value == compiled.normalizedEnumPattern,
            ),
      ShieldMatchMode.token =>
        context
            .tokens(rule)
            .any(
              (token) => token.toLowerCase() == compiled.lowerPattern,
            ),
    };
  }

  // The pre-optimization path constructed the RegExp before iterating the
  // candidate values, so an invalid pattern was reported as a rule error even
  // when the rule had no values to test. Compile eagerly to keep that error
  // surface identical; the compiled instance is still cached per rule.
  static bool _matchRegex(
    _CompiledShieldRule compiled,
    ShieldRule rule,
    _CandidateMatcherContext context,
  ) {
    final regex = compiled.regex;
    return context.rawValues(rule.type).any(regex.hasMatch);
  }

  static Iterable<String> _valuesForRule(
    ShieldRuleType type,
    ShieldCandidate candidate,
  ) sync* {
    switch (type) {
      case ShieldRuleType.keyword:
        yield ifNullEmpty(candidate.title);
        yield ifNullEmpty(candidate.body);
      case ShieldRuleType.userKeyword:
        yield ifNullEmpty(candidate.authorName);
      case ShieldRuleType.reasonKeyword:
        yield ifNullEmpty(candidate.reason);
      case ShieldRuleType.uid:
        yield ifNullEmpty(candidate.uid);
      case ShieldRuleType.category:
        yield ifNullEmpty(candidate.category);
      case ShieldRuleType.tag:
        yield* candidate.tags;
      case ShieldRuleType.avatarPendant:
        yield* candidate.avatarPendantValues;
      case ShieldRuleType.garb:
        yield* candidate.garbValues;
      case ShieldRuleType.commentMemberSex:
        yield ifNullEmpty(candidate.commentMemberSex);
      case ShieldRuleType.descriptionKeyword:
        yield ifNullEmpty(candidate.description);
      case ShieldRuleType.isUpowerExclusive:
        yield candidate.isUpowerExclusive == true ? 'true' : (
          candidate.isUpowerExclusive == false ? 'false' : ''
        );
      case ShieldRuleType.staffKeyword:
        yield* candidate.staffNames;
      case ShieldRuleType.roomId:
        yield ifNullEmpty(candidate.roomId);
      case ShieldRuleType.duration:
      case ShieldRuleType.playbackCount:
      case ShieldRuleType.danmakuCount:
      case ShieldRuleType.commentMemberLevel:
      case ShieldRuleType.publishTime:
        return;
    }
  }

  static String _normalizeEnumValue(String value) =>
      value.trim().toLowerCase().replaceAll(_enumSeparator, '');

  static List<String> _splitTokens(Iterable<String?> values) {
    final tokens = <String>[];
    for (final value in values) {
      if (value == null) continue;
      for (final token in value.split(_tokenSeparator)) {
        if (token.trim().isNotEmpty) tokens.add(token);
      }
    }
    return tokens;
  }

  static final _tokenSeparator = RegExp(r'[\s,，。！？!?:：;；_\-]+');
  static final _enumSeparator = RegExp(r'[\s_\-]+');
}

class _CandidateMatcherContext {
  _CandidateMatcherContext(this.candidate);

  final ShieldCandidate candidate;
  final Map<ShieldRuleType, List<String>> _rawValues = {};
  final Map<ShieldRuleType, List<String>> _lowerValues = {};
  final Map<ShieldRuleType, List<String>> _enumValues = {};
  final Map<ShieldRuleType, List<String>> _tokens = {};

  List<String> rawValues(ShieldRuleType type) => _rawValues.putIfAbsent(
    type,
    () => ShieldMatcher._valuesForRule(
      type,
      candidate,
    ).where((value) => value.trim().isNotEmpty).toList(growable: false),
  );

  List<String> lowerValues(ShieldRuleType type) => _lowerValues.putIfAbsent(
    type,
    () => rawValues(type)
        .map((value) => value.toLowerCase())
        .toList(
          growable: false,
        ),
  );

  List<String> enumValues(ShieldRuleType type) => _enumValues.putIfAbsent(
    type,
    () =>
        rawValues(type)
            .map(ShieldMatcher._normalizeEnumValue)
            .toList(growable: false),
  );

  Iterable<num> numbers(ShieldRule rule) sync* {
    final value = switch (rule.type) {
      ShieldRuleType.duration => candidate.durationSeconds,
      ShieldRuleType.playbackCount => candidate.playbackCount,
      ShieldRuleType.danmakuCount => candidate.danmakuCount,
      ShieldRuleType.commentMemberLevel => candidate.commentMemberLevel,
      ShieldRuleType.publishTime => candidate.pubdate,
      _ => null,
    };
    if (value != null) yield value;
  }

  List<String> tokens(ShieldRule rule) => _tokens.putIfAbsent(
    rule.type,
    () {
      if (rule.type == ShieldRuleType.userKeyword) {
        return [
          ...candidate.authorTokens,
          ...ShieldMatcher._splitTokens([candidate.authorName]),
        ];
      }
      if (rule.type == ShieldRuleType.reasonKeyword) {
        return ShieldMatcher._splitTokens([candidate.reason]);
      }
      final candidateTokens = candidate.tokens.toList(growable: false);
      if (candidateTokens.isNotEmpty) return candidateTokens;
      return ShieldMatcher._splitTokens(
        ShieldMatcher._valuesForRule(rule.type, candidate),
      );
    },
  );
}

class _CompiledShieldRule {
  _CompiledShieldRule(this._rule)
    : lowerPattern = _rule.pattern.toLowerCase(),
      patternIsEmpty = _rule.pattern.trim().isEmpty,
      normalizedEnumPattern = ShieldMatcher._normalizeEnumValue(
        _rule.pattern,
      );

  final ShieldRule _rule;
  final String lowerPattern;
  final bool patternIsEmpty;
  final String normalizedEnumPattern;
  RegExp? _regex;
  _ParsedRange? _range;
  Object? _regexError;
  Object? _rangeError;
  StackTrace? _regexStack;
  StackTrace? _rangeStack;
  bool _regexFailed = false;
  bool _rangeFailed = false;

  RegExp get regex {
    if (_regexFailed) Error.throwWithStackTrace(_regexError!, _regexStack!);
    return _regex ??= _compileRegex();
  }

  RegExp _compileRegex() {
    try {
      return RegExp(_rule.pattern, caseSensitive: false);
    } catch (error, stack) {
      _regexFailed = true;
      _regexError = error;
      _regexStack = stack;
      rethrow;
    }
  }

  _ParsedRange get range {
    if (_rangeFailed) Error.throwWithStackTrace(_rangeError!, _rangeStack!);
    try {
      return _range ??= _ParsedRange.parse(_rule.pattern);
    } catch (error, stack) {
      _rangeFailed = true;
      _rangeError = error;
      _rangeStack = stack;
      rethrow;
    }
  }
}

String ifNullEmpty(String? value) => value ?? '';

class _ParsedRange {
  const _ParsedRange({this.min, this.max});

  final num? min;
  final num? max;

  static _ParsedRange parse(String pattern) {
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Range pattern is empty');
    }

    final match = RegExp(
      r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*\.\.\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*$',
    ).firstMatch(trimmed);
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
