## Purpose

Remote Android prebuild for user validation of task-071 keyword matching semantics on the strict accepted `2.0.8-ba9d4569e+5134` baseline. This is not a stable release.

## Release Type

`prebuild`

## Branch / Commit / Tag

- Branch: `task-071-keyword-contains-from-5134`
- Commit: `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`
- Baseline: `task042-5122-prebuild.27263751328` / `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
- Tag: `task071-keyword-contains-prebuild.27394918307`

## Related PRs / Issues

- Task: `task-071`
- No PR was opened for this validation branch.

## Automation Evidence

- CI: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27394399112 (`success`)
- Build/release: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27394918307 (`success`)

## Manual Acceptance

`pass`

The user reported receipt/acceptance in the work session on 2026-06-12. This does not promote the build to stable.

## Changes

- Added explicit `ShieldMatchMode.contains`.
- Migrated old `keyword + exact` and `reasonKeyword + exact` persisted rules to `contains`.
- Kept `uid`, `category`, `tag`, and `userKeyword` exact rules as exact.
- Changed `exact` to case-insensitive equality.
- Defined `contains` as case-insensitive literal substring.
- Preserved `regex`, `token`, and `allow` over `block` behavior.
- Updated UI defaults and labels so migrated keyword rules show contains wording.
- Hid deprecated `token` mode from normal new-rule creation.

## Known Risks

- Android-only prebuild.
- Existing keyword-style exact persisted rules intentionally migrate to explicit `contains`.
- Stable release approval remains separate.

## Sources / License / Attribution

No new external code, assets, or third-party libraries were copied. This build reuses existing project code and release infrastructure.

## Rollback Plan

Use prior accepted prebuild `task042-5122-prebuild.27263751328`, or revert branch `task-071-keyword-contains-from-5134` back to baseline commit `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`.

## Not Covered / Still Yellow

- Stable release approval is not covered.
- Cross-platform assets were not produced.
- This evidence does not modify Design Institute canonical kanban state.

## User Action Required

No additional action is required for this prebuild acceptance record.
