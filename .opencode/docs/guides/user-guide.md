# Command Workflows User Guide

[Back to Docs](../README.md) | [README.md](../../README.md) | [Architecture](../architecture/system-overview.md)

A comprehensive guide to using the `.opencode/` task management system commands for Logos/Theory development.

**Last Updated**: 2026-02-28

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
   - [/lake](#lake-command)
   - [/errors](#errors-command)
4. [Utility Commands](#utility-commands)
   - [/meta](#meta-command)
    - [/fix-it](#fix-it-command)
5. [Quick Reference](#quick-reference)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

The `.opencode/` system provides structured task management for development workflows. The core cycle is:

```
/task "Description" -> /research OC_N -> /plan OC_N -> /implement OC_N -> /todo
```

### Your First Workflow

1. **Create a task**:
   ```
   /task "Add documentation for the modal logic evaluator"
   ```
   Creates task OC_123 with status `[NOT STARTED]`.

2. **Research the task** (optional but recommended):
   ```
   /research OC_123
   ```
   Creates a research report with findings and recommendations.

3. **Create an implementation plan**:
   ```
   /plan OC_123
   ```
   Generates a phased plan with steps and verification criteria.

4. **Implement the plan**:
   ```
   /implement OC_123
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
/task "Prove completeness theorem for K modal logic"
/task "Add README documentation for the semantic evaluator"
/task "Fix type mismatch error in Frame.lean"
```

**Language Detection**: The system automatically detects task language from keywords:
- `lean`, `theorem`, `proof`, `lemma`, `Mathlib` -> `lean`
- `meta`, `agent`, `command`, `skill`, `.opencode/` -> `meta`
- `typst`, `.typ` -> `typst`
- `latex`, `.tex` -> `latex`
- Otherwise -> `general`

#### Recover Archived Tasks

```
/task --recover OC_N        # Recover single task
/task --recover OC_N-M      # Recover task range
```

Moves tasks from archive back to active status.

#### Expand a Task

```
/task --expand OC_N [prompt]
```

Breaks a large task into smaller subtasks. The original task gets status `[EXPANDED]`.

**Example**:
```
/task --expand OC_45 "Focus on separating soundness and completeness proofs"
```

#### Synchronize State

```
/task --sync
```

Reconciles `specs/TODO.md` with `specs/state.json` if they become desynchronized.

#### Abandon a Task

```
/task --abandon OC_N        # Abandon single task
/task --abandon OC_N-M      # Abandon task range
```

Marks tasks as `[ABANDONED]` and archives them.

---

### /research Command

Conduct research on a task and create reports.

```
/research OC_N [focus]
```

**Arguments**:
- `OC_N` - Task number (required)
- `focus` - Optional focus area for the research

**Examples**:
```
/research OC_123                          # General research
/research OC_123 "focus on Mathlib lemmas for decidability"
```

**Language Routing**:
- `lean` tasks -> Uses Lean MCP tools (leansearch, loogle, leanfinder)
- Other tasks -> Uses web search, documentation, codebase exploration

**Output**: Creates `specs/OC_NNN_{SLUG}/reports/research-NNN.md`

**Repeatable**: Yes. Run multiple times to gather additional research. Each run creates a new numbered report (001, 002, etc.).

---

### /plan Command

Create an implementation plan for a task.

```
/plan OC_N
```

**Prerequisites**: Task should exist (ideally researched first, but not required).

**Output**: Creates `specs/OC_NNN_{SLUG}/plans/implementation-NNN.md`

**Plan Structure**:
- **Phases**: Logical groupings of related work
- **Steps**: Individual actions within each phase
- **Verification**: How to confirm each phase succeeded

**Example Plan Phases**:
```markdown
### Phase 1: Set Up Module Structure [NOT STARTED]
**Goal**: Create file structure and imports
**Steps**:
1. Create Theories/Modal/Completeness.lean
2. Add required imports
**Verification**: File compiles without errors

### Phase 2: Define Helper Lemmas [NOT STARTED]
**Goal**: Prove prerequisite lemmas
...
```

---

### /revise Command

Create a new plan version or update task description.

```
/revise OC_N [reason]
```

**Behavior depends on task status**:

| Status | Action |
|--------|--------|
| `not_started`, `researched` | Updates task description |
| `planned`, `implementing`, `partial`, `blocked` | Creates new plan version |

**Examples**:
```
/revise OC_123 "Need to split into smaller phases"
/revise OC_45   # Interactive revision
```

**Output for Plan Revision**: Creates `specs/OC_NNN_{SLUG}/plans/implementation-NNN.md` with incremented version number.

---

### /implement Command

Execute an implementation plan.

```
/implement OC_N [--force]
```

**Arguments**:
- `OC_N` - Task number (required)
- `--force` - Skip confirmation prompts (optional)

**Language Routing**:
- `lean` -> Lean-specific implementation with MCP tools
- `latex` -> LaTeX document implementation
- `typst` -> Typst document implementation
- Other -> General file implementation

**Resume Support**: If interrupted, running `/implement OC_N` again automatically resumes from the last incomplete phase.

**Phase Markers** (in plan file):
- `[NOT STARTED]` -> Not yet begun
- `[IN PROGRESS]` -> Currently executing
- `[COMPLETED]` -> Finished successfully
- `[PARTIAL]` -> Partially complete (interrupted)

**Output**: Creates `specs/OC_NNN_{SLUG}/summaries/implementation-summary-{DATE}.md`

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
4. For non-meta tasks: Annotates `ROADMAP.md` with completion notes
5. For meta tasks: Displays suggestions for review

**Example Output**:
```
Archived 3 tasks:
- Task OC_120: Prove soundness theorem [COMPLETED]
- Task OC_121: Add frame validation [COMPLETED]
- Task OC_122: Old prototype code [ABANDONED]
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
- For Lean: `sorry` placeholders, axioms, build status
- Roadmap progress tracking
- Documentation coverage

**Example**:
```
/review Theories/Modal/         # Review modal logic directory
/review --create-tasks          # Review all and create tasks for issues
```

---

### /refresh Command

Clean resources.

```
/refresh [--dry-run] [--force]
```

**Arguments**:
- `--dry-run` - Show what would be cleaned without doing it
- `--force` - Skip confirmation prompts

**Actions**:
1. Terminates orphaned processes
2. Cleans old files
3. Interactive age threshold selection

---

### /lake Command

Run Lean build with automatic error repair.

```
/lake [--clean] [--max-retries N] [--dry-run] [--module NAME]
```

**Arguments**:
- `--clean` - Run `lake clean` before building
- `--max-retries N` - Maximum repair iterations (default: 5)
- `--dry-run` - Show what would be fixed without doing it
- `--module NAME` - Build specific module only

**Auto-Fixable Errors**:

| Error Type | Automatic Fix |
|------------|---------------|
| Missing pattern match cases | Add `| {case} => sorry` branches |
| Unused variables | Rename to `_{name}` |
| Unused imports | Remove import line |

**For Unfixable Errors**: Creates tasks with error reports for manual resolution.

**Example**:
```
/lake                     # Build and auto-repair
/lake --clean             # Clean build
/lake --max-retries 10    # More repair iterations
```

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

Interactive system builder for `.opencode/` changes.

```
/meta [PROMPT] | --analyze
```

**Modes**:

| Mode | Syntax | Description |
|------|--------|-------------|
| Interactive | `/meta` | Multi-stage interview process |
| Prompt | `/meta "Add a /debug command"` | Abbreviated flow for direct requests |
| Analyze | `/meta --analyze` | Read-only system analysis |

**Important**: `/meta` creates TASKS for system changes; it never implements directly. After running `/meta`, use the normal workflow (`/plan`, `/implement`) to make the changes.

**Example**:
```
/meta "Add support for Typst document compilation"
```

Creates tasks like:
- Task OC_200: Create typst-implementation-agent
- Task OC_201: Add /typst command
- Task OC_202: Update language routing

---

### /fix-it Command

Scan for FIX:/NOTE:/TODO:/QUESTION: tags and create tasks.

```
/fix-it [PATH...]
```

**Arguments**:
- `PATH...` - Optional paths to scan (default: entire project)

**Interactive Flow**:
1. Scans files for tags (`FIX:`, `NOTE:`, `TODO:`, `QUESTION:`)
2. Displays tag summary with counts
3. Prompts for task type selection
4. Optional: Select specific TODOs/QUESTIONs to process
5. Optional: Group items by topic
6. Creates selected tasks

**Tag Types**:

| Tag | Task Type | Behavior |
|-----|-----------|----------|
| `FIX:` | fix-it-task | Grouped into single task |
| `NOTE:` | fix-it-task + learn-it-task | Creates task with dependency |
| `TODO:` | todo-task | Individual or grouped by topic |
| `QUESTION:` | research-task | Content-based language detection |

**Example**:
```
/fix-it                           # Scan entire project
/fix-it src/                      # Scan specific directory
/fix-it src/core.lua src/utils/   # Scan multiple paths
```

**Migration Note**: This command was previously `/fix`. It has been renamed to `/fix-it` to align with the .claude/ system.

---

## Quick Reference

### Command Summary Table

| Command | Syntax | Description |
|---------|--------|-------------|
| `/task` | `/task "Description"` | Create new task |
| `/task` | `/task --recover OC_N` | Recover archived task |
| `/task` | `/task --expand OC_N [prompt]` | Break into subtasks |
| `/task` | `/task --sync` | Synchronize state files |
| `/task` | `/task --abandon OC_N` | Archive as abandoned |
| `/research` | `/research OC_N [focus]` | Research task |
| `/plan` | `/plan OC_N` | Create implementation plan |
| `/revise` | `/revise OC_N [reason]` | Revise plan or description |
| `/implement` | `/implement OC_N [--force]` | Execute plan |
| `/todo` | `/todo [--dry-run]` | Archive completed tasks |
| `/review` | `/review [SCOPE] [--create-tasks]` | Analyze codebase |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean resources |
| `/lake` | `/lake [--clean] [--max-retries N]` | Build with repair |
| `/errors` | `/errors [--fix N]` | Analyze errors |
| `/meta` | `/meta [PROMPT] \| --analyze` | System builder |
| `/fix-it` | `/fix-it [PATH...]` | Extract tags to tasks |

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
| `lean` | theorem, proof, lemma, Mathlib | lean_leansearch, lean_loogle | lean_goal, lean_multi_attempt |
| `meta` | agent, command, skill, .opencode/ | Read, Grep, Glob | Write, Edit |
| `latex` | latex, .tex, document | WebSearch, Read | pdflatex |
| `typst` | typst, .typ | WebSearch, Read | typst compile |
| `general` | (default) | WebSearch, Read | Write, Edit, Bash |

---

## Optional Integrations

### TTS (Text-to-Speech) Notifications

OpenCode supports optional TTS notifications that announce when workflow commands complete. This helps you track task progress when working across multiple terminal tabs.

**Features**:
- Announces task completion: "Task 184 research complete"
- Announces tab activity: "Tab 2: Task 184 complete"
- Configurable cooldown to prevent spam
- Graceful degradation when dependencies not installed

**Requirements**:
- [Piper TTS](https://github.com/rhasspy/piper) - Neural text-to-speech engine
- `aplay` (ALSA) or `paplay` (PulseAudio) - Audio playback
- Optional: [WezTerm](https://wezfurlong.org/wezterm/) - For tab-aware announcements

**Installation** (NixOS):
```nix
environment.systemPackages = with pkgs; [
  piper-tts
  alsa-utils  # for aplay
  pulseaudio  # for paplay (optional)
];
```

**Configuration**:
| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_TTS_ENABLED` | `1` | Enable/disable TTS notifications |
| `PIPER_MODEL` | `~/.local/share/piper/en_US-lessac-medium.onnx` | Path to voice model |
| `TTS_COOLDOWN` | `10` | Seconds between notifications |

**Setup**:
1. Download a Piper voice model:
   ```bash
   mkdir -p ~/.local/share/piper
   cd ~/.local/share/piper
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
   ```

2. Test the setup:
   ```bash
   echo "Task 1 complete" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | aplay
   ```

3. TTS notifications trigger automatically on workflow command completion

**Disable TTS**:
```bash
export OPENCODE_TTS_ENABLED=0
```

For more details, see the full [TTS/STT Integration Guide](tts-stt-integration.md).

---

## Troubleshooting

### Common Issues

#### Task Not Found

**Symptom**: "Task OC_N not found" error

**Solutions**:
1. Check task exists: Look in `specs/TODO.md`
2. Check if archived: Look in `specs/archive/`
3. Recover if needed: `/task --recover OC_N`
4. Sync state: `/task --sync`

#### Implementation Won't Start

**Symptom**: `/implement` fails to begin

**Solutions**:
1. Verify task is planned: Status should be `[PLANNED]`
2. Check for missing plan: Run `/plan OC_N` first
3. Check plan file exists: `specs/OC_NNN_{SLUG}/plans/implementation-001.md`

#### Stuck in Implementing Status

**Symptom**: Task remains `[IMPLEMENTING]` after errors

**Solutions**:
1. Run `/implement OC_N` again to resume
2. Check plan for `[PARTIAL]` phase markers
3. Review errors: `/errors`
4. If truly stuck, manually edit plan to mark phases `[COMPLETED]`

#### State Desynchronization

**Symptom**: TODO.md and state.json show different information

**Solutions**:
1. Run `/task --sync` to reconcile
2. Git shows which file was updated more recently
3. In extreme cases, one file can be regenerated from the other

#### Build Errors Not Auto-Fixed

**Symptom**: `/lake` keeps failing on same errors

**Solutions**:
1. Some errors require manual fixes (type mismatches, logic errors)
2. Check created tasks for unfixable errors
3. Use `/errors` to analyze patterns
4. Increase retries: `/lake --max-retries 10`

#### MCP Tools Not Responding

**Symptom**: Lean tools timeout or fail

**Solutions**:
1. Verify Lean project builds: `lake build`
2. Check MCP configuration in `~/.opencode.json`
3. Run `/refresh` to clean orphaned processes
4. Restart opencode session

### Getting Help

- **Architecture docs**: See [system-overview.md](../architecture/system-overview.md)
- **Command details**: Check individual command files in `.opencode/commands/`
- **README.md**: Quick reference at [../../README.md](../../README.md)

---

[Back to Docs](../README.md) | [README.md](../../README.md) | [Architecture](../architecture/system-overview.md)
