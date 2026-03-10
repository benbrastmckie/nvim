---
name: skill-logic-research
description: Research mathematical logic tasks using domain context and codebase exploration. Invoke for logic-language research involving modal logic, Kripke semantics, and related mathematical foundations.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Logic Research Skill

Thin wrapper that delegates mathematical logic research to `logic-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task language is "logic"
- Research involves modal logic, Kripke semantics, or general mathematical logic
- Domain context files are needed for mathematical foundations

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

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
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination.

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-logic-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "logic"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "logic-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute logic research for task {N}"
```

**DO NOT** use `Skill(logic-research-agent)` - this will FAIL.

The subagent will:
- Load domain context files from `.claude/context/project/logic/`
- Search codebase for existing patterns
- Use Mathlib lookup tools (lean_leansearch, lean_loogle, lean_leanfinder, lean_local_search)
- Execute web research for mathematical logic literature
- Create research report in `specs/{NNN}_{SLUG}/reports/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 6: Parse Subagent Return (Read Metadata File)

After subagent returns, read the metadata file.

---

### Stage 7: Update Task Status (Postflight)

If status is "researched", update state.json and TODO.md.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

---

### Stage 9: Git Commit

Commit changes with session ID using targeted staging.

---

### Stage 10: Cleanup

Remove marker and metadata files.

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Research completed for task {N}:
- Found existing patterns in source files
- Loaded domain context for modal logic and Kripke semantics
- Used Mathlib lookup tools to discover relevant theorems
- Created report at specs/{NNN}_{SLUG}/reports/research-{NNN}.md
- Status updated to [RESEARCHED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "researching"
2. Do not cleanup postflight marker
3. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 3600s).
Keep status as "researching" for resume.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
