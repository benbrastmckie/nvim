# Implementation Plan: Task #99 - Simplified Extension Architecture

- **Task**: 99 - review_agent_systems_core_extensions
- **Status**: [COMPLETED]
- **Effort**: 10-14 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md), [research-003.md](../reports/research-003.md), [research-004.md](../reports/research-004.md)
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Implement a file-copy-based extension system for the `.claude/` agent infrastructure. The core agent system (managed via `<leader>ac` Load All) remains unchanged. Extensions live at `.claude/extensions/{name}/` in the global source directory (`~/.config/nvim/.claude/extensions/`) and are loaded into target repos by copying files into the target's `.claude/` directory. Each extension contains a `manifest.json` declaring its files and merge targets, plus standard `.claude/` subdirectories. The `<leader>ac` picker gains an `[Extensions]` section for visibility, and a new `<leader>ae` keybinding provides dedicated extension management with toggle, reload, and detail inspection. Extension state in the target repo is tracked via `.claude/extensions.json`.

### Research Integration

- research-001.md: Identified 22 missing features across ProofChecker and Theory; classified into core infrastructure vs domain extensions; established the core + extensions architectural model
- research-002.md: Validated file-copying approach using existing sync.lua infrastructure; rejected symlinks; designed manifest schema and registry tracking
- research-003.md: Explored Claude Code native plugin system; rejected due to maintenance overhead and gaps in rules/context support
- research-004.md (AUTHORITATIVE): Finalized simplified extension architecture with dual picker integration, CLAUDE.md section markers, settings fragment deep-merge, pre-built index entries, and extension state tracking via extensions.json

## Goals & Non-Goals

**Goals**:
- Create extension manifest schema (`manifest.json`) and directory structure convention
- Build extension loader/unloader engine as Lua modules reusing existing sync.lua patterns
- Enhance `<leader>ac` picker with `[Extensions]` section showing available extensions with active/inactive status
- Create dedicated `<leader>ae` extension management picker with toggle, reload, and detail inspection
- Implement file merge strategies for CLAUDE.md sections, settings.json fragments, and index.json entries
- Build extension state tracking via `.claude/extensions.json` in target repos
- Create initial extension packs: lean, neovim, latex

**Non-Goals**:
- Claude Code native plugin system integration (explicitly rejected)
- Symlink-based extension loading (explicitly rejected)
- Automatic extension detection based on project content
- Extension dependency resolution across multiple extensions (defer to future work)
- Migration of existing core files to extensions (separate task after extension system is working)
- Marketplace or distribution system

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| File conflicts between extensions providing same-named artifacts | High | Low | Manifest validation on load; prefix convention per extension; warn and skip on conflict |
| CLAUDE.md section markers corrupted by manual editing | Medium | Medium | Validate marker pairs before operations; fall back to manual cleanup instructions |
| Settings merge creates invalid JSON | High | Low | Backup original before merge; validate JSON after merge; rollback on failure |
| Extension files modified locally, then overwritten on update | Medium | Medium | Checksum comparison on update; warn before overwriting modified files |
| Sync.lua refactoring breaks existing Load All functionality | High | Low | Phase 2 extracts shared helpers without modifying sync.lua public API; test Load All after changes |
| Large context directories slow extension loading | Low | Low | Extension loading is a one-time copy; manifest declares expected file count |
| Picker entry rendering inconsistent with existing categories | Low | Medium | Follow exact pattern from entries.lua create_category_entries functions |

## Implementation Phases

### Phase 1: Extension Manifest Schema and Directory Structure [COMPLETED]

**Goal:** Define the extension manifest format, create the `.claude/extensions/` directory structure in the global source, and build the manifest parser module.

**Tasks:**
- [ ] Create `.claude/extensions/` directory at `~/.config/nvim/.claude/extensions/`
- [ ] Define `manifest.json` JSON schema following research-004 specification (name, version, description, language, dependencies, provides, merge_targets, mcp_servers)
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/manifest.lua` module with:
  - `M.read(extension_dir)` - Read and validate manifest.json from an extension directory
  - `M.validate(manifest)` - Validate manifest against schema (required fields, valid file references)
  - `M.list_extensions(global_dir)` - Scan extensions directory and return list of valid extensions
- [ ] Create a skeleton lean extension directory to validate the schema:
  - `.claude/extensions/lean/manifest.json` (with all provides fields)
  - Empty subdirectories: agents/, skills/, commands/, rules/, context/, scripts/, hooks/
- [ ] Write unit tests for manifest parsing in `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`

**Timing:** 1.5 hours

**Files to create:**
- `.claude/extensions/` (directory)
- `.claude/extensions/lean/manifest.json` (skeleton)
- `lua/neotex/plugins/ai/claude/extensions/manifest.lua`
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`

**Verification:**
- `manifest.lua` loads and validates the skeleton lean manifest without errors
- `list_extensions()` discovers the lean extension from the extensions directory
- Invalid manifests (missing required fields) are rejected with clear error messages
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.extensions.manifest')" -c "q"` exits cleanly

---

### Phase 2: Extension Loader Engine [COMPLETED]

**Goal:** Build the core load/unload engine that copies extension files into a target `.claude/` directory and tracks state in `extensions.json`. Reuse patterns from the existing `sync.lua` and `helpers.lua` modules.

**Tasks:**
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/init.lua` as the public API module:
  - `M.load(extension_name, opts)` - Load an extension into the current project
  - `M.unload(extension_name, opts)` - Unload an extension from the current project
  - `M.reload(extension_name, opts)` - Unload then load (picks up changes)
  - `M.get_status(extension_name)` - Return active/inactive/update-available status
  - `M.list_available()` - List all extensions from global source
  - `M.list_loaded()` - List extensions loaded in current project
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/loader.lua` with internal implementation:
  - `_copy_simple_files(manifest, source_dir, target_dir)` - Copy agents, commands, rules, scripts (using helpers.lua patterns for permission preservation)
  - `_copy_skill_dirs(manifest, source_dir, target_dir)` - Copy skill directories recursively
  - `_copy_context_dirs(manifest, source_dir, target_dir)` - Copy context directories recursively preserving structure
  - `_copy_hooks(manifest, source_dir, target_dir)` - Copy hook scripts and merge hooks.json
  - `_check_conflicts(manifest, target_dir)` - Check for existing files that would be overwritten
  - `_remove_installed_files(installed_files, installed_dirs, target_dir)` - Clean removal using tracking data
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/state.lua` for extensions.json management:
  - `M.read(project_dir)` - Read extensions.json from target project (returns empty state if not found)
  - `M.write(project_dir, state)` - Write extensions.json to target project
  - `M.mark_loaded(state, extension_name, manifest, installed_files, installed_dirs, merged_sections)` - Record loaded extension
  - `M.mark_unloaded(state, extension_name)` - Record unloaded extension
  - `M.is_loaded(state, extension_name)` - Check if extension is loaded
  - `M.get_installed_files(state, extension_name)` - Get list of installed files for unloading
- [ ] Implement user confirmation dialog before load/unload operations (reuse helpers.lua notification patterns)
- [ ] Add conflict detection: warn if target files already exist and differ from extension source

**Timing:** 2.5 hours

**Files to create:**
- `lua/neotex/plugins/ai/claude/extensions/init.lua`
- `lua/neotex/plugins/ai/claude/extensions/loader.lua`
- `lua/neotex/plugins/ai/claude/extensions/state.lua`

**Files to read (for pattern reuse, not modify):**
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - File copy patterns
- `lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua` - Permission preservation, notifications
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning patterns

**Verification:**
- Load the skeleton lean extension into a test `.claude/` directory
- Verify `extensions.json` is created with correct tracking data
- Verify files are copied to correct locations
- Unload the extension and verify all files are removed
- Verify `extensions.json` is updated to mark extension as unloaded
- Load All (existing `<leader>ac` action) still works unchanged

---

### Phase 3: Merge Engine for Shared Files [COMPLETED]

**Goal:** Implement merge strategies for files that require content merging rather than simple copying: CLAUDE.md section injection, settings.json/settings.local.json deep-merge, and index.json entry append.

**Tasks:**
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/merge.lua` with merge operations:
  - `M.inject_claudemd_section(target_path, section_content, section_id)` - Insert section between `<!-- SECTION: extension_{name} -->` markers; idempotent (skip if markers already exist)
  - `M.remove_claudemd_section(target_path, section_id)` - Remove content between markers including markers themselves
  - `M.merge_settings(target_path, fragment)` - Deep-merge settings fragment: append arrays (deduplicate), add new object keys (do not overwrite existing)
  - `M.unmerge_settings(target_path, tracked_entries)` - Remove only entries that were added by the extension
  - `M.append_index_entries(target_path, entries)` - Append entries to index.json entries array (deduplicate by path)
  - `M.remove_index_entries(target_path, path_prefix)` - Remove entries where path starts with extension's context prefix
  - `M.merge_hooks(target_hooks_path, extension_hooks)` - Merge hook event arrays from extension hooks.json into target
  - `M.unmerge_hooks(target_hooks_path, tracked_hooks)` - Remove extension-added hooks
