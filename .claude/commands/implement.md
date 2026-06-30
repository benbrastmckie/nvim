---
description: Execute implementation with resume support
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read, Edit, Glob
argument-hint: TASK_NUMBERS [--team [--team-size N]] [--force] [--fast|--hard] [--haiku|--sonnet|--opus]
model: opus
---

# /implement Command

Execute implementation plan with automatic resume support by delegating to the appropriate implementation skill/subagent.

## Arguments

- `$1` - Task number(s): single (`353`), comma-separated (`7, 22, 59`), ranges (`22-24`), or combined
- Optional: `--force` to override status validation for completed tasks

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable parallel phase execution with multiple teammates | false |
| `--team-size N` | Number of implementation teammates to spawn (2-4) | 2 |
| `--force` | Override status validation (allow re-implementation of completed tasks) | false |
| `--fast` | Low-effort mode: lighter reasoning, faster responses | false |
| `--hard` | High-effort mode: deeper reasoning, more thorough analysis | false |
| `--haiku` | Use Haiku model (fastest, lowest cost) | false |
| `--sonnet` | Use Sonnet model (balanced cost/quality) | false |
| `--opus` | Use Opus model (highest quality, same as agent default) | false |
| `--clean` | Skip automatic memory retrieval | false |
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based implementation | false |

## Anti-Bypass Constraint

**PROHIBITION**: You MUST NOT write implementation summary artifacts directly using Write or Edit tools. All summary files MUST be created by invoking the appropriate skill (skill-implementer or skill-team-implement) via the Skill tool.

**Required**: Always delegate to the Skill tool. Never write to `specs/*/summaries/*.md` directly from this command.

## Execution

**Note**: Delegate to skills for task-type-specific implementation.

### STAGE 0: PARSE TASK NUMBERS

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS, REMAINING_ARGS, TEAM_MODE, TEAM_SIZE, EFFORT_FLAG, MODEL_FLAG,
#          CLEAN_FLAG, FORCE_FLAG, LIT_FLAG, FOCUS_PROMPT
[ "$TEAM_SIZE" -gt 4 ] && TEAM_SIZE=4
```

If `len(TASK_NUMBERS) > 1`: continue to MULTI-TASK DISPATCH below.
If `len(TASK_NUMBERS) == 1`: fall through to CHECKPOINT 1: GATE IN.

---

### MULTI-TASK DISPATCH

#### Step 1: Batch Validation

```bash
validated_tasks=(); skipped_tasks=()
for task_num in "${task_numbers[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" '.active_projects[] | select(.project_number == $num)' specs/state.json)
  if [ -z "$task_data" ]; then skipped_tasks+=("$task_num: not found"); continue; fi
  status=$(echo "$task_data" | jq -r '.status')
  case "$status" in
    completed) [ "$FORCE_FLAG" = "true" ] || { skipped_tasks+=("$task_num: already completed (use --force)"); continue; } ;;
    abandoned|expanded) skipped_tasks+=("$task_num: terminal status [$status]"); continue ;;
  esac
  validated_tasks+=("$task_num")
done
# Report skipped tasks (warnings, non-blocking); if no validated tasks remain, ABORT
```

#### Step 2: Generate Batch Session ID

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

#### Step 3: Dispatch Skills

For each validated task, invoke the appropriate implementation skill using parallel Skill tool calls:
- Extract task_type per task from state.json; route using extension manifests or default `skill-implementer`
- If `--team`: use `skill-team-implement`; invoke all skills in a single message (parallel execution)
- Pass `--force` to each skill when `FORCE_FLAG == "true"`
- Collect results; read `.return-meta.json` for structured data

#### Step 4: Batch Git Commit and Consolidated Output

Git commit remaining changes (non-blocking). Display results table with session ID, counts (requested/succeeded/failed/skipped), and per-task status. Include partial-success note in commit message. Suggest re-running failed tasks individually.

**After consolidated output, STOP.** Do not continue to CHECKPOINT 1.

---

### CHECKPOINT 1: GATE IN

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "implement"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [IMPLEMENT] Task {N}: {project_name}
# Aborts if task not found or in terminal status (unless --force)
```

**--force override** (implement-specific): If `FORCE_FLAG == "true"` and gate-in rejects due to terminal status, override the rejection and proceed.

**Load Implementation Plan** (implement-specific):
Find latest: `specs/${PADDED_NUM}_${PROJECT_NAME}/plans/*.md` (sorted by version)

If no plan: ABORT "No implementation plan found. Run /plan {N} first."

**Detect Resume Point**: Scan plan phase markers — `[NOT STARTED]`/`[IN PROGRESS]`/`[PARTIAL]` → start/resume; `[COMPLETED]` → skip; all `[COMPLETED]` → task already done.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present): Route to `skill-team-implement`.

**Extension Routing** (when `--team` flag NOT present):

```bash
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"
skill_name="$SKILL_NAME"
# Defensive correction (state.json + TODO.md) handled by command-gate-out.sh
```

**Routing table**:

| Task Type | Skill to Invoke |
|-----------|-----------------|
| `neovim` | `skill-neovim-implementation` |
| `nix` | `skill-nix-implementation` |
| `general`, `meta`, `markdown` | `skill-implementer` (default) |
| Extension type | Resolved via extension manifest routing |

**Invoke the Skill tool NOW** with:
```
# For team mode:
skill: "skill-team-implement"
args: "task_number={N} plan_path={path} resume_phase={phase} team_size={TEAM_SIZE} session_id={SESSION_ID} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} clean_flag={CLEAN_FLAG} lit_flag={LIT_FLAG} orchestrator_mode=false"

# For single-agent mode:
skill: "{skill_name}"
args: "task_number={N} plan_path={path} resume_phase={phase} session_id={SESSION_ID} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} clean_flag={CLEAN_FLAG} lit_flag={LIT_FLAG} orchestrator_mode=false"
```

Pass `model` parameter if `MODEL_FLAG` is set. Pass `effort_flag` as prompt context if set.

**On DELEGATE success**: Implementation complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "implement" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
# Runs validate-artifact.sh --fix (non-blocking)
# Defensive correction (state.json + TODO.md) handled by this script
```

The following steps are implement-specific (not handled by command-gate-out.sh):

4. **Populate Completion Summary (if implemented)** — Only when `result.status == "implemented"`:

   ```bash
   completion_summary="$result_summary"
   jq --arg summary "$completion_summary" \
     '(.active_projects[] | select(.project_number == '"$task_number"')).completion_summary = $summary' \
     specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
   ```

5. **Verify Plan File Status Updated (Defensive)** — Only when `result.status == "implemented"`: If plan file doesn't show `[COMPLETED]`, call `update-plan-status.sh "$task_number" "$PROJECT_NAME" "COMPLETED"`.

6. **Verify TODO.md Status (Defensive)** — Only when `result.status == "implemented"`: If `[IMPLEMENTING]` still present, call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md from state.json (which has the correct status).

7. **Post-Delegation Takeover Detection**: Log a warning if the skill operated on non-specs files after the Agent tool returned (future enforcement).

**On GATE OUT success**: Artifacts and completion summary verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

**On completion:**
```bash
git add -A && git commit -m "task {N}: complete implementation\n\nSession: {SESSION_ID}"
```

**On partial:**
```bash
git add -A && git commit -m "task {N}: partial implementation (phases 1-{M} of {total})\n\nSession: {SESSION_ID}"
```

Commit failure is non-blocking (log and continue).

## Output

**Completion**: `Implementation complete for Task #{N}` | Summary path | Phases {M}/{total} | `[COMPLETED]`

**Partial**: `Implementation paused for Task #{N}` | Phases 1-{M} complete | `Status: [IMPLEMENTING] | Next: /implement {N}`

## Error Handling

- **GATE IN Failure**: Task not found, no plan, or invalid status — return error with guidance
- **DELEGATE Failure**: Keep [IMPLEMENTING], log error; phase markers preserved for resume
- **GATE OUT Failure**: Missing artifacts — log warning, continue with available
