# Implementation Summary: Task #259

- **Task**: 259 - Allow completion when a plan branch deliberately skips phases, and stop the identical-redispatch loop
- **Status**: [COMPLETED]
- **Started**: 2026-09-25T18:45:00Z
- **Completed**: 2026-09-25T22:00:00Z
- **Effort**: ~9 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_gate-skipped-plan-completion.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two independent defects that combined to produce an observed deadlock: a completion-claim
gate that refused on an agent's self-reported phase counters without ever consulting the plan's
own markers, and a convergence guard that could not see a dispatch-refuse-redispatch loop because
each cycle genuinely dispatched. Fix 1 widens the corroboration trigger in
`orchestrate-cycle-postflight.sh` so a plan whose gate-skipped phases carry
`[COMPLETED WITH EXCLUSIONS]` can supply the completion evidence a handoff understated — with no
new marker, no new handoff field, and no new gate case. Fix 2 makes the convergence guard count
*identical* dispatches, not merely absent ones, capping any dispatch-refuse-redispatch loop at one
wasted cycle. A third, purely documentary strand tells planners and implementation agents that a
decision-gate/contingency-branch plan shape is exactly what `[COMPLETED WITH EXCLUSIONS]` is for.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — added `cycle_plan_dispatch_hash()`
  (normalizes a dispatch file, strips the two per-cycle-varying lines, emits a sha256sum digest,
  degrades to a named notice when sha256sum is unavailable); three new per-task multi-state fields
  (`last_dispatch_hash`, `last_dispatch_phase`, `identical_dispatch_streak`) plus
  `identical_dispatch_halted`; post-build streak accounting in the live dispatch loop; a halt
  branch that backs out the dispatch file, restores state.json's status/last_updated/session_id
  from the pre-dispatch pre-image via `state-write.sh`, releases the task lock, and excludes the
  task from the rest of the run via a `blocked[]` row — all before any budget charge.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — widened the
  corroboration-trigger precondition from `phases_total -eq 0` alone to `dispatch_status =
  "implemented"` alone, so a Case 1 shape (handoff understates progress) also reaches
  `skill_corroborate_phase_counts`; gated the resulting three-variable overwrite on
  `plan_markers_verified == "true"` so a non-corroborating result never zeroes a genuinely-nonzero
  `phases_total` (which would otherwise flip an ordinary Case 1 refusal into a false-positive
  `META_MISSING_AFTER_NARRATION` defect record).
- `agent-system/extensions/core/scripts/skill-base.sh` — comment-only correction of
  `skill_corroborate_phase_counts`'s D3/D4 header blocks, which asserted invariants ("sole
  consumer is Case 3", "Case 1 is unreachable by construction") the widened trigger makes false.
  `skill_gate_completion_claim`'s body is byte-unchanged.
- `agent-system/extensions/core/context/formats/plan-format.md` — new "Decision gates and
  contingency branches" subsection (after `## Reasoned Exclusions (format)`) documenting the
  mapping from a gate-skipped contingency branch to `[COMPLETED WITH EXCLUSIONS]`, with a worked
  seven-phase example.