- [ ] Implement JSON backup before merge: copy target file to `{target}.backup` before modification
- [ ] Implement JSON validation after merge: parse result to verify valid JSON before writing
- [ ] Integrate merge operations into `loader.lua` load/unload flow:
  - On load: read manifest `merge_targets`, process each merge target file
  - On unload: read `merged_sections` from extensions.json, reverse each merge operation
- [ ] Create extension support files for the lean skeleton:
  - `.claude/extensions/lean/claudemd-section.md` - CLAUDE.md section with Lean routing and skill mapping
  - `.claude/extensions/lean/settings-fragment.json` - MCP server config and permissions
  - `.claude/extensions/lean/index-entries.json` - Context index entries for Lean context files

**Timing:** 2.5 hours

**Files to create:**
- `lua/neotex/plugins/ai/claude/extensions/merge.lua`
- `.claude/extensions/lean/claudemd-section.md`
- `.claude/extensions/lean/settings-fragment.json`
- `.claude/extensions/lean/index-entries.json`

**Files to modify:**
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` - Integrate merge calls into load/unload flow

**Verification:**
- Inject a CLAUDE.md section and verify markers are present and content is correct
- Remove the section and verify CLAUDE.md is clean (no orphaned markers)
- Re-inject the same section and verify idempotent behavior (no duplicates)
- Merge a settings fragment into a test settings.json and verify arrays are appended and objects are added
- Unmerge and verify only extension-added entries are removed
- Append index entries and verify deduplication by path
- Remove index entries by prefix and verify correct entries are removed
- Backup file exists before merge operations
- Invalid JSON after merge triggers rollback to backup

---

### Phase 4: Picker UI Enhancement [COMPLETED]

**Goal:** Add an `[Extensions]` section to the existing `<leader>ac` picker for visibility, and create a dedicated `<leader>ae` picker for extension management operations.

**Tasks:**
- [ ] Add `create_extensions_entries()` function to `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`:
  - Scan available extensions from global source directory
  - Read extensions.json from current project for active/inactive status
  - Create entries with format: `  {name}  [{active|inactive}]  {description}`
  - Follow existing tree formatting pattern from other category entry creators
  - Insert `[Extensions]` section after `[Load All Artifacts]` in the entry list
- [ ] Modify `lua/neotex/plugins/ai/claude/commands/picker/init.lua`:
  - Add extensions entries to the picker's entry list (call `create_extensions_entries()`)
  - Handle Enter action on extension entries: navigate to `<leader>ae` focused on selected extension
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/picker.lua` for dedicated `<leader>ae` picker:
  - Telescope picker showing all available extensions with status indicators
  - Preview pane showing manifest details (description, version, provides, dependencies)
  - Actions:
    - Enter: Toggle extension active/inactive (runs load/unload with confirmation)
    - Tab: Multi-select for batch toggle (useful for initial setup)
    - Ctrl-i: Show detailed manifest in preview
    - Ctrl-d: Show list of installed files (from extensions.json)
    - Ctrl-r: Reload extension (unload + load)
  - Status indicators: `[active]`, `[inactive]`, `[update available]` (version comparison)
- [ ] Register `<leader>ae` keybinding in `lua/neotex/plugins/editor/which-key.lua`:
  - Add under existing `<leader>a` (ai) group
  - `{ "<leader>ae", function() require("neotex.plugins.ai.claude.extensions.picker").show() end, desc = "claude extensions", icon = "..." }`
- [ ] Add `ClaudeExtensions` user command in `lua/neotex/plugins/ai/claude/init.lua` (following ClaudeCommands pattern)

**Timing:** 2.5 hours

**Files to create:**
- `lua/neotex/plugins/ai/claude/extensions/picker.lua`

**Files to modify:**
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Add `create_extensions_entries()`
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Wire extensions entries and handle Enter action
- `lua/neotex/plugins/editor/which-key.lua` - Register `<leader>ae`
- `lua/neotex/plugins/ai/claude/init.lua` - Register `ClaudeExtensions` user command

**Verification:**
- `<leader>ac` picker shows `[Extensions]` section with available extensions and correct active/inactive status
- `<leader>ae` opens dedicated extension picker with all extensions listed
- Enter on an extension in `<leader>ae` toggles its state (runs load/unload)
- Ctrl-r reloads an extension (unload + load)
- Tab multi-selects extensions for batch operations
- Preview pane shows manifest details when extension is selected
- `[update available]` indicator appears when global manifest version exceeds loaded version
- `:ClaudeExtensions` command opens the extension picker

---

### Phase 5: Create Initial Extension Packs [COMPLETED]

**Goal:** Build complete, functional extension packs for lean, neovim, and latex by extracting domain-specific files from existing `.claude/` systems (ProofChecker for Lean, nvim for Neovim/LaTeX).

**Tasks:**
- [ ] Build `extensions/lean/` extension pack:
  - Copy agents from ProofChecker: `lean-research-agent.md`, `lean-implementation-agent.md`
  - Copy skills from ProofChecker: `skill-lean-research/`, `skill-lean-implementation/`, `skill-lake-repair/`, `skill-lean-version/`
  - Copy commands from ProofChecker: `lake.md`, `lean.md`
  - Copy rules from ProofChecker: `lean4.md`
  - Copy context from ProofChecker: `project/lean4/` (full subdirectory tree: domain/, patterns/, standards/, tools/)
  - Copy scripts from ProofChecker: `setup-lean-mcp.sh`, `verify-lean-mcp.sh`
  - Create `claudemd-section.md` with Lean language routing table and skill-agent mapping
  - Create `settings-fragment.json` targeting `settings.local.json` with `mcpServers.lean-lsp` and `permissions.allow: ["mcp__lean-lsp__*"]`
  - Create `index-entries.json` with pre-built entries for all Lean context files
  - Finalize `manifest.json` with complete `provides` and `merge_targets` sections
- [ ] Build `extensions/neovim/` extension pack:
  - Copy skills from nvim: `skill-neovim-research/`, `skill-neovim-implementation/`
  - Copy agents from nvim: `neovim-research-agent.md`, `neovim-implementation-agent.md`
  - Copy rules from nvim: `neovim-lua.md`
  - Copy context from nvim: `project/neovim/` (domain/, patterns/, standards/, tools/)
  - Create `claudemd-section.md` with Neovim language routing and skill-agent mapping
  - Create `index-entries.json` with pre-built entries for all Neovim context files
  - Create `manifest.json`
- [ ] Build `extensions/latex/` extension pack:
  - Copy skills from nvim: `skill-latex-implementation/`
  - Copy agents from nvim: `latex-implementation-agent.md`
  - Copy context from nvim: `project/latex/` (if exists)
  - Create `claudemd-section.md` with LaTeX language routing and skill-agent mapping
  - Create `index-entries.json`
  - Create `manifest.json`
- [ ] End-to-end test: load lean extension into a clean test directory, verify all files are in place, verify CLAUDE.md section exists, verify settings fragment merged, verify index entries appended
- [ ] End-to-end test: unload lean extension, verify clean removal of all files and merged content
- [ ] End-to-end test: load lean + neovim extensions, verify no conflicts, verify both CLAUDE.md sections present

**Timing:** 2.5 hours

**Files to create:**
- `.claude/extensions/lean/` (complete pack: manifest.json, agents/, skills/, commands/, rules/, context/, scripts/, hooks/, claudemd-section.md, settings-fragment.json, index-entries.json)
- `.claude/extensions/neovim/` (complete pack: manifest.json, skills/, agents/, rules/, context/, claudemd-section.md, index-entries.json)
- `.claude/extensions/latex/` (complete pack: manifest.json, skills/, agents/, context/, claudemd-section.md, index-entries.json)

**Verification:**
- Each extension pack has a valid manifest.json that passes `manifest.validate()`
- Loading lean extension copies all declared files to correct locations
- Loading lean extension injects CLAUDE.md section between correct markers
- Loading lean extension merges MCP server config into settings.local.json
- Loading lean extension appends context index entries
- Unloading lean extension cleanly removes all files and reverses all merges
- Loading multiple extensions does not cause conflicts
- Extensions.json correctly tracks all three extensions with installed_files and merged_sections

## Testing & Validation

- [ ] Unit tests: manifest.lua parses valid manifests and rejects invalid ones
- [ ] Unit tests: state.lua correctly reads/writes/updates extensions.json
- [ ] Unit tests: merge.lua handles CLAUDE.md injection/removal, settings merge/unmerge, index append/remove
- [ ] Integration test: full load/unload cycle for lean extension in isolated test directory
- [ ] Integration test: multi-extension load (lean + neovim) without conflicts
- [ ] Integration test: existing `<leader>ac` Load All functionality unchanged after modifications
- [ ] Manual test: `<leader>ac` shows `[Extensions]` section with correct status indicators
- [ ] Manual test: `<leader>ae` opens extension picker, toggle works, reload works
- [ ] Headless verification: `nvim --headless -c "lua require('neotex.plugins.ai.claude.extensions')" -c "q"` exits cleanly

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/extensions/init.lua` - Public API module
- `lua/neotex/plugins/ai/claude/extensions/manifest.lua` - Manifest parser and validator
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` - File copy engine
- `lua/neotex/plugins/ai/claude/extensions/state.lua` - Extension state tracking
- `lua/neotex/plugins/ai/claude/extensions/merge.lua` - Shared file merge strategies
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Dedicated extension picker
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` - Unit tests
- `.claude/extensions/lean/` - Complete Lean extension pack
- `.claude/extensions/neovim/` - Complete Neovim extension pack
- `.claude/extensions/latex/` - Complete LaTeX extension pack
- Modified: `entries.lua`, `picker/init.lua`, `which-key.lua`, `claude/init.lua`

## Rollback/Contingency

- All new code is in the new `extensions/` module directory; removing it reverts to the current system
- Modifications to existing files (`entries.lua`, `picker/init.lua`, `which-key.lua`, `init.lua`) are additive (new entries, new keybindings) and can be reverted by removing the added lines
- The existing `<leader>ac` Load All functionality is not modified, only extended with a new category
- Extension packs in `.claude/extensions/` are self-contained and can be deleted without affecting core
- If merge operations corrupt CLAUDE.md or settings.json, backup files (`.backup`) are available for restoration
