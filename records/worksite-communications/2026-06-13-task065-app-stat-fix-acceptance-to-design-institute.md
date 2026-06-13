---
audience: dual-use
record_type: worksite-to-design-institute
task: task-065
status: manual-acceptance-passed
created: 2026-06-13
source_repo: CometDash77/PiliAvalon-Worksite
review_owner: Codex
---

# Task-065 App Stat Fix Acceptance Report

## User-Facing Summary

用户已手动验收通过 `task065-app-stat-fix-prebuild.27460023543`
（`2.0.8-1093b29be+5149`）。

本轮修复确认解决了 App 首页推荐流中“时长过滤生效，但播放量过滤和弹幕量过滤不生效”的覆盖缺口。
旧的 task-065 中间 prerelease 已从 GitHub Releases 和远程 tag 删除，避免误装错误版本；相关 git commit 历史保留。

当前保留的可用包：

- 最新验收通过包：
  `task065-app-stat-fix-prebuild.27460023543`
- 上一个可回退的无 bug 基线：
  `task071-keyword-contains-prebuild.27394918307`

## Technical Body

### Accepted Prebuild

- Release tag: `task065-app-stat-fix-prebuild.27460023543`
- Release URL: https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/task065-app-stat-fix-prebuild.27460023543
- Version: `2.0.8-1093b29be+5149`
- Target commit: `1093b29be0a417663ca098188514d84875af7b13`
- Commit message: `Fix task-065 app recommendation stat shielding`
- Manual acceptance: passed by user

### Automation Evidence

- CI run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27460023543
- CI conclusion: `success`
- Build run: https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/27460282784
- Build conclusion: `success`
- Worksite evidence:
  `records/session/2026-06-13-task065-app-stat-fix-prebuild-5149-release-evidence.md`
- Reasonix monitor:
  `records/reasonix/2026-06-13/task-065-app-stat-fix-ci-build-monitor.md`

### User Acceptance Result

Raw user acceptance feedback:

```text
验收通过了，删除掉5149之前的prelease防差错直到上一个可用无bug位置，然后写file给设计院，接着commit and push
```

Interpretation:

- Manual acceptance passed for the 5149 prerelease.
- The user requested cleanup of superseded task-065 prereleases before 5149,
  stopping at the previous known good baseline.
- Commit history must be preserved.

### Cleanup Completed

Deleted GitHub Releases and remote tags:

- `task065-home-feed-prebuild.27455813313`
- `task065-ci-recheck-2-prebuild.27457599604`
- `task065-inline-filters-prebuild.27459281224`

Preserved:

- `task065-app-stat-fix-prebuild.27460023543`
- `task071-keyword-contains-prebuild.27394918307`
- all git commits on `task-071-keyword-contains-from-5134`

Verification:

- `gh release list -R CometDash77/PiliAvalon-Worksite --limit 10 --json tagName,isPrerelease,isDraft,name,publishedAt`
  shows 5149 and 5136 as the newest relevant prereleases.
- `git ls-remote --tags origin ...` shows 5149 and 5136 tags only among the checked relevant tags.
- `git log --oneline -8` still shows the intermediate task-065 commits, including the 5147 evidence commit.

### Scope Boundary

This report does not mark the broader `task-025` page-series scope accepted.
It reports only the task-065 homepage/recommend-feed acceptance result for the
current App stat fix prerelease.

Stable release was not created.
