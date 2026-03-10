---
name: skill-typst-implementation
description: Implement Typst documents. Invoke for Typst-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Typst Implementation Skill

Thin wrapper that delegates Typst implementation to `typst-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task language is "typst"
- /implement command targets a Typst task
- Plan exists and task is ready for implementation

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and language is "typst".

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context
Include task_context, plan_path, metadata_file_path.

### Stage 4: Invoke Subagent
Use Task tool with subagent_type: "typst-implementation-agent".

### Stage 5: Parse Subagent Return
Read metadata from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add artifact to state.json with summary.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## Error Handling

### Input Validation Errors
Return immediately if task not found or wrong language.

### Metadata File Missing
Keep status as "implementing", report error.

### Git Commit Failure
Non-blocking: Log failure but continue.

## Return Format

Brief text summary (NOT JSON).
