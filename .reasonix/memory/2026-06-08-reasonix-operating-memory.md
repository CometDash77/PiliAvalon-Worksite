---
type: project
title: Worksite Reasonix Operating Memory
date: 2026-06-08
audience: agent-facing
---

# Worksite Reasonix Operating Memory

Reasonix means the installed DeepSeek Reasonix CLI agent, not a Codex-internal subagent. It is a DeepSeek-native terminal coding agent optimized for prefix-cache stability and long-running low-cost sessions.

In this worksite, `reasonix doctor` works only when allowed network access outside the Codex sandbox. The 2026-06-08 health check passed with 9 ok / 0 warn / 0 fail and listed `deepseek-v4-flash` and `deepseek-v4-pro`. A minimal real invocation with `reasonix run --model deepseek-v4-flash --max-steps 4 --dir /home/mo/Documents/piliavalon "Reply exactly REASONIX_RUN_ARG_OK and do not inspect or modify files."` returned `REASONIX_RUN_ARG_OK`. Some configured third-party MCP servers may fail auth/protocol checks during startup; this is not a core Reasonix failure unless the task needs those MCPs.

Official Reasonix documentation checked on 2026-06-08:

- Official site: `https://esengine.github.io/DeepSeek-Reasonix/index.html`
- Official repository: `https://github.com/esengine/DeepSeek-Reasonix`
- CLI reference: `https://github.com/esengine/DeepSeek-Reasonix/blob/main/docs/CLI-REFERENCE.md`
- Architecture guide: `https://github.com/esengine/DeepSeek-Reasonix/blob/main/docs/ARCHITECTURE.md`
- Configuration guide: `https://esengine.github.io/DeepSeek-Reasonix/configuration.html?lang=en`

Official docs describe Reasonix as cache-first and designed for long, cheap sessions: append-only history is aligned to DeepSeek prefix cache so long sessions can keep high cache hit rates and lower input-token cost. Prefer durable sessions when the installed surface supports them reliably, but follow the observed CLI behavior in this worksite before assuming which surface can edit files.

For worksite tasks, Reasonix should receive explicit harness fields: `role_id`, `target_repo`, `target_branch_or_run`, `allowed_commands`, `forbidden_actions`, `expected_artifact_path`, `max_iterations`, `max_time_minutes`, `usd_cap`, and `review_owner`. It must persist candidate reports under `records/reasonix/...` when evidence may be cited.

Codex must explicitly classify task difficulty before choosing a Reasonix model strategy, and must record that judgment in the dispatch prompt and any related coordination or audit report. If the task is simple, bounded, and low-risk, use `deepseek-v4-flash`. If the task is hard, cross-cutting, high-risk, governance-sensitive, release-sensitive, or requires architectural feasibility judgment, use `deepseek-v4-pro`. Use only flags supported by the installed CLI; on 2026-06-08 the observed supported `reasonix run` flags are `--dir`, `--model`, `--max-steps`, `--metrics`, and `--show-thinking`. Do not use stale `-m`, `--effort`, `--budget`, or `--transcript` flags unless `reasonix run --help` in the current environment proves they are available. When the user gives a direct model/effort policy, follow it unless it conflicts with safety, installed CLI reality, or worksite governance. Record any deviation and the reason.

The mandatory Codex/Reasonix division of labor is: Reasonix handles dirty jobs, long jobs, repetitive verification, monitoring, broad read-only audits, and other bounded labor that can be externalized; Codex handles hard planning, coordination, code review, evidence review, and final gate judgment. Codex must not silently absorb dirty or long work just because delegation is inconvenient. If Reasonix delegation is required but unreliable, Codex must repair the delegation path, relaunch with the correct Reasonix surface, or record the blocker and ask for direction rather than doing the dirty/long work itself.

Codex and Reasonix should communicate through persisted result files, not ephemeral chat state. Reasonix outputs should be written under explicit expected artifact paths, usually `records/reasonix/...`; Codex reviews, decisions, and coordination records should be persisted under the appropriate `records/...` path before they are relied on.

For long or implementation-heavy Reasonix collaboration, Codex must first understand the target task and decompose it into atomic slices before delegation. Each Reasonix dispatch should cover one bounded slice with narrow files, explicit acceptance evidence, and its own persisted artifact. Codex should coordinate, plan, review, clarify pace, and integrate the baby-step results toward the final goal. Codex must not implement directly just because it is faster or more convenient. Direct Codex implementation is allowed only after Reasonix demonstrably cannot handle the atomic slice or the Reasonix surface is unavailable, and Codex must ask the user before taking over.

Reliable Reasonix collaboration is mandatory. Before delegating material work, Codex must:

1. Check Reasonix health or use a recently verified health record.
2. Classify task difficulty and choose the model/effort strategy accordingly.
3. Choose the correct Reasonix surface based on current observed behavior, not stale documentation or prior memory.
4. Provide a harnessed prompt with role, repo, branch/run, allowed commands, forbidden actions, expected artifact path, limits, budget, and Codex as review owner.
5. Require relevant project skills and Reasonix subagents for independent dirty/long slices where available.
6. Use clean-home or MCP-isolation tactics when unrelated configured MCP servers block startup, without mutating the user's real global Reasonix config.
7. Require a persisted candidate artifact and review it before citation or final decisions.
8. Use long wait intervals or Reasonix long-task mechanisms such as `/loop` only with clear stop conditions.

Reasonix delegated implementation slices should run in YOLO/edit mode so approval prompts do not stall bounded work. Codex dispatch prompts must explicitly tell Reasonix to use YOLO/edit-auto-free behavior for the allowed slice commands and file edits. If a Reasonix session visibly starts in a non-YOLO or approval-stalling mode, Codex must repair/relaunch that slice before relying on it, rather than letting the task hang.

Reasonix output is candidate evidence until persisted and reviewed by Codex. Reasonix must not claim green, push, merge, release, dispatch workflows without explicit authorization, or close runtime smoke, manual acceptance, technical-lead review, client acceptance, or user acceptance gates.

When asked to finish work through Reasonix, encourage Reasonix to use its own subagents and skills. Reasonix skills can run inline or as isolated subagents using `runAs: subagent`; project skills live under `<project>/.reasonix/skills/`, and Claude-format skills under `<project>/.claude/skills/<name>/SKILL.md` also load.

Reasonix surface selection matters:

- Check `reasonix --help`, `reasonix run --help`, and any needed subcommand help in the current environment before writing a dispatch that depends on flags or behavior.
- 2026-06-21 update record: the user requested the npm `next` train, not
  `latest`. `npm view reasonix dist-tags` with a temporary cache and official
  npm registry returned `latest: 0.53.2`, `canary: 1.8.0-canary.9`, and
  `next: 1.10.0-rc.1`. Install/update with `npm install -g reasonix@next`,
  not `npm install -g reasonix` or `reasonix@latest`, unless the user changes
  that policy.
- 2026-06-21 broken-update symptom: after an interrupted/bad update,
  `reasonix --help`, `reasonix --version`, `reasonix doctor`, and
  `reasonix run ...` exited `0` with no output. Root cause was a corrupted
  global npm package: `~/.nvm/versions/node/v22.22.3/lib/node_modules/reasonix`
  had zero-byte `package.json`, `README.md`, and `bin/reasonix.js`; direct
  `node .../bin/reasonix.js --help` failed with `ERR_INVALID_PACKAGE_CONFIG`.
  Do not treat this as a new normal CLI behavior.
- 2026-06-21 repair path: reinstall `reasonix@next` using a clean temporary
  cache and official npm registry if the configured mirror/cache is corrupt:
  `npm install -g reasonix@next --registry=https://registry.npmjs.org --cache /tmp/reasonix-npm-cache`.
  After install, verify package files are non-zero.
- 2026-06-21 npm package shim caveat: `reasonix@1.10.0-rc.1` installed a
  non-executable `bin/reasonix.js` in this environment. If shell invocations
  fail with `Permission denied`, run
  `chmod +x ~/.nvm/versions/node/v22.22.3/lib/node_modules/reasonix/bin/reasonix.js`
  and re-test.
- 2026-06-21 verified CLI after repair: `reasonix --version` returned
  `reasonix npm-v1.10.0-rc.1`; `reasonix doctor` completed with providers
  `deepseek-flash` and `deepseek-pro` key present; a minimal real invocation
  `reasonix run --dir /home/mo/Documents/piliavalon --model deepseek-pro --max-steps 1 "Reply exactly REASONIX_NEXT_OK"`
  returned `REASONIX_NEXT_OK`.
- 2026-06-21 verified `reasonix run` flags:
  `-c`, `--continue`, `--dir`, `--max-steps`, `--metrics`, `--model`,
  `--resume`, and `--show-thinking`.
- 2026-06-21 config migration: `reasonix doctor` now uses
  `~/.reasonix/config.toml` and warns that legacy
  `~/.config/reasonix/config.toml` is ignored when the new config exists.
  This warning is not a core failure.
- 2026-06-21 plugin behavior: `doctor` lists many configured plugins and
  minimal `reasonix run` may print third-party MCP/plugin warnings such as
  `context canceled`. Treat unrelated plugin warnings as non-core failures
  when the task does not require those plugins.
