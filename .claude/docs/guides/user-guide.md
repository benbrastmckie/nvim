# Command Workflows User Guide

[Back to Docs](../README.md) | [CLAUDE.md](../../CLAUDE.md) | [Architecture](../architecture/system-overview.md)

A comprehensive guide to using the `.claude/` task management system commands for ProofChecker development.

**Last Updated**: 2026-01-28

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Workflow Commands](#core-workflow-commands)
   - [/task](#task-command)
   - [/research](#research-command)
   - [/plan](#plan-command)
   - [/revise](#revise-command)
   - [/implement](#implement-command)
3. [Maintenance Commands](#maintenance-commands)
   - [/todo](#todo-command)
   - [/review](#review-command)
   - [/refresh](#refresh-command)
   - [/errors](#errors-command)
4. [Utility Commands](#utility-commands)
   - [/meta](#meta-command)
   - [/fix-it](#fix-it-command)
   - [/convert](#convert-command)
5. [Quick Reference](#quick-reference)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

The `.claude/` system provides structured task management for development workflows. The core cycle is:

```
/task "Description" -> /research N -> /plan N -> /implement N -> /todo
```

### Your First Workflow

1. **Create a task**:
   ```
   /task "Add documentation for the modal logic evaluator"
   ```
   Claude creates task #123 with status `[NOT STARTED]`.

2. **Research the task** (optional but recommended):
   ```
   /research 123
   ```
   Creates a research report with findings and recommendations.

3. **Create an implementation plan**:
   ```
   /plan 123
   ```
   Generates a phased plan with steps and verification criteria.

4. **Implement the plan**:
   ```
   /implement 123
   ```
   Executes each phase, creating files and verifying results.

5. **Archive completed tasks**:
   ```
   /todo
   ```
   Moves completed tasks to the archive.

### Status Progression

Tasks progress through these statuses:

| Phase | Status | After Command |
|-------|--------|---------------|
| Created | `[NOT STARTED]` | `/task` |
| Researching | `[RESEARCHING]` | `/research` (in progress) |
| Researched | `[RESEARCHED]` | `/research` (complete) |
| Planning | `[PLANNING]` | `/plan` (in progress) |
| Planned | `[PLANNED]` | `/plan` (complete) |
| Implementing | `[IMPLEMENTING]` | `/implement` (in progress) |
| Completed | `[COMPLETED]` | `/implement` (complete) |
| Archived | (moved to archive) | `/todo` |

**Exception statuses**: `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]`

---

## Core Workflow Commands

These commands form the primary task lifecycle.

### /task Command

Create and manage tasks.

#### Create a Task

```
/task "Brief description of what needs to be done"
```

**Examples**:
```
/task "Add telescope picker for recent config files"
/task "Add README documentation for the semantic evaluator"
/task "Fix type mismatch error in lsp/init.lua"
```

**Language Detection**: The system automatically detects task language from keywords:
- `neovim`, `plugin`, `keymap`, `lua`, `nvim` -> `neovim`
- `meta`, `agent`, `command`, `skill`, `.claude/` -> `meta`
- `latex`, `.tex`, `document` -> `latex`
- `typst`, `.typ` -> `typst`
- Otherwise -> `general`

#### Recover Archived Tasks

```
/task --recover N        # Recover single task
/task --recover N-M      # Recover task range
```

Moves tasks from `specs/archive/` back to active status.

#### Expand a Task

```
/task --expand N [prompt]
```

Breaks a large task into smaller subtasks. The original task gets status `[EXPANDED]`.

**Example**:
```
/task --expand 45 "Focus on separating soundness and completeness proofs"
```

#### Synchronize State

```
/task --sync
```

Reconciles `specs/TODO.md` with `specs/state.json` if they become desynchronized.

#### Abandon a Task

```
/task --abandon N        # Abandon single task
/task --abandon N-M      # Abandon task range
```

Marks tasks as `[ABANDONED]` and archives them.

#### Review Task Completion

```
/task --review N
```

Reviews a completed task and optionally creates follow-up tasks for remaining work.

---

### /research Command

Conduct research on a task and create reports.

```
/research N [focus]
```

**Arguments**:
- `N` - Task number (required)
- `focus` - Optional focus area for the research

**Examples**:
```
/research 123                          # General research
/research 123 "focus on lazy.nvim event loading patterns"
```

**Language Routing**:
- `neovim` tasks -> Uses Neovim-specific research agent
- Other tasks -> Uses web search, documentation, codebase exploration

**Output**: Creates `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md`

**Repeatable**: Yes. Run multiple times to gather additional research. Each run creates a new numbered report (001, 002, etc.).

---

### /plan Command

Create an implementation plan for a task.

```
/plan N
```

**Prerequisites**: Task should exist (ideally researched first, but not required).

**Output**: Creates `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`

**Plan Structure**:
- **Phases**: Logical groupings of related work
- **Steps**: Individual actions within each phase
- **Verification**: How to confirm each phase succeeded

**Example Plan Phases**:
```markdown
### Phase 1: Set Up Module Structure [NOT STARTED]
**Goal**: Create file structure and imports
**Steps**:
1. Create lua/neotex/plugins/new_feature.lua
2. Add required imports
**Verification**: Module loads without errors

### Phase 2: Define Helper Lemmas [NOT STARTED]
**Goal**: Prove prerequisite lemmas
...
```

---

### /revise Command

Create a new plan version or update task description.

```
/revise N [reason]
```

**Behavior depends on task status**:

| Status | Action |
|--------|--------|
| `not_started`, `researched` | Updates task description |
| `planned`, `implementing`, `partial`, `blocked` | Creates new plan version |

**Examples**:
```
/revise 123 "Need to split into smaller phases"
/revise 45   # Interactive revision
```

**Output for Plan Revision**: Creates `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md` with incremented version number.

---

### /implement Command

Execute an implementation plan.

```
/implement N [--force]
```

**Arguments**:
- `N` - Task number (required)
- `--force` - Skip confirmation prompts (optional)

**Language Routing**:
- `neovim` -> Neovim-specific implementation agent
- `latex` -> LaTeX document implementation
- `typst` -> Typst document implementation
- Other -> General file implementation

**Resume Support**: If interrupted, running `/implement N` again automatically resumes from the last incomplete phase.

**Phase Markers** (in plan file):
- `[NOT STARTED]` -> Not yet begun
- `[IN PROGRESS]` -> Currently executing
- `[COMPLETED]` -> Finished successfully
- `[PARTIAL]` -> Partially complete (interrupted)

**Output**: Creates `specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md`

---

## Maintenance Commands

Commands for system health and cleanup.

### /todo Command

Archive completed and abandoned tasks.

```
/todo [--dry-run]
```

**Arguments**:
- `--dry-run` - Show what would be archived without doing it

**Actions**:
1. Finds tasks with status `[COMPLETED]` or `[ABANDONED]`
2. Moves task directories to `specs/archive/`
3. Updates `specs/TODO.md` and `specs/state.json`
4. For non-meta tasks: Annotates `ROAD_MAP.md` with completion notes
5. For meta tasks: Displays CLAUDE.md modification suggestions for review

**Example Output**:
```
Archived 3 tasks:
- Task 120: Prove soundness theorem [COMPLETED]
- Task 121: Add frame validation [COMPLETED]
- Task 122: Old prototype code [ABANDONED]
```

---

### /review Command

Analyze codebase and create review reports.

```
/review [SCOPE] [--create-tasks]
```

**Arguments**:
- `SCOPE` - File path, directory, or "all" (default: current project)
- `--create-tasks` - Create tasks for identified issues

**Analysis includes**:
- TODOs, FIXMEs, and code smells
- For Neovim: deprecated APIs, missing lazy-loading, keymap descriptions
- Roadmap progress tracking
- Documentation coverage

**Example**:
```
/review lua/neotex/plugins/     # Review plugins directory
/review --create-tasks          # Review all and create tasks for issues
```

---

### /refresh Command

Clean Claude Code resources.

```
/refresh [--dry-run] [--force]
```

**Arguments**:
- `--dry-run` - Show what would be cleaned without doing it
- `--force` - Skip confirmation prompts

**Actions**:
1. Terminates orphaned processes
2. Cleans old files in `~/.claude/` directories
3. Interactive age threshold selection:
   - 8 hours (recent files)
   - 2 days (older files)
   - Clean slate (all non-essential files)

---

---

### /errors Command

Analyze error patterns and create fix plans.

```
/errors [--fix N]
```

**Arguments**:
- `--fix N` - Fix specific error by ID

**Actions**:
1. Reads `specs/errors.json`
2. Groups errors by type, severity, recurrence
3. Creates analysis report in `specs/errors/`
4. Optionally fixes specific errors

**Example**:
```
/errors                   # Analyze all errors
/errors --fix err_12345   # Fix specific error
```

---

## Utility Commands

Specialized utilities for specific tasks.

### /meta Command

Interactive system builder for `.claude/` changes.

```
/meta [PROMPT] | --analyze
```

**Modes**:

| Mode | Syntax | Description |
|------|--------|-------------|
| Interactive | `/meta` | 7-stage interview process |
| Prompt | `/meta "Add a /debug command"` | Abbreviated flow for direct requests |
| Analyze | `/meta --analyze` | Read-only system analysis |

**Important**: `/meta` creates TASKS for system changes; it never implements directly. After running `/meta`, use the normal workflow (`/plan`, `/implement`) to make the changes.

**Example**:
```
/meta "Add support for Typst document compilation"
```

Creates tasks like:
- Task 200: Create typst-implementation-agent
- Task 201: Add /typst command
- Task 202: Update language routing

---

### /fix-it Command

Scan for FIX:/NOTE:/TODO: tags and create tasks.

```
/fix-it [PATH...]
```

**Arguments**:
- `PATH...` - Optional paths to scan (default: entire project)

**Interactive Flow**:
1. Scans files for tags (`FIX:`, `NOTE:`, `TODO:`)
2. Displays tag summary with counts
3. Prompts for task type selection
4. Optional: Select specific TODOs to process
5. Optional: Group TODOs by topic
6. Creates selected tasks

**Tag Types**:

| Tag | Task Type | Behavior |
|-----|-----------|----------|
| `FIX:` | fix-it-task | Grouped into single task |
| `NOTE:` | fix-it-task + learn-it-task | Creates task with dependency |
| `TODO:` | todo-task | Individual or grouped by topic |

**Example**:
```
/fix-it                          # Scan entire project
/fix-it Theories/Modal/          # Scan specific directory
```

---

### /convert Command

Convert documents between formats.

```
/convert SOURCE_PATH [OUTPUT_PATH]
```

**Supported Conversions**:

| From | To |
|------|-----|
| PDF, DOCX, XLSX, PPTX, HTML | Markdown |
| Markdown | PDF |

**Tools Used**: markitdown, pandoc, typst

**Examples**:
```
/convert paper.pdf                    # PDF -> Markdown (auto output name)
/convert paper.pdf notes.md           # PDF -> Markdown (custom output)
/convert README.md README.pdf         # Markdown -> PDF
```

---

## Quick Reference

### Command Summary Table

| Command | Syntax | Description |
|---------|--------|-------------|
| `/task` | `/task "Description"` | Create new task |
| `/task` | `/task --recover N` | Recover archived task |
| `/task` | `/task --expand N [prompt]` | Break into subtasks |
| `/task` | `/task --sync` | Synchronize state files |
| `/task` | `/task --abandon N` | Archive as abandoned |
| `/task` | `/task --review N` | Review completion |
| `/research` | `/research N [focus]` | Research task |
| `/plan` | `/plan N` | Create implementation plan |
| `/revise` | `/revise N [reason]` | Revise plan or description |
| `/implement` | `/implement N [--force]` | Execute plan |
| `/todo` | `/todo [--dry-run]` | Archive completed tasks |
| `/review` | `/review [SCOPE] [--create-tasks]` | Analyze codebase |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean resources |
| `/errors` | `/errors [--fix N]` | Analyze errors |
| `/meta` | `/meta [PROMPT] \| --analyze` | System builder |
| `/fix-it` | `/fix-it [PATH...]` | Extract tags to tasks |
| `/convert` | `/convert SOURCE [OUTPUT]` | Convert documents |

### Status Transitions

```
[NOT STARTED] --/research--> [RESEARCHING] --> [RESEARCHED]
                                                    |
                                        --/plan--> [PLANNING] --> [PLANNED]
                                                                     |
                                                     --/implement--> [IMPLEMENTING] --> [COMPLETED]
                                                                                            |
                                                                              --/todo--> (archived)
```

**Exception Transitions**:
- Any status -> `[BLOCKED]` (with reason)
- Any status -> `[ABANDONED]` (via `/task --abandon`)
- `[NOT STARTED]` -> `[EXPANDED]` (via `/task --expand`)
- `[IMPLEMENTING]` -> `[PARTIAL]` (on timeout/error)

### Language Routing

| Language | Detection Keywords | Research Tools | Implementation |
|----------|-------------------|----------------|----------------|
| `neovim` | neovim, plugin, keymap, lua, nvim | WebSearch, WebFetch, Read | nvim --headless, Write, Edit |
| `meta` | agent, command, skill, .claude/ | Read, Grep, Glob | Write, Edit |
| `latex` | latex, .tex, document | WebSearch, Read | pdflatex |
| `typst` | typst, .typ | WebSearch, Read | typst compile |
| `markdown` | docs, readme, documentation | WebSearch, Read | Write, Edit |
| `general` | (default) | WebSearch, Read | Write, Edit, Bash |

---

## Troubleshooting

### Common Issues

#### Task Not Found

**Symptom**: "Task N not found" error

**Solutions**:
1. Check task exists: Look in `specs/TODO.md`
2. Check if archived: Look in `specs/archive/`
3. Recover if needed: `/task --recover N`
4. Sync state: `/task --sync`

#### Implementation Won't Start

**Symptom**: `/implement` fails to begin

**Solutions**:
1. Verify task is planned: Status should be `[PLANNED]`
2. Check for missing plan: Run `/plan N` first
3. Check plan file exists: `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`

#### Stuck in Implementing Status

**Symptom**: Task remains `[IMPLEMENTING]` after errors

**Solutions**:
1. Run `/implement N` again to resume
2. Check plan for `[PARTIAL]` phase markers
3. Review errors: `/errors`
4. If truly stuck, manually edit plan to mark phases `[COMPLETED]`

#### State Desynchronization

**Symptom**: TODO.md and state.json show different information

**Solutions**:
1. Run `/task --sync` to reconcile
2. Git shows which file was updated more recently
3. In extreme cases, one file can be regenerated from the other

#### Tools Not Responding

**Symptom**: Tools timeout or fail

**Solutions**:
1. Verify Neovim configuration loads: `nvim --headless -c "q"`
2. Check MCP configuration in `~/.claude.json`
3. Run `/refresh` to clean orphaned processes
4. Restart Claude Code session

### Getting Help

- **Architecture docs**: See [system-overview.md](../architecture/system-overview.md)
- **Command details**: Check individual command files in `.claude/commands/`
- **Examples**: See [examples/](../examples/) for workflow walkthroughs
- **CLAUDE.md**: Quick reference at [../../CLAUDE.md](../../CLAUDE.md)

---

[Back to Docs](../README.md) | [CLAUDE.md](../../CLAUDE.md) | [Architecture](../architecture/system-overview.md)
