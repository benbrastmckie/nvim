# Implementation Plan: Task #168

- **Task**: 168 - Fix core agent system loading and extension loader issues
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: Task 167 (move extension artifacts into core directories)
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10
- **Feature**: Fix broken index.json paths, loader bugs, and manifest inconsistencies across .claude and .opencode extension systems
- **Estimated Hours**: 4-6 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)

## Overview

Both research reports identified systemic issues in how the extension loader handles metadata injection. The core problems are: (1) source index-entries.json files use 3 different path prefix conventions, (2) the loader copies paths verbatim without normalization, (3) some index-entries.json use bare arrays instead of the expected `{entries: [...]}` format, (4) the epidemiology .claude manifest has a wrong merge_target_key, and (5) .claude/.opencode manifests have parity gaps. This plan fixes all issues at the source AND adds defensive normalization in the loader for belt-and-suspenders reliability.

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

## Implementation Phases

### Phase 1: Fix Source index-entries.json Path Prefixes [NOT STARTED]

**Goal**: Normalize all 22 index-entries.json files (11 .claude + 11 .opencode) to use the correct `project/` path prefix convention.

**Tasks**:
- [ ] Audit all 22 index-entries.json files, cataloging current path prefixes
- [ ] For each file, strip incorrect prefixes to produce `project/{domain}/...` paths
- [ ] Simultaneously fix bare-array files (4 files) to wrap in `{"entries": [...]}`
- [ ] Validate every normalized path resolves to an actual file relative to `.claude/context/` or `.opencode/context/`

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/formal/index-entries.json` - Strip `.claude/extensions/formal/context/` prefix
- `.claude/extensions/nix/index-entries.json` - Strip `.claude/extensions/nix/context/` prefix
- `.claude/extensions/web/index-entries.json` - Strip `.claude/extensions/web/context/` prefix
- `.claude/extensions/latex/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/lean/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/nvim/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/python/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/typst/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/z3/index-entries.json` - Strip `context/` prefix
- `.claude/extensions/filetypes/index-entries.json` - Strip `.claude/extensions/filetypes/context/` prefix, wrap bare array in `{entries: [...]}`
- `.claude/extensions/epidemiology/index-entries.json` - Verify (already correct `project/` prefix)
- `.opencode/extensions/formal/index-entries.json` - Strip `.opencode/extensions/formal/context/` prefix
- `.opencode/extensions/nix/index-entries.json` - Strip `.opencode/extensions/nix/context/` prefix, wrap bare array in `{entries: [...]}`
- `.opencode/extensions/web/index-entries.json` - Strip `.opencode/extensions/web/context/` prefix, wrap bare array in `{entries: [...]}`
- `.opencode/extensions/latex/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/lean/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/nvim/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/python/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/typst/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/z3/index-entries.json` - Strip `context/` prefix
- `.opencode/extensions/filetypes/index-entries.json` - Wrap bare array in `{entries: [...]}`
- `.opencode/extensions/epidemiology/index-entries.json` - Verify (already correct `project/` prefix)

**Verification**:
- Run a script that reads each index-entries.json, extracts all paths, and checks that each path resolves to a file relative to `.claude/context/` or `.opencode/context/` respectively
- All 22 files parse as valid JSON with `{entries: [...]}` structure
- Zero paths start with `.claude/`, `.opencode/`, or `context/` (only `project/` or `core/` allowed)

---

### Phase 2: Add Loader Path Normalization (Defense-in-Depth) [NOT STARTED]

**Goal**: Add path normalization to the shared merge module so the loader strips incorrect prefixes before appending entries, and add fallback handling for bare arrays.

**Tasks**:
- [ ] Add `normalize_index_path()` function to `shared/extensions/merge.lua` that strips known bad prefixes
- [ ] Call normalization on each entry path before deduplication check in `append_index_entries()`
- [ ] Add bare-array fallback in `shared/extensions/init.lua`: detect when `entries_data` is an array and use it directly
- [ ] Verify normalization handles all 3 known bad prefix patterns:
  - `.claude/extensions/{ext}/context/` -> strip
  - `.opencode/extensions/{ext}/context/` -> strip
  - `context/` -> strip
  - `.claude/context/` -> strip
  - `.opencode/context/` -> strip

**Timing**: 1 hour

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Add `normalize_index_path()`, apply in `append_index_entries()`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add bare-array fallback in `process_merge_targets()`

**Verification**:
- Unit test: pass entries with each bad prefix pattern, verify normalization produces `project/...` paths
- Unit test: pass bare array to process_merge_targets, verify entries are processed (not silently skipped)
- Reload an extension and verify index.json entries have correct paths

---

### Phase 3: Fix Epidemiology Manifest and Manifest Parity [NOT STARTED]

**Goal**: Fix the epidemiology .claude manifest merge_target_key and sync .claude/.opencode manifest parity gaps.

**Tasks**:
- [ ] Fix `.claude/extensions/epidemiology/manifest.json`: change `opencode_md` to `claudemd`, update `target` to `.claude/CLAUDE.md`, update `section_id` to `extension_epidemiology`
- [ ] Add missing items to `.opencode/extensions/filetypes/manifest.json`: `deck-agent.md` in agents, `skill-deck` in skills, `deck.md` in commands
- [ ] Add missing items to `.opencode/extensions/web/manifest.json`: `skill-tag` in skills, `tag.md` in commands
- [ ] Verify the actual files (deck-agent.md, skill-deck/, deck.md, skill-tag/, tag.md) exist in both `.opencode/` target directories

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/epidemiology/manifest.json` - Fix merge_target_key
- `.opencode/extensions/filetypes/manifest.json` - Add deck-agent, skill-deck, deck.md
- `.opencode/extensions/web/manifest.json` - Add skill-tag, tag.md

