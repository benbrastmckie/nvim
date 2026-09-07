# Implementation Plan: Fix the two pre-existing verify-deploy gate failures

- **Task**: 151 - Fix the two pre-existing verify-deploy gate failures (state-writer boundary, whole-tree orphan)
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/151_fix_pre_existing_verify_deploy_failures/reports/01_verify-deploy-gate-failures.md
- **Artifacts**: plans/01_verify-deploy-gate-remediation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research established that FAILURE 1 (gate 12, state-writer boundary lint) was already remedied on
disk by commit `89f575aed` and currently reports 0 violations, and that FAILURE 2 (gate 13,
whole-tree orphan detection) currently reports 0 findings with its original single finding no
longer reproducible. This plan therefore does not re-fix FAILURE 1; it confirms both gates against
live evidence, records the FAILURE 1 remedy decision and its reasoning, honestly documents what
could and could not be established about FAILURE 2's finding identity, and closes the one
concrete, non-hypothetical defect that made that identity unrecoverable in the first place: gates
13 and 5 tell the operator to "re-run without `--quiet` for detail", but their per-finding detail
lines are emitted **only** under `--findings`, so a non-quiet re-run prints nothing extra. Done
means: gate 12 and gate 13 both pass in a full `verify-deploy.sh` run, the gate-13 hint is true
rather than false, and each conclusion is recorded with the evidence that supports it.

### Research Integration

Key findings carried into this plan:

- Gate 12 is green: `lint-state-writer-boundary.sh --verbose` reports 0 violations / 1075 files;
  `test-force-phases.sh` 19/19; `test-lint-state-writer-boundary.sh` 8/8. Independently
  re-confirmed at plan time (0 violations, 1075 files, 22 exempted).
- The chosen FAILURE 1 remedy is option **(a)**, applied uniformly to all four sites, because the
  fixture copies `state-write.sh` and its dependency chain into `$WORKDIR/.claude/scripts/` and
  `state-write.sh` resolves `PROJECT_ROOT` from its own invoked path — so the sanctioned writer
  already self-targets the scratch root with zero plumbing. Options (b) allowlist and (c)
  narrow-the-lint were live, supported mechanisms and were rejected on the merits, not by
  default.
- Gate 13 currently reports 0 findings (5353 files checked, 0 orphans, 0 ghost index rows). The
  original finding's identity was not captured and is not reproducible; research's evidenced
  hypothesis is a transient declared/deployed mismatch from a concurrent multi-task
  `/orchestrate` batch, consistent with the "uncommitted source-store working-tree artifact"
  exclusion class in `context/patterns/deploy-orphan-detection.md`.
- Research's Context Extension Recommendation names the diagnosability gap in gates 13 and 5
  (suppress-and-extract shape; detail only under `--findings`). Confirmed at plan time by reading
  both gate blocks: the `fail ... "re-run without --quiet for detail"` hint is factually wrong.
- Research flagged one unrelated live failure: gate 3 (doc-lint) Rule R `line_count` mismatch for
  `project/lean4/domain/comparator-integration.md` (declared 219, actual 247). Re-confirmed still
  failing at plan time (`check-extension-docs.sh --quiet`: lean FAIL, 1 issue). Phase 4 carries an
  explicit decision rule for it rather than leaving the "all gates passing" acceptance criterion
  silently unreachable.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap context was provided in this dispatch.

## Goals & Non-Goals

**Goals**:
- Confirm, from live re-runs rather than from the research report's transcription, that gate 12
  reports 0 violations and gate 13 reports 0 findings.
- Record the FAILURE 1 remedy choice (option (a), uniform across all four sites) and the reasoning
  that rejected options (b) and (c), in the implementation summary.
- Document what is actually known about FAILURE 2's finding — including, explicitly, that its
  identity was never captured and is not reproducible — without fabricating a specific file or row.
- Make gate 13's own remedy pointer true: emit the per-finding `ORPHAN_FINDING` detail in
  non-quiet output, so the next occurrence is diagnosable from first observation. Apply the same
  correction to gate 5, which shares the identical suppress-and-extract shape and the same false
  hint.
