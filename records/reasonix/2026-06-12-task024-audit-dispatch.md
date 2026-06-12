---
audience: agent-facing
role_id: reasonix-task024-core-audit
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-071-keyword-contains-from-5134
expected_artifact_path: records/reasonix/2026-06-12-task024-core-audit.md
review_owner: Codex
created: 2026-06-12
task_difficulty: hard-cross-cutting
model_strategy: deepseek-pro
---

# Reasonix Dispatch - Task-024 Core Audit

First confirm that response instructions / 响应指令 are enabled for this task.

Use the project skill `.reasonix/skills/worksite-reasonix-harness.md`.
Because this is Flutter/Dart work, also use `.reasonix/skills/flutter-official-skill-router.md`
and read the official skills `.agents/skills/dart-add-unit-test/SKILL.md`,
`.agents/skills/dart-run-static-analysis/SKILL.md`, and
`.agents/skills/flutter-add-widget-test/SKILL.md` before acting.

## Limits

- `allowed_commands`: read-only file inspection commands only (`pwd`, `git status --short`,
  `git branch --show-current`, `rg`, `find`, `sed`, `nl`, `cat`, `git diff --stat`,
  `git diff --`, `git ls-files`). You may write only the expected artifact path.
- `forbidden_actions`: no code edits, no format, no tests, no analyze, no pub/flutter dependency
  resolution, no network, no push, no merge, no release, no tag, no governance changes.
- `max_iterations`: 1
- `max_time_minutes`: 20
- `usd_cap`: 0.50

## Source Inputs

Read these Design Institute inputs:

- `/home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/specs/2026-06-12-task023-expanded-shielding-formal-spec.md`
- `/home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/2026-06-12-task024-expanded-shielding-core-handoff.md`

## Audit Scope

Map the current code needed for task-024 only:

- shielding model enums and JSON serialization compatibility;
- `ShieldCandidate` fields and current adapters;
- `ShieldMatcher` semantics and allow-over-block behavior;
- quick action creation flow and current hard-coded scope;
- settings labels/categories/scope display/mode visibility;
- existing tests that should be extended.

Respect explicit non-scope:

- Do not plan or implement task-025 production scene wiring.
- Do not migrate `RecommendFilter`.
- Do not merge `DanmakuBlockPage` / `RuleFilter`.
- Do not add second-batch rule types.
- Do not remove token compatibility.

## Required Artifact

Write `records/reasonix/2026-06-12-task024-core-audit.md` with:

- audience class near the top;
- files inspected;
- current behavior summary;
- concrete edit plan grouped by file;
- focused test plan with exact existing/new test files;
- compatibility risks;
- explicit forbidden-work boundary confirmation.

Remember: output is candidate evidence only. Codex remains the reviewer and final coordinator.
