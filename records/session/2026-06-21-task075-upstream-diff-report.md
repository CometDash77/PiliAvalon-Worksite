---
audience: agent-facing
type: task-075-upstream-diff-report
task_id: task-075
created: "2026-06-21"
baseline_kind: latest-user-accepted-prerelease
baseline_version: "2.0.8-981869d33+5175"
baseline_commit: 981869d336bd19d977879594f176ac536a25ccd5
upstream_ref: upstream/main
upstream_commit: 2536350ccfc87b9d5d23c564e3d4c8adbd175820
merge_base: cd367a8649ed1f2bed7000d5e4bcb7096a811bc5
status: upstream-diff-recorded
---

# Task-075 Upstream Diff Report

## Scope

This report records the Phase 1 upstream-diff gate for Task-075 before any
real merge. It uses the user-confirmed latest usable baseline:

- GitHub prerelease: `task066-related-numeric-ui-plus5169.27870685659`
- Accepted APK version: `2.0.8-981869d33+5175`
- Product baseline commit: `981869d336bd19d977879594f176ac536a25ccd5`
- Upstream branch: `upstream/main`
- Upstream commit after fetch: `2536350ccfc87b9d5d23c564e3d4c8adbd175820`

Current worksite branch at preflight was
`task-066-detail-intro-shielding` at
`9cf4b0adbc7bb1e5d0a013b965847f577538a7ea`, but Task-075 merge work must
start from the user-accepted product baseline commit `981869d33`, not from
later evidence-only commits.

## Preflight Notes

- Repository path: `/home/mo/Documents/piliavalon`
- Fork remote: `origin git@github.com:CometDash77/PiliAvalon-Worksite.git`
- Upstream remote: `upstream https://github.com/bggRGjQaUbCoE/PiliPlus.git`
- Upstream default branch: `main`
- Worktree before edits: clean (`git status --short --branch` showed only the
  tracking branch header).
- `reasonix doctor`: passed for core Reasonix health. It reported
  `deepseek-flash` and `deepseek-pro` providers with DeepSeek key present,
  no plugins configured, sandbox network enabled, and write root limited to
  this repository.
- Broad `git fetch --all --prune` and unprivileged `git fetch upstream main
  --prune` did not return promptly in the sandbox. The required upstream fetch
  was rerun with explicit escalation and succeeded:
  `From https://github.com/bggRGjQaUbCoE/PiliPlus * branch main -> FETCH_HEAD`.
- Local shell did not have `flutter`, `dart`, or `fvm` on `PATH`.
  `.fvmrc` requires Flutter `3.44.0`. Local Flutter/Dart verification is
  blocked unless the toolchain is installed or PATH is repaired; GitHub Actions
  may be required as replacement verification evidence.

## Required Diff Commands

- `git merge-base 981869d336bd19d977879594f176ac536a25ccd5 upstream/main`
  returned `cd367a8649ed1f2bed7000d5e4bcb7096a811bc5`.
- `git rev-parse 981869d336bd19d977879594f176ac536a25ccd5` returned
  `981869d336bd19d977879594f176ac536a25ccd5`.
- `git rev-parse upstream/main` returned
  `2536350ccfc87b9d5d23c564e3d4c8adbd175820`.
- `git diff --name-only
  981869d336bd19d977879594f176ac536a25ccd5...upstream/main | wc -l`
  returned `100`.
- `git diff --name-only
  cd367a8649ed1f2bed7000d5e4bcb7096a811bc5..981869d336bd19d977879594f176ac536a25ccd5
  | wc -l` returned `253`.

## Upstream Summary

The upstream delta from the accepted `+5175` baseline to `upstream/main`
contains 100 changed files with approximately 1667 insertions and 1305
deletions.

Major upstream themes:

- Flutter tooling moves from the worksite `.fvmrc` Flutter `3.44.0` line to
  upstream's newer Flutter line.
- CI build workflows remove some flutter channel pinning.
- Rich text field internals changed in several vendored Flutter widget files.
- Live room stream/format/codec URL handling changed.
- Login/geetest and utility request handling changed.
- Player and video progress paths changed.
- Settings models and storage utilities changed.

## Area Grouping

