# Implementation Plan: Port single-task-only orchestrator features into the batch engine

- **Task**: 148 - Port hard-mode counters, loop guard and auxiliary dispatches into the batch engine as per-dispatch options
- **Status**: [NOT STARTED]
- **Effort**: 13.5 hours
- **Dependencies**: 143 (`orchestrate-cycle-postflight.sh`) — completed
- **Research Inputs**: specs/148_port_single_task_features_to_batch_engine/reports/01_port-single-task-features.md
- **Artifacts**: plans/01_port-single-task-features.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Stage A.5 of `specs/PATH.md` ("One engine, batch of one"): every capability that exists only in
`skill-orchestrate/SKILL.md`'s single-task Stages 1-8 must exist as a script or a per-row option
in the batch engine (`orchestrate-cycle-plan.sh` / `orchestrate-cycle-postflight.sh`) before the
successor deletion task can remove Stages 1-8. Item (1) TEAM is withdrawn by the dispatch
addendum (team mode was already deleted); items (2) HARD, (3) LOOP GUARD, (4) AUXILIARY
DISPATCHES and (5) single-task-through-the-batch-path stand in full. **Done** means: a single
task number routed through the batch engine behind a feature flag exhibits hard-mode churn /
three-strikes / burnout counting, a cumulative cycle budget honoring `--continue-budget`, and
blocker-escalation / drift-inspection dispatches — with Stages 1-8 left intact on disk and still
the default path.

All edits target the source store `agent-system/extensions/core/`. `.claude/**` is a disposable
deploy artifact and is never hand-authored (see `.claude/rules/source-store-deploy-boundary.md`).

### Research Integration

The research report established four facts this plan is built on, and this plan does not
re-derive them:

- `orchestrate-churn.sh` is a **pure gap**: `orchestrate-cycle-postflight.sh` has zero
  `hard_mode`/churn/burnout awareness today (grep-verified), so item (2) is new construction, not
  a partial port. The churn-state file is already task-directory-scoped, so it needs no
  session/task reconciliation of its own.
- The loop-guard counter is a **genuine reconciliation problem**: single-task's `cycle_count`
  lives in `${TASK_DIR}/.orchestrator-loop-guard` and is cumulative across `/orchestrate`
  invocations *by design* (protected by `test-session-runtime-files.sh` Case 3); multi-task's
  `cycle_count` lives in `specs/.orchestrator-multi-state-${session_id}.json`, a file minted fresh
  every invocation. Resolved by Decision 1 below.
- The auxiliary flows use **fixed agents** (`fork`, `reviser-agent`) chosen by the escalation
  logic, not by task type — structurally incompatible with the current dispatch-row schema, whose
  `phase` ∈ {research, plan, implement} and whose `agent` is task-type-routed through
  `orchestrate-build-dispatch.sh`. Resolved by Decision 2 below.
- `commands/orchestrate.md`'s STAGE 0 already contains the exact `len(TASK_NUMBERS) == 1` branch
  point item (5) needs; `SKILL.md`'s Stage 0 needs no change at all.

Only two test files extract sentinel-delimited bash regions out of `SKILL.md`'s Stage 2:
`test-loop-guard-budget-override.sh` and `test-loop-guard-staleness.sh`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` found. The governing sequencing document is `specs/PATH.md`, whose Stage A
table places this task at A.5, gating A.6 (delete the single-task engine).

## Decisions

These four decisions resolve the open questions the research report deliberately left to
planning. They are recorded here because implementation must not silently re-decide them.

### Decision 1 — Loop guard: cumulative per task, live in the multi-state file

The cumulative-across-invocations guarantee is **preserved**; the per-session freshness of
`MAX_CYCLES_MT` is **relaxed**. Rationale: the cumulative guarantee is an explicit, named,
test-protected invariant (`test-session-runtime-files.sh` Case 3; Stage 2's "Defect B" comment
states that resetting on `session_id` would let an operator silently bypass `MAX_CYCLES`), while
per-session freshness is protected by no test and is arguably the latent defect — today an
operator can re-run a stuck 5-task batch indefinitely. Routing a single task through the batch
path must not become that bypass.

Mechanism (one counter *value* per task, honored in one place):

- The **live** counter is `cycle_counts[task_number]` in
  `specs/.orchestrator-multi-state-${session_id}.json`, read and written only by
  `orchestrate-cycle-plan.sh`. The scalar `cycle_count`/`max_cycles` pair is replaced by this map
  plus `max_cycles_per_task[task_number]`.
- The **durable backing store** is the pre-existing, gitignored, reap-exempt
  `${TASK_DIR}/.orchestrator-loop-guard` file. On first sight of a task in an invocation,
  `cycle_counts[t]` is seeded from that file's `cycle_count`; at the end of every cycle the live
  value is flushed back to it. Nothing else about that file's schema changes, so
  `burnout_signals_this_session`, `dispatch_seq_counter` and `detected_defects` keep their
  existing home.
- `max_cycles` becomes **per task and mode-aware** — 13 under `--hard`, 5 otherwise — the
  single-task Stage 2 values, ported verbatim. The batch-wide `default_max_cycles = ntasks * 5`
  (capped 25) is retired; a batch now stops when *every* non-terminal task has exhausted its own
  budget, which reduces exactly to single-task Stage 2's refusal for a batch of one.
- `--continue-budget` is honored in **exactly one place**: `orchestrate-cycle-plan.sh`'s
  top-of-script budget guard, which archives the exhausted per-task guard file aside and resets
  that task's `cycle_count` to 0 in place, preserving `dispatch_seq_counter` and
  `detected_defects` — the existing `budget-continuation-override` behavior, moved.

Rejected alternative: accept the multi-state file's per-session behavior and document the
relaxation. Rejected because it converts a named invariant into a silent bypass reachable by
typing `/orchestrate N` twice.

### Decision 2 — Auxiliary dispatches: a sibling `aux_dispatch[]` array, never `dispatch[]`

`orchestrate-cycle-plan.sh`'s output JSON gains a **new top-level array** `aux_dispatch[]`
alongside `dispatch[]`. Rows are
`{task, kind, agent, model, dispatch_file, orchestrator_mode: false}` with
`kind ∈ {drift-inspection, blocker-research, plan-revision, divergence-audit}` and a **fixed**
`agent` chosen by the emitting logic (`fork`, `fork`, `reviser-agent`, and the task's own research
agent respectively) — never resolved through `command-route-agent.sh`.

Rationale: widening `dispatch[]`'s `phase` vocabulary would break the `--phase` contract of
`orchestrate-cycle-postflight.sh` (which also drives phase-count corroboration and the
artifact-round advance) and would risk the exact regression the dispatch's MUST NOT forbids —
silently routing an aux dispatch through task-type agent resolution. A sibling array leaves every
existing consumer of `dispatch[]` byte-identical.

Consequences, all deliberate:

- Aux rows get **no** `orchestrate-cycle-postflight.sh` call. Their effect is a written file or a
  revised plan, which the *next* cycle's ordinary status-derived dispatch picks up — matching the
  dispatch text's "rows the cycle-plan script emits on the next cycle".
- Aux dispatch files are written by a new, small `orchestrate-build-aux-dispatch.sh` that
  **never** calls `orchestrate-build-dispatch.sh`'s memory/lit/routing path (as today), while
  preserving the pointer-prompt convention ("read your dispatch file first").
- Single-task Stage 6's Step 3 ("read the fork's own returned text") is replaced by: the aux
  dispatch file instructs the fork to write `${TASK_DIR}/.blocker-research.json`, which
  `orchestrate-cycle-plan.sh` reads to compose the follow-on `plan-revision` row. The thin lead
  never reads prose; this mirrors Stage 5a's own existing `.drift-inspection.json` convention.
- Stage 6's Step 5 (re-dispatch implement) is **not** an aux row — it is the ordinary
  status-derived implement dispatch on a later cycle, exactly as the research predicted.
- Caps are preserved verbatim and stay per-invocation (matching single-task's "reset each
  `/orchestrate` invocation"): `MAX_BLOCKER_ESCALATIONS=2` and `MAX_DRIFT_INSPECTIONS=1`, held as
  per-task maps in the per-session multi-state file, which is the correct scope for them.
- Stage 5a/5b mutual exclusion is preserved: `drift-inspection` is emitted only when
  `hard_mode=false`, `divergence-audit` only when `hard_mode=true`.

### Decision 3 — Churn: a script that *requests* an audit, never dispatches one

`orchestrate-churn.sh` is task-directory-scoped, called from `orchestrate-cycle-postflight.sh`
only when hard mode is on. Two departures from a literal transcription of Stage 5b, both forced
by the architecture and both faithful in outcome:

- Stage 5b's three-strikes branch invokes the Agent tool inline. Scripts in this codebase never
  invoke the Agent tool. `orchestrate-churn.sh` instead returns
  `{churn_detected, target, count, audit_requested, verbatim_goal}`; postflight persists
  `audit_requested` to the resolved state store, and the next cycle's
  `orchestrate-cycle-plan.sh` emits a `divergence-audit` aux row carrying the same target and
  verbatim goal. The dispatch still happens, one cycle later, with the same agent and the same
  `orchestrator_mode: false`.
- Stage 5b's `phases_completed_before` was captured in Stage 4's H1 branch, which the batch engine
  does not have as a caller-side variable. `orchestrate-churn.sh` instead persists
  `phases_completed_last` in `.orchestrator-churn-state.json` and computes the delta across
  cycles itself. The "skip the check entirely rather than compute a false delta" guard is
  preserved: an absent `phases_completed_last` (first cycle for this task) skips the check, the
  same unset-vs-zero distinction Stage 5b makes.

Stage 2's churn-state init/resume becomes lazy initialization inside this script, so no separate
init call is needed anywhere in the batch path. The burnout counter keeps its existing home in
the loop-guard file (Decision 1 leaves that file in place), reached via
`orchestrate-churn.sh --burnout-signal`.

### Decision 4 — H1 refusals become per-task defers, not whole-run exits

Single-task's H1 branch answers an inconclusive phase scan or a marker/handoff mismatch with
`EXIT (partial)` — stopping the whole invocation. The batch engine has no whole-run exit for a
single task's problem; its established idiom is a per-task `blocked[]`/`deferred[]` row carrying
the verdict's own reason string verbatim. H1's two refusal paths therefore become blocked rows
with the same named reasons. The disputed-heading downgrade to `[PARTIAL]` is ported unchanged
(it is a plan-file repair, not a control-flow decision).

## Goals & Non-Goals

**Goals**:

- `orchestrate-churn.sh` exists, is task-directory-scoped, and is called from
  `orchestrate-cycle-postflight.sh` when hard mode is on (item 2).
- The H1 single-blocking-phase-per-cycle limiter lives in `orchestrate-cycle-plan.sh` (item 2).
- One cycle-budget counter per task, cumulative across invocations, `--continue-budget` honored in
  one place (item 3).
- Blocker escalation and drift inspection are emitted as next-cycle aux rows with their fixed
  agents and frontmatter models, bypassing the memory/lit path (item 4).
- A single task number routes through the batch engine behind a feature flag, with the
  hard-mode/loop-guard test set green against it (item 5).
- Every row of `specs/PATH.md`'s "One engine, batch of one" capability table has a live home in
  the batch engine (minus the withdrawn team row).

**Non-Goals**:

- Deleting or disabling `SKILL.md` Stages 1-8. They stay on disk and stay the **default** path;
  the successor task deletes them. Temporary duplication between the two engines is expected and
  sanctioned for the flag's lifetime.
- Team fan-out in any form (`orchestrate-team-fanout.sh`, a `team` row field, `--team` per row).
  Withdrawn by the dispatch addendum.
- Changing hard-mode contract injection (already script-side in `orchestrate-build-dispatch.sh`).
- Extending the hard-only `loop-guard-staleness` detector to base mode (an explicitly separate,
  undecided question recorded in Stage 2).
- Any user-prompting surface. The orchestrator never asks on its own.
- Making the batch path the default for a single task number.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Cumulative-budget guarantee silently lost when a single task routes through the batch path | H | M | Decision 1 preserves it via the durable per-task guard file; Phase 8 demonstrates a budget-exhaustion stop on a live batch-of-one run and Phase 1 adds a regression case asserting a second invocation resumes the prior `cycle_count` |
| An aux row accidentally routed through `command-route-agent.sh`, changing which agent runs | H | M | Decision 2's sibling array keeps fixed-agent selection in the emitting code; Phase 5 adds a test asserting `aux_dispatch[]` agents are never task-type-resolved |
| `orchestrate-churn.sh` introduced session-scoped, diverging from single-task's per-task churn semantics | M | L | Script takes `$TASK_DIR` and only ever touches `${TASK_DIR}/.orchestrator-churn-state.json`; Phase 2's test asserts two different session ids share one task's churn state |
| Retiring the batch-wide `MAX_CYCLES_MT` scalar breaks a consumer that reads `.cycle_count`/`.max_cycles` | M | M | Phase 1 greps every reader of those fields (`SKILL.md` MT stages, postflight's `--cycle-count`, the tests) and updates each; the scalar is kept as a derived mirror only if a reader cannot be updated in scope |
| H1's port into `orchestrate-cycle-plan.sh` changes phase selection for existing hard-mode batch runs | H | M | The heading-scan, conformance gate and crosscheck are ported from the same shared `scripts/lib/phase-heading-patterns.sh` anchor with no pattern re-derivation; Phase 4 runs `test-phase-heading-patterns.sh` and `test-resume-scan-nonconformance.sh` unchanged |
| Test coverage lost by retargeting the two loop-guard tests off `SKILL.md` | M | M | Phase 7 *adds* script-targeted cases and keeps the existing `SKILL.md` region cases until the successor task deletes those stages |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 3, 4 |
| 4 | 6 | 5 |
| 5 | 7 | 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Per-task cumulative cycle budget in `orchestrate-cycle-plan.sh` [NOT STARTED]

**Goal**: Implement Decision 1 — one cycle-budget counter per task, live in the multi-state file,
durably backed by the per-task loop-guard file, with `--continue-budget` honored in one place.

**Tasks**:
- [ ] Enumerate every reader/writer of the multi-state `.cycle_count` / `.max_cycles` scalars
      (`orchestrate-cycle-plan.sh`, `SKILL.md` MT-3/MT-4, `orchestrate-cycle-postflight.sh`'s
      `--cycle-count`, `scripts/tests/test-orchestrate-cycle-plan.sh`) before changing the shape.
- [ ] Replace the scalars with `cycle_counts` and `max_cycles_per_task` maps in the multi-state
      file's `//=` initialization block; keep every other field name byte-identical.
