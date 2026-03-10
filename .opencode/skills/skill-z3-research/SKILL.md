---
name: skill-z3-research
description: Research Z3/SMT tasks. Invoke for Z3-language research.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Z3 Research Skill

Thin wrapper that delegates Z3 research to `z3-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task language is "z3"
- Research involves SMT solving or constraints
- Z3-specific research is needed

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists.

### Stage 2: Preflight Status Update
Update status to "researching" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context
Include task_context, focus_prompt, metadata_file_path.

### Stage 4: Invoke Subagent
Use Task tool with subagent_type: "z3-research-agent".

### Stage 5: Parse Subagent Return
Read metadata from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add research artifact to state.json.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## Return Format

Brief text summary (NOT JSON).
