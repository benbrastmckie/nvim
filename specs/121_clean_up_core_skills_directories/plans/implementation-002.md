# Implementation Plan: Clean Up Core Skills Directories

- **Task**: 121 - clean_up_core_skills_directories
- **Date**: 2026-03-03 (Revised)
- **Feature**: Remove extension artifacts from core directories and simplify sync.lua
- **Status**: [NOT STARTED]
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**:
  - [research-001.md](../reports/research-001.md) - Contamination inventory across all artifact types
  - [research-002.md](../reports/research-002.md) - Clean-source architecture and sync.lua simplification
  - [research-003.md](../reports/research-003.md) - Safety verification, feature parity, context reconciliation

## Overview

Extension-specific artifacts contaminate the `.opencode/` source directories and the `~/.config/.claude/` target directory, violating the core/extension disjointness invariant. The `.claude/` source is already clean. This plan removes extension artifacts from core directories, reconciles context directories (including copying missing `hooks/` to `.opencode/`), and simplifies sync.lua by removing the now-unnecessary extension filter machinery (~130 lines). After cleanup, "Load Core Agent System" becomes a simple full-directory copy with no extension filtering needed.

**Note**: The `CONTEXT_EXCLUDE_PATTERNS` mechanism in sync.lua is PRESERVED. This filters repository-specific files (project-overview.md, self-healing-implementation-details.md) during sync - a distinct purpose from extension filtering.

### Research Integration

Three research reports inform this plan:
- **Research-001**: Identified 25 contaminated artifacts in `.opencode/` (11 skills, 9 agents, 3 commands, 2 rules) and 8 in `~/.config/.claude/` (3 skills, 3 agents, 1 command, 1 rule). Root cause: pre-task-118 syncs without filtering.
- **Research-002**: Confirmed `.claude/` source is already clean while `.opencode/` is contaminated. Recommended clean-source-first approach, then simplify sync.lua by removing filter code.
- **Research-003**: Safety verified (all core copies have newer extension copies). Identified 6 contaminated context directories in `.opencode/context/project/`, with typst/ having 5 files not in extension copy. Confirmed `code-reviewer-agent.md` is a legitimate core agent. Confirmed `CONTEXT_EXCLUDE_PATTERNS` must be preserved.

## Goals and Non-Goals

**Goals**:
- Achieve clean source directories: core artifacts ONLY in core dirs, extension artifacts ONLY in `extensions/{name}/`
- Remove 25 contaminated artifacts from `.opencode/` source directories
- Remove 6 contaminated context directories from `.opencode/context/project/`
- Remove 8 contaminated artifacts from `~/.config/.claude/` target directory
- Copy missing `hooks/` context directory from `.claude/` to `.opencode/`
- Simplify sync.lua by removing ~130 lines of extension filter code
- Preserve `CONTEXT_EXCLUDE_PATTERNS` for filtering repository-specific files during sync

**Non-Goals**:
- Modifying the extension loader (already works correctly)
- Changing the picker infrastructure (already has full parity)
- Modifying `.claude/` source directories (already clean)
- Creating additional validation scripts

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Typst context files lost (5 core-only files) | Medium | High | Phase 1 reconciles context directories before any deletion |
| Other context dirs have core-only files | Medium | Medium | Phase 1 diffs ALL 6 contaminated context dirs |
| Accidentally removing code-reviewer-agent.md | High | Low | Explicit PRESERVE marker in Phase 2 checklist |
| CONTEXT_EXCLUDE_PATTERNS accidentally removed with filter code | High | Low | Phase 4 explicitly preserves this constant and its usage |
| Active Claude sessions affected by ~/.config/.claude/ cleanup | Medium | Low | Phase 3 targets only stale extension artifacts, not core |

## Implementation Phases

### Phase 1: Context Directory Reconciliation [COMPLETED]

**Goal**: Ensure no files are lost before deleting contaminated context directories from `.opencode/context/project/`, and copy the missing `hooks/` directory.

