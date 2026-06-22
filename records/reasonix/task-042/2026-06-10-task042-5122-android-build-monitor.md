# Android Build Monitor Report — task-042-5122-prebuild

**Audience classification:** agent-facing
**Role:** Reasonix (GitHub Actions Monitor)
**Date:** 2026-06-10

## Run Overview

| Field | Value |
|---|---|
| **Run ID** | 27263751328 |
| **URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27263751328 |
| **Event** | workflow_dispatch |
| **Branch** | `task-042-repeat-exposure-prefilter-from-5122` |
| **Head SHA** | `ba9d4569ecc364ac7d5d4d559aaa95acf839a383` |
| **Display Title** | Build |
| **Status** | `completed` |
| **Conclusion** | `success` |

## Job Results

| Job | Status | Duration |
|---|---|---|
| Release Android | ✅ success | 7m 6s |
| ios | — (skipped) | 0s |
| win_x64 | — (skipped) | 0s |
| linux_x64 | — (skipped) | 0s |
| mac | — (skipped) | 0s |

## Prerelease Tag

| Field | Value |
|---|---|
| **Tag** | `task042-5122-prebuild.27263751328` |
| **Type** | prerelease (published) |
| **URL** | https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task042-5122-prebuild.27263751328 |

## APK Assets

The release contains **3 Android APK** artifacts (all signed with fingerprint `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`):

1. `PiliAvalon_android_2.0.8-ba9d4569e+5134_arm64-v8a.apk`
2. `PiliAvalon_android_2.0.8-ba9d4569e+5134_armeabi-v7a.apk`
3. `PiliAvalon_android_2.0.8-ba9d4569e+5134_x86_64.apk`

## Verdict

**Android build/prerelease is ✅ green.** The build succeeded on the correct 5122-based branch, and the prerelease tag with signed APK assets is published.

## Notes

- Node.js 20 deprecation warning for `softprops/action-gh-release@v2` — non-blocking, but should be updated before June 16, 2026.
- This report is Reasonix candidate evidence only. Codex review required before citable use.
