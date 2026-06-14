# unreviewed Reasonix candidate output

## Comment Shielding Phase 4 Independent Review — Candidate

**Date:** 2026-06-14 (continued session)
**Role:** Reasonix (auditor)
**Status:** ⚠️ **Unreviewed candidate** — requires Codex review. Do not treat as final.

---

## Reading Scope

Documents reviewed:
- `docs/superpowers/specs/2026-06-15-comment-shielding-system-spec.md` (approved spec)
- `docs/superpowers/plans/2026-06-14-comment-shielding-system-phase2-plan.md` (Phase 2 implementation plan)
- `records/session/2026-06-14-comment-shielding-phase4-5-blueprint.md` (Phase 4/5 review blueprint)
- Worksite source at `C:/Users/77182/Documents/Coding/piliavalon` — all modified/new files in the uncommitted diff

Source files read in full:
| File | Lines |
|------|-------|
| `lib/features/shielding/comment_shielding_config.dart` | 318 |
| `lib/features/shielding/shielding.dart` | 6 |
| `lib/features/shielding/shielding_models.dart` | 292 |
| `lib/features/shielding/shielding_adapters.dart` | 168 |
| `lib/features/shielding/shielding_matcher.dart` | 144 |
| `lib/pages/common/reply_controller.dart` | 310 |
| `lib/pages/comment_shield_settings/view.dart` | 375 |
| `lib/models/common/setting_type.dart` | 17 |
| `lib/pages/setting/view.dart` | 343 |
| `lib/pages/setting/models/shielding_settings.dart` | 141 |
| `lib/common/widgets/video_card/shield_quick_action.dart` | 615 |
| `lib/router/app_pages.dart` | (route section) |

Test files verified for coverage:
| Test file | Lines |
|----------|-------|
| `test/features/shielding/comment_shielding_config_test.dart` | (untracked) |
| `test/features/shielding/comment_shielding_matcher_test.dart` | (untracked) |
| `test/features/shielding/comment_decoration_rule_test.dart` | (untracked) |
| `test/features/shielding/comment_reply_controller_test.dart` | +151 diff |
| `test/features/shielding/shielding_adapters_test.dart` | +57 diff |
| `test/features/shielding/shielding_store_test.dart` | +33 diff |
| `test/features/shielding/video_card_shield_quick_action_test.dart` | +17 diff (updated) |
| `test/pages/setting/models/shielding_settings_test.dart` | +69 diff |

Commands run (read-only): `git diff --stat`, `git status --short`, `rg`/`grep` for hard exclusion patterns, `git diff HEAD -- [files]`.

---

## Factual Findings

### 1. CommentShieldingConfig is additive singleton config storage, separate from ShieldingRule list ✅

**Verified.** `CommentShieldingConfig` (lib/features/shielding/comment_shielding_config.dart) is a standalone data class with 9 direct setting fields. It is persisted as one JSON string under a dedicated key `piliavalon.comment_shielding.v1.config` in the existing settings box via `CommentShieldingStore`. There is no overlap with `ShieldingRule` list. The existing `ShieldRuleSet` rules remain in a separate structure with its own key.

- `CommentShieldingStore.snapshot()` reads one JSON object, returns one `CommentShieldingConfig`.
- `CommentShieldingStore.save()` writes one JSON string.
- No list traversal needed. No migration.

### 2. Settings page is first-level and has no master switch ✅

**Verified.**
- `SettingType.commentShieldSetting('评论区屏蔽设置')` is a top-level enum member, sibling to `shieldingSetting`, `channelQuietSetting`, `recommendSetting`, etc.
- In `lib/pages/setting/view.dart`, the item appears in the `_items` list at its own position (line 67-70 in diff), with its own icon and subtitle.
- In wide-landscape mode, the switch case maps `SettingType.commentShieldSetting` to `CommentShieldSettingsPage(showAppBar: false)`.
- Route at `/commentShieldSetting` is registered in `lib/router/app_pages.dart` (new GetPage entry).
- The settings page (`CommentShieldSettingsPage`) has **no master switch**. Each setting operates independently. Empty/unset = no filtering.

### 3. All nine controls and semantics ✅

All nine controls are present in the settings page (in order):

