---
description: Execute implementation with resume support
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit, Glob
argument-hint: TASK_NUMBER [--team [--team-size N]] [--force]
model: claude-opus-4-5-20251101
---

# /implement Command

Execute implementation plan with automatic resume support by delegating to the appropriate implementation skill/subagent.

## Arguments

- `$1` - Task number (required)
- Optional: `--force` to override status validation

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable parallel phase execution with multiple teammates | false |
| `--team-size N` | Number of implementation teammates to spawn (2-4) | 2 |
| `--force` | Override status validation | false |

When `--team` is specified, implementation is delegated to `skill-team-implement` which spawns teammates to execute independent phases in parallel. Dependent phases wait for their dependencies. A debugger teammate can be spawned on build errors.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent implementation.

## Execution

**Note**: Delegate to skills for language-specific implementation.

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

3. **Validate Team Size**
   ```bash
   # Clamp team_size to valid range
   team_size=${team_size:-2}
   [ "$team_size" -lt 2 ] && team_size=2
   [ "$team_size" -gt 4 ] && team_size=4
   ```

**On STAGE 1.5 success**: Flags parsed. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present):

If `team_mode == true`:
- Route to `skill-team-implement`
- Pass `team_size` parameter

**Extension Routing** (when `--team` flag NOT present):

Check extension manifests for language-specific implement routing:

```bash
# Get task language
language=$(echo "$task_data" | jq -r '.language // "general"')

# Check extension routing for implement (skill_name starts empty)
skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.implement[$lang] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback to default implementer if no extension routing found
skill_name=${skill_name:-"skill-implementer"}
```

**Extension-Based Routing Table**:

| Language | Skill to Invoke |
|----------|-----------------|
| `founder` | `skill-founder-implement` (from founder extension) |
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
args: "task_number={N} plan_path={path to implementation plan} resume_phase={phase number} team_size={team_size} session_id={session_id}"

# For extension-routed skill (e.g., skill-founder-implement):
skill: "{skill_name from extension routing}"
args: "task_number={N} plan_path={path to implementation plan} resume_phase={phase number} session_id={session_id}"

# For default single-agent mode:
skill: "skill-implementer"
args: "task_number={N} plan_path={path to implementation plan} resume_phase={phase number} session_id={session_id}"
```

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

**RETRY** skill if validation fails.

**On GATE OUT success**: Artifacts and completion summary verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

**On completion:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: complete implementation

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**On partial:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: partial implementation (phases 1-{M} of {total})

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
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
