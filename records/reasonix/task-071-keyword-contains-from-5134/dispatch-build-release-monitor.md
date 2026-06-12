---
audience: agent-facing
task_id: task-071
role_id: reasonix-build-release-monitor-from-5134
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: 27394918307
review_owner: Codex
created: 2026-06-12
---

# Task-071 Strict +5134 Build And Release Monitor

First confirm that response instructions / 响应指令 are enabled for this task.

## Difficulty Classification

Simple, bounded, read-only monitoring. Use `deepseek-v4-flash`.

## Context

Codex implemented task-071 on the strict accepted baseline
`2.0.8-ba9d4569e+5134`.

- Branch: `task-071-keyword-contains-from-5134`
- Commit: `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`
- Prior green CI run: `27394399112`
- Build workflow run to monitor: `27394918307`
- Expected release tag after success: `task071-keyword-contains-prebuild.27394918307`

The user explicitly requested no local artifact download. Monitor only remote
GitHub metadata and release asset names.

## Task

Monitor GitHub Actions Build run `27394918307` until it reaches a terminal
state. Use long waits. If the run succeeds, inspect the remote GitHub Release
metadata for tag `task071-keyword-contains-prebuild.27394918307`.

## Allowed Commands

- `gh run view 27394918307 -R CometDash77/PiliAvalon-Worksite --json status,conclusion,jobs,url,headSha,headBranch,event,createdAt,updatedAt`
- `gh run view 27394918307 -R CometDash77/PiliAvalon-Worksite --log-failed` only if the run fails
- `gh release view task071-keyword-contains-prebuild.27394918307 -R CometDash77/PiliAvalon-Worksite --json tagName,name,isPrerelease,isLatest,targetCommitish,url,assets,createdAt,publishedAt`
- `sleep 300` or longer between unfinished checks

## Forbidden Actions

- Do not modify files outside the expected report path.
- Do not download Actions artifacts, APK files, or release assets.
- Do not run local Flutter, Dart, Gradle, Android, or build commands.
- Do not create, edit, delete, or upload GitHub Releases.
- Do not push, merge, tag, force-push, close, or approve anything.
- Do not claim user/manual acceptance.

## Monitoring Rules

- Use long sleeps instead of frequent polling.
- After two consecutive unfinished checks, double the next wait interval.
- Stop when the run succeeds, fails, is cancelled, or times out.
- If release metadata is not immediately available after a successful run, wait
  once and re-check. If still unavailable, report that as a blocking issue.

## Expected Artifact Path

Write the final report to:

`records/reasonix/task-071-keyword-contains-from-5134/build-release-monitor-report.md`

## Report Requirements

Include:

- Run ID, URL, branch, commit, status, conclusion.
- Job names and conclusions.
- If failed, the relevant failed log summary.
- If succeeded, release tag, URL, prerelease/latest flags, target commitish, and
  remote asset names.
- Explicit confirmation that no local artifact download was performed.
- Blocking issues, if any.

## Limits

- `max_iterations`: 10
- `max_time_minutes`: 90
- `usd_cap`: 0.25
- `review_owner`: Codex
