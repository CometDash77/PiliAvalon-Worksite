# Task-066 Baseline Recovery Audit

Audience: agent-facing (English)
Reasonix role: task066-baseline-recovery-auditor
Review owner: Codex
Date: 2026-06-17

## 1. Reference Points

| Label | Commit | Rev-list | Branch |
|-------|--------|----------|--------|
| Correct baseline (task065-comment-gate-prebuild.27497810462) | `f96a0e1d7b5dfc99a263c7478ebd9b3e69a020e5` | 5162 | `origin/production` |
| Wrong prerelease (task066-prebuild.27667066405) | `acfc3a356d99765b444c849bc26ef4a1332c6ddb` | 5162 | `task-066-detail-intro-shielding` |
| Current HEAD | `b27dbc295` (this branch tip) | 5164 | `task-066-detail-intro-shielding` |
| Common merge-base | `1093b29be0a417663ca098188514d84875af7b13` | — | — |

## 2. Commands Run

```bash
git status --short --branch
git log --oneline -10
git merge-base f96a0e1d HEAD
git merge-base acfc3a356 HEAD
git merge-base f96a0e1d acfc3a356
git rev-list --count f96a0e1d
git rev-list --count acfc3a356
git rev-list --count HEAD
git branch -a --contains f96a0e1d
git branch -a --contains acfc3a356
comm -23 <(git ls-tree -r --name-only f96a0e1d | sort) <(git ls-tree -r --name-only acfc3a356 | sort)
comm -13 <(git ls-tree -r --name-only f96a0e1d | sort) <(git ls-tree -r --name-only acfc3a356 | sort)
comm -12 <(git ls-tree -r --name-only f96a0e1d | sort) <(git ls-tree -r --name-only acfc3a356 | sort) | while read f; do if ! git diff --quiet f96a0e1d acfc3a356 -- "$f"; then echo "M $f"; fi; done
git rev-list --count 1093b29b..f96a0e1d
git rev-list --count 1093b29b..acfc3a356
git log --oneline f96a0e1d ^acfc3a356
git log --oneline acfc3a356 ^f96a0e1d
git diff --name-only f96a0e1d HEAD -- lib/ test/ .github/
git diff --stat f96a0e1d HEAD -- lib/ test/ .github/
# Plus per-file diffs for all modified shielding files.
```

## 3. Divergence Evidence: Same Rev-List, Different Lineage

**Finding: both reference points have rev-list count 5162, but this is coincidental.**

- Both `f96a0e1d` and `acfc3a356` have exactly **13 commits** from the common merge-base `1093b29b`.
- **Zero commits are shared** between the two branches beyond the merge-base. Complete divergence.
- The correct baseline `f96a0e1d` lives on `origin/production` and is a merge commit: `Merge Task065 shielding baseline into comment gate work`.
- The wrong prerelease `acfc3a356` lives on `task-066-detail-intro-shielding` and descends from a parallel task-066 branch that never received the task065 merge.

### Correct baseline commits (not in wrong prerelease):

```
f96a0e1d7 Merge Task065 shielding baseline into comment gate work
fdcc82523 Add comment-based home feed shielding gate
32192aa62 Ensure Android prerelease versionCode can upgrade
dc799f110 Add comment shielding settings
ef3c9eca5 Update Reasonix plan-gated workflow
92c9046dc Chore: add docs/ nul reasonix.toml to .gitignore, clean up stale branches
e17375680 Record Task-020 temporary quiet acceptance
abb6128ea Merge Task 042 repeat exposure from 5122 baseline
343da17f2 Record Task 042 wrong baseline retrospective seed
0edbea207 Record Task 042 5122 manual acceptance
91830f2f2 Record Task 042 5122 prerelease evidence
bf9f78b4b Record Task-020 PR closure
0eed2f9b8 Record Task-026 final closure
```

### Wrong prerelease commits (not in correct baseline):

```
acfc3a356 Draft task-066 prebuild 5162 notes
68489f804 Review task-066 diagnostic CI failure
e92a911b5 Refine task-066 related video adapter scope
2039b8136 Test task-066 quick action scope
291ca605c Record task-066 implementation checkpoint
64dfafc63 Test task-066 shield store flags
68092902a Fix task-066 quick action labels
e2d438d20 Record task-066 plus5162 gate
41efe2607 Fix task-066 rule editor coverage
d21dbc6f9 Temp implement task-066 related video shielding
f8be1e9bf Temp record task-066 prerelease prep
f806d36d1 Record task-065 app stat acceptance cleanup
daa69e896 Record task-065 app stat prebuild 5149 evidence
```

