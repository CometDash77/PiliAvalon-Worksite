---
audience: agent-facing
record_type: release-evidence
task: task-065
release_type: prebuild
status: manual-acceptance-pending
created: 2026-06-13
review_owner: Codex
---

# Task-065 Recommend Range Prebuild 5144 Evidence

## Release

- Type: `prebuild`
- Tag: `task065-ci-recheck-2-prebuild.27457599604`
- Title: `task065-ci-recheck-2-prebuild.27457599604`
- URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-ci-recheck-2-prebuild.27457599604
- GitHub release state: prerelease, not draft
- Published at: `2026-06-13T05:24:38Z`

## Branch / Commit

- Repository: `CometDash77/PiliAvalon-Worksite`
- Branch: `task-071-keyword-contains-from-5134`
- Commit: `dfdf9493b1f1837403c8999308b4b667b8baab45`
- Commit message: `Fix task-065 range settings test import`
- Version: `2.0.8-dfdf9493b+5144`
- Version code: `5144`

## Automation Evidence

- CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27457010889
- CI conclusion: `success`
- Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27457599604
- Build conclusion: `success`
- Reasonix monitor report: `records/reasonix/2026-06-13/task-065-recommend-range-github-monitor-2.md`
- Codex review record: `records/codex/review/2026-06-13-task-065-recommend-range-settings-entry-codex-review.md`

## Attached Assets

- `PiliAvalon_android_2.0.8-dfdf9493b+5144_arm64-v8a.apk`
- `PiliAvalon_android_2.0.8-dfdf9493b+5144_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.8-dfdf9493b+5144_x86_64.apk`

## Scope Implemented

- Removed `数值元数据` and `评论用户信息` entry points from the general `屏蔽规则` page.
- Hid numeric metadata and comment-user rule types from the general add-rule editor.
- Added `推荐流范围屏蔽` under `推荐流设置`.
- Added recommendation-scope range shielding for `duration`, `playbackCount`, and `danmakuCount`.
- Preserved multiple independent range rules, including lower-bounded, upper-bounded, and bounded ranges.

## Manual Acceptance

- Status: pending.
- This prebuild is available for user/client validation.
- Automation can only support the statement that no new known CI, build, or runtime-smoke failure was observed.
- A no-new-bug acceptance claim remains pending until the user validates the APK.

## Known Risks / Still Yellow

- User/client acceptance is not complete.
- Stable release was not created.
- Task-065 was not marked accepted.
- Scope intentionally excludes search, related videos, dynamic, comments, derived metrics, and new independent fetch/enrich behavior.

## Rollback Plan

- Return to the last clean manually accepted prerelease:
  `task071-keyword-contains-prebuild.27394918307`
- Baseline version: `2.0.8-b8106ac60+5136`

## Command Discipline

- Repo-scoped GitHub CLI commands used `-R CometDash77/PiliAvalon-Worksite`.
