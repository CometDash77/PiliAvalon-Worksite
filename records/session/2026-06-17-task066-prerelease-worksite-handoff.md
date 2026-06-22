---
audience: agent-facing
record_type: worksite-handoff
task: task-066
status: source-verification-reopened-prerelease-prep
created: 2026-06-17
updated: 2026-06-17
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
release_type: prebuild
target_version_code: 5162
---

# Task-066 Prerelease Worksite Handoff

This handoff prepares task-066 for a governed path toward a prerelease.
It does not mark task-066 implemented, accepted, green, or releasable.

Codex role remains Design Institute lead, reviewer, and orchestrator.
DeepSeek Reasonix may perform dirty work, broad read-only verification,
implementation slices, repeated verification, and GitHub Actions monitoring.
Reasonix output is candidate evidence only until Codex reviews the persisted
artifact and writes or records the review result.

Per the 2026-06-17 user instruction, current worksite source verification is
not complete for the prerelease path. Earlier read-only subagent verification
may inform planning, but remains candidate evidence for the current hard gate
until Codex reviews fresh persisted worksite evidence from the current branch
and worktree state.

Earlier planning-only records:

- Reasonix candidate report:
  `records/reasonix/task-066/source-verification-report.md`
- Codex review:
  `records/codex/task-066/source-verification-codex-review.md`

Current required fresh source-verification prompt:

- `records/reasonix/prompts/2026-06-17-task066-worksite-source-verification-v2.prompt.md`

Required fresh candidate and Codex review artifacts:

- `records/reasonix/task-066/source-verification-report-v2.md`
- `records/codex/task-066/source-verification-codex-review-v2.md`

## Current Worksite Baseline

- Repository: `CometDash77/PiliAvalon-Worksite`
- Local branch inspected: `task-066-detail-intro-shielding`
- Branch/base decision:
  `records/codex/task-066/branch-base-decision.md`
- Current HEAD: `f806d36d1b97e6b601372947e9a29fdaca7d68d7`
- Current derived Android versionCode: `5151`
- Target test APK and prerelease versionCode: `5162`
- VersionCode source: `lib/scripts/build.ps1` uses
  `git rev-list --count HEAD`
- Distance to target from current HEAD: 11 commits
- Current dirty product-source files:
  - `lib/features/shielding/shielding_matcher.dart`
  - `lib/features/shielding/shielding_models.dart`
  - `lib/utils/storage_key.dart`

The dirty product-source files may be user or previous-agent work. They must be
audited during fresh Stage 0 before any implementation report, verification
result, APK, or prerelease can be promoted as worksite evidence.

## Required Skills And Governance Already Loaded

Codex read these required guidance files before writing this handoff:

- `.codex/skills/worksite-release-governance/SKILL.md`
- `.codex/skills/dart-run-static-analysis/SKILL.md`
- `.codex/skills/dart-add-unit-test/SKILL.md`
- `.codex/skills/flutter-add-widget-test/SKILL.md`
- `.codex/skills/flutter-build-responsive-layout/SKILL.md`

The external design-institute communication directory named by the release
governance skill was not present at
`/home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/records/worksite-communications/`.
Relevant worksite-local communication records were read instead:

- `records/worksite-communications/2026-06-13-task065-app-stat-fix-acceptance-to-design-institute.md`
- `records/worksite-communications/2026-06-12-task024-expanded-shielding-core-implementation-report.md`
- `records/session/2026-06-13-task065-app-stat-fix-prebuild-5149-release-evidence.md`
- `records/session/2026-06-12-task071-keyword-contains-prebuild-release.md`

Reasonix health must be checked with `reasonix doctor` or a current verified
health record immediately before material delegation. This handoff update does
not itself dispatch Reasonix or treat Reasonix as healthy for later execution.

## Product Scope

Task-066 covers the video detail-page introduction component as source metadata
for recommendation shielding. It does not mean hiding or disabling the current
detail page.

The first-batch detail introduction fields are:

- Introduction or description text.
- Publish time.
- Staff or creative team.
- Upower / charging-exclusive state.
- Already approved stable introduction metadata.

Explicitly excluded from task-066:

- `dimension`
- aspect ratio
- portrait or landscape orientation
- derived metrics, which remain in task-074

## Filtering Contract

The introduction metadata serves the home recommendation feed. Its application
order is the same kind of feed-side enrichment as tag shielding and must run
after tag shielding.

Related videos must reuse the shared shielding path:

- `ShieldMatcher`
- `ShieldRuleSet`
- `ShieldingAdapters.filterList`
- list-filter pipeline semantics

Related videos must not directly reuse the home recommendation
`ShieldingAdapters.fromRecommendationJson` adapter. They need a related-video
candidate path that uses source fields available on related-video models.

Related videos need an independent settings switch named "related video
shielding" in user-facing Chinese. This switch must not reuse, rename, or
reinterpret the old `RecommendFilter.applyFilterToRelatedVideos` switch.

The old switch remains only the legacy `RecommendFilter` policy switch described
by the task-057 boundary record:

`records/session/2026-06-12-task057-recommend-filter-boundary-spec.md`

## Existing Source Notes To Verify

The current source search found these likely surfaces. Reasonix must verify them
before implementation; Codex must review the persisted report before relying on
it.

- `lib/features/shielding/shielding_models.dart`
  - `ShieldCandidate`
  - `ShieldRuleSet`
  - `ShieldScope`
  - `ShieldRuleType`
- `lib/features/shielding/shielding_matcher.dart`
  - `ShieldMatcher.match`
- `lib/features/shielding/shielding_adapters.dart`
  - `fromRecommendationJson`
  - `fromRelatedVideo`
  - `filterList`
  - `filterRecommendationVideos`
- `lib/utils/recommend_filter.dart`
  - legacy `applyFilterToRelatedVideos`
- `lib/pages/setting/models/recommend_settings.dart`
  - old setting currently titled `过滤器也应用于相关视频`
- `lib/utils/storage_key.dart`
  - existing storage keys
- `lib/utils/storage_pref.dart`
  - existing preference defaults
- `lib/pages/video/introduction/ugc/controller.dart`
  - related-video replay behavior
- `lib/pages/video/view.dart`
  - detail page related-video panel/tab layout
- `test/features/shielding/shielding_adapters_test.dart`
  - existing related-video adapter tests
- `test/pages/setting/models/recommend_settings_test.dart`
  - existing recommendation settings model tests

## Stage Plan

### Stage 0: Fresh Worksite Source Verification

Owner: Reasonix for broad verification, Codex for review.

Goal:

- Prove current source surfaces, existing behavior, missing task-066 behavior,
  branch/build-number preconditions, and the exact meaning of the current dirty
  files.
- Treat earlier subagent/read-only verification only as planning input.

Required candidate artifact:

- `records/reasonix/task-066/source-verification-report-v2.md`

Required Codex review artifact:

- `records/codex/task-066/source-verification-codex-review-v2.md`

Exit criteria:

- Source paths and behavior are cited from current files.
- Existing task-066 implementation status is classified as absent, partial, or
  present with file-level evidence.
- Dirty worktree changes are classified as in-scope candidate work,
  out-of-scope drift, or unknown/user-owned changes requiring clarification.
- The old related-video `RecommendFilter.applyFilterToRelatedVideos` boundary is
  confirmed unchanged.
- The route to produce exactly versionCode `5162` is identified.

### Stage 1: Atomic Implementation Slices

Owner: Reasonix for implementation candidate, Codex for review and integration.

The initial slice should be narrow:

- Add or extend detail-introduction candidate metadata without adding excluded
  dimensions, aspect ratio, or orientation.
- Keep related-video shielding on the shared `ShieldMatcher` / `ShieldRuleSet`
  list-filter path.
