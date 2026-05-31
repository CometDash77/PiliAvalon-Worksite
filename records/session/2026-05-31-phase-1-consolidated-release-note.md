# Phase 1 Consolidated Release Note

Date: 2026-05-31

## Release State

Status: prebuild available for user retest; not green.

This note consolidates Phase 1 shielding changes and evidence requirements
across prior per-prebuild notes and the current acceptance-fixes worktree. It is
not a stable release note until technical-lead review and user/manual
acceptance evidence are filled in.

## Target

- Repository: `CometDash77/PiliAvalon-Worksite`
- Current local branch: `phase-1-shielding-acceptance-fixes`
- Reviewed branch HEAD:
  `eda5bee71c2a1f0a0d15187d7104b7bda7a5a915`
- Integration branch: `phase-1-shielding-core`
- Final commit SHA: `eda5bee71c2a1f0a0d15187d7104b7bda7a5a915`
- Final tag: `phase-1-prebuild.26707279023`
- Release URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/phase-1-prebuild.26707279023
- CI run URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/26707276542
- Build run URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/26707279023
- Runtime smoke URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/26707550380

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

- Fresh CI on the exact final ref: Reasonix-monitored and Codex-reviewed for
  run `26707276542`.
- Fresh Android build artifact for the final ref: Reasonix-monitored and
  Codex-reviewed for run `26707279023`.
- Fresh Android runtime smoke on the final APK/ref: Reasonix-monitored and
  Codex-reviewed for run `26707550380`.
- Screenshots, UI evidence, and logcat evidence from runtime smoke are in
  smoke evidence artifact `7315187616`.
- If merged into `phase-1-shielding-core`, fresh CI and smoke are required
  again on the merged core ref.
- Technical-lead review result.
- User/manual acceptance result or explicit deferral.

## Known Open Items

- Remote automation on `phase-1-shielding-acceptance-fixes` was monitored by
  Reasonix and reviewed by Codex with restrictions.
- Technical-lead review is pending.
- User/manual acceptance is pending.
- Phase 1 remains yellow.

## User Retest Package

- Retest handoff:
  `records/session/2026-05-31-phase-1-user-retest-handoff.md`
- Recommended physical-device APK for most Android phones:
  `PiliAvalon_android_2.0.7-eda5bee71+5041_arm64-v8a.apk`
- Release URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/phase-1-prebuild.26707279023

## Rollback Plan

If final CI, runtime smoke, review, or user acceptance fails:

- Do not mark Phase 1 green, accepted, stable, latest, or complete.
- Preserve the failed run/package as evidence.
- Do not repurpose the failed package as pass evidence.
- Fix forward or revert only the identified final fix range, then rerun fresh
  local verification, CI, runtime smoke, review, and acceptance.
