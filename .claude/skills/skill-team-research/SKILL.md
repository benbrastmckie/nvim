---
name: skill-team-research
description: Orchestrate multi-agent research with wave-based parallel execution. Spawns 2-4 teammates for diverse investigation angles and synthesizes findings.
allowed-tools: Task, Bash, Edit, Read, Write
# This skill uses TeammateTool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
# Context loaded by lead during synthesis:
#   - .claude/context/patterns/team-orchestration.md
#   - .claude/context/formats/team-metadata-extension.md
#   - .claude/utils/team-wave-helpers.md
---

# Team Research Skill

Multi-agent research with wave-based parallelization. Spawns 2-4 teammates to investigate complementary angles, then synthesizes findings into a unified report.

**Task-Type-Aware Routing**: Teammates are spawned with task-type-appropriate prompts and tools. Meta tasks focus on .claude/ system patterns; general tasks use web search and codebase exploration.

**IMPORTANT**: This skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If team creation fails, gracefully degrades to single-agent research via skill-researcher.

## Context References

Reference (load as needed during synthesis):
- Path: `.claude/context/patterns/team-orchestration.md` - Wave coordination patterns
- Path: `.claude/context/formats/team-metadata-extension.md` - Team result schema
- Path: `.claude/context/formats/return-metadata-file.md` - Base metadata schema
- Path: `.claude/utils/team-wave-helpers.md` - Reusable wave patterns

## Trigger Conditions

This skill activates when:
- `/research N --team` is invoked
- Task exists and status allows research
- Team mode is requested via --team flag

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_number` | integer | Yes | Task to research |
| `focus_prompt` | string | No | Optional focus for research |
| `team_size` | integer | No | Number of teammates (2-4, default 2) |
| `session_id` | string | Yes | Session ID for tracking |
| `model_flag` | string | No | Model override (haiku, sonnet, opus). If set, use instead of default |
| `effort_flag` | string | No | Effort level (fast, hard). Passed as prompt context |

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must exist in state.json
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
description=$(echo "$task_data" | jq -r '.description // ""')

# Team research always uses 4 teammates (Primary, Alternatives, Critic, Horizons)
team_size=4
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE spawning teammates.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Change status marker to `[RESEARCHING]`.

---

### Stage 3: Create Postflight Marker

Create marker file to prevent premature termination:

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-team-research",
  "task_number": ${task_number},
  "operation": "team-research",
  "team_size": ${team_size},
  "reason": "Team research in progress: synthesis, status update, git commit pending"
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
  # Fall back to skill-researcher
  # ... (see Stage 4a)
fi
```

---

### Stage 4a: Fallback to Single Agent

If team mode is unavailable:

1. Log warning about degradation
2. Invoke `skill-researcher` via Skill tool
3. Pass original parameters
4. Add `degraded_to_single: true` to metadata
5. Continue with postflight

---

### Stage 5a: Calculate Artifact Number

Read `next_artifact_number` from state.json (or fall back to directory scanning for legacy tasks):

```bash
# Read next_artifact_number from state.json
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks: count existing artifacts
if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
# run_padded is now the artifact number for this team research run (e.g., "01")
```

**Note**: Team research uses the same artifact number for all teammates and synthesis. The artifact number advances after all teammates and synthesis complete.

---

### Stage 5b: Task Type Routing Decision

Determine task-type-specific configuration for teammate prompts:

```bash
# Route by task type
case "$task_type" in
  "meta")
    # Meta tasks - focus on .claude/ system patterns
    context_refs="@.claude/CLAUDE.md, @.claude/context/index.json"
    available_tools="Read, Grep, Glob"
    ;;
  *)
    # General tasks
    context_refs=""
    available_tools="WebSearch, WebFetch, Read, Grep, Glob"
    ;;
esac

# Determine model for teammates: use model_flag if provided, otherwise default to sonnet (cost-effective for team mode)
teammate_model="${model_flag:-sonnet}"

# Prepare model preference line for prompts (secondary guidance)
model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this analysis."
```

---

### Stage 5: Spawn Research Wave

Create teammate prompts and spawn wave. Pass `artifact_number` and `teammate_letter` to each teammate.

**Delegation context for teammates**:
```json
{
  "artifact_number": "{run_padded}",
  "teammate_letter": "a",
  "artifact_pattern": "{NN}_teammate-{letter}-findings.md",
  "roadmap_path": "specs/ROADMAP.md"
}
```

