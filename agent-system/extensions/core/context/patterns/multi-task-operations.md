# Multi-Task Operations Pattern

**Created**: 2026-04-02
**Purpose**: Define how workflow commands parse multi-task arguments, dispatch parallel skills, and produce consolidated output
**Audience**: Command developers implementing multi-task support in /research, /plan, /implement

---

## Overview

Workflow commands accept task numbers using the same range syntax already used by `/task --recover` and `/task --abandon`; a batch of one task and a batch of many use the same dependency-aware dispatch mechanism, not two separate code paths. This pattern extends single-task commands to accept multiple task numbers as the default way to work this system, not a special mode layered on top of single-task use. When multiple tasks are specified, the command spawns one agent per task in parallel, collects results, and produces a batch commit with consolidated output. See `batch-orchestration-guardrails.md`'s "Batching Is the Default" section for which tasks to batch together.

**Design principles**:
- Single-task input falls through to existing flow unchanged (no special-casing overhead for a batch of one)
- Multi-task spawns independent agents with per-task isolation
- Failure of one task never blocks or rolls back other tasks
- Flags apply uniformly to all tasks in the batch

**Scope**: This pattern covers argument parsing, dispatch flow, batch commits, consolidated output, and error handling. It does NOT implement these changes -- each workflow command file is updated separately to apply this pattern.

---

## 1. Argument Parsing

### parse_task_args() Specification

The `parse_task_args()` function wraps the existing `parse_ranges()` function from `routing.md` to separate task numbers from remaining arguments (flags and focus prompts).

**Algorithm**:

```
Input: $ARGUMENTS (raw string from command invocation)

1. Scan from left, consuming characters that are:
   - Digits [0-9]
   - Commas [,]
   - Hyphens [-] between digits (range separator)
   - Whitespace adjacent to the above

2. Stop consuming when encountering:
   - An alphabetic character [a-zA-Z]
   - A flag marker [--]
   - End of input

3. Parse consumed portion through parse_ranges()
4. Remaining portion becomes $REMAINING_ARGS
```

**Pseudocode**:

```bash
parse_task_args() {
  local input="$1"
  local task_spec=""
  local remaining=""

  # Match leading task specification: digits, commas, hyphens, spaces
  # Stop at first alphabetic char or -- flag
  if [[ "$input" =~ ^([0-9][0-9,\ \-]*)(\ +.*)?$ ]]; then
    task_spec="${BASH_REMATCH[1]}"
    remaining="${BASH_REMATCH[2]}"
  else
    echo "[FAIL] No task number found in arguments"
    return 1
  fi

  # Trim trailing whitespace/commas from task_spec
  task_spec=$(echo "$task_spec" | sed 's/[, ]*$//')

  # Parse through existing parse_ranges()
  task_numbers=($(parse_ranges "$task_spec"))

  # Trim leading whitespace from remaining
  remaining=$(echo "$remaining" | sed 's/^[[:space:]]*//')

  echo "TASK_NUMBERS=${task_numbers[*]}"
  echo "REMAINING_ARGS=$remaining"
}
```

### Examples

| Input | task_numbers | remaining_args | Mode |
|-------|-------------|----------------|------|
| `7` | `[7]` | `` | single |
| `7, 22-24, 59` | `[7, 22, 23, 24, 59]` | `` | multi |
| `7 focus on APIs` | `[7]` | `focus on APIs` | single |
| `7, 22-24 --hard` | `[7, 22, 23, 24]` | `--hard` | multi |
| `42 --clean --lit` | `[42]` | `--clean --lit` | single |
| `10-12, 15 --force` | `[10, 11, 12, 15]` | `--force` | multi |

---

## 2. Single-Task Fallthrough

When `parse_task_args()` produces exactly one task number, the command proceeds through its existing checkpoint flow unchanged:

```
len(task_numbers) == 1
  -> task_number = task_numbers[0]
  -> Continue to CHECKPOINT 1: GATE IN
  -> Existing single-task flow (no changes)
```

