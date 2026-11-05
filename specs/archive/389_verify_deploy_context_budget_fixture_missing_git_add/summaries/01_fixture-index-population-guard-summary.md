# Implementation Summary: Task #389

- **Task**: 389 - Fix test-verify-deploy-context-budget.sh's fixture so the full verify-deploy gate set can pass
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T21:52:00Z
- **Completed**: 2026-10-14T22:40:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fixture-index-population-guard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Converted `test-verify-deploy-context-budget.sh`'s comment-protected fixture-staging invariant
(the `git add -A && git commit` step Gate 22 depends on) into a mechanically enforced one: the
fixture now counts its own staged `*.sh` files with the exact pathspec `lint-shellcheck.sh` uses
and refuses with a named reason at exit 2 if the count is zero, instead of silently producing a
misleading Gate 22 failure roughly a hundred seconds later. The dispatch's premise — that the
`git add` step was missing — turned out to be stale (already fixed in commit `5e23c280c`, before
this task was dispatched); this task did not re-apply that fix, it hardened the invariant the fix
depends on, per the research report's recommendation 4.

Discharging the complete `verify-deploy.sh` gate set (Phase 2) surfaced three independent,
pre-existing failure causes, none attributable to this task's own change: a Gate 20 eager-load
budget regression, a Gate 3 doc-lint index-registration gap, and four unrelated failing suites
inside Gate 8. All are evidenced, issue-tracked, and explicitly excluded in the plan's Phase 2
Reasoned Exclusions record rather than silently absorbed or left unmentioned.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — after the
  existing `git -C "$FIXTURE" add -A && git -C "$FIXTURE" commit -q -m fixture`, added a
  NUL-safe count of `git ls-files -z -- 'agent-system/extensions/*.sh'` (the exact pathspec
  `lint-shellcheck.sh` uses), an `exit 2` with a named reason if that count is zero, and an
  `info()` line reporting the count on success. Rewrote the adjoining comment block to describe
  the now-enforced invariant. Deployed to `.claude/scripts/tests/test-verify-deploy-context-budget.sh`
  via `deploy-headless.sh` (not hand-authored).

## Decisions

- Did not re-apply the dispatch's named fix (`git add`/`commit`) — it was already present and
  committed (`5e23c280c`, 2026-10-12); re-adding it would have been fabrication. Converted the
  Overview's contradiction of the dispatch premise into an explicit, evidenced record instead of
  silently diverging.
- Closed Phase 1 `[COMPLETED WITH EXCLUSIONS]`: the phase's own `run-all.sh --only` verification
  criterion cannot pass today because the suite's internal full-battery baseline step hits a
  live, pre-existing Gate 20 eager-load regression — proven unrelated to this phase's edit via a
  side-by-side run of the pristine pre-task script against the identical live-repo state (both
  reproduce the identical "11 passed, 2 failed" result). The phase's actual deliverable (the
  index-population guard) was independently verified via `lint-shellcheck.sh` (clean), a positive
  run (`[INFO] fixture index populated: 375 tracked *.sh files`), and a negative probe (exit 2
  with the named reason, in ~5s, then restored clean).
