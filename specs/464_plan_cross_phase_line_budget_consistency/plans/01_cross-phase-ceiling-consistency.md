# Implementation Plan: Task #464

- **Task**: 464 - Plan cross-phase line/scope budget consistency
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/464_plan_cross_phase_line_budget_consistency/reports/01_cross-phase-line-budget-consistency.md
- **Artifacts**: plans/01_cross-phase-ceiling-consistency.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close a plan-time self-contradiction gap: a plan can cite a numeric ceiling for some quantity,
carry per-phase estimates of that same quantity whose sum exceeds the ceiling, and simultaneously
assert in its own prose that it stays under that ceiling. Research settled the design on option
(b) from the task description — a mandatory stated rule in `plan-format.md` plus one advisory
mechanical check added to the existing per-phase loop in `validate-artifact.sh` — and this plan
executes exactly that, with a regression suite case and a redeploy. Three source-store files are
touched; no new script and no new required plan field are introduced.

### Research Integration

The research report's findings are adopted as-is and not re-litigated:

- The gap is structural, not a missing field. `plan-format.md`'s `### Counts-are-hypotheses
  obligation` subsection already requires a per-phase `**Scope Hypothesis:**` line whenever a
  phase asserts a count or scope estimate, but that field points each estimate *forward* at
  implementation-time reality, one phase at a time. Nothing compares the estimates to each other
  or to a ceiling the same plan quotes in its own prose.
- `validate-artifact.sh` is the right consumer and needs no new script. Re-derived at plan
  authoring time: the per-phase loop lives at lines 303-368 of the 388-line file, inside the one
  `if [ "$artifact_type" = "plan" ]` branch. It already runs
  `mapfile -t phase_line_nums < <(grep -nE "$PHASE_HEADING_ERE" ...)`, isolates each phase with
  `phase_block=$(sed -n "${start_line},${end_line}p" ...)`, and regex-extracts a field value from
  that block (the `Verification Tier` check) plus a header-presence test (the `Files to modify`
  check, with a deferred two-tier emission after the loop). A new check is a sibling read of the
  same `phase_block` variable.
- The advisory-first convention with a named promotion criterion is already established twice in
  the same file (`Verification Tier`; `Files to modify`, per-phase tier), and documented in
  `plan-format.md`'s `### Enforcement level` and `### Enforcement level (Files to modify)`
  subsections. The new check follows that shape rather than inventing a third convention.
- No new required field. `**Scope Hypothesis:**` stays free-form prose (the format document says
  so explicitly and says it is deliberately not a `file_scope` harvest source), so the check
  reads it with a best-effort regex. Because the check is advisory and strictly additive, a
  heuristic's false negatives only ever mean a warning is not raised — never that a contradiction
  is silently blessed by a weaker requirement.
- Rejected options, on their own merits: **(a) authoring rule only** — the incident was an author
  failing to do arithmetic, so a rule asking for the same arithmetic again has no backstop, and
  this repository's own corpus already shows authors writing ceiling-citing prose unprompted
  without catching contradictions. **(c) planner-agent checklist item** — an agent prompt is far
  more volatile than a format document and a tested shell script; there is no durable record that
  the check ran, no counted residue, and no promotion path to a stronger guarantee.

Re-derived at plan authoring time rather than carried: `plan-format.md` heading offsets (the
`### Counts-are-hypotheses obligation` subsection begins at line 461; `### Enforcement level` at
490; `### Enforcement level (Files to modify)` at 502; `### Naming a tool's entry point in
verification criteria` at 537), `validate-artifact.sh` length (388 lines) and loop bounds
(303-368), and the covering-suite resolution for both target files via
`suite_selection_select` (recorded per phase below).