**Backward compatibility guarantees**:
- Single task number (`/research 7`) behaves identically to current implementation
- Single task with focus prompt (`/research 7 focus on APIs`) behaves identically
- Single task with flags (`/research 7 --hard`) behaves identically
- Ranges that resolve to one task (`/research 7-7` or `/research 7,7,7`) use single-task flow

---

## 3. Edge Cases

| Input | Resolution | Rationale |
|-------|-----------|-----------|
| `7-7` | Normalize to `[7]`, use single-task flow | Degenerate range |
| `7,7,7` | Deduplicate to `[7]`, use single-task flow | `parse_ranges()` deduplicates |
| `7, 22-24, 22` | Deduplicate to `[7, 22, 23, 24]` | `parse_ranges()` deduplicates and sorts |
| `7 -9` | `task_numbers=[7]`, `remaining="-9"` | Hyphen not between digits is not a range |
| `0` | Rejected by validation step | Task numbers start at 1 |
| (empty) | `[FAIL] No task number found` | Missing required argument |
| `abc` | `[FAIL] No task number found` | No leading digits |
| `7, 22-24 focus on APIs` | `task_numbers=[7,22,23,24]`, `remaining="focus on APIs"` | Focus prompt in multi-task applies to all tasks |

---

## 4. Multi-Task Dispatch Flow

When `parse_task_args()` produces more than one task number, the command enters multi-task mode. This inserts a **STAGE 0: PARSE AND DISPATCH** before the existing checkpoint flow.

### Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│  STAGE 0: PARSE AND DISPATCH                            │
│                                                         │
│  1. parse_task_args($ARGUMENTS)                         │
│  2. if len(task_numbers) == 1 --> single-task flow      │
│  3. if len(task_numbers) > 1  --> multi-task dispatch    │
│                                                         │
│  MULTI-TASK:                                            │
│  4. Validate all tasks (existence + status)             │
│  5. Generate batch session ID                           │
│  6. Route each task to appropriate skill                │
│  7. Invoke all skills in parallel (one per task)        │
│  8. Collect results from all skills                     │
│  9. Batch git commit (cleanup; may be empty)            │
│  10. Consolidated output                                │
└─────────────────────────────────────────────────────────┘
```

### Dispatch Decision

```
task_numbers = parse_task_args($ARGUMENTS)

if len(task_numbers) == 1:
    # SINGLE-TASK MODE
    task_number = task_numbers[0]
    # Fall through to existing CHECKPOINT 1: GATE IN
    # No changes to existing flow

elif len(task_numbers) > 1:
    # MULTI-TASK MODE
    # Continue to batch validation and dispatch below
```

---

## 5. Batch Validation

Before spawning any agents, validate all tasks exist and have valid status for the requested operation.

```bash
validated_tasks=()
invalid_tasks=()

for task_num in "${task_numbers[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)

  if [ -z "$task_data" ]; then
    invalid_tasks+=("$task_num: not found")
    continue
  fi

  status=$(echo "$task_data" | jq -r '.status')

  # Check status allows the requested operation
  if ! status_allows_operation "$status" "$command"; then
    invalid_tasks+=("$task_num: invalid status [$status]")
    continue
  fi

  validated_tasks+=("$task_num")
done
```

**Status validation per command**:

| Command | Allowed From Status |
|---------|-------------------|
| /research | not_started, researched |
| /plan | researched |
| /implement | planned, implementing (resume) |

**Handling invalid tasks**:

```
if invalid_tasks is not empty:
    Report warnings for each invalid task
    Continue with validated_tasks only

if validated_tasks is empty:
    [FAIL] No valid tasks to process
    Abort entirely
