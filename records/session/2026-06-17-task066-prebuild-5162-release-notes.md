---
audience: agent-facing
record_type: release-notes
task: task-066
release_type: prebuild
status: published-prerelease
created: 2026-06-17
updated: 2026-06-17
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
target_version_code: 5162
release_tag: task066-prebuild.27667066405
release_url: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task066-prebuild.27667066405
target_commit: acfc3a356d99765b444c849bc26ef4a1332c6ddb
---

# Task 066 Prebuild - Manual Acceptance

## Purpose

Validation-only Android prebuild for task-066 detail-introduction metadata
shielding. This is not a stable release and does not close user/client manual
acceptance.

## Release Type

`prebuild`

Manual acceptance remains pending. This package is intended for user/client
validation after GitHub CI and Android prerelease build evidence at exact
`+5162` passed.

## Branch / Commit / Tag

- Repository: `CometDash77/PiliAvalon-Worksite`
- Branch: `task-066-detail-intro-shielding`
- Commit: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
- Commit message: `Draft task-066 prebuild 5162 notes`
- Derived versionCode: `5162`
- Tag: `task066-prebuild.27667066405`
- Release URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task066-prebuild.27667066405

## Related PRs / Issues

- Task: `task-066`
- Fresh source verification:
  `records/reasonix/task-066/source-verification-report-v2.md`
- Codex source verification review:
  `records/codex/task-066/source-verification-codex-review-v2.md`
- +5162 CI monitor candidate evidence:
  `records/reasonix/task-066/ci-5162-monitor-report.md`
- +5162 prerelease monitor candidate evidence:
  `records/reasonix/task-066/prerelease-5162-monitor-report.md`
- Codex +5162 CI review:
  `records/codex/task-066/ci-5162-codex-review.md`
- Codex +5162 prerelease review:
  `records/codex/task-066/prerelease-5162-codex-review.md`

## Automation Evidence

- `PiliAvalon CI` run:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27666656062
  - Event: `workflow_dispatch`
  - Branch: `task-066-detail-intro-shielding`
  - Head SHA: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
  - Derived versionCode: `5162`
  - Conclusion: `success`
  - Passed jobs:
    - `Focused Flutter verification`
    - `Build Android x86_64 artifact`
    - `Android emulator runtime smoke`
- `Build` prerelease run:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27667066405
  - Event: `workflow_dispatch`
  - Branch: `task-066-detail-intro-shielding`
  - Head SHA: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
  - Derived versionCode: `5162`
  - Conclusion: `success`
  - Passed release job: `Release Android`

The prerelease build was not downloaded locally. Codex verified the build basis
through GitHub Actions metadata, release target metadata, asset names, and the
local commit count for the release target commit.

## Manual Acceptance

Pending.

This prebuild is ready for user/client validation only. It is not a stable
release and does not close manual acceptance.

## Changes

- Adds first-batch detail-introduction shielding metadata support:
  - introduction/description text
  - publish time
  - staff/creative team keyword
  - Upower/charging-exclusive state
- Adds an independent related-video shielding switch titled `相关视频屏蔽`.
- Keeps legacy `RecommendFilter.applyFilterToRelatedVideos` separate and
  unchanged.
- Keeps video-detail related videos on the shared `ShieldMatcher` /
  `ShieldRuleSet` / list-filter path.
- Keeps homepage/ranking `filterRecommendationVideos` behavior separate from
  video-detail `filterRelatedVideos`.
- Excludes dimension, aspect ratio, portrait/landscape, and task-074 derived
  metrics from task-066.

## Known Risks

- Manual acceptance is still pending.
- Android is the only platform published for this prerelease.
- Cross-platform behavior is not covered by this prebuild.
- The GitHub Release body was updated after the workflow-created prerelease to
  include this governance-complete note set; artifacts and release target
  remain the original `+5162` build output.

## Sources / License / Attribution

No new external source code, assets, or third-party libraries were copied. The
work reuses existing project shielding infrastructure and GitHub Actions
release infrastructure.

## Android Signing Evidence

- Run ID: `27667066405`
- Commit: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
- Version: `2.0.8-acfc3a356+5162`

| APK | SHA-256 fingerprint |
| --- | --- |
| `PiliAvalon_android_2.0.8-acfc3a356+5162_arm64-v8a.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| `PiliAvalon_android_2.0.8-acfc3a356+5162_armeabi-v7a.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| `PiliAvalon_android_2.0.8-acfc3a356+5162_x86_64.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |

Cover-install verification requires:

- Same applicationId: `com.example.piliplus`
- Same signing certificate fingerprint as the installed release
- Install over existing app without uninstall

## Rollback Plan

- User-facing rollback: return to the latest accepted task-065 package
  `task065-app-stat-fix-prebuild.27460023543` or the prior no-bug baseline
  `task071-keyword-contains-prebuild.27394918307`.
- Code rollback: revert task-066 commits on
  `task-066-detail-intro-shielding` with forward history, or create a
  superseding fixed task-066 prebuild.
- Release rollback: mark this prerelease superseded or delete it only with
  explicit approval and recorded rollback reason, then publish a corrected
  prebuild from a reviewed target.

## Not Covered / Still Yellow

- Stable release approval is not covered.
- Manual acceptance is not covered.
- Cross-platform builds are not covered.
- Task-074 derived metrics remain excluded.

## User Action Required

Install the appropriate Android APK from the GitHub prerelease and validate
task-066 behavior. Do not use earlier diagnostic builds for acceptance.
