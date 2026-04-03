---
description: Create implementation plan for a task
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBERS [--team [--team-size N]]
model: opus
---

# /plan Command

Create a phased implementation plan for a task by delegating to the planner skill/subagent.

## Arguments

- `$1` - Task number(s) (required). Supports:
  - Single task: `352`
  - Comma-separated: `7, 22, 59`
  - Ranges: `22-24`
  - Combined: `7, 22-24, 59`
- Remaining args - Optional flags

When multiple task numbers are provided, the command enters multi-task mode (see STAGE 0 below). Single task numbers fall through to the existing single-task flow unchanged.

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable multi-agent parallel planning with multiple teammates | false |
| `--team-size N` | Number of planning teammates to spawn (2-3) | 2 |

When `--team` is specified, planning is delegated to `skill-team-plan` which spawns multiple planning agents generating alternative plans in parallel. Each teammate produces a plan candidate, and the lead synthesizes findings into a final plan with trade-off analysis.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent planning.

## Execution

### STAGE 0: PARSE TASK NUMBERS

**Parse task arguments to separate task numbers from remaining args.**

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
| `7 --team` | `[7]` | `--team` | single |
| `7, 22-24 --team` | `[7, 22, 23, 24]` | `--team` | multi |
| `42 --team --team-size 3` | `[42]` | `--team --team-size 3` | single |

**Dispatch decision**:

```
task_numbers = parse_task_args($ARGUMENTS)

if len(task_numbers) == 1:
    # SINGLE-TASK MODE
    task_number = task_numbers[0]
    # Fall through to CHECKPOINT 1: GATE IN below
    # Existing single-task flow proceeds unchanged

elif len(task_numbers) > 1:
    # MULTI-TASK MODE
    # Continue to MULTI-TASK DISPATCH below
```

### MULTI-TASK DISPATCH

When `parse_task_args()` produces more than one task number, execute the batch flow below instead of the single-task checkpoints.

#### Step 1: Batch Validation

Validate all tasks exist and have status `researched` (the required status for planning):

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

  # /plan requires status = researched
  if [ "$status" = "researched" ] || [ "$status" = "not_started" ] || [ "$status" = "partial" ]; then
    validated_tasks+=("$task_num")
  else
    invalid_tasks+=("$task_num: invalid status [$status]")
  fi
done

