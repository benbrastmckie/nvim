# Implementation Plan: Task #168 (Revised)

- **Task**: 168 - Fix core agent system loading and extension loader issues
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: Task 167 (move extension artifacts into core directories)
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10 (Revised)
- **Feature**: Fix broken index.json paths, loader bugs, and manifest inconsistencies while ensuring full independence of .claude and .opencode systems
- **Estimated Hours**: 4-6 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)

## Revision Notes

**Key Change**: Added explicit independence requirement for .claude and .opencode agent systems. Each system must be fully self-contained with no cross-references or shared dependencies beyond the Neovim loader code itself.

## Overview

Both research reports identified systemic issues in how the extension loader handles metadata injection. The core problems are: (1) source index-entries.json files use 3 different path prefix conventions, (2) the loader copies paths verbatim without normalization, (3) some index-entries.json use bare arrays instead of the expected `{entries: [...]}` format, (4) the epidemiology .claude manifest has a wrong merge_target_key, and (5) .claude/.opencode manifests have parity gaps. This plan fixes all issues at the source AND adds defensive normalization in the loader for belt-and-suspenders reliability.

**CRITICAL: System Independence Requirement**

The .claude and .opencode agent systems MUST remain fully independent:
- No cross-references between systems (no paths referencing the other system)
- Each system has its own complete set of agents, skills, commands, rules, context
- Extension manifests must be tailored to their respective systems
- The loader code is shared (in Neovim), but the outputs are completely independent
- A project can load either system, both systems, or neither - they operate independently

### Research Integration

Research-001 identified 77 broken paths in .claude/context/index.json and 12 in .opencode, all due to incorrect path prefixes. Research-002 traced the root cause to 3 different prefix conventions in source index-entries.json files and confirmed the loader's `append_index_entries()` function performs no path normalization. Research-002 also found 4 bare-array index-entries.json files silently skipped, a wrong manifest key in epidemiology .claude, and manifest parity gaps.

## Goals & Non-Goals

**Goals**:
- Fix all source index-entries.json files to use correct `project/` path prefix
- Fix bare-array index-entries.json files to use `{entries: [...]}` format
- Add path normalization to the loader's `append_index_entries()` function
- Fix epidemiology .claude manifest merge_target_key
- Sync .claude/.opencode manifest parity gaps
- Update core/routing.md to reflect all languages (post-merge)
- Fix extensions.json state tracking for installed_files/installed_dirs
- Add a validation script for ongoing maintenance
- **ENSURE FULL INDEPENDENCE of .claude and .opencode systems**

**Non-Goals**:
- Refactoring the entire extension loader architecture
- Adding new extensions or capabilities
- Modifying the file copy engine (works correctly per research)
- Generating project-overview.md (project-specific, not a system fix)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path normalization regex too aggressive | H | L | Test against all 22 index-entries.json files, use specific prefix patterns |
| Breaking existing working paths during normalization | H | L | Only strip known bad prefixes, keep `project/` and `core/` intact |
| Manifest parity changes break .opencode loader | M | L | Test load/unload cycle after changes |
| State tracking fix changes mark_loaded API | M | L | Keep API compatible, fix serialization only |
| **Cross-system contamination during fixes** | H | M | Audit each change for system isolation, verify no cross-references |

## Implementation Phases

### Phase 1: Audit and Ensure System Independence [NOT STARTED]

**Goal**: Before making any fixes, audit both systems to identify any cross-system references or dependencies that violate independence, and document the expected independent structure.

**Tasks**:
- [ ] Grep all .claude/ files for any reference to `.opencode` or `opencode/` paths
- [ ] Grep all .opencode/ files for any reference to `.claude` or `claude/` paths
- [ ] Document any violations found
- [ ] Create a checklist of independence requirements:
  - No cross-system path references in any config files
  - Each system's CLAUDE.md/OPENCODE.md references only its own files
  - Each system's index.json references only `project/` or `core/` (relative to itself)
  - Extension manifests use correct merge_target_key for their system
  - Context files don't reference the other system

**Timing**: 0.5 hours

**Files to audit**:
- All files under `.claude/` for `.opencode` references
- All files under `.opencode/` for `.claude` references
- Extension manifests in both systems

**Verification**:
- Grep produces no cross-system references (or documents all that need fixing)
- Independence checklist is complete and verified

---

### Phase 2: Fix Source index-entries.json Path Prefixes [NOT STARTED]

