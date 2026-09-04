---
description: Execute a task autonomously through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read
argument-hint: TASK_NUMBERS [PROMPT] [--haiku|--sonnet|--opus|--fable] [--research] [--plan] [--implement]
model: opus
---

# /orchestrate Command

Drive a task through its complete lifecycle autonomously without pausing for user confirmation.
Implements fire-and-forget state machine: research -> plan -> implement -> complete.

## Arguments

- `$1` - Task number(s) (required). Supports single task, comma-separated lists, and ranges.
  - Single: `42`
  - Comma-separated: `42, 43, 45`
  - Range: `42-45`
  - Mixed: `42, 44-46, 50`
- `$2+` - Optional prompt/focus text (e.g., `focus on the LSP config`). Applies to all tasks in multi-task mode.

## Constraints

- Multi-task mode uses dependency-aware wave dispatch.
- `--research`/`--plan`/`--implement` (phase-forcing flags): honored uniformly across every
  task_number in multi-task mode too, via `scripts/orchestrate-cycle-plan.sh`'s `--force-phases`
  — each task tracks its own remaining-forced-phases position independently, falling through to
  ordinary status-derived classification once its own forced sequence is exhausted.
- No confirmation gates between lifecycle phases.
- Terminates on success, `MAX_CYCLES` exceeded, `MAX_INFRA_FAILURES` exceeded (repeated Agent-tool
  transport/API failures — distinct from work-budget exhaustion), or an unrecoverable blocker.
- Multi-task mode: a failed task never blocks siblings in its own wave, but DOES block dependents
  in later waves.

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based tasks | false |
| `--dry-run` | Report-only: run the full admission analysis and print the verdict report; dispatch nothing and mutate nothing | false |
| `--allow-self-modifying` | Opt-in, this-invocation-only bypass of the self-modification admission gate; deliberate human intent, never a general-purpose weakening | false |
| `--allow-scope-collision` | Opt-in, this-invocation-only bypass of the CROSS-BATCH `file_scope_collision` gate only (never `in_batch`); deliberate human intent | false |
| `--continue-budget` | Authorization to continue past an exhausted `MAX_CYCLES` budget. **Never inferred automatically** (not from `session_id`, not from mtime) — without it, refuses with an honest message. See `orchestrator-runtime-files.md`'s budget-continuation-override section | false |
| `--clean` | Skip automatic memory retrieval | false |
| `--fast` | Low-effort mode: lighter reasoning, faster responses | false |
| `--hard` | High-effort mode: injects hard-mode contracts (churn/three-strikes/burnout counters); ~3-5x cost; composable with `--lit`, model flags, and the phase-forcing flags | false |
| `--haiku` | Use Haiku model (fastest, lowest cost). Applies to research/plan/implement dispatches only — diagnostic dispatches retain their frontmatter model | false |
| `--sonnet` | Use Sonnet model (balanced cost/quality) | false |
| `--opus` | Use Opus model (highest quality, same as agent default) | false |
| `--fable` | Use Fable model (claude-fable-5) | false |
| `--research` | Force a research round even if the task progressed past it. Composable with `--plan`/`--implement`: canonical lifecycle order (research, plan, implement) regardless of typed order, STOPS after the last named phase, opens a new `MM_` artifact round, never regresses status. Accepted and ignored (loud notice) in multi-task mode today — per-task in the batch engine once the feature-port task lands | false |
| `--plan` | Force a plan round even if the task progressed past it. Composable on the same terms as `--research` above. Accepted and ignored (loud notice) in multi-task mode today — per-task once the feature-port task lands | false |
| `--implement` | Force an implement round even if the task progressed past it. Composable on the same terms as `--research` above. Accepted and ignored (loud notice) in multi-task mode today — per-task once the feature-port task lands | false |

## Anti-Bypass Constraint

**PROHIBITION**: All lifecycle phases (research, plan, implement) MUST be executed by delegating
to `skill-orchestrate` via the Skill tool. Never run research/plan/implement directly from this
command.

## Execution

