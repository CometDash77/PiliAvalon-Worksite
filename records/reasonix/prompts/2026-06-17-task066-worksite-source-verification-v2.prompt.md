---
audience: agent-facing
record_type: reasonix-dispatch-prompt
task: task-066
stage: fresh-worksite-source-verification
status: ready-to-dispatch
created: 2026-06-17
review_owner: Codex
---

# Reasonix Prompt: Task-066 Fresh Worksite Source Verification

```text
First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-066-fresh-worksite-source-verifier
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: local branch task-066-detail-intro-shielding at f806d36d1b97e6b601372947e9a29fdaca7d68d7 plus current worktree
review_owner: Codex
difficulty_classification: hard, governance-sensitive, prerelease-sensitive source verification with dirty worktree audit
model_strategy: deepseek-v4-pro
max_iterations: 1
max_time_minutes: 40
usd_cap: 1.25
expected_artifact_path: records/reasonix/task-066/source-verification-report-v2.md

Use YOLO/edit-auto-free behavior only for allowed read-only commands and for
writing the expected artifact path. Do not wait for approval prompts inside the
bounded slice. Use long waits only if a command is genuinely long-running.

You are DeepSeek Reasonix acting as a fresh worksite source verifier. Codex
remains the Design Institute lead, reviewer, orchestrator, and final gate owner.
Your output is candidate evidence only until Codex reviews the persisted
artifact. Earlier subagent/read-only verification must be treated only as
planning input for this task.

Before acting:
- Run or confirm a current `reasonix doctor` health check if the surface allows
  it without mutating global config. If health cannot be confirmed, record that
  as a blocker in the artifact and stop after read-only local source facts.
- Read records/session/2026-06-17-task066-prerelease-worksite-handoff.md.
- Read records/codex/task-066/branch-base-decision.md.
- Read .reasonix/skills/flutter-official-skill-router.md if present, then the
  relevant official Flutter/Dart skills it routes to for static analysis and
  tests. This is source verification only; do not run Flutter tests here.

Allowed commands:
- reasonix doctor
- pwd
- git status --short --branch
- git status --porcelain=v1
- git diff -- lib/features/shielding/shielding_matcher.dart lib/features/shielding/shielding_models.dart lib/utils/storage_key.dart
- git diff --stat
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
- Do not claim task-066 is green, accepted, releasable, or ready for +5162 APK/prerelease.
- Do not treat unpersisted chat output as evidence.

Verification scope:
1. Verify the current branch, HEAD SHA, dirty files, and derived versionCode.
2. Classify each dirty file as in-scope candidate task-066 work, out-of-scope
   drift, or unknown/user-owned change requiring Codex clarification:
   - lib/features/shielding/shielding_matcher.dart
   - lib/features/shielding/shielding_models.dart
   - lib/utils/storage_key.dart
3. Verify whether current worksite source already contains task-066 behavior,
   and classify implementation status as absent, partial, or present.
4. Identify exact source paths for:
   - ShieldCandidate / ShieldRuleSet / ShieldMatcher
   - recommendation adapter and related-video adapter
   - list-filter pipeline
   - old RecommendFilter.applyFilterToRelatedVideos setting/storage
   - video detail introduction metadata model/controller/view surfaces
   - related-video list loading/filtering surfaces
   - settings model tests and shielding adapter tests
5. Verify that task-066 means detail-page introduction metadata used for
   recommendation shielding, not hiding or disabling the current detail page.
6. Verify the requested first-batch fields:
   - introduction/description text
   - publish time
   - staff/creative team
   - Upower/charging-exclusive state
   - already approved stable introduction metadata
7. Verify exclusions:
   - no dimension
   - no aspect ratio
   - no portrait/landscape orientation
   - no task-074 derived metrics
8. Verify related-video boundary:
   - must use shared ShieldMatcher / ShieldRuleSet / list-filter pipeline
   - must not directly reuse homepage fromRecommendationJson adapter
   - must add an independent related-video shielding switch named "相关视频屏蔽"
   - must not reuse, rename, or reinterpret RecommendFilter.applyFilterToRelatedVideos
9. Verify what is required to reach exactly +5162 for both test APK and
   prerelease, without creating empty/versionCode-only commits.

Write records/reasonix/task-066/source-verification-report-v2.md in English with:
- audience: agent-facing
- source-verification status
- Reasonix health status
- commands run
- current branch / commit / derived versionCode
- dirty worktree classification table
- source fact table with file paths and cited line summaries
- current task-066 implementation status: absent, partial, or present
- +5162 route and risks
- blockers and yellow items
- recommended atomic implementation slices
- explicit statement that this is candidate evidence for Codex review only
```
