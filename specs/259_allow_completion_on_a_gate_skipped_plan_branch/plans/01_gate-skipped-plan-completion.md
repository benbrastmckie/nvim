# Implementation Plan: Task #259

- **Task**: 259 - Allow completion when a plan branch deliberately skips phases, and stop the identical-redispatch loop
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/259_allow_completion_on_a_gate_skipped_plan_branch/reports/01_gate-skipped-plan-completion.md
- **Artifacts**: plans/01_gate-skipped-plan-completion.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent defects produced one observed deadlock: a completion-claim gate that refuses on
the agent's self-reported phase counters without ever consulting the plan's own markers, and a
convergence guard that cannot see a dispatch-refuse-redispatch loop because each cycle *does*
dispatch. Fix 1 widens the corroboration trigger in `orchestrate-cycle-postflight.sh` so a plan
whose gate-skipped phases carry `[COMPLETED WITH EXCLUSIONS]` can supply the completion evidence
the handoff understated — with no new marker, no new handoff field, and no new gate case. Fix 2
makes the convergence guard count *identical* dispatches, not merely absent ones, which is the
general protection against any refuse-redispatch loop. A third, purely documentary strand tells
the planner and implementation agents that a decision-gate/contingency-branch plan shape is what
`[COMPLETED WITH EXCLUSIONS]` is for.

### Research Integration

The research report changes three things from the dispatch's own framing and this plan follows
the report, not the dispatch, on each:

1. **The Gap 2 edit site is `scripts/orchestrate-cycle-postflight.sh:478-486`, not
   `scripts/skill-base.sh`.** `skill_gate_completion_claim` is a documented pure decision function
   ("never reads a plan file"); the corroboration trigger lives entirely in its caller, hardcoded
   to `phases_total -eq 0`. `skill-base.sh` needs only a **non-functional comment correction** to
   its `skill_corroborate_phase_counts` D3/D4 header blocks, which assert as invariants the very
   things this change makes false ("sole consumer is Case 3", "Case 1 is UNREACHABLE from any
   caller of this function by construction").
2. **A naive widening introduces a false-positive defect record.** The existing Case-3 call site
   overwrites `phases_completed`/`phases_total`/`plan_markers_verified` unconditionally, which is
   safe only because it runs when `phases_total` is already `0`. `skill_corroborate_phase_counts`
   returns `phases_completed=0 phases_total=0` on *every* non-corroborating branch, so reusing
   that unconditional overwrite under a widened trigger would zero a genuinely-nonzero
   `phases_total`, silently reclassifying an ordinary Case 1 refusal (explicitly documented as
   NOT a defect) into a Case 3 refusal that records `META_MISSING_AFTER_NARRATION`. The overwrite
   must therefore be gated on `plan_markers_verified=true`, not merely on entering the widened
   branch.
3. **`docs/architecture/handoff-schema.md` must be edited regardless of any schema addition.** Its
   `plan_markers_verified` subsection states as settled fact that Case 1 "always REFUSES.
   `plan_markers_verified` is not consulted" — text that becomes false the moment Fix 1 lands.

Also carried over: `orchestrate-stage5-gates.sh` / `orchestrate-stage5-postflight.sh` are
confirmed dead code and must not be edited; `--phase-check=refuse` is confirmed never in force on
the `/orchestrate` path (both live sites hardcode `"warn"`), so no downstream second refusal can
undo this fix; and `scripts/lib/deploy-ledger-lib.sh`'s `sha256sum`-with-explicit-degrade idiom is
the precedent Fix 2's hashing reuses.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:

- A branched plan whose gate-skipped phases are closed as `[COMPLETED WITH EXCLUSIONS]` (with the
  required `#### Reasoned Exclusions` record) completes normally, with the completion evidence
  reaching the gate through `count_plan_phases` / `skill_corroborate_phase_counts` — no new field,
  no new marker, no new gate case.
- The gate's fail-closed posture is preserved exactly: a genuine shortfall whose plan also shows
  the phases open still refuses, and still refuses as Case 1 (not silently reclassified as Case 3).
- An agent cannot escape the gate by under-reporting `phases_total` against an incomplete plan.
- The convergence guard stops a run after N=2 consecutive *identical* dispatches for the same
  task/phase, capping any dispatch-refuse-redispatch loop at one wasted cycle, with `MAX_CYCLES`
  remaining as the outer bound behind it.
- A planner and an implementation agent can discover, from `plan-format.md` and
  `status-markers.md` alone, that a decision-gate/contingency-branch plan shape maps onto
  `[COMPLETED WITH EXCLUSIONS]`.

**Non-Goals**:

- **No new phase-heading marker.** `[SKIPPED]` / `[NOT APPLICABLE]` are dropped: the premise that
  no sanctioned marker exists is false, and `status-markers.md` already rejects a fourth
  semantically-overlapping marker by name (`[DESCOPED]`). No change to
  `scripts/lib/phase-heading-patterns.sh` or the plan-format lint.
- **No handoff-schema addition.** `phases_skipped` / `phase_accounting_note` are dropped. The
  research shows the existing mechanism suffices end to end; a second mechanism inside the
  documented "documented incompleteness that still counts as success" family is the drift
  `status-markers.md` and `anti-analysis.md` deliberately prevent. Only the schema *documentation*
  changes.
- **No `PHASE_ACCOUNTING_MISMATCH` defect class** (adjacent item (b), decided OUT — see Decisions).
- **No agent-body edits.** `planner-agent.md` and every other `agents/*.md` file belong to the
  sibling agent-contract task's declared `file_scope` this same cycle. All agent-facing guidance
  lands in `plan-format.md` / `status-markers.md` instead.
- **No edits to `orchestrate-stage5-gates.sh` / `orchestrate-stage5-postflight.sh`** (dead code).
- **No revert or weakening of the gate's recent tightening** (the loss of base mode's
  `phases_total == 0` blind allow stays).
- **No durable, cross-run persistence of the identical-dispatch streak.** Scoped to the run's
  ephemeral multi-state file, matching the existing per-run cycle-budget design.

## Decisions

- **Adjacent item (a) — DROPPED.** No new marker; no `phase-heading-patterns.sh` or lint change.
  This removes the largest risk item the earlier draft carried.
- **Adjacent item (b) — DECIDED OUT.** A `PHASE_ACCOUNTING_MISMATCH` class in
  `system-defect-record.sh`'s enum is not added. After Fix 1, the deadlock case resolves without
  producing any defect record at all, and Case 1 is explicitly documented as an ordinary refuse
  that is NOT a defect — so the proposed class would have no writer. Adding it would be enum
  growth for its own sake, and would needlessly put this task into the same closed enum the
  sibling recovery-decline-attribution task is contemplating. The incident's misfiled
  `ARTIFACTS_SHAPE_MISMATCH` record is left as-is (historical).
- **Fix 2 halts the offending task, not the whole run.** On tripping, the task is excluded from
  the rest of the run via a `blocked[]` row and a per-run halted marker; sibling tasks making
  genuine progress continue. If that leaves nothing dispatched, the existing
  empty-`probed_dispatch` guard takes over unchanged — the two guards compose rather than compete.
- **Fix 2 detects post-build and backs out inline.** The dispatch file's content is not knowable
  before `orchestrate-build-dispatch.sh` writes it, so the check necessarily runs after the build,
  after the lock acquire and preflight write. Back-out is written inline (lock release, prior
  status triple restore via `state-write.sh`, delete the just-written `.dispatch/{seq}.md`, skip
  the budget charge / `--flush-seq` / `pending_dispatch` record). `orchestrate-unwind-dispatch.sh`
  is deliberately NOT invoked: its own header declares it a by-hand tool that "is never invoked
  automatically by the orchestrate loop."
- **N = 2.** The first repeat is tolerated (it may be a legitimate retry after a transient); the
  second stops the run for that task. This caps the observed incident at one wasted cycle.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer follows the dispatch's File Scope Note and edits `skill_gate_completion_claim` itself, breaching its "never reads a plan file" contract and duplicating tested corroboration logic | H | M | Phase 3 names the edit site explicitly and restricts `skill-base.sh` to a comment-only change; Phase 3's verification asserts `skill_gate_completion_claim`'s body is byte-unchanged |
