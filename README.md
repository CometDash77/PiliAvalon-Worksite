# Piliavalon Worksite Governance

This orphan branch stores construction governance for the Piliavalon worksite. Product source stays on `main`.

## Branch Rules

- `main` contains product source.
- `governance` contains `.specs/`, `.reports/`, `.governance/`, `.github/workflows/`, and read-only dashboard files.
- External source repositories stay in `/home/mo/Documents/piliavalon-yard/sources`.
- No fork source tree, `_forks/`, or submodule belongs in `main`.

## Verification Rule

This environment cannot perform Android install, launch, or device acceptance tests. Missing local Android testing is a yellow blocker, not a pass. Potential issues remain open until CI or an approved Android device writes concrete evidence.
