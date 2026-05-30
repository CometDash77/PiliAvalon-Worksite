# Reasonix Inbox Governance

This directory is the fixed Reasonix delivery box for `CometDash77/PiliAvalon-Worksite`.
It lets Codex dispatch multiple Reasonix sessions while keeping their outputs isolated,
unreviewed, and auditable until Codex performs a review gate.

## Directory Contract

- `records/reasonix/inbox/`: the only final artifact drop location Reasonix may write.
- `records/reasonix/reviewed/`: Codex archives artifacts here after review acceptance.
- `records/reasonix/rejected/`: Codex archives malformed, mismatched, or failed artifacts here.
- `records/reasonix/index.json`: Codex-owned review index. Reasonix must not edit it.
- `records/reasonix/templates/artifact-template.md`: required artifact body template.
- `records/reasonix/templates/dispatch-prompt-template.md`: required dispatch prompt template.

Reasonix artifacts are untrusted before Codex review. Before review they may only be
called `unreviewed candidate evidence`, and they must not be treated as facts,
source-of-truth status, acceptance evidence, or release authorization.

## Artifact Naming

Reasonix must write exactly one final artifact per task:

```text
records/reasonix/inbox/<task-id>.ready.md
```

`<task-id>` must use this format:

```text
YYYY-MM-DDTHHMMZ-<role-id>-<topic>-<short-head>
```

Rules:

- Each Reasonix session gets a unique task ID and a unique artifact path.
- No two sessions may write the same file.
- Temporary files may use `.tmp` only inside `records/reasonix/inbox/`.
- Codex only scans final files matching `records/reasonix/inbox/*.ready.md`.
- Reasonix must not move artifacts into `reviewed/` or `rejected/`.

## Required Artifact Headers

Every `.ready.md` artifact must begin with these exact fields:

```text
Status: unreviewed candidate evidence
Task ID:
Role ID:
Target Repo: CometDash77/PiliAvalon-Worksite
Branch:
HEAD:
Allowed Commands:
Forbidden Actions:
Expected Artifact Path:
Review Owner: codex-lead | codex-reviewer
READY_FOR_CODEX_REVIEW: true
```

Codex must reject the artifact if any required header is missing, if
`READY_FOR_CODEX_REVIEW: true` is missing, if the target repo is not
`CometDash77/PiliAvalon-Worksite`, if the branch or HEAD does not match the
review target, or if the expected artifact path does not equal the scanned path.

## Required Artifact Sections

Every artifact must include these sections:

- `Task Declaration`
- `Raw Reasonix Report`
- `Command Transcript`
- `Evidence Pointers`
- `Unknowns`
- `Forbidden Action Check`
- `Candidate Evidence`
- `Gates That Must Remain Yellow/Red`
- `Reasonix Stats / Cost if available`

Artifacts without a raw report or command transcript must be rejected. A summary
alone is not reviewable evidence.

## Codex Review Gate

When the user says "Reasonix ran", "Reasonix finished", or equivalent, Codex must:

1. Scan only `records/reasonix/inbox/*.ready.md`.
2. Validate required headers, path, target repo, branch, HEAD, and ready flag.
3. Validate required body sections, raw report, command transcript, and evidence pointers.
4. Treat every artifact as `unreviewed candidate evidence` until this review completes.
5. Reject malformed, mismatched, stale, or non-reviewable artifacts.
6. Independently verify any claim before using it as evidence.
7. Write accepted or rejected review results to `records/reasonix/index.json`.
8. Archive reviewed artifacts into `records/reasonix/reviewed/` or
   `records/reasonix/rejected/`.

Passing this review gate does not close Android runtime smoke, manual acceptance,
technical-lead review, or 甲方验收. Those gates remain separate and cannot be
closed by Reasonix evidence alone.

## Reasonix Forbidden Actions

Unless a single task prompt explicitly grants a narrow exception, Reasonix must not:

- Edit `records/reasonix/index.json`.
- Move files into `records/reasonix/reviewed/` or `records/reasonix/rejected/`.
- Stage, commit, push, merge, tag, release, or create pull requests.
- Modify files outside the declared artifact path, except for `.tmp` files used to
  prepare that exact artifact.
- Treat its own output as accepted evidence.

## Dispatch Requirements

Every Codex dispatch prompt for Reasonix must include:

- The exact expected artifact path under `records/reasonix/inbox/`.
- The target repo, branch, and HEAD to report.
- Allowed commands and forbidden actions.
- A requirement to enable or confirm response instructions / 响应指令.
- The statement that Reasonix must not edit `records/reasonix/index.json`.
- The statement that Reasonix must not stage, commit, push, merge, or release
  unless that individual task grants explicit authorization.
