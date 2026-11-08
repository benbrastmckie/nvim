# Implementation Plan: Task #420

- **Task**: 420 - Surface a plan-size versus per-run cycle-budget mismatch at plan time or at admission
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None (sequenced after the concurrent-gate-coordination task for file territory only, not a blocking dependency edge)
- **Research Inputs**: specs/420_warn_plan_size_exceeds_cycle_budget/reports/01_plan-size-cycle-budget-warning.md
- **Artifacts**: plans/01_plan-size-cycle-budget-warning.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-plan.sh` knows the per-run shared cycle budget and never reads plan size;
nothing in the engine compares the two, so an operator learns a plan will not finish in one
invocation only by exhausting the budget. This plan adds a purely additive, advisory
`cycle_budget_advisory` field to the per-task dispatch row at admission time, computed from the
plan file's own phase headings against the shared batch cycle pool, with a mode-aware threshold
drawn from the measured phases-per-cycle distribution in the research report. Done means: the
notice fires for a plan materially exceeding the remaining budget and not otherwise, the dispatch
is provably unchanged when it fires, both documentation homes describe it, and the full gate set
passes against an explicit source-store TARGET.

### Research Integration

The research report settled every open design question; this plan executes its recommendations
rather than re-deriving them. The load-bearing findings carried forward:

- **The gap**: `grep -c phases_total orchestrate-cycle-plan.sh` returns 0 (re-verified at plan
  authoring time against the source store). The file's only phase-accounting read is
  `phases_completed` from a handoff, inside the hard-mode-only H1 block.
- **Budget-remaining is a shared batch-wide pool**, not a per-task counter: the blocking
  eligibility gate tests `sum(.cycle_counts[])` against `.batch_cycle_budget`
  (`= ntasks * per_task_max_cycles`, 5 base / 13 hard). The advisory must read the same two
  values, or it would disagree with the mechanism that actually enforces the budget.
- **Admission time is the sole correct site.** The budget half of the comparison does not exist
  until an invocation chooses its mode, so a plan-time notice would necessarily be mode-blind.
  Admission runs before every dispatch of every cycle, including the first after planning, so it
  is also provably early.
- **Threshold `remaining_phases > remaining_cycles * K`, `K=2` base / `K=1` hard**, chosen from
  the report's measured distribution: hard mode's observed ratio is 1:1 with zero deviation
  across 15 consecutive cycles (task 328, a 20-phase plan), so no slack is justified; base mode
  is right-skewed (117 of 127 sampled tasks finished a whole plan in one implement dispatch, at
  totals up to 10), so `K=1` would false-positive on ordinary plans while `K=2` lands exactly on
  the boundary the data supports.
- **Shape precedent**: `orchestrate-batch-admit.sh`'s `dirty_scope_advisory` — a fragment merged
  onto every verdict, "Never changes decision, defer_reason, or exit code — purely
  informational", paired with a human-readable string. This is a closer precedent than `--gate`,
  which only writes an agent-facing hint into the dispatch file.
- **`phases_total == 0` pass-through**: mirror `skill_gate_completion_claim`'s Case 3, which falls
  back rather than asserting anything when the count is absent or malformed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Compute `phases_total` and `phases_remaining` for every implement-phase dispatch candidate from
  the task's latest plan file, reusing the existing `lib/phase-heading-patterns.sh` grammar and
  its mandatory whole-file conformance gate.
- Compare that against the remaining shared batch cycle pool with a mode-aware multiplier, and
  attach a `cycle_budget_advisory` object to the candidate's dispatch row when the threshold
  trips, identically in the dry-run and live paths.
- Keep the signal strictly advisory: never alter `dispatch`/`deferred`/`blocked`/`stop`, never
  change a status, never change an exit code.
- Pair the machine-readable field with a human-readable stderr line naming the concrete
  consequence and the two already-sanctioned remedies (re-invoke `/orchestrate`; consider
  division for a plan materially larger than one run's budget).
- Pin the behavior with fixtures, including the non-interference property and both the
  originating shape and its real-history counter-case.
- Document the notice in the two named homes.

**Non-Goals**:

- Changing `MAX_CYCLES`, the shared-pool arithmetic, the per-task contribution, or the blocking
  eligibility gate in any way.
- Adding a budget-override flag. `docs/architecture/orchestrate-state-machine.md` documents the
  absence of one as deliberate; the notice must not propose one.
- Adding a plan-time (planner-side) emission site. Settled against by the research; see
  Decisions.
- Making the notice claim impossibility. It is a heuristic signal about likely non-completion in
  one invocation.
- Blocking, deferring, failing, or downgrading anything on the basis of this signal.
- Touching any section of `context/patterns/batch-orchestration-guardrails.md` outside its
  admission-layer material (per this task's sequencing note).
- Fixing the known-unrelated pre-existing gate failures named in the task description (Gate 3
  lean4 doc-lint index.json entry; Gate 20 eager-load budget; Gate 8 suites
  `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh`, `test-guard-git-push.sh`).

## Decisions

Recorded here because they are ordinary planning judgment calls the research left to this phase,
not research questions:

1. **Both threshold operands come from the plan file, not the handoff.** `phases_total` and
   `phases_done` are both derived from the latest plan file's `### Phase N:` headings
   (`PHASE_HEADING_ERE` for total, `PHASE_HEADING_DONE_ERE` for done), with
   `has_nonconforming_phase_headings` run over the whole file first. Rationale: the plan file is
   the only source that exists before a task's first dispatch, when the notice is most valuable
   (a handoff exists only after a dispatch has already run); and the plan is already the
   authoritative phase-completion signal for all three existing accounting consumers. The
   rejected alternative — preferring the handoff's `phases_completed` when present — would make
   the advisory's operand disagree with the plan-derived operand H1 itself uses, and would
   require this advisory to re-decide the marker/handoff mismatch question H1 already owns.
