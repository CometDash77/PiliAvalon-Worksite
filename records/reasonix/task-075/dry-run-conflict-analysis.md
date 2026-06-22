---
audience: agent-facing
type: reasonix-candidate-report
evidence_status: candidate evidence only
task_id: task-075
role_id: task-075-dry-run-conflict-analyst
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: dry-run merge of upstream/main into +5175 baseline
review_owner: Codex
created: "2026-06-21"
dry_run_worktree_path: /home/mo/Documents/piliavalon/.worktrees/task075-dry-run
baseline_commit: 981869d336bd19d977879594f176ac536a25ccd5
upstream_commit: 2536350ccfc87b9d5d23c564e3d4c8adbd175820
merge_base: cd367a8649ed1f2bed7000d5e4bcb7096a811bc5
---

# Task-075 Dry-Run Conflict Analysis

## Scope

This report analyzes the results of a dry-run merge of `upstream/main`
(`2536350cc`) into the user-accepted product baseline `+5175`
(`981869d33`).  The merge was performed with:

```sh
git merge --no-commit --no-ff upstream/main
```

in the dry-run worktree at
`/home/mo/Documents/piliavalon/.worktrees/task075-dry-run`.

Prior reports consulted:
- `records/session/2026-06-21-task075-upstream-diff-report.md` (Phase 1
  upstream diff gate)