| Unconditional overwrite under the widened trigger zeroes a genuinely-nonzero `phases_total`, turning ordinary Case 1 refusals into false-positive `META_MISSING_AFTER_NARRATION` defect records | H | H (if unguarded) | Phase 3 gates the three-variable overwrite on `plan_markers_verified=true`; Phase 4 arm (4) asserts the emitted *case label* (`COMPLETION-CLAIM GATE case 1/3`), not just the refuse boolean, and asserts no defect record is written |
| Fix 2 false-positives on a legitimately retried dispatch whose content varies somewhere the exclusion pattern misses | M | L | Phase 1 begins by enumerating every per-cycle-varying interpolation in `orchestrate-build-dispatch.sh` rather than assuming only the two Identity lines vary; the hash-normalizer strips exactly that enumerated set and the enumeration is recorded in a comment |
| Fix 2's back-out leaves a task in a wrong status or holding a lock | H | M | Phase 2 reuses the already-captured `_pd_prior_status`/`_pd_prior_last_updated`/`_pd_prior_session_id` pre-image and the sanctioned `state-write.sh` writer; a dedicated test asserts status, lock and `.dispatch/` state after a trip |
| Sibling task edits collide on the shared working tree this same cycle | M | M | Sibling's declared `file_scope` is agent bodies + two lint/validate scripts; this plan touches none of them. Re-read every file immediately before editing; stage only this task's own hunks; never a directory or glob `git add` |
| Widening the trigger makes an existing `test-orchestrate-cycle-postflight.sh` fixture take a new branch | M | M | Phase 3 runs the full existing suite before adding any new arm and treats any pre-existing-test change as a design error, never as a test to weaken |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 5 | -- |
| 2 | 2, 4, 6 | 1 (for 2), 3 (for 4 and 6) |
| 3 | 7 | 2, 4, 5, 6 |

Phases within the same wave have no ordering dependency on each other. A single implementation
agent executing them sequentially should prefer 1 -> 2 (Fix 2, committable green on its own and
independent of how Fix 1 resolves), then 3 -> 4, then 5 -> 6, then 7.

---

### Phase 1: Dispatch-content hashing and per-task identical-dispatch accounting [COMPLETED]

**Goal**: `orchestrate-cycle-plan.sh` computes a normalized content hash of each dispatch file it
builds and maintains a per-task consecutive-identical-dispatch streak in the run's multi-state
file. Log-only: no dispatch is blocked and no behavior changes. This phase is committable green on
its own and is a strict no-op for every existing test.

**Tasks**:

- [x] Enumerate every per-cycle-varying interpolation in `scripts/orchestrate-build-dispatch.sh`'s
      dispatch-file writer block (currently ~lines 387-430+). Confirm by reading the writer, not by
      assumption, that within one `/orchestrate` run only `- dispatch_seq: N` and
      `- dispatch_start_ts: N` vary for an otherwise-unchanged task/phase. Record the enumerated
      set in a comment at the normalizer. If any other varying line is found, add it to the
      normalizer's strip set and note it in the phase's Verification below. *(completed: confirmed
      by reading the writer end to end -- only those two lines vary; enumerated in a comment on
      `cycle_plan_dispatch_hash()`)*
- [x] Add a `cycle_plan_dispatch_hash <dispatch_file>` helper to `scripts/orchestrate-cycle-plan.sh`
      that strips the enumerated varying lines and emits a `sha256sum` digest. Reuse
      `scripts/lib/deploy-ledger-lib.sh`'s degrade idiom verbatim in spirit:
      `command -v sha256sum >/dev/null 2>&1 || return 2`, surfaced by the caller as a **named
      stderr notice that disables the guard for this run**, never a silent skip and never a fatal.
      *(completed)*
