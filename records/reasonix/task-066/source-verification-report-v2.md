---
audience: agent-facing
record_type: source-verification-candidate
task: task-066
status: candidate-evidence
created: 2026-06-17
worker: DeepSeek Reasonix (deepseek-v4-pro)
model_strategy: deepseek-v4-pro
difficulty_classification: hard, governance-sensitive, prerelease-sensitive
review_owner: Codex
source_repo: CometDash77/PiliAvalon-Worksite
expected_artifact: records/reasonix/task-066/source-verification-report-v2.md
---

# Task-066 Fresh Worksite Source Verification Report v2

## Worker Identity

DeepSeek Reasonix acting as a fresh worksite source verifier for task-066
(fresh Stage 0). Codex remains Design Institute lead, reviewer, orchestrator,
and final gate owner.

**This output is candidate evidence only until Codex reviews this persisted
artifact and writes `records/codex/task-066/source-verification-codex-review-v2.md`.**

## Reasonix Health Status

`reasonix doctor` ran successfully before any source verification commands.
Result: **all 9 indicators ok** (0 warn, 0 fail).

- npm: v1.3.0-rc.1
- system: linux/amd64
- providers: deepseek-flash (default), deepseek-pro — both key:present
- codegraph: enabled, v0.9.7, resolved
- lsp: enabled
- sandbox: bash=enforce, network=true, write_roots=~/Documents/piliavalon
- permissions: mode=ask, allow:0 ask:0 deny:0

No MCP servers are required for this read-only source verification; configured
third-party MCP failures are irrelevant.

## Commands Run

| # | Command | Exit | Notes |
|---|---|---|---|
| 1 | `reasonix doctor` | 0 | 9 ok |
| 2 | `git status --short --branch` | 0 | 3 dirty files |
| 3 | `git status --porcelain=v1` | 0 | same 3 M entries |
| 4 | `git rev-parse HEAD` | 0 | `f806d36d1b97e6b601372947e9a29fdaca7d68d7` |
| 5 | `git rev-list --count HEAD` | 0 | `5151` |
| 6 | `git log --oneline --decorate -n 20` | 0 | full history |
| 7 | `git diff -- lib/features/shielding/shielding_matcher.dart` | 0 | 2 hunks |
| 8 | `git diff -- lib/features/shielding/shielding_models.dart` | 0 | 4 hunks |
| 9 | `git diff -- lib/utils/storage_key.dart` | 0 | 1 hunk |
| 10 | `rg -n "class ShieldCandidate\|..." lib/` | 0 | core types confirmed |
| 11 | `rg -n "fromRecommendationJson\|..." lib/` | 0 | adapter locations |
| 12 | `rg -n "applyFilterToRelatedVideos" lib/` | 0 | legacy switch locations |
| 13 | `rg -n "introduction\|Introduction" lib/pages/video/` | 0 | intro surfaces |
| 14 | `rg -n "related.*video\|RelatedVideo\|relatedVideo" lib/pages/video/` | 0 | related-video surfaces |
| 15 | `rg -n "relatedVideoEnabled\|related_video_enabled" lib/` | 0 | new flag locations |
| 16 | `rg -n "相关视频屏蔽\|relatedVideo" lib/pages/setting/` | 1 (no match) | no settings UI entry |
| 17 | `rg -n "descriptionKeyword\|publishTime\|isUpowerExclusive" lib/pages/` | 0 | no settings UI labels |
| 18 | `rg -n "staff\|Staff\|pubdate" lib/pages/video/introduction/ugc/controller.dart` | 0 | staff in intro controller |
| 19 | `rg -n "setRelatedVideo\|relatedVideoEnabled" lib/features/shielding/shielding_store.dart` | 1 (no match) | store missing setter |
| 20 | `read_file` (multiple) | — | full source inspection |

## Current Branch / Commit / Derived VersionCode

| Fact | Value |
|---|---|
| Local branch | `task-066-detail-intro-shielding` |
| HEAD SHA | `f806d36d1b97e6b601372947e9a29fdaca7d68d7` |
| Derived versionCode | **5151** |
| Target versionCode | **5162** |
| Required additional commits | **11** |
| Base confirmation | matches `records/codex/task-066/branch-base-decision.md` |

## Dirty Worktree Classification

All three dirty product-source files are classified as **in-scope candidate
task-066 work**. No out-of-scope drift or unknown/user-owned changes detected.

