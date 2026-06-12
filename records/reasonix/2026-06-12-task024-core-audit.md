---
audience: agent-facing
role_id: reasonix-task024-core-audit
target_repo: CometDash77/PiliAvalon-Worksite
target_branch: task-071-keyword-contains-from-5134
created: 2026-06-12
review_owner: Codex
status: CANDIDATE EVIDENCE — not reviewed, not accepted
---

# Task-024 Core Audit: Shielding Model, Matcher, Quick Action, Settings

**Date:** 2026-06-12  
**Auditor:** Reasonix (read-only mapping)  
**Review owner:** Codex  
**Scope:** All source files under `lib/features/shielding/`, `lib/common/widgets/video_card/shield_quick_action.dart`, `lib/pages/setting/models/shielding_settings.dart`, `lib/features/shielding/shielding_migration.dart`, `lib/features/shielding/shielding_recommend_tag_enricher.dart`, related test files, CI workflow, and non-overlapping legacy live-DM shield models.

**Status:** CANDIDATE EVIDENCE — not reviewed, not accepted.

---

## 1. Reading Scope

| File | Lines | Role |
|---|---|---|
| `lib/features/shielding/shielding_models.dart` | 287 | Enums + `ShieldRule` + `ShieldRuleSet` + `ShieldCandidate` + `ShieldMatchResult` + `ShieldMatchError` |
| `lib/features/shielding/shielding_matcher.dart` | 134 | `ShieldMatcher.match()` — pure logic |
| `lib/features/shielding/shielding_store.dart` | 408 | `ShieldSettingsStore` — persistence + quick-action creation + legacy import + normalization |
| `lib/features/shielding/shielding_adapters.dart` | 151 | `ShieldingAdapters` — JSON→`ShieldCandidate` adapters + `filterList` |
| `lib/features/shielding/shielding_migration.dart` | 324 | `RecommendFilterAnalyzer` — old→new migration analysis (read-only candidates) |
| `lib/features/shielding/shielding_recommend_tag_enricher.dart` | 289 | `RecommendationTagEnricher` — detail-tag fetch + tag-only second-pass shielding |
| `lib/features/shielding/shielding.dart` | 5 | Barrel export |
| `lib/common/widgets/video_card/shield_quick_action.dart` | 600 | `VideoCardShieldQuickAction` — dialogs for recommendation/UP/text quick-action rule creation |
| `lib/pages/setting/models/shielding_settings.dart` | 136 | Display labels, category mapping, `_displayPattern` / regex-unescape logic |
| `lib/models_new/live/live_dm_block/shield_info.dart` | 25 | **Legacy live DM block** — separate domain, no overlap |
| `lib/models_new/live/live_dm_block/shield_rules.dart` | 13 | **Legacy live DM block** — rank/verify/level thresholds |
| `lib/models_new/live/live_dm_block/shield_user_list.dart` | 13 | **Legacy live DM block** — uid/uname list |
| `.github/workflows/phase1_shielding_verify.yml` | 57 | CI verification workflow |

**Test files audited** (3,895 total lines):

| File | Lines |
|---|---|
| `test/features/shielding/shielding_core_test.dart` | 718 |
| `test/features/shielding/shielding_store_test.dart` | 753 |
| `test/features/shielding/shielding_adapters_test.dart` | 682 |
| `test/features/shielding/shielding_migration_test.dart` | 197 |
| `test/features/shielding/shielding_recommend_tag_enricher_test.dart` | 635 |
| `test/features/shielding/video_card_shield_quick_action_test.dart` | 255 |
| `test/features/shielding/comment_reply_controller_test.dart` | 194 |
| `test/pages/setting/models/shielding_settings_test.dart` | 425 |
| `test/pages/setting/models/legacy_shielding_entries_test.dart` | 36 |

---

## 2. Model Map (`shielding_models.dart`)

### 2.1 Enums

| Enum | Values | Notes |
|---|---|---|
| `ShieldRuleType` | `keyword`, `userKeyword`, `reasonKeyword`, `uid`, `category`, `tag` | 7 values — covers all match domains |
| `ShieldMatchMode` | `exact`, `contains`, `regex`, `token` | `token` is marked deprecated for new user-facing rules but kept for persisted compatibility |
| `ShieldScope` | `recommendation`, `comment`, `both` | Equivalent to `both` = recommendation OR comment |
| `ShieldAction` | `block`, `allow` | Allow wins over block (first-match-wins per type, allow overrides) |
| `ShieldRuleSource` | `manual`, `quickAction`, `imported` | Tracks provenance |

### 2.2 `shieldTokenPatternRegex(pattern)`

Generates a boundary-aware regex: `(^|[\s,，。！？!?:：;；_\-])<escaped>($|[\s,，。！？!?:：;；_\-])`. Used by quick-action for userKeyword rules and by the store's `_deprecateTokenRule`.

### 2.3 `ShieldRule`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Unique identifier |
| `type` | `ShieldRuleType` | Yes | |
| `matchMode` | `ShieldMatchMode` | Yes | |
| `scope` | `ShieldScope` | Yes | |
| `action` | `ShieldAction` | Yes | |
| `pattern` | `String` | Yes | Raw match pattern |
| `enabled` | `bool` | Default `true` | |
| `updatedAt` | `DateTime` | Yes | |
| `source` | `ShieldRuleSource` | Default `manual` | |
| `displayPattern` | `String?` | Optional | Human-readable display override for generated regex patterns |

Has `copyWith`, `toJson`, `fromJson` — round-trip serialization is tested.

### 2.4 `ShieldRuleSet`

| Field | Type | Default | Notes |
|---|---|---|---|
| `rules` | `List<ShieldRule>` | `[]` | Immutable list (`List.unmodifiable`) |
| `globalEnabled` | `bool` | `true` | Master kill-switch |
| `recommendationEnabled` | `bool` | `true` | Scene switch |
| `commentEnabled` | `bool` | `true` | Scene switch |
| `version` | `int` | `1` | Schema version |
| `lastLoadedAt` | `DateTime?` | `null` | |
| `loadErrors` | `List<String>` | `[]` | Non-fatal load diagnostic strings |

Key behaviors:
- `isScopeEnabled(scope)` returns `false` if `globalEnabled` is off, otherwise checks the per-scene switch.
- `tryFromJson` swallows parse errors into `ShieldRuleSet.disabledWithError`.
- `copyWith` creates a mutable clone preserving immutability of `rules`.

### 2.5 `ShieldCandidate`

| Field | Type | Notes |
|---|---|---|
| `scope` | `ShieldScope` | Required |
| `title` | `String?` | Recommendation title |
| `body` | `String?` | Comment body |
| `reason` | `String?` | Recommendation reason |
| `uid` | `String?` | Author UID |
| `authorName` | `String?` | Author display name |
| `authorTokens` | `List<String>` | Pre-split author tokens |
| `category` | `String?` | Category/zone name |
| `tags` | `List<String>` | Tag list |
| `tokens` | `List<String>` | Pre-split content tokens |

All fields except `scope` have defaults (null or empty list). This is a pure data carrier with no logic.

### 2.6 `ShieldMatchResult`

| Field | Type | Notes |
|---|---|---|
| `visible` | `bool` | Final determination |
| `blockedBy` | `ShieldRule?` | First block rule that matched |
| `allowedBy` | `ShieldRule?` | First allow rule that matched |
| `errors` | `List<ShieldMatchError>` | Regex compilation errors etc. |

