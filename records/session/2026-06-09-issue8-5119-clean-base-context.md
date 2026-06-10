# Issue #8 5119 Clean Base Restart Context

Audience classification: agent-facing

Date: 2026-06-09
Repository: `CometDash77/PiliAvalon-Worksite`
Working branch: `task-026-live-room-quiet-controls-issue8-9104`
Base commit: `1134f3d1d5305df13b28d0657ac121711e0b68fc`

## User Facts

- The latest trusted clean APK is `versionCode 5119`.
- `versionCode 5119` maps to release tag `task020-temp-quiet-27148639104`.
- Release tag `task020-temp-quiet-27148639104` targets commit `1134f3d1d5305df13b28d0657ac121711e0b68fc`.
- Commit `1134f3d1d5305df13b28d0657ac121711e0b68fc` and all commits before it are trusted for this restart.
- Commits after `1134f3d1d5305df13b28d0657ac121711e0b68fc` are not trusted by default and must be judged one by one before any idea or code from them is reused.
- The repair APK must be installable over the user's current `versionCode 5119` APK, so the new APK must have `versionCode >= 5120`.

## Trust Boundary

- Trusted baseline: `1134f3d1d5305df13b28d0657ac121711e0b68fc` and earlier history.
- Untrusted until audited: every commit after `1134f3d1d5305df13b28d0657ac121711e0b68fc`.
- Explicitly do not use `task026-live-room-quiet-27180424846` or `task026-live-room-quiet-installable-27181102193` as implementation baselines.

## Forbidden Sources

- Do not reuse dirty live-room changes from the main worktree at `/home/mo/Documents/piliavalon`.
- Do not reuse derived residue from `/tmp/piliavalon-task026-installable-prerelease`.
- Do not copy directly from the old `79ff3a3b` implementation. If a post-5119 commit contains a reusable idea, Reasonix must identify it in the post-5119 audit and Codex must review that artifact before use.

## Implementation Constraints

- Temporary live-room quiet state must be page-local and non-persistent.
- Do not write `GStorage`, `Pref`, Hive, or database records for the new temporary state.
- Do not modify player surface or player lifecycle.
- Do not disconnect the live-room websocket.
- Gate live-room UI feeding/rendering only: live danmaku overlay, live chat-list danmaku rows, Super Chat panel/PageView/list state, and fullscreen Super Chat overlay.
- Global settings remain authoritative. Temporary toggles cannot re-enable danmaku or Super Chat when the global setting disables them.

## Updated User Semantics

- The user clarified that temporary live-room hiding should stop the live-room chat and Super Chat UI from accepting/feeding the hidden message types while the temporary toggle is active.
- This does not authorize disconnecting the live websocket or changing the shared player. The safer implementation boundary is to keep the websocket connected and drop/gate hidden message types before they enter the relevant live-room UI lists/overlays.
- When the temporary toggle is turned back on, subsequent incoming messages should feed the UI again. When the live room is opened next time, the page-local temporary state starts from the default `false` values.

## Screenshot And Vision Constraint

- DeepSeek Reasonix is not reliable for direct screenshot interpretation in this workflow.
- If screenshot feedback is involved, Codex must first translate the screenshot into concrete technical symptoms before delegating to Reasonix.

## Role Boundary

- Reasonix produces candidate evidence, audits, and implementation slices under `records/reasonix/...`.
- Codex reviews persisted Reasonix artifacts before citing them or making gate decisions.
- Codex remains responsible for coordination, code review, commits, pushes, GitHub Actions dispatch, release actions, and final gate judgment.
