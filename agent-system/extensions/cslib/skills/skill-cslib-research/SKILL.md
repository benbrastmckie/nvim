---
name: skill-cslib-research
description: Research CSLib formalization patterns and Mathlib API for CSLib contributions. Invoke for cslib research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Research Skill

Thin wrapper that delegates CSLib research to `cslib-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "cslib"
- Research is needed for CSLib formalization, Lean 4 proof patterns, or Mathlib API
- CSLib contribution standards or module patterns need to be gathered

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and task_type is "cslib".

### Stage 2: Preflight Status Update
Update status to "researching" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context

Domain-specific context for the cslib-research-agent:
- lean-lsp MCP tools for Mathlib search (lean_leansearch, lean_loogle, lean_local_search)
- CSLib context files from `.claude/extensions/cslib/context/`
- Local CSLib Lean files for pattern analysis

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-cslib-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "cslib"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### Stage 4a: Memory and Literature Retrieval (Auto)

Retrieve relevant memories and literature briefing to inject into the delegation context.

**Skip memory if**: `clean_flag` is true (from `--clean` command flag).

```bash
# Check clean_flag
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/sapience-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi

# memory_context will be empty string if:
# - clean_flag is true (skipped)
# - memory-index.json missing or empty
# - no keywords matched any entries
# - script exited with error
```

```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi

# lit_context will be empty string if:
# - lit_flag is not "true" (skipped)
# - specs/literature/ sub-index is empty or missing
# - script exited with error
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "cslib-research-agent".

Include `memory_context` and `lit_context` in the prompt if non-empty:
- If `memory_context` is non-empty, include it as a `<memory-context>` block after the delegation context.
- If `lit_context` is non-empty, include it as a `<literature-briefing>` block after the memory context.

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 4b). Do NOT skip these stages for any reason.

### Stage 5: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`.

**Expected `status` vocabulary**: `researched` on success; otherwise `partial`, `failed`, or
`blocked`. This is a closed set (`@.claude/context/formats/return-metadata-file.md` is
normative) and near-synonyms are not accepted — see the `status` note in
`cslib-research-agent.md`'s Stage 7 for the three consumers a variant breaks and the
stranded-task failure mode it produces. If the value read here is outside the set, do NOT
proceed to Stage 6 as if it were a success: report it and stop, so the task is not promoted on
an unrecognized outcome.

**No `.orchestrator-handoff.json`**: research agents never write one, in any mode, including
under `orchestrator_mode: true` (`cslib-research-agent.md` Stage 7 states this as a
prohibition). A dispatching orchestrator MUST NOT instruct this skill's subagent to write one
either — `.return-meta.json` is the sole status channel for research, and
`skill-orchestrate`'s Stage 5 already treats an absent handoff from a research dispatch as the
expected outcome and recovers through `scripts/orchestrate-recover-outcome.sh`.

**Defensive case, if this prohibition is ever reversed**: should a future variant of this skill's
subagent write `.orchestrator-handoff.json`, it MUST echo `dispatch_seq` unchanged from its own
delegation context — copy the value verbatim (never invent, increment, or recompute one), or
omit it when the delegation context omits it. See
`context/patterns/dispatch-report-not-termination.md`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add research artifact to state.json. Update TODO.md per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`, `next_field=**Plan**`.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## Return Format

Brief text summary (NOT JSON).
