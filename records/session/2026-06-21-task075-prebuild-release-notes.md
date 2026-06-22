audience: dual-use

# Task-075 Prebuild Release Notes

## Purpose

中文摘要：这是 Task-075 上游合并后的 Android 预发布候选包，仅用于用户手动验收；不是 stable release，也不代表用户已验收通过。

This release publishes Android APKs for manual validation of the Task-075
upstream stable merge candidate.

## Release Type

prebuild

## Branch / Commit / Tag

- Branch: `task-075-upstream-stable-merge`
- Commit: `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
- Tag: `task075-upstream-merge-prebuild.27891774669`
- Version: `2.0.9-ee2241f18+5218`

## Related PRs / Issues

- Related task: Task-075 upstream stable merge.
- Related PRs/issues: none recorded for this prebuild.

## Automation Evidence

- CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891459215
  - Focused Flutter verification: success
  - Android x86_64 artifact build: success
  - Android emulator runtime smoke: success
- Android Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891774669
  - Release Android job: success
  - Signing evidence artifact: `Android_signing_evidence`

## Manual Acceptance

Pending. The attached APKs are candidate packages for user/client validation.

## Changes

- Merged upstream `main` into the accepted Task-066 `+5175` baseline as the
  Task-075 upstream stable merge candidate.
- Regenerated `pubspec.lock` for the merged `pubspec.yaml`; `file_picker`
  resolves to `12.0.0-beta.7`.
- Fixed the post-merge live-room popup icon compile error by removing two
  invalid bare `color` references and using the popup menu icon theme.

## Known Risks

- This APK has not been manually accepted by the user/client.
- Broader real-device behavior beyond the GitHub emulator smoke remains
  unverified.
- Upstream merge risk remains open for flows not covered by the CI smoke.

## Sources / License / Attribution

- No new external code was copied for this prebuild.
- The package is built from the worksite repository and the merged upstream
  PiliPlus source already tracked in git history.
- Existing upstream/project licenses and attribution remain unchanged.

## Rollback Plan

- Do not promote this prebuild to stable if manual validation fails.
- Continue using the last user-accepted APK version
  `2.0.8-981869d33+5175`.
- If the prerelease itself must be withdrawn, delete the GitHub prerelease and
  tag only after explicit user approval and a recorded rollback reason.

## Not Covered / Still Yellow

- Manual user/client acceptance is pending.
- Stable release is blocked until the user explicitly accepts a candidate APK
  and authorizes stable.
- Manual cover-install validation is pending.

## User Action Required

Download and manually test the appropriate APK from this prerelease. Report
whether it is accepted for stable promotion or rejected with issues.

## Android Release Signing Evidence

- Run ID: 27891774669
- Commit: `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
- Version: `2.0.9-ee2241f18+5218`

| APK | SHA-256 fingerprint |
|---|---|
| `PiliAvalon_android_2.0.9-ee2241f18+5218_arm64-v8a.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| `PiliAvalon_android_2.0.9-ee2241f18+5218_armeabi-v7a.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| `PiliAvalon_android_2.0.9-ee2241f18+5218_x86_64.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |

Cover-install verification requires:

- same applicationId: `com.example.piliplus`
- same signing certificate fingerprint as the installed release
- install over existing app without uninstall
