// Differential check: optimized ShieldMatcher vs the HEAD reference matcher.
//
//   dart run tool/bench/shield_matcher_equivalence.dart
//
// Both implementations see the same rule sets and candidates; any divergence in
// visible / blockedBy / allowedBy / errors is reported. Temporary artifact.
//
// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings
import 'dart:math' as math;

import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';

import '_reference_shield_matcher.dart';

final math.Random _random = math.Random(4711);

const _patterns = <String>[
  '',
  '   ',
  '猫',
  'CAT.*DOG',
  'cat and dog',
  '[',
  'a(',
  '*',
  '(?!x)',
  '42',
  '10..20',
  '..5',
  '5..',
  'abc',
  '20..10',
  '1.5..2.5',
  'UP主',
  'up 主',
  'UP_主',
  'UP-主',
  '美食',
  '探店',
  '攻略',
  '90001',
];

List<ShieldRule> _rules() {
  final rules = <ShieldRule>[];
  var id = 0;
  final count = 1 + _random.nextInt(8);
  for (var i = 0; i < count; i++) {
    rules.add(
      ShieldRule(
        id: 'r' + id.toString(),
        type: ShieldRuleType.values[_random.nextInt(ShieldRuleType.values.length)],
        matchMode: ShieldMatchMode.values[_random.nextInt(ShieldMatchMode.values.length)],
        scope: ShieldScope.values[_random.nextInt(ShieldScope.values.length)],
        action: _random.nextBool() ? ShieldAction.block : ShieldAction.allow,
        pattern: _patterns[_random.nextInt(_patterns.length)],
        enabled: _random.nextInt(5) != 0,
        updatedAt: DateTime.utc(2025, 10, 3),
      ),
    );
    id++;
  }
  return rules;
}

List<ShieldCandidate> _candidates() {
  final candidates = <ShieldCandidate>[];
  for (var i = 0; i < 24; i++) {
    final bool? exclusive = switch (i % 3) {
      0 => true,
      1 => false,
      _ => null,
    };
    candidates.add(
      ShieldCandidate(
        scope: ShieldScope.values[i % ShieldScope.values.length],
        title: switch (i % 5) {
          0 => null,
          1 => '',
          2 => '猫咪睡觉合集',
          3 => 'CAT 42 DOG',
          _ => 'UP主的美食探店攻略',
        },
        body: i.isEven ? '评论里有剧透 42' : null,
        reason: switch (i % 4) {
          0 => null,
          1 => '因为你看过相似内容',
          2 => '相似内容',
          _ => '',
        },
        uid: switch (i % 4) {
          0 => null,
          1 => '42',
          2 => '142',
          _ => '90001',
        },
        authorName: switch (i % 4) {
          0 => null,
          1 => '普通UP',
          2 => '测试 UP',
          _ => '测试员',
        },
        authorTokens: i.isEven ? const ['美食'] : const [],
        category: switch (i % 3) {
          0 => null,
          1 => '游戏',
          _ => '单机游戏',
        },
        tags: switch (i % 3) {
          0 => const [],
          1 => const ['攻略'],
          _ => const ['攻略合集', '萌宠'],
        },
        tokens: switch (i % 3) {
          0 => const [],
          1 => const ['美食'],
          _ => const ['探店', 'UP主'],
        },
        avatarPendantValues: i.isEven ? const ['pendant'] : const [],
        garbValues: i.isEven ? const ['card-1'] : const [],
        durationSeconds: switch (i % 4) {
          0 => null,
          1 => 0,
          2 => 15,
          _ => 90,
        },
        playbackCount: switch (i % 3) {
          0 => null,
          1 => 7,
          _ => 250000,
        },
        danmakuCount: switch (i % 3) {
          0 => null,
          1 => 0,
          _ => 40,
        },
        commentMemberSex: i.isEven ? '1' : null,
        commentMemberLevel: switch (i % 3) {
          0 => null,
          1 => 4,
          _ => 12,
        },
        description: i.isEven ? '简介里有攻略' : null,
        pubdate: i.isEven ? 1700000000 : null,
        staffNames: switch (i % 3) {
          0 => const [],
          1 => const ['staff-a'],
          _ => const ['staff-a', 'staff-b'],
        },
        isUpowerExclusive: exclusive,
      ),
    );
  }
  return candidates;
}

String _signature(ShieldMatchResult result) {
  final errors = result.errors
      .map((error) => error.rule.id + ':' + error.message)
      .join('|');
  return [
    result.visible ? 'visible' : 'blocked',
    result.blockedBy?.id ?? '-',
    result.allowedBy?.id ?? '-',
    errors,
  ].join('#');
}

class _Counting {
  int tokensCalls = 0;
  int authorTokensCalls = 0;
}

/// Copy of [c] with the token lists swapped for lazy providers.
///
/// [keepEager] keeps the eager lists too, which must win over the providers;
/// [providerTokens] overrides what the token provider returns, so an eager list
/// that still decides the outcome is detectable.
ShieldCandidate _withProviders(
  ShieldCandidate c,
  _Counting counter, {
  bool keepEager = false,
  List<String> providerTokens = const ['zzz-not-a-real-token'],
}) => ShieldCandidate(
  scope: c.scope,
  title: c.title,
  body: c.body,
  reason: c.reason,
  uid: c.uid,
  authorName: c.authorName,
  authorTokens: keepEager ? c.authorTokens : const [],
  authorTokensProvider: () {
    counter.authorTokensCalls++;
    return keepEager ? const ['zzz-not-a-real-token'] : c.authorTokens;
  },
  category: c.category,
  tags: c.tags,
  tokens: keepEager ? c.tokens : const [],
  tokensProvider: () {
    counter.tokensCalls++;
    return keepEager ? providerTokens : c.tokens;
  },
  avatarPendantValues: c.avatarPendantValues,
  garbValues: c.garbValues,
  durationSeconds: c.durationSeconds,
  playbackCount: c.playbackCount,
  danmakuCount: c.danmakuCount,
  commentMemberSex: c.commentMemberSex,
  commentMemberLevel: c.commentMemberLevel,
  description: c.description,
  pubdate: c.pubdate,
  staffNames: c.staffNames,
  isUpowerExclusive: c.isUpowerExclusive,
);

