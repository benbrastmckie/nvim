---
name: skill-math-research
description: Research mathematical tasks using domain context and codebase exploration. Invoke for math-language research involving algebra, lattice theory, order theory, topology, and category theory.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Math Research Skill

Thin wrapper that delegates mathematical research to `math-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task language is "math"
- Research involves algebra, lattice theory, order theory, topology, or category theory
- Domain context files are needed for mathematical foundations

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
  "delegation_path": ["orchestrator", "research", "skill-math-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "math"
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
  - subagent_type: "math-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute math research for task {N}"
```

**DO NOT** use `Skill(math-research-agent)` - this will FAIL.

The subagent will:
- Load domain context files from `.opencode/context/project/math/`
- Search codebase for existing patterns
- Use Mathlib lookup tools
- Execute web research for mathematical literature
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
- Loaded domain context for algebra/lattice theory
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
If subagent didn't write metadata file, keep status as "researching".

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
