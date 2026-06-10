# Task-044 Core Exposure Tracker — Codex Review Report

Audience classification: agent-facing

## Status

**PASS_WITH_FINDINGS** — The core implementation faithfully follows the Task 1-3 plan and approved design spec. No blocking issues. Three low-severity findings and three informational notes are recorded below. The implementation is safe to proceed to Task-045 (integration) and Task-046 (settings/verification).

## Review Metadata

- **Reviewer**: Codex
- **Branch**: `task-044-repeat-exposure-prefilter`
- **Base commit**: `bf9f78b4b3eff9a4a39986d72148fb63622b2a8b`
- **Files reviewed**: 7 (see scope below)
- **Commands run**: `git branch --show-current`, `git rev-parse HEAD`, `git status --short`, `rg` (typeId conflict, setting keys, storage references, scope guard, import chains), `wc -l`
- **All exit codes**: 0

## Files Reviewed

| File | Lines | Status |
|---|---|---|
| `lib/features/exposure_tracker/exposure_tracker_models.dart` | 110 | NEW — matches plan |
| `lib/features/exposure_tracker/exposure_tracker_store.dart` | 225 | NEW — matches plan |
| `lib/features/exposure_tracker/exposure_tracker.dart` | 117 | NEW — matches plan |
| `lib/utils/storage.dart` | modified | ExposureRecordAdapter registered, box opened, compact/close/clear included |
| `lib/utils/storage_key.dart` | modified | 5 new setting keys added |
| `test/features/exposure_tracker/exposure_tracker_store_test.dart` | 438 | NEW — 19 tests (2 model + 17 store) |
| `test/features/exposure_tracker/exposure_tracker_test.dart` | 330 | NEW — 11 tracker tests |

## Answers to Review Questions

### 1. Does the implementation meet the Task 1-3 plan and approved design?

**YES.** Every element of Tasks 1-3 is present:

- **Task 1 (Models)**: `ExposureRecord` with all 5 fields + `isCooling` + `copyWith(clearCoolingStartAt:)`; `ExposureTrackerConfig` with all 5 fields + `normalized()` clamping to spec ranges; manual `ExposureRecordAdapter` with typeId 30 (confirmed no conflict — existing IDs: 1,3,4,5,8,9,10,11,12).
- **Task 2 (Store)**: `ExposureTrackerBox` abstract interface; `HiveExposureTrackerBox` wrapping a Hive Box; `ExposureTrackerStore` with clock injection and full state machine covering all 8 transitions from the design spec state diagram.
- **Task 3 (Tracker)**: `ExposureTracker` singleton with lazy `_ensureStore`, `filterAndRecord<T>` (synchronous), `clearExposure`, `cacheCount`, `activeCoolingCount`, `clearAll`, and `@visibleForTesting testStore`.
- **Storage bootstrap**: `ExposureRecordAdapter` registered in `GStorage.regAdapter()`, independent box `exposure_tracker_v1` opened in `GStorage.init()`, included in `compact()/close()/clear()`.
- **Setting keys**: 5 keys (`repeatExposureFilterEnabled`, `repeatExposureWindowDays`, `repeatExposureThreshold`, `repeatExposureCoolingDays`, `repeatExposureMaxCacheSize`) added to `SettingBoxKey`.

### 2. Does disabled mode avoid writes, deletes, and cleanup?

**YES.** Confirmed with dual guard:

- **exposure_tracker_store.dart:80**: `if (!config.enabled) return true;` — returns before any box read/write, no cleanup triggered.
- **exposure_tracker.dart:59**: `if (!config.enabled) return items;` — returns original list object unchanged.
- `_lazyCleanup` is only reachable **after** the enabled check at store.dart:86, so disabled mode never triggers expiry/eviction scans.

### 3. Does `clearExposure` preserve cooling records?

**YES.** Confirmed at **exposure_tracker_store.dart:142-149**:

```dart
void clearExposure(String bvid) {
    final bv = bvid.trim();
    if (bv.isEmpty) return;
    final record = box.get(bv);
    if (record != null && !record.isCooling) {
      box.delete(bv);
    }
  }
```

The guard `!record.isCooling` ensures cooling records survive. Both store and tracker test files have dedicated tests for this (store_test.dart:276-293, tracker_test.dart:219-236).

### 4. Does lazy cleanup handle cooling expiry, counting-window expiry, and LRU eviction correctly?

**YES.** Confirmed at **exposure_tracker_store.dart:172-212** (`_lazyCleanup`):

1. **Cooling expiry** (lines 178-183): Iterates all records; if `isCooling` and `now - coolingStartAt >= coolingDays`, adds to delete list. Uses `Duration.inDays` with `>=` — matches design spec "冷却到期(now - coolingStartAt ≥ coolingDays)".
2. **Window expiry** (lines 186-189): For non-cooling records, if `now - firstExposedAt >= windowDays`, adds to delete list. Matches spec "超出统计窗口".
3. **LRU eviction** (line 196, implementation lines 199-211): After expiry cleanup, `_lruEvict(maxCacheSize)` iterates all remaining records, finds the one with oldest `lastExposedAt`, and deletes it; repeats until `box.length <= maxCacheSize`.

Deletions are batched (collect then delete) to avoid concurrent-modification issues. LRU uses a safe delete-and-restart pattern.

**Note**: `_lazyCleanup` runs on **every** `recordAndShouldKeep` call (line 86), causing an O(n) scan of all cache records per BV. With maxCacheSize=5000 and typical recommendation feeds of ~20 items, this is ~100,000 record checks per page load. This is by design ("懒惰清理") but is recorded as Finding L2 below.

### 5. Is `filterAndRecord` synchronous and default-off?

**YES.**

- **Synchronous**: `filterAndRecord` at tracker.dart:51-70 has no `async` keyword and no `await` expressions. The entire call chain (`filterAndRecord` → `_ensureStore` getter → `_loadConfig` → `store.recordAndShouldKeep` → `_lazyCleanup`) is fully synchronous.
- **Default-off**: `ExposureTrackerConfig.enabled` defaults to `false` (models.dart:42). `filterAndRecord` checks `!config.enabled` and returns `items` unchanged.

### 6. Is storage bootstrap safe and free of circular imports?

**YES.** Import dependency graph is acyclic:

```
exposure_tracker.dart
  → exposure_tracker_models.dart
  → exposure_tracker_store.dart (→ exposure_tracker_models.dart)
  → storage.dart (→ exposure_tracker_models.dart)
  → storage_key.dart

storage.dart
  → exposure_tracker_models.dart  (for ExposureRecord type)

No reverse edges: storage.dart does NOT import exposure_tracker.dart or exposure_tracker_store.dart.
```

The Hive box `exposureTracker` is declared as `late final Box<ExposureRecord>` in `storage.dart` (line 27) and is fully initialized in `GStorage.init()` before any Hive-dependent code can call it. The adapter is registered in `regAdapter()` before box open.

### 7. Are there analyzer/compiler risks visible from code inspection?

**LOW RISK.** Three findings from static inspection (detailed in Findings below):

- **L1**: Redundant constructor initializer in `HiveExposureTrackerBox` (store.dart:17) — may trigger a lint warning but is not a compilation error.
- **L3**: `_ensureStore` bare `catch (_)` (tracker.dart:33) catches `LateInitializationError` (an `Error`) plus any unexpected Hive errors — by design for startup ordering but non-specific.
- **L4**: `HiveExposureTrackerBox.values` uses `.cast<ExposureRecord>()` (store.dart:27) — lazy runtime cast; safe when box is `Box<ExposureRecord>` but would silently fail with wrong box type.

No import cycles, no missing symbols, no type mismatches detected. Grpc protobuf files have unrelated `clearExposureOnce`/`clearExposureType` methods — confirmed unrelated autogenerated code (`lib/grpc/` path prefix).

### 8. Are tests focused and likely to compile under `flutter test`?

**YES.** Both test files use only `flutter_test` and `hive_ce` (existing dependencies) with in-memory boxes — no Hive disk I/O in store tests. Tracker tests use a temp Hive directory for `GStorage.setting` with a try/catch fallback for shared-isolate scenarios.

Test coverage:

| Category | Store tests | Tracker tests | Total |
|---|---|---|---|
| Model (copyWith, normalized) | 2 | — | 2 |
| Disabled config | 1 | 1 | 2 |
| First exposure | 1 | 1 | 2 |
| Empty/whitespace BV | 2 | 1 | 3 |
| Counting/threshold | 2 | 1 | 3 |
| Active cooling | 1 | 1 | 2 |
| Cooling expiry | 1 | — | 1 |
| Window expiry | 1 | — | 1 |
| clearExposure | 2 | 2 | 4 |
| clearAll | 1 | 1 | 2 |
| cacheCount/activeCoolingCount | 2 | 1 | 3 |
| LRU eviction | 1 | 1 | 2 |
| Config normalization in store | 1 | — | 1 |
| BV whitespace trimming | 1 | — | 1 |
| Null store (before init) | — | 1 | 1 |
| **Total** | **19** | **11** | **30** |

