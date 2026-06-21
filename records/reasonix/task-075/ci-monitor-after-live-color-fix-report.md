# CI Monitor Report — Run 27891459215

**Audience:** agent-facing  
**Role ID:** task-075-ci-monitor-after-live-color-fix-worker-resumed  
**Review Owner:** Codex  
**Difficulty Classification:** simple bounded monitoring, release-sensitive gate; flash is sufficient  
**Model Strategy:** deepseek-v4-flash  

---

## Run Overview

| Field | Value |
|---|---|
| **Run ID** | 27891459215 |
| **Run URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27891459215 |
| **Workflow** | PiliAvalon CI |
| **Display Title** | PiliAvalon CI |
| **Head Branch** | `task-075-upstream-stable-merge` |
| **Head SHA** | `ee2241f18fbb3560cc3017a06c3e7dd90b01b4e8` |
| **Status** | `completed` |
| **Conclusion** | `success` |

## Job Conclusions

| Job | ID | Duration | Status | Conclusion |
|---|---|---|---|---|
| Focused Flutter verification | 82535488636 | 3m 34s | `completed` | `success` |
| Build Android x86_64 artifact | 82535675743 | 6m 25s | `completed` | `success` |
| Android emulator runtime smoke | 82536039826 | 2m 50s | `completed` | `success` |

### Job 1: Focused Flutter verification ✅

All 11 steps succeeded, including:
- Install dependencies
- Verify dependency lock is clean
- Run shielding tests
- Run settings model test
- Run recommend settings test
- Run bootstrap startup test
- Analyze

### Job 2: Build Android x86_64 artifact ✅

All steps succeeded:
- Build x86_64 APK
- Stage x86_64 APK
- Upload x86_64 APK

### Job 3: Android emulator runtime smoke ✅

- **Emulator:** API 35, google_apis, x86_64, Pixel 6 profile
- **APK:** `com.example.piliplus.dev`
- **Scenario:** `task075-upstream-merge-ci`
- **Script:** `.github/scripts/android_runtime_smoke.sh`
- **Smoke result:** `result=pass` (adb had expected startup retries before emulator was ready)
- **Evidence uploaded:** `android-runtime-smoke-evidence.zip` (1.26 MB, artifact ID 7771242176)

**Annotation (non-blocking):** Node.js 20 deprecation warning for `actions/download-artifact@v6`.

---

## CI Green Status

✅ **CI green is candidate evidence only.** The following gates all passed:
1. Focused Flutter verification — success
2. Build Android x86_64 artifact — success
3. Android emulator runtime smoke — success (`result=pass`)

## Non-Claims

- **Codex review required:** This CI green report is candidate evidence. Codex must review this artifact before citing its conclusions.
- **No prerelease created:** No prerelease action was taken.
- **No stable release created:** No stable release action was taken.
- **No manual acceptance performed:** User/client acceptance has not been obtained.
- **No merge performed:** Git push, merge, and tag operations were not executed.

---

## Monitoring Notes

- Start time (watch): approx. 2026-06-21T03:02 UTC
- End time: 2026-06-21T03:05:08 UTC (Android emulator runtime smoke completed)
- Monitoring method: `gh run watch --exit-status` (background) with adaptive waits
- No failures, no reruns needed.

Report written by task-075-ci-monitor-after-live-color-fix-worker-resumed.
