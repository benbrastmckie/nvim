# Implementation Plan: Comprehensive Core Genericization

- **Task**: 438 - Comprehensive core genericization
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Tasks 432-433 (prior genericization), Task 437 (neovim file moves)
- **Research Inputs**: specs/438_comprehensive_core_genericization/reports/01_core-genericization.md
- **Artifacts**: plans/01_core-genericization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove all remaining neovim/nvim-specific references from core `.claude/` files (excluding extensions and templates) to make the agent system fully project-agnostic. The research report identified 337 references across 45 files, organized into 5 priority tiers. This plan addresses all MUST FIX items (7 files with routing/detection logic and hardcoded paths) and all SHOULD GENERICIZE items (~23 files with neovim examples in context docs, guides, and standards). Files marked ACCEPTABLE in the research report are left unchanged.

### Research Integration

Research report `01_core-genericization.md` provided a complete audit of 337 nvim/neovim/neotex references across 45 core files. Key findings integrated:
- 4 files contain hardcoded routing/detection logic that breaks in non-nvim repos
- 3 files have hardcoded nvim paths in commands and settings
- 8 context/reference files use neovim examples where generic ones belong
- 15+ documentation files need systematic replacement of neovim examples
- Generic replacement patterns defined (nvim/lua/ -> src/, `<leader>ac` -> "the extension picker", etc.)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Zero stale references to removed/renamed files in `.claude/`" success metric
- Relates to "Subagent-return reference cleanup" pattern (systematic reference sweep)
- The ROADMAP.md itself contains a `<leader>ac` reference in Phase 2 ("Extension hot-reload") that should be genericized, but ROADMAP.md is outside scope (read-only for this plan)

## Goals & Non-Goals

**Goals**:
- Remove all neovim-specific routing and keyword detection from core skills, commands, and agents
- Genericize all hardcoded nvim paths in commands and settings
- Replace neovim examples in context docs with project-agnostic alternatives
- Replace neovim examples in documentation guides with generic equivalents
- Add `output/implementation-001.md` to `.syncprotect`

**Non-Goals**:
- Modifying files in `.claude/extensions/` (these are extension-specific by design)
- Modifying `.claude/templates/` (templates may legitimately reference neovim)
- Modifying `settings.local.json` (project-specific, not synced)
- Modifying files marked ACCEPTABLE in the research report (validate-wiring.sh extension case, lint scripts, etc.)
- Rewriting documentation content beyond what is needed for genericization

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing neovim from routing tables breaks existing neovim-typed tasks | H | L | Extension loader merges neovim routing when nvim extension is loaded; verify with validate-wiring.sh |
| Mass replacement introduces typos or broken markdown | M | M | Review each file individually; run check-extension-docs.sh after |
| settings.json hook path change breaks ready signal | M | L | Move to settings.local.json or use relative path; test after change |
| Genericized examples lose clarity | L | M | Use realistic generic examples (src/config/, src/plugins/) not abstract placeholders |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Remove Neovim Routing and Detection Logic [NOT STARTED]

**Goal**: Eliminate all hardcoded neovim task type routing, keyword detection, and domain classification from core skills, commands, and agents. These actively break the system in non-nvim repos.

**Tasks**:
- [ ] Edit `.claude/skills/skill-orchestrator/SKILL.md`: Remove the `neovim` row from the core routing table; change `"task_type": "neovim"` example to `"task_type": "general"`
- [ ] Edit `.claude/skills/skill-fix-it/SKILL.md`: Change `.lua (nvim/) -> "neovim"` to `.lua -> "general"`; remove neovim keyword list from content-based detection; replace Telescope examples with generic ones (e.g., "Database Migrations", "Related to database schema changes")
- [ ] Edit `.claude/commands/task.md`: Remove the `"neovim", "plugin", "nvim", "lua" -> neovim` keyword detection line
- [ ] Edit `.claude/agents/meta-builder-agent.md`: Remove `"nvim", "neovim", "plugin", "lazy.nvim", "lsp", "treesitter" -> task_type = "neovim"` keyword detection; change domain example from "neovim configuration" to "frontend development"; remove "neovim" and "plugin" from language indicators list

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrator/SKILL.md` - Remove neovim routing row and example
- `.claude/skills/skill-fix-it/SKILL.md` - Remove neovim detection logic and examples
- `.claude/commands/task.md` - Remove neovim keyword detection
- `.claude/agents/meta-builder-agent.md` - Remove neovim keyword detection and examples

**Verification**:
- Grep for `neovim` in modified files returns zero matches (excluding comments about extensions)
- Core routing table contains only `general`, `meta`, `markdown` task types
- No neovim-specific keyword detection remains in core files

---

### Phase 2: Genericize Commands and Settings [NOT STARTED]

**Goal**: Replace all hardcoded nvim paths and commands in todo.md, review.md, and settings.json with project-agnostic alternatives.

**Tasks**:
- [ ] Edit `.claude/commands/todo.md`: Replace `grep -r "TODO" nvim/lua/` with generic project scanning (e.g., `grep -r "TODO" . --include="*.lua" --include="*.py" --include="*.js"` or reference project-overview.md for source paths); replace `nvim --headless` check with generic health check pattern
- [ ] Edit `.claude/commands/review.md`: Replace `nvim --headless` with generic lint/check description; replace all `nvim/lua/plugins/lsp.lua` paths with `src/config/lsp.lua`; replace grep paths; remove `nvim/**/*.lua -> neovim` from task type inference table
- [ ] Edit `.claude/settings.json`: Move the `bash ~/.config/nvim/scripts/claude-ready-signal.sh` hook to use a relative or project-agnostic path, or document that it belongs in `settings.local.json`
- [ ] Edit `.claude/commands/fix-it.md`: Replace all nvim example paths (`nvim/lua/Layer1/Modal.lua:67`, `nvim/lua/config/lsp.lua:45`) with generic paths (`src/components/Modal.js:67`, `src/config/lsp.lua:45`); replace neovim task type examples with "general"; replace scan paths `nvim/lua/` with `src/`

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/commands/todo.md` - Genericize repository metrics scripts
- `.claude/commands/review.md` - Genericize paths and task type inference
- `.claude/settings.json` - Fix hardcoded nvim hook path
- `.claude/commands/fix-it.md` - Replace all nvim example paths and task types

