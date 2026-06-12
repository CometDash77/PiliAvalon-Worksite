---
audience: agent-facing
role_id: reasonix-task024-ci-monitor-rerun
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: 27402927654
expected_artifact_path: records/reasonix/2026-06-12-task024-ci-monitor-rerun.md
review_owner: Codex
created: 2026-06-12
task_difficulty: simple-bounded-monitoring
model_strategy: deepseek-flash
---

# Reasonix Dispatch - Task-024 GitHub CI Monitor Rerun

First confirm that response instructions / 响应指令 are enabled for this task.

Use `.reasonix/skills/worksite-reasonix-harness.md`.

## Limits

- `allowed_commands`: `gh run view -R CometDash77/PiliAvalon-Worksite 27402927654`,
  `gh run watch -R CometDash77/PiliAvalon-Worksite 27402927654`,
  `gh run view -R CometDash77/PiliAvalon-Worksite 27402927654 --json status,conclusion,workflowName,headBranch,headSha,url,createdAt,updatedAt,jobs`,
  and read/write only the expected artifact path.
- `forbidden_actions`: no code edits, no commits, no pushes, no reruns, no workflow changes,
  no releases, no tags, no merge/PR action, no local Flutter/Dart tests.
- `max_iterations`: 1
- `max_time_minutes`: 60
- `usd_cap`: 0.25

## Monitor Target

- Repository: `CometDash77/PiliAvalon-Worksite`
- Workflow: `PiliAvalon CI`
- Run ID: `27402927654`
- Branch: `task-071-keyword-contains-from-5134`
- Commit: `5bfa4545f`

## Required Behavior

Monitor with long waits, not frequent polling. Stop when the run reaches a terminal
state (`success`, `failure`, `cancelled`, `timed_out`, or `skipped`).

## Required Artifact

Write `records/reasonix/2026-06-12-task024-ci-monitor-rerun.md` with:

- audience class near the top;
- run id, branch, commit, workflow name, URL;
- final status and conclusion;
- job list with conclusions;
- failed job names and key failure summary if any;
- explicit note that no local Flutter/Dart verification was used.

Reasonix output is candidate evidence only. Codex remains reviewer and final gate owner.
