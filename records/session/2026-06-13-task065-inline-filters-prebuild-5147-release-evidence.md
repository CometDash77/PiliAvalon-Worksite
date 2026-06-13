---
audience: agent-facing
record_type: release-evidence
task: task-065
release_type: prebuild
status: manual-acceptance-pending
created: 2026-06-13
review_owner: Codex
---

# Task-065 Inline Filters Prebuild 5147 Evidence

## Release

- Type: `prebuild`
- Tag: `task065-inline-filters-prebuild.27459281224`
- Title: `task065-inline-filters-prebuild.27459281224`
- URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-inline-filters-prebuild.27459281224
- GitHub release state: prerelease, not draft
- Published at: `2026-06-13T06:45:00Z`

## Branch / Commit

- Repository: `CometDash77/PiliAvalon-Worksite`
- Branch: `task-071-keyword-contains-from-5134`
- Commit: `3f793af3161e18fffd0ee27833eec170cf5ae346`
- Commit message: `Record task-065 inline filter CI evidence`
- Runtime code change commit: `50e9f28b8ae019d1060f0cec44951c243dcfbf3e`
- Version: `2.0.8-3f793af31+5147`
- Version code: `5147`

## Automation Evidence

- CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27458819019
- CI conclusion: `success`
- Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27459281224
- Build conclusion: `success`
- Reasonix CI monitor report: `records/reasonix/2026-06-13/task-065-inline-filters-github-ci-monitor.md`
- Reasonix prebuild monitor report: `records/reasonix/2026-06-13/task-065-inline-filters-prebuild-monitor.md`
- Codex review record: `records/codex/review/2026-06-13-task-065-recommend-settings-inline-entry-review.md`

## Attached Assets

- `PiliAvalon_android_2.0.8-3f793af31+5147_arm64-v8a.apk`
- `PiliAvalon_android_2.0.8-3f793af31+5147_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.8-3f793af31+5147_x86_64.apk`

## Scope Implemented

- Removed the user-facing `推荐流范围屏蔽` second-level entry from
  `推荐流设置`.
- Added first-level singleton settings items in `推荐流设置`:
  - `时长过滤`
  - `播放量过滤`
  - `弹幕量过滤`
- Hid upstream settings-page entries only:
  - `点赞率`
  - upstream `视频时长`
  - upstream `播放量`
- Preserved upstream storage keys, model factory, and `RecommendFilter`
  business logic.
- Mapped singleton UI thresholds onto existing range primitives:
  - `屏蔽 ≤ X` -> `..X`
  - `屏蔽 ≥ Y` -> `Y..`

## Manual Acceptance

- Status: pending.
- This prebuild is available for user/client validation.
- Automation evidence proves CI/build/runtime-smoke success only.
- No user acceptance or no-new-bug acceptance is claimed yet.

## Known Risks / Still Yellow

- Manual acceptance remains open.
- Stable release was not created.
- Task-065 was not marked accepted.
- The APK is built from the latest branch HEAD, which includes a CI evidence
  commit after the runtime code change commit.

## Rollback Plan

- Return to the last manually accepted clean baseline:
  `task071-keyword-contains-prebuild.27394918307`
- Baseline version: `2.0.8-b8106ac60+5136`

## Command Discipline

- Repo-scoped GitHub CLI commands used `-R CometDash77/PiliAvalon-Worksite`.
