# Post-5119 Audit: Live Room Temporary Quiet Controls

Audience classification: agent-facing
Date: 2026-06-09
Auditor: Reasonix (post-5119-audit)
Review owner: Codex
Trusted base: commit `1134f3d1d5305df13b28d0657ac121711e0b68fc` (versionCode 5119)

---

## 1. Current Branch and Base Commit Confirmation

| Item | Value |
|------|-------|
| Current branch | `task-026-live-room-quiet-controls-issue8-9104` |
| HEAD commit | `1134f3d1d5305df13b28d0657ac121711e0b68fc` |
| HEAD tag | `task020-temp-quiet-27148639104` |
| origin/production | `a4b1fcbe5` (Record Task-020 continuation snapshot) |
| Trusted base matches HEAD? | **YES** — HEAD IS the trusted base |

**Command:**
```
git status --short --branch
```
Result: `## task-026-live-room-quiet-controls-issue8-9104...origin/task-026-live-room-quiet-controls-issue8-9104`

**Command:**
```
git log --oneline --decorate -5 1134f3d1d5305df13b28d0657ac121711e0b68fc
```
Result: HEAD = `1134f3d1d`, preceded by `17c3d4d8f`, `a4b1fcbe5` (origin/production), `86fa65d70`, `6a20eddad`.

---

## 2. Commits After Trusted Base Visible from origin/production

**Command:**
```
git log --oneline --decorate --graph 1134f3d1d5305df13b28d0657ac121711e0b68fc..origin/production
```

**Result: EMPTY.** There are zero commits between `1134f3d1d` and `origin/production` in the forward direction. `origin/production` (`a4b1fcbe5`) is an **ancestor** of the trusted base `1134f3d1d`. Therefore, all commits on `origin/production` are included in the trusted set.

---

## 3. Post-5119 Commits on Other Branches (Relevant to Live-Room/Quiet)

The following branches exist off the trusted path. I enumerated all commits on task-026 related branches after the trusted merge-base:

| Branch | Commits | Description |
|--------|---------|-------------|
| `origin/task-026-live-room-quiet-controls` | `79ff3a3b4` (tag: `task026-live-room-quiet-27180424846`) | "Implement live room temporary quiet controls" |
| `origin/task-026-live-room-quiet-controls-installable-prerelease` | `27b23eca7`, `68fc0f07a`, then `79ff3a3b4` | Build-number bumps (empty commits) on top of 79ff3a3b4 |
| `origin/task-026-live-room-quiet-controls-issue8-repair` | `786590ffe`, then `79ff3a3b4` | Revert of 79ff3a3b4 |

**Command:**
```
git log --oneline --decorate --graph --all 1134f3d1d..79ff3a3b4 1134f3d1d..786590ffe
```

---

## 4. Classification of Each Relevant Commit

### Commit `79ff3a3b4` — "Implement live room temporary quiet controls"

**Tag:** `task026-live-room-quiet-27180424846`
**Branch:** `origin/task-026-live-room-quiet-controls`
**Merge-base with trusted base:** `a4b1fcbe5` (origin/production) — NOT `1134f3d1d`
**Files changed (4 files, +124/-27):**

| File | Delta |
|------|-------|
| `lib/pages/live_room/controller.dart` | +10/-0 |
| `lib/pages/live_room/view.dart` | +104/-27 |
| `lib/pages/live_room/widgets/chat_panel.dart` | +3/-0 |
| `lib/pages/live_room/widgets/header_control.dart` | +34/-0 |

**Classification: INSPECT-ONLY-DO-NOT-COPY**

**Rationale:**
1. This commit is NOT on `origin/production` and is NOT an ancestor of the trusted base.
2. The merge-base is `a4b1fcbe5`, which is 2 commits behind the trusted base `1134f3d1d`. The commit applies to an older codebase — notably the `LiveDanmaku` widget signature differs between `a4b1fcbe5` and `1134f3d1d`.
3. The implementation approach (two reactive booleans gating rendering) is a valid idea, but the specific diff cannot be copied because:
   - It targets the wrong code baseline (merge-base a4b1fcbe5, not 1134f3d1d)
   - It uses `ever()` listener on `tempHideSC` to clear `fsSC.value`, which is a pattern that may have edge cases (the listener fires reactively but only hides the current SC; new SC arriving while hidden would still be stored in `superChatMsg` list)
   - Some of the gating conditions are duplicated across files (e.g., SC panel gate in both `view.dart` and `chat_panel.dart`)
