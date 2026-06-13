---
audience: agent-facing
record_type: release-evidence
task: task-065
release_type: prebuild
status: manual-acceptance-pending
created: 2026-06-13
review_owner: Codex
---

# Task-065 App Stat Fix Prebuild 5149 Evidence

## Release

- Type: `prebuild`
- Tag: `task065-app-stat-fix-prebuild.27460023543`
- Title: `task065-app-stat-fix-prebuild.27460023543`
- URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-app-stat-fix-prebuild.27460023543
- GitHub release state: prerelease, not draft
- Published at: `2026-06-13T07:31:38Z`

## Branch / Commit

- Repository: `CometDash77/PiliAvalon-Worksite`
- Branch: `task-071-keyword-contains-from-5134`
- Commit: `1093b29be0a417663ca098188514d84875af7b13`
- Commit message: `Fix task-065 app recommendation stat shielding`
- Version: `2.0.8-1093b29be+5149`
- Version code: `5149`

## Automation Evidence

- CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27460023543
- CI conclusion: `success`
- Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27460282784
- Build conclusion: `success`
- Reasonix monitor report:
  `records/reasonix/2026-06-13/task-065-app-stat-fix-ci-build-monitor.md`
- Codex review record:
  `records/codex/review/2026-06-13-task-065-app-recommend-stat-field-fix-review.md`

## Attached Assets

- `PiliAvalon_android_2.0.8-1093b29be+5149_arm64-v8a.apk`
- `PiliAvalon_android_2.0.8-1093b29be+5149_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.8-1093b29be+5149_x86_64.apk`

## Scope Implemented

- Fixed App homepage/recommendation `ShieldCandidate` population for:
  - `playbackCount`
  - `danmakuCount`
- Reused already parsed `RcmdVideoItemAppModel.stat.view` and
  `RcmdVideoItemAppModel.stat.danmu`.
- Preserved existing duration filtering behavior.
- Preserved settings UI and matcher range semantics.
- Added no independent HTTP/API fetches, enrichment, cache, concurrency, or
  endpoint behavior.

## Manual Acceptance

- Status: pending.
- Previous prebuild `task065-inline-filters-prebuild.27459281224`
  (`2.0.8-3f793af31+5147`) failed manual acceptance because playback-count and
  danmaku-count filtering did not work on the user's App homepage path while
  duration filtering did work.
- This prebuild is available for user/client re-validation.
- Automation evidence proves CI/build/runtime-smoke success only.
- No user acceptance or no-new-bug acceptance is claimed yet.

## Known Risks / Still Yellow

- Manual acceptance remains open.
- Stable release was not created.
- Task-065 was not marked accepted.
- Only Android APKs were built for this prebuild.
- The GitHub release tag includes the CI run id (`27460023543`) because the
  build dispatch supplied that exact tag value.

## Rollback Plan

- Return to the last manually accepted clean baseline:
  `task071-keyword-contains-prebuild.27394918307`
- Baseline version: `2.0.8-b8106ac60+5136`

## Command Discipline

- Repo-scoped GitHub CLI commands used `-R CometDash77/PiliAvalon-Worksite`.