```

Invalid tasks are reported as warnings but do not block valid tasks from proceeding.

---

## 5a. Batch Admission Pre-Check and Bounded Second Pass (Tier 1)

After Batch Validation (section 5) and BEFORE the per-task acquire/dispatch loop (section 6),
each of `commands/research.md`, `commands/plan.md`, and `commands/implement.md` runs a Batch
Admission Pre-Check (Step 2.5) against `orchestrate-batch-admit.sh`'s bounded conflict-detection
predicate — cross-batch `file_scope` collisions, the self-modification hazard, and live
session-registry contention (see `context/patterns/batch-orchestration-guardrails.md`'s "The
Three Existing Admission Layers"). This is DETECTION only: a deferred task is moved OUT of
`validated_tasks`, never hard-failed.

**The `in_batch` `file_scope_collision` case gets a bounded second pass — Tier 1 (auto-sequence)
of the four-tier conflict-response ladder** (see `context/patterns/task-lock.md`'s "Four-Tier
Conflict Response" section for the full ladder):

1. **Pass 1 (parallel)**: Step 2.5 splits every `defer` verdict by `defer_reason` and, for
   `file_scope_collision`, by `collision_scope`. `collision_scope == "in_batch"` (the colliding
   task is itself one of THIS invocation's candidates and will finish this run) moves the task
   into a new `deferred_second_pass` array — NOT `skipped_tasks`. Every other defer flavor
   (`cross_batch` `file_scope_collision`, `self_modifying`, `session_active`) keeps the
   pre-existing single-pass exclude-to-`skipped_tasks` behavior verbatim; only `in_batch` gets
   the second chance. The remaining `validated_tasks` dispatch in PARALLEL exactly as section 6
   describes, unaffected.
2. **Pass 2 (sequential, bounded to exactly ONE extra pass)**: a new Step 3.5, run after Step 3's
   parallel dispatch and unconditional lock releases complete, re-runs
   `orchestrate-batch-admit.sh` over EXACTLY the `deferred_second_pass` set (never expanded to
   pull in any out-of-batch predecessor — bounded scan, never a sweep of all task directories).
   Admitted tasks dispatch SEQUENTIALLY (not parallel) through the identical per-task
   `acquire-retry` → skill → `release` bracket Step 3 uses. A task still deferred after this one
   extra pass moves to `skipped_tasks` with the distinguishing reason `"deferred after second
   pass [$defer_reason]"` — there is never a third pass.
3. **Convergence log, not an exclusion set**: `second_pass_ledger` accumulates one entry per
   pass-1 in-batch defer and per pass-2 outcome
   (`{"task":N,"defer_reason":...,"collision_scope":...,"pass":1|2,"detail":...}`). It is
   APPEND-ONLY and read only when composing the consolidated summary (section 9) — a task's
   presence in the ledger never excludes it from the pass-2 admission input.
