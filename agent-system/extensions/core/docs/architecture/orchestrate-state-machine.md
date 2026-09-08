# /orchestrate State Machine Specification

**Status**: Current architecture — result of the unified workflow refactor's /orchestrate state machine component.

**See Also**: `handoff-schema.md`

---

## Overview

The `/orchestrate` command runs a fire-and-forget autonomous loop that drives one or more tasks
through their full lifecycle (research → plan → implement → complete) without user confirmation
between phases. The state machine is implemented inside `skill-orchestrate` (Pattern C:
Orchestrator/Routing skill) as a single four-move loop — see "The Orchestration Loop
(Batch-of-One and Multi-Task)" below — driven by `orchestrate-cycle-plan.sh`,
`orchestrate-build-dispatch.sh`, and `orchestrate-cycle-postflight.sh`. A batch of one task is not
a special case: it is the same loop with `task_numbers` of length one.

---

## Complete State Table

| State | Detected By | Action | Success Next | Failure Next |
|-------|-------------|--------|--------------|--------------|
| `not_started` | `state.json status = "not_started"` | `dispatch(plan, task_n)` — research on demand (Stage A.8): the default lifecycle is plan → implement; the planner itself requests a research phase via a `needs_research` verdict when the description does not suffice (see the `needs_research` fork footnote below) | `planned` | increment cycle, loop |
| `researching` | `status = "researching"` | `dispatch(research, task_n)` — no longer converged with `not_started` (that row now routes to `plan`, per the research-on-demand flip). `researching` has TWO producers: `preflight:research` (an ordinary in-flight research dispatch) and a planner's `needs_research` verdict (`postflight:needs_research`, see the `needs_research` fork footnote below) — the same resting state, reused rather than minting a new one. Also still reachable from a dead prior session's stale lock (see "Convergence: `researching`/`planning` No Longer Exit" below) | `researched` | increment cycle, loop |
| `researched` | `status = "researched"` | `dispatch(plan, task_n)` | `planned` | increment cycle, loop |
| `planning` | `status = "planning"` | `dispatch(plan, task_n)` — CONVERGED with `researched` (was: wait/re-check, exit with warning; see "Convergence: `researching`/`planning` No Longer Exit" below) | `planned` | increment cycle, loop |
| `planned` | `status = "planned"` | `dispatch(implement, task_n, orchestrator_mode=true)` | `implemented` | check blockers |
| `implementing` | `status = "implementing"` | `dispatch(implement, task_n, orchestrator_mode=true)` — resume | `implemented` | check blockers |
| `partial` (with handoff) | `.orchestrator-handoff.json` has a continuation pointer in either accepted form — nested `continuation_context.handoff_path` or flat top-level `continuation_path` (see `docs/architecture/handoff-schema.md`'s "Two Accepted Forms") | `dispatch(implement, task_n, continuation_context, orchestrator_mode=true)` (normalized to `{ handoff_path, orchestrator_mode: true }`) | `implemented` | check blockers |
| `partial` (with blockers) | `.orchestrator-handoff.json` has non-empty `blockers` array | `dispatch_blocker_escalation()` → revise → implement | `implemented` | increment cycle |
| `partial` (no handoff, cycle limit) | `cycle_count >= MAX_CYCLES` | Report state, exit | — | — |
| `partial` (infra cap) | `infra_failures >= MAX_INFRA_FAILURES` | Report connectivity issue, exit | — | — |
| `blocked`, discharged | `status = "blocked"`, all `dependencies[]` reached `status: "completed"`, and handoff carries no blockers | `dispatch(<phase>, task_n)` where `<phase>` is named by `previous_status` (research/plan/implement) | `researched`/`planned`/`implemented` | increment cycle |
| `blocked`, not discharged | `status = "blocked"`, and a dependency is outstanding, empty `dependencies[]`, a dependency is stuck non-completed-terminal, handoff blockers are present, or `previous_status` is missing | Read blockers from `state.json`, `dispatch_blocker_escalation()` | `planned` | increment cycle |
| `completed` | `status = "completed"` | Report success, exit | — | — |
| `abandoned` | `status = "abandoned"` | Report abandoned status, exit | — | — |
| `expanded` | `status = "expanded"` | Report expanded status, exit | — | — |

Each `dispatch(...)` call in the table above now performs the preflight status transition (to
`researching`/`planning`/`implementing`) immediately before invoking the Agent tool, so these
in-flight states are entered during the work window rather than only after the dispatch returns.
This is implemented via `skill_preflight_update()` (see `.claude/scripts/skill-base.sh`), called
from `orchestrate-cycle-plan.sh`'s own per-task live-dispatch loop — covering both effort modes
and every batch size uniformly, since the four-move loop rewrite deleted the single-task engine's
former "Stage 4: State Handlers" section entirely and consolidated per-task dispatch preflight
into this one script call site — immediately before that task's corresponding Agent dispatch
(composed in `skill-orchestrate/SKILL.md`'s Move 2), mirroring the `skill_postflight_update()`
call `orchestrate-cycle-postflight.sh` makes (Move 3) after the dispatch returns.

### Convergence: `researching`/`planning` No Longer Exit

The single-task engine's `researching` and `planning` state handlers (deleted along with the rest
of that engine by the four-move loop rewrite) used to exit the whole invocation with a warning
("another session is actively researching/planning — wait and re-run"), under the premise that a
live sibling session owned the in-flight work. That premise was already provably false whenever
those handlers were reachable at all, and the one surviving engine's design (see "Dependency
Gating Model" below) never re-introduces it: a task's own status among
`{researching, planning, ...}` never by itself removes it from eligibility, and
`orchestrate-cycle-plan.sh`'s per-task `task-lock.sh acquire` reclaims a stale lock (left behind
by a dead prior session) with a warning rather than refusing — a task stranded in `researching` or
`planning` is re-classified and re-dispatched (research or plan, respectively) exactly like any
other non-terminal status, never treated as a reason to exit. A task genuinely in flight under a
FRESH foreign lock is still never concurrently dispatched: the acquire refuses (exit 1) and the
task is deferred to a later cycle, never excluded and never added to `failed_tasks`.

