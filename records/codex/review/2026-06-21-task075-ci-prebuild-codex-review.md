audience: agent-facing

# Codex Review: Task-075 CI And Prebuild Evidence

## Scope

This review covers Task-075 continuation after the upstream stable merge branch
was pushed to `origin/task-075-upstream-stable-merge`.

Reviewed evidence:

- Reasonix lockfile fix report:
  `records/reasonix/task-075/lockfile-fix-report.md`
- Failed post-lockfile CI monitor report:
  `records/reasonix/task-075/ci-monitor-after-lockfile-report.md`
- Successful post-live-color-fix CI monitor report:
  `records/reasonix/task-075/ci-monitor-after-live-color-fix-report.md`
- Successful Android prebuild monitor report:
  `records/reasonix/task-075/prebuild-monitor-report.md`
- GitHub Actions CI run:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891459215
- GitHub Actions Build run:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891774669
- GitHub prerelease:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task075-upstream-merge-prebuild.27891774669

## Branch State

- Branch: `task-075-upstream-stable-merge`
- Final reviewed commit:
  `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
- Commit sequence after the previous failing CI head:
  - `0f00ff7084bb3eff3f3dcd4dad47b693156447f6`
    `Regenerate lockfile for Task-075 upstream merge`
  - `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
    `Fix live room popup icon colors after upstream merge`

Codex created these commits through the GitHub git API because the active
linked worktree's `.git` metadata was mounted read-only and fresh network clone
attempts failed. The branch ref was updated with `force: false`.

## Lockfile Review

The lockfile fix was narrow and matches the failed CI diff from runs
`27890267219` and `27890305038`:

- `file_picker` resolved-ref changed from
  `8a987e491225341839bafb3d1c3174c4b2d797ef73` to
  `02eb0aede6ca2278bea54eb5cc9ec520bf8165fc`.
- `file_picker` version changed from `12.0.0-beta.6` to
  `12.0.0-beta.7`.
- `pubspec.yaml` was not modified.

CI run `27891459215` later proved `Verify dependency lock is clean` passed.

## Compile Fix Review

CI run `27891223045` passed the lockfile gate but failed during shielding
tests because `lib/pages/live_room/view.dart` contained two invalid bare
`color` references in popup menu icons.

Codex removed those two explicit icon `color:` fields. This is the narrowest
fix because adjacent popup menu icons use the menu `IconTheme`, and the
full-screen live-room header controls already use explicit white/white54 colors
in a different widget surface.

The commit changed only:

- `lib/pages/live_room/view.dart`

## CI Review

CI run `27891459215`:

- URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891459215
- Head SHA: `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
- Conclusion: success

Jobs:

- Focused Flutter verification: success
- Build Android x86_64 artifact: success
- Android emulator runtime smoke: success

The runtime smoke used package `com.example.piliplus.dev` and scenario
`task075-upstream-merge-ci`; Reasonix reported `result=pass`.

Codex accepts this as CI-green candidate evidence for prebuild dispatch.

## Android Prebuild Review

Build run `27891774669`:

- URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891774669
- Head SHA: `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
- Conclusion: success
- Release Android job: success
- Non-Android jobs: skipped by workflow inputs

Prerelease:

- Tag: `task075-upstream-merge-prebuild.27891774669`
- URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task075-upstream-merge-prebuild.27891774669
- Draft: false
- Prerelease: true
- Target commitish: `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8`
- APK asset count: 3

APK assets:

- `PiliAvalon_android_2.0.9-ee2241f18+5218_arm64-v8a.apk`
- `PiliAvalon_android_2.0.9-ee2241f18+5218_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.9-ee2241f18+5218_x86_64.apk`

Signing evidence:

- Run artifact: `Android_signing_evidence`
- Shared SHA-256 fingerprint:
  `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

Codex edited the release notes after workflow publication to satisfy the
worksite release-notes contract while keeping the release marked prerelease.

## Gate Judgment

- CI green: accepted as candidate evidence.
- Android prebuild: accepted as candidate APK publication evidence.
- Manual acceptance: pending.
- Stable release: blocked.

This review does not approve merge to `main`, stable release, client/user
acceptance, or any acceptance gate beyond CI/build candidate evidence.

## Commands / Surfaces

All repo-level `gh` commands used `-R CometDash77/PiliAvalon-Worksite`.
GitHub git API writes targeted only:

- `task-075-upstream-stable-merge`
- the prerelease notes for
  `task075-upstream-merge-prebuild.27891774669`

No stable release was created or edited.