**Verification**:
- Grep for `nvim/lua/` in modified command files returns zero matches
- No `nvim --headless` remains in core commands (only in acceptable files)
- settings.json contains no absolute nvim paths

---

### Phase 3: Genericize Context and Reference Documentation [NOT STARTED]

**Goal**: Replace neovim-specific examples and references in core context files, schema, and standards with project-agnostic alternatives.

**Tasks**:
- [ ] Edit `.claude/CLAUDE.md`: Change `"task_type": "neovim"` to `"task_type": "general"` in state.json example; replace `<leader>ac` with "the extension picker"; genericize extension examples
- [ ] Edit `.claude/context/architecture/system-overview.md`: Change "Neovim Configuration agent system" to "The agent system"
- [ ] Edit `.claude/context/orchestration/orchestration-core.md`: Change "Neovim Configuration's command-skill-agent architecture" to "the project's command-skill-agent architecture"
- [ ] Edit `.claude/context/formats/frontmatter.md`: Change "General research agent for non-Neovim tasks" to "General research agent with topic subdivision support"; change "Add Neovim plugin tooling" to "Add editor plugin tooling"
- [ ] Edit `.claude/context/guides/extension-development.md`: Replace neovim extension examples with generic extension examples (e.g., python); replace `<leader>ac` with "the extension picker"
- [ ] Edit `.claude/context/reference/skill-agent-mapping.md`: Replace `<leader>ac` with "the extension picker"
- [ ] Edit `.claude/context/index.schema.json`: Change `$id` from `https://nvim.config/context/index.schema.json` to `https://claude-agent.config/context/index.schema.json`
- [ ] Edit `.claude/context/standards/ci-workflow.md`: Remove or genericize neovim-specific CI entries
- [ ] Edit `.claude/context/standards/documentation-standards.md`: Remove "Use `lua` for Neovim configuration" line
- [ ] Edit `.claude/context/repo/update-project.md`: Change wording about neovim to generic template description
- [ ] Edit `.claude/rules/plan-format-enforcement.md`: Change `meta, neovim, general, etc.` to `meta, general, etc.`
- [ ] Add `output/implementation-001.md` to `.syncprotect`

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/CLAUDE.md` - Genericize examples and picker references
- `.claude/context/architecture/system-overview.md` - Remove "Neovim Configuration"
- `.claude/context/orchestration/orchestration-core.md` - Remove "Neovim Configuration"
- `.claude/context/formats/frontmatter.md` - Genericize agent descriptions
- `.claude/context/guides/extension-development.md` - Replace neovim examples
- `.claude/context/reference/skill-agent-mapping.md` - Replace picker references
- `.claude/context/index.schema.json` - Fix schema $id
- `.claude/context/standards/ci-workflow.md` - Remove neovim CI rows
- `.claude/context/standards/documentation-standards.md` - Remove neovim example
- `.claude/context/repo/update-project.md` - Genericize wording
- `.claude/rules/plan-format-enforcement.md` - Remove neovim from type list
- `.syncprotect` - Add output/implementation-001.md

**Verification**:
- Grep for `neovim` in modified context files returns zero matches (excluding extension references)
- Schema $id is project-agnostic
- No `<leader>ac` references in modified files

---

### Phase 4: Genericize Documentation and Guides [NOT STARTED]

**Goal**: Systematically replace all neovim-specific examples, paths, and references across documentation files in `.claude/docs/`. This is the bulk of the work (~200+ references across ~15 files).

**Tasks**:
- [ ] Edit `.claude/docs/README.md`: Change "Neovim Configuration" system name to generic
- [ ] Edit `.claude/docs/architecture/system-overview.md`: Change "Neovim Configuration agent system" to generic; replace neovim routing examples with generic or extension-qualified callouts
- [ ] Edit `.claude/docs/architecture/extension-system.md`: Replace `~/.config/nvim/.claude/extensions` with variable; change "Neovim Managed" to "Editor Managed"; change "Neovim picker" to "Extension picker"
- [ ] Edit `.claude/docs/examples/fix-it-flow-example.md`: Replace all `nvim/lua/` paths with `src/` paths; replace `neovim` task types with `general` (50+ replacements)
- [ ] Edit `.claude/docs/examples/research-flow-example.md`: Change scenario examples to use generic routing
- [ ] Edit `.claude/docs/guides/user-guide.md`: Replace all neovim examples with generic equivalents
- [ ] Edit `.claude/docs/guides/user-installation.md`: Replace neovim-focused installation with generic project setup
- [ ] Edit `.claude/docs/guides/copy-claude-directory.md`: Replace neovim-specific content with generic equivalents
- [ ] Edit `.claude/docs/guides/component-selection.md`: Change "Neovim Configuration" system name; genericize skill/agent tables
- [ ] Edit `.claude/docs/guides/creating-agents.md`: Change system name; genericize agent examples
- [ ] Edit `.claude/docs/guides/adding-domains.md`: Replace `<leader>ac` with "the extension picker"; genericize neovim examples
- [ ] Edit `.claude/docs/guides/creating-extensions.md`: Replace `<leader>ac` references
- [ ] Edit `.claude/docs/guides/creating-skills.md`: Change system name
- [ ] Edit `.claude/docs/guides/permission-configuration.md`: Replace nvim paths and neovim agent examples
- [ ] Edit `.claude/docs/guides/development/context-index-migration.md`: Replace neovim index examples with generic
- [ ] Edit `.claude/docs/reference/standards/agent-frontmatter-standard.md`: Replace neovim agent examples
- [ ] Edit `.claude/docs/reference/standards/extension-slim-standard.md`: Replace `<leader>ac` references
- [ ] Edit `.claude/docs/reference/standards/multi-task-creation-standard.md`: Replace nvim path in example
- [ ] Edit `.claude/README.md`: Genericize system name references (lines 3, 5, 18-19, 96, 100) while preserving the extension listing table which is acceptable

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/docs/README.md` - Genericize system name
- `.claude/docs/architecture/system-overview.md` - Genericize system name and examples
- `.claude/docs/architecture/extension-system.md` - Genericize paths and labels
- `.claude/docs/examples/fix-it-flow-example.md` - Replace all nvim paths and task types
- `.claude/docs/examples/research-flow-example.md` - Genericize routing examples
- `.claude/docs/guides/user-guide.md` - Replace neovim examples
- `.claude/docs/guides/user-installation.md` - Genericize installation guide
- `.claude/docs/guides/copy-claude-directory.md` - Replace neovim content
- `.claude/docs/guides/component-selection.md` - Genericize system name and tables
- `.claude/docs/guides/creating-agents.md` - Genericize system name and examples
- `.claude/docs/guides/adding-domains.md` - Replace picker references and examples
- `.claude/docs/guides/creating-extensions.md` - Replace picker references
- `.claude/docs/guides/creating-skills.md` - Genericize system name
- `.claude/docs/guides/permission-configuration.md` - Replace nvim paths
- `.claude/docs/guides/development/context-index-migration.md` - Replace index examples
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Replace examples
- `.claude/docs/reference/standards/extension-slim-standard.md` - Replace picker references
- `.claude/docs/reference/standards/multi-task-creation-standard.md` - Replace path example
- `.claude/README.md` - Genericize system name

