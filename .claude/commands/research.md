---
description: Research a task and create reports
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBERS [FOCUS] [--team [--team-size N]] [--fast] [--hard] [--opus]
model: opus
---

# /research Command

Conduct research for a task by delegating to the appropriate research skill/subagent.

## Arguments

- `$1` - Task number(s) (required). Supports single task, comma-separated lists, and ranges.
- Remaining args - Optional focus/prompt for research direction (applies to all tasks in multi-task mode)

### Multi-Task Syntax

| Input | Tasks | Mode |
|-------|-------|------|
| `7` | 7 | single |
| `7, 22-24, 59` | 7, 22, 23, 24, 59 | multi |
| `7 focus on APIs` | 7 | single (with focus) |
| `7, 22-24 --team` | 7, 22, 23, 24 | multi (with team) |

When multiple tasks are specified, each task is researched independently in parallel. Flags and focus prompts apply uniformly to all tasks.

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable multi-agent parallel research with multiple teammates | false |
| `--team-size N` | Number of teammates to spawn (2-4) | 2 |
| `--fast` | Use Sonnet model (explicit low-cost mode) | false |
| `--hard` | Use Opus model (explicit high-effort mode) | false |
| `--opus` | Use Opus model (alias for --hard) | false |

When `--team` is specified, research is delegated to `skill-team-research` which spawns multiple research agents working in parallel on different aspects of the task. Each teammate produces a research report, and the lead synthesizes findings into a final comprehensive report.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent research.

## Anti-Bypass Constraint

**PROHIBITION**: You MUST NOT write research report artifacts directly using Write or Edit tools. All report files MUST be created by invoking the appropriate skill (skill-researcher or skill-team-research) via the Skill tool.

**Why**: Direct writes bypass format enforcement (validate-artifact.sh), produce non-conforming artifacts missing required metadata fields and sections, and circumvent the delegation chain that ensures quality. A PostToolUse hook monitors all Write/Edit operations to artifact paths and will flag violations with corrective context.

**Required**: Always delegate to the Skill tool. Never write to `specs/*/reports/*.md` directly from this command.

## Execution

**Note**: Delegate to skills for task-type-specific research.

### STAGE 0: PARSE TASK NUMBERS

Parse the raw argument string to separate task numbers from remaining arguments (flags and focus prompts).

**Algorithm**:

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

**Dispatch Decision**:

```
task_numbers = parse_task_args($ARGUMENTS)

if len(task_numbers) == 1:
    # SINGLE-TASK MODE
    task_number = task_numbers[0]
    remaining_args = $REMAINING_ARGS
    # Fall through to CHECKPOINT 1: GATE IN below
    # Existing single-task flow proceeds unchanged

elif len(task_numbers) > 1:
    # MULTI-TASK MODE
    # Continue to MULTI-TASK DISPATCH below
    # Do NOT enter CHECKPOINT 1
```

**On single task**: Fall through to CHECKPOINT 1: GATE IN below (existing flow unchanged).
**On multiple tasks**: Branch to MULTI-TASK DISPATCH section below. After dispatch completes, skip directly to output (do not enter single-task checkpoints).

---

### MULTI-TASK DISPATCH

When `parse_task_args()` produces more than one task number, execute batch research.

#### Step 1: Batch Validation

Validate all tasks exist and have valid status for research:

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

  # Allowed statuses for /research
  case "$status" in
    not_started|researched|planned|partial|blocked) validated_tasks+=("$task_num") ;;
    *) skipped_tasks+=("$task_num: invalid status [$status]") ;;
  esac
done
```

Report skipped tasks as warnings. If no validated tasks remain, ABORT.

#### Step 2: Generate Batch Session ID

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

#### Step 3: Dispatch Agents

For each validated task, spawn an independent research agent using the orchestrator's built-in batch loop:

1. Extract task_type per task from state.json
2. Route to the appropriate research skill per task (extension routing or default `skill-researcher`)
3. Spawn one agent per task via parallel Task tool calls
4. Each agent runs the full single-task research lifecycle independently (preflight, research, postflight)
5. Collect results from all agents

**Note**: Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill.

**Team mode interaction**: If `--team` is in `remaining_args`, team mode is applied to ALL tasks. Total agents spawned = `N_tasks * team_size`. Use with care due to cost multiplication.

#### Step 4: Batch Git Commit

After all agents complete, produce a single batch commit:

**Full success**:
```
research tasks {range_summary}: complete research

Tasks: {comma-separated list}
Session: {batch_session_id}
```

**Partial success**:
```
research tasks {range_summary}: complete research ({succeeded}/{total} succeeded)

Tasks completed: {comma-separated}
Tasks failed: {num} ({reason})[, {num} ({reason})]
Session: {batch_session_id}
```

#### Step 5: Consolidated Output

Display batch results and exit (do not enter single-task checkpoints):

```markdown
## Batch Research Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {count}
Failed: {count}
Skipped: {count}

### Succeeded

| Task | Title | Status | Artifact |
|------|-------|--------|----------|
| #7 | task_title | [RESEARCHED] | specs/007_slug/reports/01_short.md |

### Failed

| Task | Error |
|------|-------|
| #23 | Agent timeout |

### Skipped

| Task | Reason |
|------|--------|
| #99 | Not found in state.json |

### Next Steps
- /plan {succeeded_task_numbers}
```

#### Error Handling (Multi-Task)

- **Partial success is normal**: Failure of one task does not block or roll back others
- **Failed tasks**: Remain in "researching" status; user can re-run individually (`/research {N}`)
- **Skipped tasks**: Never dispatched; user fixes the issue and re-runs
- **Git conflicts**: Non-blocking (logged, not fatal)

---

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Researching] Task {N}: {project_name}
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

   task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
   ```

