---
description: Execute implementation with resume support
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit, Glob
argument-hint: TASK_NUMBERS [--team [--team-size N]] [--force] [--fast|--hard] [--haiku|--sonnet|--opus]
model: opus
---

# /implement Command

Execute implementation plan with automatic resume support by delegating to the appropriate implementation skill/subagent.

## Arguments

- `$1` - Task number(s) (required). Supports:
  - Single task: `353`
  - Comma-separated: `7, 22, 59`
  - Ranges: `22-24`
  - Combined: `7, 22-24, 59`
- Optional: `--force` to override status validation

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable parallel phase execution with multiple teammates | false |
| `--team-size N` | Number of implementation teammates to spawn (2-4) | 2 |
| `--force` | Override status validation | false |
| `--fast` | Low-effort mode: lighter reasoning, faster responses | false |
| `--hard` | High-effort mode: deeper reasoning, more thorough analysis | false |
| `--haiku` | Use Haiku model (fastest, lowest cost) | false |
| `--sonnet` | Use Sonnet model (balanced cost/quality) | false |
| `--opus` | Use Opus model (highest quality, same as agent default) | false |
| `--clean` | Skip automatic memory retrieval | false |

When `--team` is specified, implementation is delegated to `skill-team-implement` which spawns teammates to execute independent phases in parallel. Dependent phases wait for their dependencies. A debugger teammate can be spawned on build errors.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent implementation.

## Anti-Bypass Constraint

**PROHIBITION**: You MUST NOT write implementation summary artifacts directly using Write or Edit tools. All summary files MUST be created by invoking the appropriate skill (skill-implementer or skill-team-implement) via the Skill tool.

**Why**: Direct writes bypass format enforcement (validate-artifact.sh), produce non-conforming artifacts missing required metadata fields and sections, and circumvent the delegation chain that ensures quality. A PostToolUse hook monitors all Write/Edit operations to artifact paths and will flag violations with corrective context.

**Required**: Always delegate to the Skill tool. Never write to `specs/*/summaries/*.md` directly from this command.

## Execution

**Note**: Delegate to skills for task-type-specific implementation.

### STAGE 0: PARSE TASK NUMBERS

Parse raw arguments to extract task numbers and remaining arguments (flags, focus prompts).

**Algorithm** (inline `parse_task_args()`):

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

**Examples**:

| Input | task_numbers | remaining_args | Mode |
|-------|-------------|----------------|------|
| `7` | `[7]` | `` | single |
| `7, 22-24, 59` | `[7, 22, 23, 24, 59]` | `` | multi |
| `7 --force` | `[7]` | `--force` | single |
| `7, 22-24 --team` | `[7, 22, 23, 24]` | `--team` | multi |
| `10-12, 15 --force` | `[10, 11, 12, 15]` | `--force` | multi |

**Dispatch Decision**:

```
if len(task_numbers) == 1:
    # SINGLE-TASK MODE
    task_number = task_numbers[0]
    # Fall through to CHECKPOINT 1: GATE IN below (existing flow, unchanged)

elif len(task_numbers) > 1:
    # MULTI-TASK MODE
    # Continue to MULTI-TASK DISPATCH below
```

**Single-task fallthrough**: When exactly one task number is parsed (including degenerate ranges like `7-7` or `7,7,7` that deduplicate to `[7]`), execution continues directly to CHECKPOINT 1: GATE IN. The entire existing single-task flow is unchanged.

---

### MULTI-TASK DISPATCH

When `parse_task_args()` produces more than one task number, enter multi-task mode. This section replaces the single-task checkpoints for the batch operation.

#### Step 1: Batch Validation

Validate all tasks exist and have valid status before spawning any agents.

```bash
validated_tasks=()
skipped_tasks=()

for task_num in "${task_numbers[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)

  if [ -z "$task_data" ]; then
    skipped_tasks+=("$task_num: not found")
    continue
  fi

  status=$(echo "$task_data" | jq -r '.status')

  # Allowed statuses for /implement (same as GATE IN step 3)
  # With --force: also allow "completed"
  case "$status" in
    planned|implementing|partial|researched|not_started) ;;
    completed)
      if [ "$force_mode" = "true" ]; then
        : # Allow with --force
      else
        skipped_tasks+=("$task_num: already completed (use --force)")
        continue
      fi
      ;;
    abandoned)
      skipped_tasks+=("$task_num: abandoned (recover first)")
      continue
      ;;
    *)
      skipped_tasks+=("$task_num: invalid status [$status]")
      continue
      ;;
  esac

  validated_tasks+=("$task_num")
done
```