| File | Status | Classification | Change Summary |
|---|---|---|---|
| `lib/features/shielding/shielding_models.dart` | M | **in-scope candidate** | Added `descriptionKeyword`, `publishTime`, `isUpowerExclusive` to `ShieldRuleType`; added `relatedVideoEnabled` field to `ShieldRuleSet` (constructor, `fromJson`, `toJson`, `copyWith`, `isScopeEnabled`); added `description`, `pubdate`, `staffNames`, `isUpowerExclusive` to `ShieldCandidate`; changed `isScopeEnabled` so `ShieldScope.videoDetail` returns `relatedVideoEnabled` instead of hardcoded `true` |
| `lib/features/shielding/shielding_matcher.dart` | M | **in-scope candidate** | Added `descriptionKeyword` case in `_valuesForRule` yielding `candidate.description`; added `isUpowerExclusive` case yielding `'true'`/`'false'`/`''`; added `publishTime` case in `_matchNumbers` using `candidate.pubdate` |
| `lib/utils/storage_key.dart` | M | **in-scope candidate** | Added `relatedVideoEnabled = 'piliavalon.shielding.v1.related_video_enabled'` to `ShieldBoxKey` |

## Source Fact Table

### Core Shielding Types

| Symbol | File | Lines | Notes |
|---|---|---|---|
| `ShieldCandidate` | `lib/features/shielding/shielding_models.dart` | 241–284 | Now has 4 new task-066 fields: `description`, `pubdate`, `staffNames`, `isUpowerExclusive` (dirty) |
| `ShieldRuleSet` | `lib/features/shielding/shielding_models.dart` | 138–239 | Now has `relatedVideoEnabled` field with full serialization round-trip (dirty) |
| `ShieldMatcher.match` | `lib/features/shielding/shielding_matcher.dart` | 4–51 | Unchanged core matching logic |
| `ShieldMatcher._valuesForRule` | `lib/features/shielding/shielding_matcher.dart` | 95–128 | Now handles `descriptionKeyword` and `isUpowerExclusive` (dirty) |
| `ShieldMatcher._matchNumbers` | `lib/features/shielding/shielding_matcher.dart` | 130–143 | Now handles `publishTime` via `candidate.pubdate` (dirty) |
| `ShieldScope.videoDetail` | `lib/features/shielding/shielding_models.dart` | 29–37 (enum), 197–208 (`isScopeEnabled`) | `isScopeEnabled` now returns `relatedVideoEnabled` for `videoDetail` scope (dirty) |

### Adapters

| Symbol | File | Lines | Notes |
|---|---|---|---|
| `ShieldingAdapters.fromRecommendationJson` | `lib/features/shielding/shielding_adapters.dart` | 10–62 | **Unchanged.** Does NOT pass `description`, `pubdate`, `staffNames`, or `isUpowerExclusive`. Only maps title, uid, authorName, authorTokens, category, tags, tokens, durationSeconds, playbackCount, danmakuCount. |
| `ShieldingAdapters.fromRelatedVideo` | `lib/features/shielding/shielding_adapters.dart` | 84–96 | **Unchanged.** Uses `scope: ShieldScope.recommendation` (NOT `videoDetail`). Does NOT pass any new task-066 fields. Only maps title, uid, authorName, authorTokens, category, tokens. |
| `ShieldingAdapters.filterList` | `lib/features/shielding/shielding_adapters.dart` | 98–112 | **Unchanged.** Generic list filter with `enabled`, `ruleSet`, `toCandidate`. |
| `ShieldingAdapters.filterRecommendationVideos` | `lib/features/shielding/shielding_adapters.dart` | 117–125 | **Unchanged.** Gates on `ruleSet.recommendationEnabled` (NOT `relatedVideoEnabled`). Uses `fromRelatedVideo` adapter. |

### List-Filter Pipeline — Related Videos

| Call Site | File | Line | Notes |
|---|---|---|---|
| `VideoHttp.relatedVideoList` → `filterRecommendationVideos` | `lib/http/video.dart` | 382–386 | Uses `ShieldSettingsStore().snapshot()` and `filterRecommendationVideos` |
| `VideoHttp.rcmdTop10List` → `filterRecommendationVideos` | `lib/http/video.dart` | 231 | Same pipeline for top-10 ranking |
| `VideoHttp.regionRankList` → `filterRecommendationVideos` | `lib/http/video.dart` | 963–966 | Same pipeline for region ranking |

