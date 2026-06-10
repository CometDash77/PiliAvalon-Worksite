# Issue #8 Live-Player Gray Screen — Repair Candidate

Audience: agent-facing

## Diagnosis

### Symptom
Live-room video player becomes gray and uncontrollable during initial render or player creation.

### Root Cause: Double PLVideoPlayer Construction
`view.dart:252-291` wraps `PLVideoPlayer` creation in an `Obx` that reads **both** `_liveRoomController.isLoaded.value` and `_liveRoomController.roomInfoH5.value`:

```dart
// view.dart:252-257
Widget player = Obx(
  key: playerKey,
  () {
    if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
      final roomInfoH5 = _liveRoomController.roomInfoH5.value; // reactive read
      return PLVideoPlayer(
        headerControl: LiveHeaderControl(
          title: roomInfoH5?.roomInfo?.title,         // ← from roomInfoH5
          upName: roomInfoH5?.anchorInfo?.baseInfo?.uname, // ← from roomInfoH5
```

In `controller.dart:onInit()`, two async calls fire concurrently:
- `queryLiveUrl()` (line 165): sets `isLoaded.value = true` at line 231
- `queryLiveInfoH5()` (line 166): sets `roomInfoH5.value = response` at line 240

**Race condition**: When `queryLiveUrl` completes first, the Obx fires:
1. `isLoaded=true` → PLVideoPlayer created with `roomInfoH5=null`
2. `roomInfoH5` updates → Obx fires again → first PLVideoPlayer destroyed mid-initialization, new PLVideoPlayer created
3. First PLVideoPlayer's internal video controller disposed before texture is ready → gray screen

This double-rebuild pattern existed since at least clean base `1134f3d1d` (same Obx wrapping), but may have been masked by timing or occur only intermittently.

### Not the Cause (verified unchanged)
- PLVideoPlayer internal code: no diffs between release `4e5db33` and current HEAD
- Obx wrapping pattern: identical between release and current HEAD for the core PLVideoPlayer construction
- `childWhenDisabled`, `_buildPH`, `_buildPP`, `_buildBodyH`: identical between release and current HEAD
- New quiet-control changes (tempHideSC, tempHideDanmaku): operate in separate Obx widgets outside the player Obx, cannot cause cascading PLVideoPlayer rebuild

### Why `roomInfoH5` Read is Unnecessary
`LiveHeaderControl` already reads `title` reactively from `liveController.title.value` (line 67 of header_control.dart). The `title` parameter passed at construction is never used. `upName` is used but can be made reactive similarly.

## Files Changed

### 1. `lib/pages/live_room/view.dart` — Remove reactive dependency on `roomInfoH5`

**Location**: `videoPlayerPanel()` method, lines 252-291

**Change**: Remove `final roomInfoH5 = _liveRoomController.roomInfoH5.value;` from inside the Obx builder. Pass `null` for `title` and `upName` to `LiveHeaderControl`.

Before:
```dart
      () {
        if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
          final roomInfoH5 = _liveRoomController.roomInfoH5.value;
          return PLVideoPlayer(
            ...
            headerControl: LiveHeaderControl(
              key: _liveRoomController.headerKey,
              title: roomInfoH5?.roomInfo?.title,
              upName: roomInfoH5?.anchorInfo?.baseInfo?.uname,
```

After:
```dart
      () {
        if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
          return PLVideoPlayer(
            ...
            headerControl: LiveHeaderControl(
              key: _liveRoomController.headerKey,
              title: null,
              upName: null,
```

**Effect**: The Obx now only depends on `_liveRoomController.isLoaded.value` and `plPlayerController.isLive`. `roomInfoH5` changes no longer trigger PLVideoPlayer reconstruction. PLVideoPlayer is constructed exactly once during initial load.

### 2. `lib/pages/live_room/widgets/header_control.dart` — Make `upName` reactive

**Location**: `_LiveHeaderControlState.build()`, lines 87-94

**Change**: Replace synchronous `widget.upName` check with an `Obx` reactive read from `widget.liveController.roomInfoH5.value?.anchorInfo?.baseInfo?.uname`.

Before:
```dart
              if (widget.upName case final upName?)
                Text(
                  upName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
```

After:
```dart
              Obx(() {
                final upName = widget.liveController.roomInfoH5.value
                    ?.anchorInfo
                    ?.baseInfo
                    ?.uname;
                if (upName == null) return const SizedBox.shrink();
                return Text(
                  upName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                );
              }),
```

**Effect**: `upName` updates reactively without requiring PLVideoPlayer reconstruction. The `title` (line 64-76) was already reactive via `liveController.title.value` and needs no change.

## Commands Run

```bash
# git log to identify commits
git log --oneline -10

# Compare videoPlayerPanel across versions
git show 4e5db33:lib/pages/live_room/view.dart | sed -n '239,371p'
git show 1134f3d1d:lib/pages/live_room/view.dart | sed -n '239,371p'

# Full diff between release and current HEAD
git diff 4e5db33 -- lib/pages/live_room/view.dart
git diff 4e5db33 -- lib/pages/live_room/controller.dart
git diff 4e5db33 -- lib/pages/live_room/widgets/header_control.dart
git diff 4e5db33 -- lib/pages/live_room/widgets/chat_panel.dart
git diff 4e5db33 -- lib/plugin/pl_player/  # empty — no changes
```

## Diff Summary

| File | Lines Changed | Nature |
|---|---|---|
| `lib/pages/live_room/view.dart` | -1 line in Obx, 2 param changes | Remove `roomInfoH5` reactive read; pass null title/upName |
| `lib/pages/live_room/widgets/header_control.dart` | ~10 lines changed | Make upName Obx-reactive |

## Remaining Risks

1. **upName display latency**: `upName` now updates via Obx when `roomInfoH5` loads, instead of being available at PLVideoPlayer construction. No visible impact expected since roomInfoH5 typically loads within ~200ms.

2. **Pre-existing race in `didPopNext()`**: `_liveRoomController.isLoaded.refresh()` at view.dart:120 can cause a second Obx rebuild if `isLoaded` was already true. This is pre-existing and unchanged by this fix.

3. **PLVideoPlayer internal resilience**: The fix prevents double construction, but PLVideoPlayer should ideally be resilient to rapid dispose/recreate. This is a separate improvement for `lib/plugin/pl_player/`.

## Recommended GitHub Actions Verification

1. Push the fix branch
2. Dispatch android debug build workflow
3. Install APK, open a live room, observe initial player load
4. Verify: no gray screen, player controls responsive, video plays
5. Verify quiet controls (SC hide, danmaku hide) still work correctly
6. Verify fullscreen toggle and PiP still work

## Manual Acceptance Pending

- [ ] User installs APK and confirms live-room playback is no longer gray or uncontrollable
- [ ] User confirms quiet controls (SC/danmaku hide) unchanged
- [ ] User confirms fullscreen and PiP unaffected
