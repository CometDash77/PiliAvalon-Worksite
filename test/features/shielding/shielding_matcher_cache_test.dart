import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldMatcher verdict stability under reuse', () {
    test('one rule set reused across candidates keeps per-candidate verdicts', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
          ),
          _rule(
            type: ShieldRuleType.tag,
            mode: ShieldMatchMode.exact,
            pattern: '萌宠',
          ),
          _rule(
            type: ShieldRuleType.duration,
            mode: ShieldMatchMode.range,
            pattern: '60..300',
          ),
        ],
      );

      const blocked = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
        durationSeconds: 180,
      );
      const visible = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '烘焙教程',
        durationSeconds: 900,
      );

      for (var i = 0; i < 5; i++) {
        expect(ShieldMatcher.match(blocked, ruleSet).visible, isFalse);
        expect(ShieldMatcher.match(visible, ruleSet).visible, isTrue);
      }
    });

    test('shared rule instances report the same blocker on every pass', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
          ),
        ],
      );
      const candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
      );

      final first = ShieldMatcher.match(candidate, ruleSet);
      expect(first.visible, isFalse);
      for (var i = 0; i < 5; i++) {
        final again = ShieldMatcher.match(candidate, ruleSet);
        expect(again.visible, first.visible);
        expect(again.blockedBy, same(first.blockedBy));
        expect(again.errors, isEmpty);
      }
    });

    test('allow still overrides a block from a cached rule list', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
          ),
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
            action: ShieldAction.allow,
          ),
        ],
      );
      const candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
      );

      for (var i = 0; i < 3; i++) {
        final result = ShieldMatcher.match(candidate, ruleSet);
        expect(result.visible, isTrue);
        expect(result.blockedBy, isNotNull);
        expect(result.allowedBy, isNotNull);
      }
    });

    test('disabled and out-of-scope rules stay excluded across passes', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
            enabled: false,
          ),
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
            scope: ShieldScope.comment,
          ),
        ],
      );
      const candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
      );

      for (var i = 0; i < 3; i++) {
        expect(ShieldMatcher.match(candidate, ruleSet).visible, isTrue);
      }
    });

    test('a disabled rule set stays fully permissive across passes', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
          ),
        ],
        globalEnabled: false,
      );
      const candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
      );

      for (var i = 0; i < 3; i++) {
        expect(ShieldMatcher.match(candidate, ruleSet).visible, isTrue);
      }
    });
  });

  group('ShieldMatcher error reporting under reuse', () {
    test('invalid regex still reports one error for a value-less candidate', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.regex,
            pattern: '[',
          ),
        ],
      );
      const candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '',
      );

      final messages = <String>{};
      for (var i = 0; i < 3; i++) {
        final result = ShieldMatcher.match(candidate, ruleSet);
        expect(result.visible, isTrue);
        expect(result.errors, hasLength(1));
        expect(result.errors.single.rule.pattern, '[');
        messages.add(result.errors.single.message);
      }
      expect(messages, hasLength(1));
    });

    test('invalid range still reports one error for a value-less candidate', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.duration,
            mode: ShieldMatchMode.range,
            pattern: '300..60',
          ),
        ],
      );
      const candidate = ShieldCandidate(scope: ShieldScope.recommendation);

      final messages = <String>{};
      for (var i = 0; i < 3; i++) {
        final result = ShieldMatcher.match(candidate, ruleSet);
        expect(result.visible, isTrue);
        expect(result.errors, hasLength(1));
        messages.add(result.errors.single.message);
      }
      expect(messages, hasLength(1));
    });

    test('a broken rule does not stop a later rule from blocking', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.regex,
            pattern: '[',
          ),
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '睡觉',
          ),
        ],
      );
      const candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
      );

      for (var i = 0; i < 3; i++) {
        final result = ShieldMatcher.match(candidate, ruleSet);
        expect(result.visible, isFalse);
        expect(result.blockedBy?.pattern, '睡觉');
        expect(result.errors, hasLength(1));
      }
    });
  });

  group('ShieldCandidate lazy tokens', () {
    test('providers are not consulted when no token rule applies', () {
      var tokenCalls = 0;
      var authorCalls = 0;
      final candidate = _lazyCandidate(
        tokens: const ['美食', '探店'],
        authorTokens: const ['UP主'],
        onTokens: () => tokenCalls++,
        onAuthorTokens: () => authorCalls++,
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(type: ShieldRuleType.keyword, pattern: '睡觉'),
          _rule(type: ShieldRuleType.keyword, pattern: '猫'),
        ],
      );

      expect(ShieldMatcher.match(candidate, ruleSet).visible, isTrue);
      expect(tokenCalls, 0);
      expect(authorCalls, 0);
    });

    test('providers are consulted at most once per match', () {
      var tokenCalls = 0;
      var authorCalls = 0;
      final candidate = _lazyCandidate(
        tokens: const ['美食', '探店'],
        authorTokens: const ['UP主'],
        onTokens: () => tokenCalls++,
        onAuthorTokens: () => authorCalls++,
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          for (final pattern in const ['美食', '探店', 'zzz'])
            _rule(
              type: ShieldRuleType.keyword,
              mode: ShieldMatchMode.token,
              pattern: pattern,
            ),
          for (final pattern in const ['UP主', 'zzz'])
            _rule(
              type: ShieldRuleType.userKeyword,
              mode: ShieldMatchMode.token,
              pattern: pattern,
            ),
        ],
      );

      final result = ShieldMatcher.match(candidate, ruleSet);
      expect(result.visible, isFalse);
      expect(result.blockedBy?.pattern, '美食');
      expect(tokenCalls, 1);
      expect(authorCalls, 1);
    });

    test('an eager token list wins over the provider', () {
      var tokenCalls = 0;
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.token,
            pattern: '美食',
          ),
        ],
      );

      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '烘焙教程',
        tokens: const ['美食'],
        tokensProvider: () {
          tokenCalls++;
          return const ['zzz'];
        },
      );

      final result = ShieldMatcher.match(candidate, ruleSet);
      expect(result.visible, isFalse);
      expect(result.blockedBy?.pattern, '美食');
      expect(tokenCalls, 0);
    });

    test('lazy tokens reproduce the eager verdict', () {
      const eager = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '猫咪睡觉合集',
        tokens: ['美食', '探店', 'UP主'],
      );
      final lazy = _lazyCandidate(tokens: eager.tokens, authorTokens: const []);
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.token,
            pattern: '探店',
          ),
        ],
      );

      final eagerResult = ShieldMatcher.match(eager, ruleSet);
      final lazyResult = ShieldMatcher.match(lazy, ruleSet);
      expect(eagerResult.visible, isFalse);
      expect(lazyResult.visible, isFalse);
      expect(lazyResult.blockedBy, same(eagerResult.blockedBy));
    });

    test('lazy author tokens feed userKeyword token rules', () {
      final lazy = _lazyCandidate(
        tokens: const [],
        authorTokens: const ['被屏蔽UP'],
        authorName: '被屏蔽UP的美食日常',
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.userKeyword,
            mode: ShieldMatchMode.token,
            pattern: '被屏蔽up',
          ),
        ],
      );

      final result = ShieldMatcher.match(lazy, ruleSet);
      expect(result.visible, isFalse);
      expect(result.blockedBy?.pattern, '被屏蔽up');
    });
  });
}

ShieldCandidate _lazyCandidate({
  List<String> tokens = const [],
  List<String> authorTokens = const [],
  String? authorName,
  String? title,
  void Function()? onTokens,
  void Function()? onAuthorTokens,
}) => ShieldCandidate(
  scope: ShieldScope.recommendation,
  title: title,
  authorName: authorName,
  authorTokens: const [],
  authorTokensProvider: () {
    onAuthorTokens?.call();
    return authorTokens;
  },
  tokens: const [],
  tokensProvider: () {
    onTokens?.call();
    return tokens;
  },
);

ShieldRule _rule({
  ShieldRuleType type = ShieldRuleType.keyword,
  ShieldMatchMode mode = ShieldMatchMode.exact,
  ShieldScope scope = ShieldScope.both,
  ShieldAction action = ShieldAction.block,
  required String pattern,
  bool enabled = true,
}) => ShieldRule(
  id: 'cache-rule-$type-$mode-$scope-$action-$pattern',
  type: type,
  matchMode: mode,
  scope: scope,
  action: action,
  pattern: pattern,
  enabled: enabled,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
);
