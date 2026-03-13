---
name: skill-physics-research
description: Research physics formalization tasks using domain context and codebase exploration. Invoke for physics-language research involving dynamical systems, chaos theory, and related formalization.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Physics Research Skill

Thin wrapper that delegates physics formalization research to `physics-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task language is "physics"
- Research involves dynamical systems, chaos theory, or physics formalization
- Domain context files are needed for physics foundations

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
  "delegation_path": ["orchestrator", "research", "skill-physics-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "physics"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/OC_{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "physics-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute physics research for task {N}"
```

**DO NOT** use `Skill(physics-research-agent)` - this will FAIL.

The subagent will:
- Load domain context files from `.opencode/context/project/physics/`
- Search codebase for existing patterns
- Use Mathlib lookup tools
- Execute web research for physics/dynamical systems literature
- Create research report in `specs/{NNN}_{SLUG}/reports/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 6-11: Standard Postflight

Parse metadata file, update task status, link artifacts, git commit, cleanup, return brief summary.

---

## Error Handling

Standard error handling patterns: validate inputs, handle missing metadata, non-blocking git failures.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
