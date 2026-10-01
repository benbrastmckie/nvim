---
name: skill-fix-it
description: Scan codebase for FIX:/NOTE:/TODO:/QUESTION: tags and create structured tasks with interactive selection. Invoke for /fix-it command.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Fix-It Skill (Direct Execution)

Direct execution skill for scanning files, presenting findings interactively, and creating user-selected tasks. Replaces the previous delegation-based approach with synchronous execution and AskUserQuestion prompts.

**Key behavior**: Users always see tag scan results BEFORE any tasks are created. Users select which task types to create via interactive prompts.

## Context References

Reference (do not load eagerly):
- Path: `@specs/TODO.md` - Current task list
- Path: `@specs/state.json` - Machine state

---

## Execution

### Step 1: Parse Arguments

Extract paths from command input:

```bash
# Parse from command input
paths="$ARGUMENTS"

# Default to project root if no paths specified
if [ -z "$paths" ]; then
  paths="."
fi
```

**Note**: The `--dry-run` flag is no longer supported. The interactive flow is inherently "preview first" - users always see findings before any tasks are created.

### Step 2: Generate Session ID

Generate session ID for tracking:

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
```

### Step 3: Execute Tag Extraction

Scan for all four tag types (FIX:, NOTE:, TODO:, QUESTION:) using file-type-specific comment patterns:

| File Type | Comment Prefix | Includes |
|-----------|---------------|----------|
| Lua | `--` | `*.lua` |
| LaTeX | `%` | `*.tex` |
| Markdown | `<!--` | `*.md` |
| Script | `#` | `*.py`, `*.sh`, `*.yaml`, `*.yml` |

For each tag type, grep across all file types with `-rn` and collect matches. Parse each match into: file path, line number, tag type, tag content.

Categorize into arrays: `fix_tags[]`, `note_tags[]`, `todo_tags[]`, `question_tags[]`.

### Step 4: Display Tag Summary

Present findings to user BEFORE any selection:

```
## Tag Scan Results

**Files Scanned**: {paths}
**Tags Found**: {total_count}

### FIX: Tags ({count})
- `{file}:{line}` - {content}
- ...

### NOTE: Tags ({count})
- `{file}:{line}` - {content}
- ...

### TODO: Tags ({count})
- `{file}:{line}` - {content}
- ...

### QUESTION: Tags ({count})
- `{file}:{line}` - {content}
- ...
```

### Step 5: Handle Edge Cases

#### No Tags Found

If no tags found:
```
## No Tags Found

Scanned files in: {paths}
No FIX:, NOTE:, TODO:, or QUESTION: tags detected.

Nothing to create.
```

Exit gracefully without prompts.

#### Only Certain Tag Types

Only show task type options for tag types that exist:
- FIX: tags exist -> offer "fix-it task"
- NOTE: tags exist -> offer "fix-it task" AND "learn-it task"
- TODO: tags exist -> offer "TODO tasks"
- QUESTION: tags exist -> offer "Research tasks"

### Step 6: Task Type Selection

If tags were found, prompt user to select task types:

```json
{
  "question": "Which task types should be created?",
  "header": "Task Types",
  "multiSelect": true,
  "options": [
    {
      "label": "fix-it task",
      "description": "Combine {N} FIX:/NOTE: tags into single task"
    },
    {
      "label": "learn-it task",
      "description": "Update context from {N} NOTE: tags"
    },
    {
      "label": "TODO tasks",
      "description": "Create tasks for {N} TODO: items"
    },
    {
      "label": "Research tasks",
      "description": "Create research tasks for {N} QUESTION: items"
    }
  ]
}
```

**Important**: Only include options where the tag type exists:
- Include "fix-it task" only if FIX: or NOTE: tags exist
- Include "learn-it task" only if NOTE: tags exist
- Include "TODO tasks" only if TODO: tags exist
- Include "Research tasks" only if QUESTION: tags exist

If user selects nothing, exit gracefully:
```
No task types selected. No tasks created.
```

### Step 7: Individual TODO Selection

If "TODO tasks" was selected AND there are TODO: tags:

#### Standard Case (<=20 TODOs)

```json
{
  "question": "Select TODO items to create as tasks:",
  "header": "TODO Selection",
  "multiSelect": true,
  "options": [
    {
      "label": "{content truncated to 50 chars}",
      "description": "{file}:{line}"
    },
    ...
  ]
}
```

#### Large Number of TODOs (>20)

Add a "Select all" option at the top:

```json
{
  "question": "Select TODO items to create as tasks:",
  "header": "TODO Selection (many items)",
  "multiSelect": true,
  "options": [
    {
      "label": "Select all ({N} items)",
      "description": "Create a task for every TODO tag"
    },
    {
      "label": "{content truncated to 50 chars}",
      "description": "{file}:{line}"
    },
    ...
  ]
}
```

If "Select all" is chosen, include all TODOs. Otherwise, only selected items.

### Step 7.5: Topic Grouping (Shared Algorithm)

This grouping algorithm applies to both TODO items (Step 7.5) and QUESTION items (Step 7.7). Skip if only 1 item selected.

**Topic Indicator Extraction** per item:
- **Shared-Target Indicator**: the anticipated narrow `file_scope` path(s) the item would declare,
  and any named acceptance gate or check it resolves. See Component 0 (Task-Count Reasoning) in
  `.claude/docs/reference/standards/multi-task-creation-standard.md` for the full rule and its
  narrowness exclusion (a directory root or broad, widely-edited infrastructure file does not
  count).
- **Key Terms**: Significant words (nouns, verbs), ignoring stop words
- **File Section**: Group by file path prefix
- **Action Type**: Inferred from content (Add/Create -> implementation, Fix -> fix, Document -> docs, Test -> testing, Refactor -> improvement). For QUESTION items, action_type is always "research".

