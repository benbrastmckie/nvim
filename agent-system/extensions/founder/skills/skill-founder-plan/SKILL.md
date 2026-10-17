---
name: skill-founder-plan
description: Create founder analysis plans with interactive forcing questions
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Founder Plan Skill

Routes founder-specific planning requests to the `founder-plan-agent`, enabling interactive forcing questions workflow for market sizing, competitive analysis, and GTM strategy planning.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/plan` command on a task with `language: founder`
- Extension routing lookup finds `routing.plan.founder`

### Task-Type-Based Routing
- Task type is "founder"
- `/plan {N}` where task {N} has language="founder"

### When NOT to trigger

Do not invoke for:
- Tasks with other language types (general, meta, neovim, etc.)
- Quick mode operations (`--quick` flag)
- Tasks already in [PLANNED] or [COMPLETED] status

---

## Execution

### 1. Input Validation

Validate inputs from delegation context:
- `task_number` - Required, integer
- `research_path` - Optional, path to existing research reports
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

### 2 + 3. Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"
skill_name="skill-founder-plan"
operation="plan"
```

### 4. Context Preparation

Extract task_type from state.json (null-safe):

```bash
# Extract task_type from state.json (null-safe)
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)
```

Prepare delegation context for agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "task_type": "founder",
    "task_type": "market"
  },
  "research_path": "specs/234_market_sizing_fintech_payments/reports/01_context.md",
  "metadata_file_path": "specs/234_market_sizing_fintech_payments/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-founder-plan"]
  }
}
```

### 5. Invoke Agent

**CRITICAL**: You MUST use the **Agent** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "founder-plan-agent"
  - prompt: [Include task_context, research_path, metadata_file_path, metadata]
  - description: "Create founder analysis plan with forcing questions"
```

The agent will:
- Load existing context (research reports if any)
- Conduct interactive forcing questions to gather data
- Generate plan artifact with gathered context stored
- Write metadata file for postflight consumption
- Return brief text summary

### 5b. Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### 6. Read Metadata File

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
metadata=$(cat "$metadata_file")
status=$(echo "$metadata" | jq -r '.status')
```

### 7. Postflight Status Update

If agent succeeded (status == "planned"):

```bash
# Update state.json
bash .claude/scripts/state-write.sh \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planned",
     last_updated: $ts
   }' \
   --session-id "$session_id" \
   --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Link artifact in state.json
plan_path=$(echo "$metadata" | jq -r '.artifacts[0].path')
plan_summary=$(echo "$metadata" | jq -r '.artifacts[0].summary')
bash .claude/scripts/state-write.sh \
   '(.active_projects[] | select(.project_number == $num)).artifacts += [{
     type: "plan",
     path: $path,
     summary: $summary
   }]' \
   --session-id "$session_id" \
   --argjson num "$task_number" \
   --arg path "$plan_path" \
   --arg summary "$plan_summary"
```

Update TODO.md status marker to [PLANNED] and link plan artifact per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Plan**`, `next_field=**Description**`.

### 8. Git Commit

Apply the `plan` scope from `.claude/context/standards/git-staging-scope.md` — targeted staging,
never a repo-wide add:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: create implementation plan" \
  --session "{session_id}" \
  --honest-index-rows {N} \
  -- "${task_dir}/" "specs/TODO.md" "specs/state.json"
```

### 9. Cleanup and Return

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

Return brief text summary to caller.

---

## MUST NOT (Postflight Boundary)

After the agent returns -- whether with status planned, partial, or failed -- this skill MUST
proceed immediately to postflight (Stage 6). The skill MUST NOT:

1. **Edit plan/report files** - All plan generation is done by agent
2. **Run domain analysis or calculations** - Analysis is agent work
3. **Use MCP or WebSearch tools** - Domain tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write plan artifacts** - Artifact creation is done by agent

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT
> attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed
> status and let the user re-run `/plan` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates (state.json + TODO.md)
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

Brief text summary (NOT JSON).

Expected successful return:
```
Founder plan created for task {N}:
- {questions_asked} forcing questions completed, {phase_count} phases planned
- Context gathered: {brief summary of key data points}
- Plan: specs/{NNN}_{SLUG}/plans/01_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
- Next: Run /orchestrate {N} to execute the plan and generate report
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
