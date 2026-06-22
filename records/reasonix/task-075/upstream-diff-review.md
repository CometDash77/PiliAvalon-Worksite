---
audience: agent-facing
type: reasonix-candidate-review
evidence_status: candidate evidence only
task_id: task-075
role_id: task-075-upstream-diff-reviewer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-075 pre-merge diff review from +5175 baseline to upstream/main
review_owner: Codex
created: "2026-06-21"
---

# Task-075 Upstream Diff Review

## Scope

This is a candidate review artifact produced by Codex acting as the diff
reviewer for Task-075, per the dispatch prompt at
`records/reasonix/prompts/2026-06-21-task075-upstream-diff-review.prompt.md`.

Baseline: `981869d336bd19d977879594f176ac536a25ccd5` (accepted `2.0.8-981869d33+5175`)
Upstream: `2536350ccfc87b9d5d23c564e3d4c8adbd175820` (upstream/main)
Merge base: `cd367a8649ed1f2bed7000d5e4bcb7096a811bc5`

Upstream delta from baseline: 100 files changed, +1667/-1305 lines.

Worksite Phase 2 delta from merge-base: 253 files changed (per the diff
report; verified as substantial additions to key overlapping files).

## Key Upstream Themes Observed

1. **Dart language modernization**: switch expressions with `.ugc`/`.pgc`
   syntax, record-type `case final roomId?` patterns, tear-off constructor
   references (`.new`), `FilteringText.decimal` static access.
2. **Player buffer rearchitecture**: `expandBuffer` (bool) replaced by
   `bufferSize` (double, default 4.0 MB) and `bufferSec` (double, default
   16.0 s), with new `initBuffer()` and `initLiveBuffer()` methods.
3. **Player volume rearchitecture**: `maxVolume` moved from a static
   `PlPlayerController.maxVolume` to a per-platform `kMaxVolume` in play
   settings and `Pref.maxVolume` via settings box key `maxVolume`.
4. **Dark theme wrapping rationalization**: `Theme(data:
   ThemeUtils.darkTheme, child: child)` pattern introduced in multiple
   places (send danmaku panel, post panel, note list, live room).
5. **Live stream/codec/format refactor**: `initLiveUrl()` method with
   index-based stream/format/codec/url selection, replacing the previous
   monolithic `queryLivePlayInfo` body.
6. **Subtitle loading changed**: `memory://` URIs instead of writing to
   temp files, removing `dart:io` and `path` dependencies from the
   controller.
7. **Flutter version bump**: `.fvmrc` from `3.44.0` to `3.44.2`;
   `pubspec.yaml` environment flutter `3.44.0` to `3.44.2`.
8. **Dependency churn**: `gt3_flutter_plugin` removed,
   `flutter_inappwebview_windows` override added, media-kit repo URLs
   changed from `bggRGjQaUbCoE` to `My-Responsitories`, `media_kit_libs_ios_video`
   ref changed from `dev` to `version_1.2.5`.
9. **CI build patch step tightened**: `continue-on-error: true` removed from
   `lib/scripts/patch.ps1 android` step in `build.yml`.
10. **Code style cleanups**: implicit `const` contexts, `.all(.circular(6))`
    syntax, `.min` enum values, removal of explicit type annotations where
    inferred.

## Findings Table

