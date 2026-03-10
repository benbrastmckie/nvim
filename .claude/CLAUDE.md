# Agent System

Task management and agent orchestration for project development. For comprehensive documentation, see @.claude/README.md.

## Quick Reference

- **Task List**: @specs/TODO.md
- **Machine State**: @specs/state.json
- **Error Tracking**: @specs/errors.json
- **Architecture**: @.claude/README.md

## Project Structure

```
.                         # Repository root
├── specs/               # Task management artifacts
│   ├── TODO.md         # Task list
│   ├── state.json      # Task state
│   └── {NNN}_{SLUG}/   # Task directories
└── .claude/             # Claude Code configuration
    ├── commands/       # Slash commands
    ├── skills/         # Skill definitions
    ├── agents/         # Agent definitions
    ├── rules/          # Auto-applied rules
    └── context/        # Domain knowledge
```

**Project-specific structure**: See `.claude/context/project/repo/project-overview.md` for details about this repository's layout.

**New repository setup**: If project-overview.md doesn't exist, see `.claude/context/project/repo/update-project.md` for guidance on generating project-appropriate documentation.

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
`{NNN}` = 3-digit zero-padded (directories and artifact versions), `{DATE}` = YYYYMMDD.

**Note**: Task numbers remain unpadded (`{N}`) in TODO.md entries, state.json values, and commit messages. Only directory names and artifact version numbers use zero-padding for lexicographic sorting.

### Language-Based Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `lean4` | `skill-lean-research` | `skill-lean-implementation` | MCP (lean-lsp), Read, Write, Edit |
| `latex` | `skill-latex-research` | `skill-latex-implementation` | WebSearch, Read, Write, Edit, Bash |
| `typst` | `skill-typst-research` | `skill-typst-implementation` | WebSearch, Read, Write, Edit, Bash |
| `python` | `skill-python-research` | `skill-python-implementation` | WebSearch, Read, Write, Edit, Bash |
| `nix` | `skill-nix-research` | `skill-nix-implementation` | MCP (mcp-nixos), Read, Write, Edit, Bash |
| `web` | `skill-web-research` | `skill-web-implementation` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `epidemiology` | `skill-epidemiology-research` | `skill-epidemiology-implementation` | WebSearch, Read, Write, Edit, Bash |
| `formal`, `logic`, `math`, `physics` | `skill-formal-research` | `skill-implementer` | WebSearch, Read, Write, Edit |
| `general` | `skill-researcher` | `skill-implementer` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `meta` | `skill-researcher` | `skill-implementer` | Read, Grep, Glob, Write, Edit |

**Note**: All skills including extension-provided skills (neovim, z3, etc.) are in `.claude/skills/`. Extension metadata is in `.claude/extensions/`.

## Command Reference

All commands use checkpoint-based execution: GATE IN (preflight) -> DELEGATE (skill/agent) -> GATE OUT (postflight) -> COMMIT.

| Command | Usage | Description |
|---------|-------|-------------|
| `/task` | `/task "Description"` | Create task |
| `/task` | `/task --recover N`, `--expand N`, `--sync`, `--abandon N` | Manage tasks |
| `/research` | `/research N [focus]` | Research task, route by language |
| `/plan` | `/plan N` | Create implementation plan |
| `/implement` | `/implement N` | Execute plan, resume from incomplete phase |
| `/revise` | `/revise N` | Create new plan version |
| `/review` | `/review` | Analyze codebase |
| `/todo` | `/todo` | Archive completed/abandoned tasks, sync repository metrics |
| `/errors` | `/errors` | Analyze error patterns, create fix plans |
| `/meta` | `/meta` | System builder for .claude/ changes |
| `/learn` | `/learn [PATH...]` | Scan for FIX:/NOTE:/TODO: tags |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and old files |

### Utility Scripts

- `.claude/scripts/export-to-markdown.sh` - Export .claude/ directory to consolidated markdown file

## State Synchronization

TODO.md and state.json must stay synchronized. Update state.json first (machine state), then TODO.md (user-facing).

### state.json Structure
```json
{
  "next_project_number": 1,
  "active_projects": [{
    "project_number": 1,
    "project_name": "task_slug",
    "status": "planned",
    "language": "neovim",
    "completion_summary": "Required when status=completed",
    "roadmap_items": ["Optional explicit roadmap items"]
  }],
  "repository_health": {
    "last_assessed": "ISO8601 timestamp",
    "status": "healthy"
  }
}
```

