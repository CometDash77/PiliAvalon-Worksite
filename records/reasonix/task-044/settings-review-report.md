# Task-044 Settings Review Report

Audience classification: agent-facing

## Status

**PASS** — No findings that block merging. All 7 review questions are satisfied with file:line evidence.

## Files Changed (if narrow fix applied)

None — no compile-risk fixes were needed.

## Review Answers

### Q1: Design/Plan Match

**PASS** — The settings implementation (`exposure_tracker_settings.dart`) matches both the approved design spec and Task 6 of the implementation plan exactly.

| Spec/Plan Requirement | Implementation | Evidence |
|---|---|---|
| Switch toggle (默认 off) | `const SwitchModel(title: '启用重复曝光过滤', ..., defaultVal: false)` | `exposure_tracker_settings.dart:22-28` |
| 统计窗口 (默认 7 天, 1-30) | `buildNumberInputModel(title: '重复曝光统计窗口', defaultVal: 7, min: 1, max: 30, suffix: '天')` | `exposure_tracker_settings.dart:29-37` |
| 曝光阈值 (默认 10 次, 2-50) | `buildNumberInputModel(title: '重复曝光阈值', defaultVal: 10, min: 2, max: 50, suffix: '次')` | `exposure_tracker_settings.dart:38-46` |
| 冷却过滤期 (默认 30 天, 1-90) | `buildNumberInputModel(title: '重复曝光冷却期', defaultVal: 30, min: 1, max: 90, suffix: '天')` | `exposure_tracker_settings.dart:47-55` |
| 缓存状态 + 清除按钮 | `NormalModel(title: '重复曝光缓存状态', getSubtitle: ..., onTap: ...)` with AlertDialog and `clearAll()` | `exposure_tracker_settings.dart:56-90` |
| Integration: import + spread | `import '...exposure_tracker_settings.dart'` + `...exposureTrackerSettings(buildNumberInputModel: _buildNumberInputModel)` | `recommend_settings.dart:1,155` |
| Settings code in `lib/features/exposure_tracker/` | File path: `lib/features/exposure_tracker/exposure_tracker_settings.dart` | git diff confirms new file |

Design spec lists exactly 6 UI elements (switch + 3 number inputs + cache status + clear). Implementation has exactly 5 entries producing those 6 UI elements (the 5th entry combines cache status display and clear button). The `maxCacheSize` key exists in `storage_key.dart:164` and `ExposureTrackerConfig` but has no dedicated settings UI widget — consistent with the design spec which omits it from the Settings UI section. PASS.

### Q2: Default Off

**PASS** — The `SwitchModel` for the feature toggle has `defaultVal: false` at `exposure_tracker_settings.dart:27`. This matches the design spec ("默认 off") and the plan (Step 3, line 1296: `defaultVal: false`). The `ExposureTracker._loadConfig()` at `exposure_tracker.dart:97` also defaults `repeatExposureFilterEnabled` to `false`. The feature is default-off at both the settings model and tracker config layers.

### Q3: Pattern Reuse

**PASS** — The implementation correctly reuses the existing `SettingsModel`, `SwitchModel`, `NormalModel`, and `_buildNumberInputModel` patterns:

- **`SwitchModel`**: `const SwitchModel(title: '启用重复曝光过滤', subtitle: '...', leading: Icon(...), setKey: ..., defaultVal: false)` at `exposure_tracker_settings.dart:22-28`. The `SwitchModel` constructor at `model.dart:168-179` accepts all these as named parameters. Title is `required String` named param (not positional). Usage is correct.

- **`NormalModel`**: Used in two patterns:
  - Via `_buildNumberInputModel`: `NormalModel(title:, leading: Icon(icon), getSubtitle:, onTap:)` at `recommend_settings.dart:168-220`. Constructor at `model.dart:116-126` accepts all named params. PASS.
  - Cache status: `NormalModel(title: '重复曝光缓存状态', leading: const Icon(...), getSubtitle: () {...}, onTap: (context, setState) {...})` at `exposure_tracker_settings.dart:56-90`. Not marked `const` (correct — contains closures). PASS.

- **`_buildNumberInputModel`**: The private helper at `recommend_settings.dart:158-221` has signature matching the typedef `ExposureNumberInputModelBuilder` at `exposure_tracker_settings.dart:8-17` field-for-field. The spread at `recommend_settings.dart:155` passes `buildNumberInputModel: _buildNumberInputModel`. No duplicate implementation. PASS.

