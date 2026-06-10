# Task-042 5122 Build And Runtime Smoke Codex Review

Audience classification: agent-facing

## Scope

Codex review of the GitHub Android build prerelease and Android runtime smoke evidence for the corrected Task-042 `+5122` rebuild.

## Reviewed Artifacts

- Reasonix build monitor: `records/reasonix/task-042/2026-06-10-task042-5122-android-build-monitor.md`
- Reasonix runtime smoke monitor: `records/reasonix/task-042/2026-06-10-task042-5122-runtime-smoke-monitor.md`
- Release notes: `records/session/2026-06-10-task042-5122-prebuild-release-notes.md`

## Baseline Check

- Correct baseline release: `issue-8-player-controls-fix-build.27188216292`
- Correct baseline commit: `aef06bd7ed94a67dffa45dbee484f6ef46339df5`
- Correct baseline APK/version family: `2.0.8-aef06bd7e+5122`
- Build branch: `task-042-repeat-exposure-prefilter-from-5122`
- Build head: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`

Codex confirmed the prerelease target commit is `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`, whose history is built on `aef06bd7ed94a67dffa45dbee484f6ef46339df5`. The deleted wrong prerelease `task042-repeat-exposure-prebuild.27260059861` is not used.

## Independent Codex Verification

Codex independently checked GitHub Actions and release state with explicit repository scoping:

```bash
gh run view 27263751328 -R CometDash77/PiliAvalon-Worksite --json conclusion,status,displayTitle,headBranch,headSha,url,event,createdAt,updatedAt
gh release view task042-5122-prebuild.27263751328 -R CometDash77/PiliAvalon-Worksite
gh run view 27264338846 -R CometDash77/PiliAvalon-Worksite --json conclusion,status,displayTitle,headBranch,headSha,url,event,createdAt,updatedAt
gh run view --job=80517613830 -R CometDash77/PiliAvalon-Worksite
gh run view --job=80517613830 -R CometDash77/PiliAvalon-Worksite --log | rg -n "status=|result=|task042-5122|2\\.0\\.8-ba9d4569e\\+5134|Status: ok|android-runtime-smoke-evidence"
```

Observed Android build result:

- Run ID: `27263751328`
- URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27263751328
- Branch: `task-042-repeat-exposure-prefilter-from-5122`
- Head SHA: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
- Conclusion: `success`
- Android job: `Release Android`
- Prerelease tag: `task042-5122-prebuild.27263751328`
- Release URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task042-5122-prebuild.27263751328

Observed APK assets:

- `PiliAvalon_android_2.0.8-ba9d4569e+5134_arm64-v8a.apk`
- `PiliAvalon_android_2.0.8-ba9d4569e+5134_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.8-ba9d4569e+5134_x86_64.apk`

Observed runtime smoke result:

- Run ID: `27264338846`
- URL: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27264338846
- Artifact source run: `27263751328`
- Branch: `task-042-repeat-exposure-prefilter-from-5122`
- Head SHA: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
- Conclusion: `success`
- Job ID: `80517613830`
- Downloaded APK: `PiliAvalon_android_2.0.8-ba9d4569e+5134_x86_64.apk`
- Scenario: `task042-5122-repeat-exposure-prebuild`
- Launch result: three `Status: ok` entries.
- Smoke result: `status=0`, `result=pass`
- Evidence artifact: `android-runtime-smoke-evidence`, artifact ID `7530849559`

## Review Decision

Accepted. The Reasonix build and runtime-smoke reports match Codex direct GitHub inspection. Android build/prerelease and runtime smoke are green for the corrected `+5122` rebuild package `task042-5122-prebuild.27263751328`.

## Boundaries

This review only accepts automation evidence for the corrected prerelease package. It does not close:

- Manual acceptance.
- Technical-lead review.
- Stable/latest release approval.
- Parent Task-042 closure.

The deleted wrong prerelease `task042-repeat-exposure-prebuild.27260059861` and its `2.0.8-ea07ad4d2+5129` APKs remain invalid for acceptance evidence.
