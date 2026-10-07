# G0 baseline checkpoint

## Repository and worktree

- Product repository: `CometDash77/PiliAvalon-Worksite`
- Product remote: `https://github.com/CometDash77/PiliAvalon-Worksite.git`
- Governance repository: `CometDash77/PiliAvalon-Design-Institute`; its plan and corrected review were read-only inputs and were not edited.
- Verified remote refs before creating the worktree:
  - `origin/main`: `b0eb8dff122ddc86666a98d6a71800ac0af965de`
  - `origin/production`: `3f7d5c83f6c6489d1f87340974dc45bd10743308`
  - `origin/upstream`: `4d66b7b638c9cb9d533ffe95f23a56b822af90e2`
- `origin/main` tree: `27673860294a48905d79b9071d29b46725826b23`
- `origin/production` tree: `27673860294a48905d79b9071d29b46725826b23`
- `production` is an ancestor of `main`; the implementation base is the freshly verified remote `main`, not stale local `production`.
- Dedicated branch: `codex/nara-f2-half-screen-quality`
- Dedicated worktree: `D:/obsidian/工程/VIBECODING项目/.worktrees/piliavalon-worksite-codex-nara-f2`
- Initial branch HEAD: `b0eb8dff122ddc86666a98d6a71800ac0af965de`
- Initial worktree was clean; no unrelated checkout was switched, reset or cleaned.

## Source and license evidence

- Nara pin: `a12f5632f80859265056161b1fd1e6a4803b4b1a`, tree `b6b3afeca826e624fa53700fb02c426fc0e94558`.
- Nara and Worksite root `LICENSE` SHA-256: `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809`.
- Eight-file F2 map, all eleven supplied history seeds, prerequisite `8873f02d72f7ff852f8eec5a33a0380f4e367d41`, local adaptations and exclusions are in `source-history-ledger.csv`, `source-map.md` and `reuse-decision.md`.

## Checks run

| Check | Result |
|---|---|
| `git ls-remote origin refs/heads/main refs/heads/production refs/heads/upstream` | Passed read-only identity check; values recorded above. |
| `git worktree add ... -b codex/nara-f2-half-screen-quality b0eb8dff...` | Passed; isolated Worksite worktree created. |
| `git diff --check` at the initial worktree | Passed. |
| Nara fixed-pin checkout and all eight target-file presence checks | Passed. |
| Nara seed `git merge-base --is-ancestor <seed> a12f563...` for all selected seeds | Passed for all rows. |
| Nara/Worksite root license SHA-256 comparison | Passed; identical GPL-3.0 text digest. |
| Flutter/Android local tool discovery | `adb`, `gradle`, `java` and a discoverable Flutter SDK were unavailable; this is an environment limitation, not a fabricated pass. |

## Recorded result

- G0 evidence commit: `e9e812dcfa4ead5c7bf5a7e4a6853417e936203c`
- The commit contains only the four Worksite-owned files in this directory; no product source, workflow, dependency, governance file or unrelated ignored content was staged.
- The staged evidence passed `git diff --cached --check` before commit.

## Next action

Implement the G1 settings slice in a separate checkpoint: add the storage key and nullable normalized getter, add the mobile half-screen setting/dialog with `-1` follow semantics and no-write cancellation, then add focused behavior coverage before wiring playback transitions.
