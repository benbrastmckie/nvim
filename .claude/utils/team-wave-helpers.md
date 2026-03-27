# Team Wave Helpers

Reusable patterns for wave-based team coordination.

## Overview

This file contains reference patterns for implementing team skills. Copy and adapt these patterns rather than importing directly.

## Artifact Numbering Helpers

### Unified Artifact Numbering

All artifacts (reports, plans, summaries) share a single sequence number per task within a "round" of work. Research advances the sequence; plan and implement reuse the current number.

**Read Artifact Number for Research (advances sequence)**:
```bash
# Read next_artifact_number from state.json
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks
if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${SLUG}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
# After completion, increment: next_artifact_number = artifact_number + 1
```

**Read Artifact Number for Plan/Implement (stays in same round)**:
```bash
# Read next_artifact_number and use (current - 1)
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Plan/implement use (current - 1) to stay in same round
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
# Do NOT increment next_artifact_number after completion
```

### Team Mode Artifact Naming

**Teammate Artifacts**: `{NN}_teammate-{letter}-findings.md`
- Example: `01_teammate-a-findings.md`, `01_teammate-b-findings.md`

**Synthesis Artifacts**: `{NN}_{slug}.md` (base number, no letter)
- Example: `01_team-research.md`, `01_implementation-plan.md`

**Key Principle**: All artifacts from the same research round share the same base number. Letter suffixes distinguish parallel work within a round.

---

## Wave Spawning Pattern

### Spawn Research Wave

Spawn 2-4 teammates for parallel research. First, calculate the artifact number using unified numbering:

```bash
# Read next_artifact_number from state.json (research advances the sequence)
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks
if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${SLUG}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
```

Then spawn teammates with run-scoped output paths. **Pass the `model` parameter** to enforce model selection:

```
# Research Wave Spawning (run {RR})
Wave 1 teammates:
1. Primary Angle (required)
   - Name: "{Task}ResearcherA"
   - Model: "sonnet"
   - Prompt: "Research {task} focusing on implementation approaches.
     Challenge assumptions. Provide specific examples.
     Output to: specs/{NNN}_{SLUG}/reports/{RR}_teammate-a-findings.md"

2. Alternative Approaches (required)
   - Name: "{Task}ResearcherB"
   - Prompt: "Research {task} focusing on alternative patterns and prior art.
     Look for existing solutions we could adapt.
     Output to: specs/{NNN}_{SLUG}/reports/{RR}_teammate-b-findings.md"

3. Risk Analysis (optional, size >= 3)
   - Name: "{Task}ResearcherC"
   - Prompt: "Research {task} focusing on risks, blockers, and edge cases.
     Identify what could go wrong.
     Output to: specs/{NNN}_{SLUG}/reports/{RR}_teammate-c-findings.md"

4. Devil's Advocate (optional, size >= 4)
   - Name: "{Task}ResearcherD"
   - Prompt: "Challenge findings from other teammates.
     Look for gaps, inconsistencies, and missed alternatives.
     Output to: specs/{NNN}_{SLUG}/reports/{RR}_teammate-d-findings.md"
```

### Spawn Planning Wave

Spawn teammates for parallel plan generation. First, calculate the artifact number using unified numbering:

```bash
# Read next_artifact_number and use (current - 1) since plan stays in same round
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Plan uses (current - 1) to stay in same round as research
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${SLUG}/plans/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
```

Then spawn teammates with run-scoped output paths:

```
# Planning Wave Spawning (run {RR})
Wave 1 teammates:
1. Plan Version A (required)
   - Name: "{Task}PlannerA"
   - Model: "sonnet"
   - Prompt: "Create a phased implementation plan for {task}.
     Focus on incremental delivery with verification at each phase.
     Output to: specs/{NNN}_{SLUG}/plans/{RR}_candidate-a.md"

2. Plan Version B (required)
   - Name: "{Task}PlannerB"
   - Prompt: "Create an alternative implementation plan for {task}.
     Consider different phase boundaries or ordering.
     Output to: specs/{NNN}_{SLUG}/plans/{RR}_candidate-b.md"

3. Risk/Dependency Analysis (optional, size >= 3)
   - Name: "{Task}PlannerC"
   - Prompt: "Analyze dependencies and risks for implementing {task}.
     Identify which phases can be parallelized vs sequential.
     Output to: specs/{NNN}_{SLUG}/plans/{RR}_risk-analysis.md"
```

### Spawn Implementation Wave

Spawn teammates for parallel phase execution:

```
# Implementation Wave Spawning
For each independent phase group:
1. Phase Implementer (per independent phase)
   - Name: "{Task}Phase{P}Impl"
   - Model: "sonnet"
   - Prompt: "Implement phase {P} of the plan for {task}.
     Follow the steps in the implementation plan.
     Update phase status markers as you complete.
     Write results to: specs/{NNN}_{SLUG}/phases/{RR}_phase-{P}-results.md"

2. Debugger (spawned on error)
   - Name: "{Task}Debugger"
   - Model: "sonnet"
   - Prompt: "Analyze the error in {task} implementation.
     Error: {error_details}
     Generate hypothesis and create debug report at:
     specs/{NNN}_{SLUG}/debug/{RR}_phase-{P}-debug.md"
```

## Wait and Collect Pattern

### Wait for Wave Completion

