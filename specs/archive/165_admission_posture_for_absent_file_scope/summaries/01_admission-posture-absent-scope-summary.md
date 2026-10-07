# Implementation Summary: Admission gates in orchestrate-batch-admit.sh: posture for an absent `file_scope`, then cross-session visibility for self-modifying candidates

- **Task**: 165 - Admission gates in orchestrate-batch-admit.sh: posture for an absent `file_scope`, then cross-session visibility for self-modifying candidates
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T22:50:00Z
- **Completed**: 2026-10-03T04:10:00Z
- **Effort**: ~9 hours (matching the plan's estimate)
- **Dependencies**: None outstanding
- **Artifacts**: plans/01_admission-posture-absent-scope.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

Implemented the split admission posture for an absent `file_scope` in
`orchestrate-batch-admit.sh`: cross-batch absence stays advisory-only (a new
`absent_scope_advisory` verdict field, no version bump) with a recorded promotion criterion,
while in-batch absence becomes blocking via a new `absent_file_scope` `defer_reason` converging
through the same designated-candidate tie-breaker pattern `self_modifying` already uses (schema
bump v5 -> v6). Additively closed a second, independent defect: a solo self-modifying candidate's
admit verdict now carries a `cross_session_hazard` field naming a live foreign session's
overlapping covered scope, without ever changing the admit decision. Both observed incidents
(a BimodalLogic cross-batch collision and a Logos/Verification 8-task in-batch collision) are
reproduced as fixture cases whose outcomes demonstrably change. Both executing consumers
(`orchestrate-cycle-plan.sh`, `orchestrate-predispatch-review.sh`) were updated, and a
previously-latent silent-exclusion gap in the executing gate's `case "$dr" in` block (no default
arm) was closed in the same change set. A broad regression sweep across 24 test suites found and
fixed 12 pre-existing failures this new rule surfaced in unrelated legacy fixtures.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — v6 verdict schema; header
  ruling section recording the split posture, its tradeoff, the measured coverage, and the
  promotion criterion; `absent_scope_advisory` field (additive); `absent_file_scope` defer_reason
  with `designated_absent_candidate` payload and override-semantics documentation;
  `cross_session_hazard` field (additive) on the three self-modifying admit branches; Precedence
  block extended for mutual-exclusivity and the additive session-advisory note.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` — 8 new fixture
  cases (IN-BATCH-ABSENCE, CROSS-BATCH-ABSENCE, SOLO-SELF-MOD-CROSS-SESSION,
  PHASE-EXEMPT-ABSENCE, SOLO-ABSENT-SCOPE-NON-REGRESSION, SOLO-SELF-MOD-NO-CROSS-SESSION-OVERLAP,
  SOLO-SELF-MOD-SESSION-ID-OMITTED, SCHEMA-LITERAL), written TDD red/green style against the
  target post-fix shape from the start.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — bumped the one assertion
  pinning the `$schema` literal to v6.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — v5 -> v6 Version
  History entry with the full consumer table, a new "Admission Posture for an Absent `file_scope`
  (v6 Ruling)" section, two new example verdict JSON blocks, Field Definitions rows for
  `absent_scope_advisory`/`designated_absent_candidate`/`cross_session_hazard`, and a Precedence
  section update.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — new `absent_file_scope` case
  arm and a loud `*)` default arm in the executing gate's `case "$dr" in` block (closing a
  pre-existing silent-exclusion gap); `absent_scope_ledger`/`cross_session_hazard_ledger`/
  `unrecognized_defer_reason_ledger` mt_state_file fields.
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — new Class H
  (`absent_file_scope` defers) and Class H-admitted (`absent_scope_advisory`), new Class I
  (`cross_session_hazard`), Class F cross-reference, header class-inventory update (SEVEN -> NINE
  classes).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — repaired 12
  pre-existing failures the new in-batch rule surfaced in legacy multi-candidate fixtures sharing
  an empty/absent `file_scope` for reasons unrelated to admission (lock refusal, session-id
  suffixing, `--compare` forwarding, sibling-territory rendering, streak-freeze, build-heavy
  co-scheduling); added a new Group 34 regression case for the default-arm fix.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  "Absent file_scope Hazard: The Split Admission Posture (v6)" section (both incidents, the
  split ruling, the measured coverage, the promotion criterion, the additive cross-session fix),
  two new Classification Table rows, one new Gate Catalogue row.

## Decisions

- Wrote the three red-baseline fixture cases (Phase 1) against the TARGET post-fix shape rather
  than literally asserting "today's behavior", per the standard TDD red/green convention — this
  was required to satisfy Phases 2-4's own "remains red until Phase N" Verification language,
  which a literal current-behavior assertion would have contradicted immediately.
- Named the deployment repositories generically in the script header's ruling section (rather
  than citing proper names) to avoid baking an external project's identity into shared,
  broadly-deployed infrastructure documentation; the pattern-doc narrative (a different
  document, aimed at a different reader) does cite them by name and command per the dispatch's
  explicit instruction.
- `cross_session_hazard` has no "-admitted" counterpart class in `orchestrate-predispatch-review.sh`
  (it is its own Class I) since the field only ever appears on an admit verdict — there is no
  defer-side shape to split it from.

## Plan Deviations

- **Phase 1**: the three red-baseline fixture cases were written against the target post-fix
  shape (TDD red/green), not literally "today's behavior" as the task bullets said — see that
  phase's own deviation note for the full rationale; the Verification sections across Phases 2-4
  require exactly this progression.
- **Phase 2**: the measured-coverage prose names deployment repositories generically rather than
  by proper name (numbers and date preserved exactly).
- **Phase 5**: `test-orchestrate-cycle-plan.sh` was not in that phase's declared Files to modify,
  but running the full test corpus (required by this plan's own repeated "every pre-existing case
  still PASSes" bar) surfaced 12 pre-existing failures Phase 3's new rule caused in that suite's
  legacy fixtures; repaired in the same phase rather than left red.
- **Phase 6**: the three newly-triaged "NEW" `run-all.sh` failures were confirmed pre-existing and
  unrelated (full triage in that phase's completion note) but were deliberately NOT added to
  `known-failures.txt`, since that manifest is outside this task's declared scope.

## Verification

- Build: N/A (shell scripts + markdown docs)
- Tests: `test-orchestrate-batch-admit.sh` 11/11 PASS (0 failed for the first time after Phase 4);
  `test-conflict-predicate.sh` 33/33; `test-four-tier-conflict.sh` 13/13;
  `test-orchestrate-predispatch-review.sh` 34/34; `test-orchestrate-cycle-plan.sh` 344/344 (was
  328/12 before this task's regression repair); `test-orchestrate-cycle-postflight.sh` 153/153.
  `shellcheck` clean on every edited `.sh` file, identical to each file's own pre-task baseline.
  `bash .claude/scripts/check-task-references.sh`: 0 unexempted occurrences. Full deploy:
  `verify-deploy.sh` 33/33 checks, 0 failures. `run-all.sh`: 98/104 passed; the 6 failures are all
  confirmed pre-existing and unrelated to this task (3 already in `known-failures.txt`; 3 newly
  triaged and confirmed via source-store reproduction and `git stash` isolation — see Phase 6's
  completion note in the plan for the full per-suite evidence).
- Files verified: Yes

## Impacts

- Closes the silent-passage hole where a co-dispatched batch of absent-`file_scope` tasks could
  run fully concurrent with zero collision-guard coverage (the motivating Logos/Verification
  incident) — now serialized one-per-cycle via the designated-candidate tie-breaker.
- Cross-batch absence stays non-blocking (deliberately, pending the recorded coverage-based
  promotion criterion), but is no longer silent — every such verdict now carries an advisory
  naming the remedy.
- A solo self-modifying candidate's verdict now surfaces a live cross-session hazard it
  previously could never see at all, without changing when such a candidate is admitted.
- `orchestrate-cycle-plan.sh`'s executing gate can no longer silently exclude a task on an
  unrecognized future `defer_reason` value — it now warns loudly and records a ledger entry.

## Follow-ups

- Promote cross-batch absence from advisory to blocking once `validate-state.sh --strict` reports
  zero Check 10 `missing_key`/`null_value` findings across every repository this system deploys
  into (recorded promotion criterion; not performed by this task).
- Consider formally accepting the three newly-triaged `run-all.sh` failures
  (`test-detect-noop-bash.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-orchestrate-build-aux-dispatch.sh`) into `known-failures.txt`, or fixing their underlying
  deploy-vs-source-store path-resolution defects — both confirmed pre-existing and unrelated to
  this task, triaged in Phase 6's completion note.

## References

- Plan: `specs/165_admission_posture_for_absent_file_scope/plans/01_admission-posture-absent-scope.md`
- Research: `specs/165_admission_posture_for_absent_file_scope/reports/01_admission-posture-absent-scope.md`
- Schema doc: `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- Pattern doc: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
