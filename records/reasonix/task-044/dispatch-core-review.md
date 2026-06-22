# Task-044 Reasonix Dispatch: Core Exposure Tracker Review

Audience classification: agent-facing

First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-044-core-exposure-tracker-reviewer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-044-repeat-exposure-prefilter
review_owner: Codex
task_difficulty: hard/cross-cutting review. Use deepseek-pro.
max_iterations: 1 review pass
max_time_minutes: 30
usd_cap: 1.00
expected_artifact_path: records/reasonix/task-044/core-review-report.md

## Required Context

Read before reviewing:

- /home/mo/Documents/piliavalon/AGENTS.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-10-task044-repeat-exposure-prefilter-to-worksite.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-10-task042-repeat-exposure-prefilter-worksite-plan.md
- records/reasonix/task-044/core-implementation-report.md

## Review Scope

Review only the core slice:

- lib/features/exposure_tracker/exposure_tracker_models.dart
- lib/features/exposure_tracker/exposure_tracker_store.dart
- lib/features/exposure_tracker/exposure_tracker.dart
- lib/utils/storage.dart
- lib/utils/storage_key.dart
- test/features/exposure_tracker/exposure_tracker_store_test.dart
- test/features/exposure_tracker/exposure_tracker_test.dart

## Allowed Commands

- Read-only commands only: `git diff -- ...`, `git status --short`, `rg ...`, `sed -n ...`, `nl -ba ...`.
- Do not edit files.

## Forbidden Actions

- Do not run local `flutter`, `dart`, dependency probes, formatters, or fixers. Verification is GitHub-only later.
- Do not push, merge, release, run workflows, edit GitHub Actions, or modify Design Institute files.
- Do not touch unrelated dirty live_room files.

## Review Questions

1. Does the implementation meet the Task 1-3 plan and approved design?
2. Does disabled mode avoid writes, deletes, and cleanup?
3. Does `clearExposure` preserve cooling records?
4. Does lazy cleanup handle cooling expiry, counting-window expiry, and LRU eviction correctly?
5. Is `filterAndRecord` synchronous and default-off?
6. Is storage bootstrap safe and free of circular imports?
7. Are there analyzer/compiler risks visible from code inspection?
8. Are tests focused and likely to compile under `flutter test`?
9. Are there hidden risks from `@visibleForTesting testStore`, lazy `GStorage.exposureTracker`, import ordering, Hive adapter registration, or async Hive writes?

## Artifact Requirements

Write `records/reasonix/task-044/core-review-report.md` with:

- status: PASS, PASS_WITH_FINDINGS, or FAIL
- findings ordered by severity, each with file path and line number
- explicit answers to the review questions
- any required fixes before proceeding to Task 4-6
- commands run and exact exit codes

Codex remains responsible for final judgment and integration.
