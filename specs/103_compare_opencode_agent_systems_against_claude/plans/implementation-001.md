# Implementation Plan: Task #103

- **Task**: 103 - Create parallel .opencode/extensions/ system with web/ extension
- **Status**: [NOT STARTED]
- **Effort**: 8-10 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a fully parallel `.opencode/extensions/` system that mirrors the architecture of `.claude/extensions/`, accessible via `<leader>ao` keybindings in Neovim. The first extension will be `web/` (Astro, Tailwind CSS v4, Cloudflare), extracted from the existing inline context in `.opencode/context/project/web/`. A shared Lua base module will be created to avoid maintaining two independent codebases for the claude and opencode extension loaders.

### Research Integration

Research-001 established that the `.claude` system is the most mature (284 files, 5 extensions, structured JSON index, model enforcement) and recommended porting its extensions architecture to `.opencode`. Research-002 provided a deep-dive into the 6-module extension architecture (init, loader, manifest, merge, state, picker), confirmed `<leader>ao` is available for opencode extension management, mapped the web domain content for extraction, and estimated 60-95% code reuse across modules.

## Goals & Non-Goals

**Goals**:
- Create `.opencode/extensions/` directory structure with manifest.json schema
- Extract web domain content into a standalone `web/` extension with manifest
- Build shared Lua extension base module parameterized for both claude and opencode
- Refactor existing `.claude` extension Lua modules to use the shared base
- Create Telescope picker and `OpencodeExtensions` vim command under `<leader>ao`
- Port all 5 existing `.claude` extensions (lean, latex, typst, z3, python) to `.opencode` format

**Non-Goals**:
- Modifying the existing `.claude/extensions/` directory contents (agents, skills, context files)
- Implementing opencode-specific plugin system integration (`@opencode-ai/plugin`)
- Creating a structured JSON context index for `.opencode` (separate task)
- Adding model enforcement to opencode agent frontmatter (separate task)
- Changing the opencode runtime behavior or settings.json schema

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Shared base module introduces regressions in claude extensions | High | Medium | Validate claude extension load/unload still works after refactor via headless Neovim tests |
| opencode agent frontmatter differences cause manifest incompatibility | Medium | Low | Use same manifest.json schema; frontmatter lives in agent .md files, not manifests |
| Telescope picker module has claude-specific assumptions | Medium | Medium | Audit picker.lua for hardcoded paths before creating shared base |
| Moving web/ content to extension breaks existing opencode workflows | Medium | Medium | Keep inline copies as fallback during migration; only remove after validation |
| merge.lua section injection assumes CLAUDE.md format | Medium | High | Parameterize section markers and target file paths in shared base |

## Implementation Phases

### Phase 1: Extension Directory Structure and Web Extension [NOT STARTED]

**Goal**: Create the `.opencode/extensions/` directory with the `web/` extension as the first domain extension, including manifest, agents, and context files.

**Tasks**:
- [ ] Create `.opencode/extensions/` directory at `~/.config/nvim/.opencode/extensions/`
- [ ] Create `.opencode/extensions/web/manifest.json` with provides, merge_targets, and metadata
- [ ] Create `.opencode/extensions/web/EXTENSION.md` with OPENCODE.md section content for web development routing
- [ ] Copy `~/.config/nvim/.opencode/agents/web-research.md` to `.opencode/extensions/web/agents/web-research.md`
- [ ] Copy `~/.config/nvim/.opencode/agents/web-implementation.md` to `.opencode/extensions/web/agents/web-implementation.md`
- [ ] Copy skill directories for web (if they exist as `skill-web-research/`, `skill-web-implementation/`) to `.opencode/extensions/web/skills/`
- [ ] Copy `~/.config/nvim/.opencode/context/project/web/` tree to `.opencode/extensions/web/context/project/web/`
- [ ] Validate manifest.json has all required fields (name, version, description, language, provides, merge_targets)

**Timing**: 1.5 hours

**Files to create**:
- `.opencode/extensions/web/manifest.json` - Extension manifest
- `.opencode/extensions/web/EXTENSION.md` - Section for OPENCODE.md injection
- `.opencode/extensions/web/agents/web-research.md` - Web research agent
- `.opencode/extensions/web/agents/web-implementation.md` - Web implementation agent
- `.opencode/extensions/web/skills/` - Web skill directories (if applicable)
- `.opencode/extensions/web/context/project/web/**` - Full web context tree

**Verification**:
- `manifest.json` parses as valid JSON with all required fields
- All files listed in `provides` exist in the extension directory
- Directory structure mirrors `.claude/extensions/lean/` pattern

---

### Phase 2: Shared Lua Extension Base Module [NOT STARTED]