The `partial` no-handoff/no-blockers sub-state (a normal shape for a base-mode dispatch, which
never writes a handoff) now dispatches `implement` on every cycle where budget remains, sourcing
resume context from the prior dispatch's `.return-meta.json`; the `partial` (no handoff, cycle
limit) row above is reached through the same generic end-of-cycle check that governs every other
non-terminating row, not through a dedicated early exit.

### The `needs_research` Fork (Research on Demand, Stage A.8)

The default lifecycle is `plan → implement`, not `research → plan → implement`: a fresh
(`not_started`) task dispatches straight to the PLANNER. The planner opens with an assessment
step (`agents/planner-agent.md`) — if the task description plus what it can read in the codebase
suffices to write a plan meeting `plan-format.md`, it plans normally (`planned`, converging with
the ordinary `researched → dispatch(plan) → planned` row above). If not, it writes NO plan and
returns `status: needs_research` in its `.return-meta.json`, carrying a focused
`research_questions` array naming what a research phase must establish.

`orchestrate-cycle-postflight.sh` resolves a `needs_research` outcome to its OWN verdict
(`verdict=needs_research`, `halt=false` — never the off-schema catch-all) and writes state.json
status `researching` — the SAME resting state `preflight:research` already produces, reusing the
existing `researching → dispatch(research)` classifier row rather than minting a new one — plus
the `research_questions` array (see `context/reference/state-management-schema.md`'s Research
Questions Field). The NEXT cycle's classifier therefore routes the task to `research` exactly as
it would for an ordinary `not_started`-turned-`researching` task; `orchestrate-cycle-plan.sh`
reads the persisted `research_questions`, joins them into a single string, and passes it as
`--focus` to `orchestrate-build-dispatch.sh` (an already-built, already phase-gated flag — no
change needed inside that script), so the research agent's dispatch file carries a `User focus:`
block naming exactly what to answer. Once research completes (`researched`), the task proceeds
to `plan` as normal — this time with a report on disk, so the planner's assessment step should
now find the description sufficient.

`--research` (the phase-forcing flag) is unrelated to and unaffected by this fork: it forces the
research phase first on a fresh task through the existing `force_phases_remaining` queue,
independent of the classifier default, and bypasses the planner's assessment entirely. A task
that already has a report is never asked again (the planner's assessment step only fires when no
report exists for the current round).

---

## State Transition Diagram (ASCII)

```
               ┌─────────────────────────────────────────┐
               │           /orchestrate start             │
               └─────────────────────────────────────────┘
                                    │
                             read state.json
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
         not_started           researched             planned /
              │                     │               implementing /
              ▼                     ▼                  partial
              └─────────►dispatch plan◄──────┘             │
                              │                             ▼
                    ┌─────────┴─────────┐            dispatch implement
                    │                   │            (orchestrator_mode)
              needs_research         planned                │
                    │                   │                   │
                    ▼                   │                   │
             dispatch research          │                   │
                    │                   │                   │
                    ▼                   │                   │
               researched               │                   │
                    │                   │                   │
                    └───►(loops back to dispatch plan,        │
                          research on demand, Stage A.8)      │
                                                               │
                                        ┌──────────────────┼──────────────────┐
                                        │                  │                  │
                                    success            partial+           partial+
                                        │              handoff            blockers
                                        ▼                  │                  │
                                   completed       re-dispatch            fork research
                                        │          implement               (warm cache)
                                        ▼           with                       │
                                      EXIT       continuation              read findings
                                              context                          │
                                                    │                     dispatch revise
                                                    │                          │
                                                    │                  re-dispatch implement
                                                    │                          │
                                                    └─────────►────────────────┘
                                                                               │
                                                                         cycle_count++
                                                                               │
                                                              ┌────────────────┤
                                                              │                │
                                                       < MAX_CYCLES      >= MAX_CYCLES
                                                              │                │
                                                           loop back         EXIT
                                                          to dispatch      (partial)
```

The `not_started`/`researched` fork at the top merges into a single `dispatch plan` node
(research on demand, Stage A.8): `not_started` now goes straight to `plan`, and the planner
itself forks back out to `dispatch research` only on a `needs_research` verdict, looping back to
`dispatch plan` once research completes. See "The `needs_research` Fork" above for the full
narrative.

---

## MAX_CYCLES Enforcement

```bash
MAX_CYCLES=5            # Maximum dispatch cycles per /orchestrate invocation
MAX_INFRA_FAILURES=3    # Maximum corroborated Agent-tool transport/API failures per invocation

# Loop guard file: specs/{NNN}_{SLUG}/.orchestrator-loop-guard
# Schema:
{
  "session_id": "sess_...",
  "cycle_count": 2,
  "max_cycles": 5,
  "infra_failures": 0,
  "max_infra_failures": 3,
  "last_recovered_phases_completed": 2,   # optional; written only by the Stage 5 recovery grep
  "last_recovered_phases_total": 6,       # optional; written only by the Stage 5 recovery grep
  "current_state": "planned",
  "started": "2026-05-22T00:00:00Z",
  "last_updated": "2026-05-22T00:30:00Z"
}
```

The two last_recovered_* fields are optional and diagnostic: they appear only after a
missing/stale-handoff recovery event, are read back with a jq default, and never participate in
any cap or status transition.

The loop guard file is created at the start of an `/orchestrate` invocation and updated after each
dispatch cycle. It persists between conversational turns so a resumed `/orchestrate` invocation
sees the accumulated cycle count.

**On cycle limit**: The task is left in `partial` state. The orchestrator reports: "Task {N} reached
MAX_CYCLES limit. Run `/orchestrate {N}` again to continue, or `/implement {N}` to resume manually."

### Infra-Failure vs. Work-Cycle Discrimination

