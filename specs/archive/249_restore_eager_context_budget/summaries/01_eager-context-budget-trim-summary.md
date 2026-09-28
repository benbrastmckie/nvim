# Implementation Summary: Task #249

- **Task**: 249 - Restore the eager-context budget: trim the source-store rule to a lazy narrative rather than re-baselining
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T00:00:00Z
- **Completed**: 2026-09-22T01:25:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_eager-context-budget-trim.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The eager-load context budget was breached by 1,053 B (67,003 B measured against a 65,950 B
`baseline_bytes`), traced to a single prior task's rewrite that grew the eagerly-loaded
`rules/source-store-deploy-boundary.md` from 2,746 B to 4,443 B without the budget gate ever
running. This task split the rule into an eager core (path pattern, principle, one-line
resolution instruction) and a new lazily-loaded companion carrying the full resolution
procedure, the unreachable-source-store fallback, a worked example, the Exceptions list, and the
Enforcement narrative — the same rule-to-narrative split already used twice in this codebase
(`git-workflow.md`/`git-workflow-narrative.md`, `state-management.md`/
`state-management-schema.md`). The measured eager-load TOTAL is now 64,148 B, 1,802 B under
baseline.

## What Changed

- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` — trimmed from 4,443 B to
  1,588 B. The first 1,180 B (title, HTML "why eager" comment, `## Path Pattern`, `## Principle`)
  is byte-for-byte unchanged; everything from `## Correct Edit Target` onward was replaced with a
  condensed section holding the one-line resolution instruction plus a plain backticked pointer
  to the new companion.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` —
  new file (3,854 B / 75 lines). Carries the relocated `## Correct Edit Target — Full Resolution
  Procedure`, `### If the source store is unreachable`, `## Worked Example` (the promoted
  Before/After block), `## Exceptions`, and `## Enforcement` sections, extracted by byte range
  (`tail -c +1181`) rather than retyped, so no relocated sentence was reworded.
- `agent-system/extensions/core/index-entries.json` — one new entry for
  `standards/source-store-deploy-boundary-narrative.md`, modeled on the existing
  `standards/git-workflow-narrative.md` entry (`line_count: 75`, `load_when.agents:
  [general-implementation-agent, meta-builder-agent]`, `load_when.commands: [/meta]`).

## Decisions

- Extracted the relocated section by byte range (`tail -c +1181` on the pre-edit file, confirmed
  3,263 B, matching the plan's scope hypothesis exactly) rather than retyping, to guarantee no
  wording drift.
- Re-headed only `## Correct Edit Target` to `## Correct Edit Target — Full Resolution Procedure`
  in the companion, and promoted the Before/After block to its own `## Worked Example` heading;
  every other relocated section (`### If the source store is unreachable`, `## Exceptions`,
  `## Enforcement`, including the Known-limitation paragraph) is untouched.
- Did not redeploy `.claude/` after the source-store edit. Per
  `context/patterns/regeneration-is-manual-only.md`, only `skill-orchestrate`'s Stage MT-3 step 7
  (evidence-gated on a change touching an orchestrator-critical path) and the postflight
  completion-deploy gate's two call sites are sanctioned to invoke `deploy-headless.sh`
  automatically; this task's files (`rules/source-store-deploy-boundary.md`, the new companion,
  `index-entries.json`) are not on the critical-path registry, and under `/orchestrate` the
  postflight gate defers loudly rather than redeploying a third call site. A
  general-implementation-agent dispatch is not a sanctioned caller, so no redeploy was attempted
  here.

## Plan Deviations

- None (implementation followed plan). Acceptance criteria 2 and 4 (see Verification below)
  surfaced an interaction the plan's Scope Hypothesis had anticipated in principle ("if another
  suite is red, it is either pre-existing and out of scope or caused by this change, and the two
  must be distinguished before closing") but not in its specific mechanism; the plan's own Phase
  4 tasks were followed and annotated with the distinguishing evidence rather than altered.

