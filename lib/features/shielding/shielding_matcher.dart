import 'package:PiliPlus/features/shielding/shielding_models.dart';

abstract final class ShieldMatcher {
  static ShieldMatchResult match(
    ShieldCandidate candidate,
    ShieldRuleSet ruleSet,
  ) {
    if (!ruleSet.isScopeEnabled(candidate.scope)) {
      return ShieldMatchResult.visibleResult;
    }

    final errors = <ShieldMatchError>[];
    ShieldRule? allowedBy;
    ShieldRule? blockedBy;

    for (final rule in ruleSet.rules) {
      if (!rule.enabled || !_scopeMatches(rule.scope, candidate.scope)) {
        continue;
      }

      bool matched;
      try {
        matched = _matches(rule, candidate);
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

  static bool _matches(ShieldRule rule, ShieldCandidate candidate) {
    final pattern = rule.pattern.toLowerCase();
    if (pattern.trim().isEmpty) return false;
    return switch (rule.matchMode) {
      ShieldMatchMode.exact => _matchValues(rule, candidate).any(
        (value) => value.toLowerCase() == pattern,
      ),
      ShieldMatchMode.contains => _matchValues(rule, candidate).any(
        (value) => value.toLowerCase().contains(pattern),
      ),
      ShieldMatchMode.regex => _matchValues(rule, candidate).any(
        RegExp(rule.pattern, caseSensitive: false).hasMatch,
      ),
      ShieldMatchMode.range => _matchNumbers(rule, candidate).any(
        _rangeMatcher(rule.pattern),
      ),
      ShieldMatchMode.enumValue => _matchValues(rule, candidate).any(
        (value) => _normalizeEnumValue(value) == _normalizeEnumValue(pattern),
      ),
      ShieldMatchMode.token => _tokenValues(rule, candidate).any(
        (token) => token.toLowerCase() == rule.pattern.toLowerCase(),
      ),
    };
  }

  static Iterable<String> _matchValues(
    ShieldRule rule,
    ShieldCandidate candidate,
  ) => _valuesForRule(
    rule.type,
    candidate,
  ).where((value) => value.trim().isNotEmpty);

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
      case ShieldRuleType.duration:
      case ShieldRuleType.playbackCount:
      case ShieldRuleType.danmakuCount:
      case ShieldRuleType.commentMemberLevel:
      case ShieldRuleType.publishTime:
        return;
    }
  }

  static Iterable<num> _matchNumbers(
    ShieldRule rule,
    ShieldCandidate candidate,
  ) sync* {
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

  static bool Function(num value) _rangeMatcher(String pattern) {
    final range = _ParsedRange.parse(pattern);
    return range.matches;
  }

  static String _normalizeEnumValue(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  static Iterable<String> _tokenValues(
    ShieldRule rule,
    ShieldCandidate candidate,
  ) sync* {
    if (rule.type == ShieldRuleType.userKeyword) {
      yield* candidate.authorTokens;
      yield* _splitTokens([candidate.authorName]);
      return;
    }
    if (rule.type == ShieldRuleType.reasonKeyword) {
      yield* _splitTokens([candidate.reason]);
      return;
    }
    if (candidate.tokens.isNotEmpty) {
      yield* candidate.tokens;
      return;
    }
    yield* _splitTokens(_valuesForRule(rule.type, candidate));
  }

  static Iterable<String> _splitTokens(Iterable<String?> values) =>
      values.whereType<String>().expand(
        (value) => value
            .split(RegExp(r'[\s,，。！？!?:：;；_\-]+'))
            .where((token) => token.trim().isNotEmpty),
      );
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
