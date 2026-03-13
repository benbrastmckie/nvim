# OpenCode Agent System

Task management and agent orchestration system for Neovim configuration development. This system provides structured workflows for research, planning, and implementation across multiple languages and domains.

## Quick Reference

- **Task List**: @specs/TODO.md
- **Machine State**: @specs/state.json
- **Error Tracking**: @specs/errors.json
- **Architecture**: @.opencode/README.md

## Project Structure

```
.                         # Repository root
├── specs/               # Task management artifacts
│   ├── TODO.md         # Task list
│   ├── state.json      # Task state
│   └── {NNN}_{SLUG}/   # Task directories
└── .opencode/           # OpenCode configuration
    ├── commands/       # Slash commands
    ├── skills/         # Skill definitions
    ├── agent/          # Agent definitions
    ├── rules/          # Auto-applied rules
    └── context/        # Domain knowledge
```

## Task Management

### Status Markers

- `[NOT STARTED]` - Initial state
- `[RESEARCHING]` -> `[RESEARCHED]` - Research phase
- `[PLANNING]` -> `[PLANNED]` - Planning phase
- `[IMPLEMENTING]` -> `[COMPLETED]` - Implementation phase
- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states

### Artifact Paths

```
specs/{NNN}_{SLUG}/
├── reports/research-{NNN}.md
├── plans/implementation-{NNN}.md
└── summaries/implementation-summary-{DATE}.md
```

`{NNN}` = 3-digit padded number, `{DATE}` = YYYYMMDD.

### Language Routing

**Core Languages** (always available):

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `general` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash |
| `meta` | Read, Grep, Glob | Write, Edit |

**Extension Languages** (available when extensions are loaded via `<leader>ao`):

Extensions provide specialized routing for additional languages. See `extensions/*/manifest.json` for available extensions.

## Command Reference

All commands use checkpoint-based execution: GATE IN -> DELEGATE -> GATE OUT -> COMMIT.

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
| `/fix-it` | `/fix-it [PATH...]` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and files |
| `/convert` | `/convert FILE --to FORMAT` | Convert document formats |

## Skill-to-Agent Mapping

**Core Skills** (always available):

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-researcher | general-research-agent | General web/codebase research |
| skill-planner | planner-agent | Implementation plan creation |
| skill-implementer | general-implementation-agent | General file implementation |
| skill-meta | meta-builder-agent | System building and task creation |
| skill-status-sync | (direct execution) | Atomic status updates |
| skill-refresh | (direct execution) | Process and file cleanup |
| skill-git-workflow | (direct execution) | Scoped git commits |
| skill-fix-it | (direct execution) | Scan for FIX:/NOTE:/TODO:/QUESTION: tags with topic grouping |
| skill-todo | (direct execution) | Archive completed tasks |
| skill-orchestrator | (direct execution) | Route commands to workflows |

**Extension Skills**: When extensions are loaded via `<leader>ao`, additional skill-to-agent mappings are available.

## Rules and Conventions

Core rules (auto-applied by file path):

| Rule | Purpose | Auto-Applied To |
|------|---------|-----------------|
| [state-management.md](rules/state-management.md) | Task state patterns | `specs/**` |
| [git-workflow.md](rules/git-workflow.md) | Commit conventions | All files |
| [error-handling.md](rules/error-handling.md) | Error recovery | `.opencode/**` |
| [artifact-formats.md](rules/artifact-formats.md) | Report/plan formats | `specs/**` |
| [workflows.md](rules/workflows.md) | Command lifecycle | `.opencode/**` |

## State Synchronization

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

Claude Code Issue #1132 causes jq parse errors when using `!=` operator.

**Safe pattern**: Use `select(.type == "X" | not)` instead of `select(.type != "X")`

## Command Migration Notes

### `/fix` renamed to `/fix-it`

The `/fix` command has been renamed to `/fix-it` to align with the .claude/ agent system naming convention. The new command includes:
- Support for `QUESTION:` tags (research tasks)
- Topic grouping for TODO and QUESTION items
- Dependency handling between learn-it and fix-it tasks
- Content-based language detection for research tasks

**Update your workflows**: Replace all occurrences of `/fix` with `/fix-it` in scripts and documentation.

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading via @-references
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits
