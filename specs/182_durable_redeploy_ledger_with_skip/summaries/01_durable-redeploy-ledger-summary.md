# Implementation Summary: Task #182

- **Task**: 182 - Add a durable redeploy ledger with content-hash and recency skip to the checkpoint
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T00:00:00Z
- **Completed**: 2026-09-18T02:00:00Z
- **Effort**: ~2 hours
- **Dependencies**: 181 (gate-depth / verdict-logic unification), 193, 213
- **Artifacts**: plans/01_durable-redeploy-ledger.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the plan's 5 phases in full: a new durable, gitignored, machine-local redeploy
ledger (`scripts/lib/deploy-ledger-lib.sh`, default path
`specs/.orchestrator-deploy-ledger.json`) that gives the Inter-Cycle Redeploy Checkpoint in
`orchestrate-cycle-plan.sh` cross-invocation memory it previously lacked. The checkpoint now
consults the ledger before its first expensive call and can skip the deploy+verify body on two
kinds of positive evidence — a content-hash skip for the ordinary case, and an attributed-recency
skip for the self-modifying-task class (a task whose own `file_scope` is the orchestrator source
store, which changes the hash on every cycle by construction and therefore cannot be helped by a
hash rule alone). A `deploy_pending` override and negative-record (`deploy_failed`/`blocking`)
ledger writes ensure a skip can never starve the postflight completion-deploy gate's backstop.
The existing `deployed_critical_paths` field's narrower, within-invocation role is preserved
unchanged and now explicitly documented as such.

## What Changed

- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh` — new library exporting
  `deploy_ledger_path`, `deploy_ledger_hash_state`, `deploy_ledger_read`, `deploy_ledger_decide`,
  `deploy_ledger_write`, and the `DEPLOY_LEDGER_*` env-overridable constants.
- `agent-system/extensions/core/scripts/tests/test-deploy-ledger-lib.sh` — new unit suite (27
  cases): hash determinism/MISSING handling/CANNOTVERIFY, read validation, all `decide()` branches
  (skip_hash, skip_attributed, and one `run` case per broken conjunct), write round-trip.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — sources the new library;
  consults the ledger (hash state, ledger read, `deploy_pending` scan via `task-lookup-lib.sh`,
  `deploy_ledger_decide`) right after the existing banner and before `pre_findings=...`; wraps the
  existing deploy/verify body in an `if`/`else` on the decision (never an early exit); writes
  ledger records on all five checkpoint outcomes (`clean`, `pre_existing`, `filtered`,
  `deploy_failed`, `blocking`); extends the `(k, part 2)` header comment.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — copies the new
  lib into the fixture tree; adds Group 11 cases (l)-(r): hash skip, attributed skip, no-skip
  outside the recency window, no-skip on a foreign change, `deploy_pending` override, a negative
  `blocking` record that prevents a later skip, and the NAMED self-modifying-task acceptance
  criterion (a 3-invocation sequence proving total deploy count stays 1, plus a counterfactual
  proving a hash-only rule would redeploy every time).
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — new 18th class member
  (`deploy-ledger`) across all six parallel arrays; header/comment counts updated.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — new Class
  Table row and a "third disposition" subsection (durable, machine-local, gitignored, hash-gated
  on read — distinct from both the Ephemeral and tracked-Durable-provenance classes); pinned
  gitignore block updated to match `runtime_ignore_block()` byte-for-byte.
- `.gitignore` (repo root) — new `**/.orchestrator-deploy-ledger.json` pattern with rationale.
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — Case 5 member
  count updated 17 → 18.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — rewrote the
  Idempotence guard paragraph to state `deployed_critical_paths`'s session-suffixed,
  within-invocation-only scope; added the full "Durable redeploy ledger" contract paragraph
  block; corrected the D6 residual's stale "its own task" clause to point at the now-existing
  ledger without marking D6 resolved.
- `agent-system/extensions/core/manifest.json` — registered the two new script files under
  `provides.scripts` (doc-lint caught the omission before the final redeploy).

## Decisions

- Hash scope is `agent-system/extensions/core` only (never the `.claude`/`.opencode` deploy
  mirrors), per the plan's Decision 2 — keeps the ledger meaningful across a deploy/redeploy
  cycle rather than chasing the copy.
- `deploy_ledger_decide`'s attribution `⊆` check resolves `orchestrator-critical-paths.json` via
  a path relative to the library's own file location (works identically in the real deployed tree
  and in the test fixture's mirror), rather than taking it as a parameter — keeps the function
  signature exactly as specified in the plan.
- Counterfactual acceptance test uses `DEPLOY_LEDGER_RECENT_SEC=-1`, not `0` as literally written
  in the plan (see Plan Deviations).

## Plan Deviations

- **Case (r) counterfactual** altered: used `DEPLOY_LEDGER_RECENT_SEC=-1` instead of `0`. `age_sec`
  is computed via whole-second `date +%s`; a same-second seed+decide pair could produce
  `age_sec == 0`, making `0` a flaky, timing-dependent threshold for "the recency window is never
  satisfied." `-1` is unsatisfiable by any non-negative age and keeps the assertion deterministic.

## Verification

- Build: N/A (shell scripts + markdown)
- Tests: Passed — `test-deploy-ledger-lib.sh` (27/27), `test-orchestrate-cycle-plan.sh` (238/238,
  including all-new Group 11 cases l-r and the pre-existing cases a-k unchanged),
  `test-runtime-file-tracking.sh` (9/9, 18-member count), `test-deploy-orphans.sh` (5/5),
  `test-deploy-propagation.sh` (4/4), `test-deploy-baseline-lib.sh` (7/7).
- Task-reference lint: clean (0 unexempted occurrences across all touched deliverables).
- Final gate: `deploy-headless.sh` → `landed_verify_clean` (33/33 fast checks); full
  `verify-deploy.sh` (including the Gate 8 shell test suite) run to confirm the slow gate — see
  follow-ups if this task returns before that background run's notification lands.
- Files verified: Yes (all new/modified files read back and exercised by the test suites above).

## Impacts

- `/orchestrate` batches touching `agent-system/extensions/core/**` repeatedly across separate
  invocations (the ordinary case) or via a task whose own `file_scope` is the source store itself
  (the self-modifying-task class) no longer incur a redundant full deploy+verify on every
  qualifying cycle — closing the observed ~10-minute-per-firing cost and the "both tasks in the
  batch deferred" failure mode named in the dispatch.
- The completion-deploy gate's stale-deploy backstop remains fully reachable: any
  `deploy_pending: true` batch task forces a real redeploy regardless of ledger evidence.
- No change to the checkpoint's verdict logic (confirmation/attribution filters, depth reporting)
  or to `deployed_critical_paths`'s existing within-invocation semantics.

## Follow-ups

- D6 residual (widening Stage MT-3 step 7's trigger predicate from critical-path keying to a
  broader `agent-system/extensions/**` predicate) remains open, separate follow-up work, as
  explicitly named in the plan's Non-Goals and re-confirmed in the guardrails doc.
- `command-gate-out.sh` / skill-base retry paths do not write the ledger in this task; the
  library is built so they can adopt it later (plan Decision 8, Non-Goals).

## References

- `specs/182_durable_redeploy_ledger_with_skip/plans/01_durable-redeploy-ledger.md`
- `specs/182_durable_redeploy_ledger_with_skip/reports/01_durable-redeploy-ledger-design.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` ("The
  Inter-Cycle Redeploy Checkpoint" subsection)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (Class Table)