2. **An inconclusive heading scan suppresses the notice; it never blocks.** When
   `has_nonconforming_phase_headings` hits, no advisory is emitted for that task. The blocking
   response to that condition is H1's, and only in hard mode; an advisory must not acquire a
   blocking posture by a side door.
3. **The stderr line is emitted on every cycle the condition holds, not deduplicated per run.**
   The remaining-budget operand shrinks monotonically within a run, so each emission carries
   different numbers and is informative rather than duplicate output. The "stated once, early"
   requirement is satisfied by its guaranteed presence on the run's first cycle. The rejected
   alternative — a once-per-task-per-run dedup flag in the multi-task state file — adds
   persistence state that `--dry-run` never writes, which would make the human-facing half
   behave differently under the dry-run path the test suite overwhelmingly uses (92 of 155
   `run_sut` calls), i.e. buy tidiness at the cost of testability.
4. **Only implement-phase candidates are considered.** A research- or plan-phase candidate has no
   plan size to measure (and in the `plan` case is about to produce the plan). Those candidates
   still draw from the pool, which is reflected in the remaining-cycles operand, but they receive
   no advisory of their own.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widening the H1 block's `hard_mode` guard accidentally changes hard-mode dispatch behavior rather than only adding a read | H | M | Do not widen the H1 loop guard at all. Add a separate sibling loop, and make only the `phase-heading-patterns.sh` sourcing unconditional (it defines functions and variables and has no side effect). Every existing hard-mode-only side effect (disputed-heading downgrade, marker/handoff mismatch block) stays under its existing gate, untouched. Phase 1 verification asserts the hard-mode H1 fixtures (Group 9, Group 25) still pass unchanged |
