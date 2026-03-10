# Implementation Plan: Verify and Revise Agent System Loaders

- **Task**: 167 - Verify and revise agent system loaders for .claude/ and .opencode/
- **Status**: [NOT STARTED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

The agent system loaders (`<leader>ac` for .claude/, `<leader>ao` for .opencode/) have four categories of issues: (1) incomplete symlink strategy leaving 25 extension agents, 5 rules, 7 commands, and all extension context directories absent from core sync; (2) a filetypes extension manifest bug with an incorrect context path prefix; (3) a double-confirmation dialog bug when loading extensions into projects that already received files via core sync; and (4) 8 missing README/utility files in .opencode/ sync. The plan eliminates symlinks by making core directories the single source of truth, fixes the manifest bug, merges the double-question into a single dialog, and ensures both .claude/ and .opencode/ systems are consistent.

### Research Integration

Research report 001 confirmed the sync mechanism works correctly and identified the .opencode/ missing files as a scanner pattern gap. Report 002 identified the symlink incompleteness (only 2/27 agents symlinked), the filetypes manifest bug, and the double-question root cause (two sequential `vim.fn.confirm()` calls in `shared/extensions/init.lua`). Both reports inform the phased approach below.

## Goals & Non-Goals

**Goals**:
- Eliminate all symlinks from .claude/ core directories by copying extension artifacts into core
- Make core directories (.claude/agents/, .claude/skills/, etc.) the single source of truth
- Fix the filetypes extension manifest context path bug
- Merge the double-confirmation dialog into a single dialog for extension loading
- Ensure .opencode/ core directories mirror the same completeness as .claude/
- Update all internal path references from extension paths to core paths
- Maintain the extension picker's ability to list and describe extensions (keep manifest.json metadata)

**Non-Goals**:
- Removing the extensions/ directory entirely (manifests remain for metadata)
- Rewriting the extension loader architecture (only the conflict dialog changes)
- Modifying the core sync logic in sync.lua (it already globs core directories correctly)
- Changing the Vision project's loaded extensions (they work correctly post-fix)

## Risks & Mitigations

- **Risk**: Dual-source divergence if extension files are edited in extensions/ instead of core. **Impact**: H. **Likelihood**: M. **Mitigation**: Remove actual files from extensions/ subdirectories after copying to core; only manifest.json remains. Add a comment in each manifest.json noting that artifacts live in core directories.

- **Risk**: Breaking extension picker functionality by removing extension files. **Impact**: H. **Likelihood**: L. **Mitigation**: Update the extension loader to resolve artifact paths from core directories using the manifest's file list. Test picker load/unload cycle after changes.

- **Risk**: Incorrect path references after migration. **Impact**: M. **Likelihood**: M. **Mitigation**: Use grep to find all `extensions/{ext}/` path references and update systematically. Verify with a test load into a clean directory.

- **Risk**: .opencode/ inconsistency with .claude/ after changes. **Impact**: M. **Likelihood**: L. **Mitigation**: Phase 4 explicitly mirrors all .claude/ changes to .opencode/ with verification.

## Implementation Phases

### Phase 1: Fix Filetypes Manifest Bug and Double-Question Dialog [COMPLETED]

- **Goal:** Fix the two bugs that affect current functionality before the larger refactor.

- **Tasks:**
  - [ ] Fix `.claude/extensions/filetypes/manifest.json`: change `"context/project/filetypes"` to `"project/filetypes"` in the `provides.context` array
  - [ ] Fix `.opencode/extensions/filetypes/manifest.json`: apply the same context path fix
  - [ ] In `lua/neotex/plugins/ai/shared/extensions/init.lua`, merge the conflict-check dialog (lines ~176-189) into the main confirmation dialog (lines ~192-215) so only one `vim.fn.confirm()` fires per extension load
  - [ ] The merged dialog should include conflict count information when conflicts exist (e.g., "Note: N existing files will be overwritten")
  - [ ] Verify the merged dialog works by testing extension load with and without pre-existing files

- **Timing:** 1 hour

- **Files to modify:**
  - `.claude/extensions/filetypes/manifest.json` - Fix context path
  - `.opencode/extensions/filetypes/manifest.json` - Fix context path
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` - Merge double-question into single dialog

- **Verification:**
  - Open Neovim, trigger `<leader>ac`, select an extension to load -- confirm only ONE dialog appears
  - Verify filetypes manifest has correct path by inspecting JSON
  - Run `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` to confirm no load errors

---

### Phase 2: Copy Extension Artifacts into .claude/ Core Directories [COMPLETED]

- **Goal:** Move all extension-provided files from extensions/ subdirectories into the corresponding core directories, replacing symlinks with real files.

- **Tasks:**
  - [ ] Remove all existing symlinks in `.claude/agents/` (2 symlinks: z3-implementation-agent.md, z3-research-agent.md)
  - [ ] Remove all existing symlinks in `.claude/skills/` (28 skill directory symlinks)
  - [ ] Copy all 27 extension agent files from `.claude/extensions/*/agents/*.md` into `.claude/agents/`
  - [ ] Copy all 29 extension skill directories from `.claude/extensions/*/skills/*` into `.claude/skills/`
  - [ ] Copy all 5 extension rule files from `.claude/extensions/*/rules/*.md` into `.claude/rules/`
  - [ ] Copy all 7 extension command files from `.claude/extensions/*/commands/*.md` into `.claude/commands/`
  - [ ] Copy all extension context directories from `.claude/extensions/*/context/*` into `.claude/context/` preserving directory structure
  - [ ] Copy all 2 extension script files from `.claude/extensions/lean/scripts/*.sh` into `.claude/scripts/`
  - [ ] Verify no symlinks remain: `find .claude/agents .claude/skills .claude/rules .claude/commands -type l` returns empty
  - [ ] Verify file counts match research report totals (27 agents, 29 skills, 5 rules, 7 commands, 2 scripts)

- **Timing:** 1.5 hours

- **Files to modify:**
  - `.claude/agents/` - Add 25 agent files, replace 2 symlinks with real files
  - `.claude/skills/` - Replace 28 symlinks with real directories
  - `.claude/rules/` - Add 5 rule files
  - `.claude/commands/` - Add 7 command files
  - `.claude/context/` - Add extension context directories
  - `.claude/scripts/` - Add 2 script files

- **Verification:**
  - `find .claude/ -type l | wc -l` returns 0
  - `ls .claude/agents/*.md | wc -l` returns at least 31 (4 core + 27 extension)
  - `ls -d .claude/skills/skill-* | wc -l` returns at least 37 (9 core + 28 extension)
  - `ls .claude/rules/*.md | wc -l` returns at least 11 (6 core + 5 extension)
  - `ls .claude/commands/*.md | wc -l` returns at least 18 (11 core + 7 extension)

---

### Phase 3: Remove Extension Artifact Files and Update Manifests [COMPLETED]

- **Goal:** Remove duplicated files from extensions/ subdirectories so core is the single source of truth. Update manifests to reference core paths. Update the extension loader to resolve files from core.

- **Tasks:**
  - [ ] For each of the 11 extensions, remove the agents/, skills/, rules/, commands/, context/, and scripts/ subdirectories from the extension directory (keep only manifest.json and EXTENSION.md)
  - [ ] Update each manifest.json to add a `"source": "core"` field or similar marker indicating artifacts live in core directories
  - [ ] Update `lua/neotex/plugins/ai/shared/extensions/loader.lua` to resolve artifact source paths from core directories (e.g., `.claude/agents/` instead of `.claude/extensions/{ext}/agents/`) when the manifest indicates core-sourced artifacts
  - [ ] Update `lua/neotex/plugins/ai/shared/extensions/init.lua` conflict detection to account for core-sourced files
  - [ ] Grep for all `extensions/{ext}/` path references in agent files, skill SKILL.md files, and CLAUDE.md -- update to core paths (e.g., `@.claude/extensions/nvim/context/project/neovim/` becomes `@.claude/context/project/neovim/`)
  - [ ] Update `.claude/CLAUDE.md` context imports section to remove extension-specific references now that context lives in core

- **Timing:** 2 hours

- **Files to modify:**
  - `.claude/extensions/*/` - Remove artifact subdirectories, keep manifest.json and EXTENSION.md
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Support core-sourced artifact resolution
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` - Update conflict detection for core paths
  - `.claude/agents/*.md` - Update internal @-references from extension paths to core paths
  - `.claude/skills/*/SKILL.md` - Update internal @-references
  - `.claude/CLAUDE.md` - Update context imports

- **Verification:**
  - Each extension directory contains only `manifest.json` and `EXTENSION.md` (and possibly README.md)
  - `grep -r "extensions/" .claude/agents/ .claude/skills/ .claude/CLAUDE.md | grep -v ".git"` returns no hits referencing extension artifact paths
  - Extension picker can still list all 11 extensions by reading manifests
  - Loading an extension into a test directory copies files from core paths correctly

---

### Phase 4: Mirror Changes to .opencode/ [NOT STARTED]

- **Goal:** Apply the same core-directory-as-source-of-truth pattern to .opencode/, ensuring parity with .claude/.

- **Tasks:**
  - [ ] Copy all 27 extension agent files into `.opencode/agent/subagents/` (note: .opencode uses `agent/subagents/` not `agents/`)
  - [ ] Copy all extension skill directories into `.opencode/skills/`
  - [ ] Copy all 5 extension rule files into `.opencode/rules/`
  - [ ] Copy all 7 extension command files into `.opencode/commands/`
  - [ ] Copy all extension context directories into `.opencode/context/` preserving structure
  - [ ] Copy all 2 extension scripts into `.opencode/scripts/`
  - [ ] Remove artifact subdirectories from `.opencode/extensions/*/`, keeping manifest.json and EXTENSION.md
  - [ ] Update `.opencode/extensions/filetypes/manifest.json` context path (if not already fixed in Phase 1)
  - [ ] Update any `extensions/` path references in .opencode/ agent and skill files to core paths
  - [ ] Fix the 8 missing files identified in research-001: add README.md files to `agent/`, `hooks/`, `scripts/`, `systemd/`, `templates/` and add `.gitkeep`/`.placeholder` files as needed
  - [ ] Update the sync scanner patterns in `sync.lua` to include README.md files in directories that currently skip them (scripts, hooks, systemd, templates)

- **Timing:** 1.5 hours

- **Files to modify:**
  - `.opencode/agent/subagents/` - Add extension agents
  - `.opencode/skills/` - Add extension skills
  - `.opencode/rules/` - Add extension rules
  - `.opencode/commands/` - Add extension commands
  - `.opencode/context/` - Add extension context
  - `.opencode/scripts/` - Add extension scripts
  - `.opencode/extensions/*/` - Remove artifact subdirectories
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Update scanner patterns for README.md inclusion

- **Verification:**
  - `.opencode/agent/subagents/*.md` count matches `.claude/agents/*.md` count
  - `ls -d .opencode/skills/skill-* | wc -l` matches `.claude/skills/` count
  - All 8 previously missing files now exist in .opencode/ source
  - `find .opencode/ -type l | wc -l` returns 0

---

### Phase 5: Update Documentation and Verify End-to-End [NOT STARTED]

- **Goal:** Update all documentation to reflect the new core-as-source-of-truth architecture. Perform end-to-end verification of both loaders.

- **Tasks:**
  - [ ] Update `.claude/CLAUDE.md` Notes section to remove references to "extension skills located in extensions/" and document that all artifacts live in core directories
  - [ ] Update `.opencode/OPENCODE.md` (if it exists) similarly
  - [ ] Update each extension's `EXTENSION.md` to note that artifacts now live in core directories and the extension directory only contains metadata
  - [ ] Update `lua/neotex/plugins/ai/shared/extensions/` module README or inline comments to document the core-sourced architecture
  - [ ] Perform end-to-end test: load .claude/ agent system into a clean test directory using `<leader>ac` -> `[Load Core Agent System]` -- verify ALL extension artifacts are included
  - [ ] Perform end-to-end test: load .opencode/ agent system similarly using `<leader>ao`
  - [ ] Verify extension picker still works: select an extension, confirm single dialog, verify files copied correctly
  - [ ] Run `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` to confirm no runtime errors

- **Timing:** 1 hour

- **Files to modify:**
  - `.claude/CLAUDE.md` - Update architecture notes
  - `.claude/extensions/*/EXTENSION.md` - Update artifact location notes
  - `lua/neotex/plugins/ai/shared/extensions/` - Update comments/documentation

- **Verification:**
  - Documentation consistently describes core-as-source-of-truth architecture
  - No references to "symlinks" or "extensions/{ext}/agents/" remain in documentation
  - End-to-end sync produces a target directory with all expected files
  - Extension picker lists all 11 extensions and loads any one without errors
  - Both `<leader>ac` and `<leader>ao` work without double-question dialog

## Testing & Validation

- [ ] **Unit**: filetypes manifest has `"project/filetypes"` (not `"context/project/filetypes"`) in both .claude/ and .opencode/
- [ ] **Unit**: No symlinks remain in .claude/ or .opencode/ core directories (`find -type l` returns empty)
- [ ] **Unit**: Extension directories contain only manifest.json and EXTENSION.md (no artifact subdirectories)
- [ ] **Integration**: `<leader>ac` -> `[Load Core Agent System]` syncs all agents, skills, rules, commands, context, and scripts to a target directory
- [ ] **Integration**: `<leader>ao` -> `[Load Core Agent System]` syncs equivalently for .opencode/
- [ ] **Integration**: Extension picker loads a single extension with one confirmation dialog (not two)
- [ ] **Regression**: Existing Vision project .claude/ and .opencode/ directories remain functional after re-sync
- [ ] **Headless**: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` exits cleanly

## Artifacts & Outputs

- `specs/167_verify_revise_agent_system_loaders/plans/implementation-001.md` (this file)
- `specs/167_verify_revise_agent_system_loaders/summaries/implementation-summary-20260310.md` (on completion)
- Modified files in `.claude/`, `.opencode/`, and `lua/neotex/plugins/ai/shared/extensions/`

## Rollback/Contingency

All changes are to tracked files in the nvim configuration repository. If the implementation introduces regressions:

1. `git stash` or `git checkout -- .claude/ .opencode/ lua/neotex/plugins/ai/` to revert all changes
2. The symlinks can be recreated from extension source files if needed
3. Vision project extensions are independently tracked in `extensions.json` and can be reloaded

The implementation is designed to be phase-independent: each phase can be committed and tested separately. If a later phase fails, earlier phases remain valid.
