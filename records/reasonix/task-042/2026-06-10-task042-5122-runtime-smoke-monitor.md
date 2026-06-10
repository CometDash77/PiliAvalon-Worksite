# Runtime Smoke Monitor Report — Task-042 / 5122 Baseline

- **Audience classification:** agent-facing
- **Reasonix role_id:** github-actions-monitor-task042-5122-runtime-smoke
- **Target repo:** `CometDash77/PiliAvalon-Worksite`
- **Monitored run:** [27264338846](https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27264338846)
- **Branch:** `task-042-repeat-exposure-prefilter-from-5122`
- **Head SHA:** `ba9d4569ecc364ac7d5d4d559aaa95acf839a383`
- **Event:** `workflow_dispatch`
- **Build artifact input (artifact_run_id):** `27263751328`

## Run Status

| Field | Value |
|-------|-------|
| Status | `completed` |
| Conclusion | `success` |
| Job | `Install and launch APK on emulator` — completed in 3m58s |
| Job ID | `80517613830` |
| Emulator | API 35, x86_64, pixel_6, Android 35 google_apis |
| APK | `PiliAvalon_android_2.0.8-ba9d4569e+5134_x86_64.apk` |

## Smoke Test Result

| Variable | Value |
|----------|-------|
| scenario | `task042-5122-repeat-exposure-prebuild` |
| status | `0` |
| result | `pass` |

### Smoke Execution Details

- APK installed successfully via `adb install` (Streamed Install, Success)
- First cold launch: `Status: ok`, `LaunchState: COLD`, `TotalTime: 3597ms`
- Two subsequent warm launches: `Status: ok`, `LaunchState: UNKNOWN (0)`, `TotalTime: 0ms`
- Evidence artifact: `android-runtime-smoke-evidence` uploaded (ID 7530849559, size 2577266 bytes)
- Evidence artifact SHA256: `7ad3d5dea252bca11d981116103d3616ceea137a12fc09f95d74fd81734d712a`

## Verdict

**Runtime smoke is GREEN.** The APK from build run `27263751328` (version `2.0.8-ba9d4569e+5134`) installed and launched successfully on the Android 35 x86_64 emulator. All three launch attempts returned `Status: ok`, and the smoke script exited with `status=0`, `result=pass`.

## Notes

- This is candidate evidence only. Codex must review this report before it is citable evidence.
- Manual/green acceptance gates remain separate.

## Monitoring History

| Check # | Wait Before | Status |
|---------|-------------|--------|
| 1 | — | `in_progress` |
| 2 | 60s | `in_progress` |
| 3 | 120s (doubled after 2 unfinished) | `completed` / `success` |

Total monitoring time: ~4 minutes.