| A dispatch-row consumer enumerates row keys exhaustively and breaks on a new one | H | L | The research flagged this as un-audited and deferred it here. Phase 2's Scope Hypothesis makes the audit an explicit confirmation step across `orchestrate-cycle-postflight.sh`, `skills/skill-orchestrate/SKILL.md`, and `orchestrate-build-dispatch.sh` before the field is added |
| The notice fires but subtly perturbs the dispatch (ordering, a changed `focus`, a shifted row) | H | L | Phase 3's byte-identity fixture diffs the whole emitted plan JSON with the advisory field stripped from both sides, against the same scenario with the notice suppressed. The research names this as the property most likely to regress |
| A future maintainer tightens `K` without re-consulting the measured distribution | M | M | Phase 4's documentation states the threshold with its source and sample size, and records that raw phase count is a weak predictor (multi-dispatch totals 4-8 overlap substantially with single-dispatch totals at the same sizes) |
| A concurrent sibling task is mid-edit on `context/patterns/batch-orchestration-guardrails.md`, and another declares a coarse scope covering `agent-system/extensions/core/scripts/` and `context/` wholesale | M | H | Per `context/contracts/territory.md`'s Cross-Task Territory section: re-read every target file immediately before editing it; stage and commit only this task's own hunks with an explicit file list, never a directory or glob add; never run `git-snapshot.sh` in its reverting default mode; treat a build failure outside this task's own file list as possibly a sibling's in-flight edit. Confine the guardrails edit strictly to the admission-layer material |
| The advisory computation adds a plan-file read per implement candidate per cycle, slowing admission | L | L | One `ls` plus two `grep` passes per implement candidate per cycle, on files the H1 path already reads in hard mode. No mitigation needed beyond not introducing a second redundant read |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Compute the plan-size versus remaining-budget signal [COMPLETED]