**Teammate A - Primary Angle**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: a

Focus on implementation approaches and patterns.
Challenge assumptions and provide specific examples.
Consider {focus_prompt} if provided.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-a-findings.md

Format: Markdown with clear sections for:
- Key Findings
- Recommended Approach
- Evidence/Examples
- Confidence Level (high/medium/low)
```

**Teammate B - Alternative Approaches**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: b

Focus on alternative patterns and prior art.
Look for existing solutions we could adapt.
Do NOT duplicate Teammate A's focus on primary approaches.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-b-findings.md

Format: Same as Teammate A
```

**Teammate C - Critic (always present)**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: c

You are the Critic. Your job is to identify gaps, shortcomings, and blind spots in the research.
Focus on:
- What assumptions haven't been validated?
- What could the other researchers be missing or getting wrong?
- Are there known limitations in the proposed approaches?
- Is the task scope complete, or are there important aspects being overlooked?
- What questions should be asked but aren't being asked?

Do NOT duplicate risk analysis (implementation risks). Focus on research quality and completeness.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-c-findings.md

Format: Same as Teammate A
```

**Teammate D - Horizons (always present)**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: d

You are the Horizons researcher. Your job is to think about long-term alignment and strategic direction.

Read the project roadmap at {roadmap_path} (from delegation context) if it exists.
If the roadmap file does not exist, contribute general strategic thinking about project direction.

Focus on:
- Does the proposed approach align with the project's long-term goals and priorities?
- Are there opportunities to advance adjacent roadmap items simultaneously?
- Could the task be scoped differently to better serve the project trajectory?
- What creative or unconventional approaches might better serve the long-term vision?
- What strategic challenges remain that this task could help address?

Think outside the box. Challenge conventional approaches where a better path exists.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-d-findings.md

Format: Same as Teammate A
```

---

**Spawn teammates using TeammateTool**.

**IMPORTANT**: Pass the `model` parameter to enforce model selection:
- Use `model: "${teammate_model}"` (from Stage 5b: model_flag if provided, otherwise "sonnet" as default)

The `model_preference_line` in prompts serves as secondary guidance only. The `model` parameter on TeammateTool is the enforced selection.

**Synthesis uses base number without letter**: After all teammates complete, the synthesis report uses `{run_padded}_{slug}.md` (e.g., `01_team-research.md`).

---

### Stage 6: Wait for Wave Completion

Wait for all teammates to complete or timeout:

```
Timeout: 30 minutes for Wave 1

While not all complete and not timed out:
  - Check teammate completion status
  - Collect completed results
  - Wait 30 seconds between checks

On timeout:
  - Mark remaining as "timeout"
  - Continue with available results
```

---

### Stage 7: Collect Teammate Results

Read each teammate's output file using run-scoped paths:

```bash
teammate_results=[]
padded_num=$(printf "%03d" "$task_number")

for teammate in a b c d; do
  # Use run-scoped path
  file="specs/${padded_num}_${project_name}/reports/${run_padded}_teammate-${teammate}-findings.md"
  if [ -f "$file" ]; then
    # Parse findings
    # Extract confidence level
    # Check for conflicts with other teammates
    teammate_results+=("...")
  fi
done
```

---

### Stage 8: Synthesize Findings

Lead synthesizes all teammate results:

1. **Extract key findings** from each teammate
2. **Detect conflicts** between findings
3. **Resolve conflicts** with evidence-based judgment
4. **Identify gaps** in coverage
5. **Decide on Wave 2** if significant gaps exist (not implemented in v1)

**Conflict Resolution**:
- Compare findings across teammates
- Log conflicts found
- Make judgment call based on evidence strength
- Document resolution reasoning

---

### Stage 9: Create Unified Report

Write synthesized report:

```markdown
# Research Report: Task #{N}

**Task**: {title}
**Date**: {ISO_DATE}
**Mode**: Team Research ({team_size} teammates)

## Summary

{Synthesized summary of findings}

## Key Findings

### Primary Approach (from Teammate A)
{Findings}

### Alternative Approaches (from Teammate B)
{Findings}

### Gaps and Shortcomings (from Critic)
{Findings}

### Strategic Horizons (from Horizons)
{Findings}

## Synthesis

### Conflicts Resolved
{List of conflicts and how they were resolved}

### Gaps Identified
{List of any remaining gaps}

### Recommendations
{Synthesized recommendations}

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary | completed | high |
| B | Alternatives | completed | medium |
| C | Critic | completed | high |
| D | Horizons | completed | medium |

## References

{Sources cited by teammates}
```

