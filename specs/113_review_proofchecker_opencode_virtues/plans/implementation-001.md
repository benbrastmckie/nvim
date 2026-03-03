# Implementation Plan: Opencode Feature Parity and `<leader>ao` Picker

- **Task**: 113 - review_proofchecker_opencode_virtues
- **Status**: [NOT STARTED]
- **Effort**: 10-14 hours
- **Dependencies**: Task 110 (extension system architecture, completed), Task 111 (system comparison, completed)
- **Research Inputs**:
  - [research-001.md](../reports/research-001.md) - ProofChecker virtues analysis (15 virtues, 3 tiers)
  - [research-002.md](../reports/research-002.md) - Logos/Theory comparison (12 enhancements identified)
  - [research-003.md](../reports/research-003.md) - Feature parity gap analysis (11 gap categories, 58 missing components)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements feature parity between the `.opencode/` and `.claude/` agent systems in three major workstreams: (1) adding an extension system architecture to `.opencode/`, (2) creating a `<leader>ao` commands picker that mirrors the existing `<leader>ac` Claude picker by maximizing code reuse through a shared/parameterized architecture, and (3) adding a machine-readable context index to `.opencode/`. The approach prioritizes reuse over duplication -- the existing `shared/extensions/` infrastructure demonstrates the pattern, and the picker will follow the same parameterization approach.

### Research Integration

Three research reports inform this plan:
- **research-001.md**: Identified 15 ProofChecker virtues across 3 tiers. Tier 1 critical items (ADRs, TESTING.md, validation scripts, rich domain context) inform Phase 5 extension content.
- **research-002.md**: Identified 12 Logos/Theory enhancements. Documentation organization and MCP safety patterns inform Phase 6 documentation work.
- **research-003.md**: Quantified 58-component gap between .claude/ (with extensions) and .opencode/. The extension system architecture (Gap #1) and context discovery mechanism (Gap #2) are addressed in Phases 1 and 3 respectively.

## Goals & Non-Goals

**Goals**:
- Create `.opencode/extensions/` directory architecture with manifest-based extension management
- Build `<leader>ao` picker that reuses the Claude picker infrastructure (parser, display, operations) through parameterization
- Add machine-readable `context/index.json` to `.opencode/` for automated context discovery
- Reorganize `.opencode/` agents into core vs extension categories
- Register `OpencodeCommands` user command and integrate with which-key

**Non-Goals**:
- Porting all 10 missing domain-specific agents/skills (only create extension stubs; content is out of scope)
- Rewriting the Claude picker (the goal is to parameterize and reuse, not rewrite)
- Migrating existing `.opencode/` agents to different formats
- Creating ADRs, TESTING.md, or STANDARDS_QUICK_REF.md (those are separate follow-up tasks from research-001)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Parameterizing the parser breaks Claude picker | High | Low | Test both pickers after each change; keep Claude paths as defaults |
| Extension directory structure conflicts with existing .opencode/ flat layout | Medium | Medium | Create extensions/ as new directory; do not move existing files until Phase 4 |
| OpenCode plugin (NickvanDyke/opencode.nvim) conflicts with new user commands | Low | Low | Namespace all commands with "Opencode" prefix; test coexistence |
| Shared picker code becomes overly generic and hard to maintain | Medium | Medium | Keep parameterization minimal -- only paths and labels differ |
| .opencode/ extensions have different merge target keys than .claude/ | Low | Low | Shared extension config already handles this via config.opencode() |

## Implementation Phases

### Phase 1: Create .opencode/ Extension System Architecture [NOT STARTED]

**Goal**: Establish the `.opencode/extensions/` directory structure in the global config, with at least one example extension manifest to validate the system works end-to-end.

**Tasks**:
- [ ] Create `/home/benjamin/.config/nvim/.opencode/extensions/` directory
- [ ] Create extension directory structure for at least 2 starter extensions (lean, formal) with `manifest.json` files
- [ ] Verify the shared extension infrastructure (`neotex.plugins.ai.shared.extensions`) works with `.opencode/` config by testing `list_available()`, `load()`, and `unload()` operations
- [ ] Create a `merge_targets` section in manifests that references `OPENCODE.md` (using the `opencode_md` merge key from shared config)

**Timing**: 2 hours

**Files to create/modify**:
- `/home/benjamin/.config/nvim/.opencode/extensions/lean/manifest.json` - Lean extension manifest
- `/home/benjamin/.config/nvim/.opencode/extensions/formal/manifest.json` - Formal methods extension manifest
- `/home/benjamin/.config/nvim/.opencode/extensions/lean/` - Lean extension directory tree (agents/, skills/, context/, rules/)
- `/home/benjamin/.config/nvim/.opencode/extensions/formal/` - Formal methods extension directory tree

**Verification**:
- Run `:lua print(vim.inspect(require("neotex.plugins.ai.opencode.extensions").list_available()))` and confirm extensions are discovered
- Test load/unload cycle for one extension in a test project directory

---

### Phase 2: Parameterize the Claude Picker into a Shared Picker [NOT STARTED]

**Goal**: Refactor the Claude commands picker so it accepts a configuration table specifying paths (`.claude/` vs `.opencode/`), labels ("Claude" vs "OpenCode"), and directory names. The existing `<leader>ac` behavior must remain identical.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/shared/picker/` directory with shared picker infrastructure
- [ ] Create `lua/neotex/plugins/ai/shared/picker/config.lua` defining the parameterization interface:
  ```lua
  -- Example config structure:
  -- {
  --   base_dir = ".claude",           -- or ".opencode"
  --   label = "Claude",               -- or "OpenCode"
  --   commands_subdir = "commands",
  --   skills_subdir = "skills",
  --   agents_subdir = "agents",       -- or "agent/subagents"
  --   hooks_subdir = "hooks",
  --   settings_file = "settings.local.json", -- or "settings.json"
  --   root_config_file = "CLAUDE.md", -- or "OPENCODE.md"
  --   user_command = "ClaudeCommands", -- or "OpencodeCommands"
  --   extensions_module = "neotex.plugins.ai.claude.extensions", -- or opencode variant
  -- }
  ```
- [ ] Refactor `parser.lua` to accept a config parameter instead of hardcoding `.claude/` paths. The `get_extended_structure()` function should accept a config table and use it for all directory resolution.
- [ ] Refactor `picker/init.lua` to accept config and pass it to parser, entries, and operations modules
- [ ] Refactor `picker/utils/scan.lua` to accept config for directory resolution (replacing hardcoded `.claude/`)
- [ ] Refactor `picker/display/entries.lua` to use config labels instead of "Claude"
- [ ] Refactor `picker/display/previewer.lua` to use config if it references ".claude/" paths
- [ ] Refactor `picker/operations/sync.lua` to use config for directory paths
- [ ] Refactor `picker/operations/edit.lua` to use config for directory paths
- [ ] Refactor `picker/operations/terminal.lua` to use config for command context
- [ ] Update the existing Claude picker facade (`commands/picker.lua`) to pass Claude-specific config
- [ ] Verify `<leader>ac` (ClaudeCommands) still works identically after refactoring

**Timing**: 3-4 hours

**Files to create/modify**:
- `lua/neotex/plugins/ai/shared/picker/config.lua` - NEW: Shared picker configuration
- `lua/neotex/plugins/ai/claude/commands/parser.lua` - MODIFY: Accept config parameter
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - MODIFY: Accept and propagate config
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - MODIFY: Accept config for paths
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - MODIFY: Use config labels
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - MODIFY: Use config paths
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - MODIFY: Use config paths
- `lua/neotex/plugins/ai/claude/commands/picker/operations/edit.lua` - MODIFY: Use config paths
- `lua/neotex/plugins/ai/claude/commands/picker/operations/terminal.lua` - MODIFY: Use config context
- `lua/neotex/plugins/ai/claude/commands/picker.lua` - MODIFY: Pass Claude config

**Verification**:
- Open Neovim, run `:ClaudeCommands` or press `<leader>ac` -- all categories (commands, skills, agents, hooks, extensions) should display and function identically to pre-refactor behavior
- Run existing picker tests (if any) in `commands/picker/` directory

---

### Phase 3: Create OpenCode Commands Picker (`<leader>ao`) [NOT STARTED]

**Goal**: Create the OpenCode-specific picker using the shared infrastructure from Phase 2, registered as `:OpencodeCommands` and bound to an appropriate keymap.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/opencode/commands/` directory
- [ ] Create `lua/neotex/plugins/ai/opencode/commands/picker.lua` -- thin facade that creates OpenCode config and delegates to the shared picker:
  ```lua
  local shared_config = require("neotex.plugins.ai.shared.picker.config")
  local picker_init = require("neotex.plugins.ai.claude.commands.picker.init")

  local M = {}
  function M.show_commands_picker(opts)
    local config = shared_config.opencode()
    return picker_init.show_commands_picker(opts, config)
  end
  return M
  ```
- [ ] Handle `.opencode/`-specific directory structure differences:
  - Agents are in `agent/subagents/` not `agents/`
  - Settings file is `settings.json` not `settings.local.json`
  - Root config is `OPENCODE.md` not `CLAUDE.md`
  - Skills directories use same `skills/skill-*/SKILL.md` structure (compatible)
- [ ] Register `OpencodeCommands` user command in `opencode.lua` plugin config (update existing `config` function)
- [ ] Add `<leader>aoc` keymap in which-key.lua for "opencode commands" (or repurpose `<leader>ao` group)
- [ ] Test that the picker correctly discovers and displays all `.opencode/` artifacts:
  - Commands (14)
  - Skills (22)
  - Agents (16)
  - Hooks (if any)
  - Extensions (from Phase 1)

**Timing**: 2 hours

**Files to create/modify**:
- `lua/neotex/plugins/ai/opencode/commands/picker.lua` - NEW: OpenCode commands picker facade
- `lua/neotex/plugins/ai/opencode.lua` - MODIFY: Register OpencodeCommands user command
- `lua/neotex/plugins/editor/which-key.lua` - MODIFY: Add `<leader>aoc` keymap for opencode commands

**Verification**:
- Run `:OpencodeCommands` and verify all .opencode/ components are listed
- Press `<leader>aoc` and verify picker opens with correct title "OpenCode Commands"
- Select a command entry and verify it sends to terminal correctly
- Select a skill/agent entry and verify it opens the file for editing
- Test extension toggle from within the picker

---

### Phase 4: Add Machine-Readable Context Index to .opencode/ [NOT STARTED]

**Goal**: Create `context/index.json` for `.opencode/` enabling automated context discovery via jq queries, mirroring the `.claude/context/index.json` pattern.

**Tasks**:
- [ ] Audit current `.opencode/context/` directory structure and enumerate all context files
- [ ] Create `.opencode/context/index.json` with entries for each context file, including:
  - `path` (relative to context/)
  - `domain` (core/project)
  - `subdomain` (orchestration/checkpoints/formats/etc.)
  - `topics` (array of topic keywords)
  - `keywords` (array of search keywords)
  - `summary` (1-line description)
  - `line_count` (approximate)
  - `load_when.agents` (which agents should load this)
  - `load_when.commands` (which commands trigger this)
  - `load_when.languages` (which language routes use this)
- [ ] Update `.opencode/OPENCODE.md` to document the context discovery pattern with jq query examples
- [ ] Create `.opencode/context/core/patterns/context-discovery.md` with jq query patterns for .opencode/ context

**Timing**: 2-3 hours

**Files to create/modify**:
- `.opencode/context/index.json` - NEW: Machine-readable context index
- `.opencode/OPENCODE.md` - MODIFY: Add Context Discovery section
- `.opencode/context/core/patterns/context-discovery.md` - NEW: Query patterns documentation

**Verification**:
- Run `jq '.entries | length' .opencode/context/index.json` and verify count matches actual context files
- Run `jq -r '.entries[] | select(.load_when.agents[]? == "lean-research-agent") | .path' .opencode/context/index.json` and verify reasonable output
- Spot-check 5 entries against actual file existence and line counts

---

### Phase 5: Reorganize .opencode/ Agents into Core vs Extensions [NOT STARTED]

**Goal**: Move domain-specific agents and skills from the flat `.opencode/` structure into the extension directories created in Phase 1.

**Tasks**:
- [ ] Identify which agents/skills are "core" (general-purpose) vs "domain-specific" (lean, latex, typst, logic, math, formal methods)
  - Core agents: general-research-agent, general-implementation-agent, planner-agent, meta-builder-agent, status-sync-manager, git-workflow-manager, task-executor, code-reviewer-agent
  - Domain agents to move: lean-research-agent, lean-implementation-agent, latex-implementation-agent, typst-implementation-agent, logic-research-agent, math-research-agent, physics-research-agent, formal-research-agent
- [ ] For each domain-specific agent, create the appropriate extension directory structure and copy/move the agent file
- [ ] Create corresponding skill entries in each extension
- [ ] Move domain-specific context files to extension `context/` directories
- [ ] Move domain-specific rules to extension `rules/` directories
- [ ] Update manifest.json `provides` sections to list all moved components
- [ ] Test extension load/unload to verify agents are properly installed/removed

**Timing**: 2-3 hours

**Files to modify**:
- `.opencode/extensions/lean/manifest.json` - UPDATE: Add full provides list
- `.opencode/extensions/formal/manifest.json` - UPDATE: Add full provides list
- `.opencode/extensions/latex/manifest.json` - NEW: LaTeX extension
- `.opencode/extensions/typst/manifest.json` - NEW: Typst extension
- Various agent, skill, context, and rule files - MOVE to extension directories

**Verification**:
- After moving, load lean extension and verify lean-research-agent appears in `.opencode/agent/subagents/`
- Unload lean extension and verify it is removed
- Verify `.opencode/agent/subagents/` retains only core agents when no extensions are loaded
- Run `:OpencodeCommands` and verify extension entries appear with correct status

---

### Phase 6: Validation, Documentation, and Tests [NOT STARTED]

**Goal**: Validate the complete system, update documentation, and write test coverage for the shared picker infrastructure.

**Tasks**:
- [ ] Write Lua tests for shared picker config (`shared/picker/config_spec.lua`)
  - Test Claude config returns correct paths
  - Test OpenCode config returns correct paths
  - Test directory structure differences are handled
- [ ] Write integration test that verifies both pickers can be instantiated without errors
- [ ] Update `lua/neotex/plugins/ai/README.md` to document the new `<leader>ao` picker and shared architecture
- [ ] Update `lua/neotex/plugins/ai/opencode/` README.md (create if needed) documenting the extension system
- [ ] Update `lua/neotex/plugins/ai/claude/README.md` to reference the shared picker architecture
- [ ] Verify both pickers side-by-side:
  - `<leader>ac` opens Claude picker with all categories
  - `<leader>aoc` opens OpenCode picker with all categories
  - Extension toggle works in both pickers
  - File editing works in both pickers
  - Terminal command sending works in both pickers

**Timing**: 1.5-2 hours

**Files to create/modify**:
- `lua/neotex/plugins/ai/shared/picker/config_spec.lua` - NEW: Config tests
- `lua/neotex/plugins/ai/README.md` - MODIFY: Document shared architecture
- `lua/neotex/plugins/ai/opencode/README.md` - NEW: OpenCode plugin documentation
- `lua/neotex/plugins/ai/claude/README.md` - MODIFY: Reference shared picker

**Verification**:
- All tests pass: `nvim --headless -c "lua require('plenary.test_harness').test_directory('lua/neotex/plugins/ai/shared/picker/')"`
- Both pickers open without errors
- Extension management works from both pickers
- No regressions in existing Claude picker functionality

## Testing & Validation

- [ ] **Phase 1**: Extension discovery test -- `require("neotex.plugins.ai.opencode.extensions").list_available()` returns extensions
- [ ] **Phase 2**: Claude picker regression test -- `<leader>ac` shows all categories with correct entries
- [ ] **Phase 3**: OpenCode picker functional test -- `:OpencodeCommands` shows all .opencode/ components
- [ ] **Phase 4**: Context index validation -- `jq` queries return expected results
- [ ] **Phase 5**: Extension load/unload cycle -- agents appear/disappear correctly
- [ ] **Phase 6**: Dual picker coexistence test -- both pickers work independently without interference
- [ ] **End-to-end**: Open Neovim in a test project, verify both `<leader>ac` and `<leader>aoc` work, manage extensions in both systems

## Artifacts & Outputs

- `specs/113_review_proofchecker_opencode_virtues/plans/implementation-001.md` (this plan)
- `.opencode/extensions/` directory tree with lean, formal, latex, typst extension manifests
- `.opencode/context/index.json` machine-readable context index
- `lua/neotex/plugins/ai/shared/picker/config.lua` shared picker configuration
- `lua/neotex/plugins/ai/opencode/commands/picker.lua` OpenCode commands picker
- Updated which-key.lua with `<leader>aoc` keymap
- Updated README files for ai/, claude/, and opencode/ directories
- `specs/113_review_proofchecker_opencode_virtues/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

- **Phase 2 rollback**: If parameterizing the picker proves too invasive, an alternative approach is to create a standalone OpenCode picker that copies the Claude picker code with `.opencode/` paths. This increases duplication but reduces risk of regressions. The shared picker infrastructure can be revisited in a future task.
- **Phase 5 rollback**: If extension reorganization causes issues, agents can remain in flat structure. The extension system works independently of reorganization.
- **General rollback**: All changes are in new files or additive modifications. Git revert of the implementation commits restores the original state.