### Feed / Recommendation

Upstream changed files relevant or adjacent to feed/recommendation:

- `lib/http/video.dart`
- `lib/pages/rcmd/view.dart` is Worksite-changed but not in the upstream
  delta from `+5175`.
- `lib/models/home/rcmd/result.dart` is Worksite-changed but not in the
  upstream delta from `+5175`.
- `lib/utils/recommend_filter.dart` is Worksite-changed but not in the
  upstream delta from `+5175`.

Risk: high for `lib/http/video.dart` because it overlaps with Worksite
recommendation/related-video adapter work and upstream also touched it.

### Video Detail

Upstream changed files relevant or adjacent to video detail:

- `lib/http/video.dart`
- `lib/pages/video/controller.dart`
- `lib/pages/video/view.dart`
- `lib/pages/video/widgets/header_control.dart`
- `lib/pages/video/reply/widgets/reply_item_grpc.dart`
- `lib/pages/video/introduction/ugc/widgets/action_item.dart`
- `lib/pages/video/pay_coins/view.dart`
- `lib/pages/video/reply_new/view.dart`
- `lib/pages/video/reply_reply/view.dart`
- `lib/pages/video/send_danmaku/view.dart`
- `lib/pages/video/widgets/header_mixin.dart`
- `lib/pages/video/widgets/player_focus.dart`

Risk: high. Multiple accepted Phase 2 quiet-control, related-video shielding,
and detail-page behavior surfaces overlap.

### Player / Danmaku

Upstream changed files relevant or adjacent to player/danmaku:

- `lib/pages/video/controller.dart`
- `lib/pages/video/view.dart`
- `lib/pages/video/widgets/header_control.dart`
- `lib/plugin/pl_player/controller.dart`
- `lib/plugin/pl_player/view/view.dart`
- `lib/plugin/pl_player/view/widgets.dart`
- `lib/models/video/play/url.dart`

Risk: high because Worksite accepted temporary quiet controls and persistent
quiet gates in player/detail surfaces.

### Live

Upstream changed files relevant or adjacent to live:

- `lib/http/live.dart`
- `lib/pages/live_room/controller.dart`
- `lib/pages/live_room/view.dart`
- `lib/pages/live_room/widgets/bottom_control.dart`
- `lib/pages/live_room/widgets/header_control.dart`
- `lib/models_new/live/live_dm_info/data.dart`
- `lib/models_new/live/live_room_play_info/codec.dart`
- `lib/models_new/live/live_room_play_info/format.dart`
- `lib/models_new/live/live_room_play_info/playurl.dart`
- `lib/models_new/live/live_room_play_info/stream.dart`
- `lib/models_new/live/live_room_play_info/url_info.dart`

Risk: high because Worksite accepted live danmaku and SC controls, and upstream
changed live stream/codec/format handling.

### Settings / Storage

Upstream changed files relevant or adjacent to settings/storage:

- `lib/pages/setting/models/extra_settings.dart`
- `lib/pages/setting/models/play_settings.dart`
- `lib/pages/setting/models/privacy_settings.dart`
- `lib/pages/setting/models/style_settings.dart`
- `lib/pages/setting/models/video_settings.dart`
- `lib/pages/setting/pages/play_speed_set.dart`
- `lib/pages/setting/view.dart`
- `lib/pages/setting/widgets/dual_slider_dialog.dart`
- `lib/pages/setting/widgets/ordered_multi_select_dialog.dart`
- `lib/pages/setting/widgets/select_dialog.dart`
- `lib/pages/setting/widgets/slider_dialog.dart`
- `lib/utils/storage_key.dart`
- `lib/utils/storage_pref.dart`

Risk: high. Accepted Phase 2 behavior depends on settings entries, scoped
storage keys, and persistence across restart.

### Build / Release

Upstream changed files relevant to build/release:

- `.fvmrc`
- `.github/workflows/build.yml`
- `.github/workflows/ios.yml`
- `.github/workflows/linux_x64.yml`
- `.github/workflows/mac.yml`
- `.github/workflows/win_x64.yml`
- `pubspec.yaml`
- `pubspec.lock`
- `lib/scripts/bottom_sheet_ios_piliplus.patch`
- `lib/scripts/geetest_ios.patch`
- `lib/scripts/navigation_drawer.patch`
- `lib/scripts/patch.ps1`

