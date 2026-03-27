---
name: skill-team-implement
description: Orchestrate multi-agent implementation with parallel phase execution. Spawns teammates for independent phases and coordinates dependent phases. Includes debugger teammate for error recovery.
allowed-tools: Task, Bash, Edit, Read, Write, Glob
# This skill uses TeammateTool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
# Context loaded by lead during coordination:
#   - .claude/context/patterns/team-orchestration.md
#   - .claude/context/formats/team-metadata-extension.md
#   - .claude/utils/team-wave-helpers.md
---

# Team Implement Skill

Multi-agent implementation with wave-based phase parallelization. Analyzes phase dependencies to identify parallelization opportunities, spawns teammates for independent phases, and coordinates sequential execution of dependent phases.

**IMPORTANT**: This skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If team creation fails, gracefully degrades to single-agent implementation via skill-implementer.

## Context References

Reference (load as needed during coordination):
- Path: `.claude/context/patterns/team-orchestration.md` - Wave coordination patterns
- Path: `.claude/context/formats/team-metadata-extension.md` - Team result schema
- Path: `.claude/context/formats/return-metadata-file.md` - Base metadata schema
- Path: `.claude/utils/team-wave-helpers.md` - Reusable wave patterns

## Trigger Conditions

This skill activates when:
- `/implement N --team` is invoked
- Task exists and has implementation plan
- Team mode is requested via --team flag

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_number` | integer | Yes | Task to implement |
| `plan_path` | string | Yes | Path to implementation plan |
| `resume_phase` | integer | No | Phase to resume from |
| `team_size` | integer | No | Max concurrent teammates (2-4, default 2) |
| `session_id` | string | Yes | Session ID for tracking |

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must exist in state.json
- `plan_path` - Must exist and contain phases
- `team_size` - Clamp to range [2, 4], default 2

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')

# Validate plan exists
if [ ! -f "$plan_path" ]; then
  return error "Plan not found: $plan_path"
fi

# Validate team_size
team_size=${team_size:-2}
[ "$team_size" -lt 2 ] && team_size=2
[ "$team_size" -gt 4 ] && team_size=4
```

---

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE spawning teammates.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Change status marker to `[IMPLEMENTING]`.

---

### Stage 3: Create Postflight Marker

Create marker file to prevent premature termination:

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-team-implement",
  "task_number": ${task_number},
  "operation": "team-implement",
  "team_size": ${team_size},
  "reason": "Team implementation in progress: phase coordination, status update, git commit pending"
}
EOF
```

---

### Stage 4: Check Team Mode Availability

Verify Agent Teams feature is available:

```bash
# Check environment variable
if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  echo "Warning: Team mode unavailable, falling back to single agent"
  # Fall back to skill-implementer (see Stage 4a)
fi
```

---

### Stage 4a: Fallback to Single Agent

If team mode is unavailable:

1. Log warning about degradation
2. Invoke `skill-implementer` via Skill tool
3. Pass original parameters
4. Add `degraded_to_single: true` to metadata
5. Continue with postflight

---

### Stage 4b: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since summary stays in the same round as research/plan:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Implement uses (current - 1) to stay in the same round as research/plan
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks: count existing summary artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/summaries/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
```

**Note**: Team implement does NOT increment `next_artifact_number`. Only research advances the sequence.

---

### Stage 5: Analyze Phase Dependencies

Parse implementation plan to identify parallelization opportunities:

```bash
# Extract phases and their dependencies
# Phases with no unfinished dependencies can run in parallel

# Phase structure analysis:
# - Phase status: [NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL]
# - Dependencies: Listed in phase or inferred from file modifications

# Build dependency graph
dependency_graph = {}
for phase in phases:
  dependency_graph[phase.number] = {
    "status": phase.status,
    "depends_on": phase.dependencies,
    "files": phase.files_modified
  }

# Find parallelizable phases (no unfinished dependencies)
parallel_phases = [p for p in phases
                   if all(dep_status == "completed" for dep in p.dependencies)]
```

**Dependency Analysis**:
- Explicit dependencies from plan metadata
- Implicit dependencies from file modifications (phases modifying same files are dependent)
- Cross-phase imports or references

---

### Stage 6: Calculate Implementation Waves