- Add an independent related-video shielding setting and storage key.
- Preserve old `RecommendFilter.applyFilterToRelatedVideos` behavior.
- Add focused tests for candidate fields, setting visibility/default behavior,
  old-switch independence, and related-video list filtering.

Prerequisites:

- Fresh Stage 0 candidate report exists.
- Codex writes the fresh Stage 0 review.
- Codex explicitly authorizes implementation on the current branch and dirty
  worktree state.

Required candidate artifact:

- `records/reasonix/task-066/implementation-report.md`

Required Codex review artifact:

- `records/codex/task-066/implementation-codex-review.md`

Exit criteria:

- Codex reviews the diff, rejects any scope drift, and records whether the
  candidate can proceed to verification.

### Stage 2: Focused Verification

Owner: Reasonix for repeated local or GitHub verification when allowed, Codex
for evidence review.

Minimum checks before any APK build:

- `flutter test test/features/shielding`
- `flutter test test/pages/setting/models/recommend_settings_test.dart`
- Any new focused task-066 tests.
- `flutter analyze --no-fatal-infos`

If the user requires GitHub-only verification for a later step, do not replace
it with local checks.

Required candidate artifact:

- `records/reasonix/task-066/focused-verification-report.md`

Required Codex review artifact:

- `records/codex/task-066/focused-verification-codex-review.md`

Exit criteria:

- Every relevant test command has a fresh conclusion.
- Failures are fixed or recorded as blockers.
- Codex records whether verification evidence is strong enough for the
  versionCode `5162` build stage.

### Stage 3: +5162 Test APK

Owner: Codex for workflow dispatch decision; Reasonix for GitHub monitoring.

Hard requirement:

- The test APK must be built from a commit whose derived versionCode is exactly
  `5162`.

Required evidence:

- GitHub Actions run URL and conclusion.
- Commit SHA.
- Artifact names containing `+5162`.
- Android signing evidence where applicable.
- Runtime smoke result if the selected verification surface includes it.

Required candidate monitor artifact:

- `records/reasonix/task-066/test-apk-5162-monitor-report.md`

Required Codex review artifact:

- `records/codex/task-066/test-apk-5162-codex-review.md`

Exit criteria:

- Codex confirms the APK artifact names and run metadata prove `+5162`.
- No user/client acceptance is implied.

### Stage 4: +5162 Prerelease

Owner: Codex for release workflow dispatch and notes; Reasonix for GitHub
monitoring.

Hard requirement:

- The prerelease must be built from the same `+5162` source as the test APK
  unless Codex records a deliberate correction before dispatch.

Release type:

- `prebuild`

Expected tag pattern:

- `task066-prebuild.<run-id>`

Required notes sections:

- `Purpose`
- `Release Type`
- `Branch / Commit / Tag`
- `Related PRs / Issues`
- `Automation Evidence`
- `Manual Acceptance`
- `Changes`
- `Known Risks`
- `Sources / License / Attribution`
- `Rollback Plan`
- `Not Covered / Still Yellow`
- `User Action Required`

Required candidate monitor artifact:

- `records/reasonix/task-066/prerelease-5162-monitor-report.md`

Required worksite release evidence:

- `records/session/2026-06-17-task066-prebuild-5162-release-evidence.md`
- release notes file under `records/session/` before publishing or immediately
  after a workflow-created release is reviewed

Exit criteria:

- GitHub Release is a prerelease and not latest/stable.
- All attached Android APK artifact names include `+5162`.
- Release target commit matches the accepted `+5162` commit.
- Manual acceptance remains pending unless the user explicitly accepts it.

## Allowed Commands

Codex may run local read-only inspection commands and create worksite records.

Reasonix prompts may allow only the commands necessary for each slice. Typical
allowed commands:

- `pwd`
- `git status --short --branch`
- `git rev-parse HEAD`
- `git rev-list --count HEAD`
- `git log --oneline --decorate -n 20`
- `rg`
- `sed`
- `flutter test ...` for focused test targets
- `flutter analyze --no-fatal-infos`
- `dart format <changed dart files>`
- `gh run list -R CometDash77/PiliAvalon-Worksite ...`
- `gh run view -R CometDash77/PiliAvalon-Worksite ...`
- `gh run watch -R CometDash77/PiliAvalon-Worksite ...`
- `gh release view -R CometDash77/PiliAvalon-Worksite ...`

