---
audience: agent-facing
type: reasonix-candidate-report
evidence_status: candidate evidence only
task_id: task-075
role_id: task-075-real-merge-candidate-worker
target_repo: CometDash77/PiliAvalon-Worksite
target_branch: task-075-upstream-stable-merge
review_owner: Codex
created: "2026-06-21"
merge_commit: 2e4b2299d2a2674dc83e0c2e564df41275f21ec3
worktree_path: /home/mo/Documents/piliavalon/.worktrees/task075-real-merge
baseline_commit: 981869d336bd19d977879594f176ac536a25ccd5
upstream_commit: 2536350ccfc87b9d5d23c564e3d4c8adbd175820
merge_base: cd367a8649ed1f2bed7000d5e4bcb7096a811bc5
---

# Task-075 Real Merge Candidate Report

## Scope

This report records the real merge of `upstream/main` (`2536350cc`) into the
user-accepted product baseline `+5175` (`981869d33`) on branch
`task-075-upstream-stable-merge` in an isolated worktree.

All inputs were read and applied as specified in the Reasonix dispatch prompt:

- `records/session/2026-06-21-task075-upstream-diff-report.md`
- `records/reasonix/task-075/upstream-diff-review.md`
- `records/codex/review/2026-06-21-task075-upstream-diff-reasonix-codex-review.md`
- `records/reasonix/task-075/dry-run-conflict-analysis.md`
- `records/codex/review/2026-06-21-task075-dry-run-conflict-codex-review.md`

## Commands Executed

| Step | Command | Exit Code |
|------|---------|-----------|
| 1. Verify baseline | `git rev-parse --verify 981869d336bd19d977879594f176ac536a25ccd5` | 0 |
| 2. Verify upstream | `git rev-parse --verify upstream/main` | 0 |
| 3. List existing worktrees | `git worktree list` | 0 |
| 4. Create worktree + branch | `git worktree add .worktrees/task075-real-merge -b task-075-upstream-stable-merge 981869d336bd19d977879594f176ac536a25ccd5` | 0 |
| 5. Execute merge | `git merge upstream/main --no-ff --no-commit` | 1 (expected — 2 file conflicts) |
| 6. Resolve header_control.dart imports | edit_file (combined all 3 imports) | 0 |
| 7. Resolve header_control.dart widgets | edit_file (dropped standalone info icon, kept danmaku/SC toggles) | 0 |
| 8. Resolve pubspec.lock file_picker | sed (accepted upstream resolved-ref) | 0 |
| 9. Resolve pubspec.lock flutter_inappwebview_android | edit_file (accepted upstream resolved-ref) | 0 |
| 10. Apply version number | edit_file (`2.0.9+1` → `2.0.9+5176`) | 0 |
| 11. Stage resolved files | `git add header_control.dart pubspec.lock pubspec.yaml` | 0 |
| 12. Commit merge | `git commit -m "..."` | 0 → SHA `2e4b2299d2a2674dc83e0c2e564df41275f21ec3` |

## Merge Outcome

- **Textual conflicts**: 2 files (exactly as predicted by dry-run analysis)
- **Auto-merged files**: 98 files
- **Total changed files**: 100 files, +1665/-1303 lines
- **Merge commit**: `2e4b2299d` — true merge with parents `981869d33` (baseline) and `2536350cc` (upstream/main)

## Conflict Resolutions

### C-1: `lib/pages/live_room/widgets/header_control.dart`

**Import block (lines 4–9)**:
- Kept: `custom_icon.dart` (Phase 2, needed for `CustomIcons.dm_off`/`CustomIcons.dm_on`)
- Kept: `style.dart` and `draggable_scrollable_sheet.dart` (upstream)
- Result: all three imports coexist

**Widget block (lines 304–344)**:
- Accepted upstream's `PopupMenuButton` structure (player info + volume in popup menu items)
- Dropped the duplicate standalone `Icons.info_outline` info icon button (upstream provides this in the PopupMenu)
- Kept both `Obx` toggle buttons for live danmaku (`tempHideDanmaku`) and SC (`tempHideSC`)
- Placement: danmaku/SC toggles follow immediately after the `PopupMenuButton`'s `),` closing, before the `],` that closes the parent `Row` children list

### C-2: `pubspec.lock`

- `file_picker` resolved-ref: accepted upstream `8a987e491225341839bafb3d1c3174c4b2d797ef73`
- `flutter_inappwebview_android` resolved-ref: accepted upstream `0bfa46dfff87f0d9e9d5e13cbd5c4a7c7310f8c9`
- Both are temporary; `pubspec.lock` must be regenerated with `flutter pub get` when a Flutter toolchain is available

## Version Decision

- Upstream version after auto-merge: `2.0.9+1`
- Applied Worksite monotonic build number convention: `2.0.9+5176`
- Base version `2.0.9` accepted from upstream; build number `5176` = `+5175` baseline + 1 (merge commit)

## Static Text Audits