- [x] Add three fields to the multi-state defaults block (alongside `.cycle_counts //= {}` /
      `.max_cycles_per_task //= {}`): `.last_dispatch_hash //= {}`, `.last_dispatch_phase //= {}`,
      `.identical_dispatch_streak //= {}`. All keyed by task number as strings, matching the
      existing per-task map convention. *(completed)*
- [x] In the live-only dispatch loop, immediately after `orchestrate-build-dispatch.sh` succeeds
      and `dispatch_file` is resolved (and BEFORE the budget-charge block), compute the hash and
      update the streak: if the hash and the phase both match this task's recorded values,
      `streak = streak + 1`; otherwise `streak = 1` and record the new hash/phase. *(completed)*
- [x] Emit one greppable stderr line per repeat, e.g.
      `[orchestrate] IDENTICAL DISPATCH: task #<t> <phase> dispatch content matches the previous
      one (streak=<n>) -- ...`. Do not emit anything on a streak of 1. *(completed)*
- [x] Add test coverage to `scripts/tests/test-orchestrate-cycle-plan.sh`: (i) the normalizer
      yields the same digest for two dispatch files differing only in the enumerated varying lines
      and a different digest when any other line differs; (ii) the streak increments across two
      identical live compositions and resets on a differing one; (iii) the `sha256sum`-absent
      degrade path emits the named notice and leaves every dispatch decision unchanged.
      *(completed: Group 27 Cases A-E in test-orchestrate-cycle-plan.sh)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that only two lines (`- dispatch_seq:` and
`- dispatch_start_ts:`) vary per cycle for an otherwise-unchanged task/phase within one run. Confirm
at implementation time by reading `orchestrate-build-dispatch.sh`'s writer block end to end and by
diffing two real dispatch files for the same task/phase (`.dispatch/6.md` vs `.dispatch/7.md` shape
from the incident); widen the strip set if the reading contradicts the hypothesis.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - hash helper, three multi-state
  fields, post-build streak accounting, log-only notice
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - normalizer, streak
  and degrade-path cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes, with the
  new cases present and green and every pre-existing case unchanged.
- A `--dry-run` composition produces byte-identical output to before this phase (the guard lives
  entirely in the live-only half).
- The comment at the normalizer names the enumerated varying-line set explicitly.

---

### Phase 2: Halt the run for a task after N=2 consecutive identical dispatches [COMPLETED]

**Goal**: When the streak from Phase 1 reaches 2, the dispatch is backed out rather than issued,
the task is excluded from the remainder of the run with a `blocked[]` row, and the run stops if
nothing else remains to dispatch. This is verification arm (5).

**Tasks**:

- [x] Add `.identical_dispatch_halted //= []` to the multi-state defaults block. *(completed)*
- [x] At the Phase 1 accounting point, when `streak >= 2`: skip the dispatch row entirely and back
      out the side effects already taken for this task this cycle, in this order — (1) delete the
      just-written `.dispatch/{seq}.md`; (2) restore `status`/`last_updated`/`session_id` from the
      already-in-scope `_pd_prior_status` / `_pd_prior_last_updated` / `_pd_prior_session_id`
      pre-image via `scripts/state-write.sh` (the sanctioned writer) with `--regen-todo`, skipping
      the restore when the pre-image triple is empty; (3) release the task lock via
      `task-lock.sh release <task> <session_id>`. Do NOT invoke
      `orchestrate-unwind-dispatch.sh` — it is by-hand-only by its own contract. *(completed)*
- [x] Do not charge the per-task cycle budget, do not call
      `orchestrate-loop-guard-init.sh --flush-seq`, and do not record a `pending_dispatch` for a
      backed-out dispatch. *(completed: the halt branch `continue`s before that block is ever
      reached)*
- [x] Append the task to `.identical_dispatch_halted` and emit an `out_blocked_rows` entry with a
      reason naming the guard and the streak. *(completed)*
- [x] Exclude any task in `.identical_dispatch_halted` from the eligibility/candidate pass at the
      top of the composition for the rest of the run, emitting the same `blocked[]` reason each
      subsequent cycle so the exclusion is visible rather than silent. *(completed)*