| # | Severity | File/Area | Risk Description | Recommended Worksite Response |
|---|----------|-----------|------------------|-------------------------------|
| 1 | **Critical** | `lib/utils/storage_key.dart` + `lib/utils/storage_pref.dart` | Upstream renamed `expandBuffer` → `bufferSize`/`bufferSec` and added `playerVolume`/`maxVolume` keys. Worksite Phase 2 added 26+44 lines of shielding/quiet/recommend settings keys in these same files. Both extend `SettingBoxKey` and `Pref` with non-overlapping key names, so auto-merge may succeed, but **semantic conflict**: upstream `initBuffer()` and `initLiveBuffer()` reference `bufferSize`/`bufferSec` — if Worksite code anywhere calls the old `expandBuffer` API, the merge will produce broken references. | Manual resolution: keep both sets of entries. Audit all Worksite code for `Pref.expandBuffer` references (likely 0 since Worksite uses its own keys, but verify). Ensure `playerVolume` and `maxVolume` keys coexist with Worksite shielding keys. Run `dart analyze` after merge. |
| 2 | **Critical** | `lib/pages/video/controller.dart` | Upstream removed `dart:io`, `file_ext`, `path_utils`, `path` imports; removed `video`, `audio`, `seekToTime`, `duration`, `volume` parameters from `playerInit()`; changed `queryVideoUrl` signature (removed `defaultST` param, uses internal `defaultST` field only); replaced subtitle file writing with `memory://` URIs. Worksite Phase 2 added +181 lines of quiet controls, related-video shielding, and player state management in this same file. The parameter removals and signature changes will almost certainly cause **textual merge conflicts** because Worksite additions call `playerInit(...)` and `queryVideoUrl(...)` with the old signatures. | High-effort manual merge required. Map Worksite's `queryVideoUrl(defaultST: ...)` calls to the new signature (remove `defaultST:`). Map Worksite's `playerInit(video: ..., audio: ..., seekToTime: ...)` calls to the new signature (drop the removed parameters). Preserve Worksite quiet control logic in `queryVideoUrl` and `playerInit` callers. After merge, verify all `queryVideoUrl` call sites in Worksite code use the new signature. |
| 3 | **Critical** | `lib/http/video.dart` | Upstream refactored `videoUrl` switch block: removed `break` statements, reordered `pgc` before `pugv`, added `await` to internal `videoUrl` call, removed `sid` from subtitle SRT output. Worksite added +110 lines of recommendation/related-video adapter work in the same file (separate methods/classes). The switch block changes are syntactic but the `await` addition in the fallback path is a **behavior change** — if Worksite's recommendation flow hits the same HTTP method, the control flow may differ. | Manual merge with careful review of the HTTP layer. The Worksite additions are likely in separate methods, so textual conflicts may be minimal. Verify the Worksite recommendation adapter methods still compile against the upstream-changed `videoUrl` return type. Test recommendation feed. |
| 4 | **Critical** | `lib/pages/video/view.dart` | Upstream removed `TickerProviderStateMixin`, changed `TabController(vsync: this)` to `TabController(vsync: videoDetailController)`, refactored dark theme wrapping for bottom sheets. Worksite Phase 2 added +146 lines for detail page tabs, quiet controls, intro shielding UI. The `TickerProviderStateMixin` removal will conflict textually if Worksite's view added any `SingleTickerProviderStateMixin` usage. The `TabController` vsync change must be preserved; Worksite's tab-related additions must reference `videoDetailController` as vsync. | Manual merge: ensure Worksite's tab construction uses `vsync: videoDetailController`. Verify no `TickerProviderStateMixin` references remain. Preserve Worksite's shielding UI and quiet control widgets. |
| 5 | **Critical** | `.fvmrc` + `pubspec.yaml` + `pubspec.lock` | Upstream bumps Flutter to `3.44.2` and version to `2.0.9+1`, removes `gt3_flutter_plugin`, changes media-kit repo URLs, adds `flutter_inappwebview_windows` override. Worksite must choose: accept upstream's `3.44.2` or keep `3.44.0`. Worksite version is `2.0.8+5175` — upstream version `2.0.9+1` is incompatible. | **Decision required from user/Codex.** Options: (a) keep Worksite version `2.0.8+5175` and accept only dependency/Flutter changes; (b) adopt upstream version `2.0.9+1` but keep Worksite build number scheme. Accept Flutter `3.44.2` unless Worksite testing reveals regressions. Media-kit repo URL change from `bggRGjQaUbCoE` to `My-Responsitories` must be reviewed — if the Worksite fork of media-kit is needed, override accordingly. Run `flutter pub get` post-merge to regenerate `pubspec.lock`. |
| 6 | **High** | `lib/plugin/pl_player/controller.dart` | Upstream refactored buffer configuration (removed `bufferSize` from `PlayerConfiguration`, moved to per-source `extras` map), changed volume options (`volume-max: kMaxVolume`, `volume: platform-dependent`), removed `theme_utils` import. Worksite Phase 2 may or may not have touched this file. | Verify Worksite-specific player changes are preserved. If Worksite didn't touch this file, auto-merge likely succeeds cleanly. Verify `kMaxVolume`, `playerVolume`, and `buffer` getters exist and are compatible with Worksite's settings model. |
| 7 | **High** | `lib/pages/video/widgets/header_control.dart` | Upstream added player volume control (`showPlayerVolumeDialog`), changed `showPlayerInfo` to take `NativePlayer` directly instead of `PlPlayerController` (with null-guard moved to caller), refactored `queryVideoUrl` calls to drop `defaultST:`. Worksite added +78 lines of manual quiet controls (likely in different sections). The `queryVideoUrl` signature changes (dropping `defaultST:`) will conflict if Worksite code calls it with the old parameter. | Manual merge: accept upstream's `queryVideoUrl` call sites (drop `defaultST:` from both upstream and Worksite callers). Preserve Worksite's quiet control menu items. Verify `showPlayerInfo` call sites pass the correct `player` argument (not `plPlayerController`). |
| 8 | **High** | `lib/pages/live_room/controller.dart` | Upstream did a major refactor: extracted `initLiveUrl()` from `queryLivePlayInfo()`, added stream/format/codec index fields, used `case final roomId?` pattern, wrapped `LiveSendDmPanel` in dark theme. Worksite added +75 lines of live danmaku and SC controls. Both changes likely touch `queryLivePlayInfo()` and the send-danmaku flow. | Manual merge with careful inspection. Worksite's live danmaku/SC controls must coexist with upstream's `initLiveUrl()` refactor. The dark theme wrapping of `LiveSendDmPanel` may duplicate Worksite's own theme handling. Verify live room works with danmaku + SC controls. |
| 9 | **High** | `lib/pages/video/reply/widgets/reply_item_grpc.dart` | Upstream commented out unmatched URL handling (lines 915-925), effectively removing link rendering for unmatched URLs in reply content. Worksite added +171 lines of comment shielding logic. The shielding logic may depend on the content rendering path that upstream just altered. | **RISK**: The commented-out URL matching code changes reply content rendering. Worksite's comment shielding (which may filter replies by keywords/patterns) could interact with this change. Verify reply rendering with shielding enabled. The upstream comment is likely debugging leftover — consider whether to keep it commented. |
| 10 | **High** | `.github/workflows/build.yml` | Upstream removed `continue-on-error: true` from the `lib/scripts/patch.ps1 android` step. If the patch script fails for any reason (e.g., patch file out of date after merge), the CI build will now **fail hard** instead of continuing. | Accept the upstream change (tightened CI) but verify the `patch.ps1` and patch files still apply cleanly after the merge. If patch application fails, the build will break, which is the intended behavior for catching merge issues early. |
| 11 | **High** | `lib/pages/live_room/view.dart` | Upstream wrapped the entire body in `Theme(data: ThemeUtils.darkTheme, child: child)` and refactored popup menu items (removed explicit `color:` parameters, added `const`). Worksite added +83 lines. The Theme wrapping is a behavior change — it forces dark theme on the live room. Worksite's live controls may expect specific theme behavior. | Manual merge: preserve upstream's dark theme wrapping. Verify Worksite's live danmaku/SC UI renders correctly under forced dark theme. Check for any theme-dependent color references in Worksite additions. |
| 12 | **High** | `lib/pages/live_room/widgets/header_control.dart` | Upstream added 243 lines with stream selection dialog, player volume control, and player info popup. Worksite may not have touched this file, but if it did, conflicts are possible. | If Worksite didn't touch this file, accept upstream changes fully. Verify live header controls function with Worksite's player/control system. |
| 13 | **High** | `lib/main.dart` | Upstream added `FlutterSmartNotifyStyle` with `NotifyWarning.new` and changed `toastBuilder`/`loadingBuilder` to tear-off syntax. Worksite added +162 lines of storage initialization and settings migration. The changes are in different sections but the `initServices()` flow (where Worksite likely added storage init) must be preserved. | Manual merge: preserve Worksite's storage init code. Accept upstream's smart dialog builder changes (they are syntactic improvements). Verify app startup initializes Worksite settings correctly. |
| 14 | **Medium** | `lib/pages/setting/models/extra_settings.dart` | Upstream changed `inputFormatters` from `FilteringTextInputFormatter.allow(RegExp(...))` to `FilteringText.decimal`, added `filtering_text.dart` import, changed title strings to `const Text(...)`. Worksite had -8 lines in this file (Phase 2 maybe removed some settings). | Manual merge: accept upstream's `FilteringText.decimal` (cleaner), ensure Worksite's Phase 2 settings model changes are preserved. |
| 15 | **Medium** | `lib/pages/setting/view.dart` | Upstream changed subtitle text: "黑名单、无痕模式" → "黑名单", "设置账号模式" → "切换账号". Worksite added +24 lines (settings navigation for shielding/quiet). Textual conflict likely on the subtitle string. | Manual merge: choose the correct subtitle for the Worksite context. If Worksite's shielding settings are under a separate menu item, upstream text change is cosmetic and can be accepted. |
| 16 | **Medium** | `lib/plugin/pl_player/view/view.dart` | Upstream changed `PlPlayerController.maxVolume` to `plPlayerController.maxVolume` and removed `pitch` from player info dialog. Worksite not in Worksite diff — likely clean auto-merge. | Accept upstream changes. Verify `plPlayerController.maxVolume` getter exists and returns expected value. |
| 17 | **Medium** | `lib/utils/image_utils.dart` | Upstream removed 3 lines. Worksite changed this file. | Check Worksite diff for what was changed. If the Worksite change was additive and upstream removal is in a different function, auto-merge succeeds cleanly. |
| 18 | **Low** | All other 78 upstream-only files | Files changed by upstream but not by Worksite Phase 2. | Auto-merge should succeed cleanly. Group smoke coverage to verify no regressions in audio, dynamics, login, music, whisper, sponsor block, etc. |

