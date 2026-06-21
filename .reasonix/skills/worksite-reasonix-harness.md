---
description: Use this worksite harness for bounded PiliAvalon verification, monitoring, implementation, or evidence-audit tasks.
runAs: subagent
---

# Worksite Reasonix Harness

Use this skill when Codex delegates PiliAvalon worksite labor to Reasonix.

Every task prompt must include:

- `role_id`
- `target_repo: CometDash77/PiliAvalon-Worksite`
- `target_branch_or_run`
- `allowed_commands`
- `forbidden_actions`
- `expected_artifact_path`
- `max_iterations`
- `max_time_minutes`
- `usd_cap`
- `review_owner: Codex`

Installed CLI guidance:

- Prefer the installed, tested syntax over older notes.
- Current verified CLI on 2026-06-21: `reasonix npm-v1.10.0-rc.1`
  installed from the npm `next` dist-tag (`reasonix@next`, resolved to
  `1.10.0-rc.1` at verification time). Do not install npm `latest` when the
  user requests the next train.
- On 2026-06-21 after reinstalling `reasonix@next`, the npm package shim
  `bin/reasonix.js` lacked the executable bit. If `reasonix --help` returns
  `Permission denied`, run:
  `chmod +x ~/.nvm/versions/node/v22.22.3/lib/node_modules/reasonix/bin/reasonix.js`
  and re-test.
- If `reasonix` exits `0` with no output, inspect the npm package files. On
  2026-06-21 this meant `package.json`, `README.md`, and `bin/reasonix.js`
  were all zero bytes after a broken update. Repair by reinstalling
  `reasonix@next` from npm with a clean cache.
- If npm registry access through `registry.npmmirror.com` returns
  `EINTEGRITY`, `ENOENT`, or zero-byte metadata, use a temporary cache and
  official npm registry for metadata/install:
  `npm view reasonix@next version dist.tarball bin --registry=https://registry.npmjs.org --cache /tmp/reasonix-npm-cache`
  and
  `npm install -g reasonix@next --registry=https://registry.npmjs.org --cache /tmp/reasonix-npm-cache`.
- On 2026-06-21 the reliable headless filesystem surface remained
  `reasonix run --dir <repo> --model <model> --max-steps <N> "<prompt>"`.
  A minimal verified run returned `REASONIX_NEXT_OK`.
- Use a generous `--max-steps` value or `--max-steps 0` for implementation plus report slices. A low cap can pause after edits but before the required candidate report is written.
- Verified `reasonix run` flags on 2026-06-21:
  `--dir`, `--model`, `--max-steps`, `--metrics`, `--show-thinking`,
  `-c/--continue`, and `--resume <session-file>`.
- Do not use stale `-m`, `--effort`, `--budget`, or `--transcript` flags unless `reasonix run --help` in the current environment proves they are supported.
- If a run pauses after reaching `max_steps`, continue with a narrow report-only or continuation prompt instead of redoing completed work.
- `reasonix doctor` now reads `~/.reasonix/config.toml`; it may warn that
  legacy `~/.config/reasonix/config.toml` exists and is ignored. Treat this as
  configuration migration information, not a failure.
- Third-party MCP/plugin startup warnings are not a core Reasonix failure when
  the requested task does not need those plugins.

Authority boundaries:

- Output is candidate evidence only until persisted under `records/reasonix/...` and reviewed by Codex.
- Do not claim green, accepted, closed, merged, released, or user/client approved.
- Do not push, merge, release, tag, mutate workflow definitions, or close runtime smoke, manual acceptance, technical-lead review, client acceptance, or user acceptance gates.
- Do not edit governance policy unless the user explicitly authorizes a governance-model change and Codex records the new rule.

Division of labor:

- Reasonix owns simple, repeat, and dirty jobs.
- Reasonix should use its own subagents aggressively to improve speed and coverage when tasks can be split safely.
- Codex owns hard, planning, and review jobs.
- Codex and Reasonix communicate through persisted result files, not ephemeral chat state.

Quality expectations:

- Use relevant Reasonix skills and isolated subagents when they improve coverage.
- Split independent audit, implementation, verification, and monitor work across subagents when write scopes do not conflict.
- Own GitHub Actions monitoring when Codex delegates it. Use `gh run list`, `gh run view`, and, when appropriate, `gh run watch` with long waits and clear stop conditions; avoid frequent polling.
- Persist final reports under the exact expected path, with reading scope, commands, factual findings, risks, unknowns, verification results, and client-decision needs.
