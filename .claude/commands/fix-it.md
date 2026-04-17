---
description: Scan files for FIX:, NOTE:, TODO:, QUESTION: tags and create structured tasks interactively
allowed-tools: Skill
argument-hint: [PATH...]
model: opus
---

# /fix-it Command

Scans codebase files for embedded tags (`FIX:`, `NOTE:`, `TODO:`, `QUESTION:`) and creates structured tasks based on user selection. This command helps capture work items embedded in source code comments.

## Arguments

- No args: Scan entire project for tags
- `PATH...` - Scan specific files or directories

## Interactive Flow

The command always runs interactively:
1. Scan files for tags
2. Display tag summary to user
3. Prompt for task type selection
4. Optionally prompt for individual TODO selection
5. **Optionally prompt for TODO topic grouping** (if 2+ TODOs selected)
6. Optionally prompt for individual QUESTION selection
7. **Optionally prompt for QUESTION topic grouping** (if 2+ QUESTIONs selected)
8. Create selected tasks

This design ensures users always see what was found before any tasks are created.

## Tag Types and Task Generation

| Tag | Task Type | Description |
|-----|-----------|-------------|
| `FIX:` | fix-it-task | Grouped into single task for small changes |
| `NOTE:` | fix-it-task + learn-it-task | Creates both task types (with dependency) |
| `TODO:` | todo-task | Individual task per selected tag |
| `QUESTION:` | research-task | Research task to answer embedded questions |

### Task Type Details

**fix-it-task**: Combines all FIX: and NOTE: tags into a single task describing fixes needed. Includes file paths and line references. Only offered if FIX: or NOTE: tags exist.

**learn-it-task**: Groups NOTE: tags by target context directory. Creates tasks to update `.claude/context/` files based on the learnings. Only offered if NOTE: tags exist.

**todo-task**: One task per selected TODO: tag (or grouped by topic). Preserves original text as task description. Language detected from source file type.

**research-task**: One task per selected QUESTION: tag (or grouped by topic). Creates research tasks to answer embedded questions. **Language is detected from question content** (not source file type) using keyword matching: extension-specific keywords are matched by loaded extensions, latex keywords (theorem, proof, lemma, etc.) -> "latex", meta keywords (.claude, command, agent, etc.) -> "meta", otherwise -> "general".

### TODO Topic Grouping

When multiple TODO items are selected, the command analyzes them for semantic topics and offers grouping options:

1. **Accept suggested topic groups** - Creates grouped tasks based on shared terms, file sections, and action types
2. **Keep as separate tasks** - Traditional behavior (one task per TODO item)
3. **Create single combined task** - All TODO items in one task

**Topic detection uses**:
- Shared key terms (2+ significant terms in common)
- File section proximity (same directory)
- Action type similarity (implement, fix, document, test, refactor)

**Example topic groups**:
```
Group: "S5 Theorems" (2 items)
  - Add LSP configuration for S5
  - Add soundness theorem for S5

Group: "Utility Optimization" (1 item)
  - Optimize helper function
```

**Effort scaling for grouped tasks**:
- Base: 1 hour
- +30 minutes per additional item
- Example: 3 items = 2 hours

### Dependency Workflow for NOTE: Tags

When NOTE: tags exist and you select **both** fix-it and learn-it task types:

1. **Learn-it task is created first** - Updates context files based on learnings (NOTE: tags remain in source files)
2. **Fix-it task is created second with dependency** - Has `dependencies: [learn_it_task_num]` pointing to the learn-it task

This ensures proper workflow ordering:
- Learn-it task handles knowledge extraction to context files only
- Fix-it task handles file-local code changes and removes both NOTE: and FIX: tags (TODO: tags are left for separate tasks)

This dependency is only added when both task types are selected for NOTE: tags. If you select only one task type, no dependency is created.

## Supported Comment Styles

| File Type | Comment Prefix | Example |
|-----------|----------------|---------|
| Lua (`.lua`) | `--` | `-- FIX: Handle edge case` |
| LaTeX (`.tex`) | `%` | `% NOTE: Document this pattern` |
| Markdown (`.md`) | `<!--` | `<!-- TODO: Add section -->` |
| Python/Shell/YAML | `#` | `# QUESTION: What is the best approach?` |

## Execution

### 1. Scan and Display

The skill scans specified paths and displays findings:

```
## Tag Scan Results

**Files Scanned**: src/, docs/
**Tags Found**: 17

### FIX: Tags (5)
- `src/module.lua:23` - Handle edge case in parser
- `src/module.lua:45` - Fix off-by-one error
...

### NOTE: Tags (3)
- `docs/guide.tex:89` - Document this pattern
...

### TODO: Tags (7)
- `src/components/Modal.js:67` - Add LSP configuration
...

### QUESTION: Tags (2)
- `src/config/lsp.js:45` - What is the best way to configure hover windows?
...
```

### 2. Task Type Selection

User selects which task types to create via AskUserQuestion:

```json
{
  "question": "Which task types should be created?",
  "header": "Task Types",
  "multiSelect": true,
  "options": [
    {"label": "fix-it task", "description": "Combine 8 FIX:/NOTE: tags into single task"},
    {"label": "learn-it task", "description": "Update context from 3 NOTE: tags"},
    {"label": "TODO tasks", "description": "Create tasks for 7 TODO: items"},
    {"label": "Research tasks", "description": "Create research tasks for 2 QUESTION: items"}
  ]
}
```

### 3. TODO Item Selection

If "TODO tasks" is selected, user picks individual items:

```json
{
  "question": "Select TODO items to create as tasks:",
  "header": "TODO Selection",
  "multiSelect": true,
  "options": [
    {"label": "Add LSP configuration", "description": "src/components/Modal.js:67"},
    {"label": "Implement helper function", "description": "src/utils/helpers.js:23"}
  ]
}
```

For >20 TODO items, add "Select all" option.

### 4. Topic Grouping (if 2+ TODOs)

When multiple TODOs are selected, the command analyzes them for topics:

```json
{
  "question": "How should TODO items be grouped into tasks?",
  "header": "Topic Grouping",
  "multiSelect": false,
  "options": [
    {"label": "Accept suggested topic groups", "description": "Creates 2 grouped tasks: S5 Theorems (2), Utility Optimization (1)"},
    {"label": "Keep as separate tasks", "description": "Creates 3 individual tasks"},
    {"label": "Create single combined task", "description": "Creates 1 task containing all items"}
  ]
}
```

### 5. Task Creation

Selected tasks are created in TODO.md and state.json.

## Output Examples

### Tags Found - Interactive Selection

```
## Tag Scan Results

**Files Scanned**: .
**Tags Found**: 17

### FIX: Tags (5)
- `src/module.lua:23` - Handle edge case in parser
- `src/module.lua:45` - Fix off-by-one error
- `docs/guide.tex:56` - Update outdated reference

### NOTE: Tags (3)
- `docs/guide.tex:89` - Document this pattern
- `.claude/agents/foo.md:12` - Update context routing

### TODO: Tags (7)
- `src/components/Modal.js:67` - Add LSP configuration
- `src/utils/helpers.js:23` - Implement helper function
...

### QUESTION: Tags (2)
- `src/config/lsp.js:45` - What is the best way to configure hover windows?
- `src/plugins/cmp.js:78` - How do I customize completion sources?

---

[User selects task types and items]

---

## Tasks Created from Tags

**Tags Processed**: 17

### Created Tasks

| # | Type | Title | Priority | Language |
|---|------|-------|----------|----------|
| 650 | fix-it | Fix issues from FIX:/NOTE: tags | High | general |
| 651 | learn-it | Update context files from NOTE: tags | Medium | meta |
| 652 | todo | Add LSP configuration | Medium | general |
| 653 | todo | Implement helper function | Medium | general |
| 654 | research | Research: What is the best way to configure... | Medium | general |

---

Next Steps:
1. Review tasks in TODO.md
2. Run /research 650 to begin
3. Progress through /research -> /plan -> /implement cycle
```

### No Tags Found

```
## No Tags Found

Scanned files in: src/
No FIX:, NOTE:, TODO:, or QUESTION: tags detected.

Nothing to create.
```

### No Selection Made

```
## Tag Scan Results
...

---

No task types selected. No tasks created.
```

## Examples

```bash
# Scan entire project interactively
/fix-it

# Scan specific directory
/fix-it src/components/

# Scan specific file
/fix-it docs/04-Metalogic.tex

# Scan multiple paths
/fix-it src/ .claude/agents/
```

## Standards Reference

This command implements the multi-task creation pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard.

**Compliance Level**: Full (all required components)

| Component | Status | Notes |
|-----------|--------|-------|
| Discovery | Yes | Tag scanning (FIX:, NOTE:, TODO:, QUESTION:) |
| Selection | Yes | AskUserQuestion with multiSelect |
| Grouping | Yes | Topic clustering for TODO and QUESTION |
| Dependencies | Partial | Internal only (learn-it -> fix-it) |
| Ordering | No | Sequential creation |
| Visualization | No | Not implemented |
| Confirmation | Yes | Implicit via selection |
| State Updates | Yes | Atomic state.json + TODO.md |

**Limitation**: External dependency support (TODO tasks depending on existing tasks) is not implemented. The only dependency relationship is internal: when both fix-it and learn-it tasks are selected for NOTE: tags, learn-it is created first and fix-it depends on it.

## Notes

- The `--dry-run` flag is no longer supported. The interactive flow is inherently "preview first" - users always see findings before any tasks are created.
- Git commit is performed automatically after tasks are created.
- Task numbers are assigned sequentially from state.json.
