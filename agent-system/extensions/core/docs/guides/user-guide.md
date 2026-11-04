# Command Workflows User Guide

[Back to Docs](../docs-README.md) | [CLAUDE.md](../../CLAUDE.md) | [Architecture](../architecture/system-overview.md)

A comprehensive guide to using the `.claude/` task management system commands for project development.

**Last Updated**: 2026-11-04

---

## Table of Contents

1. [Quick Start](#quick-start)
   - [Your First Workflow](#your-first-workflow)
   - [Reviewing Research and the Plan Before Implementation](#reviewing-research-and-the-plan-before-implementation)
   - [Status Progression](#status-progression)
2. [Core Workflow Commands](#core-workflow-commands)
   - [/task](#task-command)
   - [/project-overview](#project-overview-command)
   - [/revise](#revise-command)
3. [Maintenance Commands](#maintenance-commands)
   - [/todo](#todo-command)
   - [/review](#review-command)
   - [/refresh](#refresh-command)
   - [/errors](#errors-command)
4. [Automation Commands](#automation-commands)
   - [/orchestrate](#orchestrate-command)
   - [/spawn](#spawn-command)
   - [/merge](#merge-command)
   - [/please](#please-command) (user-only)
5. [Utility Commands](#utility-commands)
   - [/meta](#meta-command)
   - [/fix-it](#fix-it-command)
   - [/zulip](#zulip-command)
   - [/convert](#convert-command) (requires `filetypes` extension)
6. [Extensions](#extensions)
7. [Quick Reference](#quick-reference)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

The `.claude/` system provides structured task management for development workflows. The core
cycle drives a task through its full lifecycle autonomously, with `/orchestrate` as the sole
lifecycle driver:

```
/task "Description" -> /orchestrate N -> /todo
```

### Your First Workflow

1. **Create a task**:
   ```
   /task "Add documentation for the modal logic evaluator"
   ```
   Claude creates task #{N} with status `[NOT STARTED]`.

2. **Drive it through its full lifecycle**:
   ```
   /orchestrate N
   ```
   Runs research -> plan -> implement automatically as a state machine, with no confirmation
   gates between phases, and reports the final status.

3. **Archive completed tasks**:
   ```
   /todo
   ```
   Moves completed tasks to the archive.

### Reviewing Research and the Plan Before Implementation

The fully autonomous cycle above is the default, but a reader who wants to inspect the research
report and the plan before any implementation work lands can drive the same task through the
same lifecycle one phase at a time, using `/orchestrate`'s phase-forcing flags (covered in full
under [/orchestrate Command](#orchestrate-command)) together with `/revise`:

1. **Create a task**:
   ```
   /task "Add documentation for the modal logic evaluator"
   ```

2. **Force a research round and stop**:
   ```
   /orchestrate N --research
   ```
   Creates a research report; task reaches `[RESEARCHED]`. Review the report.

3. **Force a plan round and stop**:
   ```
   /orchestrate N --plan
   ```
   Generates a phased plan with steps and verification criteria; task reaches `[PLANNED]`.
   Review the plan.

4. **Adjust the plan if needed**:
   ```
   /revise N "Need to split into smaller phases"
   ```
   Creates a new plan version without re-running research.

5. **Force the implement round**:
   ```
   /orchestrate N --implement
   ```
   Executes each phase, creating files and verifying results; task reaches `[COMPLETED]`.

6. **Archive completed tasks**:
   ```
   /todo
   ```

### Status Progression

Tasks progress through these statuses:

| Phase | Status | After Command |
|-------|--------|---------------|
| Created | `[NOT STARTED]` | `/task` |
| Researching | `[RESEARCHING]` | `/orchestrate` (research round in progress) |
| Researched | `[RESEARCHED]` | `/orchestrate` (research round complete) |
| Planning | `[PLANNING]` | `/orchestrate` (plan round in progress) |
| Planned | `[PLANNED]` | `/orchestrate` (plan round complete) |
| Implementing | `[IMPLEMENTING]` | `/orchestrate` (implement round in progress) |
| Completed | `[COMPLETED]` | `/orchestrate` (implement round complete) |
| Held | `[HOLD]` | Operator-set pause; not resumed by ordinary `/orchestrate N`. Lifted by an explicit `/orchestrate N --research\|--plan\|--implement` (admits the task for one dispatch; the hold itself persists afterward) or by an operator-run unhold |
| PR Ready (`task_type: pr` only) | `[PR READY]` | `/orchestrate` (implementation complete, awaiting `/merge`) |
| Archived | (moved to archive) | `/todo` |

**Exception statuses**: `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]`

---

## Core Workflow Commands

`/task` creates work and `/revise` adjusts a plan or description; the lifecycle itself (research,
planning, implementation) is driven by [/orchestrate](#orchestrate-command), covered in full
under Automation Commands below.

### /task Command

Create and manage tasks.

#### Create a Task

```
/task "Brief description of what needs to be done"
```

**Examples**:
```
/task "Add search functionality for recent project files"
/task "Add README documentation for the API module"
/task "Fix type mismatch error in src/config.py"
```

**Language Detection**: The system automatically detects task language from keywords:
- `meta`, `agent`, `command`, `skill`, `.claude/` -> `meta`
- Extension-specific keywords -> extension task type (when loaded)
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

### /project-overview Command

Interactively analyze the repository and create a task to generate `project-overview.md`.

```
/project-overview
```

**Behavior**: Scans the repository (languages, frameworks, build tools, testing, CI/CD, key
files), interviews the user to verify findings and gather project purpose/workflow details, then
creates a task in `[RESEARCHED]` status with a research artifact containing all findings. Drive
that task through `/orchestrate` (forced with `--plan` then `--implement`, or a bare
`/orchestrate N`) to generate the actual `project-overview.md` file.

**When to use**:
- First time setting up the agent system in a new repository
- When `project-overview.md` still contains the generic template placeholder
- When the project structure has changed significantly and the overview needs regeneration

**Example**:
```
/project-overview
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
5. For meta tasks: Displays CLAUDE.md modification suggestions for review

**Example Output**:
```
Archived 3 tasks:
- Task {N}: Prove soundness theorem [COMPLETED]
- Task {N}: Add frame validation [COMPLETED]
- Task {N}: Old prototype code [ABANDONED]
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
- For extensions: domain-specific checks (when loaded)
- Roadmap progress tracking
- Documentation coverage

**Example**:
```
/review src/modules/            # Review modules directory
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

## Automation Commands

Commands for autonomous task execution, blocker resolution, and repository management.

### /orchestrate Command

Drive one or more tasks autonomously through their full lifecycle without user confirmation
between phases. This is the sole lifecycle driver in this system.

```
/orchestrate TASK_NUMBERS [PROMPT] [flags...]
```

**Arguments**:
- `TASK_NUMBERS` - Task number(s) (required). Supports single task, comma-separated lists, and
  ranges, mixed freely:
  - Single: `/orchestrate 42`
  - Comma-separated: `/orchestrate 42,43,45`
  - Range: `/orchestrate 42-45`
  - Mixed: `/orchestrate 42,44-46,50`
- `PROMPT` - Optional focus text (e.g. `/orchestrate 42 "focus on the LSP config"`), applied to
  every task in a multi-task batch.

**Behavior**: Runs the complete lifecycle (research -> plan -> implement -> complete) as a state
machine, advancing through each phase automatically with no confirmation gates between stages.
A batch of one task is not a special case — it is the same dependency-aware wave dispatch
mechanism running with one task in it.

#### Batching Is the Default

Batching related open tasks into one `/orchestrate` invocation is the normal way to work this
system, not a throughput-only optimization — even a batch that serializes to width 1 gains
collision visibility a separate invocation cannot provide. Shared file territory is a reason to
batch together, never to run separately, even when that collapses the batch to one task at a
time: if two open tasks have an unordered overlap on the same files, add the dependency edge
(`update-task-status.sh --depends-on-add`) and run them as a sequence in one invocation, rather
than recording the overlap as a bare exclusion. A single-task invocation remains fully correct
and unpenalized. See `context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the
Default" section for the full selection criteria and dominance rule.

**Batch size cap**: at most 8 tasks per invocation (`MAX_TASKS=8`); a larger request is trimmed
to the first 8 with a warning.

#### Options

The most commonly used flags:

| Flag | Description | Default |
|------|-------------|---------|
| `--research` / `--plan` / `--implement` | Force that phase round, composable in this canonical order; `--implement` requires a plan artifact to exist | false |
| `--hard` | High-effort mode: injects hard-mode behavioral contracts; roughly 3-5x cost | false |
| `--fast` | Low-effort mode: lighter reasoning, skips the default research-first phase for a `not_started` task | false |
| `--dry-run` | Report-only: print the admission verdict for every task and dispatch nothing | false |

For the complete, current flag set (model-selection flags, `--lit`, `--clean`, `--compare`,
`--gate`, and the opt-in admission-gate bypasses) see
[`/orchestrate`'s own Options section](../../commands/orchestrate.md#options) — the authority for
this command's full flag/option semantics, since Claude Code loads that file directly as the
command's own instructions.

**Canonical composition order**: `--research`, `--plan`, `--implement` compose — each named flag
queues that phase, consumed in that order over however many cycles it takes. A task stops (never
falls through to ordinary status-derived classification) once its own forced sequence is
exhausted for the rest of that run; re-invoke `/orchestrate` to continue. Admission is
artifact-keyed, not status-keyed, not a simple recomputation of the task's current status.

**A failed task never blocks siblings in its own wave, but DOES block dependents in later
waves.**

#### Forcing a Single Phase

Pass `--research`, `--plan`, or `--implement` to force exactly that phase and stop, instead of
letting the task run through the rest of its lifecycle. This is what the stepwise review
walkthrough in [Reviewing Research and the Plan Before Implementation](#reviewing-research-and-the-plan-before-implementation)
uses.

**`--research`**:
```
/orchestrate N --research
```
Creates a research report and stops. **Output**: `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md`.
Repeatable: run again to gather additional research; each run creates a new numbered report.

**`--plan`**:
```
/orchestrate N --plan
```
Creates (or, if a plan already exists, revises) a phased implementation plan and stops.
**Output**: `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`.

**Plan Structure**:
- **Phases**: Logical groupings of related work
- **Steps**: Individual actions within each phase
- **Verification Tier**: How broadly verification must run *during* the phase -- one of `prose`,
  `local`, `interface`, `full` (strictest); see `context/formats/plan-format.md`'s
  `## Verification Tiers` section for the full vocabulary. This does not replace or weaken the
  final gate, which still runs before a phase closes and before the task completes.
- **Verification**: How to confirm each phase succeeded

**Example Plan Phases**:
```markdown
### Phase 1: Set Up Module Structure [NOT STARTED]
**Goal**: Create file structure and imports
**Steps**:
1. Create src/modules/new_feature.py
2. Add required imports
**Verification Tier**: local
**Verification**: Module loads without errors

### Phase 2: Define Helper Lemmas [NOT STARTED]
**Goal**: Prove prerequisite lemmas
...
```

**`--implement`**:
```
/orchestrate N --implement
```
Executes each plan phase, creating files and verifying results, and stops. Admitted only when a
plan artifact already exists; with no plan, the task is excluded with "no plan artifact; run
--plan first". **Output**: `specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md`.

**Resume Support**: If interrupted, re-running `/orchestrate N --implement` (or a bare
`/orchestrate N`) automatically resumes from the last incomplete phase.

**Phase Markers** (in plan file):
- `[NOT STARTED]` -> Not yet begun
- `[IN PROGRESS]` -> Currently executing
- `[COMPLETED]` -> Finished successfully
- `[COMPLETED WITH EXCLUSIONS]` -> Finished with a recorded, reasoned exclusion
- `[PARTIAL]` -> Partially complete (interrupted)
- `[BLOCKED]` -> Blocked on a dependency or issue

#### Forced Phases on a Terminal or Archived Task

Ordinarily `--research`/`--plan`/`--implement` matter only for a task still progressing through
its lifecycle. On a TERMINAL task (`[COMPLETED]`, `[ABANDONED]`, `[EXPANDED]`) -- including one
already archived by `/todo` -- an explicit forcing flag still admits it for exactly one more
round; the round's artifacts land next to the task's existing reports and plans (in the archive
directory, if archived), and the task's status is never regressed (`completed` stays
`completed`, etc.). Without an explicit forcing flag, a fully terminal batch dispatches nothing.

#### `[HOLD]` and `[PR READY]`

`[HOLD]` is an operator-set pause: non-terminal, but **not resumed by a bare `/orchestrate N`**.
An explicit `/orchestrate N --research|--plan|--implement` CAN admit a held task for exactly one
dispatch -- the human typing the forcing flag **is** the act of lifting the hold for that one
round -- and the hold itself is preserved afterward (the task returns to `[HOLD]` once that
round completes). An operator can also lift it permanently via `update-task-status.sh preflight
... unhold`, which restores the exact prior status.

`[PR READY]` is reachable only for `task_type: pr`: implementation is complete and a PR is
awaiting a user-invoked `/merge` to submit it. A bare `/orchestrate N` on a `[PR READY]` task
does not push or open a PR itself -- only `/merge`, invoked directly by the user, does that.

#### Cycle Budgets

Each invocation gets a fresh, per-run work-cycle budget -- `cycle_count` resets to 0 at the
start of every `/orchestrate` call and is never cumulative across runs:
- **Single or multi-task batch**: `MAX_CYCLES_MT = min(task_count * 5, 25)`.
- **Under `--hard`**: the budget is multiplied roughly 2.6x (`MAX_CYCLES` x 2.6 ~= 13 for a
  single task).
- **Infra-failure cap**: up to `MAX_INFRA_FAILURES = 3` corroborated Agent-tool transport/API
  failures per task are tolerated (charged separately from the work-cycle budget) before that
  task falls back to `failed`.

**On reaching the cap**: the task is left `[PARTIAL]`. Re-invoke `/orchestrate N` (a fresh run,
hence a fresh budget) to continue -- there is no override flag to continue past an exhausted
per-run budget.

#### Resumption

Re-running `/orchestrate N` after an interruption, a cycle-budget exit, or a `[PARTIAL]`/
`[BLOCKED]` status resumes from the last successful state -- no special resume flag is needed.
A task stranded in `[RESEARCHING]`/`[PLANNING]` by a dead prior session's stale lock is
re-classified and re-dispatched exactly like any other non-terminal status.

#### When to Use

- Well-defined tasks where you trust the agent to make research, planning, and implementation
  decisions end to end
- Tasks where you want hands-off execution
- Driving several related, already-created tasks through their lifecycle together (batching)

#### When NOT to Use a Bare Invocation

- When you want to review the research report and the plan before implementation lands -- use
  the forcing flags and the stepwise walkthrough in
  [Reviewing Research and the Plan Before Implementation](#reviewing-research-and-the-plan-before-implementation)
  instead of avoiding `/orchestrate` altogether; it is the same driver either way, just invoked
  one phase at a time

**Example**:
```
/orchestrate 123                      # Runs research -> plan -> implement automatically
/orchestrate 42,44-46 --hard --opus   # Batches four tasks under hard mode and Opus
```

---

### /spawn Command

Analyze blockers and spawn new tasks to overcome them.

```
/spawn N [blocker description]
```

**Arguments**:
- `N` - Blocked task number (required)
- `blocker description` - Optional description of what is blocking the task

**Behavior**: Analyzes the blocked task, identifies what is preventing progress, and creates minimal new tasks to resolve the blocker. The new tasks are added as dependencies of the blocked task.

**Example**:
```
/spawn 45 "Missing type definitions for the API module"
```

Creates new tasks (e.g., Task {N}: "Create API type definitions") and updates the source task's dependencies.

---

### /merge Command

Create a pull request or merge request for the current branch.

```
/merge
```

**Behavior**: Analyzes the current branch's changes relative to the main branch and creates a GitHub PR (or GitLab MR) with an auto-generated title and description. Uses `gh pr create` for GitHub repositories.

**Prerequisites**: The current branch must have commits ahead of the main branch. A GitHub remote must be configured.

**Example**:
```
/merge    # Creates a PR for the current branch
```

---

### /please Command

Authorize exactly one otherwise-blocked git action for this single invocation. **User-only**:
agents MUST NOT invoke this command.

```
/please push <remote> <branch>
/please push <branch> to <remote>
/please push tag <name> to <remote>
/please <push form> --force-with-lease
```

**Behavior**: Typing `/please ...` proves to the system that a human submitted this prompt,
which mints a single-use, HMAC-signed grant bound to the exact action, remote/branch (or tag),
commit SHA, and force-or-not. The command then confirms with the user and runs the one
sanctioned action that consumes that grant -- never a bare `git push`. The same grant mechanism
also covers otherwise-blocked destructive git forms (`git reset --hard`, `git clean -fd`,
`git stash drop`/`clear`, a foreign `git stash pop`/`apply`), substituting the literal command
for the push wrapper.

**Example**:
```
/please push origin feature-x
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

**Important**: `/meta` creates TASKS for system changes; it never implements directly. After running `/meta`, drive the created task(s) through `/orchestrate` to make the changes.

**Example**:
```
/meta "Add support for Typst document compilation"
```

Creates tasks like:
- Task {N}: Create typst-implementation-agent
- Task {N}: Add /typst command
- Task {N}: Update language routing

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

### /zulip Command

Fetch a Zulip thread via API and write formatted JSON to a file.

```
/zulip <zulip-url> [output-path]
```

**Arguments**:
- `zulip-url` - Full Zulip thread URL from the browser address bar (required)
- `output-path` - File path to write JSON output; prompts interactively if omitted

**Behavior**: Fetches all messages from a Zulip chat thread and writes formatted JSON (sender,
date, content) to a file, reading API credentials from `~/.zuliprc`.

**Example**:
```
/zulip https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/some.20topic /tmp/thread.json
```

---

### /convert Command (requires `filetypes` extension)

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

## Extensions

Domain-specific capabilities (language support, document pipelines, email triage, and more) are
not part of the core system above -- they are loaded on demand from
[`agent-system/extensions/`](../../../README.md), which catalogs every available extension, what
each one provides, and how extensions are structured. See that file's "Available Extensions"
table for the full, current list.

**Loading and unloading**: extensions are loaded and unloaded via the editor's extension picker:
- Neovim: `<leader>ac`
- OpenCode: `<leader>ao`

Loading an extension merges its agents, skills, rules, and context into `.claude/` and
regenerates `.claude/CLAUDE.md`; unloading removes them again. A task's `task_type` determines
which loaded extension's agents and tools handle it (see
[Language Routing](#language-routing) above for the core types, and the extension catalog for
each domain extension's own routing).

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
| `/project-overview` | `/project-overview` | Interactively scan repo and create a project-overview.md task |
| `/revise` | `/revise N [reason]` | Revise plan or description |
| `/todo` | `/todo [--dry-run]` | Archive completed tasks |
| `/review` | `/review [SCOPE] [--create-tasks]` | Analyze codebase |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean resources |
| `/errors` | `/errors [--fix N]` | Analyze errors |
| `/meta` | `/meta [PROMPT] \| --analyze` | System builder |
| `/fix-it` | `/fix-it [PATH...]` | Extract tags to tasks |
| `/zulip` | `/zulip <url> [output-path]` | Fetch a Zulip thread to JSON |
| `/orchestrate` | `/orchestrate N[,N-N]` | Drive task(s) through full lifecycle autonomously |
| `/orchestrate` | `/orchestrate N --research\|--plan\|--implement` | Force exactly one lifecycle phase and stop |
| `/spawn` | `/spawn N [blocker]` | Spawn tasks to unblock a blocked task |
| `/merge` | `/merge` | Create pull/merge request for current branch |
| `/please` | `/please push <remote> <branch>` | Authorize one blocked git push (user-only) |
| `/tag` | `/tag [--patch|--minor|--major]` | Create semantic version tag (user-only) |
| `/convert` | `/convert SOURCE [OUTPUT]` | Convert documents (requires `filetypes` extension) |

### Status Transitions

```
[NOT STARTED] --/orchestrate--> [RESEARCHING] --> [RESEARCHED]
                                                        |
                                    --/orchestrate--> [PLANNING] --> [PLANNED]
                                                                         |
                                                     --/orchestrate--> [IMPLEMENTING] --> [COMPLETED]
                                                                                              |
                                                                            --/todo--> (archived)
```

A single `/orchestrate N` invocation drives all of the transitions above in one run, with no
confirmation gates between them. `/orchestrate N --research`, `--plan`, or `--implement` forces
exactly one of these phases and stops there instead.

**Exception Transitions**:
- Any status -> `[BLOCKED]` (with reason)
- Any status -> `[ABANDONED]` (via `/task --abandon`)
- `[NOT STARTED]` -> `[EXPANDED]` (via `/task --expand`)
- `[IMPLEMENTING]` -> `[PARTIAL]` (on timeout/error)
- Any non-terminal status -> `[HOLD]` (operator pause, via `preflight:hold`); `[HOLD]` ->
  prior status (via `preflight:unhold`, or a one-dispatch admission under an explicit
  `/orchestrate N --research\|--plan\|--implement`, after which the hold itself persists)
- `[IMPLEMENTING]` -> `[PR READY]` (`task_type: pr` only; implementation complete, awaiting
  `/merge`); `[PR READY]` -> `[IMPLEMENTING]` (if PR review finds issues) or `[COMPLETED]`
  (after `/merge` submits the PR)

### Language Routing

Core task types and the tools each dispatch uses (from `agent-system/extensions/core/merge-sources/claudemd.md`'s
routing table):

| Task Type | Detection | Tools |
|-----------|-----------|-------|
| `meta` | Strong keyword anchors: `.claude/`, `agent-system`, `specs/`, a `skill-<word>`/`<word>-agent` compound, a leading `/command` token, and others (see `scripts/lib/task-type-detect.sh`) | Read, Grep, Glob, Write, Edit, Bash |
| `markdown` | No automatic keyword detection in the current resolution ladder; reached via the project default (`state.json`'s `default_task_type`) or manual assignment | Read, Write, Edit |
| `general` | Default outcome when no strong anchor, extension `keyword_overrides`, project default, or weak-signal match (2+ distinct keywords) resolves another type | WebSearch, WebFetch, Read, Write, Edit, Bash |
| Extension types | Extension-declared `keyword_overrides`, or weak-signal keywords (e.g. `lean`, `theorem`, `proof` for `lean4`; `latex`, `tex` for `latex`) | Per extension's own routing table |

The full resolution ladder (strong anchors -> extension `keyword_overrides` -> project default ->
weak-signal scoring -> alias remapping) is implemented once in `scripts/lib/task-type-detect.sh`
and is the authority for its own precedence rules.

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

**Symptom**: `/orchestrate N --implement` is excluded with "no plan artifact; run --plan first"

**Solutions**:
1. Verify a plan artifact exists: `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`
2. If missing, force a plan round: `/orchestrate N --plan`
3. Then re-run `/orchestrate N --implement` (or a bare `/orchestrate N` to let it continue the
   rest of the lifecycle automatically)

#### Stuck in Implementing Status

**Symptom**: Task remains `[IMPLEMENTING]` after errors

**Solutions**:
1. Run `/orchestrate N` again to resume
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
1. Verify your project builds or loads correctly
2. Check MCP configuration in `~/.claude.json`
3. Run `/refresh` to clean orphaned processes
4. Restart Claude Code session

### Getting Help

- **Architecture docs**: See [system-overview.md](../architecture/system-overview.md)
- **Command details**: Check individual command files in `.claude/commands/`
- **Examples**: See [examples/](../examples/) for workflow walkthroughs
- **CLAUDE.md**: Quick reference at [../../CLAUDE.md](../../CLAUDE.md)

---

[Back to Docs](../docs-README.md) | [CLAUDE.md](../../CLAUDE.md) | [Architecture](../architecture/system-overview.md)
