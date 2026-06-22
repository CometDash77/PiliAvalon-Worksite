---
audience: agent-facing
record_type: reasonix-dispatch-prompt
task: task-066
stage: source-verification
status: superseded-by-fresh-worksite-source-verification-v2
created: 2026-06-17
review_owner: Codex
---

# Reasonix Prompt: Task-066 Source Verification

Superseded by
`records/reasonix/prompts/2026-06-17-task066-worksite-source-verification-v2.prompt.md`
after the user clarified that earlier read-only verification remains candidate
evidence only and fresh worksite source verification must happen first.

```text
First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-066-source-verifier
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: current worksite branch unless Codex provides a replacement task-066 branch
review_owner: Codex
difficulty_classification: hard, governance-sensitive, prerelease-sensitive source verification
model_strategy: deepseek-v4-pro
max_iterations: 1
max_time_minutes: 35
usd_cap: 1.00
expected_artifact_path: records/reasonix/task-066/source-verification-report.md

Use YOLO/edit-auto-free behavior for allowed read-only commands and for writing
only the expected artifact path. Do not wait for approval prompts inside the
bounded slice. Use long waits only if a command is genuinely long-running.

You are DeepSeek Reasonix acting as a candidate source verifier. Codex remains
the reviewer/coordinator and final gate owner. Your output is candidate evidence
only until Codex reviews the persisted artifact.

Before acting, read the project Flutter/Dart routing guidance:
- .reasonix/skills/flutter-official-skill-router.md if present
- then the relevant official skills it routes to for static analysis and tests

Allowed commands:
- pwd
- git status --short --branch
- git rev-parse HEAD
- git rev-list --count HEAD
- git log --oneline --decorate -n 20
- rg
- sed -n ...
- ls
- find records -maxdepth ...

Forbidden actions:
- Do not spawn or dispatch another Reasonix process; you are the worker.
- Do not create coordination notes or dispatch records.
- Do not edit product source.
- Do not run builds or tests in this source-verification slice.
- Do not push, merge, tag, release, delete releases, delete tags, or force-push.
- Do not modify governance policy, workflows, release state, or design-institute files.
- Do not claim task-066 is green, accepted, or releasable.
- Do not treat unpersisted chat output as evidence.

Verification scope:
1. Verify whether current worksite source already contains task-066 behavior.
2. Identify exact source paths for:
   - ShieldCandidate / ShieldRuleSet / ShieldMatcher
   - recommendation adapter and related-video adapter
   - list-filter pipeline
   - old RecommendFilter.applyFilterToRelatedVideos setting/storage
   - video detail introduction metadata model/controller/view surfaces
   - related-video list loading/filtering surfaces
   - settings model tests and shielding adapter tests
3. Verify that task-066 means detail-page introduction metadata used for
   recommendation shielding, not hiding or disabling the current detail page.
4. Verify the requested first-batch fields:
   - introduction/description text
   - publish time
   - staff/creative team
   - Upower/charging-exclusive state
   - already approved stable introduction metadata
5. Verify exclusions:
   - no dimension
   - no aspect ratio
   - no portrait/landscape orientation
   - no task-074 derived metrics
6. Verify related-video boundary:
   - must use shared ShieldMatcher / ShieldRuleSet / list-filter pipeline
   - must not directly reuse homepage fromRecommendationJson adapter
   - must add an independent related-video shielding switch
   - must not reuse or reinterpret RecommendFilter.applyFilterToRelatedVideos
7. Verify current branch, HEAD SHA, derived versionCode, and what is required to
   reach exactly +5162.

Write records/reasonix/task-066/source-verification-report.md in English with:
- audience: agent-facing
- source-verification status
- commands run
- current branch / commit / derived versionCode
- source fact table with file paths and cited line summaries
- current task-066 implementation status: absent, partial, or present
- risks and blockers
- recommended atomic implementation slices
- explicit statement that this is candidate evidence for Codex review only
```
