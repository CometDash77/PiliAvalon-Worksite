# Task-042 5122 Repeat Exposure Prebuild - Manual Acceptance Start

**audience classification:** agent-facing

## Purpose

This GitHub prerelease is a user-installable Android validation package for the Task-042 homepage recommendation repeat-exposure prefilter rebuilt from the accepted `+5122` baseline. It is not a stable release and not latest.

The previous wrong-base prerelease `task042-repeat-exposure-prebuild.27260059861` was deleted and must not be used for acceptance evidence.

## Release Type

`prebuild`

## Branch / Commit / Tag

- Correct baseline release: `issue-8-player-controls-fix-build.27188216292`
- Correct baseline commit: `aef06bd7ed94a67dffa45dbee484f6ef46339df5`
- Correct baseline APK/version family: `2.0.8-aef06bd7e+5122`
- Branch: `task-042-repeat-exposure-prefilter-from-5122`
- Commit: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
- Tag: `task042-5122-prebuild.27263751328`
- Release URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task042-5122-prebuild.27263751328
- Version: `2.0.8-ba9d4569e+5134`

## Related PRs / Issues

- Parent task: `task-042`
- Rebuild reason: old Task-042 prerelease was built from the wrong base and was removed before this release.
- Correct baseline acceptance package: `issue-8-player-controls-fix-build.27188216292`
- Design spec: `/home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-10-task042-repeat-exposure-prefilter-design.md`

## Automation Evidence

- Task 044 focused verification: success
  - Run ID: `27263295760`
  - URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27263295760
  - Head SHA: `f504c6f0941dbd478b0fe3ebc618a9198f2cda83`
  - Covered: focused exposure tracker tests, `flutter analyze`, and scope grep.
- Android-only Build: success
  - Run ID: `27263751328`
  - URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27263751328
  - Head SHA: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
  - Android job: `Release Android`
  - Non-Android jobs: skipped by dispatch inputs.
- Android Runtime Smoke: success
  - Run ID: `27264338846`
  - URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27264338846
  - Head SHA: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
  - Artifact source run: `27263751328`
  - Covered: GitHub Actions artifact download of the x86_64 APK, emulator install/launch smoke, and evidence upload.
  - Smoke result: `status=0`, `result=pass`

Release APK assets:

- `PiliAvalon_android_2.0.8-ba9d4569e+5134_arm64-v8a.apk`
- `PiliAvalon_android_2.0.8-ba9d4569e+5134_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.8-ba9d4569e+5134_x86_64.apk`

Signing fingerprint for all release APKs:

`0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

Cover-install verification requires:

- same applicationId: `com.example.piliplus`
- same signing certificate fingerprint as the installed release
- install over existing app without uninstall

## Manual Acceptance

Pass. The user reported no issue after manual acceptance of this corrected `+5122` prerelease.

Raw user feedback preserved verbatim:

```text
no issue
```

## Changes

- Adds a default-off homepage recommendation repeat-exposure filter.
- Tracks homepage recommendation BV exposure in an independent exposure tracker cache.
- Filters repeated unclicked homepage recommendation BVs after the configured threshold.
- Keeps active cooling records from being cleared by clicks.
- Adds repeat-exposure settings entries and cache/cooling status visibility.
- Wires exposure clearing only from homepage recommendation card taps.
- Keeps search, favorites, history, related videos, member pages, and other non-homepage channels outside this exposure-clearing path.

## Known Risks

- This is a prebuild validation package, not a stable/latest release.
- Runtime smoke only proves install/launch on the GitHub Actions emulator.
- Technical-lead review and parent task closure remain open gates.
- GitHub reported a non-blocking Node.js 20 deprecation warning for `softprops/action-gh-release@v2`.

## Sources / License / Attribution

No new external source code, media, or third-party assets were copied for this prebuild package. The changes are internal Worksite Flutter/Dart edits in the existing project codebase and remain under the repository's existing licensing posture.

## Rollback Plan

If a regression is found, do not promote this prerelease. Keep `issue-8-player-controls-fix-build.27188216292` / `2.0.8-aef06bd7e+5122` as the accepted baseline. Open a follow-up fix branch from `aef06bd7ed94a67dffa45dbee484f6ef46339df5` or revert the Task-042 feature commit range on `task-042-repeat-exposure-prefilter-from-5122` as appropriate.

Do not restore or use the deleted wrong prerelease `task042-repeat-exposure-prebuild.27260059861`.

## Not Covered / Still Yellow

- Parent task `task-042` remains open.
- Stable/latest release approval is not covered.
- Technical-lead review remains open unless separately accepted.

## User Action Required

No further user action is required for this prerelease manual acceptance record unless a regression is later found. Do not use `task042-repeat-exposure-prebuild.27260059861`; it was the wrong-base prerelease and has been deleted.
