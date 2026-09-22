# Topic Assignment Pattern

**Created**: 2026-06-10
**Purpose**: Canonical reference for topic picker logic in commands/skills
**Audience**: Commands and skills that assign topics to tasks

## Overview

Topic picker logic was duplicated across ~6 files (~147 lines) in the agent system. The
`active_topics` maintenance jq snippet appeared verbatim 5 times; the full interactive
AskUserQuestion picker was inlined 3 times.

This document and `manage-topics.sh` replace all inline implementations. Commands should
call `manage-topics.sh` for state.json operations and copy the AskUserQuestion templates
from this document for user interaction.

The `AskUserQuestion` schema used throughout this document (`question`, `header`, `multiSelect`,
`options: [{label, description}]`) is a copy, not the source of truth — see
`context/standards/interactive-selection.md` for the authoritative tool schema definition. Check
against that file before editing any template here.

### Mandatory Assignment Guarantee

Every new-task-creation path MUST end with a non-empty topic. **Mode A is the universal
fallback**: whenever a topic cannot be inherited (Mode B, parent has no topic) or inferred
(Mode C, heuristic misses), the caller invokes Mode A instead of leaving the task topicless.
There is no option to bypass topic assignment with no topic on any new-task-creation path —
the only escape hatch permitted anywhere in the system is the single, explicitly-labeled
**"Defer (leave uncategorized for now)"** option in `/task --sync`'s backfill loop, which
remediates *pre-existing* topicless tasks and is not a creation-time bypass. This guarantee
covers the **zero-existing-topics branch** (Mode A Step 1) too: when no topics exist yet, the
picker is skipped but free-text collection is not — there is no Skip and no Defer on that
branch either. See
`specs/796_mandatory_topic_assignment/plans/01_mandatory-topic-assignment.md` Decision (a) for
the rationale; future edits to this document or its callers must not re-introduce a bypass
option outside that one carve-out.

### Three Assignment Modes

| Mode | Used by | Picker shown? | State updated by |
|------|---------|---------------|-----------------|
| **A: Interactive** | `/task` create, `/task` sync backfill, `/meta` interview Stage 4.5; also the universal fallback for Modes B/C | Yes (full picker) | `manage-topics.sh add` + `manage-topics.sh set` |
| **B: Inherit** | `/task --expand`, `/task --recover` follow-up tasks, `/spawn` | No (falls back to Mode A if parent has no topic) | `manage-topics.sh add` + `manage-topics.sh set` |
| **C: Suggest** | `/review`, `/fix-it` | No (falls back to Mode A if heuristic misses) | `manage-topics.sh add` + `manage-topics.sh set` |

---

## Mode A: Interactive

Show a picker when the user is actively creating or reviewing a task and can make a
deliberate topic choice. **Mode A is the universal fallback**: any caller of Mode B or Mode C
that cannot inherit or infer a topic MUST invoke this picker (or its batch variant, below)
rather than leaving the task topicless.

**Caller locations**:
- `/task` — Create new task (task creation interview, last step)
- `/task --sync` — Backfill missing topics for existing tasks (retains a single explicit
  "Defer" option — see Step 4 below; this is the ONE exception to "no Skip")
- `/meta` — Interview Stage 4.5 (group tasks by topic before creation; see batch variant)
- Universal fallback invocation from Mode B (`/task --expand`, `/task --recover`, `/spawn`)
  when the parent/source has no topic
- Universal fallback invocation from Mode C (`/review`, `/fix-it`) when the path heuristic
  misses

### Step 1: Build options array

```bash
# Get existing active topics from state.json
mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
```

**Zero-existing-topics branch**: if `${#existing_topics[@]} -eq 0` (every fresh repo's first
task), skip the picker entirely — `AskUserQuestion` requires 2-4 options, and "New topic..."
alone would under-shoot that floor. Go straight to Step 3's free-text prompt, reusing its
empty-input re-prompt rule. This branch offers no Skip and no Defer; topic assignment is still
mandatory, it is simply collected without an options picker.

```bash
if [[ ${#existing_topics[@]} -eq 0 ]]; then
  # Skip Step 2 entirely; go straight to Step 3's free-text prompt.
  :
else
  # Build AskUserQuestion options: existing + "New topic..." (no Skip option)
  options=()
  for t in "${existing_topics[@]}"; do
    options+=("$t")
  done
  options+=("New topic...")
fi
```

### Step 2: Show picker

