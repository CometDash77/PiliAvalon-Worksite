# Issue #8 Live-Player Gray Screen — Next Session Context

Audience: agent-facing

## Accepted Release Baseline

- Commit: `4e5db3308bd08d8a9db14f1a6115fc8bd54b38b2`
- VersionCode: 5120
- Release: issue-8-fix-build.27184526843 (GitHub Actions)

## Accepted Quiet-Controls Behavior

- SC hide (tempHideSC) and danmaku hide (tempHideDanmaku) work correctly via inline RxBool toggles
- `effectiveShowDanmaku` / `effectiveShowSC` getters and `toggleTempHideDanmaku` / `toggleTempHideSC` methods removed from controller
- Header control, chat panel, popup menu, and bottom widgets all use `tempHideSC.value` / `tempHideDanmaku.value` directly
- SC overlay in videoPlayerPanel uses `tempHideSC.value` for visibility
- Quiet-controls behavior is accepted and must not be reopened except where it directly interferes with player creation

## Remaining Bug: Live-Room Video Player Gray + Uncontrollable

- Trigger: during initial render / player creation
- Symptom: video surface is gray, player controls unresponsive
- NOT present in accepted release (or was intermittent and unreported)
- Root cause identified: concurrent async `queryLiveUrl()` → `isLoaded=true` and `queryLiveInfoH5()` → `roomInfoH5=value` cause PLVideoPlayer to be constructed TWICE via Obx at `view.dart:252`

## Root Cause Detail

In `videoPlayerPanel()` at `view.dart:252-291`:
```dart
Widget player = Obx(
  key: playerKey,
  () {
    if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
      final roomInfoH5 = _liveRoomController.roomInfoH5.value;  // LINE 255 — reactive read
      return PLVideoPlayer(
        headerControl: LiveHeaderControl(
          title: roomInfoH5?.roomInfo?.title,    // extracted from roomInfoH5
          upName: roomInfoH5?.anchorInfo?.baseInfo?.uname,
          ...
        ),
      );
    }
    return const SizedBox.shrink();
  },
);
```

The Obx reads BOTH `isLoaded.value` AND `roomInfoH5.value`. Since `queryLiveUrl()` sets `isLoaded = true` and `queryLiveInfoH5()` sets `roomInfoH5` concurrently:
1. If `queryLiveUrl` wins race: `isLoaded=true` → Obx fires → PLVideoPlayer created with `roomInfoH5=null` → then `roomInfoH5` updates → Obx fires again → PLVideoPlayer DESTROYED and RECREATED
2. If `queryLiveInfoH5` wins race: no double-rebuild (isLoaded still false when roomInfoH5 updates)

Race condition 1 causes gray screen because PLVideoPlayer's internal video controller is disposed mid-initialization.

## Repair Direction

1. Remove `roomInfoH5.value` reactive read from inside the Obx at `view.dart:255`
2. `title` is already handled reactively inside `LiveHeaderControl` via `liveController.title.value` (line 67)
3. Make `upName` also reactive in `LiveHeaderControl` by reading from `liveController.roomInfoH5.value?.anchorInfo?.baseInfo?.uname`
4. Result: Obx only depends on `isLoaded.value` — PLVideoPlayer constructed ONCE

## Verification — GitHub Actions Only

- No local Flutter/Dart/APK builds allowed
- After fix push, dispatch GitHub Actions workflow for android debug build
- Reasonix monitors the run
- Manual acceptance: user installs APK and confirms live-room playback is no longer gray/uncontrollable

## Reasonix/Codex Division of Labor

- Reasonix (this session): audit + apply minimal fix to `view.dart` and `header_control.dart` + persist repair-candidate.md
- Codex: review the Reasonix artifact, review diff, decide whether to commit/push/dispatch workflow
