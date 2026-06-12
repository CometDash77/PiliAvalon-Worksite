---
audience: agent-facing
task_id: task-071
release_type: prebuild
created: 2026-06-12
target_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
---

# Task-071 Keyword Contains Prebuild Release Evidence

## Purpose

This is a remote GitHub pre-release for user validation of task-071 on the
strict accepted `2.0.8-ba9d4569e+5134` baseline. It is not a stable release.

## Release Type

`prebuild`

Manual acceptance package only. User acceptance was reported by the user in
chat on 2026-06-12 after receiving the remote release.

## Branch / Commit / Tag

- Branch: `task-071-keyword-contains-from-5134`
- Baseline tag: `task042-5122-prebuild.27263751328`
- Baseline commit: `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
- Final commit: `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`
- Release tag: `task071-keyword-contains-prebuild.27394918307`
- Release title/name: `task071-keyword-contains-prebuild.27394918307`
- Release URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task071-keyword-contains-prebuild.27394918307
- GitHub Release state: prerelease `true`, draft `false`
- Target commitish: `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`

## Related PRs / Issues

- Task: `task-071`
- Design Institute plan read:
  `/home/mo/Documents/obsidian/VIBECODING项目/Piliavalon/docs/superpowers/plans/2026-06-12-task071-keyword-contains-fix-plan.md`
- No PR was created for this branch.

## Automation Evidence

- GitHub CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27394399112
  - Branch: `task-071-keyword-contains-from-5134`
  - Commit: `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`
  - Conclusion: `success`
  - Jobs passed:
    - Focused Flutter verification
    - Build Android x86_64 artifact
    - Android emulator runtime smoke
- Remote Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27394918307
  - Event: `workflow_dispatch`
  - Branch: `task-071-keyword-contains-from-5134`
  - Commit: `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`
  - Conclusion: `success`
  - Release Android: `success`
  - iOS/macOS/Windows/Linux: skipped intentionally by workflow inputs

## Manual Acceptance

`pass`

The user reported "我已经接受到了" on 2026-06-12 after the remote pre-release was
created and made available. No local artifact download was performed by Codex.

## Changes

- Added `ShieldMatchMode.contains`.
- Migrated old persisted `keyword + exact` and `reasonKeyword + exact` rules to
  `contains`.
- Kept `uid`, `category`, `tag`, and `userKeyword` exact rules as exact.
- Changed `exact` matcher semantics to case-insensitive equality.
- Added `contains` matcher semantics as case-insensitive literal substring.
- Kept `regex` and `token` compatibility.
- Kept `allow` precedence over `block`.
- Updated settings/UI defaults and labels so keyword rules default to and
  display as contains, while identity/category/tag rules default to exact.
- Hid `token` from normal new-rule UI.
- Added focused matcher, migration, idempotency, compatibility, precedence, and
  settings/UI tests.

Changed implementation and test files:

- `lib/common/widgets/video_card/shield_quick_action.dart`
- `lib/features/shielding/shielding_matcher.dart`
- `lib/features/shielding/shielding_migration.dart`
- `lib/features/shielding/shielding_models.dart`
- `lib/features/shielding/shielding_store.dart`
- `lib/pages/setting/models/shielding_settings.dart`
- `lib/pages/shielding_settings/view.dart`
- `test/features/shielding/comment_reply_controller_test.dart`
- `test/features/shielding/shielding_adapters_test.dart`
- `test/features/shielding/shielding_core_test.dart`
- `test/features/shielding/shielding_migration_test.dart`
- `test/features/shielding/shielding_store_test.dart`
- `test/features/shielding/video_card_shield_quick_action_test.dart`
- `test/pages/setting/models/shielding_settings_test.dart`

## Remote Assets

Release assets attached remotely:

- `PiliAvalon_android_2.0.8-b8106ac60+5136_arm64-v8a.apk`
- `PiliAvalon_android_2.0.8-b8106ac60+5136_armeabi-v7a.apk`
- `PiliAvalon_android_2.0.8-b8106ac60+5136_x86_64.apk`

No APK, workflow artifact, or release asset was downloaded locally.

## Reasonix Evidence

- Implementation dispatch:
  `records/reasonix/task-071-keyword-contains-from-5134/dispatch-implementation.md`
- Implementation report:
  `records/reasonix/task-071-keyword-contains-from-5134/implementation-report.md`
- Read-only review dispatch:
  `records/reasonix/task-071-keyword-contains-from-5134/dispatch-review-001.md`
- Read-only review report:
  `records/reasonix/task-071-keyword-contains-from-5134/review-001-report.md`
  - Verdict: PASS
  - Blocking issues: none
- CI monitor rerun report:
  `records/reasonix/task-071-keyword-contains-from-5134/ci-monitor-rerun-report.md`
- Build/release monitor report:
  `records/reasonix/task-071-keyword-contains-from-5134/build-release-monitor-report.md`

## Boundary Confirmation

Not modified:

- `RecommendFilter` implementation.
- Danmaku `RuleFilter`.
- Scene adapters.
- Expanded rule types.
- Design Institute canonical kanban.

The only `RecommendFilter` mentions are pre-existing shielding migration
analysis/tests and were not expanded into the runtime filter implementation.

## Known Risks

- This release is a prebuild/manual validation artifact, not a stable release.
- Android was the only remotely published platform in this Build run.
- Existing persisted keyword-style exact rules intentionally change their stored
  mode to `contains` on load to preserve old user-facing behavior under a clear
  semantic name.

## Sources / License / Attribution

No new external source code, assets, or third-party libraries were copied. The
work reuses existing project code and GitHub Actions release infrastructure.

## Rollback Plan

- User-facing rollback: return users to the previous accepted prerelease
  `task042-5122-prebuild.27263751328`.
- Code rollback: revert commit
  `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e` and its parent task-071
  implementation commit on branch `task-071-keyword-contains-from-5134`, or
  switch back to baseline commit
  `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`.
- Data behavior rollback warning: persisted migrated rules may have explicit
  `contains`; reverting code would require confirming older clients tolerate
  the enum string before rollback deployment.

## Not Covered / Still Yellow

- Stable release approval is not covered by this prebuild.
- Cross-platform release assets were not produced; only Android APK assets were
  published.
- Client/user acceptance is based on the user's reported receipt/acceptance in
  this session and does not replace any separate formal stable-release approval.

## User Action Required

None for this prebuild evidence record. Any stable release promotion requires a
separate approval and release-governance pass.

## Command Discipline

Every repository-level GitHub CLI command used for this release evidence was
scoped with `-R CometDash77/PiliAvalon-Worksite`.