### Root cause

The task066 branch was created from a pre-task065-merge parent (around `1093b29b` or later but before the production merge at `f96a0e1d`). Task065 shielding infrastructure (comment shielding config, comment gate, comment shield settings page) was merged to production and is present at `f96a0e1d` but never reached the task066 branch. The task066 work instead started from a bare `1093b29b`-era state and implemented detail-intro shielding on top of it, removing comment-shielding stubs that didn't exist in that bare baseline and replacing `avatarPendant`/`garb` types with the new detail-intro types.

## 4. Comment-Shielding Files: Present in Correct Baseline, Missing in HEAD

### Source files (3)

| File | Role |
|------|------|
| `lib/features/shielding/comment_shielding_config.dart` | CommentShieldingStore, CommentShieldConfig, CommentShieldMatcher, comment decoration rules, reply-field matrix (level/sex/member/ip/words/likes) |
| `lib/features/shielding/home_feed_comment_gate.dart` | HomeFeedCommentGate.filter — async gate that batch-loads comment stats for homepage cards and filters by comment count threshold |
| `lib/pages/comment_shield_settings/view.dart` | CommentShieldSettingsPage — full settings UI for comment-level, sex, membership, IP location, word count, like count filters with visual decoration |

### Test files (7)

| File | Coverage |
|------|----------|
| `test/features/shielding/comment_shielding_config_test.dart` | CommentShieldConfig fromJson, defaults |
| `test/features/shielding/comment_shielding_matcher_test.dart` | CommentShieldMatcher level/sex/member/ip/words/likes rules |
| `test/features/shielding/home_feed_comment_gate_test.dart` | HomeFeedCommentGate filter and batch loading |
| `test/features/shielding/comment_decoration_rule_test.dart` | Comment decoration rule application logic |
| `test/features/shielding/comment_quick_action_decoration_test.dart` | Quick action decoration rules on comments |
| `test/features/shielding/comment_reply_field_matrix_test.dart` | Reply field matrix filtering |
| `test/pages/comment_shield_settings/comment_shield_settings_test.dart` | CommentShieldSettingsPage widget test |

### Files modified to remove/disable comment shielding

| File | Change |
|------|--------|
| `lib/features/shielding/shielding.dart` | Removed `export 'comment_shielding_config.dart'` |
| `lib/models/common/setting_type.dart` | Removed `commentShieldSetting` enum value |
| `lib/pages/setting/view.dart` | Removed import of `comment_shield_settings/view.dart`, removed `_SettingsModel` entry, removed page dispatch case |
| `lib/router/app_pages.dart` | Removed import, removed `/commentShieldSetting` route |
| `lib/http/video.dart` | Removed `HomeFeedCommentGate.filter` calls from both `homeRecommendV2` and `homeDynamic` — now passes unfiltered list directly to ExposureTracker |
| `lib/pages/common/reply_controller.dart` | Replaced `CommentShieldMatcher.match` + per-item `ShieldingAdapters.isVisible` dual-filter with simple `ShieldingAdapters.filterList` |
| `lib/pages/video/reply/widgets/reply_item_grpc.dart` | Removed `shieldSettingsStore` parameter, removed pendant/garb value extraction in `_buildQuickActions` |

### Test files modified to remove comment-shielding coverage

| File | Change |
|------|--------|
| `test/features/shielding/shielding_adapters_test.dart` | Removed 2 tests for pendant/garb mapping |
| `test/features/shielding/shielding_store_test.dart` | Removed `avatarPendant`/`garb` round-trip test |
| `test/pages/setting/models/shielding_settings_test.dart` | (132 lines changed — category/label updates) |
| `test/pages/setting/recommend_range_shielding_test.dart` | (14 lines changed — minor formatting) |

## 5. Task-066 Functional Changes to Preserve

These changes exist in the wrong prerelease (and HEAD) but NOT in the correct baseline. They represent the actual task-066 work.