## Phase 2 Behaviors at Risk

| Phase 2 Behavior | Risk Level | Why |
|---|---|---|
| Homepage recommendation shielding | **High** | `lib/http/video.dart` upstream changes touch the HTTP layer that feeds recommendations. If build/compile breaks, shielding is dead. |
| Related-video shielding | **High** | `lib/pages/video/controller.dart` and `lib/http/video.dart` both changed upstream. Related-video adapter uses these surfaces. |
| Derived metric filters | **High** | Same HTTP/controller surfaces as above. Metric calculation may be unaffected but data flow could break. |
| Repeat-exposure filter | **Medium** | Depends on storage keys and recommendation HTTP path. Upstream storage/pref changes are semantic conflicts. |
| Temporary quiet controls | **High** | `lib/pages/video/widgets/header_control.dart` and `lib/pages/video/controller.dart` upstream signature changes will break calls. |
| Persistent quiet controls | **High** | Settings models and storage keys changed upstream. If keys are misaligned, persistence breaks. |
| Live danmaku and SC controls | **High** | `lib/pages/live_room/controller.dart` upstream refactored the entire play-info-to-player-init flow. |
| Settings persistence | **Critical** | `storage_key.dart` and `storage_pref.dart` are semantic conflict hotspots. The `expandBuffer` → `bufferSize`/`bufferSec` rename must not collide with Worksite shielding keys. |

