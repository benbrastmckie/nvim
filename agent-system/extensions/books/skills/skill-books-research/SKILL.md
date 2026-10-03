---
name: skill-books-research
description: Research lean-book authoring, certification and documentation tasks. Invoke for books research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Books Research Skill

Thin wrapper that delegates `books` research to `books-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "books" (or the `books:certify` sub-route)
- Research involves lean-book authoring, certification, or documentation per
  `docs/book-convention.md`

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists.

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-books-research"
operation="research"
```

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`, exactly as `skill-orchestrate` does. This skill supplies the shared block's
preconditions: `lit_flag`, `description`, `orchestrator_mode` (default `"false"` when unset).

### Stage 4: Prepare Delegation Context
Include task_context, focus_prompt, metadata_file_path. If `memory_context` and/or `lit_context`
from Stage 4a are non-empty, include them in the prompt (memory context first, then literature
briefing). Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "books-research-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"researched"`.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including `memory_candidates`.

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full: `field_name=**Research**`,
`next_field=**Plan**`.

## Error Handling

### Input Validation Errors
Return immediately if task not found.

### Metadata File Missing
Keep status as "researching", report error.

### Git Commit Failure
Non-blocking: Log failure but continue.

## Return Format

Brief text summary (NOT JSON).
