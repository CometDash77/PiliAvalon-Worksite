# G0 F2 source map and bounded reuse decision

## Fixed identities

| Item | Exact identity / evidence |
|---|---|
| Nara source | `https://github.com/Starfallan/PiliNara.git` at `a12f5632f80859265056161b1fd1e6a4803b4b1a`; tree `b6b3afeca826e624fa53700fb02c426fc0e94558` |
| Worksite implementation base | `CometDash77/PiliAvalon-Worksite` `origin/main` at `b0eb8dff122ddc86666a98d6a71800ac0af965de`; tree `27673860294a48905d79b9071d29b46725826b23` |
| Nara root license | `LICENSE`, SHA-256 `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809`; GNU GPL v3 title |
| Worksite root license | `LICENSE`, SHA-256 `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809`; same root GPL v3 text |
| Separate file notices | The eight inspected F2 files have no separate SPDX/license header at the fixed Nara pin. Root GPL obligations and source attribution remain applicable. |

The Nara fixed pin is an ancestor of the fixed Nara HEAD for every selected history row in `source-history-ledger.csv`; all eleven supplied F2 seeds plus prerequisite `8873f02d72f7ff852f8eec5a33a0380f4e367d41` were verified reachable from the pin. The ledger records parent SHA, changed files, zero-context hunk anchors, semantic role, final presence and the Worksite adaptation/exclusion decision. It deliberately does not claim that the unrelated 516-commit repository history was audited.

## Eight-file target map

| Worksite file / current seam | Fixed Nara source contract | Bounded adaptation for Worksite |
|---|---|---|
| `lib/utils/storage_key.dart` (`defaultVideoQa` and `defaultVideoQaCellular` currently adjacent at lines 5–6) | Add `SettingBoxKey.defaultVideoQaHalfScreen = 'defaultVideoQaHalfScreen'` beside the existing quality keys. | Add one string constant to the existing `abstract final class`; no enum, migration, or new setter layer. |
| `lib/utils/storage_pref.dart` (existing quality getters around lines 229–237) | Nara getter at lines 447–451 returns nullable: missing and stored `-1` normalize to `null`. | Add the nullable getter after the existing fullscreen/cellular getters. Keep old fullscreen/cellular getter defaults and writes unchanged. Explicit follow still writes `-1`. |
| `lib/pages/setting/models/video_settings.dart` (existing default quality rows around lines 86–99 and dialogs around lines 238–273) | Nara mobile-only row at lines 88–112; labels distinguish half-screen, fullscreen and cellular fullscreen; dialog lines 314–334 offers `(-1, '跟随全屏画质')`. Subtitle reports the network cap. | Add only the mobile row and dialog; rename existing rows to current UI convention. Do not expose the half-screen setting on desktop. Dialog cancellation must not write. |
| `lib/pages/video/controller.dart` (query/default at lines 1019–1029 and available target around lines 1106–1108; `onInit` 530–568; `onClose` 1421–1436) | Nara `setupFullScreenQualitySwitch` and `persistVideoQa` are the semantic core (fixed source lines 388–444), plus media/CID cache reset and current-actual quality comparison. | Preserve Worksite `PlayUrlModel.findAvailableVideoQuality`, supplemental quality acquisition, `updatePlayer` position handling, playback state and existing PIP/quiet/shielding code. Add the helper methods at the existing controller seam, with active owner, bvid/CID, query, fullscreen and disposed checks after awaits. Reset defaults only for a different media/CID; preserve same-media manual choices. |
| `lib/plugin/pl_player/controller.dart` (singleton; `_setFullScreen` at current lines 1324–1327, `triggerFullScreen` finalization at 1405) | Nara adds one callback field and calls it from the central fullscreen state update. | Add one owner-scoped callback field and invocation at the existing `_setFullScreen` seam. Preserve `isFullScreen` Rx and `updateSubtitleStyle`; do not add permanent per-page `ever()` listeners or a lifecycle framework. |
| `lib/plugin/pl_player/view/view.dart` (quality popup around lines 795–868) | Nara final menu delegates quality persistence to `VideoDetailController.persistVideoQa`. | Keep current menu, availability filtering, `cacheVideoQa`, `currentVideoQa` and `updatePlayer`; replace only direct storage routing with the shared controller helper. |
| `lib/pages/video/widgets/header_control.dart` (quality sheet around lines 899–988) | Nara final header menu uses the same persistence route as the player menu. | Make the same minimal replacement as the player popup so both menus share exact routing, temporary-mode behavior and network evaluation. |
| `lib/pages/video/view.dart` (existing `didPushNext`/`didPopNext` at lines 371–440 and `dispose`) | Nara rebinds the fullscreen callback on route return because the player is a singleton. | Rebind through existing `didPopNext`; on disposal clear only if the callback still belongs to this page/controller. Preserve current route pause/resume, media-session, brightness and observer behavior. |

## Semantic contract carried into implementation

1. Mobile online VOD only: effective initial quality is `min(independentHalfScreen, currentNetworkFullscreen)`; follow uses the network fullscreen preference directly. Desktop keeps the existing fullscreen behavior.
2. Missing/null and stored `-1` mean follow; cancellation writes nothing; old keys retain their meaning.
3. Fullscreen entry may upgrade to the resolved available fullscreen target only when it is higher than actual playback. Equal/lower targets do not reload. Fullscreen exit never downgrades. Follow causes no extra transition.
4. Manual quality changes use the current player path. Temporary player configuration writes nothing; desktop writes fullscreen default; mobile independent half-screen writes half-screen; mobile fullscreen/follow writes current-network fullscreen. Both menus use one helper.
5. Different bvid/CID re-evaluates defaults. Same-media manual choices survive layout/orientation changes. Async completions must not reload an inactive/disposed/old owner.
6. Live and local/offline playback are excluded from new switching logic. Existing position, play/pause, codec/audio selection, shielding, quiet behavior, quality supplementation and bootstrap/AI paths are preserved.

## Explicit exclusions

Do not copy Nara's unrelated PiP, AI, danmaku, predictive-back, resolver or dependency changes. Do not replace Worksite's newer resolver with an older inline resolver. Do not add a continuous connectivity subscription, a second player, a GetX lifecycle extension, a dependency fork or a global lifecycle rewrite.

## Verification linkage

The G0 source evidence was produced with read-only `git show`, `git diff`, `git merge-base --is-ancestor`, `git rev-parse`, `git cat-file`, `sha256sum`, and targeted source inspection at the fixed pins. Local Flutter/Android tools are unavailable in this environment; G0 records that limitation rather than treating source inspection as runtime verification. Subsequent G1–G5 evidence must link focused behavioral tests, static analysis, CI/build URLs, exact APK SHA-256 and runtime smoke observations to the final Worksite source SHA.
