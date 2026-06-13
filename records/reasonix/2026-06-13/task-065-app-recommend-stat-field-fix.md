# Task-065: App Recommend Stat Field Fix

audience: agent-facing

---

## Summary

Fixed homepage/recommend feed `ShieldCandidate` adapter so App recommendation items (`RcmdVideoItemAppModel`) populate `playbackCount` and `danmakuCount` from their already-parsed `RcmdStat` fields, just as Web recommendation items (`RcmdVideoItemModel`) already did. Previously these fields were left `null` for App items, causing playback-count and danmaku-count range rules to silently pass through (no match against `null`). Duration filtering already worked since it uses a direct field on the base model.

---

## Change Record

| File | Change |
|---|---|
| `lib/features/shielding/shielding_adapters.dart` | Added import for `RcmdVideoItemAppModel` from `result.dart`. Added `else if (item is RcmdVideoItemAppModel)` branch that reads `item.stat.view` and `item.stat.danmu` into `playbackCount` and `danmakuCount`, using the same RcmdStat fields already parsed from `cover_left_text_1` / `cover_left_text_2`. |
| `test/features/shielding/shielding_adapters_test.dart` | Updated the App recommendation test to expect `playbackCount == 12000` and `danmakuCount == 450` (was `isNull`). Updated the danmakuCount App end-to-end test to expect blocking (was visible). Added a new end-to-end test for playbackCount range rule blocking on App recommendation. |

### Detailed behavior change

**Before:** `ShieldingAdapters.fromRecommendationJson(item, ...)` where `item is RcmdVideoItemAppModel`:

| Candidate field | Value | Range rule effect |
|---|---|---|
| `durationSeconds` | `item.duration` (>0) | ✅ Rules could match |
| `playbackCount` | `null` | ❌ Range matcher skipped (`null` → no match → visible) |
| `danmakuCount` | `null` | ❌ Range matcher skipped (`null` → no match → visible) |

**After:**

| Candidate field | Value | Source |
|---|---|---|
| `durationSeconds` | `item.duration` (>0) | `player_args.duration` (unchanged) |
| `playbackCount` | `item.stat.view` | `RcmdStat` parsed from `cover_left_text_1` via `NumUtils.parseNum` |
| `danmakuCount` | `item.stat.danmu` | `RcmdStat` parsed from `cover_left_text_2` via `NumUtils.parseNum` |

Both range rules now correctly block App recommendation items matching their patterns.

---

## Files Changed (uncommitted on `task-071-keyword-contains-from-5134`)

- `lib/features/shielding/shielding_adapters.dart` — 3 lines added, 2 lines removed (net +1)
- `test/features/shielding/shielding_adapters_test.dart` — 50 lines added, 4 lines removed (net +46)

---

## Tests

**Command:** `flutter test test/features/shielding/shielding_adapters_test.dart` — could not run locally; Flutter/Dart SDK not available in this environment.

**CI evidence (previous commit):** On commit `2d79c59db` ("Implement task-065 homepage numeric shielding"), the `PiliAvalon CI` verify job reported **144 shielding tests passed**. At that commit the App adapter branch was not yet present; the test counted `null` expectations. The changes in this fix add +3 effective new assertions (playbackCount/danmakuCount populated, blocking behavior) and should not regress any passing test.

**Pre-existing CI issue:** The CI run at commit `7f73c7975` had an analyzer warning in `test/pages/setting/recommend_range_shielding_test.dart:5` (unused import preventing `analyze` from passing). This is unrelated to the shielding adapter fix. All 184 tests passed in that run.

---

## Verification

Manual code review confirms:

1. `RcmdVideoItemAppModel.stat` is `RcmdStat` (parsed at `result.dart:18`)
2. `RcmdStat.fromJson` parses `cover_left_text_1` → `view`, `cover_left_text_2` → `danmu` (lines 55-58)
3. The adapter now reads `item.stat.view` and `item.stat.danmu` for `RcmdVideoItemAppModel` items via an explicit `is` check, identical to the `RcmdVideoItemModel` pattern
4. The unused import + comment-admonition on the old behavior is replaced with the working code
5. Three test changes cover:
   - Unit: App model populates both numeric fields from parsed stat
   - Integration: danmakuCount range rule blocks App model
   - Integration: playbackCount range rule blocks App model

---

## Residual Risks

1. **No local test run executed** — Flutter SDK not available. CI must confirm the 144+ test count remains green.
2. **Edge case: `NumUtils.parseNum` returns `null`** — If `cover_left_text_1` is absent or unparseable, `view` stays `null`, which flows into `playbackCount` as `null`, and the range matcher treats `null` as no-match (visible). Same for `danmakuCount`. This matches the pre-existing behavior for Web items where `stat.view` could also be `null`. No regression.
3. **`NumUtils.parseNum` accuracy for display strings** — Values like "1.2万" parse to 12000. This is the same parsing already used for Web recommendation by the downstream `RecommendFilter`; no new parsing is introduced.

---

## Responds to

User manual acceptance failure reported: in the latest prerelease, playback-count and danmaku-count filtering did not work on the homepage/recommend feed, while duration filtering worked correctly. Root cause: the `ShieldCandidate` adapter omitted `RcmdVideoItemAppModel` from the `is` type-check chain that populates `playbackCount`/`danmakuCount`, leaving those fields `null` for App recommendation items. The fix adds the missing branch, reusing the already-parsed `RcmdStat.view` and `RcmdStat.danmu` fields.

---

## Commands Attempted

```
dart format lib/features/shielding/shielding_adapters.dart test/features/shielding/shielding_adapters_test.dart
  → exit 127 (dart: command not found)

flutter test test/features/shielding/shielding_adapters_test.dart
  → command not available
```

---

## Authority Boundary

- ✅ Bounded adapter edit completed
- ✅ Test updates completed
- ❌ No `git commit` or `git push` — uncommitted changes on `task-071-keyword-contains-from-5134`
- ❌ No CI green claimed — CI not re-run
- ❌ No release created
- ❌ No workflow files modified
- ❌ No governance/design-institute files modified

*Candidate evidence ready for Codex review.*