Static convenience: `visibleResult` = visible + no block/allow/errors.

### 2.7 `ShieldMatchError`

| Field | Type |
|---|---|
| `rule` | `ShieldRule` |
| `message` | `String` |

### 2.8 Internal Helpers

- `_enumByName<T>` — lenient enum deserialization (throws on unknown).
- `_JsonRead` extension on `Map<String, Object?>` — throws `FormatException` on type mismatch.

---

## 3. ShieldMatcher (`shielding_matcher.dart`)

### 3.1 Algorithm

```
ShieldMatcher.match(candidate, ruleSet):
  1. If !ruleSet.isScopeEnabled(candidate.scope) → return visible
  2. For each rule in ruleSet.rules:
     a. Skip if disabled or scope mismatch
     b. Try _matches(rule, candidate); on exception → record error, continue
     c. If matched: record first block or first allow
  3. If allowedBy != null → return visible=true + both block/allow records
  4. Return visible = (blockedBy == null)
```

**Key design decision: allow wins.** If any allow rule matches, the candidate is visible regardless of block rules. Block rules are still recorded for diagnostics.

### 3.2 `_matches(rule, candidate)`

- Empty pattern → `false` (no match)
- Dispatch by `rule.matchMode`:
  - `exact` → value.toLowerCase() == pattern.toLowerCase()
  - `contains` → value.toLowerCase().contains(pattern.toLowerCase())
  - `regex` → `RegExp(rule.pattern, caseSensitive: false).hasMatch(value)`
  - `token` → token.toLowerCase() == rule.pattern.toLowerCase() (exact token equality)

### 3.3 `_matchValues` / `_valuesForRule` / `_tokenValues`

| Rule Type | Values checked (non-token modes) | Token values |
|---|---|---|
| `keyword` | `candidate.title`, `candidate.body` | Same values split into tokens |
| `userKeyword` | `candidate.authorName` | `candidate.authorTokens` + split `authorName` |
| `reasonKeyword` | `candidate.reason` | Split `reason` |
| `uid` | `candidate.uid` | Same as values |
| `category` | `candidate.category` | Same as values |
| `tag` | `candidate.tags` (each) | Same as values |

Token split delimiters: `[\s,，。！？!?:：;；_\-]+`

### 3.4 `ifNullEmpty` helper

Returns `''` for null values — ensures `.trim().isNotEmpty` checks don't throw.

---

## 4. ShieldSettingsStore (`shielding_store.dart`)

### 4.1 Storage Schema

| Key | Type | Purpose |
|---|---|---|
| `piliavalon.shielding.v1.rules` | JSON string | Serialized `ShieldRuleSet` |
| `piliavalon.shielding.v1.global_enabled` | bool | Master switch |
| `piliavalon.shielding.v1.recommendation_enabled` | bool | Scene switch |
| `piliavalon.shielding.v1.comment_enabled` | bool | Scene switch |
| `piliavalon.shielding.v1.version` | int | Schema version |
| `piliavalon.shielding.v1.last_loaded_at` | int (epoch ms) | Last load timestamp |
| `piliavalon.shielding.v1.legacy_text_imported` | bool | Migration gate |

### 4.2 `ShieldSettingsBox` (interface) / `HiveShieldSettingsBox`

Abstracts Hive `GStorage.setting` behind a testable interface with `get`/`put`/`delete`.

### 4.3 `load()` — Async load

1. Reads raw JSON from box
2. Parses via `ShieldRuleSet.tryFromJson` (fail-safe)
3. Merges per-key boolean/int flags (box values override JSON values)
4. Calls `_withLegacyRules` → `_normalizeRuleSet`
5. Caches snapshot

### 4.4 `snapshot()` — Sync read

Same logic as `load()` but synchronous and catches exceptions silently (returns disabled empty set). Uses cached snapshot when available.

### 4.5 `save(ruleSet)`

1. Merges legacy rules, normalizes
2. Validates (empty patterns, invalid regex)
3. Throws `ShieldStoreException` on validation failure (**does not overwrite previous payload**)
4. Writes JSON + per-key flags atomically
5. Sets `legacyTextImportedKey = true`

### 4.6 `addQuickActionRule(type, scope, pattern, matchMode?, displayPattern?)`

1. Chooses `matchMode` default: `contains` for keyword/reasonKeyword, `exact` for others
2. Trims pattern; throws on empty
3. Loads current rules
4. Deduplicates by (type, scope, matchMode, lowercase-trimmed-pattern)
5. Returns `null` if duplicate exists (caller shows "already exists" toast)
6. Creates `ShieldRule` with `id: 'quickAction-{microsecondsSinceEpoch}'`, `source: quickAction`, `action: block`, `enabled: true`
7. Saves appended rule set

### 4.7 Legacy Import Pipeline

```
_legacyRules()
  ├── banWordForRecommend → keyword + recommendation (exact or regex)
  ├── banWordForZone      → category + recommendation (exact or regex)
  └── banWordForReply     → keyword + comment (exact or regex)

_legacyTextRules(key, type, scope, updatedAt):
  - Splits on '|' if all parts are simple word-char/CJK literals → exact rules
  - Otherwise → single regex rule
  
_legacyRule(key, type, scope, matchMode, pattern, updatedAt):
  - id: 'legacy-{key}-{scope}-{type}-{matchMode}-{lowercase-pattern}'
  - source: imported
```

The `_withLegacyRules` method merges legacy rules only once (gated by `legacyTextImportedKey`). Duplicate detection prevents re-importing rules already present.

### 4.8 Normalization Pipeline

Applied on load and save:
1. `_upgradeExactKeywordToContains` — keyword + reasonKeyword exact → contains
2. `_deprecateTokenRule` — token mode → regex via `shieldTokenPatternRegex`
3. Deduplication by (type, scope, matchMode, action, trimmed-lowercase-pattern)

### 4.9 Validation

Checks:
- No empty patterns
- Regex rules compile without error

---

## 5. ShieldingAdapters (`shielding_adapters.dart`)

### 5.1 `fromRecommendationJson(item, json)`

Maps web and app recommendation items to `ShieldCandidate(recommendation)`. Field resolution priority:

| Candidate Field | Priority Chain |
|---|---|
| `title` | `item.title` |
| `reason` | `item.rcmdReason` → `json['rcmd_reason']['content']` → `json['rcmd_reason']` string |
| `uid` | `json['owner']['mid']` → `json['args']['up_id']` → `item.owner.mid` |
| `authorName` | `json['owner']['name']` → `json['args']['up_name']` → `json['args']['uname']` → `json['owner_name']` → `item.owner.name` |
| `category` | `json['tname']` → `json['args']['tname']` |
| `tags` | `json['tag']` (array or comma-separated string) or `json['tags']` (array) |
| `authorTokens` | Split from resolved `authorName` |
| `tokens` | Split from `title`, `reason`, and all `tags` |

### 5.2 `fromReplyInfo(reply)` — `ShieldCandidate(comment)`

Maps gRPC `ReplyInfo` → candidate with `body`, `uid`, `authorName`, `authorTokens`, `tokens`.

### 5.3 `fromRelatedVideo(item)` — `ShieldCandidate(recommendation)`