void main() {
  final candidates = _candidates();
  var comparisons = 0;
  var mismatches = 0;

  // 1) Randomised rule sets.
  for (var iteration = 0; iteration < 4000; iteration++) {
    final ruleSet = ShieldRuleSet(
      rules: _rules(),
      globalEnabled: _random.nextInt(6) != 0,
      recommendationEnabled: _random.nextBool(),
      commentEnabled: _random.nextBool(),
      relatedVideoEnabled: _random.nextBool(),
    );
    for (final candidate in candidates) {
      final expected = _signature(ReferenceShieldMatcher.match(candidate, ruleSet));
      final actual = _signature(ShieldMatcher.match(candidate, ruleSet));
      comparisons++;
      if (expected != actual) {
        mismatches++;
        if (mismatches <= 5) {
          print('MISMATCH random iteration=' + iteration.toString());
          print('  rules=' + ruleSet.rules.map((rule) => rule.id + ':' + rule.type.name + '/' + rule.matchMode.name + '/' + rule.scope.name + '/' + rule.action.name + '/' + rule.enabled.toString() + '/<' + rule.pattern + '>').join(', '));
          print('  expected=' + expected);
          print('  actual  =' + actual);
        }
      }
    }
  }

  // 2) Exhaustive (type, mode, pattern) sweep with reused rule instances so the
  //    rule-identity caches are exercised across candidates and repeats.
  final sweepRules = <ShieldRule>[];
  var id = 0;
  for (final type in ShieldRuleType.values) {
    for (final mode in ShieldMatchMode.values) {
      for (var p = 0; p < _patterns.length; p++) {
        for (final scope in ShieldScope.values) {
          sweepRules.add(
            ShieldRule(
              id: 's' + (id++).toString(),
              type: type,
              matchMode: mode,
              scope: scope,
              action: ShieldAction.block,
              pattern: _patterns[p],
              enabled: true,
              updatedAt: DateTime.utc(2025, 10, 3),
            ),
          );
        }
      }
    }
  }
  final sweepSet = ShieldRuleSet(rules: sweepRules);
  print('sweep rules=' + sweepRules.length.toString());
  for (var repeat = 0; repeat < 3; repeat++) {
    for (final candidate in candidates) {
      final expected = _signature(ReferenceShieldMatcher.match(candidate, sweepSet));
      final actual = _signature(ShieldMatcher.match(candidate, sweepSet));
      comparisons++;
      if (expected != actual) {
        mismatches++;
        if (mismatches <= 5) {
          print('MISMATCH sweep repeat=' + repeat.toString());
          print('  expected=' + expected);
          print('  actual  =' + actual);
        }
      }
    }
  }

  // 3) Lazy token providers: the optimized matcher must be self-consistent with
  //    the eager form. The reference matcher predates providers and treats a
  //    lazy candidate as value-less, so section 3 compares optimized-lazy
  //    against optimized-eager instead of against the reference.
  final randomSets = <ShieldRuleSet>[];
  for (var i = 0; i < 60; i++) {
    randomSets.add(
      ShieldRuleSet(
        rules: _rules(),
        globalEnabled: _random.nextInt(6) != 0,
        recommendationEnabled: _random.nextBool(),
        commentEnabled: _random.nextBool(),
        relatedVideoEnabled: _random.nextBool(),
      ),
    );
  }
  for (final ruleSet in [...randomSets, sweepSet]) {
    for (final candidate in candidates) {
      final eager = _signature(ShieldMatcher.match(candidate, ruleSet));

      final counter = _Counting();
      final lazy = _withProviders(candidate, counter);
      final lazySignature = _signature(ShieldMatcher.match(lazy, ruleSet));
      comparisons++;
      if (eager != lazySignature) {
        mismatches++;
        if (mismatches <= 5) {
          print('MISMATCH lazy candidate index=' + candidates.indexOf(candidate).toString());
          print('  eager=' + eager);
          print('  lazy =' + lazySignature);
        }
      }

      // An eager list present next to a provider must still win. Only a
      // non-empty eager list can decide the outcome, so empty ones are skipped.
      if (candidate.tokens.isNotEmpty) {
      final kept = _withProviders(candidate, _Counting(), keepEager: true);
      final keptSignature = _signature(ShieldMatcher.match(kept, ruleSet));
      comparisons++;
      if (eager != keptSignature) {
        mismatches++;
        if (mismatches <= 5) {
          print('MISMATCH eager-wins candidate index=' + candidates.indexOf(candidate).toString());
          print('  eager=' + eager);
          print('  kept =' + keptSignature);
        }
      }
      }

      // Repeating a match must not depend on any cache warmed by the first run.
      final again = _signature(ShieldMatcher.match(lazy, ruleSet));
      comparisons++;
      if (again != lazySignature) {
        mismatches++;
        if (mismatches <= 5) {
          print('MISMATCH repeat candidate index=' + candidates.indexOf(candidate).toString());
          print('  first=' + lazySignature);
          print('  again=' + again);
        }
      }
    }
  }

  // 3b) Laziness is observable: a rule set without token-mode rules must never
  //     ask the providers for tokens.
  final noTokenRules = ShieldRuleSet(
    rules: [
      for (final type in ShieldRuleType.values)
        ShieldRule(
          id: 'n-' + type.name,
          type: type,
          matchMode: ShieldMatchMode.contains,
          scope: ShieldScope.recommendation,
          action: ShieldAction.block,
          pattern: 'zzz-no-match',
          updatedAt: DateTime.utc(2025, 10, 3),
        ),
    ],
  );
  var lazyCalls = 0;
  for (final candidate in candidates) {
    final counter = _Counting();
    final lazy = _withProviders(candidate, counter);
    ShieldMatcher.match(lazy, noTokenRules);
    comparisons++;
    if (counter.tokensCalls != 0 || counter.authorTokensCalls != 0) {
      lazyCalls++;
      if (lazyCalls <= 5) {
        print(
          'UNEXPECTED provider call without token rules: tokens=' +
              counter.tokensCalls.toString() +
              ' authorTokens=' +
              counter.authorTokensCalls.toString(),
        );
      }
    }
  }
  mismatches += lazyCalls;

  // 3c) With token-mode rules present the providers must be consulted at most
  //     once per match call, per candidate.
  // Every pattern needs its own rule because the matcher reports the first
  // matching token rule per action; several rules of the same type keep the
  // provider memoisation under test instead of testing type fan-out.
  final tokenOnlyRules = ShieldRuleSet(
    rules: [
      for (final pattern in const ['美食', '探店', 'UP主', '猫', 'zzz'])
        ShieldRule(
          id: 't-keyword-' + pattern,
          type: ShieldRuleType.keyword,
          matchMode: ShieldMatchMode.token,
          scope: ShieldScope.recommendation,
          action: ShieldAction.block,
          pattern: pattern,
          updatedAt: DateTime.utc(2025, 10, 3),
        ),
      for (final pattern in const ['美食', 'UP主'])
        ShieldRule(
          id: 't-user-' + pattern,
          type: ShieldRuleType.userKeyword,
          matchMode: ShieldMatchMode.token,
          scope: ShieldScope.recommendation,
          action: ShieldAction.block,
          pattern: pattern,
          updatedAt: DateTime.utc(2025, 10, 3),
        ),
    ],
  );
  for (final candidate in candidates) {
    final counter = _Counting();
    final lazy = _withProviders(candidate, counter);
    ShieldMatcher.match(lazy, tokenOnlyRules);
    comparisons++;
    if (counter.tokensCalls > 1 || counter.authorTokensCalls > 1) {
      mismatches++;
      if (mismatches <= 5) {
        print(
          'REPEATED provider call: tokens=' +
              counter.tokensCalls.toString() +
              ' authorTokens=' +
              counter.authorTokensCalls.toString(),
        );
      }
    }
  }

  print('comparisons=' + comparisons.toString() + ' mismatches=' + mismatches.toString());
}