**Report skipped tasks** (warnings, non-blocking):
```
if skipped_tasks is not empty:
    [WARN] Skipping tasks:
      - {task_num}: {reason}
      ...

if validated_tasks is empty:
    [FAIL] No valid tasks to implement
    ABORT
```

#### Step 2: Generate Batch Session ID

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

#### Step 3: Dispatch Agents

For each validated task, spawn an independent implementation agent using the orchestrator's built-in batch loop:

- Extract task type per task (from state.json)
- Route per task using existing task-type-based routing from extension manifests
- Spawn one agent per task via parallel Task tool calls
- Per-task lifecycle: preflight status update, agent execution, postflight status update
- Collect results from all agents

**Note**: Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill.

**--force flag**: When `--force` is present in `remaining_args`, it is passed to each spawned agent, which bypasses status validation in its single-task GATE IN.

**--team flag**: When `--team` is present in `remaining_args`, each task gets team mode (multiple agents per task). Total agents = `N_tasks * team_size`. Cost warning applies.

#### Step 4: Batch Git Commit

After the batch skill returns results, produce a single git commit.

**Full success**:
```bash
git add -A
git commit -m "$(cat <<'EOF'
implement tasks {range_summary}: complete implementation

Tasks: {comma-separated list}
Session: {batch_session_id}

EOF
)"
```

**Partial success**:
```bash
git add -A
git commit -m "$(cat <<'EOF'
implement tasks {range_summary}: complete implementation ({succeeded}/{total} succeeded)

Tasks completed: {comma-separated}
Tasks failed: {num} ({reason})[, {num} ({reason})]
Session: {batch_session_id}

EOF
)"
```

Commit failure is non-blocking (log and continue).

#### Step 5: Consolidated Output

Display results after all agents complete.

```markdown
## Batch Implement Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {count}
Failed: {count}
Skipped: {count}

### Succeeded

| Task | Title | Status | Artifact |
|------|-------|--------|----------|
| #7 | project_name | [COMPLETED] | specs/007_slug/summaries/01_short-summary.md |
| #22 | project_name | [COMPLETED] | specs/022_slug/summaries/01_short-summary.md |

### Failed

| Task | Error |
|------|-------|
| #23 | Agent timeout |

### Skipped

| Task | Reason |
|------|--------|
| #99 | Not found in state.json |

### Next Steps
- Re-run failed tasks individually: /implement {N}
```

**After consolidated output, STOP.** The multi-task flow does not continue to CHECKPOINT 1.