Risk: high. The merge may affect CI/build behavior and the Flutter toolchain
version needed for validation.

### Other Upstream Changes

Other upstream-changed areas include:

- `lib/common/style.dart`
- common widgets and image grid utilities
- GRPC audio/space/view files
- dynamics, article, audio, login, music, sponsor block, whisper, request,
  filtering text, image, login, color, and video utility files.

Risk: medium. These require broad smoke coverage for common upstream app flows.

## High-Risk Overlapping Files

The following files changed both in Worksite Phase 2 since merge-base and in
upstream since the accepted `+5175` baseline:

| File | Area | Risk | Required verification |
| --- | --- | --- | --- |
| `.github/workflows/build.yml` | Build/release | High | GitHub build workflow dispatch and artifact check |
| `.github/workflows/ios.yml` | Build/release | Medium | Confirm non-Android skips do not block Android candidate |
| `.github/workflows/linux_x64.yml` | Build/release | Medium | Confirm non-Android skips do not block Android candidate |
| `.github/workflows/mac.yml` | Build/release | Medium | Confirm non-Android skips do not block Android candidate |
| `.github/workflows/win_x64.yml` | Build/release | Medium | Confirm non-Android skips do not block Android candidate |
| `lib/http/video.dart` | Feed/video detail | High | Recommendation feed, related video, and adapter-focused tests |
| `lib/main.dart` | App startup/storage | High | Runtime smoke and settings initialization checks |
| `lib/pages/live_room/controller.dart` | Live | High | Live danmaku and SC control checks |
| `lib/pages/live_room/view.dart` | Live | High | Live room UI smoke checks |
| `lib/pages/live_room/widgets/header_control.dart` | Live | High | Live header control and quiet-control checks |
| `lib/pages/setting/models/extra_settings.dart` | Settings | High | Settings persistence and entry visibility checks |
| `lib/pages/setting/view.dart` | Settings | High | Shielding/quiet/settings navigation checks |
| `lib/pages/video/controller.dart` | Video detail/player | High | Detail quiet controls, related videos, player state checks |
| `lib/pages/video/reply/widgets/reply_item_grpc.dart` | Video detail/comments | High | Comment shielding and reply rendering checks |
| `lib/pages/video/view.dart` | Video detail/player | High | Detail page tabs, quiet controls, player smoke |
| `lib/pages/video/widgets/header_control.dart` | Video detail/player | High | Header controls, manual quiet controls |
| `lib/plugin/pl_player/view/view.dart` | Player | High | Player smoke and danmaku interaction checks |
| `lib/utils/image_utils.dart` | Other/common | Medium | Broad smoke and image loading sanity |
| `lib/utils/storage_key.dart` | Settings/storage | High | Settings key preservation and migration checks |
| `lib/utils/storage_pref.dart` | Settings/storage | High | Settings persistence across restart |
| `pubspec.lock` | Build/deps | High | Fresh dependency/build validation |
| `pubspec.yaml` | Build/deps | High | Fresh dependency/build validation |

If Git later auto-merges any of these files cleanly, they still require manual
review and focused verification.

## Phase 2 Behavior That Must Survive

- Homepage recommendation shielding: accepted rule matching and filtering.
- Related-video shielding: independent related-video switch and numeric fields.
- Derived metric filters: interaction rate, triple-action rate, content value.
- Repeat-exposure filter: accepted unclicked BV prefilter behavior.
- Temporary quiet controls: accepted detail-page manual quiet behavior.
- Persistent quiet controls: accepted channel/default quiet behavior.
- Live controls: accepted live danmaku and SC controls.
- Settings persistence: new and existing settings persist across restart.

## Current Gate Status

- Upstream diff gate: recorded.
- Reasonix upstream diff review: pending.
- Dry-run merge: pending.
- Real merge: pending.
- Local Flutter/Dart checks: currently blocked by missing local toolchain.
- GitHub verification: pending after merge branch push.
- Candidate APK: pending.
- User manual acceptance: pending.
- Stable release: blocked until explicit user acceptance and authorization.
