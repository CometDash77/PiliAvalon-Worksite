# Task-065 Inline Boundary Storage Fix

**Audience:** agent-facing
**Date:** 2026-06-13
**Role:** reasonix-task065-inline-boundary-storage-fix
**Review owner:** Codex
**Branch:** task-071-keyword-contains-from-5134 (working tree after task-065 inline entry candidates)

## Summary

Fixed a correctness bug in the recommend-settings inline range-shielding persistence. The previous code wrote a single `ShieldRule` with pattern `$min..$max` when the user set both "屏蔽低于" (block below) and "屏蔽高于" (block above) thresholds. The `ShieldMatchMode.range` matcher in `shielding_matcher.dart` interprets `A..B` as "match values INSIDE the interval [A, B]" — so the single rule would block the **middle** of the range, not the boundaries. This fix persists separate `..X` and `Y..` rules that the existing matcher already interprets correctly as boundary shields, without changing any matcher or business logic.

## Root Cause — Matcher Semantics

`_ParsedRange.matches()` at `lib/features/shielding/shielding_matcher.dart:204-209`:

```dart
bool matches(num value) {
  final lower = min;
  if (lower != null && value < lower) return false;
  final upper = max;
  if (upper != null && value > upper) return false;
  return true;  // value is WITHIN [min, max]
}
```

- `..30` → min=null, max=30 → blocks values ≤ 30 ✅ (correct for "屏蔽低于 30")
- `120..` → min=120, max=null → blocks values ≥ 120 ✅ (correct for "屏蔽高于 120")
- `30..120` → min=30, max=120 → blocks values **30–120** ❌ (was: "屏蔽低于 30 及高于 120")

The old code wrote `$min..$max` when both fields were set, creating a middle-interval block instead of boundary shields.

## Fix: Correct Pattern Mapping

### Save Path (unchanged from user perspective)

| User enters | Old pattern | New pattern(s) | Matcher behavior |
|---|---|---|---|
| 屏蔽低于 30 only | `30..` (broken: blocks ≥30) | `..30` | blocks ≤ 30 ✅ |
| 屏蔽高于 120 only | `..120` (broken: blocks ≤120) | `120..` | blocks ≥ 120 ✅ |
| Both 30 and 120 | `30..120` (broken: blocks 30–120) | `..30` + `120..` (2 rules) | blocks ≤ 30 and ≥ 120 ✅ |

Note: the old code also had the single-boundary cases wrong — `min..` stored the lower threshold as the range min (meaning "block ≥ min") and `..max` stored the upper threshold as the range max (meaning "block ≤ max"). The new code inverts this correctly: lower threshold → `..X`, upper threshold → `Y..`.

### Read Path

`_findRangeThresholds()` aggregates all range rules for the same `type+scope+matchMode`:
- Rule with pattern `..X` → lower threshold = X
- Rule with pattern `Y..` → upper threshold = Y
- Legacy bounded `A..B` → lower = A, upper = B (defensive: uses `??=` so first legacy rule wins)

The subtitle formatter (`_formatSubtitle`) renders from the aggregated thresholds.

## Files Changed

### `lib/pages/setting/models/recommend_settings.dart`

| Change | Description |
|---|---|
| `_findRule()` → `_findRangeThresholds()` | Aggregates multiple range rules into `(lower, upper)` record |
| `_formatSubtitle(ShieldRule?)` → `_formatSubtitle(String?, String?)` | Formats from threshold pair directly |
| `getSubtitle` closure | Calls `_findRangeThresholds()` then `_formatSubtitle(t.lower, t.upper)` |
| `onTap` closure | Precomputes thresholds, passes to dialog as `lowerInit`/`upperInit` |
| `_openRangeShieldingDialog` signature | Added `{String? lowerInit, String? upperInit}` optional params |
| Dialog init | Uses `lowerInit`/`upperInit` instead of querying store directly |
| Save path | Removes ALL old `type+scope+range` rules; creates `..$min` rule (if min set) and `$max..` rule (if max set) separately |

**Not changed:**
- `_parseRangeFields()` — already handles `..X` and `Y..` patterns correctly
- `_rangeHint()` — used for live hint only, semantics unchanged
- `_rangeTypeLabel()` — unchanged
- `shielding_matcher.dart` — **not touched**
- `shielding_models.dart` — **not touched**
- `shielding_store.dart` — **not touched**

### `test/pages/setting/models/recommend_settings_test.dart`

Added imports for `shielding_models.dart` and `shielding_store.dart`.
Added new test group `range shielding boundary semantics` with 5 tests:

1. **lower-only rule shows lower-than subtitle** — persists `..30` for duration, verifies subtitle `屏蔽 < 30`
2. **upper-only rule shows higher-than subtitle** — persists `500..` for playbackCount, verifies subtitle `屏蔽 > 500`
3. **both rules aggregate to combined subtitle** — persists `..30` + `200..` for danmakuCount, verifies subtitle `屏蔽 < 30 及 > 200`
4. **empty rules default to 未设置** — verifies all 3 dimension entries show `未设置` when no rules exist
5. **non-range rules for same type do not affect subtitle** — persists a `contains`-mode keyword rule for duration, verifies subtitle remains `未设置`

## Limitations

- **Dart SDK not available** on this machine (`which dart` returned nothing, no Flutter SDK found under common paths). Could not run `dart analyze`, `dart format`, or `flutter test` locally.
- **`_parseRangeFields`** and **`_findRangeThresholds`** are library-private (Dart file-private). The test file in `test/pages/setting/models/` cannot import private symbols from `lib/pages/setting/models/recommend_settings.dart`. The new boundary-semantic tests work around this by testing through the public `recommendSettings` getter and `ShieldSettingsStore`, which exercises the full read path end-to-end.
- **`git diff --check`** passed with no whitespace errors.

## Verification Checklist

| Check | Status | Notes |
|---|---|---|
| `git diff --check` | ✅ Passed | No whitespace errors |
| ShieldMatchMode.range semantics confirmed | ✅ | `_ParsedRange.matches()` uses `[min, max]` inclusion |
| `..X` blocks values ≤ X | ✅ | Matcher: min=null, max=X → `value > X` returns false |
| `Y..` blocks values ≥ Y | ✅ | Matcher: min=Y, max=null → `value < Y` returns false |
| Two-rule save path | ✅ | Creates separate `..$min` and `$max..` rules |
| Old rules removed on save | ✅ | Filters ALL `type+scope+range` rules, not just first |
| Legacy `A..B` handled defensively | ✅ | `_findRangeThresholds` treats as lower=A, upper=B with `??=` |
| Business matcher unchanged | ✅ | `shielding_matcher.dart` not modified |
| Storage model unchanged | ✅ | `shielding_models.dart` not modified |
| UI structure unchanged | ✅ | Same 3 inline entries, same dialog labels |
| dart analyze | ⚠️ Not run | Dart SDK not available |
| flutter test | ⚠️ Not run | Dart SDK not available |

## Remaining Gates

1. **Codex review** — this artifact + the diff
2. **CI** — GitHub Actions: `dart analyze` + `flutter test`
3. **Manual acceptance** — verify dialog save/read round-trip for all 3 dimensions, single-threshold and dual-threshold cases
