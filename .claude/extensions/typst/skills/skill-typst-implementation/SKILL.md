---
name: skill-typst-implementation
description: Implement Typst documents. Invoke for Typst-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Typst Implementation Skill

Thin wrapper that delegates Typst implementation to `typst-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "typst"
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

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .typ files** - All Typst work is done by agent
2. **Run typst compile** - Compilation is done by agent
3. **Analyze or grep source** - Analysis is agent work
4. **Write summary/reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

Brief text summary (NOT JSON).