CARRIED-UNVERIFIED, source named: the originating incident's figures
(`110+120+95+10+90+80+130` against a 959-line baseline summing to ~1594 past a cited 1500-line
ceiling, with the file crossing at Phase 6) come from BimodalLogic's issue log entry
`iss_1793754003650_RvAmat`. The originating plan is not in this repository and the figures are not
re-derivable here. They are used only as the illustrating incident and as the worked example's
shape, never as a measurement this repository asserts.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- State the rule once, generally: a plan citing a numeric ceiling for some quantity and carrying
  per-phase estimates of that same quantity must not also assert conformance against its own
  arithmetic. Phrased for ANY numeric ceiling (line count, file count, token budget), with the
  Lean `longFile` linter appearing at most as one parenthetical worked example.
- Record the decision among (a), (b), (c) in the format document itself, with the rejected
  options stated on their own merits.
- Add one advisory, non-blocking mechanical check to `validate-artifact.sh`'s existing per-phase
  plan loop, reusing the existing `phase_block` machinery and the existing advisory-first
  convention, with a named promotion criterion documented alongside the two that already exist.
- Add a regression case to the existing `test-validate-artifact.sh` fixture suite covering both
  the contradiction-detected and the no-contradiction paths.
- Redeploy the source store and leave the deployed tree verified clean.

**Non-Goals**:
- Improving per-phase line-estimate accuracy. The deliverable is internal consistency only.
- Any blocking gate over approximate numbers. The check emits `log_warn` in default mode and is
  promoted to a failing exit only by the pre-existing `--strict` `total_issues = errors + warnings`
  branch, which this change does not modify.
- Any Lean-specific clause in `plan-format.md`. `longFile`, `LEAN_STYLE_GUIDE.md` and
  `MODULE_INVARIANTS` appear nowhere in `agent-system/` today and must not be introduced as
  governing vocabulary.
- A new structured plan field, a new microformat inside `**Scope Hypothesis:**`, a new script, or
  any change to `plan-file-scope-harvest.sh`'s harvest grammar.
- Any edit under a deployed `.claude/` tree, and any edit to `plan-format.md` outside the new
  subsection and the enforcement-level subsection it extends.
- Executing the new check's promotion criterion (a corpus sweep of non-terminal plans). It is
  recorded for a future task, exactly as the two existing promotion criteria were.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dead-lifecycle-command prose sweep also owns sites in `plan-format.md` (CONFIRMED at plan time: line 3 names `/plan, /revise, /implement, /review`; line 417 names a bare `` `/implement N` ``) | M | H (already true) | That sweep is `not_started` and is not a concurrent sibling this cycle, so there is no live race and no dependency edge is warranted. Constrain this task's edits to the new subsection and the `### Enforcement level` area only; never touch line 3 or line 417, and never introduce a new `/research`, `/plan` or `/implement` reference in the new text (say "a plan dispatch" or "the plan phase"). Re-read the file immediately before editing per the concurrency note. |
| Heuristic false negatives: a badly-phrased estimate or ceiling the regex misses | L | H | Accepted by design. The check is advisory and strictly additive — a miss means no warning, never a suppressed stricter finding. The rule text, which is mandatory, covers what the regex cannot. |
| Heuristic false positives: an unrelated number near an unrelated "ceiling"/"under" word | M | M | Require the SAME unit word to co-occur in the per-phase estimate and the plan-level ceiling citation; require an explicit ceiling-indicating word (`ceiling|limit|budget|cap`); require a conformance-assertion phrase. Residual is a non-blocking warning in default mode, consistent with the existing per-phase warnings' tolerance for imprecision. |
| Scope creep toward estimate accuracy | M | M | The rule's trigger condition is purely internal arithmetic contradiction. Phase 1's verification explicitly reads the drafted text for any accuracy obligation and removes it. |
| New check regresses an existing plan in the live corpus, turning a `--strict` caller red | M | L | Phase 3 runs the new check over every non-terminal plan under `specs/` in default mode and records the observed residue; no call site of `validate-artifact.sh` is blocking, and default mode exits 0 on warnings alone. |
| Whole-tree-claim serialization at implement admission (another task in flight also declares `__WHOLE_TREE__`) | L | M | Expected and correct: the sentinel exists so two whole-tree regenerators serialize. Treat a `whole_tree_claim` deferral as the intended visibility surface, not an error. |
| `deploy-headless.sh` exit 0 (`RESULT=landed_verify_clean`) certifies only the FAST verify subset | M | H | The final phase runs the full `verify-deploy.sh` with no `--skip-slow` and no `--only-gate`, separately from the deploy's own inline verify, and reads that run's verdict as the phase's evidence. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully serial by substance: the
check implements a rule the rule text must first define, the regression suite tests the check, and
the redeploy must observe all three.

---

### Phase 1: State the Cross-Phase Ceiling Consistency Rule [COMPLETED]

**Goal**: `plan-format.md` carries the rule, sited once, phrased generally, with the (a)/(b)/(c)
decision and the rejected options recorded.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/formats/plan-format.md` immediately before
      editing (a sibling may have changed it) and re-derive the current line number of
      `### Counts-are-hypotheses obligation`. *(completed)*
- [x] Insert a new `### Cross-phase ceiling consistency obligation` subsection immediately after
      `### Counts-are-hypotheses obligation` and before `### Enforcement level`, stating: when a
      plan cites a numeric ceiling for some quantity AND one or more phases carry a
      `**Scope Hypothesis:**` estimating that same quantity, the plan MUST NOT assert anywhere in
      its own prose (Goals & Non-Goals, Risks & Mitigations, Rollback/Contingency, or a phase
      block) that the quantity stays under or within that ceiling when the plan's own per-phase
      estimates, summed against any stated starting baseline, already exceed it. *(completed)*
- [x] In the same subsection, state the positive obligation: where the author expects the quantity
      to approach or cross the ceiling, the plan says so and names its own contingency (widening
      the ceiling via the governing limit's own sanctioned escape valve, splitting a phase, or
      re-scoping) rather than asserting conformance its own numbers contradict. *(completed)*
- [x] State the relationship to the sibling obligation explicitly: `**Scope Hypothesis:**` governs
      each estimate's forward-looking confirmation one phase at a time; this subsection governs
      the relation BETWEEN those estimates and a ceiling the same plan quotes. Neither discharges
      the other. *(completed)*
- [x] Add exactly one parenthetical worked example using a line-count limit of the Lean
      `longFile` shape, written so the governing vocabulary stays generic (a numeric line ceiling
      a plan cites) and the Lean linter name appears only inside the example. *(completed)*
- [x] Record the decision and the rejected alternatives in the same subsection, on their own
      merits: a mechanical check in the existing validator, chosen because an authoring rule alone
      asks for the same arithmetic the incident shape already failed to do, and because an agent
      checklist item leaves no durable record, no counted residue and no promotion path.
      *(completed)*
- [x] Extend the `### Enforcement level` area with the new check's own advisory posture and a
      named promotion criterion in the same shape as the two existing ones: promote the warning to
      an error once a sweep of non-terminal plans under `specs/` shows zero plans would newly
      fail, re-measured at that time rather than trusting a recorded count. *(completed: new
      `### Enforcement level (Cross-phase ceiling consistency)` subsection added; residue left as
      "pending a corpus sweep recorded separately in this same document" for Phase 3 to fill in)*
- [x] Verify by grep that the edit introduced no new `/research`, `/plan` or `/implement` slash
      command reference and that lines 3 and 417 are byte-identical to their pre-edit state.
      *(completed: both confirmed unchanged)*
- [x] Verify by grep that the added text contains no task-number reference and no
      record-versioning language ("no longer", "previously", "formerly", "supersedes", "v1").
      *(completed: no matches in the added diff hunks)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one markdown file with no executable surface, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
is the resolved covering suite set for `plan-format.md`, run together with the diff read-through
the `local` row prescribes.

**Scope Hypothesis**: The new subsection is estimated at roughly 40-55 added lines in
`plan-format.md`, and the enforcement-level extension at roughly 8-12 more. Confirm at
implementation time with `git diff --stat` on that one file rather than treating these figures as
facts; a materially larger diff means the subsection has absorbed content that belongs in the
check's own header comment instead.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - add
  `### Cross-phase ceiling consistency obligation` after `### Counts-are-hypotheses obligation`;
  extend the `### Enforcement level` area with the new check's advisory posture and promotion
  criterion.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
  exits 0.
