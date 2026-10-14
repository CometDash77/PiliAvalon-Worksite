# AGENTS.md

## Agent skills

### Issue tracker

Issues and PRDs live as GitHub issues, driven with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Triage uses the five canonical label strings unchanged: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Flutter testing on CI only

All Flutter work (`flutter test`, `flutter analyze`, `flutter pub get`) runs on GitHub Actions only — never locally. To verify changes: push and let the `PiliAvalon CI` workflow run (PR-triggered). Do not install or use a local Flutter SDK for verification; the local SDK has been removed. Local reproduction of CI failures is a mistake, not a shortcut.

## Domain docs

Domain docs are multi-context: a root `CONTEXT-MAP.md` points at one `CONTEXT.md` per context. See `docs/agents/domain.md`.
