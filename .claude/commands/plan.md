---
description: Create implementation plan for a task
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER [--team [--team-size N]]
model: opus
---

# /plan Command

Create a phased implementation plan for a task by delegating to the planner skill/subagent.

## Arguments

- `$1` - Task number (required)

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable multi-agent parallel planning with multiple teammates | false |
| `--team-size N` | Number of planning teammates to spawn (2-3) | 2 |

When `--team` is specified, planning is delegated to `skill-team-plan` which spawns multiple planning agents generating alternative plans in parallel. Each teammate produces a plan candidate, and the lead synthesizes findings into a final plan with trade-off analysis.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent planning.

## Execution

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
# Get task language
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

# Fallback to default planner if no extension routing found
skill_name=${skill_name:-"skill-planner"}
```

**Extension-Based Routing Table**:

| Language | Skill to Invoke |
|----------|-----------------|
| `founder` | `skill-founder-plan` (from founder extension) |
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