- `records/reasonix/task-075/upstream-diff-review.md` (Codex diff review,
  findings #1-#18)

## Merge Outcome Summary

- **Textual conflicts**: 2 files (2 conflict regions in each)
- **Auto-merged files**: 94 files total; 20 of the 22 high-risk overlapping
  files from the diff report auto-merged cleanly
- **Upstream-only files** (no Phase 2 overlap): 78 files, all auto-merged

## Section 1: Textual Conflict Analysis

### Conflict C-1: `lib/pages/live_room/widgets/header_control.dart`

| Field | Detail |
|---|---|
| **Conflict regions** | 2 (lines 4-9 imports; lines 304-344 widget layout) |
| **Upstream changed** | Added `style.dart` and `draggable_scrollable_sheet.dart` imports; refactored player info and volume into a `PopupMenuButton` with `PopupMenuItem` items; added `_showLiveStreamDialog()` method; removed the standalone player info `Icon` button |
| **Phase 2 changed** | Added `custom_icon.dart` import (for `CustomIcons.dm_off`/`CustomIcons.dm_on`); added standalone player info `Icon` button; added two `Obx` toggle buttons for live danmaku (`tempHideDanmaku`) and SC (`tempHideSC`) controls |
| **Conflict nature** | **C-1a (imports)**: Both sides added different imports at the same import-block location. **C-1b (widgets)**: Phase 2 appended a standalone player info button and danmaku/SC toggles after the existing info button; upstream removed the standalone info button (replaced by `PopupMenu`) and added nothing in that position — the empty upstream side means Git could not resolve whether to keep Phase 2's block. |
| **Resolution strategy** | **Combine both** with adaptation to upstream structure. (1) Keep all four imports: `custom_icon.dart`, `style.dart`, `draggable_scrollable_sheet.dart`. (2) Accept upstream's `PopupMenuButton` with player info and volume `PopupMenuItem` entries (lines 268-300, already auto-merged above the conflict). (3) Drop the standalone player info icon button (HEAD lines 304-310) since upstream already provides it in the PopupMenu. (4) Keep both `Obx` toggle buttons for danmaku and SC (HEAD lines 311-342) — place them after `),` of the `PopupMenuButton` wrapper but before `],` of the parent `Row`. (5) Verify `CustomIcons.dm_off`/`CustomIcons.dm_on` resolve with the preserved `custom_icon.dart` import. |
| **Risk** | **Medium**. The resolution is straightforward: keep upstream's PopupMenu structure and Phase 2's danmaku/SC toggles. No Phase 2 behavior is lost. No upstream behavior is lost. The only risk is placement — the toggles should render after the PopupMenu in the header control row. |
| **Required verification** | Live room smoke: (a) PopupMenu shows player info and volume items; (b) danmaku toggle button appears and toggles danmaku visibility; (c) SC toggle button appears and toggles SC visibility; (d) no duplicate player info icons; (e) `CustomIcons` resolve; (f) stream selection dialog works (`_showLiveStreamDialog()`). |

### Conflict C-2: `pubspec.lock`

| Field | Detail |
|---|---|
| **Conflict regions** | 2 (lines 529-533 `file_picker` resolved-ref; lines 627-631 `flutter_inappwebview_android` resolved-ref) |
| **Upstream changed** | Updated `file_picker` resolved-ref to `8a987e491225341839bafb3d1c3174c4b2d797ef73`; updated `flutter_inappwebview_android` resolved-ref to `0bfa46dfff87f0d9e9d5e13cbd5c4a7c7310f8c9` |
| **Phase 2 changed** | Has different resolved-refs for the same two git dependencies: `file_picker` at `a8f06d11b0b8f6d903c5680b57a8d7a385992149`; `flutter_inappwebview_android` at `e0e82ff8492bbc77aecc37e3b4d02c0f3e3de40f` |
| **Conflict nature** | Both are resolved-ref hash conflicts in auto-generated lock entries. Neither side changed the dependency source (URL, ref, path) — only the resolved commit hash differs. |
| **Resolution strategy** | **Accept upstream** for both resolved-refs, then run `flutter pub get` to regenerate `pubspec.lock` from the resolved `pubspec.yaml`. The lock file is a generated artifact; the correct resolution is to regenerate it post-merge. During conflict resolution in the real merge, accept either side's entries temporarily and regenerate lock as the first post-resolution step. |
| **Risk** | **Low**. These are lock-file hash differences only. The actual dependency resolution is controlled by `pubspec.yaml`. Running `flutter pub get` after merge will produce a correct, consistent lock file. |
| **Required verification** | `flutter pub get` succeeds; `pubspec.lock` is consistent with `pubspec.yaml`; no dependency resolution errors. |

## Section 2: Auto-Merge Risk Analysis

The following table covers all 22 high-risk overlapping files from the diff
report.  Files that textually conflicted (C-1, C-2) are included for
completeness with a reference to Section 1.

| # | File | Upstream changed | Phase 2 changed | Auto-merge? | Resolution strategy | Risk | Required verification |
|---|---|---|---|---|---|---|---|
| 1 | `.github/workflows/build.yml` | Removed `continue-on-error: true` from `lib/scripts/patch.ps1 android` step | Added Android build workflow customization | Auto-merged | **Accept upstream** (tightened CI). Patch failure now blocks build — intentional. | **High** | GitHub Actions Android build dispatch; verify patch.ps1 applies cleanly post-merge |
| 2 | `.github/workflows/ios.yml` | Non-Android workflow changes | Non-Android workflow changes | Auto-merged | **Accept upstream** | **Low** | Confirm non-Android builds do not block Android candidate |
| 3 | `.github/workflows/linux_x64.yml` | Non-Android workflow changes | Non-Android workflow changes | Auto-merged | **Accept upstream** | **Low** | Confirm non-Android builds do not block Android candidate |
| 4 | `.github/workflows/mac.yml` | Non-Android workflow changes | Non-Android workflow changes | Auto-merged | **Accept upstream** | **Low** | Confirm non-Android builds do not block Android candidate |
| 5 | `.github/workflows/win_x64.yml` | Non-Android workflow changes | Non-Android workflow changes | Auto-merged | **Accept upstream** | **Low** | Confirm non-Android builds do not block Android candidate |
| 6 | `lib/http/video.dart` | Refactored `videoUrl` switch block: removed `break` statements, added `await` to internal call, reordered `pgc` cases, removed `sid` from subtitle output | Added +110 lines of recommendation/related-video adapter work: `ShieldingAdapters` imports, `RecommendFilter`, `RecommendationTagEnricher`, `CommentShieldingStore` integration in `rcmdVideoList`, `rcmdVideoListApp`, and `relatedVideoList` | Auto-merged | **Combine both** — auto-merge succeeded because changes are in different methods. Phase 2 recommendation methods intact. Upstream `videoUrl` switch block changes intact. | **Medium** | Recommendation feed loads with shielding; related-video shielding active; no build errors in `lib/http/video.dart` |
| 7 | `lib/main.dart` | Added `FlutterSmartNotifyStyle` with `NotifyWarning.new`; changed `toastBuilder`/`loadingBuilder` to tear-off syntax; added smart dialog theme customization | Added +162 lines of storage initialization and settings migration (`GStorage.setting.get`, `storageDisplay`) | Auto-merged | **Combine both** — upstream changes are in different sections from Phase 2 storage init. | **Medium** | App launches without crash; storage initialization succeeds; settings persist across restart |
| 8 | `lib/pages/live_room/controller.dart` | Major refactor: extracted `initLiveUrl()` from `queryLivePlayInfo()`; added `stream`, `streamIndex`, `formatIndex`, `codecIndex`, `liveUrlIndex` fields; used `case final roomId?` pattern matching; wrapped `LiveSendDmPanel` in dark theme | Added +75 lines of live danmaku and SC controls: `tempHideDanmaku`, `tempHideSC`, `showSuperChat`, `danmakuController`, `toggleTempHideDanmaku()`, `toggleTempHideSC()`, SC message filter | Auto-merged | **Keep both** — auto-merge succeeded. Phase 2 danmaku/SC control fields and methods preserved (verified at lines 56, 112-113, 133, 177, 361, 374, 385-397, 412, 459, 467, 502, 578). Upstream `initLiveUrl()` refactor intact (verified at lines 196-260). | **High** | Live room: stream loads; danmaku renders and toggle works; SC shows and toggle works; quality switching via stream/format/codec index works; dark theme wrapping of `LiveSendDmPanel` does not break Phase 2 SC display |
| 9 | `lib/pages/live_room/view.dart` | Wrapped entire body in `Theme(data: ThemeUtils.darkTheme, child: child)`; refactored popup menu items (removed `color:`, added `const`); added `fullScreenSCWidth` from `Pref` | Added +83 lines of live danmaku/SC UI: `danmakuController` initialization, pause/resume/clear lifecycle, SC fullscreen overlay with width from `fullScreenSCWidth` | Auto-merged | **Keep both** — auto-merge succeeded. Phase 2 danmaku lifecycle and SC overlay preserved (verified at lines 72, 125-169, 207, 255, 313-346). Upstream dark theme wrapping and popup changes intact. | **High** | Live room UI: dark theme renders; SC fullscreen overlay works; danmaku pauses/resumes correctly on lifecycle events; `fullScreenSCWidth` from `Pref` resolves (it's an upstream getter) |
| 10 | `lib/pages/live_room/widgets/header_control.dart` | See Section 1, Conflict C-1 | See Section 1, Conflict C-1 | **TEXTUAL CONFLICT** | See C-1 resolution | **Medium** | See C-1 verification |
| 11 | `lib/pages/setting/models/extra_settings.dart` | Changed `inputFormatters` from `FilteringTextInputFormatter.allow(RegExp(...))` to `FilteringText.decimal`; added `filtering_text.dart` import; changed title strings to `const Text(...)` | Phase 2 removed 8 lines (settings model changes) | Auto-merged | **Accept upstream** for `FilteringText.decimal`; keep Phase 2 settings model changes | **Low** | Settings page loads; input formatting works; Phase 2 settings entries visible |
| 12 | `lib/pages/setting/view.dart` | Changed subtitle text: "黑名单、无痕模式" → "黑名单", "设置账号模式" → "切换账号" | Added +24 lines of settings navigation for shielding/quiet controls | Auto-merged | **Keep Phase 2** for navigation additions; accept upstream subtitle text changes (cosmetic) | **Low** | Settings navigation shows shielding/quiet entries; about page subtitle shows correct text |
| 13 | `lib/pages/video/controller.dart` | Removed `dart:io`, `file_ext`, `path_utils`, `path` imports; changed `playerInit()` signature (removed `video`, `audio`, `seekToTime`, `duration`, `volume` parameters); changed `queryVideoUrl()` signature (removed `defaultST` parameter); replaced subtitle file writing with `memory://` URIs; wrapped `SendDanmakuPanel`/`PostPanel` in dark theme; changed `fromReset` logic | Added +181 lines of quiet controls, related-video shielding, and player state management: `tempHideReply`, `tempHideDanmaku`, `currentChannelQuietRule`, `setChannelQuietRule()`, `persistChannelRule()`, `removeChannelRule()`, `currentChannelTarget`, `ChannelQuietTarget`, `ChannelQuietStore` integration | Auto-merged | **Keep both** — auto-merge succeeded because Phase 2 additions are mostly new fields and methods, not modifications to changed signatures. However, `playerInit()` and `queryVideoUrl()` signature changes were cleanly applied. All Phase 2 quiet control code preserved (verified at lines 45, 46, 157, 160, 166-167, 170, 172, 177, 183, 191, 200-201, 208-209, 212-324, 1458). All upstream signature changes applied (verified `queryVideoUrl(fromReset: true)` at line 990, `playerInit()` at line 917 — no stale `defaultST:` or removed parameters). | **Critical** | Video detail: all `queryVideoUrl` calls compile (no `defaultST:`); all `playerInit` calls compile (no removed params); quiet controls toggle; channel quiet rules persist; related-video shielding works; subtitle loading works; no `dart:io` or removed import references |
| 14 | `lib/pages/video/reply/widgets/reply_item_grpc.dart` | Commented out unmatched URL handling (lines 915-925 upstream equivalent), effectively removing link rendering for unmatched URLs in reply content | Added +171 lines of comment shielding logic | Auto-merged | **Accept upstream** for URL handling change; keep Phase 2 shielding logic (auto-merge preserved both) | **High** | Reply rendering with shielding enabled; no broken link rendering in replies; reply shielding filters still active |
| 15 | `lib/pages/video/view.dart` | Removed `TickerProviderStateMixin`; changed `TabController(vsync: this)` to `TabController(vsync: videoDetailController)`; refactored dark theme wrapping for bottom sheets | Added +146 lines for detail page tabs, quiet controls, intro shielding UI | Auto-merged | **Keep both** — auto-merge succeeded. `TabController(vsync: videoDetailController)` correct (verified at lines 1478-1479). Upstream dark theme wrapping intact. | **High** | Detail page tabs render; quiet controls UI visible; intro shielding works; no `TickerProviderStateMixin` references remain |
| 16 | `lib/pages/video/widgets/header_control.dart` | Added player volume control (`showPlayerVolumeDialog`); changed `showPlayerInfo` to take `NativePlayer` directly instead of `PlPlayerController` (null-guard moved to caller); refactored `queryVideoUrl` calls to drop `defaultST:` | Added +78 lines of manual quiet controls: `tempHideReply`, `tempHideDanmaku`, `toggleTempHideReply()`, `toggleTempHideDanmaku()`, `showDanmakuPool()` | Auto-merged | **Keep both** — auto-merge succeeded. Phase 2 quiet controls preserved (verified at lines 437-470, 697, 1542, 1944-1975). Upstream changes to `showPlayerInfo(player: player)` and `queryVideoUrl(fromReset: true)` applied (verified at lines 492, 558). No stale `defaultST:` references anywhere (verified by grep). | **High** | Header control menu: quiet toggles work; player info dialog works; volume control dialog works; `queryVideoUrl` calls correct; no stale `defaultST:` |
| 17 | `lib/plugin/pl_player/view/view.dart` | Changed `PlPlayerController.maxVolume` to `plPlayerController.maxVolume`; removed `pitch` from player info dialog; `showPlayerInfo` signature change | Worksite changes (if any) not in conflict | Auto-merged | **Accept upstream** | **Medium** | `plPlayerController.maxVolume` getter resolves; player info dialog renders without `pitch` |
| 18 | `lib/utils/image_utils.dart` | Removed 3 lines | Worksite changed this file | Auto-merged | **Accept upstream** removal if in a different function from Phase 2 changes | **Low** | Broad smoke; image loading sanity |
| 19 | `lib/utils/storage_key.dart` | Renamed `expandBuffer` → `bufferSize` + added `bufferSec`; added `playerVolume` and `maxVolume` keys to `SettingBoxKey` enum | Added +26 lines of shielding/quiet/recommend settings keys | Auto-merged | **Keep both** — upstream key changes are at lines 17-32; Phase 2 keys are in `static const String` section below (lines 34+). No key name collisions. Upstream keys: `bufferSize`, `bufferSec`, `playerVolume`, `maxVolume`. Phase 2 keys: shielding/quiet/recommend (separate names). | **Critical** | All settings keys compile; no duplicate key names; Phase 2 `SettingBoxKey.*` entries for shielding/quiet/recommend present; upstream `bufferSize`/`bufferSec`/`playerVolume`/`maxVolume` present |
| 20 | `lib/utils/storage_pref.dart` | Replaced `expandBuffer` (bool getter) with `bufferSize` (double), `bufferSec` (double), `initBuffer()` method, `initLiveBuffer()` method; added `playerVolume` and `maxVolume` getters | Added +44 lines of shielding/quiet/recommend settings getters and setters | Auto-merged | **Keep both** — upstream additions are at lines 800-827, 1011-1015. Phase 2 settings are in different line ranges. No API collision: `expandBuffer` is removed (replaced by `bufferSize`/`bufferSec`), and Phase 2 code does not reference `expandBuffer` (verified by grep). | **Critical** | `Pref.bufferSize`, `Pref.bufferSec`, `Pref.initBuffer()`, `Pref.initLiveBuffer()` compile; `Pref.playerVolume`, `Pref.maxVolume` compile; Phase 2 shielding/quiet getters compile; no references to removed `Pref.expandBuffer` anywhere in codebase |
| 21 | `pubspec.lock` | See Section 1, Conflict C-2 | See Section 1, Conflict C-2 | **TEXTUAL CONFLICT** | See C-2 resolution | **Low** | See C-2 verification |
| 22 | `pubspec.yaml` | Bumped version to `2.0.9+1`; bumped Flutter to `3.44.2`; removed `gt3_flutter_plugin` dependency; removed `flutter_volume_controller` dependency override (kept as direct dep at line 107); changed media-kit repo URLs from `bggRGjQaUbCoE` to `My-Responsitories`; changed `media_kit_libs_ios_video` ref from `dev` to `version_1.2.5`; added `flutter_inappwebview_windows` override | Version `2.0.8+5175` with Phase 2 dependency additions | Auto-merged | **Adapt Phase 2 to upstream structure** with decisions: (a) **Version**: keep upstream's `2.0.9` base but restore Phase 2 build number scheme → use `2.0.9+5175` (or `2.0.9+5176` with bump). (b) **Flutter**: accept upstream's `3.44.2`. (c) **gt3_flutter_plugin removal**: accept upstream — `geetest_webview_dialog.dart` was auto-merged and appears de-coupled from the plugin. (d) **flutter_volume_controller override removal**: accept upstream — it remains a direct dependency, which is sufficient. (e) **media-kit repo URLs**: **decision needed** — upstream changed to `My-Responsitories`. If Worksite's media-kit fork has custom patches at `bggRGjQaUbCoE`, this change may break the build. (f) **flutter_inappwebview_windows override**: accept upstream (new). | **Critical** | `flutter pub get` succeeds; version number in app matches `2.0.9+5175` (or chosen scheme); Flutter `3.44.2` build succeeds; media-kit resolves from correct repo; `flutter_volume_controller` resolves; login flow works without `gt3_flutter_plugin` |

## Section 3: Additional Auto-Merge Semantic Conflict Risks

Beyond the 22 tracked high-risk files, the auto-merge produced the following
semantic risks that do not appear as textual conflicts:

### S-1: `.fvmrc` Flutter version bump

| Field | Detail |
|---|---|
| **Change** | Upstream bumped Flutter from `3.44.0` to `3.44.2`. Phase 2 validated on `3.44.0`. |
| **Auto-merged** | Yes — `.fvmrc` accepted upstream's `3.44.2`. |
| **Risk** | **Medium**. The minor version bump is small, but Phase 2 has not been tested on `3.44.2`. Any rendering or plugin regressions are unknown. |
| **Resolution** | **Accept upstream** unless testing reveals regressions. |
| **Verification** | Dart analyze; widget tests; runtime smoke on `3.44.2`. |

### S-2: `gt3_flutter_plugin` removal — login impact

| Field | Detail |
|---|---|
| **Change** | Upstream removed `gt3_flutter_plugin: ^0.1.0` from `pubspec.yaml`. Phase 2's `lib/pages/login/controller.dart` still imports `GeetestWebviewDialog` and uses its `.geetest()` static method. |
| **Auto-merged** | Yes — `pubspec.yaml` auto-merged (no `gt3_flutter_plugin`); `lib/pages/login/controller.dart` and `lib/pages/login/geetest/geetest_webview_dialog.dart` auto-merged (Phase 2 login references preserved). |
| **Risk** | **High**. If `GeetestWebviewDialog.geetest()` internally depended on the removed `gt3_flutter_plugin`, login will break at runtime even if compilation succeeds. Upstream may have refactored the geetest dialog to use a webview-based approach instead. |
| **Resolution** | **Adapt Phase 2 to upstream structure**. Accept upstream's removal. Verify that the auto-merged `geetest_webview_dialog.dart` no longer imports `gt3_flutter_plugin`. If it does, this is a silent break and needs manual fix. |
| **Verification** | Check `geetest_webview_dialog.dart` for `gt3_flutter_plugin` import; login flow smoke test with geetest captcha. |

### S-3: media-kit repo URL change

| Field | Detail |
|---|---|
| **Change** | Upstream changed media-kit repo URLs from `bggRGjQaUbCoE/media-kit.git` to `My-Responsitories/media-kit.git` for `media_kit`, `media_kit_libs_ios_video`, `media_kit_libs_video`. |
| **Auto-merged** | Yes. |
| **Risk** | **High**. If Worksite's Phase 2 media-kit build depends on a fork at `bggRGjQaUbCoE` (e.g., for custom patches), switching to `My-Responsitories` will break the build or produce a different media-kit behavior. |
| **Resolution** | **Decision needed from user/Codex**. If Worksite has custom media-kit patches on its fork, revert the URL change for media-kit overrides. If Worksite uses upstream media-kit as-is, accept the change. |
| **Verification** | `flutter pub get` resolves media-kit; player smoke with danmaku works. |

### S-4: Version number scheme loss

| Field | Detail |
|---|---|
| **Change** | Upstream version `2.0.9+1` auto-merged over Phase 2's `2.0.8+5175`. |
| **Auto-merged** | Yes — `pubspec.yaml` now has `2.0.9+1`. |
| **Risk** | **Medium**. The Phase 2 build-number tracking scheme (`+5175` reflecting commit count) is lost. The `2.0.9` base may be correct (upstream increment), but the build number should follow Phase 2 convention. |
| **Resolution** | **Adapt Phase 2 to upstream structure**. Use `2.0.9+5175` (or bump to `2.0.9+5176` to reflect one new merge commit). |
| **Verification** | `pubspec.yaml` version line matches chosen scheme; version displays correctly in app. |

### S-5: CI patch step hardening

| Field | Detail |
|---|---|
| **Change** | Upstream removed `continue-on-error: true` from `lib/scripts/patch.ps1 android` in `build.yml`. |
| **Auto-merged** | Yes. |
| **Risk** | **Medium**. If any patch file becomes stale after the merge, the CI build will fail hard instead of continuing with a warning. This is the intended behavior (catch issues early), but the build will block until patches are fixed. |
| **Resolution** | **Accept upstream**. Verify all `.patch` files apply cleanly post-merge. |
| **Verification** | `git apply --check` on each `.patch` file in the merged tree; GitHub Actions Android build dispatch. |

### S-6: `dart:io` / `path` removal in video controller

| Field | Detail |
|---|---|
| **Change** | Upstream removed `dart:io`, `file_ext`, `path_utils`, `path` imports from `lib/pages/video/controller.dart` and changed subtitle loading to `memory://` URIs. |
| **Auto-merged** | Yes — the imports were removed and the new subtitle path was merged. |
| **Risk** | **Low**. No Phase 2 code in the controller uses `dart:io`, `path`, or the old subtitle file-writing path. Verified by grep — no `File(`, `path.`, or file I/O references in the merged controller's Phase 2 additions. |
| **Resolution** | **Accept upstream**. No adaptation needed. |
| **Verification** | Subtitle loading works; no `dart:io` or removed import compile errors. |

## Section 4: Phase 2 Behavior Survival Assessment

| Phase 2 Behavior | Status in Dry-Run Merge | Risk | Notes |
|---|---|---|---|
| Homepage recommendation shielding | **PRESERVED** | Medium | `lib/http/video.dart` auto-merged; `ShieldingAdapters`, `RecommendFilter`, `RecommendationTagEnricher` intact |
| Related-video shielding | **PRESERVED** | Medium | `lib/http/video.dart` `relatedVideoList()` with `RecommendFilter` + `ShieldingAdapters` intact |
| Derived metric filters | **PRESERVED** | Low | `RecommendFilter` methods in `lib/utils/recommend_filter.dart` not touched by upstream |
| Repeat-exposure filter | **PRESERVED** | Low | Storage keys and recommendation filter logic intact |
| Temporary quiet controls (video) | **PRESERVED** | Medium | `lib/pages/video/widgets/header_control.dart` and `lib/pages/video/controller.dart` auto-merged; `tempHideReply`, `tempHideDanmaku`, toggles intact; `queryVideoUrl` calls adapted to new signature |
| Persistent quiet controls (video) | **PRESERVED** | High | `lib/pages/video/controller.dart` `ChannelQuietRule`, `ChannelQuietStore`, `setChannelQuietRule()`, `persistChannelRule()` intact; `lib/utils/storage_key.dart` and `storage_pref.dart` Phase 2 keys intact |
| Live danmaku controls | **PRESERVED** | High | `lib/pages/live_room/controller.dart` `tempHideDanmaku`, `danmakuController`, `toggleTempHideDanmaku()` intact |
| Live SC controls | **PRESERVED** | High | `lib/pages/live_room/controller.dart` `tempHideSC`, `showSuperChat`, `toggleTempHideSC()`, SC message filter intact; `lib/pages/live_room/view.dart` SC overlay intact |
| Settings persistence | **PRESERVED** (semantic risk) | Critical | Phase 2 settings keys coexist with upstream keys. No name collisions detected. `storage_key.dart` and `storage_pref.dart` auto-merged with both sides' entries. |

## Section 5: Recommended Merge Order

For the real merge on a disposable branch created from `981869d33`:

1. **Execute merge**: `git merge upstream/main --no-commit --no-ff`
2. **Resolve C-1** (`header_control.dart`): Combine imports, keep upstream PopupMenu, drop standalone info icon, keep danmaku/SC toggles
3. **Resolve C-2** (`pubspec.lock`): Accept either side temporarily
4. **Resolve S-3** (media-kit URLs): Decide fork vs upstream
5. **Resolve S-4** (version number): Set to `2.0.9+5175` (or `+5176`)
6. **Post-resolution steps** (in order):
   a. `flutter pub get` — regenerates `pubspec.lock`
   b. `dart analyze` — catches any compile errors from auto-merge
   c. Review auto-merged files per verification column in Section 2
7. **Commit merge**: `git commit -m "Merge upstream/main into Phase 2 baseline"`
8. **Push to GitHub**: dispatch Android build for verification
9. **Monitor GitHub Actions** via Reasonix monitor — do not claim green until CI passes

## Section 6: Explicit Non-Claims

- **No merge approval**: This analysis does not approve or reject the merge.
- **No green claim**: No CI green, build green, or runtime green is claimed.
- **No release approval**: No candidate, prerelease, or stable release is
  approved.
- **No manual/user acceptance**: User/client acceptance gates remain pending.
- **No governance changes**: This artifact does not modify worksite governance.
- **Evidence status**: This artifact is **candidate evidence only**. Codex must
  review before citation.
- **No conflict resolution performed**: The dry-run worktree remains in
  conflicted state. No files have been modified.
