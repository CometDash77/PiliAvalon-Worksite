---
audience: agent-facing
record_type: implementation-note
task: task-066
status: in-progress-local-fix
created: 2026-06-18
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
wrong_release_tag: task066-prebuild.27667066405
correct_baseline_tag: task065-comment-gate-prebuild.27497810462
---

# Task-066 Baseline Recovery Implementation

## Problem

The task-066 prerelease `task066-prebuild.27667066405` was built from
`acfc3a356d99765b444c849bc26ef4a1332c6ddb`, which derives versionCode `5162`
but is not based on the requested source baseline
`task065-comment-gate-prebuild.27497810462`
(`f96a0e1d7b5dfc99a263c7478ebd9b3e69a020e5`).

The consequence was a functional regression: comment-shielding infrastructure
from the correct baseline was absent from the task-066 package.

## Reviewed Evidence

- Reasonix candidate audit:
  `records/reasonix/task-066/baseline-recovery-audit.md`
- Codex review:
  `records/codex/task-066/baseline-recovery-codex-review.md`
- User feedback record:
  `records/session/2026-06-17-task066-manual-validation-problems-reported.md`

## Local Recovery Work

Restored correct-baseline comment-shielding source and tests:

- `lib/features/shielding/comment_shielding_config.dart`
- `lib/features/shielding/home_feed_comment_gate.dart`
- `lib/pages/comment_shield_settings/view.dart`
- comment-shielding unit/widget tests under `test/features/shielding/` and
  `test/pages/comment_shield_settings/`

Reconnected the restored baseline into the current app:

- `lib/features/shielding/shielding.dart` exports comment-shielding config.
- `lib/models/common/setting_type.dart`,
  `lib/pages/setting/view.dart`, and `lib/router/app_pages.dart` restore the
  comment-shield settings entry and route.
- `lib/http/video.dart` restores `HomeFeedCommentGate.filter` for web/app
  homepage recommendation lists while preserving task-066 related-video
  filtering.
- `lib/pages/common/reply_controller.dart` restores the
  `CommentShieldMatcher` pre-filter plus regular shielding rules.
- `lib/pages/video/reply/widgets/reply_item_grpc.dart` restores comment quick
  actions for avatar pendant and garb card rules.

Preserved and integrated task-066 behavior:

- detail-introduction rule types:
  `descriptionKeyword`, `publishTime`, `isUpowerExclusive`, `staffKeyword`
- `ShieldRuleSet.relatedVideoEnabled`
- `ShieldingAdapters.filterRelatedVideos`
- video-detail rule labels, categories, and editor defaults

Additional correction:

- The shielding-rule page category navigation now includes categories returned
  by `shieldingRuleCategoryFor`: `数值元数据`, `评论用户信息`, `评论装饰`, and
  `视频详情信息`.

## Verification Status

- `git diff --check`: passed.
- Local `dart`/`flutter` commands are not available in the current shell, so
  focused Flutter tests and analysis could not be run locally in this session.
- Fresh GitHub CI/build verification is still required before publishing any
  corrected validation APK.

## Release Status

`task066-prebuild.27667066405` remains failed/superseded evidence only. It must
not be used for acceptance, release-candidate, stable-release, or closure
claims.

Deleting the GitHub Release, tag, or workflow run is destructive and requires
explicit approval plus rollback recording. Marking the release body as
superseded is preferred when GitHub Release API authorization is available.
