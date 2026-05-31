# Phase 1 Field Variance Closure Matrix

Date: 2026-05-31

## Status

Matrix status: open. Phase 1 remains yellow.

This matrix consolidates current field variance status for the acceptance-fixes
worktree. It does not close CI, smoke, review, manual acceptance, or final
acceptance gates.

## Branch And Evidence Baseline

- Repo: `CometDash77/PiliAvalon-Worksite`
- Worktree: `C:\tmp\PiliAvalon-Worksite-phase1`
- Local branch: `phase-1-shielding-acceptance-fixes`
- Local HEAD before dirty changes: `ce5f6915dac362a824857f7eee228f49b364d177`
- Remote `phase-1-shielding-acceptance-fixes`: absent from `origin`
- Remote `phase-1-shielding-core`: `9c9669e477310d9fa1325ca454a022688dc31597`
- Current dirty changes: implementation, tests, Reasonix records, session
  records, closure matrix, release note, and review request artifacts.

## Matrix

| Variance / gate | Current status | Evidence path or command | Closure requirement |
| --- | --- | --- | --- |
| `phase-1-multi-agent-governance-gap` | Open | `records/session/2026-05-31-phase-1-governance-gap-closure.md` | Fresh CI, smoke, technical-lead review, user retest, and final evidence paths. |
| `phase-1-shielding-implementation-audit` | Open | this matrix plus Codex review of Reasonix candidate audit | Verify full shielding test bundle, analyze, CI, and runtime smoke on final ref. |
| Reasonix field variance audit review | Reviewed with restrictions | `records/reasonix/review/2026-05-31-phase-1-field-variance-sidecar-audit-codex-review.md` | Keep candidate-only boundaries in release note and handoffs. |
| Migration test storage initialization | Locally fixed and bundle-verified | `flutter test test\features\shielding` passed 53/53 after test setup fix | Run fresh CI on final ref. |
| Settings widget category assertion | Locally fixed and verified | `flutter test test\pages\setting\models\shielding_settings_test.dart` passed 7/7 after scroll-visible test fix | Run fresh CI on final ref. |
| Current branch CI | Missing | `gh run list -R CometDash77/PiliAvalon-Worksite --branch phase-1-shielding-acceptance-fixes --limit 10` returned no runs | Push or otherwise create final ref and run fresh CI. |
| Merge-to-core CI | Missing for final fix set | old `phase-1-shielding-core` runs predate these dirty changes | After merge, run fresh CI on the merged core ref. |
| Runtime smoke | Missing for final fix set | old smoke evidence belongs to earlier `phase-1-shielding-core` refs | Build/install/launch/smoke final APK and archive screenshots/logcat. |
| Technical-lead review | Pending | `records/session/2026-05-31-phase-1-technical-lead-review-request.md` | Receive explicit technical-lead review result. |
| User/manual acceptance | Pending | no final retest artifact | User retests final APK/ref or explicitly defers. |
| Consolidated release note | Drafted, not final | `records/session/2026-05-31-phase-1-consolidated-release-note.md` | Fill final commit, tag, CI URL, smoke URL, release URL, and acceptance result. |
| Old failed package/smoke reuse | Prohibited | this matrix and release note | Cite old failures only as history, never pass evidence. |

## CI Decision

The acceptance-fixes branch needs fresh CI. Existing `phase-1-shielding-core`
runs cannot be reused as pass evidence because:

- the acceptance-fixes branch is local-only and has no remote head;
- no GitHub Actions run exists for `phase-1-shielding-acceptance-fixes`;
- the current dirty worktree contains changes not present in any CI ref;
- `origin/phase-1-shielding-core` has advanced beyond the local acceptance
  branch base.

If the fix set is merged into `phase-1-shielding-core`, the required pass
evidence must be a fresh run on the merged core ref, not an old core run.

## Local Verification Snapshot

Fresh local commands run after the current fixes:

```powershell
flutter test test\features\shielding
flutter test test\pages\setting\models\shielding_settings_test.dart
flutter analyze --no-fatal-infos
git diff --check
```

Results:

- Shielding tests: 53/53 passed.
- Settings model/widget tests: 7/7 passed.
- Analyze: exit 0 with 52 info-level issues.
- Diff check: exit 0; only CRLF conversion warnings were printed.

These local results do not close CI, runtime smoke, technical-lead review, or
user acceptance.