`cycle_count` and `infra_failures` are two separate, independently capped counters. A missing
`.orchestrator-handoff.json` is charged against `cycle_count` (a genuine work cycle) unless BOTH
of two corroborating signals agree the Agent tool call itself failed at the transport/API layer
with no subagent execution at all — in which case it is charged against `infra_failures`
instead, up to `MAX_INFRA_FAILURES`. See
`context/patterns/infra-failure-discrimination.md` for the full two-signal rule, the conservative
"either signal alone charges" default, and the `MAX_CYCLES + MAX_INFRA_FAILURES` worst-case
iteration bound. On reaching `MAX_INFRA_FAILURES`, the orchestrator exits `partial` with a
message distinct from the `MAX_CYCLES` message, so a log reader can tell "connectivity problem"
apart from "ran out of work budget."

---

## Blocker Escalation: 5-Step Sequence

When a dispatch returns with non-empty `blockers` in the orchestrator handoff:

```
Step 1: DETECT
  Read .orchestrator-handoff.json
  blockers = jq -c '.blockers // []' handoff.json
  If blockers array is non-empty: escalate=true

Step 2: RESEARCH FORK (subagent_type: "fork")
  blocker_desc = jq -r '.[0].description' blockers
  Invoke Agent tool:
    subagent_type: "fork"
    prompt: "Research this blocker for task $N: $blocker_desc. Find root cause and solution path."
    context: { task_number, session_id, blocker, orchestrator_mode: false }
  Read .orchestrator-handoff.json → research findings

Step 3: READ FINDINGS
  findings = jq -r '.summary' .orchestrator-handoff.json
  artifact = jq -r '.artifacts[0].path' .orchestrator-handoff.json

Step 4: REVISE PLAN
  Invoke Agent tool:
    subagent_type: "reviser-agent"
    prompt: "Revise plan for task $N to address blocker: $blocker_desc. Findings: $findings"
    context: { task_number, session_id, research_findings, plan_path, orchestrator_mode: false }
  Reviser reads current plan + research findings, writes new plan version

Step 5: RE-DISPATCH IMPLEMENT
  Invoke Agent tool:
    subagent_type: $IMPLEMENT_AGENT  (resolved by task_type inside orchestrate-cycle-plan.sh's resolve_agent())
    prompt: "Implement task $N following the revised plan."
    context: { task_number, session_id, orchestrator_mode: true, plan_path }
  Fresh implementation with revised plan
```

---

## Context Flatness Guarantee

On the normal path the orchestrator never reads `.orchestrator-handoff.json` directly — it never
opens research reports, plan files, implementation summaries, or the raw handoff object for
comprehension during its state machine loop. Instead, after every dispatch (both engines, Move 3)
it invokes `orchestrate-cycle-postflight.sh`, which performs the sanctioned handoff read (gated by
mtime staleness and the `dispatch_seq` identity check) and every recovery fallback internally, and
returns one compact JSON line the lead actually consumes:

```bash
postflight_json=$(bash .claude/scripts/orchestrate-cycle-postflight.sh "$t" \
  --session "$session_id" --state-file specs/state.json --phase "$phase" \
  --task-dir "$task_dir_rel" --task-type "$task_type" --agent "$agent" \
  --plan-path "$plan_path_for_task" --cycle-count "${cycle_count:-0}" \
  --transport-error "${task_transport_error:-false}" --force-invoked "$force")
dispatch_status=$(echo "$postflight_json" | jq -r '.status')
verdict=$(echo "$postflight_json" | jq -r '.verdict')
halt=$(echo "$postflight_json" | jq -r '.halt')
```

Three narrow, grep-only exceptions to "the lead never reads artifact content" are sanctioned
elsewhere in the loop (adversarial-verification grep, next-phase selection grep, and the phase-marker
recovery grep, the last of which lives *inside* `orchestrate-cycle-postflight.sh` itself, not in
the lead); see the exception table in `docs/architecture/handoff-schema.md` for the full
accounting, and `docs/architecture/orchestrate-cycle-postflight.md`'s own
`## Context Flatness: What Each Read Is Bounded To` section for exactly what that script reads on
the lead's behalf (never restated here).

Per-task-per-cycle growth is a **measured** figure, not an estimate: **871 bytes** (~218 tokens),
produced by `scripts/tests/test-orchestrate-context-growth.sh` — a disposable 3-task fixture cycle
through the real `orchestrate-cycle-plan.sh` / `orchestrate-build-dispatch.sh` /
`orchestrate-cycle-postflight.sh` call graph. Re-run that suite (deterministic; it prints a
`PER_TASK_PER_CYCLE_BYTES:` line) to reproduce or re-derive the number after a future change,
rather than trusting this sentence. The measured total breaks down as: an amortized share of one
`orchestrate-cycle-plan.sh` call's `plan_json` per cycle (~234 B/task on a 3-task batch — this
includes real, currently-unfiltered noise from `update-task-status.sh`'s unredirected preflight
`echo`, not just the clean JSON), the Move 2 pointer prompt plus Context object per task (~463 B),
and the Move 3 `orchestrate-cycle-postflight.sh` compact JSON per task (~174 B).

---

## Example Flows

### Normal Flow (specification-shaped task, no research needed)

Research on demand (Stage A.8): a task whose description already carries the defect, the
evidence, the work list, and the acceptance bar needs no research phase at all.

```
Cycle 1: status=not_started → dispatch plan
         planner's opening assessment: description + codebase reads suffice
         handoff: {status: "planned", summary: "4-phase plan created..."}
         state.json: status → planned

Cycle 2: status=planned → dispatch implement (orchestrator_mode=true)
         handoff: {status: "implemented", summary: "All 4 phases complete..."}
         state.json: status → completed

EXIT: Task {N} completed successfully.
```

### Research-on-Demand Flow (planner requests research)

A task whose plan would otherwise rest on guesses about facts an agent can establish (an
external API, an unfamiliar code path, literature) routes to research — but only because the
PLANNER asked, not because the orchestrator or a keyword heuristic decided.