**Tasks**:
- [ ] Diff `.opencode/context/project/typst/` against `extensions/typst/context/project/typst/` to identify the 5 core-only files
- [ ] Copy any core-only typst files to `extensions/typst/context/project/typst/` (also copy to `.claude/extensions/typst/context/project/typst/` for parity)
- [ ] Diff `.opencode/context/project/latex/` against `extensions/latex/context/project/latex/`
- [ ] Diff `.opencode/context/project/lean4/` against `extensions/lean/context/project/lean4/`
- [ ] Diff `.opencode/context/project/logic/` against `extensions/formal/context/project/logic/`
- [ ] Diff `.opencode/context/project/math/` against `extensions/formal/context/project/math/`
- [ ] Diff `.opencode/context/project/web/` against `extensions/web/context/project/web/`
- [ ] For each dir: copy any core-only files to the extension copy (both `.opencode/extensions/` and `.claude/extensions/`)
- [ ] Verify all files now exist in extension copies before proceeding
- [ ] Copy `.claude/context/project/hooks/` to `.opencode/context/project/hooks/` (missing directory)

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/extensions/typst/context/project/typst/` - receive reconciled files
- `.claude/extensions/typst/context/project/typst/` - receive reconciled files (parity)
- `.opencode/context/project/hooks/` - NEW directory, copy from `.claude/`
- Potentially other extension context directories if core-only files found

**Verification**:
- For each of the 6 contaminated dirs, confirm the extension copy has >= the file count of the core copy
- No core-only files remain unaccounted for
- `.opencode/context/project/hooks/` exists and matches `.claude/context/project/hooks/`

---

### Phase 2: Clean .opencode/ Source Directories [COMPLETED]

**Goal**: Remove all extension-owned artifacts from `.opencode/` core directories, establishing the clean-source invariant.

**Tasks**:
- [ ] Remove 9 extension agents from `.opencode/agent/subagents/`:
  - document-converter-agent.md (document-converter ext)
  - latex-implementation-agent.md (latex ext)
  - latex-research-agent.md (latex ext)
  - lean-implementation-agent.md (lean ext)
  - lean-research-agent.md (lean ext)
  - logic-research-agent.md (formal ext)
  - math-research-agent.md (formal ext)
  - typst-implementation-agent.md (typst ext)
  - typst-research-agent.md (typst ext)
  - **PRESERVE**: code-reviewer-agent.md (legitimate core agent)
- [ ] Remove 11 extension skill directories from `.opencode/skills/`:
  - skill-document-converter (document-converter ext)
  - skill-lake-repair (lean ext)
  - skill-latex-implementation (latex ext)
  - skill-latex-research (latex ext)
  - skill-lean-implementation (lean ext)
  - skill-lean-research (lean ext)
  - skill-lean-version (lean ext)
  - skill-logic-research (formal ext)
  - skill-math-research (formal ext)
  - skill-typst-implementation (typst ext)
  - skill-typst-research (typst ext)
- [ ] Remove 3 extension commands from `.opencode/commands/`:
  - convert.md (document-converter ext)
  - lake.md (lean ext)
  - lean.md (lean ext)
- [ ] Remove 2 extension rules from `.opencode/rules/`:
  - latex.md (latex ext)
  - lean4.md (lean ext)
- [ ] Remove 6 contaminated context directories from `.opencode/context/project/`:
  - project/latex/ (latex ext)
  - project/lean4/ (lean ext)
  - project/logic/ (formal ext)
  - project/math/ (formal ext)
  - project/typst/ (typst ext)
  - project/web/ (web ext)
- [ ] Verify post-cleanup counts:
  - `.opencode/agent/subagents/`: 7 files (6 core + code-reviewer)
  - `.opencode/skills/`: 11 directories (all core)
  - `.opencode/commands/`: 11 files (all core)
  - `.opencode/rules/`: 5 files (all core)
  - `.opencode/context/project/`: core dirs only (hooks/, neovim/, repo/)

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/agent/subagents/` - remove 9 files
- `.opencode/skills/` - remove 11 directories
- `.opencode/commands/` - remove 3 files
- `.opencode/rules/` - remove 2 files
- `.opencode/context/project/` - remove 6 directories

**Verification**:
- Count files in each directory matches expected post-cleanup counts
- `code-reviewer-agent.md` still exists
- All 11 core skills present
- All 11 core commands present

---

### Phase 3: Clean ~/.config/.claude/ Target Directory [COMPLETED]

**Goal**: Remove extension artifacts that were inadvertently synced to the `~/.config/.claude/` target directory.

**Tasks**:
- [ ] Remove 3 extension skills from `~/.config/.claude/skills/`:
  - skill-document-converter/
  - skill-latex-implementation/
  - skill-typst-implementation/
- [ ] Remove 3 extension agents from `~/.config/.claude/agents/`:
  - document-converter-agent.md
  - latex-implementation-agent.md
  - typst-implementation-agent.md
- [ ] Remove 1 extension command from `~/.config/.claude/commands/`:
  - convert.md
- [ ] Remove 1 extension rule from `~/.config/.claude/rules/`:
  - latex.md
- [ ] Verify post-cleanup counts:
  - `~/.config/.claude/skills/`: 11 directories (all core)
  - `~/.config/.claude/agents/`: 6 files (all core)
  - `~/.config/.claude/commands/`: 11 files (all core)
  - `~/.config/.claude/rules/`: 6 files (all core)

**Timing**: 15 minutes

**Files to modify**:
- `~/.config/.claude/skills/` - remove 3 skill directories
- `~/.config/.claude/agents/` - remove 3 agent files
- `~/.config/.claude/commands/` - remove 1 command file
- `~/.config/.claude/rules/` - remove 1 rule file

**Verification**:
- Count files in each directory matches expected post-cleanup counts
- All core artifacts still present

---

### Phase 4: Simplify sync.lua [COMPLETED]

**Goal**: Remove the extension filter machinery from sync.lua (~130 lines) since clean source directories make it unnecessary. Preserve `CONTEXT_EXCLUDE_PATTERNS` and its usage.

