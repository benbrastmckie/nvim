---
name: skill-formal-research
description: Coordinate formal reasoning research across logic, math, and physics domains. Invoke for formal-language research requiring cross-domain coordination.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Formal Research Skill

Thin wrapper that delegates formal reasoning research to `formal-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task type is "formal"
- Research requires cross-domain coordination (logic + math, math + physics, etc.)
- Domain context files are needed from multiple formal domains

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

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
  "delegation_path": ["orchestrator", "research", "skill-formal-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "formal"
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
  - subagent_type: "formal-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute formal research for task {N}"
```

**DO NOT** use `Skill(formal-research-agent)` - this will FAIL.

The subagent will:
- Analyze task for domain routing (logic, math, physics)
- Load appropriate domain context files
- Coordinate cross-domain research when needed
- Use Mathlib lookup tools
- Execute web research
- Create research report in `specs/{NNN}_{SLUG}/reports/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value "researched".

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6-11: Standard Postflight

Parse metadata file, update task status, link artifacts, git commit, cleanup, return brief summary.

---

## Error Handling

Standard error handling patterns: validate inputs, handle missing metadata, non-blocking git failures.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
