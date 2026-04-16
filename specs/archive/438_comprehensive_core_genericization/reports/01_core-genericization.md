# Research Report: Task #438

**Task**: 438 - Comprehensive core genericization
**Started**: 2026-04-14T00:00:00Z
**Completed**: 2026-04-14T00:30:00Z
**Effort**: 4-6 hours (implementation estimate)
**Dependencies**: Tasks 432-433 (prior genericization), Task 437 (neovim file moves)
**Sources/Inputs**: Codebase grep audit across `.claude/` excluding `.claude/extensions/`
**Artifacts**: - specs/438_comprehensive_core_genericization/reports/01_core-genericization.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **337 nvim/neovim/neotex references** remain across **45 core files** in `.claude/` (excluding extensions and templates)
- 22 files need substantive changes (MUST FIX or SHOULD GENERICIZE categories)
- 19 files are documentation/guides that use neovim as an example -- these need the heaviest editing
- 4 files contain hardcoded routing/detection logic that will break in non-nvim repos (MUST FIX)
- The `settings.json` hook has a hardcoded `~/.config/nvim/` path
- The `output/implementation-001.md` file is a historical artifact and should be excluded from sync

## Context & Scope

Tasks 432-433 genericized ~30 files and task 437 moved 2 neovim-only files. The zed audit (task 65) found 368 nvim/neovim references across 53 files after sync. This audit catalogs every remaining reference in core `.claude/` for the final genericization pass.

**Methodology**: Searched for `nvim`, `neovim`, `neotex`, `<leader>ac`, `lazy.nvim`, `telescope`, `nvim-lspconfig` (case-insensitive where applicable) across all `.md`, `.json`, `.sh`, `.lua` files in `.claude/` excluding `.claude/extensions/` and `.claude/templates/`.

---

## Findings

### Category 1: MUST FIX -- Hardcoded Routing/Detection Logic

These contain logic that actively breaks in non-nvim repos.

#### 1.1 `.claude/skills/skill-orchestrator/SKILL.md`

**Lines 44, 69**: Hardcoded neovim routing in core orchestrator
```
| neovim | skill-neovim-research | skill-neovim-implementation |
```
```json
"task_type": "neovim",
```
**Fix**: Remove the `neovim` row from the core routing table (it belongs in the extension). The JSON example should use a generic task type like `"general"`.

#### 1.2 `.claude/skills/skill-fix-it/SKILL.md`

**Line 410**: Hardcoded path-based language detection
```
.lua (nvim/) -> "neovim"
```
**Fix**: Change to `.lua -> "general"` (or remove the nvim/ qualifier). Neovim-specific detection should come from the extension.

**Line 424**: Hardcoded neovim keyword list in content-based detection
```
neovim: nvim, neovim, plugin, lazy, telescope, treesitter, lsp, buffer, window, keymap, autocmd, lua
```
**Fix**: Remove or genericize. Core should not have neovim-specific keyword matching. This should be extension-injected or removed entirely, defaulting to "general".

**Line 354, 361**: Telescope examples in topic grouping
```
- `{topic_label}` = generated label (e.g., "Telescope Worktrees")
- `{shared_terms_description}` = ... (e.g., "Related to telescope worktree functionality")
```
**Fix**: Replace with generic examples (e.g., "Database Migrations", "Related to database schema changes").

#### 1.3 `.claude/commands/task.md`

**Line 112**: Hardcoded neovim keyword detection
```
- "neovim", "plugin", "nvim", "lua" -> neovim
```
**Fix**: Remove the neovim line. Extension task types should be detected by extensions, not core.

#### 1.4 `.claude/agents/meta-builder-agent.md`

**Line 239**: Hardcoded neovim keyword detection in domain classification
```
- Keywords: "nvim", "neovim", "plugin", "lazy.nvim", "lsp", "treesitter" -> task_type = "neovim"
```
**Fix**: Remove the neovim line. Core meta-builder should not hardcode extension task types.

**Line 1012**: Neovim as example domain
```
- `{domain}` = Domain from interview (e.g., "meta changes", "neovim configuration")
```
**Fix**: Change to generic example (e.g., "meta changes", "frontend development").

**Line 1152**: Language indicators list
```
- Language indicators: "neovim", "plugin", "command", "skill", "latex", etc.
```
**Fix**: Remove "neovim" and "plugin" from this list. Keep "command", "skill", etc.

#### 1.5 `.claude/commands/todo.md`

**Lines 862-875**: Hardcoded nvim paths in repository metrics
```bash
todo_count=$(grep -r "TODO" nvim/lua/ --include="*.lua" | wc -l)
fixme_count=$(grep -r "FIXME" nvim/lua/ --include="*.lua" | wc -l)
if nvim --headless -c "quit" 2>/dev/null; then
```
**Fix**: These should use `project-overview.md` paths or a configurable source directory. Replace with generic patterns that scan the project root.

#### 1.6 `.claude/commands/review.md`

**Line 49**: Hardcoded nvim command
```
- Run `nvim --headless` to check for errors
```
**Fix**: Remove or genericize to "Run project-specific lint/check commands".

**Line 110**: Hardcoded nvim path in JSON example
```
"location": "nvim/lua/plugins/lsp.lua"
```
**Fix**: Use generic path like `"src/config/lsp.lua"`.

**Line 145**: Hardcoded grep path
```
grep -r "TODO" nvim/lua/ --include="*.lua" | wc -l
```
**Fix**: Use generic path pattern.

**Lines 483, 510, 518**: More nvim path examples in file_section logic
```
"file_path": "nvim/lua/plugins/lsp.lua"
"file_section": "nvim/lua/plugins/"
```
**Fix**: Use generic paths like `"src/plugins/lsp.lua"`, `"src/plugins/"`.

**Line 723**: Task type inference table
```
| `nvim/**/*.lua` | neovim |
```
**Fix**: Remove this row from core. Should be extension-contributed.

#### 1.7 `.claude/scripts/validate-wiring.sh`

**Lines 240-244**: Hardcoded neovim agent validation
```bash
nvim)
    validate_agent_exists "$system_dir/$agents_subdir" "neovim-research-agent"
    validate_agent_exists "$system_dir/$agents_subdir" "neovim-implementation-agent"
    validate_index_entries "$system_dir" "neovim-research-agent"
    validate_language_entries "$system_dir" "neovim"
    ;;
```
**Fix**: This is inside an extension case statement -- actually ACCEPTABLE since it validates the nvim extension when loaded. No change needed.

#### 1.8 `.claude/settings.json`

**Line 87**: Hardcoded nvim path in hook
```
"command": "bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"
```
**Fix**: This is project-specific and should remain in `settings.local.json`, not `settings.json`. Move to local or use a relative path.

---

### Category 2: SHOULD GENERICIZE -- Examples Using Neovim

These use neovim as the example domain where generic placeholders would be more appropriate for sync.

#### 2.1 `.claude/commands/fix-it.md`

**Lines 48, 109, 122, 126, 158, 207-213, 229-233, 248, 272, 278**: Extensive nvim examples throughout
- Example file paths: `nvim/lua/Layer1/Modal.lua:67`, `nvim/lua/config/lsp.lua:45`
- Example task types: `neovim`
- Example scan paths: `nvim/lua/`, `/fix-it nvim/lua/Layer1/`
- Language detection keywords mentioning neovim

**Fix**: Replace all example paths with generic equivalents (`src/config/lsp.js:67`, `src/utils/helpers.py:23`). Replace neovim task types with "general". Replace scan paths with `src/`.

#### 2.2 `.claude/CLAUDE.md`

**Line 120**: state.json example uses `"task_type": "neovim"`
**Fix**: Change to `"task_type": "general"`.

**Lines 73, 293**: `<leader>ac` references for extension loading
**Fix**: Change to "the extension loader" or "the extension picker" (editor-agnostic).

**Lines 200, 222**: Extension examples mention neovim
**Fix**: Use generic extension examples (e.g., "skill-python-research -> python-research-agent", "python-lint.md for Python development").

#### 2.3 `.claude/README.md`

**Line 113**: `<leader>ac` keybinding reference
**Fix**: Change to "the extension picker/loader".

**Line 119**: nvim extension in table
```
| nvim | Neovim/Lua | neovim-research-agent, neovim-implementation-agent |
```
**Fix**: This is an extension listing -- ACCEPTABLE as documentation of what the nvim extension provides. But consider making it more clearly an "available extensions" list rather than a core feature.

**Line 188**: Reference to moved content -- ACCEPTABLE (it's a changelog note).

#### 2.4 `.claude/context/architecture/system-overview.md`

**Line 12**: "Neovim Configuration agent system"
**Fix**: Change to "The agent system" or "The project agent system".

#### 2.5 `.claude/context/orchestration/orchestration-core.md`

**Line 11**: "Neovim Configuration's command-skill-agent architecture"
**Fix**: Change to "the project's command-skill-agent architecture".

#### 2.6 `.claude/context/formats/frontmatter.md`

**Line 103**: "General research agent for non-Neovim tasks"
**Fix**: Change to "General research agent with topic subdivision support."

**Line 698**: "Add Neovim plugin tooling for configuration agents"
**Fix**: Change to "Add editor plugin tooling for configuration agents".

#### 2.7 `.claude/context/guides/extension-development.md`

**Lines 29-52, 77, 87-89, 161**: Uses neovim as the primary extension example
**Fix**: Replace with a simpler, non-neovim extension example (e.g., python or a fictional "rust" extension). Lines 77 and 161 say "loaded via `<leader>ac` in Neovim" -- change to "loaded via the extension picker".

#### 2.8 `.claude/context/reference/skill-agent-mapping.md`

**Lines 87, 146**: `<leader>ac` references
**Fix**: Change to "the extension picker".

#### 2.9 `.claude/context/repo/update-project.md`

**Line 142**: "existing project-overview.md in this repository is an example for a Neovim configuration project"
**Fix**: Change to "the existing project-overview.md serves as a template for generating project-specific documentation".

#### 2.10 `.claude/context/standards/ci-workflow.md`

**Lines 35, 60-61, 64-66**: Neovim-specific CI entries
**Fix**: Remove neovim-specific rows or genericize.

#### 2.11 `.claude/context/standards/documentation-standards.md`

**Line 78**: "Use `lua` for Neovim configuration"
**Fix**: Remove this line or change to generic example.

#### 2.12 `.claude/context/standards/postflight-tool-restrictions.md`

**Line 74**: `nvim --headless` as example
**Fix**: This is in a list of verification commands -- ACCEPTABLE as it shows various build tools.

#### 2.13 `.claude/docs/architecture/extension-system.md`

**Line 222**: `global_extensions_dir = "~/.config/nvim/.claude/extensions"`
**Fix**: Use a variable or generic path.

**Lines 33, 364**: "Neovim Managed", "Neovim picker"
**Fix**: Change to "Editor Managed", "Extension picker".

#### 2.14 `.claude/docs/architecture/system-overview.md`

**Lines 5, 34, 46, 138-148, 192, 227, 231**: Extensive neovim references
**Fix**: This is a key architecture doc. Change "Neovim Configuration agent system" to generic. Replace neovim routing examples with generic or use a clearly-labeled "example with nvim extension loaded" callout.

#### 2.15 `.claude/docs/examples/fix-it-flow-example.md`

**~50+ lines**: The entire example uses neovim paths and task types
**Fix**: Replace all `nvim/lua/` paths with generic `src/` paths. Replace `neovim` task types with `general`. This is the highest-count file.

#### 2.16 `.claude/docs/examples/research-flow-example.md`

**Lines 70, 109, 308-318, 402-420**: Neovim routing examples
**Fix**: Change scenario examples to use generic or extension-qualified routing.

#### 2.17 `.claude/docs/guides/` (multiple files)

| File | Lines | Nature |
|------|-------|--------|
| `adding-domains.md` | 22, 157-164, 190, 371 | Extension loading via `<leader>ac`, neovim examples |
| `component-selection.md` | 3, 9, 112-300, 409 | "Neovim Configuration" system name, skill/agent tables |
| `copy-claude-directory.md` | 5, 14-15, 61, 99, 104, 115-126, 166-190, 228-261 | Entire guide is neovim-specific |
| `creating-agents.md` | 3, 75, 78, 257, 298, 670-692 | System name, agent examples |
| `creating-extensions.md` | 11, 147, 556, 599 | `<leader>ac` references |
| `creating-skills.md` | 3, 537 | System name |
| `permission-configuration.md` | 247-283, 500 | nvim in bash tools, neovim agent examples |
| `user-guide.md` | 5, 109, 115, 185, 189, 220, 269, 332, 338, 535, 591 | Full of neovim examples |
| `user-installation.md` | 5, 13-15, 70-76, 98, 114-115, 141-165, 234-269, 290-318 | Entirely neovim-focused |

**Fix**: All guides need systematic replacement:
1. "Neovim Configuration" -> "Project" or remove qualifier
2. `<leader>ac` -> "the extension picker"
3. `nvim/lua/` paths -> `src/` or project-agnostic paths
4. `~/.config/nvim` -> "your project directory"
5. neovim task type examples -> generic examples

#### 2.18 `.claude/docs/README.md`

**Lines 3, 5, 18-19, 96, 100**: "Neovim Configuration" system name, breadcrumb links
**Fix**: Change system name to generic.

#### 2.19 `.claude/docs/reference/standards/`

| File | Lines | Nature |
|------|-------|--------|
| `agent-frontmatter-standard.md` | 21, 28-29, 71-72, 127 | neovim agent examples |
| `extension-slim-standard.md` | 5, 137 | `<leader>ac` references |
| `multi-task-creation-standard.md` | 80 | nvim path in example |

**Fix**: Replace neovim-specific examples with generic ones.

#### 2.20 `.claude/docs/guides/development/context-index-migration.md`

**Lines 53-62, 80, 95, 117-124, 191-199, 210-217**: Full of neovim index examples
**Fix**: Use generic extension examples throughout.

#### 2.21 `.claude/rules/plan-format-enforcement.md`

**Line 19**: `meta, neovim, general, etc.`
**Fix**: Change to `meta, general, etc.` (task types are dynamic).

#### 2.22 `.claude/context/index.schema.json`

**Line 3**: `"$id": "https://nvim.config/context/index.schema.json"`
**Fix**: Change to a generic schema ID like `"https://claude-agent.config/context/index.schema.json"`.

---

### Category 3: ACCEPTABLE -- No Change Needed

These are references that are appropriate in their context:

| File | Nature | Reason |
|------|--------|--------|
| `.claude/scripts/validate-wiring.sh` (lines 240-244) | Extension validation case | Validates nvim extension when loaded; part of per-extension switch |
| `.claude/scripts/lint/lint-postflight-boundary.sh` (lines 6, 100) | `nvim --headless` in build pattern list | Lists various build tools; nvim is one of many |
| `.claude/context/standards/postflight-tool-restrictions.md` (line 74) | `nvim --headless` in tool list | Part of a generic list of verification tools |
| `.claude/settings.local.json` | Project-specific paths | Local settings are inherently project-specific; not synced |
| `.claude/output/implementation-001.md` | Historical artifact | Should be in `.syncprotect` or excluded from sync |
| `.claude/README.md` (line 119) | Extension listing table | Documents what extensions exist |
| `.claude/README.md` (line 188) | Migration note | Historical changelog entry |
| `.claude/agents/code-reviewer-agent.md` (lines 36-38) | Extension context references | References extension paths correctly |
| `.claude/agents/spawn-agent.md` (line 185) | Task type example | Lists `neovim` as one of many task types -- BORDERLINE, could genericize |

---

## Decisions

1. **Extension task types should NEVER appear in core routing tables** -- the orchestrator's core table should only list `general`, `meta`, `markdown`. Extension types are merged at load time.
2. **`<leader>ac`** is a neovim-specific keybinding. Core docs should use "the extension picker/loader" instead.
3. **Example paths** in core docs should use `src/` not `nvim/lua/`.
4. **`settings.json`** hooks with absolute paths should move to `settings.local.json`.
5. **`output/implementation-001.md`** is a historical artifact that should be added to `.syncprotect`.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Changing routing tables may break existing neovim-typed tasks | Verify extension loader merges neovim routing when nvim extension is loaded |
| Genericized examples may be less helpful | Use realistic generic examples (src/config/, src/plugins/) |
| Mass find-and-replace may introduce errors | Review each file individually; test with validate-wiring.sh after |
| settings.json hook change may break ready signal | Test hook path resolution after change |

## Implementation Priorities

### Priority 1 -- Routing/Logic (MUST FIX, 4 files)
1. `skill-orchestrator/SKILL.md` -- Remove neovim from core routing table
2. `skill-fix-it/SKILL.md` -- Remove neovim keyword detection, genericize examples
3. `commands/task.md` -- Remove neovim keyword detection
4. `agents/meta-builder-agent.md` -- Remove neovim keyword detection

### Priority 2 -- Commands with hardcoded paths (MUST FIX, 3 files)
5. `commands/todo.md` -- Genericize repository metrics scripts
6. `commands/review.md` -- Genericize paths and task type inference
7. `settings.json` -- Move nvim hook to settings.local.json

### Priority 3 -- Context/reference docs (SHOULD GENERICIZE, 8 files)
8. `CLAUDE.md` -- Genericize examples
9. `context/architecture/system-overview.md` -- Remove "Neovim Configuration"
10. `context/orchestration/orchestration-core.md` -- Remove "Neovim Configuration"
11. `context/formats/frontmatter.md` -- Genericize examples
12. `context/guides/extension-development.md` -- Replace neovim example extension
13. `context/reference/skill-agent-mapping.md` -- Genericize picker references
14. `context/index.schema.json` -- Fix schema $id
15. `context/standards/ci-workflow.md` -- Remove neovim-specific rows

### Priority 4 -- Documentation/guides (SHOULD GENERICIZE, 11+ files)
16-26. All `docs/` files listed in Category 2

### Priority 5 -- Housekeeping
27. Add `output/implementation-001.md` to `.syncprotect`
28. `rules/plan-format-enforcement.md` -- Minor wording fix
29. `context/standards/documentation-standards.md` -- Minor example fix
30. `context/repo/update-project.md` -- Minor wording fix

## File-Level Summary Table

| File | Matches | Category | Priority |
|------|---------|----------|----------|
| `skills/skill-orchestrator/SKILL.md` | 3 | MUST FIX | 1 |
| `skills/skill-fix-it/SKILL.md` | 5 | MUST FIX | 1 |
| `commands/task.md` | 3 | MUST FIX | 1 |
| `agents/meta-builder-agent.md` | 4 | MUST FIX | 1 |
| `commands/todo.md` | 4 | MUST FIX | 2 |
| `commands/review.md` | 8 | MUST FIX | 2 |
| `settings.json` | 1 | MUST FIX | 2 |
| `CLAUDE.md` | 5 | SHOULD GENERICIZE | 3 |
| `context/architecture/system-overview.md` | 1 | SHOULD GENERICIZE | 3 |
| `context/orchestration/orchestration-core.md` | 1 | SHOULD GENERICIZE | 3 |
| `context/formats/frontmatter.md` | 2 | SHOULD GENERICIZE | 3 |
| `context/guides/extension-development.md` | 14 | SHOULD GENERICIZE | 3 |
| `context/reference/skill-agent-mapping.md` | 2 | SHOULD GENERICIZE | 3 |
| `context/index.schema.json` | 1 | SHOULD GENERICIZE | 3 |
| `context/standards/ci-workflow.md` | 3 | SHOULD GENERICIZE | 3 |
| `docs/examples/fix-it-flow-example.md` | 50+ | SHOULD GENERICIZE | 4 |
| `docs/examples/research-flow-example.md` | 10 | SHOULD GENERICIZE | 4 |
| `docs/architecture/system-overview.md` | 15 | SHOULD GENERICIZE | 4 |
| `docs/architecture/extension-system.md` | 3 | SHOULD GENERICIZE | 4 |
| `docs/guides/user-guide.md` | 12 | SHOULD GENERICIZE | 4 |
| `docs/guides/user-installation.md` | 25+ | SHOULD GENERICIZE | 4 |
| `docs/guides/copy-claude-directory.md` | 20+ | SHOULD GENERICIZE | 4 |
| `docs/guides/component-selection.md` | 15+ | SHOULD GENERICIZE | 4 |
| `docs/guides/creating-agents.md` | 10 | SHOULD GENERICIZE | 4 |
| `docs/guides/adding-domains.md` | 6 | SHOULD GENERICIZE | 4 |
| `docs/guides/creating-extensions.md` | 4 | SHOULD GENERICIZE | 4 |
| `docs/guides/creating-skills.md` | 2 | SHOULD GENERICIZE | 4 |
| `docs/guides/permission-configuration.md` | 6 | SHOULD GENERICIZE | 4 |
| `docs/guides/development/context-index-migration.md` | 12 | SHOULD GENERICIZE | 4 |
| `docs/README.md` | 5 | SHOULD GENERICIZE | 4 |
| `docs/reference/standards/agent-frontmatter-standard.md` | 5 | SHOULD GENERICIZE | 4 |
| `docs/reference/standards/extension-slim-standard.md` | 2 | SHOULD GENERICIZE | 4 |
| `docs/reference/standards/multi-task-creation-standard.md` | 1 | SHOULD GENERICIZE | 4 |
| `rules/plan-format-enforcement.md` | 1 | SHOULD GENERICIZE | 5 |
| `context/standards/documentation-standards.md` | 1 | SHOULD GENERICIZE | 5 |
| `context/repo/update-project.md` | 1 | SHOULD GENERICIZE | 5 |
| `README.md` | 3 | MIXED | 5 |
| **ACCEPTABLE (no change)** | | | |
| `scripts/validate-wiring.sh` | 5 | ACCEPTABLE | - |
| `scripts/lint/lint-postflight-boundary.sh` | 2 | ACCEPTABLE | - |
| `context/standards/postflight-tool-restrictions.md` | 1 | ACCEPTABLE | - |
| `settings.local.json` | 5 | ACCEPTABLE | - |
| `output/implementation-001.md` | 15 | ACCEPTABLE | - |
| `agents/code-reviewer-agent.md` | 3 | ACCEPTABLE | - |
| `agents/spawn-agent.md` | 1 | ACCEPTABLE | - |

## Appendix

### Search Queries Used
```
grep -rni 'nvim' .claude/ (excluding extensions/, templates/)
grep -rni 'neovim' .claude/ (excluding extensions/, templates/)
grep -rni 'neotex' .claude/ (excluding extensions/, templates/)
grep -rn '<leader>ac' .claude/ (excluding extensions/, templates/)
grep -rn 'lazy\.nvim' .claude/ (excluding extensions/, templates/)
grep -rni 'telescope' .claude/ (excluding extensions/, templates/)
grep -rn 'nvim-lspconfig' .claude/ (excluding extensions/, templates/)
```

### Generic Replacement Patterns
| Old Pattern | New Pattern |
|-------------|-------------|
| `Neovim Configuration agent system` | `The agent system` or `The project agent system` |
| `nvim/lua/plugins/lsp.lua` | `src/config/lsp.js` or `src/plugins/lsp.lua` |
| `nvim/lua/` | `src/` |
| `~/.config/nvim` | `your project directory` or `$PROJECT_ROOT` |
| `<leader>ac` | `the extension picker` |
| `lazy.nvim` (in core examples) | remove or use generic plugin manager |
| `telescope` (in core examples) | remove or use generic tool |
| `"task_type": "neovim"` | `"task_type": "general"` (in core examples) |
| `neovim -> skill-neovim-research` | remove from core (extension-provided) |
| `"neovim", "plugin", "nvim" -> neovim` | remove from core detection logic |
| `https://nvim.config/` | `https://claude-agent.config/` |
