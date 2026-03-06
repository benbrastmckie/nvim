# OpenCode Agent System

Task management and agent orchestration system for Neovim configuration development. This system provides structured workflows for research, planning, and implementation across multiple languages and domains.

## Quick Start

For installation instructions, see [INSTALLATION.md](INSTALLATION.md).

Essential commands to get started:

```bash
# Task management
/task "Create new task"              # Create a task
/task --recover N                     # Recover abandoned task N
/research N                           # Research task N
/plan N                               # Create implementation plan
/implement N                          # Execute implementation plan

# System maintenance
/todo                                 # Archive completed tasks
/review                               # Analyze codebase
```

## System Overview

The .opencode/ system provides:

- **Task Lifecycle Management**: From creation to completion with state tracking
- **Language-Based Routing**: Specialized handling for neovim, lean, typst, latex, and more
- **Checkpoint-Based Execution**: GATE IN → DELEGATE → GATE OUT → COMMIT workflow
- **State Synchronization**: Automatic sync between `specs/TODO.md` (human-readable) and `specs/state.json` (machine state)

## Core Features

### Task Lifecycle

```
[NOT STARTED] → [RESEARCHING] → [RESEARCHED] → [PLANNING] → [PLANNED] → [IMPLEMENTING] → [COMPLETED]
```

Terminal states: `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]`

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `neovim` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (nvim --headless) |
| `lean` | lean_leansearch, lean_loogle, lean_leanfinder | lean_goal, lean_hover_info, lean_multi_attempt |
| `latex` | skill-latex-research (LaTeX context) | Read, Write, Edit, Bash (pdflatex) |
| `typst` | skill-typst-research (Typst context) | Read, Write, Edit, Bash (typst compile) |
| `general` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash |
| `meta` | Read, Grep, Glob | Write, Edit |

### Checkpoint Execution

All commands follow the same lifecycle:
1. **GATE IN** (preflight): Validate inputs, update status
2. **DELEGATE** (skill/agent): Execute specialized work
3. **GATE OUT** (postflight): Verify results, update artifacts
4. **COMMIT**: Persist changes with session ID

## Command Reference

| Command | Usage | Description |
|---------|-------|-------------|
| `/task` | `/task "Description"` | Create task |
| `/task` | `/task --recover N`, `--expand N`, `--sync`, `--abandon N` | Manage tasks |
| `/research` | `/research N [focus]` | Research task, route by language |
| `/plan` | `/plan N` | Create implementation plan |
| `/implement` | `/implement N` | Execute plan, resume from incomplete phase |
| `/revise` | `/revise N` | Create new plan version |
| `/review` | `/review` | Analyze codebase |
| `/todo` | `/todo` | Archive completed/abandoned tasks, sync metrics |
| `/errors` | `/errors` | Analyze error patterns, create fix plans |
| `/meta` | `/meta` | System builder for .opencode/ changes |
| `/fix` | `/fix [PATH...]` | Scan for FIX:/NOTE:/TODO: tags |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and files |
| `/convert` | `/convert FILE --to FORMAT` | Convert document formats |

### Memory System

Store and retrieve knowledge with the `/remember` command:

```bash
# Add memories
/remember "Text content to remember"
/remember /path/to/file.md

# Research with memory augmentation
/research N --remember
```

The memory system provides:
- **Checkbox Confirmation**: Interactive multi-select
- **Similarity Detection**: Finds related memories automatically
- **MCP Integration**: Search memories via Obsidian CLI REST server
- **Git Versioning**: All memories tracked in git
- **Markdown Format**: Plain text with YAML frontmatter

**Quick Links**:
- [Memory Vault](memory/README.md) - Organization and usage
- [Usage Guide](docs/guides/remember-usage.md) - Detailed examples
- [MCP Setup](docs/guides/memory-setup.md) - Server configuration

For detailed command documentation, see [commands/README.md](commands/README.md).

## Extensions

The system supports 10 language/domain-specific extensions. See [extensions/README.md](extensions/README.md) for complete listing:

| Extension | Description | Documentation |
|-----------|-------------|---------------|
| **lean** | Lean 4 theorem proving with Lake build system | [README](extensions/lean/context/project/lean4/README.md) |
| **typst** | Modern document typesetting | [README](extensions/typst/context/project/typst/README.md) |
| **latex** | Traditional document typesetting | [README](extensions/latex/context/project/latex/README.md) |
| **formal** | Formal verification (logic, math, physics) | [README](extensions/formal/context/project/logic/README.md) |
| **python** | Python development | [README](extensions/python/context/project/python/README.md) |
| **nix** | Nix package management | [README](extensions/nix/context/project/nix/README.md) |
| **web** | Web development | [README](extensions/web/context/project/web/README.md) |
| **filetypes** | File format conversion | [README](extensions/filetypes/context/project/filetypes/README.md) |
| **z3** | Z3 theorem prover | [README](extensions/z3/context/project/z3/README.md) |
| **epidemiology** | Epidemiology research and R modeling | [README](extensions/epidemiology/context/project/epidemiology/README.md) |

## Directory Structure

```
.opencode/
├── agent/              # Primary agents and subagents [README](agent/subagents/README.md)
├── commands/           # Slash command definitions [README](commands/README.md)
├── context/            # Core and project context [README](context/README.md)
├── docs/               # User-facing documentation [README](docs/README.md)
├── extensions/         # Language/domain extensions (9 available)
├── hooks/              # Hook scripts used by tooling
├── rules/              # System rules and conventions
├── skills/             # Skill definitions
├── systemd/            # Service definitions for automation
└── templates/          # JSON and markdown templates
```

## Task Management

### Artifact Paths

```
specs/{NNN}_{SLUG}/
  reports/research-{NNN}.md
  plans/implementation-{NNN}.md
  summaries/implementation-summary-{DATE}.md
```

`{NNN}` = 3-digit padded number (e.g., `001`), `{DATE}` = YYYYMMDD. Task numbers in text use unpadded format.

### Status Markers

- `[NOT STARTED]` - Initial state
- `[RESEARCHING]` → `[RESEARCHED]` - Research phase
- `[PLANNING]` → `[PLANNED]` - Planning phase
- `[IMPLEMENTING]` → `[COMPLETED]` - Implementation phase
- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states

### State Synchronization

TODO.md and state.json must stay synchronized. Update state.json first (machine state), then TODO.md (user-facing).

**state.json structure**:
```json
{
  "next_project_number": 1,
  "active_projects": [{
    "project_number": 1,
    "project_name": "task_slug",
    "status": "planned",
    "language": "neovim"
  }],
  "repository_health": {
    "last_assessed": "ISO8601 timestamp",
    "status": "healthy"
  }
}
```

## Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | Neovim/plugin research |
| skill-neovim-implementation | neovim-implementation-agent | Neovim configuration implementation |
| skill-lean-research | lean-research-agent | Lean 4/Mathlib research |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |
| skill-logic-research | logic-research-agent | Mathematical logic research |
| skill-math-research | math-research-agent | Mathematical foundations research |
| skill-latex-research | latex-research-agent | LaTeX documentation research |
| skill-researcher | general-research-agent | General web/codebase research |
| skill-planner | planner-agent | Implementation plan creation |
| skill-implementer | general-implementation-agent | General file implementation |
| skill-latex-implementation | latex-implementation-agent | LaTeX document implementation |
| skill-typst-implementation | typst-implementation-agent | Typst document implementation |
| skill-typst-research | typst-research-agent | Typst documentation research |
| skill-meta | meta-builder-agent | System building and task creation |
| skill-filetypes | filetypes-router-agent | File format conversion |
| skill-status-sync | (direct execution) | Atomic status updates |
| skill-refresh | (direct execution) | Process and file cleanup |
| skill-git-workflow | (direct execution) | Scoped git commits |
| skill-fix | (direct execution) | Scan for FIX:/NOTE:/TODO: tags |
| skill-orchestrator | (direct execution) | Route commands to workflows |

## Rules and Conventions

Core rules (auto-applied by file path):

| Rule | Purpose | Auto-Applied To |
|------|---------|-----------------|
| [state-management.md](rules/state-management.md) | Task state patterns | `specs/**` |
| [git-workflow.md](rules/git-workflow.md) | Commit conventions | All files |
| [neovim-lua.md](rules/neovim-lua.md) | Neovim Lua development | `lua/**/*.lua`, `after/**/*.lua` |
| [error-handling.md](rules/error-handling.md) | Error recovery | `.opencode/**` |
| [artifact-formats.md](rules/artifact-formats.md) | Report/plan formats | `specs/**` |
| [workflows.md](rules/workflows.md) | Command lifecycle | `.opencode/**` |

## Context Imports

Domain knowledge (load as needed):

- [Neovim API](context/project/neovim/domain/neovim-api.md)
- [Plugin Spec Patterns](context/project/neovim/patterns/plugin-spec.md)
- [lazy.nvim Guide](context/project/neovim/tools/lazy-nvim-guide.md)
- [Project Overview](context/project/repo/project-overview.md)

## Error Handling

- **On failure**: Keep task in current status, log to errors.json, preserve partial progress
- **On timeout**: Mark phase [PARTIAL], next /implement resumes
- **Git failures**: Non-blocking (logged, not fatal)

## Git Commit Conventions

Format: `task {N}: {action}` with session ID in body.

```
task 1: complete research

Session: sess_1736700000_abc123

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

Standard actions: `create`, `complete research`, `create implementation plan`, `phase {P}: {name}`, `complete implementation`.

## jq Command Safety

Claude Code Issue #1132 causes jq parse errors when using `!=` operator (escaped as `\!=`).

**Safe pattern**: Use `select(.type == "X" | not)` instead of `select(.type != "X")`

```bash
# SAFE - use "| not" pattern
select(.type == "plan" | not)

# UNSAFE - gets escaped as \!=
select(.type != "plan")
```

Full documentation: [jq-escaping-workarounds.md](context/core/patterns/jq-escaping-workarounds.md)

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading via @-references
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits

---

## Navigation

- [Installation Guide](INSTALLATION.md) - Setup and dependencies
- [Commands](commands/README.md) - Detailed command reference
- [Agents](agent/subagents/README.md) - Agent documentation
- [Documentation](docs/README.md) - User guides and architecture
- [Context](context/README.md) - Context organization
