# Task-044 Reasonix Dispatch: Recommendation Integration

Audience classification: agent-facing

First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-044-recommendation-integration-implementer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-044-repeat-exposure-prefilter
review_owner: Codex
task_difficulty: hard/cross-cutting integration. Use deepseek-pro.
max_iterations: 1 implementation pass with self-review
max_time_minutes: 35
usd_cap: 1.50
expected_artifact_path: records/reasonix/task-044/integration-implementation-report.md

## Required Context

Read before editing:

- /home/mo/Documents/piliavalon/AGENTS.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-10-task044-repeat-exposure-prefilter-to-worksite.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md
- /home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-10-task042-repeat-exposure-prefilter-worksite-plan.md
- records/reasonix/task-044/core-review-report.md
- lib/features/exposure_tracker/exposure_tracker.dart
- lib/http/video.dart
- lib/common/widgets/video_card/video_card_v.dart
- lib/pages/rcmd/view.dart
- /home/mo/Documents/piliavalon/.reasonix/skills/flutter-official-skill-router.md
- /home/mo/Documents/piliavalon/.agents/skills/flutter-add-widget-test/SKILL.md

## Allowed Commands

- Read-only inspection: `git status --short`, `git diff -- ...`, `rg ...`, `sed -n ...`, `nl -ba ...`.
- File edits only within the Write Scope.

## Forbidden Actions

- Do not run local `flutter`, `dart`, dependency probes, formatters, or fixers. Verification is GitHub-only later.
- Do not push, merge, release, run workflows, edit GitHub Actions, or modify Design Institute files.
- Do not overwrite, revert, stage, commit, or format unrelated dirty live_room files.
- Do not modify core exposure tracker files in this slice unless there is a compile blocker directly caused by this integration.
- Do not add external dependencies.

## Write Scope

Modify only:

- lib/http/video.dart
- lib/common/widgets/video_card/video_card_v.dart
- lib/pages/rcmd/view.dart
- test/common/widgets/video_card/video_card_v_test.dart only if needed for deterministic callback coverage
- records/reasonix/task-044/integration-implementation-report.md

## Required Implementation

Implement Task 4 and Task 5 from the detailed plan:

1. In `VideoHttp.rcmdVideoList()`, after existing `RecommendationTagEnricher.enrichAndFilter(...)`, return:
   - `Success(ExposureTracker.instance.filterAndRecord(list, getBvid: (item) => item.bvid))`
2. In `VideoHttp.rcmdVideoListApp()`, do the same after tag enrichment.
3. Add optional `ValueChanged<String>? onRecommendationTapBvid` to `VideoCardV`.
4. In `VideoCardV.onPushDetail()`, in the `goto == 'av'` path only, invoke `onRecommendationTapBvid?.call(bvid)` immediately before `PageUtils.toVideoPage(...)`, only after a valid `cid` exists and the actual bvid has been resolved.
5. In `RcmdPage`, pass `onRecommendationTapBvid: ExposureTracker.instance.clearExposure` to both homepage recommendation `VideoCardV` constructors only.

## Required Behavior Gates

- This feature only serves the homepage recommendation feed.
- `filterAndRecord` has exactly two production call sites: both in `lib/http/video.dart`.
- `ExposureTracker.instance.clearExposure` has exactly one production call site: `lib/pages/rcmd/view.dart`.
- `onRecommendationTapBvid` is passed only in `lib/pages/rcmd/view.dart`.
- Do not add shared-card global click side effects for search, favorites, history, related videos, member pages, bangumi, picture, URI fallback, long-press, or popup menu.
- No local Flutter/Dart verification.

## Required Read-Only Scope Guard

Run and record:

```bash
rg -n "ExposureTracker|filterAndRecord|clearExposure|onRecommendationTapBvid" lib test
```

## Artifact Requirements

Write `records/reasonix/task-044/integration-implementation-report.md` with:

- status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
- files changed
- exact integration summary
- scope guard command output summary and exit code
- commands run and exact exit codes
- self-review against the behavior gates
- risks or follow-up needs for Codex

Use YOLO/edit-auto-free behavior for only the allowed write scope. Codex remains responsible for final review, GitHub verification, commits, pushes, releases, and gate judgment.
