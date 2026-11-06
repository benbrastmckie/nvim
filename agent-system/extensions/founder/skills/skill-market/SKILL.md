---
name: skill-market
description: Market sizing research with TAM/SAM/SOM framework
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Market Skill

Thin wrapper that routes market sizing research requests to the `market-agent`.

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
- User explicitly runs `/market` command with task number
- User runs `/research` on a founder task with `task_type: "market"`

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Analyze market size"
- "Calculate TAM/SAM/SOM"
- "Market sizing analysis"
- "Estimate addressable market"

**Target mentions**:
- "TAM", "SAM", "SOM"
- "total addressable market"
- "market opportunity"
- "market sizing"

### When NOT to trigger

Do not invoke for:
- Competitive analysis (use skill-analyze)
- GTM strategy (use skill-strategy)
- General business research (use /orchestrate --research, task_type general)
- Revenue projections (not market sizing)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `industry` - Optional, string
- `segment` - Optional, string
- `mode` - Optional, one of: VALIDATE, SIZE, SEGMENT, DEFEND

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "founder"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Extract pre-gathered forcing_data (if present)
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // null')
pre_gathered_mode=$(echo "$forcing_data" | jq -r '.mode // null' 2>/dev/null)

# Validate mode if provided
if [ -n "$mode" ]; then
  case "$mode" in
    VALIDATE|SIZE|SEGMENT|DEFEND) ;;
    *) return error "Invalid mode: $mode. Must be VALIDATE, SIZE, SEGMENT, or DEFEND" ;;
  esac
fi
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-market"
operation="research"
```

---

### Stage 4: Prepare Delegation Context

Include pre-gathered forcing_data when available:

```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{project_name}",
    "description": "{description}",
    "task_type": "founder",
    "task_type": "market"
  },
  "forcing_data": {
    "mode": "{pre_gathered_mode}",
    "problem": "{pre_gathered_problem}",
    "target_entity": "{pre_gathered_target}",
    "geography": "{pre_gathered_geography}",
    "price_point": "{pre_gathered_price_point}",
    "gathered_at": "{timestamp}"
  },
  "industry": "optional industry hint",
  "segment": "optional segment hint",
  "mode": "VALIDATE|SIZE|SEGMENT|DEFEND or use forcing_data.mode",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "market", "skill-market"]
  }
}
```

**Note**: If `forcing_data` is present from STAGE 0 of /market command, pass it to the agent.
The agent will use pre-gathered data and only ask follow-up questions for missing details.

---

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Agent** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "market-agent"
  - prompt: [Include task_context, forcing_data, industry, segment, mode, metadata_file_path, metadata]
  - description: "Market sizing research with TAM/SAM/SOM"
```

The agent will:
- Use pre-gathered forcing_data if available (skip already-answered questions)
- Present mode selection only if not pre-selected
- Ask follow-up forcing questions for details not in forcing_data
- Create research report at specs/{NNN}_{SLUG}/reports/
- Write metadata file
- Return brief text summary

---

### Stage 5b: Self-Execution Fallback

See `context/patterns/thin-wrapper-skill.md` § "3b. Self-Execution Fallback" for the full
obligation: if you performed the work above WITHOUT using the Agent tool, write
`.return-meta.json` now per `return-metadata-file.md`'s schema before proceeding to postflight.
If you DID use the Agent tool, skip this stage.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

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

---

### Stage 7: Update Task Status (Postflight)

If status is "researched", update state.json and TODO.md.

**Update state.json**:
```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == $num)) |= . + {
    status: $status,
    last_updated: $ts
  }' \
  --session-id "$session_id" \
  --argjson num "$task_number" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg status "researched"
```

**Update TODO.md**: Use Edit tool to change status marker to `[RESEARCHED]`.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid escaping issues.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern)
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == "research" | not)]' \
      --session-id "$session_id" \
      --argjson num "$task_number"

    # Step 2: Add new research artifact
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" --arg path "$artifact_path" --arg type "$artifact_type" --arg summary "$artifact_summary"
fi
```

**Update TODO.md**: Link artifact using count-aware format.

Apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md`
with `field_name=**Research**`, `next_field=**Plan**`.

---

### Stage 9: Git Commit

Apply the `research` scope from `.claude/context/standards/git-staging-scope.md` — targeted
staging, never a repo-wide add:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete research" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "specs/${padded_num}_${project_name}/reports/" \
     "specs/${padded_num}_${project_name}/.return-meta.json" \
     "specs/TODO.md" \
     "specs/state.json"
```

---

### Stage 10: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

---

### Stage 11: Return Brief Summary

```
Market sizing research completed for task {N}:
- Mode: {mode}, {questions_asked} forcing questions completed
- Problem: {brief problem statement}
- Entity count: {value} from {source}
- Pre-gathered data used: {yes/no}
- Research report: specs/{NNN}_{SLUG}/reports/01_{short-slug}.md
- Status updated to [RESEARCHED]
- Changes committed
- Next: Run /orchestrate {N} to create implementation plan
```

---

## MUST NOT (Postflight Boundary)

After the agent returns -- whether with status researched, partial, or failed -- this skill MUST
proceed immediately to postflight (Stage 6). The skill MUST NOT:

1. **Edit source/report files** - All research work is done by agent
2. **Run domain analysis or calculations** - Analysis is agent work
3. **Use MCP or WebSearch tools** - Research tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write reports** - Artifact creation is done by agent

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT
> attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed
> status and let the user re-run `/research` to resume.

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
Market sizing research completed for task {N}:
- Mode: SIZE, 8 forcing questions completed
- Problem: Streamline deploy coordination for mid-market SaaS
- Entity count: 500,000 mid-market SaaS companies globally (Gartner)
- Pre-gathered data used: yes (4 questions from STAGE 0)
- Research report: specs/234_market_sizing_fintech/reports/01_market-sizing.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_1736700000_abc123
- Next: Run /orchestrate 234 to create implementation plan
```

---

## Error Handling

### Input Validation Errors
Return immediately if task not found.

### Metadata File Missing
Keep status as "researching" for resume.

### User Abandonment
Return partial status with progress made.

### Git Commit Failure
Non-blocking: Log failure but continue.
