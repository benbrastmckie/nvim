# Implementation Plan: Task #352

- **Task**: 352 - validate-artifact.sh fixes counters do not accumulate
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (the group's dependency edge is a territory serialization on `known-failures.txt`, not a work dependency)
- **Research Inputs**: specs/352_validate_artifact_fixes_counters_do_not_accumulate/reports/01_known-failures-row-misdiagnosis.md
- **Artifacts**: plans/01_repair-reporting-fixture-closeout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research overturned the dispatch's literal framing: `SKILL_VALIDATE_FIXES` /
`SKILL_VALIDATE_FIXED_FILES` already accumulate across a multi-file sweep and already reset
unconditionally at function entry (both landed 2026-09-03), and Cases 3/4/6 of
`test-gate-out-repair-reporting.sh` pin those properties green today. The one live failure is
Case 1, whose fixture omits the plan `**Status**` field and therefore trips a *later*, unrelated
plan-level Status-line grammar check (2026-09-29) against the generic `--fix` placeholder — a
by-design remaining error the assertion predates. This plan therefore (a) re-confirms the
boundary from live evidence rather than from the stale registry row, (b) repairs Case 1's fixture
with a one-field swap and no production-code change, (c) adds the two pinning fixtures the
acceptance criteria demand — including a genuinely cross-subdirectory accumulation case and a
repairing-then-repairing cross-call case that today's Case 6 does not cover — (d) deletes this
task's `known-failures.txt` row, and (e) lints and redeploys.

### Research Integration

Key findings carried into the phases below:

- **No production defect.** `skill_validate_task_artifacts` in `skill-base.sh` resets all four
  `SKILL_VALIDATE_*` globals at entry (~lines 777-780) and accumulates per-file (~lines 843-845).
  `command-gate-out.sh`'s reporting block is likewise correct. Phase 1 re-confirms this from live
  code and live suite output rather than restating the report.
- **Real failure mechanism.** `validate-artifact.sh --fix` inserts a generic
  `- **Field**: TBD` placeholder for any absent metadata field; the plan-type branch then runs
  `plan_status_classify` against the resulting `- **Status**: TBD`, which has no `[STATUS]`
  bracket pair, yielding one intentional remaining error. The script's own header (lines 14-28)
  documents this non-participation as deliberate.
- **Confirmed minimal fix.** Swapping the omitted field so `**Status**: [NOT STARTED]` is present
  and well-formed while `**Effort**` is the absent one reproduces Case 1's originally-intended
  `fixes=1 errors=0` shape. Verified by direct repro in the research phase.
- **Registry row is stale, not merely unowned.** It was seeded 2026-09-30, after both the real
  fix and the commit that introduced the current failure, and its symptom text (`fixes=0
  errors=1`, "cases 4 and 6 fail") does not match live output (`fixes=1 errors=1`, Case 1 fails).
  The ON FIX branch — outright deletion — is the correct disposition.
- **Sibling-global sweep came back clean.** `SKILL_HOOK_LAST_*` are also reset at entry; no other
  accumulator in `skill-base.sh` lacks a reset. Phase 1 records this; no edit follows from it.
- **Structural "return values instead of globals" change declined.** Bash function returns are
  exit codes only, four pieces of structured state cannot ride them, and every sibling
  caller-visible channel in the same file is already a global-plus-entry-reset. Recorded as a
  decision below, per the dispatch's "state why if you do not take it".

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- `test-gate-out-repair-reporting.sh` finishes with zero failing assertions, under both a direct
  run and `tests/run-all.sh`.
- A fixture pins multi-file accumulation: N repairable files in one invocation report exactly N,
  and across more than one artifact subdirectory, matching what Case 3's own comment already
  claims.
- A separate fixture pins cross-call reset in the shape the acceptance names: a *second repairing*
  invocation in the same shell reports only its own repairs, not the sum.
- Both pinning fixtures demonstrably fail against a partial fix that addresses only one of the two
  directions.
- This task's `known-failures.txt` row is deleted (ON FIX branch) and no row it does not own is
  touched.
- Source store edited, repo redeployed, shellcheck clean, no task-number references land under
  `agent-system/**`.

**Non-Goals**:

- Changing `validate-artifact.sh`'s `--fix` placeholder mechanism or its Status-line grammar
  check. Both are working as designed; `write_repair_plus_errors_plan`/Case 4 already exists to
  pin their intended coexistence.
- Changing `skill-base.sh`'s accumulation/reset logic or `command-gate-out.sh`'s reporting call
  site.
- Converting the globals to return values (declined, with reasoning recorded above).
- Touching, reordering, or re-categorising any other `known-failures.txt` row.
- Re-litigating the group's dependency edge or filing a task to remove it.

## Decisions

1. **Deletion, not formal acceptance, for the registry row.** The ON FORMAL ACCEPTANCE branch
   applies only when the ruling is that the behaviour is correct and the assertion was wrong.
   Here the assertion *was* wrong in its own narrow way (Case 1's error expectation), but the fix
   is a real fixture repair that makes the suite green, not a tolerated gap — so the row must go,
   per the registry header's own rule that a fixed suite must not keep a known-failing exception.
2. **The "19/19" acceptance figure is a floor, read as "zero failing assertions".** The same
   acceptance block mandates two additional pinning fixtures, which necessarily raise the
   denominator. Implementation records the new pass/pass total explicitly so the change in
   denominator is visible rather than looking like drift.
3. **Globals retained.** See Research Integration above for the three grounds.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `write_repairable_plan` is shared by Cases 1/3/6/7; editing it breaks a sibling case | M | M | Phase 2 runs the full suite immediately after the edit rather than assuming the report's "unaffected" analysis; sibling breakage is caught in the same phase that causes it |
| The new accumulation case needs a repairable *report* fixture, a helper that does not exist yet | L | H | Phase 3 adds `write_repairable_report` modelled on `write_repairable_plan`, omitting `Effort` (reports have no secondary grammar check, so a single-field repair stays clean) |
| The partial-fix resistance probe temporarily reverts a line in `skill-base.sh` | H | L | Probe is read-only in intent: revert, observe, restore in the same step, then confirm `git diff` on `skill-base.sh` is empty before the phase closes. Never committed in the reverted state |
| Deleting the wrong registry line, or disturbing a concurrent task's row | H | L | Phase 4 deletes by exact full-line match on the owned basename and then asserts `git diff` shows exactly one deletion and no other changed line in that file |
| Redeploy overwrites or desyncs the edited test | M | L | Phase 6 redeploys and then re-runs the suite from the deployed tree, diffing deployed vs. source copies of both edited files |
| A task-number reference slips into an `agent-system/**` file | M | L | Phase 6 runs the repo-wide task-reference lint; the write-time hook also gates it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-confirm the live baseline and fix the boundary [COMPLETED]

**Goal**: Replace the stale registry row's claim with live evidence, and settle on the record
whether the defect is confined to `validate-artifact.sh` or extends to `skill-base.sh` /
`command-gate-out.sh`. No file edits in this phase.

**Tasks**:

- [x] Run `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`,
      capture full output to the scratchpad, and record the pass/fail tally. *(completed: 18
      passed, 1 failed)*
- [x] Record which assertion's `[FAIL]` line fired, verbatim, and the `fixes=N errors=N` shape it
      reports. Compare against the registry row's claimed shape and note the mismatch.
      *(completed: Case 1's "report line did not name a nonzero repaired-field count"; live
      shape fixes=1 errors=1, vs. registry row's claimed fixes=0 errors=1 -- mismatch confirmed)*
- [x] Confirm Cases 3, 4 and 6 are in the PASS list. *(completed)*
- [x] Read the entry-reset block and the per-file accumulation arithmetic in
      `skill_validate_task_artifacts` (`agent-system/extensions/core/scripts/skill-base.sh`) and
      record the line numbers that carry each property. *(completed: reset lines 777-780,
      accumulation lines 843-850)*
- [x] Read `command-gate-out.sh`'s repair-reporting block and record that it consumes the globals
      without mutating them. *(completed: lines 269-310, read-only consumer)*
- [x] Sweep `skill-base.sh` for every `+=`-style or `$((VAR + ...))` accumulator and every
      caller-visible uppercase global, and record for each whether it is reset at entry. Report
      the finding even where nothing changes. *(completed: SKILL_HOOK_LAST_* also reset at entry,
      lines 206-209; no sibling gap found)*
- [x] Write the boundary determination down (one of: confined to `validate-artifact.sh`; extends
      to `skill-base.sh`; extends to `command-gate-out.sh`) with the line-level evidence that
      supports it. *(completed: confined to the test suite's own stale fixture; no production
      defect in validate-artifact.sh, skill-base.sh, or command-gate-out.sh)*

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Verification**:

- The captured suite output names the failing assertion and its numeric shape.
- The boundary determination cites specific files and line ranges, not the research report's
  prose.
- The sibling-global sweep enumerates what it checked, so a reader can tell the sweep happened.
- `git status --short` shows no change to any tracked file from this phase.

---

### Phase 2: Repair Case 1's stale fixture [COMPLETED]

**Goal**: Restore Case 1's originally-intended "clean single-field repair, zero remaining errors"
shape with a fixture-only edit, and leave a comment so the mis-triage cannot recur.

**Tasks**:

- [x] In `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`'s
      `write_repairable_plan` helper: add a well-formed `- **Status**: [NOT STARTED]` metadata
      line and remove the `- **Effort**: 1h` line, so `**Effort**` becomes the single absent
      field. *(completed)*
- [x] Update that helper's own header comment, which currently says "missing `**Status**`
      metadata field", to name `**Effort**` and to state why a field with no secondary grammar
      check is required here. *(completed)*
- [x] Add a short cross-reference comment at `write_repair_plus_errors_plan` / Case 4 recording
      that a missing-`**Status**` repair necessarily leaves one remaining error (the Status-line
      bracket grammar check does not participate in `--fix`), so a future maintainer editing
      either fixture does not reintroduce this mis-triage. *(completed)*
- [x] Re-run the suite and confirm Case 1's three assertions pass. *(completed: 19 passed, 0
      failed)*
- [x] Confirm Cases 3, 6 and 7 — which share this helper — still pass, from the run output rather
      than by assumption. *(completed)*
- [x] Confirm the contamination-guard assertion still passes. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the edit is confined to one fixture helper plus two comments inside
`test-gate-out-repair-reporting.sh`, and no production script changes. Confirm by `git diff
--stat`: exactly one file changed, and that file is the test suite. If any production file appears
in the diff, stop and re-diagnose rather than widening the edit.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` - swap
  `write_repairable_plan`'s omitted field from `**Status**` to `**Effort**`; refresh that helper's
  header comment; add the Case 4 cross-reference comment.

**Verification**:

- The suite reports zero failing assertions (expected 19 passed, 0 failed at this point).
- `git diff --stat` names only the test suite file.
- `git diff` shows no change to `validate-artifact.sh`, `skill-base.sh`, or
  `command-gate-out.sh`.

---

### Phase 3: Add the two acceptance-mandated pinning fixtures [COMPLETED]

**Goal**: Pin multi-file accumulation and cross-call reset in the exact shapes the acceptance
criteria name, and prove both pins would fail against a one-directional partial fix.

**Tasks**:

- [x] Add a `write_repairable_report` helper modelled on `write_repairable_plan`: a report-type
      fixture carrying every required report metadata field except `**Effort**`, plus the required
      report sections, so `--fix` performs exactly one clean repair with zero remaining errors.
      *(completed)*
- [x] Verify that helper in isolation first: run `validate-artifact.sh <fixture> report --fix`
      against a scratch copy and confirm the `1 field(s) auto-repaired, 0 error(s)` summary line
      before wiring it into a case. *(completed: confirmed "1 field(s) auto-repaired, 0 error(s),
      0 warning(s) remaining" on an isolated scratch fixture)*
- [x] Strengthen Case 3 so it is genuinely cross-subdirectory: two repairable plans plus one
      repairable report, asserting `SKILL_VALIDATE_FIXES` equals exactly 3 and that
      `SKILL_VALIDATE_FIXED_FILES` names all three paths. Correct Case 3's stale "two
      subdirectories" comment, which currently over-claims relative to its two-plans body.
      *(completed)*
- [x] Add a new case pinning the cross-call shape today's Case 6 does not cover: a first
      invocation over a multi-file repairable fixture, then a *second repairing* invocation over a
      separate single-file fixture in the same shell. Assert the second call reports exactly its
      own repair count (1), not the sum, and that `SKILL_VALIDATE_FIXED_FILES` names only the
      second fixture's path. *(completed: added as Case 6b, immediately after Case 6)*
- [x] Keep Case 6 as-is: repairing-then-clean is a distinct property and stays pinned.
      *(completed: Case 6 unmodified)*
- [x] Partial-fix resistance probe, direction one: temporarily remove the per-file accumulation
      arithmetic in `skill_validate_task_artifacts`, run the suite, and confirm the strengthened
      Case 3 fails. Restore the line immediately. *(completed: strengthened Case 3 failed with
      "expected SKILL_VALIDATE_FIXES=3, got 1" when accumulation was replaced with plain
      overwrite; restored and reconfirmed empty diff)*
- [x] Partial-fix resistance probe, direction two: temporarily remove the entry-reset block, run
      the suite, and confirm the new cross-call case fails. Restore the block immediately.
      *(completed, with one deviation recorded below: a literal deletion of the reset lines under
      this suite's own `set -u` crashes the whole script on the first direct-call case (Case 3)
      with "unbound variable" before reaching Case 6b, rather than producing a targeted
      assertion failure. The probe was instead implemented as an "only-if-unset" init
      (`: "${VAR:=0}"`) -- the literal shape of fault #2 from the dispatch ("a second call in
      the same shell inherits the first call's state") -- which reaches Case 6b and fails it
      exactly as expected: "expected first_call_fixes=2 and second_call_fixes=1, got first=7
      second=8", plus the fixed-files leak assertion. Restored and reconfirmed empty diff)*
- [x] Confirm `git diff` on `skill-base.sh` is empty after both probes, before the phase closes.
      *(completed: confirmed empty after each probe and after final restoration)*
- [x] Re-run the full suite and record the new pass total. *(completed: 21 passed, 0 failed, up
      from 19)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: the assertion count rises above 19 (one new helper, one strengthened case,
one new case). The acceptance figure is a floor meaning zero failures, so record the exact new
total rather than forcing the count back to 19. Confirm the new total from the suite's own
`Results: N passed, 0 failed` line.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` - add
  `write_repairable_report`; strengthen Case 3 to three files across two subdirectories and fix
  its comment; add the repairing-then-repairing cross-call case.

**Verification**:

- Suite reports `0 failed` with a pass total greater than 19.
- Probe direction one: strengthened Case 3 fails with accumulation removed; passes once restored.
- Probe direction two: new cross-call case fails with the entry reset removed; passes once
  restored.
- `git diff -- agent-system/extensions/core/scripts/skill-base.sh` is empty.
- Contamination guard still passes; no case writes into the real `specs/` tree.

---

### Phase 4: Delete this task's known-failures.txt row [NOT STARTED]

**Goal**: Close out the owned registry row on the ON FIX branch, with the suite proven green
under the harness that consumes the registry.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and confirm
      `test-gate-out-repair-reporting.sh` is in the passing roster.
- [ ] Delete the single `test-gate-out-repair-reporting.sh|real-defect|...|needs-owner` line from
      `agent-system/extensions/core/scripts/tests/known-failures.txt`, matching the full line
      exactly. Delete the row outright; do not rewrite its `owner` field.
- [ ] Confirm no remaining reference to `test-gate-out-repair-reporting.sh` exists anywhere in
      that file, including its header narrative.
- [ ] Confirm `git diff` on that file shows exactly one deleted line and no other changed line,
      so no concurrently-owned row was disturbed.
- [ ] Confirm the suite's status is not restated in prose anywhere else — in particular that
      `context/standards/shell-script-testing.md` still points at the registry rather than
      carrying its own list.
- [ ] Re-run `run-all.sh` after the deletion and confirm the suite is now classified as a plain
      pass with no EXPECTED annotation.

**Timing**: 0.3 hours

**Depends on**: 3

**Verification Tier**: interface

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/known-failures.txt` - delete the owned
  `test-gate-out-repair-reporting.sh` row.

**Verification**:

- `grep -c 'test-gate-out-repair-reporting' known-failures.txt` returns 0.
- `git diff --numstat` on that file shows one deletion and zero insertions.
- `run-all.sh` shows the suite passing, with no EXPECTED/NEW annotation attached to it.
- No row owned by another task differs in the diff.

---

### Phase 5: Record the registry-triage discipline [NOT STARTED]

**Goal**: Capture the generalisable lesson this task is an instance of — that a registry row's
reason text must be re-validated against live output before it is accepted as the scope of work —
as process guidance, without duplicating the known-failing list.

**Tasks**:

- [ ] Add a short subsection to
      `agent-system/extensions/core/context/standards/shell-script-testing.md` stating that when
      claiming a `known-failures.txt` row, the suite must be re-run and the live `[FAIL]` text
      matched against the row's claimed symptom shape before the row's description is treated as
      the task's scope.
- [ ] Include the mechanism that makes this necessary — a row can be seeded after the defect it
      describes was already fixed, while the suite stays red for a later, unrelated reason — using
      a durable anchor (the suite basename and the dates), never a task number.
- [ ] Confirm the addition contains no list of which suites are currently known-failing: the
      registry remains the single source of truth for that, and a prose copy is the drift
      mechanism this file already points away from.
- [ ] Confirm no task-number reference was introduced.

**Timing**: 0.3 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/standards/shell-script-testing.md` - add the
  row-re-validation triage subsection.

**Verification**:

- The new subsection names the re-run-and-match step as a required triage action.
- The subsection contains no suite-status list and no task number.
- The file's existing pointer to `known-failures.txt` as the single source of truth is intact.

---

### Phase 6: Lint, redeploy and verify from the deployed tree [NOT STARTED]

**Goal**: Close the source-store edit cycle: lint clean, no prohibited references, redeployed, and
the suite proven green from the deployed copy as well as the source copy.

**Tasks**:

- [ ] Run shellcheck against the edited test suite per
      `context/standards/shell-strict-mode.md` and resolve any finding the edits introduced.
      Pre-existing findings unrelated to these edits are reported, not silently fixed.
- [ ] Run the repo-wide task-reference lint (`scripts/check-task-references.sh`) and confirm no
      new occurrence under `agent-system/**`.
- [ ] Redeploy with `bash .claude/scripts/deploy-headless.sh` (default non-destructive resync).
- [ ] Diff the deployed copies of `tests/test-gate-out-repair-reporting.sh` and
      `tests/known-failures.txt` against their source-store originals; both must be identical.
- [ ] Run the suite from the deployed tree and confirm zero failures there too.
- [ ] Confirm the deployed `known-failures.txt` no longer carries the deleted row.
- [ ] Final `git status --short` review: only the intended files changed, nothing staged by
      accident.

**Timing**: 0.5 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:

- None directly; this phase regenerates `.claude/**` as a deploy artifact and must not
  hand-author anything there.

**Verification**:

- Shellcheck reports no new finding attributable to this task's edits.
- Task-reference lint passes for `agent-system/**`.
- Deployed and source copies of both edited files are byte-identical.
- Suite run from the deployed tree reports `0 failed`.
- `git status --short` shows only the test suite, the registry, and the standards doc as modified.

---

## Testing & Validation

- [ ] `test-gate-out-repair-reporting.sh` reports `0 failed`, with the new pass total recorded.
- [ ] Multi-file accumulation pinned: three repairable files across two artifact subdirectories in
      one invocation report exactly 3, with all three paths named.
- [ ] Cross-call reset pinned in the repairing-then-repairing shape: the second invocation reports
      only its own repairs and names only its own path.
- [ ] Both pins proven to fail against a one-directional partial fix, and `skill-base.sh` proven
      unmodified afterwards.
- [ ] `run-all.sh` shows the suite passing with no known-failure annotation.
- [ ] `known-failures.txt` carries no row for this suite; no other row changed.
- [ ] Shellcheck clean; no task-number reference under `agent-system/**`.
- [ ] Deploy complete and deployed-tree suite run green.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`
- Modified: `agent-system/extensions/core/scripts/tests/known-failures.txt` (one row deleted)
- Modified: `agent-system/extensions/core/context/standards/shell-script-testing.md`
- Regenerated: the repo's `.claude/**` deploy tree
- Summary artifact recording the boundary determination (confined to `validate-artifact.sh`'s
  by-design behaviour as surfaced through a stale fixture, with `skill-base.sh` and
  `command-gate-out.sh` exonerated by line-level evidence) and the sibling-global sweep result

## Rollback/Contingency

Every edit is confined to three source-store text files, so reverting is a per-file `git
checkout` of the committed version followed by a redeploy. Specific contingencies:

- **Phase 2 breaks a sibling case**: the `write_repairable_plan` edit is one added line and one
  removed line; revert the helper and re-diagnose which sibling assertion depends on the absent
  `**Status**` field before retrying.
- **Phase 3's probe is interrupted mid-revert**: `skill-base.sh` is a committed file with no
  intended change in this task, so `git checkout -- agent-system/extensions/core/scripts/skill-base.sh`
  restores it exactly. Phase 3 cannot close with a non-empty diff on that file.
- **The suite cannot be made green**: do not delete the registry row. Leave it in place, record
  the live failure shape, and return `partial` — a deleted row with a red suite is strictly worse
  than a stale row, because it removes the annotation that keeps the failure visible.
- **Redeploy fails**: the source store is authoritative and unaffected; re-run
  `deploy-headless.sh` and, if it still fails, report the deploy failure rather than
  hand-authoring under `.claude/**`.