- **`exposureTrackerSettings`** signature: `List<SettingsModel> exposureTrackerSettings({required ExposureNumberInputModelBuilder buildNumberInputModel})` returns `List<SettingsModel>`. The spread `...exposureTrackerSettings(...)` in `recommendSettings` correctly expands into the list literal at `recommend_settings.dart:155`. PASS.

### Q4: Clear-Cache Scope

**PASS** — The clear-cache `onPressed` callback at `exposure_tracker_settings.dart:77-84` calls only:
1. `ExposureTracker.instance.clearAll()`
2. `Get.back()`
3. `setState()`
4. `SmartDialog.showToast('重复曝光缓存已清空')`

No other systems, boxes, or cleanup logic are invoked. `ExposureTracker.clearAll()` at `exposure_tracker.dart:87` delegates to `_ensureStore?.clearAll()` which clears only the `exposure_tracker_v1` Hive box. The shielding system, recommendation filter, tag enricher, and other subsystems are not touched. PASS.

### Q5: Test Coverage

**PASS** — The test file at `recommend_settings_test.dart` covers all required areas:

- **setUp clears all 5 new keys** (lines 25-29): `repeatExposureFilterEnabled`, `repeatExposureWindowDays`, `repeatExposureThreshold`, `repeatExposureCoolingDays`, `repeatExposureMaxCacheSize`. All 5 are deleted alongside the 3 existing tag enrichment key deletions.

- **New test: titles** (lines 135-144): Asserts `effectiveTitle` contains all 5 Chinese titles: `启用重复曝光过滤`, `重复曝光统计窗口`, `重复曝光阈值`, `重复曝光冷却期`, `重复曝光缓存状态`.

- **New test: default values** (lines 146-167): Asserts subtitles for the 3 numeric entries:
  - `重复曝光统计窗口` → `contains('当前: 7天')`
  - `重复曝光阈值` → `contains('当前: 10次')`
  - `重复曝光冷却期` → `contains('当前: 30天')`

- **Count update** (line 132): Changed from `expect(list.length, 12)` to `expect(list.length, 17)`. 12 + 5 = 17. PASS.