- `grep -nE '/research|/plan\b|/implement' agent-system/extensions/core/context/formats/plan-format.md`
  returns the same site set as before the edit (lines 3 and 417 only, for the slash-command form).
- Diff read-through confirms every changed hunk lies inside the new subsection or the
  enforcement-level area, and that no sentence imposes an estimate-accuracy obligation.
- `grep -nEi 'longFile|LEAN_STYLE_GUIDE|MODULE_INVARIANTS' agent-system/extensions/core/context/formats/plan-format.md`
  shows `longFile` only inside the worked example and no other Lean identifier anywhere.

---

### Phase 2: Add the Advisory Check to validate-artifact.sh [COMPLETED]

**Goal**: `validate-artifact.sh` warns, non-blockingly, when a plan's own per-phase estimates sum
past a ceiling the same plan cites while asserting conformance.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-artifact.sh` immediately before
      editing and re-derive the per-phase loop's current bounds. *(completed)*
- [x] Inside the existing per-phase `for i in "${!phase_line_nums[@]}"` loop, add a sibling block
      that reads the already-computed `phase_block` and extracts a numeric-with-unit token from
      that phase's `Scope Hypothesis` text, accepting both punctuation conventions
      (`**Scope Hypothesis**:` and `**Scope Hypothesis:**`) exactly as the neighbouring checks do.
      *(completed)*
- [x] Accumulate a running sum per distinct unit word encountered, and remember which phase
      numbers contributed to each unit's sum, so the warning can name them. *(completed: unit
      word normalized to a singular stem so "lines"/"line" aggregate together)*
- [x] After the loop, scan the whole document (not phase-scoped — a ceiling citation and a
      conformance assertion both live in plan-level prose) for a ceiling citation whose unit word
      matches an accumulated unit AND sits near a ceiling-indicating word
      (`ceiling|limit|budget|cap`), and separately for a conformance assertion
      (`stays|remains` + optional `well` + `under|within|below`) near the same number. *(completed:
      implemented as same-line co-occurrence of digit + ceiling-word + unit-stem for the ceiling
      citation, and unit-stem co-occurrence with the stays/remains phrase for the conformance
      assertion, rather than literal numeric proximity — a deliberate, documented heuristic
      simplification)*
- [x] Emit `log_warn` only when all three hold for the same unit word — estimates accumulated, a
      ceiling cited, a conformance assertion present — and the sum (plus any stated baseline
      the scan found) exceeds the cited ceiling. Name the contributing phases, the summed total
      and the cited ceiling in the message. *(completed; manually verified against a synthetic
      contradiction fixture, a no-contradiction fixture, and a no-ceiling fixture — see the
      permanent versions of these fixtures added to test-validate-artifact.sh in Phase 3)*
- [x] Add a header comment above the block recording: the advisory-first posture, the promotion
      criterion by reference to `plan-format.md`'s enforcement-level area, the deliberate
      heuristic-not-field choice, and an explicit note that the block must never be promoted to
      `log_error` as part of an unrelated migration (mirroring the existing note on the
      Verification Tier check). *(completed)*
- [x] Confirm the block never calls `log_error` and never touches the
      `total_issues`/`strict_mode` summary logic. *(completed: confirmed by grep)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` (or the repository's
      sanctioned entry point for shellcheck) over the changed script and resolve any new finding.
      *(completed: 0 findings at -S warning)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to one script with no change to any externally
visible signature or exit-code contract, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-artifact.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh`
is the resolved covering suite set for `validate-artifact.sh`.

**Scope Hypothesis**: The new block plus its header comment is estimated at roughly 35-50 added
lines, all inside the existing `if [ "$artifact_type" = "plan" ]` branch, with zero lines changed
outside it. Confirm at implementation time with `git diff --stat` and with a read of the diff's
hunk headers; a hunk landing outside that branch means the block has been mis-sited.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - add the per-phase numeric
  accumulation inside the existing phase loop and the deferred whole-document
  ceiling/conformance scan plus `log_warn` emission after it.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-artifact.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh`
  exits 0 (the pre-existing suites still pass; the new case lands in Phase 3).
- `bash agent-system/extensions/core/scripts/validate-artifact.sh specs/464_plan_cross_phase_line_budget_consistency/plans/01_cross-phase-ceiling-consistency.md plan`
  exits 0 — this plan cites no ceiling, so the new check must stay silent on it.
- `grep -n 'log_error' agent-system/extensions/core/scripts/validate-artifact.sh` shows no new
  occurrence relative to the pre-edit file.
- Shellcheck via the repository's sanctioned lint entry point reports no new finding.

---

### Phase 3: Regression Suite Cases and Live-Corpus Residue [COMPLETED]

**Goal**: The new check is covered by fixtures in both directions, and its effect on the live plan
corpus is measured and recorded rather than assumed.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` and reuse its
      existing structural model: the `pass()`/`fail()`/`info()` helpers, the `PASSED`/`FAILED`
      counters, the `mktemp -d` workdir with `trap EXIT` cleanup, and a new
      `make_*_fixture()` helper mirroring `make_two_phase_ftm_fixture()`'s shape. *(completed; also
      added a `VALIDATE_SRC` variable — see deviation below — since the suite's existing `$VALIDATE`
      resolution is deploy-tree-first and would otherwise test the stale deployed copy pre-redeploy)*
- [x] Add a contradiction fixture: a plan whose per-phase `Scope Hypothesis` estimates sum past a
      ceiling the same plan cites in its Rollback/Contingency section while asserting it stays
      under that ceiling. Assert the check warns, names the ceiling and the summed total, and that
      default-mode exit stays 0 (advisory, not blocking). *(completed: case ceiling(f))*
- [x] Add a no-contradiction fixture: the same shape with estimates summing below the cited
      ceiling. Assert no warning from the new check. *(completed: case ceiling(g))*
- [x] Add a no-ceiling fixture: per-phase estimates present but no ceiling cited anywhere. Assert
      no warning — the check must not fire on estimates alone. *(completed: case ceiling(h))*
- [x] Add a `--strict` assertion on the contradiction fixture confirming the warning is promoted
      to a failing exit by the pre-existing `total_issues = errors + warnings` branch, with no new
      strictness logic of its own. *(completed)*
- [x] Run the new check in default mode over every non-terminal plan under `specs/`, count the
      plans that newly warn, and record that residue in `plan-format.md`'s promotion-criterion
      text (or, if the count is zero, record that it was measured as zero at this check's
      authoring and must be re-measured before promotion). *(completed: 0 of 14 non-terminal,
      plan-linked tasks newly warn; recorded in plan-format.md)*
- [x] Update the suite's header comment to name the new check among the checks it covers.
      *(completed)*

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file plus a promotion-criterion sentence
in one markdown file, and `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
is itself the covering check for the suite under edit.

**Scope Hypothesis**: Three new fixture helpers and roughly 6-9 new assertions, estimated at
roughly 90-130 added lines in `test-validate-artifact.sh`, plus one to three sentences in
`plan-format.md`. Confirm the live-corpus residue count by actually running the check over the
non-terminal plans rather than estimating it; the residue figure recorded in the promotion
criterion must be the observed count, never a projection.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - add the three fixtures,
  the direction assertions, the `--strict` assertion, and the header-comment update.
- `agent-system/extensions/core/context/formats/plan-format.md` - record the measured live-corpus
  residue in the new check's promotion criterion.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with every
  new case reported PASS.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-artifact.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh`
  exits 0.
- The default-mode sweep over non-terminal `specs/` plans is run, its warning count observed, and
  the observed number (not an estimate) appears in the promotion-criterion text.
- Diff read-through confirms the `plan-format.md` hunk touches only the promotion-criterion
  sentence added in Phase 1, and that lines 3 and 417 remain untouched.

---

### Phase 4: Redeploy and Full Gate Set [NOT STARTED]

**Goal**: The source-store changes are deployed and the whole gate set is observed green.

**Tasks**:
- [ ] Confirm the three source-store files are committed and the working tree holds no
      unrelated staged hunks.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` and confirm
      `RESULT=landed_verify_clean` (exit 0).
