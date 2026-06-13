---
audience: agent-facing
record_type: manual-acceptance-feedback
task: task-065
status: failed
created: 2026-06-13
review_owner: Codex
---

# Task-065 Inline Filters Manual Acceptance Failure

## Source

- Prebuild tag: `task065-inline-filters-prebuild.27459281224`
- Version: `2.0.8-3f793af31+5147`
- Release URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-inline-filters-prebuild.27459281224

## Raw User Feedback

```text
手动测试完了，播放量和弹幕屏蔽不生效，但是时长生效
```

## Acceptance Status

- Manual acceptance: failed.
- No-new-bug acceptance: not claimed.
- Stable release: not created.
- Task accepted: not claimed.

## Technical Interpretation

Duration filtering worked because recommendation candidates populated
`durationSeconds`.

Playback-count and danmaku-count filtering failed for the user's runtime path
because App recommendation candidates did not populate `playbackCount` or
`danmakuCount`. The adapter only populated these fields for
`RcmdVideoItemModel` and left `RcmdVideoItemAppModel` fields null. Numeric range
rules do not match null candidate fields, so affected feed items remained
visible.

## Follow-Up

Fix candidate: reuse already parsed `RcmdVideoItemAppModel.stat.view` and
`RcmdVideoItemAppModel.stat.danmu` in
`ShieldingAdapters.fromRecommendationJson`.

This remains within the task-065 homepage/recommend-feed boundary because it
does not add HTTP/API fetches, enrichment, settings changes, or matcher
semantic changes.
