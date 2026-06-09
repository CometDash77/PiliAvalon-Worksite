# Issue 8 Player Controls Fix - Codex Review

Audience classification: agent-facing

Date: 2026-06-09
Review owner: Codex
Target branch: `issue8-player-gray-fix`
Reviewed base: `013535eb8` (`issue-8-player-gray-fix-build.27186258288`, APK `+5121`)

## Reviewed Candidate Artifacts

- `records/reasonix/2026-06-09-issue8-player-controls/tap-dm-control-layer-audit.md`
- `records/reasonix/2026-06-09-issue8-player-controls/implementation-report.md`

## Gate Status

Codex marks `issue-8-player-gray-fix-build.27186258288` / commit `013535eb8` / APK `+5121` as a failed manual-acceptance candidate for the live-room gray/control-layer symptom. It must not be used as the acceptance package for Issue 8.

The next candidate commit is expected to have versionCode `5122` because `git rev-list --count HEAD` was `5121` before this fix commit.

## Root-Cause Judgment

Reasonix's audit establishes a high-confidence player-control-layer defect:

- `PLVideoPlayer.videoDetailController` is nullable at the widget boundary.
- `_PLVideoPlayerState.videoDetailController` force-unwraps `widget.videoDetailController!` and is unsafe when accessed for live-room player instances.
- Live room constructs `PLVideoPlayer` without `videoDetailController`.
- Normal video constructs `PLVideoPlayer` with `videoDetailController`.
- `PlPlayerController.enableTapDm` is mobile/pref-gated, so mobile live rooms can enter the tap-danmaku overlay branch.
- The issue branch reads `videoDetailController.effectiveShowDanmaku` in that branch, while upstream uses `plPlayerController.enableShowDanmaku.value`, which is safe for live playback.

Codex accepts the candidate failure mechanism: on mobile with tap-danmaku enabled, the shared player can build in live mode without a `VideoDetailController`, then the tap-danmaku overlay evaluates a forced-null `videoDetailController` field. That can break the overlay/control layer and is consistent with the reported gray surface and controls that cannot be called out.

## Diff Review

Accepted source changes:

- `lib/plugin/pl_player/view/view.dart`: accepted. The tap-danmaku overlay now computes:
  ```dart
  final effectiveShowDanmaku =
      widget.videoDetailController?.effectiveShowDanmaku ??
      plPlayerController.enableShowDanmaku.value;
  ```
  Normal video continues to use `VideoDetailController.effectiveShowDanmaku`; live room falls back to `PlPlayerController.enableShowDanmaku`.
- `lib/pages/live_room/view.dart`: accepted as rollback of the failed `013535eb8` H5/header experiment. It restores `roomInfoH5` title/upName passing.
- `lib/pages/live_room/widgets/header_control.dart`: accepted as rollback of the failed `013535eb8` header-only `Obx` experiment. It restores direct `widget.upName` rendering.

No `LiveRoomController`, quiet-state, websocket, lifecycle, SC, danmaku feature, workflow, or release files were changed by the implementation slice.

## Verification Status

Local Flutter, Dart, Gradle, adb, APK builds, artifact downloads, and local dependency probes were not run because this task is under GitHub-only verification rules.

Required next evidence:

- `PiliAvalon CI` workflow success on the final commit.
- `Focused Flutter verification` success.
- `Build Android x86_64 artifact` success.
- `Android emulator runtime smoke` success.
- Android-only `Build` workflow success on the final commit.
- GitHub prerelease tag `issue-8-player-controls-fix-build.{run_id}`.
- APK asset filenames containing `+5122`.
- Manual acceptance remains pending until the user installs the `arm64-v8a` APK and confirms live-room playback, control overlay, gray-mask behavior, fullscreen transitions, and accepted hide-SC/hide-danmaku behavior.