**Goal**: `orchestrate-cycle-plan.sh` computes, for every implement-phase dispatch candidate, the
plan-derived remaining phase count, the remaining shared pool cycles, and the mode-aware
threshold verdict — and emits the human-readable stderr line. No dispatch-row change yet.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` immediately before
  editing (concurrent siblings declare overlapping scope).
- [x] Make the `. "$SCRIPT_DIR/lib/phase-heading-patterns.sh"` sourcing unconditional, replacing
  the `if [ "$hard_mode" = "true" ]` wrapper that currently guards it. Leave the H1 loop's own
  `[ "$hard_mode" != "true" ] && continue` guard and every hard-mode-only side effect inside that
  loop exactly as they are.
- [x] Add a new, clearly commented sibling block immediately AFTER the loop that builds
  `probed_dispatch_post_h1` and BEFORE the `if [ "$dry_run" = "true" ]` fork. Iterating
  `probed_dispatch_post_h1` (not `probed_dispatch`) is deliberate: an H1-refused candidate is
  already blocked and must receive no advisory.
- [x] In that block, for each candidate with `effective_group[$t] == "implement"`: resolve the
  latest plan file by the same chain the H1 block uses (`task_lookup_dir` then
  `ls -1 "${task_dir_abs}/plans/"*.md | sort -V | tail -1`). Skip the candidate when the project
  name is empty, no plan file resolves, or the resolved path is not a regular file.
- [x] Run `has_nonconforming_phase_headings` over the whole plan file BEFORE any filtered scan.
  On a hit, call `warn_nonconforming` and skip this candidate with no advisory (Decision 2). This
  ordering obligation is the one `plan-format.md` names as structurally unreachable if checked
  on the filtered result instead.
- [x] Count `adv_phases_total` with `PHASE_HEADING_ERE` and `adv_phases_done` with
  `PHASE_HEADING_DONE_ERE`; compute `adv_phases_remaining = total - done`, clamped at a floor of
  0. Skip the candidate with no advisory when `adv_phases_total` is 0 or non-numeric (the
  `skill_gate_completion_claim` Case 3 pass-through posture), and when `adv_phases_remaining` is
  0.
- [x] Compute `adv_remaining_cycles` as `_pool_budget - _pool_used`, re-read via the same two
  `mt_get` expressions the eligibility gate uses (`'[.cycle_counts[]? // 0] | add // 0'` and
  `'.batch_cycle_budget // 0'`), clamped at a floor of 0. Do not substitute a per-task
  subtraction.
- [x] Apply the mode-aware threshold: `K=1` when `hard_mode == "true"`, else `K=2`; fire when
  `adv_phases_remaining > adv_remaining_cycles * K`.
- [x] On a fire, populate an associative array keyed by task number with the advisory's component
  values (`phases_total`, `phases_remaining`, `remaining_cycles`, `mode`, `message`), and echo a
  `[orchestrate]`-prefixed line to stderr naming the numbers, the concrete consequence (the plan
  is unlikely to finish in this invocation and the task will come to rest blocked for the
  remainder of the run), and the two sanctioned remedies (re-invoke `/orchestrate` to continue in
  a fresh run; consider dividing a plan materially larger than one run's budget). The message
  must not propose a budget-override flag and must not claim impossibility.
- [x] Confirm no existing control flow was altered: the block must contain no `continue` that
  skips subsequent per-candidate work, no `out_blocked_rows` / `out_deferred_rows` append, and no
  mutation of `eligible_tasks`, `probed_dispatch_post_h1`, `cycle_counts`, or any status.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Three claims to confirm at implementation time rather than trust. (a) The
threshold multipliers `K=2` (base) / `K=1` (hard) and the distribution figures justifying them are
CARRIED from `specs/420_warn_plan_size_exceeds_cycle_budget/reports/01_plan-size-cycle-budget-warning.md`
(Recommendations item 3 and the Measured Evidence table); re-check the two boundary arithmetic
cases directly — `11 > 5*2` must be true and `10 > 5*2` must be false — rather than re-deriving
the distribution. (b) `grep -c phases_total` over this script returning 0, and the
`phase-heading-patterns.sh` sourcing being hard-mode-gated, were both verified at plan-authoring
time against the source store; re-confirm both by grep immediately before editing, since a
concurrent sibling declares a coarse scope covering this directory. (c) The insertion point is
identified structurally (after the `probed_dispatch_post_h1` build loop, before the `dry_run`
fork), not by line number; locate it by those two anchors.

**Tier Justification**: A single-file change to one script adding an isolated read-only
computation block with no signature or output-shape change; covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-force-phases.sh,test-gate-out-self-attribution.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deploy-caller-wrap.sh,test-lint-json-channel-discipline.sh,test-mint-dispatch-seq.sh,test-orchestrate-batch-gate.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-churn.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-record-decision.sh,test-orchestrate-triage-classify.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh`
(the verbatim `suite_selection_select` output for this phase's one path).

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - unconditional
  `phase-heading-patterns.sh` sourcing; new advisory-computation block between the
  `probed_dispatch_post_h1` build loop and the dry-run fork

**Verification**:

- [x] `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` is clean.
- [x] `shellcheck` on the file reports no new findings relative to its pre-edit baseline (capture
  the baseline before editing).
- [x] The narrowed suite set named in Tier Justification passes, with
  `test-orchestrate-cycle-plan.sh` green — in particular its existing Group 9 (H1 nonconforming /
  mismatch / dispatch / fallthrough / dry-run) and Group 25 (hard-mode H1) fixtures, which prove
  the unconditional sourcing did not disturb hard-mode H1 behavior.
- [x] A hand-run fixture confirms the stderr line appears for a seeded implement candidate with
  an 11-phase plan at phase 0 against a fresh base-mode budget, and does not appear for the same
  task with a 2-phase plan.

---

### Phase 2: Thread `cycle_budget_advisory` onto both dispatch-row sites [COMPLETED]

**Goal**: The advisory is carried as a purely additive `cycle_budget_advisory` object on the
per-task dispatch row, present with identical content in the dry-run and live paths, and absent
entirely when the threshold does not fire.

**Tasks**:

- [x] Re-read `orchestrate-cycle-plan.sh` immediately before editing.
- [x] Audit every consumer of the dispatch row for exhaustive key enumeration BEFORE adding the
  field: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, and
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`. Grep each for
  `to_entries`, `keys`, `with_entries`, and any fixed-field destructuring of a `.dispatch[]`
  element. Record the audit result in the phase's progress notes. If a consumer does enumerate
  keys exhaustively, STOP and report rather than adding the field.
- [x] Add the field to the dry-run row construction (the `jq -n -c` call inside the
  `if [ "$dry_run" = "true" ]` block that currently emits
  `{task, phase, agent, model: null, dispatch_file: null, force, focus}`).
- [x] Add the field to the live row construction (the `jq -n -c` call at the end of the live
  per-task loop that emits the same seven keys with real `model`/`dispatch_file`).
- [x] Use one shared composition idiom at both sites so they cannot drift: build the advisory
  fragment as a jq object merged onto the base row, empty (`{}`) when this task has no advisory,
  so the key is entirely ABSENT rather than `null` in the non-firing case. This matches the
  `byte-identical when absent` convention the script's own header already states for
  `--compare`/`--gate`, and `dirty_scope_advisory`'s empty-fragment shape.
- [x] Confirm the field's content is identical between the two paths for the same scenario: the
  advisory depends only on the plan file, the mode, and the pool, none of which differ across the
  fork.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Two claims to confirm. (a) The dispatch row's key set is exactly
`{task, phase, agent, model, dispatch_file, force, focus}` at both construction sites, and there
are exactly two such sites (one in the dry-run block, one at the end of the live per-task loop) —
located structurally by their `out_dispatch_rows+=` appends, not by line number. (b) The consumer
list above is believed complete but was explicitly NOT audited by the research report (its Risks
section flags this as a plan-phase verification item); the audit task above is the confirmation,
and a fourth consumer discovered during it widens this phase's file list rather than being
silently absorbed.

**Tier Justification**: The dispatch row is a cross-file data contract read by
`orchestrate-cycle-postflight.sh`, `skill-orchestrate/SKILL.md`, and
`orchestrate-build-dispatch.sh`, so the covering check must reach those enumerated direct
dependents, not just the changed script; `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-force-phases.sh,test-gate-out-self-attribution.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deploy-caller-wrap.sh,test-lint-json-channel-discipline.sh,test-mint-dispatch-seq.sh,test-orchestrate-batch-gate.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-churn.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-record-decision.sh,test-orchestrate-triage-classify.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh`
(the verbatim `suite_selection_select` output for this phase's one path) covers all three,
including `test-orchestrate-cycle-postflight.sh` and `test-orchestrate-build-dispatch.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the additive
  `cycle_budget_advisory` fragment to both `out_dispatch_rows+=` constructions

**Verification**:

- [x] `bash -n` clean; `shellcheck` no new findings against the Phase 1 baseline.
- [x] The narrowed suite set above passes.
- [x] A hand-run dry-run invocation on the 11-phase fixture shows `.dispatch[0].cycle_budget_advisory`
  present with all five component fields; the same invocation on a 2-phase fixture shows
  `.dispatch[0] | has("cycle_budget_advisory")` is `false`.
- [x] The consumer audit is recorded, with the specific grep patterns run and their results.

---

### Phase 3: Fixtures pinning the behavior and the non-interference property [COMPLETED]

**Goal**: `test-orchestrate-cycle-plan.sh` gains a fixture group covering every case the task
description requires, including the non-interference property and both the originating shape and
its real-history counter-case.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
  immediately before editing.
- [x] Add a new test group following the file's established idiom: `write_state` heredoc,
  `reset_lock_dirs`, a seeded `.orchestrator-multi-state-<session>.json` carrying `cycle_counts`,
  a plan file written with `printf`/`cat` heredoc into `specs/{NNN}_{slug}/plans/01_*.md`, then
  `run_sut --session <s> --dry-run -- <task>` and `jqf` assertions.
- [x] **Fires**: an 11-phase plan at phase 0, base mode, fresh 5-cycle budget — asserts
  `.dispatch[] | select(.task == N) | .cycle_budget_advisory` is non-null. This is the fixture
  reproducing the originating shape.
- [x] **Does not fire (comfortably within)**: a 2-phase plan, base mode, fresh budget — asserts
  `has("cycle_budget_advisory")` is `false`.
- [x] **Does not fire (no plan)**: an implement candidate whose task directory has no `plans/`
  entry — asserts absence, and asserts the task still appears in `.dispatch` or `.blocked`
  exactly as it would without this feature.
- [x] **Does not fire (zero/absent phase count)**: a plan file containing no conforming
  `### Phase N:` heading at all — asserts absence. Add a second case whose plan has a
  non-conforming heading, asserting absence plus no blocked row attributable to the advisory.
- [x] **Mode-aware, different budgets**: the same plan and the same seeded `cycle_counts` run
  once without and once with `--hard`, asserting the two runs disagree on whether the advisory is
  present. Choose the phase count so the `K=2` base multiplier fires and the 13-cycle hard budget
  does not, so the assertion genuinely discriminates mode rather than restating the plan size.
- [x] **Counter-fixture from real history**: a plan at phase 10 of 11 (ten headings marked
  `[COMPLETED]`, one open) with budget remaining — asserts absence. This is the case that proves
  the heuristic is not merely flagging large plans unconditionally.
- [x] **Non-blocking / byte-identical dispatch**: run the firing scenario, capture the full
  emitted plan JSON, strip `cycle_budget_advisory` from every dispatch row with jq, and diff
  against the same scenario's full emitted JSON with the notice suppressed (suppress it by
  seeding a `cycle_counts` value that puts the same plan comfortably within budget while leaving
  every other input identical, or by an equivalent single-variable change). Assert the two
  stripped documents are identical, and that `.stop` and `.blocked` are identical between them.
  This is the property most likely to regress.