3. **Validate**
   - Task exists (ABORT if not)
   - Status allows research: not_started, planned, partial, blocked, researched
   - If completed/abandoned: ABORT with recommendation

**ABORT** if any validation fails.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 1.5 below.

### STAGE 1.5: PARSE FLAGS

**Parse arguments to determine team mode and focus prompt.**

1. **Extract Team Options**
   Check remaining args (after task number) for team flags:
   - `--team` -> `team_mode = true`
   - `--team-size N` -> `team_size = N` (clamp 2-4)

   If no team flag found: `team_mode = false`, `team_size = 2`

2. **Validate Team Size**
   ```bash
   # Clamp team_size to valid range
   team_size=${team_size:-2}
   [ "$team_size" -lt 2 ] && team_size=2
   [ "$team_size" -gt 4 ] && team_size=4
   ```

3. **Extract Model Override Flags**
   Check remaining args for model flags:
   - `--fast` -> `model_flag = "fast"` (uses Sonnet, explicit low-cost mode)
   - `--hard` -> `model_flag = "hard"` (uses Opus, explicit high-effort mode)
   - `--opus` -> `model_flag = "opus"` (uses Opus, explicit alias for --hard)

   If multiple are provided, last one wins.
   If none: `model_flag = null` (use agent default, which is Sonnet)

4. **Extract Focus Prompt**
   Remove all recognized flags from remaining args:
   - Remove `--team`
   - Remove `--team-size N` (flag and its value)
   - Remove `--fast`, `--hard`, `--opus`

   Remaining text is `focus_prompt`.

**On STAGE 1.5 success**: Flags parsed. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present):

If `team_mode == true`:
- Route to `skill-team-research` regardless of task_type
- Pass `team_size` parameter

**Extension Routing** (when `--team` flag NOT present):

Check extension manifests for task-type-specific research routing:

```bash
# Get task_type (may be simple "founder" or compound "founder:deck")
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')

# Check extension routing for research (skill_name starts empty)
skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.research[$tt] // empty' "$manifest")
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
        '.routing.research[$tt] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

# Fallback to default researcher if no extension routing found
skill_name=${skill_name:-"skill-researcher"}
```

**Extension-Based Routing Table**:

| Task Type | Skill to Invoke |
|-----------|-----------------|
| `founder` | `skill-market` (from founder extension) |
| `founder:deck` | `skill-deck-research` (from founder extension) |
| `founder:analyze` | `skill-analyze` (from founder extension) |
| `founder:strategy` | `skill-strategy` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-market` |
| `general`, `meta`, `markdown` | `skill-researcher` (default) |

**Skill Selection Logic**:
```
if team_mode:
  skill_name = "skill-team-research"
else:
  skill_name = {extension routing lookup} OR "skill-researcher"
```

**Invoke the Skill tool NOW** with:
```
# For team mode:
skill: "skill-team-research"
args: "task_number={N} focus={focus_prompt} team_size={team_size} session_id={session_id} model_flag={model_flag}"

# For single-agent mode:
skill: "{skill-name from table above}"
args: "task_number={N} focus={focus_prompt} session_id={session_id} model_flag={model_flag}"
```

If `model_flag` is set, pass the `model` parameter to override the agent's default model:
- `model_flag="fast"` -> pass `model: sonnet` (explicit Sonnet)
- `model_flag="hard"` or `model_flag="opus"` -> pass `model: opus` (override to Opus)
- `model_flag=null` -> omit `model` parameter (use agent default)

The skill will spawn the appropriate agent(s) to conduct research and create a report.

**On DELEGATE success**: Research complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts

2. **Verify Artifacts**
   Check each artifact path exists on disk

3. **Verify Status Updated**
   The skill handles status updates internally (preflight and postflight).
   Confirm status is now "researched" in state.json.

4. **Verify state.json Status (Defensive)**

   **Only when skill reports success:**

   Check that state.json shows status "researched" for this task. If not, apply defensive correction:

   ```bash
   # Check if state.json status is "researched"
   current_status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)

   if [ "$current_status" = "researched" | not ]; then
       echo "WARNING: state.json status is '$current_status', expected 'researched'. Applying defensive correction."
       bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
   fi
   ```

5. **Verify TODO.md Status (Defensive)**

   **Only when skill reports success:**

   Check that the task entry in TODO.md shows `[RESEARCHED]`. If it still shows `[RESEARCHING]`, apply correction:

   ```bash
   # Check if TODO.md task entry still shows [RESEARCHING]
   if grep -q "- \*\*Status\*\*: \[RESEARCHING\]" <(grep -A 5 "^### ${task_number}\." specs/TODO.md); then
       echo "WARNING: TODO.md status not updated to [RESEARCHED]. Applying defensive correction."
   fi
   ```

   If the check finds a mismatch, use Edit tool to fix both:
   - Task entry: `- **Status**: [RESEARCHING]` -> `- **Status**: [RESEARCHED]`
   - Task Order: `**{N}** [RESEARCHING]` -> `**{N}** [RESEARCHED]`

**RETRY** skill if validation fails.

**On GATE OUT success**: Artifacts verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: complete research

Session: {session_id}

EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

```
Research completed for Task #{N}

Report: specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md

Status: [RESEARCHED]
Next: /plan {N}
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Invalid status: Return error with current status

### DELEGATE Failure
- Skill fails: Keep [RESEARCHING], log error
- Timeout: Partial research preserved, user can re-run

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Link failure: Non-blocking warning
