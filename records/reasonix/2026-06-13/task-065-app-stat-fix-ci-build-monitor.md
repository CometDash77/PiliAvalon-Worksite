# Task-065 App Stat Fix — CI + Build + Prerelease Monitor Report

**Audience:** agent-facing
**Date:** 2026-06-13
**Role:** reasonix-task065-app-stat-fix-ci-prebuild-monitor
**Target repo:** CometDash77/PiliAvalon-Worksite
**Review owner:** Codex

---

## Summary

CI run succeeded → build dispatched → build succeeded → prerelease verified with APK assets. Manual acceptance remains pending.

---

## 1. CI Run

| Field | Value |
|---|---|
| **Run ID** | 27460023543 |
| **URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27460023543 |
| **Head SHA** | 1093b29be0a417663ca098188514d84875af7b13 |
| **Head branch** | task-071-keyword-contains-from-5134 |
| **Dislay title** | PiliAvalon CI |
| **Status** | completed |
| **Conclusion** | success |

**Jobs:**
- Focused Flutter verification — success
- Build Android x86_64 artifact — success
- Android emulator runtime smoke — completed (success inferred)

**Commands used:**
```shell
gh run view 27460023543 -R CometDash77/PiliAvalon-Worksite --json status,conclusion,headSha,headBranch,displayTitle,url
gh run view 27460023543 -R CometDash77/PiliAvalon-Worksite --json jobs
```

**Monitoring:** Used adaptive waits (120s → 120s → 240s) per policy. Three checks before completion. CI completed with success.

---

## 2. Build Dispatch

After CI success, build.yml was dispatched:

```shell
gh workflow run build.yml -R CometDash77/PiliAvalon-Worksite \
  --ref task-071-keyword-contains-from-5134 \
  -f build_android=true \
  -f build_ios=false \
  -f build_mac=false \
  -f build_win_x64=false \
  -f build_linux_x64=false \
  -f tag=task065-app-stat-fix-prebuild.$(gh run view 27460023543 -R CometDash77/PiliAvalon-Worksite --json databaseId --jq .databaseId)
```

Result: build.yml workflow run created.

---

## 3. Build Run

| Field | Value |
|---|---|
| **Run ID** | 27460282784 |
| **URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27460282784 |
| **Head SHA** | 1093b29be0a417663ca098188514d84875af7b13 |
| **Head branch** | task-071-keyword-contains-from-5134 |
| **Dislay title** | Build |
| **Status** | completed |
| **Conclusion** | success |

**Jobs:**
- Release Android — success (all steps green: checkout, Java, Flutter, patch, key, version extract, APK build, rename, signing capture, tag resolve, release, APK uploads, signing evidence upload)
- linux_x64 — skipped (as configured)
- ios — skipped
- mac — skipped
- win_x64 — skipped

**Commands used:**
```shell
gh run list -R CometDash77/PiliAvalon-Worksite --workflow build.yml --branch task-071-keyword-contains-from-5134 --limit 1 --json databaseId,status,conclusion,headSha,headBranch,displayTitle,url
gh run view 27460282784 -R CometDash77/PiliAvalon-Worksite --json status,conclusion,headSha,url
gh run view 27460282784 -R CometDash77/PiliAvalon-Worksite --json jobs
```

**Monitoring:** Used adaptive waits (120s → 120s → 240s). Three checks before completion.

---

## 4. Prerelease Verification

| Field | Value |
|---|---|
| **Tag** | task065-app-stat-fix-prebuild.27460023543 |
| **URL** | https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-app-stat-fix-prebuild.27460023543 |
| **Name** | task065-app-stat-fix-prebuild.27460023543 |
| **Is prerelease** | true |
| **Is draft** | false |
| **APK assets** | 3 uploaded |

**APK Assets:**
1. `PiliAvalon_android_2.0.8-1093b29be+5149_arm64-v8a.apk` (25.9 MB)
2. `PiliAvalon_android_2.0.8-1093b29be+5149_armeabi-v7a.apk` (25.8 MB)
3. `PiliAvalon_android_2.0.8-1093b29be+5149_x86_64.apk` (26.9 MB)

**Commands used:**
```shell
gh release list -R CometDash77/PiliAvalon-Worksite --limit 20 --json tagName,isPrerelease,isDraft,name
gh release view task065-app-stat-fix-prebuild.27460023543 -R CometDash77/PiliAvalon-Worksite --json tagName,isPrerelease,isDraft,name,url,assets
```

---

## 5. Manual Acceptance Status

**Pending.** No manual acceptance has been performed. This report only covers CI verification, build, and prerelease creation.

---

## 6. Commands Used (Complete List)

All commands executed with `-R CometDash77/PiliAvalon-Worksite`:

```shell
gh run view 27460023543 -R CometDash77/PiliAvalon-Worksite --json status,conclusion,headSha,headBranch,displayTitle,url
gh run view 27460023543 -R CometDash77/PiliAvalon-Worksite --json jobs
gh workflow run build.yml -R CometDash77/PiliAvalon-Worksite --ref task-071-keyword-contains-from-5134 -f build_android=true -f build_ios=false -f build_mac=false -f build_win_x64=false -f build_linux_x64=false -f tag=task065-app-stat-fix-prebuild.$(gh run view 27460023543 -R CometDash77/PiliAvalon-Worksite --json databaseId --jq .databaseId)
gh run list -R CometDash77/PiliAvalon-Worksite --workflow build.yml --branch task-071-keyword-contains-from-5134 --limit 1 --json databaseId,status,conclusion,headSha,headBranch,displayTitle,url
gh run view 27460282784 -R CometDash77/PiliAvalon-Worksite --json status,conclusion,headSha,url
gh run view 27460282784 -R CometDash77/PiliAvalon-Worksite --json jobs
gh release list -R CometDash77/PiliAvalon-Worksite --limit 20 --json tagName,isPrerelease,isDraft,name
gh release view task065-app-stat-fix-prebuild.27460023543 -R CometDash77/PiliAvalon-Worksite --json tagName,isPrerelease,isDraft,name,url,assets
```

---

## 7. Risks and Unknowns

- Manual acceptance has not been performed — no claim can be made that the playback-count / danmaku-count filtering fix works in the App.
- The prerelease APKs are from commit 1093b29b (version 2.0.8-1093b29be+5149) on branch task-071-keyword-contains-from-5134.
- No iOS/Mac/Windows/Linux builds were requested or produced.