| # | Audit | Result |
|---|-------|--------|
| 1 | No conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) remain | **PASS** — grep confirmed zero markers |
| 2 | No stale `defaultST:` references anywhere in `lib/` | **PASS** — grep confirmed zero hits |
| 3 | Storage keys: upstream buffer/volume keys coexist with Phase 2 shielding keys | **PASS** — `bufferSize`, `bufferSec`, `playerVolume`, `maxVolume` at lines 17–18, 33–34; Phase 2 `repeatExposureFilter*`, `recommendCardWidth`, `ShieldingKey.*` at separate line ranges; no collisions |
| 4 | Live danmaku and SC toggles present | **PASS** — `tempHideDanmaku`, `tempHideSC`, `toggleTempHideDanmaku()`, `toggleTempHideSC()` in controller; `Obx` toggle widgets in header_control.dart |
| 5 | Video quiet controls present | **PASS** — `tempHideReply`, `tempHideDanmaku`, `toggleTempHideReply()`, `toggleTempHideDanmaku()`, `ChannelQuietRule`, `setChannelQuietRule()`, `persistChannelRule()`, `removeChannelRule()` all intact in video controller and header_control.dart |
| 6 | Related-video shielding entries present | **PASS** — `ShieldingAdapters`, `RecommendFilter`, `relatedVideoList()`, `RecommendFilterAnalyzer` all intact across `lib/http/video.dart`, `lib/utils/recommend_filter.dart`, `lib/features/shielding/` |

## Phase 2 Behavior Survival

Based on matching the dry-run conflict analysis auto-merge risk table against
the real merge result:

| Phase 2 Behavior | Status |
|---|---|
| Homepage recommendation shielding | Preserved (auto-merged) |
| Related-video shielding | Preserved (auto-merged) |
| Derived metric filters | Preserved (auto-merged) |
| Repeat-exposure filter | Preserved (auto-merged) |
| Temporary quiet controls (video) | Preserved (auto-merged) |
| Persistent quiet controls (video) | Preserved (auto-merged) |
| Live danmaku controls | Preserved (manually resolved C-1) |
| Live SC controls | Preserved (manually resolved C-1) |
| Settings persistence | Preserved (auto-merged, no key collisions) |

All Phase 2 behaviors survived the merge as static text; no Phase 2 code was
removed or overwritten.

## Local Toolchain Blocker

`flutter`, `dart`, and `fvm` are not available on `PATH` in the current
environment. The following post-resolution steps remain blocked locally:

- `flutter pub get` — regenerate `pubspec.lock` from merged `pubspec.yaml`
- `dart analyze` — static analysis of the merged tree
- `flutter test` — widget/unit tests
- `flutter build apk` — candidate APK production

These must be performed either by installing Flutter `3.44.2` locally or
dispatching GitHub Actions on the merge branch.

## Unresolved Semantic Risks

The following risks from the dry-run conflict analysis remain open because they
require build or runtime verification beyond static text audit:

| Risk | Status |
|------|--------|
| S-1: Flutter `3.44.2` compatibility | Unverified — requires Flutter build |
| S-2: `gt3_flutter_plugin` removal — login impact | Unverified — `geetest_webview_dialog.dart` must be checked for compile errors; login flow must be smoke-tested |
| S-3: media-kit repo URL change (`bggRGjQaUbCoE` → `My-Responsitories`) | **Decision needed** from user/Codex — Worksite may need to revert media-kit URLs |
| S-4: Version numbering scheme | Resolved — `2.0.9+5176` applied |
| S-5: CI patch step hardening | Unverified — `patch.ps1` must be tested on merged tree |
| S-6: `dart:io` / `path` removal | Presumed safe — static audit found no Phase 2 code references |

## Files Changed (Resolved/Beyond Auto-Merge)

- `lib/pages/live_room/widgets/header_control.dart` — manual resolution (C-1)
- `pubspec.lock` — manual resolution (C-2, temporary)
- `pubspec.yaml` — version override (S-4)

All other 97 files accepted as auto-merged with no manual intervention.

## Branch and Worktree State

- **Branch**: `task-075-upstream-stable-merge` at `2e4b2299d`
- **Worktree**: `/home/mo/Documents/piliavalon/.worktrees/task075-real-merge`
- **Status**: working tree clean, all changes committed
- **Ready for**: Codex review, push decision, GitHub Actions dispatch

## Explicit Non-Claims

- **No green claim**: No CI green, build green, or runtime green is claimed.
- **No release approval**: No candidate, prerelease, or stable release is approved.
- **No merge approval**: This report does not approve or close the Task-075 merge.
- **No manual/user acceptance**: User/client acceptance gates remain pending.
- **No governance changes**: No design-institute or CI/workflow files were weakened.
- **No verification completion**: No Flutter/Dart build, test, or runtime smoke has passed.
- **Evidence status**: This artifact is **candidate evidence only**. Codex must review before citation.
- **Stable release**: Remains blocked until a post-merge candidate APK is built, manually validated by the user, and explicitly authorized.