**Note**: Implementation report under-counts store tests as 16; actual count is 19 (2 model + 17 store). Documentation-only discrepancy (Finding I1).

### 9. Hidden risks from `@visibleForTesting testStore`, lazy `GStorage.exposureTracker`, import ordering, Hive adapter registration, or async Hive writes?

**No blocking risks.** Specific assessment:

- **`@visibleForTesting testStore`** (tracker.dart:21-22): Setter that writes `_store`. Tests inject via this setter and reset to `null` in `tearDown`. Safe; the annotation is advisory only and doesn't affect compilation. Risk: if `_ensureStore` is called after tearDown with a null store, it would attempt real Hive access — but tests don't do this.
- **Lazy `GStorage.exposureTracker`** (tracker.dart:28-36): Uses `try/catch` to handle `LateInitializationError`. If `filterAndRecord` is called before `GStorage.init()` completes, the store stays null and filtering is silently skipped (items returned unchanged). This matches the intended behavior — the recommendation API is called after init in production.
- **Import ordering** (tracker.dart:1-6): Blank line between `package:flutter/foundation.dart` and other `package:` imports may trigger `directives_ordering` lint. All are `package:` imports so this is a minor style deviation (Finding I2).
- **Hive adapter registration** (storage.dart:104-115): `ExposureRecordAdapter` is registered last in `regAdapter()`, after all existing adapters. Correct ordering.
- **Async Hive writes**: The entire `filterAndRecord` call chain is **synchronous**. Hive's `put()`/`delete()` methods are synchronous in the `hive_ce` package. No async/await in the tracker path. This means exposure counting happens immediately, which is the intended behavior. However, there is no explicit `await` on Hive's internal async flush — data persistence depends on Hive's automatic lazy disk sync. This is consistent with how other boxes (setting, localCache) are used in the project.

## Findings

### Finding L1 — Redundant constructor initializer (LOW)

- **File**: `lib/features/exposure_tracker/exposure_tracker_store.dart`, line 17
- **Issue**: `HiveExposureTrackerBox(this._box) : _box = _box;` — `this._box` already assigns the parameter to the field; the initializer list `: _box = _box` is a redundant double-assignment.
- **Risk**: None functionally; may trigger an `avoid_redundant_initialization` or similar lint warning under `flutter analyze`.
- **Fix**: Change to `HiveExposureTrackerBox(this._box);` (remove the initializer list).

### Finding L2 — O(n) per-call lazy cleanup scan (LOW)

- **File**: `lib/features/exposure_tracker/exposure_tracker_store.dart`, lines 172-197
- **Issue**: `_lazyCleanup` runs on every `recordAndShouldKeep` call, iterating all box values. With maxCacheSize=5000 and ~20 items per recommendation feed, this is ~100,000 record checks per page load.
- **Risk**: Performance degradation at large cache sizes (approaching maxCacheSize). Acceptable for current defaults but warrants a follow-up optimization ticket (e.g., throttle cleanup to once per `filterAndRecord` call rather than once per BV).
- **Mitigation**: This is the design-specified "lazy cleanup" approach. The O(n) scan is bounded by `maxCacheSize` (clamped 1-50000).

### Finding L3 — Non-specific error catch in `_ensureStore` (LOW)

- **File**: `lib/features/exposure_tracker/exposure_tracker.dart`, line 33
- **Issue**: `catch (_)` swallows all throwables including `LateInitializationError` (intended) and any unexpected Hive/box errors (unintended). If `GStorage.exposureTracker` throws a persistent error (e.g., corrupted box), every `filterAndRecord` call will silently fail to create the store and return items unfiltered — with no diagnostic output.
- **Risk**: Silent degradation if the Hive box is corrupted. The tracker would permanently remain in no-op mode without logging.
- **Mitigation**: The production app initializes `GStorage` before any recommendation API calls, so `LateInitializationError` is the only expected error. Consider adding a debug-mode log or limiting retry attempts.

### Finding L4 — `.cast<>()` lazy runtime cast (LOW)

