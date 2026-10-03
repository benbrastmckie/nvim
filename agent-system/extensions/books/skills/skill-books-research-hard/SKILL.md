---
name: skill-books-research-hard
description: Research lean-book tasks with hard-mode contracts (H2 anti-analysis, H3 reference grounding, H4 adversarial verification). Invoke for --hard books research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Books Research Hard Skill

Hard-mode wrapper that delegates `books` research to `books-research-hard-agent` subagent.
Extends `skill-books-research` with hard-mode behavioral contracts (H2, H3, H4) and postflight
logging of adversarial verification status.

**Relationship to base skill**: This skill is structurally identical to `skill-books-research`
except it dispatches to `books-research-hard-agent` and logs
`adversarial_verification_triggered`.
**Maintenance note**: changes to `skill-books-research` postflight should be mirrored here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/reference-grounding.md` - H3 contract (loaded by agent)
- Path: `.claude/context/contracts/adversarial-verification.md` - H4 contract (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol

## Trigger Conditions

This skill activates when:
- `/research N --hard` is invoked and task type is `books` (or `books:certify`)
- `skill-orchestrate`'s own hard-mode dispatch resolves and dispatches the AGENT
  (`books-research-hard-agent`) directly via `command-route-agent.sh`, not this SKILL file —
  this skill's own activation above is for direct invocation

---

## Execution Flow

### Stage 1: Input Validation

```bash
# Lookup task (skill_validate_input exits 1 with its own not-found/terminal-state message;
# this is a newly-inherited terminal-state check -- the prior hand-rolled lookup here had none
# -- an intentional tightening consistent with every other skill-layer call site)
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"
task_data="$TASK_DATA"

# Extract fields
task_type="$TASK_TYPE"
status="$TASK_STATUS"
project_name="$PROJECT_NAME"
description="$DESCRIPTION"
```

### Stage 1.5: Hard-Mode Cost Note

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active (books research). Cost: ~3-5x standard." >&2
  touch "$session_flag_file"
fi
```

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-books-research-hard"
operation="research"
```

### Stage 4a: Memory Retrieval and Literature Detection

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`.

### Stage 4: Prepare Delegation Context

Include task_context, focus_prompt, metadata_file_path, and `effort_flag: "hard"`. If
`memory_context` and/or `lit_context` from Stage 4a are non-empty, include them in the prompt
(memory context first, then literature briefing). Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "books-research-hard-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"researched"`.

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including
`memory_candidates` and `adversarial_verification_triggered`.

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
