audience: agent-facing

# Task-075 Prebuild Release Record

## Release Summary

- Release type: prebuild
- Tag: `task075-upstream-merge-prebuild.27891774669`
- Title/name: `task075-upstream-merge-prebuild.27891774669`
- URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task075-upstream-merge-prebuild.27891774669
- Draft: false
- Prerelease: true
- Stable/latest: not claimed

## Branch And Commit

- Repository: `CometDash77/PiliAvalon-Worksite`
- Branch: `task-075-upstream-stable-merge`
- Commit: `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`

## Related PRs / Issues

- Related task: Task-075 upstream stable merge.
- Related PRs/issues: none recorded for this prebuild.

## Automation Evidence

- CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891459215
  - Focused Flutter verification: success
  - Android x86_64 artifact build: success
  - Android emulator runtime smoke: success
- Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891774669
  - Release Android job: success
  - Signing evidence captured and uploaded

## Assets

- `PiliAvalon_android_2.0.9-ee2241f18+5218_arm64-v8a.apk`
- `PiliAvalon_android_2.0.9-ee2241f18+5218_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.9-ee2241f18+5218_x86_64.apk`

Run artifact:

- `Android_signing_evidence`

## Signing Evidence

All 3 APK assets share SHA-256 signing certificate fingerprint:

`0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

Cover-install requirements recorded in the release notes:

- same applicationId: `com.example.piliplus`
- same signing certificate fingerprint as the installed release
- install over existing app without uninstall

## Release Notes

Release notes were updated after workflow publication to include the required
worksite sections. Source file:

- `records/session/2026-06-21-task075-prebuild-release-notes.md`

## Manual Acceptance

Pending. This is a candidate package for user/client validation only.

## Known Risks

- Manual real-device acceptance is pending.
- Stable release remains blocked.
- Flows outside CI and the Android emulator smoke are not fully covered.

## Rollback Path

- Do not promote this prebuild to stable if manual validation fails.
- Continue using the last user-accepted APK version
  `2.0.8-981869d33+5175`.
- Delete the prerelease/tag only after explicit user approval and a recorded
  rollback reason.

## Repository Scoping

Every `gh` command used for run/release inspection, workflow dispatch, and
release-note editing used explicit repository scope:

`-R CometDash77/PiliAvalon-Worksite`

No command targeted upstream, pilinara, pilisuper, or design-institute release
surfaces.

## Non-Claims

- No stable release was created.
- No merge to `main` was performed.
- No user/client acceptance is claimed.
- No manual acceptance package is accepted until the user explicitly accepts an
  APK candidate.
