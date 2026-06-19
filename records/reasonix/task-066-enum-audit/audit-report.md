# task-066 ShieldRuleType enum audit

Date: 2026-06-19
Branch: task-066-detail-intro-shielding
Auditor: Codex
Base inspected commit: e38b2254871cc14022cdedb2d50ff4e60f25949a
User version note: latest available build/version is +5162

## Scope

Audited the current task-066 branch for `ShieldRuleType` switch coverage after
the enum was expanded to 17 values:

- keyword
- userKeyword
- reasonKeyword
- uid
- category
- tag
- avatarPendant
- garb
- duration
- playbackCount
- danmakuCount
- commentMemberSex
- commentMemberLevel
- descriptionKeyword
- publishTime
- isUpowerExclusive
- staffKeyword

## Findings

No remaining `ShieldRuleType` exhaustiveness gap was found on the current
task-066 branch.

Production-risk switches from the handoff:

| File | Switch/function | Current task-066 status |
| --- | --- | --- |
| `lib/common/widgets/video_card/shield_quick_action.dart` | `_ruleLabel` | Covers all 17 enum values explicitly. |
| `lib/common/widgets/video_card/shield_quick_action.dart` | `_isRecommendationQuickActionType` | Method is absent on current task-066 branch; `rg` found no symbol or caller. |
| `lib/features/shielding/shielding_matcher.dart` | `_valuesForRule` switch | Covers all 17 values explicitly. Text/enum values yield candidate fields; numeric fields return. |
| `lib/pages/setting/models/shielding_settings.dart` | `shieldRuleTypeLabel` | Covers all 17 enum values explicitly. |
| `lib/pages/setting/models/shielding_settings.dart` | `shieldingRuleCategoryFor` switch | Covers all 17 enum values explicitly; task-066 values map to `视频详情信息`. |

Additional related switches checked:

| File | Switch/function | Status |
| --- | --- | --- |
| `lib/features/shielding/shielding_matcher.dart` | `_matchNumbers` | Includes `publishTime`; wildcard intentionally maps non-numeric rule types to `null`. |
| `lib/features/shielding/shielding_store.dart` | `_defaultMatchMode` | Includes task-066 semantic defaults: description/staff `contains`, publish time `range`, upower `enumValue`; wildcard remains intentional for exact-match types. |
| `lib/pages/shielding_settings/view.dart` | `_defaultEditorMode`, `_modeFitsType` | Includes task-066 values. |
| `lib/pages/setting/models/recommend_settings.dart` | `_rangeTypeLabel` | Intentionally limited to the three recommendation range setting entries. |

## Code fixes made

While validating, `flutter analyze` exposed a real compile error in
`test/features/shielding/comment_quick_action_decoration_test.dart`: the test
still passed `shieldSettingsStore` into `ReplyItemGrpc`, but the widget no
longer accepted that parameter.

Fix:

- Restored optional `ReplyItemGrpc.shieldSettingsStore`.
- Threaded it into main/sub-reply quick-action menus.
- Used it in comment quick-action rule writes, falling back to the global
  `ShieldSettingsStore()` for production behavior.

The remaining analyzer issues were info-level lints that still made
`flutter analyze` exit non-zero locally. These were fixed mechanically:

- Renamed local helper functions in `recommend_settings.dart`.
- Converted simple lambdas to tearoffs and replaced deprecated dropdown
  `value` with `initialValue` in `recommend_range_shielding.dart`.
- Added `const` to task-066 candidate tests.
- Removed one unnecessary `async`.
- Enlarged two widget-test surfaces so tests can see the full horizontal chip
  row and full dropdown item set.

## Conclusion

The task-066 branch currently has complete `ShieldRuleType` switch coverage for
the 17-value enum. The remaining failures found during validation were not
enum exhaustiveness gaps; they were a stale test injection parameter and lint /
widget-test visibility issues. Those were fixed and verified.