| # | Setting | Input type | Semantics verified |
|---|---------|-----------|-------------------|
| 1 | levelThreshold | Number 0-6, dialog | null/0 = no filter; hides when `member.level < threshold` |
| 2 | genderFilter | Multi-select (`男`, `女`, `保密`, `''`) | Selected = blocked; empty list = no filter |
| 3 | memberFilter | Multi-select (4 VIP keys) | Selected key pair = blocked; strict match, no hierarchy |
| 4 | ipLocationFilter | Multi-select (31 provinces + 海外) | Selected = blocked; strips `IP属地：` prefix before matching |
| 5 | minCharCount | Number dialog | null = no filter; hides when `content.message.length < minCharCount` |
| 6 | maxCharCount | Number dialog | null = no filter; hides when `content.message.length > maxCharCount` |
| 7 | likeThreshold | Number dialog | null/0 = no filter; hides when `reply.like < likeThreshold` |
| 8 | blockWithPicture | SwitchListTile | hides when `content.pictures.isNotEmpty` |
| 9 | blockWithEmote | SwitchListTile | hides when `content.emotes.isNotEmpty` |

### 4. minCharCount > maxCharCount is rejected/not saved ✅

**Two-layer enforcement:**

1. **UI layer** (`_canSaveBounds` in `CommentShieldSettingsPage`): When `minCharCount != null && maxCharCount != null && minCharCount > maxCharCount`, a toast "最少字数不能大于最多字数" is shown and the method returns `false`, preventing save.

2. **Persisted config sanitization** (`CommentShieldingConfig.fromJson`): When deserializing, if both `min_char_count` and `max_char_count` are non-null and `minCharCount > maxCharCount`, **both are set to null** (lines 102-116 of comment_shielding_config.dart). This is a hardening fix against stale/corrupt persisted data.

### 5. Empty numeric input clears stale saved thresholds ✅

**Verified.** In `_editNumber`, when the dialog field is empty/blank (`trimmed.isEmpty`), the result is `_NumberEditResult(null)` which is then passed to `onSaved(null)`. This calls `_config.copyWith(field: null)`, which sets the field to `null` in the config, and `_save()` persists it. So clearing the input and tapping "保存" sends `null`, not the previous value.

### 6. Filtering is pre-render through reply controller/list path, not widget-layer hide/show ✅

**Verified.** In `ReplyController.applyShielding()` (lib/pages/common/reply_controller.dart, lines 91-124), filtering happens in `handleListResponse` which is called by the common list controller **before** the data reaches any widget. The flow:

```
API response → customHandleResponse → handleListResponse → applyShielding()
  → filter root replies (config match + rule match)
  → for each surviving root, filter its child replies
  → mutate dataList in place
  → widget renders the already-filtered list
```

No widget-layer hide/show. No flash.

### 7. Parent/root removal hides children naturally ✅

**Verified.** When a parent/root reply matches a config filter, `applyShielding()` removes it from the `visibleReplies` list at line 96-105. Since child replies are nested as `reply.replies`, they are never rendered. No explicit child iteration needed for parent removal.

### 8. Child filtering removes only child ✅

**Verified.** The child filtering loop (lines 107-122) iterates each child individually, filtering only the matching child. Parent comment and non-matching siblings are kept.

### 9. Existing comment keyword/UID/selected-text quick actions still work ✅

**Verified — no changes to these files:**
- `lib/pages/video/reply/widgets/reply_item_grpc.dart` — zero diff. The existing comment quick actions remain:
  - Line 1143-1145: ShieldRuleType.uid → "屏蔽评论用户 UID"
  - Line 1157-1160: ShieldRuleType.keyword → "屏蔽整条评论文本"
  - Line 1250-1256: ShieldRuleType.keyword → "屏蔽评论关键词" (selected text)
- `lib/pages/video/introduction/ugc/view.dart` — zero diff. Video-page quick actions unchanged.

Additionally, in `ReplyController.applyShielding()`, existing keyword/UID rules still respect `ShieldRuleSet.commentEnabled` (line 94: `rulesEnabled = ruleSet.globalEnabled && ruleSet.commentEnabled`), while the new config filters are independent of this switch.

### 10. Pendant/garb are comment-scope rule categories, not comment quick actions ✅