- Closed Phase 2 `[COMPLETED WITH EXCLUSIONS]`: the complete gate set terminated (did not hang —
  the plan's anticipated non-termination contingency did not fire) but genuinely fails 3 of 37
  checks for reasons unrelated to this task. Rather than force a false `[COMPLETED]` or leave the
  phase open with no path forward, applied the plan's own stated principle (exclude, evidence,
  do not attribute to this task's named cause) to the three items actually found.
- Did not attempt to fix any of the three excluded items (Gate 20 eager-load overage, Gate 3
  doc-lint gap, the four unrelated Gate 8 suite failures) — each is a distinct, pre-existing
  problem outside this task's Non-Goals-bounded scope (Gate 22/shellcheck/git-add only).

## Plan Deviations

- **Task 1 (final verification item)**: `run-all.sh --only test-verify-deploy-context-budget.sh`
  does not exit 0, for the pre-existing Gate 20 reason above. The phase's actual deliverable is
  verified directly (lint, positive INFO line, negative probe) instead.
- **Task 2.7**: the plan anticipated a single non-terminating-suite exclusion; the complete gate
  set instead terminated normally with 3 of 37 checks genuinely failing for three independent,
  unrelated, pre-existing causes. Closed with a 3-item Reasoned Exclusions record instead of the
  anticipated 1-item non-termination record. See the plan's Phase 2 section for full detail.

## Verification

- Build: N/A (shell script change)
- Tests:
  - `lint-shellcheck.sh --verbose` on the edited file: PASS (0 findings, exit 0).
  - Positive run: `[INFO] fixture index populated: 375 tracked *.sh files under
    agent-system/extensions/` present in both the source-store and deployed-copy runs.
  - Negative probe (staging step disabled): exit 2 with the named reason in ~5s; file restored
    byte-identical to its pre-probe edited state (`diff`); re-run clean afterward.
  - `bash .claude/scripts/verify-deploy.sh` (complete gate set, no `--skip-slow`): exit 1, "3 of
    37 check(s) failed" — Gate 22 (shellcheck) itself PASSES; the 3 failures are Gate 3, Gate 8,
    and Gate 20, all pre-existing and unrelated (see Reasoned Exclusions record).
- Files verified: Yes (deployed copy confirmed byte-identical to the source-store commit via
  `diff`).

## Reconciliation (premise staleness)

The dispatch's named cause — `test-verify-deploy-context-budget.sh`'s fixture never running
`git add` — was already absent from the tree as of commit `5e23c280c` (2026-10-12), before this
task was dispatched. This task did not re-apply that fix (it would have been fabrication); it
added the index-population assertion that mechanically enforces the invariant the fix depends on.
This specific Gate 22/`git add` cause is therefore no longer an admissible pre-existing
attribution for any later task's "verify-deploy.sh exits 0" verification criterion. Recorded as
issue `iss_1792019079627_HtAY3q`.

Three OTHER pre-existing, unrelated causes remain open and are newly issue-tracked rather than
fixed here (each is its own, separate scope):
- Gate 20 eager-load budget regression (67,088 B vs. 66,100 B baseline) — issue
  `iss_1792015798103_u6yBQB`.
- Gate 3 doc-lint index-registration gap (lean4 `measurement-harness-strictness.md`) — issue
  `iss_1792019093789_pEpEft`.
- Four unrelated Gate 8 suite failures (`test-detect-noop-bash.sh`, `test-guard-git-push.sh`,
  `test-skill-base-lifecycle.sh`, `test-four-tier-conflict.sh`) — issue
  `iss_1792019093909_Zk3nZO`.

A future task citing "verify-deploy.sh exits 0" as unmeetable should cite one of these three
issues (or a fresh finding), never the original `git add` cause this task closed.

## Impacts

- Every future implementation plan's final-phase criterion "verify-deploy.sh exits 0 — the
  complete gate set" now has an accurate, narrowed set of admissible pre-existing attributions
  (three issue-tracked causes, none of them this task's original one) instead of one vague,
  already-stale one.
- The fixture's own staging invariant is now self-verifying: a future regression that drops the
  `git add` line will fail loudly within seconds (exit 2, named reason) instead of opaquely via
  Gate 8 roughly a hundred seconds later.

## Follow-ups

- Trim eager-loaded rules/CLAUDE.md content to close the Gate 20 overage (issue
  `iss_1792015798103_u6yBQB`) — a documentation-budget task.
- Register `agent-system/extensions/lean/context/project/lean4/patterns/measurement-harness-strictness.md`
  in `.claude/context/index.json` (issue `iss_1792019093789_pEpEft`).
- Investigate the four unrelated Gate 8 suite failures (issue `iss_1792019093909_Zk3nZO`):
  `test-detect-noop-bash.sh`'s stray-tmp-dir isolation defect, `test-guard-git-push.sh`'s
  uncaptured single failing case, `test-skill-base-lifecycle.sh`'s possible working-tree
  cleanliness assumption, and `test-four-tier-conflict.sh`'s timing-budget flake.

## References

- Plan: `specs/389_verify_deploy_context_budget_fixture_missing_git_add/plans/01_fixture-index-population-guard.md`
- Research: `specs/389_verify_deploy_context_budget_fixture_missing_git_add/reports/02_independent-corroboration.md`
- Edited file: `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
- Issues: `iss_1792015798103_u6yBQB`, `iss_1792019079627_HtAY3q`, `iss_1792019093789_pEpEft`, `iss_1792019093909_Zk3nZO`