- Reach a full `verify-deploy.sh` run in which gates 12 and 13 pass, and either all other gates
  pass or every residual failure is named, reasoned about, and explicitly excluded.
- Leave a regression note per fix explaining what prevents silent re-breakage.

**Non-Goals**:
- Re-implementing the FAILURE 1 fix. It is committed, verified, and correct; this task confirms
  and records it.
- Weakening any gate. No detection logic, exclusion class, or allowlist is loosened anywhere in
  this plan; the only detection-adjacent change (Phase 3) is strictly additive output.
- Fixing the `line_count`/gate-coupling problem as a class — that is the sibling task's scope.
  Phase 4 touches at most the single stale declaration blocking the acceptance run, and only
  under the stated decision rule.
- Auto-deleting or auto-reconciling any orphan. `deploy-orphan-detection.md`'s detect-never-delete
  design is preserved unchanged.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent `/orchestrate` batches mutate the tree mid-verification, producing new transient gate failures | M | H | Capture `git status --short` and a process check immediately alongside every gate run; classify any new failure against `deploy-orphan-detection.md`'s four exclusion classes before treating it as real |
| Phase 3's added output breaks a downstream consumer that parses `verify-deploy.sh` stdout/stderr | H | L | Phase 3 is `interface` tier: enumerate and re-run the direct dependents (`deploy-headless.sh`, the postflight deploy gate, `test-deploy-verify-wiring.sh`, `test-postflight-deploy-gate.sh`) before closing; the change adds lines only and alters no exit code and no `--findings` output |
| Gate 3's residual `line_count` drift is concurrently owned by another in-flight task, so fixing it here causes an edit conflict | M | M | Phase 4 re-checks ownership (`git log`/`git status` on the lean extension's `index-entries.json`) before touching it and takes the documented exclusion path instead of editing if the file is in flight |
| Acceptance criterion "the finding's actual identity documented" cannot be literally satisfied | M | H (already realized) | Phase 2 documents the identity question honestly with evidence and a falsifiable hypothesis, and Phase 3 removes the mechanism that made recovery impossible — recorded as a stated deviation, not a silent gap |
| The Phase 3 end-to-end check requires a temporary undeclared file under `.claude/` | L | M | Create and delete the probe inside a single command with `trap`-guarded cleanup; it is a transient test artifact, never a hand-authored deploy-tree edit, and the tree is re-verified clean afterward |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Confirm the FAILURE 1 remedy and capture its decision evidence [COMPLETED]