- [ ] Confirm the deployed `.claude/context/formats/plan-format.md` and
      `.claude/scripts/validate-artifact.sh` carry the new subsection and the new check
      respectively, so the deploy is known to have landed this task's content and not merely
      exited 0.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` with no `--skip-slow` and no `--only-gate`, and
      read its verdict as this phase's evidence — the deploy's own inline verify covers only the
      fast subset and is not a substitute.
- [ ] Confirm Gate 3 (doc-lint) and Gate 4 (task-reference lint) both ran and did not SKIP, since
      this task's edits are source-store markdown and a silent SKIP would attest to nothing.

**Timing**: 30 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree, so this phase
  carries a whole-tree claim and serializes against any other task that also regenerates it.

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` exits 0 with
  `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` (complete gate set, no narrowing flags) exits 0.
- Gate 3 and Gate 4 are both reported as having run, not SKIPped.
- `grep -c 'Cross-phase ceiling consistency' .claude/context/formats/plan-format.md` is non-zero
  and the deployed `validate-artifact.sh` contains the new check block.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with the
      contradiction, no-contradiction and no-ceiling cases all PASS.
- [ ] The contradiction fixture warns in default mode AND default-mode exit stays 0, proving the
      check is advisory and not blocking.
- [ ] `--strict` turns the same fixture's warning into a failing exit through the pre-existing
      `total_issues = errors + warnings` branch, with no new strictness logic added.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-artifact.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh`
      exits 0.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
      exits 0.
- [ ] The default-mode sweep over non-terminal `specs/` plans is run and its observed warning count
      is recorded in the promotion criterion.
- [ ] No Lean identifier (`longFile`, `LEAN_STYLE_GUIDE`, `MODULE_INVARIANTS`) appears in
      `plan-format.md` outside the single worked example, and none appears in
      `validate-artifact.sh` at all.
- [ ] No task-number reference and no record-versioning language in any hunk landing under
      `agent-system/**`.
- [ ] `bash agent-system/extensions/core/scripts/deploy-headless.sh` reaches
      `RESULT=landed_verify_clean`, and the full `verify-deploy.sh` run exits 0 with Gates 3 and 4
      not SKIPped.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` — new
  `### Cross-phase ceiling consistency obligation` subsection with the generalized rule, the
  recorded decision and rejected alternatives, one worked example, and the new check's advisory
  posture plus measured promotion criterion.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — new advisory check block inside
  the existing plan-type per-phase loop plus the deferred whole-document scan and `log_warn`.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — three new fixtures and
  their direction and strictness assertions.
- A regenerated deployed `.claude/` tree carrying all three.
- A summary artifact at completion.

## Rollback/Contingency

All three edits are additive and independently revertable, and no call site of
`validate-artifact.sh` is blocking in default mode, so a bad check degrades to a spurious
non-blocking warning rather than a broken gate.

- **Phase 1 only landed**: revert the `plan-format.md` hunks. The rule is prose with no consumer
  yet; nothing else depends on it.
- **Phase 2 landed and the check misbehaves**: revert the single block in `validate-artifact.sh`.
  The surrounding loop and both neighbouring checks are untouched by this change, so the revert is
  a clean excision rather than an unwind.
- **Phase 3 reveals an unacceptable live-corpus residue**: do not promote and do not relax the
  rule text. Narrow the heuristic (tighten the ceiling-indicating word set, or require the
  conformance assertion and the ceiling citation to share a line) and re-measure. The rule in
  `plan-format.md` stands independently of how much the heuristic catches.
- **Phase 4 deploy fails or `verify-deploy.sh` goes red**: the source store is the record of
  truth; re-run the deploy after resolving the gate finding. If the finding is unrelated to this
  task's files, check whether a concurrent task's in-flight edit is responsible before treating it
  as a regression of this work.
- Before any intentional rollback that would discard uncommitted work, snapshot first with
  `bash .claude/scripts/git-snapshot.sh 464`.