### 5.1 ShieldRuleType — new enum values

```dart
descriptionKeyword,   // detail-intro description keyword matching
publishTime,           // video publish time range
isUpowerExclusive,     // charging-exclusive (充电专属) boolean
staffKeyword,          // staff/crew name keyword
```

Replaces removed: `avatarPendant`, `garb`

### 5.2 ShieldCandidate — new fields

```dart
final String? description;        // video description text
final int? pubdate;               // publish timestamp
final List<String> staffNames;    // crew/staff names
final bool? isUpowerExclusive;    // charging-exclusive flag
```

Replaces removed: `avatarPendantValues`, `garbValues`

### 5.3 ShieldRuleSet.relatedVideoEnabled

New independent toggle `relatedVideoEnabled` (default `true`) with full JSON serialization, store persistence (`relatedVideoEnabledKey`), `setRelatedVideoEnabled()` method, and `clear()` coverage. The `isScopeEnabled()` logic routes `ShieldScope.videoDetail` through `relatedVideoEnabled` instead of `recommendationEnabled`.

### 5.4 ShieldingAdapters.filterRelatedVideos

New static method that filters `HotVideoItemModel` lists using `ShieldRuleSet.relatedVideoEnabled` and scopes candidates as `ShieldScope.videoDetail`:

```dart
static List<HotVideoItemModel> filterRelatedVideos(
  List<HotVideoItemModel> items,
  ShieldRuleSet ruleSet,
) => filterList(
  items,
  enabled: ruleSet.relatedVideoEnabled,
  ruleSet: ruleSet,
  toCandidate: (item) => fromRelatedVideo(item, scope: ShieldScope.videoDetail),
);
```

`fromRelatedVideo` gained an optional `scope` parameter (defaults to `ShieldScope.recommendation` for backward compatibility) and now populates `description`, `pubdate`, `isUpowerExclusive` from `HotVideoItemModel` fields.

### 5.5 ShieldingAdapters.fromHomePageItem — detail-intro metadata

Added population of `description`, `pubdate`, `isUpowerExclusive` from homepage JSON fields (`desc`, `pubdate`, `charging_pay`).

### 5.6 ShieldMatcher — new type matching

- `ShieldRuleType.descriptionKeyword`: yields `candidate.description` as contains-match value
- `ShieldRuleType.staffKeyword`: yields `candidate.staffNames`
- `ShieldRuleType.isUpowerExclusive`: yields `'true'`/`'false'`/`''` as enum-match value
- `ShieldRuleType.publishTime`: yields `candidate.pubdate` as range-match value

### 5.7 ShieldSettingsStore — match mode defaults

Updated `modeFor` to route:
- `publishTime` → `ShieldMatchMode.range`
- `isUpowerExclusive` → `ShieldMatchMode.enumValue`
- `descriptionKeyword`, `staffKeyword` → `ShieldMatchMode.contains`

### 5.8 shield_quick_action.dart

- **Removed** `_isRecommendationQuickActionType` guard — quick actions now accept all types including comment-member and detail-intro types
- **Added** labels for new types: `descriptionKeyword`, `publishTime`, `isUpowerExclusive`, `staffKeyword`
- **Removed** `avatarPendant` and `garb` labels

### 5.9 shielding_settings/view.dart

- Added `descriptionKeyword`, `publishTime`, `isUpowerExclusive`, `staffKeyword` to `_quickActionTypes`
- Updated `_presetMatchMode` to map new types to `range`/`enumValue`/`contains`
- Updated `_modeSelectable` for new types

### 5.10 setting/models/shielding_settings.dart

- `shieldRuleTypeLabel()`: replaces `avatarPendant`/`garb` labels with `descriptionKeyword`/`publishTime`/`isUpowerExclusive`/`staffKeyword` labels
- `shieldingRuleCategoryLabels`: replaces `'头像挂件'`/`'装扮卡片'` with `'视频详情信息'`
- `shieldingRuleCategoryFor()`: new `'视频详情信息'` category for the 4 new types

### 5.11 setting/models/recommend_settings.dart

- Added `relatedVideoEnabled` `SwitchModel` entry with `ShieldBoxKey.relatedVideoEnabled`
- Numerous formatting-only changes (trailing commas, line wraps, `_` prefix on local functions)

### 5.12 http/video.dart

