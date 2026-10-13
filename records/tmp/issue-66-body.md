## Work package

Implement the owner-approved Zen Mode specification from [Zen Mode Specification (implementation-ready)](https://github.com/CometDash77/PiliAvalon-Worksite/issues/42), following [Decide Whether Zen Mode Enters Implementation](https://github.com/CometDash77/PiliAvalon-Worksite/issues/60) and its handoff [Assemble and hand off the Zen Mode specification](https://github.com/CometDash77/PiliAvalon-Worksite/issues/41).

This is the single Zen implementation entry point. Keep the existing spec as the source of truth; do not reopen the completed source map or redesign its settled rules.

## Scope and order

Implement the six slices in the approved order: **S1 → S2 → (S3 ‖ S4 ‖ S5) → S6**, with one PR per slice. Start with persistence and the single shared reactive source. Keep Zen as a presentation gate and preserve Jev/filtering semantics. Coordinate overlapping recommendation-view changes with [Trim Redundant Upstream Requests and Decouple the Recommendation Filter Pipeline](https://github.com/CometDash77/PiliAvalon-Worksite/issues/47); S4 must reconcile/rebase onto current recommendation-view changes and verify unchanged shielding behavior and request counts. Live surfaces remain outside this work package. The completed stable release is the baseline; Zen is a subsequent feature.

## Acceptance gate

- Follow the specification's per-slice requirements and regression baseline; record the baseline before S1.
- Keep a reviewed implementation plan under `REASONIX.md`. Require exact-SHA GitHub Actions evidence for analyzer and existing/new tests; local runs are development feedback only.
- Cover both toggle directions, tablet/sidebar layout, Dynamics index remapping, unchanged non-Home cards, and restoration of the user's reply/danmaku preferences with S3–S6 widget and visual checks.
- Track tests with `.gitignore` exceptions `!test/features/zen_mode/`, `!test/features/zen_mode/**`, and `!test/pages/setting/models/zen_mode_settings_test.dart`.
- Reconcile immediate reactive repaint with storage-write failure handling in the implementation plan.
- Require final production CI/prerelease evidence.

## Done when

All six slices have their own merged PR and exact-SHA acceptance evidence, shared-file overlap is resolved, and the production CI/prerelease gate passes.