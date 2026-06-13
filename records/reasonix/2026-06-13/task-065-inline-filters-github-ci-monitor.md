# Task-065: Inline Filters — GitHub CI Monitor Report

**Audience:** agent-facing
**Date:** 2026-06-13
**Agent:** Reasonix (monitor role)
**Run ID:** 27458819019
**Review Owner:** Codex

---

## Run Summary

| Field | Value |
|---|---|
| **Workflow** | PiliAvalon CI |
| **Run ID** | 27458819019 |
| **Run URL** | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27458819019 |
| **Head Branch** | `task-071-keyword-contains-from-5134` |
| **Head SHA** | `50e9f28b8ae019d1060f0cec44951c243dcfbf3e` |
| **Trigger** | `workflow_dispatch` |
| **Created** | 2026-06-13T06:15:34Z |
| **Completed** | 2026-06-13T06:26:30Z |
| **Total Duration** | ~11 minutes |
| **Workflow Conclusion** | **success** |

---

## Job Conclusions

| Job | ID | Duration | Conclusion |
|---|---|---|---|
| Focused Flutter verification | 81168355224 | 2m11s | ✅ **success** |
| Build Android x86_64 artifact | 81168493556 | 6m11s | ✅ **success** |
| Android emulator runtime smoke | 81168892166 | 2m26s | ✅ **success** |

### Per-Job Step Details

**1. Focused Flutter verification** (81168355224) — ✅ success in 2m11s
- Set up job ✓, Checkout ✓, Setup Flutter ✓, Flutter version ✓
- Install dependencies ✓, Verify dependency lock is clean ✓
- Run shielding tests ✓, Run settings model test ✓, Run recommend settings test ✓
- Run bootstrap startup test ✓, Analyze ✓
- Post Setup Flutter ✓, Post Checkout ✓, Complete job ✓

**2. Build Android x86_64 artifact** (81168493556) — ✅ success in 6m11s
- Set up job ✓, Checkout ✓, Setup Java ✓, Setup Flutter ✓
- Install dependencies ✓, Verify dependency lock is clean ✓
- Build x86_64 APK ✓, Stage x86_64 APK ✓, Upload x86_64 APK ✓
- Post Setup Flutter ✓, Post Setup Java ✓, Post Checkout ✓, Complete job ✓

**3. Android emulator runtime smoke** (81168892166) — ✅ success in 2m26s
- Set up job ✓, Checkout ✓, Download x86_64 APK artifact ✓
- List downloaded APK ✓, Enable KVM for emulator ✓
- Android emulator install and launch smoke ✓, Upload runtime smoke evidence ✓
- Post Checkout ✓, Complete job ✓

---

## Annotations (Non-blocking)

A deprecation warning was emitted for `actions/download-artifact@v6` running on Node.js 20:
> Node.js 20 actions are deprecated... Node.js 20 will be removed from the runner on September 16th, 2026.

This is a non-blocking infrastructure notice; no action required for this task.

---

## Evidence Status

- **All three jobs passed** — Flutter verification, Android APK build, and emulator runtime smoke.
- This report documents **automation evidence only**.
- **Manual acceptance remains pending.**
- **Codex review of this artifact is required** before citing its conclusions.

---

## Notes

- Monitoring used `gh run watch` with 30-second intervals and adaptive sleep waits (2m, 2m, 4m breakdowns due to tool timeout limits).
- No failures detected at any job or step level.
- The head branch `task-071-keyword-contains-from-5134` and SHA `50e9f28b8ae019d1060f0cec44951c243dcfbf3e` match the expected task branch.
