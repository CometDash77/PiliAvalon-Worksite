---
audience: agent-facing
review_type: codex-review
task: task-065
created: 2026-06-13
status: ready-for-github-verification
review_owner: Codex
---

# Task-065 Recommend Settings Inline Entry Review

## Scope

This review covers the user-requested settings-page entry correction for
Task-065. The change is intentionally focused on `推荐流设置` entry structure and
configuration persistence. It does not claim final user acceptance or stable
release readiness.

## User-Facing Entry Decision

The previous `推荐流范围屏蔽` second-level entry is removed from
`推荐流设置`. The Task-065 controls are now first-level settings items:

- `时长过滤`
- `播放量过滤`
- `弹幕量过滤`

Each item is a singleton user-facing configuration surface. The user does not
see or manage a multi-rule list for these three dimensions.

## Upstream Entry Hiding Decision

The upstream recommendation-filter entries are intentionally hidden from the
`推荐流设置` page UI:

- `点赞率`
- upstream `视频时长`
- upstream `播放量`

This is UI-entry hiding only. The original upstream storage keys, model factory,
and filtering/business logic are not deleted:

- `SettingBoxKey.minLikeRatioForRecommend`
- `SettingBoxKey.minDurationForRcmd`
- `SettingBoxKey.minPlayForRcmd`
- `getVideoFilterSelectModel(...)`
- `RecommendFilter.minLikeRatioForRecommend`
- `RecommendFilter.minDurationForRcmd`
- `RecommendFilter.minPlayForRcmd`

Maintainers must preserve this distinction. The user-facing Task-065 entry
replaces the settings-page operation surface, but it does not remove the
upstream business path.

## Boundary Semantics

Existing `ShieldMatchMode.range` matching is inclusive interval matching.
Therefore the inline UI persists boundary settings through existing primitive
rules:

- `屏蔽 ≤ X` is stored as pattern `..X`
- `屏蔽 ≥ Y` is stored as pattern `Y..`
- setting both thresholds stores two primitive rules, `..X` and `Y..`

This keeps one user-facing setting item per dimension while using the existing
matcher without changing shielding business logic.

## Files Reviewed / Changed

- `lib/pages/setting/models/recommend_settings.dart`
- `test/pages/setting/models/recommend_settings_test.dart`

Reasonix candidate reports reviewed:

- `records/reasonix/2026-06-13/task-065-recommend-settings-inline-entry-fix.md`
- `records/reasonix/2026-06-13/task-065-inline-entry-codex-review-fix.md`
- `records/reasonix/2026-06-13/task-065-inline-boundary-storage-fix.md`

Codex follow-up:

- Reverted unrelated `RecommendRangeShieldingPage` edits to keep scope narrow.
- Added test isolation via `ShieldSettingsStore().clear()` in setup/teardown.
- Aligned UI/test wording with inclusive matcher semantics (`≤` / `≥`).

## Verification

Local:

- `git diff --check`: pass.

Per user instruction, Dart/Flutter analyze and tests are delegated to GitHub
Actions, not local execution.

Required next verification:

- Push branch.
- Run GitHub Actions CI.
- Reasonix monitor GitHub Actions with long waits.
- Do not publish a new prerelease unless CI is green and Codex confirms the
  release gate.

## Gate Status

- Settings-page entry correction: implemented locally, pending GitHub CI.
- Business filtering correctness: partially covered by persistence mapping
  review, but still pending CI and manual acceptance.
- Manual acceptance: pending.
- Stable release: not allowed.
- Task-065 accepted: not allowed yet.
