# Issue 8 Live Player Gray/Uncontrollable Risk Audit

Audience classification: agent-facing
Date: 2026-06-09
Auditor: Reasonix (live-player-gray-risk-audit)
Review owner: Codex
Trusted base: commit `1134f3d1d5305df13b28d0657ac121711e0b68fc` (versionCode 5119)
Working branch: `task-026-live-room-quiet-controls-issue8-9104`

---

## 1. Direct Answer: Do Live Room and Normal Video Share Player Dart?

**YES — both pages share the same player core.**

### Shared Classes

| Shared artifact | Location | Role |
|---|---|---|
| `PLVideoPlayer` (StatefulWidget) | `lib/plugin/pl_player/view/view.dart:90` | The single shared video player widget |
| `PlPlayerController` | `lib/plugin/pl_player/controller.dart` | The single shared player controller (GetX singleton per instance) |
| `ComBtn` | `lib/plugin/pl_player/widgets/common_btn.dart` | Shared header button widget (used by both pages) |
| `PlayStatus`, `DataSource`, `DanmakuOptions`, `FullScreenMode` | `lib/plugin/pl_player/models/*.dart` | Shared player enums/models |

Both pages import `package:PiliPlus/plugin/pl_player/view/view.dart` and construct `PLVideoPlayer(...)` directly. The player widget itself is **identical** — no subclassing, no mixin divergence, no page-specific `PLVideoPlayer` variant.

### Divergent Wrappers

| Aspect | Live Room | Normal Video |
|---|---|---|
| Wrapper method | `_LiveRoomPageState.videoPlayerPanel()` in `view.dart:239` | `_VideoDetailPageState.plPlayer()` in `video/view.dart:1371` |
| Player gate | `Obx` checking `isLoaded.value && isLive` (line 255) | `popScope` + `Obx` checking `videoState && autoPlay && videoController != null` (line 1385-1388) |
| Header widget | `LiveHeaderControl` (live_room/widgets/header_control.dart) | `HeaderControl` (video/widgets/header_control.dart) |
| Bottom widget | `BottomControl` (live_room/widgets/bottom_control.dart) | None (bottom control is inside `PLVideoPlayer`) |
| Danmaku widget | `LiveDanmaku` (canvas-based, live_room/view.dart:1093) | `PlDanmaku` (video/...) |
| Controller owner | `LiveRoomController` extends `GetxController` | `VideoDetailController` extends `GetxController` |
| Lifecycle hooks | `didPushNext`/`didPopNext` + `WidgetsBindingObserver` in view.dart | Separate `playerListener`, `popScope` callback |

### Conclusion for Implementation

Because the player widget (`PLVideoPlayer`) is shared, **the player surface and lifecycle constraint applies identically to both pages**. The safe temporary quiet pattern from `1134f3d1d` — adding `RxBool` fields to the page-level controller and gating rendering at UI-layer points — is equally applicable to live room. The difference is only in which rendering points to gate and which controller to add the fields to.

---

## 2. Gray/Uncontrollable Player Risk Points in Live-Room Wrapper/Lifecycle

The user reports that this version's live room video player can become **gray and uncontrollable**. Below is a systematic audit of every risk point in the live-room player wrapper and lifecycle.

### 2.1 PLVideoPlayer Construction (view.dart:252-291)

```dart
Widget player = Obx(
  key: playerKey,
  () {
    if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
      ...
      return PLVideoPlayer(...);
    }
    return const SizedBox.shrink();
  },
);
```

**Risk:** The `Obx` rebuilds whenever `isLoaded` or `isLive` changes. Since `isLoaded` transitions from `false` → `true` (never back), and `isLive` is always `true` for live rooms, the player should construct once and stay. However:

- **If `playerKey` (a GlobalKey) causes a full widget tree rebuild**, the `PLVideoPlayer` state could be destroyed and recreated, potentially showing a gray frame during transition.
- **If `isLoaded.value` is false at any point** (e.g., network failure in `queryLiveUrl`), only `SizedBox.shrink()` is shown — this is a black/gray area where the player is expected.
- **Race condition**: `roomInfoH5.value` is nullable. If the Obx fires with `isLoaded=true` but `roomInfoH5.value == null`, the `PLVideoPlayer` still constructs with a null roomInfoH5 — the title/upName in header will be null but the player itself should work since it only depends on `plPlayerController`.

**Gray risk: LOW.** The gate is binary and the player should only appear after `videoUrl` is set and `setDataSource` called.

### 2.2 isLoaded / isLive Gates (controller.dart:59, 168-224)

- `isLoaded = false.obs` — set to `true` only after `queryLiveUrl` + `playerInit` succeed.
- `isLive` — set in PlPlayerController constructor with `isLive: true` (line 56). **Always `true` for live rooms.**
- `playerInit()` (line 168-182): calls `plPlayerController.setDataSource(NetworkSource(...))`. If `videoUrl` is null, returns `null` — `isLoaded` stays `false`.
- `queryLiveUrl()` (line 184-228): fetches play URL, sets `videoUrl`, calls `playerInit`, then sets `isLoaded.value = true`.

