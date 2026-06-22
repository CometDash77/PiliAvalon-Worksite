---
audience: agent-facing
record_type: acceptance-cleanup
task: task-065
status: manual-acceptance-passed-cleanup-complete
created: 2026-06-13
review_owner: Codex
---

# Task-065 App Stat Fix Acceptance Cleanup

## Manual Acceptance

- Accepted prebuild: `task065-app-stat-fix-prebuild.27460023543`
- Version: `2.0.8-1093b29be+5149`
- Target commit: `1093b29be0a417663ca098188514d84875af7b13`
- User acceptance status: passed

Raw user feedback:

```text
验收通过了，删除掉5149之前的prelease防差错直到上一个可用无bug位置，然后写file给设计院，接着commit and push
```

## Cleanup Scope

Deleted superseded task-065 prerelease releases and remote tags:

- `task065-home-feed-prebuild.27455813313`
- `task065-ci-recheck-2-prebuild.27457599604`
- `task065-inline-filters-prebuild.27459281224`

Preserved:

- `task065-app-stat-fix-prebuild.27460023543`
- `task071-keyword-contains-prebuild.27394918307`
- all git commits

## Verification

- `gh release list -R CometDash77/PiliAvalon-Worksite --limit 10 --json tagName,isPrerelease,isDraft,name,publishedAt`
  shows `task065-app-stat-fix-prebuild.27460023543` and
  `task071-keyword-contains-prebuild.27394918307` as the newest relevant
  prereleases.
- `git ls-remote --tags origin ...` shows only the preserved 5149 and 5136
  tags among the checked task-065/task-071 tag set.
- `git log --oneline -8` confirms intermediate task-065 commits remain in
  branch history.

## Design Institute Communication

Written:

`records/worksite-communications/2026-06-13-task065-app-stat-fix-acceptance-to-design-institute.md`

## Boundary

This cleanup does not create a stable release and does not accept the broader
task-025 page-series scope.