```
Cycle 1: status=not_started → dispatch plan
         planner's opening assessment: description + codebase reads do NOT suffice
         .return-meta.json: {status: "needs_research", artifacts: [],
                              research_questions: ["Does library X expose a streaming API?", ...]}
         postflight: verdict=needs_research, halt=false
         state.json: status → researching, research_questions persisted

Cycle 2: status=researching → dispatch research
         dispatch file carries "User focus: Does library X expose a streaming API?; ..."
         (research_questions joined via --focus, see "The needs_research Fork" above)
         handoff: {status: "researched", summary: "Confirmed X's streaming API..."}
         state.json: status → researched

Cycle 3: status=researched → dispatch plan
         planner's opening assessment now succeeds (report on disk)
         handoff: {status: "planned", summary: "4-phase plan created..."}
         state.json: status → planned

Cycle 4: status=planned → dispatch implement (orchestrator_mode=true)
         handoff: {status: "implemented", summary: "All 4 phases complete..."}
         state.json: status → completed

EXIT: Task {N} completed successfully.
```

### Partial Recovery Flow

```
Cycle 1: status=planned → dispatch implement (orchestrator_mode=true)
         Agent context exhausted after phase 2
         Agent writes continuation handoff to handoffs/phase-2-handoff-T.md
         handoff (flat form — what a live H9 hard-mode wrap-up writer actually emits; see
         handoff-schema.md's "Two Accepted Forms"): {
           status: "partial",
           phases_completed: 2,
           phases_total: 4,
           continuation_path: "specs/593_.../handoffs/phase-2-handoff-T.md"
         }

Cycle 2: read continuation_context from handoff
         dispatch implement with continuation_context embedded
         (orchestrator_mode=true preserved in continuation_context)
         handoff: {status: "implemented", phases_completed: 4, phases_total: 4, ...}
         skill_gate_completion_claim(593, 4, 4, ..., "[orchestrate]") → Case 2/3, ALLOW

EXIT: Task {N} completed successfully.
```

### Completion-Claim Refusal Flow

A `status: "implemented"` handoff does not unconditionally flip the task to `completed`.
`orchestrate-cycle-postflight.sh` — the single shared per-task postflight body for every batch
size and effort mode (Move 3) — calls `skill_gate_completion_claim` before the postflight
transition. On a Case 1 (phase accounting present but incomplete) or Case 3 (phase accounting
absent and `plan_markers_verified` not `true`) refusal:

- No status transition happens this cycle — the task stays `implementing`.
- `cycle_count` still increments (the only exemption is a corroborated infra failure).
- The gate has already logged which case fired to stderr.
- The next cycle's Move 1 re-classifies the task from its still-`implementing` status and
  re-dispatches implement against the same plan, which resumes at the first non-completed phase.
- The existing `MAX_CYCLES` (base) / `MAX_CYCLES_MT` (multi-task) caps bound the retry — a
  persistently misreporting agent exits via the cap, not an infinite loop. See
  `handoff-schema.md`'s `plan_markers_verified` section for the full three-case gate contract and
  the four greppable log-line shapes.

### Blocker Escalation Flow

```
Cycle 1: status=planned → dispatch implement (orchestrator_mode=true)
         Implementation stuck: API not responding
         handoff: {
           status: "partial",
           blockers: [{
             description: "API endpoint returns 404; integration pattern unclear",
             phase: "phase-2",
             severity: "hard"
           }]
         }

Cycle 2: BLOCKER ESCALATION
  Step 2: fork research (is_blocker_escalation=true)
          Prompt: "Research: API endpoint 404 — integration pattern for..."
          Returns: {status: "researched", summary: "Found: use /v2 endpoint instead of /v1..."}

  Step 4: dispatch revise
          Prompt: "Revise plan using research findings: [findings text]"
          Returns: new plan version 02_revised-plan.md

  Step 5: re-dispatch implement (orchestrator_mode=true)
          handoff: {status: "implemented", ...}

EXIT: Task {N} completed successfully.
```

---

## The Orchestration Loop (Batch-of-One and Multi-Task)

**This is the sole design.** There is one engine, not two: a single-task-number invocation is
simply a batch of size one through the same lifecycle-cycling loop, dependency-aware gating, and
parallel-dispatch machinery described below. The former single-task state machine (Stages 0-8,
one dedicated stage per lifecycle state) has been deleted outright — it predated the extraction
of `orchestrate-cycle-plan.sh`/`orchestrate-build-dispatch.sh`/`orchestrate-cycle-postflight.sh`
and duplicated logic those three scripts now own for every batch size uniformly. The historical
single-task Complete State Table and transition diagram above remain accurate as a description of
per-task state transitions — every task in a batch still moves through exactly those states — but
the dispatch/postflight mechanics that drive those transitions are the four-move loop below, run
once per cycle across however many tasks the batch contains (one or many), never a parallel or
alternate code path keyed on batch size.

The loop drives every task in the batch through its full lifecycle (research -> plan -> implement
-> completed) using a lifecycle-cycling loop with dependency-aware gating and parallel dispatch.

### Lifecycle-Cycling Loop (the Four-Move Loop's Move 1 and Move 3)

Steps 1-5 below, plus the `cycle_count++`/`MAX_CYCLES_MT` accounting and the inter-cycle redeploy
checkpoint (formerly described as step 8), are not inline `SKILL.md` prose/jq — they are ONE call
to `scripts/orchestrate-cycle-plan.sh`, made once per cycle by the lead (`SKILL.md`'s own text for
this move is that one call plus a loop of at most ten lines composing the batched Agent-tool
message from the script's `dispatch[]` rows — see `SKILL.md`'s "Move 1: Plan the cycle" and
"Move 2: Dispatch" sections). This diagram states the CONCEPTUAL loop shape, unchanged in
behavior since before the single-task engine's deletion; the EXECUTABLE source of truth for steps
1-5/8 is that script's own header comment (`mt_state_file` field list, the bare-vs-suffixed
`session_id` invariant, the `--dry-run` design, and the re-sited budget-guard/redeploy-checkpoint
timing note — the script runs strictly BEFORE its own cycle's Agent dispatches, so its budget
guard sits at the TOP of each invocation and its redeploy checkpoint consumes the PRIOR cycle's
`cycle_modified_files` rather than the current one). Steps 6-7 (read handoffs, per-task
postflight) are `SKILL.md`'s "Move 3: Postflight" section, which delegates the entire per-task
postflight body to `orchestrate-cycle-postflight.sh` (one call per dispatched task, after every
Move 2 Agent call has returned).