- [x] Confirm every assertion uses the suite's `common_test_pass` / `common_test_fail` helpers
  with `$LAST_STDOUT` quoted in the failure message, matching the file's convention.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts it adds exactly eight fixture cases across the seven
required categories. Confirm at implementation time by counting the `common_test_pass` call sites
added in the new group and mapping each to a named requirement from the task description's
VERIFICATION list; a category that turns out to need two cases (or one) adjusts the count, which
is expected, but no requirement may end with zero cases. Also confirm the claim that
`run_sut` defaults to no `--dry-run` and the flag must be passed explicitly — verified at plan
authoring time, where most but not all existing `run_sut` call sites pass it; re-check before
relying on it.

**Tier Justification**: A test-file-only change with no production-code surface, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-ledger-lib.sh,test-force-phases.sh,test-gate-out-self-attribution.sh,test-mint-dispatch-seq.sh,test-orchestrate-batch-gate.sh,test-orchestrate-churn.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-record-decision.sh,test-resume-scan-nonconformance.sh`
(the verbatim `suite_selection_select` output for this phase's one path).

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new fixture group
  for the cycle-budget advisory

**Verification**:

- [x] `bash -n` clean on the test file.
- [x] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes in
  full, with the new group's cases all reported pass and the suite's pre-existing case count
  undiminished.
- [x] The narrowed suite set above passes.
- [x] Each of the task description's four named fixture requirements plus the mode-awareness and
  zero/absent requirements maps to at least one passing case, listed explicitly in the phase's
  progress notes.

---

### Phase 4: Document the notice in both named homes [COMPLETED]

**Goal**: The advisory is described where the budget is already documented and where this class of
admission guardrail is already catalogued, with its threshold stated alongside the measured
source and sample size.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  immediately before editing.
- [x] Add a subsection to that file's `## MAX_CYCLES Enforcement` section, after the
  `### Infra-Failure vs. Work-Cycle Discrimination` subsection and before the section's closing
  `---`. State: the notice is advisory and never blocks; it fires at admission for implement-phase
  candidates only; both operands and where they come from (plan-file headings; the shared pool,
  `batch_cycle_budget - sum(cycle_counts)`); the mode-aware threshold
  `remaining_phases > remaining_cycles * K` with `K=2` base / `K=1` hard; the measured
  justification with its sample size (127 tasks sampled, 117 completing a whole plan in one
  implement dispatch at totals up to 10; a 20-phase plan advancing exactly +1 across 15
  consecutive hard-mode cycles); that raw phase count is a weak predictor, so the signal is a
  heuristic about likely non-completion in one invocation and never a proof of impossibility; and
  the two sanctioned remedies, with an explicit note that no budget-override flag is proposed
  because its absence is deliberate.
- [x] While in that section, make the shared-pool framing explicit in the prose rather than only
  in the code block, per the research report's Context Extension Recommendation — the surrounding
  prose currently describes `cycle_count` in largely single-task terms.
- [x] Re-read `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  immediately before editing. A concurrent sibling task also edits this file.
- [x] Add one row to that file's `### Classification Table` (inside
  `## Blocking vs. Advisory: The Criterion`) classifying the plan-size/cycle-budget notice as
  ADVISORY, with the reasoning tied to the file's own two-condition criterion: the signal is a
  derived heuristic rather than a hard structural fact (the same failure mode the existing
  heuristic-drift-percentage row records), and the harm of a false positive is recoverable by the
  operator simply continuing. Follow the `dirty_scope_advisory` row's phrasing conventions.
- [x] Touch no other section of the guardrails file. Confine the edit to the admission-layer
  material named above.
- [x] Verify no task-number reference and no record-versioning language enters either file (both
  land under `agent-system/**`, where both are prohibited).

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts two specific insertion locations — a new subsection at
the end of `## MAX_CYCLES Enforcement` (before its closing `---`), and one new row in
`### Classification Table` under `## Blocking vs. Advisory: The Criterion`. Both were located by
section heading at plan-authoring time; re-locate them by heading, never by line number, since a
concurrent sibling declares a coarse scope covering this `context/` directory and may have
shifted line numbers. The measured figures quoted in the documentation are CARRIED from
`specs/420_warn_plan_size_exceeds_cycle_budget/reports/01_plan-size-cycle-budget-warning.md`'s
Measured Evidence table; quote them with the report's own sample sizes attached rather than
restating them as bare assertions.

