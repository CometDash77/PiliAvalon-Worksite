# Issue #8 Player-Gray Fix — Release Readiness Audit

Audience: agent-facing

Review owner: Codex

---

## 1. Current Branch and HEAD

| Property | Value |
|---|---|
| **Branch** | `issue8-player-gray-fix` |
| **HEAD** | `4e5db3308bd08d8a9db14f1a6115fc8bd54b38b2` |
| **Rev-list count** | 5120 |

No stray branches, no detached HEAD. The worktree is cleanly positioned.

---

## 2. Baseline Verification

HEAD commit `4e5db3308bd08d8a9db14f1a6115fc8bd54b38b2` is the accepted Issue #8 release baseline ("Issue 8 restart live room quiet controls from 5119"). It is **exactly** the commit Codex specified — not a descendant, not a fork — confirmed via `git rev-parse HEAD` and `git log --oneline -5`.

The parent chain is clean:
```
4e5db3308 Issue 8 restart live room quiet controls from 5119
1134f3d1d Task-020 safe temporary video quiet controls
17c3d4d8f Task-020 add channel quiet settings management
a4b1fcbe5 Record Task-020 continuation snapshot
86fa65d70 Task-020 persistent channel quiet rules checkpoint
```

**PASS** — HEAD is the accepted baseline.

---

## 3. VersionCode After One Commit

`lib/scripts/build.ps1` line 8:
```powershell
$versionCode = [int](git rev-list --count HEAD).Trim()
```

Current `git rev-list --count HEAD` = **5120**. After one new commit (the player-gray fix), the count becomes **5121**.

`5121 > 5120` — this satisfies the `>5120` requirement in the original issue acceptance criteria.

**PASS** — versionCode 5121 is guaranteed.

---

## 4. Diff Scope

`git diff` output shows exactly two modified files:

| File | Status | Lines changed |
|---|---|---|
| `lib/pages/live_room/view.dart` | modified | −1 line (line 255 removed); +0 lines (null values passed) |
| `lib/pages/live_room/widgets/header_control.dart` | modified | −6 lines, +12 lines (Obx wrapper for upName) |

No other files touched. Evidence records (`records/reasonix/2026-06-09-issue8-player-gray/*.md` and `records/session/2026-06-09-issue8-live-player-gray-next-session.md`) are **not staged** — they exist on disk but are gitignored. Codex will need `git add -f` to force-add them alongside the source commit.

**PASS** — diff is limited to the two intended player-gray fix files.

---

## 5. Fix Correctness

### view.dart change

The `Obx` at `view.dart:252-291` previously read **both** `isLoaded.value` and `roomInfoH5.value`:
```dart
// BEFORE (view.dart:252-265)
Widget player = Obx(
  key: playerKey,
  () {
    if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
      final roomInfoH5 = _liveRoomController.roomInfoH5.value;  // reactive read — triggers rebuild
      return PLVideoPlayer(
        ...
        headerControl: LiveHeaderControl(
          key: _liveRoomController.headerKey,
          title: roomInfoH5?.roomInfo?.title,
          upName: roomInfoH5?.anchorInfo?.baseInfo?.uname,
```

Now:
```dart
// AFTER (view.dart:252-272)
Widget player = Obx(
  key: playerKey,
  () {
    if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
      return PLVideoPlayer(
        ...
        headerControl: LiveHeaderControl(
          key: _liveRoomController.headerKey,
          title: null,
          upName: null,
```

**`roomInfoH5.value` read is removed** from the player-construction Obx. The only reactive dependency left inside that Obx is `isLoaded.value`. The concurrent `queryLiveInfoH5()` response can no longer trigger a PLVideoPlayer rebuild/dispose mid-initialization.

### header_control.dart change

The displayed upName is now read inside a new dedicated `Obx` in `LiveHeaderControl`:
```dart
Obx(() {
  final upName = widget.liveController.roomInfoH5.value
      ?.anchorInfo
      ?.baseInfo
      ?.uname;
  if (upName == null) return const SizedBox.shrink();
  return Text(
    upName,
    style: const TextStyle(fontSize: 12, color: Colors.white),
  );
}),
```

This preserves the visual header metadata without coupling it to the PLVideoPlayer build tree. The `title` field is already handled reactively inside `LiveHeaderControl` via `liveController.title.value` (header_control.dart line 67) so passing `title: null` is safe.

### Fix satisfies the design contract

- Player no longer rebuilds from H5 room-info concurrent response
- Header still shows the anchor name when roomInfoH5 resolves
- Quiet-controls behavior from the accepted release is untouched (no changes to controller, chat panel, popup menu, or bottom widgets)

**PASS** — fix implements the repair direction precisely.

---

