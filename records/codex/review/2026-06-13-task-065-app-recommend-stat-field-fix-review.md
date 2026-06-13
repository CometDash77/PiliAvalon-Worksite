---
audience: agent-facing
record_type: codex-review
task: task-065
status: candidate-approved-for-ci
created: 2026-06-13
review_owner: Codex
reasonix_artifact: records/reasonix/2026-06-13/task-065-app-recommend-stat-field-fix.md
---

# Task-065 App Recommend Stat Field Fix Review

## Reviewed Inputs

- User manual acceptance feedback:
  `records/session/2026-06-13-task065-inline-filters-user-acceptance-failure.md`
- Reasonix candidate report:
  `records/reasonix/2026-06-13/task-065-app-recommend-stat-field-fix.md`
- Candidate source diff:
  - `lib/features/shielding/shielding_adapters.dart`
  - `test/features/shielding/shielding_adapters_test.dart`

## Finding

The Reasonix candidate fix is accepted for GitHub CI verification.

The failure mechanism is coherent:

1. `ShieldingAdapters.fromRecommendationJson` populated
   `durationSeconds` for all recommendation item models.
2. It populated `playbackCount` and `danmakuCount` only when
   `item is RcmdVideoItemModel`.
3. The user's runtime path used App recommendation items
   (`RcmdVideoItemAppModel`), whose existing `RcmdStat` already parsed
   `cover_left_text_1` into `stat.view` and `cover_left_text_2` into
   `stat.danmu`.
4. Because the adapter left those candidate fields null, playback-count and
   danmaku-count range rules had no numeric field to match.

## Accepted Candidate Behavior

- Add a bounded `RcmdVideoItemAppModel` branch in
  `ShieldingAdapters.fromRecommendationJson`.
- Populate:
  - `playbackCount` from `item.stat.view`
  - `danmakuCount` from `item.stat.danmu`
- Preserve the existing duration path.
- Preserve matcher range semantics.
- Do not change settings UI.
- Do not add fetch, enrichment, cache, concurrency, or endpoint behavior.

## Test Review

The test changes are appropriate for the reported failure:

- App recommendation unit assertion now expects parsed `playbackCount` and
  `danmakuCount`.
- App playback-count range rule now blocks a matching App recommendation.
- App danmaku-count range rule now blocks a matching App recommendation.

These tests directly cover the regression reported by the user.

## Verification Boundary

Per user instruction, formal verification must run on GitHub. Local
Flutter/Dart verification is not used as acceptance evidence.

## Release Boundary

This review does not claim:

- CI green.
- Runtime smoke green.
- Manual acceptance pass.
- No-new-bug acceptance.
- Stable release readiness.
- Task acceptance.

Those gates remain open until a new GitHub-verified prerelease is built and the
user completes manual acceptance.