### Legacy RecommendFilter Boundary

| Symbol | File | Lines | Notes |
|---|---|---|---|
| `RecommendFilter.applyFilterToRelatedVideos` | `lib/utils/recommend_filter.dart` | 10 | Static bool property, value from `Pref.applyFilterToRelatedVideos` |
| Storage key | `lib/utils/storage_key.dart` | 54 | `applyFilterToRelatedVideos = 'applyFilterToRelatedVideos'` |
| Storage default | `lib/utils/storage_pref.dart` | 649–650 | Read from `SettingBoxKey.applyFilterToRelatedVideos` |
| Settings UI label | `lib/pages/setting/models/recommend_settings.dart` | 87–94 | Title: `'过滤器也应用于相关视频'`, subtitle: `'视频详情页的相关视频也进行过滤¹'` |
| Related-video filtering | `lib/http/video.dart` | 369–381 | `RecommendFilter.applyFilterToRelatedVideos` gates legacy duration/like-ratio pre-filter |
| Migration analysis | `lib/features/shielding/shielding_migration.dart` | 287–301 | Documented as old switch, not to be reused |

**Confirm: `RecommendFilter.applyFilterToRelatedVideos` is unchanged and preserved.**

### Introduction Metadata Model/Controller/View Surfaces

| Surface | File | Notes |
|---|---|---|
| `UgcIntroController` | `lib/pages/video/introduction/ugc/controller.dart` | Line 52. Has `staffRelations` (line 61). Calls `queryVideoIntro()` (line 94). References `videoDetail.staff` (line 426, 443). Calls `queryUserStat(List<Staff>? staff)` (line 170). References `videoDetail.isUpowerExclusive` in the view. |
| `UgcIntroPanel` | `lib/pages/video/introduction/ugc/view.dart` | Line 49. Displays `videoDetail.staff` (line 125). Shows `videoDetail.isUpowerExclusive` (line 462). |
| `Staff` model | `lib/models_new/video/video_detail/staff.dart` | Imported by intro controller and view |
| `PgcIntroController` | `lib/pages/video/introduction/pgc/controller.dart` | Line 37. Has `queryVideoIntro()` (line 495). |
| `LocalIntroController` | `lib/pages/video/introduction/local/controller.dart` | Line 13. No-op `queryVideoIntro()` (line 15). |
| `videoDetail` model | Imported via `lib/pages/video/introduction/ugc/controller.dart:22` | Contains `staff`, `isUpowerExclusive`, `pubdate`, `desc` (description) |

### Related-Video List Loading/Filtering Surfaces

| Surface | File | Notes |
|---|---|---|
| `RelatedController` | `lib/pages/video/related/controller.dart` | Line 7. Calls `VideoHttp.relatedVideoList(bvid: bvid)` |
| `RelatedVideoPanel` | `lib/pages/video/related/view.dart` | Line 11. Widget for related-video display |
| `VideoDetailPage` related panel | `lib/pages/video/view.dart` | Lines 946, 1008, 1842, 1858. Embeds `RelatedVideoPanel`. |
| Re-request on episode change | `lib/pages/video/introduction/ugc/controller.dart` | Lines 538–543. Re-queries related videos on episode change |
| `VideoHttp.relatedVideoList` | `lib/http/video.dart` | Lines 358–390. Loads `HotVideoItemModel` list, applies `RecommendFilter` pre-filter, then `filterRecommendationVideos` |

### HotVideoItemModel Fields (source for related-video candidate)

| Field | Type | Available for task-066? |
|---|---|---|
| `title` | String | Already used |
| `owner` (name, mid) | Owner | Already used |
| `tname` | String | Already used (`category`) |
| `pubdate` | int | **Available** — publish time (Unix timestamp) |
| `ctime` | int | **Available** — creation time |
| `desc` | String | **Available** — video description |
| `duration` | int | Available — not in task-066 first batch |
| `dimension` | Dimension? | **Excluded** — dimension model exists but excluded per scope |

### Existing Tests

