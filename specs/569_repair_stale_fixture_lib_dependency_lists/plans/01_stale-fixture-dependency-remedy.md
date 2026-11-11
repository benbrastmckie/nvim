# Implementation Plan: Task #569

- **Task**: 569 - Repair stale fixture lib dependency lists
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/569_repair_stale_fixture_lib_dependency_lists/reports/01_stale-fixture-dependency-lists.md
- **Artifacts**: plans/01_stale-fixture-dependency-remedy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`state-write.sh` unconditionally sources `lib/project-number-inuse.sh` at
`agent-system/extensions/core/scripts/state-write.sh:214`. Three fixture-based test suites copy
`state-write.sh` into a throwaway temp root using a hand-maintained dependency allow-list that
omits that library, so the copied script aborts on the `source` builtin, every fixture
`state.json` write fails, and the caller reports its own generic exit 2. The remedy is a
one-line addition to each of two curated arrays and a two-line addition to the third suite's
`require_file` list plus its `setup_sandbox()` copy loop, followed by retirement of the three
now-stale `known-failures.txt` rows and a redeploy-plus-full-gate confirmation.

### Premise Re-Validation (carried figures checked against live state)

Every measurable claim the dispatch description carries was re-checked in this dispatch, not
assumed:

- **Confirmed unchanged**: `state-write.sh:214` is
  `source "${SCRIPT_DIR}/lib/project-number-inuse.sh"`, unconditional, with no guard.
- **Confirmed unchanged**: `test-postflight-deploy-gate.sh` → `Results: 17 passed, 12 failed`;
  `test-redeploy-checkpoint-promotion.sh` → `Results: 10 passed, 7 failed`;
  `test-orchestrate-predispatch-review.sh` → `Results: 35 passed, 2 failed`. All three re-run
  standalone during this dispatch; all three tallies match the description exactly.
