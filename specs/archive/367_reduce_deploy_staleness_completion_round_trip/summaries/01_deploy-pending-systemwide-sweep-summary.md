# Implementation Summary: Task #367

- **Task**: 367 - Reduce the deploy-staleness completion round trip without weakening the completion-deploy gate
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T11:12:32Z
- **Completed**: 2026-10-08T12:10:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_deploy-pending-systemwide-sweep.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, git-staging-scope.md

## Overview

A task touching `agent-system/**` reliably finished its work and then could not record it: the
postflight completion-deploy gate (`update-task-status.sh`'s PHASE 0.5, exit 6) correctly refused
the stale-deploy write, but the promised automatic self-heal — the Inter-Cycle Redeploy
Checkpoint's `run_post_deploy_reconcile_pass()` — never reached the refused task unless a later
`/orchestrate` invocation happened to name that exact task number again. This implementation
widens that one already-sanctioned trigger's own candidate set, inside its own shared promotion
library, to also sweep `specs/state.json` system-wide for any other non-terminal, deploy-pending
task, lock-gated and reporting-scoped — closing the gap without adding a third automated
`deploy-headless.sh` call site and without touching the gate itself.

## What Changed

- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` — widened
  `run_post_deploy_reconcile_pass()`'s candidate derivation from the invocation-scoped
  `post_deploy_reconcile_json` alone to that list unioned with a system-wide `specs/state.json`
  sweep for every other non-terminal (`implementing`/`partial`) task whose own
  `.return-meta.json` carries `deploy_pending: true` — strictly excluding any task already a
  member of this invocation's own `.task_numbers` (a required addition beyond the plan's literal
  predicate text; see Plan Deviations). Each swept (out-of-batch) candidate is lock-gated via
  `task-lock.sh check` (proceed on free/held-stale, skip fail-closed on held-fresh/unresolvable)
  before any reconcile attempt. Every notice now carries a `scope` field (`"batch"`/`"swept"`);
  `.completed_tasks` is appended only for `scope == "batch"`, while the scoped
  `state.json`/`TODO.md` commit fires for both scopes. The header comment was rewritten to record
  the widened reach, the lock-gate rationale, the scope distinction, and the structural safety
  argument (every promotion still passes through the same unconditional, check-only gate).
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` — new
  fixture-driven suite (17 assertions, Cases A–F) that drives `run_post_deploy_reconcile_pass()`
  directly against an isolated fixture repo, with a `REDEPLOY_CHECKPOINT_LIB` environment
  override for the fail-before/pass-after demonstration.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — corrected the
  "Automated Exception: The Postflight Completion-Deploy Gate" section's sanctioned-sites pair
  from `{command-gate-out.sh's rc==6 branch, a now-defunct markdown command file's Step 4
  trigger}` to `{command-gate-out.sh's rc==6 branch, orchestrate-cycle-plan.sh's Inter-Cycle
  Redeploy Checkpoint}` — the pair `test-lint-deploy-caller-wrap.sh` mechanically enforces —
  across four occurrence sites (one more than the plan's own Scope Hypothesis anticipated), and
  added a labeled **CORRECTION.** block recording the earlier naming, the lint's mechanical
  authority, and this task's own system-wide-sweep widening.
- `agent-system/extensions/core/manifest.json` — one-line `provides.scripts` registration for the
  new test file (via `sync-manifest-scripts.sh --write`), a required companion to the new script
  file, not itself in `file_scope`.
- `agent-system/extensions/core/index-entries.json` — one-line `line_count` correction for
  `regeneration-is-manual-only.md` (694 → 722, via `generate-context-line-counts.sh --write`), a
  required companion to that edit, not itself in `file_scope`.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — read in full (`implementing`
  and `partial` branches) but NOT edited: both branches read only the `task_number` argument
  they are given and that task's own directory, with no assumption about who or what is calling
  them, so no accommodation was needed for a swept (out-of-batch) candidate.

## Decisions

- **Out-of-batch exclusion (required, not optional)**: the plan's literal candidate-derivation
  predicate (`T` not already in `post_deploy_reconcile_json`) was insufficient on its own. A
  direct regression run against `test-orchestrate-cycle-plan.sh` showed Arm E (deploy-failure
  negative control) and Arm G (self-attribution hard-mode withholding) both fail under the
  literal predicate: a task that IS a member of this invocation's own `.task_numbers`, but was
  deliberately withheld THIS SAME cycle (deploy did not land, or the self-attribution screen
  withheld it), still carries `status: implementing` and `deploy_pending: true` on disk — exactly
  the shape the naive sweep would re-promote, silently defeating that same-cycle decision. The
  fix adds a second, required exclusion: a swept candidate must also NOT be a member of
  `.task_numbers`. After this fix, both arms (and the full `test-orchestrate-cycle-plan.sh` suite,
  359 passed / 0 failed) are green.
- **Case C's "byte-identical" narrowed to `.status`**: `reconcile-task-status.sh` unconditionally
  `link_artifact()`s a found summary into `state.json`'s `.artifacts` BEFORE attempting the
  postflight promotion a stale tree then refuses — pre-existing, unmodified behavior. The
  fixture's whole-file byte identity therefore does not hold even on a correct refusal; the
  `.status` field (the actual thing the gate exists to protect) does, mirroring
  `test-postflight-deploy-gate.sh`'s own precedent (`before_status == after_status`, never
  whole-file identity).
- Fixture tasks in the new suite are referred to as "project N" rather than "task N" in comments
  and assertion messages, to stay clear of the no-task-references-in-deliverables write-time
  guard hook while remaining unambiguous.

## Plan Deviations

- **Task 2.2** altered: added the required `.task_numbers`-exclusion conjunct to the
  candidate-derivation predicate (see Decisions above).
- **Task 3.2** altered: narrowed Case C's "byte-identical state.json" assertion from the whole
  file to the `.status` field (see Decisions above).
- **Task 4.3** altered: corrected a fourth occurrence site in
  `regeneration-is-manual-only.md` beyond the three the Scope Hypothesis anticipated (a "fires at
  most once per its own invocation ... a Step 4 run" clause further down the same section).
- **Phase 2/5** (companion edits, not themselves `file_scope` members): `manifest.json` and
  `index-entries.json` each received one required, mechanical line — not scope creep, but
  recorded honestly as excursions via `issue-record.sh` at the time.

## Verification

- **Build**: N/A (shell scripts).
- **Tests**: `test-redeploy-checkpoint-promotion.sh` — 17/17 passed (Cases A–F). Fail-before:
  pristine library (the commit immediately preceding this task's Phase 2 commit) — 11
  passed/6 failed, exit 1 (Cases B, C, D, E failed, exactly as Case D's absent lock-skip line and
  Cases B/C/E's absent promotion/scope evidence predict). Pass-after: widened library (default
  resolution) — 17 passed/0 failed, exit 0. `test-lint-deploy-caller-wrap.sh` — 7/7 passed, file
  unmodified, still exactly two genuine callers (`command-gate-out.sh`,
  `orchestrate-cycle-plan.sh`). `test-orchestrate-cycle-plan.sh` — 359/359 passed (0 failed, after
  the out-of-batch exclusion fix). `test-force-phases.sh` — 36/36 passed.
  `test-orchestrate-unwind-dispatch.sh` — 21/21 passed. `test-postflight-deploy-gate.sh` and
  `test-reconcile-handoff-status.sh` — both green, unmodified. Full `run-all.sh`: 121 passed, 1
  failed (0 expected, 1 NEW), 4 skipped, 126 total — the one failure
  (`test-verify-deploy-context-budget.sh`) is the expected, self-resolving deploy-staleness
  condition this task's own undeployed edits produce (see Acceptance Walkthrough #7).
- **Files verified**: Yes — every new/changed file confirmed on disk and non-empty; `git diff
  --stat` reviewed against the task's start point (see Acceptance Walkthrough #6).
- **shellcheck**: suite file clean (0 findings). Library file reports only the same
  SC2154 (closed-over caller-scope globals)/SC2016 (single-quoted jq filter, deliberate) findings
  already present on the pre-existing, unmodified file and on sibling Class C libraries
  (`territory-contention-lib.sh`, `task-classification-lib.sh`) of the identical extraction
  lineage — no new category introduced.

## Acceptance Walkthrough

1. **Cause named with evidence**: variant **(b)** — the pass ran, and would run again, but its
   candidate set never contained the stranded task. Re-verified directly:
   `scripts/orchestrate-cycle-plan.sh`'s per-task `_dp_t` loop builds `deploy_pending_tasks_json`
   (and hence `post_deploy_reconcile_json`) by iterating `mt_get_json '.task_numbers'` only — a
   task not named by the current invocation is structurally never considered, regardless of how
   many later cycles run. Confirmed by direct reproduction: a pristine-library fixture run for 3
   successive cycles against a stranded deploy-pending task promoted it 0 times (status stayed
   `implementing` across all 3); the widened library promotes it on cycle 1.
2. **Reproduction fixture**: Case B (`test-redeploy-checkpoint-promotion.sh`) — an out-of-batch,
   deploy-pending task on a FRESH tree is promoted to `completed`, its `deploy_pending` marker
   cleared, with a `scope: "swept"` notice. The two-run fail-before/pass-after pair: pristine
   library exit 1 (11 passed/6 failed); widened library exit 0 (17 passed/0 failed).
3. **Counted before/after**: measured directly from the fixture, not asserted — pristine library,
   3 successive cycles, 0 promotions (unbounded automated-cycle count; the only prior remedy was
   a hand-run `reconcile-task-status.sh`); widened library, the very first cycle of any later
   `/orchestrate` invocation promotes it (1 cycle).
4. **Gate still refuses against a genuinely stale deploy**: Case C — an out-of-batch candidate on
   a deliberately-advanced-but-not-recorded (STALE) source tree is attempted exactly as Case B,
   but `update-task-status.sh`'s PHASE 0.5 gate refuses with exit 6; the task's `.status` stays
   `implementing`, `deploy_pending` stays `true`, and the notice records `outcome: "refused",
   exit_code: 6`.
5. **Sanctioned automated deploy-caller census still exactly two**:
   `test-lint-deploy-caller-wrap.sh` — 7/7 passed, the suite file itself byte-for-byte unmodified
   (confirmed via `git diff --stat`), genuine-caller classification unchanged
   (`orchestrate-cycle-plan.sh`, `command-gate-out.sh`).
6. **Documented pair matches the lint**: `context/patterns/regeneration-is-manual-only.md`'s
   sanctioned-sites sentence, its "deliberately UNCHANGED" paragraph, its structural-precondition
   paragraph, and a fourth, previously-unnoticed occurrence all now read
   `{command-gate-out.sh's rc==6 branch, orchestrate-cycle-plan.sh's Inter-Cycle Redeploy
   Checkpoint}` — the exact pair the lint's own genuine-caller census reports. A labeled
   **CORRECTION.** block records the earlier, now-dangling naming and names the lint as the
   mechanical source of truth. `grep -n 'commands/implement'` against the target file now
   returns zero matches (it returned one dangling reference before this phase).
7. **`scripts/tests/` passes**: with one honestly-documented, non-weakened exception —
   `test-verify-deploy-context-budget.sh`'s baseline case symlinks the REAL deployed `.claude/`
   tree and fails on the same expected, self-resolving deploy-staleness this task's own
   (currently undeployed) source edits produce; direct reproduction confirmed the deployed tree
   was byte-identical to committed source at this task's start (before any edit of mine), so this
   task's own edits are the sole, expected cause. Every other named suite — including the full
   `test-lint-*.sh` family, `test-postflight-deploy-gate.sh`, `test-reconcile-handoff-status.sh`,
   `test-orchestrate-cycle-plan.sh`, `test-force-phases.sh`, and
   `test-orchestrate-unwind-dispatch.sh` — passed clean. No suite was weakened, skipped, or
   deleted to reach this result. A separate, genuine, deploy-state-independent defect
   (`index-entries.json`'s stale `line_count` for the edited doc) was found and fixed during this
   verification pass.
8. **shellcheck clean**: per `context/standards/shell-strict-mode.md` — the new Class B suite
   file is fully clean; the Class C library carries only the pre-existing closed-over-global
   finding categories already present before this task and on sibling libraries of the identical
   extraction lineage, with no new category introduced.

## Impacts

- A future `/orchestrate` cycle that does not happen to name a gate-6-refused, `agent-system/**`
  -touching task will now self-heal that task's completion on its very next cycle, regardless of
  which task(s) that cycle's own invocation names — removing the wasted dispatch cycle (and the
  `MAX_CYCLES` budget it burned) the dispatch's background section measured across three
  instances in one session.
- The widening is entirely additive and reach-only: it introduces no new `deploy-headless.sh`
  call site, no change to the completion-deploy gate, and no change to
  `reconcile-task-status.sh`.
- `context/patterns/regeneration-is-manual-only.md`'s sanctioned-sites prose is now accurate and
  will not mislead a future reader into looking for a nonexistent `commands/implement.md`.

## Follow-ups

- `context/patterns/batch-orchestration-guardrails.md`'s own invariant text (a different file,
  claimed by two other open tasks) still documents the pre-widening invocation-scoped behavior
  for the post-deploy reconcile pass; this plan's Non-Goals deliberately left that document to
  its owners and recorded the needed wording in this library's own header comment instead.
- Repository-wide, several OTHER files still reference the stale `commands/implement.md` path in
  contexts unrelated to the specific deploy-trigger claim this task corrects (`docs/architecture/
  batch-admit-schema.md`, `docs/architecture/handoff-schema.md`, `docs/guides/creating-
  commands.md`, `context/patterns/multi-task-operations.md`, `context/processes/implementation-
  workflow.md`, `context/patterns/skill-postflight-flow.md`, `context/patterns/task-lock.md`,
  `context/patterns/batch-orchestration-guardrails.md`). Reported per this phase's own Scope
  Hypothesis instruction; deliberately left unedited as out of this task's declared scope.
- This task's own completion write is expected to be refused with exit 6 (it modifies
  `agent-system/extensions/**`) — that refusal is itself acceptance #3's "before" datum, not a
  defect; the sanctioned path (the next `/orchestrate` cycle's own widened checkpoint sweep, now
  that it has landed) is expected to self-heal it.

## References

- Plan: `specs/367_reduce_deploy_staleness_completion_round_trip/plans/01_deploy-pending-systemwide-sweep.md`
- Research: `specs/367_reduce_deploy_staleness_completion_round_trip/reports/01_deploy_pending_task_numbers_scope_gap.md`
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh`
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh`