| Test File | Notes |
|---|---|
| `test/features/shielding/shielding_adapters_test.dart` | 997 lines. Tests `fromRecommendationJson`, `fromRelatedVideo`, `filterList`, `filterRecommendationVideos`. Has task-065 tests for `durationSeconds`/`playbackCount`/`danmakuCount`. Line 968–996: explicit test confirming `fromRelatedVideo` does **not** populate `durationSeconds`/`playbackCount`/`danmakuCount`. **No tests for new task-066 fields.** |
| `test/pages/setting/models/recommend_settings_test.dart` | 336 lines. Tests range shielding settings, tag enrichment, exposure tracker. Line 57: references `'过滤器也应用于相关视频'`. Line 138: expects 17 settings entries. **No test for "相关视频屏蔽" entry.** |
| `test/pages/setting/models/shielding_settings_test.dart` | 512 lines. Tests shielding rule labels and categories. `shieldScopeLabel(ShieldScope.videoDetail)` returns `'视频详情'` (line 331). **No labels for `descriptionKeyword`, `publishTime`, `isUpowerExclusive`.** |

## Current Task-066 Implementation Status: PARTIAL

### What IS Present (candidate work in dirty files)

1. **Type system**: `ShieldRuleType.descriptionKeyword`, `ShieldRuleType.publishTime`, `ShieldRuleType.isUpowerExclusive` are defined.
2. **Candidate model**: `ShieldCandidate` has `description`, `pubdate`, `staffNames`, `isUpowerExclusive` fields.
3. **Matcher**: `ShieldMatcher._valuesForRule` handles `descriptionKeyword` (yields `candidate.description`) and `isUpowerExclusive` (yields `'true'`/`'false'`/`''`). `_matchNumbers` handles `publishTime` via `candidate.pubdate`.
4. **RuleSet**: `ShieldRuleSet.relatedVideoEnabled` field with full serialization (`fromJson`/`toJson`/`copyWith`/constructor).
5. **Scope gating**: `isScopeEnabled` correctly maps `ShieldScope.videoDetail => relatedVideoEnabled`.
6. **Storage key**: `ShieldBoxKey.relatedVideoEnabled` defined.

### What IS Absent (gaps — must be filled for task-066)

1. **Adapter population gap**: `fromRecommendationJson` does NOT populate `description`, `pubdate`, `staffNames`, or `isUpowerExclusive`. `fromRelatedVideo` does NOT populate any new task-066 fields.
2. **Related-video scope mismatch**: `fromRelatedVideo` uses `scope: ShieldScope.recommendation` (line 86). It should use `ShieldScope.videoDetail` so that `isScopeEnabled` gates on `relatedVideoEnabled`. Currently, related-video candidates are scoped as `recommendation` and filtered by `recommendationEnabled`, bypassing the new `relatedVideoEnabled` gate entirely.
3. **filterRecommendationVideos uses wrong enabler**: Line 122 passes `enabled: ruleSet.recommendationEnabled` instead of `ruleSet.relatedVideoEnabled`. Even after fixing the scope, this would still be gated on the wrong flag.
4. **Store persistence gap**: `ShieldSettingsStore.load()` (lines 54–88) and `snapshot()` (lines 90–133) do NOT read `relatedVideoEnabled` from storage. `save()` (lines 135–156) does NOT write it. `clear()` (lines 213–222) does NOT delete it. No `setRelatedVideoEnabled()` method exists.
5. **Settings UI gap**: No `'相关视频屏蔽'` switch exists in `recommendSettings` list (confirmed by `rg` search returning no match). There is no UI entry for the new `relatedVideoEnabled` toggle.
6. **No tests**: No tests exist for `descriptionKeyword` matching, `publishTime` range matching, `isUpowerExclusive` enum matching, `relatedVideoEnabled` scope gating, or the new settings entry.

### What Is Correctly Excluded (per scope — confirmed absent)

- **No `dimension`** field added to `ShieldCandidate`
- **No aspect ratio** matching rule type
- **No portrait/landscape orientation** fields
- **No task-074 derived metrics** (playbackCount/danmakuCount are pre-existing task-065 fields, not task-074)
- Detail page introduction surfaces are NOT modified (correctly untouched)

## Verifications

### 1. Task-066 Meaning: Detail-page introduction metadata for recommendation shielding, NOT hiding the detail page