**Tasks**:
- [ ] Read current sync.lua to confirm line numbers from research
- [ ] Remove `build_extension_exclusions()` function (lines ~24-107, ~84 lines)
- [ ] Remove `filter_extension_files()` function (lines ~114-126, ~13 lines)
- [ ] Remove `filter_extension_skills()` function (lines ~132-152, ~21 lines)
- [ ] Remove `filter_extension_context()` function (lines ~159-188, ~30 lines)
- [ ] Remove all filter call sites in `scan_all_artifacts()`:
  - Remove `local exclusions = build_extension_exclusions(...)` call
  - Remove `filter_extension_files(agents, ...)` call
  - Remove `filter_extension_files(commands, ...)` call
  - Remove `filter_extension_files(rules, ...)` call
  - Remove `filter_extension_files(scripts, ...)` call
  - Remove `filter_extension_files(hooks, ...)` call
  - Remove `filter_extension_skills(skills, ...)` call
  - Remove `filter_extension_context(context_files, ...)` call
- [ ] **PRESERVE**: `CONTEXT_EXCLUDE_PATTERNS` constant (lines ~15-18)
- [ ] **PRESERVE**: The `exclude_patterns` parameter usage in `scan_directory_for_sync()` call for context
- [ ] **PRESERVE**: The `exclude_patterns` parameter in `scan.scan_directory_for_sync()` function signature in scan.lua
- [ ] Remove unused local variable declarations or requires related to extension filtering (e.g., manifest module import if only used by filters)
- [ ] Verify sync.lua has no syntax errors by checking Lua parse

**Timing**: 45 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - remove ~130 lines of filter code and ~8 call sites

**Verification**:
- sync.lua parses without errors: `luacheck sync.lua` or `lua -c sync.lua`
- `CONTEXT_EXCLUDE_PATTERNS` still present and used
- `build_extension_exclusions`, `filter_extension_files`, `filter_extension_skills`, `filter_extension_context` no longer defined
- No dangling references to removed functions

---

### Phase 5: Testing [NOT STARTED]

**Goal**: Verify the full system works correctly after cleanup.

**Tasks**:
- [ ] Test "Load Core Agent System" for Claude:
  - Create a temporary test directory
  - Run sync operation via `nvim --headless` with Claude config
  - Verify only core artifacts are copied (no extension artifacts)
  - Verify project-overview.md is NOT copied (CONTEXT_EXCLUDE_PATTERNS working)
  - Clean up test directory
- [ ] Test "Load Core Agent System" for OpenCode:
  - Same as above with OpenCode config
  - Verify only core artifacts are copied
  - Verify project-overview.md is NOT copied
  - Clean up test directory
- [ ] Verify artifact counts match expected post-cleanup values:
  - `.opencode/agent/subagents/`: 7 (6 core + code-reviewer)
  - `.opencode/skills/`: 11
  - `.opencode/commands/`: 11
  - `.opencode/rules/`: 5
  - `.opencode/context/project/`: 3 dirs (hooks/, neovim/, repo/)
  - `.claude/agents/`: 6
  - `.claude/skills/`: 11
  - `.claude/commands/`: 11
  - `.claude/rules/`: 6

**Timing**: 30 minutes

**Verification**:
- "Load Core Agent System" sync test produces only core artifacts
- `CONTEXT_EXCLUDE_PATTERNS` prevents project-overview.md from being copied
- No extension artifacts in any core directory

## Testing and Validation

- [ ] Phase 1: All 6 contaminated context dirs have extension copies >= core file count
- [ ] Phase 1: `.opencode/context/project/hooks/` exists and matches `.claude/`
- [ ] Phase 2: `.opencode/` core directories contain ONLY core artifacts (count verification)
- [ ] Phase 3: `~/.config/.claude/` directories contain ONLY core artifacts (count verification)
- [ ] Phase 4: sync.lua parses without errors; CONTEXT_EXCLUDE_PATTERNS preserved
- [ ] Phase 5: "Load Core Agent System" sync test produces only core artifacts
- [ ] Phase 5: project-overview.md is excluded during sync (CONTEXT_EXCLUDE_PATTERNS working)
- [ ] End-to-end: `code-reviewer-agent.md` preserved in `.opencode/`
- [ ] End-to-end: No extension artifacts in any core directory across all 3 trees

## Artifacts and Outputs

- `specs/121_clean_up_core_skills_directories/plans/implementation-002.md` (this file)
- `specs/121_clean_up_core_skills_directories/summaries/implementation-summary-20260303.md` (on completion)
- Modified `sync.lua` with ~130 lines of filter code removed

## Rollback/Contingency

All removed artifacts have authoritative copies in their extension directories (verified in research-003). If cleanup causes issues:

1. **Restore individual artifacts**: Copy from `extensions/{name}/{category}/{artifact}` back to the core directory
2. **Restore sync.lua**: Use `git checkout` to restore the filter functions if sync behavior regresses
3. **Full rollback**: `git revert` the cleanup commit(s) to restore all removed files

The extension copies are all newer (Mar 2) than the core copies (Feb 27), so restoring from extension copies would actually provide more up-to-date versions.
