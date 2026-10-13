## Resolution — implementation slices, ordering, and regression checks

**Resolved 2026-10-01** (plan-only: no product source modified). This plan implements the rules decided on [Fix the Zen Mode presentation rules for Home, feeds, and video detail](https://github.com/CometDash77/PiliAvalon-Worksite/issues/39) (issue 39), grounded in the evidence of [Inventory Zen Mode and Feed Navigation Surfaces](https://github.com/CometDash77/PiliAvalon-Worksite/issues/24) (issue 24). Both artefacts are imported here; the slices below add only the *how*, per file.

### 0. Five rules the user added in this session

These extend the 12 rules on issue 39 and are part of the contract:

1. The **danmaku input box / send button** is hidden too — not only the danmaku count and the player overlay.
2. The **danmaku on/off button in the player control bar** is hidden too (under Zen it would be inert). All *other* player controls are retained.
3. The **Dynamics tab strip** is hidden when Zen leaves only 投稿 (one tab is noise, same rule as Home).
4. The Hot page's **top row of three entrances** (排行榜 / 每周必看 / 入站必刷) is hidden.
5. The Home Zen toggle sits to the **left** of the centred search box.

### 1. Implementation slices

Each slice is independently landable (own branch/PR), independently verifiable, and reversible without another slice.

#### S1 — Persistence + the one shared reactive source (foundation)

* **Files**
  * `lib/utils/storage_key.dart` — add `static const String zenMode = 'zenMode';` to `SettingBoxKey`.
  * `lib/utils/storage_pref.dart` — add `static bool get zenMode => _setting.get(SettingBoxKey.zenMode, defaultValue: false);` (pattern of `showRelatedVideo`, :394-395).
  * new `lib/utils/zen_mode.dart` — `abstract final class ZenMode` with `static final RxBool enabled = Pref.zenMode.obs;`, `static bool get isOn => enabled.value;`, and `static Future<void> set(bool value)` that awaits `GStorage.setting.put(SettingBoxKey.zenMode, value)` then assigns `enabled.value = value`. Rationale: `Pref` has no reactive members, so a plain getter repaints nothing (precedent: `lib/plugin/pl_player/controller.dart:192`). One shared observable is what makes "changes take effect immediately" true for every surface; a standalone helper is preferred over an RxBool on `MainController` so video detail and dynamics do not depend on the shell controller. Implementation may relocate it, but there must be exactly one shared source.
* **Acceptance check** — on a clean install `Pref.zenMode` is `false`; `ZenMode.set(true)` persists into the Hive `setting` box and flips `enabled.value` synchronously so an `Obx` repaints without a reload; `ZenMode.set(false)` restores.
* **How it will be verified** — unit test `test/features/zen_mode/zen_mode_store_test.dart` mirroring `test/features/channel_quiet/channel_quiet_store_test.dart` (default value, persist, read-back, reactive flip) + `flutter analyze`.

#### S2 — Settings entry point (switch row + settings-search indexing)

* **Files** — `lib/pages/setting/models/extra_settings.dart` (any existing list built by `lib/pages/settings_search/view.dart` works; `extra_settings.dart` is the natural home) — add a `SwitchModel(title: …, setKey: SettingBoxKey.zenMode, defaultVal: false, onChanged: (v) => ZenMode.set(v))`. `lib/pages/setting/view.dart` needs no change: its `_items` is only the 11 page entries, and settings-search indexing is automatic because the page builds its index from `[...extraSettings, …]`.
* **Acceptance check** — the row appears in its settings page; typing its title/subtitle into `/settingsSearch` finds it; toggling persists, flips `ZenMode.enabled` immediately, and shows no "重启生效" toast.
* **How it will be verified** — `test/pages/setting/models/zen_mode_settings_test.dart` asserting the list contains the row with the right `setKey`/`defaultVal` and that `onChanged` writes through, plus a search-index membership assertion; mirrors `test/pages/setting/models/recommend_settings_test.dart`.
* **Depends on** S1.

#### S3 — Home shell: reduced top bar, Zen shortcut, hidden tab strip

* **Files** — `lib/pages/home/view.dart` (`customAppBar()` :96-145: under Zen render `Row[<Zen toggle>, SizedBox, searchBar]` and drop `msgBadge`/`userAvatar`; keep the search bar visually centred by mirroring the toggle's width on the right; `build()` :44-77: under Zen replace the tab strip with the existing empty spacer); new `lib/pages/home/widgets/zen_mode_toggle.dart` (IconButton, tooltip, `Obx` on `ZenMode.enabled`, `onPressed: () => ZenMode.set(!ZenMode.isOn)`); `lib/pages/main/view.dart` `userAndSearchVertical()` :569-585 — same reduction for tablet/sidebar. The existing scroll-hide top-bar behaviour may stay; the contract is about *content*.
* **Acceptance check** — Zen on: Home shows nothing but one centred search box with the Zen toggle on its left; no tab strip, no message badge, no avatar, blank body below; bottom nav 首页/动态/我的 intact; tapping the search box still opens `/search`; one tap on the toggle turns Zen off and restores the full bar, tab strip and feeds immediately. Tablet/sidebar behaves identically.
* **How it will be verified** — extract the visibility rules into a pure, testable predicate (e.g. `homeZenLayout({required bool zen, required int tabCount})` next to the page or in `lib/utils/zen_mode.dart`) and cover it in `test/features/zen_mode/home_zen_layout_test.dart`; add a widget test in the style of `test/features/shielding/home_feed_comment_gate_test.dart` for the top-bar/tab-strip subtrees.
* **Depends on** S1.

#### S4 — Feed cards: explicit Zen opt-in in the two shared cards + the three Home feeds

* **Design (implements issue 39 §5)** — the cards must **not** read the global flag. `VideoCardV`/`VideoCardH` gain an explicit `final bool zen` (default `false`); only the owning Home-feed surfaces pass it, so 收藏 / 历史 / 稍后再看 / 搜索 / UP 主 / 音乐 / 订阅详情 / 相关视频 keep the normal card.
* **Files**
  * `lib/common/widgets/video_card/video_card_v.dart` — in `content()` :160-231 keep the title and `StatWidget(.play)` from `videoStat()` :236-270; drop `StatWidget(.danmaku)`, the pubdate text, the UP-name `Text`, and the conditional PBadges (pgc / rcmdReason / 动态 / 已关注); keep the cover + duration badge; drop `VideoPopupMenu` :144-155.
  * `lib/common/widgets/video_card/video_card_h.dart` — in `content()` :186-258 keep title/titleList and `StatWidget(.play)`; drop `StatWidget(.danmaku)`, pubdate and `videoItem.owner.name`; drop `VideoPopupMenu` :170-180 and the long-press shield dialog :33-41 (an interaction).
  * `lib/pages/rcmd/view.dart` (:101, :116, :141), `lib/pages/hot/view.dart` (:133, plus hide the three entrances around :68), `lib/pages/rank/zone/view.dart` (:66) — wrap the list body in an `Obx` and pass `zen: ZenMode.isOn`.
  * `lib/common/widgets/stat/stat.dart` needs **no** change — omitting the `.danmaku` `StatWidget` is the whole mechanism.
* **Acceptance check** — Zen on: 推荐 / 热门 / 分区 cards show cover + duration + title + play count only, no popup menu, no shield long-press, no danmaku count, no UP name/pubdate/badges; the Hot page's three entrances are gone; the same pages reached by route (`/hot`) behave the same; all other video lists keep the normal card in both modes; toggling Zen repaints without a reload.
* **How it will be verified** — `test/features/zen_mode/video_card_zen_test.dart` rendering each card with `zen: true/false` and asserting the exact retained/hidden subtrees (precedent: `test/features/shielding/video_card_shield_quick_action_test.dart`) + `flutter analyze`.
* **Depends on** S1.

#### S5 — Dynamics: only 投稿 survives, tab strip hidden, dynamics card reduced

* **Files** — `lib/pages/dynamics/controller.dart`: derive a filtered visible-tab list (`ZenMode.isOn ? [DynamicsTabType.video] : DynamicsTabType.values`), use it for the `TabController` length :51-55 and `initialIndex` (clamping `Pref.defaultDynamicTypeIndex`), remap `_jumpToTab` :59-61, and fix the `DynamicsTabController` tag lookup :38-46 which indexes `DynamicsTabType.values[tabController.index]`; `lib/pages/dynamics/view.dart`: hide the tab strip when one tab is visible and render only the visible tabs' pages; `lib/pages/dynamics/widgets/video_panel.dart` `videoSeasonWidget`: keep cover + duration + title + `'…播放'` (:110), drop `'…弹幕'` (:112) and the badges/overlays, matching S4's card rule.
* **Acceptance check** — Zen on: dynamics shows only 投稿 content and no tab strip; Zen off: all five tabs exactly as before; the followed-UP panel and tab/index mapping still work (no index-out-of-range from a 5-entry enum vs a 1-tab controller).
* **How it will be verified** — pure test of the visible-tab/index mapping helper in `test/features/zen_mode/dynamics_zen_tabs_test.dart` (style of `test/features/channel_quiet/channel_matching_test.dart`) + a widget test for the strip + `flutter analyze`.
* **Depends on** S1; independent of S3/S4.

#### S6 — Video detail gating

* **Files**
  * `lib/pages/video/quiet_state.dart` — extend the pure helpers so Zen is a **separate layer**: e.g. `effectiveShowContent({required bool globalShow, required bool persistentRuleHide, required bool temporaryHide, bool zenMode = false}) => globalShow && !persistentRuleHide && !temporaryHide && !zenMode;` (keep the existing signature usable by adding the defaulted parameter). Zen must not overwrite the user's own danmaku/reply preferences — turning Zen off restores exactly the pre-Zen state.
  * `lib/pages/video/controller.dart` — route `effectiveShowReply` :178-182 through the Zen-aware helper, add the Zen-aware danmaku gate used by the player overlay (:184-188), and keep `toggleTempHideReply/Danmaku` :193-208 consistent (no-op/clear as today).
  * `lib/pages/video/view.dart` — tab list `buildTabBar` :1357-1362 keeps 简介 + 播放列表 and drops 评论 (the existing `quietControlsEffectiveTabIndex` :1372-1379 already handles the length change); hide the related panel :1705-1718; **keep** the season/playlist panel (:124, :1361, :1784); hide the send-danmaku entry (`lib/pages/video/send_danmaku/**`).
  * `lib/pages/video/introduction/ugc/view.dart` — hide `StatWidget(.danmaku)` :943-947, pubdate :948-951, anonymity / 在线人数 :952-965, `actionGrid` :464+, `followButton` :437-462, `_buildTags` :1001+, `_aiBtn` :970-999; **keep** the title :414 and `StatWidget(.play)` :942.
  * `lib/pages/video/widgets/header_control.dart` :427-460 — hide the 隐藏评论/显示评论 and 隐藏弹幕/显示弹幕 entries under Zen.
  * The player control bar's danmaku toggle: located in `lib/plugin/pl_player/**`; it is the one player control hidden under Zen.
* **Acceptance check** — Zen on: player + all controls except the danmaku toggle + title + play count + tab bar [简介, 播放列表]; no comments tab/panel, danmaku count, overlay, send box, pubdate, 在线人数, action row, follow, tags, AI button or related panel. Zen off restores the pre-Zen presentation bit-for-bit, including the user's own danmaku preference.
* **How it will be verified** — extend `test/pages/video/quiet_state_test.dart` with Zen cases (pure truth table, including "Zen off ⇒ user preference wins"), a widget test for the intro panel subtree in `test/features/zen_mode/video_detail_zen_test.dart`, + `flutter analyze`.
* **Depends on** S1; touches no file that S3/S4/S5 own, so it may proceed in parallel.

### 2. Ordering, dependencies, smallest first step

```
S1 (persistence + Rx source)          <- smallest independently verifiable first step
 ├── S2 (settings row)
 ├── S3 (Home shell)          ─┐
 ├── S4 (feed cards)          ─┼─ can be built in parallel (disjoint files)
 ├── S5 (dynamics)            ─┘
 └── S6 (video detail)         <- parallel; only quiet_state.dart/controller.dart overlap with existing
```

* **S1 is the first step**: it ships no visible change, is provable by one unit test, and every other slice consumes its flag. Nothing else can be accepted before it.
* **S2 then S3/S4/S5** — S2 gives the second entry point and makes manual acceptance practical; the three UI slices own disjoint files and can run concurrently.
* **S6 last among the feature slices** is the safest order (it is the largest surface and its pure helpers must not be shaped around the feed work), though nothing structurally forbids parallelism.
* One slice per branch/PR keeps each acceptance check meaningful and makes a bad slice revertible alone; the handoff ticket decides whether any slices group.

### 3. Regression checks

**Must stay green** (existing whitelisted suites; run them as a recorded baseline before S1):

* `test/pages/video/quiet_state_test.dart` — S6 edits `lib/pages/video/quiet_state.dart`.
* `test/pages/live_room/quiet_state_test.dart`.
* `test/features/channel_quiet/**` — its gate functions feed the same `effectiveShowContent` path.
* `test/features/shielding/**` (14 files) including `home_feed_comment_gate_test.dart` and `video_card_shield_quick_action_test.dart` — S3/S4 touch the Home shell and both cards.
* `test/pages/setting/models/{shielding_settings,recommend_settings,legacy_shielding_entries}_test.dart` and `test/pages/setting/recommend_range_shielding_test.dart` — S2 edits a settings model list.
* `test/pages/comment_shield_settings/comment_shield_settings_test.dart`.
* `flutter analyze` clean on every slice.

**New tests, one per slice:** `test/features/zen_mode/zen_mode_store_test.dart` (S1), `test/pages/setting/models/zen_mode_settings_test.dart` (S2), `test/features/zen_mode/home_zen_layout_test.dart` (S3), `test/features/zen_mode/video_card_zen_test.dart` (S4), `test/features/zen_mode/dynamics_zen_tabs_test.dart` (S5), `test/features/zen_mode/video_detail_zen_test.dart` + Zen cases in `test/pages/video/quiet_state_test.dart` (S6).

**Two repo-mechanics cautions found while planning:**

1. `.gitignore` ignores `test/**` by default and whitelists individual paths (:150-169). New test paths are invisible until whitelisted: add `!test/features/zen_mode/` + `test/features/zen_mode/**` (pattern of :159-160) and `!test/pages/setting/models/zen_mode_settings_test.dart` (:167-168 pattern). A slice whose tests are not whitelisted cannot be accepted.
2. Favour pure gating helpers (the `quiet_state.dart` model) over widget-only tests so the truth tables run headless; widget tests follow the shielding gate precedent where the subtree itself is the contract.

### 4. Verification evidence bar per slice (REASONIX.md governance)

* **Development feedback only (not acceptance):** local `flutter analyze` + `flutter test <slice paths>`, recording the exact command and exit code. Reasonix may not claim CI green or acceptance from a local run.
* **Acceptance:** the slice's tests must be inside the `.gitignore` whitelist and executed by GitHub Actions on the production branch; the final Zen Mode implementation is accepted only on CI/prerelease evidence. Substantial implementation work stays plan-gated: the slice plan is reviewed before execution, per `REASONIX.md`.
* **Per slice:** S1 and S2 are accepted by unit tests plus analyzer alone. S3–S6 additionally need their widget tests plus a manual visual acceptance pass on a real build (recorded as dev feedback until CI evidence exists), because the contract is about what is *not* on screen.

### 5. Handoff

The six slices above are the plan-of-record for the Zen Mode implementation; the presentation rules are issue 39 and the surface evidence is issue 24. Assembling these into the implementation-ready specification (artifact form, location, handoff) is [Assemble and hand off the Zen Mode specification](https://github.com/CometDash77/PiliAvalon-Worksite/issues/41), which this ticket unblocks. No product source was modified in this session.