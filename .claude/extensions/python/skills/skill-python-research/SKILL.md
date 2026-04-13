---
name: skill-python-research
description: Research Python development tasks. Invoke for Python-language research.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Python Research Skill

Thin wrapper that delegates Python research to `python-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "python"
- Research involves Python development
- Python-specific research is needed

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists.

### Stage 2: Preflight Status Update
Update status to "researching" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context
Include task_context, focus_prompt, metadata_file_path.

### Stage 4: Invoke Subagent
Use Task tool with subagent_type: "python-research-agent".

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 4b). Do NOT skip these stages for any reason.

### Stage 5: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add research artifact to state.json.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## Return Format

Brief text summary (NOT JSON).
