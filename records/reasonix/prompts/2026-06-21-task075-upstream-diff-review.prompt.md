---
audience: agent-facing
type: reasonix-dispatch-prompt
task_id: task-075
role_id: task-075-upstream-diff-reviewer
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-075 pre-merge diff review from +5175 baseline to upstream/main
model_strategy: deepseek-pro
difficulty_classification: hard, cross-cutting, governance-sensitive, release-sensitive upstream merge
expected_artifact_path: records/reasonix/task-075/upstream-diff-review.md
review_owner: Codex
created: "2026-06-21"
---

First confirm that response instructions / 响应指令 are enabled for this task.

You are DeepSeek Reasonix acting as a candidate reviewer for Task-075. Codex is
the review owner and final gate owner.

## Required Metadata

- role_id: `task-075-upstream-diff-reviewer`
- target_repo: `CometDash77/PiliAvalon-Worksite`
- target_branch_or_run: `task-075 pre-merge diff review from +5175 baseline to upstream/main`
- allowed_commands:
  - `git status --short --branch`
  - `git rev-parse 981869d336bd19d977879594f176ac536a25ccd5 upstream/main`
  - `git merge-base 981869d336bd19d977879594f176ac536a25ccd5 upstream/main`
  - `git diff --name-status 981869d336bd19d977879594f176ac536a25ccd5...upstream/main`
  - `git diff --stat 981869d336bd19d977879594f176ac536a25ccd5...upstream/main`
  - `git diff --name-only 981869d336bd19d977879594f176ac536a25ccd5...upstream/main`
  - read-only `sed`, `rg`, `git show`, and `git diff` for files named in the report
- forbidden_actions:
  - no product code edits
  - no git branch changes
  - no git merge, rebase, cherry-pick, reset, clean, stash, tag, commit, push, or release
  - no workflow dispatch
  - no stable/release/candidate acceptance claims
  - no user/manual acceptance claims
  - no modification of governance policy
- expected_artifact_path: `records/reasonix/task-075/upstream-diff-review.md`
- max_iterations: 1
- max_time_minutes: 20
- usd_cap: 1.00
- review_owner: `Codex`

## Task Difficulty Classification

Hard, cross-cutting, governance-sensitive, and release-sensitive. Use the
pro-capability model strategy. This is an upstream merge planning review across
feed, video detail, player, live, settings/storage, build/release, and accepted
Phase 2 behavior.

## Inputs

Read this Worksite upstream diff report:

- `records/session/2026-06-21-task075-upstream-diff-report.md`

Use it as the primary input. You may inspect the named diffs read-only if it
helps identify risky auto-merges.

## Review Questions

Identify:

1. likely conflict areas;
2. risky auto-merges, especially high-risk overlapping files;
3. accepted Phase 2 behaviors that may regress;
4. focused automated tests or manual checks that should be required;
5. release risks, including build, versioning, APK, workflow, and rollback risks;
6. any gaps or mistakes in the Worksite diff report.

## Output Contract

Write exactly one candidate artifact to:

- `records/reasonix/task-075/upstream-diff-review.md`

The artifact must be in English and include:

- audience class: `agent-facing`
- evidence status: candidate evidence only
- role_id and target repo
- exact baseline and upstream commits reviewed
- concise findings table with severity, file/area, risk, and recommended Worksite response
- required verification checklist
- explicit non-claims: no green, no merge approval, no release approval, no manual acceptance

Do not edit any other file. Do not claim final acceptance. Codex will review
and accept/reject/amend each finding.