- [ ] Extend `orchestrate-loop-guard-init.sh` into the shared read/seed/flush helper for
      `${TASK_DIR}/.orchestrator-loop-guard` (seed `cycle_count` on first sight of a task, flush
      it back at cycle end), leaving that file's JSON schema unchanged.
- [ ] Set per-task `max_cycles` to 13 when `--hard` is passed, 5 otherwise; retire
      `default_max_cycles = ntasks * 5` (cap 25).
- [ ] Re-site the top-of-script budget guard to trip per task; the batch stops only when every
      non-terminal task has exhausted its own budget, with the existing `stop.reason="max_cycles"`
      string preserved.
- [ ] Port the `budget-continuation-override` behavior (archive the exhausted guard aside, reset
      `cycle_count` to 0 in place, preserve `dispatch_seq_counter`/`detected_defects`) into the
      `--continue-budget` branch of that guard.
- [ ] Record Decision 1 in `orchestrate-cycle-plan.sh`'s header comment, naming
      `test-session-runtime-files.sh` Case 3 explicitly.
- [ ] Extend `scripts/tests/test-orchestrate-cycle-plan.sh`: a second invocation with a fresh
      `session_id` resumes the prior `cycle_count`; `--continue-budget` resets it; hard mode gets
      13 and base mode 5.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — budget guard, multi-state
  field shape, per-task max_cycles, continue-budget override
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` — seed/flush helper
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new cases

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` green, including the new cases
- `bash scripts/test-session-runtime-files.sh` green (Case 3 unchanged and still meaningful)
- Two successive `--dry-run`-free live runs against a fixture state file show a monotonically
  increasing `cycle_counts[t]` across differing `session_id`s