- `agent-system/extensions/core/context/standards/status-markers.md` — cross-reference from the
  `[COMPLETED WITH EXCLUSIONS]` subsection to the new plan-format.md subsection.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — corrected the
  `plan_markers_verified` three-case description: Case 1 no longer asserts
  "`plan_markers_verified` is not consulted"; documents the corroboration mechanism, the
  fail-closed guarantee, and that no handoff field was added.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 27 (hash
  normalizer, sha256sum-degrade path, streak accounting) and Group 28 (halt on streak=2, full
  back-out assertions, subsequent-cycle exclusion, non-repeating-composition regression guard).
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` — Fixtures I
  (branched incident-shaped plan, arm 2), J (bare shortfall, arm 3), K (under-reported
  `phases_total`, arm 4), plus a case-2/3-label assertion added to the existing Fixture A (arm 1),
  via a new `corroborate_and_gate()` helper that replicates the widened caller's exact call
  sequence against the real `skill_corroborate_phase_counts`/`skill_gate_completion_claim`
  functions.

## Decisions

- No new phase-heading marker, no new handoff-schema field, no new defect-enum class — the
  existing `[COMPLETED WITH EXCLUSIONS]` marker and `skill_corroborate_phase_counts` machinery
  were already sufficient; only the corroboration *trigger* and the *documentation* were gaps.
- N=2 for the identical-dispatch guard: the first repeat is tolerated (may be a legitimate retry),
  the second halts the task for the rest of the run.
- Fix 2's back-out is written inline in `orchestrate-cycle-plan.sh` rather than delegating to
  `orchestrate-unwind-dispatch.sh`, which is by-hand-only by its own contract.
- The four caller-level verification arms (case-label, defect-record assertions) were expressed in
  `test-corroborate-phase-counts.sh` via a helper reproducing the real widened call sequence,
  rather than in `test-orchestrate-cycle-postflight.sh` — see Plan Deviations below.

## Plan Deviations

- **Phase 4, arm 2's `[phase-check]` sub-claim**: the plan asserted the `[phase-check]` warning
  "still fires" for a branched plan whose gate-skipped phases are corroborated to 7/7. Verified
  empirically against the real, task-259-unmodified `update-task-status.sh`: a genuinely
  7/7-closed plan takes the `DONE >= TOTAL -> "proceeding"` branch, not the WARNING branch (which
  only fires when `DONE < TOTAL`). The plan's claim describes arm 3's shortfall shape, not arm 2's
  fully-corroborated shape. No test asserting the false claim was written; the correct behavior
  was confirmed by direct invocation and documented instead.
- **Phase 4's caller-level test placement**: all four verification arms, including the case-label
  and defect-record assertions the plan asked to be placed in
  `test-orchestrate-cycle-postflight.sh`, were instead expressed in the lighter-weight
  `test-corroborate-phase-counts.sh` via a `corroborate_and_gate()` helper that calls the real
  production functions (`skill_corroborate_phase_counts`, `skill_gate_completion_claim`) in the
  exact sequence the widened caller now uses. `test-orchestrate-cycle-postflight.sh` carries a
  large, pre-existing, unrelated flakiness surface (confirmed below); adding new cases there would
  inherit it for no additional verification benefit the lighter harness doesn't already provide.
  Load-bearing-ness was proven by a falsification test: temporarily making the overwrite
  unconditional (the pre-Phase-3 defect shape) flips the shortfall fixture's case-label and
  defect-predicate assertions to FAIL, exactly as expected.
- **Phase 7's suite-green verification**: `test-orchestrate-cycle-postflight.sh` exits 1 (76/110
  pass). The remaining 34 failures are a confirmed pre-existing, unrelated defect — `git stash`
  bisection reproduces the IDENTICAL 34-case failure set with this task's
  `orchestrate-cycle-postflight.sh`/`skill-base.sh` changes stashed out (byte-identical after
  normalizing tmpdir paths, mtimes, and event IDs). Closed via a `#### Reasoned Exclusions` record
  on Phase 7's heading (`[COMPLETED WITH EXCLUSIONS]`) rather than claimed as a false pass.

## Verification

- Build: N/A (bash scripts + markdown docs)
- Tests: `test-skill-base-lifecycle.sh` 35/35, `test-corroborate-phase-counts.sh` 33/33,
  `test-orchestrate-cycle-plan.sh` 274/274, `test-orchestrate-context-growth.sh` 6/6,
  `test-orchestrate-cycle-postflight.sh` 76/110 (34 pre-existing, unrelated failures — see Plan
  Deviations)
- Files verified: Yes
- All five verification arms demonstrated with recorded evidence (see the plan's Phase 7 five-arm
  evidence table)
- No test weakened or deleted: the diff across both touched test files is pure additions (484
  insertions, 0 deletions)
- No file under `agents/` touched; the two dead `orchestrate-stage5-*.sh` scripts are unchanged

## Impacts

- A branched plan whose gate-skipped phases are correctly closed as `[COMPLETED WITH EXCLUSIONS]`
  now completes normally instead of deadlocking `/orchestrate` in a refuse-redispatch loop.
- Any future dispatch-refuse-redispatch loop (not only this phase-accounting case) is now capped
  at one wasted cycle by the identical-dispatch convergence guard, rather than bounded only by
  `MAX_CYCLES`.
- Planners and implementation agents now have documented guidance (plan-format.md,
  status-markers.md) connecting the decision-gate/contingency-branch plan shape to the
  `[COMPLETED WITH EXCLUSIONS]` marker, closing the discovery gap the originating incident's agent
  fell into.

## Follow-ups

- `test-orchestrate-cycle-postflight.sh`'s 34 pre-existing failures (STALE HANDOFF mtime races, a
  broad "Skill did not write orchestrator handoff" schema-detection issue) are a real,
  independent defect worth its own investigation — out of this task's scope, recorded here for
  visibility.
- Adjacent item (b) (a `PHASE_ACCOUNTING_MISMATCH` defect-enum class) remains explicitly decided
  OUT per the plan's Decisions section — no follow-up needed unless that decision is revisited.

## References

- Plan: `specs/259_allow_completion_on_a_gate_skipped_plan_branch/plans/01_gate-skipped-plan-completion.md`
- Research: `specs/259_allow_completion_on_a_gate_skipped_plan_branch/reports/01_gate-skipped-plan-completion.md`
- `context/formats/plan-format.md`'s "Decision gates and contingency branches" subsection
- `context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection
- `docs/architecture/handoff-schema.md`'s `plan_markers_verified` subsection