Skipped entirely when `existing_topics` is empty (see Step 1's zero-existing-topics branch) —
go directly to Step 3. Otherwise, show the real `AskUserQuestion` schema (see
`context/standards/interactive-selection.md` for the authoritative schema definition):

```json
{
  "question": "Assign a topic to this task?",
  "header": "Topic",
  "multiSelect": false,
  "options": [
    {"label": "<existing-topic-1>", "description": "Existing topic"},
    {"label": "<existing-topic-2>", "description": "Existing topic"},
    {"label": "New topic...", "description": "Free-text follow-up to name a new topic"}
  ]
}
```

### Step 3: Handle "New topic..." branch

If the user selects "New topic..." (Step 2), or the zero-existing-topics branch (Step 1) skipped
straight here, prompt for free-text input in the next conversational turn. This is a natural-
language follow-up, not a second tool schema — `AskUserQuestion` has no `freeText` variant:

```
Enter new topic name (lowercase, kebab-case, e.g. 'agent-system'):
```

Validate: non-empty, no spaces (suggest replacing spaces with hyphens if entered). Re-prompt
on empty input — an empty free-text response is not a valid escape from topic assignment. This
is the same re-prompt rule the zero-existing-topics branch reuses.

### Step 4: Update state

```bash
# topic is either the selected existing value or the new free-text value.
# Every caller except /task --sync backfill MUST have a non-empty topic here.
bash .claude/scripts/manage-topics.sh add "$topic"
bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
```

**`/task --sync` backfill exception ONLY**: this is the sole path in the system permitted an
explicit deferral affordance, because it remediates pre-existing topicless tasks rather than
gatekeeping new-task creation. Its picker adds exactly one extra option, clearly labeled (NOT
"Skip"):

```json
{
  "question": "Assign a topic to this task?",
  "header": "Topic Backfill",
  "multiSelect": false,
  "options": [
    {"label": "<existing-topic-1>", "description": "Existing topic"},
    {"label": "<existing-topic-2>", "description": "Existing topic"},
    {"label": "New topic...", "description": "Free-text follow-up to name a new topic"},
    {"label": "Defer (leave uncategorized for now)", "description": "The one exception to mandatory topic assignment: leaves this pre-existing task topicless for now"}
  ]
}
```

```bash
if [[ "$topic" == "Defer (leave uncategorized for now)" ]]; then
  : # no-op, remediation deferred; Phase 6 warning in generate-task-order.sh keeps this visible
else
  bash .claude/scripts/manage-topics.sh add "$topic"
  bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
fi
```

### Mode A: Interactive, batch variant

Used when assigning topics to multiple tasks at once (e.g. `/meta` Stage 4.5 grouping several
proposed tasks, or `/fix-it`'s per-`topic_groups[]` fallback). The picker and options are the
same as Step 1-3 above but the question wording is pluralized (e.g. "Assign a topic to these N
tasks?") and the selection loops per group. No Skip option here either — a batch entry that
cannot be grouped by heuristic still routes through this picker before task creation completes.
It also inherits Steps 1-3's corrected `AskUserQuestion` schema and zero-existing-topics branch
verbatim: a batch invocation with no existing topics skips straight to free-text collection the
same way a single-task invocation does.

---

## Mode B: Inherit

Propagate the parent task's topic to child tasks automatically, without showing a picker.
Used for tasks that are derived from or blocked by another task and should share its
organizational context. **If the parent/source has no topic, the caller MUST invoke Mode A
(the universal fallback) rather than leaving the child topicless.**

**Caller locations**:
- `/task --expand N` — Sub-tasks inherit the expanded task's topic
- `/task --recover N` — Recovery tasks inherit the original task's topic
- `/spawn N` — Spawned unblock tasks inherit the blocked task's topic

### Canonical bash

```bash
# Read parent topic from state.json
parent_topic=$(jq -r --arg num "$parent_task_num" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // empty' \
  specs/state.json)

if [[ -n "$parent_topic" ]]; then
  bash .claude/scripts/manage-topics.sh add "$parent_topic"
  bash .claude/scripts/manage-topics.sh set "$new_task_num" "$parent_topic"
else
  # Parent has no topic: invoke Mode A as the universal fallback (no Skip option).
  # Show the Mode A picker (Steps 1-3 above) and apply Step 4 with the result.
  : # caller: run Mode A picker here, then manage-topics.sh add/set with its result
fi
```

---

## Mode C: Suggest

Infer the topic from the path of files being reviewed or the type of fix, without showing
a picker. Used for batch task creation where user interaction would be disruptive. **If the
path heuristic misses (the `other` branch below), the caller MUST invoke the Mode A batch
variant as the universal fallback instead of silently assigning `topic=""`.**

**Caller locations**:
- `/review` — Code review creates tasks; topic inferred from reviewed path
- `/fix-it` — Tag scanner creates tasks; topic inferred from file path

### Path heuristic table

| File path prefix | Inferred topic |
|-----------------|----------------|
| `.claude/` or `specs/` | `agent-system` |
| `lua/` or `after/` | `neovim` |
| `home/` or `modules/` (nix) | `nix-config` |
| other | *(routes to Mode A universal fallback — see below)* |

### Canonical bash

```bash
# file_path is the path of the file being reviewed/fixed
infer_topic_from_path() {
  local path="$1"
  if [[ "$path" == .claude/* || "$path" == specs/* ]]; then
    echo "agent-system"
  elif [[ "$path" == lua/* || "$path" == after/* ]]; then
    echo "neovim"
  elif [[ "$path" == home/* || "$path" == modules/* ]]; then
    echo "nix-config"
  else
    echo ""
  fi
}

inferred=$(infer_topic_from_path "$file_path")
if [[ -n "$inferred" ]]; then
  bash .claude/scripts/manage-topics.sh add "$inferred"
  bash .claude/scripts/manage-topics.sh set "$task_num" "$inferred"
else
  # Heuristic missed: invoke the Mode A batch variant as the universal fallback
  # (do NOT set topic="" and move on).
  : # caller: run Mode A batch-variant picker (confirm-wrap: Accept / Override, no Skip),
    # then manage-topics.sh add/set with its result
fi
```

---

## Autonomous Context

When `orchestrator_mode == true` (e.g. `/orchestrate`), no human is available to answer an
`AskUserQuestion` prompt, so callers of Mode A (including its universal-fallback invocations
from Mode B and Mode C) MUST NOT invoke `AskUserQuestion` for topic assignment. This mirrors the
`--lit` flag's deterministic-default directive for the equivalent autonomous-context gap (see
CLAUDE.md's Literature Mode section, "Global index exists, sub-index missing, autonomous
context" subsection, directive `AUTONOMOUS_GLOBAL`).

**Deterministic default** (apply in order, stop at the first that resolves):

1. **Inherit** — if a parent/source topic exists (the Mode B path), use it.
2. **Infer** — else, if the Mode C path heuristic resolves a topic from the relevant file path,
   use it.
3. **Sentinel + notice** — else, leave the task's `topic` field unset (do not fabricate a value)
   and emit a visible `[topic:auto]` notice to the transcript stating that topic assignment was
   skipped because no parent topic could be inherited, no path heuristic matched, and no human
   was available to prompt. This is never a silent no-op.

This directive is currently latent: no autonomous caller reaches the topic picker today (all
`/spawn`, `/fix-it`, and `/review` invocations run in interactive contexts). It is documented
here so a future autonomous caller has a defined path instead of dead-ending on
`AskUserQuestion`. It does not require any change to `/spawn`, `/fix-it`, or `/review` today.

---

## State Update Reference

All state mutations go through `manage-topics.sh`. Never write jq topic snippets inline.

| Subcommand | Description | Example |
|-----------|-------------|---------|
| `list` | Print all active topics, one per line | `bash .claude/scripts/manage-topics.sh list` |
| `add TOPIC` | Add topic to active_topics (idempotent) | `bash .claude/scripts/manage-topics.sh add "agent-system"` |
| `set TASK TOPIC` | Assign topic to task + add to active_topics | `bash .claude/scripts/manage-topics.sh set 42 "agent-system"` |
| `validate TOPIC` | Exit 0 if present, exit 1 if not | `bash .claude/scripts/manage-topics.sh validate "agent-system"` |

**Exit codes**: `0`=success/found, `1`=not-found/bad-args, `2`=state.json-error,
`3`=jq-write-failure, `4`=task-not-found.

---

## Related Documentation

- `.claude/scripts/manage-topics.sh` — Script implementation with full inline docs
- `.claude/rules/state-management.md` — State update patterns and schema
- `.claude/context/patterns/jq-escaping-workarounds.md` — jq safety (Issue #1132)
- `.claude/context/reference/state-management-schema.md` — Full state.json schema