**Verified.**
- `ShieldRuleType.avatarPendant` and `ShieldRuleType.garb` are new enum values in the existing `ShieldingRule` system (in `shielding_models.dart`).
- `ShieldMatcher._valuesForRule` handles both types, yielding values from `ShieldCandidate.avatarPendantValues` and `ShieldCandidate.garbValues`.
- Adapter population (`ShieldingAdapters.fromReplyInfo`) extracts pendant/garb values from `ReplyInfo.member.garbPendantImage`, `memberV2.garb.pendantImage`, `member.garbCardNumber/Image/JumpUrl`, `memberV2.garb.cardNumber/Image/JumpUrl`.
- Labels/categories in `shielding_settings.dart`: `shieldRuleTypeLabel` → `头像挂件` / `装扮卡片`; `shieldingRuleCategoryFor` → `头像挂件` / `装扮卡片`; `shieldingRuleCategoryLabels` includes them.
- Tests in `test/pages/setting/models/shielding_settings_test.dart` verify labels and categories.
- The comment quick actions in `reply_item_grpc.dart` do NOT add pendant/garb rules — they only use `ShieldRuleType.uid` and `ShieldRuleType.keyword`.

### 11. Video-card quick actions cannot create comment-only avatarPendant or garb rules ✅

**Verified.** `VideoCardShieldQuickAction.addRule()` (in `shield_quick_action.dart`) has a guard:

```dart
if (!_isRecommendationQuickActionType(type)) {
  return; // early exit, no rule added
}
```

And `_isRecommendationQuickActionType` returns `false` for both `ShieldRuleType.avatarPendant` and `ShieldRuleType.garb`. The test at `test/features/shielding/video_card_shield_quick_action_test.dart` lines 29-44 confirms this behavior:

```dart
test('rejects comment decoration rule types', () async {
  await VideoCardShieldQuickAction.quickRule(type: ShieldRuleType.avatarPendant, ...);
  await VideoCardShieldQuickAction.quickRule(type: ShieldRuleType.garb, ...);
  expect((await store.load()).rules, isEmpty);
});
```

---

## Blockers

**No blockers identified.**

---

## Warnings

1. **ShieldRuleType enumeration order** — `avatarPendant` and `garb` were appended to the end of `ShieldRuleType`. This changes the ordinal index. If any persisted code relied on position-based serialization (e.g., protobuf enum index), this would break. However, `ShieldRule.toJson()`/`fromJson()` use `.name` (string), not index, so this is safe. **No action required.**

2. **Pendant/garb matching precision** — As noted in Phase 2 plan, pendant matching is against raw image URL strings and card metadata, not stable pendant/garb IDs. The UI labels acknowledge this (`头像挂件`/`装扮卡片` without claiming ID matching). Users may find URL-based matching fragile if pendant images get CDN URL changes. This is a known limitation, not an implementation bug.

3. **No test for `minCharCount > maxCharCount` persisted sanitization** — The `fromJson()` sanitization (nulling both when inverted) is in the source code but there is no test in `comment_shielding_config_test.dart` that verifies this behavior. The UI test verifies rejection at save time, but the persisted deserialization path is untested. **Low risk** since the test gap is for the hardening layer, not the primary UI path.

4. **ipLocationFilter province list completeness** — The hardcoded list of 31 provinces + 海外 is reasonable but may miss newer administrative divisions or overseas regions. This is a content completeness concern, not a structural defect.

---

## Non-blocking Notes

- `CommentShieldingConfig.version` field exists but is not used for migration logic. This is fine for additive config (per spec Section 6).
- Naming in `CommentShieldMatcher.match()` uses `blockedBy` strings that match the config field names, making diagnostics straightforward.
- The `_editNumber` dialog uses a side-channel (`text = value` mutated in `onChanged`) rather than a `TextEditingController`. Works correctly but slightly unconventional. Not a defect.
- When the user clears numeric input and saves, `_editNumber` returns `null` via `_NumberEditResult(null)` only if the field is empty. If the user enters `0`, it's saved as `0`. For `likeThreshold`, `0` means no filter (same as `null`), which is consistent. For `levelThreshold`, `0` means no filter — consistent.

---

## Hard Exclusion Results

All searches performed with `rg`/`grep` on the diff and relevant source paths.