```
┌──────────────────────────────────────────────────┐
│         MT Lifecycle-Cycling While Loop          │
│                                                  │
│  ┌─────────────────────────────────────────┐     │
│  │ 1. Refresh statuses from state.json     │     │
│  │    for every task in task_numbers[]     │     │
│  │    [scripts/orchestrate-cycle-plan.sh]  │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 2. All-terminal check                   │     │
│  │    all tasks in {completed, abandoned,  │     │─── YES ──► EXIT (success)
│  │    expanded, failed_tasks}?             │     │
│  │    [scripts/orchestrate-cycle-plan.sh]  │     │
│  └──────────────────┬──────────────────────┘     │
│                     │ NO                         │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 3. Build eligible_tasks[]               │     │
│  │    Filter each task:                    │     │
│  │    (a) not terminal                     │     │
│  │    (b) all predecessors terminal        │     │
│  │    (eligibility is not status-gated on  │     │
│  │    an in-flight string -- see Dependency│     │
│  │    Gating Model below)                  │     │
│  │    [scripts/orchestrate-cycle-plan.sh]  │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 4. No-eligible circuit breaker          │     │
│  │    eligible_tasks[] is empty?           │     │─── YES ──► EXIT (partial)
│  │    [scripts/orchestrate-cycle-plan.sh]  │     │
│  └──────────────────┬──────────────────────┘     │
│                     │ NO                         │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 5. Phase-aware dispatch decision         │     │
│  │    (classification, admission, forced   │     │
│  │    phases, lock probe, dispatch-file     │     │
│  │    build) -- returns dispatch[] rows     │     │
│  │    [scripts/orchestrate-cycle-plan.sh]  │     │
│  │    ─────────────────────────────────    │     │
│  │    Lead issues ALL Agent calls named by │     │
│  │    dispatch[] in ONE message (concurrent│     │
│  │    parallel execution) [SKILL.md]       │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 6. Read handoffs for every dispatched   │     │
│  │    task (after ALL Agents complete)     │     │
│  │    [SKILL.md Move 2/Move 3]     │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 7. Per-task postflight                  │     │
│  │    skill_postflight_update + artifact   │     │
│  │    linking + per-task scoped commit +   │     │
│  │    multi-state update                   │     │
│  │    [SKILL.md Move 2/Move 3]     │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 8. cycle_count++ / MAX_CYCLES_MT guard  │     │─── HIT ──► EXIT (partial)
│  │    + inter-cycle redeploy checkpoint    │     │       (via `stop` on the
│  │    [scripts/orchestrate-cycle-plan.sh,  │     │        NEXT cycle's call)
│  │     at the TOP of the next invocation]  │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│                     └──────────────────────────► │
│                        (back to step 1)          │
└──────────────────────────────────────────────────┘
```

### Auxiliary Dispatch (`aux_dispatch[]`)

