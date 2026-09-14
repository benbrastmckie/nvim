# Implementation Summary: Task #181

- **Task**: 181 - Unify the /orchestrate inter-cycle redeploy checkpoint gate depth and verdict trustworthiness
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T16:45:00Z
- **Completed**: 2026-09-08T17:24:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: consumer-scan opt-in task (shared `deploy-headless.sh` footprint)
- **Artifacts**: plans/01_unify-redeploy-checkpoint-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed three related defects in the `/orchestrate` inter-cycle redeploy checkpoint that together
produced a contradictory, unactionable whole-batch deferral: a candidate new finding relative to
the pre-redeploy baseline is now passed through a **confirmation filter** (re-run once; a
finding that does not reproduce was flaky, most concretely a load-sensitive test flaking under
the checkpoint's own self-inflicted deploy+verify load) and then an **attribution filter** (a
confirmed finding that positively names an identifier absent from the batch's own
`modified_files` is unrelated). Only findings surviving both filters may defer the batch, and
they now name themselves in both the stderr warning and the `defer_ledger` detail. The
fast/full depth mismatch between `deploy-headless.sh`'s own internal `--skip-slow` verify and
the checkpoint's independent full-depth comparison is now reported as an explicit depth
disagreement rather than silently resolved. All five plan phases completed as designed with no
deviations beyond one additive test case.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — branch (b) now names the
  specific new findings in the stderr warning and `defer_ledger` detail (Defect B); the checkpoint
  now runs a candidate new-finding set through confirmation and attribution filters before
  deferring, with an all-filtered-empty result proceeding loudly via a `filtered:true`
  `verify_deploy_baseline_notices` entry (Defect C); a fast-PASS/full-FAIL depth disagreement now
  emits an explicit "DEPTH NOTE" stderr line and a `depth_disagreement` field on the
  `defer_ledger` entry (Defect A); the comment block above `post_findings` is extended, not
  replaced, to state the depth asymmetry is now explicitly reported.
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` — two new functions added:
  `deploy_baseline_confirm_new_findings` (comm -12 intersection against a fresh confirmation
  snapshot) and `deploy_baseline_unattributable_findings` (drops confirmed findings that
  positively name an identifier absent from `modified_files`, fail-safe toward blocking for
  identifier-free findings). Header comment extended to document all four exported functions and
  the deliberate checkpoint-only scope (never used by `command-gate-out.sh`'s `rc==6` handler).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 11 extended
  with cases (d) through (k): flaky-does-not-defer, unrelated-does-not-defer,
  genuine-attributable-still-defers, defer-message-names-the-finding, identifier-free-still-defers,
  depth-symmetry-regression-guard, call-count-guard, and (added beyond the plan's letter range)
  an explicit Defect A depth-disagreement case. `write_g11_verify_stub` extended with an optional
  4th confirm-response argument, defaulting to the post value for full backward compatibility.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — "### The
  Inter-Cycle Redeploy Checkpoint" subsection updated: branch (b)/(c) bullets now describe the
  filter pipeline and finding-naming; new "Confirmation and attribution filters" and "Gate depth"
  sub-sections added; the Stage-MT-3-step-7 trigger-predicate follow-up note sharpened with an
  explicit re-considered-and-split-out rationale.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` —
  `verify_deploy_baseline_notices` and `defer_ledger` shape documentation updated to reflect the
  new fields (`filtered`, `flaky_count`/`flaky_findings`, `unrelated_count`/`unrelated_findings`,
  `blocking_count`, `depth_disagreement`).

## Decisions

- Defect A: kept two verify depths (checkpoint full-depth, `deploy-headless.sh` internal
  `--skip-slow`) and made the mismatch explicit via a depth-disagreement report, rather than
  lowering the checkpoint's depth (would drop Gate 8 from the blocking baseline) or raising
  `deploy-headless.sh`'s own depth (would impose ~2.8min on every deploy for every caller).
- Defect C: confirmation filter first (kills the self-inflicted-load flake without weakening the
  gate — a real breakage reproduces), then attribution filter (satisfies the "or unrelated"
  clause), fail-safe toward blocking (identifier-free findings never dropped).
- The two new filter functions are additive to `lib/deploy-baseline-lib.sh` and used ONLY by the
  checkpoint; `command-gate-out.sh`'s `rc==6` handler deliberately keeps the unfiltered
  comparison (single-task gate, operator present).
- Added test case (k) beyond the plan's enumerated (d)-(j) letters to give the Testing &
  Validation section's separately-named Defect A depth-disagreement criterion its own explicit
  coverage.

## Plan Deviations

- None beyond the additive test case (k), recorded in the Phase 4 progress file's `deviations`
  array as an addition, not a deviation from any required item.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-orchestrate-cycle-plan.sh` 116/116 (up from 96 baseline; +20 new
  assertions across cases (d)-(k)), run twice for stability
- `bash -n` clean on all three modified shell scripts
- `run-all.sh --quiet`: 74 passed, 1 failed at the time Phase 4 ran mid-implementation. The one
  failure (`test-verify-deploy-context-budget.sh`'s "baseline fixture is not clean") was
  diagnosed in isolation by manually rebuilding its fixture and running `verify-deploy.sh`
  directly: it is gate3/gate5 deployed-vs-source drift correctly detecting that the 3 files this
  task edited had not yet been deployed to `.claude/` — expected mid-implementation, not a logic
  regression, and resolved by the final `deploy-headless.sh` run this dispatch performs as its
  last action (per the ORDERING operational note: commit everything first, deploy last, so the
  freshness marker records the final commit).
- Files verified: Yes

## Impacts

- The `/orchestrate` inter-cycle redeploy checkpoint no longer defers an entire batch on a
  finding that is flaky (load-induced) or unrelated to the batch's own modified files — the
  acceptance criterion this task was scoped against.
- A checkpoint deferral is now actionable: the operator sees the specific blocking finding text
  in both the stderr warning and `defer_ledger` detail without re-running the whole gate.
- A fast-PASS/full-FAIL disagreement between `deploy-headless.sh`'s own internal verify and the
  checkpoint's independent full-depth comparison is now surfaced as an explicit depth
  disagreement rather than presented as a silent contradiction.
- `command-gate-out.sh`'s single-task `rc==6` completion gate is unaffected — it deliberately
  continues to use the unfiltered baseline comparison, since an operator is present there to
  judge a flake by hand.

## Follow-ups

- **Split-out, owed follow-up (named per this task's Phase 5, not created as a task by this
  dispatch)**: widen the Postflight Completion-Deploy Gate's `/orchestrate` residual (D6) — Stage
  MT-3 step 7's trigger predicate currently keys off `orchestrator-critical-paths.json`'s
  critical-path expansion rather than a broader `agent-system/extensions/**` predicate, so a
  completed task whose own commits touch the source store outside a declared critical path can
  be refused at postflight with no serialized redeploy trigger of its own under `/orchestrate` to
  self-correct within the same invocation (unlike the single-task `command-gate-out.sh` rc==6
  path and the multi-task `commands/implement.md` Step 4 path, which both already have one).
  Widening the predicate (and its `deployed_critical_paths` idempotence backing store) is
  disjoint from this task's verdict-logic changes — no shared edit — which is why it was split
  out rather than absorbed here. The operator should create this as a new task.

## References

- Plan: specs/181_unify_redeploy_checkpoint_gate_depth/plans/01_unify-redeploy-checkpoint-gate.md
- Phase handoffs: specs/181_unify_redeploy_checkpoint_gate_depth/handoffs/
- Phase progress files: specs/181_unify_redeploy_checkpoint_gate_depth/progress/
