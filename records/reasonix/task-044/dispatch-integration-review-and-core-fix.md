# Task-044 Reasonix Dispatch: Integration Review And Core Compile-Risk Fix

Audience classification: agent-facing

First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-044-integration-review-core-fix
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-044-repeat-exposure-prefilter
review_owner: Codex
task_difficulty: hard/cross-cutting review plus narrow fix. Use deepseek-pro.
max_iterations: 1 fix/review pass
max_time_minutes: 35
usd_cap: 1.50
expected_artifact_path: records/reasonix/task-044/integration-review-and-core-fix-report.md

## Required Context

Read before acting:

- /home/mo/Documents/piliavalon/AGENTS.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-10-task044-repeat-exposure-prefilter-to-worksite.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-10-task042-repeat-exposure-prefilter-worksite-plan.md
- records/reasonix/task-044/core-review-report.md
- records/reasonix/task-044/integration-implementation-report.md

## Allowed Commands

- Read-only inspection: `git diff -- ...`, `git status --short`, `rg ...`, `sed -n ...`, `nl -ba ...`.
- Narrow file edit only if needed for the compile-risk fix below.

## Forbidden Actions

- Do not run local `flutter`, `dart`, dependency probes, formatters, or fixers. Verification is GitHub-only later.
- Do not push, merge, release, run workflows, edit GitHub Actions, or modify Design Institute files.
- Do not overwrite, revert, stage, commit, or format unrelated dirty live_room files.
- Do not modify settings UI in this slice.
- Do not add external dependencies.

## Narrow Fix Scope

Codex coordinator observed a likely compile/analyzer risk in:

```dart
class HiveExposureTrackerBox implements ExposureTrackerBox {
  HiveExposureTrackerBox(this._box) : _box = _box;

  // ignore: unused_field — read via the typed getters below
  final dynamic _box;
```

This likely initializes a final field twice. Fix it narrowly in:

- lib/features/exposure_tracker/exposure_tracker_store.dart

Preferred fix: import `package:hive_ce/hive.dart`, type the field as `Box<ExposureRecord>`, and use:

```dart
class HiveExposureTrackerBox implements ExposureTrackerBox {
  HiveExposureTrackerBox(this._box);

  final Box<ExposureRecord> _box;
```

Then remove unnecessary dynamic casts in getters/methods where practical.

## Integration Review Scope

Review:

- lib/http/video.dart
- lib/common/widgets/video_card/video_card_v.dart
- lib/pages/rcmd/view.dart
- lib/features/exposure_tracker/exposure_tracker_store.dart only for the narrow fix above

## Review Questions

1. Do Tasks 4-5 match the plan and approved design?
2. Are `filterAndRecord` production call sites exactly the two homepage recommendation API paths?
3. Is `clearExposure` passed only from `RcmdPage` and nowhere else?
4. Does `VideoCardV` avoid global shared-card side effects when the callback is null?
5. Is the click callback only in the `goto == 'av'` path after a resolved bvid and valid cid?
6. Did the compile-risk fix remove the double initialization without changing behavior?
7. Are there visible analyzer/compiler risks from line formatting, import ordering, missing imports, signatures, or type mismatches?

## Required Read-Only Scope Guard

Run and record:

```bash
grep -rn "ExposureTracker\|filterAndRecord\|clearExposure\|onRecommendationTapBvid" lib test | grep -v "grpc/"
```

Also run and record:

```bash
grep -rn "HiveExposureTrackerBox" lib/features/exposure_tracker test/features/exposure_tracker
```

## Artifact Requirements

Write `records/reasonix/task-044/integration-review-and-core-fix-report.md` with:

- status: PASS, PASS_WITH_FINDINGS, or FAIL
- files changed by the fix
- findings ordered by severity with file path and line number
- explicit answers to the review questions
- scope guard output summary and exit code
- commands run and exact exit codes
- required fixes before settings work, if any

Use YOLO/edit-auto-free behavior only for the allowed narrow fix. Codex remains responsible for final judgment and GitHub verification.
