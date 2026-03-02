# Research Report: Task #109

**Task**: 109 - generic_agent_system_portability
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 2-4 hours estimated for implementation
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (.claude/ directory, sync.lua, context/, agents/, rules/)
**Artifacts**: specs/109_generic_agent_system_portability/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `.claude/` directory has a clear split between **generic agent system infrastructure** (commands, skills, core context, templates, scripts) and **project-specific content** (neovim agents, neovim context, neovim rules, project-overview.md)
- The `<leader>ac` "Load All Artifacts" function (`sync.lua`) copies **everything** from the global directory - all commands, agents, skills, rules, context, docs, hooks, scripts, templates, settings, and root files including `CLAUDE.md`
- The current `.claude/CLAUDE.md` contains **13 neovim-specific references** that would be incorrect when copied to a new repo
- Creating `agent-system.md` (generic overview) and restructuring `CLAUDE.md` to be project-agnostic is achievable with minimal disruption
- The `update-project.md` file does **not yet exist** - it needs to be created as part of this task

## Context & Scope

This research investigates how to make the `.claude/` agent system portable across repositories. Currently, when `<leader>ac` "Load All Artifacts" syncs from the global directory to a new project, it copies files that contain neovim-specific content that is irrelevant or incorrect for non-neovim projects.

The goal is to split content into:
1. **agent-system.md** - Generic agent system overview (portable, always copied)
2. **project-overview.md** - Project-specific content (stays in this repo, not copied)
3. **CLAUDE.md** - Made generic, links to project-overview.md, suggests generating it if missing

## Findings

### 1. Complete File Audit: Neovim-Specific Content in .claude/

#### Definitely Neovim-Specific (DO NOT copy to new repos)

| File | Content | Category |
|------|---------|----------|
| `agents/neovim-research-agent.md` | Neovim plugin research agent | Agent |
| `agents/neovim-implementation-agent.md` | Neovim config implementation agent | Agent |
| `skills/skill-neovim-research/SKILL.md` | Neovim research skill wrapper | Skill |
| `skills/skill-neovim-implementation/SKILL.md` | Neovim implementation skill wrapper | Skill |
| `rules/neovim-lua.md` | Lua coding standards, Neovim API patterns | Rule |
| `context/project/neovim/` (entire directory, 7 subdirs) | Neovim domain knowledge (API, patterns, templates, tools) | Context |
| `context/project/repo/project-overview.md` | Neovim project structure, tech stack, workflows | Context |
| `context/project/repo/self-healing-implementation-details.md` | Implementation details referencing TODO.md patterns | Context |
| `context/project/hooks/wezterm-integration.md` | WezTerm + Neovim integration details | Context |

#### Mixed Content (needs splitting or parameterization)

| File | Neovim-Specific Lines | Generic Lines | Action Needed |
|------|----------------------|---------------|---------------|
| `.claude/CLAUDE.md` | 13 lines (Project Structure, language routing, skill mapping, rules refs, context imports) | ~200 lines (task management, commands, state sync, git conventions, error handling, jq safety) | Extract neovim content, make generic |
| `context/project/processes/research-workflow.md` | ~30 lines (neovim agent routing, neovim-specific tools section) | ~570 lines (general research workflow) | Flag neovim parts as project-specific examples |
| `context/project/processes/implementation-workflow.md` | ~5 lines (neovim agent routing) | ~415 lines (general implementation workflow) | Flag neovim parts as project-specific examples |
| `context/core/orchestration/routing.md` | ~50 lines (neovim routing validation) | ~700 lines (general routing logic) | Make routing examples generic or parameterized |

#### Definitely Generic (safe to copy to any repo)

| Category | Count | Examples |
|----------|-------|---------|
| Core context | 36+ files | orchestration/, formats/, standards/, workflows/, templates/, schemas/ |
| Commands | 12 files | task.md, research.md, plan.md, implement.md, etc. |
| Generic agents | 7 files | general-research-agent, planner-agent, meta-builder-agent, etc. |
| Generic skills | 8 files | skill-researcher, skill-planner, skill-implementer, etc. |
| Generic rules | 5 files | state-management, git-workflow, error-handling, artifact-formats, workflows |
| Scripts | 9 files | cleanup, export, postflight scripts |
| Hooks | 8 files | log-session, wezterm-notify, validate-state-sync |
| Documentation | All docs/ | guides, reference, templates |
| Extensions | 8 dirs | formal, latex, lean, nix, python, typst, web, z3 |
| Templates | All | settings.json template |

### 2. How `<leader>ac` "Load All Artifacts" Works

The sync mechanism is implemented in:
- **Keybinding**: `<leader>ac` (normal mode) opens the Claude commands picker
- **Entry**: `[Load All Artifacts]` special entry in picker (see `display/entries.lua:658`)
- **Handler**: `sync.load_all_globally()` in `commands/picker/operations/sync.lua`

**Source resolution**: `scan.get_global_dir()` returns `config.options.global_source_dir` or defaults to `~/.config/nvim`

**What gets synced** (all directories scanned):
1. `commands/` (*.md)
2. `hooks/` (*.sh)
3. `templates/` (*.yaml)
4. `lib/` (*.sh)
5. `docs/` (*.md)
6. `scripts/` (*.sh)
7. `tests/` (test_*.sh)
8. `agents/` (*.md)
9. `rules/` (*.md)
10. `context/` (*.md, *.json, *.yaml)
11. `skills/` (*.md, *.yaml)
12. `systemd/` (*.service, *.timer)
13. `settings.json`
14. Root files: `.gitignore`, `README.md`, `CLAUDE.md`, `settings.local.json`
15. Project root `CLAUDE.md`

**Key observation**: The sync copies EVERYTHING from the global `.claude/` directory. There is **no filtering** of neovim-specific files. This means neovim agents, neovim rules, and neovim context all get copied to new repos.

**Sync behavior**: Users can choose "Sync all (replace existing)" or "Add new only". The "Add new only" mode skips files that already exist locally but still copies all new files including neovim-specific ones.

### 3. update-project.md Does Not Exist Yet

The task description references `.claude/context/project/repo/update-project.md` for guidance when `project-overview.md` does not exist. This file has **not been created** yet. It needs to be created as part of this task to provide a template/guide for generating project-specific overview files in new repositories.

### 4. Current CLAUDE.md Structure Analysis

The current `.claude/CLAUDE.md` (228 lines) contains these sections:

| Section | Lines | Neovim-Specific? | Action |
|---------|-------|-------------------|--------|
| Title + Quick Reference | 1-10 | YES ("Neovim Configuration Management System") | Make generic |
| Project Structure | 12-27 | YES (init.lua, lua/, after/, ftplugin/) | Move to project-overview.md |
| Task Management | 29-57 | MIXED (status markers generic, language routing has "neovim" row) | Make routing table generic |
| Command Reference | 59-80 | NO (fully generic) | Keep |
| State Synchronization | 82-107 | MIXED (example has "neovim" language) | Make example generic |
| Git Commit Conventions | 109-120 | NO (fully generic) | Keep |
| Skill-to-Agent Mapping | 122-138 | YES (neovim agents in table) | Move neovim-specific to project-overview.md |
| Rules References | 140-148 | YES (neovim-lua.md reference) | Move neovim-specific to project-overview.md |
| Context Discovery | 150-165 | YES (neovim-research-agent examples) | Make examples generic |
| Context Imports | 167-173 | YES (neovim context file paths) | Move to project-overview.md |
| Multi-Task Creation | 175-198 | NO (fully generic) | Keep |
| Error Handling | 200-204 | NO (fully generic) | Keep |
| jq Command Safety | 206-220 | NO (fully generic) | Keep |
| Important Notes | 222-228 | NO (fully generic) | Keep |

### 5. Proposed Architecture

#### New File: `agent-system.md`
**Location**: `.claude/context/core/architecture/agent-system.md`
**Purpose**: Generic overview of the agent system, suitable for any repository
**Content**: High-level description of the agent system architecture, how commands/skills/agents work together, the task management lifecycle, and how to customize for a specific project

#### Existing File: `project-overview.md` (stays as-is)
**Location**: `.claude/context/project/repo/project-overview.md`
**Purpose**: Neovim-specific project information
**Content**: Current content (tech stack, project structure, development workflow, verification commands)

#### New File: `update-project.md`
**Location**: `.claude/context/project/repo/update-project.md`
**Purpose**: Template/guide for generating project-overview.md in new repos
**Content**: Instructions for Claude to analyze a new repository and generate an appropriate project-overview.md

