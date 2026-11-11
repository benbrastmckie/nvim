# Implementation Summary: Task #446

- **Task**: 446 - Close the plan-to-file_scope reconciliation gap
- **Status**: [COMPLETED]
- **Started**: 2026-11-09T13:23:17Z
- **Completed**: 2026-11-09T17:30:00Z
- **Effort**: ~4 hours
- **Dependencies**: 430 (COMPLETED), 443, 407, 385, 328 (serialization only)
- **Artifacts**: plans/01_close-plan-file-scope-gap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the plan-to-`file_scope` reconciliation gap along its two named axes. PART A ruled a
deployed-tree path (`.claude`, `.claude/`, or anything prefixed `.claude/`) never a legitimate
`file_scope` member, and enforced the refusal at the harvester (`plan-file-scope-harvest.sh`)
plus the deposit and containment sites inside `git-commit-phase.sh`, closing a previously-live
loophole where a bare `.claude/` `file_scope` entry caused the Containment predicate to admit
every deployed-tree path. PART B extended the already-shipped `proposed_file_scope` deposit
channel with a mechanical follow-up-commit trigger in the implementing agent's own protocol, so
a within-dispatch drop is never lost to an unread `WARNING:` line again. Six phases landed; all
carry `[COMPLETED]` in the plan file.

## What Changed

- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` — added the deployed-tree
  refusal stage (a structural prefix test, never filesystem validation) filtering the final
  merged harvest array, with a loud per-entry stderr warning and the exit-code/`[]` contract
  unchanged. Header documents the refusal and the `__WHOLE_TREE__` sentinel escape hatch.
- `agent-system/extensions/core/context/formats/plan-format.md` — added the one-path-per-line
  anti-pattern paragraph (wrapped-continuation and comma-join shapes) and the never-name-a-
  deployed-path paragraph to the `Files to modify` field definition, plus a new "Enforcement
  level (Files to modify authoring shape)" subsection.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — added three advisory
  (`log_warn`-only) authoring-shape checks inside the existing per-phase loop: the
  wrapped-continuation shape, the comma-join shape, and a directly-named deployed-tree path.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — refuses a deployed-tree deposit in
  `propose_file_scope_addition()`; strips deployed-tree entries from the Containment Self-Check's
  `file_scope_arr` before the own-task-directory/engine-written-state splices, with a post-strip
  non-emptiness re-test falling through to the existing fail-open path; adds a read-only
  `proposed_file_scope_lookup` that annotates (never suppresses or admits) a repeat drop's
  warning text with an already-known pointer to the follow-up-commit remedy.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — added the mechanical
  follow-up-commit trigger (a before/after comparison of `proposed_file_scope`) at both the
  per-objective green-substep and per-phase commit sites, and updated the Containment Self-Check
  step-by-step prose to describe the deployed-tree strip and the read-only annotation lookup.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added "A third
  asymmetry, deliberately left open" documenting that the deployed-tree strip and the
  within-dispatch lookup are site-2-only, with the Site-3 residual this leaves.
- Extended fixtures in `test-plan-file-scope-harvest.sh` (Cases 23-25, 39 total),
  `test-validate-artifact.sh` (FTM-shape cases g/h, 59 total), `test-git-commit-phase.sh` (Cases
  25-28, 63 total), and `test-skill-base-lifecycle.sh` (mixed-entry Group 4a extension, 72 total).
- Redeployed the source store; all ten edited source-store files confirmed byte-identical to
  their deployed counterparts.

## Decisions

- No harvester grammar widening (explicitly rejected in the plan's own Research Integration
  section): the #417 citation's comma-join and wrapped-continuation shapes are pinned as
  unchanged, documented behavior, not fixed — authoring-time advisory detection (PART A, Phase 2)
  is the sanctioned fix instead.
- The deployed-tree refusal is a pure structural prefix test on the string, categorically never
  a filesystem/existence check, at every one of the three points identified (harvester, deposit,
  containment-site assembly) — preserving the harvester's documented never-validates posture.
- **Phase 4's union was built and rejected.** A literal admitting union (making an already-
  deposited path survive Site 2's Containment check) regressed `test-git-commit-phase.sh`'s own
  pre-existing idempotence fixture (Case 20) under two different designs, because
  `git-commit-scoped.sh` carries its own, separate, un-patched Site-3 V10 containment guard that
  independently vetoes based on the still-unwidened declared `file_scope`. Shipped instead: a
  read-only lookup that only annotates a repeat drop's warning text, leaving the
  drop/warn/issue-record/deposit cadence completely unchanged. See the Phase 4 progress file's
  `approaches_tried` for both rejected designs in full.

## Plan Deviations

- **Phase 1 & 2**: the verification command literally named in each phase's Tier Justification
  (deployed-mode `run-all.sh --only ...`) was run against the SOURCE STORE instead, because this
  dispatch's deploy-freshness-context flagged the deployed `core` extension as stale at dispatch
  start; both modes were run where informative, only the source-store result is probative.
- **Phase 3**: the Case 26 fixture ("`file_scope` of only `.claude/` strips to empty and fails
  open") was narrowed to assert only `git-commit-phase.sh`'s own Containment Self-Check behavior,
  not the full end-to-end commit outcome, after discovering the Site-3 residual (below).
- **Phase 4**: the planned admitting union was replaced by a read-only annotation lookup (see
  Decisions above). This is the single most significant deviation in this task.
- **Phase 5**: the Self-Check step-3/step-4 prose and `git-staging-scope.md`'s "Three Containment
  sites" section were written to describe the annotation-lookup design actually shipped, not the
  union the plan's Phase 5 task list literally describes, to keep the durable documentation
  truthful.
- **Phase 6**: the mixed-entry fixture's stderr-propagation assertion was redirected to invoke
  the harvester directly (rather than through `skill_postflight_update`), because
  `skill-base.sh`'s own plan-branch call site redirects the harvester's stderr to `/dev/null` by
  design (unedited by this task). The "run the complete gate set unnarrowed" task was discharged
  per this dispatch's Batch Gate Deferral directive as a scoped `run-all.sh --only` invocation for
  `run-all.sh` specifically, while the repo-wide task-reference lint and `validate-state.sh` ran
  genuinely unnarrowed (both clean for this task).

## Verification

- Build: N/A (meta/shell task)
- Tests: `test-plan-file-scope-harvest.sh` 39/39, `test-validate-artifact.sh` 59/59,
  `test-git-commit-phase.sh` 63/63, `test-skill-base-lifecycle.sh` 72/72 — all passing, each
  extended with this task's own fixtures. Agent-contract lint: 421 passed / 15 pre-existing
  warnings (none new). Scoped-commit-boundary, task-reference, and record-version lints: 0
  BLOCKING on every file this task touched.
- Files verified: all ten edited source-store files confirmed byte-identical to their deployed
  counterparts after `deploy-headless.sh`.

## Impacts

- A plan whose "Files to modify" block names a deployed-tree path is now refused (not silently
  dropped and forgotten) at the earliest possible point — plan-postflight harvest time — with the
  option for an authoring-time advisory warning at `/orchestrate --plan` acceptance.
- The previously-live loophole (a bare `.claude/` `file_scope` entry wrongly admitting every
  `.claude/**` path at `git-commit-phase.sh`'s own Containment Self-Check) is closed.
- An implementing agent now has a mechanical, before/after `proposed_file_scope` comparison to
  trigger a scoped follow-up commit, replacing "read the WARNING output" as the loop-closing step
  — though landing a within-dispatch-recorded drop still requires that dedicated follow-up
  commit; it is never automatic on a later phase's ordinary commit (see Follow-ups).

## Follow-ups

- **Site-3 residual** (recorded, non-blocking, `git-staging-scope.md`'s own new subsection):
  `git-commit-scoped.sh`'s separate V10 containment guard does not share Phase 3's deployed-tree
  strip or Phase 4's annotation lookup. A future task could port the same strip into its
  `containment_scope_arr` resolution block to close this fully — out of this task's declared
  `file_scope` (`git-commit-scoped.sh` and its test suite are not members of it).
- Five pre-existing, unrelated defects were discovered and recorded via `issue-record.sh` during
  this task's own verification (none in this task's `file_scope`, none fixed here):
  `test-orchestrate-cycle-postflight.sh`'s failures; `test-task-type-detect.sh`'s deployed-mode
  failure (`common_test_resolve_candidate()`'s `[ -f ... ]` test misapplied to a directory
  candidate); a lean-extension shellcheck finding; two memory-extension dead-command-
  recommendation hits; and three Himalaya-plugin-docs record-versioning BLOCKING hits.
- Live `specs/state.json` `.claude/**` `file_scope` residue re-measured at phase 6: 4 entries
  across 2 tasks (483, 512), unchanged from the plan's own research-time count. Left untouched
  per this task's Non-Goals (never narrowing another task's declaration); neutralized at the
  containment site by Phase 3's strip whenever those tasks' own phase commits run.

## References

- Plan: `specs/446_close_the_plan_to_file_scope_reconciliation_gap/plans/01_close-plan-file-scope-gap.md`
- Report: `specs/446_close_the_plan_to_file_scope_reconciliation_gap/reports/01_plan_to_file_scope_reconciliation_gap.md`
- Progress files: `specs/446_close_the_plan_to_file_scope_reconciliation_gap/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/446_close_the_plan_to_file_scope_reconciliation_gap/handoffs/phase-{1..6}-handoff-*.md`