Output to: `specs/{NNN}_{SLUG}/reports/{RR}_team-research.md`

---

### Stage 10: Update Status (Postflight)

Update task status to "researched":

**Update state.json** (includes incrementing `next_artifact_number`):
```bash
# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Increment next_artifact_number (team research advances the sequence)
jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
    (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Note**: Team research (like single-agent research) is the only operation that increments `next_artifact_number`. Team plan and team implement use `(current - 1)` to stay in the same "round".

**Update TODO.md**: Change status marker to `[RESEARCHED]`.

**Link artifact**:
```bash
padded_num=$(printf "%03d" "$task_number")
jq --arg path "specs/${padded_num}_${project_name}/reports/${run_padded}_team-research.md" \
   --arg type "research" \
   --arg summary "Team research with ${team_size} teammates" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Link artifact using the automated script:

```bash
bash .claude/scripts/link-artifact-todo.sh $task_number '**Research**' '**Plan**' "$artifact_path"
```

If the script exits non-zero, log a warning but continue (linking errors are non-blocking).

---

### Stage 11: Write Metadata File

Write team execution metadata:

```json
{
  "status": "researched",
  "summary": "Team research completed with {N} teammates",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/{NNN}_{SLUG}/reports/{RR}_team-research.md",
      "summary": "Synthesized research from {team_size} teammates"
    }
  ],
  "team_execution": {
    "enabled": true,
    "wave_count": 1,
    "teammates_spawned": {team_size},
    "teammates_completed": {completed_count},
    "teammates_failed": {failed_count},
    "token_usage_multiplier": 5.0,
    "degraded_to_single": false
  },
  "teammate_results": [...],
  "synthesis": {
    "conflicts_found": {N},
    "conflicts_resolved": {N},
    "gaps_identified": {N},
    "wave_2_triggered": false
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "skill-team-research"
  }
}
```

---

### Stage 12: Git Commit

Commit using targeted staging (prevents race conditions with concurrent agents):

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/reports/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete team research (${team_size} teammates)

Session: ${session_id}
```

**Note**: Use targeted staging, NOT `git add -A`. See `.claude/context/standards/git-staging-scope.md`.

---

### Stage 13: Cleanup

Remove marker and temporary files:

```bash
padded_num=$(printf "%03d" "$task_number")
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
# Keep teammate findings files for reference
```

---

### Stage 14: Return Summary

Return brief text summary:

```
Team research completed for task {N}:
- Spawned {team_size} teammates for parallel investigation
- Teammate A: Primary approach findings (high confidence)
- Teammate B: Alternative patterns identified (medium confidence)
- {N} conflicts found and resolved
- Synthesized report at specs/{NNN}_{SLUG}/reports/{RR}_team-research.md
- Status updated to [RESEARCHED]
```

---

## Error Handling

### Team Creation Failure
- Fall back to skill-researcher
- Mark `degraded_to_single: true`
- Continue with single-agent research

### Teammate Timeout
- Continue with available results
- Note timeout in synthesis
- Mark result as partial if critical teammate missing

### Synthesis Failure
- Preserve raw teammate findings
- Mark status as partial
- Provide raw findings to user

### Git Commit Failure
- Non-blocking: log and continue
- Return success with warning

---

## Return Format

Brief text summary (NOT JSON):

```
Team research completed for task 412:
- Spawned 3 teammates for parallel investigation
- Teammate A: Implementation patterns (high confidence)
- Teammate B: Prior art analysis (medium confidence)
- Teammate C: Risk analysis (high confidence)
- 1 conflict resolved (approach preference)
- Synthesized report at specs/412_task_name/reports/01_team-research.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_...
```

---

## MUST NOT (Postflight Boundary)

After teammates complete and findings are synthesized, this skill MUST NOT:

1. **Edit source files** - All research work is done by teammates
2. **Run build/test commands** - Verification is done by teammates
3. **Use WebSearch/WebFetch** - Research tools are for teammate use only
4. **Analyze or grep source** - Analysis is teammate work
5. **Write reports** - Artifact creation is done during synthesis, not postflight

The postflight phase is LIMITED TO:
- Reading teammate metadata files
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
