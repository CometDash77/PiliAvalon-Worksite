# Task-042 Wrong Baseline Retrospective Seed

Audience classification: agent-facing

## Purpose

Preserve the fact that Task-042 repeat-exposure work was initially developed and prereleased from the wrong baseline, so Phase 2 closure can include a retrospective and future agents do not repeat the mistake after cleanup deletes the obsolete branch.

## What Went Wrong

An agent built the first Task-042 repeat-exposure implementation on the old `task-044-repeat-exposure-prefilter` branch / wrong-base line instead of the accepted `+5122` baseline.

Wrong-base identifiers:

- Wrong development branch: `task-044-repeat-exposure-prefilter`
- Wrong prerelease tag: `task042-repeat-exposure-prebuild.27260059861`
- Wrong prerelease head: `ea07ad4d2609266ba3707d0104242bd40176405a`
- Wrong prerelease version family: `2.0.8-ea07ad4d2+5129`
- Wrong build run: `27260059861`

The issue was not the repeat-exposure feature logic itself; the issue was the merge/base choice. The feature code had to be replanted onto the correct accepted baseline.

## Correct Baseline

The only valid Task-042 rebuild baseline is:

- Baseline release: `issue-8-player-controls-fix-build.27188216292`
- Baseline commit: `aef06bd7ed94a67dffa45dbee484f6ef46339df5`
- Baseline APK/version family: `2.0.8-aef06bd7e+5122`

Corrected Task-042 branch and package:

- Correct rebuild branch: `task-042-repeat-exposure-prefilter-from-5122`
- Correct prerelease tag: `task042-5122-prebuild.27263751328`
- Correct prerelease version: `2.0.8-ba9d4569e+5134`
- Correct build run: `27263751328`
- Correct runtime smoke run: `27264338846`

## Cleanup Already Performed

- The wrong prerelease `task042-repeat-exposure-prebuild.27260059861` was deleted with `--cleanup-tag`.
- The corrected `task042-5122-prebuild.27263751328` prerelease passed focused verification, Android build, runtime smoke, and user manual acceptance.
- This record must remain after deleting obsolete branches, so the mistake is still visible in `production` history.

## Rule For Future Agents

For Task-042 or follow-up work, do not resurrect or branch from:

- `task-044-repeat-exposure-prefilter`
- `ea07ad4d2609266ba3707d0104242bd40176405a`
- `task042-repeat-exposure-prebuild.27260059861`
- any `2.0.8-ea07ad4d2+5129` APK

Start from `production` after the corrected merge, or from `aef06bd7ed94a67dffa45dbee484f6ef46339df5` if a fresh rebuild is explicitly required.

## Phase 2 Retrospective Prompt

At Phase 2 closure, review why the agent selected the wrong baseline despite the accepted `+5122` package existing. The retrospective should cover:

- whether branch naming caused confusion between Task-042 and Task-044;
- whether release evidence was trusted without checking ancestry against `aef06bd7e`;
- whether prerelease cleanup happened too late;
- whether future release plans should require an explicit `git merge-base --is-ancestor <accepted-baseline> HEAD` check before any build dispatch;
- whether release tags should include the accepted baseline marker, as `task042-5122-prebuild.27263751328` now does.
