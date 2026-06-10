# Issue #8 Live-Player Gray Screen — Codex Review

Audience: agent-facing

## Reviewed Reasonix Artifact

- Candidate artifact: `records/reasonix/2026-06-09-issue8-player-gray/repair-candidate.md`
- Context record: `records/session/2026-06-09-issue8-live-player-gray-next-session.md`
- Review owner: Codex

## Verdict

Accepted with one narrowed claim.

Reasonix correctly identified that `videoPlayerPanel()` was reading
`_liveRoomController.roomInfoH5.value` inside the same `Obx` that constructs
`PLVideoPlayer`. That makes the player subtree react to the async H5 room-info
response during initial load. Removing that reactive dependency is a targeted
repair for the user-reported initial gray/uncontrollable player symptom.

The claim that this guarantees exactly one player construction is too strong:
`isLoaded.refresh()`, fullscreen state, PiP state, and layout/orientation changes
can still rebuild the wrapper. The accepted narrower claim is that the H5 room
info response no longer triggers a redundant player reconstruction during first
load.

## Diff Review

- `lib/pages/live_room/view.dart`: accepted. `roomInfoH5.value` is no longer read
  inside the `PLVideoPlayer` construction `Obx`; `LiveHeaderControl` receives
  null `title` and `upName` values so header metadata cannot bind the player
  subtree to H5 room-info updates.
- `lib/pages/live_room/widgets/header_control.dart`: accepted. The displayed
  anchor name now reads `liveController.roomInfoH5.value` in a small header-only
  `Obx`, preserving the visible metadata without rebuilding `PLVideoPlayer`.
- Existing quiet-control edits in `controller.dart`, `view.dart`,
  `chat_panel.dart`, and `header_control.dart` are treated as the accepted
  user-tested behavior from the previous prerelease and were not reopened.

## Verification Status

Local Flutter, Dart, Gradle, adb, APK builds, and artifact downloads were not
run because this repair is under GitHub-only verification rules.

Required next evidence:

- `PiliAvalon CI` workflow success at the final commit.
- `Build` workflow Android-only success at the final commit.
- APK names from the final build showing versionCode greater than `5120`.
- Android emulator install/launch smoke success.
- GitHub prerelease marked prerelease, not stable/latest, linked to Issue #8.
- Manual acceptance remains pending until the user confirms live-room playback
  is no longer gray/uncontrollable.