- Related video filtering call changed from `filterRecommendationVideos` to `filterRelatedVideos`

### 5.13 storage_key.dart

- Added `ShieldBoxKey.relatedVideoEnabled`

### 5.14 build.yml

- Removed `PILI_VERSION_CODE_FLOOR: 5150` env var from `Set and Extract version` step

### 5.15 Test changes

- `shielding_store_test.dart`: Replaced `avatarPendant`/`garb` round-trip test with `relatedVideoEnabled` persistence, `setRelatedVideoEnabled`, `clear` tests; added `descriptionKeyword`/`staffKeyword` contains-mode and `publishTime` range-mode quick-action tests; added `isUpowerExclusive` enum-mode test
- `shielding_adapters_test.dart`: Replaced pendant/garb mapping tests with `fromRelatedVideo` scope and detail-intro field tests
- `video_card_shield_quick_action_test.dart`: Replaced `'rejects comment decoration rule types'` with `'text dialog creates video detail description rule'` widget test; preserved recommendation dialog tests

## 6. Conflict Hotspot Map

When rebasing/merging task066 work onto the correct baseline `f96a0e1d`, conflicts are expected in these files:

### HIGH conflict probability (both sides changed same lines/sections)

| File | Conflict reason |
|------|----------------|
| `lib/features/shielding/shielding_models.dart` | RuleTypes replaced (avatarPendant/garb vs descriptionKeyword/publishTime/isUpowerExclusive/staffKeyword); Candidate fields replaced; RuleSet gained relatedVideoEnabled; isScopeEnabled changed |
| `lib/features/shielding/shielding_store.dart` | relatedVideoEnabled key + methods added; modeFor updated for both new types and removed old types |
| `lib/features/shielding/shielding_adapters.dart` | fromReplyInfo pendant/garb logic removed; fromHomePageItem detail-intro fields added; fromRelatedVideo scope param + detail-intro fields; filterRelatedVideos added |
| `lib/features/shielding/shielding_matcher.dart` | Candidate field extraction changed for new/old types |
| `lib/features/shielding/shielding.dart` | Barrel exports: correct baseline adds `comment_shielding_config.dart`, task066 branch removes it |
| `lib/http/video.dart` | Correct baseline adds HomeFeedCommentGate.filter calls; task066 branch removes them AND changes filterRecommendationVideos→filterRelatedVideos |
| `lib/pages/common/reply_controller.dart` | Correct baseline has CommentShieldMatcher + Adapters dual-filter; task066 branch simplified to filterList only |
| `lib/common/widgets/video_card/shield_quick_action.dart` | Type guard removal + new labels vs old pendant/garb labels |
| `lib/pages/setting/view.dart` | Correct baseline adds comment shield settings entry; task066 branch removes it |
| `lib/router/app_pages.dart` | Correct baseline adds `/commentShieldSetting` route; task066 branch removes it |
| `lib/models/common/setting_type.dart` | Correct baseline adds `commentShieldSetting`; task066 branch removes it |

### MEDIUM conflict probability

| File | Conflict reason |
|------|----------------|
| `lib/pages/shielding_settings/view.dart` | Both sides change quickActionTypes and modeFor |
| `lib/pages/setting/models/shielding_settings.dart` | Both sides change rule type labels and categories |
| `lib/pages/setting/models/recommend_settings.dart` | Task066 adds relatedVideoEnabled switch + formatting changes |
| `lib/utils/storage_key.dart` | Task066 adds relatedVideoEnabled key |
| `lib/pages/video/reply/widgets/reply_item_grpc.dart` | Task066 removes shieldSettingsStore param; both sides touch quick action building |

### LOW conflict probability

| File | Conflict reason |
|------|----------------|
| `lib/pages/setting/recommend_range_shielding.dart` | Formatting + constructor change |
| `lib/scripts/build.ps1` | (present in correct baseline, may not be in wrong) |
| `.github/workflows/build.yml` | PILI_VERSION_CODE_FLOOR removal |
| `.gitignore` | docs/ nul reasonix.toml entry |

### Files to RESTORE from correct baseline (no conflict, just copy)

These files exist in `f96a0e1d` but are completely absent from the current branch:

- `lib/features/shielding/comment_shielding_config.dart`
- `lib/features/shielding/home_feed_comment_gate.dart`
- `lib/pages/comment_shield_settings/view.dart`
- `test/features/shielding/comment_shielding_config_test.dart`
- `test/features/shielding/comment_shielding_matcher_test.dart`
- `test/features/shielding/home_feed_comment_gate_test.dart`
- `test/features/shielding/comment_decoration_rule_test.dart`
- `test/features/shielding/comment_quick_action_decoration_test.dart`
- `test/features/shielding/comment_reply_field_matrix_test.dart`
- `test/pages/comment_shield_settings/comment_shield_settings_test.dart`

## 7. Recommended Minimal Recovery Strategy

### Strategy: Rebase task066 commits onto correct baseline

1. **Create a recovery branch** from the correct baseline `f96a0e1d`. This gives you the full comment-shielding infrastructure plus all production history.

2. **Cherry-pick or rebase the task066 implementation commits** in order. The 13 task066 commits are (oldest first):
   ```
   daa69e896 Record task-065 app stat prebuild 5149 evidence         [records only — skip?]
   f806d36d1 Record task-065 app stat acceptance cleanup              [records only — skip?]
   f8be1e9bf Temp record task-066 prerelease prep                     [records only — skip?]
   d21dbc6f9 Temp implement task-066 related video shielding          [**CORE**]
   41efe2607 Fix task-066 rule editor coverage                        [**CORE**]
   e2d438d20 Record task-066 plus5162 gate                            [records only — skip?]
   68092902a Fix task-066 quick action labels                         [**CORE**]
   64dfafc63 Test task-066 shield store flags                         [**CORE**]
   291ca605c Record task-066 implementation checkpoint                [records only — skip?]
   2039b8136 Test task-066 quick action scope                         [**CORE**]
   e92a911b5 Refine task-066 related video adapter scope              [**CORE**]
   68489f804 Review task-066 diagnostic CI failure                    [records only — skip?]
   acfc3a356 Draft task-066 prebuild 5162 notes                       [records only — skip?]
   ```

   The **6 substantive implementation commits** contain all task066 changes. Records-only commits can be cherry-picked optionally or recreated fresh.

3. **For each conflict**, resolve by:
   - **Comment-shielding files** (`comment_shielding_config.dart`, `home_feed_comment_gate.dart`, `comment_shield_settings/view.dart`): Keep from correct baseline (these are the task065 infrastructure that was missing).
   - **`shielding_models.dart`**: Keep task066's `ShieldRuleType` values (add detail-intro types, remove avatarPendant/garb). Keep task066's `ShieldCandidate` fields. Keep BOTH `relatedVideoEnabled` from task066 AND the `commentEnabled`/`recommendationEnabled` from correct baseline. Merge `isScopeEnabled` — videoDetail should use `relatedVideoEnabled` (task066), the rest unchanged (correct baseline).
   - **`shielding_store.dart`**: Merge both — keep comment-related storage keys from correct baseline, add `relatedVideoEnabled` from task066. Merge `modeFor` to include both the new detail-intro type mappings AND remove the old avatarPendant/garb mappings.
   - **`shielding_adapters.dart`**: Keep the removal of pendant/garb collection in `fromReplyInfo` (task066). Keep the detail-intro metadata population in `fromHomePageItem` (task066). Keep `fromRelatedVideo` scope param and detail fields (task066). Keep `filterRelatedVideos` (task066). Keep `filterRecommendationVideos` (correct baseline, for homepage callers).
   - **`shield_quick_action.dart`**: Keep task066 changes (removed guard, new labels). The correct baseline has the old pendant/garb labels — discard those.
   - **`shielding_matcher.dart`**: Keep task066 changes (new type case arms). The old avatarPendant/garb arms should be removed (task066 already does this).
   - **`http/video.dart`**: Merge carefully — KEEP `HomeFeedCommentGate.filter` from correct baseline in the homepage recommend/dynamic methods (the comment gate is independently useful). KEEP `filterRelatedVideos` from task066 for the related-video endpoint. These are non-overlapping.
   - **`reply_controller.dart`**: Merge the CommentShieldMatcher pre-filter from correct baseline WITH the ShieldingAdapters.filterList approach from task066. The correct baseline had CommentShieldMatcher.match() + per-item ShieldingAdapters.isVisible. The task066 code simplified to just filterList. **Recommendation**: use the correct baseline's dual-filter approach since it preserves comment-level decoration filtering that filterList alone cannot replicate.
   - **`setting/view.dart`**, **`setting_type.dart`**, **`app_pages.dart`**: Keep the correct baseline additions (comment shield settings). The task066 removals were incorrect — they removed features that never existed on the task066 branch.
   - **`shielding_settings/view.dart`**: Merge `_quickActionTypes` (add new types, remove pendant/garb entries). Merge `_presetMatchMode`.
   - **`shielding_settings.dart` (model)**: Merge labels and categories.
   - **`recommend_settings.dart`**: Merge `relatedVideoEnabled` switch entry.
   - **`storage_key.dart`**: Merge `relatedVideoEnabled` key.
   - **`reply_item_grpc.dart`**: Keep `shieldSettingsStore` removal from task066 (the store was injected unnecessarily — quick actions use their own store internally now).
   - **`build.yml`**: Keep task066's removal of `PILI_VERSION_CODE_FLOOR` (but verify it was intentional).
   - **Test files**: Merge all — restore the 7 comment-shielding test files from correct baseline; merge the modified test files keeping both task066 additions and comment-shielding coverage.