#### Restructured: `.claude/CLAUDE.md`
**Changes needed**:
1. Change title from "Neovim Configuration Management System" to generic title (e.g., "Agent System Configuration")
2. Remove Project Structure section (move to project-overview.md reference)
3. Make Language-Based Routing table generic (keep rows but note "neovim" is project-specific example)
4. Remove neovim-specific skill/agent mappings (move to project-overview.md)
5. Remove neovim-specific rules references (move to project-overview.md)
6. Make Context Discovery examples use generic agent names
7. Replace Context Imports with link to project-overview.md
8. Add note: "If `.claude/context/project/repo/project-overview.md` does not exist, see `.claude/context/project/repo/update-project.md` for guidance on generating one."

### 6. Sync Mechanism Considerations

The current `sync.lua` copies ALL files. For this task, we are **NOT modifying the sync mechanism** - instead we are making the files themselves portable. After this change:

- **CLAUDE.md** will be generic and correct in any repo
- **agent-system.md** will provide generic system documentation
- **project-overview.md** will be copied but will contain neovim-specific content (which the user can regenerate using update-project.md guidance)
- **Neovim agents/skills/rules/context** will still be copied (but this is acceptable since extensions handle domain-specific content, and the core neovim files are few)

### 7. Extension System Already Handles Domain Portability

The `.claude/extensions/` system (formal, latex, lean, nix, python, typst, web, z3) provides a clean portability mechanism for domain-specific agents, skills, context, and rules. However, the "core" neovim support (`agents/neovim-*`, `skills/skill-neovim-*`, `rules/neovim-lua.md`, `context/project/neovim/`) is **not** in an extension - it's in the main `.claude/` directory.

**Future consideration**: Moving neovim support into a `extensions/neovim/` extension would fully solve the portability problem for neovim-specific agents, but that is beyond the scope of this task.

## Decisions

1. **agent-system.md location**: Place in `.claude/context/core/architecture/agent-system.md` alongside existing `system-overview.md` and `component-checklist.md`
2. **CLAUDE.md approach**: Make generic by extracting project-specific content, not by adding conditional logic
3. **update-project.md**: Create as a guide that instructs Claude how to analyze a new repository and generate an appropriate project-overview.md
4. **Do not modify sync.lua**: The portability is achieved by making the files themselves portable, not by adding filtering logic to the sync mechanism
5. **Neovim agents/skills/rules stay in place**: Moving them to an extension is a separate task

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CLAUDE.md changes break existing workflows | Medium | High | Keep all functional references intact, only change presentation |
| Neovim agents still copied to non-neovim repos | Low | Low | They won't be invoked unless a task has language="neovim" |
| project-overview.md not regenerated in new repos | Medium | Medium | update-project.md provides clear guidance; CLAUDE.md includes note |
| Agent references in CLAUDE.md become stale if neovim agents moved later | Low | Low | Document as future extension migration task |

## Implementation Recommendations

### Phase 1: Create New Files
1. Create `agent-system.md` with generic system overview
2. Create `update-project.md` with project generation guidance

### Phase 2: Restructure CLAUDE.md
1. Make title and description generic
2. Extract neovim-specific Project Structure to project-overview.md reference
3. Parameterize Language-Based Routing table (note project-specific entries)
4. Split Skill-to-Agent Mapping (generic core vs project-specific)
5. Split Rules References (generic core vs project-specific)
6. Make Context Discovery examples generic
7. Replace Context Imports with project-overview.md link + note about update-project.md

### Phase 3: Verify Portability
1. Verify CLAUDE.md reads correctly without neovim context
2. Verify all command references still work
3. Test that neovim workflows still function (agents still exist, routing still works)

## Appendix

### Search Queries Used
- `find .claude/ -type f` - Full file listing
- `grep -r "neovim\|nvim\|neotex" .claude/CLAUDE.md` - Neovim references in CLAUDE.md
- `grep -r "leader.*ac\|Load All Artifacts\|load_all"` - Sync mechanism search
- Read: `sync.lua`, `scan.lua`, `project-overview.md`, `routing.md`, `context/README.md`

### Key File Paths
- Sync implementation: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Global dir resolution: `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua:8-17`
- CLAUDE.md: `.claude/CLAUDE.md` (228 lines)
- Project overview: `.claude/context/project/repo/project-overview.md` (145 lines)
- Context README: `.claude/context/README.md` (196 lines)
- Routing context: `.claude/context/core/orchestration/routing.md` (778 lines)

### File Counts by Category
- Total .claude/ files: ~410
- Neovim-specific files: ~16 (agents: 2, skills: 2, rules: 1, context: 11)
- Generic files: ~380
- Mixed files: ~14 (CLAUDE.md, routing, processes, etc.)