---

### Phase 2: Build `orchestrate-churn.sh` and its test [NOT STARTED]

**Goal**: Implement Decision 3's script — task-directory-scoped churn/three-strikes state, an
audit *request* return value, and a burnout-signal mode — with no caller wired up yet.

**Tasks**:
- [ ] Create `scripts/orchestrate-churn.sh` with the codebase's standard header/usage/exit-code
      conventions (model it on `orchestrate-triage-classify.sh`).
- [ ] Lazy init/resume of `${TASK_DIR}/.orchestrator-churn-state.json` via `task-lock.sh
      init-marker`, with the observational-only `session_id` mismatch INFO log ported verbatim
      (never a gate). Add `phases_completed_last` to the record.
- [ ] Port the Stage 5b churn signature: `dispatch_status = partial` AND non-empty blockers AND
      `phases_delta == 0` increments `target_churn[blocker_target]` and `total_churn`, with the
      atomic `jq > tmp && mv` write idiom.
- [ ] Port the three-strikes branch as a *request*: at `target_churn >= 3`, return
      `audit_requested: true` with `target` and `verbatim_goal`, reset that target's counter and
      increment `audit_dispatches`. Never invoke the Agent tool.
- [ ] Implement `--burnout-signal <task_dir>`: increment `burnout_signals_this_session` in the
      loop-guard file and emit the existing `[orchestrate] H-orch: burnout signal detected ...`
      message verbatim.
- [ ] Emit one compact JSON line; exit 0 for any verdict, 2 for usage/environment errors.
- [ ] Create `scripts/tests/test-orchestrate-churn.sh` covering: fresh init; resume across two
      different `session_id`s against one task dir; the three-strikes threshold and its counter
      reset; the first-cycle skip when `phases_completed_last` is absent; the burnout counter
      write; the non-churn signature (progress made, or no blockers) leaving state untouched.
- [ ] Register both files wherever the deploy manifest enumerates scripts and tests
      (`manifest.json`, `scripts/tests/run-all.sh` if it enumerates explicitly).

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts two new files and no edits to existing scripts beyond
manifest/test-runner registration. Confirm at implementation time with
`git status --short` after the phase — any third source file touched means the boundary was
wrong and should be re-examined before committing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-churn.sh` — new
- `agent-system/extensions/core/scripts/tests/test-orchestrate-churn.sh` — new
- `agent-system/extensions/core/manifest.json` — register the new script/test if the manifest
  enumerates them

**Verification**:
- `bash scripts/tests/test-orchestrate-churn.sh` green
- `bash -n scripts/orchestrate-churn.sh` and `shellcheck` clean at the repo's usual level
- A fixture run with two different `session_id`s against one task dir shows the churn counters
  accumulating in one file

---

### Phase 3: Wire hard mode and the aux signals into `orchestrate-cycle-postflight.sh` [NOT STARTED]

**Goal**: Postflight calls `orchestrate-churn.sh` when hard mode is on, and persists the two
signals the next cycle's aux emission needs.

**Tasks**:
- [ ] Add `--hard` (default off) to `orchestrate-cycle-postflight.sh`'s flag parser and usage
      block; thread it from `orchestrate-cycle-plan.sh`'s per-row hard mode through the caller.
- [ ] After the status transition and before the commit, call `orchestrate-churn.sh` when
      `--hard`, passing `$TASK_DIR`, `dispatch_status`, the handoff's `blockers`, and
      `phases_completed`.
- [ ] Persist the churn script's `audit_requested`/`target`/`verbatim_goal` to the resolved state
      store (multi-state file, or the loop-guard file for a single-task caller) as
      `aux_pending[task]`.
- [ ] Emit the base-mode drift signal: when `hard_mode` is false, `dispatch_status = partial` and
      `phases_completed / max(phases_total,1) < 0.70`, record `aux_pending[task] =
      {kind: "drift-inspection"}`.
- [ ] Emit the blocker signal: when `verdict = blocked`, record
      `aux_pending[task] = {kind: "blocker-research", blocker_desc}`.
- [ ] Extend the output JSON with the churn/aux outcome as informational fields only; do **not**
      change `verdict`, `halt`, or `infra_exempt_cycle` semantics.
- [ ] Update the script's header WORK list and `docs/architecture/orchestrate-cycle-postflight.md`
      with the new lettered items.
- [ ] Extend `scripts/tests/test-orchestrate-cycle-postflight.sh`: `--hard` invokes the churn
      script and a base-mode run does not; each of the three `aux_pending` writes fires on its own
      trigger and on no other.

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — `--hard`, churn call,
  aux-signal persistence, header
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md` — WORK list
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new cases

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` green
- A fixture hard-mode run with three consecutive zero-progress partial dispatches on one blocker
  target leaves `audit_requested: true` in the state store
- A base-mode partial run below the completion threshold writes a `drift-inspection`
  `aux_pending` entry and no churn state

---

### Phase 4: Move the H1 per-phase limiter into `orchestrate-cycle-plan.sh` [NOT STARTED]

**Goal**: Under hard mode, an `implement` row dispatches exactly one open phase, selected by the
shared heading-scan machinery, with H1's two refusal paths mapped to per-task blocked rows
(Decision 4).

**Tasks**:
- [ ] Source `scripts/lib/phase-heading-patterns.sh` in `orchestrate-cycle-plan.sh`; do not
      re-derive any pattern inline.
- [ ] Port the resume-scan conformance gate: run `has_nonconforming_phase_headings` over the whole
      plan file **before** the filtered scan; on a hit emit a blocked row carrying the existing
      "the true next phase is UNKNOWN" reason verbatim.
- [ ] Port the heading-scan `next_phase` selection (`PHASE_HEADING_ERE` + `PHASE_STATUS_OPEN_ERE`,
      `extract_phase_number`).
- [ ] Port the pre-dispatch marker/handoff crosscheck, including the disputed-heading downgrade to
      `[PARTIAL]`; on a mismatch emit a blocked row with the existing MARKER/HANDOFF MISMATCH
      reason instead of `EXIT (partial)`.
- [ ] Port the H7 territory literal and pass it to `orchestrate-build-dispatch.sh` via the
      existing `--territory` flag for hard-mode implement rows.
- [ ] Add `--phase-number N` to `orchestrate-build-dispatch.sh` so the dispatch file records the
      selected phase; keep it optional and absent from base-mode calls.
- [ ] Confirm the "exactly one blocking phase per cycle" property holds by construction (at most
      one implement row per task per cycle) and record that in the header rather than adding a
      second limiter.
- [ ] Extend `scripts/tests/test-orchestrate-cycle-plan.sh` and
      `scripts/tests/test-orchestrate-build-dispatch.sh` for the new behavior.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase assumes the H1 hard branch's portable content is exactly the four
regions named above (conformance gate, heading scan, marker crosscheck, territory) and that
`orchestrate-build-dispatch.sh` needs exactly one new flag. Confirm at implementation time by
diffing the ported code against `SKILL.md`'s `##### Hard branch: Per-Phase Dispatch (H1)` section
end-to-end and listing anything left behind, before closing the phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — H1 port
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `--phase-number`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new case

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh`,
  `bash scripts/tests/test-orchestrate-build-dispatch.sh`,
  `bash scripts/tests/test-phase-heading-patterns.sh`,
  `bash scripts/tests/test-resume-scan-nonconformance.sh` all green
- A hard-mode fixture plan with a `3a`-style non-conforming heading produces a blocked row, never
  a dispatch row
- A fixture where the plan's markers run ahead of the handoff produces the mismatch blocked row
  and downgrades exactly one heading

---

### Phase 5: Emit `aux_dispatch[]` rows and build their dispatch files [NOT STARTED]

**Goal**: Implement Decision 2 — the next-cycle emission of drift-inspection, blocker-research,
plan-revision and divergence-audit rows with fixed agents and a dedicated dispatch-file writer.

**Tasks**:
- [ ] Create `scripts/orchestrate-build-aux-dispatch.sh`: writes
      `specs/{NNN}_{slug}/.dispatch/{seq}-aux-{kind}.md` carrying the kind's prompt content and
      the "read your dispatch file first" pointer convention; never calls
      `orchestrate-build-dispatch.sh`, never touches memory retrieval, the `--lit` briefing, or
      `command-route-agent.sh`.
- [ ] Add `aux_dispatch[]` to `orchestrate-cycle-plan.sh`'s output JSON and to its header's output
      contract; leave `dispatch[]`, `deferred[]`, `blocked[]` and `stop` byte-identical.
- [ ] Emit rows from `aux_pending[task]` at the top of the cycle, one row per task per cycle,
      clearing the entry as it is emitted.
- [ ] Chain `blocker-research` -> `plan-revision`: when `${TASK_DIR}/.blocker-research.json` exists
      and no revision has run for it, emit the `plan-revision` row carrying the file's `summary`;
      then fall through to ordinary status-derived dispatch.
- [ ] Chain `drift-inspection` -> `plan-revision`: read `${TASK_DIR}/.drift-inspection.json` and
      emit the revision row only when `drift_pct > 0.30`; otherwise log the existing "Drift check
      passed" message and emit nothing.
- [ ] Enforce the caps: `MAX_BLOCKER_ESCALATIONS=2` and `MAX_DRIFT_INSPECTIONS=1` per task per
      invocation, held in the per-session multi-state file; at the cap, log the existing manual-
      intervention guidance and emit no row.
- [ ] Enforce mutual exclusion: `drift-inspection` only when hard mode is off,
      `divergence-audit` only when it is on.
- [ ] Set each row's `model` from the fixed agent's own frontmatter (null when the agent declares
      none), never from `--model`/effort routing.
- [ ] Extend `scripts/tests/test-orchestrate-cycle-plan.sh`: each kind emits on its own trigger and
      no other; agents are the fixed four and are never task-type-resolved; caps hold; the two
      mutually exclusive kinds never co-occur.

**Timing**: 2 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` — new
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `aux_dispatch[]` emission
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new cases
- `agent-system/extensions/core/manifest.json` — register the new script

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` green including the fixed-agent assertion
- A fixture with `aux_pending = blocker-research` produces exactly one `aux_dispatch[]` row with
  `agent = "fork"`, `orchestrator_mode = false`, and a dispatch file containing no memory or
  literature block (grep-asserted)
- `dispatch[]`'s JSON shape is unchanged for every pre-existing test case

---

### Phase 6: Wire aux rows and the burnout breaker into the engine's MT stages [NOT STARTED]

**Goal**: `SKILL.md`'s MT-3/MT-4 dispatch the new rows correctly and never postflight them; the
hard-mode burnout self-check reaches `orchestrate-churn.sh`.

**Tasks**:
- [ ] In Stage MT-4's dispatch-composition loop, add a second, adjacent loop over
      `plan_json.aux_dispatch[]` issuing its Agent calls in the SAME single message (the batching
      rule is unchanged), with `context.orchestrator_mode = false` and no `handoff_path`.
- [ ] State explicitly, as a MUST NOT, that aux rows never reach
      `orchestrate-cycle-postflight.sh` and never contribute to `failed_tasks`.
- [ ] Add the hard-mode burnout circuit-breaker self-check to the MT loop as a short MUST that
      calls `orchestrate-churn.sh --burnout-signal`, replacing inline reasoning with a dispatch,
      and delete no single-task copy.
- [ ] Thread `--hard` into the Stage MT-4 postflight call so Phase 3's wiring is reachable.
- [ ] Update `docs/architecture/orchestrate-state-machine.md`'s MT-mode section with the aux-row
      contract and Decision 2's rationale; keep `SKILL.md` itself terse (it is under a byte
      ceiling).
- [ ] Remove any stale "accepted-and-ignored" notice for flags the batch engine now honors,
      leaving genuinely ignored flags' notices intact.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — MT-4 aux loop, burnout MUST,
  `--hard` threading
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — aux-row contract

**Verification**:
- `bash scripts/tests/test-lint-postflight-boundary.sh` and
  `bash scripts/tests/test-lint-branch-gated-sections.sh` green
- `bash scripts/verify-deploy.sh` reports no new findings, including the `SKILL.md` byte ceiling
- Grep confirms exactly one `orchestrate-cycle-postflight.sh` call site in the MT stages, still
  iterating `dispatch[]` only

---

### Phase 7: Route one task number through the batch path behind a flag; retarget the tests [NOT STARTED]

**Goal**: `/orchestrate N` can run as a batch of one, opt-in, with the hard-mode and loop-guard
test set exercising the new scripts.

**Tasks**:
- [ ] In `commands/orchestrate.md` STAGE 0, gate the `len(TASK_NUMBERS) == 1` branch on
      `ORCHESTRATE_BATCH_OF_ONE` (env var, default unset): when set, build
      `waves_json=[[N]]`, `task_numbers_json=[N]`, `dep_graph_json={"N":[]}` and take the same
      `multi_task_mode=true` Skill invocation the `> 1` branch already uses.
- [ ] Leave the unset path falling through to CHECKPOINT 1 exactly as today; document the flag in
      the command's Options section as experimental and temporary.
- [ ] Confirm `SKILL.md` Stage 0 needs no change (it already branches on the delegation-context
      flag regardless of task count) and record that as a verified fact, not an assumption.
- [ ] Retarget `scripts/tests/test-loop-guard-budget-override.sh`: add cases running the budget
      guard and `--continue-budget` path of `orchestrate-cycle-plan.sh` directly, keeping the
      existing `SKILL.md` sentinel-region cases (the single-task engine is still live and still
      the default).
- [ ] Retarget `scripts/tests/test-loop-guard-staleness.sh` the same way against whichever script
      now owns the staleness region for the batch path, or record explicitly that the detector
      stays single-task-only for now and why.
- [ ] Update both suites' HONEST SCOPE LIMIT headers to describe the two-target structure.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: this phase assumes exactly two test files extract sentinel regions from
`SKILL.md`'s Stage 2 and therefore need retargeting. Confirm at implementation time with
`grep -rl "SKILL.md" agent-system/extensions/core/scripts/tests/` and inspect every hit before
declaring the list closed.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` — the flagged branch and Options entry
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` — new target
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` — new target or
  recorded scope note

**Verification**:
- Both loop-guard suites green, with both the `SKILL.md` cases and the script cases running
- With `ORCHESTRATE_BATCH_OF_ONE` unset, a single-task `--dry-run` is byte-identical to today's
- With it set, the same invocation produces a one-row wave table

---

### Phase 8: Acceptance runs and the full gate [NOT STARTED]

**Goal**: Demonstrate each surviving acceptance case on a live invocation carrying one task number
routed through the batch engine, and close the task on a green full gate.

**Tasks**:
- [ ] Deploy the source store (`deploy-headless.sh`) so `.claude/**` reflects the new scripts, and
      confirm no hand-authored `.claude/**` file was created at any point in this task.
- [ ] Acceptance A — hard-mode churn: a live batch-of-one `--hard` run against a fixture whose
      handoff reports three consecutive zero-progress partials on one blocker target; observe the
      churn script firing and a `divergence-audit` aux row on the following cycle.
- [ ] Acceptance B — budget exhaustion: run a batch-of-one task past its per-task `max_cycles`;
      observe the honest stop message, then observe `--continue-budget` authorizing a fresh budget
      and preserving `dispatch_seq_counter`.
- [ ] Acceptance C — blocker escalation: a live batch-of-one run whose postflight verdict is
      `blocked`; observe the `blocker-research` aux row, the `.blocker-research.json` write, and
      the `plan-revision` row on the cycle after.
