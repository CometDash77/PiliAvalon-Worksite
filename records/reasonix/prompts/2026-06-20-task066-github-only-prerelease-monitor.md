First confirm that response instructions / 响应指令 are enabled for this task.

role_id: monitor-github-only-prerelease
target_repo: CometDash77/PiliAvalon-Worksite
target_branch_or_run: task-066-detail-intro-shielding; baseline Build run 27833501793; baseline prerelease v2.0.10-task066-task074-candidate; baseline commit 465952d9c0f64b708dec08dbc6c94e236773ad31; baseline APK versionCode +5169
allowed_commands:
- gh run list -R CometDash77/PiliAvalon-Worksite ...
- gh run view -R CometDash77/PiliAvalon-Worksite ...
- gh release view -R CometDash77/PiliAvalon-Worksite ...
- gh api repos/CometDash77/PiliAvalon-Worksite/...
- git rev-parse ...
- git rev-list --count ...
- git show ...
- Get-Content for repository records and workflows
- rg for repository records and workflows
forbidden_actions:
- Do not run local Flutter, Dart, Gradle, Java build/test commands, or APK download commands.
- Do not download APKs or workflow artifacts locally; use GitHub API metadata only.
- Do not run git push, merge, tag, release mutation, gh workflow run, gh release create/upload/delete, or destructive filesystem commands.
- Do not edit workflow files, governance files, release artifacts, or merge state.
- Do not claim CI green, runtime smoke accepted, APK/prerelease complete, user/client acceptance, merge complete, or parent task closure.
max_iterations: 6
max_time_minutes: 45
usd_cap: 1.50
expected_artifact_category: monitor
expected_artifact_path: records/reasonix/task-066/2026-06-20-github-only-prerelease-monitor.md
review_owner: Codex

Task:
Monitor and summarize the GitHub-only evidence path for a new prerelease based on the user-certified +5169 APK baseline.

Reading scope:
- REASONIX.md
- .reasonix/skills/worksite-reasonix-harness.md if present
- .github/workflows/ci.yml
- .github/workflows/build.yml
- records/codex/task-066/
- records/reasonix/task-066/
- GitHub release v2.0.10-task066-task074-candidate
- GitHub Build run 27833501793
- Any newer PiliAvalon CI or Build workflow_dispatch runs on branch task-066-detail-intro-shielding

Required checks:
1. Confirm baseline +5169 facts from GitHub API metadata only:
   - release tag/name/prerelease/draft state
   - target commit
   - run id and run conclusion
   - APK asset names and sizes
   - signing evidence artifact presence
2. Confirm whether any newer GitHub CI or Build run exists after 27833501793.
3. If Codex creates a newer CI or Build run while you are monitoring, record:
   - run id, url, event, branch, head SHA, status, conclusion
   - job conclusions
   - release tag and APK asset metadata if a new prerelease exists
4. Use long waits only: if a target run is in progress, sleep at least 180 seconds before rechecking. If it is still in progress twice, double the next wait interval.
5. Persist your final report to expected_artifact_path with this shape:
   - reading scope
   - factual findings
   - changes or recommendations
   - risks
   - unknowns
   - verification results
   - whether client decision is needed

Important:
- This is candidate monitor output pending Codex review.
- Only Codex may decide whether evidence is citable or sufficient.
