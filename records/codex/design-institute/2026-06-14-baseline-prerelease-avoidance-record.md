# Baseline And Prerelease Avoidance Record

Date: 2026-06-14
Audience: Design Institute
Owner: Codex
Repo: `CometDash77/PiliAvalon-Worksite`

## Rule

Do not publish, preserve, or cite a prerelease as release evidence until it has
been checked against every baseline it claims to include.

## Pitfall Pattern

A prerelease can be technically green and still be wrong if it was built from
the wrong baseline. The dangerous pattern is:

1. implement the new feature;
2. run focused tests for the new feature;
3. publish a successful prerelease;
4. only afterward discover that older accepted capability was overwritten or
   omitted.

The problem is not weak CI. The problem is an incomplete release question.

## Required Design Gate

Before a prerelease is treated as useful evidence, define the baseline list in
plain text:

- current feature branch or commit;
- prior feature tags that must remain intact;
- files or behavior surfaces expected to survive;
- tests that cover inherited behavior;
- explicit exclusions, if an older behavior is intentionally dropped.

For comment shielding, the missing gate was:

- compare the comment-gate candidate against
  `task065-app-stat-fix-prebuild.27460023543`;
- verify Task065 numeric/range shielding routes, models, matcher behavior,
  settings pages, quick actions, and regression tests still existed;
- only then build and publish the prerelease.

## Release Cleanup Rule

When a prerelease is discovered to be based on the wrong baseline:

1. stop citing it immediately;
2. delete the wrong prerelease and its tag;
3. write a short record explaining why it was invalid;
4. rebuild from the corrected baseline;
5. verify the new release tag, commit, assets, and workflow run by direct
   lookup.

Keeping the wrong prerelease around creates ambiguity. A future operator may
download or cite it by mistake.

## Reasonix Boundary

Reasonix should do dirty labor only:

- monitor long-running runs;
- collect release facts;
- compare command outputs;
- write candidate verifier artifacts.

Reasonix must not make the baseline decision, claim release readiness, delete
releases or tags, push branches, or close acceptance gates. Codex keeps those
decisions.

## Branch Hygiene Rule

After the corrected prerelease is published, remove obsolete task branches and
leave the development environment on `production`. Task branches that survive
after release increase the chance of accidentally rebuilding or dispatching
from stale state.

For this episode, the intended final development state is:

- local checked-out branch: `production`;
- no local task branch retained;
- obsolete remote task branches removed after record commit/push;
- corrected prerelease tag:
  `task065-comment-gate-prebuild.27497810462`.

## Checklist For Next Time

- Baseline tag named before release work starts.
- `git diff` or equivalent comparison run against the baseline tag.
- Focused tests cover both new feature and inherited baseline behavior.
- Prerelease target commit equals the reviewed commit.
- APK assets exist for all expected Android ABIs.
- Old wrong-baseline prerelease/tag is absent before final handoff.
- Local worksite ends on `production`.