Group phases into waves based on dependencies:

```
Wave 1: Phases with no unfinished dependencies
Wave 2: Phases depending on Wave 1
Wave 3: Phases depending on Wave 2
...

Example:
  Plan has phases 1, 2, 3, 4, 5, 6
  Phase 1, 2, 3: No dependencies -> Wave 1 (parallel)
  Phase 4: Depends on 1, 2 -> Wave 2
  Phase 5: Depends on 3 -> Wave 2
  Phase 6: Depends on 4, 5 -> Wave 3 (sequential after Wave 2)
```

---

### Stage 7: Spawn Phase Implementers

For each wave, spawn teammates for parallelizable phases (up to team_size):

**Phase Implementer Prompt Template**:
```
Implement phase {P} of task {task_number}: {phase_name}

{model_preference_line}

## Plan Context
{phase_details from plan}

## Files to Modify
{files_list}

## Steps
{steps_from_plan}

## Verification
{verification_criteria}

## Instructions
1. Read existing files before modifying
2. Execute steps in order
3. Verify completion with criteria
4. Update phase status in plan file to [COMPLETED]
5. Write results to: specs/{NNN}_{SLUG}/phases/{RR}_phase-{P}-results.md

## On Error
If build/test fails:
1. Write error details to results file
2. Mark phase [PARTIAL] instead of [COMPLETED]
3. Return with error context for debugger
```

---

### Stage 8: Wave Execution Loop

Execute waves sequentially, phases within wave in parallel:

```
for wave in waves:
  # Spawn teammates for this wave (up to team_size concurrent)
  active_teammates = []
  for phase in wave.phases[:team_size]:
    teammate = spawn_phase_implementer(phase)
    active_teammates.append(teammate)

  # Wait for wave completion
  while not all_complete(active_teammates):
    for teammate in active_teammates:
      if teammate.complete():
        result = teammate.result
        if result.error:
          # Spawn debugger for this phase
          spawn_debugger(phase, result.error)
        else:
          mark_phase_complete(phase)

    # Spawn additional teammates if slots available
    remaining_phases = wave.phases[len(active_teammates):]
    for phase in remaining_phases[:team_size - len(active)]:
      spawn_phase_implementer(phase)

  # Commit wave progress
  git_commit_wave(wave)
```

---

### Stage 9: Handle Phase Errors (Debugger Teammate)

When a phase implementer encounters an error:

**Debugger Teammate Prompt**:
```
Analyze and fix the error in task {task_number} phase {P}:

{model_preference_line}

## Error Details
{error_output}

## Phase Context
{phase_details}

## Files Involved
{files_list}

## Instructions
1. Analyze the error cause
2. Generate hypothesis
3. Attempt fix
4. Verify fix with build/test
5. If fixed: Mark phase [COMPLETED]
6. If not fixable: Document issue and mark [BLOCKED]

Output diagnosis to: specs/{NNN}_{SLUG}/debug/{RR}_phase-{P}-debug.md
```

---

### Stage 10: Per-Wave Commits

After each wave completes, commit progress:

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/" \
  "specs/TODO.md" \
  "$plan_path"
git commit -m "task ${task_number}: complete wave ${wave_num} (phases ${phase_list})

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Stage 11: Create Implementation Summary

After all waves complete, write summary:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Mode**: Team Implementation ({team_size} max concurrent teammates)
**Duration**: {time}

## Wave Execution

### Wave 1
- Phase 1: {status} ({teammate})
- Phase 2: {status} ({teammate})
- Phase 3: {status} ({teammate})

### Wave 2
- Phase 4: {status} ({teammate})
- Phase 5: {status} ({teammate})

### Wave 3
- Phase 6: {status} ({teammate})

## Changes Made

{Summary of changes from all phases}

## Files Modified

- `path/to/file` - {change description}

## Verification

- Build: {Pass/Fail}
- Tests: {Pass/Fail/N/A}

## Team Metrics

| Metric | Value |
|--------|-------|
| Total phases | {N} |
| Waves executed | {N} |
| Max parallelism | {N} |
| Debugger invocations | {N} |
| Total teammates spawned | {N} |

## Notes

