# ShieldMatcher hot-path acceptance harness (map #47 / issue #52)

Purpose: prove that the in-flight ShieldMatcher hot-path optimization is
(a) decision-equivalent to the pre-optimization implementation and
(b) measurably faster per page, in one process, on one workload.

## Files
- `shield_matcher_bench_test.dart` — equivalence assertion + timing loop.
- `_legacy_shielding_matcher.dart` — verbatim copy of
  `git show HEAD:lib/features/shielding/shielding_matcher.dart` from the
  pre-optimization checkout (branch `codex/task55-temp-quiet-rewrite`,
  HEAD `0d4be712a`), with exactly one added line:
  `case ShieldRuleType.roomId: break;` — required for Dart 3 exhaustive
  switch analysis, otherwise the file does not compile at all.

## How to run
```
flutter test tool/bench/shield_matcher_bench_test.dart --reporter expanded
```
The harness must be run against a working tree that already contains the
optimized `lib/features/shielding/shielding_matcher.dart` (see below).

## Workload
20 candidates (Chinese titles/tags/token lists/authors/durations/play counts/
categories) x 72 mixed rules spinning over 17 `ShieldRuleType` values. Numeric
types use `range`, sex/exclusive use `enumValue`, `i % 13 == 0` uses `token`,
the rest rotate over `exact`/`contains`/`regex`; scopes are mostly
`recommendation`, `i % 9 == 0` is `both`, `i % 5 == 0` is `allow`. One rule is
deliberately an invalid regex (`(?i)spoiler|剧透`) so the rule-error surface is
covered.

## Measured result (2026-10-05)
- equivalence: 0 mismatch over 20 candidates (visible / blockedBy.id /
  allowedBy.id / error count all identical).
- legacy:    906.3 / 909.6 us per page
- optimized: 463.9 / 459.4 us per page
- speedup: ~1.95x / ~1.98x (30 warmup pages, then 7 samples x 100 iterations,
  median, legacy and optimized interleaved twice).

## Reproducing against a clean tree
The optimization itself is not committed: the shared working tree
(`codex/task55-temp-quiet-rewrite`) carries 35 modified files from several
work streams, several of them uncommitted. To reproduce, apply the ShieldMatcher
change to `lib/features/shielding/shielding_matcher.dart`:
per-rule Expando cache of normalized pattern / compiled RegExp / parsed range,
per-rule-set + candidate-scope cache of enabled rules, per-match memoization of
normalized candidate field values, and lazy token splitting, plus the
`_matchRegex` eager-compile helper that keeps the invalid-pattern error surface
identical to the legacy code.
