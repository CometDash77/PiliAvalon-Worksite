# CI-5162 Monitor Report

- **audience**: agent-facing
- **role_id**: task-066-ci-5162-github-monitor
- **target_repo**: CometDash77/PiliAvalon-Worksite
- **monitoring_status**: completed

---

## Run Facts

| Field | Value |
|---|---|
| **Run ID** | 27666656062 |
| **Run URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27666656062 |
| **Workflow** | PiliAvalon CI |
| **Branch** | `task-066-detail-intro-shielding` |
| **Target Commit** | `acfc3a356d99765b444c849bc26ef4a1332c6ddb` |
| **Event** | `workflow_dispatch` |
| **Status** | `completed` |
| **Conclusion** | `success` |
| **Created** | 2026-06-17T04:53:25Z |
| **Completed** | 2026-06-17T05:04:06Z |
| **Duration** | ~10m41s |

---

## 5162 / VersionCode Confirmation

- Commit message: `Draft task-066 prebuild 5162 notes`
- `git rev-list --count acfc3a356d99765b444c849bc26ef4a1332c6ddb` → **5162**
- **✅ +5162 confirmed** — commit SHA matches and versionCode is 5162.

---

## Job Conclusion Summary

| Job | Conclusion | Started | Completed | Duration |
|---|---|---|---|---|
| **Focused Flutter verification** | ✅ `success` | 04:53:30Z | 04:55:29Z | 1m59s |
| **Build Android x86_64 artifact** | ✅ `success` | 04:55:31Z | 05:01:35Z | 6m04s |
| **Android emulator runtime smoke** | ✅ `success` | 05:01:43Z | 05:04:06Z | 2m23s |

### Job 1: Focused Flutter verification (81821954104)
All 13 steps passed:
- Set up job, Checkout, Setup Flutter, Flutter version, Install dependencies
- Verify dependency lock is clean
- **Run shielding tests** ✅
- **Run settings model test** ✅
- **Run recommend settings test** ✅
- **Run bootstrap startup test** ✅
- Analyze, Post Setup Flutter, Post Checkout, Complete job

### Job 2: Build Android x86_64 artifact (81822158943)
All 13 steps passed:
- Set up job, Checkout, Setup Java, Setup Flutter, Install dependencies
- Verify dependency lock is clean
- **Build x86_64 APK** ✅
- **Stage x86_64 APK** ✅
- **Upload x86_64 APK** ✅
- Post Setup Flutter, Post Setup Java, Post Checkout, Complete job

### Job 3: Android emulator runtime smoke (81822791400)
All 9 steps passed:
- Set up job, Checkout, Download x86_64 APK artifact, List downloaded APK
- Enable KVM for emulator
- **Android emulator install and launch smoke** ✅
- **Upload runtime smoke evidence** ✅
- Post Checkout, Complete job

---

## Command Table

| # | Command | Exit Code |
|---|---|---|
| 1 | `gh run list -R CometDash77/PiliAvalon-Worksite --branch task-066-detail-intro-shielding --workflow "PiliAvalon CI" --event workflow_dispatch --limit 5 --json databaseId,headSha,displayTitle,status,conclusion,url,createdAt` | 0 |
| 2 | `gh run view 27666656062 -R CometDash77/PiliAvalon-Worksite --json name,headBranch,headSha,displayTitle,status,conclusion,url,event,createdAt,updatedAt,workflowName,number` | 0 |
| 3 | `gh run view 27666656062 -R CometDash77/PiliAvalon-Worksite --json jobs --jq '.jobs[] \| {name, status, conclusion, startedAt, completedAt, stepCount}'` | 0 |
| 4 | `git log --format="%H %s" -1 acfc3a356d99765b444c849bc26ef4a1332c6ddb` | 0 |
| 5 | `git rev-list --count acfc3a356d99765b444c849bc26ef4a1332c6ddb` | 0 |
| 6 | `gh run watch 27666656062 -R CometDash77/PiliAvalon-Worksite` (background) | 0 |
| 7 | `gh run view 27666656062 -R CometDash77/PiliAvalon-Worksite --json conclusion,status,url,headSha,headBranch,event,createdAt,updatedAt,workflowName,displayTitle` | 0 |
| 8 | `gh run view 27666656062 -R CometDash77/PiliAvalon-Worksite --json jobs --jq '.jobs[] \| {name, conclusion, startedAt, completedAt}'` | 0 |

---

## Conclusion

**✅ PASS** — Run 27666656062 completed with conclusion `success`. All 3 jobs passed:
1. Focused Flutter verification (shielding tests, settings model test, recommend settings test, bootstrap startup test, analyze)
2. Build Android x86_64 APK
3. Android emulator runtime smoke

**+5162 confirmed** — commit `acfc3a356d99765b444c849bc26ef4a1332c6ddb`, versionCode 5162.

---

> ⚠️ **This is candidate evidence only, pending Codex review.** Reasonix cannot claim green, cannot close acceptance, cannot push, cannot merge, cannot release. Codex is the review owner for evidence review, final gate judgment, commit, push, workflow dispatch, release, and client acceptance.