### STAGE 0: PARSE AND DISPATCH

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS (space-separated), FOCUS_PROMPT, REMAINING_ARGS, DRY_RUN_FLAG,
#          ALLOW_SELF_MODIFYING_FLAG, ALLOW_SCOPE_COLLISION_FLAG, CONTINUE_BUDGET_FLAG,
#          CLEAN_FLAG, EFFORT_FLAG, MODEL_FLAG, FORCE_PHASES_FLAG
focus_prompt="${FOCUS_PROMPT:-}"
```

Each parsed flag becomes a delegation-context key, threaded unchanged into both the single-task
STAGE 2 JSON and the multi-task Skill invocation below. All are **consumer-side-only** — never
forwarded to `orchestrate-batch-admit.sh`:

- `allow_self_modifying` (default `false`) — opt-in bypass of the self-modification gate, this
  invocation only.
- `allow_scope_collision` (default `false`) — opt-in bypass of the CROSS-BATCH
  `file_scope_collision` gate only (never `in_batch`).
- `continue_budget` (default `false`) — authorization to continue past an exhausted `MAX_CYCLES`
  budget, read by `skill-orchestrate`'s Stage 2. **Never inferred automatically** (not from
  `session_id`, not from mtime) — without it, an exhausted budget refuses with an honest message.
  See `orchestrator-runtime-files.md`'s budget-continuation-override section.
- `clean_flag` (default `false`) — suppresses Stage 3.5's automatic memory retrieval.
- `effort_flag` (default `""`) / `model_flag` (default `""`, not `null`) — reasoning-depth
  guidance and model-family selection for every lifecycle dispatch.
- `force_phases` (default `""`) — the composable `--research`/`--plan`/`--implement` surface (A2).
  Single-task: read only by `skill-orchestrate`'s Stage 2b. Multi-task: diagnostics only — Stage
  MT-1 emits an accepted-and-ignored notice, never fanned into per-task dispatch.

**Dry-run short-circuit** (before the `len(TASK_NUMBERS)` branch): `SESSION_ID` may be unset here
(minted at CHECKPOINT 1), so `--session` is passed to the report only when non-empty.

```bash
if [ "${DRY_RUN_FLAG:-false}" = "true" ]; then
  if [ -n "${SESSION_ID:-}" ]; then
    bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --session "$SESSION_ID" --state-file specs/state.json $TASK_NUMBERS
  else
    bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json $TASK_NUMBERS
  fi
  # STOP HERE.
fi
```

`orchestrate-cycle-plan.sh --dry-run` runs the IDENTICAL read-only decision pass the live
multi-task cycle uses (the same call to `scripts/orchestrate-batch-admit.sh` and
`scripts/orchestrate-triage-classify.sh`), so the printed verdicts match what a live run would
actually dispatch — one rendering of every admission verdict, not a second, independently
maintained one. It prints the plan JSON on stdout and a compact human table on stderr; neither
schema is restated here — see that script's own header comment.

**Dry-run prohibition block**: in dry-run mode this command MUST NOT continue to multi-task
dispatch below, MUST NOT reach CHECKPOINT 1 (GATE IN), MUST NOT invoke the Skill or Agent tools,
MUST NOT acquire a task lock, and MUST NOT run CHECKPOINT 3 (COMMIT) — mirroring the Anti-Bypass
Constraint above, the STOP HERE is absolute, not advisory.

If `len(TASK_NUMBERS) == 1`: extract `task_number=$(echo "$TASK_NUMBERS" | awk '{print $1}')` and fall through to CHECKPOINT 1: GATE IN.

If `len(TASK_NUMBERS) > 1`: continue to the multi-task dispatch block below.

**Multi-task dispatch** (`len(TASK_NUMBERS) > 1`):

```bash
validated_tasks=(); skipped_tasks=()
for task_num in "${TASK_NUMBERS[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' specs/state.json)
  if [ -z "$task_data" ]; then
    skipped_tasks+=("$task_num: not found")
    continue
  fi
  status=$(echo "$task_data" | jq -r '.status')
  case "$status" in
    completed|abandoned|expanded)
      skipped_tasks+=("$task_num: terminal status [$status]")
      continue
      ;;
  esac
  validated_tasks+=("$task_num")
done
```

Report skipped tasks as warnings. If no validated tasks remain, ABORT with error.

**Pre-Dispatch Review** (advisory-loud, never blocking — the only visibility surface for
out-of-batch/nonexistent `dependencies[]` edges before they are narrowed away below; `--dry-run`
remains the abort-before-dispatch surface for a human who wants the full picture):

```bash
bash .claude/scripts/orchestrate-predispatch-review.sh "${validated_tasks[@]}"
```

Build the intra-batch dependency graph (dependencies on tasks also in `validated_tasks` — the
raw, unfiltered edges were already reviewed above):

```bash
declare -A predecessors
for task_num in "${validated_tasks[@]}"; do
  deps=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' \
    specs/state.json)
  intra_deps=()
  for dep in $deps; do
    [[ " ${validated_tasks[*]} " == *" $dep "* ]] && intra_deps+=("$dep")
  done
  predecessors[$task_num]="${intra_deps[*]}"