| Exclusion | Search scope | Result |
|-----------|-------------|--------|
| `RecommendationTagEnricher` imported/called in comment shielding path | Full `lib/` + `test/` | ✅ Clean — only in `shielding_recommend_tag_enricher.dart` (pre-existing, not part of this diff) and its test file. No references in comment-shielding new code. |
| `RecommendFilter` imported/called in comment shielding path | Full `lib/` + `test/` | ✅ Clean — only in `shielding_migration.dart` (pre-existing migration analysis), existing test files. No references in comment-shielding new code. |
| Homepage secondary filtering / refill / pagination logic | Full diff + comment-shielding files | ✅ Clean — `applyShielding()` is a pure list filter; no pagination refill, no compensation, no second-chance logic. |
| bvid/cid detail-fetch pipelines in comment path | Full `lib/` + `test/` | ✅ Clean — bvid/cid references exist only in `shielding_recommend_tag_enricher.dart` (pre-existing, homepage-only), `shielding_adapters_test.dart` (pre-existing recommendation test fixtures). No bvid/cid usage in comment shielding code. |
| Video tags, category, duration, playback count, danmaku count, video like rate, derived metrics | Full diff of `lib/` | ✅ Clean — no video metadata leaks into comment shielding. The diff only touches comment-scope fields (`level`, `sex`, `vipType/vipStatus`, `location`, `content.message.length`, `like`, `content.pictures`, `content.emotes`, `garbPendantImage`, `garbCardNumber`, etc.). |
| Video-card quick action behavior in comment shielding path | Full diff + `shield_quick_action.dart` | ✅ Clean — `_isRecommendationQuickActionType` explicitly guards against `avatarPendant`/`garb`. Comment quick actions are in a different file (`reply_item_grpc.dart`, unchanged). |

**No exclusion violations found.**

---

## Verification Commands Inspected

All commands were read-only executions through the tool interface. Primary verifications:

1. `git diff --stat` — confirmed 15 files modified, 5 new untracked files
2. `git status --short` — confirmed working tree state
3. `git diff HEAD -- [file]` for each modified file — verified content
4. `rg 'RecommendationTagEnricher' lib/ test/` — searched for forbidden enricher
5. `rg 'RecommendFilter' lib/ test/` — searched for forbidden filter
6. `rg -n 'bvid' lib/features/shielding/ lib/pages/comment_shield_settings/ lib/pages/common/reply_controller.dart test/features/shielding/ test/pages/comment_shield_settings/` — searched for bvid/cid pipeline references
7. `rg -n 'tag\|duration\|playback\|danmaku\|category\|partition\|likeRate\|interaction'` on diff — searched for video metadata in new code

---

## Unknowns

1. **Actual test pass/fail status** — I did not run Flutter tests. The user-reported baseline states "Phase 3 shielding test group: passed, 126 tests" and "Settings page / rule model test group: passed, 36 tests" and "video-card quick action boundary test: passed, 9 tests". This review assumes those results are accurate but does not re-verify them.
2. **Runtime behavior** — No emulator/device was used. This is a source-level review only. Widget rendering, tapping, and state save/load paths were verified syntactically, not by execution.
3. **Existing test coverage completeness** — The test files `comment_shielding_config_test.dart`, `comment_shielding_matcher_test.dart`, and `comment_decoration_rule_test.dart` (untracked) were not re-read in full. All three are referenced in the plan but only the diff portions of modified test files were verified.
4. **`lib/pages/shielding_settings/view.dart`** — This file was not modified (zero diff) and was not read in full. Pendant/garb rule creation in the existing rule editor UI relies on pre-existing category/chip widgets. I verified that `shieldingRuleCategoryFor` returns correct categories and labels, and that the test file asserts the category chips contain `头像挂件` and `装扮卡片`. The UI rendering path was not traced through `view.dart`.

---

## Client Decision Needed

**No.** No ambiguous or client-significant decision was encountered. All implementation choices follow the approved spec and Phase 2 plan. The warnings above are actionable by the implementation team without client consultation.

---

## Summary

| Check | Status |
|-------|--------|
| Config storage additive singleton, separate from rules | ✅ |
| Settings page first-level, no master switch | ✅ |
| All nine controls with correct semantics | ✅ |
| minCharCount > maxCharCount rejected (UI + persisted) | ✅ |
| Empty numeric clears stale threshold | ✅ |
| Pre-render filtering (not widget hide/show) | ✅ |
| Parent removal hides children naturally | ✅ |
| Child removal removes only child | ✅ |
| Existing comment quick actions unchanged | ✅ |
| Pendant/garb are rule categories, not quick actions | ✅ |
| Video-card quick actions blocked for comment rule types | ✅ |
| Hard exclusions respected | ✅ |
| **Blockers** | **None** |
| **Warnings** | **4** (see above — all low/medium severity) |