**Goal**: Normalize all 22 index-entries.json files (11 .claude + 11 .opencode) to use the correct `project/` path prefix convention. Fix each system independently.

**Tasks**:
- [ ] Fix all 11 .claude/extensions/*/index-entries.json files:
  - Strip incorrect prefixes to produce `project/{domain}/...` paths
  - Fix bare-array files to wrap in `{"entries": [...]}`
- [ ] Fix all 11 .opencode/extensions/*/index-entries.json files (independently):
  - Strip incorrect prefixes to produce `project/{domain}/...` paths
  - Fix bare-array files to wrap in `{"entries": [...]}`
- [ ] Validate every normalized path resolves to an actual file relative to its respective system's `context/` directory

**Timing**: 1.5 hours

**Files to modify (.claude)**:
- `.claude/extensions/formal/index-entries.json` - Strip `.claude/extensions/formal/context/` prefix
- `.claude/extensions/nix/index-entries.json` - Strip `.claude/extensions/nix/context/` prefix
- `.claude/extensions/web/index-entries.json` - Strip `.claude/extensions/web/context/` prefix
- `.claude/extensions/latex/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/lean/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/nvim/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/python/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/typst/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/z3/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/filetypes/index-entries.json` - Strip prefix, wrap bare array in `{entries: [...]}`
- `.claude/extensions/epidemiology/index-entries.json` - Verify (already correct)

**Files to modify (.opencode)** - treated completely independently:
- `.opencode/extensions/formal/index-entries.json` - Strip `.opencode/extensions/formal/context/` prefix
- `.opencode/extensions/nix/index-entries.json` - Strip prefix, wrap bare array in `{entries: [...]}`
- `.opencode/extensions/web/index-entries.json` - Strip prefix, wrap bare array in `{entries: [...]}`
- `.opencode/extensions/latex/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/lean/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/nvim/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/python/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/typst/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/z3/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/filetypes/index-entries.json` - Wrap bare array in `{entries: [...]}`
- `.opencode/extensions/epidemiology/index-entries.json` - Verify (already correct)

**Verification**:
- Run validation for each system separately
- All 11 .claude files parse as valid JSON with `{entries: [...]}` structure
- All 11 .opencode files parse as valid JSON with `{entries: [...]}` structure
- Zero paths start with `.claude/`, `.opencode/`, or `context/`
- Each system's paths resolve relative to its own `context/` directory

---

### Phase 3: Add Loader Path Normalization (Defense-in-Depth) [NOT STARTED]

**Goal**: Add path normalization to the shared merge module so the loader strips incorrect prefixes before appending entries. The loader is shared Neovim code but produces independent outputs.

**Tasks**:
- [ ] Add `normalize_index_path(path, system_type)` function to `shared/extensions/merge.lua` that:
  - Takes system_type parameter ("claude" or "opencode") to use correct patterns
  - Strips known bad prefixes specific to that system
  - Returns normalized `project/...` or `core/...` path
- [ ] Call normalization on each entry path before deduplication check in `append_index_entries()`
- [ ] Add bare-array fallback in `shared/extensions/init.lua`: detect when `entries_data` is an array and use it directly
- [ ] Verify normalization handles all known bad prefix patterns for each system type

**Timing**: 1 hour

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Add `normalize_index_path()`, apply in `append_index_entries()`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add bare-array fallback in `process_merge_targets()`

**Verification**:
- Unit test: pass entries with each bad prefix pattern for each system type
- Unit test: pass bare array to process_merge_targets, verify entries are processed
- Reload an extension in each system and verify index.json entries have correct paths
- Verify no cross-system references are introduced by the loader

---

### Phase 4: Fix Epidemiology Manifest and Manifest Parity [NOT STARTED]

**Goal**: Fix the epidemiology .claude manifest merge_target_key and ensure manifest parity while maintaining system independence.

**Tasks**:
- [ ] Fix `.claude/extensions/epidemiology/manifest.json`:
  - Change `opencode_md` key to `claudemd`
  - Update `target` to `.claude/CLAUDE.md`
  - Update `section_id` to `extension_epidemiology`
- [ ] Fix `.opencode/extensions/epidemiology/manifest.json` (if not already correct):
  - Ensure it uses `opencode_md` key (not claudemd)
  - Ensure `target` is `.opencode/OPENCODE.md`
- [ ] Add missing items to `.opencode/extensions/filetypes/manifest.json`:
  - `deck-agent.md` in agents
  - `skill-deck` in skills
  - `deck.md` in commands
