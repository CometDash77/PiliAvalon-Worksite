# Task-044 Reasonix Dispatch: Core Exposure Tracker

Audience classification: agent-facing

First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-044-core-exposure-tracker-implementer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-044-repeat-exposure-prefilter
review_owner: Codex
task_difficulty: hard/cross-cutting. This slice changes persistent storage, public tracker behavior, and tests, and must preserve governance boundaries. Use deepseek-pro.
max_iterations: 1 implementation pass with self-review
max_time_minutes: 45
usd_cap: 2.00
expected_artifact_path: records/reasonix/task-044/core-implementation-report.md

## Required Context

Read before editing:

- /home/mo/Documents/piliavalon/AGENTS.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-10-task044-repeat-exposure-prefilter-to-worksite.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-10-task042-repeat-exposure-prefilter-worksite-plan.md
- /home/mo/Documents/piliavalon/.reasonix/skills/flutter-official-skill-router.md
- /home/mo/Documents/piliavalon/.agents/skills/dart-add-unit-test/SKILL.md
- /home/mo/Documents/piliavalon/.agents/skills/dart-run-static-analysis/SKILL.md

## Allowed Commands

- Read-only inspection: `git status --short`, `git branch --show-current`, `git diff -- ...`, `rg ...`, `sed -n ...`
- File edits only within the files listed in Write Scope.
- Formatting only if available without Flutter/Dart SDK assumptions. Do not use local Flutter/Dart for verification.

## Forbidden Actions

- Do not run local `flutter test`, `flutter analyze`, `dart test`, `dart analyze`, `dart format`, `dart fix`, or dependency probes. The user stated this local machine has no Flutter environment; verification must happen on GitHub later.
- Do not push, merge, release, prerelease, run workflows, edit GitHub Actions, sync upstream, or modify Design Institute files.
- Do not overwrite, revert, stage, commit, or format unrelated dirty files:
  - lib/pages/live_room/controller.dart
  - lib/pages/live_room/view.dart
  - lib/pages/live_room/widgets/chat_panel.dart
  - lib/pages/live_room/widgets/header_control.dart
- Do not edit API integration, card callback, settings UI, or implementation report in this slice.
- Do not add external dependencies.

## Write Scope

Create or modify only:

- lib/features/exposure_tracker/exposure_tracker_models.dart
- lib/features/exposure_tracker/exposure_tracker_store.dart
- lib/features/exposure_tracker/exposure_tracker.dart
- lib/utils/storage.dart
- lib/utils/storage_key.dart
- test/features/exposure_tracker/exposure_tracker_store_test.dart
- test/features/exposure_tracker/exposure_tracker_test.dart
- records/reasonix/task-044/core-implementation-report.md

## Required Implementation

Implement Task 1, Task 2, and Task 3 from the detailed implementation plan:

- `ExposureRecord`, `ExposureTrackerConfig`, and manual Hive adapter with type id 30 unless a current repo conflict is found.
- `ExposureTrackerStore` with a small testable box interface, Hive box adapter, lazy cleanup, cooling expiry, counting-window expiry, active cooling count, clearExposure preserving cooling records, clearAll, and LRU eviction by oldest `lastExposedAt`.
- Public `ExposureTracker` singleton with synchronous `filterAndRecord`, `clearExposure`, `cacheCount`, `activeCoolingCount`, and `clearAll`.
- Independent Hive box name `exposure_tracker_v1` registered/opened in `GStorage`, included in compact/close/clear.
- Settings keys:
  - `repeatExposureFilterEnabled`
  - `repeatExposureWindowDays`
  - `repeatExposureThreshold`
  - `repeatExposureCoolingDays`
  - `repeatExposureMaxCacheSize`
- Focused tests covering:
  - config normalization clamps invalid values;
  - disabled config returns the same list object and writes nothing;
  - first exposure is kept and counted;
  - threshold crossing starts cooling and removes current item;
  - active cooling removes without incrementing;
  - cooling expiry resets counting;
  - counting-window expiry resets counting;
  - recommendation click clears non-cooling record;
  - recommendation click does not clear cooling record;
  - LRU eviction removes oldest `lastExposedAt`;
  - empty or missing BV is kept and not recorded.

## Required Behavior Gates

- Default off.
- Disabled feature writes nothing, deletes nothing, and performs no cleanup.
- Cooling clicks do not cancel cooling.
- `filterAndRecord()` must be synchronous.
- Empty or whitespace BV should be kept and not recorded.
- Keep the feature scoped to homepage recommendation integration later; do not add other call sites in this slice.

## Artifact Requirements

Write `records/reasonix/task-044/core-implementation-report.md` with:

- status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
- files changed
- summary of implemented behavior
- commands run and exact exit codes; if no Flutter/Dart commands were run, state that this was intentional due to GitHub-only verification
- self-review checklist against the behavior gates
- any risks or follow-up needs for Codex

Use YOLO/edit-auto-free behavior for only the allowed write scope so approval prompts do not stall. Codex remains responsible for final review, GitHub verification, commits, pushes, releases, and gate judgment.
