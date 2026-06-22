Audience classification: agent-facing

# Reasonix Coordination Protocol

This project uses Reasonix as the primary implementation, verifier, monitor,
and auditor labor agent where practical. Codex is the coordinator and reviewer.

## Current Operating Rule

- Codex handles planning, replanning, dispatch prompts, artifact review,
  evidence decisions, git push, workflow dispatch, prerelease authority, and
  final reports.
- Reasonix performs implementation and verification labor as much as possible.
- Reasonix complex/substantial work is plan-gated: it must first produce a
  read-only plan, Codex must review and approve or revise that plan, and only
  then may Reasonix execute side-effecting commands or edits.
- Codex and Reasonix communicate through persisted project files, not ephemeral
  session chat.
- Use `records/codex/coordination/` for Codex work ledgers and dispatch notes.
- Use `records/reasonix/prompts/` for Reasonix prompts.
- Use `records/reasonix/task-*/`, `records/reasonix/verifier/`, or
  `records/reasonix/monitor/` for Reasonix outputs.
- Use `records/reasonix/review/` for Codex reviews of Reasonix outputs.

## Next Session Defaults

- Current verified Reasonix train: npm `next`, not `latest`. On 2026-06-21
  `reasonix@next` resolved to `1.10.0-rc.1` and `reasonix --version` returned
  `reasonix npm-v1.10.0-rc.1`.
- If Reasonix exits `0` with no output after an update, inspect the global npm
  package. On 2026-06-21 this meant the installed package files were zero
  bytes. Reinstall `reasonix@next` with a clean temporary cache; do not fall
  back to npm `latest`.
- If `reasonix --help` fails with `Permission denied`, restore executable bit
  on the shim:
  `chmod +x ~/.nvm/versions/node/v22.22.3/lib/node_modules/reasonix/bin/reasonix.js`.
- Verified `reasonix run` flags on 2026-06-21:
  `--dir`, `--model`, `--max-steps`, `--metrics`, `--show-thinking`,
  `-c/--continue`, and `--resume`.
- `reasonix doctor` now prefers `~/.reasonix/config.toml` and may warn that
  legacy `~/.config/reasonix/config.toml` is ignored. Treat unrelated
  third-party MCP/plugin warnings as non-core unless the task needs those
  plugins.
- If the next session is mainly testing or verification, prefer GitHub Actions
  and prerelease evidence over local Flutter loops for final proof.
- If waiting is needed, use `Start-Sleep` or sleep intervals of at least
  3 minutes; after two still-in-progress checks, double the next wait.
- If monitoring is needed, dispatch or command `reasonix` as the monitor and
  require a persisted report file under `records/reasonix/monitor/`.
- On Windows, do not launch `reasonix` directly with `Start-Process -FilePath
  'reasonix'`; it resolves to a PowerShell shim and can fail as an invalid
  Win32 application. For background runs with logs, launch `powershell.exe` and
  pipe the prompt into `reasonix run`, for example:
  `Get-Content -Raw -Encoding UTF8 <prompt> | reasonix run --model <model>
  --max-steps <n>`.
- The local Reasonix version supports `reasonix config auto-plan [off|on]`.
  This repository keeps `agent.auto_plan = "on"` in `reasonix.toml`. In
  interactive Reasonix frontends, complex-looking tasks should enter read-only
  plan mode and wait for controller approval before edits or side-effecting
  commands. Non-interactive `reasonix run` remains autonomous, so Codex
  automation must emulate the gate with two explicit runs: a plan-only run that
  writes a plan artifact, followed by a separate execution run only after Codex
  records approval.
- In plan-only runs, Reasonix must stop immediately after writing the requested
  plan artifact. It must not run follow-up listing/status/self-verification
  commands after the write; Codex verifies the artifact separately.
- If a report-only Reasonix run repeatedly pauses before writing the artifact,
  narrow the prompt to "write the expected artifact now" before increasing
  `--max-steps`; broad prompts plus low step caps waste cycles on investigation
  and internal checklist bookkeeping.

## Reasonix Usage Standard

Every substantial Reasonix dispatch should instruct Reasonix to:

- read `.reasonix/skills/worksite-reasonix-harness.md`;
- use relevant `.reasonix/skills/*.md` skills;
- for implementation, verification with side effects, or other substantial
  labor, first write a plan artifact under `records/reasonix/plans/` or the
  task-specific `records/reasonix/task-*/` directory and stop for Codex review;
- execute only after the dispatch references a Codex-reviewed approved plan
  artifact;
- use subagents where the task has independent read, implementation,
  verification, or audit slices;
- record which skills/subagents were used or why they were not used;
- sleep or wait with long intervals for long-running work instead of busy
  polling;
- when a sleep/wait ends and the task is still in progress twice, double the
  next sleep/wait duration;
- Codex sleep intervals while Reasonix works must be at least 3 minutes;
- Reasonix dispatches may request YOLO/edit-auto-free behavior only in the
  post-approval execution run, when the slice scope allows edits and the
  forbidden-action boundary is explicit;
- persist an artifact with reading scope, factual findings, files changed,
  commands and exit codes, risks, unknowns, and client-decision needs.

## Local Flutter Policy

This environment has local Flutter available. Local focused tests may be used
as development feedback and should be recorded with exact commands and exit
codes. Local test/build/release output is not final acceptance proof for
Task-020; final proof still requires GitHub Actions and prerelease/APK evidence.

## Authority Boundary

Reasonix must not:

- run `git push`, merge, tag, publish releases, or mutate workflow files;
- claim CI green, runtime smoke accepted, APK/prerelease complete, user/client
  acceptance, merge complete, or parent task closure;
- edit governance/design-institute files unless explicitly authorized;
- cite unpersisted chat text as evidence.

Codex must review persisted Reasonix artifacts before citing their conclusions.

## Context Hygiene

- Keep chat updates short.
- Store durable context in project files.
- Prefer referencing persisted files over pasting long instructions into chat.
- When waiting on Reasonix or CI, use long waits/sleep rather than repeated
  polling.
- Prefer launching Reasonix as a background job that writes a report to the
  requested artifact path and stdout/stderr logs under `records/reasonix/logs/`.
- Codex should continue coordination, review, and non-overlapping checks while
  Reasonix runs, then scan the requested report path after timed sleeps.