```
# Wait for all teammates in wave
For each teammate in current wave:
  1. Check if teammate has notified completion
  2. If not, wait with timeout (30 min per wave)
  3. On timeout: mark as timed out, continue with available

Collect results:
  1. Read each teammate's output file
  2. Parse status (completed/partial/failed)
  3. Store in teammate_results array
```

### Collect Teammate Results

Use run-scoped paths to collect teammate findings:

```bash
# Pattern: Collect results from teammate files (run-scoped)
padded_num=$(printf "%03d" "$task_number")
teammate_files=(
  "specs/${padded_num}_${SLUG}/reports/${run_padded}_teammate-a-findings.md"
  "specs/${padded_num}_${SLUG}/reports/${run_padded}_teammate-b-findings.md"
  # ... add more as needed based on team_size
)

for file in "${teammate_files[@]}"; do
  if [ -f "$file" ]; then
    # Parse findings from file
    # Add to teammate_results
  else
    # Mark as failed/missing
  fi
done
```

## Synthesis Pattern

### Lead Synthesis Loop

```
# Synthesis procedure
1. Initialize synthesis object
   - conflicts_found: 0
   - conflicts_resolved: 0
   - gaps_identified: 0

2. For each teammate result:
   a. Extract key findings
   b. Compare with other teammates for conflicts
   c. Log any conflicts found

3. Conflict resolution:
   For each conflict:
   a. Evaluate evidence strength
   b. Make judgment call
   c. Document resolution reason
   d. Increment conflicts_resolved

4. Gap analysis:
   a. Check if any expected angle missing
   b. Check for contradictions without resolution
   c. Decide if Wave 2 needed (not implemented in v1)

5. Generate unified output:
   a. Merge non-conflicting findings
   b. Include resolved conflicts with reasoning
   c. Note any remaining gaps
```

### Conflict Detection

```
# Pattern: Detect conflicts between findings
conflicts = []

for each finding_a in teammate_a.findings:
  for each finding_b in teammate_b.findings:
    if contradicts(finding_a, finding_b):
      conflicts.append({
        "teammate_a": "ResearcherA",
        "finding_a": finding_a,
        "teammate_b": "ResearcherB",
        "finding_b": finding_b
      })
```

## Graceful Degradation Pattern

### Fallback to Single Agent

```
# Pattern: Graceful degradation
try:
  spawn_teammates()
except TeamCreationFailed:
  log_warning("Team mode unavailable, falling back to single agent")

  # Execute single-agent version
  result = execute_single_agent_workflow()

  # Mark as degraded in metadata
  result.team_execution = {
    "enabled": true,
    "degraded_to_single": true,
    "degradation_reason": "Teams feature unavailable"
  }

  return result
```

### Partial Teammate Failure

```
# Pattern: Handle partial teammate failure
available_results = []
failed_teammates = []

for teammate in wave:
  if teammate.status == "completed":
    available_results.append(teammate.result)
  else:
    failed_teammates.append(teammate.name)

if len(available_results) >= 1:
  # Synthesize from available
  synthesis = synthesize(available_results)
  synthesis.gaps_identified += len(failed_teammates)
else:
  # All failed, degrade to single
  return fallback_to_single_agent()
```

## Timeout Handling Pattern

```
# Pattern: Wave timeout handling
WAVE_TIMEOUT = 1800  # 30 minutes per wave

start_time = now()
completed = []

while len(completed) < len(wave) and (now() - start_time) < WAVE_TIMEOUT:
  for teammate in wave:
    if teammate.is_complete() and teammate not in completed:
      completed.append(teammate)
  sleep(30)  # Poll every 30 seconds

# After timeout, collect what we have
for teammate in wave:
  if teammate not in completed:
    teammate.status = "timeout"
    log_warning(f"{teammate.name} timed out")
```

## Language Routing Pattern

Team skills route teammates based on the task's `language` field:

### Language Routing Lookup

```
# Pattern: Route by task language
language_config = {
  "meta": {
    "research_agent": "general-research-agent",
    "implementation_agent": "general-implementation-agent",
    "default_model": "sonnet",
    "context_references": [
      "@.claude/CLAUDE.md",
      "@.claude/context/index.json"
    ],
    "blocked_tools": [],
    "research_tools": ["Read", "Grep", "Glob"],
    "implementation_tools": ["Write", "Edit"],
    "verification": "File creation and consistency checks"
  },
  "general": {
    "research_agent": "general-research-agent",
    "implementation_agent": "general-implementation-agent",
    "default_model": "sonnet",
    "context_references": [],
    "blocked_tools": [],
    "research_tools": ["WebSearch", "WebFetch", "Read"],
    "implementation_tools": ["Read", "Write", "Edit", "Bash"],
    "verification": "Project-specific build/test commands"
  }
}

# Model Selection (ENFORCED via TeammateTool parameter)
#
# default_model specifies the Claude model for teammates:
# - "sonnet": Balanced model (Sonnet 4.6), used for most tasks
#
# ENFORCEMENT:
# - Pass `model: $default_model` when spawning teammates via TeammateTool
# - The model preference in prompts is secondary guidance only
# - Model selection is enforced at the tool level
```

## Related Files

- `.claude/context/patterns/team-orchestration.md` - Overall coordination
- `.claude/context/formats/team-metadata-extension.md` - Result schema
- `.claude/skills/skill-team-*/SKILL.md` - Skill implementations
