---
audience: agent-facing
task_id: task-071
role_id: reasonix-build-release-monitor-from-5134
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: 27394918307
review_owner: Codex
created: 2026-06-12
---

# Build + Release Monitor Report — Task-071

## Run Status

| Field          | Value                                                                                     |
|----------------|-------------------------------------------------------------------------------------------|
| **Run ID**     | 27394918307                                                                               |
| **URL**        | https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27394918307               |
| **Branch**     | `task-071-keyword-contains-from-5134`                                                     |
| **Commit**     | `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`                                               |
| **Event**      | `workflow_dispatch`                                                                       |
| **Status**     | `completed`                                                                               |
| **Conclusion** | **`success`**                                                                             |
| **Created**    | 2026-06-12T04:40:29Z                                                                      |
| **Updated**    | 2026-06-12T04:46:54Z                                                                      |

## Jobs

| Job Name             | Conclusion | Details                                                       |
|----------------------|------------|---------------------------------------------------------------|
| Release Android      | `success`  | All 22 steps completed successfully                           |
| ios                  | `skipped`  | Platform not targeted                                        |
| linux_x64            | `skipped`  | Platform not targeted                                        |
| mac                  | `skipped`  | Platform not targeted                                        |
| win_x64              | `skipped`  | Platform not targeted                                        |

## Release Metadata

| Field              | Value                                                                                          |
|--------------------|------------------------------------------------------------------------------------------------|
| **Tag**            | `task071-keyword-contains-prebuild.27394918307`                                                |
| **URL**            | https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task071-keyword-contains-prebuild.27394918307 |
| **Name**           | `task071-keyword-contains-prebuild.27394918307`                                                |
| **Prerelease**     | `true`                                                                                         |
| **Draft**          | `false`                                                                                        |
| **Target Commitish** | `b8106ac60dbf65acb30dfc6b9ab7b9b3aece252e`                                                   |
| **Published**      | 2026-06-12T04:46:42Z                                                                           |

### Remote Assets (no local download)

| Asset Name                                                                                     | Size      | Content Type                        |
|------------------------------------------------------------------------------------------------|-----------|-------------------------------------|
| `PiliAvalon_android_2.0.8-b8106ac60+5136_arm64-v8a.apk`                                       | 25,922,703 | application/vnd.android.package-archive |
| `PiliAvalon_android_2.0.8-b8106ac60+5136_armeabi-v7a.apk`                                     | 25,840,737 | application/vnd.android.package-archive |
| `PiliAvalon_android_2.0.8-b8106ac60+5136_x86_64.apk`                                          | 26,914,176 | application/vnd.android.package-archive |

## Local Artifact Download

**Not performed.** All data was collected from remote GitHub API metadata and release asset names only. No APK files, build artifacts, or release assets were downloaded to the local machine.

## Blocking Issues

**None.** The build run completed successfully. The release was published with the expected tag and all three APK assets were uploaded. No blockers encountered.
