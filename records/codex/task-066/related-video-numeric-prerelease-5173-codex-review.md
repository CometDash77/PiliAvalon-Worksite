---
audience: agent-facing
record_type: codex-review
task: task-066
stage: related-video-numeric-prerelease-5173
status: reviewed-github-prerelease-and-runtime-smoke-green
created: 2026-06-20
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
baseline_release: v2.0.10-task066-task074-candidate
baseline_commit: 465952d9c0f64b708dec08dbc6c94e236773ad31
baseline_version_code: 5169
release_commit: 222192e36fe495031e5ab12eacf8277eaf676787
release_version_code: 5173
new_prerelease: task066-related-numeric-plus5169.27869254709
ci_run: 27869244077
build_run: 27869254709
release_smoke_run: 27869582693
---

# Task-066 Related-Video Numeric Fields Prerelease +5173 Codex Review

Codex independently checked GitHub Actions and GitHub Release metadata for the
related-video numeric shielding change. No Reasonix candidate report was cited
for this review.

## Decision

The GitHub automated prerelease gate is green for:

- Prerelease: `task066-related-numeric-plus5169.27869254709`
- Release URL:
  `https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task066-related-numeric-plus5169.27869254709`
- Target commit: `222192e36fe495031e5ab12eacf8277eaf676787`
- APK version emitted by workflow: `2.0.8-222192e36+5173`

This review does not claim user manual acceptance, formal production release,
merge completion, or physical-device acceptance.

## Code Change Reviewed

- `lib/features/shielding/shielding_adapters.dart`
  - `fromRelatedVideo` now maps:
    - `durationSeconds: item.duration > 0 ? item.duration : null`
    - `playbackCount: item.stat.view`
    - `danmakuCount: item.stat.danmu`
- `test/features/shielding/shielding_adapters_test.dart`
  - Existing related-video numeric null assertion was changed to positive
    field assertions.
  - Added `ShieldScope.videoDetail` range coverage for duration, playback
    count, and danmaku count through `filterRelatedVideos`.
  - Added switch coverage showing `relatedVideoEnabled=false` disables these
    rules and `recommendationEnabled=false` does not disable
    `filterRelatedVideos`.

Local focused check before push:

- `flutter test test\features\shielding\shielding_adapters_test.dart`
- Result: passed, 53 tests.

The release decision below is based on GitHub evidence.

## GitHub Evidence

| Evidence | Result |
| --- | --- |
| Baseline prerelease `v2.0.10-task066-task074-candidate` | Non-draft prerelease, target commit `465952d9c...`, APKs include `+5169` |
| Baseline signing fingerprint | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| CI run `27869244077` | `completed / success`, head SHA `222192e36...` |
| CI verification job | shielding tests, settings tests, bootstrap startup test, and analyze all succeeded |
| CI x86_64 build job | `completed / success` |
| CI dev runtime smoke job | `completed / success` |
| Build run `27869254709` | `completed / success`, Android-only release build |
| New prerelease | Non-draft prerelease, `isPrerelease=true`, target commit `222192e36...` |
| Release APK runtime smoke `27869582693` | `completed / success`, installed/launched release x86_64 APK from Build run `27869254709` |

## APK Assets

| APK | Size | Digest |
| --- | ---: | --- |
| `PiliAvalon_android_2.0.8-222192e36+5173_arm64-v8a.apk` | 25,956,974 | `sha256:1073132353e55a1f9a26d49764bf0ba72f68c76f590edee5fe44ee4e9c2a8535` |
| `PiliAvalon_android_2.0.8-222192e36+5173_armeabi-v7a.apk` | 25,879,256 | `sha256:23d3a0740c9815ad9b1acd84b9466dd202895110ecbacdc843c4f75f06dd8fac` |
| `PiliAvalon_android_2.0.8-222192e36+5173_x86_64.apk` | 26,947,866 | `sha256:b3e597ce3c95805a564dc62609b4969a1dd101b399346add480e6b262778ed44` |

Build run artifacts:

| Artifact | Size |
| --- | ---: |
| `PiliAvalon_android_2.0.8-222192e36+5173_arm64-v8a.apk` | 25,956,974 |
| `PiliAvalon_android_2.0.8-222192e36+5173_armeabi-v7a.apk` | 25,879,256 |
| `PiliAvalon_android_2.0.8-222192e36+5173_x86_64.apk` | 26,947,866 |
| `Android_signing_evidence` | 2,094 |

## Signing Evidence

Release body signing fingerprint for all three +5173 APKs:

`0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

The baseline +5169 release body records the same fingerprint:

`0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

This supports the GitHub-side signing compatibility constraint relative to the
user-accepted +5169 baseline. It is still not a claim that a user has manually
performed cover-install acceptance on a physical device for +5173.

## Non-Claims

This review does not claim:

- user/client acceptance
- production release promotion
- merge completion
- physical-device cover-install verification
- non-Android platform coverage
