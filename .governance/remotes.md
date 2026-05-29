# Worksite Remote Policy

Date: 2026-05-29
Status: active

## Allowed Remotes

- `origin`: write target for the worksite repository.
- `upstream`: read-only PiliPlus baseline.
- `pilinara`: read-only reference remote.
- `pilisuper`: read-only reference remote.

## Deferred Remote

- `piliplusx`: not configured. The candidate URL `https://github.com/gucooing/PiliPlus.git` remains identity-unconfirmed and lives only in the material yard.

## Rules

- Reference remotes must have push disabled.
- Fork code must not be merged wholesale.
- Any code-level reuse requires an updated reuse decision before implementation.
- Upstream sync must be reviewed before merge into product `main`.