- On 2026-06-08 in this worksite, `reasonix code --help` printed the `chat` usage and redirected/non-TTY code/chat input failed with `bubbletea: could not open TTY`; TTY paste could stall in composer mode.
- On 2026-06-08 in this worksite, escalated `reasonix run --dir /home/mo/Documents/piliavalon --model deepseek-v4-flash --max-steps 18 "..."` successfully read files and edited `lib/pages/video/widgets/header_control.dart`. It stopped before writing its candidate report because the step cap was too low.
- For bounded filesystem slices here, prefer `reasonix run --dir <repo> --model <model> --max-steps 0 "<harnessed prompt>"` or a generously high `--max-steps` value. If a run stops with `paused after ... tool-call rounds`, relaunch a report-only or continuation slice with a higher/zero step cap instead of manually absorbing Reasonix's report work.
- Use `reasonix chat` only for chat-style work unless current testing proves it can safely perform the requested file work.
- If global MCP config causes startup failures, a temporary clean `HOME` plus `DEEPSEEK_API_KEY` can isolate Reasonix from unrelated configured MCP servers. Do not edit the user's real `~/.reasonix/config.json` just to avoid broken MCP entries.

For long task mode, prefer Reasonix code-mode sessions with explicit budget and durable instructions. Official CLI reference lists `/loop <interval> <prompt>` as the auto-resubmit mechanism for recurring/monitoring work, and `/jobs`, `/logs <id>`, and `/kill <id>` for background job inspection/control. Use `/loop` only with long intervals and clear stop conditions; do not busy-poll. For file-changing work, start with `/plan` or a read-only audit prompt when the task is governance-sensitive or not yet authorized.

For long-running Reasonix or GitHub monitoring, Codex and Reasonix must use long wait/sleep intervals and avoid frequent polling. This applies both to Reasonix's own polling and to Codex while waiting for Reasonix reports: Codex must not repeatedly ask for short status updates or busy-wait on Reasonix. Track consecutive unfinished checks after each sleep/wait cycle. After two consecutive sleep/wait cycles end and the monitored work is still unfinished, double the next wait duration. Reset the unfinished-check counter when the work completes, fails definitively, or meaningful new progress changes the monitoring state. While Reasonix runs, Codex should do non-overlapping coordinator work or wait calmly with the adaptive long wait interval rather than burning tokens.

GitHub Actions monitoring is Reasonix-owned by default. After Codex pushes or dispatches a GitHub verification run, Codex should delegate the monitor loop to Reasonix and wait for a persisted `records/reasonix/...` report. Reasonix should use `gh run list`, `gh run view`, and, when appropriate, `gh run watch` with long wait intervals and clear stop conditions. Codex should not poll GitHub directly unless the user explicitly asks Codex to inspect a run or Reasonix monitoring fails and that failure is recorded.

## Flutter and Dart Skill Memory

For Flutter, Dart, Android Flutter build, widget, layout, routing, localization, JSON serialization, package-conflict, static-analysis, unit-test, widget-test, integration-test, runtime-error, or responsive-layout work, Reasonix must use the project-level Flutter router skill before planning, editing, verifying, reviewing, debugging, testing, refactoring, or delegating implementation work.

At job start, if Reasonix is going to implement, verify, review, debug, refactor, test, or delegate Flutter/Dart work, it must read the router skill and relevant official skill first. The only exception is pure discussion: high-level Q&A, conceptual explanation, option comparison, or brainstorming where no implementation, verification, review, or delegation is being performed.

Official Flutter and Dart skills are installed under `.agents/skills/` from:

- `https://github.com/flutter/skills`
- `https://github.com/dart-lang/skills`

Codex project-level copies live under `.codex/skills/`. Reasonix must use `.reasonix/skills/flutter-official-skill-router.md` as its project-level entry point, then read the relevant `.agents/skills/<skill-name>/SKILL.md` files before acting.

Use the most specific official skill for the task, and combine related skills when appropriate:

- Flutter UI/layout: `flutter-build-responsive-layout`, `flutter-fix-layout-issues`
- Flutter tests/previews: `flutter-add-widget-test`, `flutter-add-integration-test`, `flutter-add-widget-preview`
- Flutter architecture/routing/localization/serialization/HTTP: `flutter-apply-architecture-best-practices`, `flutter-setup-declarative-routing`, `flutter-setup-localization`, `flutter-implement-json-serialization`, `flutter-use-http-package`
- Dart quality/testing/runtime/package work: `dart-run-static-analysis`, `dart-add-unit-test`, `dart-collect-coverage`, `dart-fix-runtime-errors`, `dart-generate-test-mocks`, `dart-resolve-package-conflicts`

Official skills improve implementation quality but do not override worksite governance. Reasonix must still persist candidate evidence under `records/reasonix/...`, use subagents for safe independent slices, avoid claiming green/accepted/released, and use long waits instead of frequent polling. The installation summary flagged `flutter-use-http-package` with a high Snyk risk assessment; inspect that skill before use and prefer existing project HTTP conventions unless the task explicitly requires package changes.
