---
audience: agent-facing
record_type: release-evidence
task: task-066
release_type: prebuild
status: published-pending-manual-acceptance
created: 2026-06-17
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
release_tag: task066-prebuild.27667066405
release_url: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task066-prebuild.27667066405
target_commit: acfc3a356d99765b444c849bc26ef4a1332c6ddb
target_version_code: 5162
---

# Task-066 +5162 Prebuild Release Evidence

## Summary

The task-066 Android validation prerelease has been published as
`task066-prebuild.27667066405`.

This is a `prebuild` for manual acceptance only. It is not a stable release and
does not close user/client acceptance.

## Release

- Title: `Task 066 Prebuild - Manual Acceptance`
- Tag: `task066-prebuild.27667066405`
- URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task066-prebuild.27667066405
- GitHub prerelease: `true`
- GitHub draft: `false`
- Target commit: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
- Derived versionCode: `5162`

## Branch And Source

- Repository: `CometDash77/PiliAvalon-Worksite`
- Branch at build time: `task-066-detail-intro-shielding`
- Target commit message: `Draft task-066 prebuild 5162 notes`
- Local confirmation:
  `git rev-list --count acfc3a356d99765b444c849bc26ef4a1332c6ddb` returned
  `5162`.

## Automation Evidence

- CI run:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27666656062
  - Workflow: `PiliAvalon CI`
  - Head SHA: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
  - Conclusion: `success`
- Prerelease build run:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27667066405
  - Workflow: `Build`
  - Head SHA: `acfc3a356d99765b444c849bc26ef4a1332c6ddb`
  - Conclusion: `success`

## Artifacts

No APK was downloaded locally. Artifact publication was verified through
GitHub Release metadata.

| APK | Size |
| --- | ---: |
| `PiliAvalon_android_2.0.8-acfc3a356+5162_arm64-v8a.apk` | 25,932,270 bytes |
| `PiliAvalon_android_2.0.8-acfc3a356+5162_armeabi-v7a.apk` | 25,847,903 bytes |
| `PiliAvalon_android_2.0.8-acfc3a356+5162_x86_64.apk` | 26,920,483 bytes |

All artifact names include `+5162`.

## Signing Evidence

The release body records the same SHA-256 signing fingerprint for all Android
APKs:

```text
0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051
```

## Evidence Chain

- Reasonix CI candidate report:
  `records/reasonix/task-066/ci-5162-monitor-report.md`
- Codex CI review:
  `records/codex/task-066/ci-5162-codex-review.md`
- Reasonix prerelease candidate report:
  `records/reasonix/task-066/prerelease-5162-monitor-report.md`
- Codex prerelease review:
  `records/codex/task-066/prerelease-5162-codex-review.md`
- Release notes:
  `records/session/2026-06-17-task066-prebuild-5162-release-notes.md`

## Manual Acceptance

Pending. This prebuild is ready for user/client validation only.

## Known Yellow Items

- Stable release approval remains open.
- Manual acceptance remains open.
- Cross-platform builds were intentionally not published.
- Task-074 derived metrics remain excluded.

## Rollback Path

- User-facing rollback: use
  `task065-app-stat-fix-prebuild.27460023543` or
  `task071-keyword-contains-prebuild.27394918307`.
- Code rollback: revert task-066 commits with forward history or publish a
  superseding fixed prebuild from a reviewed target.
- Release rollback: do not delete or supersede this prerelease without explicit
  approval and a recorded rollback reason.

## Command Scope Confirmation

All GitHub CLI commands used for CI, build, release view, and release edit were
scoped with `-R CometDash77/PiliAvalon-Worksite`.