- **Corrected (and the research report's scope correction confirmed)**:
  `test-orchestrate-unwind-dispatch.sh` now reports `Results: 21 passed, 0 failed`, not the
  description's "10 passed, 11 failed". Its `REQUIRED_LIB_SCRIPTS` array already carries
  `project-number-inuse.sh` (line 42). It is excluded from this plan's file list entirely — no
  phase touches it.
- **Confirmed unchanged**: `project-number-inuse.sh` is the only missing library. The three
  affected suites already carry `common.sh`, `task-lookup-lib.sh`, and `file-scope-overlap.sh`;
  `project-number-inuse.sh` itself contains no `source` line of its own, so it introduces no
  further transitive dependency.
- **Confirmed by direct observation, newly measured here**: the failure signature is
  single-caused. `test-orchestrate-predispatch-review.sh`'s first `[FAIL]` line names the missing
  library verbatim
  (`state-write.sh: line 214: <fixture>/.claude/scripts/lib/project-number-inuse.sh: No such file
  or directory`), and every `[FAIL]` line in the other two suites is either `expected exit 0, got
  2` or a downstream consequence of a `state.json` write that never landed
  (`expected status 'completed', got 'implementing'`; `deploy_pending='true'`; an absent promoted
  notice). No failure line in any of the three indicates a second, independent cause.
- **Newly established, not in the description or the report**: all three affected suites hold a
  `real-defect|...|needs-owner` row in `agent-system/extensions/core/scripts/tests/known-failures.txt`
  (lines 51, 52, 53). The predispatch-review row's own reason text names this exact defect
  ("not present in the fixture's hardcoded dependency copy-list"). Those three rows become stale
  the moment the fix lands and must be retired in the same task; the roster is advisory-only, so
  nothing fails if they are left behind — which is precisely why they would otherwise rot.
- **Newly established**: gate 8 executes the **source-store** runner
  (`verify-deploy.sh` runs `bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh"`),
  so the fix is visible to the gate without a redeploy. A redeploy is nonetheless required before
  task completion, because the postflight completion-deploy gate refuses when `modified_files`
  overlap `agent-system/extensions/**` and the deployed tree is stale.

### Research Integration

The research report's findings are adopted in full:

- Its scope correction (three suites, not four) is adopted and independently re-confirmed above.
- Its exact per-file fix locations are adopted as the phase tasks below.
- Its answer to the dispatch description's secondary design question ("should these lists be
  derived from the subject script's own source lines") is adopted as written: a corpus-wide
  re-derivation found **zero drift beyond the three known suites**, so a runtime change replacing
  the arrays would touch 8+ working suites to fix a defect that is not currently recurring
  elsewhere. A lint-time drift detector is the right-sized durable remedy and is recorded as a
  follow-up candidate, not built here (see Non-Goals).
- Its territory finding (no overlap with the concurrent siblings' declared file scopes) is
  adopted and re-checked against this dispatch's own Territory block.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted and must
not be modified by this task.

## Goals & Non-Goals

**Goals**:

- All three affected suites report `0 failed` standalone and inside gate 8's battery:
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`,
  `test-orchestrate-predispatch-review.sh`.
- Each fix is the minimal addition of `project-number-inuse.sh` to the suite's own existing
  dependency declaration — no change to any assertion, any fixture shape, or any logic under test.
- The three now-stale `known-failures.txt` rows are retired, so the roster stays the single
  truthful source for which suites are known-failing.
- The deployed tree is regenerated and the complete gate set runs green, leaving the task
  completable through the postflight completion-deploy gate.
- The "derive the lists from source" design question is answered on the record with the evidence
  that settles it, rather than left open for a future reader to re-derive.

**Non-Goals**:

- A runtime change deriving each fixture's copy list from the subject script's own `source` lines.
  Rejected on measured evidence: the re-derivation found no drift anywhere else in the corpus, so
  the change would touch 8+ working suites for no currently-observable defect.
- Building `lint-test-fixture-dependency-drift.sh` (the lint-time drift detector that would close
  this defect class by construction). Durable and worth doing, but a larger surface than this
  repair; recorded as a follow-up candidate.
- Any edit to `test-orchestrate-unwind-dispatch.sh`. It is already green at 21/21; editing an
  already-correct line defensively is a wasted commit on a file a concurrent sibling also reads.
- The audit-evidence gate in `state-write.sh`. It fires only on new `active_projects` entries;
  every affected fixture pre-seeds `active_projects` and transitions `status` only, so the gate is
  never reached. Confirmed out of scope by the dispatch description and the research report alike.
- Any edit under `.claude/**`. That tree is a gitignored deploy artifact; every edit lands in
  `agent-system/extensions/**` and reaches `.claude/` only via whole-tree regeneration.
- Converting any affected suite to the whole-directory `cp lib/*.sh` pattern. That pattern is
  structurally immune to this defect class, but switching a suite to it changes what the fixture
  contains and is a behavior change, not a repair.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A suite retains failures after the library is added, because some cases have a second, independent cause | M | L | Every remedy phase carries a Scope Hypothesis naming the exact expected post-fix tally; a residual failure is recorded via `issue-record.sh` and its `known-failures.txt` row is **narrowed to the residual**, never deleted. Phase 4 retires only rows whose suite was observed at `0 failed` |
| A concurrent sibling edits `known-failures.txt` (not in any sibling's declared `file_scope`, but it is the natural roster for any suite fix) | M | M | Re-read the file immediately before editing, match each row by its suite basename rather than by line number, and stage only the three rows this task owns |
| Phase 4's whole-tree regeneration also deploys a concurrent sibling's in-flight source-store edits | M | M | `__WHOLE_TREE__` is declared in Phase 4's `Files to modify`, which is what makes the batch admitter serialize this task against task 589's own whole-tree claim; before regenerating, re-read `git status --short` and report (not dismiss, not fix) any foreign uncommitted modification per the dispatch's concurrency note |
| A failure observed outside this task's own three suites during Phase 4's full gate run is actually a sibling's in-flight edit | M | M | Task 589's `file_scope` names five other suites in this same `tests/` directory and claims `__WHOLE_TREE__`; task 500 claims `update-task-status.sh` and its suite. Check `git log`/`git status` before attributing any such failure, and report rather than fix |
| Line numbers cited below drift before the implementer reaches them | L | M | Every edit is specified by its anchor text (the array literal, the `require_file` precedent block, the `setup_sandbox()` copy sequence), with the line number as a locator only |
| Gate 8's full battery is the dominant cost of a complete gate run | L | H | Phases 1-3 narrow to the selector-reported suites via `run-all.sh --only`; only Phase 4 pays the full gate set |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add `project-number-inuse.sh` to `test-postflight-deploy-gate.sh` [COMPLETED]

**Goal**: Complete this suite's `REQUIRED_LIBS` array so its fixture carries the library
`state-write.sh` sources, clearing all 12 current failures without touching any assertion.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh`
      immediately before editing it (concurrent-sibling discipline). *(completed)*
- [x] Append `project-number-inuse.sh` to the `REQUIRED_LIBS=(...)` array literal (locator: line
      65; anchor:
      `REQUIRED_LIBS=(common.sh phase-heading-patterns.sh status-vocabulary.sh file-scope-overlap.sh task-lookup-lib.sh)`).
      Confirm the same array drives both the pre-flight existence loop (locator: line 66) and the
      fixture copy loop inside `build_fixture_repo()` (locator: line 93), so this single edit
      repairs check and copy together — no second edit site exists in this suite. *(completed)*
- [x] Confirm the copy source for libraries in this suite is `$DEPLOY_SCRIPTS_SRC/lib`
      (`$REPO_ROOT/.claude/scripts/lib`) and that
      `.claude/scripts/lib/project-number-inuse.sh` exists there, so the new copy-loop entry
      resolves. *(completed)*
- [x] Run the suite standalone and record its `Results:` line and every remaining `[FAIL]` line.
      *(completed: 29 passed, 0 failed, no FAIL lines remaining)*
- [x] Record the outcome via `issue-record.sh` (`win` if the tally reaches 29/0; `issue` with
      severity `costly` if any failure survives — that one has a second cause and must not be
      swept into Phase 4). *(completed: win recorded)*
- [x] Commit with an explicit single-file list. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly one line changes in exactly one file, and all 12 of this suite's
current failures are expected to clear (29 passed, 0 failed), because every one of its `[FAIL]`
lines observed in this dispatch is either `expected exit 0, got 2` or a state-transition
assertion downstream of a `state.json` write that never landed. Confirm by running the suite
standalone after the edit. A surviving failure is a distinct defect: record it via
`issue-record.sh` and narrow — do not delete — this suite's `known-failures.txt` row in Phase 4.

**Tier Justification**: `suite_selection_select` run over this phase's only path returns
`test-generate-task-order.sh test-orchestrate-cycle-plan.sh test-orchestrate-cycle-postflight.sh
test-postflight-deploy-gate.sh test-redeploy-checkpoint-promotion.sh test-skill-base-lifecycle.sh`,
so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-skill-base-lifecycle.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` - append
  `project-number-inuse.sh` to the `REQUIRED_LIBS` array (one line; drives both the existence
  check and the fixture copy loop)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` reports
  `0 failed`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-skill-base-lifecycle.sh`
  exits 0.
- `git diff` for this phase shows exactly one changed line in exactly one file.

---

### Phase 2: Add `project-number-inuse.sh` to `test-redeploy-checkpoint-promotion.sh` [COMPLETED]

**Goal**: Complete this suite's `REQUIRED_LIBS` array — the identical pattern and identical
single-array double duty as Phase 1 — clearing all 7 current failures.

**Tasks**:

- [x] Re-read
      `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh`
      immediately before editing it. *(completed)*
- [x] Append `project-number-inuse.sh` to the `REQUIRED_LIBS=(...)` array literal (locator: line
      88; the array literal is byte-identical to Phase 1's). Confirm the existence loop (locator:
      line 89) and the copy loop inside `build_fixture_repo()` (locator: line 121) both iterate
      this same array. *(completed)*
- [x] Run the suite standalone and record its `Results:` line and every remaining `[FAIL]` line.
      *(completed: 17 passed, 0 failed, no FAIL lines remaining)*
- [x] Record the outcome via `issue-record.sh`. *(completed: win recorded)*
- [x] Commit with an explicit single-file list. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly one line changes in exactly one file, and all 7 of this suite's
current failures are expected to clear (17 passed, 0 failed), because its roster reason and its
own `[FAIL]` lines are all state-transition assertions downstream of a failed `state.json` write
(`expected status 'completed', got 'implementing'`; `deploy_pending` not cleared; an absent
`scope='swept'` promoted notice). Confirm by running the suite standalone after the edit; a
surviving failure is recorded and its roster row narrowed rather than retired.

**Tier Justification**: `suite_selection_select` run over this phase's only path returns
`test-redeploy-checkpoint-promotion.sh` alone, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-redeploy-checkpoint-promotion.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` - append
  `project-number-inuse.sh` to the `REQUIRED_LIBS` array (one line)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` reports
  `0 failed`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-redeploy-checkpoint-promotion.sh`
  exits 0.
- `git diff` for this phase shows exactly one changed line in exactly one file.

---

### Phase 3: Add `project-number-inuse.sh` to `test-orchestrate-predispatch-review.sh` [NOT STARTED]

**Goal**: Complete this suite's dependency declaration, which uses no named array — so both its
`require_file` pre-flight list and its hard-coded `setup_sandbox()` copy sequence need the new
library, and the existing per-addition explanatory-comment convention is kept.

**Tasks**:

- [ ] Re-read
      `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
      immediately before editing it.
- [ ] Add `require_file "$CORE_DIR/lib/project-number-inuse.sh"` to the pre-flight list (locator:
      after the `require_file "$CORE_DIR/task-lock.sh"` line at 49). Precede it with a short
      explanatory comment in the same shape as the existing `file-scope-overlap.sh` and
      `task-lock.sh` precedents at lines 43-49 — those comments record *why* each addition became
      necessary, and this suite's convention is to keep that record. The comment must cite the
      durable anchor (`state-write.sh`'s unconditional `source` of this library), never a task
      number: this file lives under `agent-system/extensions/**`, where task-number references are
      prohibited.
- [ ] Add `cp "$CORE_DIR/lib/project-number-inuse.sh" "$WORKDIR/.claude/scripts/lib/project-number-inuse.sh"`
      inside `setup_sandbox()`, alongside the existing `common.sh` / `task-lookup-lib.sh` /
      `file-scope-overlap.sh` copies (locator: lines 61-67). This suite's copy source is
      `$CORE_DIR/lib` (the source store), not the deployed tree — confirm
      `agent-system/extensions/core/scripts/lib/project-number-inuse.sh` exists there.
- [ ] Run the suite standalone and confirm scenario 10's `--repair` path no longer exits 2 and its
      `file_scope` assertion now evaluates (the two current failures are exactly these).
- [ ] Record the outcome via `issue-record.sh`.
- [ ] Commit with an explicit single-file list.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Two lines plus one comment change in exactly one file (this suite needs two
edit sites, unlike Phases 1 and 2, because it has no named array doing double duty), and both of
its current failures are expected to clear (37 passed, 0 failed). The hypothesis is well
supported: this suite's first `[FAIL]` line already names the missing library verbatim, and its
second is the assertion that line prevents from running. Confirm by running the suite standalone
after the edit.

**Tier Justification**: `suite_selection_select` run over this phase's only path returns
`test-orchestrate-predispatch-review.sh` alone, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-predispatch-review.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` - add the
  `require_file` pre-flight check (with its explanatory comment) and the matching
  `setup_sandbox()` copy line

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
  reports `0 failed`.
- The suite's output contains no `No such file or directory` text for
  `lib/project-number-inuse.sh`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-predispatch-review.sh`
  exits 0.
- `git diff` for this phase shows changes confined to the pre-flight list and `setup_sandbox()`
  in exactly one file.

---

### Phase 4: Retire the Stale Roster Rows, Redeploy, and Run the Complete Gate Set [NOT STARTED]

**Goal**: Bring `known-failures.txt` back into agreement with observed reality, regenerate the
deployed tree so the task is completable through the postflight completion-deploy gate, and
confirm the whole repository is green with no new failure anywhere.

**Tasks**:

- [ ] Re-read `git status --short`; report (do not dismiss, do not fix) any foreign uncommitted
      modification or foreign commit before touching the roster or regenerating the tree, per the
      dispatch's concurrency note. Task 589 holds a concurrent `__WHOLE_TREE__` claim and five
      other suites in this same directory; task 500 holds `update-task-status.sh` and its suite.
- [ ] Re-read `agent-system/extensions/core/scripts/tests/known-failures.txt`. It exists and
      currently holds one `real-defect|...|needs-owner` row for each of this task's three suites
      (locators: lines 51, 52, 53); match each row by its suite basename, not by line number, in
      case a concurrent writer has shifted them.
- [ ] For each of the three suites observed at `0 failed` in Phases 1-3, delete its row. For any
      suite with a surviving residual failure, instead **rewrite** its `reason` field to describe
      only the residual and leave the row in place — a row is retired only on observed green, never
      on an expected one.
- [ ] Regenerate the deployed tree from the source store
      (`bash agent-system/extensions/core/scripts/deploy-headless.sh`, or the deployed entry point,
      whichever resolves). This is a whole-tree regeneration, which is why `__WHOLE_TREE__` is
      declared below.
- [ ] Confirm the deployed copies carry the edits: `grep -c project-number-inuse` on each of the
      three suites' deployed counterparts under `.claude/scripts/tests/` returns a non-zero count,
      and the deployed `known-failures.txt` no longer names them.
- [ ] Run gate 8 as the registry invokes it:
      `bash .claude/scripts/verify-deploy.sh --only-gate 8 <repo_root>`, and confirm none of the
      three suites appears among its `[FAIL]` lines and that the run reports no NEW failure.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh <repo_root>`.
- [ ] Record in the task's summary artifact: the before/after tally for each of the three suites,
      the roster rows retired, and the deferred `lint-test-fixture-dependency-drift.sh` follow-up
      candidate together with the evidence that sizes it (the corpus-wide re-derivation found zero
      drift beyond these three suites, so the detector is a guard against recurrence, not a fix for
      a live defect).
- [ ] Record the phase outcome via `issue-record.sh`.
- [ ] Commit with an explicit file list.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: Exactly three roster rows are expected to be retired, one per suite fixed
in Phases 1-3, and no other row in `known-failures.txt` is expected to change. Confirm by
comparing the observed `0 failed` tally recorded in each of Phases 1-3 against the row being
deleted; a suite not observed green keeps a narrowed row instead, which reduces the retired count
below three and is a legitimate outcome rather than a failure of this phase.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/known-failures.txt` - delete the three now-stale
  `real-defect|...|needs-owner` rows (one per suite fixed in Phases 1-3), or narrow any row whose
  suite retains a residual failure
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:

- The complete gate set for the repository runs green:
  `bash .claude/scripts/verify-deploy.sh <repo_root>` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`).
- `bash .claude/scripts/verify-deploy.sh --only-gate 8 <repo_root>` exits 0 and names none of
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`,
  `test-orchestrate-predispatch-review.sh` among its `[FAIL]` lines.
- `grep -E 'test-(postflight-deploy-gate|redeploy-checkpoint-promotion|orchestrate-predispatch-review)\.sh' agent-system/extensions/core/scripts/tests/known-failures.txt`
  returns no match for any suite observed green.
- Each of the three deployed suite copies under `.claude/scripts/tests/` mentions
  `project-number-inuse.sh`.
- `test-orchestrate-unwind-dispatch.sh` is unchanged by this task: `git diff` across all four
  phases shows no hunk in that file.

---

## Testing & Validation

- [ ] `test-postflight-deploy-gate.sh`: 29 passed, 0 failed (from 17/12).
- [ ] `test-redeploy-checkpoint-promotion.sh`: 17 passed, 0 failed (from 10/7).
- [ ] `test-orchestrate-predispatch-review.sh`: 37 passed, 0 failed (from 35/2).
- [ ] No suite output anywhere contains `lib/project-number-inuse.sh: No such file or directory`.
- [ ] `bash .claude/scripts/verify-deploy.sh <repo_root>` runs green, with gate 8 reporting no NEW
      failure.
- [ ] `known-failures.txt` names no suite this task observed at `0 failed`.
- [ ] `test-orchestrate-unwind-dispatch.sh` remains at 21 passed, 0 failed and is untouched.
- [ ] No file under `.claude/**` was hand-edited; every change lands in
      `agent-system/extensions/**` and reaches the deployed tree only via regeneration.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` (one-line array fix)
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` (one-line
  array fix)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
  (`require_file` check + `setup_sandbox()` copy line)
- `agent-system/extensions/core/scripts/tests/known-failures.txt` (three rows retired)
- A regenerated `.claude/` deploy tree (whole-tree claim, not a tracked deliverable)
- `specs/569_repair_stale_fixture_lib_dependency_lists/summaries/01_*-summary.md` (before/after
  tallies, rows retired, and the drift-detector follow-up candidate with its sizing evidence)
- Issue-log entries in `specs/569_repair_stale_fixture_lib_dependency_lists/issues.jsonl`

## Rollback/Contingency

Every edit is additive and confined to four files, each committed separately, so reverting is a
per-file `git revert` of that phase's commit — no schema, state, or interface change is involved
and nothing outside the test harness observes these files.

- **A suite retains failures after its library addition**: do not revert the addition (it is
  independently correct — the missing library is proven missing). Keep the suite's
  `known-failures.txt` row, rewritten to describe only the residual, and record the residual via
  `issue-record.sh` as a distinct defect for a follow-up task.
- **The full gate set fails in a suite outside this task's three**: check `git log` and
  `git status` first. Task 589 holds a concurrent whole-tree claim and five other suites in this
  same directory; task 500 holds `update-task-status.sh`. Report the failure rather than fixing a
  file outside this task's scope.
- **The regeneration in Phase 4 picks up a foreign in-flight source-store edit**: stop before
  regenerating if `git status --short` shows foreign uncommitted modifications, and report. The
  `__WHOLE_TREE__` declaration exists to have the batch admitter prevent this, but the pre-flight
  re-read is the backstop.
- **Full abandonment**: reverting all four commits restores the three suites to their current
  tallies (17/12, 10/7, 35/2) and the roster to its current three rows. No cleanup beyond the
  reverts and one further regeneration is required.