- [x] Confirm the existing empty-`probed_dispatch` convergence guard still fires normally when the
      halt leaves nothing to dispatch (the two guards must compose, not shadow each other).
      *(completed: the halted-set exclusion produces an empty `eligible_tasks`/`probed_dispatch`
      exactly as any other blocked-out candidate would, so the pre-existing guard at its existing
      call site is reached unmodified — no new interaction to add)*
- [x] Add test coverage to `scripts/tests/test-orchestrate-cycle-plan.sh`: a task whose dispatch
      content repeats twice is halted on the second repeat; after the halt its state.json status,
      `last_updated` and `session_id` match the pre-dispatch pre-image, the lock is released, the
      `.dispatch/{seq}.md` file is gone, the durable `dispatch_seq_counter` was not advanced, and
      the per-task cycle budget was not charged; a subsequent cycle emits a `blocked[]` row for it
      and dispatches nothing for that task. *(completed: Group 28 in test-orchestrate-cycle-plan.sh)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - halt branch, inline back-out,
  halted-set exclusion in the eligibility pass
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - arm (5) case and
  the back-out assertions

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes,
  including the new halt/back-out case and every pre-existing case.
- Verification arm (5): the same dispatch fired twice with identical content stops the run for that
  task.
- A non-repeating multi-task composition is unaffected: dispatch rows, deferred rows and blocked
  rows are byte-identical to pre-change output.

---

### Phase 3: Widen the corroboration trigger to the Case 1 shape [COMPLETED]

**Goal**: `orchestrate-cycle-postflight.sh` consults the plan's own phase markers whenever a
dispatch reports `implemented`, not only when `phases_total == 0` — while leaving the handoff's
original counters untouched unless corroboration actually succeeded. This is the whole of Fix 1's
executable surface.

**Tasks**:

- [x] Re-read `scripts/orchestrate-cycle-postflight.sh`'s handoff-present branch (the corroboration
      block currently at ~lines 478-486) immediately before editing — a sibling task is scheduled
      on this same tree this cycle. *(completed)*
- [x] Change the trigger precondition from
      `[ "$dispatch_status" = "implemented" ] && [ "$phases_total" -eq 0 ]` to
      `[ "$dispatch_status" = "implemented" ]` alone, so both the Case 3 shape and the Case 1 shape
      reach `skill_corroborate_phase_counts`. *(completed)*
- [x] **Gate the three-variable overwrite on corroboration succeeding.** Parse `cpc_line` into
      locals first, then assign `phases_completed` / `phases_total` / `plan_markers_verified` only
      when the parsed `plan_markers_verified` is exactly `true`. On any non-corroborating result
      leave all three at their handoff-derived values. Record the reason in a comment: the function
      returns `phases_completed=0 phases_total=0` on every non-corroborating branch, so an
      unconditional overwrite would zero a genuinely-nonzero `phases_total`, flip an ordinary Case 1
      refusal into a Case 3 refusal, and trip the caller's `META_MISSING_AFTER_NARRATION` recorder
      at ~lines 803-812 with a false positive. *(completed)*
- [x] Update the block's own header comment (currently "matches skill_gate_completion_claim's own
      Case 3 precondition exactly") to describe the new two-shape trigger and the
      corroboration-gated overwrite. *(completed)*
- [x] Correct the now-stale invariant claims in `scripts/skill-base.sh`'s
      `skill_corroborate_phase_counts` header — **comment text only, no functional change**: the D3
      block's "This function's sole consumer is skill_gate_completion_claim's Case 3 above" and
      "each caller gates on it BEFORE invoking this function", and the D4 block's "Case 1 ... is
      UNREACHABLE from any caller of this function by construction". Replace with an accurate
      description of the two-shape trigger and of why a corroborated correction can now legitimately
      raise a Case 1 shape to Case 2, while a non-corroborating result can never lower anything.
      *(completed)*
- [x] Leave `skill_gate_completion_claim`'s body byte-unchanged. Leave
      `orchestrate-stage5-gates.sh` and `orchestrate-stage5-postflight.sh` untouched (dead code).
      *(completed: verified via `git diff --stat` showing zero changes to both dead scripts, and a
      manual diff read confirming `skill_gate_completion_claim`'s body is comment-only-adjacent,
      not itself touched)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the corroboration block is at