### Verification Tests After Recovery

1. **Comment shielding unit tests** (restored):
   ```bash
   flutter test test/features/shielding/comment_shielding_config_test.dart
   flutter test test/features/shielding/comment_shielding_matcher_test.dart
   flutter test test/features/shielding/home_feed_comment_gate_test.dart
   flutter test test/features/shielding/comment_decoration_rule_test.dart
   flutter test test/features/shielding/comment_quick_action_decoration_test.dart
   flutter test test/features/shielding/comment_reply_field_matrix_test.dart
   flutter test test/pages/comment_shield_settings/comment_shield_settings_test.dart
   ```

2. **Task066 detail-intro shielding tests** (modified):
   ```bash
   flutter test test/features/shielding/shielding_store_test.dart
   flutter test test/features/shielding/shielding_adapters_test.dart
   flutter test test/features/shielding/video_card_shield_quick_action_test.dart
   flutter test test/features/shielding/comment_reply_controller_test.dart
   ```

3. **Integration check**:
   ```bash
   flutter test test/features/shielding/
   flutter test test/pages/comment_shield_settings/
   flutter test test/pages/setting/
   ```

4. **Static analysis**:
   ```bash
   dart analyze lib/features/shielding/
   dart analyze lib/pages/comment_shield_settings/
   dart analyze lib/pages/setting/
   ```

### Risk: reply_controller.dart dual-filter approach

The biggest design decision is in `reply_controller.dart`. The correct baseline uses `CommentShieldMatcher.match()` for decoration-level filtering (level, sex, membership, IP, words, likes) plus `ShieldingAdapters.isVisible()` for rule-based filtering. Task066 simplified this to `ShieldingAdapters.filterList()` only — losing the decoration-level filtering. **Recommendation**: restore the correct baseline's dual-filter approach, as `CommentShieldingStore` and `CommentShieldMatcher` are restored from the correct baseline files.

## 8. Summary

| Metric | Value |
|--------|-------|
| Files missing from current branch (present in correct baseline) | 11 (3 src + 7 test + 1 tool) |
| Files modified divergently | 27 (lib + test) |
| Task066 substantive commits to preserve | 6 |
| High-conflict files | 11 |
| Medium-conflict files | 4 |
| Low-conflict files | 3 |
| Files to restore directly (no conflict) | 10 |
| Total source diff: f96a0e1d → HEAD | 950 insertions, 3114 deletions |

**Root cause**: task066 branch forked from a pre-task065-merge parent. The task065 comment-shielding baseline (merged to production at `f96a0e1d`) was never incorporated. Task066's 13 commits are completely divergent from production's 13 commits. The coincidental rev-list count of 5162 on both sides masked the divergence.

**Recovery**: Rebase the 6 substantive task066 commits onto `f96a0e1d`, resolving conflicts with the guidance in Section 6. Restore the 10 missing comment-shielding files directly from `f96a0e1d`. Run the verification tests listed in Section 7. Do NOT merge — rebase to preserve linear history on the recovery branch.