**Goal**: Create a shared, parameterized Lua module that both the claude and opencode extension systems can use, avoiding code duplication across the two systems.

**Tasks**:
- [ ] Read all 6 existing claude extension modules to identify parameterizable paths and config
- [ ] Create `lua/neotex/plugins/ai/shared/extensions/` directory
- [ ] Create `shared/extensions/config.lua` - Configuration schema (base_dir, config_file, section_prefix, state_file, global_extensions_dir)
- [ ] Create `shared/extensions/manifest.lua` - Manifest parsing and validation (parameterized by global_extensions_dir)
- [ ] Create `shared/extensions/loader.lua` - File copy engine (parameterized by base_dir target)
- [ ] Create `shared/extensions/merge.lua` - Reversible merge strategies (parameterized by config_file, section_prefix)
- [ ] Create `shared/extensions/state.lua` - State tracking via extensions.json (parameterized by state_file path)
- [ ] Create `shared/extensions/init.lua` - Public API: load, unload, reload, list_available, get_details

**Timing**: 2 hours

**Files to create**:
- `lua/neotex/plugins/ai/shared/extensions/config.lua`
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua`
- `lua/neotex/plugins/ai/shared/extensions/loader.lua`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- `lua/neotex/plugins/ai/shared/extensions/state.lua`
- `lua/neotex/plugins/ai/shared/extensions/init.lua`

**Verification**:
- All modules load without error: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"`
- Config schema accepts both claude and opencode parameter sets
- Public API functions exist and accept config parameter

---

### Phase 3: Refactor Claude Extensions to Use Shared Base [NOT STARTED]

**Goal**: Refactor the existing 6 claude extension Lua modules to delegate to the shared base, confirming no regressions in claude extension load/unload behavior.

**Tasks**:
- [ ] Create claude-specific config in `lua/neotex/plugins/ai/claude/extensions/config.lua` with paths: `.claude/`, `CLAUDE.md`, `extension_`, `extensions.json`, global extensions dir
- [ ] Refactor `claude/extensions/init.lua` to instantiate shared base with claude config
- [ ] Refactor `claude/extensions/manifest.lua` to delegate to shared manifest module
- [ ] Refactor `claude/extensions/loader.lua` to delegate to shared loader module
- [ ] Refactor `claude/extensions/merge.lua` to delegate to shared merge module
- [ ] Refactor `claude/extensions/state.lua` to delegate to shared state module
- [ ] Preserve `claude/extensions/picker.lua` as-is (will be parameterized in Phase 4)
- [ ] Test claude extension load/unload for at least one extension (lean or latex) via headless Neovim

**Timing**: 2 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/extensions/init.lua` - Delegate to shared base
- `lua/neotex/plugins/ai/claude/extensions/manifest.lua` - Delegate to shared base
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` - Delegate to shared base
- `lua/neotex/plugins/ai/claude/extensions/merge.lua` - Delegate to shared base
- `lua/neotex/plugins/ai/claude/extensions/state.lua` - Delegate to shared base

**Files to create**:
- `lua/neotex/plugins/ai/claude/extensions/config.lua` - Claude-specific configuration

**Verification**:
- `nvim --headless -c "lua local ext = require('neotex.plugins.ai.claude.extensions'); print(vim.inspect(ext.list_available()))" -c "q"` returns available extensions
- ClaudeExtensions command still opens Telescope picker
- Load/unload cycle for one extension produces no errors
- `extensions.json` state file is correctly written and read

---

### Phase 4: OpenCode Extension Lua Modules and Telescope Picker [NOT STARTED]

**Goal**: Create the opencode extension Lua modules using the shared base, register the `OpencodeExtensions` vim command, create the Telescope picker, and wire up `<leader>ao` which-key bindings.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/opencode/extensions/` directory
- [ ] Create `opencode/extensions/config.lua` with paths: `.opencode/`, `OPENCODE.md` (or target config), `extension_oc_`, `extensions.json`, global extensions dir
- [ ] Create `opencode/extensions/init.lua` that instantiates shared base with opencode config and exposes public API
- [ ] Create `opencode/extensions/picker.lua` adapted from claude picker with opencode branding (title, icons, paths)
- [ ] Register `OpencodeExtensions` vim command in the opencode plugin init module (either `opencode.lua` or a new `lua/neotex/plugins/ai/opencode/init.lua`)
- [ ] Add `<leader>ao` which-key group with subkeys:
  - `<leader>aoe` - OpencodeExtensions picker
  - `<leader>aoc` - OpencodeCommands picker (placeholder if no commands picker exists yet)
- [ ] Test that `OpencodeExtensions` command opens picker showing `web` extension as available

**Timing**: 2 hours

**Files to create**:
- `lua/neotex/plugins/ai/opencode/extensions/config.lua` - OpenCode configuration
- `lua/neotex/plugins/ai/opencode/extensions/init.lua` - OpenCode extension API
- `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Telescope picker for opencode

**Files to modify**:
- `lua/neotex/plugins/ai/opencode.lua` (or equivalent init) - Register OpencodeExtensions command
- `lua/neotex/plugins/editor/which-key.lua` - Add `<leader>ao` group and bindings

**Verification**:
- `nvim --headless -c "lua local ext = require('neotex.plugins.ai.opencode.extensions'); print(vim.inspect(ext.list_available()))" -c "q"` shows `web` extension
- `:OpencodeExtensions` command exists and is callable
- `<leader>ao` group appears in which-key popup
- `<leader>aoe` opens the opencode extensions picker

---

### Phase 5: Port Claude Extensions to OpenCode Format [NOT STARTED]

**Goal**: Create opencode-format versions of the 5 existing claude extensions (lean, latex, typst, z3, python) in `.opencode/extensions/`, adapting agent frontmatter to include opencode-specific fields (tools, permissions, temperature).

**Tasks**:
- [ ] Create `.opencode/extensions/lean/` with manifest.json, EXTENSION.md, agents (lean-research, lean-implementation), context, and rules
- [ ] Adapt lean agents to include opencode frontmatter (tools, permissions, temperature, mode fields from Logos .opencode pattern)
- [ ] Create `.opencode/extensions/latex/` with manifest.json, EXTENSION.md, agents (latex-research, latex-implementation), context, and rules
- [ ] Adapt latex agents to include opencode frontmatter
- [ ] Create `.opencode/extensions/typst/` with manifest.json, EXTENSION.md, agents (typst-research, typst-implementation), and context
- [ ] Adapt typst agents to include opencode frontmatter
- [ ] Create `.opencode/extensions/z3/` with manifest.json, EXTENSION.md, agents (z3-research, z3-implementation), and context
- [ ] Adapt z3 agents to include opencode frontmatter
- [ ] Create `.opencode/extensions/python/` with manifest.json, EXTENSION.md, agents (python-research, python-implementation), and context
- [ ] Adapt python agents to include opencode frontmatter
- [ ] Validate all 6 extensions (including web) appear in OpencodeExtensions picker

**Timing**: 2 hours

**Files to create**:
- `.opencode/extensions/lean/manifest.json` and supporting files (agents/, context/, rules/)
- `.opencode/extensions/latex/manifest.json` and supporting files
- `.opencode/extensions/typst/manifest.json` and supporting files
- `.opencode/extensions/z3/manifest.json` and supporting files
- `.opencode/extensions/python/manifest.json` and supporting files

**Verification**:
- All 6 extension manifests parse as valid JSON
- `nvim --headless -c "lua local ext = require('neotex.plugins.ai.opencode.extensions'); local avail = ext.list_available(); print(#avail)" -c "q"` returns 6
- Each extension's `provides` files exist in their respective directories
- Agent frontmatter in opencode extensions includes tools, permissions, and temperature fields

## Testing & Validation

- [ ] All shared Lua modules load without error in headless Neovim
- [ ] Claude extension system continues to function after refactor (load/unload cycle test)
- [ ] OpenCode extension system can list all 6 available extensions
- [ ] OpencodeExtensions Telescope picker opens and displays extensions with status
- [ ] `<leader>ao` which-key group registers correctly
- [ ] Web extension load/unload cycle works (files copied to target, state tracked, clean unload)
- [ ] Manifest.json schema is identical between claude and opencode extensions for portability
- [ ] No Neovim startup errors after all changes

## Artifacts & Outputs

- `specs/103_compare_opencode_agent_systems_against_claude/plans/implementation-001.md` (this plan)
- `.opencode/extensions/` directory with 6 extensions (web, lean, latex, typst, z3, python)
- `lua/neotex/plugins/ai/shared/extensions/` shared base module (6 files)
- `lua/neotex/plugins/ai/opencode/extensions/` opencode extension modules (3 files)
- Modified `lua/neotex/plugins/ai/claude/extensions/` modules (5 refactored + 1 new config)
- Modified `lua/neotex/plugins/editor/which-key.lua` with `<leader>ao` group
- `specs/103_compare_opencode_agent_systems_against_claude/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

- The shared base module is additive; if it fails, revert by restoring original claude extension modules from git
- OpenCode extension modules are entirely new files; delete `lua/neotex/plugins/ai/opencode/extensions/` to revert
- `.opencode/extensions/` directory is new; delete entirely to revert
- Which-key additions can be reverted by removing the `<leader>ao` entries
- Git tags or branches can be created before Phase 3 (the refactor phase) as a safety checkpoint
