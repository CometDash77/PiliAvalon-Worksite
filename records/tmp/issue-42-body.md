# Zen Mode Specification — implementation-ready

**Carrier:** this GitHub issue is the source of truth (the tracker is the only durable, linkable carrier — `records/` is gitignored, see `.gitignore:180`). A same-machine mirror lives at `records/wayfinder/zen-mode-specification.md`.
**Produced by:** [Assemble and hand off the Zen Mode specification](https://github.com/CometDash77/PiliAvalon-Worksite/issues/41) to close map [Specify Zen Mode Behavior Across Home, Feeds, and Video Detail](https://github.com/CometDash77/PiliAvalon-Worksite/issues/23).
**Rule sources:** [Fix the Zen Mode presentation rules for Home, feeds, and video detail](https://github.com/CometDash77/PiliAvalon-Worksite/issues/39) (normative rules) · [Slice Zen Mode implementation and regression checks](https://github.com/CometDash77/PiliAvalon-Worksite/issues/40) (implementation plan) · [Inventory Zen Mode and Feed Navigation Surfaces](https://github.com/CometDash77/PiliAvalon-Worksite/issues/24) (surface evidence).
**Target:** `CometDash77/PiliAvalon-Worksite`, product branch `production`, verified at `3f7d5c83f6c6489d1f87340974dc45bd10743308` on 2026-09-30.
**Status:** rules complete (no open decisions). Re-verified against the pinned commit on 2026-10-07 — two count corrections applied below (§9 shielding suite: 15 files; §13 card call sites: 8). Implementation is handed off under `REASONIX.md` governance and is in flight: [Implement Zen Mode Across Home, Feeds, and Video Detail](https://github.com/CometDash77/PiliAvalon-Worksite/issues/66), S1 PR #81. This document authorizes no product source change.

---

## 1. What Zen Mode is

One **persisted boolean** setting, default **OFF**, toggled from two entry points (Settings and a Home shortcut), taking effect **immediately** in both directions. When ON, PiliAvalon reduces Home to a lean entry surface and strips video feeds and video detail down to playback, title and play count. When OFF, the normal presentation returns exactly as before. Zen Mode does not exist in `production` today — this is a from-scratch feature (evidence: issue https://github.com/CometDash77/PiliAvalon-Worksite/issues/24 §1).

## 2. Scope

**Covered by Zen:** the Home shell, the three Home video feeds (推荐 / 热门 / 分区), the Dynamics tab content, and video detail (`/videoV`).

**Untouched by Zen:** live rooms and live lists; bangumi/cinema series surfaces and `PgcCardV`; the `/follow` user list; `/subscription`; and every **non-Home video list** — 收藏, 历史, 稍后再看, 搜索, UP 主, 音乐, 订阅详情 (they keep the normal card in both modes).

**Outside this map entirely:** implementing or modifying product source, release/merge/CI/publication. The implementing effort owns the code and the CI evidence.

## 3. The setting

| # | Requirement |
|---|---|
| S1 | New key `SettingBoxKey.zenMode = 'zenMode'` in `lib/utils/storage_key.dart`; boolean, default `false`. |
| S2 | Read through `Pref.zenMode` in `lib/utils/storage_pref.dart` (pattern `showRelatedVideo`, :394-395). |
| S3 | Exactly **one shared reactive source** (`RxBool`) for the whole app; `Pref` has no reactive members, so a plain getter repaints nothing (precedent `lib/plugin/pl_player/controller.dart:192`). Writing the setting persists to the Hive `setting` box **and** flips the Rx synchronously, so every `Obx` repaints without a reload. |
| S4 | Entry point 1 — a Settings `SwitchModel` row in an existing settings model list (e.g. `lib/pages/setting/models/extra_settings.dart`). It is indexed by `/settingsSearch` automatically because the search page builds its index from those lists. No "重启生效" toast. |
| S5 | Entry point 2 — a Zen toggle icon button on Home, **left of the centred search box**; one tap toggles. |
| S6 | The setting is app-global (like every other `Pref` key), not per-account; no migration is needed for a new key. |

## 4. Normative behavior — Home (Zen ON)

| # | Rule |
|---|---|
| R1 | Home shows exactly one centred search box; tapping it still opens `/search`. |
| R2 | The Zen toggle sits to its left; the right side is padded to the same width so the search box stays visually centred. |
| R3 | Message badge and user avatar are hidden. |
| R4 | The `HomeTabType` tab strip is hidden; the body below the search box is **blank** (nothing rendered). |
| R5 | Bottom navigation (首页 / 动态 / 我的) is retained. |
| R6 | Tablet / sidebar layout applies the same rule (`userAndSearchVertical()`: search + toggle, no avatar, no badge). |
| R7 | Accepted consequence: 推荐 / 热门 / 分区 have **no entry point** while Zen is ON; video is reached through Dynamics-投稿, search, and 我的. |
| R8 | Turning Zen OFF restores the full top bar, tab strip, feeds and landing behavior immediately. |

## 5. Normative behavior — feeds and video cards

| # | Rule |
|---|---|
| R9 | Only the **Home feeds** render the reduced card: 推荐 (`lib/pages/rcmd/view.dart`), 热门 (`lib/pages/hot/view.dart`), 分区 (`lib/pages/rank/zone/view.dart`) — also when reached by route (e.g. `/hot`). |
| R10 | Reduced card = **cover + duration badge + title + play count**. Hidden: danmaku count, UP name, publish date, the conditional badges (pgc / rcmdReason / 动态 / 已关注), the ⋯ popup menu, and the shield long-press action. |
| R11 | The two shared cards (`VideoCardV`, `VideoCardH`) take an **explicit `zen` parameter** (default `false`). They must **not** read the global flag — that is what keeps 收藏/历史/搜索/UP 主/音乐/订阅详情 normal. |
| R12 | The Hot page's top row of three entrances (排行榜 / 每周必看 / 入站必刷) is hidden. |
| R13 | Toggling Zen repaints the feeds without a reload and reverts exactly. |

## 6. Normative behavior — Dynamics

| # | Rule |
|---|---|
| R14 | Zen ON renders **only** the 投稿 (`DynamicsTabType.video`) tab; 全部 / 番剧 / 专栏 / UP are hidden. |
| R15 | The tab strip is hidden (a single tab is noise), consistent with R4. |
| R16 | The Dynamics video card is reduced like R10: keep cover + duration + title + "N播放"; hide "N弹幕" and the badges/overlays (`lib/pages/dynamics/widgets/video_panel.dart`). |
| R17 | Tab/index bookkeeping must stay consistent: `TabController` length and `initialIndex` (clamp `Pref.defaultDynamicTypeIndex`) derive from the visible-tab list; `_jumpToTab` indices are remapped; the `DynamicsTabController` tag lookup must index the visible list, not `DynamicsTabType.values`. |
| R18 | Zen OFF restores all five tabs exactly as before. |

## 7. Normative behavior — video detail

| # | Rule |
|---|---|
| R19 | **Retained:** the player and **all** its controls except the danmaku toggle; the title (existing maxLines-2 expansion rules unchanged); the play count; the tab bar with 简介 + 播放列表. |
| R20 | **Hidden:** comments tab and reply panel; danmaku count; the player danmaku overlay; the danmaku send box/entry; the danmaku on/off button in the player control bar; publish date; anonymity icon / 在线人数; the like / coin / fav / share row; the follow button; tags; the AI conclusion button and bottom sheet; the related-video panel; and the 隐藏评论/显示评论 + 隐藏弹幕/显示弹幕 entries in the player's overflow menu. |
| R21 | The season/playlist panel (播放列表) and the 简介 panel are **kept**. |
| R22 | Zen is a **separate gate layer**: `effectiveShowContent({globalShow, persistentRuleHide, temporaryHide, zenMode})` in `lib/pages/video/quiet_state.dart`. Turning Zen OFF restores the user's own danmaku/reply preferences — Zen never overwrites a user preference. |
| R23 | Tab-count changes reuse the existing `quietControlsEffectiveTabIndex` remap (the comments tab disappearing is already handled by that mechanism). |

## 8. Implementation plan (summary)

Full detail — files, acceptance checks, verification per slice — is in [Slice Zen Mode implementation and regression checks](https://github.com/CometDash77/PiliAvalon-Worksite/issues/40) (resolution comment). Gist:

| Slice | Content | Depends on |
|---|---|---|
| **S1** | Persistence + the one shared reactive source (`SettingBoxKey` + `Pref` getter + `RxBool` helper + unit test). **Smallest independently verifiable first step**; ships no visible change. | — |
| **S2** | Settings switch row + settings-search indexing. | S1 |
| **S3** | Home shell: reduced top bar, Zen toggle (left of search), hidden tab strip; tablet/sidebar identical. | S1 |
| **S4** | Explicit `zen` opt-in in `VideoCardV`/`VideoCardH` + the three Home feeds pass it; Hot entrances hidden. | S1 |
| **S5** | Dynamics: 投稿 only, tab strip hidden, dynamics card reduced, index mapping fixed. | S1 |
| **S6** | Video detail gating as a separate layer in `quiet_state.dart` + intro-panel/player/menu gating. | S1 |

**Order:** `S1 → S2 → (S3 ‖ S4 ‖ S5) → S6`. The three middle slices own disjoint files and may run in parallel; S6 is the largest surface and lands last. One slice per PR keeps each acceptance check meaningful and each slice revertible alone.

## 9. Regression and verification requirements

**Must stay green:** `test/pages/video/quiet_state_test.dart`, `test/pages/live_room/quiet_state_test.dart`, `test/features/channel_quiet/**`, `test/features/shielding/**` (15 files), `test/pages/setting/models/{shielding_settings,recommend_settings,legacy_shielding_entries}_test.dart`, `test/pages/setting/recommend_range_shielding_test.dart`, `test/pages/comment_shield_settings/comment_shield_settings_test.dart`, and a clean `flutter analyze`. Record the baseline run before S1 so any new failure is attributable.

**New tests:** `test/features/zen_mode/zen_mode_store_test.dart` (S1), `test/pages/setting/models/zen_mode_settings_test.dart` (S2), `test/features/zen_mode/home_zen_layout_test.dart` (S3), `test/features/zen_mode/video_card_zen_test.dart` (S4), `test/features/zen_mode/dynamics_zen_tabs_test.dart` (S5), `test/features/zen_mode/video_detail_zen_test.dart` plus Zen cases in `test/pages/video/quiet_state_test.dart` (S6).

**Repo mechanics caution:** `.gitignore` ignores `test/**` except an explicit whitelist (:150-169). New test paths must be whitelisted — `!test/features/zen_mode/` + `test/features/zen_mode/**` (pattern of :159-160) and `!test/pages/setting/models/zen_mode_settings_test.dart` (:167-168 pattern) — otherwise the tests cannot be accepted. Prefer pure gating helpers (the `quiet_state.dart` model) so truth tables run headless; use widget tests where the on-screen subtree is the contract.

**Evidence bar (`REASONIX.md`):** local `flutter analyze` / `flutter test` runs are **development feedback only** (record the exact command and exit code); acceptance requires GitHub Actions / prerelease evidence on the production branch. The implementing session may not claim CI green or acceptance from local runs. S1–S2 are accepted by unit tests + analyzer; S3–S6 additionally need their widget tests and a manual visual acceptance pass recorded as dev feedback until CI evidence exists.

## 10. Handoff

* **Receiver:** the implementing effort on `CometDash77/PiliAvalon-Worksite` (Worksite owns product source and CI), under `REASONIX.md`: substantial implementation work is plan-gated — the slice plan is reviewed before execution; Reasonix does not push/merge/tag/publish and does not claim CI green.
* **Shape:** execute S1 first, then S2, then S3/S4/S5, then S6; land each slice as its own PR with its acceptance check; group slices only if the implementing session records why.
* **"Implementation-ready" means:** every presentation rule is decided (no open questions remain), each slice names its files, acceptance check and verification method, the regression baseline and evidence bar are fixed, and the scope boundaries (covered vs untouched vs out-of-map) are explicit. This document plus tickets https://github.com/CometDash77/PiliAvalon-Worksite/issues/39, https://github.com/CometDash77/PiliAvalon-Worksite/issues/40 and https://github.com/CometDash77/PiliAvalon-Worksite/issues/24 satisfies that bar.
* **Map closure:** this spec closes map https://github.com/CometDash77/PiliAvalon-Worksite/issues/23. Further work (implementation, release) is a **new effort**, not a resumption of this map.

## 11. Traceability index

| Spec content | Held in full by |
|---|---|
| Normative rules R1–R8 (Home), R9–R13 (feeds/cards), R14–R18 (Dynamics), R19–R23 (video detail), S1–S6 (setting) | [Fix the Zen Mode presentation rules for Home, feeds, and video detail](https://github.com/CometDash77/PiliAvalon-Worksite/issues/39) — resolution comment https://github.com/CometDash77/PiliAvalon-Worksite/issues/39#issuecomment-5932601236 |
| Slice files, acceptance checks, per-slice verification, ordering, regression list, evidence bar | [Slice Zen Mode implementation and regression checks](https://github.com/CometDash77/PiliAvalon-Worksite/issues/40) — resolution comment https://github.com/CometDash77/PiliAvalon-Worksite/issues/40#issuecomment-5932748082 |
| Surface matrix, shared-card consumer list, "following feed = Dynamics, not /follow" disambiguation, video-detail hide/keep evidence with line numbers | [Inventory Zen Mode and Feed Navigation Surfaces](https://github.com/CometDash77/PiliAvalon-Worksite/issues/24) — resolution comment https://github.com/CometDash77/PiliAvalon-Worksite/issues/24#issuecomment-5932461093; local asset `records/wayfinder/zen-mode-surface-inventory.md` |
| Map-level decisions and scope boundaries | Map https://github.com/CometDash77/PiliAvalon-Worksite/issues/23 "Decisions so far" / "Out of scope" |

## 12. Deferred to the implementer (deliberately not specified)

* The toggle icon glyph and tooltip wording.
* Whether any slice is grouped into fewer PRs (recommended: one PR per slice).
* Transition animation on toggle (an ordinary rebuild is sufficient; no animation is required).
* Exact test-helper names, as long as the gating logic is pure and testable.

## 13. Known risks

* **Card parameter threading (R11):** the two cards have 8 instantiation sites across 7 files (word-boundary count at the pinned commit); defaulting `zen` to `false` keeps them all correct, but a blind global gate would silently reduce 收藏/历史/搜索 — the regression list in §9 exists to catch that.
* **Dynamics index mapping (R17):** the most fragile change; a 5-entry enum driving a 1-tab controller must be remapped, not truncated.
* **Danmaku layering (R22):** folding Zen into the user's own danmaku flag would clobber it; Zen must be an extra AND-term.
* **Test whitelist (§9):** forgetting the `.gitignore` entries makes the slice unverifiable without any test failure.