- [ ] Add missing items to `.opencode/extensions/web/manifest.json`:
  - `skill-tag` in skills
  - `tag.md` in commands
- [ ] Verify the actual files exist in both systems (copy if needed to maintain independence)

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/epidemiology/manifest.json` - Fix merge_target_key
- `.opencode/extensions/epidemiology/manifest.json` - Verify correct (independent from .claude)
- `.opencode/extensions/filetypes/manifest.json` - Add deck-agent, skill-deck, deck.md
- `.opencode/extensions/web/manifest.json` - Add skill-tag, tag.md

**Verification**:
- Each system's epidemiology manifest references its own CLAUDE.md/OPENCODE.md
- No cross-system references in any manifest
- .opencode manifest file counts match .claude versions
- All declared files exist in their respective extension directories

---

### Phase 5: Update core/routing.md and Fix State Tracking [NOT STARTED]

**Goal**: Update the routing reference to reflect all post-merge languages for each system independently, and fix the extensions.json state tracking.

**Tasks**:
- [ ] Update `.claude/context/core/routing.md` language table with all languages
- [ ] Update `.opencode/context/core/routing.md` language table with all languages (independent copy)
- [ ] Remove the "Additional languages available via extensions" note from both
- [ ] Debug `shared/extensions/state.lua` `mark_loaded()` function
- [ ] Fix serialization so file/dir lists are properly recorded per system

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/core/routing.md` - Expand language routing table
- `.opencode/context/core/routing.md` - Expand language routing table (independent)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Fix mark_loaded serialization

**Verification**:
- Each system's core/routing.md lists all post-merge languages independently
- Load an extension in each system, check extensions.json has non-empty installed_files
- Unload the extension, verify files are properly removed
- Extensions.json files are separate for each system (if applicable)

---

### Phase 6: Create Validation Script and End-to-End Testing [NOT STARTED]

**Goal**: Create a reusable validation script that verifies index.json integrity and system independence, and run comprehensive end-to-end verification.

**Tasks**:
- [ ] Create `.claude/scripts/validate-extension-index.sh` that:
  - Reads all index-entries.json files and validates path prefixes
  - Checks that all paths resolve to real files relative to their system
  - Validates JSON structure (`{entries: [...]}` format)
  - **Checks for cross-system references (FAIL if found)**
  - Reports errors with file and entry-level detail
- [ ] Run the validation script against all 22 source index-entries.json files
- [ ] Test full extension load/unload cycle independently for each system:
  - Load all extensions in .claude system only, verify no .opencode contamination
  - Unload .claude, load all extensions in .opencode system only, verify no .claude contamination
  - Verify each system works when loaded alone
- [ ] Final independence verification:
  - Delete .opencode from a test project, verify .claude still works completely
  - Delete .claude from a test project, verify .opencode still works completely

**Timing**: 1 hour

**Files to modify**:
- `.claude/scripts/validate-extension-index.sh` - New validation script with independence checks

**Verification**:
- Validation script exits 0 when all files are valid and independent
- Validation script exits non-zero for any cross-system references
- Each system operates correctly when the other is absent
- All issues from research-001 and research-002 are resolved

---

## Testing & Validation

**Independence Tests** (CRITICAL):
- [ ] No .claude files reference .opencode paths
- [ ] No .opencode files reference .claude paths
- [ ] Each system can be loaded and used independently
- [ ] Removing one system does not break the other

**Functional Tests**:
- [ ] All 22 index-entries.json files use `{entries: [...]}` format
- [ ] All paths use `project/` or `core/` prefix (no system-specific prefixes)
- [ ] Loader normalizes paths and handles bare arrays
- [ ] Epidemiology .claude manifest uses correct `claudemd` key
- [ ] .opencode manifests have parity with .claude versions
- [ ] core/routing.md lists all languages in each system
- [ ] extensions.json records non-empty installed_files

## Artifacts & Outputs

- 22 fixed index-entries.json files (path normalization + format fix)
- 4 fixed manifest.json files (epidemiology key + parity sync)
- Updated merge.lua with system-aware path normalization
- Updated init.lua with bare-array fallback
- 2 updated core/routing.md files (one per system)
- Fixed state.lua for proper file tracking
- New validate-extension-index.sh with independence checking

## Rollback/Contingency

All changes are to source files in the nvim/ configuration repository. Git history provides full rollback capability. The loader changes are additive and system-aware, so reverting them restores original behavior. Source fixes are independent per system and can be applied/reverted separately for .claude or .opencode.