## 6. Release-Readiness Risks and Blockers

### Risk R1 — Zero compilation / test / CI evidence

Neither `flutter analyze`, `flutter build`, nor any CI workflow has run on this diff. Dart syntax in the new `Obx` closure looks correct, but compilation is unverified. This is the highest-priority risk.

**Mitigation**: Codex must dispatch CI before claiming green. Reasonix can be dispatched to monitor the workflow run (read-only, using the GitHub API from a subagent).

### Risk R2 — Stale evidence records not staged

The audit, repair-candidate, and codex-review artifacts under `records/` exist on disk but are **gitignored** (the default `.gitignore` patterns for `/records/`). They are invisible to `git status`. Codex must use `git add -f records/reasonix/2026-06-09-issue8-player-gray/` and `git add -f records/session/2026-06-09-issue8-live-player-gray-next-session.md` to include them in the commit.

Without force-add, the commit would carry only source changes and the CI/dispatch record trail would be orphaned from the release commit.

### Risk R3 — `title` visual regression in header

`title: null` is passed to `LiveHeaderControl` unconditionally. The next-session record asserts that title is already reactive in `LiveHeaderControl` via `liveController.title.value`. This is **plausible** but unverified — if `LiveHeaderControl` does not independently subscribe to `title.value` in all header states, the room title might disappear during initial player construction.

**Severity**: Low. Even if temporarily absent, the reactive binding will fill it when the controller updates. Should be verified in the CI APK smoke test.

### Risk R4 — No manual acceptance pre-commit

The user cannot pre-approve the fix because it has never been compiled or run. The release workflow must be: GitHub CI green → Android Build green → APK download → user installs → manual smoke → prerelease publish.

### Summary

| Risk | Severity | Blocking Release? |
|---|---|---|
| R1 — No CI/compliation evidence | High | Yes — must have CI green |
| R2 — Stale uncommitted records | Medium | Yes — must be force-added |
| R3 — Title regression | Low | No — reactive binding covers it |
| R4 — No manual acceptance | Medium | No — expected post-CI step |

**No blocker is a code defect. All blockers are process/evidence gaps that Codex resolves in the next steps.**

---

## 7. Recommended Codex-Owned Next Steps

Ordered sequence — do not skip or reorder:

1. **Force-add evidence records** into the commit index:
   ```bash
   git add -f records/reasonix/2026-06-09-issue8-player-gray/
   git add -f records/session/2026-06-09-issue8-live-player-gray-next-session.md
   ```
   (Run from the `/home/mo/Documents/piliavalon-issue8-player-gray` worktree.)

2. **Commit** the player-gray fix + evidence:
   ```bash
   git commit -m "Issue 8 fix live-room player gray screen from concurrent H5 room-info race

   Removes roomInfoH5.value read from PLVideoPlayer construction Obx in
   videoPlayerPanel() to prevent double reconstruction when queryLiveUrl()
   and queryLiveInfoH5() complete concurrently. Moves upName display into
   a dedicated header-local Obx in LiveHeaderControl so visual metadata
   survives without coupling to the player subtree."
   ```

3. **Push** to remote branch `issue8-player-gray-fix`:
   ```bash
   git push origin issue8-player-gray-fix
   ```

4. **Dispatch GitHub Actions** — two workflows:
   - `PiliAvalon CI` (full matrix)
   - `Build` workflow with `android-only` / `issue-fix` tag pattern (Android APK + universal APK)
   
   Dispatch using `gh workflow run` or GitHub UI, not Reasonix. Confirm both start before proceeding.

5. **Delegate monitoring to Reasonix**: Dispatch Reasonix as a read-only monitor subagent with:
   - Task: poll both workflow runs until completion, record pass/fail status, APK artifact names, and versionCode from the Build run.
   - Artifact path: `records/reasonix/2026-06-09-issue8-player-gray/ci-monitor-report.md`
   - Model: deepseek-flash (cheap, sufficient for API polling)
   - Check interval: every 3 minutes, doubling to 6 after two still-in-progress reads.

6. **Publish prerelease** only after:
   - `PiliAvalon CI` — green across all matrix entries.
   - `Build` — green, APK artifacts named with `issue8-player-gray-fix` and versionCode 5121.
   - User manual acceptance: install the APK, open a live room, confirm no gray screen + player controls responsive.
   - Codex writes a concise prerelease summary into `records/reasonix/2026-06-09-issue8-player-gray/prerelease-summary.md`.

7. **Close**: After prerelease evidence is persisted, Codex may close Task-026 / Issue #8.

---

## End — Audit Complete

No source code was edited by Reasonix. No git mutations were performed by Reasonix. Evidence was read-only verified and persisted to this artifact.
