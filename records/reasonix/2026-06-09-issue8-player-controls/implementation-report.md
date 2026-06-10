# Implementation Report: Issue 8 Player Controls (Gray Screen Fix)

**Audience classification:** agent-facing

**Agent:** Reasonix (reasonix-issue8-player-controls-implementation)
**Date:** 2026-06-09
**Target branch:** issue8-player-gray-fix (based on 013535eb8)

---

## Files Changed

### 1. `lib/pages/live_room/view.dart` — Restore PLVideoPlayer construction

**What changed:** Reverted two hunks that had been altered in commit 013535eb8:

- Added back `final roomInfoH5 = _liveRoomController.roomInfoH5.value;` inside the `if (_liveRoomController.isLoaded.value && plPlayerController.isLive)` block (line 256).
- Restored `title: roomInfoH5?.roomInfo?.title` and `upName: roomInfoH5?.anchorInfo?.baseInfo?.uname` parameters passed to `LiveHeaderControl`, replacing `title: null` / `upName: null`.

**Why:** This restores the live room's ability to display the stream title and uploader name in the player header. The previous H5/header experiment had suppressed these values by always passing `null`.

### 2. `lib/pages/live_room/widgets/header_control.dart` — Restore direct upName display

**What changed:** Replaced the `Obx` that re-read `widget.liveController.roomInfoH5.value?.anchorInfo?.baseInfo?.uname` from the controller with the original pattern match `if (widget.upName case final upName?)`.

**Why:** The `LiveHeaderControl` already receives `upName` as a constructor parameter. The `Obx` wrapper was redundant and reintroduced a reactive dependency that belongs in the parent's decision about what to pass. The pattern-match form is more idiomatic Dart and correctly handles the nullable case.

### 3. `lib/plugin/pl_player/view/view.dart` — Danmaku overlay live-safe fallback

**What changed:** In the tap-danmaku overlay branch (line 1423-1438), replaced:
```dart
if (!videoDetailController.effectiveShowDanmaku) {
  return const SizedBox.shrink();
}
```
with:
```dart
final effectiveShowDanmaku =
    widget.videoDetailController?.effectiveShowDanmaku ??
    plPlayerController.enableShowDanmaku.value;
if (!effectiveShowDanmaku) {
  return const SizedBox.shrink();
}
```

**Why:** `videoDetailController` is a `late final` non-nullable field that force-unwraps `widget.videoDetailController!`. In live mode, `widget.videoDetailController` is `null`, so the old code would throw a LateInitializationError. The new code uses nullable access on the widget property and falls back to `plPlayerController.enableShowDanmaku.value` for live rooms.

**Scope:** Only the tap-danmaku overlay branch was changed. All other player branches (subtitle, speed toast, controls, etc.) are untouched. This preserves normal video detail page behavior while protecting against the live null case.

---

## Local Verification

**Why local verification was NOT run:** Per project guidance for this task, local Flutter/Dart/Gradle verification is skipped because this task is GitHub-only verified. The task is classified as simple bounded low-risk implementation. No local test commands (flutter analyze, dart compile, gradle) were executed.

## GitHub-only Verification Needs

The following must be verified via GitHub Actions / prerelease on the `issue8-player-gray-fix` branch:

1. **Live room player loads without crash** — confirm the live room page renders with no LateInitializationError from `videoDetailController`.
2. **Header displays correctly** — verify the stream title and uploader name appear in the player header.
3. **Danmaku toggle works in live room** — confirm tap-danmaku respects the live room's danmaku enabled/disabled state.
4. **Normal video detail page unaffected** — verify tap-danmaku overlay behavior is unchanged for non-live video playback.
5. **Regression: no gray screen** — confirm the original gray screen issue (Issue 8) is resolved.

---

## Git Diff Summary

```diff
 lib/pages/live_room/view.dart                    |  3 ++-
 lib/pages/live_room/widgets/header_control.dart  | 12 ++----------
 lib/plugin/pl_player/view/view.dart              |  5 ++++-
 3 files changed, 8 insertions(+), 12 deletions(-)
```

Full diff available via `git diff 013535eb8..HEAD` on the working branch.

---

## Files Not Modified (as required)

- `lib/pages/live_room/controller.dart` — no LiveRoomController edits
- Any websocket/lifecycle/quiet-state/SC/danmaku feature files
- Workflow files, git config, CI files
- Any other player branches in `lib/plugin/pl_player/view/view.dart`
