# Implementation Plan: Task #645

- **Task**: 645 - Repair seven failing Gate 8 suites (remaining scope: the `.mcp.json` merge defect)
- **Status**: [NOT STARTED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/645_repair_seven_failing_gate8_suites/reports/01_mcp-merge-defect-already-fixed.md
- **Artifacts**: plans/01_mcp-merge-closure-confirmation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The named defect is already closed. `merge.lua`'s `remove_tracked` treated a tracked
`"new_object"` entry the same as `"new_array"`/`"new_value"` — unconditional wholesale
`t[key] = nil` — which destroyed a hand-written `.mcp.json` sibling key living inside the same
object the extension's first load created. The fix gave `"new_object"` its own branch that
recurses into `info.children` (mirroring the existing `"merged"` branch) and prunes the object
only once it is empty. That fix is committed and present in the working tree, and
`test-mcp-merge-target.sh` now passes deterministically.

This plan is therefore **verification-and-close only**: no code edit is scoped. Phase 1
re-confirms closure and captures the verbatim evidence the acceptance criteria demand. Phase 2
redeploys and hands the complete gate set to the orchestration close. The merge code was the
wrong side, not the test's expectation — the plan preserves the additive-merge / tracked-removal
contract exactly as the task's binding constraints require, and no assertion was loosened and no
`known-failures.txt` row was added.

### Premise Re-Validation (Carried-Figure Discipline)

Every extracted premise line was checked against the prior report and against live state in this
dispatch. Results, stated explicitly even where unchanged:

| Premise as written | Live result |
|---|---|
| "SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`" | **Falsified as applied.** The defect and its fix live in `lua/neotex/plugins/ai/shared/extensions/merge.lua` — primary Neovim plugin code, edited directly, mirrored nowhere under `agent-system/` — plus a contract doc under `agent-system/extensions/nvim/`. Only the unchanged test file lives under `agent-system/extensions/core/`. No `core` source-store edit is scoped by this plan. |
| ORIGIN: "seven confirmed Gate 8 findings ... six since closed, one substantive defect remains" | **The remaining-one clause is now falsified.** The seventh (this `.mcp.json` defect) is also closed. The six-closed provenance is unverified here by design (explicitly provenance-only, not to be re-diagnosed). |
| GATE STATE: "FAIL -- 1 of 42 check(s) failed, down from 3" | **Stale and not re-measurable in this dispatch.** Its premise (a live mcp-merge defect) is falsified. An unfiltered `verify-deploy.sh` is refused right now: a non-stale marker `specs/.orchestration/batch-gate-pending-sess_1795494587_0fa3fc.json` exists, so the complete set is owed to this invocation's own batch-gate stage. Forcing `--override-batch-gate-deferral` from a plan dispatch is not sanctioned. |
| "(4) test-deploy-baseline-lib.sh -- FIXED, now 30/0 (was 27/3) ... count updated to 6" | Not re-measured. Provenance-only by the description's own instruction; nothing in this plan's scope depends on it. |
| "(6) test-gate-cache-equivalence.sh -- NOT A NEW DEFECT ... rostered as load-sensitive \| needs-owner" | **Confirmed unchanged.** The row is present in `known-failures.txt` as row 2, classed `load-sensitive`, carrying the 543-second whole-suite hint and the gate10-timeout account. |
| AC 1: "verify-deploy.sh completes its full gate set with exit 0" | Cannot be discharged inside any single dispatch of this batch (see GATE STATE above). Phase 2 defers it to the orchestration close, per plan-format.md's Batch-aware deferral. |
| AC 4: "known-failures.txt entry count is unchanged or lower, never higher" | **Confirmed at 4 data rows** (`test-run-all-parallel.sh`, `test-gate-cache-equivalence.sh`, `test-verify-deploy-context-budget.sh`, `test-double-loading-check.sh`). Phase 1 re-asserts this as its own gate. |

Additional live confirmations made while authoring this plan:
- `bash .claude/scripts/tests/test-mcp-merge-target.sh` -> `Results: 7 passed, 0 failed`, exit 0.
  Assertions C and E both `[PASS]`.
- `git log --oneline -1 3c7f91a92` resolves; `merge.lua` carries the `"new_object" and
  info.children` branch at line 587 with the defensive no-children fallback at line 601.
- `git status --short` is empty for `merge.lua`, `init.lua`, the contract doc, the test file, and
  both copies of `known-failures.txt` — the fix is committed, not an uncommitted working-tree
  artifact that a sibling or a regenerate could erase.
- `lua/neotex/plugins/ai/claude/extensions/merge.lua` is a 62-line shim that `require`s the shared
  module; there is no second implementation of `remove_tracked` needing the same fix.

### Research Integration

The report's three load-bearing conclusions are adopted wholesale and re-confirmed above:
(1) Assertions C and E are **one** root cause, not two — both exercise the identical tracked
record (`mcpServers` -> `mcpfixture-server`) through `remove_tracked`'s `"new_object"` arm, C
observing it post-regenerate and E one step further post-unload; (2) the merge code was the wrong
side; (3) the remaining work is confirmatory. The report's own recommendation that no edit be
scoped under `agent-system/extensions/core/**` is followed exactly.

### Prior Plan Reference

No prior plan. `plans/` was empty at dispatch time.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; no roadmap consultation was performed and
no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Close acceptance criterion 2: `test-mcp-merge-target.sh` passes on a direct run, counts quoted verbatim.
- Close acceptance criterion 3: the summary names the merge code (not the test expectation) as the
  wrong side, says why, and states that C and E are one fault.
- Close acceptance criterion 4: `known-failures.txt` data-row count is 4 or lower, never higher.
- Close acceptance criterion 5: `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- Hand acceptance criterion 1 to the orchestration close explicitly, recorded as a deferral rather
  than as a satisfied criterion.

**Non-Goals**:
- Any edit to `merge.lua`, `init.lua`, `merge-tracking-contract.md`, or
  `test-mcp-merge-target.sh`. The fix is already in place; re-deriving or re-landing it is waste.
- Any edit under `agent-system/extensions/core/**`. The description's edit-target line does not
  apply to this defect (see Premise Re-Validation).
- Re-diagnosing the six already-closed findings, or `test-gate-cache-equivalence.sh`.
- Rewriting the task's own stale description in `specs/state.json`. The corrected framing is
  carried by this plan and the summary — the durable artifacts a future reader reaches — not by a
  mid-cycle edit to a file two concurrent siblings are also writing.
- The separately-tracked adjacent work the description fences off: the `known-failures` roster for
  `test-deploy-propagation.sh` and its sibling, and the orchestrator's
  stall-on-backgrounded-verify-deploy behavior.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The orchestration-close gate surfaces a NEW Gate 8 red unrelated to this defect | M | M | Out of scope by the research's own recommendation. Record it via `issue-record.sh`, name it in the summary as newly-discovered-and-separate, and do not expand this task to chase it. Phase 1's evidence stands regardless. |
| Gate 8 / `specs/.gate-lock` contention from siblings 639 and 697 stalls or flakes a check | M | M | Phase 1 is deliberately sequenced first and costs one suite, so criteria 2/3/4 close before any contended step. If Phase 2 cannot complete, close Phase 1 and mark Phase 2 [PARTIAL] rather than forcing the deferral override. |
| `deploy-headless.sh` returns `landed_verify_red` (exit 3) | M | L | Its inline pass is `verify-deploy.sh --skip-slow --override-batch-gate-deferral`, which it supplies itself, so a deferral can no longer be misread as drift. A genuine red is reported with its findings verbatim and the task marked [PARTIAL]; do not re-run the full set to "clear" it. |
| Temptation to force `--override-batch-gate-deferral` to satisfy AC 1 inside the dispatch | H | L | Explicitly prohibited by this plan. That flag is reserved for the batch-gate stage's own discharger. The in-dispatch obligation is the scoped check plus a recorded deferral. |
| A sibling's in-flight edit makes an unrelated check fail | M | L | Per the Territory block: treat a failure outside this task's own (empty) real-file scope as possibly a sibling's in-flight edit; check `git log` before attributing it, and report rather than dismiss. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Confirm Closure and Capture Verbatim Evidence [NOT STARTED]

**Goal**: Establish, from live runs rather than from the report, that the C/E defect is closed and
that the known-failures roster did not grow — producing the exact strings acceptance criteria 2,
3, and 4 require the summary to quote.

**Tasks**:
- [ ] Run `bash .claude/scripts/tests/test-mcp-merge-target.sh` and capture its final
      `Results: N passed, M failed` line and exit code verbatim. Capture the `[PASS]`/`[FAIL]`
      lines for Assertion C (requirement d) and Assertion E specifically.
- [ ] If and only if that run is not 7/0: stop, record via `issue-record.sh`, and report. Do not
      edit the suite, do not loosen an assertion, and do not add a `known-failures.txt` row — all
      three are forbidden by the task's binding constraints.
- [ ] Count the `known-failures.txt` data rows (non-comment, non-blank) in the deployed copy and
      confirm the count is 4 or lower. Record the row count and the suite basenames.
- [ ] Confirm the fix is committed, not uncommitted: `git status --short` must be empty for
      `lua/neotex/plugins/ai/shared/extensions/merge.lua`,
      `lua/neotex/plugins/ai/shared/extensions/init.lua`, and
      `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh`.
- [ ] Confirm `merge.lua`'s `remove_tracked` still carries the `"new_object" and info.children`
      recursing branch (and that `"new_array"`/`"new_value"` retain unconditional removal), so the
      summary's root-cause statement is anchored to live code rather than to the report.
- [ ] Record the one-fault finding for the summary: C and E are the same fault on the same tracked
      record (`mcpServers` -> `mcpfixture-server`), C post-regenerate and E post-unload — not two
      independent faults.

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this phase asserts `test-mcp-merge-target.sh` is 7 passed / 0 failed and
`known-failures.txt` holds exactly 4 data rows. Both were measured while authoring this plan, but
both are hypotheses at implementation time (the tree is shared with two concurrent siblings).
Confirm each by the live run and the live row count above, and quote what the live run actually
printed — never this plan's figures.

**Tier Justification**: this phase edits no file, so no suite covers an edit and
`verify-touched.sh` has no touched path to resolve; per plan-format.md's Batch-aware-deferral
"Unmappable criterion" rule the phase's own named check is run directly as the scoped discharge —
`bash .claude/scripts/tests/test-mcp-merge-target.sh`, which is exactly the check acceptance
criterion 2 names.

**Files to modify**:
- None — this phase is read-only. It runs checks and records their output; it writes no file on
  disk, so it produces no commit of its own.

**Verification**:
- The suite's final line reads `Results: 7 passed, 0 failed` with exit code 0, and both the
  Assertion C and Assertion E lines are `[PASS]`.
- The `known-failures.txt` data-row count is 4 or lower.
- `git status --short` is empty for the three paths named above.

---

### Phase 2: Redeploy and Hand the Complete Gate Set to the Orchestration Close [NOT STARTED]

**Goal**: Close acceptance criterion 5 with a clean redeploy, and discharge acceptance criterion 1
the way a dispatch inside a batch is permitted to — a scoped check now, the complete set deferred
to the orchestration close and recorded as deferred.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and capture its `RESULT=` marker and exit code
      verbatim. `RESULT=landed_verify_clean` (exit 0) satisfies acceptance criterion 5. Note that
      this script supplies `--skip-slow --override-batch-gate-deferral` to its own inline
      verification pass, so the pending batch-gate marker cannot be misreported here as drift.
- [ ] On `RESULT=landed_verify_red` (exit 3): capture the findings verbatim, record via
      `issue-record.sh`, mark this phase [PARTIAL], and report. Do not re-run the full gate set to
      clear it, and do not force the deferral override.
- [ ] On `RESULT=not_landed` (exit 1 or 2): the deploy itself did not land — report it as a
      blocker; it is a different failure class from a verification red and must not be conflated.
- [ ] Run the scoped Gate 8 check that this phase's in-dispatch obligation actually is:
      `bash .claude/scripts/verify-deploy.sh --only-gate 8 --gate8-touched lua/neotex/plugins/ai/shared/extensions/merge.lua`.
      Capture its verdict. This is the scoped tier, not a substitute for the complete set.
- [ ] Record in the phase's verification notes, and in the summary, that the complete gate set was
      **deferred to the once-per-invocation batch-gate stage** rather than independently run, and
      why: a non-stale `batch-gate-pending` marker exists for this session, an unfiltered
      `verify-deploy.sh` refuses with `DEFERRED`, and `--override-batch-gate-deferral` belongs to
      that stage's own discharger. Acceptance criterion 1 is closed there, not here.
- [ ] Ensure the summary states, in plain terms: the merge code was the wrong side (not the test's
      expectation); the root cause is `remove_tracked` treating a tracked `"new_object"` like a
      `"new_array"`/`"new_value"` and removing it wholesale, destroying a hand-written sibling key
      inside it; the fix recurses into tracked children and prunes only when empty; and Assertions
      C and E are one fault, not two. Quote the Phase 1 pass/fail counts verbatim.
- [ ] Ensure the summary also carries the corrected framing for a future reader: the defect was
      already closed before this task's implementation phase, and the description's
      `agent-system/extensions/core/**` edit-target line does not apply to it.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree, so this
  phase carries a whole-tree claim and must serialize against any sibling that would do the same.
  No individual real file is hand-edited by this phase.

**Verification**:
- `deploy-headless.sh` prints `RESULT=landed_verify_clean` and exits 0.
- The scoped `verify-deploy.sh --only-gate 8 --gate8-touched ...` check is green, with its verdict
  captured.
- The deferral of the complete gate set to the orchestration close is explicitly recorded in this
  phase's verification notes and in the summary — recorded as a deferral, never as a satisfied
  criterion.

---

## Testing & Validation

- [ ] `test-mcp-merge-target.sh`: 7 passed, 0 failed, exit 0, with Assertions C and E both PASS
      (acceptance criterion 2, counts quoted verbatim).
- [ ] `known-failures.txt` data-row count is 4 or lower, never higher (acceptance criterion 4).
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean` (acceptance criterion 5).
- [ ] Scoped `verify-deploy.sh --only-gate 8 --gate8-touched` check green.
- [ ] Summary names the wrong side, the root cause, and the one-fault verdict (acceptance
      criterion 3).
- [ ] Complete gate set exit 0 — deferred to the orchestration close's batch-gate stage
      (acceptance criterion 1), recorded as deferred.
- [ ] No assertion loosened, skipped, or deleted; no `known-failures.txt` row added.

## Artifacts & Outputs

- `specs/645_repair_seven_failing_gate8_suites/plans/01_mcp-merge-closure-confirmation.md` (this file)
- `specs/645_repair_seven_failing_gate8_suites/summaries/01_mcp-merge-closure-confirmation-summary.md`
  carrying the verbatim counts, the wrong-side verdict, the one-fault verdict, and the recorded
  gate deferral
- A regenerated deployed `.claude/` tree (no source-store content change)

## Rollback/Contingency

No code change is made, so there is nothing to revert. If `deploy-headless.sh` fails to land, the
pre-existing deployed tree is unchanged by a `not_landed` outcome; re-run after the contending
sibling finishes rather than forcing anything. If a check contradicts this plan's premise — the
suite fails, or the known-failures count has grown — stop and report rather than editing the suite
or the roster: both remedies are forbidden by the task's binding constraints, and a live failure
would mean the premise re-validation above has been overtaken by a new event worth reporting on its
own terms.