4. **Ideas that CAN be borrowed** (design intent, not code):
   - Two non-persistent `RxBool` fields on `LiveRoomController`: `tempHideDanmaku` and `tempHideSC`
   - Gate live danmaku overlay rendering: check `!tempHideDanmaku.value` before showing `DanmakuScreen`
   - Gate chat-list danmaku rows: skip `DanmakuMsg` items when `tempHideDanmaku` is true
   - Gate SC panel/PageView: hide SC tab/page when `tempHideSC` is true
   - Gate fullscreen SC overlay: hide `fsSC` when `tempHideSC` is true
   - Add toggle buttons in both `header_control.dart` (persistent header icons) and the `PopupMenuButton` in `view.dart`
   - Global settings remain authoritative: toggles only gate rendering, they do not re-enable when global is off

### Commit `27b23eca7` — "Prepare Task-026 installable prerelease build number"

**Classification: UNRELATED**

Empty commit (no file changes detected via `git diff-tree` and `git show --name-only`). Build metadata only; no code impact.

### Commit `68fc0f07a` — "Prepare Task-026 installable prerelease build number 2"

**Classification: UNRELATED**

Empty commit (no file changes detected). Build metadata only; no code impact.

### Commit `786590ffe` — "Revert 'Implement live room temporary quiet controls'"

**Branch:** `origin/task-026-live-room-quiet-controls-issue8-repair`
**Files changed (4 files, +27/-124):** Exact inverse of 79ff3a3b4

**Classification: UNRELATED**

This is a mechanical revert. It confirms that 79ff3a3b4 was recognized as problematic. It provides no new ideas — it simply restores the pre-79ff3a3b4 state (which is `a4b1fcbe5`, not our trusted `1134f3d1d`). The +27 lines are restorations of the old code, not new contributions.

---

## 5. Judgment: Can Live-Room Temporary Danmaku/SC Implementation Ideas Be Borrowed?

**YES — the design idea can be borrowed. The code must NOT be copied.**

The core idea from `79ff3a3b4` is sound and minimal:
- Two page-local, non-persistent reactive booleans (`tempHideDanmaku`, `tempHideSC`)
- Gate rendering at precisely 4 points (danmaku overlay, chat-list danmaku, SC PageView, fullscreen SC overlay)
- Toggle UI in header buttons and popup menu

**What can be reused as an idea:**
1. The gating architecture: add booleans to `LiveRoomController`, use them in `Obx`/conditional checks at render points
2. The UI placement: header buttons (in `header_control.dart`) and popup menu items (in `view.dart`)
3. The principle that global settings remain authoritative (toggles are "hide" only, never "show over global off")

**What must NOT be reused:**
1. Any specific line of code from the diff — the code targets the wrong baseline
2. The `ever(tempHideSC, ...)` listener pattern — prefer direct checks at render time instead
3. The duplicated SC panel gating logic — use a single source of truth

**Implementation from clean base should:**
- Start from `1134f3d1d` (not `a4b1fcbe5`)
- Add two `RxBool` fields: `tempHideDanmaku = false.obs` and `tempHideSC = false.obs`
- Gate rendering at the 4 identified points using the clean base's existing code structure
- Add header toggle buttons and popup menu items (writing from scratch)
- NOT use `ever()` listeners — check the boolean directly in `Obx`/conditionals
- Ensure toggles never override global disable state

---

## 6. Files the Implementation Slice Should Modify (from Clean Base)

| File | Reason |
|------|--------|
| `lib/pages/live_room/controller.dart` | Add `tempHideDanmaku` and `tempHideSC` reactive fields (~2 lines) |
| `lib/pages/live_room/view.dart` | Gate danmaku overlay in `LiveDanmaku.build`; gate SC PageView + fsSC overlay; add popup menu toggle items (~20-30 lines) |
| `lib/pages/live_room/widgets/chat_panel.dart` | Gate danmaku message rows in `ListView` itemBuilder (~3 lines) |
| `lib/pages/live_room/widgets/header_control.dart` | Add danmaku/SC toggle buttons in header (~25 lines) |

These are the exact same 4 files that `79ff3a3b4` touched, but the diff should be cleanly written against `1134f3d1d`.

---

## 7. Files/Tests That Should Be Avoided

| Path | Reason |
|------|--------|
| `lib/plugin/pl_player/` | Player lifecycle must not change; temporary quiet is a UI-layer concern |
| `lib/pages/video/` | Video quiet controls already exist (Task-020); this task is live-room only |
| `test/` | No existing live-room tests; new tests are out of scope for this minimal gating fix |
| `pubspec.yaml` | No dependency changes needed |
| `android/app/build.gradle.kts` | Only versionCode bump needed for release (Codex responsibility) |
| `records/session/` | Read-only context; do not modify |
| `records/worksite-communications/` | Read-only; do not modify |