4. **Non-convergence is `partial`, never a failure**: if pass 2 leaves at least one task still
   deferred, the consolidated summary (section 9) reports the invocation's overall status as
   `partial` and names the mutually-colliding task set, suggesting a solo re-run once the field
   clears — mirroring `skill-orchestrate`'s own `consecutive_no_dispatch_cycles`-break shape. A
   conflict must never error the invocation (section 10's Defer-Not-Fail contract).

**`--allow-scope-collision` cross-reference (bounded, not silence)**: `/orchestrate`'s
`--allow-scope-collision` flag (see `commands/orchestrate.md`'s `## Options`) overrides the
CROSS-BATCH `file_scope_collision` admission gate only, never `in_batch` — this asymmetry is a
deliberate design decision (D1 in the originating plan), not an oversight. Tier 1's bounded
second pass above remains the SOLE remedy for an `in_batch` collision; there is no override flag
for it, and none is planned, because an `in_batch` collision means the colliding task is a live
concurrent co-dispatch in THIS SAME invocation — bypassing it would risk two agents editing the
same files in the same pass, a hazard `--allow-scope-collision` deliberately does not reach.

This is intentionally narrower than `/orchestrate`'s own multi-cycle Tier-1 resequencing
(`scripts/orchestrate-cycle-plan.sh`'s step 4.5, which can retry the identical verdict across
MANY cycles as tasks progress toward completion): plain multi-task commands get exactly one bonus
pass, not an open-ended cycling loop, because they have no wave/cycle concept to cycle within.
See `context/patterns/batch-orchestration-guardrails.md`'s "Scope Limitation and Residual Risk"
subsection for the full comparison against `/orchestrate`'s narrowing.

---

## 6. Parallel Skill Dispatch

**Superseded note**: this section describes the original per-command (`/research`/`/plan`/
`/implement`) dispatch shape from when this pattern was authored. Those commands, and the
research/plan/implement skill layer they dispatched to, have since been deleted; `/orchestrate`
is now the sole multi-task-capable entry point, and its own Stage MT loop dispatches agents
directly via the Agent tool (resolved through `command-route-agent.sh`), not via Skill tool
calls to a research/plan/implement skill. See `skill-orchestrate/SKILL.md`'s Multi-Task Mode
section for the current mechanism; the shape below is retained as historical context for the
pattern's original design intent.

### Architecture: Orchestrator-Loop Skill Invocation

Multi-task dispatch uses parallel Skill tool calls from the command's orchestrator loop. Each task maps to the appropriate skill for that task type, and all skills are invoked in a single message for parallel execution.

```
Command -> [Agent(general-research-agent, task {N}), Agent(planner-agent, task {N}), ...]
```

This keeps dispatch logic co-located with each command's validation and routing rules, avoiding an extra indirection layer. Each skill runs the full single-task lifecycle (preflight, agent delegation, postflight) independently.

### Batch Session ID

Generate a single session ID for the entire batch operation:

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

Each invoked skill receives a derived per-task session ID:

```
Per-task session: {batch_session_id}_{task_num}
```

### Spawning Pattern

The orchestrator invokes one skill per validated task using parallel Skill tool calls. Routing is per task_type using the same extension manifest lookup used for single-task dispatch:

```
# All invoked in a single message (parallel execution)
For each task_num in validated_tasks:
  Tool: Skill
  Parameters:
    skill: "{skill_name}"  # e.g., "general-research-agent" (routed per task_type)
    args: "task_number={task_num} session_id={batch_session_id}_{task_num} {remaining_args}"
```

Each invoked skill runs the full single-task lifecycle independently:
- Preflight status update (researching/planning/implementing)
- Agent delegation and execution
- Postflight status update
- Artifact creation
- Per-skill git commit (may occur before the batch commit at Step 4)

### Result Collection

After all parallel skills complete, the orchestrator collects their text return values. Each skill returns a brief text summary; the orchestrator reads `.return-meta.json` files in each task directory for structured data if needed:

```
Skill results (text summaries):
  task {N}: "Research completed: specs/{NNN}_.../reports/01_....md [RESEARCHED]"
  task {N}: "Research completed: specs/{NNN}_.../reports/01_....md [RESEARCHED]"
  task {N}: "Research failed: Agent timeout. Status: researching"
  task {N}: "Research completed: specs/{NNN}_.../reports/01_....md [RESEARCHED]"
```

---

## 7. Flag Compatibility

### Flag Compatibility Table

| Flag | Multi-task behavior |
|------|---------------------|
| `--force` | Applied to ALL tasks (bypasses status validation) |
| Focus prompt | Applied to ALL tasks (same focus for each) |

**Not supported**: Per-task flags or per-task focus prompts. Users wanting different configurations per task should run separate commands.

---

## 8. Batch Git Commit Format

After all skills complete, the orchestrator produces a single batch git commit covering all successful tasks.

**Note on per-skill commits**: Each invoked skill runs its own postflight, which may produce an individual commit before the batch commit executes. The batch commit at Step 4 is a cleanup/consolidation step that captures any remaining unstaged changes. If per-skill postflight already committed all changes, the batch commit may be empty (which fails gracefully with no effect).

### Full Success

```
{command} tasks {range_summary}: {action}

Tasks: {comma-separated list}
Session: {batch_session_id}
```

**Example**:

<!-- task-ref-ok:begin canonical rendered commit-message example -->
```
research tasks 7, 22-24, 59: complete research

Tasks: 7, 22, 23, 24, 59
Session: sess_1743523200_abc123
```
<!-- task-ref-ok:end -->

### Partial Success

```
{command} tasks {range_summary}: {action} ({succeeded}/{total} succeeded)

Tasks completed: {comma-separated}
Tasks failed: {num} ({reason})[, {num} ({reason})]
Session: {batch_session_id}
```

**Example**:

<!-- task-ref-ok:begin canonical rendered commit-message example -->
```
research tasks 7, 22-24: complete research (3/4 succeeded)

Tasks completed: 7, 22, 24
Tasks failed: 23 (invalid status [IMPLEMENTING])
Session: sess_1743523200_abc123
```
<!-- task-ref-ok:end -->

### Commit Scope

The batch commit includes only changes from successful tasks:
- State.json updates for succeeded tasks
- TODO.md status changes for succeeded tasks
- Artifacts created by succeeded agents (reports, plans, summaries)

Failed tasks remain in their "in progress" status and are NOT included in the commit.

---

## 9. Consolidated Output Format

The orchestrator produces a consolidated output displayed to the user after all skills complete.

```markdown
## Batch {Command} Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {count}
Failed: {count}
Skipped: {count}

### Succeeded

| Task | Title | Status | Artifact |
|------|-------|--------|----------|
| #7 | task_title | [RESEARCHED] | specs/007_slug/reports/01_short.md |
| #22 | task_title | [RESEARCHED] | specs/022_slug/reports/01_short.md |

### Failed

| Task | Error |
|------|-------|
| #23 | Invalid status [IMPLEMENTING] |

### Skipped

| Task | Reason |
|------|--------|
| #99 | Not found in state.json |

### Next Steps
- /plan 7, 22, 24, 59
```

**Field definitions**:
- **Succeeded**: Tasks where the agent completed successfully and status was updated
- **Failed**: Tasks that were dispatched but the agent encountered an error
- **Skipped**: Tasks that failed validation before dispatch (not found, wrong status)
- **Next Steps**: Suggested follow-up command using succeeded task numbers

---

## 10. Partial-Success Error Handling

### Principle

Failure of one task MUST NOT block or roll back other tasks. Each agent manages its own task's state independently.

### Error Categories

| Error | When | Handling | User Recovery |
|-------|------|----------|---------------|
| Task not found | Validation (pre-dispatch) | Skip, report in Skipped section | Create task first, re-run |
| Invalid status | Validation (pre-dispatch) | Skip, report in Skipped section | Fix status, re-run |
| Agent timeout | During execution | Mark task partial, report in Failed | Re-run single task: `/{command} {N}` |
| Agent failure | During execution | Keep "in progress" status, report in Failed | Re-run single task: `/{command} {N}` |
| Git conflict | Post-execution commit | Non-blocking, log warning | Manual resolution |

### Per-Task Isolation

Each spawned agent operates independently:
- Writes only its own task's fields in state.json (scoped by project_number)
- Creates artifacts only in its own task directory (`specs/{NNN}_{SLUG}/`)
- Updates only its own task's status in TODO.md

If the agent for one task in the batch fails:
- That task's status remains "researching" (in-progress variant)
- The other tasks transition to "researched" normally
- The batch commit includes only changes from the tasks that succeeded

### Concurrent State Safety

Multiple skills writing to state.json concurrently is safe for two independent reasons:
- Each skill writes to a specific `project_number` entry in `active_projects`; jq operations are
  scoped (`select(.project_number == $num)`), so no skill modifies another task's fields.
- `scripts/state-write.sh` is the single sanctioned, mutex-guarded writer: fail-closed
  `specs/.scope-lock` acquisition, private per-process `mktemp` staging, `jq empty` validation
  before `mv`. Every writer converted to call it closes the read-modify-write race that used to
  exist between concurrent writers — see `context/patterns/task-lock.md`'s "State-Write
  Convention" section for the full contract and `scripts/test-state-write-concurrency.sh` for the
  isolated-temp-root suite proving no-lost-update under genuine concurrency.

The read-modify-write race this section used to record as a known, unfixed limitation is fixed
for every writer that has been converted to `state-write.sh` (the scripts and command files
enumerated in `context/patterns/task-lock.md`'s "Consumers" list). It is NOT yet fixed for the
residual surface named in that same file's "Known residual surface" note — 14 core `SKILL.md`
files and two command files still write `specs/state.json` inline, tracked as a dedicated
follow-up task in the orchestration-concurrency topic group of `specs/TODO.md` rather than
silently assumed complete.

---

## 11. Backward Compatibility

This pattern is fully backward compatible with existing single-task usage:

1. **Single task** (`/research 7`): `parse_task_args()` returns `[7]`, falls through to existing flow
2. **Single task with focus** (`/research 7 focus on APIs`): Parser separates `7` from `focus on APIs`
3. **Single task with flags** (`/research 7 --hard`): Parser separates `7` from `--hard`
4. **Existing /task flags** (`/task --recover 343-345`): Unaffected -- different command with flag-based routing via `/task` command file

No existing behavior changes. Multi-task mode activates only when multiple task numbers are detected in the argument string.

---

## 12. Command File Modification Guide

Each workflow command is updated to apply this pattern. This section summarizes what each command file needs.

### Changes Common to All Three Commands

1. **Add STAGE 0 block** before CHECKPOINT 1: GATE IN
   - Call `parse_task_args($ARGUMENTS)` (inline the pseudocode from Section 1)
   - Add dispatch decision: single-task falls through, multi-task branches to batch dispatch

2. **Add multi-task dispatch branch**
   - Batch validation of all tasks
   - Generate batch session ID
   - Route each task to appropriate skill (per task_type extension lookup)
   - Invoke all skills in a single message (parallel Skill tool calls, one per task)
   - After all skills return: produce batch commit and consolidated output

3. **No changes to single-task flow**
   - Existing GATE IN, DELEGATE, GATE OUT, COMMIT remain unchanged
   - Single-task path is unmodified

### Per-Command Specifics

**Historical**: the `/research`, `/plan`, and `/implement` commands named below have since been
deleted; `/orchestrate` is the sole surviving multi-task-capable entry point. Table retained for
the pattern's original per-command design intent.

| Command | Status Validation | Skill Invoked | Action Verb |
|---------|------------------|---------------|-------------|
| `/research` | not_started, researched | general-research-agent (or extension research skill) | "complete research" |
| `/plan` | researched | planner-agent (or extension plan skill) | "create implementation plan" |
| `/implement` | planned, implementing | general-implementation-agent (or extension implement skill) | "complete implementation" |

### Batch Dispatch Architecture

Multi-task dispatch is handled by the orchestrator loop built into each command file (`/research`, `/plan`, `/implement`), not by a separate batch skill. Each command's MULTI-TASK DISPATCH section implements:

- Task type extraction per task (from state.json)
- Skill routing per task (using existing task-type-based routing from extension manifests)
- Parallel Skill tool calls (one skill per task, all invoked in a single message)
- Result collection from skill text returns (`.return-meta.json` for structured data)
- Consolidated status update and batch git commit

This approach keeps dispatch logic co-located with each command's validation and routing rules, avoiding an additional indirection layer. It is consistent with Section 6, which describes the same orchestrator-loop architecture.

---

## 13. Orchestrate-Specific Behavior

### Why Wave Dispatch Instead of Pure Parallel

`/research`, `/plan`, and `/implement` operate on a **single lifecycle phase**: each command performs one well-defined step for each task. Since one task's research does not depend on another task's research completing (they are independent state machines), pure parallel dispatch is safe.

`/orchestrate` is different: it drives tasks through their **entire lifecycle** (research -> plan -> implement -> complete). When task B depends on task A, B must not begin orchestration until A has completed -- if B requires A's output, starting B before A finishes produces incorrect results.

This requires **wave-based dispatch**: tasks are grouped into topological waves based on their intra-batch dependency graph, waves execute sequentially, and tasks within each wave run in parallel.

### Intra-Batch Dependency Resolution

Only dependencies between tasks **within the current batch** affect wave assignment. External dependencies (on tasks not in the batch) are ignored for ordering purposes -- those are assumed to be already completed or irrelevant to the current run.

```
Example: /orchestrate 42, 43, 44, 45
  state.json dependencies:
    43 depends on [42, 10]  (10 is outside batch -- ignored)
    44 depends on [43]
    45 depends on [42]

  Intra-batch dependency graph:
    42: no deps         -> Wave 0
    43: depends on 42   -> Wave 1
    44: depends on 43   -> Wave 2
    45: depends on 42   -> Wave 1

  Execution:
    Wave 0: [42]          (parallel -- 1 task)
    Wave 1: [43, 45]      (parallel -- both depend only on Wave 0)
    Wave 2: [44]          (parallel -- depends on Wave 1)
```

### File Footprint Overlap as a Serialization Edge

Wave assignment (above) treats any `dependencies[]` edge as a serialization constraint. Since
task creation (Multi-Task Creation Standard Component 4a, see
`.claude/docs/reference/standards/multi-task-creation-standard.md`) now auto-adds a serializing
`dependencies[]` edge whenever two tasks' `file_scope` arrays overlap (per the shared algorithm
in `.claude/context/patterns/file-footprint-overlap.md`), **file footprint overlap is itself a
serialization edge** by the time `/orchestrate` reads `dependencies[]` — no separate
footprint-aware wave-computation logic is needed for tasks created together in the same batch.

**Same-batch vs cross-batch coverage**:
- **Same-batch** (tasks created together, e.g. via one `/meta` or `/fix-it` run): fully covered
  at creation time by Component 4a. Wave assignment is file-safe "for free".
- **Cross-batch** (tasks created in separate batches/sessions that happen to touch the same
  files, e.g. `/orchestrate 785,787` where 785 and 787 were created independently): no
  creation-time comparison exists between them, so `dependencies[]` may be silent about a real
  file conflict. This residual gap is closed by the runtime wave-split check documented in
  `.claude/scripts/orchestrate-cycle-plan.sh` (step 4.5): before dispatching a
  wave/cycle with 2+ tasks, compare `file_scope` pairwise and defer the lower-priority task if an
  overlap has no `dependencies[]` edge.

### Failed Predecessor Handling

A failed task in Wave N causes its **direct dependents** to be skipped in Wave N+1 (and transitively in later waves). Failure does NOT propagate sideways -- other tasks in Wave N that succeeded do NOT become failed.

The failed predecessor rule is applied at wave dispatch time:
1. Before dispatching Wave N+1, check each task in the wave for failed predecessors.
2. If any predecessor is in the failed or skipped set, move that task to `skipped_tasks` with reason "predecessor {N} failed/skipped".
3. Dispatch only the remaining (non-skipped) tasks in the wave.

This ensures a clean failure boundary: only the dependency chain of the failed task is affected.

### Focus Prompt Compatibility

The optional focus prompt (e.g., `/orchestrate 42, 43 focus on the auth layer`) applies uniformly to all tasks in the batch. Each `skill-orchestrate` invocation receives the same `focus_prompt` value. Per-task focus prompts are not supported; run separate `/orchestrate` commands for different focus areas.

### Dispatch Model Comparison

| Property | `/research`, `/plan`, `/implement` | `/orchestrate` |
|----------|------------------------------------|----------------|
| Scope per task | Single lifecycle phase | Full lifecycle (all phases) |
| Dispatch model | Pure parallel (all tasks at once) | Wave dispatch (topological order) |
| Dependency awareness | None (each phase is independent) | Yes (intra-batch dependency graph) |
| Failed task impact | No cross-task impact | Blocks direct dependents in later waves |
| Batch session ID | Single ID, per-task suffix | Single ID, per-task suffix |
| Per-task skill | Routed by task_type | Always `skill-orchestrate` |
| Parallelism | All validated tasks simultaneously | Tasks within each wave simultaneously |

---

## See Also

- `checkpoint-execution.md` -- Three-checkpoint command flow (GATE IN, DELEGATE, GATE OUT)
- `skill-lifecycle.md` -- Self-contained skill lifecycle management
- `routing.md` -- `parse_ranges()` function and task-type-based routing tables
- `.claude/commands/orchestrate.md` -- Full orchestrate command implementation
