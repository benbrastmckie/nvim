---
name: skill-legal
description: Contract review and legal analysis for founders
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Legal Skill

Thin wrapper that routes contract review requests to the `legal-council-agent`.

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
- User explicitly runs `/legal` command with task number
- User runs `/research` on a founder task with `task_type: "legal"`

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Review contract"
- "Analyze agreement"
- "Contract negotiation"
- "Legal review"

**Target mentions**:
- "contract review"
- "negotiation strategy"
- "liability", "indemnification"
- "IP ownership", "data rights"

### When NOT to trigger

Do not invoke for:
- Market sizing (use skill-market)
- Competitive analysis (use skill-analyze)
- GTM strategy (use skill-strategy)
- General business research (use /orchestrate --research, task_type general)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `contract_type` - Optional, string
- `primary_concern` - Optional, string
- `mode` - Optional, one of: REVIEW, NEGOTIATE, TERMS, DILIGENCE

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
    REVIEW|NEGOTIATE|TERMS|DILIGENCE) ;;
    *) return error "Invalid mode: $mode. Must be REVIEW, NEGOTIATE, TERMS, or DILIGENCE" ;;
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
skill_name="skill-legal"
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
    "task_type": "legal"
  },
  "forcing_data": {
    "mode": "{pre_gathered_mode}",
    "contract_type": "{pre_gathered_contract_type}",
    "primary_concern": "{pre_gathered_concern}",
    "position": "{pre_gathered_position}",
    "financial_exposure": "{pre_gathered_exposure}",
    "gathered_at": "{timestamp}"
  },
  "contract_type": "optional contract type hint",
  "primary_concern": "optional concern hint",
  "mode": "REVIEW|NEGOTIATE|TERMS|DILIGENCE or use forcing_data.mode",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "legal", "skill-legal"]
  }
}
```

**Note**: If `forcing_data` is present from STAGE 0 of /legal command, pass it to the agent.
The agent will use pre-gathered data and only ask follow-up questions for missing details.

---

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Agent** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "legal-council-agent"
  - prompt: [Include task_context, forcing_data, contract_type, primary_concern, mode, metadata_file_path, metadata]
  - description: "Contract review and legal analysis"
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

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

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
Contract review research completed for task {N}:
- Mode: {mode}, {questions_asked} forcing questions completed
- Contract: {contract_type} with {parties}
- Concerns: {primary_concerns}
- Pre-gathered data used: {yes/no}
- Escalation: {self-serve|attorney-review|attorney-required}
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
Contract review research completed for task {N}:
- Mode: REVIEW, 8 forcing questions completed
- Contract: SaaS vendor agreement with Company X
- Concerns: Data rights, liability cap, termination provisions
- Pre-gathered data used: yes (4 questions from STAGE 0)
- Escalation: Self-serve (under $100K threshold)
- Research report: specs/256_contract_review_saas/reports/01_contract-review.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_1736700000_abc123
- Next: Run /orchestrate 256 to create implementation plan
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
