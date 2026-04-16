# Research Report: Task #437

**Task**: 437 - move_neovim_only_files_to_extension
**Started**: 2026-04-14T00:00:00Z
**Completed**: 2026-04-14T00:30:00Z
**Effort**: small
**Dependencies**: None (task 433 already completed generic project-overview work)
**Sources/Inputs**: Codebase exploration (Glob, Grep, Read)
**Artifacts**: specs/437_move_neovim_only_files_to_extension/reports/01_nvim-file-relocation.md
**Standards**: report-format.md

## Executive Summary

- 2 of 5 candidate files are 100% neovim-specific and should move to the nvim extension
- 2 files are heavily neovim-flavored but have generic structure worth preserving -- better handled via genericization (task 438)
- 1 file (`learn-usage.md`) is already in the correct extension (`memory`) and uses neovim only as example data -- task 433 scope or task 438 scope
- The `.sync-exclude` file already has audit patterns for neovim/neotex but no path exclusions yet
- No files appear in `context/index.json`, so no index entries need updating

## Context & Scope

Task 433 generalized project-overview and several orchestration/format docs. This task targets 5 remaining files that were flagged as 100% neovim-specific. The research verifies each file's neovim contamination level and recommends action.

## Findings

### File 1: `.claude/docs/guides/neovim-integration.md`

| Metric | Value |
|--------|-------|
| **Path** | `.claude/docs/guides/neovim-integration.md` |
| **Lines** | 335 |
| **nvim/neovim/neotex references** | 33 |
| **100% neovim-specific?** | **YES** |

**Content**: Documents SessionStart hook for Neovim sidebar readiness, TTS notifications with WezTerm tab detection, and STT voice input via Neovim plugin. Every section references `nvim --remote-expr`, `neotex.plugins.*` Lua modules, `:ClaudeCode` command, `<leader>` keymaps, and `~/.config/nvim/` paths.

**Recommended action**: **MOVE** to nvim extension.

**Destination**: `.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md`

**Cross-references to update** (6 locations):
1. `.claude/docs/guides/tts-stt-integration.md` line 366 -- relative link `neovim-integration.md`
2. `.claude/docs/README.md` lines 18, 56 -- guide listing and link
3. `.claude/README.md` line 188 -- link in Related Documentation

### File 2: `.claude/docs/guides/tts-stt-integration.md`

| Metric | Value |
|--------|-------|
| **Path** | `.claude/docs/guides/tts-stt-integration.md` |
| **Lines** | 366 |
| **nvim/neovim/neotex references** | 22 |
| **100% neovim-specific?** | **YES** |

**Content**: TTS portion (Piper + WezTerm hooks) is semi-generic but references `.claude/hooks/tts-notify.sh` which is project-local. STT portion is entirely Neovim-specific: `neotex.plugins.tools.stt`, `which-key.lua`, `lazy.nvim`, Neovim commands (`:STTHealth`, `:STTStart`). The "Workflow Examples" section describes WezTerm tab workflows interleaved with Neovim buffer operations.

**Recommended action**: **MOVE** to nvim extension.

**Destination**: `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`

**Cross-references to update** (5 locations):
1. `.claude/docs/guides/neovim-integration.md` lines 77, 332 -- relative links (will be co-located after move)
2. `.claude/docs/README.md` lines 19, 57 -- guide listing and link
3. `.claude/README.md` -- no direct reference (only via neovim-integration.md)

### File 3: `.claude/docs/guides/user-installation.md`

| Metric | Value |
|--------|-------|
| **Path** | `.claude/docs/guides/user-installation.md` |
| **Lines** | 327 |
| **nvim/neovim/neotex references** | 22 |
| **100% neovim-specific?** | **NO -- mixed** |