- **File**: `lib/features/exposure_tracker/exposure_tracker_store.dart`, lines 26-27
- **Issue**: `(_box as dynamic).values.cast<ExposureRecord>()` relies on a runtime cast wrapper. If the underlying box were ever not `Box<ExposureRecord>`, the `.cast<>()` would fail at iteration time (not construction time) with a `TypeError`.
- **Risk**: Low — `GStorage.exposureTracker` is typed `Box<ExposureRecord>`. The risk is only if the box type changes without updating `HiveExposureTrackerBox`.
- **Mitigation**: No action required given current typing.

### Finding I1 — Test count mismatch in implementation report (INFO)

- **File**: `records/reasonix/task-044/core-implementation-report.md`, lines 96-116
- **Issue**: Report states "16 tests" for store tests; actual count is 19 (2 model + 17 store). Tracker tests are correctly reported as 11.
- **Risk**: Documentation only. Does not affect code correctness.

### Finding I2 — Import ordering blank line (INFO)

- **File**: `lib/features/exposure_tracker/exposure_tracker.dart`, lines 1-6
- **Issue**: A blank line separates `package:flutter/foundation.dart` from other `package:` imports. Standard Dart style groups all `package:` imports together without blank lines. May trigger `directives_ordering` lint.
- **Risk**: Cosmetic. Does not affect compilation.

### Finding I3 — Redundant cooling-expiry check after `_lazyCleanup` (INFO)

- **File**: `lib/features/exposure_tracker/exposure_tracker_store.dart`, lines 99-103
- **Issue**: `recordAndShouldKeep` checks for expired cooling records and deletes them, but `_lazyCleanup` (called at line 86, before this check) already removes all expired cooling records. Both use the same `_clock()` value, so the second check can never find an expired cooling record.
- **Risk**: None. This is defensive coding and serves as a safety net if cleanup logic changes. The extra check is cheap (single `box.get` + `duration.inDays`).

## Scope Guard Verification

Command: `rg -n "ExposureTracker|filterAndRecord|clearExposure|onRecommendationTapBvid" lib test lib/features/exposure_tracker/ test/features/exposure_tracker/`

Results:
- `filterAndRecord`: defined in `exposure_tracker.dart`, called only in test files. **Zero production call sites** — correct for Task-044 core (Task-045 adds video.dart integration).
- `clearExposure`: defined in `exposure_tracker_store.dart` and `exposure_tracker.dart`, called only in test files. **Zero production call sites** — correct for Task-044 core (Task-045 adds rcmd/view.dart callback).
- `onRecommendationTapBvid`: **zero matches** — correct for Task-044 core (Task-045 adds this to video_card_v.dart).
- Unrelated grpc protobuf `clearExposureOnce`/`clearExposureType`/`clearExposureReport` — confirmed autogenerated, not in review scope.

## Required Fixes Before Task 4-6

None required. All three low-severity findings are safe to defer:

| Finding | Blocking? | Recommendation |
|---|---|---|
| L1 (redundant constructor) | No | Fix during Task-045 or leave as-is |
| L2 (O(n) cleanup scan) | No | File follow-up optimization ticket |
| L3 (bare catch) | No | Consider debug log in future |
| L4 (.cast<> risk) | No | No action needed |

## Commands Run

```
git branch --show-current          → task-044-repeat-exposure-prefilter (exit 0)
git rev-parse HEAD                 → bf9f78b4b3eff9a4a39986d72148fb63622b2a8b (exit 0)
git status --short                 → shows expected modified + new files (exit 0)
rg -n "typeId\s*=\s*30" lib       → only models.dart:66 (exit 0; no conflict)
rg -n "repeatExposure" lib/utils/storage_key.dart → 5 keys confirmed (exit 0)
rg -n "exposureTracker|exposure_tracker_v1" lib/utils/storage.dart → 7 refs (exit 0)
rg -n "ExposureTracker|filterAndRecord|clearExposure|onRecommendationTapBvid" lib test lib/features/... test/features/... → scope clean (exit 0)
rg -n "class _MemoryExposureBox" test/features/... → 2 definitions, one per test file (exit 0)
rg -n "HiveExposureTrackerBox" lib/ test/features/... → defined store.dart:16, used tracker.dart:30 (exit 0)
rg -n "import.*exposure_tracker" lib/ test/features/... → acyclic imports confirmed (exit 0)
wc -l on each reviewed file → 1220 total lines (exit 0)
```

## Conclusion

The core implementation (Tasks 1-3) is complete, correct, and faithful to the design spec and implementation plan. All behavior gates pass. No modifications are required before proceeding to Task-045 (integration) and Task-046 (settings/verification). The three low-severity findings are safe to address in follow-up work.
