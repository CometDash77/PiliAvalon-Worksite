audience: agent-facing

# Task-075 Stable Release Report

## Role

`task-075-stable-release-worker`

## Verdict

**v2.0.9+5218 is now a stable release with 3 APK assets. All checks passed.**

## Release Details

| Field | Value |
|---|---|
| Tag | `v2.0.9+5218` |
| Target commit | `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8` |
| Release URL | https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/v2.0.9%2B5218 |
| isPrerelease | `false` |
| isDraft | `false` |
| Release title | `PiliAvalon v2.0.9+5218` |
| Accepted prerelease | `task075-upstream-merge-prebuild.27891774669` |

## Build Evidence

| Run | ID | Conclusion |
|---|---|---|
| CI (prebuild verification) | [27891459215](https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891459215) | success |
| Prebuild Build | [27891774669](https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891774669) | success |
| **Stable Build** | **[27893042963](https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27893042963)** | **success** |

All non-Android jobs (linux_x64, ios, mac, win_x64) were correctly skipped. Release Android job completed all steps successfully.

## APK Assets

| APK | Size |
|---|---|
| `PiliAvalon_android_2.0.9-ee2241f18+5218_arm64-v8a.apk` | 25,421,919 bytes |
| `PiliAvalon_android_2.0.9-ee2241f18+5218_armeabi-v7a.apk` | 25,343,400 bytes |
| `PiliAvalon_android_2.0.9-ee2241f18+5218_x86_64.apk` | 26,399,739 bytes |

## Signing Evidence

All three APKs share the same signing certificate SHA-256 fingerprint:
`0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

Signing evidence artifact `Android_signing_evidence` (2,096 bytes) is archived
in run 27893042963.

## Manual Acceptance

The user manually accepted the prerelease APKs from
`task075-upstream-merge-prebuild.27891774669` and authorized stable promotion.

## Commands Executed

1. `gh api repos/CometDash77/PiliAvalon-Worksite/git/ref/tags/v2.0.9+5218`
   → 404 Not Found (tag did not exist, clean state)
2. `gh release view v2.0.9+5218 -R ... --json ...`
   → release not found
3. `gh api repos/.../git/refs --method POST -f ref='refs/tags/v2.0.9+5218' -f sha='ee2241f...'`
   → tag created
4. `gh workflow run Build -R ... --ref v2.0.9+5218 -f build_android=true ...`
   → dispatched
5. `gh run list -R ... --workflow Build --limit 10 --json ...`
   → identified run 27893042963
6. `gh run view 27893042963 -R ... --json status,conclusion,jobs`
   → success after ~10 min
7. `gh release view v2.0.9+5218 -R ... --json ...`
   → verified 3 APKs, signing evidence in body
8. `gh api repos/.../actions/runs/27893042963/artifacts`
   → confirmed 3 APKs + Android_signing_evidence artifact
9. `gh release edit v2.0.9+5218 -R ... --title '...' --notes-file ... --prerelease=false --latest`
   → promoted to stable
10. `gh release view v2.0.9+5218 -R ... --json tagName,url,isPrerelease,isDraft,targetCommitish,assets`
    → final confirmation: isPrerelease=false, isDraft=false, 3 APKs

## Non-Claims

- This report does not claim user/client acceptance (that was granted before
  this task by the user).
- This report does not claim CI green for non-Android platforms.
- This report does not claim merge, tag mutation, or source code changes.
- No APK assets were downloaded to local disk during this task.
- Codex remains the final reviewer for this report.

## Release Notes

Written to `records/session/2026-06-21-v2.0.9+5218-stable-release-notes.md`
(dual-use, 108 lines, all required sections present).