---

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Implementing] Task {N}: {project_name}
```

1. **Generate Session ID**
   ```
   session_id = sess_{timestamp}_{random}
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber))' \
     specs/state.json)
   ```

3. **Validate**
   - Task exists (ABORT if not)
   - Status allows implementation: planned, implementing, partial, researched, not_started
   - If completed: ABORT unless --force
   - If abandoned: ABORT "Recover task first"

4. **Load Implementation Plan**
   Find latest: `specs/{NNN}_{SLUG}/plans/*.md` (sorted by version)

   If no plan: ABORT "No implementation plan found. Run /plan {N} first."

5. **Detect Resume Point**
   Scan plan for phase status markers:
   - [NOT STARTED] → Start here
   - [IN PROGRESS] → Resume here
   - [COMPLETED] → Skip
   - [PARTIAL] → Resume here

   If all [COMPLETED]: Task already done

**ABORT** if any validation fails.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 1.5 below.

### STAGE 1.5: PARSE FLAGS

**Parse arguments to determine team mode and other flags.**

1. **Extract Team Options**
   Check args for team flags:
   - `--team` -> `team_mode = true`
   - `--team-size N` -> `team_size = N` (clamp 2-4)

   If no team flag found: `team_mode = false`, `team_size = 2`

2. **Extract Other Flags**
   - `--force` -> `force_mode = true`

3. **Extract Effort Flags**
   Check remaining args for effort flags:
   - `--fast` -> `effort_flag = "fast"` (low-effort mode: lighter reasoning)
   - `--hard` -> `effort_flag = "hard"` (high-effort mode: deeper reasoning)

   If multiple are provided, last one wins.
   If none: `effort_flag = null` (normal effort)

4. **Extract Model Flags**
   Check remaining args for model flags:
   - `--haiku` -> `model_flag = "haiku"` (use Haiku model)
   - `--sonnet` -> `model_flag = "sonnet"` (use Sonnet model)
   - `--opus` -> `model_flag = "opus"` (use Opus model)

   If multiple are provided, last one wins.
   If none: `model_flag = null` (use agent default, currently opus for all agents)

5. **Validate Team Size**
   ```bash
   # Clamp team_size to valid range
   team_size=${team_size:-2}
   [ "$team_size" -lt 2 ] && team_size=2
   [ "$team_size" -gt 4 ] && team_size=4
   ```

6. **Extract Clean Flag**
   Check remaining args for memory retrieval suppression:
   - `--clean` -> `clean_flag = true` (skip automatic memory retrieval)

   If not present: `clean_flag = false`

**On STAGE 1.5 success**: Flags parsed. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present):

If `team_mode == true`:
- Route to `skill-team-implement`
- Pass `team_size` parameter

**Extension Routing** (when `--team` flag NOT present):

Check extension manifests for task-type-specific implement routing:

```bash
# Get task_type (may be simple "founder" or compound "founder:deck")
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')

# Check extension routing for implement (skill_name starts empty)
skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.implement[$tt] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base task_type
if [ -z "$skill_name" ] && echo "$task_type" | grep -q ":"; then
  base_type=$(echo "$task_type" | cut -d: -f1)
  for manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg tt "$base_type" \
        '.routing.implement[$tt] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

# Fallback to default implementer if no extension routing found
skill_name=${skill_name:-"skill-implementer"}
```

**Extension-Based Routing Table**:

| Language | Skill to Invoke |
|----------|-----------------|
| `founder` | `skill-founder-implement` (from founder extension) |
| `founder:deck` | `skill-deck-implement` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-implement` |
| `general`, `meta`, `markdown` | `skill-implementer` (default) |
| `formal`, `logic`, `math`, `physics` | `skill-implementer` (default) |

**Extension Skills Location**: Extension skills are located in `.claude/extensions/{ext}/skills/`. Claude Code discovers these skills via extension manifest `routing.implement` entries.

**Skill Selection Logic**:
```
if team_mode:
  skill_name = "skill-team-implement"
else:
  skill_name = {extension routing lookup} OR "skill-implementer"
```

**Invoke the Skill tool NOW** with:
```
# For team mode:
skill: "skill-team-implement"
args: "task_number={N} plan_path={path to implementation plan} resume_phase={phase number} team_size={team_size} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"

# For extension-routed skill (e.g., skill-founder-implement):
skill: "{skill_name from extension routing}"
args: "task_number={N} plan_path={path to implementation plan} resume_phase={phase number} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"

# For default single-agent mode:
skill: "skill-implementer"
args: "task_number={N} plan_path={path to implementation plan} resume_phase={phase number} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"
```

If `model_flag` is set, pass the `model` parameter to override the agent's default model:
- `model_flag="haiku"` -> pass `model: haiku`
- `model_flag="sonnet"` -> pass `model: sonnet`
- `model_flag="opus"` -> pass `model: opus`
- `model_flag=null` -> omit `model` parameter (use agent default, currently opus for all agents)

If `effort_flag` is set, pass it as prompt context to the skill/agent for reasoning depth guidance.

The skill will spawn the appropriate agent(s) which execute plan phases (in parallel for team mode), update phase markers, create commits per phase, and return a structured result.

**On DELEGATE success**: Implementation complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts, metadata (phases_completed, phases_total)

2. **Verify Artifacts**
   Check summary file exists on disk (if implemented)

3. **Verify Status Updated**
   The skill handles status updates internally (preflight and postflight).

   **If result.status == "implemented":**
   Confirm status is now "completed" in state.json.

   **If result.status == "partial":**
   Confirm status is still "implementing", resume point noted.

4. **Populate Completion Summary (if implemented)**

   **Only when result.status == "implemented":**

   Extract the summary from the skill result and update state.json:
   ```bash
   # Get completion summary from skill result (result.summary field)
   completion_summary="$result_summary"

   # Update state.json with completion_summary field
    jq --arg num "$task_number" \
       --arg summary "$completion_summary" \
       '(.active_projects[] | select(.project_number == ($num | tonumber))) += {
         completion_summary: $summary
       }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
   ```

   **Update TODO.md with Summary line:**
   Add a `- **Summary**: {completion_summary}` line to the task entry in TODO.md, after the Completed date line.

   **Skip if result.status == "partial":**
   Partial implementations do not get completion summaries.

5. **Verify Plan File Status Updated (Defensive)**

   **Only when result.status == "implemented":**

   Check that the plan file status marker was updated to `[COMPLETED]`. If not, apply defensive correction.

   ```bash
   # Find latest plan file
   padded_num=$(printf "%03d" "$task_number")
   project_name=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .project_name' \
     specs/state.json)
   plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)

   if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
       # Check if plan file has [COMPLETED] status
       if ! grep -qE '^\*\*Status\*\*: \[COMPLETED\]|^\- \*\*Status\*\*: \[COMPLETED\]' "$plan_file"; then
           echo "WARNING: Plan file status not updated to [COMPLETED]. Applying defensive correction."
           .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "COMPLETED"
       fi
   fi
   ```

   **Skip if result.status == "partial":**
   Partial implementations do not need plan file verification.

6. **Verify TODO.md Status (Defensive)**

   **Only when result.status == "implemented":**

   Check that the task entry in TODO.md shows `[COMPLETED]`. If it still shows `[IMPLEMENTING]`, apply correction:

   ```bash
   # Check if TODO.md task entry still shows [IMPLEMENTING]
   if grep -q "- \*\*Status\*\*: \[IMPLEMENTING\]" <(grep -A 5 "^### ${task_number}\." specs/TODO.md); then
       echo "WARNING: TODO.md status not updated to [COMPLETED]. Applying defensive correction."
   fi
   ```

   If the check finds a mismatch, use Edit tool to fix both:
   - Task entry: `- **Status**: [IMPLEMENTING]` → `- **Status**: [COMPLETED]`
   - Task Order: `**{N}** [IMPLEMENTING]` → `**{N}** [COMPLETED]`

7. **Post-Delegation Takeover Detection (Future Work)**

   > **Note**: A future enhancement should detect if the skill performed source-file reads, builds, or codebase exploration after the subagent returned. If the skill's tool-call sequence shows Read/Grep/Glob/Bash operations on non-specs files after the Task tool returned, log a warning: "Skill violated postflight boundary -- source operations detected after delegation." This is not currently enforced automatically but is documented as a desired GATE OUT validation.

**RETRY** skill if validation fails.

**On GATE OUT success**: Artifacts and completion summary verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

**On completion:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: complete implementation

Session: {session_id}

EOF
)"
```

**On partial:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: partial implementation (phases 1-{M} of {total})

Session: {session_id}

EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

**On Completion:**
```
Implementation complete for Task #{N}

Summary: specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md

Phases completed: {phases_completed}/{phases_total}

Status: [COMPLETED]
```

**On Partial:**
```
Implementation paused for Task #{N}

Completed: Phases 1-{M}
Remaining: Phase {M+1}

Status: [IMPLEMENTING]
Next: /implement {N}
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- No plan found: Return error "Run /plan {N} first"
- Invalid status: Return error with current status

### DELEGATE Failure
- Skill fails: Keep [IMPLEMENTING], log error
- Timeout: Progress preserved in plan phase markers, user can re-run

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Link failure: Non-blocking warning

### Build Errors
- Skill returns partial/failed status
- Error details included in result
- User can fix issues and re-run /implement