{Any issues, blockers, or follow-up items}
```

Output to: `specs/{NNN}_{SLUG}/summaries/{RR}_implementation-summary.md`

---

### Stage 12: Update Status (Postflight)

Update task status to "completed":

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Change status marker to `[COMPLETED]`.

**Link artifact**:
```bash
padded_num=$(printf "%03d" "$task_number")
jq --arg path "specs/${padded_num}_${project_name}/summaries/${run_padded}_implementation-summary.md" \
   --arg type "summary" \
   --arg summary "Team implementation with ${team_size} max concurrent teammates" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 13: Write Metadata File

Write team execution metadata:

```json
{
  "status": "implemented",
  "summary": "Team implementation completed with parallel phase execution",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{RR}_implementation-summary.md",
      "summary": "Implementation summary with wave execution details"
    }
  ],
  "team_execution": {
    "enabled": true,
    "wave_count": {N},
    "teammates_spawned": {total_count},
    "max_parallelism": {team_size},
    "debugger_invocations": {N},
    "token_usage_multiplier": 5.0,
    "degraded_to_single": false
  },
  "completion_data": {
    "completion_summary": "Brief description of what was implemented",
    "claudemd_suggestions": "Changes to .claude/ (meta tasks) or 'none'"
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "skill-team-implement",
    "phases_completed": {N},
    "phases_total": {N}
  }
}
```

---

### Stage 14: Final Git Commit

Final commit with summary:

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/summaries/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json" \
  "$plan_path"
git commit -m "task ${task_number}: complete team implementation

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Stage 15: Cleanup

Remove marker and temporary files:

```bash
padded_num=$(printf "%03d" "$task_number")
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
# Keep phase results and debug files for reference
```

---

### Stage 16: Return Summary

Return brief text summary:

```
Team implementation completed for task {N}:
- Executed {wave_count} waves with up to {team_size} parallel teammates
- Wave 1: Phases 1, 2, 3 (parallel)
- Wave 2: Phases 4, 5 (parallel, after Wave 1)
- Wave 3: Phase 6 (sequential)
- {debugger_count} debugger invocations for error recovery
- All {phase_count} phases completed
- Summary at specs/{NNN}_{SLUG}/summaries/{RR}_implementation-summary.md
- Status updated to [COMPLETED]
```

---

## Error Handling

### Team Creation Failure
- Fall back to skill-implementer
- Mark `degraded_to_single: true`
- Continue with single-agent implementation

### Phase Timeout
- Mark phase [PARTIAL]
- Continue with remaining phases if independent
- Log timeout in summary

### Build/Test Failure
- Spawn debugger teammate
- If debugger succeeds: Continue
- If debugger fails: Mark [BLOCKED], continue with independent phases

### All Phases Blocked
- Return partial status
- Document blocking issues
- User can resolve and re-run

### Git Commit Failure
- Non-blocking: log and continue
- Return success with warning

---

## Return Format

Brief text summary (NOT JSON):

```
Team implementation completed for task 412:
- Executed 3 waves with up to 2 parallel teammates
- Wave 1: Phases 1, 2 completed in parallel
- Wave 2: Phase 3, 4 completed in parallel
- Wave 3: Phase 5, 6 completed in parallel
- 1 debugger invocation for build error (resolved)
- All 6 phases completed
- Summary at specs/412_task_name/summaries/01_implementation-summary.md
- Status updated to [COMPLETED]
- Changes committed with session sess_...
```

### Partial Return

```
Team implementation partially completed for task 412:
- Executed 2 of 3 waves
- Wave 1: Phases 1, 2 completed
- Wave 2: Phase 3 [BLOCKED] (build error unresolved)
- Remaining: Phases 4, 5, 6 blocked by Phase 3
- Debugger attempted fix, see debug report
- Status remains [IMPLEMENTING]
- Run /implement 412 to resume after fixing Phase 3
```

---

## MUST NOT (Postflight Boundary)

After teammates complete phase execution, this skill MUST NOT:

1. **Edit source files** - All implementation work is done by teammates
2. **Run build/test commands** - Verification is done by teammates
3. **Use MCP tools** - Domain tools are for teammate use only
4. **Analyze or grep source** - Analysis is teammate work
5. **Write summary/reports** - Artifact creation is done by teammates

The postflight phase is LIMITED TO:
- Reading teammate metadata files
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
