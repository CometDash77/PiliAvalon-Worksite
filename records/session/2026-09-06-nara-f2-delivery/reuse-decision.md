# G0 reuse, attribution and license decision

## Decision

F2 is a bounded C1 selective adaptation from `Starfallan/PiliNara` at `a12f5632f80859265056161b1fd1e6a4803b4b1a` into `CometDash77/PiliAvalon-Worksite` at `b0eb8dff122ddc86666a98d6a71800ac0af965de`. The source is attributed as adapted upstream/fork code, not original Worksite code. The root `LICENSE` files are byte-identical GPL-3.0 texts (SHA-256 `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809`); no inspected F2 file carries a separate SPDX header. The Worksite change will retain its existing root license and add durable reuse attribution in this Worksite-owned evidence package.

The implementation will port only the verified F2 behavior and use current Worksite seams. It will not cherry-pick the mixed Nara feature/fix commits, because Worksite contains newer player, PIP, quiet, shielding, resolver and media-session behavior. The complete selected source/fix chain and each local decision are recorded in `source-history-ledger.csv` and `source-map.md`.

## Source-to-target reuse

- Reuse the storage key shape and nullable `-1` normalization from the F2 introduction.
- Reuse the mobile-only settings row, network-cap subtitle and explicit follow option from the final Nara quality-persistence fix.
- Reuse the upgrade-only fullscreen target comparison and actual-quality display semantics from the connected fix chain.
- Reuse the single central player fullscreen callback seam, but adapt callback ownership to Worksite's singleton `PlPlayerController`.
- Reuse the shared manual-menu persistence routing; both Worksite quality menus must call the same `VideoDetailController` helper.
- Preserve Worksite's `findAvailableVideoQuality`, supplemental-quality merge, current playback position and existing media/player state handling.

## Local adaptations explicitly authorized by the plan

1. `PlPlayerController` is a singleton. The callback is assigned by the active video page, rebound in the existing `didPopNext`, and cleared only if it still belongs to that owner. No permanent per-controller `ever()` listener is added.
2. After `ConnectivityUtils.isWiFi` and other asynchronous work, verify owner identity, bvid/CID, query state, fullscreen state and disposal before mutating `cacheVideoQa`, `currentVideoQa` or calling `updatePlayer`.
3. Reset quality cache for a different video/CID at the current query seam, while preserving same-media manual selections.
4. Use Worksite's current labels, `PlatformUtils` and storage objects rather than copying older Nara helpers or introducing a setter/service layer.

## License and notice handling

The GPL-3.0 root notices remain in the repository. The evidence package names the exact source repository, source pin, selected commits, copied/adapted responsibilities and local changes. No third-party dependency is introduced and no source tree, downloaded archive, SDK, secret, key or build artifact will be committed. Any future distribution candidate must carry this attribution in its prebuild notes/release body and keep the source branch available.

## Non-goals and rejected shortcuts

- No F1 similar/pinyin danmaku merging.
- No F3 predictive back, F4 AI chat or F5 in-app PiP.
- No old Nara quality resolver, dependency fork, SDK change, continuous connectivity listener or global player lifecycle redesign.
- No stable merge, stable/latest publication or tag movement.
- No claim of user acceptance; the terminal state is only `ready for user acceptance` after exact candidate evidence exists.

## G0 limitations

This is source/history/license evidence, not a build or runtime claim. The local environment currently lacks `adb`, `gradle`, `java` and a discoverable Flutter SDK. Existing Worksite CI, build and Android runtime smoke workflows are the authorized path for later packaged verification. Local Flutter tests and static analysis remain unrun until a verified SDK surface is available locally or through CI.