- [ ] Verify PATH.md's capability table row-by-row: every non-withdrawn row has a live home in the
      batch engine; record the mapping in the execution summary.
- [ ] Run the full gate set: `scripts/tests/run-all.sh`, `scripts/verify-deploy.sh`,
      `scripts/check-task-references.sh`, and any repo-health probe the postflight gate invokes.
- [ ] Record in the summary that `SKILL.md` Stages 1-8 remain on disk and remain the default path,
      naming the successor deletion task's precondition as satisfied.

**Timing**: 1.5 hours

**Depends on**: 7

**Verification Tier**: full

**Files to modify**:
- `specs/148_port_single_task_features_to_batch_engine/summaries/01_*.md` — execution summary
  (created by the implementation postflight)

**Verification**:
- All three acceptance runs produce the expected rows/messages, quoted in the summary
- `bash scripts/tests/run-all.sh` green
- `bash scripts/verify-deploy.sh` reports no new findings
- No occurrence of a task-number reference outside `specs/**`
  (`bash scripts/check-task-references.sh` green)

---

## Testing & Validation

- [ ] `scripts/tests/test-orchestrate-churn.sh` — new suite, all cases pass
- [ ] `scripts/tests/test-orchestrate-cycle-plan.sh` — extended for the per-task budget, the H1
      port, and `aux_dispatch[]` emission
- [ ] `scripts/tests/test-orchestrate-cycle-postflight.sh` — extended for `--hard` and the three
      aux signals
- [ ] `scripts/tests/test-orchestrate-build-dispatch.sh` — extended for `--phase-number`
- [ ] `scripts/tests/test-loop-guard-budget-override.sh` and
      `scripts/tests/test-loop-guard-staleness.sh` — both targets green
- [ ] `scripts/test-session-runtime-files.sh` — Case 3 still passes and is still meaningful
- [ ] `scripts/tests/test-phase-heading-patterns.sh`,
      `scripts/tests/test-resume-scan-nonconformance.sh` — unchanged and green
- [ ] `scripts/tests/run-all.sh` — full suite green
- [ ] `scripts/verify-deploy.sh` — no new findings, byte ceilings respected
- [ ] `scripts/check-task-references.sh` — no task-number references outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-churn.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-churn.sh` (new)
- Modified: `scripts/orchestrate-cycle-plan.sh`, `scripts/orchestrate-cycle-postflight.sh`,
  `scripts/orchestrate-build-dispatch.sh`, `scripts/orchestrate-loop-guard-init.sh`,
  `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `manifest.json`
- Modified docs: `docs/architecture/orchestrate-cycle-postflight.md`,
  `docs/architecture/orchestrate-state-machine.md`
- Modified tests: `test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-build-dispatch.sh`, `test-loop-guard-budget-override.sh`,
  `test-loop-guard-staleness.sh`
- `specs/148_port_single_task_features_to_batch_engine/summaries/01_*.md` (execution summary)

**Declared `file_scope` widening**: the task's recorded `file_scope` omits
`commands/orchestrate.md`, `scripts/orchestrate-build-dispatch.sh`,
`scripts/orchestrate-build-aux-dispatch.sh`, `scripts/orchestrate-loop-guard-init.sh`, the two
loop-guard test files and the two architecture docs. Implementation should widen it rather than
work around it.

## Rollback/Contingency

Every phase commits independently and the feature flag defaults to unset, so the single-task
engine remains the live default path throughout. Rollback of any individual phase is
`git revert` of that phase's commits; rollback of the whole task is a revert of the phase range,
after which `SKILL.md` Stages 1-8 and the unchanged batch engine continue to operate exactly as
today. The two genuinely irreversible-feeling changes are guarded: the multi-state file's
`cycle_count` -> `cycle_counts` reshape is a per-session ephemeral file that is regenerated on the
next invocation, and the per-task loop-guard file's schema is left unchanged by design. If Phase 4
(the H1 port) proves larger than its budget, it can be split at the marker/handoff crosscheck
boundary without blocking Phase 5, which depends only on the cycle-plan output contract.