**Verification**:
- Verify `.claude/extensions/epidemiology/manifest.json` has `"claudemd"` key with correct target and section_id
- Verify `.opencode/extensions/filetypes/manifest.json` provides count matches `.claude` version
- Verify `.opencode/extensions/web/manifest.json` provides count matches `.claude` version
- Check that all declared files exist in the source extension directories

---

### Phase 4: Update core/routing.md and Fix State Tracking [NOT STARTED]

**Goal**: Update the routing reference to reflect all post-merge languages, and fix the extensions.json empty installed_files issue.

**Tasks**:
- [ ] Update `.claude/context/core/routing.md` language table to include all languages from CLAUDE.md (lean4, latex, typst, python, nix, web, epidemiology, formal/logic/math/physics, general, meta)
- [ ] Update `.opencode/context/core/routing.md` similarly if it exists
- [ ] Remove the "Additional languages available via extensions" note (no longer applicable post-merge)
- [ ] Debug `shared/extensions/state.lua` `mark_loaded()` function to fix why installed_files/installed_dirs are empty in extensions.json
- [ ] Fix the serialization so file/dir lists are properly recorded

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/core/routing.md` - Expand language routing table
- `.opencode/context/core/routing.md` - Expand language routing table (if exists)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Fix mark_loaded serialization of file/dir lists

**Verification**:
- core/routing.md lists all 10+ languages matching CLAUDE.md
- Load an extension, check extensions.json has non-empty installed_files and installed_dirs arrays
- Unload the extension, verify all listed files are removed

---

### Phase 5: Create Validation Script and End-to-End Testing [NOT STARTED]

**Goal**: Create a reusable validation script that can verify index.json integrity, and run end-to-end verification.

**Tasks**:
- [ ] Create `.claude/scripts/validate-extension-index.sh` that:
  - Reads all index-entries.json files and validates path prefixes
  - Checks that all paths resolve to real files
  - Validates JSON structure (`{entries: [...]}` format)
  - Reports errors with file and entry-level detail
- [ ] Run the validation script against all 22 source index-entries.json files
- [ ] Test extension load/unload cycle for at least 2 extensions (one per system) and verify:
  - index.json entries have correct paths after load
  - CLAUDE.md/OPENCODE.md sections are properly injected (including epidemiology for .claude)
  - extensions.json tracks installed_files correctly
  - Unload properly removes files and entries
- [ ] Run validation against a target project's index.json after loading all extensions

**Timing**: 1 hour

**Files to modify**:
- `.claude/scripts/validate-extension-index.sh` - New validation script

**Verification**:
- Validation script exits 0 when all index-entries.json are valid
- Validation script exits non-zero and reports specific errors for invalid files
- Full load/unload cycle completes without errors for tested extensions
- All issues from research-001 and research-002 are resolved

---

## Testing & Validation

- [ ] All 22 index-entries.json files use `{entries: [...]}` format (no bare arrays)
- [ ] All paths in index-entries.json use `project/` or `core/` prefix (no `.claude/`, `.opencode/`, or `context/` prefix)
- [ ] Loader `append_index_entries()` normalizes paths before appending
- [ ] Loader `process_merge_targets()` handles bare arrays gracefully
- [ ] Epidemiology .claude manifest uses `claudemd` merge_target_key
- [ ] .opencode filetypes/web manifests include all items from .claude versions
- [ ] core/routing.md lists all post-merge languages
- [ ] extensions.json records non-empty installed_files after loading
- [ ] Validation script passes on all source files

## Artifacts & Outputs

- 22 fixed index-entries.json files (path normalization + format fix)
- 3 fixed manifest.json files (epidemiology key + parity sync)
- Updated merge.lua with path normalization function
- Updated init.lua with bare-array fallback
- Updated core/routing.md with complete language table
- Fixed state.lua for proper file tracking
- New validate-extension-index.sh validation script

## Rollback/Contingency

All changes are to source files in the nvim/ configuration repository. Git history provides full rollback capability. The loader changes are additive (normalization function + fallback), so reverting them restores original behavior. Source index-entries.json fixes are independent of the loader fix and can be applied/reverted separately.
