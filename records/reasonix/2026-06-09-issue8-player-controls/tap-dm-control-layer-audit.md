# Tap-DM Control Layer Audit Report

**Audience classification:** agent-facing

**Date:** 2026-06-09
**Reviewer (agent):** Reasonix (audit slice)
**Review owner (coordinator):** Codex
**Target commits:** `013535eb8` (`issue8-player-gray-fix`), `4e5db3308`, compared with `origin/main` (upstream HEAD `~4e5db3308`)

**Status:** Read-only audit complete. Evidence for each conclusion verified below.

---

## Conclusions

### 1. `PLVideoPlayer.videoDetailController` is nullable in the widget API

In `lib/plugin/pl_player/view/view.dart`, the `PLVideoPlayer` widget declares:

```dart
final VideoDetailController? videoDetailController;
```

- **Line:** constructor parameter (exact line depends on formatting, ~line 28 in both commits).
- The `?` makes it explicitly nullable at the widget boundary.

### 2. `_PLVideoPlayerState` forces an unwrap with `late final`

Inside `_PLVideoPlayerState` (same file, ~line 83):

```dart
late final VideoDetailController videoDetailController =
    widget.videoDetailController!;
```

The `!` (null-assertion) means that if `widget.videoDetailController` is null at the time this field is first accessed, a `LateInitializationError` / null error will be thrown — there is no null-safe fallback.

### 3. Live room constructs `PLVideoPlayer` without `videoDetailController`

In `lib/pages/live_room/view.dart` (~line 256):

```dart
return PLVideoPlayer(
  maxWidth: width,
  maxHeight: height,
  fill: fill,
  alignment: alignment,
  plPlayerController: plPlayerController,
  headerControl: LiveHeaderControl(...),
  bottomControl: BottomControl(...),
  danmuWidget: !needDm ? null : LiveDanmaku(...),
  // ❌ No videoDetailController argument
);
```

The named parameter `videoDetailController:` is absent, so it defaults to `null`.

### 4. Normal video constructs `PLVideoPlayer` with `videoDetailController`

In `lib/pages/video/view.dart` (~line 1389):

```dart
: PLVideoPlayer(
    maxWidth: width,
    maxHeight: height,
    plPlayerController: plPlayerController!,
    videoDetailController: videoDetailController,  // ✅ Provided
    introController: introController,
    headerControl: HeaderControl(...),
    danmuWidget: ...,
    ...
  ),
```

Here `videoDetailController` is passed — no null issue at construction.

### 5. `PlPlayerController.enableTapDm` is platform-gated

In `lib/plugin/pl_player/controller.dart` (line 313):

```dart
late final enableTapDm = PlatformUtils.isMobile && Pref.enableTapDm;
```

This means `enableTapDm` is `true` only on mobile devices *and* when the user preference `Pref.enableTapDm` is enabled.

### 6. In `013535eb8` and `4e5db3308`, the tap-danmaku overlay reads `videoDetailController.effectiveShowDanmaku` unconditionally

In `lib/plugin/pl_player/view/view.dart` (~line 1423):

```dart
if (plPlayerController.enableTapDm)
  Obx(
    () {
      if (!videoDetailController.effectiveShowDanmaku) {  // 🔴 Unconditional access
        return const SizedBox.shrink();
      }
      final dmOffset = _dmOffset.value;
      if (dmOffset != null && _suspendedDm != null) {
        return _buildDmAction(_suspendedDm!, dmOffset);
      }
      return const SizedBox.shrink();
    },
  ),
```

This block is **NOT** guarded by `if (!isLive)` — unlike the surrounding control blocks (e.g. the long-press speed toast at line 1438 and the quality selector at line 1477, both of which have `if (!isLive)` guards). The `enableTapDm` check alone does not distinguish between live and video contexts.

### 7. In upstream/main, that branch used `plPlayerController.enableShowDanmaku.value`, which is live-safe

The git diff between `origin/main` and `013535eb8` confirms the only change in this region:

```diff
-              if (!plPlayerController.enableShowDanmaku.value) {
+              if (!videoDetailController.effectiveShowDanmaku) {
```

`plPlayerController.enableShowDanmaku.value` (defined at `lib/plugin/pl_player/controller.dart` lines 205-208) resolves to `_enableShowLiveDanmaku` when `isLive` is true, which is always valid — it does not depend on `VideoDetailController` at all. The upstream code was therefore safe for both live and video contexts.

### 8. Failure mechanism and blast radius (candidate evidence)

**Trigger chain:**
1. Mobile device with `Pref.enableTapDm == true`.
2. User opens a live room → `lib/pages/live_room/view.dart` builds `PLVideoPlayer` **without** `videoDetailController`.
3. `_PLVideoPlayerState` initializes with `videoDetailController` declared `late final` but never assigned a real value — the field is effectively a null bomb.
4. The player build method reaches the tap-danmaku overlay block (`if (plPlayerController.enableTapDm)`).
5. `Obx` evaluates its builder callback, hits `videoDetailController.effectiveShowDanmaku`, which dereferences the forced-null field.
6. Dart throws a runtime null error (or `LateInitializationError`).

**Blast radius:**
- The error occurs during the player/control overlay build phase on the branch that constructs the tap-danmaku overlay.
- Symptom consistent with the "gray surface / control layer stuck" report: the player surface renders (it's built before this overlay), but the interactive overlay stack fails partway, leaving a non-responsive or gray control layer.
- Normal video playback is **not** affected because the video page always passes `videoDetailController`.
- Live rooms with `enableTapDm == false` (desktop, or mobile with pref off) are **not** affected because the entire overlay block short-circuits at the `if` check.

**Evidence summary of affected code paths:**

| Context | `videoDetailController` passed? | `enableTapDm` possible? | Overlay reads `videoDetailController` | Outcome |
|---|---|---|---|---|
| Normal video (`lib/pages/video/view.dart`) | ✅ Yes | ✅ Yes | ✅ Yes | Safe — controller exists |
| Live room (`lib/pages/live_room/view.dart`) | ❌ No | ✅ Yes | ✅ Yes | 💥 Crash / gray layer |
| Live room, desktop | ❌ No | ❌ No (`isMobile` false) | (not reached) | Safe |
| Live room, `enableTapDm` pref off | ❌ No | ❌ No | (not reached) | Safe |

---

## Files referenced

| File | Lines of interest |
|---|---|
| `lib/plugin/pl_player/view/view.dart` | Widget constructor (`videoDetailController?`), state field (`late final ... = widget...!`), tap-dm overlay block (~1423) |
| `lib/plugin/pl_player/controller.dart` | `enableTapDm` (313), `enableShowDanmaku` (205-208) |
| `lib/pages/live_room/view.dart` | `PLVideoPlayer(...)` call (~256) — no `videoDetailController` |
| `lib/pages/video/view.dart` | `PLVideoPlayer(...)` call (~1389) — with `videoDetailController` |
| `lib/pages/video/controller.dart` | `effectiveShowDanmaku` definition (184) |
| `lib/pages/live_room/controller.dart` | `effectiveShowDanmaku` definition (134) |

## Git diff (upstream vs fix)

```diff
-              if (!plPlayerController.enableShowDanmaku.value) {
+              if (!videoDetailController.effectiveShowDanmaku) {
```

This single-line change in commit `013535eb8` (against `4e5db3308`/`origin/main`) is the regression that introduced the live-room crash.

## Risks and unknowns

- The `videoDetailController` late field is also accessed in other parts of `_PLVideoPlayerState`. If any of those are reached before the overlay block, the crash would happen earlier. That does not change the root cause, but could affect symptom timing.
- The `_dmOffset.value` line after the guard is not reached if `effectiveShowDanmaku` throws, so the exact symptom stack trace may vary by Flutter/Dart runtime.
- No decision required from Codex for this slice — the report is evidentiary only.

## Skills / subagents used

- None. Read-only verification done directly via `git show`, `sed -n`, and `grep`.