**Goal**: Establish from live re-runs (not from the research report's transcription) that gate 12
is green, and capture the exact command output that the summary's decision record will cite.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose`
      and record the files-checked / exempted / violations triple verbatim. *(completed: Files
      checked: 1075, Candidate lines exempted: 22, Total violations: 0)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-force-phases.sh` and record the
      pass/fail counts. *(completed: 19 passed, 0 failed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` and
      record the pass/fail counts. *(completed: 8 passed, 0 failed)*
- [x] Read the four converted call sites in
      `agent-system/extensions/core/scripts/tests/test-force-phases.sh` and confirm all four now
      invoke `"$WORKDIR/.claude/scripts/state-write.sh"`, with no residual `jq ... > tmp && mv`
      state write in the file. *(completed: lines 265, 312, 323, 334 all route through
      state-write.sh; no state.json.tmp pattern remains)*
- [x] Confirm the in-file regression comment (added by commit `89f575aed` above the first
      converted site) states why the suite is not exempt from the boundary contract. If the
      comment is absent or does not name the contract, add a one-line pointer near the remaining
      converted sites; otherwise change nothing. *(completed: comment present at lines 261-264,
      names lint-state-writer-boundary.sh's boundary contract explicitly; no edit needed)*
- [x] Draft the decision record text for the summary: remedy (a), uniform across all four sites,
      with the `PROJECT_ROOT`-self-resolution reasoning and the explicit rejection of (b)
      allowlist and (c) narrow-detection. *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts four converted call sites in one file, and expected
results of 0 lint violations, 19/19 `test-force-phases.sh`, and 8/8
`test-lint-state-writer-boundary.sh`. Confirm at implementation time by running the three commands
above and by grepping the file for any remaining `state.json.tmp` / `> ... && mv` pattern; the
counts may legitimately differ if another task has since added cases, in which case record the
observed numbers rather than the planned ones.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` - only if the regression
  comment is missing; otherwise no edit.

**Verification**:
- `lint-state-writer-boundary.sh --verbose` exits 0 with `Total violations: 0`.
- Both test suites report 0 failures.
- No `state.json.tmp` occurrence remains in `test-force-phases.sh`.

---

### Phase 2: Establish gate 13's current state and record the orphan-finding identity question [NOT STARTED]

**Goal**: Re-run whole-tree orphan detection directly, classify anything it reports, and produce
the honest, evidence-backed record of what the original single finding was and was not.

**Tasks**:
- [ ] Run gate 13's detection directly (the headless-nvim `manager.find_orphans` snippet from
      `verify-deploy.sh`'s gate 13 block, against this repo root) and record the `ORPHAN_DONE
      checked=` count and every `ORPHAN_FINDING` line, if any.
- [ ] Capture the concurrent-activity context at the same moment: `git status --short` and a check
      for other running `verify-deploy.sh` / `/orchestrate` processes.
- [ ] If any finding IS reported: classify it against the four exclusion classes in
      `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` (runtime
      artifact, merged/generated artifact, `.syncprotect`-protected path, uncommitted source-store
      working-tree artifact). Record the class and the evidence. Only if it fits none of the four
      is it a real orphan requiring a source-store remedy — in that case, stop and re-scope rather
      than deleting anything.
- [ ] If 0 findings are reported: record that outcome, plus the explicit statement that the
      original finding's identity was never captured and is not reproducible, plus research's
      falsifiable transient-concurrency hypothesis and how a future occurrence would confirm or
      refute it.
- [ ] Note the untracked source-store path currently present in `git status`
      (`agent-system/extensions/literature/scripts/literature-pyenv/`) as a concrete live example
      of the "uncommitted source-store working-tree artifact" class, since it is exactly the shape
      the hypothesis names.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase assumes gate 13 will again report 0 findings over roughly 5353
checked files. Confirm by the direct `find_orphans` run; the checked count will drift with tree
size and a nonzero finding count is a live possibility that the classification branch above
handles. Do not carry the 5353 figure into the summary without re-observing it.

**Files to modify**:
- None (evidence gathering only).

**Verification**:
- The direct `find_orphans` invocation emits `ORPHAN_DONE` (i.e. the detector actually ran, rather
  than erroring), and every emitted `ORPHAN_FINDING` line, if any, has a recorded classification.

---

### Phase 3: Make gates 13 and 5 emit their per-finding detail in non-quiet output [NOT STARTED]

**Goal**: Remove the defect that made FAILURE 2's identity unrecoverable — both gates instruct the
operator to "re-run without `--quiet` for detail", but their per-finding lines are appended only to
`FINDINGS_LIST` under `--findings`, so a non-quiet run prints nothing extra.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/verify-deploy.sh`, in the gate 13 failure branch,
      emit each extracted `ORPHAN_FINDING` line to the operator-visible output on failure,
      independent of the `--findings` flag, keeping the existing `--findings`
      `FINDINGS_LIST` population exactly as it is (additive change only).
- [ ] Apply the identical change to the gate 5 failure branch (`VERIFY_FINDING` lines), which
      shares the same suppress-and-extract shape and the same hint text.
- [ ] Update both `fail` hint strings so they describe what the script actually does now.
- [ ] Confirm no exit code, no `CHECKS`/`FAILURES` accounting, and no `--findings` output line
      changes as a result — the sorted-unique `FINDING ` block must be byte-identical for the same
      input.
- [ ] Add a short subsection to
      `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` recording that a
      gate-13 failure now prints its findings directly, so the measurement recipe is a
      follow-up-classification tool rather than the only way to learn what was found.
- [ ] End-to-end check: with `trap`-guarded cleanup in a single command, create one deliberately
      undeclared file under `.claude/` (e.g. `.claude/context/__orphan-probe-151.md`), run the
      gate-13 detection, confirm the probe path is named in the non-quiet output, then delete the
      probe and re-run detection to confirm it returns to 0 findings and the tree is clean.

**Timing**: 60 minutes

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (i) exactly two gate blocks share the suppress-and-extract
shape, and (ii) a direct-dependent set of `deploy-headless.sh`, the orchestrator postflight deploy
gate, `test-deploy-verify-wiring.sh`, and `test-postflight-deploy-gate.sh`. Confirm (i) by grepping
`verify-deploy.sh` for `FINDINGS = "true"` blocks that pass `""` as `fail`'s third argument, and
(ii) by grepping the source store for consumers of `verify-deploy.sh` before closing the phase;
extend the re-run set if the grep finds more.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - gate 13 and gate 5 failure branches:
  print per-finding detail on failure regardless of `--findings`; correct both hint strings.
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` - short subsection
  recording the new fail-time detail output.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` passes.
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` is clean.
- The orphan-probe check names the probe file in non-quiet output, and detection returns to 0
  findings after cleanup with `git status --short` showing no leftover probe.

---

### Phase 4: Redeploy, run the full gate suite, and reconcile any residual failure [NOT STARTED]

**Goal**: Reach the acceptance state — a full `verify-deploy.sh` run with gates 12 and 13 passing
and every other gate either passing or explicitly, reasonedly excluded.

**Tasks**:
- [ ] Redeploy from the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`
      (allow several minutes; it runs verification inline and exits 3 on gate failure).
- [ ] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` in full (no `--quiet`,
      several minutes) and record the per-gate result line for gates 12 and 13 plus the final
      `N of M check(s)` summary.
- [ ] If any gate other than 12/13 fails, apply this decision rule, in order:
      (a) if it is a stale `index-entries.json` `line_count` declaration and the owning
      `index-entries.json` is not currently being edited by another in-flight task (check
      `git status --short` and recent `git log` on that file), correct the declaration using the
      sanctioned tool `agent-system/extensions/core/scripts/generate-context-line-counts.sh` —
      this synchronizes a declaration to reality and weakens no check — then re-run gate 3;
      (b) otherwise, do NOT fix it here: record it as an explicit, named exclusion with its
      reasoning, mark this phase `[COMPLETED WITH EXCLUSIONS]`, and carry the exclusion into the
      summary.
- [ ] Re-run `verify-deploy.sh` after any correction and record the final gate tally.
- [ ] Confirm no edit made in this task targets `.claude/**` (source-store boundary rule): review
      the phase's diff paths before committing.

**Timing**: 45 minutes

**Depends on**: 1, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes exactly one residual non-target failure — gate 3, Rule R,
`project/lean4/domain/comparator-integration.md`, declared 219 vs actual 247 (re-confirmed still
failing at plan time). Confirm by the full run; if the residual set is larger, different, or empty,
apply the decision rule to what is actually observed rather than to this hypothesis.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` (or whichever extension's index the observed
  drift belongs to) - only under decision-rule branch (a), and only the drifted `line_count`
  values.

**Verification**:
- `verify-deploy.sh` reports `[PASS]` for gate 12 and gate 13 explicitly.
- The run's final summary reports 0 failures, or every failure is enumerated with its exclusion
  reasoning.
- `deploy-headless.sh` exits 0.

---

### Phase 5: Write the decision record and regression notes into the summary [NOT STARTED]

**Goal**: Satisfy the acceptance criteria's recording obligations in the implementation summary.

**Tasks**:
- [ ] Record the FAILURE 1 remedy decision from Phase 1: option (a), uniform across all four sites,
      with the reasoning and the explicit rejection of (b) and (c), and the verbatim lint/test
      evidence.
- [ ] Record the FAILURE 2 outcome from Phase 2: gate 13's observed state, the honest statement
      that the original finding's identity was never captured and is not reproducible, the
      evidenced transient-concurrency hypothesis, and the classification of anything newly
      observed.
- [ ] Record the Phase 3 change as the substantive FAILURE 2 remedy: the false hint is now true,
      and the next gate-13 (or gate-5) failure names its findings at first observation.
- [ ] Write the two regression notes: (1) FAILURE 1 cannot silently re-break because gate 12 runs
      `lint-state-writer-boundary.sh` over the whole source store on every `verify-deploy.sh`, and
      `test-lint-state-writer-boundary.sh` pins the lint's own detection behavior; (2) FAILURE 2's
      diagnosability cannot silently re-break because gate 13 runs on every redeploy checkpoint
      and now prints its findings unconditionally on failure.
- [ ] Record any Phase 4 exclusion explicitly, including that gate 3's `line_count` drift class is
      the sibling task's scope.
- [ ] State the deviation plainly: the acceptance criterion "the finding's actual identity
      documented" is satisfied by an honest non-reproducibility record plus a diagnosability fix,
      not by naming a file that was never observed.

**Timing**: 30 minutes

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `specs/151_fix_pre_existing_verify_deploy_failures/summaries/01_*-summary.md`

**Verification**:
- Every acceptance bullet from the task description maps to a named section of the summary, with
  the two that could not be literally satisfied marked as stated deviations rather than omitted.

---

## Testing & Validation

- [ ] `lint-state-writer-boundary.sh --verbose` reports 0 violations.
- [ ] `test-force-phases.sh` reports 0 failures.
- [ ] `test-lint-state-writer-boundary.sh` reports 0 failures.
- [ ] `test-deploy-verify-wiring.sh`, `test-postflight-deploy-gate.sh`, `test-deploy-orphans.sh`
      all report 0 failures.
- [ ] `bash -n verify-deploy.sh` clean.
- [ ] Direct `find_orphans` run emits `ORPHAN_DONE` with every finding classified.
- [ ] Orphan-probe end-to-end check names the probe in non-quiet output and cleans up fully.
- [ ] Full `verify-deploy.sh`: gate 12 PASS, gate 13 PASS; 0 failures or all failures explicitly
      excluded.
- [ ] `deploy-headless.sh` exits 0.

## Artifacts & Outputs

- `specs/151_fix_pre_existing_verify_deploy_failures/plans/01_verify-deploy-gate-remediation.md`
  (this plan)
- `specs/151_fix_pre_existing_verify_deploy_failures/summaries/01_*-summary.md` (decision record +
  regression notes)
- Modified: `agent-system/extensions/core/scripts/verify-deploy.sh` (gates 13 and 5 fail-time
  detail output)
- Modified: `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` (fail-time
  detail subsection)
- Conditionally modified: an extension `index-entries.json` `line_count` value, only under Phase
  4's decision-rule branch (a)
- Regenerated: the `.claude/` deploy tree (deploy artifact, not committed as hand-authored content)

## Rollback/Contingency

- Phase 3 is the only non-conditional code change and touches one script plus one doc; revert with
  `git revert` of that phase's commit, then redeploy. Nothing else depends on its output shape.
- Phase 4's conditional `line_count` correction is a single numeric field; revert the same way.
- If Phase 2 surfaces a real orphan (fits none of the four exclusion classes), do not delete
  anything: stop, record the finding, and re-scope — `deploy-orphan-detection.md`'s
  detect-never-auto-delete design is deliberate and this task must not be the exception to it.
- If the full run in Phase 4 cannot reach 0 failures because of a concurrently-owned residual
  failure, close Phase 4 as `[COMPLETED WITH EXCLUSIONS]` with the exclusion recorded rather than
  editing another task's in-flight file.