done

dep_graph_json=$(jq -n '{}')
for task_num in "${validated_tasks[@]}"; do
  deps_array=$(jq -n --argjson deps "$(printf '%s\n' "${predecessors[$task_num]}" | jq -R . | jq -s .)" '$deps')
  dep_graph_json=$(echo "$dep_graph_json" | jq --arg key "$task_num" --argjson deps "$deps_array" \
    '. + {($key): $deps}')
done
```

**MAX_TASKS Guard** (contract: `orchestrate-state-machine.md`'s `### Batch Size Cap`):

```bash
task_count=${#validated_tasks[@]}
MAX_TASKS=8
if [ "$task_count" -gt "$MAX_TASKS" ]; then
  echo "[orchestrate] WARNING: $task_count tasks exceeds MAX_TASKS=$MAX_TASKS."
  echo "Batching is not yet supported. Running with first $MAX_TASKS tasks only."
  validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")
fi
```

`waves` is a **diagnostic echo, not a schedule the engine consumes** — eligibility is re-derived
fresh every cycle from `dependency_graph` (Stage MT-3 step 4.5). Passed as one row of all
validated tasks:

```bash
waves_json=$(jq -n --argjson t "$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')" '[$t]')
task_numbers_json=$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')

source .claude/scripts/lib/common.sh
batch_session_id="$(common_session_id)"
```

Invoke a single `skill-orchestrate` instance with all task context — it manages wave-by-wave
dispatch, per-task postflight, session-registry annotation, and writes results to
`specs/.orchestrator-multi-state-${batch_session_id}.json`:

```
Tool: Skill
Parameters:
  skill: "skill-orchestrate"
  args: "multi_task_mode=true task_numbers={task_numbers_json} waves={waves_json} dependency_graph={dep_graph_json} session_id={batch_session_id} focus_prompt={focus_prompt} lit_flag={LIT_FLAG} allow_self_modifying={ALLOW_SELF_MODIFYING_FLAG} allow_scope_collision={ALLOW_SCOPE_COLLISION_FLAG} continue_budget={CONTINUE_BUDGET_FLAG} clean_flag={CLEAN_FLAG} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} force_phases={FORCE_PHASES_FLAG}"
```

The delegation context passed to the skill must include:
```json
{
  "session_id": "{batch_session_id}",
  "multi_task_mode": true,
  "task_numbers": [42, 43, 44],
  "waves": [[42, 43, 44]],
  "dependency_graph": {"42": [], "43": [42], "44": [42]},
  "focus_prompt": "{focus_prompt}",
  "lit_flag": "{LIT_FLAG}",
  "allow_self_modifying": "{ALLOW_SELF_MODIFYING_FLAG}",
  "allow_scope_collision": "{ALLOW_SCOPE_COLLISION_FLAG}",
  "continue_budget": "{CONTINUE_BUDGET_FLAG}",
  "clean_flag": "{CLEAN_FLAG}",
  "effort_flag": "{EFFORT_FLAG}",
  "model_flag": "{MODEL_FLAG}",
  "force_phases": "{FORCE_PHASES_FLAG}"
}
```

The skill emits the consolidated batch output itself (Stage MT-5) — see
`orchestrate-batch-results-template.md`.

**After the Skill invocation returns, STOP. Do not continue to CHECKPOINT 1** — multi-task mode
is fully handled inside this single call.

---

### CHECKPOINT 1: GATE IN

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "orchestrate"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [ORCHESTRATE] Task {N}: {project_name}
```

**Permissive gate**: unlike `/implement`, no plan file is required — the state machine handles
all lifecycle phases from wherever the task currently is.

**Only blocks on terminal states** (`completed`, `abandoned`, `expanded`). Every other status
(not_started, researched, planned, implementing, partial, blocked) is a valid entry point —
without exception, a `partial` task with no handoff and no blockers (the normal shape left by a
base-mode dispatch) dispatches implement rather than being treated as a dead end.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 2.

### STAGE 2: DELEGATE

**EXECUTE NOW**: immediately invoke the Skill tool.

```
skill: "skill-orchestrate"
args: "task_number={N} session_id={SESSION_ID} orchestrator_mode=true lit_flag={LIT_FLAG} continue_budget={CONTINUE_BUDGET_FLAG} clean_flag={CLEAN_FLAG} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} force_phases={FORCE_PHASES_FLAG}"
```

The delegation context passed to the skill must include:
```json
{
  "session_id": "{SESSION_ID}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "orchestrate", "skill-orchestrate"],
  "task_context": {
    "task_number": N,
    "task_name": "{PROJECT_NAME}",
    "description": "{DESCRIPTION}",
    "task_type": "{TASK_TYPE}"
  },
  "orchestrator_mode": true,
  "focus_prompt": "{FOCUS_PROMPT}",
  "lit_flag": "{LIT_FLAG}",
  "continue_budget": "{CONTINUE_BUDGET_FLAG}",
  "clean_flag": "{CLEAN_FLAG}",
  "effort_flag": "{EFFORT_FLAG}",
  "model_flag": "{MODEL_FLAG}",
  "force_phases": "{FORCE_PHASES_FLAG}"
}
```

**On DELEGATE success**: Orchestration complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2.

### CHECKPOINT 2: GATE OUT

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "orchestrate" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
```