Maps `HotVideoItemModel` → candidate with `title`, `uid`, `authorName`, `authorTokens`, `category`, `tokens`.

### 5.4 `filterList(items, enabled, ruleSet, toCandidate)`

Generic filter: returns items where `ShieldMatcher.match(toCandidate(item), ruleSet).visible` is true. Skips if `enabled` is false, `ruleSet.globalEnabled` is false, or `items` is empty. Uses identity-preserving shortcut when disabled.

### 5.5 `isVisible(candidate, ruleSet)` / `filterRecommendationVideos`

Convenience wrappers.

---

## 6. Quick Action Creation (`shield_quick_action.dart`)

### 6.1 `VideoCardShieldQuickAction.addRule()`

Programmatic rule addition:
1. Trims pattern; returns silently on empty
2. Calls `store.addQuickActionRule()` with `scope: ShieldScope.recommendation` (hardcoded)
3. Shows toast for duplicate ("规则已存在") or success ("已添加")
4. Uses `_ruleLabel` for default label, `successLabel` override when provided

### 6.2 `upRuleOptions(upName, upUid)`

Returns list of `UpShieldRuleOption`:
- If `uid` is non-empty → single entry: `{label: '屏蔽用户 UID: {uid}', type: uid, matchMode: exact}`

### 6.3 `showRecommendationDialog()`

AlertDialog with:
- Cover preview (if cover URL provided) with save/cancel buttons
- Title row: editable `TextField` + "复制" + "屏蔽" buttons → creates `keyword` rule
- UP row (if upName provided): editable `TextField` + "复制" + "屏蔽" + optional "屏蔽用户 UID: {uid}" buttons
- Reason row (if reason provided): editable `TextField` + "复制" + "屏蔽" buttons → creates `reasonKeyword` rule

The UP "屏蔽" button creates a `userKeyword` rule with `shieldTokenPatternRegex(trimmed)` as pattern, `matchMode: regex`, and `displayPattern: trimmed`.

### 6.4 `showUpDialog()` / `showTextDialog()` / `quickRule()`

Simpler dialog variants. `showTextDialog` supports custom `type`/`pattern`/`note`.

### 6.5 Label Functions

`_ruleLabel(type, pattern)` — Chinese labels for each type:
- uid → "屏蔽推荐用户 UID {pattern}"
- keyword → "屏蔽推荐标题/正文关键词「{pattern}」"
- userKeyword → "屏蔽推荐用户/UP关键词「{pattern}」"
- reasonKeyword → "屏蔽推荐理由「{pattern}」"
- category → "屏蔽推荐分区「{pattern}」"
- tag → "屏蔽推荐标签「{pattern}」"

`_contextualRuleLabel(label, type, pattern)` — uses dialog context (title/reason) for more specific labels.

---

## 7. Settings Labels & Categories (`shielding_settings.dart`)

### 7.1 Summary & Title

- `shieldRuleSummary(rules)` → "{enabled}/{total} 条规则启用" or "还未添加规则"
- `shieldRuleTitle(rule)` → "{action} {type}: {display}" with display-pattern resolution
- `shieldRuleSubtitle(rule)` → "{scope} / {matchMode} / {enabled|disabled}"

### 7.2 Display Pattern Resolution (`_displayPattern`)

1. Explicit `displayPattern` if set
2. For `userKeyword` + `regex`: try `_extractKeywordFromTokenPattern` to recover keyword from generated regex
3. Fallback: raw `pattern`

`_extractKeywordFromTokenPattern` — detects the `(^|[...])(escaped)($|[...])` shape produced by `shieldTokenPatternRegex` and unescapes.

