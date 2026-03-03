# Neovim Configuration Management System (OpenCode)

Task management and agent orchestration for Neovim configuration maintenance. For comprehensive documentation, see @.opencode/README.md.

## Quick Reference

- **Task List**: @specs/TODO.md
- **Machine State**: @specs/state.json
- **Error Tracking**: @specs/errors.json
- **Architecture**: @.opencode/context/core/architecture/system-overview.md

## Project Structure

```
nvim/                     # Neovim configuration
  lua/                   # Lua modules
    neotex/              # Main configuration namespace
      core/              # Core configuration
      plugins/           # Plugin specifications
      utils/             # Utility functions
  after/                 # Filetype-specific overrides
    ftplugin/            # Filetype plugins
  plugin/                # Auto-loaded plugins
  init.lua               # Entry point
docs/                    # Project documentation
specs/                   # Task management artifacts
.opencode/               # OpenCode configuration
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
  reports/research-{NNN}.md
  plans/implementation-{NNN}.md
  summaries/implementation-summary-{DATE}.md
```
`{NNN}` = 3-digit padded number (e.g., `001`), `{DATE}` = YYYYMMDD. Task numbers in text use unpadded format.

### Language-Based Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `neovim` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (nvim --headless) |
| `lean` | lean_leansearch, lean_loogle, lean_leanfinder | lean_goal, lean_hover_info, lean_multi_attempt |
| `latex` | skill-latex-research (LaTeX context) | Read, Write, Edit, Bash (pdflatex) |
| `typst` | skill-typst-research (Typst context) | Read, Write, Edit, Bash (typst compile) |
| `general` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash |
| `meta` | Read, Grep, Glob | Write, Edit |

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
| `/meta` | `/meta` | System builder for .opencode/ changes |
| `/learn` | `/learn [PATH...]` | Scan for FIX:/NOTE:/TODO: tags |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and old files |
| `/convert` | `/convert FILE --to FORMAT` | Convert documents between formats |

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
    "completion_summary": "Required when status=completed"
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

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

Standard actions: `create`, `complete research`, `create implementation plan`, `phase {P}: {name}`, `complete implementation`.

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
| skill-document-converter | document-converter-agent | Document format conversion |
| skill-status-sync | (direct execution) | Atomic status updates |
| skill-refresh | (direct execution) | Process and file cleanup |
| skill-git-workflow | (direct execution) | Scoped git commits for task operations |
| skill-learn | (direct execution) | Scan for FIX:/NOTE:/TODO: tags |
| skill-orchestrator | (direct execution) | Route commands to workflows |

## Rules References

Core rules (auto-applied by file path):
- @.opencode/rules/state-management.md - Task state patterns (specs/**)
- @.opencode/rules/git-workflow.md - Commit conventions
- @.opencode/rules/neovim-lua.md - Neovim Lua development (lua/**/*.lua, after/**/*.lua)
- @.opencode/rules/error-handling.md - Error recovery (.opencode/**)
- @.opencode/rules/artifact-formats.md - Report/plan formats (specs/**)
- @.opencode/rules/workflows.md - Command lifecycle (.opencode/**)

## Context Imports

Domain knowledge (load as needed):
- @.opencode/context/project/neovim/domain/neovim-api.md
- @.opencode/context/project/neovim/patterns/plugin-spec.md
- @.opencode/context/project/neovim/tools/lazy-nvim-guide.md
- @.opencode/context/project/repo/project-overview.md

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

Full documentation: @.opencode/context/core/patterns/jq-escaping-workarounds.md

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading via @-references
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits
