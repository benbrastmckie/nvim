---
name: skill-books-implementation
description: Implement lean-book authoring, certification and documentation changes. Invoke for books implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Books Implementation Skill

Thin wrapper that delegates `books` implementation to `books-implementation-agent` subagent.
This skill also serves the `books:certify` sub-route: no dedicated lifecycle skill exists for
it, since `books:certify` maps to the same base agents as `books` in the manifest's
`routing_agents` block (the `lean4:lake` precedent) — a certification-focused implementation
task routes here, not to a separate skill.

## Trigger Conditions

This skill activates when:
- Task type is "books" (or the `books:certify` sub-route)
- `/implement` command targets a `books` task
- Plan exists and task is ready for implementation

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and task type is "books" (or "books:certify").

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-books-implementation"
operation="implement"
```

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`, exactly as `skill-orchestrate` does. This skill supplies the shared block's
preconditions: `lit_flag`, `description`, `orchestrator_mode` (default `"false"` when unset).

### Stage 4: Prepare Delegation Context
Include task_context, plan_path, metadata_file_path. If `memory_context` and/or `lit_context`
from Stage 4a are non-empty, include them in the prompt (memory context first, then literature
briefing). Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "books-implementation-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

**Self-review before writing metadata**: if this fallback path authors or modifies any book
module, `book.toml`, or Lean file directly (rather than wholesale re-delegating to another
skill/agent), it bypasses `books-implementation-agent`'s own Stage 4C entirely — so before
writing `.return-meta.json` with `status: "implemented"`, re-read every file this inline path
touched, by path, against `rules/books.md`'s six non-negotiables. A successful `lake build` does
NOT satisfy this check.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including `memory_candidates`.

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full: `field_name=**Summary**`,
`next_field=**Description**`.

## Error Handling

### Input Validation Errors
Return immediately if task not found or wrong task type.

### Metadata File Missing
Keep status as "implementing", report error.

### Git Commit Failure
Non-blocking: Log failure but continue.

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit book/Lean/TOML files** - All books work is done by agent
2. **Run `lake build` or `books-tool`** - Verification is done by agent
3. **Analyze or grep source** - Analysis is agent work
4. **Write summary/reports** - Artifact creation is agent work

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.

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
