---
name: skill-deck-plan
description: Pitch deck planning with interactive template, content, and ordering selection
allowed-tools: Task, Bash, Edit, Read, Write
---

# Deck Plan Skill

Thin wrapper that routes pitch deck planning requests to the `deck-planner-agent`. Handles preflight/postflight status management while the agent conducts the interactive planning flow.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/plan` command on a task with `language: founder` and `task_type: deck`
- Extension routing lookup finds `routing.plan["founder:deck"]`

### Language-Based Routing
- Task language is "founder" AND task_type is "deck"
- `/plan {N}` where task {N} has language="founder" and task_type="deck"

### When NOT to trigger

Do not invoke for:
- Non-deck founder tasks (use skill-founder-plan)
- Tasks with other language types (general, meta, neovim, etc.)
- Quick mode operations (`--quick` flag)
- Tasks already in [PLANNED] or [COMPLETED] status

---

## Execution

### Stage 1: Input Validation

Validate inputs from delegation context:
- `task_number` - Required, integer
- `session_id` - Required, string

```bash
# Validate task_number is present
if [ -z "$task_number" ]; then
  return error "task_number is required"
fi

# Validate session_id is present
if [ -z "$session_id" ]; then
  return error "session_id is required"
fi
```

### Stage 2: Preflight Status Update

Update task status to "planning" in state.json:

```bash
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planning",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [PLANNING].

### Stage 3: Create Postflight Marker

Create marker file to signal postflight operations needed:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"

cat > "$task_dir/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-deck-plan",
  "task_number": ${task_number},
  "operation": "plan",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

### Stage 4: Context Preparation

Extract task_type and research_path from state.json:

```bash
# Extract task_type from state.json (null-safe)
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)

# Find research report path
research_path=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .artifacts[] | select(.type == "research") | .path' \
  specs/state.json 2>/dev/null | head -1)
```

Prepare delegation context for agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "{project_name}",
    "description": "{description}",
    "language": "founder",
    "task_type": "deck"
  },
  "research_path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-deck-plan"]
  }
}
```

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "deck-planner-agent"
  - prompt: [Include task_context, research_path, metadata_file_path, metadata]
  - description: "Pitch deck planning with interactive template, content, and ordering selection"
```

The agent will:
- Read the deck research report
- Ask 3 interactive questions (template, content, ordering)
- Generate plan artifact with Deck Configuration section
- Write metadata file for postflight consumption
- Return brief text summary

### Stage 6: Parse Subagent Return

```bash
padded_num=$(printf "%03d" "$task_number")
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    status="failed"
fi
```

### Stage 7: Postflight Status Update

If agent succeeded (status == "planned"):

```bash
# Update state.json
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planned",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Link artifact in state.json
plan_path=$(echo "$metadata" | jq -r '.artifacts[0].path')
plan_summary=$(echo "$metadata" | jq -r '.artifacts[0].summary')
jq --argjson num "$task_number" \
   --arg path "$plan_path" \
   --arg summary "$plan_summary" \
   '(.active_projects[] | select(.project_number == $num)).artifacts += [{
     type: "plan",
     path: $path,
     summary: $summary
   }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [PLANNED] and add Plan link.

### Stage 8: Git Commit

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: create implementation plan

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Stage 9: Cleanup

Remove postflight markers and metadata:

```bash
rm -f "$task_dir/.postflight-pending"
rm -f "$task_dir/.postflight-loop-guard"
rm -f "$task_dir/.return-meta.json"
```

### Stage 10: Return Brief Summary

Return brief text summary to caller.

---

## Return Format

Brief text summary (NOT JSON).

Expected successful return:
```
Deck plan created for task {N}:
- Template: {template_name}, {N} main slides in {ordering_name} order
- Appendix: {M} slides
- Content gaps: {G} identified
- Plan: specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
- Next: Run /implement {N} to generate the Typst pitch deck
```

---

## Error Handling

### Session ID Missing
Return immediately with failed status.

### Task Not Found
Return error with guidance to check task number.

### Agent Errors
Pass through the agent's error return verbatim.

### User Abandonment
Return partial status with progress made, keep status as "planning".