Every repo-level GitHub command must include
`-R CometDash77/PiliAvalon-Worksite`.

## Forbidden Actions

Forbidden unless Codex receives explicit user approval and records the reason:

- Publishing stable releases.
- Marking task-066 source verified without Codex-reviewed persisted evidence.
- Treating Reasonix chat text as citable evidence.
- Pushing, merging, or force-pushing from Reasonix.
- Deleting releases or tags.
- Modifying governance policy, workflows, release state, or design-institute
  files.
- Reusing `fromRecommendationJson` directly for related videos.
- Reusing or repurposing `RecommendFilter.applyFilterToRelatedVideos` for the
  new related-video shielding switch.
- Adding task-074 derived metrics to task-066.
- Adding dimension, aspect-ratio, portrait, or landscape matching.
- Calling any test APK or prerelease accepted before user/client acceptance.

## Rollback Path

Code rollback:

- Revert task-066 implementation commits on the task branch with ordinary
  non-destructive git history, or create a forward fix commit.

Prebuild rollback:

- Preserve the previous known accepted task-065 package:
  `task065-app-stat-fix-prebuild.27460023543`
- Preserve the previous known no-bug baseline:
  `task071-keyword-contains-prebuild.27394918307`
- If a task-066 prerelease is wrong, publish a superseding fixed prerelease only
  after evidence; do not delete releases/tags without explicit user approval.

Operational rollback:

- If +5162 is missed, stop and record the mismatch. Do not publish a prerelease
  under a tag that implies +5162.

## Stage Acceptance Checklist

- [ ] Fresh Stage 0 source verification candidate report exists.
- [ ] Fresh Codex source-verification review exists.
- [ ] Stage 1 implementation candidate report exists.
- [ ] Codex implementation review exists.
- [ ] Focused task-066 tests exist and are relevant.
- [ ] Focused verification report exists.
- [ ] Codex focused-verification review exists.
- [ ] Test APK build commit has `git rev-list --count HEAD == 5162`.
- [ ] Test APK artifact names include `+5162`.
- [ ] Test APK GitHub run conclusion is success.
- [ ] Reasonix monitor report exists for test APK build.
- [ ] Codex test APK review exists.
- [ ] Prerelease target commit is the accepted `+5162` commit.
- [ ] Prerelease artifact names include `+5162`.
- [ ] Prerelease is marked prerelease and not latest/stable.
- [ ] Release notes include all governance sections.
- [ ] Reasonix prerelease monitor report exists.
- [ ] Worksite release evidence record exists.
- [ ] Manual acceptance remains pending until explicit user feedback.

## +5162 APK And Prerelease Checklist

Before dispatch:

- [ ] Confirm intended branch.
- [ ] Confirm target commit SHA.
- [ ] Confirm `git rev-list --count HEAD` equals `5162` on the target commit.
- [ ] Confirm no unreviewed changes are present.
- [ ] Confirm release notes state `prebuild`, not stable.

After test APK build:

- [ ] GitHub run URL recorded.
- [ ] GitHub run conclusion is success.
- [ ] APK filenames include `+5162`.
- [ ] Artifact platform list is recorded.
- [ ] Runtime smoke or selected installability evidence is recorded.

After prerelease:

- [ ] GitHub Release URL recorded.
- [ ] Tag pattern is `task066-prebuild.<run-id>`.
- [ ] Target commit matches the `+5162` test APK commit.
- [ ] Attached APK filenames include `+5162`.
- [ ] Release is prerelease.
- [ ] Release is not latest/stable.
- [ ] `Manual Acceptance` is pending unless the user has accepted it.
- [ ] `Not Covered / Still Yellow` is non-empty.