**Content analysis**: The file has a useful generic structure:
- Installing Claude Code (generic)
- Authentication (generic)
- Setting up a project with Claude Code (neovim-specific: `~/.config/nvim`, Neovim verification prompts)
- Agent commands overview (generic)
- Working with configuration (neovim-specific examples: LSP, telescope, `:Lazy sync`)
- GitHub CLI setup (generic)
- Troubleshooting (mixed: generic Claude Code issues + neovim-specific issues)

**Recommended action**: **GENERICIZE** in task 438. Replace neovim examples with generic project examples, move neovim-specific portions to extension as supplemental guide.

**Cross-references** (3 locations):
1. `.claude/docs/guides/copy-claude-directory.md` lines 3, 269, 273 -- sibling links
2. `.claude/docs/README.md` line 53 -- guide listing
3. `.claude/docs/architecture/system-overview.md` line 281 -- "Getting started" link
4. `.claude/README.md` line 186 -- link in Related Documentation

### File 4: `.claude/docs/guides/copy-claude-directory.md`

| Metric | Value |
|--------|-------|
| **Path** | `.claude/docs/guides/copy-claude-directory.md` |
| **Lines** | 273 |
| **nvim/neovim/neotex references** | 17 |
| **100% neovim-specific?** | **NO -- mixed** |

**Content analysis**: The structure is generic and valuable for any project:
- What is the .claude/ system? (generic with neovim examples in feature list)
- Prerequisites (generic)
- What to copy / What to customize (neovim-specific directory examples)
- Extension points (generic with neovim examples)
- Installation instructions for macOS/Linux/Windows (neovim paths: `~/.config/nvim`, `$LOCALAPPDATA\nvim`)
- Verification and Quick Start (neovim-specific examples: telescope, `:Lazy sync`)
- Troubleshooting (neovim-specific: `context/project/neovim/`)

**Recommended action**: **GENERICIZE** in task 438. The copy-directory concept is essential for any sync target. Replace neovim paths/examples with generic placeholders.

**Cross-references** (3 locations):
1. `.claude/docs/guides/user-installation.md` line 327 -- sibling link
2. `.claude/docs/README.md` lines 17, 55 -- guide listing and link

### File 5: `.claude/extensions/memory/context/project/memory/learn-usage.md`

| Metric | Value |
|--------|-------|
| **Path** | `.claude/extensions/memory/context/project/memory/learn-usage.md` |
| **Lines** | 300 |
| **nvim/neovim/neotex/telescope references** | 24 (12 nvim/neovim, 12 telescope) |
| **100% neovim-specific?** | **NO -- example data only** |

**Content analysis**: The file documents the `/learn` command workflow (content mapping, memory search, memory operations). The structure and logic are 100% generic. All neovim references are **example data**:
- Example file paths: `~/docs/neovim-tips.txt`, `~/notes/neovim/`
- Example segments: "Telescope picker creation"
- Example memory names: `MEM-telescope-custom-pickers`, `MEM-neovim-plugin-patterns`
- Example topics: `neovim/plugins/telescope`, `neovim/lua`

**Location**: Already in the **memory extension**, not in core `.claude/`. This is correctly placed.

**Recommended action**: **GENERICIZE examples** in task 438 (or leave as-is if examples are helpful). Replace neovim/telescope examples with generic ones (e.g., "React component patterns", "API endpoint design"). Low priority since it is already in an extension.

**Cross-references** (6 locations, all within memory extension):
1. `.claude/extensions/memory/skills/skill-memory/SKILL.md` line 21
2. `.claude/extensions/memory/context/project/memory/memory-troubleshooting.md` lines 235, 249
3. `.claude/extensions/memory/context/project/memory/memory-setup.md` line 246
4. `.claude/extensions/memory/context/project/memory/README.md` line 7
5. `.claude/extensions/memory/index-entries.json` line 4
6. `.claude/extensions/memory/README.md` line 279

### Extension Structure: `.claude/extensions/nvim/`