**CONFIRMED.** The dirty changes add `description`, `pubdate`, `staffNames`, and `isUpowerExclusive` as candidate fields for shielding matching. They do not modify the detail page's own rendering, visibility, or accessibility. The introduction metadata is used as source data fed into `ShieldCandidate` for `ShieldMatcher.match` filtering — same pattern as existing tag shielding. No code hides or disables the current detail page.

### 2. First-Batch Fields

| Field | Model Support (dirty) | Adapter Population | Matcher Support (dirty) |
|---|---|---|---|
| Introduction/description text | `ShieldCandidate.description` | **ABSENT** — neither adapter populates | `descriptionKeyword` in `_valuesForRule` |
| Publish time | `ShieldCandidate.pubdate` (int) | **ABSENT** — neither adapter populates | `publishTime` in `_matchNumbers` |
| Staff/creative team | `ShieldCandidate.staffNames` (List\<String\>) | **ABSENT** — neither adapter populates | **ABSENT** — no `ShieldRuleType.staffKeyword` exists |
| Upower/charging-exclusive | `ShieldCandidate.isUpowerExclusive` (bool?) | **ABSENT** — neither adapter populates | `isUpowerExclusive` in `_valuesForRule` |
| Already-approved stable metadata | — | **ABSENT** — no field defined | **ABSENT** |

**Gap**: `staffNames` has a model field but no corresponding `ShieldRuleType` (no `staffKeyword`) and no matching logic in `ShieldMatcher`. The existing dirty work only covers 3 of 5 first-batch fields in the matcher.

### 3. Exclusions Verified

| Exclusion | Status |
|---|---|
| No `dimension` | **CONFIRMED ABSENT** — not in dirty diff |
| No aspect ratio | **CONFIRMED ABSENT** |
| No portrait/landscape orientation | **CONFIRMED ABSENT** |
| No task-074 derived metrics | **CONFIRMED ABSENT** — only pre-existing task-065 fields (`duration`, `playbackCount`, `danmakuCount`) |

### 4. Related-Video Boundary

| Requirement | Status |
|---|---|
| Must use shared `ShieldMatcher` | **CONFIRMED** — `filterRecommendationVideos` → `filterList` → `ShieldMatcher.match` |
| Must use shared `ShieldRuleSet` | **CONFIRMED** — pipeline uses same `ShieldSettingsStore().snapshot()` |
| Must use list-filter pipeline | **CONFIRMED** — `filterRecommendationVideos` → `filterList` |
| Must NOT directly reuse `fromRecommendationJson` | **CONFIRMED** — uses `fromRelatedVideo` adapter |
| Must add independent "相关视频屏蔽" switch | **ABSENT** — no settings UI entry |
| Must NOT reuse/rename/reinterpret `RecommendFilter.applyFilterToRelatedVideos` | **PRESERVED** — old switch untouched at lines 87–94 of `recommend_settings.dart`. New `relatedVideoEnabled` is a separate field in `ShieldRuleSet`, not `RecommendFilter`. |

### 5. +5162 Route Analysis

Current HEAD: `5151`. Target: `5162`. Required: **11 additional commits**.

The 3 dirty files can form the nucleus of task-066 implementation. A feasible route:

1. Commit current dirty changes as initial task-066 plumbing (1 commit)
2. Implementation slices (est. 4–6 commits): adapter population, store persistence, settings UI, staff-keyword rule type, tests
3. Remaining commits for review fixups, formatting, rebase artifacts

**Risk**: 11 commits is a fixed number — versionCode derives from `git rev-list --count HEAD`. Every commit on the branch counts. No empty/versionCode-only commits are permitted per governance. The implementation must produce exactly 11 meaningful commits from current HEAD to reach 5162.

## Blockers (must resolve before implementation)

| # | Blocker | Severity | Detail |
|---|---|---|---|
| B1 | Store does not persist `relatedVideoEnabled` | **BLOCKING** | `ShieldSettingsStore.load()`, `snapshot()`, `save()`, `clear()` ignore the field. `setRelatedVideoEnabled()` method does not exist. Without this, the toggle can never work. |
| B2 | `fromRelatedVideo` uses wrong scope | **BLOCKING** | Uses `ShieldScope.recommendation` (line 86 of `shielding_adapters.dart`). Must use `ShieldScope.videoDetail` so `isScopeEnabled` gates on `relatedVideoEnabled`. |
| B3 | `filterRecommendationVideos` uses wrong enabler | **BLOCKING** | Uses `ruleSet.recommendationEnabled` (line 122). Must use `ruleSet.relatedVideoEnabled` for the related-video path. |
| B4 | No `staffKeyword` rule type | **BLOCKING (partial)** | `staffNames` field exists in `ShieldCandidate` but no `ShieldRuleType` for matching against staff names. Either add `staffKeyword` to `ShieldRuleType` or defer to a later slice. |