**Gray risk point:** If `queryLiveUrl` succeeds (play URL obtained) but `playerInit`/`setDataSource` fails silently (e.g., codec error, native player init failure), `isLoaded` is set to `true` and the player widget is constructed, but the native video surface shows nothing → **gray screen**.

**Risk: MEDIUM.** The gap between `isLoaded = true` and a working video surface is the most likely explanation for the reported gray/uncontrollable player.

### 2.3 Obx Rebuilds (general)

Any reactive field read inside the Obx at line 252-291 triggers a full `PLVideoPlayer` rebuild. The following are read inside or affect the player area:

- `_liveRoomController.isLoaded.value` (line 255)
- `plPlayerController.isLive` (line 255 — but isLive is a plain bool, not Rx, so it doesn't trigger rebuilds — **RISK: stale value if changed externally**)
- `_liveRoomController.roomInfoH5.value` (line 256 — nullable, but only used for header)

**Note:** `plPlayerController.isLive` at line 255 is accessed as a **plain field**, not `.value`. It is declared in `PlPlayerController` as `bool isLive;` (non-reactive). This means the Obx does **NOT** track `isLive` changes. If something sets `isLive = false`, the Obx won't rebuild and `PLVideoPlayer` remains in the tree — but internally the player may not work correctly.

**Actually critical observation:** `plPlayerController.isLive` is set to `true` at construction (controller.dart:56-57: `PlPlayerController.getInstance(isLive: true)`), then accessed at line 255 as just `plPlayerController.isLive`. It's also set in `didPopNext` (view.dart:118-119): `plPlayerController.isLive = true`. This is NOT reactive — the Obx won't react to it. The only reactive field is `isLoaded`.

**Gray risk: LOW-MEDIUM.** The non-reactive `isLive` check is suspicious but in practice `isLive` is always `true` for live room.

### 2.4 PopScope (view.dart:366-370)

```dart
return popScope(
  canPop: !isFullScreen && !plPlayerController.isDesktopPip,
  onPopInvokedWithResult: plPlayerController.onPopInvokedWithResult,
  child: player,
);
```

**Risk: NONE.** PopScope only affects navigation back gesture; does not touch player surface or lifecycle.

### 2.5 Overlays: Stack/Positioned Layers (view.dart:293-364)

When `showSuperChat && (isFullScreen || isDesktopPip)`, the player is wrapped in a Stack with:
- `Positioned.fill(child: player)` — main player
- Debug buttons (kDebugMode)
- `Positioned(left, bottom, fullScreenSCWidth)` — fullscreen SC overlay

**Risk:** The Stack + Positioned.fill should not cause grayness. However, if the SC overlay Positioned covers the player controls (it's placed at left: padding.left + 25, bottom: 25) and is opaque, the bottom-left area could be visually obstructed. But it's a SC card, not a full overlay.

**Gray risk: VERY LOW.** No overlay covers the entire player surface.

### 2.6 playerInit / queryLiveUrl (controller.dart:168-228)

Called:
- On `onInit()` (line 158)
- On `didPopNext()` (line 138, if player is not playing)
- On refresh button
- On quality change

**Risk:** `setDataSource` is async. Between `videoUrl` being set and the native player actually rendering frames, there is a window where the `PLVideoPlayer` widget is in the tree but the native video surface is blank/gray. This is the **most likely cause of the reported gray/uncontrollable symptom**.

### 2.7 didPushNext / didPopNext (view.dart:116-156)

- **didPushNext**: `removeObserverMobile`, `removeStatusLister`, pause danmaku, cancel timer, close live message stream, save `isPlaying` state. Does NOT dispose player.
- **didPopNext**: `addObserverMobile`, set `isLive = true`, `isLoaded.refresh()`, restore danmaku controller, `setPlayCallBack`, `startLiveTimer`, optionally `playerInit(autoplay: shouldPlay)`.

**Risk:** On returning to live room (didPopNext), if `playerInit` is called and fails, or if `isLoaded.refresh()` triggers a rebuild before `playerInit` completes, the player could show a stale/gray surface.

**Gray risk: LOW-MEDIUM.** The `didPopNext` flow is complex and re-initializes the player.

### 2.8 App Lifecycle (view.dart:192-206)

```dart
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (plPlayerController.visible = state == .resumed) {
    ...
    plPlayerController.showDanmaku = true;
  } else if (state == .paused) {
    _liveRoomController.cancelLiveTimer();
    plPlayerController
      ..showDanmaku = false
      ..danmakuController?.clear();
  }
}
```

**Risk:** When app resumes, the player's `visible` is set to true. The native video surface should resume rendering. On some Android versions, the video surface may need explicit re-attachment. The `showDanmaku` toggle only affects danmaku, not the video.

**Gray risk: LOW.** Standard lifecycle handling.

### 2.9 Temporary Quiet-Control Insertion Points

Any new Obx wrapper or conditional that changes the widget tree around `PLVideoPlayer` could:
1. Cause unnecessary rebuilds of the player widget
2. Insert `SizedBox.shrink()` in the wrong place, removing the player entirely
3. Change the key or parent widget, causing state loss

**Specifically:** Wrapping the chat PageView in an `Obx` (as 79ff3a3b4 did at view.dart:826-827) or adding `Obx` around the fsSC overlay is safe because these are outside the player widget tree. But any Obx wrapping the player itself is risky.

**Gray risk for quiet controls: LOW if gates are placed outside the player subtree. MEDIUM if any Obx/conditional wraps the player directly.**

---

## 3. Compare Normal Video Safe Temporary Quiet (1134f3d1d) with Live Room

### 3.1 Normal Video's Safe Pattern (from `VideoDetailController`, lib/pages/video/controller.dart:170-230)

```dart
// Fields
final RxBool tempHideReply = false.obs;
final RxBool tempHideDanmaku = false.obs;

// Computed effective gates (3-layer: global → persistent → temporary)
bool get effectiveShowDanmaku => effectiveShowContent(
  globalShow: plPlayerController.enableShowDanmaku.value,
  persistentRuleHide: persistentRuleHideDanmaku,
  temporaryHide: tempHideDanmaku.value,
);

// Toggle methods — no-op when global is off
void toggleTempHideDanmaku() {
  if (!plPlayerController.enableShowDanmaku.value) return;
  tempHideDanmaku.toggle();
  if (tempHideDanmaku.value) {
    plPlayerController.danmakuController?.clear();
  }
}

// Reset on page change
void resetTempQuietControls() {
  tempHideReply.value = false;
  tempHideDanmaku.value = false;
}
```

UI integration in `header_control.dart` uses `ComBtn` with `Obx`:
```dart
Obx(() {
  final tempHide = videoDetailCtr.tempHideDanmaku.value;
  return ComBtn(
    tooltip: tempHide ? '显示弹幕' : '隐藏弹幕',
    onTap: videoDetailCtr.toggleTempHideDanmaku,
    icon: Icon(tempHide ? CustomIcons.dm_off : CustomIcons.dm_on,
        color: tempHide ? Colors.white54 : Colors.white),
  );
})
```

### 3.2 What Can Be Mirrored Safely

| Pattern | Mirror to Live Room? | Notes |
|---|---|---|
| `RxBool` fields on page controller | **YES** | Add `tempHideDanmaku` and `tempHideSC` to `LiveRoomController` |
| `ComBtn` toggle in header | **YES** | Same `ComBtn` widget already used in live room header (header_control.dart:112-249) |
| PopupMenuDivider + PopupMenuItem with Obx | **YES** | Insert into existing `PopupMenuButton` at view.dart:618-708 |
| Global gate: no-op toggle when global off | **YES** | `if (!enableShowDanmaku.value) return;` for danmaku; `if (!showSuperChat) return;` for SC |
| `clear()` danmaku on hide | **PARTIALLY** | Live danmaku is transient; clearing is less important but harmless. Live room danmaku is canvas-based, not a list — `danmakuController?.clear()` should work |
| Reset on page change | **N/A** | Live room doesn't have a page-change reset trigger; `onClose()` handles full dispose |

### 3.3 What Cannot Be Mirrored Directly

| Pattern | Why Not | Alternative |
|---|---|---|
| `effectiveShowDanmaku` getter | Normal video has a 3-layer gate; live room only needs 2-layer (global + temporary). Also, live room uses `enableShowDanmaku` inline in `_LiveDanmakuState.build()` at view.dart:1112 | Inline the check: `enableShowDanmaku.value && !tempHideDanmaku.value` — same as 79ff3a3b4 did |
| Persistent rule layer | Live room has no `ChannelQuietRule` concept | Skip entirely — live room only needs page-local temporary |
| `resetTempQuietControls()` on video/page change | Live room pages don't change in the same way | The fields reset naturally on `onClose()`/dispose; no explicit reset needed |

### 3.4 Structural Differences That Matter

1. **Danmaku rendering:** Normal video uses `PlDanmaku` widget with its own Obx. Live room uses `_LiveDanmakuState.build()` with `AnimatedOpacity` + `DanmakuScreen`. The gate is at opacity level (view.dart:1112): `enableShowDanmaku.value ? opacity : 0`. Adding `&& !tempHideDanmaku.value` here is safe.

2. **SC rendering:** Normal video doesn't have SuperChat. Live room has SC at 3 points:
   - Fullscreen overlay (`fsSC` Obx at view.dart:328-362)
   - Chat PageView SC tab (view.dart:780-797)
   - Chat list `SuperChatCard` items (chat_panel.dart:129-135)

3. **Global SC gate:** Normal video uses `showReply`. Live room uses `showSuperChat` (a `bool`, not Rx — derived from `Pref.superChatType` at controller.dart:129). This means popup menu items checking `showSuperChat` won't be reactive if the setting changes, but since it's read from Pref at init, this is acceptable for a page-local toggle.

---

## 4. Exact Prior Failure Modes — Do NOT Repeat

The following are compiled from the wrong-implementation records (`01-culprit-and-revert-audit.md`, `01-post-5119-audit.md`) and the `79ff3a3b4` diff. Every implementation slice must avoid **all** of these.

### F1: SC Chat-List Leakage (Issue A from 01-culprit)

**Symptom:** `SuperChatCard` entries in the chat message list remain visible when SC is toggled "hidden."

**Root cause:** Commit `79ff3a3b4` gated the SC PageView tab and fullscreen SC overlay but **did not gate** `SuperChatCard` in `chat_panel.dart:129-135`:

```dart
// chat_panel.dart — 79ff3a3b4 MISSED this gate:
if (item is SuperChatItem) {
    return SuperChatCard(item: item, persistentSC: true, ...); // NO tempHideSC check
}
```

**Prevention:** Add `if (liveRoomController.tempHideSC.value) return const SizedBox.shrink();` before the `SuperChatCard` return in `chat_panel.dart`.

### F2: `ever()` Watcher Destroys fsSC Content (Issue B from 01-culprit)

**Symptom:** When user toggles SC off then on, the previously visible fullscreen SuperChat is gone forever.

**Root cause:** Commit `79ff3a3b4` added `ever(tempHideSC, ...)` in `controller.dart:154-158`:

```dart
ever(tempHideSC, (bool value) {
  if (value) {
    fsSC.value = null;  // Clears only on true→false—wait, no, clears when value==true
  }
});
```

On `tempHideSC` toggle false→true: `fsSC` cleared. On toggle true→false: `fsSC` is already null, nothing to restore. The `ever()` is destructive.

**Prevention:** Do NOT use `ever()` listener. Remove it entirely. The normal video pattern does NOT use `ever()`. The line 516 gate (`!tempHideSC.value` check in `SUPER_CHAT_MESSAGE` handler) already prevents new SC display when hidden. Existing `fsSC` content can be left in memory — it won't render because the `fsSC` Obx at view.dart:328-362 checks `tempHideSC.value`.

### F3: Slice-3 Report Mismatch (Issue C from 01-culprit)

**Symptom:** Slice-3 report described `Icons.star`/`Icons.star_border` for SC toggle icon, but commit used `Icons.visibility_off`/`Icons.visibility`.

**Root cause:** Implementation was changed after the slice report was written without updating the artifact. This breaks evidence traceability.

**Prevention:** Any change from the slice plan must update the corresponding persisted artifact. Use `Icons.visibility_off/Icons.visibility` (consistent with 79ff3a3b4's actual usage and more semantically correct) or decide and document explicitly.

### F4: Wrong Merge-Base (Implicit from 01-post-5119-audit)

**Symptom:** Commit `79ff3a3b4` was built on `a4b1fcbe5` (origin/production), which is 2 commits behind the trusted base `1134f3d1d`. The `LiveDanmaku` widget signature differs between these baselines.

**Root cause:** The implementation targeted the wrong code baseline. Diff inspection confirmed merge-base mismatch.

**Prevention:** ALL implementation slices MUST be written against `1134f3d1d`. Verify with `git merge-base HEAD 1134f3d1d` before every edit. The current working branch HEAD IS `1134f3d1d` — confirmed in 01-post-5119-audit.md Section 1.

### F5: Dirty Worktree Contamination

**Symptom:** The main worktree at `/home/mo/Documents/piliavalon` on `production` branch has uncommitted modifications matching `79ff3a3b4` exactly (`git diff 79ff3a3b -- lib/pages/live_room/...` returns empty).

**Prevention:** The implementation is in the clean worktree at `/tmp/piliavalon-task026-issue8-9104`. Do NOT use, reference, or copy from `/home/mo/Documents/piliavalon`.

### F6: Wrong Baselines (0224, 4846, 2193)

**Symptom:** Three commits/branches were initially considered as baselines and all rejected by user.

**Prevention:** Only `1134f3d1d` is the trusted baseline. Do not inspect, merge, or rebase onto any of: `27142160224`, `27180424846`, `27181102193`.

### F7: `tempHideDanmaku` Gate in `addDm()` Is Incomplete (from 79ff3a3b4 diff)

**79ff3a3b4 change to controller.dart:437:**
```dart
// Before: if (item != null) { danmakuController?.addDanmaku(item); }
// After:  if (item != null && !tempHideDanmaku.value) { danmakuController?.addDanmaku(item); }
```

This prevents danmaku items from being added to the canvas controller but does NOT prevent the auto-scroll trigger that follows. **Not a gray-player risk**, but an implementation subtlety to note: the autoScroll trigger fires even when danmaku is hidden, scrolling the chat list unnecessarily.

**Prevention:** Keep the `!tempHideDanmaku.value` guard in `addDm()` but also consider guarding the auto-scroll inside the same condition block, OR leave it (harmless).

### F8: SC `addDm()` Still Called When Hidden (from 79ff3a3b4 diff)

**79ff3a3b4 change to `SUPER_CHAT_MESSAGE` handler (controller.dart:507-516):**
```dart
if (plPlayerController.showDanmaku &&
    !tempHideSC.value &&            // ← added gate
    (isFullScreen || ...)) {
  fsSC.value = item.copyWith(...); // gate prevents fsSC assignment
}
addDm(item);  // ← STILL called unconditionally — SC added to messages list
```

The `addDm(item)` call adds the SuperChat to the messages list for chat rendering. Since `chat_panel.dart` doesn't gate `SuperChatItem`, these SC cards appear in chat even when hidden.

**Prevention:** Gate `addDm(item)` or gate `SuperChatItem` rendering in chat_panel.dart (see F1).

### F9: Global `enableShowDanmaku` Checks in 79ff3a3b4 Popup Menu

**79ff3a3b4 view.dart diff (popup menu):**
```dart
if (mounted && plPlayerController.enableShowDanmaku.value)
  PopupMenuItem(...tempHideDanmaku toggle...)
```

The `enableShowDanmaku.value` is read once at menu build time, NOT reactively. If the menu is already open and the user toggles global danmaku, the menu item won't disappear.

**Prevention:** This is acceptable behavior (menu rebuilds on next open). But the alternative is to always show the menu item and disable it when global is off — either approach is fine as long as the behavior is documented.

---

## 5. Recommended Safe Implementation Strategy

### Design Principle

**All temporary quiet controls are rendering-only gates.** They gate what is displayed, never what is received or processed. The player surface and lifecycle remain untouched. The websocket continues receiving all messages. `GStorage`/`Pref`/Hive are never written for temporary state.

### Slice Plan (5 atomic slices)

#### Slice 1: Controller Fields (lib/pages/live_room/controller.dart)

Add to `LiveRoomController` class body:

```dart
/// Temporary per-page hide overrides. Page-local and non-persistent.
/// Reset naturally when the controller is disposed.
final tempHideDanmaku = false.obs;
final tempHideSC = false.obs;
```

- **Do NOT add `ever()` listener.**
- **Do NOT add `GStorage`/`Pref`/Hive writes.**
- Place after `disableAutoScroll` (line 109) for logical grouping.

#### Slice 2: Danmaku Rendering Gates (2 files)

**File A: view.dart `_LiveDanmakuState.build()` (line 1110-1126)**

Change:
```dart
opacity: plPlayerController.enableShowDanmaku.value
    ? plPlayerController.danmakuOpacity.value
    : 0,
```
To:
```dart
opacity: plPlayerController.enableShowDanmaku.value
        && !widget.liveRoomController.tempHideDanmaku.value
    ? plPlayerController.danmakuOpacity.value
    : 0,
```

**File B: chat_panel.dart itemBuilder for DanmakuMsg (line ~58)**

Add before the `DanmakuMsg` rendering:
```dart
if (item is DanmakuMsg) {
    if (liveRoomController.tempHideDanmaku.value) {
        return const SizedBox.shrink();
    }
    // existing DanmakuMsg rendering...
}
```

(Same as 79ff3a3b4's approach — this pattern is correct for the chat list.)

#### Slice 3: SuperChat Rendering Gates (2 files)

**File A: chat_panel.dart itemBuilder for SuperChatItem (line 129)**

Add before `SuperChatCard`:
```dart
if (item is SuperChatItem) {
    if (liveRoomController.tempHideSC.value) {
        return const SizedBox.shrink();
    }
    return SuperChatCard(...);
}
```

This fixes **F1 (SC chat-list leakage)**.

**File B: view.dart Chat PageView SC tab (line 780)**

Wrap with `Obx` to react to `tempHideSC`:
```dart
child: Obx(() =>
    _liveRoomController.showSuperChat && !_liveRoomController.tempHideSC.value
        ? PageView(...existing PageView with chat() + SuperChatPanel...)
        : chat(),
),
```

**File C: view.dart Fullscreen SC overlay (line 329)**

Add gate to existing `Obx`:
```dart
final item = _liveRoomController.fsSC.value;
if (item == null || _liveRoomController.tempHideSC.value) {
    return const SizedBox.shrink();
}
```

(Same as 79ff3a3b4's approach — correct.)

**Note:** The `SUPER_CHAT_MESSAGE` handler in controller.dart (line 504-516) DOES NOT need a `tempHideSC` gate for `fsSC` assignment. The rendering gates above prevent display. Keeping `fsSC` in memory is harmless and avoids the **F2 (ever() destroy)** problem. The `addDm(item)` call at line 516 can remain unconditional — the chat_panel gate from File A above handles SuperChatCard hiding.

#### Slice 4: Header Toggle Buttons (lib/pages/live_room/widgets/header_control.dart)

Add two `ComBtn` widgets inside the existing `Row` children (before the closing `]` at line 249):

**Danmaku toggle:**
```dart
Obx(() {
  final globalDanmakuOn =
      liveController.plPlayerController.enableShowDanmaku.value;
  if (!globalDanmakuOn) return const SizedBox.shrink();
  final tempHideDanmaku = liveController.tempHideDanmaku.value;
  return ComBtn(
    height: 30,
    tooltip: tempHideDanmaku ? '显示弹幕' : '隐藏弹幕',
    onTap: () => liveController.tempHideDanmaku.value = !tempHideDanmaku,
    icon: Icon(
      size: 18,
      tempHideDanmaku ? CustomIcons.dm_off : CustomIcons.dm_on,
      color: tempHideDanmaku ? Colors.white54 : Colors.white,
    ),
  );
}),
```

**SC toggle:**
```dart
Obx(() {
  final globalSCOff = !liveController.showSuperChat;
  if (globalSCOff) return const SizedBox.shrink();
  final tempHideSC = liveController.tempHideSC.value;
  return ComBtn(
    height: 30,
    tooltip: tempHideSC ? '显示SC' : '隐藏SC',
    onTap: () => liveController.tempHideSC.value = !tempHideSC,
    icon: Icon(
      size: 18,
      tempHideSC ? Icons.visibility_off : Icons.visibility,
      color: tempHideSC ? Colors.white54 : Colors.white,
    ),
  );
}),
```

- `CustomIcons` import (for `dm_on`/`dm_off`) already exists in header_control.dart? **CHECK:** No — the current clean base header_control.dart does NOT import `custom_icon.dart`. Add: `import 'package:PiliPlus/common/widgets/custom_icon.dart';`.

#### Slice 5: Popup Menu Toggle Items (lib/pages/live_room/view.dart)

In the `PopupMenuButton`'s `itemBuilder` (line 620-706), add before the closing `];`:

```dart
const PopupMenuDivider(),
if (mounted && plPlayerController.enableShowDanmaku.value)
  PopupMenuItem(
    onTap: () => _liveRoomController.tempHideDanmaku.toggle(),
    child: Obx(() => Row(
      spacing: 10,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _liveRoomController.tempHideDanmaku.value
              ? CustomIcons.dm_off : CustomIcons.dm_on,
          size: 19, color: color,
        ),
        Text(_liveRoomController.tempHideDanmaku.value ? '显示弹幕' : '隐藏弹幕'),
      ],
    )),
  ),
if (mounted && _liveRoomController.showSuperChat)
  PopupMenuItem(
    onTap: () => _liveRoomController.tempHideSC.toggle(),
    child: Obx(() => Row(
      spacing: 10,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _liveRoomController.tempHideSC.value
              ? Icons.visibility_off : Icons.visibility,
          size: 19, color: color,
        ),
        Text(_liveRoomController.tempHideSC.value ? '显示 SC' : '隐藏 SC'),
      ],
    )),
  ),
```

### 5.1 What This Strategy Does NOT Touch

| Untouched | Why |
|---|---|
| `lib/plugin/pl_player/` | Player surface and lifecycle constraint — no changes to shared player |
| Player construction Obx (view.dart:252-291) | No wrapping, no conditional changing around PLVideoPlayer |
| `didPushNext`/`didPopNext` | No lifecycle changes needed for rendering-only gates |
| `didChangeAppLifecycleState` | No app lifecycle changes |
| `queryLiveUrl`/`playerInit` | No changes to player initialization flow |
| LiveMessageStream / websocket | No changes to data reception |
| `GStorage`/`Pref`/Hive | No persistence writes for temporary state |
| `addDm()` in controller.dart | NOT modified — gates are only in rendering, not in data flow. This is a deliberate divergence from 79ff3a3b4 to avoid touching controller logic. |
| `SUPER_CHAT_MESSAGE` handler (line 504-516) | NOT modified — rendering gates handle visibility |

### 5.2 How This Prevents Gray/Uncontrollable Player

1. **No Obx wrapping around PLVideoPlayer construction** — the player widget tree is unchanged.
2. **No conditional that can return SizedBox.shrink() for the player** — the `isLoaded && isLive` gate remains the only gate; temp flags only gate danmaku/SC overlays.
3. **No `ever()` listeners** — no reactive side effects that could mutate player state.
4. **No changes to `isLoaded`, `isLive`, `videoUrl`, `playerInit`, `queryLiveUrl`** — the player initialization path is untouched.
5. **No `setDataSource` or `PlPlayerController` modifications** — the shared player controller is not touched.

---

## 6. Recommended Tests / Static Checks / Manual Smoke Steps for Gray Player Risk

### 6.1 Static Checks (Pre-Implementation)

```bash
# Verify working on correct baseline
git merge-base HEAD 1134f3d1d5305df13b28d0657ac121711e0b68fc
# Must output: 1134f3d1d5305df13b28d0657ac121711e0b68fc

# Verify no dirty files in pl_player
git diff --name-only HEAD -- lib/plugin/pl_player/
# Must be empty

# Verify only expected files touched after implementation
git diff --name-only HEAD
# Must be subset of:
#   lib/pages/live_room/controller.dart
#   lib/pages/live_room/view.dart
#   lib/pages/live_room/widgets/chat_panel.dart
#   lib/pages/live_room/widgets/header_control.dart
```

### 6.2 dart analyze (Post-Implementation)

```bash
dart analyze lib/pages/live_room/controller.dart
dart analyze lib/pages/live_room/view.dart
dart analyze lib/pages/live_room/widgets/chat_panel.dart
dart analyze lib/pages/live_room/widgets/header_control.dart
# All must pass with no errors
```

### 6.3 Manual Smoke Steps (on Device/Emulator)

These are the critical gray-player-risk-specific smoke steps:

| # | Step | Expected | Gray Risk Checked |
|---|---|---|---|
| 1 | Open a live room from cold start | Video plays within ~3 seconds. No persistent gray frame. | `isLoaded` + `playerInit` race window |
| 2 | Navigate to another page, then back (didPushNext → didPopNext) | Video resumes playing. No gray frame. | `didPopNext` re-init path |
| 3 | Send app to background, bring to foreground | Video resumes. No gray frame. | `didChangeAppLifecycleState` |
| 4 | Rotate device to landscape, back to portrait | Player adapts. No gray frame. | Orientation change rebuild |
| 5 | Enter fullscreen, exit fullscreen | Player transitions smoothly. No gray frame. | Fullscreen toggle |
| 6 | Toggle danmaku temp-hide ON | Danmaku overlay disappears. Player video continues playing. | Danmaku gate at opacity |
| 7 | Toggle danmaku temp-hide OFF | Danmaku overlay reappears. Player video continues playing. | Danmaku gate reversal |
| 8 | Toggle SC temp-hide ON | SC overlay, SC tab, SC chat cards all disappear. Video continues. | All 3 SC gates |
| 9 | Toggle SC temp-hide OFF | SC elements reappear. Video continues. | SC gate reversal |
| 10 | With SC visible, toggle hide, then unhide | SC reappears (not destroyed). See **F2 fix**. | `ever()` absence |
| 11 | Toggle SC hide, send a SuperChat in chat | SC does NOT appear in chat list. Video continues. | Chat-list SC gate (F1 fix) |
| 12 | Global danmaku OFF → temp toggle button invisible | No temporary danmaku toggle in header or popup | Global gate dominance |
| 13 | Global SC OFF → temp toggle button invisible | No temporary SC toggle in header or popup | Global gate dominance |
| 14 | Temp-hide danmaku ON, kill and reopen live room | Temp state reset (danmaku visible again) | Non-persistence |
| 15 | Temp-hide SC ON, kill and reopen live room | Temp state reset (SC visible again) | Non-persistence |

### 6.4 Specific Gray Player Regression Test

**The most important test:** Open a live room, wait for video to start, then rapidly toggle danmaku/SC hide ON and OFF 5 times in quick succession. The video player must NOT flicker gray, freeze, or become unresponsive. The danmaku/SC overlays must appear and disappear cleanly.

---

## 7. Prevention Checklist for Codex/Reasonix Implementation Slices

### Pre-Implementation (Codex Review)

- [ ] **Baseline confirmed:** `git merge-base HEAD 1134f3d1d` == `1134f3d1d`
- [ ] **No dirty pl_player files:** `git diff --name-only HEAD -- lib/plugin/pl_player/` is empty
- [ ] **Worktree is clean:** Running from `/tmp/piliavalon-task026-issue8-9104`, NOT `/home/mo/Documents/piliavalon`
- [ ] **No forbidden sources:** Not reusing anything from `79ff3a3b4`, `0224`, `4846`, `2193`, or dirty worktrees
- [ ] **Slice plan approved:** The 5-slice plan in Section 5 above reviewed and accepted

### Per-Slice (Reasonix Implementation, Codex Review)

- [ ] **Slice 1 (Controller):** Only `tempHideDanmaku` and `tempHideSC` added. NO `ever()`. NO `GStorage`/`Pref`/Hive. NO changes to `addDm()` or `SUPER_CHAT_MESSAGE` handler.
- [ ] **Slice 2 (Danmaku gates):** Only view.dart opacity line + chat_panel.dart DanmakuMsg gate. No Obx wrapping PLVideoPlayer.
- [ ] **Slice 3 (SC gates):** chat_panel.dart SuperChatItem gate + view.dart PageView gate + view.dart fsSC gate. NO `ever()` in controller. NO changes to data flow handlers.
- [ ] **Slice 4 (Header):** Two ComBtn widgets inside existing Row. Correct icon: `CustomIcons.dm_on/dm_off` for danmaku, `Icons.visibility_off/visibility` for SC. White54 when hidden.
- [ ] **Slice 5 (Popup menu):** PopupMenuDivider + two PopupMenuItem widgets. Gated on global settings.

### Post-Implementation (Codex Review)

- [ ] **File scope check:** Only 4 files modified (controller.dart, view.dart, chat_panel.dart, header_control.dart)
- [ ] **dart analyze passes** on all 4 files
- [ ] **No player surface changes:** Diff does not touch `lib/plugin/pl_player/`
- [ ] **No Obx wrapping PLVideoPlayer construction:** The `Obx` at view.dart:252 still only reads `isLoaded` and `isLive`
- [ ] **No `ever()` anywhere in the diff**
- [ ] **No persistence writes in the diff** (no `GStorage.setting.put`, no `Pref.`, no Hive)
- [ ] **Global gates dominant:** Temp toggles cannot re-enable when global is off (verified in Slice 4 and 5)
- [ ] **SC chat-list gate present:** chat_panel.dart has `tempHideSC` check before `SuperChatCard` (F1 fix verified)
- [ ] **fsSC not cleared by ever():** No `ever(tempHideSC, ...)` in controller.dart (F2 fix verified)
- [ ] **VersionCode bump:** Not in this implementation scope — Codex handles separately

### Failure Mode Cross-Reference

| Failure Mode | Prevention Verified |
|---|---|
| F1: SC chat-list leakage | chat_panel.dart SuperChatItem gate present |
| F2: ever() destroys fsSC | No ever() listener in controller.dart |
| F3: Slice report mismatch | This audit serves as the reference; any deviation must be documented |
| F4: Wrong merge-base | Verified HEAD == 1134f3d1d |
| F5: Dirty worktree contamination | Working in clean worktree at /tmp/piliavalon-task026-issue8-9104 |
| F6: Wrong baselines | Only 1134f3d1d used; 0224/4846/2193 excluded |
| F7: Incomplete addDm() gate | Not touching addDm() — rendering gates only |
| F8: SC addDm() called when hidden | Not gating in data flow — rendering gates in chat_panel handle it |
| F9: Non-reactive popup menu global check | Acceptable — popup rebuilds on next open |

---

## 8. Evidence Log

### Commands run during this audit

```
1. read_file on 5 required records (see Section references)
2. grep on PLVideoPlayer/pl_player across lib/pages/live_room, lib/pages/video, lib/plugin/pl_player
3. read_file on lib/pages/live_room/view.dart (offsets 60-260, 290-371, 610-710, 770-870, 1090-1127)
4. read_file on lib/pages/video/view.dart (offset 1370-1450)
5. read_file on lib/plugin/pl_player/view/view.dart (offset 85-205)
6. read_file on lib/pages/live_room/controller.dart (offset 1-300, 490-550)
7. read_file on lib/pages/live_room/widgets/header_control.dart (full)
8. read_file on lib/pages/live_room/widgets/chat_panel.dart (offset 120-190)
9. read_file on lib/pages/video/controller.dart (offset 160-240)
10. grep on enableShowDanmaku/showSuperChat/tempHide across lib/pages/video and lib/pages/live_room
11. grep on ComBtn/toggleTempHide in video/widgets/header_control.dart
12. grep on PopupMenuButton in lib/pages/live_room/view.dart
13. grep on didPushNext/didPopNext/AppLifecycle in lib/pages/live_room
14. git show 79ff3a3b4 --stat
15. git show 79ff3a3b4 -- controller.dart, view.dart, chat_panel.dart, header_control.dart (complete diffs)
16. mkdir -p records/reasonix/2026-06-09-issue8
```

### Files read (source)

| File | Lines read |
|---|---|
| `lib/pages/live_room/view.dart` | 60-371, 610-710, 770-870, 1090-1127 |
| `lib/pages/live_room/controller.dart` | 1-300, 490-550 |
| `lib/pages/live_room/widgets/header_control.dart` | 1-253 (full) |
| `lib/pages/live_room/widgets/chat_panel.dart` | 120-190 |
| `lib/pages/video/view.dart` | 1370-1450 |
| `lib/pages/video/controller.dart` | 160-240 |
| `lib/plugin/pl_player/view/view.dart` | 85-205 |
| `79ff3a3b4` diff | Full (4 files) |

---

## 9. Summary for Codex

1. **Player code IS shared** — `PLVideoPlayer` and `PlPlayerController` serve both live room and normal video. Changes to them affect both. Our implementation does NOT touch them.

2. **Gray/uncontrollable risk is real but manageable** — The most likely cause is the gap between `isLoaded = true` and a working native video surface. Our rendering-only gates do not affect this path.

3. **Normal video's safe pattern can be mostly mirrored** — `RxBool` fields, `ComBtn` toggles, `PopupMenuItem` toggles, and rendering gates are all applicable. Persistent rules and `effectiveShow*` getters are NOT needed.

4. **Eight prior failure modes cataloged** — Every one has a specific prevention built into the slice plan. The two worst (F1 SC leakage, F2 ever() destroy) are explicitly prevented.

5. **Five-slice plan is safe** — No player surface changes, no lifecycle changes, no data-flow changes. Rendering gates only.

6. **Smoke test list targets gray-player risk** — 15 manual steps plus one rapid-toggle regression test.

7. **Checklist is comprehensive** — Cross-references all 9 failure modes against specific prevention items.
