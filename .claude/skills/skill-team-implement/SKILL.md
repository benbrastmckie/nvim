---
name: skill-team-implement
description: Orchestrate multi-agent implementation with parallel phase execution. Spawns teammates for independent phases and coordinates dependent phases. Includes debugger teammate for error recovery.
allowed-tools: Task, Bash, Edit, Read, Write, Glob
# This skill uses TeammateTool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
# Context loaded by lead during coordination:
#   - .claude/context/patterns/team-orchestration.md
#   - .claude/context/formats/team-metadata-extension.md
#   - .claude/extensions/core/context/reference/team-wave-helpers.md
---

# Team Implement Skill

Multi-agent implementation with wave-based phase parallelization. Analyzes phase dependencies to identify parallelization opportunities, spawns teammates for independent phases, and coordinates sequential execution of dependent phases.

**IMPORTANT**: This skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If team creation fails, gracefully degrades to single-agent implementation via skill-implementer.

## Context References

Reference (load as needed during coordination):
- Path: `.claude/context/patterns/team-orchestration.md` - Wave coordination patterns
- Path: `.claude/context/formats/team-metadata-extension.md` - Team result schema
- Path: `.claude/context/formats/return-metadata-file.md` - Base metadata schema
- Path: `.claude/extensions/core/context/reference/team-wave-helpers.md` - Reusable wave patterns

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
| `model_flag` | string | No | Model override (haiku, sonnet, opus). If set, use instead of default |
| `effort_flag` | string | No | Effort level (fast, hard). Passed as prompt context |

**Model Selection**: Determine teammate model early:
```bash
# Use model_flag if provided, otherwise default to sonnet (cost-effective for team mode)
teammate_model="${model_flag:-sonnet}"
model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this task."
```

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
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
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

Parse implementation plan to identify parallelization opportunities. Prefer explicit dependency data from the plan; fall back to heuristic inference for older plans.

**Primary: Explicit dependencies** (plans with `**Depends on**:` fields per phase):

```bash
# Parse explicit "**Depends on**:" fields from each phase
dependency_graph = {}
has_explicit_deps = false

for phase in phases:
  depends_on_field = parse_field(phase, "Depends on")
  if depends_on_field is not None:
    has_explicit_deps = true
    if depends_on_field == "none":
      deps = []
    else:
      deps = [int(x.strip()) for x in depends_on_field.split(",")]
    dependency_graph[phase.number] = {
      "status": phase.status,
      "depends_on": deps
    }
```

**Fallback: Heuristic inference** (plans without explicit dependency fields):

```bash
if not has_explicit_deps:
  # Build dependency graph from file overlap analysis
  dependency_graph = {}
  for phase in phases:
    dependency_graph[phase.number] = {
      "status": phase.status,
      "depends_on": infer_from_file_overlap(phase, phases),
      "files": phase.files_modified
    }
```

**Heuristic signals** (fallback only):
- Implicit dependencies from file modifications (phases modifying same files are dependent)
- Cross-phase imports or references

> **CRITICAL: Plan-Text-Only Analysis** -- Stage 5 analyzes dependencies using file paths and phase descriptions extracted from the plan text. The lead agent MUST NOT read, grep, or glob source files to infer dependencies. All signals come from parsing the plan document itself. Actual source file reading is the exclusive responsibility of phase implementer sub-agents.

---

### Stage 6: Calculate Implementation Waves

**Primary: Read wave table from plan** (plans with `**Dependency Analysis**` table):

```
# Parse the Dependency Analysis table from the plan
# Format: | Wave | Phases | Blocked by |
waves = parse_dependency_analysis_table(plan)

if waves is not empty:
  # Use pre-computed wave groupings directly
  # Example parsed result:
  #   Wave 1: [1]        (blocked by: --)
  #   Wave 2: [2, 3]     (blocked by: 1)
  #   Wave 3: [4]        (blocked by: 2, 3)
```

**Fallback: Compute from dependency graph** (plans without wave table):

```
if waves is empty:
  # Topological grouping from dependency_graph (Stage 5 output)
  Wave 1: Phases with no unfinished dependencies
  Wave 2: Phases depending on Wave 1
  Wave 3: Phases depending on Wave 2
  ...

  Example:
    Phase 1, 2, 3: No dependencies -> Wave 1 (parallel)
    Phase 4: Depends on 1, 2 -> Wave 2
    Phase 5: Depends on 3 -> Wave 2
    Phase 6: Depends on 4, 5 -> Wave 3
```

---

### Stage 7: Spawn Phase Implementers

For each wave, spawn teammates for parallelizable phases (up to team_size):

> **CRITICAL: Template Population from Plan Text Only** -- All template variables (`{phase_details}`, `{files_list}`, `{steps_from_plan}`, `{verification_criteria}`) MUST be populated by extracting text from the plan file. The lead agent MUST NOT read source files, run grep/glob, or use MCP tools to populate these fields. The sub-agent will read source files after it is spawned.

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

Execute waves sequentially, phases within wave in parallel. Detect Y-shaped
dependency patterns: when a single-phase "trunk" wave precedes a multi-phase
"branching" wave, execute the trunk with a single agent before spawning
parallel teammates for the branching waves.

```
# Y-shaped detection: classify each wave as trunk or branching
# A trunk wave has 1 phase and is followed by a wave with 2+ phases
for i, wave in enumerate(waves):
  next_wave = waves[i+1] if i+1 < len(waves) else None
  wave.is_trunk = (len(wave.phases) == 1 and
                   next_wave is not None and
                   len(next_wave.phases) > 1)

for wave in waves:
  if wave.is_trunk:
    # Trunk wave: execute single phase directly (no team spawning)
    phase = wave.phases[0]
    execute_phase_directly(phase)  # single agent, no teammate overhead
    mark_phase_complete(phase)
  else:
    # Branching or standard wave: spawn parallel teammates
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

**Update TODO.md**: Link artifact using the automated script:

```bash
bash .claude/scripts/link-artifact-todo.sh $task_number '**Summary**' '**Description**' "$artifact_path"
```

If the script exits non-zero, log a warning but continue (linking errors are non-blocking).

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

After teammates complete phase execution -- whether with status implemented, partial, or failed -- this skill MUST proceed immediately to postflight operations. The skill MUST NOT:

1. **Edit source files** - All implementation work is done by teammates
2. **Run build/test commands** - Verification is done by teammates
3. **Use MCP tools** - Domain tools are for teammate use only
4. **Analyze or grep source** - Analysis is teammate work
5. **Write summary/reports** - Artifact creation is done by teammates

> **PROHIBITION**: If a teammate returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the teammate's work. Report the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading teammate metadata files
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## MUST NOT (Pre-Delegation Boundary)

Before spawning phase implementer teammates, this skill MUST NOT:

1. **Read source files** - Source files are read by sub-agents, not the lead
2. **Grep or glob the codebase** - Codebase exploration is sub-agent work
3. **Use MCP tools** - Domain tools (LSP, build, etc.) are for sub-agent use only
4. **Analyze source code** - Code analysis belongs to phase implementers
5. **Run build or test commands** - Verification is done by sub-agents

The pre-delegation phase is LIMITED TO:
- Reading the plan file to extract phases, dependencies, and template variables
- Reading state.json and TODO.md for status updates
- Parsing phase dependency graphs from plan text
- Populating prompt templates with plan-extracted content
- Spawning sub-agents with delegation context