**Tier Justification**: Both edits are confined to markdown prose with no compile or elaboration
surface, so the tier-table diff read-through applies; the covering checks are
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-gate-out-self-attribution.sh,test-handoff-reader-parity.sh,test-lint-postflight-boundary.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh,test-stall-reprompt-wiring.sh`
(the verbatim `suite_selection_select` output for this phase's two paths passed together) together
with `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
for the doc-lint and task-reference lint these source-store markdown edits are subject to (the
repository root is passed explicitly as TARGET because it holds both a deployed `.claude/` tree
and the `agent-system/extensions` source store).

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - new advisory
  subsection in `## MAX_CYCLES Enforcement`; shared-pool framing made explicit in that section's
  prose
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - one new
  ADVISORY row in `### Classification Table`

**Verification**:

- [x] Diff read-through confirms every changed hunk in both files lies entirely within prose, and
  that the guardrails edit touches only the classification-table row.
- [x] The narrowed suite set above passes.
- [x] `--only-gate 3,4` with the explicit repository-root TARGET passes, with neither gate
  reporting SKIP (a SKIP would mean nothing was checked).
- [x] `grep` over both files' diffs finds no task-number reference and no record-versioning
  language.

---

### Phase 5: Redeploy and full gate set [IN PROGRESS]

**Goal**: The source-store changes are deployed to the running `.claude/` tree and the complete
gate set passes against an explicit source-store TARGET.

**Tasks**:

- [ ] Confirm Phases 1-4 are committed and the working tree holds no uncommitted hunk belonging
  to this task.
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash
  tool's `timeout` parameter raised to 600000 per `context/patterns/external-process-wait.md`
  Rule 1. The dispatch context records this repository's deployed tree as already stale for the
  `core`, `lean`, and `nvim` extensions independently of this task, so the redeploy is required
  rather than optional.
- [ ] Run the complete gate set with an explicit TARGET:
  `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`.
  The bare, no-argument form is NOT acceptable here — it silently skips the source-store-only
  gates.
