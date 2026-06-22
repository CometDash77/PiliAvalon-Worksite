import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldRuleType decoration', () {
    test('avatarPendant round trips JSON by name', () {
      final rule = ShieldRule(
        id: 'pendant-1',
        type: ShieldRuleType.avatarPendant,
        matchMode: ShieldMatchMode.exact,
        scope: ShieldScope.comment,
        action: ShieldAction.block,
        pattern: 'https://i0.hdslb.com/pendant.png',
        enabled: true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );

      final json = rule.toJson();
      expect(json['type'], 'avatarPendant');

      final decoded = ShieldRule.fromJson(json);
      expect(decoded.type, ShieldRuleType.avatarPendant);
      expect(decoded.pattern, 'https://i0.hdslb.com/pendant.png');
    });

    test('garb round trips JSON by name', () {
      final rule = ShieldRule(
        id: 'garb-1',
        type: ShieldRuleType.garb,
        matchMode: ShieldMatchMode.regex,
        scope: ShieldScope.comment,
        action: ShieldAction.block,
        pattern: r'NO\.\d+',
        enabled: true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );

      final json = rule.toJson();
      expect(json['type'], 'garb');

      final decoded = ShieldRule.fromJson(json);
      expect(decoded.type, ShieldRuleType.garb);
      expect(decoded.pattern, r'NO\.\d+');
    });

    test(
      'avatar pendant exact matching blocks when pattern equals pendant image',
      () {
        const candidate = ShieldCandidate(
          scope: ShieldScope.comment,
          avatarPendantValues: ['https://i0.hdslb.com/pendant.png'],
        );
        final ruleSet = ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'pendant-block',
              type: ShieldRuleType.avatarPendant,
              matchMode: ShieldMatchMode.exact,
              scope: ShieldScope.comment,
              action: ShieldAction.block,
              pattern: 'https://i0.hdslb.com/pendant.png',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );

        final result = ShieldMatcher.match(candidate, ruleSet);

        expect(result.visible, isFalse);
        expect(result.blockedBy?.type, ShieldRuleType.avatarPendant);
      },
    );

    test('avatar pendant does not block when value does not match', () {
      const candidate = ShieldCandidate(
        scope: ShieldScope.comment,
        avatarPendantValues: ['https://i0.hdslb.com/other.png'],
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'pendant-block',
            type: ShieldRuleType.avatarPendant,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: 'https://i0.hdslb.com/pendant.png',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final result = ShieldMatcher.match(candidate, ruleSet);

      expect(result.visible, isTrue);
    });

    test('garb regex matching blocks when pattern matches card number', () {
      const candidate = ShieldCandidate(
        scope: ShieldScope.comment,
        garbValues: ['NO.0001', 'NO.0002'],
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'garb-regex',
            type: ShieldRuleType.garb,
            matchMode: ShieldMatchMode.regex,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: r'NO\.\d+',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final result = ShieldMatcher.match(candidate, ruleSet);

      expect(result.visible, isFalse);
      expect(result.blockedBy?.type, ShieldRuleType.garb);
    });

    test('garb does not block when no value matches', () {
      const candidate = ShieldCandidate(
        scope: ShieldScope.comment,
        garbValues: ['plain text'],
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'garb-regex',
            type: ShieldRuleType.garb,
            matchMode: ShieldMatchMode.regex,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: r'NO\.\d+',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final result = ShieldMatcher.match(candidate, ruleSet);

      expect(result.visible, isTrue);
    });

    test('empty avatarPendantValues are ignored', () {
      const candidate = ShieldCandidate(
        scope: ShieldScope.comment,
        avatarPendantValues: [],
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'pendant-block',
            type: ShieldRuleType.avatarPendant,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: 'anything',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final result = ShieldMatcher.match(candidate, ruleSet);

      expect(result.visible, isTrue);
    });

    test('empty garbValues are ignored', () {
      const candidate = ShieldCandidate(
        scope: ShieldScope.comment,
        garbValues: [],
      );
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'garb-block',
            type: ShieldRuleType.garb,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: 'anything',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final result = ShieldMatcher.match(candidate, ruleSet);

      expect(result.visible, isTrue);
    });

    test('decoration rules JSON round trip in ShieldRuleSet', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'pendant-1',
            type: ShieldRuleType.avatarPendant,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: 'https://example.com/pendant.png',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
          ShieldRule(
            id: 'garb-1',
            type: ShieldRuleType.garb,
            matchMode: ShieldMatchMode.regex,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: r'NO\.\d+',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        ],
      );

      final decoded = ShieldRuleSet.fromJson(ruleSet.toJson());

      expect(decoded.rules, hasLength(2));
      expect(
        decoded.rules.map((r) => r.type),
        containsAll([ShieldRuleType.avatarPendant, ShieldRuleType.garb]),
      );
    });
  });
}
