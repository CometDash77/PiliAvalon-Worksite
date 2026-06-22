# Task-075 Prebuild Monitor Report

**audience**: agent-facing
**role_id**: task-075-prebuild-monitor-worker
**review_owner**: Codex
**report_date**: 2026-06-21

---

## Build Run Summary

| Field | Value |
|-------|-------|
| **Run ID** | 27891774669 |
| **Run URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891774669 |
| **Workflow** | Build |
| **Head branch** | `task-075-upstream-stable-merge` |
| **Head SHA** | `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8` |
| **Status** | completed |
| **Conclusion** | **success** |

---

## Job Results

### Release Android (job 82536334417)
- **Status**: completed
- **Conclusion**: **success**
- **Started**: 2026-06-21T03:07:09Z
- **Completed**: 2026-06-21T03:14:54Z
- **Duration**: ~7 min 45 s

| Step | Name | Conclusion |
|------|------|-----------|
| 1 | Set up job | success |
| 2 | 代码迁出 | success |
| 3 | 构建Java环境 | success |
| 4 | 安装Flutter | success |
| 5 | Apply Patch | success |
| 6 | Write key | success |
| 7 | Set and Extract version | success |
| 8 | Flutter Build Release Apk | success |
| 9 | Flutter Build Dev Apk | skipped |
| 10 | Rename | success |
| 11 | Capture Android signing fingerprints | success |
| 12 | Resolve release tag | success |
| 13 | Release | success |
| 14-16 | 上传 (APK uploads ×3) | success |
| 17 | 上传签名证据 | success |
| 32-35 | Post steps + Complete job | success |

### Other Jobs
| Job | Conclusion |
|-----|-----------|
| mac | skipped |
| ios | skipped |
| linux_x64 | skipped |
| win_x64 | skipped |

---

## Prerelease Tag

| Field | Value |
|-------|-------|
| **Tag name** | `task075-upstream-merge-prebuild.27891774669` |
| **Release name** | `task075-upstream-merge-prebuild.27891774669` |
| **URL** | https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task075-upstream-merge-prebuild.27891774669 |
| **isPrerelease** | **true** |
| **isLatest** | not set (prerelease) |
| **target commitish** | `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8` |

---

## APK Assets (exactly 3)

| # | Asset name | Size (bytes) | Content type |
|---|-----------|-------------|-------------|
| 1 | `PiliAvalon_android_2.0.9-ee2241f18+5218_arm64-v8a.apk` | 25,421,929 | application/vnd.android.package-archive |
| 2 | `PiliAvalon_android_2.0.9-ee2241f18+5218_armeabi-v7a.apk` | 25,343,410 | application/vnd.android.package-archive |
| 3 | `PiliAvalon_android_2.0.9-ee2241f18+5218_x86_64.apk` | 26,399,737 | application/vnd.android.package-archive |

**APK count**: 3 — matches the expected 3 APK requirement.

---

## Signing Evidence

### Release Body
The release body contains a signing evidence table with SHA-256 fingerprints:

| APK | SHA-256 fingerprint |
|-----|-------------------|
| `PiliAvalon_android_2.0.9-ee2241f18+5218_arm64-v8a.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| `PiliAvalon_android_2.0.9-ee2241f18+5218_armeabi-v7a.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| `PiliAvalon_android_2.0.9-ee2241f18+5218_x86_64.apk` | `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |

All 3 APKs share the same signing certificate fingerprint. Cover-install verification requirements are documented in the release body:
- applicationId: `com.example.piliplus`
- same signing certificate fingerprint as the installed release
- install over existing app without uninstall

### Run Artifacts
| Artifact name | Size (bytes) | Expired |
|--------------|-------------|---------|
| `Android_signing_evidence` | 2,095 | false |

---

## Verdict

**Prerelease candidate evidence only.**

- Build run 27891774669 completed successfully with Android Release job passing all steps.
- Prerelease tag `task075-upstream-merge-prebuild.27891774669` exists on GitHub with `isPrerelease=true`.
- Exactly 3 APK assets are attached to the release.
- Signing evidence is present in the release body (SHA-256 fingerprints for all 3 APKs) and as a run artifact.

**Codex review required.** Manual user acceptance pending. Stable remains blocked.
