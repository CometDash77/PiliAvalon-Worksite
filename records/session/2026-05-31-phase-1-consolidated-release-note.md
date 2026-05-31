# Phase 1 Consolidated Release Note

Date: 2026-05-31

## Release State

Status: draft, not released, not green.

This note consolidates Phase 1 shielding changes and evidence requirements
across prior per-prebuild notes and the current acceptance-fixes worktree. It is
not a stable release note until final commit, CI, runtime smoke, technical-lead
review, and user/manual acceptance evidence are filled in.

## Target

- Repository: `CometDash77/PiliAvalon-Worksite`
- Current local branch: `phase-1-shielding-acceptance-fixes`
- Current local HEAD before dirty changes:
  `ce5f6915dac362a824857f7eee228f49b364d177`
- Integration branch: `phase-1-shielding-core`
- Final commit SHA: `<PENDING_FINAL_COMMIT>`
- Final tag: `<PENDING_FINAL_TAG>`
- Release URL: `<PENDING_RELEASE_URL>`
- CI run URL: `<PENDING_FRESH_CI_URL>`
- Runtime smoke URL: `<PENDING_FRESH_RUNTIME_SMOKE_URL>`

## Superseded Or Historical Evidence

The following records remain historical context only:

- `phase-1-prebuild.26678247652`: failed/manual acceptance problem history.
- `phase-1-prebuild.26679987266`: invalid tag/package mismatch history.
- `phase-1-prebuild.26680259984`: prior per-prebuild evidence, before the
  acceptance-fixes branch.
- Runtime smoke and CI runs on older `phase-1-shielding-core` refs.

Do not reuse old failures or old smoke evidence as pass evidence for the final
acceptance-fixes package.

## Consolidated Change Summary

- Phase 1 shielding rules cover recommendation and comment workflows with
  explicit rule type, match mode, scope, action, source, and updated timestamp.
- Quick actions preserve existing recommendation card actions while adding
  shielding entries for title, user, recommendation reason, tags/categories,
  related videos, and comments.
- Recommendation/ranking paths route through Phase 1 recommendation shielding,
  including all-blocked pagination behavior.
- Comment reply lookup keeps target resolution against the unfiltered data list
  before display filtering.
- Legacy `RecommendFilter` compatibility remains bounded by Phase 1 global and
  recommendation switches.
- Settings page presents categorized sections for global switches, legacy
  compatibility, recommendation rules, comment rules, user/UP rules, and tag
  rules.
- Shielding store cache behavior is instance-scoped and malformed payloads fall
  back to disabled shielding instead of stale rules.
- Migration analyzer tests now initialize temporary storage before reading
  legacy `RecommendFilter` statics.

## Required Final Verification

Fresh local verification already run for the current dirty worktree:

```powershell
flutter test test/features/shielding
flutter test test/pages/setting/models/shielding_settings_test.dart
flutter analyze --no-fatal-infos
git diff --check
```

Local results:

- Shielding tests: 53/53 passed.
- Settings model/widget tests: 7/7 passed.
- Analyze: exit 0 with 52 info-level issues.
- Diff check: exit 0; only CRLF conversion warnings were printed.

Required CI and runtime evidence:

- Fresh CI on the exact final ref.
- If merged into `phase-1-shielding-core`, fresh CI on the merged core ref.
- Fresh Android build artifact for the final ref.
- Fresh Android runtime smoke on the final APK/ref.
- Screenshots, UI evidence, and logcat evidence from the runtime smoke.
- Technical-lead review result.
- User/manual acceptance result or explicit deferral.

## Known Open Items

- No remote `phase-1-shielding-acceptance-fixes` branch exists yet.
- No CI run exists for `phase-1-shielding-acceptance-fixes`.
- Runtime smoke is missing for the final fix set.
- Technical-lead review is pending.
- User/manual acceptance is pending.
- Phase 1 remains yellow.

## Rollback Plan

If final CI, runtime smoke, review, or user acceptance fails:

- Do not mark Phase 1 green, accepted, stable, latest, or complete.
- Preserve the failed run/package as evidence.
- Do not repurpose the failed package as pass evidence.
- Fix forward or revert only the identified final fix range, then rerun fresh
  local verification, CI, runtime smoke, review, and acceptance.
