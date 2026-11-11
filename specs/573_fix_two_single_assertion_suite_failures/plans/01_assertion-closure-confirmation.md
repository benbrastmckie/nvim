# Implementation Plan: Task #573

- **Task**: 573 - Fix two single-assertion suite failures
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: Task 589 (test_suite_repo_root_walk_up_depth) -- already completed; its commits `6a0d6a373` and `9bc6a7d18` carry the actual fix
- **Research Inputs**: specs/573_fix_two_single_assertion_suite_failures/reports/01_assertion-failures-closed-by-589.md
- **Artifacts**: plans/01_assertion-closure-confirmation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Both of this task's named single-assertion failures were root-caused and fixed under task 589
(invocation-path-dependent repo-root resolution, migrated to
`common_test_repo_root`/`common_test_ext_root`), which closed before this plan was written. This
is therefore a closure-confirmation plan, not a diagnosis-and-fix plan: it establishes live
evidence that both suites are green under the *originally failing* invocation path (`run-all.sh`
gate 8's entry point, not merely bare standalone invocation), records that closure in this task's
durable artifacts, and discharges the full gate set. No source file changes. Definition of done:
both suites measured green under `run-all.sh --only` from both the deployed and source-store
entry points in the implementing dispatch, a summary recording those tallies, and a clean full
gate run.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch's Premise Re-Validation section extracted the description addendum's trigger-class
claims. Checked against the prior artifact and against live state in this plan dispatch:

| Carried claim (from the description) | Status after check | Live measurement in this dispatch |
|---|---|---|
| `test-deploy-baseline-lib.sh`: 29 passed, 1 failed | **STALE** -- superseded by task 589's fix | 30 passed, 0 failed (deployed path and source-store path alike) |
| `test-lint-deploy-caller-wrap.sh`: 10 passed, 1 failed | **STALE** -- assertion *total* also changed (11 -> 7), not just the pass/fail split | 7 passed, 0 failed (both paths) |
| Failing assertion text "control: a genuinely matching warm-cache entry was expected to skip gate 1 but did not" | **NO LONGER REPRODUCES** | Now reads `[PASS] control: a genuinely matching warm-cache entry DOES skip gate 1 (SKIP-CACHED) ...`, with no chmod/mtime sandbox-artifact stderr |
| "both suites are among five whose repo-root resolution hardcodes a walk-up depth" | **CONFIRMED, and now remediated** by task 589 | Both suites now invocation-path-independent; identical tallies from both paths |
| `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` fixture-copy mechanism is NOT the cause | **CONFIRMED unchanged** | Task 589's actual fix touched only root resolution, corroborating the exclusion |

Two further authoring-time checks, both stated so the implementer knows what was and was not
confirmed:

- Neither suite basename appears in `agent-system/extensions/core/scripts/tests/known-failures.txt`
  (checked by grep at authoring time), so there is no stale manifest row to retire for either.
- `suite_selection_select` over the two suite paths resolves to
  `test-deploy-baseline-lib.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-orchestrate-batch-gate.sh` -- recorded for the implementer's benefit only; no phase in
  this plan modifies either suite file, so this mapping is not load-bearing for any tier claim
  below.

### Research Integration

The research report's single finding is that this task's work was already delivered: direct
standalone re-execution from both invocation paths returned 30/0 and 7/0, matching the live
re-measurement recorded above exactly. Its recommendation -- close with a
confirmation-only implementation that records the re-measurement evidence rather than re-running
a diagnosis already performed twice -- is what this plan's two phases implement. Its explicit
non-goals are honored: no assertion is relaxed, and the two out-of-scope follow-ups already
recorded under task 589 (the `verify-deploy.sh` `gate8_run` wrapper exit-code discrepancy, and a
prospective `lint-test-root-resolution.sh` closing the defect class by construction) are neither
re-opened nor duplicated here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch (`roadmap_path` absent, `roadmap_flag` not set),
so no roadmap items are claimed and no roadmap-review/update phases are added.

## Goals & Non-Goals

**Goals**:
- Establish live, in-dispatch evidence that both named suites pass under the `run-all.sh` entry
  point that originally exposed the failures, from both the deployed and source-store paths.
- Record the closure -- including the measured tallies and the explicit fact that this task
  changed no source file, and why -- in this task's own durable summary artifact.
- Discharge the full gate set so the task closes on a clean, unnarrowed verification run.

**Non-Goals**:
- Changing either suite's assertion logic or either subject's behaviour. The addendum's
  instruction "Do not fix either symptom by relaxing a control case" is satisfied by construction:
  the correct fix was to the shared root-cause resolver, and it already landed.
- Re-performing the diagnosis. It has been completed twice (once under task 589, once in the
  research dispatch) and re-confirmed a third time at this plan's authoring.
- Building the `lint-test-root-resolution.sh` class-closing lint, or chasing the
  `verify-deploy.sh` `gate8_run` wrapper exit-code discrepancy. Both are recorded follow-ups
  owned elsewhere.
- Editing `agent-system/extensions/core/scripts/tests/known-failures.txt`. Nothing needs
  retiring there, and a concurrent sibling task holds that file in its declared scope this cycle
  (see Risks below).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A sibling task's in-flight whole-tree regeneration changes the deployed suite copies mid-measurement, producing a tally that reflects neither a real regression nor a real pass | M | M | Re-read both suite files immediately before measuring; measure the source-store path as well as the deployed path and require the two to agree; treat a disagreement as a concurrency artifact to report, not a regression to fix |
| A measurement in Phase 1 comes back non-green, tempting a quick assertion relaxation to close the task | H | L | Phase 1's tasks require STOP-and-report on any non-green result; relaxing a control case is an explicit non-goal, and the original addendum forbids it |
| The full gate run in Phase 2 fails on something unrelated to this task (e.g. a known-failing suite or a sibling's in-flight edit) and is misread as this task's regression | M | M | Compare any failure against `known-failures.txt` and against this task's own (empty) source footprint before attributing it; an out-of-footprint failure is reported, not fixed here |
| A `known-failures.txt` row for either suite appears between authoring and implementation, leaving a stale manifest row behind | L | L | Phase 2 re-checks the manifest and reports a newly appeared row rather than editing the file, since a sibling task holds it in scope this cycle |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-confirm closure under the originally-failing invocation path [NOT STARTED]

**Goal**: Produce live, in-dispatch evidence that both suites pass under the `run-all.sh` entry
point -- the path on which the failures originally appeared -- from both the deployed and
source-store invocation paths, so closure does not rest on bare standalone invocation alone.

**Tasks**:
- [ ] Re-read both suite files immediately before measuring (`agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` and `.../test-lint-deploy-caller-wrap.sh`, plus their deployed counterparts) and note whether either differs from its state at this plan's authoring; a sibling task holds whole-tree scope this cycle.
- [ ] Run `bash .claude/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh` and capture the per-suite result lines, the roster/tally line, and the exit status verbatim.
- [ ] Run the source-store twin, `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh`, and capture the same three things.
- [ ] Confirm the two runs agree on both suites' tallies. A disagreement between the paths is the exact symptom class task 589 fixed -- if one appears, STOP and report it as a possible regression of 589's fix, do not proceed to Phase 2.
- [ ] If either suite is non-green in either run, STOP and report. Do not relax, delete, skip, or re-tune any assertion, and do not add a `known-failures.txt` row to paper over it.
- [ ] Re-check `agent-system/extensions/core/scripts/tests/known-failures.txt` for either suite basename and record the result (expected: absent for both, as at authoring).

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the live tallies are `test-deploy-baseline-lib.sh` 30
passed / 0 failed and `test-lint-deploy-caller-wrap.sh` 7 passed / 0 failed, and that both suites
agree across the two invocation paths -- confirmed standalone from both paths at this plan's
authoring. The implementer confirms it by reading the `--only` runs' own per-suite output in this
dispatch, never by citing this plan's figures.

**Tier Justification**: This phase modifies no file -- so `suite_selection_select` has no touched
path to resolve and no suite-coverage claim is being asserted about one -- and the covering check
is the phase's own measurement command, `bash .claude/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh`, run from both entry points.

**Files to modify**:
- none planned - this phase is measurement-only and writes no file; its product is the captured output carried into Phase 2.

**Verification**:
- Both `--only` runs completed with exit status 0 and each reported both selected suites passing,
  with the two runs' per-suite tallies identical.
- The captured output is in hand for Phase 2 to transcribe (not a remembered summary of it).
- The `known-failures.txt` re-check result is recorded either way.

---

### Phase 2: Record the closure and discharge the full gate set [NOT STARTED]

**Goal**: Write this task's durable closure record carrying Phase 1's measured evidence, and run
the complete gate set so the task closes on an unnarrowed verification run.

**Tasks**:
- [ ] Write `specs/573_fix_two_single_assertion_suite_failures/summaries/01_assertion-closure-confirmation-summary.md`, transcribing Phase 1's captured tallies and exit statuses verbatim (both invocation paths), per summary-format.md.
- [ ] State plainly in that summary that this task changed no source file, and why: the shared root cause (invocation-path-dependent repo-root resolution) and its fix both belong to task 589, whose commits `6a0d6a373` and `9bc6a7d18` carry it; this task's contribution is independent re-verification plus closure.
- [ ] Record in the summary that the description's carried figures (29/1 and 10/1) are stale, and that `test-lint-deploy-caller-wrap.sh`'s assertion *total* changed from 11 to 7 because 589 removed a double-count rather than flipping one assertion's polarity.
- [ ] Record the `known-failures.txt` re-check outcome. If a row for either suite has appeared since authoring, report it in the summary and leave the file untouched -- a concurrent sibling holds that file in its declared scope this cycle, so its removal is not this task's edit to make.
- [ ] Confirm no new follow-up task is warranted, and explicitly do not duplicate task 589's two already-recorded out-of-scope follow-ups (the `verify-deploy.sh` `gate8_run` wrapper exit-code discrepancy; a prospective `lint-test-root-resolution.sh`).
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Attribute any failure against this task's own (empty) source footprint and against `known-failures.txt` before treating it as this task's regression; an out-of-footprint failure is reported, not fixed here.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that the only file this task writes is its own summary
artifact under `specs/573_fix_two_single_assertion_suite_failures/summaries/`, with zero changes
to either suite file, to `known-failures.txt`, or to any other source-store file. The implementer
confirms it with `git status --short` before committing, and by staging an explicit file list
rather than a directory or glob.

**Files to modify**:
- `specs/573_fix_two_single_assertion_suite_failures/summaries/01_assertion-closure-confirmation-summary.md` - new; the durable closure record carrying Phase 1's measured tallies, the stale-figure correction, and the no-source-change rationale

**Verification**:
- The complete gate set has been run in this dispatch and observed green:
  `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `bash agent-system/extensions/core/scripts/verify-deploy.sh`), covering all gates it
  aggregates -- not a `--only-gate` subset and not a `--skip-slow` pass.
- The summary file exists, is non-empty, and carries Phase 1's tallies for both suites from both
  invocation paths.
- `git status --short` shows no modification to either suite file or to `known-failures.txt`
  attributable to this task.

## Testing & Validation

- [ ] `bash .claude/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh` exits 0 with both suites passing.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh` exits 0 with identical per-suite tallies.
- [ ] `bash .claude/scripts/verify-deploy.sh` completes green (full gate set, no gate subset, no `--skip-slow`).
- [ ] `bash .claude/scripts/validate-artifact.sh specs/573_fix_two_single_assertion_suite_failures/summaries/01_assertion-closure-confirmation-summary.md summary` passes.
- [ ] `git status --short` confirms this task's footprint is the summary artifact alone.

## Artifacts & Outputs

- `specs/573_fix_two_single_assertion_suite_failures/plans/01_assertion-closure-confirmation.md` (this plan)
- `specs/573_fix_two_single_assertion_suite_failures/summaries/01_assertion-closure-confirmation-summary.md` (Phase 2)
- No source-file outputs. This task's source footprint is deliberately empty.

## Rollback/Contingency

The only file this plan writes outside `specs/**` is none at all, so rollback is trivial: delete
or rewrite the summary artifact. No working-tree snapshot is needed, and no reverting
`git-snapshot.sh` invocation is warranted here -- there is no destructive operation in either
phase to roll back from. Should a genuine rollback ever become necessary, follow
`context/contracts/recovery.md`'s rollback rung for the correct invocation shape rather than
improvising one.

Contingency if Phase 1 measures a non-green result: do not proceed to Phase 2 and do not touch
either assertion. Report the exact failing assertion text and both invocation paths' output, and
treat it as a candidate regression of task 589's root-resolution fix -- which is a new finding
about that fix, not a license to re-tune a control case here.