## Verification

- `measure-eager-context.sh --check`: TOTAL 64,148 B, at or under `baseline_bytes` (65,950 B),
  1,802 B of headroom. `at_import` subtotal: 0 (no `@`-import regression).
- `test-verify-deploy-context-budget.sh`: 14 passed, 1 failed. Every gate-20-specific case
  (case1–case5) passes, and the suite's own `gate20 finding lines` count dropped from 1 (recorded
  in the dispatch's evidence) to 0 — direct proof the budget regression is fixed. The sole
  remaining failure, "baseline fixture is not clean (rc=1, gate20 finding lines=0)", is caused by
  Gate 5 (manifest-driven content-hash equality) failing on the fixture's symlinked `.claude/`
  tree, which has not been regenerated to reflect this task's source-store trim — a
  deploy-tree-drift condition outside this agent's authority to resolve (see Decisions above),
  and the same class of issue the task's own acceptance note scopes out for gate 20's run.
- `verify-deploy.sh --skip-slow`: Gate 20 passes cleanly (all 4 sub-checks green — eager-load
  total, `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md` all within their
  ceilings). 2 of 33 total checks fail (doc-lint, the same Gate 5 manifest-driven content-hash
  check) — both deploy-tree-drift class, explicitly out of scope per the dispatch's own note.
- `run-all.sh` (source-store copy, `agent-system/extensions/core/scripts/tests/run-all.sh`,
  matching the dispatch's 92-total baseline): `90 passed, 2 failed, 0 skipped, 92 total`, real
  exit code 1 (captured via explicit `$?`, never through a live `tail` pipe that would mask it).
  The 2 failures: (a) the budget suite's Gate-5 deploy-drift case described above; (b)
  `test-lake-build-guard.sh` — an unrelated, pre-existing Lean/Lake build-guard test failure with
  no connection to any file this task touched (confirmed: this task's file scope is limited to
  `rules/source-store-deploy-boundary.md`, the new `context/standards/` companion, and
  `index-entries.json`).
- Behavioral equivalence: `head -c 1180` byte-diff confirms the retained rule head is identical to
  the pre-edit file; the relocated payload was extracted by byte range (never retyped); the
  prohibition, Exceptions, and Enforcement narrative are unchanged in substance across the two
  files.
- Pointer format: the companion reference in the trimmed rule is a plain backticked path
  (`` `context/standards/source-store-deploy-boundary-narrative.md` ``), confirmed via `grep` to
  contain no `@`-import syntax in either file.

## Impacts

- The eager-context session-start budget has meaningful headroom (1,802 B) again, ahead of two
  queued tasks (documented in the dispatch) that will add further eager bytes to
  `rules/git-workflow.md` and `rules/pr-prohibition.md`/`merge-sources/claudemd.md`.
- `.claude/` (the deployed tree) will continue to diverge from the source store for these three
  files until the next redeploy (interactive `<leader>al`, or a future task whose `modified_files`
  overlap an orchestrator-critical path). This is expected and does not affect the correctness of
  the source-store change itself.

## Follow-ups

- **Observation (Stage 3.6 duty)**: `test-lake-build-guard.sh` failed one case in the full
  source-store `run-all.sh` run, with no connection to this task's file scope. This looks like an
  unrelated, pre-existing defect (possibly a flake, given the test's process-mutation/kill-timing
  nature) that should be triaged separately — not fixed here.
- The next `/orchestrate` cycle (or an interactive `<leader>al` reload) will redeploy `.claude/`
  and clear the residual Gate 5 / doc-lint findings this task's source-store edits introduced;
  no action is required from this task to make that happen.

## References

- Plan: `specs/249_restore_eager_context_budget/plans/01_eager-context-budget-trim.md`
- Research: `specs/249_restore_eager_context_budget/reports/01_eager-context-budget-trim.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