# Report invalid tasks but continue with valid ones
if [ ${#invalid_tasks[@]} -gt 0 ]; then
  echo "[WARN] Skipping invalid tasks:"
  for msg in "${invalid_tasks[@]}"; do
    echo "  - $msg"
  done
fi

if [ ${#validated_tasks[@]} -eq 0 ]; then
  echo "[FAIL] No valid tasks to process"
  exit 1
fi
```

#### Step 2: Generate Batch Session ID

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

#### Step 3: Invoke Batch Skill

Invoke a single batch skill that handles parallel agent spawning and result collection:

```
Tool: Skill
Parameters:
  skill: "skill-batch-dispatch"
  args: |
    command=plan
    task_numbers={validated_tasks}
    session_id={batch_session_id}
    remaining_args={remaining_args}
```

The batch skill:
1. Extracts language per task from state.json
2. Routes each task to the appropriate planner skill (extension routing or default `skill-planner`)
3. Spawns one agent per task via parallel Task tool calls
4. Collects results from all agents
5. Produces consolidated status update

#### Step 4: Batch Git Commit

After the batch skill returns, produce a single git commit:

**Full success**:
```
plan tasks {range_summary}: create implementation plan

Tasks: {comma-separated list}
Session: {batch_session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

**Partial success**:
```
plan tasks {range_summary}: create implementation plan ({succeeded}/{total} succeeded)

Tasks completed: {comma-separated}
Tasks failed: {num} ({reason})[, {num} ({reason})]
Session: {batch_session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

#### Step 5: Consolidated Output

```markdown
## Batch Plan Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {count}
Failed: {count}
Skipped: {count}

### Succeeded

| Task | Title | Status | Artifact |
|------|-------|--------|----------|
| #7 | task_title | [PLANNED] | specs/007_slug/plans/01_short.md |
| #22 | task_title | [PLANNED] | specs/022_slug/plans/01_short.md |

### Failed

| Task | Error |
|------|-------|
| #23 | Invalid status [IMPLEMENTING] |

### Skipped

| Task | Reason |
|------|--------|
| #99 | Not found in state.json |

### Next Steps
- /implement 7, 22, 24, 59
```

**End of multi-task flow. Do NOT continue to the single-task checkpoints below.**

---

**The sections below handle SINGLE-TASK mode only (when `parse_task_args()` produces exactly one task number).**

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Planning] Task {N}: {project_name}
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
   - Status allows planning: not_started, researched, partial
   - If planned: Note existing plan, offer --force for revision
   - If completed: ABORT "Task already completed"
   - If implementing: ABORT "Task in progress, use /revise instead"

4. **Load Context**
   - Task description from state.json
   - Research reports from `specs/{NNN}_{SLUG}/reports/` (if any)

**ABORT** if any validation fails.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 1.5 below.

### STAGE 1.5: PARSE FLAGS

**Parse arguments to determine team mode.**

1. **Extract Team Options**
   Check args for team flags:
   - `--team` -> `team_mode = true`
   - `--team-size N` -> `team_size = N` (clamp 2-3)

   If no team flag found: `team_mode = false`, `team_size = 2`

2. **Validate Team Size**
   ```bash
   # Clamp team_size to valid range (2-3 for planning)
   team_size=${team_size:-2}
   [ "$team_size" -lt 2 ] && team_size=2
   [ "$team_size" -gt 3 ] && team_size=3
   ```

**On STAGE 1.5 success**: Flags parsed. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present):

If `team_mode == true`:
- Route to `skill-team-plan`
- Pass `team_size` parameter

**Extension Routing** (when `--team` flag NOT present):

Check extension manifests for language-specific plan routing:

```bash
# Get task language (may be simple "founder" or compound "founder:deck")
language=$(echo "$task_data" | jq -r '.language // "general"')

# Check extension routing for plan (skill_name starts empty)
skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.plan[$lang] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base language
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  for manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg lang "$base_lang" \
        '.routing.plan[$lang] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

# Fallback to default planner if no extension routing found
skill_name=${skill_name:-"skill-planner"}
```

**Extension-Based Routing Table**:

| Language | Skill to Invoke |
|----------|-----------------|
| `founder` | `skill-founder-plan` (from founder extension) |
| `founder:deck` | `skill-deck-plan` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-plan` |
| Other | `skill-planner` (default) |

**Skill Selection Logic**:
```
if team_mode:
  skill_name = "skill-team-plan"
else:
  skill_name = {extension routing lookup} OR "skill-planner"
```

**Invoke the Skill tool NOW** with:
```
# For team mode:
skill: "skill-team-plan"
args: "task_number={N} research_path={path to research report if exists} team_size={team_size} session_id={session_id}"

# For extension-routed skill (e.g., skill-founder-plan):
skill: "{skill_name from extension routing}"
args: "task_number={N} research_path={path to research report if exists} session_id={session_id}"

# For default single-agent mode:
skill: "skill-planner"
args: "task_number={N} research_path={path to research report if exists} session_id={session_id}"
```

The skill spawns agent(s) which analyze task requirements and research findings, decompose into logical phases, identify risks and mitigations, and create a plan in `specs/{NNN}_{SLUG}/plans/`.

**On DELEGATE success**: Plan created. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts, metadata (phase_count, estimated_hours)

2. **Verify Artifacts**
   Check plan file exists on disk

3. **Verify Status Updated**
   The skill handles status updates internally (preflight and postflight).
   Confirm status is now "planned" in state.json.

4. **Verify state.json Status (Defensive)**

   **Only when skill reports success:**

   Check that state.json shows status "planned" for this task. If not, apply defensive correction:

   ```bash
   # Check if state.json status is "planned"
   current_status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)

   if [ "$current_status" = "planned" | not ]; then
       echo "WARNING: state.json status is '$current_status', expected 'planned'. Applying defensive correction."
       bash .claude/scripts/update-task-status.sh postflight "$task_number" plan "$session_id"
   fi
   ```

5. **Verify TODO.md Status (Defensive)**

   **Only when skill reports success:**

   Check that the task entry in TODO.md shows `[PLANNED]`. If it still shows `[PLANNING]`, apply correction:

   ```bash
   # Check if TODO.md task entry still shows [PLANNING]
   if grep -q "- \*\*Status\*\*: \[PLANNING\]" <(grep -A 5 "^### ${task_number}\." specs/TODO.md); then
       echo "WARNING: TODO.md status not updated to [PLANNED]. Applying defensive correction."
   fi
   ```

   If the check finds a mismatch, use Edit tool to fix both:
   - Task entry: `- **Status**: [PLANNING]` -> `- **Status**: [PLANNED]`
   - Task Order: `**{N}** [PLANNING]` -> `**{N}** [PLANNED]`

6. **Verify Plan File Status (Defensive)**

   **Only when skill reports success:**

   Check that the plan file status marker shows `[NOT STARTED]` (expected state for a newly created plan). If it shows something unexpected like `[PLANNING]`, log a warning:

   ```bash
   # Find latest plan file
   padded_num=$(printf "%03d" "$task_number")
   project_name=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .project_name' \
     specs/state.json)
   plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)

   if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
       # Check if plan file has a valid status (NOT STARTED or IMPLEMENTING)
       if grep -qE '^\*\*Status\*\*: \[PLANNING\]|^\- \*\*Status\*\*: \[PLANNING\]' "$plan_file"; then
           echo "WARNING: Plan file status still shows [PLANNING]. Expected [NOT STARTED] for newly created plan."
       fi
   fi
   ```

**RETRY** skill if validation fails.

**On GATE OUT success**: Plan verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: create implementation plan

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

```
Plan created for Task #{N}

Plan: specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md

Phases: {phase_count}
Estimated effort: {estimated_hours}

Status: [PLANNED]
Next: /implement {N}
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Invalid status: Return error with current status

### DELEGATE Failure
- Skill fails: Keep [PLANNING], log error
- Timeout: Partial plan preserved, user can re-run

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Link failure: Non-blocking warning