**Verification**:
- Grep for `nvim/lua/` across all modified docs files returns zero matches
- Grep for `<leader>ac` across all modified docs files returns zero matches
- Grep for `Neovim Configuration` (as system name, not extension description) returns zero matches in modified files
- Run `bash .claude/scripts/check-extension-docs.sh` to verify no doc drift introduced

## Testing & Validation

- [ ] Run `grep -rni 'nvim' .claude/ --include='*.md' --include='*.json' --exclude-dir=extensions --exclude-dir=templates` and verify remaining hits are only in ACCEPTABLE files
- [ ] Run `grep -rn '<leader>ac' .claude/ --exclude-dir=extensions --exclude-dir=templates` and verify zero hits in core
- [ ] Run `bash .claude/scripts/validate-wiring.sh` to verify routing integrity
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` to verify doc consistency
- [ ] Verify `.syncprotect` contains `output/implementation-001.md`

## Artifacts & Outputs

- `specs/438_comprehensive_core_genericization/plans/01_core-genericization.md` (this plan)
- `specs/438_comprehensive_core_genericization/summaries/01_core-genericization-summary.md` (post-implementation)
- ~30 modified files across `.claude/` (skills, commands, agents, context, docs, rules)
- Updated `.syncprotect` with historical artifact exclusion

## Rollback/Contingency

All changes are text replacements in markdown and JSON files. Rollback via `git checkout .claude/` for any phase. Individual file rollback with `git checkout -- <file>`. Since phases 1-3 can run in parallel, partial rollback of any single phase is straightforward. Phase 4 is the largest batch but all changes are mechanical text replacements with no logic dependencies.
