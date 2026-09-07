# Research Report: Port single-task-only orchestrator features into the batch engine

- **Task**: 148 - Port hard-mode counters, loop guard and auxiliary dispatches into the batch engine as per-dispatch options
- **Started**: 2026-09-03T00:00:00Z
- **Completed**: 2026-09-03T00:40:00Z
- **Effort**: ~1 session (research only)
- **Dependencies**: 143 (`orchestrate-cycle-postflight.sh`) — completed, unblocked
- **Sources/Inputs**:
  - `specs/PATH.md` ("One engine, batch of one", Stage A table, backlog operation manifest)
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (single-task Stages 2, 2b, 3/3b-hard/3c, 5a, 5b, 6, 7; multi-task Stage 0 branch)
  - `agent-system/extensions/core/commands/orchestrate.md` (single-vs-multi-task branch, flag table, single-task Skill invocation)
  - `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, `orchestrate-loop-guard-init.sh`
  - `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`, `check-runtime-file-tracking.sh` (runtime-file naming conventions)
  - `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh`, `test-loop-guard-staleness.sh` (SKILL.md-extraction test structure)
  - `agent-system/extensions/core/context/guides/hard-mode-routing.md`
  - `specs/state.json` (task 148's declared `file_scope`)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Team item (1) is confirmed already withdrawn on disk: task 149 deleted team mode
  (Stage 3.6/3.6a, `--team`/`--team-size`, `synthesis-agent` fan-out) before this dispatch began.
  Nothing to port for team; the dispatch addendum already reflects this.
- Item (2) HARD: `orchestrate-churn.sh` does not exist yet. `orchestrate-cycle-postflight.sh` has
  **zero** `hard_mode`/churn/burnout awareness today — it is a pure gap, not a partial port. The
  churn-state file (`.orchestrator-churn-state.json`) is already per-task-directory-scoped
  (matching single-task's model), so no session/task reconciliation is needed for item (2) itself
  — only for item (3)'s loop-guard counter.
- Item (3) LOOP GUARD: single-task's `cycle_count` is **per-task, cumulative across
  `/orchestrate` invocations by design** (protected by `test-session-runtime-files.sh` Case 3),
  stored in a per-task-directory file. Multi-task's `MAX_CYCLES_MT`/`cycle_count` is **per-session**,
  stored in `specs/.orchestrator-multi-state-${session_id}.json`, which is a *fresh file every
  invocation* since `session_id` is minted per call. Reconciling these into "ONE counter" is a
  real behavioral decision, not a mechanical port — flagged for the plan.
- Item (4) AUXILIARY DISPATCHES: `orchestrate-cycle-plan.sh` has no blocker-escalation or
  drift-inspection row emission today — a `blocked`-status task is simply reported in the
  `blocked[]` bucket with a static reason, with no auto-escalation. Single-task's Stage 6 (5-step
  blocker escalation: fork research → revise plan → re-dispatch implement) and Stage 5a (drift
  inspection fork → conditional revision) both dispatch **fixed agents** (`fork`, `reviser-agent`)
  outside the task-type routing table `orchestrate-build-dispatch.sh` uses — this is a structural
  mismatch with the current dispatch-row schema (`{task, phase, agent, model, dispatch_file,
  force}`, where `phase` ∈ {research, plan, implement} and `agent` is task-type-routed).
- Item (5) ROUTING: `commands/orchestrate.md` already contains the exact branch point needed —
  `len(TASK_NUMBERS) == 1` falls through to the single-task Skill call (`multi_task_mode`
  absent); `len(TASK_NUMBERS) > 1` builds `waves_json`/`task_numbers_json`/`dep_graph_json` and
  calls `skill-orchestrate` with `multi_task_mode=true`. A feature flag only needs to make the
  `== 1` branch build the same trivial one-task wave/dep-graph and take the `multi_task_mode=true`
  path instead — no new routing surface needs to be invented.
- Test-retargeting scope (item 5's acceptance) is narrow now that team is withdrawn: only
  `test-loop-guard-budget-override.sh` and `test-loop-guard-staleness.sh` extract sentinel-delimited
  bash regions directly out of `SKILL.md`'s Stage 2 today; both must be retargeted to source the
  new script(s) instead once that logic moves.

## Context & Scope

Task 148 is Stage A.5 of `specs/PATH.md`'s thin-lead path: the precondition for task 88 (delete
the single-task engine). The decided design is that every capability that exists **only** in
single-task Stages 1-8 today must exist as a per-row option or a script in the batch
(`orchestrate-cycle-plan.sh`/`orchestrate-cycle-postflight.sh`) engine before Stages 1-8 can be
deleted. The dispatch's addendum (2026-09-02) withdrew item (1) TEAM entirely (task 149 already
deleted team mode) and confirmed items (2)-(5) stand as written. This research scopes what
currently exists in the batch engine vs. the single-task engine for each of the four live items,
and identifies the concrete gaps and design tensions a plan must resolve.

Research does not design the final mechanism for any item — it establishes ground truth about
what exists, what is missing, and where the two engines' current models are structurally
incompatible (item 3 in particular), so planning starts from verified facts rather than
assumptions.

## Findings

### Item (1) TEAM — confirmed withdrawn, nothing to research

- `specs/PATH.md` line 141 records team fan-out as "**deleted** (149): ~5x cost, rarely used, an
  unfixed ownership defect; not worth a script."
- `orchestrate-cycle-plan.sh`'s own header states `--team`/`--team-size` are REJECTED as
  unrecognized flags (usage error, exit 2); no `team` key is ever emitted on a dispatch row.
- No action needed for this item.

### Item (2) HARD — `orchestrate-churn.sh` is a pure gap

- `grep -n "hard_mode\|churn\|burnout" orchestrate-cycle-postflight.sh` returns **zero matches**.
  The postflight script's own header's lettered WORK list (a)-(j) never mentions hard mode.
  `orchestrate-cycle-plan.sh` threads `--hard` only as far as `build_args+=(--hard)` for
  `orchestrate-build-dispatch.sh` (contract injection — already correct and explicitly out of
  scope per the dispatch text).
- Single-task's three hard-mode-only stateful mechanisms to port, all currently living inline in
  `SKILL.md`:
  - **Stage 2 churn-state init** (lines ~413-439): creates/resumes
    `${TASK_DIR}/.orchestrator-churn-state.json` with `{session_id, total_churn, target_churn:{},
    adversarial_triggers, audit_dispatches}`, atomic via `task-lock.sh init-marker`.
  - **Stage 5b churn detection (H6) + three-strikes audit dispatch (H5)** (lines 1943-2016): after
    a `partial` dispatch with non-empty blockers and zero phase progress this cycle, increments
    `target_churn[blocker_target]`; at count ≥ 3, dispatches a `$RESEARCH_AGENT` "DIVERGENCE
    AUDIT" (no handoff, `orchestrator_mode: false`) and resets that target's counter,
    incrementing `audit_dispatches`.
  - **Stage 3b-hard burnout circuit-breaker gate** (lines 657-694): a per-cycle, hard-mode-only
    self-check (re-read without new info / reasoning turns without a tool call / reversing a
    decision without a fresh finding) that increments `burnout_signals_this_session` in the
    **loop guard** file (not the churn file) and forces a dispatch/escalation instead of inline
    reasoning.
- **Key finding**: the churn-state file is already keyed by `task_dir`, not by `session_id` —
  identical scoping to single-task's model (confirmed via
  `check-runtime-file-tracking.sh`/`reap-session-runtime-files.sh`, which both treat
  `.orchestrator-churn-state.json` as a per-task runtime file needing no session-scoped reaping).
  This means item (2) in isolation is a comparatively clean port: `orchestrate-churn.sh` can take
  `$TASK_DIR` and behave identically whether called from a single-task-of-one batch row or a
  wider batch — no cross-task/session reconciliation is needed for churn/three-strikes state
  itself. The burnout counter is the one piece of item (2) that currently lives in the loop guard
  file rather than the churn file, so it inherits whatever reconciliation item (3) settles on.
- `orchestrate-churn.sh` and `scripts/tests/test-orchestrate-churn.sh` are both already declared
  in task 148's `file_scope` (`specs/state.json`) and confirmed absent on disk by task 144's own
  filesystem check (archived report: "do not exist yet").

### Item (3) LOOP GUARD — a genuine reconciliation problem, not a mechanical port

- **Single-task model** (`SKILL.md` Stage 2, `orchestrate-loop-guard-init.sh`): `cycle_count` is
  stored in `${TASK_DIR}/.orchestrator-loop-guard`, one file per task directory. It is explicitly
  documented as "a per-task, CUMULATIVE budget that survives re-invocation BY DESIGN — deliberately
  NOT reset on a new session_id" (Stage 2's "Defect B" comment), because resetting on
  `session_id` would let an operator silently bypass `MAX_CYCLES` by re-invoking `/orchestrate`.
  This invariant is protected by `test-session-runtime-files.sh` Case 3 and
  `test-loop-guard-budget-override.sh`. `MAX_CYCLES` is mode-aware (13 for hard, 5 for base).
  `--continue-budget` archives the exhausted guard and resets `cycle_count` to 0 **in place**,
  preserving `dispatch_seq_counter` and `detected_defects`.
- **Multi-task model** (`orchestrate-cycle-plan.sh`): `cycle_count`/`max_cycles` (`MAX_CYCLES_MT`)
  live in `mt_state_file = <dirname STATE_FILE>/.orchestrator-multi-state-${session_id}.json` —
  one file **per session**, not per task. Since `session_id` is minted fresh at
  `command-gate-in.sh`/`common_session_id` on every `/orchestrate` invocation, this file (and its
  `cycle_count`) starts fresh every time. The budget guard is re-sited to the top of the script
  ("(k, part 1)") and already honors `--continue-budget` the same way single-task does (stop with
  a named `max_cycles` reason unless the flag is set), but this is a **per-session** budget shared
  across every task in the batch, not a per-task cumulative one.
- **The reconciliation gap**: routing a single task number through the batch path (item 5) means
  that task's work-cycle budget becomes per-invocation (multi-task's model) unless something
  changes. This silently drops the "cumulative across invocations" guarantee
  `test-session-runtime-files.sh` Case 3 protects today — an operator re-running
  `/orchestrate N` (single task, batch-routed) would always get a fresh `MAX_CYCLES_MT` budget
  with no `--continue-budget` needed, exactly the bypass single-task's design comment says must
  never happen silently. PATH.md's own phrasing ("reconcile ... into ONE counter in the
  multi-state file") signals the multi-state file is meant to become the sole surviving
  authority, but does not by itself resolve whether that file becomes keyed per-task (so
  cross-invocation cumulation is preserved) or whether the cumulative-budget guarantee is
  deliberately relaxed for the batch path. **This is a decision the plan must make explicitly and
  record — it is not implied by any existing script's current behavior.** Two directions were
  visible in the exploration, offered as options rather than a decision:
  - Key cycle-count-per-task inside the (now more complex) multi-state file, so a
    single-task-of-one batch invocation of the same task_number resumes its cumulative
    `cycle_count` from a prior invocation's multi-state file, or from the legacy per-task loop
    guard file directly.
  - Accept the multi-state file's existing per-session behavior for the batch path and explicitly
    relax the cumulative guarantee for batch-routed runs, documenting the behavior change and
    updating `test-session-runtime-files.sh` Case 3's scope note accordingly.
- The burnout counter (`burnout_signals_this_session`, item 2's Stage 3b-hard) is presently
  written into the *loop guard* file, so it directly inherits whichever of the two above
  directions the plan picks.
- The `loop-guard-staleness` detector (3 OR-combined signals: `max_cycles` drift, `plan_version`
  drift, mtime-age backstop) and the `budget-continuation-override` region are both hard-mode-only
  today (Signal 2/asymmetry decision explicitly notes base mode does not have this detector, and
  that extending it is a *separate, undecided* question — not this task's to resolve).
- `orchestrate-loop-guard-init.sh`'s own header states it is "a shared Stage 2 loop-guard
  initializer prologue for both orchestrate engines" but its actual body only creates the
  per-task `.orchestrator-loop-guard` file shape — it has not yet been adapted to the
  per-session multi-state shape; `orchestrate-cycle-plan.sh` does not call it at all today
  (verified by absence of any `orchestrate-loop-guard-init.sh` reference in that script).

### Item (4) AUXILIARY DISPATCHES — structural mismatch with the dispatch-row schema

- `orchestrate-cycle-plan.sh`'s `blocked[]` bucket today is populated only from: (a) predecessor
  dependency failures, (b) dangling `dependencies[]` edges, (c) `MAX_INFRA_FAILURES` reached, and
  (d) `orchestrate-triage-classify.sh`'s `needs_human` verdict. In every case the row carries a
  static `reason` string — there is no dispatch of a research fork or a plan revision in response.
  This confirms item (4) is entirely unimplemented in the batch engine today, not partially built.
- **Single-task Stage 6 (Blocker Escalation, 5 steps)**: DETECT (blocker passed in) → RESEARCH
  FORK (`subagent_type: "fork"`, `orchestrator_mode: false`, no handoff written — per the
  documented one-channel-per-mode contract, a `false` dispatch never writes
  `.orchestrator-handoff.json`) → READ FINDINGS (from the fork's own returned text, not a file) →
  REVISE PLAN (`subagent_type: "reviser-agent"`, likewise `orchestrator_mode: false`) →
  RE-DISPATCH IMPLEMENT (the only step of the five that mints a real `dispatch_seq`, sets
  `orchestrator_mode: true`, and writes a handoff — i.e. only the *last* step looks like an
  ordinary dispatch row). Capped at `MAX_BLOCKER_ESCALATIONS=2` per invocation.
- **Single-task Stage 5a (Drift Inspection, base mode only)**: a `fork` dispatch that writes
  `.drift-inspection.json` (not a handoff), followed conditionally (`drift_pct >
  DRIFT_REVISION_THRESHOLD`) on a `reviser-agent` dispatch. Capped at `MAX_DRIFT_INSPECTIONS=1`.
  Explicitly documented as mutually exclusive with Stage 5b's H5 divergence-audit mechanism — one
  or the other is reachable depending on `hard_mode`, never both.
- **Structural mismatch**: the current dispatch-row schema
  (`{task, phase, agent, model, dispatch_file, force}`) assumes `phase` ∈ {research, plan,
  implement} and that `agent` is resolved via `command-route-agent.sh`'s task-type routing table
  (through `orchestrate-build-dispatch.sh`). Both auxiliary flows use a **fixed** agent
  (`fork` or `reviser-agent`) chosen by the escalation/drift logic itself, not by task type — and
  the dispatch text is explicit that these "never call build-dispatch's memory/lit path (as
  today)". This means:
  - The plan will need either a new `phase` value (e.g. `"blocker-escalation"` /
    `"drift-inspection"`) the postflight script special-cases, or a wholly separate emission path
    that bypasses `orchestrate-build-dispatch.sh` for these two row kinds while still producing a
    dispatch file (the dispatch text preserves the "read your dispatch file first" pointer-prompt
    convention established by task 146 — it does not say these dispatches go back to
    inline-authored prompts).
  - Single-task's Stage 6 step 5 (re-dispatch implement) is itself an ordinary implement dispatch
    once the revision lands — in the batch engine this most likely becomes: cycle N+1 emits the
    escalation row (fork research), a later cycle emits the revision row (reviser-agent), and a
    subsequent cycle's ordinary status-derived dispatch picks the revised plan back up — i.e. the
    5-step sequence spans multiple cycles rather than collapsing into one row, matching the
    dispatch text's "become rows... emits **on the next cycle**" (singular row per cycle, not the
    whole sequence at once).
  - `MAX_BLOCKER_ESCALATIONS`/`MAX_DRIFT_INSPECTIONS` counters need a home — today they live as
    loop-guard-adjacent shell variables reset once per single-task invocation
    (`orchestrate-loop-guard-init.sh` returns `blocker_escalation_count`/
    `max_blocker_escalations`); the batch engine has no equivalent per-task or per-session
    counter for either today.

### Item (5) ROUTING — the branch point already exists; only the condition needs a flag

- `commands/orchestrate.md`'s STAGE 0 already contains the exact fork point:
  `len(TASK_NUMBERS) == 1` → fall through to `CHECKPOINT 1: GATE IN` → single-task
  `Skill` call (`orchestrator_mode=true`, no `multi_task_mode` key at all, i.e. Stage 0 of
  `SKILL.md` defaults it to `false` and the whole single-task Stages 1-8 body runs).
  `len(TASK_NUMBERS) > 1` → builds `waves_json = [[task_numbers...]]`,
  `task_numbers_json`, `dep_graph_json`, mints `batch_session_id`, and calls `skill-orchestrate`
  with `multi_task_mode=true`.
- For a single task number, the multi-task-shaped inputs are trivial to construct: `waves_json =
  [[N]]`, `task_numbers_json = [N]`, `dep_graph_json = {"N": []}` (no intra-batch dependencies
  possible with one task). No new computation is needed beyond what the `> 1` branch already does
  for each task.
- This confirms the dispatch text's own framing is accurate and achievable: "Route a single task
  number through the batch path behind a feature flag (or an environment variable)" is a matter of
  making the `== 1` branch conditionally take the same code path the `> 1` branch already takes,
  rather than inventing new plumbing. `SKILL.md`'s Stage 0 (`multi_task_mode` detection) needs no
  change at all — it already branches correctly on the delegation-context flag regardless of task
  count.
- **Test-retargeting scope** (acceptance: "hard-mode ... test set" — team dropped by the
  addendum): only two test files currently extract sentinel-delimited bash regions directly out of
  `SKILL.md`'s Stage 2 and eval them in a fixture harness:
  - `test-loop-guard-budget-override.sh` — extracts from `budget-continuation-override:begin`
    through the "Resuming — cycle" echo inside the resume-read branch; run once per `hard_mode`
    value.
  - `test-loop-guard-staleness.sh` — extracts the `loop-guard-staleness:begin`/`:end` region
    (hard-mode-only).
  Both will need to source the *new* script(s) (`orchestrate-churn.sh` and/or whatever absorbs
  Stage 2's loop-guard init/staleness/override logic into the batch path) once that logic actually
  moves, rather than extracting bash text from `SKILL.md`. No other test file currently targets
  hard-mode Stage 2/3b-hard/5b/6 logic directly (grep across `scripts/tests/*.sh` for
  `hard_mode`/`--hard` also surfaced `test-handoff-reader-parity.sh`,
  `test-guard-destructive-git.sh`, `test-routing-resolution.sh`,
  `test-resume-scan-nonconformance.sh`, and `test-orchestrate-build-dispatch.sh`, but these test
  handoff-shape parity, git-safety, agent routing, phase-heading conformance, and dispatch-file
  construction respectively — none extract Stage 2/5b/6 bash regions the way the two loop-guard
  tests do).

## Decisions

None made by this research pass — task 148's dispatch text explicitly states "DECIDED DESIGN (do
not re-litigate)" for the overall shape, and this report surfaces open sub-decisions (loop-guard
reconciliation direction, aux-dispatch row/phase representation) for the plan to resolve rather
than deciding them here.

## Recommendations

1. **Item (2) HARD**: build `orchestrate-churn.sh` as a task-directory-scoped script (mirroring
   the existing `.orchestrator-churn-state.json` file's own scoping), taking `$TASK_DIR` and the
   postflight's already-computed `dispatch_status`/`blockers`/`phases_completed_before/after`
   values as inputs, called from `orchestrate-cycle-postflight.sh` only when `--hard` is passed
   through from `orchestrate-cycle-plan.sh`'s per-row `hard_mode`. This is the cleanest of the
   four items — no cross-task state is involved.
2. **Item (3) LOOP GUARD**: resolve the per-task-cumulative vs. per-session reconciliation
   explicitly in the plan, citing `test-session-runtime-files.sh` Case 3's existing invariant by
   name. Whichever direction is chosen, thread the burnout counter through the same storage
   decision, since it currently lives in the loop-guard file rather than the churn file.
3. **Item (4) AUXILIARY DISPATCHES**: decide the dispatch-row representation (new `phase` value
   vs. a separate emission path) before touching `orchestrate-cycle-postflight.sh`'s `--phase`
   contract, since that flag is also read by the phase-count corroboration and artifact-round
   logic documented in that script's header. Confirm whether `orchestrate-build-dispatch.sh`
   needs a bypass mode (skip memory/lit/routing) or whether these two row kinds get their own
   dispatch-file writer, consistent with "never call build-dispatch's memory/lit path (as
   today)".
4. **Item (5) ROUTING**: implement as a minimal STAGE 0 conditional in `commands/orchestrate.md` —
   when the flag/env var is set and exactly one task number was given, build the same trivial
   one-task `waves_json`/`task_numbers_json`/`dep_graph_json` the `> 1` branch already builds and
   take the `multi_task_mode=true` path. Retarget `test-loop-guard-budget-override.sh` and
   `test-loop-guard-staleness.sh` to the new script(s) as part of the same phase that moves their
   underlying logic, not as an afterthought — both tests are structurally coupled to exactly which
   file contains the sentinel regions they extract.
5. Sequence item (3)'s decision before items (2) and (4) are finalized in the plan, since both the
   churn script's burnout-counter home and the auxiliary-dispatch escalation counters
   (`MAX_BLOCKER_ESCALATIONS`, `MAX_DRIFT_INSPECTIONS`) depend on where the reconciled counter
   store ends up living.

## Risks & Mitigations

- **Risk**: silently relaxing the cumulative-cycle-budget guarantee when routing a single task
  through the batch path (item 5 combined with item 3) could let an operator bypass `MAX_CYCLES`
  by simply re-running `/orchestrate N` with the flag set, exactly the hazard the existing Stage 2
  comment calls out by name. **Mitigation**: item (3)'s reconciliation decision must be recorded
  explicitly in the plan (not left as an implicit side effect of item 5), and
  `test-session-runtime-files.sh` Case 3's scope note updated to state whether it still applies to
  batch-routed single-task runs.
- **Risk**: representing blocker-escalation/drift-inspection as ordinary dispatch rows could
  accidentally route them through `orchestrate-build-dispatch.sh`'s task-type agent resolution,
  silently changing which agent runs (task-type-routed implementer instead of `fork`/
  `reviser-agent`) — a decision-changing regression the dispatch's MUST NOT clause forbids
  ("change any decision the existing scripts make"). **Mitigation**: keep the fixed-agent
  selection explicit in whatever code emits these rows, and add a dedicated test asserting the
  emitted agent for these two row kinds is never task-type-resolved.
- **Risk**: `orchestrate-churn.sh` accidentally introduced as session-scoped (matching the
  loop-guard reconciliation direction chosen for item 3) would silently change the churn/
  three-strikes semantics from per-task to per-session, diverging from single-task's existing,
  tested behavior. **Mitigation**: keep churn state task-directory-scoped regardless of what item
  (3) decides for the loop-guard/burnout counter — the two state files answer different
  questions (churn: "has this specific task's blocker target failed repeatedly"; loop guard:
  "how much of this task's/session's cycle budget remains") and nothing in the current code
  couples their scoping.

## Appendix

- Search queries used: `grep -rn "orchestrate-churn"`, `grep -n "hard_mode\|churn\|burnout"` across
  both cycle scripts, `grep -n "MAX_CYCLES_MT\|hard_mode\|churn"` in `orchestrate-cycle-plan.sh`,
  `grep -rln "hard_mode\|--hard"` across `scripts/tests/*.sh`, `grep -n "multi-state\|mt_state_file"`
  in `orchestrate-cycle-plan.sh`.
- Confirmed absent on disk (per this research and task 144's prior filesystem check):
  `agent-system/extensions/core/scripts/orchestrate-churn.sh`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-churn.sh`.
- `specs/PATH.md` lines 132-220 ("One engine, batch of one" / "The four moves per cycle") and
  229-247 (Stage A table, including the A.5/148 row and the 2026-09-03 chain-progress note).
