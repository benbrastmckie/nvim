---
name: skill-fix-it
description: Scan files for FIX:/NOTE:/TODO:/QUESTION: tags and create structured tasks with interactive selection and topic grouping. Invoke for /fix-it command.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Fix-It Skill (Direct Execution)

Direct execution skill for scanning files, presenting findings interactively, and creating user-selected tasks with topic grouping capabilities.

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

### Step 2: Generate Session ID

Generate session ID for tracking:

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 3: Execute Tag Extraction

Scan for tags using file-type-specific patterns:

**Lua files (Neovim config)**:
```bash
grep -rn --include="*.lua" "-- FIX:" $paths 2>/dev/null || true
grep -rn --include="*.lua" "-- NOTE:" $paths 2>/dev/null || true
grep -rn --include="*.lua" "-- TODO:" $paths 2>/dev/null || true
grep -rn --include="*.lua" "-- QUESTION:" $paths 2>/dev/null || true
```

**LaTeX files**:
```bash
grep -rn --include="*.tex" "% FIX:" $paths 2>/dev/null || true
grep -rn --include="*.tex" "% NOTE:" $paths 2>/dev/null || true
grep -rn --include="*.tex" "% TODO:" $paths 2>/dev/null || true
grep -rn --include="*.tex" "% QUESTION:" $paths 2>/dev/null || true
```

**Markdown files**:
```bash
grep -rn --include="*.md" "<!-- FIX:" $paths 2>/dev/null || true
grep -rn --include="*.md" "<!-- NOTE:" $paths 2>/dev/null || true
grep -rn --include="*.md" "<!-- TODO:" $paths 2>/dev/null || true
grep -rn --include="*.md" "<!-- QUESTION:" $paths 2>/dev/null || true
```

**Python/Shell/YAML files**:
```bash
grep -rn --include="*.py" --include="*.sh" --include="*.yaml" --include="*.yml" "# FIX:" $paths 2>/dev/null || true
grep -rn --include="*.py" --include="*.sh" --include="*.yaml" --include="*.yml" "# NOTE:" $paths 2>/dev/null || true
grep -rn --include="*.py" --include="*.sh" --include="*.yaml" --include="*.yml" "# TODO:" $paths 2>/dev/null || true
grep -rn --include="*.py" --include="*.sh" --include="*.yaml" --include="*.yml" "# QUESTION:" $paths 2>/dev/null || true
```

### Step 4: Parse Results

For each grep match, extract:
- File path
- Line number
- Tag type (FIX, NOTE, TODO, QUESTION)
- Tag content (text after the tag)

Categorize into four arrays:
- `fix_tags[]` - All FIX: tags
- `note_tags[]` - All NOTE: tags
- `todo_tags[]` - All TODO: tags
- `question_tags[]` - All QUESTION: tags

### Step 5: Display Tag Summary

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

**Important**: Only include options where the tag type exists.

### Step 7: Individual Selection

If "TODO tasks" or "Research tasks" was selected, present individual items for selection:

```json
{
  "question": "Select items to create as tasks:",
  "header": "Item Selection",
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

### Step 8: Topic Grouping (TODO and QUESTION items)

If multiple TODO or QUESTION items selected, offer topic grouping:

**Extract Topic Indicators**:
- **Key Terms**: Extract significant words from content (nouns, verbs)
- **File Section**: Group by file path prefix
- **Action Type**: Identify patterns (Add/Implement, Fix/Handle, Document, Test, Refactor)

**Clustering Algorithm**:
1. Group items sharing 2+ key terms OR file section + action type
2. Generate topic labels from most common shared terms
3. Present grouping options:
   - Accept suggested topic groups
   - Keep as separate tasks
   - Create single combined task

### Step 9: Create Selected Tasks

#### Dependency-Aware Creation Order

**If NOTE: tags exist AND both fix-it and learn-it selected**:
1. Create learn-it task FIRST
2. Create fix-it task with dependency on learn-it

**Otherwise**:
- Create tasks in any order

#### Task Format

**Fix-it task**:
```json
{
  "title": "Fix issues from FIX:/NOTE: tags",
  "description": "Address {N} items from embedded tags...",
  "language": "{detected}",
  "effort": "2-4 hours",
  "dependencies": [learn_it_task_num]  // if applicable
}
```

**Learn-it task**:
```json
{
  "title": "Update context files from NOTE: tags",
  "description": "Update {N} context files based on learnings...",
  "language": "meta",
  "effort": "1-2 hours"
}
```

**TODO tasks** (grouped, combined, or separate based on user choice):
```json
{
  "title": "{topic_label}: {item_count} TODO items",
  "description": "Address TODO items related to {topic_label}...",
  "language": "{detected}",
  "effort": "{scaled_effort}"
}
```

**Research tasks** (grouped, combined, or separate):
```json
{
  "title": "Research: {topic_label}: {item_count} questions",
  "description": "Research questions related to {topic_label}...",
  "language": "{detected from question content}",
  "effort": "1-2 hours per item"
}
```

### Step 10: Update State Files

For each task created:
1. Generate slug from title
2. Add entry to state.json
3. Prepend entry to TODO.md
4. Increment next_project_number

### Step 11: Display Results

Show summary of created tasks:

```
## Tasks Created from Tags

**Tags Processed**: {N} across scanned files

### Created Tasks

| # | Type | Title | Language |
|---|------|-------|----------|
| {N} | fix-it | Fix issues from FIX:/NOTE: tags | {lang} |
| {N+1} | learn-it | Update context files from NOTE: tags | meta |
| {N+2} | todo | {title} | {lang} |
| {N+3} | research | Research: {question title} | {lang} |

---

**Next Steps**:
1. Review tasks in TODO.md
2. Run `/research {first_task}` to begin
3. Progress through /research -> /plan -> /implement cycle
```

### Step 12: Git Commit (Postflight)

If tasks were created, commit changes:

```bash
task_count={number of tasks created}
git add specs/TODO.md specs/state.json
git commit -m "fix-it: create $task_count tasks from tags

Session: $session_id

Co-Authored-By: OpenCode <noreply@opencode.ai>"
```

---

## Tag Patterns

| Tag | Purpose | Example |
|-----|---------|---------|
| `FIX:` | Bug or issue that needs fixing | `-- FIX: Handle null pointer case` |
| `NOTE:` | Important observation or documentation | `-- NOTE: This assumes positive integers` |
| `TODO:` | Pending work or implementation | `-- TODO: Add input validation` |
| `QUESTION:` | Research question to investigate | `-- QUESTION: What is the best way to configure LSP?` |

---

## Task Creation Rules

- FIX: tags -> Create "fix-it" type tasks
- NOTE: tags -> Create "learn-it" tasks (context updates) + contribute to "fix-it" tasks
- TODO: tags -> Create individual or grouped TODO tasks with topic clustering
- QUESTION: tags -> Create research tasks with content-based language detection

---

## Error Handling

### No Tags Found

This is NOT an error condition:
- Report informatively
- Exit without prompts

### Path Access Errors

When paths don't exist:
1. Log warning for each invalid path
2. Continue with valid paths
3. If no valid paths remain, report and exit

### State Update Failure

If jq fails:
1. Log error with command and output
2. Try two-step jq pattern
3. Report partial success if still failing

### Git Commit Failure

Non-blocking:
1. Log the failure
2. Tasks are still created successfully
3. Report that commit failed but tasks exist