## Required Verification Checklist

### Pre-Merge (dry-run merge)

1. **Dry-run merge** into a disposable branch: `git checkout -b task-075-dry-run
   981869d336bd19d977879594f176ac536a25ccd5 && git merge upstream/main --no-commit --no-ff`.
2. **Conflict inventory**: record every file with merge conflicts and classify as
   textual (same lines changed) vs. semantic (APIs changed).
3. **`dart analyze`** on the merged tree (requires resolving all textual conflicts
   first, even with placeholder resolutions).

### Post-Merge Resolution (on merged branch)

4. **`lib/utils/storage_key.dart`**: verify all Worksite shielding keys coexist
   with upstream `bufferSec`/`playerVolume`/`maxVolume`.
5. **`lib/utils/storage_pref.dart`**: verify `Pref.initBuffer()` and
   `Pref.initLiveBuffer()` compile and Worksite code does not reference
   `Pref.expandBuffer`.
6. **`lib/pages/video/controller.dart`**: verify all `queryVideoUrl(...)` calls
   use the new signature (no `defaultST:` parameter); all `playerInit(...)` calls
   drop removed parameters; Worksite quiet control logic intact.
7. **`lib/pages/video/widgets/header_control.dart`**: verify `showPlayerInfo` calls
   pass `player:` not `plPlayerController:`; verify `queryVideoUrl` calls drop
   `defaultST:`.
8. **`lib/pages/video/view.dart`**: verify `TabController` uses
   `vsync: videoDetailController`; no `TickerProviderStateMixin` remains.
9. **`lib/main.dart`**: verify Worksite storage initialization code preserved;
   upstream smart dialog changes accepted.
10. **`pubspec.yaml` + `pubspec.lock`**: resolve Flutter version, dependency
    overrides, and media-kit repo URLs. Run `flutter pub get` to regenerate lock.