---

## 8. Exact Commands Run (Evidence Log)

```
1. git status --short --branch
   → Confirmed branch = task-026-live-room-quiet-controls-issue8-9104, HEAD = 1134f3d1d

2. git log --oneline --decorate --graph 1134f3d1d5305df13b28d0657ac121711e0b68fc..origin/production
   → EMPTY (no commits after trusted base on production)

3. git log --oneline --decorate --all -- lib/pages/live_room lib/plugin/pl_player lib/pages/video test records/session records/worksite-communications pubspec.yaml android/app/build.gradle.kts
   → Identified 79ff3a3b4, 786590ffe as relevant; 27b23eca7, 68fc0f07a as build metadata

4. git log --oneline --decorate -5 1134f3d1d5305df13b28d0657ac121711e0b68fc
   → Confirmed HEAD ancestry chain: 1134f3d1d → 17c3d4d8f → a4b1fcbe5 → 86fa65d70 → 6a20eddad

5. git log --oneline --decorate -5 a4b1fcbe5
   → Confirmed origin/production = a4b1fcbe5

6. git show --stat 79ff3a3b4
   → 4 files, +124/-27

7. git show --stat 786590ffe
   → 4 files, +27/-124 (exact revert)

8. git show 79ff3a3b4 -- <each of 4 files>
   → Full diff inspected; implementation approach documented above

9. git merge-base 1134f3d1d 79ff3a3b4
   → a4b1fcbe5 (origin/production) — confirms 79ff3a3b4 not built on trusted base

10. git diff-tree --no-commit-id --name-only -r 27b23eca7 68fc0f07a
    → Empty (build-number commits have no file changes)

11. git show HEAD:lib/pages/live_room/view.dart (multiple sed ranges)
    → Confirmed clean base state of LiveDanmaku, popup menu, SC panel area

12. git show HEAD:lib/pages/live_room/controller.dart (head -200, sed 100-160, 420-520)
    → Confirmed clean base state: no tempHide* fields, no ever() listeners

13. git show HEAD:lib/pages/live_room/widgets/chat_panel.dart
    → Confirmed clean base: no tempHideDanmaku gating in itemBuilder

14. git show HEAD:lib/pages/live_room/widgets/header_control.dart | tail -60
    → Confirmed clean base: header ends with existing buttons, no danmaku/SC toggles

15. git log --oneline --all -- test/
    → Confirmed: no live_room test files exist

16. git branch -a | grep -i task-026
    → Enumerated all remote branches for completeness
```

---

## 9. Recommendation for Codex

**Verdict: PROCEED FROM CLEAN BASE (1134f3d1d). Do NOT reuse any code from post-5119 commits.**

### What to implement:
1. Add two page-local, non-persistent `RxBool` fields to `LiveRoomController`:
   - `final tempHideDanmaku = false.obs;`
   - `final tempHideSC = false.obs;`
   - No `ever()` listeners, no `GStorage`/`Pref`/Hive persistence.

2. Gate rendering at 4 points (all conditional on the temp flag; global settings remain authoritative):
   - **Danmaku overlay** (`view.dart` `_LiveDanmakuState.build`): wrap `AnimatedOpacity` with `!tempHideDanmaku` check alongside existing `enableShowDanmaku` check
   - **Chat-list danmaku rows** (`chat_panel.dart` itemBuilder for `DanmakuMsg`): skip row when `tempHideDanmaku` is true
   - **SC PageView** (`view.dart` chat panel area): hide SC tab when `tempHideSC` is true
   - **Fullscreen SC overlay** (`view.dart` fsSC Obx): hide when `tempHideSC` is true

3. Add toggle UI in two places:
   - **Header** (`header_control.dart`): Add `ComBtn` for danmaku toggle (only visible when global danmaku is on) and SC toggle (only visible when global SC is enabled)
   - **Popup menu** (`view.dart` PopupMenuButton itemBuilder): Add `PopupMenuDivider` and two toggle menu items

### What NOT to reuse:
- Any code from commit `79ff3a3b4` or its derived branches
- The `ever(tempHideSC, ...)` listener pattern
- Code from dirty worktrees or `/tmp/piliavalon-task026-installable-prerelease`

### Constraints to maintain:
- Temporary state is page-local and non-persistent
- Do not modify player surface, player lifecycle, or websocket
- Global settings remain authoritative (temp toggles only hide, never override global disable)
- Write against clean base `1134f3d1d`, not against `a4b1fcbe5`

### Post-implementation:
- Bump versionCode to ≥5120 (Codex responsibility)
- No new tests required (no existing live-room test suite to extend)
- Codex should review the implementation diff before commit/push
