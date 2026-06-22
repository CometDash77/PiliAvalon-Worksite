---
audience: agent-facing
record_type: codex-baseline
task: task-066
stage: github-only-plus5169-baseline
status: baseline-observed-not-final-gate
created: 2026-06-20
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
baseline_commit: 465952d9c0f64b708dec08dbc6c94e236773ad31
baseline_version_code: 5169
baseline_release: v2.0.10-task066-task074-candidate
baseline_build_run: 27833501793
---

# GitHub-Only +5169 Baseline

User instruction for the continuation: downloads, compilation, and tests must
all use GitHub. Local Flutter tests/builds and local APK downloads are not to
be used as proof for the new prerelease path.

Observed GitHub baseline:

- Branch: `task-066-detail-intro-shielding`
- Commit: `465952d9c0f64b708dec08dbc6c94e236773ad31`
- Local commit count / APK versionCode baseline: `5169`
- GitHub Build run: `27833501793`
- Build conclusion: `success`
- Existing prerelease: `v2.0.10-task066-task074-candidate`
- Existing prerelease state: non-draft prerelease
- Existing APK names all include `2.0.8-465952d9c+5169`

The next prerelease must be a fresh GitHub-produced prerelease. GitHub Actions
and GitHub API metadata are the allowed test/build/download evidence surfaces.
