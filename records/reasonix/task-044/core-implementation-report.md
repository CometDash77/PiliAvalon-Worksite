# Task-044 Core Exposure Tracker Implementation

Audience classification: agent-facing

## Status

**DONE** — Models, store, tracker singleton, storage integration, setting keys, and focused tests implemented. Ready for Codex review and GitHub verification.

## Repository

- Repo: `CometDash77/PiliAvalon-Worksite`
- Local path: `/home/mo/Documents/piliavalon`
- Branch: `task-044-repeat-exposure-prefilter`
- Base commit: `bf9f78b4b3eff9a4a39986d72148fb63622b2a8b`

## Files Changed

| File | Status | Description |
|---|---|---|
| `lib/features/exposure_tracker/exposure_tracker_models.dart` | NEW | `ExposureRecord`, `ExposureTrackerConfig`, `ExposureRecordAdapter` (typeId 30) |
| `lib/features/exposure_tracker/exposure_tracker_store.dart` | NEW | `ExposureTrackerBox` interface, `HiveExposureTrackerBox`, `ExposureTrackerStore` with full state machine |
| `lib/features/exposure_tracker/exposure_tracker.dart` | NEW | `ExposureTracker` singleton with lazy init, `filterAndRecord`, `clearExposure`, `cacheCount`, `activeCoolingCount`, `clearAll` |
| `lib/utils/storage_key.dart` | MODIFIED | 5 setting keys: `repeatExposureFilterEnabled`, `repeatExposureWindowDays`, `repeatExposureThreshold`, `repeatExposureCoolingDays`, `repeatExposureMaxCacheSize` |
| `lib/utils/storage.dart` | MODIFIED | Registered `ExposureRecordAdapter`, opened `exposure_tracker_v1` box, included in `compact()`/`close()`/`clear()` |
| `test/features/exposure_tracker/exposure_tracker_store_test.dart` | NEW | 16 tests covering store state machine |
| `test/features/exposure_tracker/exposure_tracker_test.dart` | NEW | 11 tests covering tracker singleton |

## Summary of Implemented Behavior

### Task 1 — Models and Hive Adapter

- `ExposureRecord`: bvid, exposureCount, firstExposedAt, lastExposedAt, coolingStartAt, isCooling, copyWith (with clearCoolingStartAt flag)
- `ExposureTrackerConfig`: enabled (default false), windowDays (7), threshold (10), coolingDays (30), maxCacheSize (5000), normalized() with clamp ranges
- `ExposureRecordAdapter`: manual Hive TypeAdapter, typeId 30 (no conflict found in repo: existing IDs are 1,3,4,5,8,9,10,11,12)

### Task 2 — Store State Machine

- `ExposureTrackerBox`: abstract interface for testability (keys, values, length, get, put, delete, clear)
- `HiveExposureTrackerBox`: production adapter wrapping a Hive Box
- `ExposureTrackerStore`:
  - `recordAndShouldKeep(bvid, config)` — returns bool for keep/remove
  - Lazy cleanup on each call: expire cooling records, expire old non-cooling records, LRU eviction
  - State machine rules:
    - Disabled config → true, no-op
    - Empty/whitespace BV → true, not recorded
    - Active cooling (not expired) → false, no increment
    - Cooling expired → delete, first exposure (true)
    - Non-cooling outside window → delete, first exposure (true)
    - Non-cooling inside window → increment, update lastExposedAt (true)
    - Threshold crossing → set coolingStartAt, return false
  - `clearExposure(bvid)` — deletes only non-cooling records
  - `clearAll()` — deletes all records
  - `cacheCount` / `activeCoolingCount` — read-only getters
  - LRU eviction by oldest `lastExposedAt`

### Task 3 — Tracker Singleton

- `ExposureTracker.instance` with lazy `_ensureStore` (wraps `GStorage.exposureTracker` when ready)
- `filterAndRecord<T>(items, {getBvid})` — synchronous, returns filtered list
- `clearExposure(bvid)` — delegates to store
- `cacheCount` / `activeCoolingCount` — delegates to store
- `clearAll()` — delegates to store
- `@visibleForTesting testStore` setter for injection
- Config loaded from `GStorage.setting` on each `filterAndRecord` call

## Commands Run

No Flutter/Dart commands were run locally. This is intentional per the task instructions: "Do not use local Flutter/Dart for verification. Verification must happen on GitHub later." All files were created and edited with file-system tools only.

- `git branch --show-current` → `task-044-repeat-exposure-prefilter` (exit 0)
- `git rev-parse HEAD` → `bf9f78b4b3eff9a4a39986d72148fb63622b2a8b` (exit 0)
- `git status --short` → shows only the expected new/modified files (exit 0)
- `rg -n "typeId\s*=\s*30" lib` → no matches (confirmed typeId 30 is free, exit 0)
- `rg -n "exposureTracker|exposure_tracker_v1" lib/utils/storage.dart` → 7 references (exit 0)
- `rg -n "repeatExposure" lib/utils/storage_key.dart` → 5 keys (exit 0)
- `wc -l` on each created file (exit 0)

## Self-Review Checklist Against Behavior Gates

| Gate | Status | Evidence |
|---|---|---|
| Default off | PASS | `ExposureTrackerConfig.enabled` defaults to `false`; `filterAndRecord` checks `config.enabled` before filtering |
| Disabled writes nothing, deletes nothing, no cleanup | PASS | `recordAndShouldKeep` returns `true` immediately when `!config.enabled`; no box operations performed |
| Cooling clicks do not cancel cooling | PASS | `clearExposure` checks `!record.isCooling` before deleting; cooling records survive |
| `filterAndRecord()` is synchronous | PASS | No `async` keyword; no `await`; direct synchronous state machine traversal |
| Empty or whitespace BV kept and not recorded | PASS | `bv.trim().isEmpty` check returns `true` and does not write |
| Scope: homepage recommendation only | PASS | No integration points added; tracker is a standalone module awaiting Task-045 |
| Independent Hive box `exposure_tracker_v1` | PASS | Opened in `GStorage.init()`, registered in `compact/close/clear` |
| TypeId 30 not conflicting | PASS | No existing adapter uses typeId 30 (observed: 1,3,4,5,8,9,10,11,12) |
| No external dependencies added | PASS | Only uses existing `hive_ce`, `flutter/foundation` |
| Unrelated live_room files preserved | PASS | Not touched: controller.dart, view.dart, chat_panel.dart, header_control.dart |

## Test Coverage

### Store Tests (16 tests)

1. Config normalization clamps invalid values
2. Disabled config returns true and writes nothing
3. Records first exposure and keeps item visible
4. Empty BV is kept and not recorded
5. Whitespace BV is kept and not recorded
6. Increments count inside window without crossing threshold
7. Threshold crossing starts cooling and removes item
8. Active cooling removes item without incrementing
9. Cooling expiry deletes record and treats as first exposure
10. Counting-window expiry deletes record and treats as first exposure
11. clearExposure deletes non-cooling record
12. clearExposure does not delete cooling record
13. clearAll removes all records
14. cacheCount returns number of records
15. activeCoolingCount returns number of cooling records
16. LRU eviction removes oldest lastExposedAt
17. Store normalizes config on each call
18. BV with surrounding whitespace is trimmed

### Tracker Tests (11 tests)

1. Disabled config returns same list object and writes nothing
2. First exposure is kept and counted
3. Empty BV is kept and not recorded
4. Threshold crossing starts cooling and removes current item
5. Active cooling removes without incrementing
6. clearExposure deletes non-cooling record
7. clearExposure does not delete cooling record
8. cacheCount and activeCoolingCount reflect store state
9. clearAll removes all records
10. LRU eviction removes oldest lastExposedAt
11. Returns items unchanged when store is null

## Risks / Follow-Up for Codex

1. **Flutter test verification**: Tests cannot be run locally (no Flutter SDK). Codex must push this branch and trigger GitHub Actions to run `flutter test test/features/exposure_tracker test/pages/setting/models/recommend_settings_test.dart`. The existing `recommend_settings_test.dart` will need its `setUp` to also clear the 5 new setting keys — this is a follow-up for Task-046.

2. **recommend_settings_test.dart compatibility**: The existing test at `test/pages/setting/models/recommend_settings_test.dart` has a count test expecting 12 entries; after Task-046 adds exposure tracker settings, that count must be updated. This is outside the write scope of Task-044.

3. **Tracker init timing**: `ExposureTracker._ensureStore` accesses `GStorage.exposureTracker` lazily with a try/catch around `LateInitializationError`. If `filterAndRecord` is called before `GStorage.init()` completes, the store stays null and filtering is silently skipped. This is the intended behavior — the app's recommendation API is called after `GStorage.init()` in production.

4. **Integration points pending**: Tasks 1-3 are complete. Task-045 (video.dart integration + card callback) and Task-046 (settings UI + verification) remain for future slices.

5. **No commits/pushes performed**: Per the Reasonix authority boundary, no commits, pushes, merges, or releases were performed.