### Completion Workflow
- Non-meta tasks: `completion_summary` + optional `roadmap_items` -> /todo annotates ROAD_MAP.md
- Meta tasks: `completion_summary` + `claudemd_suggestions` -> /todo displays for user review

## Git Commit Conventions

Format: `task {N}: {action}` with session ID in body.
```
task 1: complete research

Session: sess_1736700000_abc123

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Standard actions: `create`, `complete research`, `create implementation plan`, `phase {P}: {name}`, `complete implementation`.

## Skill-to-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-researcher | general-research-agent | opus | General web/codebase research |
| skill-planner | planner-agent | opus | Implementation plan creation |
| skill-implementer | general-implementation-agent | - | General file implementation |
| skill-meta | meta-builder-agent | - | System building and task creation |
| skill-status-sync | (direct execution) | - | Atomic status updates |
| skill-refresh | (direct execution) | - | Process and file cleanup |

**Model Enforcement**: Agents declare preferred models via `model:` frontmatter field. Research and planning agents use `opus` for superior reasoning. Implementation agents use default model. See `.claude/docs/reference/standards/agent-frontmatter-standard.md` for details.

**Note**: All skills including extension-provided skills (neovim, latex, typst, z3, etc.) are in `.claude/skills/`.

## Rules References

Core rules (auto-applied by file path):
- @.claude/rules/state-management.md - Task state patterns (specs/**)
- @.claude/rules/git-workflow.md - Commit conventions
- @.claude/rules/error-handling.md - Error recovery (.claude/**)
- @.claude/rules/artifact-formats.md - Report/plan formats (specs/**)
- @.claude/rules/workflows.md - Command lifecycle (.claude/**)

**Note**: All rules including extension-provided rules (neovim-lua.md, etc.) are in `.claude/rules/`.

## Context Discovery

Agents use `index.json` for automated context discovery instead of hardcoded file lists:

```bash
# Find context files for an agent
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | .path' .claude/context/index.json

# Find context by task language
jq -r '.entries[] | select(.load_when.languages[]? == "lean4") | .path' .claude/context/index.json

# Get line counts for budget calculation
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | "\(.line_count)\t\(.path)"' .claude/context/index.json
```

See `.claude/context/core/patterns/context-discovery.md` for query patterns.

**Note**: All context files including extension-provided context are in `.claude/context/`. Extension metadata (index-entries.json) remains in `.claude/extensions/{ext}/` for reference.

## Context Imports

Domain knowledge (load as needed):
- @.claude/context/project/repo/project-overview.md

**Note**: All context imports are available directly from `.claude/context/project/`. Extension EXTENSION.md files document extension capabilities for reference.

## Multi-Task Creation Standards

Commands that create multiple tasks follow a standardized 8-component pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete specification.

**Commands Using Multi-Task Creation**:
| Command | Compliance | Notes |
|---------|------------|-------|
| `/meta` | Full (Reference) | All 8 components, Kahn's algorithm, DAG visualization |
| `/learn` | Full | Interactive selection, topic grouping, internal dependencies |
| `/review` | Partial | Tier-based selection, grouping; no dependencies |
| `/errors` | Partial | Automatic mode (intentional); no interactive selection |
| `/task --review` | Partial | Numbered selection, parent_task linking |

**Required Components** (all multi-task creators):
- Item Discovery - Identify potential tasks
- Interactive Selection - AskUserQuestion with multiSelect
- User Confirmation - Explicit "Yes, create tasks" before creation
- State Updates - Atomic state.json + TODO.md updates

**Optional Components** (for 3+ tasks):
- Topic Grouping - Cluster related items
- Dependency Declaration - Ask about task relationships
- Topological Sorting - Kahn's algorithm for ordering
- Visualization - Linear chain or layered DAG display

## Error Handling

- **On failure**: Keep task in current status, log to errors.json, preserve partial progress
- **On timeout**: Mark phase [PARTIAL], next /implement resumes
- **Git failures**: Non-blocking (logged, not fatal)

## jq Command Safety

Claude Code Issue #1132 causes jq parse errors when using `!=` operator (escaped as `\!=`).

**Safe pattern**: Use `select(.type == "X" | not)` instead of `select(.type != "X")`

```bash
# SAFE - use "| not" pattern
select(.type == "plan" | not)

# UNSAFE - gets escaped as \!=
select(.type != "plan")
```

Full documentation: @.claude/context/core/patterns/jq-escaping-workarounds.md

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading via @-references
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits
