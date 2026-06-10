# Issue 8 Controller Message Gates — Implementation Report

Audience classification: agent-facing
Date: 2026-06-09
Implementer: Reasonix (controller-message-gates)
Review owner: Codex
Trusted base: commit `1134f3d1d5305df13b28d0657ac121711e0b68fc`
Working branch: `task-026-live-room-quiet-controls-issue8-9104`

---

## 1. Summary

This slice implements the **controller-side message gates** for temporary live-room
danmaku and Super Chat hiding, as specified by the updated user semantics
(2026-06-09). The implementation adds two page-local, non-persistent reactive
fields with toggle methods and gates message feeding at the data-flow layer in
`controller.dart` — dropping hidden message types **before** they reach UI lists
and overlays, without disconnecting the websocket or touching shared player code.

---

## 2. Exact Code Changes

### File changed

| File | Delta |
|------|-------|
| `lib/pages/live_room/controller.dart` | +26 lines (fields + methods + gates) |

**No other files modified.** Shared player code (`lib/plugin/pl_player/`) was not
touched. View-rendering gates (`view.dart`, `chat_panel.dart`, `header_control.dart`)
are out of scope for this slice and remain unchanged.

### Change 1: Reactive fields (lines 110–111)

```dart
final tempHideDanmaku = false.obs;
final tempHideSC = false.obs;
```

Added immediately after `disableAutoScroll` (line 109), alongside the existing
list of page-local reactive fields. Both default to `false` — when the live room
is opened next time, the `LiveRoomController` is freshly constructed, so the
state resets naturally without any explicit reset logic.

### Change 2: Toggle methods (lines 340–357)

```dart
void toggleTempHideDanmaku() {
  if (!plPlayerController.enableShowDanmaku.value) return;
  tempHideDanmaku.toggle();
  if (tempHideDanmaku.value) {
    danmakuController?.clear();
    messages.removeWhere((msg) => msg is DanmakuMsg);
  }
}

void toggleTempHideSC() {
  if (!showSuperChat) return;
  tempHideSC.toggle();
  if (tempHideSC.value) {
    fsSC.value = null;
    superChatMsg.clear();
    messages.removeWhere((msg) => msg is SuperChatItem);
  }
}
```

**Key properties:**

- **Global gate first:** `toggleTempHideDanmaku()` is a no-op when
  `enableShowDanmaku` is off. `toggleTempHideSC()` is a no-op when
  `showSuperChat` is false. Global settings remain authoritative.
- **Cleanup on hide:**
  - Danmaku hide: clears the canvas danmaku overlay via
    `danmakuController?.clear()` and removes all `DanmakuMsg` entries from
    `messages` — current hidden chat rows disappear without clearing SC/system
    items.
  - SC hide: nulls `fsSC` (fullscreen SC overlay), clears the `superChatMsg`
    list, and removes all `SuperChatItem` entries from `messages` — SC UI
    disappears immediately.
- **No `ever()` listeners.** The reactive boolean values are checked directly at
  message-reception points — not through reactive side-effect chains.

### Change 3: addDm() message gates (lines 449–465)

```dart
void addDm(dynamic msg, [DanmakuContentItem<DanmakuExtra>? item]) {
    if (plPlayerController.showDanmaku) {
      if (item != null && !tempHideDanmaku.value) {
        danmakuController?.addDanmaku(item);
      }
      if (autoScroll && !disableAutoScroll.value) {
        if (msg is! DanmakuMsg || !tempHideDanmaku.value) {
          messages.add(msg);
          scrollToBottom();
        }
        return;
      }
    }

    if (msg is DanmakuMsg && tempHideDanmaku.value) return;
    messages.addOnly(msg);
  }
```

**What changed (3 gate points):**

1. **Danmaku overlay gate (line 451):** `item != null && !tempHideDanmaku.value` —
   when temp hide is active, `DanmakuContentItem` is not added to
   `danmakuController`. The canvas overlay receives no new danmaku items.
2. **Auto-scroll message gate (line 455):** `msg is! DanmakuMsg || !tempHideDanmaku.value` —
   when temp hide is active, `DanmakuMsg` entries are not added to `messages`
   via the auto-scroll path. Non-danmaku messages (e.g. `SuperChatItem`) pass
   through unchanged.
3. **Fallback message gate (line 463):** `if (msg is DanmakuMsg && tempHideDanmaku.value) return;` —
   when auto-scroll is disabled or global danmaku is off, `DanmakuMsg` entries
   are still dropped if temp hide is active. Preserves `addOnly` behavior for
   visible messages.

**Preserved behavior:**

- `SuperChatItem` messages flow through `addDm()` unchanged (they are gated at
  their source in the `SUPER_CHAT_MESSAGE` handler — see Change 4).
- Auto-scroll (`scrollToBottom()`) fires only for visible messages.
- Non-danmaku messages (`WATCHED_CHANGE`, `ONLINE_RANK_COUNT`, etc.) are
  unaffected.

### Change 4: SUPER_CHAT_MESSAGE handler gate (lines 528–543)

```dart
case 'SUPER_CHAT_MESSAGE' when showSuperChat:
  final item = SuperChatItem.fromJson(obj['data']);
  if (!tempHideSC.value) {
    superChatMsg.insert(0, item);
    if (plPlayerController.showDanmaku &&
        (isFullScreen || plPlayerController.isDesktopPip)) {
      fsSC.value = item.copyWith(
        endTime: math.min(
          item.endTime,
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10,
        ),
      );
    }
    addDm(item);
  }
  break;
```

**What changed:** The entire SC UI feeding block (`superChatMsg.insert`,
`fsSC` assignment, `addDm()`) is wrapped in `if (!tempHideSC.value)`. When
`tempHideSC` is active:

- The item is **not** inserted into `superChatMsg` (SC PageView list).
- `fsSC` is **not** set (no fullscreen SC overlay).
- `addDm(item)` is **not** called (no SuperChatCard in the chat message list).

**The websocket remains connected.** The `SUPER_CHAT_MESSAGE` case is still
matched (the `when showSuperChat` guard still passes), the JSON is still parsed,
but the parsed item is simply dropped — no UI feeding occurs.

---

## 3. How This Satisfies Updated User Semantics

| User requirement | How satisfied |
|---|---|
| Temp hide stops UI from accepting/feeding hidden message types | DanmakuMsg blocked in `addDm()` at 3 points; SuperChatItem blocked at source in handler |
| Do not disconnect websocket | `_msgStream` and `_danmakuListener` are untouched; the `DANMU_MSG` and `SUPER_CHAT_MESSAGE` cases still fire |
| Do not touch shared player code | Zero changes to `lib/plugin/pl_player/` |
| Do not touch player lifecycle | Zero changes to `playerInit`, `queryLiveUrl`, `isLoaded`, `isLive`, `didPushNext`, `didPopNext`, app lifecycle |
| When temp hide is turned off, subsequent incoming messages feed UI again | Toggle flips `tempHideDanmaku`/`tempHideSC` from `true` to `false`; gates become pass-through; no data loss of future messages |
| When live room opened next time, temp state starts default false | Fields are `false.obs`; `LiveRoomController` is freshly constructed per page open; no persistence |
| When hiding, clear current danmaku overlay | `danmakuController?.clear()` in `toggleTempHideDanmaku()` |
| When hiding, remove DanmakuMsg from messages without clearing SC/system | `messages.removeWhere((msg) => msg is DanmakuMsg)` — type-safe removal |
| When hiding SC, clear fsSC, superChatMsg, and SuperChatItem from messages | `fsSC.value = null`, `superChatMsg.clear()`, `messages.removeWhere((msg) => msg is SuperChatItem)` |
| Global settings remain authoritative | `toggleTempHideDanmaku` no-ops when `enableShowDanmaku` is off; `toggleTempHideSC` no-ops when `showSuperChat` is false |
| No `ever()` listeners | Zero `ever()` calls in the entire diff |
| Non-hidden message behavior preserved | Auto-scroll fires only for visible messages; `addOnly` path preserved for non-danmaku items |

---

## 4. What Was NOT Touched

| Untouched | Why |
|---|---|
| `lib/plugin/pl_player/` | Player surface and lifecycle constraint — no changes to shared player |
| Player construction (`view.dart:252-291`) | No wrapping, no conditional changes |
| `didPushNext` / `didPopNext` | No lifecycle changes needed |
| `didChangeAppLifecycleState` | No app lifecycle changes |
| `queryLiveUrl` / `playerInit` | No changes to player initialization |
| LiveMessageStream / websocket | No changes to data reception layer; websocket stays connected |
| `GStorage` / `Pref` / Hive | No persistence writes for temporary state |
| `view.dart` | Not in this slice scope |
| `chat_panel.dart` | Not in this slice scope |
| `header_control.dart` | Not in this slice scope |

---

## 5. Static Checks

| Check | Result |
|-------|--------|
| `dart format lib/pages/live_room/controller.dart` | **Not available** — `dart` command not found in PATH; no Flutter/Dart SDK installed in this environment |
| `dart analyze lib/pages/live_room/controller.dart` | **Not available** — same reason as above |
| Brace balance validation | **PASS** — Python script confirms `{`/`}` balance = 0 across 674 lines |
| File scope check (`git diff --name-only`) | **PASS** — only `lib/pages/live_room/controller.dart` modified |
| No player code touched | **PASS** — `git diff --name-only -- lib/plugin/pl_player/` is empty |

The `dart` toolchain is not installed in this sandbox environment. Static
analysis should be run in the local Flutter workspace (where `dart` is available
via the Flutter SDK) before commit.

---

## 6. Suggested Codex Review Checks

1. **Correctness of addDm() control flow:**
   - Confirm that when `showDanmaku` is true + autoScroll enabled + tempHideDanmaku is true,
     the function returns without adding the DanmakuMsg to messages *and* without
     falling through to `messages.addOnly()`.
   - Confirm that when `showDanmaku` is false + tempHideDanmaku is true, the
     fallback gate at line 463 catches the DanmakuMsg.

2. **SUPER_CHAT_MESSAGE gate completeness:**
   - Verify that when `tempHideSC` is true, *nothing* is written to
     `superChatMsg`, `fsSC`, or `messages` from the SC handler.

3. **Toggle cleanup is type-safe:**
   - `messages.removeWhere((msg) => msg is DanmakuMsg)` — does not remove
     `SuperChatItem`, system messages, or other types.
   - `messages.removeWhere((msg) => msg is SuperChatItem)` — does not remove
     `DanmakuMsg`, system messages, or other types.

4. **No `ever()` usage:** Grep the full diff for `ever(` — should be zero
   matches.

5. **No persistence:** Grep the full diff for `GStorage`, `Pref.`, `Hive` —
   should be zero matches.

6. **Global gate precedence:** Trace both toggle methods — the first line is
   a global-off early return, preventing toggle when the feature is disabled.

7. **Websocket continuity:** The `_danmakuListener` method body is unchanged
   except for the `if (!tempHideSC.value)` wrapper inside the
   `SUPER_CHAT_MESSAGE` case. The stream, `init()`, and `close()` are untouched.

8. **Future slices:** The rendering gates in `view.dart`, `chat_panel.dart`, and
   the toggle UI in `header_control.dart` are still needed to:
   - Gate the `_LiveDanmakuState.build()` opacity check
   - Gate `DanmakuMsg` rows in `chat_panel.dart` itemBuilder
   - Gate SC PageView and fullscreen SC overlay in `view.dart`
   - Add `ComBtn` toggle buttons in `header_control.dart`
   - Add popup menu toggle items in `view.dart`

---

## 7. Evidence Log

### Commands run

```
1. git diff lib/pages/live_room/controller.dart — full diff confirmed
2. git diff --name-only — confirmed only controller.dart modified
3. python3 brace balance check — confirmed brace balance = 0
4. dart format — FAILED (dart not in PATH)
5. dart analyze — NOT ATTEMPTED (dart not in PATH)
```

### Files inspected

| File | How |
|------|-----|
| `lib/pages/live_room/controller.dart` | Full read (674 lines) + 4 targeted reads post-edit |
| `records/session/2026-06-09-issue8-5119-clean-base-context.md` | Full read |
| `records/reasonix/2026-06-09-issue8/01-post-5119-audit.md` | Full read |
| `records/reasonix/2026-06-09-issue8/02-live-player-gray-risk-audit.md` | Full read |
