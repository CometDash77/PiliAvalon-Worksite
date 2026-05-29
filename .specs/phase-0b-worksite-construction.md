# Phase 0B Worksite Construction Spec

Date: 2026-05-29
Status: yellow-ready

## Goal

Prepare the main worksite for controlled Phase 1 construction without mixing product source, external fork source, and governance history.

## Topology

- Design institute: `/home/mo/Documents/obsidian/VIBECODING项目/Piliavalon`
- Main worksite: `/home/mo/Documents/piliavalon`
- Material yard: `/home/mo/Documents/piliavalon-yard/sources`
- Material manifest: `/home/mo/Documents/piliavalon-yard/manifest/sources-2026-05-29.md`

## Controlled Remotes

- `origin`: `git@github.com:CometDash77/piliavalon-worksite.git`
- `upstream`: `https://github.com/bggRGjQaUbCoE/PiliPlus.git`
- `pilinara`: `https://github.com/Starfallan/PiliNara.git`
- `pilisuper`: `https://github.com/FRBLanApps/PiliSuper.git`

`piliplusx` is intentionally not configured until the precise URL and identity are confirmed.

## Defensive Planning

Construction follows the design institute open-source ethics standard and defensive systems planning:

- keep source provenance traceable
- do not copy GPL fork implementation into product code without a reuse decision
- do not treat parallel work as proof of completion
- define interfaces before Phase 1 feature implementation
- keep verification blockers open until evidence exists

## Verification Boundary

Local Android testing is unavailable in the current environment. The following remain unresolved:

- Flutter/FVM verification or CI substitute
- `flutter pub get`
- `flutter analyze`
- Android APK build
- APK install on a real or approved device
- app launch
- recommendation feed shielding validation
- comment-area shielding validation

These items must not be marked complete in this branch until evidence is added under `.reports/`.
