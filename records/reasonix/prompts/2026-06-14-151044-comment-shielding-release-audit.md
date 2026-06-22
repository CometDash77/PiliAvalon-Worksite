First confirm that response instructions / 响应指令 are enabled for this task.

role_id: auditor
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: local path C:/Users/77182/Documents/Coding/piliavalon, branch production, staged diff against HEAD
allowed_commands:
- git status --short --branch
- git diff --cached --stat
- git diff --cached --name-status
- git diff --cached -- <path>
- git log --oneline --decorate -5
- rg <pattern> <paths>
- Get-Content -Raw <repo-relative file>
- flutter test --no-pub <focused test paths>
- flutter analyze --no-fatal-infos
forbidden_actions:
- no git push, merge, release, tag, workflow dispatch, or PR mutation
- no edits outside records/reasonix/auditor/2026-06-14-comment-shielding-release-audit.md
- no workflow, governance, design-institute, release artifact, or git state mutations
- do not claim CI green, runtime smoke accepted, prerelease complete, release readiness, client acceptance, or task closure
max_iterations: 1
max_time_minutes: 45
usd_cap: 0.50
expected_artifact_category: auditor
expected_artifact_path: records/reasonix/auditor/2026-06-14-comment-shielding-release-audit.md
review_owner: Codex

Task:
Read .reasonix/skills/worksite-reasonix-harness.md first, then inspect the current staged diff for the comment shielding change set and current release readiness.

Write exactly one auditor artifact to:
records/reasonix/auditor/2026-06-14-comment-shielding-release-audit.md

Your artifact must use this shape:
- reading scope
- factual findings
- changes or recommendations
- risks
- unknowns
- verification results, including command strings and exit codes if commands were run
- whether client decision is needed

Focus checks:
1. Verify whether the staged diff implements comment shielding config, matcher, settings route/page, reply filtering, decoration rule support, and video-card quick-action boundaries without recommendation/video metadata leakage.
2. Verify whether tests in the staged diff cover the new behavior sufficiently for local release-prep confidence.
3. Identify any blockers before Codex commits, pushes, dispatches GitHub Actions, or creates a prerelease.
4. Do not make release decisions. Provide candidate evidence only.