- [ ] Triage every failure against the known-unrelated list from the task description (Gate 3
  lean4 doc-lint missing `index.json` entry; Gate 20 eager-load budget over baseline; Gate 8
  suites `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh`, `test-guard-git-push.sh`). Do
  not fix those and do not attribute them to this work. Any OTHER failure is this task's and must
  be fixed forward.
- [ ] Confirm the deployed `.claude/scripts/orchestrate-cycle-plan.sh` carries the new block (the
  deploy actually propagated), and that no file under `.claude/**` was hand-authored at any point
  in this task.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The known-unrelated failure list is CARRIED verbatim from this task's own
dispatch description (its "Known-unrelated pre-existing failures" paragraph). Confirm each named
failure is genuinely pre-existing by checking it reproduces independently of this task's changes
before dismissing it; a failure on that list that does NOT reproduce independently is this task's
and must be fixed.

**Files to modify**:

- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree, an
  implicit scope claim over that whole tree
- No source-store file is edited in this phase; any edit here is a fix-forward response to a gate
  failure attributable to this task, which widens this list rather than being absorbed silently

**Verification**:

- [ ] `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully.
- [ ] `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
  — the complete gate set, with the explicit TARGET — passes, modulo only the known-unrelated
  failures enumerated above, each confirmed to reproduce independently of this task's changes.
- [ ] `bash .claude/scripts/tests/run-all.sh` reports `test-orchestrate-cycle-plan.sh` green in
  the deployed tree.
- [ ] `git status --short` shows no stray modification under `.claude/**` beyond what the deploy
  itself regenerated.

---

## Testing & Validation

- [ ] The advisory fires for an 11-phase plan at phase 0 against a fresh base-mode 5-cycle budget
  (the originating shape).
- [ ] The advisory does not fire for a plan comfortably within the remaining budget.
- [ ] The advisory does not fire for a task with no plan file.
- [ ] The advisory does not fire when the conforming phase count is zero, or when the heading scan
  is inconclusive.
- [ ] The advisory is mode-aware: the same plan and the same seeded `cycle_counts` yield different
  verdicts under base and `--hard`.
- [ ] The advisory does not fire for a plan at phase 10 of 11 with budget remaining (the
  real-history counter-case).
- [ ] With the advisory firing, the emitted plan JSON is identical to the suppressed-notice run
  once the advisory field is stripped from both, including `.stop` and `.blocked`.
- [ ] The threshold is stated in documentation with its measured source and sample size, not
  asserted.
- [ ] The complete gate set passes with an explicit source-store TARGET, modulo only the
  known-unrelated pre-existing failures.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - advisory computation block
  and the additive `cycle_budget_advisory` field on both dispatch-row construction sites
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new fixture group
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - advisory
  subsection in `## MAX_CYCLES Enforcement`, plus explicit shared-pool prose framing
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - one new
  ADVISORY classification-table row
- The regenerated deployed `.claude/` tree
- `specs/420_warn_plan_size_exceeds_cycle_budget/summaries/01_*-summary.md` at completion

## Rollback/Contingency

Each phase commits independently, so reverting is a matter of `git revert` on the specific
phase commit(s) — no working-tree discard is required and none should be used. Because concurrent
sibling tasks are live on this same working tree, do NOT run `git-snapshot.sh` in its reverting
default mode at any point in this task; if a defensive checkpoint is wanted before Phase 1 or
Phase 2, use `bash .claude/scripts/git-snapshot.sh --no-revert 420`, which is durable without
reverting the tree. Should a genuine rollback become necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag.

The change is additive by construction: the advisory is a new optional key and a new stderr line,
with no existing control flow altered. Reverting Phase 2 alone restores the exact pre-change
dispatch-row shape while leaving the computation inert; reverting Phase 1 as well removes the
computation entirely. The one non-additive edit is making the `phase-heading-patterns.sh` sourcing
unconditional, which is independently revertible to its `hard_mode`-gated form.
