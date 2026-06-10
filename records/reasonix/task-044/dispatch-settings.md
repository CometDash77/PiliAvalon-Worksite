# Task-044 Reasonix Dispatch: Recommendation Settings

Audience classification: agent-facing

First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-044-recommendation-settings-implementer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-044-repeat-exposure-prefilter
review_owner: Codex
task_difficulty: medium/high UI model integration with tests. Use deepseek-pro.
max_iterations: 1 implementation pass with self-review
max_time_minutes: 35
usd_cap: 1.50
expected_artifact_path: records/reasonix/task-044/settings-implementation-report.md

## Required Context

Read before editing:

- /home/mo/Documents/piliavalon/AGENTS.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-10-task044-repeat-exposure-prefilter-to-worksite.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-10-task042-repeat-exposure-prefilter-worksite-plan.md
- records/reasonix/task-044/integration-review-and-core-fix-report.md
- lib/features/exposure_tracker/exposure_tracker.dart
- lib/pages/setting/models/recommend_settings.dart
- test/pages/setting/models/recommend_settings_test.dart
- /home/mo/Documents/piliavalon/.reasonix/skills/flutter-official-skill-router.md
- /home/mo/Documents/piliavalon/.agents/skills/flutter-add-widget-test/SKILL.md
- /home/mo/Documents/piliavalon/.agents/skills/dart-add-unit-test/SKILL.md

## Allowed Commands

- Read-only inspection: `git status --short`, `git diff -- ...`, `rg ...`, `grep ...`, `sed -n ...`, `nl -ba ...`.
- File edits only within Write Scope.

## Forbidden Actions

- Do not run local `flutter`, `dart`, dependency probes, formatters, or fixers. Verification is GitHub-only later.
- Do not push, merge, release, run workflows, edit GitHub Actions, or modify Design Institute files.
- Do not overwrite, revert, stage, commit, or format unrelated dirty live_room files.
- Do not modify API/card integration or core tracker files in this slice unless there is a compile blocker directly caused by settings.
- Do not add external dependencies.

## Write Scope

Create or modify only:

- lib/features/exposure_tracker/exposure_tracker_settings.dart
- lib/pages/setting/models/recommend_settings.dart
- test/pages/setting/models/recommend_settings_test.dart
- records/reasonix/task-044/settings-implementation-report.md

## Required Implementation

Implement Task 6 from the detailed plan:

1. Create `lib/features/exposure_tracker/exposure_tracker_settings.dart`.
2. Expose `exposureTrackerSettings({required buildNumberInputModel})` returning:
   - SwitchModel title `启用重复曝光过滤`, default false, key `repeatExposureFilterEnabled`.
   - Numeric entry `重复曝光统计窗口`, default 7, range 1-30, suffix `天`, key `repeatExposureWindowDays`.
   - Numeric entry `重复曝光阈值`, default 10, range 2-50, suffix `次`, key `repeatExposureThreshold`.
   - Numeric entry `重复曝光冷却期`, default 30, range 1-90, suffix `天`, key `repeatExposureCoolingDays`.
   - Cache status NormalModel title `重复曝光缓存状态`, showing `ExposureTracker.instance.cacheCount` and `activeCoolingCount`, with clear-cache confirmation calling `ExposureTracker.instance.clearAll()`.
3. Modify `recommend_settings.dart` to import the helper and spread the exposure tracker settings into `recommendSettings` near the existing tag cache settings.
4. Update `recommend_settings_test.dart`:
   - Clear the five repeat exposure keys in `setUp`.
   - Add tests for the five setting titles.
   - Add tests for default subtitles: `当前: 7天`, `当前: 10次`, `当前: 30天`.
   - Update total settings count from 12 to 17.

## Required Behavior Gates

- Feature remains default off.
- Settings use existing `SettingsModel`, `SwitchModel`, `NormalModel`, and `_buildNumberInputModel` patterns.
- No new external dependencies.
- The clear cache action clears only `ExposureTracker.instance.clearAll()`.
- Do not change existing tag enrichment settings semantics.
- No local Flutter/Dart verification.

## Artifact Requirements

Write `records/reasonix/task-044/settings-implementation-report.md` with:

- status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
- files changed
- exact settings summary
- updated test summary
- commands run and exact exit codes
- self-review against behavior gates
- risks or follow-up needs for Codex

Use YOLO/edit-auto-free behavior for only the allowed write scope. Codex remains responsible for final review, GitHub verification, commits, pushes, releases, and gate judgment.