**Added (task that ported single-task's Stage 5a/5b/6 auxiliary flows into the batch engine)**:
alongside step 5's `dispatch[]` rows, `scripts/orchestrate-cycle-plan.sh` emits a SIBLING array,
`aux_dispatch[]`, for `drift-inspection`/`blocker-research`/`plan-revision`/`divergence-audit`
work — single-task's own Stage 5a Drift Inspection, Stage 5b's H5 three-strikes divergence-audit
dispatch, and Stage 6 Blocker Escalation's research-fork/plan-revision steps, each having no
task-type to route by (their agent is FIXED per kind: `fork`, `fork`, `reviser-agent`, or the
task's own already-resolved research agent). The full decision record — why a sibling array
rather than widening `dispatch[]`'s own `phase` vocabulary, the escalation caps
(`MAX_BLOCKER_ESCALATIONS`/`MAX_DRIFT_INSPECTIONS`), the `.blocker-research.json`/
`.drift-inspection.json` chaining into a follow-on `plan-revision` row, and the hard/base-mode
mutual exclusion between `divergence-audit` and `drift-inspection` — lives in that task's own
plan (Decision 2) and in `orchestrate-cycle-plan.sh`'s header comment; it is not restated here.

Dispatch composition mirrors step 5's own `dispatch[]` loop exactly, as a second adjacent loop in
`SKILL.md`'s Move 2 over `aux_dispatch[]` instead: same single-message batching rule, but
`orchestrator_mode: false` and no `handoff_path`. An aux row NEVER reaches Move 3's per-task
postflight and NEVER contributes to `failed_tasks` — its only effect is a written file or a
revised plan for a LATER cycle's `dispatch[]` to pick up.

The hard-mode burnout circuit-breaker (single-task Stage 3b-hard, deleted along with that engine)
has a counterpart in the one surviving engine too, `SKILL.md`'s own Move 1 "Hard-mode burnout
gate" paragraph: the same three self-checks, reused verbatim rather
than duplicated, with the signal-firing action replaced by one call to
`scripts/orchestrate-churn.sh --burnout-signal`.

### Batch Size Cap (MAX_TASKS)

Before entering multi-task dispatch, the batch size is capped at `MAX_TASKS=8`. A request
exceeding it is **trimmed to the first 8 tasks**, with a loud warning that batching proper is not
yet supported:

```bash
task_count=${#validated_tasks[@]}
MAX_TASKS=8
if [ "$task_count" -gt "$MAX_TASKS" ]; then
  echo "[orchestrate] WARNING: $task_count tasks exceeds MAX_TASKS=$MAX_TASKS."
  echo "Batching is not yet supported. Running with first $MAX_TASKS tasks only."
  validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")
  # Recalculate waves for the trimmed task list
fi
```

### Dependency Gating Model

Tasks progress through lifecycle phases independently. A task becomes eligible when:
1. Its current status is not terminal (`completed`, `abandoned`, `expanded`) and not in `failed_tasks`
2. All of its predecessors in the dependency graph are in a terminal state

**Eligibility is NOT status-gated on an in-flight string.** A task's own status among
`{not_started, researched, planned, implementing, partial, researching, planning}` never by
itself removes it from eligibility — concurrency safety is enforced downstream, by locks and
`file_scope` overlap, not by the status string. A task stranded in `researching`/`planning` by a
dead prior session's stale lock is admitted to `eligible_tasks`, classified by
`scripts/orchestrate-triage-classify.sh` to the phase its status names (`researching` ->
research, `planning` -> plan), and dispatched — `orchestrate-cycle-plan.sh`'s per-task `task-lock.sh acquire`
reclaims the stale lock with a warning. A task genuinely in flight under a FRESH foreign lock is
still never concurrently dispatched: `task-lock.sh acquire` refuses (exit 1) and the task is
removed from that cycle's dispatch batch (never excluded, never added to `failed_tasks`) — this
is the same defer-not-exclude gate `file_scope_collision` already uses.

If a predecessor is `failed`, the dependent task is immediately moved to `failed_tasks` with status `blocked`.

If a predecessor is still in-progress (e.g., `researched`, `planned`), the dependent task waits until the next cycle when the predecessor reaches terminal state.

### Commit Granularity

One commit per task per phase transition, issued inside `orchestrate-cycle-postflight.sh`'s per-task postflight body (Move 3)
(step 5.5) — never a combined end-of-batch commit. MT mode used to fire exactly one commit at the
very end of a combined batch step, folding every task's diff and index rows into a single,
unrevertable commit; that batch commit is retired, and each task's own change is committed
the moment its own phase transition lands, at the same granularity a solo `/implement` run
produces. All commits route through the shared `git-commit-scoped.sh` helper, preserving
path-scoped staging, the `specs/.commit-lock/` commit mutex, and automatic ephemeral-runtime-file
exclusion — see `context/standards/git-staging-scope.md`'s "Multi-Task Application" subsection for
the full per-task scope contract. This section is the source of truth for MT commit granularity.

**Exit-path coverage** — every MT terminal outcome and where its commit is issued:

| Outcome | Commit issued where |
|---------|---------------------|
| `completed` | Move 3's per-task postflight iteration (`orchestrate-cycle-postflight.sh`), (message: complete research/plan/implementation, per that task's `dispatch_status`) |
| `failed` | Move 3's postflight body still runs for a failed dispatch; artifacts and status changes it produced are real and committed |
| `blocked` | Move 3's postflight body still runs; same reasoning as `failed` |
| Partial (gate-refused, or `MAX_CYCLES_MT` reached mid-loop) | Move 3's postflight body runs at the partial-form message on every cycle that reaches it, including the cycle where `MAX_CYCLES_MT` is hit |
| Deferred self-modifying (a task whose own dispatch is deferred rather than run this cycle) | Never dispatched and never status-mutated this cycle, so it correctly produces no commit this cycle — it becomes eligible, and committable, on a later cycle |
| Deferred-by-redeploy-checkpoint (a task excluded for the remainder of the invocation because the inter-cycle redeploy checkpoint's deploy/verify gate failed) | Never dispatched and never status-mutated for the rest of this invocation; distinct operator remedy from deferred-self-modifying — see `### The Inter-Cycle Redeploy Checkpoint` in `context/patterns/batch-orchestration-guardrails.md` |

**Residue check** (non-blocking, run by Move 4 after the lifecycle-cycling loop exits): warns
only, and never commits — a blanket commit here would recreate exactly the entanglement per-task
commits were introduced to remove.

```bash
residue=$(git status --porcelain -- specs/ 2>/dev/null)
if [ -n "$residue" ]; then
  echo "[orchestrate] WARNING: uncommitted residue under specs/ after batch completion:" >&2
  echo "$residue" >&2
  echo "[orchestrate] Per-task commits are issued inside the skill's per-task postflight; review and commit manually." >&2
fi
```

### Exit Conditions

| Condition | Exit Status | Description |
|-----------|-------------|-------------|
| All tasks terminal | `completed` (if 0 failed) or `partial` | Normal completion |
| No eligible tasks | `partial` | Deadlock or all blocked |
| MAX_CYCLES_MT hit | `partial` | Cycle budget exhausted |

`MAX_CYCLES_MT = min(task_count * 5, 25)`

**Per-task infra-failure cap**: a missing handoff for an individual task in Move 3 is deferred
(not marked `failed_tasks`) when it corroborates as an infra failure — see
`context/patterns/infra-failure-discrimination.md` — up to `MAX_INFRA_FAILURES = 3` (flat per
task, not scaled by `task_count`). The shared `MAX_CYCLES_MT` counter still increments once per
wave cycle regardless of any individual task's infra verdict, so the outer loop remains bounded
independent of this per-task cap; a task that keeps corroborating as an infra failure past
`MAX_INFRA_FAILURES` falls back to the historical `failed_tasks` behavior rather than being
deferred forever.

### MT Example Flow: 2 Independent Tasks

```
Initial: Task A (not_started), Task B (not_started)
         Dependency graph: {} (no dependencies between A and B)

--- Cycle 1 ---
Refresh: A=not_started, B=not_started
All-terminal: NO
Eligible: [A, B]  (both not_started, no dependencies)
Dispatch: research A + research B  (ONE message, 2 Agent calls)
After agents complete: read handoffs for A and B
Postflight: A -> researched (commit), B -> researched (commit)
cycle_count: 1

--- Cycle 2 ---
Refresh: A=researched, B=researched
All-terminal: NO
Eligible: [A, B]  (researched is not terminal, not in-flight)
Dispatch: plan A + plan B  (ONE message, 2 Agent calls)
After agents complete: read handoffs for A and B
Postflight: A -> planned (commit), B -> planned (commit)
cycle_count: 2

--- Cycle 3 ---
Refresh: A=planned, B=planned
All-terminal: NO
Eligible: [A, B]  (planned -> implement)
Dispatch: implement A + implement B  (ONE message, 2 Agent calls)
After agents complete: read handoffs for A and B
Postflight: A -> completed (commit), B -> completed (commit)
cycle_count: 3

--- Cycle 4 ---
Refresh: A=completed, B=completed
All-terminal: YES -- break

EXIT: All 2 tasks completed. Cycles used: 3/10.
```

---

## Loop-Owned Runtime State: `mt_state_file` Field Reference

**This is now the only engine's runtime state file** — `specs/.orchestrator-multi-state-${session_id}.json`, initialized once per invocation (including a single-task-number invocation, which is simply a batch of one). The field list below is the authoritative reference; `skill-orchestrate/SKILL.md` itself carries only the initialization call, not this narrative.

Core identity and counters: `session_id`, `task_numbers`, `waves` (diagnostic echo, recorded not consumed — eligibility is re-derived fresh every cycle from current task statuses plus `dependency_graph`, never from a pre-computed wave schedule), `max_cycles` (`min(task_count * 5, 25)`), `cycle_count: 0`, `failed_tasks: []`, `completed_tasks: []`, `current_statuses: {}`, `task_dirs: {}`, `research_agents: {}`, `implement_agents: {}`, `descriptions: {}` (map task_num -> task description, written once per task and read by dispatch composition for both prompt interpolation and Dispatch Prep's hard-required `description` precondition), `infra_failures: {}` (map task_num -> count, default 0, flat `MAX_INFRA_FAILURES=3` per task — not scaled by `task_count`), `dispatch_start_ts: {}` (map task_num -> unix seconds, written at dispatch time), `dispatch_seq_counter: 0` (batch-scoped monotonic counter, never repeats a value across the whole batch), `dispatch_seq: {}` (map task_num -> the `dispatch_seq` minted for that task's most recent dispatch).

`deferred_self_modifying: []` — an APPEND-ONLY OBSERVATION LOG (persists across every cycle of this same `mt_state_file`, never reset mid-invocation) of task numbers the self-modification gate has deferred at least once this invocation. It is NOT an eligibility-exclusion set: a task appearing in this log is not thereby excluded from a later cycle's `eligible_tasks`. The defer is re-evaluated fresh every cycle from `eligible_tasks` and the candidate's own `file_scope`, using the same convergence mechanism `file_scope_collision` uses, and clears on its own once the co-dispatched sibling that caused it leaves `eligible_tasks`. A second, independent, per-cycle exit condition also bounds this: the designated-candidate tie-breaker inside `orchestrate-batch-admit.sh` admits exactly one self-modifying candidate (the lowest task number) on every cycle, so N self-modifying candidates converge to full dispatch in at most N cycles by construction.

**In-flight session registry** (adjacent to, not part of, `mt_state_file`): the batch registers under its bare `session_id`, with the full `task_numbers` set as the CSV, via `task-lock.sh session-register`. Best-effort and non-blocking — a registration failure never affects any admission, dispatch, or eligibility decision.

Two invocation-scoped fields backing the inter-cycle redeploy checkpoint (full contract in `context/patterns/batch-orchestration-guardrails.md`'s "The Inter-Cycle Redeploy Checkpoint" subsection): `deferred_deploy_checkpoint: []` (task numbers excluded for the remainder of the invocation because a checkpoint gate — `deploy-headless.sh` or `verify-deploy.sh` — failed; a distinct set from `deferred_self_modifying`, since the two causes have different operator remedies) and `deployed_critical_paths: []` (critical paths already redeployed this invocation, backing the idempotence guard so the checkpoint does not re-fire on the same path every cycle). Alongside them: `consecutive_no_dispatch_cycles: 0` (increments on any cycle where `eligible_tasks` was non-empty but the self-modification gate deferred every member of it; resets to 0 on any cycle where at least one task dispatches — bounds the narrow non-convergence mode a removed permanent exclusion set no longer prevents by construction), and `verify_deploy_baseline_notices: []` (an append-only observation log of every checkpoint firing that proceeded past a pre-existing, or confirmed flaky/unrelated, `verify-deploy.sh` failure; entries shaped `{"cycle": <int>, "gate": "verify-deploy.sh", "pre_findings": <int>, "post_findings": <int>, "new_findings": <int>, "post_exit": <int>, "filtered": <bool>}`, where `filtered:false` marks the original, temporally-pre-existing case (`new_findings` always `0`) and `filtered:true` marks the confirmation/attribution-filtered case (`new_findings` is the pre-filter candidate count; the entry additionally carries `flaky_count`/`flaky_findings`, `unrelated_count`/`unrelated_findings`, and `blocking_count: 0` — see `context/patterns/batch-orchestration-guardrails.md`'s "Confirmation and attribution filters" subsection for the full filter pipeline); never read by any eligibility check, all-terminal check, circuit breaker, convergence guard, or admission branch — written for reporting only, read and rendered at the batch-postflight move; never merged into `defer_ledger`).

Two more fields back the **forward-progress invariant** (full contract in `context/patterns/batch-orchestration-guardrails.md`'s "The Forward-Progress Invariant" subsection): `defer_ledger: []` (an append-only observation log of every per-cycle defer/exclusion event, entries shaped `{"task": <int>, "defer_reason": <string>, "collision_scope": <string|null>, "cycle": <int>, "detail": <string>}`, with one `defer_reason`-specific extension: a `"deploy_checkpoint"` entry reached via the confirmation/attribution filter pipeline (see `context/patterns/batch-orchestration-guardrails.md`'s "Confirmation and attribution filters" and "Gate depth" subsections) also carries `depth_disagreement: <bool>`, set `true` when `deploy-headless.sh`'s own `--skip-slow` verify passed yet the checkpoint's full-depth comparison still found a blocking finding; never read by any eligibility/admission decision, not a fifth admission gate, additive to `deferred_self_modifying` and `deferred_deploy_checkpoint` rather than a replacement) and `detected_defects: []` (an append-only observation log of every system-defect detection that fired during the run; the single canonical definition of the field's contract across the whole engine, since there is only one engine file). `detected_defects` entries are shaped `{"task": <int>, "defect_class": <string>, "attributed_source_path": <string>, "detecting_site": <string>, "cycle": <int>, "detail": <string>, "record_result": <string|null>}`, and `task` is always populated. The append fires whenever the caller's own detection fires and is never gated on `system-defect-record.sh`'s exit code or a suppression value — the recorder's dedup key is cross-run, while this log answers "what fired during THIS run." Each append emits `[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=<CLASS> attributed_path=<PATH> detecting_site=<SITE>` immediately, so a detection is never a silent no-op. **Absolute constraint**: no site in this mechanism may call `AskUserQuestion` — `orchestrator_mode` means no human is watching mid-run, so accumulate-then-render is the deterministic default (this is a distinct, unrelated mechanism from the `user_decision`/`AskUserQuestion` relay the loop's branch move performs; do not conflate the two). `detected_defects` is additive to `defer_ledger` and to `verify_deploy_baseline_notices`, never merged into either — three separate logs, three separate operator remedies. It is never consulted by `exit_status` branch selection: a batch that succeeded and also observed a defect is still a successful batch.

`forward_progress_violated: false` — initialized false, computed and written once at the batch-postflight move from `dispatch_start_ts`; never read by any loop condition. `idle_overlap_ledger: []` — an append-only observation log of every admitted verdict a cycle carries with a non-empty `idle_overlap_advisory`, entries shaped `{"task": <int>, "colliding_task_number": <int>, "colliding_task_status": <string>, "overlapping_path": <string>, "cycle": <int>}`; follows `defer_ledger`'s exact MUST NOT — never read by any eligibility/admission decision, and never merged into `defer_ledger` since the candidates it names were admitted, not deferred.

## Consolidated Output and Exit-Status Resolution

After the lifecycle-cycling loop exits (all terminal, no eligible tasks, or the cycle cap reached), the loop's own postflight/branch move:

1. Reads `completed_tasks`, `failed_tasks`, `deferred_self_modifying`, `deferred_deploy_checkpoint`, `dispatch_start_ts`, `defer_ledger`, `idle_overlap_ledger`, `verify_deploy_baseline_notices`, `detected_defects`, `current_statuses`, and `cycles_used` from `mt_state_file`.
2. Computes the forward-progress invariant: `forward_progress_violated = true` when `task_numbers` is non-empty and `dispatch_start_ts` is an empty object at loop exit; otherwise `false`. This is cause-agnostic — true regardless of which `defer_reason` produced the zero-dispatch outcome.
3. Determines `exit_status` (the skill-status vocabulary normatively defined in `context/formats/return-metadata-file.md`, distinct from the `tasks_completed` array's `state.json` vocabulary):
   - `forward_progress_violated == true` -> `"partial"`, taking precedence over the `"implemented"` branch below. Without this precedence a batch that dispatched nothing because every candidate hit `file_scope_collision` would satisfy the `"implemented"` branch with an empty `completed_tasks` array — a batch that did nothing reporting success. This is a status-legibility correction only: no verdict, task status, or `state.json` write is affected.
   - `failed_count == 0` AND every task in `deferred_self_modifying` reached a terminal state by loop exit AND `deferred_deploy_checkpoint` is empty -> `"implemented"`. A task that was deferred at least once but went on to dispatch and complete before loop exit is a success, not a partial — the observation log records history, not an outstanding obligation.
   - `failed_count > 0` OR any task in `deferred_self_modifying` is still non-terminal at loop exit OR `deferred_deploy_checkpoint` is non-empty -> `"partial"`. A non-empty `deferred_deploy_checkpoint` alone still yields `"partial"` — that set retains its permanent-exclusion semantics.
   - `verify_deploy_baseline_notices` and `detected_defects` are NEVER consulted by this branch selection — both are pure observation logs with no bearing on `exit_status`. A batch that ran to completion past a pre-existing `verify-deploy.sh` failure, or that also observed a system-defect detection, is still `"implemented"`.
4. Reports `deferred_self_modifying` tasks as **deferred at least one cycle by the self-modification gate** — an observation, not an outstanding-work category — with each task's final status at loop exit. Reports `deferred_deploy_checkpoint` tasks as a distinct **deferred-by-redeploy-checkpoint** category (different operator remedy: resolve the deploy/verify failure, redeploy manually, then re-run on the remaining task numbers). Reports `verify_deploy_baseline_notices` and `detected_defects`, when non-empty, each as their own distinct category — never folded together, never omitted merely because the batch otherwise succeeded — and `idle_overlap_ledger`, when non-empty, as a distinct **admitted (idle overlap advisory)** category, since its entries are admits, not exclusions. When `forward_progress_violated` is true, the summary additionally leads with a zero-dispatch banner enumerating every `defer_ledger` entry with its `defer_reason`, and a re-run sequence ordering the deferred/excluded task numbers predecessor-first from `dependency_graph`.
5. **Emits the consolidated output**: read `context/patterns/orchestrate-batch-results-template.md` and render the batch results using that template exactly — its per-section rendering conditions are contract, not commentary. This is the template's sole caller.
6. Writes `specs/.return-meta-multi-${session_id}.json` with `status` (the closed `"implemented"`/`"partial"`/`"failed"` vocabulary) at top level, and `tasks_completed`, `tasks_failed`, `tasks_deferred_self_modifying`, `tasks_deferred_deploy_checkpoint`, `forward_progress_violated`, `defer_ledger`, `idle_overlap_ledger`, `detected_defects`, `verify_deploy_baseline_notices`, `cycles_used`, and `multi_task_mode: true` inside `metadata`.
7. Runs the non-blocking residue check (`### Commit Granularity` above) — warns only, never commits.
8. Releases the batch's in-flight session registry entry (`task-lock.sh session-release`), unconditionally regardless of `exit_status`, best-effort and non-blocking.
9. For every task in `completed_tasks` only (never `failed_tasks`, never a still-non-terminal task — mirroring the asymmetry that per-dispatch context persists across a partial/timeout exit and is swept only at genuine full completion), removes that task's accumulated `.dispatch/` directory. Best-effort and non-blocking.