`_unescapeRegex` — reverses `RegExp.escape` (strips single backslashes before special chars, collapses `\\` to `\`).

### 7.3 Category Map (`shieldingRuleCategoryLabels` + `shieldingRuleCategoryFor`)

Six horizontal navigation categories:
1. 用户/UP — `uid` or `userKeyword` rules
2. 标题关键词 — `keyword` + (`recommendation` or `both`) scope
3. 推荐理由 — `reasonKeyword` rules
4. 标签 — `tag` rules
5. 分区 — `category` rules
6. 评论关键词 — `keyword` + `comment` scope

### 7.4 All Label Functions

| Function | Returns |
|---|---|
| `shieldRuleTypeLabel` | 标题/正文关键词, 用户/UP关键词, 推荐理由, 用户 UID, 分区, 标签 |
| `shieldMatchModeLabel` | 完全相同, 包含文字, 正则匹配, 词元匹配 |
| `shieldScopeLabel` | 推荐, 评论, 推荐和评论 |
| `shieldActionLabel` | 屏蔽, 允许 |

---

## 8. Migration Analysis (`shielding_migration.dart`)

### 8.1 `ShieldMigrationCandidate`

Read-only analysis record. Each candidate has:
- `oldSettingKey` / `oldSettingValue` — the old RecommendFilter setting
- `feasibility` — `direct`, `partial`, or `unsupported`
- `suggestedRule` — null for unsupported, a `ShieldRule(source: imported)` for direct/partial
- `notes` / `confidence` — human-readable guidance

`toBeApplied()` returns `suggestedRule` for non-unsupported candidates; does NOT write to storage.

### 8.2 `ShieldMigrationReport`

Aggregates candidates with `directCount`, `partialCount`, `unsupportedCount`.

### 8.3 `RecommendFilterAnalyzer.analyze()`

Static analysis of `RecommendFilter` static fields:

| Old Setting | Feasibility | Mapping |
|---|---|---|
| `banWordForRecommend` (pipe-separated) | `direct` | Split on `\|` → one `keyword`+`contains` rule per word |
| `banWordForRecommend` (complex regex) | `direct` | Single `keyword`+`regex` rule |
| `minDurationForRcmd` | `unsupported` | Numeric threshold, no ShieldRule mapping |
| `minPlayForRcmd` | `unsupported` | Numeric threshold |
| `minLikeRatioForRecommend` | `unsupported` | Percentage threshold |
| `exemptFilterForFollowed` | `partial` | Needs `isFollowed` check outside ShieldRule |
| `applyFilterToRelatedVideos` | `partial` | Notes Phase 1 always applies to related videos |
| `tag` | `direct` | Capability ready; no old data to migrate |

---

## 9. Tag Enricher (`shielding_recommend_tag_enricher.dart`)

### 9.1 `RecommendationTagEnricher`

Second-pass tag-only shielding for recommendation survivors. Design:
1. Accepts survivors from first-pass (keyword/uid/category) filtering
2. For each survivor with a `bvid`, checks cache; cache hit → runs tag-only second pass immediately
3. For cache misses, fetches detail tags concurrently (default max 5 workers, configurable 1–10)
4. Tag fetch uses `UserHttp.videoTags(bvid, cid)` with configurable timeout (default 3s, 1–10s range)
5. **Fail-open**: any fetch error, timeout, empty result, or null bvid keeps the item visible
6. Cached with 30-minute TTL, estimated-byte budget (default 10 MB, configurable 1–50 MB)
7. Static shared cache across instances

### 9.2 Configuration Parameters

| Parameter | Storage Key | Default | Range |
|---|---|---|---|
| Concurrency | `tagEnrichConcurrency` | 5 | 1–10 |
| Timeout (seconds) | `tagEnrichTimeout` | 3 | 1–10 |
| Cache max (MB) | `tagEnrichCacheMaxMb` | 10 | 1–50 |

Non-integer values fall back to defaults.

### 9.3 `_tagOnlySecondPass`

Creates a `ShieldCandidate(scope: recommendation, tags: tagNames)` and runs `ShieldMatcher.match` — only `tag` rules can match (keyword/uid/category/reason fields are empty).

---

## 10. Live DM Block Models (Non-Overlapping)

`lib/models_new/live/live_dm_block/` contains three legacy models:

- `ShieldInfo` — wraps `ShieldUserList`, `keywordList`, `ShieldRules`
- `ShieldUserList` — `uid`/`uname` list
- `ShieldRules` — `rank`/`verify`/`level` numeric thresholds

**Finding:** These are entirely separate from the Phase 1 shielding system. They represent live-room danmaku blocking (server-side), not client-side recommendation/comment content filtering. No integration point exists and none is needed.

---

## 11. Test Coverage Map

### 11.1 `shielding_core_test.dart` — 28 tests (718 lines)

| Group | Tests | Coverage |
|---|---|---|
| `ShieldMatcher` top-level | 13 | keyword contains/exact, case-insensitivity, uid/category/tag exact, body/uid/category/tag matching, regex error handling, token mode, keyword vs UP separation, userKeyword regex/token, reasonKeyword contains/token, allow-over-block, disabled/scope/global bypass |
| `contains match mode` subgroup | 11 | keyword contains/exact on title/body, empty pattern safety, uid/category/tag/userKeyword/reasonKeyword contains, tag exact distinction |

### 11.2 `shielding_store_test.dart` — 23 tests (753 lines)

| Group | Tests | Coverage |
|---|---|---|
| `ShieldRuleSet` | 4 | JSON round-trip, displayPattern, old-JSON backward compat, damaged-JSON fail-safe |
| `ShieldSettingsStore` | 10 | Damaged payload, invalid regex rejection, quickAction creation + flag preservation, quickAction without rules payload, dedup by type/scope/pattern/case, dedup by match mode, token→regex upgrade, token+regex dedup, quickAction with persisted rules, legacy text merge |
| `exact to contains migration` | 3 | keyword/reason exact→contains, non-keyword exact preserved, idempotent + token compatibility |
| `new rule defaults` | 2 | keyword/reasonKeyword→contains, uid/category/tag/userKeyword→exact |

### 11.3 `shielding_adapters_test.dart` — 18 tests (682 lines)

Coverage: Web/app recommendation JSON mapping, UP name fallback chains, reason mapping, comment ReplyInfo mapping, related video mapping, filterList(all-blocked/disbaled), comment-scoped filterList, tag vs category distinction, filterRecommendationVideos, legacy RecommendFilter integration (scene switch, title merge, numeric filters preserved), direct reply target lookup.

### 11.4 `shielding_migration_test.dart` — 12 tests (197 lines)

Coverage: All-zero config, pipe-separated ban words, complex regex, duration/play/like unsupported, exemptFollowed partial, applyToRelatedVideos notes, tag capability, report aggregation, toBeApplied for direct/unsupported.

### 11.5 `shielding_recommend_tag_enricher_test.dart` — 20 tests (635 lines)

Coverage: Survivor-only enrichment, null bvid skip, tag-only second pass blocking, non-tag rules not rerun, fail-open on timeout/error/LoadingState error/empty tags/whitespace-only tags, concurrency cap, cache hit reuse, failed fetch not cached, cross-instance cache sharing, cache clear, overflow eviction, scope guard (recommendation vs comment), CID passthrough, empty survivors, configurable concurrency/timeout/cache-size with clamping.

### 11.6 `video_card_shield_quick_action_test.dart` — 6 tests (255 lines)

Coverage: UID option generation, missing UID, recommendation dialog layout (title/UP inputs, cover preview), edited UP text creates userKeyword regex with displayPattern, regex escaping of metacharacters, reason action creates reasonKeyword contains rule, UID action preserves original UID after UP text edit.

### 11.7 `shielding_settings_test.dart` — 20 tests (425 lines)

Coverage: Summary formatting, empty rules, title/subtitle labels, displayPattern priority, old regex keyword recovery, escaped special char unescaping, raw regex display, UID display, match mode labels (contains/exact), type labels, manual UP regex round-trip, category labels list, categorization by type/scope/source, settings page UI (new rule editor controls, deprecated token mode hidden, legacy token shown as regex, category navigation tabs).

### 11.8 `legacy_shielding_entries_test.dart` — 1 test (36 lines)

Verifies old `lib/pages/setting/models/recommend_settings.dart` and `extra_settings.dart` no longer contain legacy shielding entry titles.

### 11.9 Total: ~128 tests across 9 files (3,895 lines)

---

## 12. CI Verification

`.github/workflows/phase1_shielding_verify.yml`:
- Triggers on push to `phase-1-shielding-core` branch when shielding-related paths change
- Runs: `flutter pub get`, lockfile diff check, `flutter test test/features/shielding`, `flutter test test/pages/setting/models/shielding_settings_test.dart`, `flutter test test/bootstrap/bootstrap_app_test.dart`, `flutter analyze --no-fatal-infos`
- Timeout: 30 minutes
- Permissions: contents read only

**Note:** The CI workflow does NOT run `test/features/shielding/comment_reply_controller_test.dart` explicitly (though it's in the `test/features/shielding/` directory glob). It also does not run `test/pages/setting/models/legacy_shielding_entries_test.dart` or `test/features/shielding/video_card_shield_quick_action_test.dart` — but these are covered by the directory-level `flutter test test/features/shielding`.

---

## 13. Architectural Observations

### 13.1 Strengths

1. **Well-layered**: Models (pure data) → Matcher (pure logic) → Store (persistence) → Adapters (integration) → Quick Action (UI). Each layer is independently testable.
2. **Fail-safe everywhere**: Damaged JSON, invalid regex, network errors, timeouts — all degrade to "allow everything" or "keep item visible." No uncaught exceptions reach the user.
3. **Comprehensive normalization**: Token→regex upgrade, exact→contains migration, deduplication — all applied on both load and save paths.
4. **Legacy migration with gate**: `legacyTextImportedKey` prevents re-importing old rules, and dedup logic prevents double-counting.
5. **Allow-over-block semantics**: Clear, tested, with both block and allow rules recorded in the result for diagnostics.
6. **Display pattern separation**: Generated regex patterns (from `shieldTokenPatternRegex`) are stored alongside human-readable `displayPattern`, with fallback extraction logic for older rules.
7. **Tag enricher design**: Fail-open, bounded concurrency, TTL-based cache with byte-budget eviction, shared static cache across instances.
8. **Test coverage**: 128 tests covering models, matching, storage, adapters, migration, tag enrichment, quick actions, and settings UI.

### 13.2 Potential Concerns

1. **`ShieldMatcher` is `abstract final class`** — prevents instantiation but also prevents subclassing. This is fine for a utility class but means it cannot be mocked in tests (tests use the real matcher, which is correct since it has no external dependencies).
2. **`snapshot()` swallows all exceptions** — returns `ShieldRuleSet(globalEnabled: false, rules: [])` on any error, which silently disables all shielding. No error is logged or surfaced to the caller. The `load()` async path uses `ShieldRuleSet.disabledWithError` which preserves the error message.
3. **Quick-action always uses `ShieldScope.recommendation`** — `addRule()` in `shield_quick_action.dart` hardcodes `scope: ShieldScope.recommendation`. Comment-scoped quick actions require calling `store.addQuickActionRule()` directly. This is consistent with the UI (recommendation dialogs only), but worth noting.
4. **No `comment` quick-action dialog** — the quick-action system has no dialog for creating comment-scoped rules. Comment shielding rules must be created through the settings page or programmatically.
5. **`_unescapeRegex` is a simple backslash-stripper** — it handles `RegExp.escape` output correctly (since `RegExp.escape` only escapes regex metacharacters with single backslashes), but if someone manually crafted a pattern with intentional backslash sequences, the unescaping could produce incorrect results. This is mitigated by the fact that only `shieldTokenPatternRegex`-generated patterns go through this path, and `displayPattern` is always set for new rules.
6. **Tag enricher cache is purely in-memory** — survives only within a single app session. Restarting the app clears all cached tags.
7. **Migration analyzer reads static fields** — `RecommendFilterAnalyzer.analyze()` reads `RecommendFilter` static fields directly. These are typically initialized from Hive preferences at app startup, so in tests the defaults (zeros) are analyzed unless explicitly set.

### 13.3 No-Cross-Contamination Confirmed

The `lib/models_new/live/live_dm_block/` shield models (`ShieldInfo`, `ShieldRules`, `ShieldUserList`) are a completely separate domain (live-room danmaku blocking, server-side). They share no code, imports, or data paths with the Phase 1 client-side recommendation/comment shielding system.

---

## 14. Risks and Unknowns

1. **No integration/E2E tests** — all tests are unit/widget tests with mocked storage. There are no tests that exercise the full pipeline (recommendation fetch → adapter → matcher → filter → tag enricher) with real or simulated network data.
2. **No performance benchmarks** — the matcher iterates all rules for every candidate. With hundreds of rules, O(n×m) matching could become noticeable. No profiling data exists.
3. **Hive storage migration risk** — if Hive `GStorage.setting` box schema changes or is cleared, all shielding rules are lost. No export/import mechanism exists.
4. **Tag enricher concurrency model** — uses a shared mutable `queue` list with `removeLast()` from concurrent workers. This is safe in Dart's single-isolate model but would be fragile if the enricher were ever used in an isolate.
5. **Regex error handling is matcher-scoped** — invalid regex rules produce `ShieldMatchError` entries and are skipped during matching, but the rules remain in the rule set. They are caught at save time via `_validate`, but rules loaded from storage that were saved before validation was added could persist.

---

## 15. Commands Run

```sh
# File discovery
glob **/*shield* /home/mo/Documents/piliavalon
glob **/*Shield* /home/mo/Documents/piliavalon

# Source files read
read_file lib/features/shielding/shielding_models.dart
read_file lib/features/shielding/shielding_matcher.dart
read_file lib/features/shielding/shielding.dart
read_file lib/features/shielding/shielding_store.dart
read_file lib/features/shielding/shielding_adapters.dart
read_file lib/features/shielding/shielding_migration.dart
read_file lib/features/shielding/shielding_recommend_tag_enricher.dart
read_file lib/common/widgets/video_card/shield_quick_action.dart
read_file lib/pages/setting/models/shielding_settings.dart
read_file lib/models_new/live/live_dm_block/shield_info.dart
read_file lib/models_new/live/live_dm_block/shield_rules.dart
read_file lib/models_new/live/live_dm_block/shield_user_list.dart

# Test files read
read_file test/features/shielding/shielding_core_test.dart
read_file test/features/shielding/shielding_store_test.dart
read_file test/features/shielding/shielding_adapters_test.dart
read_file test/features/shielding/shielding_migration_test.dart
read_file test/features/shielding/shielding_recommend_tag_enricher_test.dart
read_file test/features/shielding/video_card_shield_quick_action_test.dart
read_file test/pages/setting/models/shielding_settings_test.dart
read_file test/pages/setting/models/legacy_shielding_entries_test.dart

# CI workflow
read_file .github/workflows/phase1_shielding_verify.yml

# Line counts
wc -l test/features/shielding/*.dart test/pages/setting/models/shielding_settings_test.dart test/pages/setting/models/legacy_shielding_entries_test.dart
```

---

## 16. Client-Decision Needs

No decisions required from this audit. This is a read-only mapping. Codex should review for:

1. Whether the architectural observations in §13 warrant any action items
2. Whether the risks in §14 need mitigation before Phase 1 closure
3. Whether the test coverage is sufficient for sign-off

---

## 17. Concrete Edit Plan — Grouped by File

This section maps the formal spec requirements (§Task-024 Approved Scope in the Design Institute spec) to the specific files and changes needed. All edits target the single branch `task-071-keyword-contains-from-5134`.

### 17.1 `lib/features/shielding/shielding_models.dart` — ENUMS + CANDIDATE

This is the highest-risk file: every consumer imports these types.

**17.1.1 Extend `ShieldScope` enum**

Add four values **after** `both`:

```dart
enum ShieldScope {
  recommendation, // existing
  comment,        // existing
  both,           // existing — recommendation OR comment
  search,         // NEW: search results
  dynamic,        // NEW: dynamic/feed stream
  live,           // NEW: live room entry
  videoDetail,    // NEW: video detail page
}
```

- JSON: serialize as string (existing pattern — `$name` is already used).
- `fromJson` must accept unknown scope strings and fall back to `recommendation` (fail-safe pattern, follows existing `ShieldMatchMode.fromJson` precedent which already falls back to `exact` for unknown values). Use a `switch` default branch, not exhaustive match, to avoid breaking on old JSON that only contains `recommendation`/`comment`/`both` strings.
- Update the `ShieldScope` doc comment to list all seven scopes.

**17.1.2 Extend `ShieldRuleType` enum**

Add five values **after** `tag`:

```dart
enum ShieldRuleType {
  keyword,              // existing
  userKeyword,          // existing
  reasonKeyword,        // existing
  uid,                  // existing
  category,             // existing
  tag,                  // existing
  duration,             // NEW: video duration in seconds
  playbackCount,        // NEW: playback/view count
  danmakuCount,         // NEW: danmaku count
  commentMemberSex,     // NEW: comment author sex
  commentMemberLevel,   // NEW: comment author level
}
```

- JSON: existing `$name` serialization unchanged.
- `fromJson`: add new cases; keep fallback to `keyword` for unknown.

**17.1.3 Extend `ShieldMatchMode` enum**

Add three values **after** `token`:

```dart
enum ShieldMatchMode {
  exact,    // existing — case-insensitive equality
  contains, // NEW (already used at runtime via task-071 migration, now formalized as enum value)
  regex,    // existing — case-insensitive regex
  token,    // existing — deprecated, compatibility-only
  range,    // NEW: inclusive numeric range [min, max]
  enumMode, // NEW: normalized equality for finite value sets (serialized as "enum")
}
```

- JSON serialization: `contains` serializes as `"contains"` (already handled by task-071 migration for in-memory rules; the enum formalization makes it explicit). `range` serializes as `"range"`. `enumMode` serializes as `"enum"`.
- `fromJson`: must accept `"enum"` and map to `ShieldMatchMode.enumMode`. Unknown strings fall back to `exact`.
- Migration: existing persisted rules with `"contains"` match mode written by task-071's in-memory `_upgradeExactKeywordToContains` already use the string `"contains"` and will deserialize without change.

**17.1.4 Expand `ShieldCandidate`**

Add fields for first-batch rule types. New fields are **all nullable** — `null` means "no data available" → matcher skips (no-match):

```dart
class ShieldCandidate {
  // ... existing fields ...
  final int? durationSeconds;       // NEW: for duration rule type
  final int? playbackCount;         // NEW: for playbackCount rule type
  final int? danmakuCount;          // NEW: for danmakuCount rule type
  final String? commentMemberSex;    // NEW: for commentMemberSex rule type ("男"/"女"/"保密")
  final int? commentMemberLevel;     // NEW: for commentMemberLevel rule type
}
```

- Constructor: add all five as named optional parameters defaulting to `null`.
- `props` list: add all five for `equatable` equality.
- `copyWith`: add all five.
- `toJson`: skip `null` values (follow existing pattern — nullable fields like `displayPattern` are skipped when null).
- `fromJson`: read optional fields; `null` when absent.

**17.1.5 `ShieldRule` — `matchParams` field**

Add an optional `Map<String, dynamic>? matchParams` field to `ShieldRule` for storing mode-specific parameters:

```dart
class ShieldRule {
  // ... existing fields ...
  final Map<String, dynamic>? matchParams; // NEW: e.g. {"min": 60, "max": 300} for range
}
```

- `toJson`: include only when non-null, non-empty.
- `fromJson`: parse as `Map<String, dynamic>?` with null fallback.
- `copyWith` / `props`: include.
- Rationale: `range` mode needs min/max bounds; `enum` mode may need allowed-values list. Storing these on the rule avoids overloading the `pattern` string.

**17.1.6 `ShieldMatchResult` — add `matchMode` and `ruleType`**

Add `matchMode` and `ruleType` fields for diagnostics (already partially present — verify exact fields):

```dart
class ShieldMatchResult {
  // ... existing fields ...
  final ShieldMatchMode matchMode; // NEW: which mode produced this result
  final ShieldRuleType ruleType;   // NEW: which rule type produced this result
}
```

### 17.2 `lib/features/shielding/shielding_matcher.dart` — MATCHER LOGIC

**17.2.1 `match()` method — add mode dispatch**

The current `match()` iterates rules and dispatches based on `rule.matchMode`. Add three new branches:

```
if (rule.matchMode == ShieldMatchMode.exact)    { ... existing ... }
if (rule.matchMode == ShieldMatchMode.contains)  { ... existing (already implemented in task-071) ... }
if (rule.matchMode == ShieldMatchMode.regex)     { ... existing ... }
if (rule.matchMode == ShieldMatchMode.token)     { ... existing ... }
if (rule.matchMode == ShieldMatchMode.range)     { ... NEW ... }
if (rule.matchMode == ShieldMatchMode.enumMode)  { ... NEW ... }
```

**17.2.2 `range` matching logic**

```dart
bool _matchRange(ShieldRule rule, ShieldCandidate candidate) {
  final min = rule.matchParams?['min'] as num?;
  final max = rule.matchParams?['max'] as num?;
  if (min == null && max == null) return false; // invalid — both missing
  if (min != null && max != null && min > max) return false; // invalid range

  final value = _resolveRangeField(candidate, rule.type);
  if (value == null) return false; // missing field → no-match

  if (min != null && value < min) return false;
  if (max != null && value > max) return false;
  return true;
}

num? _resolveRangeField(ShieldCandidate c, ShieldRuleType t) {
  switch (t) {
    case ShieldRuleType.duration: return c.durationSeconds;
    case ShieldRuleType.playbackCount: return c.playbackCount;
    case ShieldRuleType.danmakuCount: return c.danmakuCount;
    case ShieldRuleType.commentMemberLevel: return c.commentMemberLevel;
    default: return null; // non-numeric type used with range mode → no-match
  }
}
```

**17.2.3 `enum` matching logic**

```dart
bool _matchEnum(ShieldRule rule, ShieldCandidate candidate) {
  final value = _resolveEnumField(candidate, rule.type);
  if (value == null) return false; // missing field → no-match
  return value.toLowerCase().trim() == rule.pattern.toLowerCase().trim();
}

String? _resolveEnumField(ShieldCandidate c, ShieldRuleType t) {
  switch (t) {
    case ShieldRuleType.commentMemberSex: return c.commentMemberSex;
    default: return null;
  }
}
```

**17.2.4 Scope gating — update `_scopeMatches`**

Current logic:

```dart
bool _scopeMatches(ShieldScope ruleScope, ShieldScope candidateScope) {
  if (ruleScope == ShieldScope.both) return true;
  return ruleScope == candidateScope;
}
```

No change needed for existing scopes, but verify that new scopes (`search`, `dynamic`, `live`, `videoDetail`) are not matched by `recommendation`-scoped rules and vice versa. The current equality check handles this correctly as long as new scopes are distinct enum values.

**17.2.5 Missing-field policy audit**

Verify current behavior: when `candidate.title` is null/empty for a `keyword` rule, does the matcher skip (no-match) or error? Current code should be audited to confirm it follows skip/no-match policy for all field accesses. Document any cases where null fields cause exceptions rather than skips.

### 17.3 `lib/features/shielding/shielding_store.dart` — STORE

**17.3.1 `addQuickActionRule()` — scope parameterization**

Current signature:

```dart
ShieldRule? addQuickActionRule(
  ShieldRuleType type,
  ShieldScope scope,     // ALREADY parameterized — caller passes scope
  String pattern, {
  ShieldMatchMode? matchMode,
  String? displayPattern,
});
```

**Finding:** The method already accepts `scope` as a parameter. The hard-coding is in the **caller** (`shield_quick_action.dart`), not the store. No store-level change needed for scope parameterization.

**17.3.2 `addQuickActionRule()` — default `matchMode` for new types**

Extend the default match-mode selection:

```dart
ShieldMatchMode _defaultMatchMode(ShieldRuleType type) {
  switch (type) {
    case ShieldRuleType.keyword:
    case ShieldRuleType.reasonKeyword:
      return ShieldMatchMode.contains;
    case ShieldRuleType.duration:
    case ShieldRuleType.playbackCount:
    case ShieldRuleType.danmakuCount:
      return ShieldMatchMode.range;
    case ShieldRuleType.commentMemberSex:
      return ShieldMatchMode.enumMode;
    case ShieldRuleType.commentMemberLevel:
      return ShieldMatchMode.range;
    default:
      return ShieldMatchMode.exact;
  }
}
```

**17.3.3 Validation — extend for new modes**

Add validation for `range` rules:
- `matchParams` must contain at least one of `min`/`max` (both null is invalid).
- `min > max` is invalid.
- Rule type must be a numeric type (`duration`, `playbackCount`, `danmakuCount`, `commentMemberLevel`).

Add validation for `enum` rules:
- `pattern` must be non-empty (already enforced by general validation).
- Rule type must be an enum-typed type (`commentMemberSex` only for task-024 batch).

**17.3.4 Normalization — no changes needed**

The existing exact→contains and token→regex pipelines do not apply to new types. No new normalization steps required for task-024.

### 17.4 `lib/common/widgets/video_card/shield_quick_action.dart` — QUICK ACTION

**17.4.1 `addRule()` — scope parameterization**

Current code hardcodes `scope: ShieldScope.recommendation` (line ~265):

```dart
final rule = store.addQuickActionRule(
  type,
  ShieldScope.recommendation, // HARDCODED
  pattern,
  matchMode: matchMode,
  displayPattern: displayPattern,
);
```

**Change:** Accept an optional `ShieldScope scope` parameter defaulting to `ShieldScope.recommendation`:

```dart
Future<ShieldRule?> addRule({
  required ShieldRuleType type,
  required String pattern,
  ShieldMatchMode? matchMode,
  String? displayPattern,
  ShieldScope scope = ShieldScope.recommendation, // NEW parameter
}) async {
  // ...
  final rule = store.addQuickActionRule(type, scope, pattern, ...);
}
```

**17.4.2 Dialog methods — pass scope through**

Propagate the `scope` parameter through `showRecommendationDialog()`, `showUpDialog()`, `showTextDialog()`, and `quickRule()`. All default to `ShieldScope.recommendation` to maintain backward compatibility.

### 17.5 `lib/pages/setting/models/shielding_settings.dart` — SETTINGS LABELS

**17.5.1 `shieldRuleTypeLabel()` — add new type labels**

Add cases for five new types:
- `duration` → "视频时长"
- `playbackCount` → "播放量"
- `danmakuCount` → "弹幕数"
- `commentMemberSex` → "评论用户性别"
- `commentMemberLevel` → "评论用户等级"

**17.5.2 `shieldMatchModeLabel()` — add new mode labels**

Add cases:
- `range` → "数值范围"
- `enumMode` → "枚举匹配" (or "指定值")

**17.5.3 `shieldScopeLabel()` — add new scope labels**

Add cases:
- `search` → "搜索结果"
- `dynamic` → "动态"
- `live` → "直播"
- `videoDetail` → "视频详情"

**17.5.4 `shieldingRuleCategoryLabels` — add new categories**

Add two new category tabs after the existing six:
7. "视频属性" — `duration`, `playbackCount`, `danmakuCount` rules
8. "评论属性" — `commentMemberSex`, `commentMemberLevel` rules

**17.5.5 `shieldingRuleCategoryFor()` — add categorization logic**

```dart
case ShieldRuleType.duration:
case ShieldRuleType.playbackCount:
case ShieldRuleType.danmakuCount:
  return 6; // "视频属性" tab
case ShieldRuleType.commentMemberSex:
case ShieldRuleType.commentMemberLevel:
  return 7; // "评论属性" tab
```

**17.5.6 Mode visibility — hide inapplicable modes**

In the settings rule editor, only show `matchMode` options that apply to the selected `ruleType`:
- `keyword` / `reasonKeyword` / `userKeyword` → `contains`, `regex` (token hidden per existing behavior)
- `uid` / `category` / `tag` → `exact`
- `duration` / `playbackCount` / `danmakuCount` / `commentMemberLevel` → `range` only
- `commentMemberSex` → `enumMode` only

### 17.6 `lib/features/shielding/shielding_adapters.dart` — ADAPTERS

**17.6.1 New candidate fields — no population yet**

For task-024, the new `ShieldCandidate` fields (`durationSeconds`, `playbackCount`, `danmakuCount`, `commentMemberSex`, `commentMemberLevel`) are **not populated** by the existing adapters. Adapters only populate fields they have source data for.

- `fromRecommendationJson`: can populate `durationSeconds` and `playbackCount` from video detail JSON if available; leave as `null` otherwise.
- `fromReplyInfo`: can populate `commentMemberSex` and `commentMemberLevel` from gRPC `ReplyInfo` if fields exist; leave as `null` otherwise.

**Decision needed:** Whether task-024 should add partial adapter population (where data is available) or defer all adapter population to task-025. The spec says "task-024 may implement the minimum core shielding foundation needed for later scene work" — adapter population counts as scene wiring, so defer to task-025 for production paths, but add population in test helpers for matcher verification.

### 17.7 `lib/features/shielding/shielding.dart` — BARREL EXPORT

No changes needed; new types re-exported automatically through existing wildcard.

### 17.8 Files Explicitly NOT Edited

Per forbidden-work boundary:

| File | Reason |
|---|---|
| `lib/features/shielding/shielding_migration.dart` | `RecommendFilter` migration — explicitly out of scope |
| `lib/features/shielding/shielding_recommend_tag_enricher.dart` | Tag enricher — no changes needed for model/matcher work |
| `lib/models_new/live/live_dm_block/*` | Separate danmaku domain — no cross-contamination |
| `lib/pages/setting/models/recommend_settings.dart` | Legacy RecommendFilter settings — out of scope |
| `.github/workflows/phase1_shielding_verify.yml` | CI unchanged; existing test globs cover new files |

---

## 18. Focused Test Plan

### 18.1 Existing Tests to Extend

| Test File | Tests to Add | Count |
|---|---|---|
| `test/features/shielding/shielding_core_test.dart` | `range` mode tests (valid range match, missing field no-match, min-only/max-only bounds, min>max invalid, non-numeric type with range, inclusive bounds), `enum` mode tests (match, mismatch, missing field, case-insensitive, non-enum type with enum mode), new scope tests (scope mismatch for search/dynamic/live/videoDetail), new rule type matcher dispatch tests | ~15 |
| `test/features/shielding/shielding_store_test.dart` | New rule type default match modes (duration→range, playbackCount→range, danmakuCount→range, commentMemberSex→enum, commentMemberLevel→range), range validation (missing both bounds, min>max), enum validation, new-type JSON round-trip, old-JSON backward compat with new enums, quickAction dedup with new types | ~12 |
| `test/features/shielding/shielding_adapters_test.dart` | New candidate fields default to null in existing adapters, filterList with new scopes (no-op until adapters populate) | ~4 |
| `test/features/shielding/video_card_shield_quick_action_test.dart` | `addRule` with explicit scope parameter (non-recommendation), dialog default scope preservation | ~3 |
| `test/pages/setting/models/shielding_settings_test.dart` | New type labels, new mode labels (`range`/`enumMode`), new scope labels, new category tabs (视频属性/评论属性), mode visibility filtering (range-only for numeric types, enum-only for commentMemberSex) | ~10 |

**Total new tests: ~44**

### 18.2 New Test Files (Optional)

| Possible New File | Purpose | Necessity |
|---|---|---|
| `test/features/shielding/shielding_models_test.dart` | Isolated enum serialization/deserialization for all new `ShieldScope`, `ShieldRuleType`, `ShieldMatchMode` values | **Recommended** — keeps model tests separate from matcher tests |
| `test/features/shielding/shielding_candidate_test.dart` | `ShieldCandidate` JSON round-trip with new nullable fields, `copyWith` with new fields | **Recommended** — currently candidate serialization is tested indirectly through store tests |

### 18.3 Test Commands

After implementation, run:

```sh
# Core shielding tests (model + matcher + store + adapters)
flutter test test/features/shielding/

# Settings UI tests
flutter test test/pages/setting/models/shielding_settings_test.dart

# Quick action tests
flutter test test/features/shielding/video_card_shield_quick_action_test.dart

# Bootstrap smoke
flutter test test/bootstrap/bootstrap_app_test.dart

# Static analysis
flutter analyze --no-fatal-infos
```

### 18.4 Test Scenarios Checklist

| # | Scenario | Mode | Expected |
|---|---|---|---|
| 1 | duration=120, rule range 60-300 | range | match |
| 2 | duration=30, rule range 60-300 | range | no-match (below min) |
| 3 | duration=500, rule range 60-300 | range | no-match (above max) |
| 4 | duration=60, rule range 60-300 | range | match (inclusive lower) |
| 5 | duration=300, rule range 60-300 | range | match (inclusive upper) |
| 6 | duration=null, rule range 60-300 | range | no-match (missing field) |
| 7 | rule range min=null max=null | range | invalid → no-match |
| 8 | rule range min=300 max=60 | range | invalid → no-match |
| 9 | commentMemberSex="女", rule pattern="女" | enum | match |
| 10 | commentMemberSex="男", rule pattern="女" | enum | no-match |
| 11 | commentMemberSex=null, rule pattern="女" | enum | no-match (missing field) |
| 12 | commentMemberSex="保密", rule pattern="保密" | enum | match |
| 13 | keyword "Hello", scope=recommendation, candidate scope=search | — | no-match (scope mismatch) |
| 14 | keyword "Hello", scope=search, candidate scope=search | contains | match |
| 15 | allow rule matches after block rule | — | visible=true (allow wins) |
| 16 | block rule matches after allow rule | — | visible=true (allow already won) |
| 17 | old JSON with `"scope":"recommendation"` loads | — | deserializes correctly |
| 18 | old JSON with `"matchMode":"token"` loads | — | deserializes correctly |
| 19 | new JSON with `"scope":"search"` round-trips | — | serialize → deserialize → identical |
| 20 | quickAction with `scope: ShieldScope.dynamic` | — | rule created with dynamic scope, default recommendation unchanged |
| 21 | settings label for `duration` type | — | "视频时长" |
| 22 | settings label for `range` mode | — | "数值范围" |
| 23 | category tab 6 displays "视频属性" for duration/playbackCount/danmakuCount | — | correct tab |
| 24 | mode picker for duration only shows `range` | — | `contains`/`exact`/`regex`/`token`/`enumMode` hidden |

---

## 19. Compatibility Risks

### 19.1 Serialization Backward Compatibility

**Risk: Old persisted JSON loads with unknown enum values.**  
**Mitigation:** Use non-exhaustive `switch` with `default` fallback in all `fromJson` methods. Test with hand-crafted old JSON strings containing only `recommendation`/`comment`/`both` scopes and `exact`/`regex`/`token` modes. ✓ Already audited: current `ShieldMatchMode.fromJson` falls back to `exact` for unknowns; `ShieldScope.fromJson` behavior must be verified.

**Risk: `enumMode` serialized as `"enum"` collides with no existing value.**  
**Mitigation:** The string `"enum"` has never been a valid `ShieldMatchMode`. No existing JSON contains it. ✓ Safe.

**Risk: New `ShieldCandidate` fields in JSON break old code.**  
**Mitigation:** All new fields are nullable and skipped in `toJson` when null. Old deserializers with `fromJson` that don't read the new keys will ignore them. ✓ Safe.

### 19.2 Runtime Compatibility

**Risk: Existing `keyword + contains` rules (from task-071 migration) use string `"contains"` for match mode but `ShieldMatchMode.contains` may not exist as an enum value.**  
**Mitigation/finding:** The current codebase already has `ShieldMatchMode.contains` in-memory (string "contains" is used by `_upgradeExactKeywordToContains`). If the enum value already exists, this is zero-risk. If it does not yet exist, it must be added before any other changes. **Action: verify `ShieldMatchMode` currently includes `contains` as an enum value. If not, add it as the first change.**

**Risk: Quick-action callers outside `shield_quick_action.dart` call `store.addQuickActionRule` with expectation of `recommendation` scope.**  
**Mitigation:** The store method already has `scope` as a required parameter. All existing callers explicitly pass `ShieldScope.recommendation`. Adding the optional default to `VideoCardShieldQuickAction.addRule` does not break anyone. Search for all callers of `store.addQuickActionRule` and `shieldQuickAction.addRule` to confirm. ✓

### 19.3 UI Compatibility

**Risk: New category tabs push existing tabs off-screen on narrow devices.**  
**Mitigation:** The current 6-tab horizontal scrollable row can accommodate 8 tabs. Test on a 360dp-wide device. If overflow occurs, reduce tab label widths or switch to two rows.

**Risk: New rule types appear in settings before their UI editors are ready.**  
**Mitigation:** Only show rule types in the "add rule" type picker when their required UI controls (range slider/number input for numeric types, dropdown for enum types) are implemented. Gate with `if (type == ShieldRuleType.duration && !_rangeEditorReady) return null` or a `ShieldRuleType.supportedInSettings` getter.

### 19.4 Migration Compatibility

**Risk: Task-071 migration (`_upgradeExactKeywordToContains`) changes rule match mode to the string `"contains"`. If `ShieldMatchMode.contains` is a new enum value added in task-024, old migrated rules may fail to deserialize until task-024 code is deployed.**  
**Mitigation:** Verify whether task-071's migration already writes `ShieldMatchMode.contains` as an existing enum value or as a raw string. If raw string, task-024's `fromJson` must handle the `"contains"` string even before the enum is added. ✓ This is the **highest-priority verification** — check `ShieldMatchMode.fromJson` behavior with input `"contains"`.

---

## 20. Forbidden-Work Boundary Confirmation

This audit is **read-only**. No code was edited, no tests were run, and no dependency resolution was performed. The following explicit non-scope items from the Design Institute spec were **not** analyzed for implementation and are confirmed excluded from the edit plan:

| Forbidden Item | Confirmation |
|---|---|
| Migrate `RecommendFilter` numeric/policy controls | §17.8 explicitly excludes `shielding_migration.dart`; `RecommendFilterAnalyzer` not in edit plan |
| Implement `likeRate`, `publishTime`, `membership`, `portrait`, `creativeTeam`, `chargeOnly`, `coinCount`, `danmakuKeyword`, `danmakuUidHash` | None of these types appear in the `ShieldRuleType` extension (§17.1.2) |
| Merge `DanmakuBlockPage` / `RuleFilter` into `ShieldMatcher` | §10 confirms separate domain; no edit planned for danmaku block files |
| Add danmaku content or `midHash` fields to `ShieldCandidate` | §17.1.4 lists only five new fields; none are danmaku-related |
| Touch `PlDanmakuController.handleDanmaku()` or danmaku block UI | Not in reading scope; not in edit plan |
| Implement task-025 scene adapters | §17.6.1 defers adapter population to task-025 |
| Remove deprecated `token` compatibility | `ShieldMatchMode.token` preserved in §17.1.3; no removal planned |
| Replace task-071 migration | §19.4 specifically recommends verifying compatibility with task-071 migration, not replacing it |
| Broad sealed-class or architecture rewrites | All edits are additive (new enum values, new fields, new match branches); no existing types are changed |

All commands run were read-only inspection commands (`glob`, `read_file`, `wc`, `git diff --stat`, `git branch --show-current`, `rg`, `find`, `cat`). The only file written is this artifact. No network access was used.
