# Comment Shielding Bug Handling Process Record

Date: 2026-06-14
Audience: Design Institute
Owner: Codex
Repo: `CometDash77/PiliAvalon-Worksite`

## Purpose

Record the process used to recover from the wrong-baseline prerelease during
the comment-shielding work, so future release design avoids repeating the same
failure mode.

## What Went Wrong

The comment-shielding prerelease path was initially verified against the current
comment-gate branch state, but it did not prove that the prior Task065 homepage
numeric/range shielding baseline had survived. The first successful verification
therefore had a hidden baseline gap: comment shielding was present, but the
Task065 shielding capabilities were not fully represented in the release
candidate.

The critical mistake was treating "current feature gates are green" as enough
without independently comparing against the historical baseline that the release
was supposed to preserve.

## Detection

Codex wrote `records/codex/review/2026-06-14-task065-baseline-audit.md` after
comparing current `HEAD` against tag
`task065-app-stat-fix-prebuild.27460023543`.

That audit identified missing Task065 capability surfaces, including:

- homepage numeric/range shielding settings entry;
- task065 range/numeric rule semantics in shielding core and matcher behavior;
- recommendation range settings page and route additions;
- task065 quick-action scope changes.

Reasonix was useful for bounded verification labor, but the decisive baseline
judgment came from the Codex audit and source comparison.

## Recovery Actions

1. Treated the earlier prerelease as wrong-baseline evidence, not releasable
   evidence.
2. Deleted the obsolete wrong-baseline prerelease/tag. Current direct lookup of
   `comment-shielding-comment-gate-prebuild.27496941191` returns release not
   found, and its tag ref returns 404.
3. Merged Task065 shielding baseline work into the comment-gate branch.
4. Produced commit `f96a0e1d7b5dfc99a263c7478ebd9b3e69a020e5`
   (`Merge Task065 shielding baseline into comment gate work`).
5. Published the replacement prerelease
   `task065-comment-gate-prebuild.27497810462` from commit `f96a0e1d7`.

## Final Verified State

- Local branch: `production`
- Local `HEAD`: `f96a0e1d7b5dfc99a263c7478ebd9b3e69a020e5`
- Remote release:
  `https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-comment-gate-prebuild.27497810462`
- GitHub Actions run:
  `https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27497810462`
- Run conclusion: `success`
- Release assets:
  - `PiliAvalon_android_2.0.8-f96a0e1d7+5162_arm64-v8a.apk`
  - `PiliAvalon_android_2.0.8-f96a0e1d7+5162_armeabi-v7a.apk`
  - `PiliAvalon_android_2.0.8-f96a0e1d7+5162_x86_64.apk`

## Evidence Boundaries

Reasonix artifacts from this episode are useful as support material only:

- `records/reasonix/verifier/2026-06-14-comment-shielding-dirty-tree-verification.md`
- `records/reasonix/verifier/2026-06-14-comment-shielding-prerelease-final-audit.md`

They do not independently close release readiness, runtime smoke, or client
acceptance. Codex review and current GitHub/release evidence are required for
those claims.

## Lesson

For feature work layered on top of a prior baseline, the release gate must prove
both:

1. the new feature works; and
2. the inherited baseline still exists.

Only proving the first condition can produce a clean-looking but wrong release.
