# Phase 1 User Retest Handoff

Date: 2026-05-31

## Status

Ready for user retest after Codex review of Reasonix remote monitor output.
Phase 1 is not green or closed.

## Target Build

- Branch: `phase-1-shielding-acceptance-fixes`
- Commit: `eda5bee71c2a1f0a0d15187d7104b7bda7a5a915`
- Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/26707279023
- Runtime smoke run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/26707550380
- Prebuild release URL:
  https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/phase-1-prebuild.26707279023

## APKs

Use the APK matching the test device ABI from the prebuild release above.

Reasonix recorded these build artifacts:

| ABI | Artifact ID | Name |
| --- | --- | --- |
| x86_64 | `7315162860` | `PiliAvalon_android_2.0.7-eda5bee71+5041_x86_64.apk` |
| armeabi-v7a | `7315162710` | `PiliAvalon_android_2.0.7-eda5bee71+5041_armeabi-v7a.apk` |
| arm64-v8a | `7315162555` | `PiliAvalon_android_2.0.7-eda5bee71+5041_arm64-v8a.apk` |

Most modern physical Android phones use the `arm64-v8a` APK.

## Manual Checklist

1. Install the APK on a real Android device.
2. Launch the app from the launcher icon and confirm there is no white screen.
3. Open the home recommendation feed.
4. Long-press a recommendation card and confirm shielding actions are visible
   for title/content, UP/user, tags/category-related fields, and relevant
   recommendation metadata.
5. Add a shielding rule from a recommendation quick action, return to the feed,
   and confirm matching items are hidden without causing an endless loading loop.
6. Open a video page and confirm related/recommended videos still load.
7. Add or verify a related-video shielding rule and confirm matching related
   videos are hidden.
8. Open comments on a video.
9. Add or verify a comment/user shielding rule and confirm matching comments or
   replies are hidden.
10. Open a direct reply/detail target and confirm the target reply is still
    found before display filtering.
11. Open shielding settings and confirm sections are present:
    `总开关与场景`, `旧规则兼容`, `推荐流`, `评论`, `用户 / UP`, `标签`.
12. Toggle the global shielding switch off and confirm previously hidden items
    can show again after refresh.
13. Toggle recommendation/comment scene switches and confirm each scope gates
    only its intended surface.
14. Restart the app and confirm rules/settings persist.

## Still Pending

- Technical-lead review result.
- User/manual retest result.
- Any final merge decision.

Do not mark Phase 1 green until those are recorded.
