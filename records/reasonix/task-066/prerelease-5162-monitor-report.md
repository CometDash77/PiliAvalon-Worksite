# Prerelease +5162 Gate Monitoring Report

- **audience:** agent-facing
- **role_id:** task-066-build-prerelease-5162-monitor
- **target_repo:** CometDash77/PiliAvalon-Worksite
- **target_branch:** task-066-detail-intro-shielding
- **review_owner:** Codex
- **monitor_start:** 2026-06-17T05:05:13Z (run createdAt)
- **monitor_end:** 2026-06-17T05:12:15Z (run updatedAt)
- **report_generated:** 2026-06-17 (session time)

---

## Monitoring Status

**PASS** — All +5162 gate checks passed successfully.

---

## Command Table

| # | Command | Exit Code | Purpose |
|---|---|---|---|
| 1 | `gh run list -R CometDash77/PiliAvalon-Worksite --branch task-066-detail-intro-shielding --workflow Build --event workflow_dispatch --limit 5 --json databaseId,headSha,status,conclusion,displayTitle,number,createdAt` | 0 | Locate latest Build workflow_dispatch run |
| 2 | `git cat-file -t acfc3a356d99765b444c849bc26ef4a1332c6ddb` | 0 | Verify commit exists locally |
| 3 | `git rev-list --count acfc3a356d99765b444c849bc26ef4a1332c6ddb` | 0 | Derive versionCode from commit count |
| 4 | `gh run view -R CometDash77/PiliAvalon-Worksite 27667066405 --json status,conclusion,headSha,displayTitle,number,createdAt,updatedAt` | 0 | Check run status (multiple calls) |
| 5 | `gh release view -R CometDash77/PiliAvalon-Worksite task066-prebuild.27667066405 --json tagName,isPrerelease,isDraft,targetCommitish,assets,createdAt,body,name` | 0 | Verify release metadata and assets |

---

## Build Run Facts

| Field | Value |
|---|---|
| **databaseId** | 27667066405 |
| **run number** | 65 |
| **workflow** | Build |
| **event** | workflow_dispatch |
| **branch** | task-066-detail-intro-shielding |
| **head SHA** | `acfc3a356d99765b444c849bc26ef4a1332c6ddb` |
| **status** | completed |
| **conclusion** | success |
| **createdAt** | 2026-06-17T05:05:13Z |
| **updatedAt** | 2026-06-17T05:12:15Z |
| **duration** | ~7 minutes |

---

## Release Facts

| Field | Value |
|---|---|
| **tag** | `task066-prebuild.27667066405` |
| **release name** | `task066-prebuild.27667066405` |
| **isPrerelease** | `true` |
| **isDraft** | `false` |
| **targetCommitish** | `acfc3a356d99765b444c849bc26ef4a1332c6ddb` |
| **createdAt** | 2026-06-17T04:52:47Z |
| **total assets** | 3 |

---

## +5162 Checklist Result

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Locate latest Build workflow_dispatch run | ✅ PASS | Run databaseId=27667066405, number=65 found on branch task-066-detail-intro-shielding |
| 2 | Confirm head SHA = `acfc3a356d99765b444c849bc26ef4a1332c6ddb` | ✅ PASS | headSha from gh run list matches expected SHA |
| 3 | Confirm derived versionCode = 5162 | ✅ PASS | `git rev-list --count acfc3a356d99765b444c849bc26ef4a1332c6ddb` returned 5162 |
| 4 | Build run reaches terminal state | ✅ PASS | status=completed, conclusion=success |
| 5 | Prerelease tag `task066-prebuild.<run_id>` exists | ✅ PASS | Tag `task066-prebuild.27667066405` exists |
| 6 | Release is prerelease=true, draft=false | ✅ PASS | isPrerelease=true, isDraft=false |
| 7 | Release target commit matches head SHA | ✅ PASS | targetCommitish=`acfc3a356d99765b444c849bc26ef4a1332c6ddb` |
| 8 | APK asset names include +5162 | ✅ PASS | All 3 APK assets contain `+5162` in filename (see asset list below) |
| 9 | Android signing evidence present | ✅ PASS | Release body contains SHA-256 fingerprint table with consistent fingerprint `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` across all 3 APKs |
| 10 | No versionCode other than +5162 | ✅ PASS | All asset names and release body reference `+5162` only |

---

## Asset List

| # | Asset Name | Size | Content Type |
|---|---|---|---|
| 1 | `PiliAvalon_android_2.0.8-acfc3a356+5162_arm64-v8a.apk` | 25,932,270 bytes | application/vnd.android.package-archive |
| 2 | `PiliAvalon_android_2.0.8-acfc3a356+5162_armeabi-v7a.apk` | 25,847,903 bytes | application/vnd.android.package-archive |
| 3 | `PiliAvalon_android_2.0.8-acfc3a356+5162_x86_64.apk` | 26,920,483 bytes | application/vnd.android.package-archive |

All assets show version `2.0.8-acfc3a356+5162` (versionCode **5162**).

---

## Release Body — Android Signing Evidence (excerpt)

The release body includes a SHA-256 fingerprint table. The fingerprint is consistent across all three APKs:

```
0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051
```

The release body also documents cover-install verification requirements:
- Same `applicationId: com.example.piliplus`
- Same signing certificate fingerprint as the installed release
- Install over existing app without uninstall

---

## Conclusion

**PASS** — All 10 +5162 gate checks pass.

The Build workflow run (number 65, databaseId 27667066405) on branch `task-066-detail-intro-shielding` completed successfully. The prerelease `task066-prebuild.27667066405` was created with 3 Android APK artifacts, all bearing versionCode `+5162` and consistent signing fingerprints.

**This report is candidate evidence only, pending Codex review.** Reasonix cannot claim green, cannot close acceptance gates, and cannot replace Codex review or user/client acceptance. Codex must review this artifact before citing its conclusions.
