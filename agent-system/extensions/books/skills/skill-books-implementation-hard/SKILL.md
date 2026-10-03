---
name: skill-books-implementation-hard
description: Implement lean-book changes with hard-mode contracts (H2 anti-analysis, H7 territory, H9 wrap-up discipline). Invoke for --hard books implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Books Implementation Hard Skill

Hard-mode wrapper that delegates `books` implementation to `books-implementation-hard-agent`
subagent. Extends `skill-books-implementation` with:

- Territory parameters (H7): includes territory contract when dispatched from orchestrate-hard
- Anti-analysis contract (H2): passed in delegation context for agent enforcement
- Wrap-up discipline (H9): `.orchestrator-handoff.json` always written by the agent

**Relationship to base skill**: Structurally follows `skill-books-implementation`'s postflight
pattern. Key difference: when `orchestrator_mode=true`, uses per-phase dispatch (H1) rather than
whole-plan dispatch, same as `books:certify`'s shared routing — no separate certify skill exists
here either.
**Maintenance note**: changes to `skill-books-implementation` postflight should be mirrored
here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/wrap-up.md` - H9 contract (loaded by agent)
- Path: `.claude/context/contracts/territory.md` - H7 contract (when territory params present)
- Path: `.claude/context/contracts/phase-closure.md` - depth-first phase closure (loaded by agent)
- Path: `.claude/context/contracts/pre-edit-gate.md` - per-item evidence before a mechanical-list edit (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/subagent-continuation-loop.md` - Continuation loop pattern

## Trigger Conditions

This skill activates when:
- `/implement N --hard` is invoked and task type is `books` (or `books:certify`)
- Note: `skill-orchestrate`'s own hard-mode dispatch (both effort modes, one engine) resolves
  and dispatches the AGENT (`books-implementation-hard-agent`) directly via
  `command-route-agent.sh`, not this SKILL file; this skill's own activation is via direct
  invocation

---

## Execution Flow

### Stage 1: Input Validation

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
  return error "Task is in terminal state [$status]"
fi
```

### Stage 1.5: Hard-Mode Cost Note

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active (books implementation). Cost: ~3-5x standard." >&2
  touch "$session_flag_file"
fi
```

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-books-implementation-hard"
operation="implement"
```

### Stage 4a: Memory Retrieval and Literature Detection

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`.

### Stage 4: Prepare Delegation Context

Include task_context, plan_path, metadata_file_path, `effort_flag: "hard"`, and — when the
dispatch originates from `skill-orchestrate --hard` — the `territory`/`concurrent_siblings`
parameters it supplies. If `memory_context` and/or `lit_context` from Stage 4a are non-empty,
include them in the prompt. Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "books-implementation-hard-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

**Self-review before writing metadata**: identical to `skill-books-implementation`'s Stage 5b
self-review — re-read every file the inline path touched against `rules/books.md`'s six
non-negotiables before writing `status: "implemented"`.

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including
`memory_candidates`.

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

Identical to `skill-books-implementation`'s postflight boundary: no editing book/Lean/TOML
files, no running `lake build`/`books-tool`, no analysis, no artifact authoring. See that
skill's own section for the full list.

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

Brief text summary (NOT JSON).
