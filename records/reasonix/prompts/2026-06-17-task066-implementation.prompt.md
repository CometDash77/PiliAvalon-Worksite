---
audience: agent-facing
record_type: reasonix-dispatch-prompt
task: task-066
stage: implementation
status: draft-waiting-for-fresh-source-verification-review
created: 2026-06-17
review_owner: Codex
---

# Reasonix Prompt: Task-066 Implementation Slice

```text
First confirm that response instructions / 响应指令 are enabled for this task.

role_id: task-066-implementation-worker
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: local branch task-066-detail-intro-shielding at or after f806d36d1b97e6b601372947e9a29fdaca7d68d7
review_owner: Codex
difficulty_classification: hard, cross-cutting Flutter/Dart implementation with release impact
model_strategy: deepseek-v4-pro
max_iterations: 1
max_time_minutes: 60
usd_cap: 2.00
expected_artifact_path: records/reasonix/task-066/implementation-report.md

Use YOLO/edit-auto-free behavior for the allowed bounded slice. Do not stall on
approval prompts. Persist the report even if implementation is partial or
blocked.

You are DeepSeek Reasonix acting as an implementation worker. Codex remains the
Design Institute lead, reviewer, integrator, and final gate owner. Your changes
and report are candidate work until Codex reviews them.

Prerequisite:
- Read records/session/2026-06-17-task066-prerelease-worksite-handoff.md.
- Read fresh source verification:
  records/reasonix/task-066/source-verification-report-v2.md.
- Read fresh Codex source-verification review:
  records/codex/task-066/source-verification-codex-review-v2.md.
- Read Codex branch/base decision:
  records/codex/task-066/branch-base-decision.md.
- Read .reasonix/skills/flutter-official-skill-router.md if present, then the
  relevant official Flutter/Dart skills for this slice.
- Stop without product-source edits if either fresh Stage 0 artifact is absent
  or if Codex review has not authorized implementation on the current dirty
  worktree state.

Allowed commands:
- pwd
- git status --short --branch
- git rev-parse HEAD
- git rev-list --count HEAD
- rg
- sed -n ...
- dart format <changed Dart files>
- flutter test <focused new or existing test files>
- flutter analyze --no-fatal-infos only if time permits after focused tests

Allowed edits:
- Product source required for task-066 only.
- Focused tests under test/ matching changed source.
- The expected artifact path.

Forbidden actions:
- Do not spawn or dispatch another Reasonix process; you are the implementation worker.
- Do not create coordination notes or dispatch records.
- Do not push, merge, tag, release, delete releases, delete tags, or force-push.
- Do not modify workflows, governance policy, release state, or design-institute files.
- Do not create versionCode bump commits or empty commits.
- Do not run GitHub Actions commands.
- Do not implement task-074 derived metrics.
- Do not add dimension, aspect-ratio, portrait, or landscape matching.
- Do not hide or disable the current detail page.
- Do not directly reuse ShieldingAdapters.fromRecommendationJson for related videos.
- Do not reuse, rename, or reinterpret RecommendFilter.applyFilterToRelatedVideos
  as the new related-video shielding switch.
- Do not remove existing legacy RecommendFilter behavior.

Implementation requirements:
1. Keep the slice atomic. Prefer model/adapter/settings/test changes that make
   task-066 candidate metadata expressible and independently gateable; do not
   attempt APK, prerelease, GitHub, or broad UI refactors in this slice.
2. Add task-066 detail-introduction candidate metadata for the first-batch fields:
   introduction/description text, publish time, staff/creative team,
   Upower/charging-exclusive state, and already approved stable introduction
   metadata found by source verification.
3. Keep the runtime semantics aligned with "after tag shielding" by preserving
   the existing tag enrichment order and adding tests or explicit code evidence
   for the order if any feed pipeline is touched.
4. Keep related videos on shared ShieldMatcher / ShieldRuleSet / list-filter
   pipeline semantics.
5. Add an independent setting/storage switch for related-video shielding with
   user-facing Chinese label equivalent to "相关视频屏蔽".
6. Keep the old "过滤器也应用于相关视频" switch as legacy
   RecommendFilter.applyFilterToRelatedVideos behavior.
7. Add focused tests for:
   - candidate field population
   - excluded fields remaining absent
   - related-video adapter not using homepage JSON adapter directly
   - new switch default and independence from the old switch
   - related-video list filtering through ShieldMatcher/ShieldRuleSet/list filter
8. Stop and report instead of guessing if the slice requires a broad data-flow
   rewrite from `VideoHttp.relatedVideoList` into page/controller state.

Write records/reasonix/task-066/implementation-report.md in English with:
- audience: agent-facing
- files changed
- commands run and conclusions
- tests added/updated
- exact scope coverage against each requirement
- risks, yellow items, and rollback notes
- explicit statement that this is candidate work pending Codex review
```
