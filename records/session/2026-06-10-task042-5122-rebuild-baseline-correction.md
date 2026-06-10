# Task-042 5122 Baseline Rebuild Correction

Audience classification: agent-facing

## Purpose

Record the baseline correction for Task-042 repeat-exposure work and prevent reuse of the wrong prerelease package.

## Correct Baseline

- Correct latest accepted baseline release: `issue-8-player-controls-fix-build.27188216292`
- Correct baseline commit: `aef06bd7ed94a67dffa45dbee484f6ef46339df5`
- Correct baseline APK/version family: `2.0.8-aef06bd7e+5122`
- Correct rebuild branch: `task-042-repeat-exposure-prefilter-from-5122`

Only the `+5122` baseline is valid for this rebuild. Do not develop Task-042 from `production`, `bf9f78b4b`, or the old `task-044-repeat-exposure-prefilter` wrong-base branch.

## Wrong Prerelease Removed

The prerelease below was wrong because it was built from the old wrong-base Task-042 branch instead of the accepted `+5122` baseline:

- Wrong prerelease tag: `task042-repeat-exposure-prebuild.27260059861`
- Wrong prerelease version family: `2.0.8-ea07ad4d2+5129`
- Wrong build run: `27260059861`
- Wrong head SHA: `ea07ad4d2609266ba3707d0104242bd40176405a`

Deletion completed on 2026-06-10 with explicit repository scoping:

```bash
gh release delete task042-repeat-exposure-prebuild.27260059861 -R CometDash77/PiliAvalon-Worksite --cleanup-tag --yes
```

Post-deletion release inspection showed `issue-8-player-controls-fix-build.27188216292` as the newest release entry. The wrong prerelease must not be used for manual acceptance, evidence, release notes, or parent task closure.

## Rebuild Action

The Task-042 repeat-exposure implementation commits were cherry-picked onto the correct `aef06bd7e` baseline. The wrong-base prerelease/evidence commits were intentionally excluded:

- Excluded: `ea07ad4d2` (`Record Task 044 verification evidence`)
- Excluded: `ad4624a44` (`Record Task 042 prerelease evidence`)

The workflow trigger was moved to `task-042-repeat-exposure-prefilter-from-5122` so GitHub verification runs against the corrected branch.

## Current Gate Status

- Wrong prerelease cleanup: complete.
- Correct 5122 rebuild branch: prepared.
- GitHub focused verification: pending after push.
- Android build prerelease: not yet created.
- Runtime smoke: pending after a new correct build.
- Manual acceptance: pending and must use a future `+5122`-based package, not the deleted `+5129` package.

## Rollback / Recovery

If the corrected branch proves bad, abandon `task-042-repeat-exposure-prefilter-from-5122` and restart from `aef06bd7ed94a67dffa45dbee484f6ef46339df5`. Do not restore `task042-repeat-exposure-prebuild.27260059861` or use its APKs as acceptance evidence.
