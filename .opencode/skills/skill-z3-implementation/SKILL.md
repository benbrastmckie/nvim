---
name: skill-z3-implementation
description: Implement Z3 constraints. Invoke for Z3-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Z3 Implementation Skill

Thin wrapper that delegates Z3 implementation to `z3-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task language is "z3"
- /implement command targets a Z3 task
- Plan exists and task is ready for implementation

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and language is "z3".

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context
Include task_context, plan_path, metadata_file_path.

### Stage 4: Invoke Subagent
Use Task tool with subagent_type: "z3-implementation-agent".

### Stage 5: Parse Subagent Return
Read metadata from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add artifact to state.json with summary.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## Return Format

Brief text summary (NOT JSON).