- **Cache status subtitle NOT tested** — the cache status `getSubtitle` calls `ExposureTracker.instance` which accesses the `exposure_tracker_v1` Hive box. The test only opens the `setting` box, not `exposure_tracker_v1`. The `ExposureTracker._ensureStore` catch block at `exposure_tracker.dart:33` safely returns null, so `cacheCount`/`activeCoolingCount` return 0, producing `0 条记录，0 条冷却中`. This is correct behavior and the lack of an assertion on this subtitle is a deliberate scope choice (acknowledged in prior implementation report risk #2). Not a blocking issue.

### Q6: Tag Enrichment Semantics Preserved

**PASS** — The git diff confirms only two additions to `recommend_settings.dart`:
1. `+import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_settings.dart';` (line 1)
2. `+  ...exposureTrackerSettings(buildNumberInputModel: _buildNumberInputModel),` (line 155, after tag cache NormalModel)

No existing lines were modified. The tag enrichment settings entries (lines 91-154: concurrency, timeout, cache limit, cache status with `RecommendationTagEnricher`), `_buildNumberInputModel` private function (lines 158-221), and all other existing settings remain byte-for-byte unchanged. PASS.

### Q7: Analyzer/Compiler Risks

**PASS** — Systematic review of all potential risk categories:

| Risk Category | Verdict | Evidence |
|---|---|---|
| Missing imports | ✅ Safe | All 6 imports in `exposure_tracker_settings.dart` are existing project dependencies. `recommend_settings.dart` already imports `model.dart`, `storage_key.dart`, `flutter/material.dart`, `flutter_smart_dialog`, `get/get.dart`. |
| Typedef/signature mismatch | ✅ Safe | `ExposureNumberInputModelBuilder` at `exposure_tracker_settings.dart:8-17` matches `_buildNumberInputModel` at `recommend_settings.dart:158-221` field-for-field. |
| SwitchModel constructor args | ✅ Safe | `title` is `required String` named param at `model.dart:175`. Usage: `title: '启用重复曝光过滤'` at line 23. `setKey` is `required String` at line 176. `defaultVal` defaults to `false` at line 177. All correct. |
| NormalModel constructor args | ✅ Safe | All params are named at `model.dart:116-126`. `title` and `getSubtitle`/`getTitle` assertions satisfied. |
| const correctness | ✅ Safe | `const SwitchModel(...)` with `Icon(Icons.visibility_off_outlined)` — in const context, `Icon` constructor is implicitly const since `Icons.visibility_off_outlined` is a static const. `NormalModel` for cache status is NOT marked `const` (closures prevent it) — correct. |
| Long-line style | ✅ Safe | Longest line is ~80 chars visually (Chinese substrings). No dartsdk line-length violations expected. |
| Hive box in test | ✅ Safe | Test `setUpAll` opens only `setting` box. `ExposureTracker._ensureStore` catch block at `exposure_tracker.dart:33` safely handles the missing `exposure_tracker_v1` box. Tests that touch default values don't depend on `ExposureTracker.instance`. |
| Transitive dependency | ✅ Safe | `exposure_tracker_settings.dart` imports `exposure_tracker.dart` → `exposure_tracker_store.dart` + `exposure_tracker_models.dart` → `hive_ce`. No new external package dependencies. |
| `Get.back` tear-off | ✅ Safe | `onPressed: Get.back` at line 71 mirrors the existing pattern at `recommend_settings.dart:135`. `Get.back` accepts all-optional named parameters. |
| `ColorScheme.of(ctx)` | ✅ Safe | Imported via `package:flutter/material.dart` at line 4. |

**No compile-risk fixes needed.** All constructors, types, imports, and patterns are consistent with the existing codebase.

## Findings

Ordered by severity:

1. **INFO** — `maxCacheSize` key has no settings UI widget. The `repeatExposureMaxCacheSize` key is defined in `storage_key.dart:164`, read by `ExposureTracker._loadConfig()` at `exposure_tracker.dart:111-114`, and cleared in test `setUp` at `recommend_settings_test.dart:29`. But no number-input settings entry is created for it. The design spec Settings UI section does not list a maxCacheSize control, and the plan Task 6 Step 3 only includes 5 entries (none for maxCacheSize). This is consistent with the design — `maxCacheSize` defaults to 5000 and is a stored-but-not-user-exposed config. Not a bug.

2. **INFO** — Cache status subtitle not validated in test. The `NormalModel` at `exposure_tracker_settings.dart:56-62` uses `getSubtitle` calling `ExposureTracker.instance`. The test at `recommend_settings_test.dart` does not assert this subtitle because it depends on the `exposure_tracker_v1` Hive box which is not opened in the test environment. The `ExposureTracker._ensureStore` catch block at `exposure_tracker.dart:33` safely degrades. This is a scope choice acknowledged in the prior implementation report. Not a bug.

3. **INFO** — `leading: Icon(Icons.visibility_off_outlined)` added to SwitchModel beyond plan template. The plan Step 3 template at line 1294 omits the `leading` field for the SwitchModel. The implementation adds it. This is a cosmetic improvement and does not affect functionality. Not a bug.

## Commands Run

```
Command: grep -rn "repeatExposure\|exposureTrackerSettings\|重复曝光" lib/features/exposure_tracker lib/pages/setting/models test/pages/setting/models
Exit code: 0
Output: 32 lines across 3 files (listed in Q1-Q7 evidence above)
Summary: All references are to the expected 5 setting keys, 5 titles, and the exposureTrackerSettings function. No cross-contamination into shielding or other subsystems.

Command: git -C /home/mo/Documents/piliavalon diff -- lib/features/exposure_tracker/exposure_tracker_settings.dart lib/pages/setting/models/recommend_settings.dart test/pages/setting/models/recommend_settings_test.dart
Exit code: 0
Output: 2 files changed, 42 insertions(+), 1 deletion(-)
Files: recommend_settings.dart (+2 lines: import + spread), recommend_settings_test.dart (+36/-1 lines: 5 key clears, 2 new tests, count 12→17)
Note: exposure_tracker_settings.dart is a new untracked file (91 lines) — not in git diff.

Command: git -C /home/mo/Documents/piliavalon branch --show-current
Exit code: 0
Output: task-044-repeat-exposure-prefilter
```

## Required Fixes Before GitHub Verification

None. The implementation is correct as-is. All constructors match their definitions, imports are complete, tests cover the required assertions, and no existing code was modified beyond the 2-line addition in `recommend_settings.dart`.