`orchestrate-cycle-postflight.sh:478-486` and the defect-recording guard at ~803-812. Confirm by
re-reading both regions at implementation time; line numbers may have shifted.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - widened trigger,
  corroboration-gated overwrite, corrected block comment
- `agent-system/extensions/core/scripts/skill-base.sh` - D3/D4 header comment correction only

**Verification**:

- `git diff` on `skill-base.sh` shows comment-line changes only; `skill_gate_completion_claim`'s
  body is untouched.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`,
  `bash .../test-corroborate-phase-counts.sh` and `bash .../test-skill-base-lifecycle.sh` all pass
  with every pre-existing case unchanged. A pre-existing case that now takes a different branch is
  a design error to fix in the change, never a test to weaken.
- `git diff --stat` shows no change to `orchestrate-stage5-gates.sh` or
  `orchestrate-stage5-postflight.sh`.

---

### Phase 4: Verification arms (1)-(4) for the widened gate [NOT STARTED]

**Goal**: The four gate-side verification arms named in the task description are exercised by
tests, including the *case label* the gate emits — not merely the allow/refuse boolean.

**Tasks**:

- [ ] Arm (1) — a linear plan with all phases `[COMPLETED]` and a matching complete handoff: still
      ALLOWED, emitting `COMPLETION-CLAIM GATE case 2/3`, exactly as today.
- [ ] Arm (2) — a branched plan modeled on the incident: seven phases, three of them
      `[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions` table, against a handoff
      reporting `phases_completed=4 phases_total=7`. Assert ALLOWED, assert the
      `[UNVERIFIED PHASES CORROBORATED] ... 7/7 phases closed (COMPLETED or COMPLETED WITH
      EXCLUSIONS)` banner is emitted, and assert the count reaches 7/7 through
      `skill_corroborate_phase_counts` — not through any new field. Assert the `[phase-check]`
      warning still fires on the completing transition (it is `warn`, never `refuse`, on this path).
- [ ] Arm (3) — a bare shortfall: handoff `4/7` and the plan also showing only 4 phases closed.
      Assert REFUSED **and** that the emitted label is `COMPLETION-CLAIM GATE case 1/3`, that
      `phases_total` was not zeroed, and that **no** `META_MISSING_AFTER_NARRATION` defect record was
      written.
- [ ] Arm (4) — an agent under-reporting `phases_total` (e.g. `0/0`, or `7/0`) against an incomplete
      plan. Assert REFUSED, with the Case 3 label and the pre-existing defect-recording behavior
      unchanged from today.
- [ ] Place the plan-fixture arms in `scripts/tests/test-corroborate-phase-counts.sh` alongside its
      existing Fixture A-D style, and the caller-level arms (label assertion, defect-record
      assertion, `[phase-check]` assertion) in `scripts/tests/test-orchestrate-cycle-postflight.sh`.
      Reuse the `COMPLETION-CLAIM GATE case N/3` stderr-line assertion pattern
      `test-skill-base-lifecycle.sh` already uses.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts four new arms split across two suites. Confirm at
implementation time that `test-corroborate-phase-counts.sh`'s fixture harness can express the
caller-level assertions; if it cannot, the arm belongs wholly in
`test-orchestrate-cycle-postflight.sh` rather than being weakened to fit.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` - branched-plan and
  shortfall fixtures
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - case-label,
  defect-record and `[phase-check]` assertions

**Verification**:

- All four arms pass. Arm (2) demonstrably reaches 7/7 via the corroboration banner.
- Temporarily reverting Phase 3's overwrite gate (locally, not committed) makes arm (3) fail on the
  case label — proving the assertion is load-bearing rather than vacuous.

---

### Phase 5: Document the decision-gate to exclusion-marker mapping [NOT STARTED]

**Goal**: A planner or implementation agent reading `plan-format.md` or `status-markers.md` can
discover that a gate-skipped contingency branch is represented with `[COMPLETED WITH EXCLUSIONS]`.
This closes Gap 1, the gap the incident's agent actually fell into.

**Tasks**:

- [ ] Confirm the gap still holds: `grep -n -i "decision gate\|contingency branch\|gate-skipped"`
      over `context/formats/plan-format.md` and `context/standards/status-markers.md` returns
      nothing but the unrelated `## Rollback/Contingency` section heading.
- [ ] Add a subsection to `context/formats/plan-format.md` immediately after
      `## Reasoned Exclusions (format)` — e.g. `### Decision gates and contingency branches` —
      stating: a plan may and routinely should carry a decision gate; when the gate's criterion
      fails and the plan's contingency branch is taken instead, the phases the branch bypasses are
      closed as `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` table whose
      `Evidence` column cites the gate's own failing measurement. Include a compact worked example
      modeled on the observed seven-phase shape (gate phase `[COMPLETED]`, bypassed phases
      `[COMPLETED WITH EXCLUSIONS]`, contingency phase `[COMPLETED]`). State plainly that leaving
      the bypassed phases `[NOT STARTED]` is what deadlocks the completion gate, and that
      `[PARTIAL]` is wrong here because nothing is resumable.
- [ ] Add a cross-reference from `context/standards/status-markers.md`'s
      `[COMPLETED WITH EXCLUSIONS]` subsection — naturally placed beside the existing "Whole-phase
      exclusion is a valid, intended case" paragraph — pointing at the new `plan-format.md`
      subsection as the canonical worked example of the shape.
- [ ] Do not restate the five-condition admission test in `plan-format.md`; cross-reference it, so
      the two files cannot drift.
- [ ] Do not edit any file under `agents/` (sibling task territory this cycle).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/context/formats/plan-format.md` - new decision-gate subsection
- `agent-system/extensions/core/context/standards/status-markers.md` - cross-reference

**Verification**:

- The grep from the first task now returns the new subsection in both files.
- Every changed hunk is prose; no code, no regex, no lint rule touched.
- Cross-references resolve: the named `plan-format.md` heading exists and the named
  `status-markers.md` subsection exists.
- `bash agent-system/extensions/core/scripts/validate-artifact.sh` (or the repo's doc/link lint, if
  one covers these files) reports no new findings.

---

### Phase 6: Correct handoff-schema.md's Case 1 description [NOT STARTED]

**Goal**: `docs/architecture/handoff-schema.md` no longer asserts as fact behavior that Phase 3
changed.

**Tasks**:

- [ ] Rewrite the `plan_markers_verified` subsection's three-case list so Case 1 reads accurately:
      the gate itself still refuses unconditionally on `phases_total > 0 && phases_completed <
      phases_total`, but the orchestrator now corroborates the plan's markers *before* calling the
      gate and, when corroboration succeeds, supplies corrected counts that can move the call into
      Case 2. State explicitly that a non-corroborating plan leaves the handoff's counters untouched
      so the refusal remains a Case 1 refusal, and that this is the fail-closed guarantee.
- [ ] Add a one-line pointer to `plan-format.md`'s new decision-gate subsection as the plan-authoring
      side of the same mechanism.
- [ ] State that no handoff field was added: `phases_total` continues to mean "phases the handoff
      reports authored", and the evidence for a gate-skipped branch travels through the plan's own
      markers.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - `plan_markers_verified`
  subsection

**Verification**:

- The literal phrase "`plan_markers_verified` is not consulted" no longer appears attached to
  Case 1.
- The four quoted `COMPLETION-CLAIM GATE case N/3` log shapes listed in that section still match
  `skill-base.sh` verbatim (they are unchanged by this task — confirm by diffing the quoted strings
  against the source).
- Every changed hunk is prose.

---

### Phase 7: Full regression sweep and task wrap-up [NOT STARTED]

**Goal**: Every named test suite is green, all five verification arms are demonstrated, and the
final file scope is harvested.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`,
      `test-corroborate-phase-counts.sh`, `test-orchestrate-cycle-postflight.sh`,
      `test-orchestrate-cycle-plan.sh` and `test-orchestrate-context-growth.sh` (the latter exercises
      the cycle-plan -> build-dispatch -> cycle-postflight chain end to end and is the suite most
      likely to catch an unintended interaction).
- [ ] Walk the five verification arms explicitly and record the evidence for each: (1) linear plan
      allowed; (2) branched plan with `[COMPLETED WITH EXCLUSIONS]` allowed via 7/7 corroboration,
      with the `[phase-check]` warning still firing; (3) bare shortfall still refused as Case 1;
      (4) under-reported `phases_total` still refused; (5) identical dispatch fired twice stops the
      run.
- [ ] Confirm no test was weakened or deleted: `git diff` over `scripts/tests/` shows additions and
      no removed or relaxed assertion.
- [ ] Harvest the final `file_scope` from the actual diff and report it in the handoff's
      `modified_files`.
- [ ] Confirm no file under `agents/` was touched and that the two dead stage5 scripts are unchanged.

**Timing**: 1 hour

**Depends on**: 2, 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- None (verification phase); the task summary artifact is written at wrap-up.

**Verification**:

- All five named suites exit 0.
- Each of the five arms has recorded evidence (a quoted log line or a named passing test case).
- `git diff --stat` over the whole task matches the harvested `file_scope` exactly, with no stray
  file.

---

## Testing & Validation

- [ ] `test-skill-base-lifecycle.sh` passes with every pre-existing case unchanged.
- [ ] `test-corroborate-phase-counts.sh` passes, including the new branched-plan and shortfall
      fixtures.
- [ ] `test-orchestrate-cycle-postflight.sh` passes, including the case-label, defect-record and
      `[phase-check]` assertions.
- [ ] `test-orchestrate-cycle-plan.sh` passes, including the hash-normalizer, streak, degrade-path
      and halt/back-out cases.
- [ ] `test-orchestrate-context-growth.sh` passes (end-to-end chain regression).
- [ ] Arm (1): linear complete plan -> ALLOWED (case 2/3).
- [ ] Arm (2): branched plan, gate-skipped phases `[COMPLETED WITH EXCLUSIONS]` -> ALLOWED, count
      reaches 7/7 through corroboration, `[phase-check]` warning still fires.
- [ ] Arm (3): bare `4/7` shortfall with the plan also open -> REFUSED as case 1/3, no defect record.
- [ ] Arm (4): under-reported `phases_total` against an incomplete plan -> REFUSED.
- [ ] Arm (5): two consecutive identical dispatches -> convergence guard halts the task, back-out
      verified.
- [ ] No test weakened or deleted anywhere in the diff.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (Fix 2)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (Fix 1, Gap 2)
- `agent-system/extensions/core/scripts/skill-base.sh` (comment correction only)
- `agent-system/extensions/core/context/formats/plan-format.md` (Gap 1)
- `agent-system/extensions/core/context/standards/status-markers.md` (Gap 1 cross-reference)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (schema-doc correction)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh`
- `specs/259_allow_completion_on_a_gate_skipped_plan_branch/summaries/01_*-summary.md`

## Rollback/Contingency

Each phase commits independently and green, so rollback is per-phase `git revert` of that phase's
commit — no phase leaves the tree in a state another phase must complete. Fix 2 (Phases 1-2) and
Fix 1 (Phases 3-4) are fully independent: either can be reverted without touching the other.

Before any risky edit in Phases 1-3, take a non-reverting checkpoint with
`bash .claude/scripts/git-snapshot.sh 259 --no-revert`. Never the bare, reverting default form.

If Phase 2's inline back-out proves unreliable in testing, the fallback contingency is to ship
Phase 1's accounting and notice **without** the halt (log-only), close Phase 2 as
`[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record citing the failing test
evidence, and leave `MAX_CYCLES` as the sole outer bound — the loop remains capped, just less
tightly. This does not affect Fix 1.

If Phase 3's widened trigger turns out to change an existing postflight fixture's branch in a way
that cannot be reconciled without weakening a test, stop and report rather than relaxing the test:
that outcome would mean the widening has a reachable side effect this plan did not anticipate, and
it needs a decision, not a test edit.