## Yellow Items (risks, not blocking)

| # | Yellow Item | Detail |
|---|---|---|
| Y1 | Adapters don't populate new fields | `fromRecommendationJson` and `fromRelatedVideo` must be extended to read introduction metadata from their respective source models. |
| Y2 | No "相关视频屏蔽" settings UI entry | Must add a `SwitchModel` to `recommendSettings` list with independent storage key. |
| Y3 | No tests for new rule types | Tests needed for `descriptionKeyword`, `publishTime` (range), `isUpowerExclusive` (enum), `relatedVideoEnabled` scope gating. |
| Y4 | `filterRecommendationVideos` used by 3 call sites | All 3 (`relatedVideoList`, `rcmdTop10List`, `regionRankList`) use the same method. Changing the enabler from `recommendationEnabled` to `relatedVideoEnabled` affects all three. Verify each is a related-video surface. `rcmdTop10List` and `regionRankList` may be ranking pages, not video-detail related videos. **This needs design-institute clarification.** |
| Y5 | 11 commits to reach +5162 | Implementation must produce exactly the right commit count. If more or fewer commits are natural, an explicit plan for commit structuring is needed. |
| Y6 | `HotVideoItemModel` has `desc` and `pubdate` | These fields exist on the model but `fromRelatedVideo` doesn't read them. Populating is straightforward. |
| Y7 | `staffNames` field has no matching logic | `ShieldCandidate.staffNames` is a `List<String>` but `_valuesForRule` has no case for iterating it. Either add `staffKeyword` rule type or mark field as deferred. |

## Recommended Atomic Implementation Slices

Based on this source verification, the implementation should proceed in this order:

### Slice 0: Fix Blockers (store + scope + enabler)
- Add `setRelatedVideoEnabled()` to `ShieldSettingsStore`
- Fix `load()`, `snapshot()`, `save()`, `clear()` to handle `relatedVideoEnabled`
- Change `fromRelatedVideo` scope from `ShieldScope.recommendation` to `ShieldScope.videoDetail`
- Change `filterRecommendationVideos` enabler from `recommendationEnabled` to `relatedVideoEnabled`
- **Clarify Y4**: check whether all 3 call sites of `filterRecommendationVideos` are truly related-video surfaces or if some need the old `recommendationEnabled` behavior

### Slice 1: Populate Adapters
- Extend `fromRecommendationJson` to read and pass `description`, `pubdate`, `staffNames`, `isUpowerExclusive` from JSON source
- Extend `fromRelatedVideo` to read and pass `description` (`desc`), `pubdate`, and `isUpowerExclusive` (charging_pay badge) from `HotVideoItemModel`
- Add `staffKeyword` to `ShieldRuleType` and `_valuesForRule` if staff matching is in first batch

### Slice 2: Settings UI
- Add `'相关视频屏蔽'` `SwitchModel` to `recommendSettings` list
- Wire it to `ShieldSettingsStore().setRelatedVideoEnabled()`
- Add `ShieldRuleType` labels for `descriptionKeyword`, `publishTime`, `isUpowerExclusive`, `staffKeyword` (if added)

### Slice 3: Tests
- Add adapter tests for new candidate field population
- Add matcher tests for `descriptionKeyword`, `publishTime`, `isUpowerExclusive`
- Add scope gating test for `videoDetail` / `relatedVideoEnabled`
- Update `recommendSettings` test for new entry count and presence
- Add independence test proving old `applyFilterToRelatedVideos` is unaffected

## Candidate Evidence Statement

This report is candidate evidence produced by DeepSeek Reasonix (deepseek-v4-pro)
as a read-only source verification worker. It cites specific file paths, line
numbers, and command outputs. It does not claim task-066 is green, accepted,
releasable, or ready for +5162 APK/prerelease. It does not claim any gate is
closed. Codex must review this artifact before treating any findings as worksite
evidence.

**All findings are derived from current worktree state as of `git status` and
`git diff` output collected during this verification session.**
