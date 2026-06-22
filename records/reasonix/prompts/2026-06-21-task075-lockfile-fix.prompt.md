First confirm that response instructions / 响应指令 are enabled for this task.
audience: agent-facing
task_id: task-075
role_id: task-075-lockfile-fix-worker
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-075-upstream-stable-merge at fffe7fcab760083cd14ac8bdbf83a868f47d05e5
difficulty_classification: medium; narrow dependency-lock repair, but release-sensitive because it gates CI and prerelease evidence
model_strategy: deepseek-v4-pro because this is release-sensitive even though the file scope is narrow
expected_artifact_path: records/reasonix/task-075/lockfile-fix-report.md
review_owner: Codex
max_iterations: 1
max_time_minutes: 30
usd_cap: 2.00

# Dispatch

You are DeepSeek Reasonix acting as a bounded dependency-lock repair worker.
Codex remains coordinator, reviewer, final gate owner, and release owner.
Use YOLO/edit-auto-free behavior for the allowed file edits and allowed
commands in this slice so approval prompts do not stall the task.

Before acting, invoke the project Flutter/Dart routing guidance for dependency
work: read `.reasonix/skills/flutter-official-skill-router.md` if present and
then the relevant official skill file for package conflict or dependency
resolution guidance. Also honor AGENTS.md and this dispatch prompt.

## Goal

Repair the Task-075 dependency lock mismatch that made GitHub Actions runs
`27890267219` and `27890305038` fail at `Verify dependency lock is clean`.

Current known failure cause: `flutter pub get` updates `pubspec.lock`,
including `file_picker` from `12.0.0-beta.6` to `12.0.0-beta.7` and a changed
resolved-ref. Sync the branch lockfile to the result produced by
`flutter pub get` for the committed `pubspec.yaml`.

## Required repository and branch

- Work only in `/home/mo/Documents/piliavalon/.worktrees/task075-real-merge`.
- Target repo: `CometDash77/PiliAvalon-Worksite`.
- Target branch: `task-075-upstream-stable-merge`.
- Expected starting HEAD: `fffe7fcab760083cd14ac8bdbf83a868f47d05e5`.
- If the branch, repo, or HEAD do not match, stop and write a blocker report.

## Allowed commands

- `git status --short --branch`
- `git rev-parse HEAD`
- `git diff -- pubspec.yaml pubspec.lock`
- `git diff --stat`
- `flutter pub get`
- `dart pub get`
- `git add pubspec.lock records/reasonix/task-075/lockfile-fix-report.md records/reasonix/prompts/2026-06-21-task075-lockfile-fix.prompt.md`
- `git commit -m "Regenerate lockfile for Task-075 upstream merge"`
- `git push origin task-075-upstream-stable-merge`
- `gh run view 27890305038 -R CometDash77/PiliAvalon-Worksite --log`
- `gh run view 27890267219 -R CometDash77/PiliAvalon-Worksite --log`

You may use read-only file inspection commands such as `sed`, `rg`, and `cat`.

## Fallback if local Flutter/Dart is unavailable

If local `flutter`/`dart` is unavailable, do not give up immediately. Use the
GitHub Actions log from run `27890305038` first, then `27890267219` if needed,
to recover the exact `pubspec.lock` diff produced after `flutter pub get`.
Apply only that lockfile diff. Do not edit `pubspec.yaml` unless the log proves
`flutter pub get` changed it, and explain the evidence.

## Forbidden actions

- Do not publish, create, edit, or delete GitHub Releases.
- Do not dispatch GitHub Actions.
- Do not merge to `main`.
- Do not push any branch except `origin/task-075-upstream-stable-merge`.
- Do not force-push.
- Do not modify workflow files, source files, design-institute files, or
  unrelated records.
- Do not claim CI green, build green, runtime smoke green, prerelease accepted,
  stable accepted, or user acceptance.

## Required output artifact

Write `records/reasonix/task-075/lockfile-fix-report.md` with:

- audience class: `agent-facing`
- role_id, target repo, branch, starting SHA, ending SHA
- exact commands run and exit outcomes
- whether `flutter pub get` was local or reconstructed from GitHub logs
- concise summary of `pubspec.lock` changes, including package names and
  resolved-ref/version changes
- commit SHA if committed
- push outcome
- explicit non-claims: candidate evidence only, Codex review required, no CI
  green, no prerelease, no stable, no manual acceptance

Then commit `pubspec.lock`, the report, and this prompt file with:

`Regenerate lockfile for Task-075 upstream merge`

Push to:

`origin/task-075-upstream-stable-merge`
