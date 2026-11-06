---
name: skill-meeting
description: Investor meeting note processing and CSV tracking
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Meeting Skill

Thin wrapper that routes investor meeting note processing requests to the `meeting-agent`.

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
- User explicitly runs `/meeting` command with task number
- User runs `/research` on a founder task with `task_type: "meeting"`

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Process meeting notes"
- "Create investor meeting file"
- "Update investor CSV"
- "Meeting report"

**Target mentions**:
- "meeting notes"
- "investor meeting"
- "CSV tracker"
- "investor profile"

### When NOT to trigger

Do not invoke for:
- Market sizing (use skill-market)
- Competitive analysis (use skill-analyze)
- GTM strategy (use skill-strategy)
- Contract review (use skill-legal)
- Financial analysis (use skill-finance)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `notes_path` - Optional, file path to meeting notes or structured meeting file
- `update_only` - Optional, boolean (default: false)

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

# Extract notes_path from task metadata (stored at task creation)
stored_notes_path=$(echo "$task_data" | jq -r '.notes_path // null')

# Use provided notes_path or fall back to stored one
notes_path="${notes_path:-$stored_notes_path}"

if [ -z "$notes_path" ] || [ "$notes_path" = "null" ]; then
  return error "No notes_path found. Provide a file path or ensure task has notes_path stored."
fi

# Validate file exists
if [ ! -f "$notes_path" ]; then
  return error "File not found: $notes_path"
fi
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-meeting"
operation="research"
```

---

### Stage 4: Prepare Delegation Context

```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{project_name}",
    "description": "{description}",
    "task_type": "founder",
    "task_type": "meeting"
  },
  "notes_path": "/absolute/path/to/meeting-notes.md",
  "update_only": false,
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "meeting", "skill-meeting"]
  }
}
```

---

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Agent** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "meeting-agent"
  - prompt: [Include task_context, notes_path, update_only, metadata_file_path, metadata]
  - description: "Investor meeting note processing"
```

The agent will:
- Read raw meeting notes from `notes_path`
- Web research the investor for profile data
- Generate structured meeting file with YAML frontmatter + markdown body
- Update CSV tracker in the same directory
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
Meeting notes processed for task {N}:
- Investor: {investor_name}
- Meeting date: {meeting_date}
- Meeting file: {output_path}
- Action items: {count}
- CSV tracker: {updated|created|skipped}
- Update-only mode: {yes|no}
- Research report: {artifact_path}
- Status updated to [RESEARCHED]
- Changes committed
- Next: Review meeting file for accuracy
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

---

## Error Handling

### Input Validation Errors
Return immediately if task not found or notes_path missing.

### File Not Found
Return error if notes_path does not exist on disk.

### Metadata File Missing
Keep status as "researching" for resume.

### User Abandonment
Return partial status with progress made.

### Git Commit Failure
Non-blocking: Log failure but continue.
