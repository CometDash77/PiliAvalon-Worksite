# Task-044 Reasonix Dispatch: Settings Review

Audience classification: agent-facing

First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-044-settings-reviewer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-044-repeat-exposure-prefilter
review_owner: Codex
task_difficulty: medium/high settings and test review. Use deepseek-pro.
max_iterations: 1 review pass, with a narrow compile-risk fix only if clearly necessary
max_time_minutes: 30
usd_cap: 1.00
expected_artifact_path: records/reasonix/task-044/settings-review-report.md

## Required Context

Read before reviewing:

- /home/mo/Documents/piliavalon/AGENTS.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-10-task044-repeat-exposure-prefilter-to-worksite.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-10-task042-repeat-exposure-prefilter-worksite-plan.md
- records/reasonix/task-044/settings-implementation-report.md

## Review Scope

Review:

- lib/features/exposure_tracker/exposure_tracker_settings.dart
- lib/pages/setting/models/recommend_settings.dart
- test/pages/setting/models/recommend_settings_test.dart

## Allowed Commands

- Read-only inspection: `git diff -- ...`, `git status --short`, `rg ...`, `grep ...`, `sed -n ...`, `nl -ba ...`.
- Narrow file edit only if a visible compile-risk fix is clearly necessary in the review scope.

## Forbidden Actions

- Do not run local `flutter`, `dart`, dependency probes, formatters, or fixers. Verification is GitHub-only later.
- Do not push, merge, release, run workflows, edit GitHub Actions, or modify Design Institute files.
- Do not overwrite, revert, stage, commit, or format unrelated dirty live_room files.
- Do not modify API/card integration or core tracker files in this slice.
- Do not add external dependencies.

## Review Questions

1. Does the settings implementation match Task 6 and the approved design?
2. Does the feature remain default off?
3. Does the settings helper reuse existing `SettingsModel`, `SwitchModel`, `NormalModel`, and `_buildNumberInputModel` patterns?
4. Does the clear-cache setting call only `ExposureTracker.instance.clearAll()`?
5. Do tests clear all five new keys, assert the expected titles/subtitles, and update the count correctly?
6. Are existing tag enrichment setting semantics preserved?
7. Are there visible analyzer/compiler risks: missing imports, private helper type mismatch, invalid constructor arguments, const issues, long-line style risks, or uninitialized Hive boxes in tests?

## Required Read-Only Commands

Run and record:

```bash
grep -rn "repeatExposure\|exposureTrackerSettings\|重复曝光" lib/features/exposure_tracker lib/pages/setting/models test/pages/setting/models
```

```bash
git diff -- lib/features/exposure_tracker/exposure_tracker_settings.dart lib/pages/setting/models/recommend_settings.dart test/pages/setting/models/recommend_settings_test.dart
```

## Artifact Requirements

Write `records/reasonix/task-044/settings-review-report.md` with:

- status: PASS, PASS_WITH_FINDINGS, or FAIL
- files changed if a narrow fix was applied
- findings ordered by severity with file path and line number
- explicit answers to all review questions
- commands run and exact exit codes
- required fixes before GitHub verification, if any

Codex remains responsible for final judgment, commits, GitHub verification, releases, and gate judgment.
