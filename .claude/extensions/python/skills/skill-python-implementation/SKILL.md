---
name: skill-python-implementation
description: Implement Python code. Invoke for Python-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Python Implementation Skill

Thin wrapper that delegates Python implementation to `python-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task language is "python"
- /implement command targets a Python task
- Plan exists and task is ready for implementation

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and language is "python".

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context
Include task_context, plan_path, metadata_file_path.

### Stage 4: Invoke Subagent
Use Task tool with subagent_type: "python-implementation-agent".

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