The nvim extension already has:
- `manifest.json` with task_type "neovim", routing, and merge_targets
- `index-entries.json` with 21 context entries (all under `project/neovim/`)
- `context/project/neovim/` with subdirectories: `domain/`, `patterns/`, `standards/`, `templates/`, `tools/`, `hooks/`
- `agents/` with neovim-research-agent and neovim-implementation-agent
- `skills/` with neovim-specific research and implementation skills
- `rules/neovim-lua.md`

There is no `guides/` subdirectory yet. The two files being moved will need a new `context/project/neovim/guides/` directory.

### `.sync-exclude` Status

The file exists at `.claude/.sync-exclude` with:
- Audit patterns for `neovim`, `neotex`, `lazy%.nvim`, `nvim%-lspconfig` (content warnings)
- No path exclusions yet

For the two files being moved, path exclusions are unnecessary since the files will no longer exist in core `.claude/docs/guides/`.

### `context/index.json` Status

None of the 5 candidate files appear in `.claude/context/index.json`. No index entry updates needed for the core index.

The nvim extension's `index-entries.json` will need 2 new entries for the moved guide files.

## Recommendations

### Phase 1: Move 2 files to nvim extension (this task, 437)

1. Create `.claude/extensions/nvim/context/project/neovim/guides/` directory
2. Move `neovim-integration.md` to extension guides dir
3. Move `tts-stt-integration.md` to extension guides dir
4. Add 2 entries to `.claude/extensions/nvim/index-entries.json`
5. Update cross-references in:
   - `.claude/docs/README.md` (remove or note as "extension-provided")
   - `.claude/README.md` (remove neovim-integration link)
   - `.claude/docs/architecture/system-overview.md` (no change needed, references user-installation not these)
6. Update internal cross-references between the two moved files (relative paths still work after co-location)

### Phase 2: Genericize 2 mixed files (task 438)

1. `user-installation.md` -- replace neovim examples with generic project examples
2. `copy-claude-directory.md` -- replace neovim paths with generic placeholders

### Phase 3: Genericize learn-usage.md examples (task 438, low priority)

Replace neovim/telescope example data with generic examples. This file is already in the memory extension so it is not a sync contamination risk.

### `.sync-exclude` additions

Add path exclusions for the docs README entries that reference extension-only guides, if those references remain as notes. Alternatively, simply remove the references during the move.

## Decisions

- Files 1 and 2 are definitively 100% neovim-specific and belong in the nvim extension
- Files 3 and 4 have valuable generic structure and should be genericized, not moved
- File 5 is already in the correct extension; its neovim examples are cosmetic, not structural
- New destination subdirectory: `context/project/neovim/guides/` (consistent with existing `domain/`, `patterns/`, `standards/`, `templates/`, `tools/`, `hooks/`)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Broken cross-references after move | Systematic grep for filenames before and after; update all 11 identified locations |
| Guides not discoverable after move to extension | Add index-entries.json entries; update docs/README.md to note extension location |
| Extension not loaded when guides needed | Guides are reference docs, not agent-critical; acceptable that they require extension load |

## Appendix

### Search queries used
- `Glob .claude/extensions/nvim/**/*` -- extension structure
- `Grep neovim-integration|tts-stt|user-installation|copy-claude-directory|learn-usage` across `.claude/` -- cross-references
- `grep -c -i 'nvim|neovim|neotex'` on each file -- reference counts
- `Read` on all 5 candidate files -- content analysis
- `Read` on `.sync-exclude`, `.syncprotect`, `manifest.json`, `index-entries.json`
- `Grep` on `context/index.json` -- verify no index entries exist

### Reference count detail

| File | Lines | nvim refs | neovim refs | neotex refs | Total |
|------|-------|-----------|-------------|-------------|-------|
| neovim-integration.md | 335 | 13 | 15 | 5 | 33 |
| tts-stt-integration.md | 366 | 2 | 10 | 10 | 22 |
| user-installation.md | 327 | 8 | 14 | 0 | 22 |
| copy-claude-directory.md | 273 | 6 | 11 | 0 | 17 |
| learn-usage.md | 300 | 0 | 12 | 0 | 12+12 telescope |