11. **`.fvmrc`**: decide Flutter version and apply consistently.
12. **CI patch files**: verify `lib/scripts/patch.ps1` and all `.patch` files
    still apply after merge (no conflicts with upstream patch additions like
    `geetest_ios.patch` and `navigation_drawer.patch`).

### GitHub Verification (after merge branch push)

13. **GitHub Actions build dispatch** on the merged branch for Android.
14. **APK artifact produced** and installable.
15. **Runtime smoke**:
    - App launches without crash.
    - Homepage recommendation feed loads with shielding active.
    - Video detail page: tabs render, quiet controls toggle, related-video
      shielding works.
    - Player: danmaku visible, quality switching works, volume control works.
    - Live room: stream loads, danmaku renders, SC shows, quality switching works.
    - Settings: all Phase 2 settings entries visible, persist across restart.
16. **Settings migration check**: existing Worksite settings from `+5175` survive
    the upgrade (settings keys not lost or overwritten).

## Release Risks

| Risk | Description |
|---|---|
| **Flutter version mismatch** | Upstream requires 3.44.2; Worksite validated on 3.44.0. Build on 3.44.2 may introduce subtle rendering or plugin issues. |
| **Dependency fork divergence** | Upstream switched media-kit repo from `bggRGjQaUbCoE` to `My-Responsitories`. If Worksite's media-kit fork has custom patches, the URL change may break them. |
| **CI build hardening** | `continue-on-error: true` removal on patch step means any patch failure blocks the build. Ensure all patches apply cleanly post-merge. |
| **Version numbering** | Upstream uses `2.0.9+1`; Worksite uses `2.0.8+5175`. Must reconcile. Suggestion: keep Worksite scheme, bump to `2.0.9+5175` after merge. |
| **`gt3_flutter_plugin` removal** | Upstream removed this dependency. If Worksite's login flow uses it (geetest), login may break. This needs investigation. |
| **Rollback path** | The `+5175` baseline commit `981869d33` must remain as a known-good rollback point. Tag it before merging. |

## Gaps in the Worksite Diff Report

The Worksite diff report (`records/session/2026-06-21-task075-upstream-diff-report.md`)
is generally thorough but has the following gaps:

1. **No dry-run merge attempted**: The report records diffs but does not include a
   dry-run merge result showing which files Git can auto-merge and which produce
   textual conflicts. This is a critical missing input for the real merge.

2. **Worksite Phase 2 diff from merge-base not quoted**: The report says "253"
   files changed in Worksite, but does not list which files or show the diff
   intent. Without knowing exactly which lines Worksite changed relative to
   upstream, every overlapping file must be treated as maximum risk. A
   `git diff --name-only cd367a8..981869d33` listing would improve triage.

3. **`lib/main.dart` not in the high-risk overlapping files table**: The
   Worksite report's "High-Risk Overlapping Files" table includes
   `lib/main.dart` but the upstream diff to it is small (7 lines). The
   report correctly flags it as high-risk.

4. **`lib/pages/video/reply/widgets/reply_item_grpc.dart`**: The report
   correctly flags this, but the upstream change (commenting out URL
   matching) deserves a specific note about reply content rendering
   behavior change.

5. **No `dart analyze` or `flutter pub get` attempted**: The report notes
   local Flutter/Dart is blocked, but GitHub Actions could have been used
   for a pre-merge branch build check. This is noted as a pending gate.

6. **Buffer rearchitecture not called out**: The report mentions settings
   model changes but does not explicitly flag the semantic breaking change
   of `expandBuffer` → `bufferSize`/`bufferSec`/`initBuffer()`. This is
   the single highest-risk semantic conflict.

7. **Player volume rearchitecture not called out**: The report misses that
   upstream moved `maxVolume` from a static to settings-based, and added
   `playerVolume` as a new persistent setting. This could interact with
   Worksite's settings scheme.

8. **`gt3_flutter_plugin` removal not noted**: Upstream removed the geetest
   plugin dependency. This could affect login flow if Worksite depends on it.

## Explicit Non-Claims

- **No merge approval**: This review does not approve or reject the merge.
- **No green claim**: No CI green, build green, or runtime green is claimed.
- **No release approval**: No candidate, prerelease, or stable release is
  approved.
- **No manual/user acceptance**: User/client acceptance gates remain pending.
- **No governance changes**: This review does not modify worksite governance.
- **Evidence status**: This artifact is candidate evidence only. Codex must
  review before citation.