**On GATE OUT success**: IMMEDIATELY CONTINUE to CHECKPOINT 3.

### CHECKPOINT 3: COMMIT

Apply the `implement`-equivalent scope from `.claude/context/standards/git-staging-scope.md`
(task dir + self-reported `modified_files`) and commit via `.claude/scripts/git-commit-scoped.sh`
— the single sanctioned implementation of path-scoped, mutex-serialized committing (under-stage,
never a repo-wide add; injects the canonical ephemeral-runtime-file exclusion set automatically).
This checkpoint runs every cycle of a still-running loop, well before the loop guard's own
termination-only cleanup, and its commit mutex serializes against another in-flight task's commit
sharing the same index — see `orchestrator-runtime-files.md`'s mid-lifecycle-sweep hazard.

The zero-`modified_files` warning below is the canonical, un-suffixed wording from
`git-staging-scope.md`'s "Fail-Safe Direction" section (single-task site — never the task-number
suffix reserved for the multi-task per-task site). Do not invent a second wording here.

```bash
task_dir="specs/${PADDED_NUM}_${PROJECT_NAME}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
metadata_file="${task_dir}/.return-meta.json"
modified_count=0
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f") && modified_count=$((modified_count + 1))
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
if [ "$modified_count" -eq 0 ]; then
  echo "[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually." >&2
fi
```

**On completion:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: complete orchestration" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "${stage_paths[@]}"
# Deletion is completion-branch-only: .return-meta.json is already staged/committed above (its
# modified_files were read into stage_paths above), and orchestrate-cycle-postflight.sh's
# mtime-freshness-windowed outcome-recovery fallback (used by a still-running loop's next cycle)
# would lose its source if this ran on the partial branch below -- never add it there.
rm -f "${metadata_file}"
```

**On partial:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: orchestration paused (cycles {M}/{MAX})" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "${stage_paths[@]}"
# No .return-meta.json deletion here -- the paused/partial outcome keeps the file for the next
# cycle's outcome recovery (see the completion branch's comment above).
```

Commit failure is non-blocking (log and continue).

## Output

**Completion**: `Orchestration complete for Task #{N}` | Final status: `[COMPLETED]` | Cycles: M/5

**Partial**: `Orchestration paused for Task #{N}` | Status: `[{STATUS}]` | Cycles: M/5 | `Next: /orchestrate {N}`

**Blocked**: `Task #{N} requires manual intervention` | Blocker description | Suggested actions

**System Defects Detected**: rendered only when `metadata.detected_defects` in the task's
`.return-meta.json` is non-empty — on a **Completion** outcome as readily as a **Partial** one,
since a detection is an observation about the agent system, never a verdict on the task
(`/orchestrate --hard` writes the same key from its own Stage 8 metadata merge). Same table shape
as the batch section, for visual consistency:

| Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
|------|--------------|-------------------------|------------------|--------|
| #{N} | HANDOFF_STALE_OR_ABSENT | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff | handoff mtime predates this dispatch window |

Operator remedy: fix the named source-store path under `agent-system/extensions/**`; the durable
record is already in `specs/events.jsonl`. No task status was mutated because of these rows.

**`--dry-run`**: the printed admission report only — no status transition, no cycle consumed, no commit. The invocation ends after the report; nothing else in this Output section applies to a `--dry-run` run.

## Error Handling

- **GATE IN Failure**: task not found or terminal — error with guidance
- **DELEGATE Failure**: keep current status, log error; loop guard preserved for resume
- **GATE OUT Failure**: missing artifacts — warn, continue with what's available
- **MAX_CYCLES Reached**: report status, provide `/orchestrate {N}` resume instruction
- **MAX_INFRA_FAILURES Reached**: report a connectivity problem distinct from work-budget
  exhaustion (`cycle_count` unaffected), provide `/orchestrate {N}` resume once connectivity is
  confirmed