**Clustering Algorithm**: the shared-target/shared-gate branch (step 2) is the **primary** match
criterion — it runs first because it is the sharper, structural signal Component 0 names, ahead
of the fuzzy file_section/action_type and key-term branches, which cannot see it.
1. Start with first item as initial group
2. **Primary match**: add to existing group if it shares a narrow `file_scope` entry or the same
   named acceptance gate with that group (per Component 0's narrowness qualifier); otherwise
   continue to step 3
3. **Secondary match**: add to existing group if shares 2+ key terms OR shares file_section +
   action_type; otherwise start new group
4. Generate topic label from most common shared terms
5. Single-item groups are kept as-is

**Store result**: `topic_groups[]` with `{label, items[], shared_terms[], action_type}`

### Step 7.5.4: Topic Group Confirmation

**Condition**: At least one group has 2+ items (otherwise skip -- no grouping benefit).

Present via AskUserQuestion (multiSelect: false):
- "Accept suggested topic groups" -- Creates {N} grouped tasks
- "Keep as separate tasks" -- Creates {M} individual tasks
- "Create single combined task" -- Creates 1 task with all items

**Store**: `grouping_mode = "grouped" | "separate" | "combined"`

### Step 7.6: Individual QUESTION Selection

**Condition**: User selected "Research tasks" in Step 6 AND QUESTION: tags exist.

Same pattern as Step 7 (TODO selection): AskUserQuestion with multiSelect, "Select all" option when >20 items.

### Step 7.7: Topic Grouping for QUESTION Items

**Condition**: Selected more than 1 QUESTION item.

Apply the **same algorithm as Step 7.5** with these differences:
- action_type is always "research"
- Store result in `question_topic_groups[]`
- Confirmation prompt uses "research tasks" wording

**Store**: `question_grouping_mode = "grouped" | "separate" | "combined"`

### Step 8: Create Selected Tasks

For each selected task type, create the task. **Important**: When NOTE: tags exist and both fix-it and learn-it tasks are selected, create learn-it FIRST so fix-it can depend on it.

#### 8.1: Get Next Task Number

Bootstrap `specs/` first if this is the first task in this repo (idempotent; see
`context/standards/orchestrator-runtime-files.md`'s "Consumer Repo Setup"):
```bash
bash .claude/scripts/init-specs.sh
```

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
```

#### 8.2: Dependency-Aware Task Creation Order

**Check for NOTE: dependency condition**:
```
has_note_dependency = (NOTE: tags exist) AND (user selected both "fix-it task" AND "learn-it task")
```

**If has_note_dependency is TRUE**:
- Create learn-it task FIRST (Step 8.2a)
- Store learn-it task number as `learn_it_task_num`
- Create fix-it task SECOND with dependency (Step 8.2b)

**If has_note_dependency is FALSE**:
- Create fix-it task first (if selected)
- Create learn-it task second (if selected)
- No dependency relationship

#### 8.2a: Learn-It Task (when created first for dependency)

**Condition**: has_note_dependency is TRUE

```json
{
  "title": "Update context files from NOTE: tags",
  "description": "Update {N} context files based on learnings:\n\n{grouped by target context}",
  "task_type": "meta",
  "effort": "1-2 hours"
}
```

Store the task number: `learn_it_task_num = next_num`
Increment: `next_num = next_num + 1`

#### 8.2b: Fix-It Task (with dependency when has_note_dependency)

**Condition**: User selected "fix-it task" AND (FIX: or NOTE: tags exist)

**When has_note_dependency is TRUE**:
```json
{
  "title": "Fix issues from FIX:/NOTE: tags",
  "description": "Address {N} items from embedded tags:\n\n{list of items with file:line references}\n\n**Important**: When making changes, remove the FIX: and NOTE: tags from the source files. Leave TODO: tags untouched (they create separate tasks).",
  "task_type": "{predominant task_type from source files}",
  "effort": "2-4 hours",
  "dependencies": [learn_it_task_num]
}
```

**When has_note_dependency is FALSE**:
```json
{
  "title": "Fix issues from FIX:/NOTE: tags",
  "description": "Address {N} items from embedded tags:\n\n{list of items with file:line references}\n\n**Important**: When making changes, remove the FIX: and NOTE: tags from the source files. Leave TODO: tags untouched (they create separate tasks).",
  "task_type": "{predominant task_type from source files}",
  "effort": "2-4 hours"
}
```

**Language Detection**:
```
if majority of tags from .lean files -> "lean"
elif majority from .tex files -> "latex"
elif majority from .claude/ files -> "meta"
else -> "general"
```

#### 8.2c: File Footprint Overlap Check (Component 4a)

In addition to the hardcoded NOTE-before-fix-it dependency rule above (8.2), run the shared
Multi-Task Creation Standard Component 4a overlap check across `topic_groups[]` (each group
already carries a `file_section` from Step 7.5's clustering):

1. **Derive `file_scope` per group**: union the `file:line` paths of every item in the group
   (dropping the `:line` suffix) into a `file_scope` array for that group's would-be task.
2. **Run the shared overlap algorithm** (`.claude/context/patterns/file-footprint-overlap.md`,
   referenced by path — not restated here) pairwise across all groups that will become separate
   tasks (grouped or separate mode; combined mode produces a single task, so no pairwise check
   applies).
3. **Auto-add a serializing dependency** for every overlapping pair with no existing edge
   (in addition to the fix-it/learn-it edge from 8.2), so two groups whose `file_scope` overlaps
   never land in the same task creation batch without a dependency between them.
4. **Never silent**: annotate any auto-added edge in the Step 9 task summary/confirmation with
   "(auto: file overlap)" per Component 7 of the Multi-Task Creation Standard.

#### 8.3: Learn-It Task (when created without dependency)

**Condition**: User selected "learn-it task" AND NOTE: tags exist AND has_note_dependency is FALSE

```json
{
  "title": "Update context files from NOTE: tags",
  "description": "Update {N} context files based on learnings:\n\n{grouped by target context}",
  "task_type": "meta",
  "effort": "1-2 hours"
}
```

#### 8.4: Todo-Tasks (if selected)

**Condition**: User selected "TODO tasks" AND user selected specific TODO items

**Check grouping_mode** (from Step 7.5.4, defaults to "separate" if Step 7.5.4 was skipped):

##### 8.4.1: Grouped Mode (grouping_mode == "grouped")

For each topic group in `topic_groups`:

```json
{
  "title": "{topic_label}: {item_count} TODO items",
  "description": "Address TODO items related to {topic_label}:\n\n{item_list}\n\n---\n\nShared context: {shared_terms_description}",
  "task_type": "{detected from majority file type in group}",
  "effort": "{scaled_effort}"
}
```

Where:
- `{topic_label}` = generated label (e.g., "Database Migrations")
- `{item_count}` = number of items in group
- `{item_list}` = formatted list of items:
  ```
  - [ ] {content} (`{file}:{line}`)
  - [ ] {content} (`{file}:{line}`)
  ```
- `{shared_terms_description}` = brief description of why items are grouped (e.g., "Related to database schema changes")

**Effort Scaling Formula**:
```
base_effort = 1 hour
scaled_effort = base_effort + (30 min * (item_count - 1))

Examples:
  1 item  → 1 hour
  2 items → 1.5 hours (1h + 30min)
  3 items → 2 hours (1h + 60min)
  4 items → 2.5 hours (1h + 90min)
```

##### 8.4.2: Combined Mode (grouping_mode == "combined")

Create single task containing all selected TODO items:

```json
{
  "title": "Address {item_count} TODO items",
  "description": "Combined TODO items from scan:\n\n{all_items_list}\n\n---\n\nFiles: {unique_files_list}",
  "task_type": "{detected from majority file type}",
  "effort": "{scaled_effort}"
}
```

Where:
- `{item_count}` = total number of selected TODO items
- `{all_items_list}` = formatted list of all items with checkboxes
- `{unique_files_list}` = comma-separated list of unique files involved

**Effort Scaling**: Same formula as grouped mode.

##### 8.4.3: Separate Mode (grouping_mode == "separate" or default)

For each selected TODO item individually:

```json
{
  "title": "{tag content, truncated to 60 chars}",
  "description": "{full tag content}\n\nSource: {file}:{line}",
  "task_type": "{detected from file type}",
  "effort": "1 hour"
}
```

**Language Detection for Todo-Task** (all modes):
```
.lua -> "general"
.tex  -> "latex"
.md   -> "markdown"
.py/.sh -> "general"
.claude/* -> "meta"
```

#### 8.5: Research-Tasks (if selected)

**Condition**: User selected "Research tasks" AND user selected specific QUESTION items.

Uses `question_grouping_mode` from Step 7.7 (defaults to "separate"). Same grouped/combined/separate modes as TODO tasks (Step 8.4), with these differences:

- **Language detection is content-based** (not file-based): Match question text against keyword lists:
  - lean4: theorem, proof, lemma, axiom, proposition, corollary, derivation
  - formal: logic
  - latex: latex, tex, bibtex, biblatex, latex macro, latex package, compile error
  - typst: typst, typst package, typst compile
  - meta: .claude, command, agent, skill, workflow, state.json, TODO.md, specs/
  - Default: "general"

  (`formula` is deliberately omitted from every row: it can be either mathematical content or a
  rendering question, so it is not guessed at and falls through to `general`.)
- **Effort base**: 1.5 hours (vs 1 hour for TODO tasks), same +30min scaling per additional item
- **Title prefix**: "Research: {content}" for separate mode
- **Description format**: Uses blockquote syntax (`> {question text}`) instead of checkboxes

### Step 9: Update State Files

For each task created:

#### 9.1: Update state.json

Read current state, add new task entry, increment next_project_number:

```bash
# Create slug from title
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd 'a-z0-9_' | cut -c1-50)

# Read current state
current=$(cat specs/state.json)

# Add task using jq (use two-step pattern to avoid escaping issues)
# Step 1: Write task data to temp file
# Step 2: Use jq with slurpfile
```

**Topic Auto-Inference and Confirm (Mode C Suggest-Wrap)**: Before writing each task entry, infer topic from file path and description, then ask user to confirm:

```bash
# Infer topic from source file paths for this task
inferred_topic=""
for tag_path in "${task_file_paths[@]}"; do
  if [[ "$tag_path" == .claude/* || "$tag_path" == specs/* ]]; then
    inferred_topic="agent-system"; break
  elif [[ "$tag_path" == lua/* || "$tag_path" == after/* ]]; then
    inferred_topic="neovim"; break
  elif [[ "$tag_path" == home/* || "$tag_path" == modules/* ]]; then
    inferred_topic="nix-config"; break
  fi
done
```

If `inferred_topic` is non-empty, show Mode C confirm via AskUserQuestion (Accept / Override
only — no Skip option; topic assignment is mandatory):
```json
{
  "question": "Topic for this task?",
  "header": "Topic Confirm",
  "multiSelect": false,
  "options": [
    {"label": "Accept: {inferred_topic}", "description": "Use auto-inferred topic"},
    {"label": "Override...", "description": "Enter a different topic name"}
  ]
}
```

- If user selects "Accept: {inferred_topic}" → `topic="$inferred_topic"`
- If user selects "Override..." → show free-text follow-up: `{"question": "Enter topic name (lowercase, kebab-case):"}` and capture result as `topic`

If `inferred_topic` is empty (the path heuristic missed for this `topic_groups[]` entry),
invoke the Mode A universal fallback instead of setting `topic=""`: follow
@.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive, batch variant)
and capture the result in `topic`.

**For fix-it task when has_note_dependency is TRUE**, include dependencies array:
```json
{
  "project_number": {N},
  "project_name": "{slug}",
  "status": "not_started",
  "task_type": "{task_type}",
  "title": "{title}",
  "description": "{description}",
  "topic": "{auto-inferred topic}",
  "dependencies": [learn_it_task_num]
}
```

Note: Pass `--arg title "$title"` and `--arg desc "$description"` to the jq call.

**For all other tasks**:
```json
{
  "project_number": {N},
  "project_name": "{slug}",
  "status": "not_started",
  "task_type": "{task_type}",
  "title": "{title}",
  "description": "{description}",
  "topic": "{auto-inferred topic}"
}
```

Note: Pass `--arg title "$title"` and `--arg desc "$description"` to the jq call.

Note: The `"topic"` field is always populated (topic assignment is mandatory — the
Mode A universal fallback runs whenever the path heuristic cannot infer a topic).

#### 9.2: (Removed — state.json is authoritative for task entries)

The state.json update in Step 9.1 already writes the task data. TODO.md will be regenerated via generate-todo.sh in Step 9.4 after all state.json writes complete.

### Step 9.3: Assign Topics via manage-topics.sh (Non-Blocking)

After each task has been written to state.json, assign the confirmed topic via `manage-topics.sh set`. The `set` subcommand also calls `add` internally, so no standalone `add` call is needed:

```bash
# For each task created, call set AFTER the task entry exists in state.json
# topic is the value from Mode C confirm in Step 9.1 (may be "" if user skipped)
if [[ -n "$topic" ]]; then
  bash .claude/scripts/manage-topics.sh set "$task_num" "$topic" \
    2>/dev/null || echo "Warning: manage-topics.sh set failed for task $task_num (non-fatal)" >&2
fi
```

The `manage-topics.sh set` call updates both the task entry's `topic` field and the `active_topics` array atomically. Topics that are empty/null are skipped via the `[[ -n "$topic" ]]` guard.

### Step 9.4: Regenerate TODO.md (Non-Blocking)

After all tasks have been written to state.json, regenerate the entire TODO.md from state.json:

```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

### Step 10: Display Results

Show summary of created tasks:

```
## Tasks Created from Tags

**Tags Processed**: {N} across scanned files

### Created Tasks

| # | Type | Title | Language | Topic |
|---|------|-------|----------|-------|
| {N} | fix-it | Fix issues from FIX:/NOTE: tags | {lang} | {topic} |
| {N+1} | learn-it | Update context files from NOTE: tags | meta | agent-system |
| {N+2} | todo | {title} | {lang} | {topic} |
| {N+3} | research | Research: {question title} | {lang} | {topic} |

---

**Next Steps**:
1. Review tasks in TODO.md
2. Run `/research {first_task}` to begin
3. Progress through /research -> /plan -> /implement cycle
```

### Step 11: Git Commit (Postflight)

If tasks were created, commit changes via `.claude/scripts/git-commit-scoped.sh`, the single
sanctioned implementation of path-scoped, mutex-serialized committing:

```bash
task_count={number of tasks created}
bash .claude/scripts/git-commit-scoped.sh \
  --message "fix-it: create $task_count tasks from tags" \
  --session "$session_id" \
  -- specs/TODO.md specs/state.json
```

---

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **Path access errors**: Log warning per invalid path, continue with valid ones; exit if none remain
- **No tags found**: Not an error -- report informatively and exit without prompts
- **state.json/TODO.md failures**: Try two-step jq pattern; report partial success if still failing
- **Git commit failure**: Non-blocking (tasks still created)

## Standards Reference

Implements the multi-task creation pattern (full compliance). See `.claude/docs/reference/standards/multi-task-creation-standard.md`.
