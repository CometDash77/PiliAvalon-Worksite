# Upstream PiliPlus Delta Assessment — main HEAD vs Worksite Integration Baseline

Ticket: wayfinder research #91 (map #88) · Feeds: #94 "Integrate the Upstream Main HEAD into Production, Conflict-Free"
Status: evidence-only research; no product files changed. Committed on branch `research/upstream-delta`.

## 1. Pinned refs

| Ref | SHA | Meaning |
|---|---|---|
| Upstream target | `d94ae8da10fea4579fc8a9fdf30f8572e4a55162` | PiliPlus `bggRGjQaUbCoE/PiliPlus` `main` HEAD at fetch time (YG-approved target ref) |
| Last consumed upstream snapshot | `a30fcc31043e10cd38c198f47ddd7b23fd6e6163` | PiliPlus stable 2.1.5 source tag; selectively ported by ticket #15 |
| Last integration point (production) | `aef19ec34e51b9df3d286ac70bde7e4ef6936431` | production at v2.1.5+5524, published stable (map #11, #18) |
| Current production tip | `20083a05e3e53e361920521f298c7f4d65f51be7` | origin/production; post-integration custom work (shield matcher/pipeline redos #73–#75, comment gate #78, zen s1–s3 #83/#84) |
| Git merge-base production ↔ upstream | `4d66b7b638c9cb9d533ffe95f23a56b822af90e2` | Still the 2.1.3-era ancestor — the selective port created no shared history |

Consequences of the merge-base fact: a raw `git merge piliplus/main` would diff both sides against `4d66b7b` and light up every path both projects touched since 2.1.3. It is not the integration vehicle. #15's methodology (per-group selective port off the snapshot base) stands; this report computes collisions the same way #15 did — two-way diff against `a30fcc31`.

Upstream releases inside the delta range: **2.1.6** (`4ed5968f3`, 2026-10-05); main `pubspec.yaml` = `2.1.6+1` vs production `2.1.5+5524`. Flutter pin moved 3.47.5 → **3.47.6** (`366d6de18`, `.fvmrc`).

## 2. Delta size

- **50 commits**, `a30fcc31..piliplus/main`, dated 2026-09-30 (`c102a6115`) → 2026-10-07 (`d94ae8da1`).
- **162 files changed, +5192 / −2005** (`git diff --stat a30fcc31 piliplus/main`).
- Module histogram (top two path segments): `lib/pages` 83 · `lib/models_new` 19 · `lib/common` 15 · `lib/utils` 12 · `lib/models` 6 · `android/app` 4 · `lib/http` 4 · `lib/services` 3 · `lib/scripts` 3 · `lib/plugin` 2 · `ios` 3 · `lib/router` 1 · `lib/grpc` 1 · `lib/main.dart` 1 · `pubspec.*` 2 · README 2 · `.fvmrc` 1.
- 15 files added (additive, none collide with Worksite-only dirs `lib/features/*`, `lib/pages/video/channel_quiet`): gesture recognizers ×2, iOS PiP (`PipPlugin.swift`, `ios/pip_helper.dart`), offline/download pages ×5, PGC season widget/model ×3, match_info widgets ×2, `member_home/widgets/live_item.dart`, `scripts/double_tap_gesture.patch`.

### Commit list (50)

```
d94ae8da1|2026-10-07|upgrade deps
c8a8a4100|2026-10-07|delay researching
d08a64d85|2026-10-06|unify match info item
8be35a278|2026-10-06|opt pgc type to label
2d3182e01|2026-10-06|opt show pgc cover
6830ec15c|2026-10-05|fix season selected mask
e958c094d|2026-10-07|tweaks (#3208)
4ed5968f3|2026-10-05|Release 2.1.6
2c93d7ca3|2026-10-05|upgrade deps
ca6e6bf7f|2026-10-05|opt ui
2395e2fad|2026-10-05|align app exit
d012afcc8|2026-10-05|handle esc event on all platforms
7a4f442f4|2026-10-05|feat: offline ugc season
e5ede1a8f|2026-10-05|fix build
35e70c30b|2026-10-05|feat: offline skip
691d0307a|2026-10-04|fix cache pgc
2515ecfc8|2026-10-04|opt image viewer gesture
781bf8880|2026-10-04|fix image pan zoom from trackpad
affb0bdd1|2026-10-04|fix reply ctr onClose
919bc310a|2026-10-04|add filter scope detail
d2544b312|2026-10-04|press enter to save screenshot (#3101)
8f2af3c09|2026-10-04|add picture-in-picture on iOS (#3162)
baec58c4e|2026-10-04|disable search video tab
14ea2914c|2026-10-04|constraint cache input length
b1d3302a3|2026-10-03|improve user block
334d75812|2026-10-03|fix #3160
a6e7cc120|2026-10-03|fix ugc season panel
901dc2b9c|2026-10-03|adjust desktop pip aspectRatio
dd922b0c1|2026-10-03|skip to next/prev from audio session (#2964)
8a8db36ea|2026-10-02|upgrade deps
9a9ce8d18|2026-10-02|only show light mendal in live chat
27bf5e943|2026-10-02|show up label for chat msg
858dba22d|2026-10-02|add default live area entrance
951a91b53|2026-10-02|fix #3136
3125cbe21|2026-10-02|show pgc episodes on side pane
6c6377417|2026-10-02|switch pgc season support
bdca06f2b|2026-10-02|cache desktop pip bounds
bf1208f57|2026-10-02|add top mention item
dbb92ef2c|2026-10-02|fix #3137
11930f128|2026-10-02|feat: reply when repost
f4292ac96|2026-10-02|opt member cheese cover radius
ecb5c8974|2026-10-02|constraint season title lines
96a36fb8a|2026-10-02|fix #2901
80b1db31b|2026-10-02|opt set playback speed
55d89f55a|2026-10-02|disable selection if fav folder is full
ef895e989|2026-10-02|refa mid black list
713972df9|2026-10-02|refa player bar
2607441a2|2026-10-02|show live entrance in member home page
366d6de18|2026-10-02|flutter 3.47.6
c102a6115|2026-09-30|docs: English README, direct link to Releases page (#3131)
```

## 3. Collision method

With base `a30fcc31`:

- Upstream-changed paths: **162**
- Worksite-diverged paths (`a30fcc31..origin/production`): **503**
- **Both-sides-changed paths: 64** — the mechanical collision set (full list in §8)
- In-flight branch scopes intersected with the upstream delta:
  - `codex/issue-51-merged-recommendation-judgement` (local tip `7c9845334` "merge dual recommendation filters into single-pass judge", not yet pushed): **3 colliding files** — `lib/utils/recommend_filter.dart`, `lib/http/video.dart`, `lib/pages/setting/models/recommend_settings.dart`
  - `origin/codex/issue-65-jev-provider-settings`: **4 colliding files** — `lib/common/widgets/video_popup_menu.dart`, `lib/http/video.dart`, `pubspec.yaml`, `pubspec.lock`

For every hot file both sides changed, hunk sizes were measured with `git diff --numstat a30fcc31 {piliplus/main | origin/production} -- <file>` (table in §4).

## 4. Conflict surfaces by Worksite custom face

### 4.1 Shielding / recommendation pipeline (incl. in-flight #51 dual-filter engine) — SEVERITY: HIGH

| File | Upstream Δ | Worksite Δ | Nature of collision |
|---|---|---|---|
| `lib/utils/recommend_filter.dart` | +11/−3 (`919bc310a` "add filter scope detail", `b1d3302a3` "improve user block") | +179/−9 | **Triple collision.** Upstream renames `filter()` → `filterWithExempt()` and splits out `filterDuration()`, documenting which surface (rcmd / hot / rank / related) uses which filter — upstream is now doing per-surface filter scoping, conceptually overlapping Worksite's scope model (recommendation/comments/video-detail/both). Worksite heavily extended this file (derived metrics, content-value, followed-creator exemption, tag enrichment) and **#51 rewrites it again into a single-pass judge**. Port decision needed: adopt upstream naming or keep Worksite API with an adaptation note. |
| `lib/http/video.dart` | +66/−72 | +147/−76 (+#51) | Worksite request-header work (from #15's seven commits) and #51 request-count/judgement plumbing vs upstream rework of rcmd/related request paths. |
| `lib/pages/setting/models/recommend_settings.dart` | changed (small) | +11/−29 (+#51, its own settings tests) | Settings-model merge; both sides reorganized keys. |
| `lib/pages/common/reply_controller.dart` | +3/−0 | +52/−3 | Comment-gate hooks (`affb0bdd1` "fix reply ctr onClose"). |
| `lib/pages/video/reply/controller.dart` | changed | changed | Same comment pipeline. |
| `lib/pages/video/reply/view.dart`, `reply_reply/controller.dart` | changed | changed | Reply rendering vs comment shielding decorations. |
| `lib/pages/video/reply/widgets/reply_item_grpc.dart` | +19/−1 | +153/−22 | Upstream reply item changes vs Worksite comment-shielding decorations; small upstream delta, review line-adjacency only. |
| `lib/grpc/reply.dart` | changed | changed (36 grpc paths diverged on WS side overall) | Regenerated/adjusted grpc reply layer. |
| `lib/pages/mine/view.dart` | +61/−65 | +68/−69 | Both reworked the mine page; Worksite quick-action/quiet entries must be re-anchored. |
| (semantic) user-block | `b1d3302a3`, `ef895e989` "refa mid black list" | shielding user rules | Upstream changed block/mid-blacklist behavior — intersects Worksite user-level shielding rules; behavior-level review required. |

Not touched by upstream this round: `lib/common/widgets/video_card/video_card_h.dart`, `lib/models/home/rcmd/result.dart`, `lib/pages/rcmd/view.dart`, `lib/pages/home/view.dart` — last round's worst hotspots are quiet now; current collisions moved into the filter/request/reply layers.

### 4.2 Zen (lib/pages/home, lib/pages/main, lib/utils/zen_mode.dart) — SEVERITY: MEDIUM

| File | Upstream Δ | Worksite Δ | Nature of collision |
|---|---|---|---|
| `lib/pages/main/view.dart` | +6/−14 | +35/−17 | Upstream refactored the app-exit path: Windows `TerminateProcess` hack removed, replaced by new `DeviceUtils.exitApp()` (`2395e2fad` "align app exit", `d012afcc8` "handle esc event on all platforms"); desktop-PiP window callbacks now call `updatePipBounds()`; new imports `device_utils.dart`, `android/bindings.g.dart`. Worksite's zen-mode exit/esc interception must be re-wired and re-tested against the new exit path. |
| `lib/pages/setting/models/extra_settings.dart` | +2/−3 | +11/−29 | Zen settings row (s1–s3 work) vs upstream settings tweak — small merge. |
| `lib/pages/home/view.dart`, `lib/utils/zen_mode.dart`, `storage_pref.dart`, `storage_key.dart` | not in upstream delta | — | No file-level upstream collision; behavior verification only. |

### 4.3 Jev (in-flight #65, lib/features/jev/*) — SEVERITY: LOW-MEDIUM

- `lib/features/jev/**` (13 files): upstream has no Jev concept — **zero file collision**; purely additive Worksite surface.
- Collisions are at #65's integration edges: `lib/common/widgets/video_popup_menu.dart` (both-changed), `lib/http/video.dart` (both-changed), `pubspec.yaml`/`lock` (version-line conflict guaranteed; take Worksite version, apply upstream dep deltas consciously).
- #65's feed wiring (rcmd/hot/rank/popular/related views) does not collide with the upstream 162 this round.

### 4.4 Live shielding — SEVERITY: MEDIUM

| File | Upstream Δ | Worksite Δ | Nature of collision |
|---|---|---|---|
| `lib/pages/live_room/controller.dart` | +4/−5 | +83/−61 | Live quiet-state routing vs upstream fixes. |
| `lib/pages/live_room/widgets/chat_panel.dart` | +12/−0 (`9a9ce8d18` live-chat medal, `27bf5e943` chat up-label) | +62/−50 | Upstream modifies chat-message rendering where the quiet filter plugs in. |
| `lib/pages/live_room/widgets/header_control.dart` | changed | changed | Live header controls. |
| `lib/models_new/live/live_superchat/item.dart` | changed | changed | Model merge. |
| `lib/pages/member_home/widgets/live_item.dart`, live_feed_index models | new/additive | — | Additive; no Worksite hook. |

### 4.5 Account / playback — SEVERITY: HIGH

| File | Upstream Δ | Worksite Δ | Nature of collision |
|---|---|---|---|
| `lib/plugin/pl_player/controller.dart` | +187/−67 | +85/−109 | Largest upstream player change: desktop PiP bounds caching (`bdca06f2b`), PiP aspect ratio (`901dc2b9c`), audio-session skip next/prev (`dd922b0c1`), playback-speed opt (`80b1db31b`), esc/exit handling. Worksite quiet/playback state integration sits in the same controller. |
| `lib/plugin/pl_player/view/view.dart` | +12/−11 | +55/−68 | Player view vs quiet UI hooks (`713972df9` "refa player bar" also moves `player_bar.dart`). |
| `lib/services/audio_handler.dart` | changed | changed | Audio-session skip feature crosses Worksite playback state. |
| `lib/pages/video/controller.dart` | +38/−38 | +181/−0 | Worksite added channel-identity resolution, quiet updates, exposure callbacks; upstream changes playback-state access — hunk-adjacent, semantics preserved only by inspection. |
| `lib/pages/video/view.dart` | +98/−44 | +401/−354 | Heavy both-side rework. |
| `lib/pages/video/widgets/header_control.dart` | **+185/−176** | **+1080/−1103** | **The heaviest file in the delta.** Worksite's channel-quiet + playback UI state vs upstream speed/PiP/quality rework. Port must be done semantically, not hunks. |
| `lib/pages/danmaku/view.dart`, `lib/pages/sponsor_block/block_mixin.dart`, `lib/services/shutdown_timer_service.dart` | changed | changed | Secondary playback-adjacent merges. |
| account state | no upstream change to account service/login files; tombstone handling untouched | — | Account risk is indirect: mine-page rework + player/audio-session changes only. |

### 4.6 Mechanical / toolchain collisions (defer-by-default)

- `pubspec.yaml` / `pubspec.lock`: version line (`2.1.6+1` vs `2.1.5+5524`) + 3 "upgrade deps" commits (`8a8db36ea`, `2c93d7ca3`, `d94ae8da1`) + lock ±132. Take Worksite version; review dep deltas per #14 deferral policy (media-kit history: upgrade-then-partial-revert last round — do not blind-bump).
- `.fvmrc` → Flutter 3.47.6: defer until toolchain ticket.
- `android/app/build.gradle.kts`, `AndroidHelper.java`, `MediaHelper.java`, `android_helper.dart`, `ios/Runner*` (incl. new PiP plugin): platform files — defer per standing policy; note iOS PiP is new functionality that would be lost by deferral.
- `lib/main.dart` (+8/−7 vs Worksite +158/−30 app-init): Worksite owns initialization; port upstream bits manually if needed.
- README ×2 (branding), `lib/scripts/material/scaffold.patch` + new `double_tap_gesture.patch` (upstream patch machinery — check applicability), `lib/router/app_pages.dart` (both changed; new offline/download routes need registration), `image_utils.dart`, `gallery_viewer.dart`, `image_save.dart` (gesture/image-viewer rework × gesture recognizers).

## 5. Deferred-carryover reminder (from #12/#14/#15, still open)

Already deferred in the 2.1.5 selective port and still not in Worksite: Flutter/toolchain upgrades, media-kit upgrade, Android legacy WebView + Linux embedded WebView work, esports models/widgets, broad dependency refresh. The current delta adds on top: Flutter 3.47.6, three dep-upgrade commits, iOS PiP, desktop PiP caching. Default remains defer, with the same re-check trigger as #14 (focused checks + runtime verification).

## 6. Recommended integration order for #94

0. **Pre-flight.** Freeze base SHA `20083a05e` as rollback point; clean index; re-verify `piliplus/main` HEAD (it moves; this study pinned `d94ae8da1`). Compute the delta fresh at integration time; expect drift beyond `d94ae8da1`.
1. **Land in-flight custom work first.** Merge #51 (dual-filter single-pass judge) into production, then #65 (Jev). Both collide with the upstream delta (`recommend_filter.dart`, `http/video.dart`, `recommend_settings.dart`, `video_popup_menu.dart`, pubspec); finalizing custom semantics first means porting upstream onto stable ground once, not twice. (#51's local tip `7c9845334` is currently unpushed — push it first.)
2. **Port additive groups (collision-free):** offline/download (`35e70c30b`, `7a4f442f4`, download pages/models), PGC/season set (`6c6377417`, `3125cbe21`, `8be35a278`, `2d3182e01`, `a6e7cc120`, `6830ec15c`, `ecb5c8974`, `691d0307a`, `f4292ac96`), search/match (`d08a64d85`, `baec58c4e`, `bf1208f57`, `14ea2914c`, `55d89f55a`), image/gesture viewer (`2515ecfc8`, `781bf8880`, `d2544b312` + new gesture recognizers), member/cheese/comic/pgc cards, misc fixes (`334d75812`, `951a91b53`, `96a36fb8a`, `dbb92ef2c`, `ca6e6bf7f`, `e958c094d`).
3. **Port reply/comment group (shielding gate re-test):** `affb0bdd1` (reply ctr onClose), `919bc310a` (filter scope detail — adapt to Worksite surface scoping), `11930f128` (reply when repost), `ef895e989` + `b1d3302a3` (mid blacklist / user block). Run comment-gate + reply-decoration suites after each.
4. **Port recommendation filter/request group (after #51 is merged):** `recommend_filter.dart` (adopt or map upstream's `filterWithExempt`/`filterDuration` names), `http/video.dart`, `recommend_settings.dart`. Equivalence tests from #51 are the safety net.
5. **Port playback/player group (heaviest, file-by-file):** `pl_player/controller.dart`, `pl_player/view/view.dart`, `player_bar.dart`, `audio_handler.dart`, playback speed, desktop PiP; then `video/controller.dart`, `video/view.dart`, `video/widgets/header_control.dart` (semantics-first, preserving channel-quiet/exposure hooks), `danmaku/view.dart`, `sponsor_block/block_mixin.dart`, `shutdown_timer_service.dart`.
6. **Port live group:** chat panel medal/up-label changes, live-room controller/header, superchat model, member-home live entrance; verify live quiet-state behavior (per #13 this is menu/state-level evidence only).
7. **Port zen-adjacent group:** `main/view.dart` exit refactor — re-wire zen exit/esc interception onto `DeviceUtils.exitApp()`; merge `extra_settings.dart`; smoke the zen toggle.
8. **Defer (standing policy):** Flutter 3.47.6, dependency upgrades, android/ios platform files, webview work, script patches. Record each deferral as a focused follow-up candidate.
9. **Verification ladder** (per #13's gap list): focused shielding/exposure/quiet/jev suites → full `flutter test` + `analyze` → launcher resolver + dependency-lock → signed Android build → emulator install/launch smoke → **add the two missing acceptance checks: real account-switch persistence and a real playback session with comments/danmaku shielding**.
10. **Rollback:** pre-integration production SHA immutable; stable `v2.1.5+5524` remains published and byte-verified; rollback = restore pre-merge SHA.

## 7. Scale summary (gate answer)

50 commits / 162 files / +5192−2005 / upstream 2.1.6+1 / Flutter 3.47.6. 64 mechanical collision paths; 6 semantic hot files (`recommend_filter.dart`, `http/video.dart`, `video/widgets/header_control.dart`, `video/controller.dart` + `video/view.dart`, `pl_player/controller.dart`, `main/view.dart`). No upstream change replaces or removes any Worksite-only module (shielding, comment shielding, channel quiet, exposure tracker, Jev, zen). **No disruptive upstream rewrite found**; the largest semantic shifts are (a) upstream adopting per-surface filter scoping + the `filterWithExempt` rename (collides with #51's premise — resolve by design review, not force-merge), (b) the app-exit/PiP refactor touching zen interception, (c) the player-controller rework. Direct `git merge` remains structurally impossible (merge-base stuck at `4d66b7b`); selective port per #15 methodology is the confirmed vehicle.

## 8. Appendix A — the 64 both-sides-changed paths

```
.fvmrc
android/app/build.gradle.kts
android/app/src/main/java/com/example/piliplus/AndroidHelper.java
android/app/src/main/java/com/example/piliplus/MediaHelper.java
lib/common/widgets/image/image_save.dart
lib/common/widgets/image_viewer/gallery_viewer.dart
lib/common/widgets/player_bar.dart
lib/grpc/reply.dart
lib/http/api.dart
lib/http/video.dart
lib/main.dart
lib/models/common/search/search_type.dart
lib/models/dynamics/result.dart
lib/models/search/result.dart
lib/models/search/search_esports.dart
lib/models_new/download/bili_download_entry_info.dart
lib/models_new/live/live_superchat/item.dart
lib/pages/audio/controller.dart
lib/pages/common/dyn/common_dyn_controller.dart
lib/pages/common/dyn/common_dyn_page.dart
lib/pages/common/reply_controller.dart
lib/pages/danmaku/view.dart
lib/pages/download/detail/widgets/item.dart
lib/pages/dynamics_detail/controller.dart
lib/pages/dynamics_detail/view.dart
lib/pages/dynamics_repost/view.dart
lib/pages/live_room/controller.dart
lib/pages/live_room/widgets/chat_panel.dart
lib/pages/live_room/widgets/header_control.dart
lib/pages/main/view.dart
lib/pages/match_info/view.dart
lib/pages/member_home/view.dart
lib/pages/mine/view.dart
lib/pages/search_panel/all/widgets/esports.dart
lib/pages/search_panel/controller.dart
lib/pages/search_panel/pgc/widgets/item.dart
lib/pages/search_result/view.dart
lib/pages/setting/models/extra_settings.dart
lib/pages/setting/models/recommend_settings.dart
lib/pages/sponsor_block/block_mixin.dart
lib/pages/video/controller.dart
lib/pages/video/introduction/local/controller.dart
lib/pages/video/introduction/pgc/controller.dart
lib/pages/video/introduction/ugc/controller.dart
lib/pages/video/introduction/ugc/view.dart
lib/pages/video/reply/controller.dart
lib/pages/video/reply/view.dart
lib/pages/video/reply/widgets/reply_item_grpc.dart
lib/pages/video/reply_reply/controller.dart
lib/pages/video/view.dart
lib/pages/video/widgets/header_control.dart
lib/pages/webview/view.dart
lib/plugin/pl_player/controller.dart
lib/plugin/pl_player/view/view.dart
lib/router/app_pages.dart
lib/scripts/material/scaffold.patch
lib/services/audio_handler.dart
lib/services/shutdown_timer_service.dart
lib/utils/android/android_helper.dart
lib/utils/recommend_filter.dart
pubspec.lock
pubspec.yaml
README.en.md
README.md
```

## 9. Appendix B — evidence commands

```
git fetch piliplus main                       # proxy: HTTPS_PROXY=http://127.0.0.1:10809
git rev-parse piliplus/main                   # d94ae8da10fea4579fc8a9fdf30f8572e4a55162
git rev-list --count a30fcc31..piliplus/main  # 50
git diff --stat a30fcc31 piliplus/main        # 162 files, +5192/-2005
git diff --name-only a30fcc31 piliplus/main   # upstream path set
git diff --name-only a30fcc31 origin/production  # worksite path set (503)
# intersection = 64 paths; branch scopes via merge-base diffs of
#   codex/issue-51-merged-recommendation-judgement (base 44c15b28a, tip incl. 7c9845334)
#   origin/codex/issue-65-jev-provider-settings     (base 44c15b28a)
git merge-base origin/production piliplus/main   # 4d66b7b6... (unchanged since #12)
```

Pre-existing hazard noted during research (not caused by this delta): commit `af1c1dcb8` ("11") on production accidentally committed Windows cache files under `%SystemDrive%/ProgramData/Microsoft/Windows/Caches/` and `.local/state/gh/device-id`; candidate for a cleanup ticket.
