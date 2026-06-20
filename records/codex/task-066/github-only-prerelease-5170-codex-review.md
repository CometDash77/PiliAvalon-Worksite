---
audience: agent-facing
record_type: codex-review
task: task-066
stage: github-only-prerelease-5170
status: reviewed-github-only-automation-green
created: 2026-06-20
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
reviewed_artifact: records/reasonix/task-066/2026-06-20-github-only-prerelease-monitor.md
baseline_release: v2.0.10-task066-task074-candidate
baseline_commit: 465952d9c0f64b708dec08dbc6c94e236773ad31
baseline_version_code: 5169
release_commit: 12ba24aa292e33369779fd2880cc959d2d8fa818
release_version_code: 5170
new_prerelease: task066-plus5169-github-only.27868385432
ci_run: 27868372344
build_run: 27868385432
release_smoke_run: 27868701836
---

# Task-066 GitHub-Only Prerelease +5170 Codex Review

Codex reviewed the Reasonix candidate monitor report and independently checked
GitHub Actions and GitHub Release metadata. No local Flutter build/test and no
local APK download was used as evidence for this gate.

## Decision

The GitHub-only automated prerelease gate is accepted as green for the new
Android prerelease:

- Prerelease: `task066-plus5169-github-only.27868385432`
- Release URL:
  `https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task066-plus5169-github-only.27868385432`
- Target commit: `12ba24aa292e33369779fd2880cc959d2d8fa818`
- APK version emitted by workflow: `2.0.8-12ba24aa2+5170`

This does not claim formal release promotion, merge completion, or human/user
acceptance. It proves the requested GitHub-only test/build/prerelease path was
completed and verified.

## GitHub Evidence

| Evidence | Result |
| --- | --- |
| Baseline prerelease `v2.0.10-task066-task074-candidate` | Non-draft prerelease, target commit `465952d9c...`, APKs include `+5169` |
| New CI run `27868372344` | `completed / success`, head SHA `12ba24aa...` |
| New Build run `27868385432` | `completed / success`, head SHA `12ba24aa...` |
| New prerelease `task066-plus5169-github-only.27868385432` | Non-draft prerelease, target commit `12ba24aa...`, 3 Android APK assets |
| Release APK runtime smoke `27868701836` | `completed / success`, installed/launched APK from Build run `27868385432` in GitHub |

## APK Assets

| APK | Size | Digest |
| --- | ---: | --- |
| `PiliAvalon_android_2.0.8-12ba24aa2+5170_arm64-v8a.apk` | 25,957,159 | `sha256:8e5a58da3e2f4ae699223e6c4716dfd61f1fb2b666b428f35f0cc26d922e83cf` |
| `PiliAvalon_android_2.0.8-12ba24aa2+5170_armeabi-v7a.apk` | 25,879,295 | `sha256:ac77375f4ad5569b5cfd572165b821cc293979b7585e07d032d98fa029abafd6` |
| `PiliAvalon_android_2.0.8-12ba24aa2+5170_x86_64.apk` | 26,948,050 | `sha256:9f2b6b0b067e6ddfa2e98a94af757c5dbbd17cd5bf25f2ae179b30a5956bc9d2` |

Release body signing fingerprint for all three APKs:

`0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

This matches the +5169 baseline prerelease fingerprint recorded by GitHub
release metadata.

## Review Notes

- The new prerelease commit `12ba24aa` is +5170 because it records the +5169
  GitHub-only baseline. The product code diff from +5169 to `12ba24aa` is
  records-only.
- A later coordination-only prompt commit, `9eba1236c`, was pushed after the
  prerelease was created. It is not part of the APK. This does not invalidate
  the prerelease evidence, but the APK target remains `12ba24aa`.
- Reasonix output is citable for factual monitoring after this Codex review,
  with the caveat that Reasonix cannot close acceptance gates.

## Non-Claims

This review does not claim:

- formal production release
- merge completion
- physical-device acceptance
- user/client acceptance
- non-Android platform coverage
