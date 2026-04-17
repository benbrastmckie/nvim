# Implementation Plan: Document Extension Loader Architecture

- **Task**: 468 - Document extension loader architecture and .claude/ lifecycle
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: 466, 470 (both completed)
- **Research Inputs**: [468_document_extension_loader_architecture/reports/01_team-research.md]
- **Artifacts**: plans/01_doc-loader-architecture.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

All extension system documentation contains factual errors about CLAUDE.md generation (documents inject_section but code uses generate_claudemd), conflict handling (documents abort but code shows confirmation dialog), unload behavior (documents user confirmation but code hard-blocks), and settings merging (documents mcp_servers but code uses merge_targets.settings). Additionally, the two-layer architecture (Neovim Lua loader vs .claude/ agent system) is never explicitly named or explained. This plan fixes factual errors first, then adds missing architectural explanations, then creates new reference documentation.

### Research Integration

Team research (4 teammates, all high confidence) identified 12 findings across 6 documentation files. All teammates independently confirmed the two most critical issues: CLAUDE.md is a computed artifact (not section-injected), and the two-layer architecture is never named. Research cataloged every stale reference with file locations and line-level specificity.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task is a prerequisite enabler for three ROADMAP Phase 1 documentation items:
- Manifest-driven README generation -- requires accurate architecture docs
- CI enforcement of doc-lint -- requires docs to be correct first
- `/review` drift detection -- requires defining what "correct" looks like

## Goals & Non-Goals

**Goals**:
- Fix all factual errors about CLAUDE.md generation, conflict handling, unload behavior, and settings merging
- Add explicit two-layer architecture explanation naming the Neovim Lua loader and .claude/ agent system
- Establish "source vs loaded" vocabulary for extension file locations
- Document all 12 loader.lua copy functions and complete extension directory structure
- Document merge-sources/claudemd.md vs EXTENSION.md pattern
- Create loader-reference.md context file for agent-accessible loader documentation

**Non-Goals**:
- Modifying any Lua source code (documentation-only task)
- Adding routing table validation to check-extension-docs.sh (P4, separate task)
- Fixing nix/present EXTENSION.md line count (minor, separate task)
- Documenting sync.lua vs load/unload CLAUDE.md strategy (needs investigation first)
- Coordinating with task 474 core README (adjacent but independent)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Docs drift again as code changes | M | M | Note in each doc that CLAUDE.md is generated, not manually maintained |
| Incomplete coverage of stale references | M | L | Research identified all files; verify with grep after each phase |
| Overwrites from extension reload | M | L | All changes are to source files in extensions/, not loaded copies |
| Breaking cross-references between docs | L | M | Verify all internal links after edits |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |

### Phase 1: Fix Critical Factual Errors in extension-system.md [COMPLETED]

**Goal**: Correct all factual inaccuracies in the primary architecture reference document.

**Tasks**:
- [ ] Replace "merged section" with "regenerated" in System Overview diagram (line 25)
- [ ] Replace inject_section/remove_section docs in Merger section with generate_claudemd() description
- [ ] Remove Section Markers subsection (lines 188-196) or replace with explanation of computed artifact
- [ ] Fix load step 6a: replace "inject_section() into CLAUDE.md" with "generate_claudemd() rebuilds CLAUDE.md"
- [ ] Fix unload step 2c: replace "Proceed with unload if user confirms" with "Hard block with error, return false"
- [ ] Fix unload step 3a: replace "remove_section() from CLAUDE.md" with "generate_claudemd() rebuilds CLAUDE.md"
- [ ] Fix Conflict Handling section: replace "loading is aborted" with "conflicts presented in confirmation dialog"
- [ ] Fix Settings Merging section: replace mcp_servers manifest-root example with merge_targets.settings source fragment
- [ ] Add missing loader functions to the Loader section: copy_hooks, copy_docs, copy_templates, copy_systemd, copy_root_files, copy_data_dirs
- [ ] Expand extension directory structure diagram to include hooks/, docs/, templates/, systemd/, root-files/, merge-sources/
- [ ] Add note that section_id is vestigial for load/unload but still used by sync.lua

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/extension-system.md` - Primary architecture reference (all fixes)

**Verification**:
- Grep for "inject_section" in extension-system.md returns zero hits (except any sync.lua note)
- Grep for "loading is aborted" returns zero hits
- Grep for "user confirms" in unload section returns zero hits
- All 12 loader functions listed in Loader section

---

### Phase 2: Fix Factual Errors in Remaining Documentation [NOT STARTED]

**Goal**: Correct stale references in the other 3 documentation files that contain factual errors.

**Tasks**:
- [ ] `.claude/docs/guides/creating-extensions.md`: Remove or update "Check CLAUDE.md injection" verification step (grep for section_id markers); replace with verification that content appears in regenerated CLAUDE.md
- [ ] `.claude/docs/guides/creating-extensions.md`: Update "Load Fails with Conflicts" troubleshooting to reflect confirmation dialog behavior
- [ ] `.claude/extensions/core/context/guides/extension-development.md`: Replace "CLAUDE.md Merging" subsection that references section_id injection with computed-artifact explanation
- [ ] `.claude/extensions/core/context/guides/extension-development.md`: Add missing provides categories (hooks, docs, templates, systemd, root-files, data_dirs) to structure template
- [ ] `.claude/extensions/README.md`: Fix load step 4 to say "CLAUDE.md is regenerated from all loaded extensions" instead of "injection"
- [ ] `.claude/extensions/README.md`: Fix post-load verification to say "EXTENSION.md content appears in CLAUDE.md" instead of "section was injected"

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/docs/guides/creating-extensions.md` - Extension authoring guide
- `.claude/extensions/core/context/guides/extension-development.md` - Agent-facing dev guide
- `.claude/extensions/README.md` - Extensions directory overview

**Verification**:
- Grep for "inject" across all 4 documentation files returns zero hits (except sync.lua mentions)
- Grep for "section_id" only appears in manifest field reference (not in behavioral descriptions)
- Grep for "EXTENSION.md section was injected" returns zero hits

---

### Phase 3: Add Two-Layer Architecture Documentation [NOT STARTED]

**Goal**: Add explicit architectural explanation of the two-layer system and establish vocabulary.

**Tasks**:
- [ ] Add "Two-Layer Architecture" section to extension-system.md near the top (after System Overview), naming Layer 1 (Neovim Lua loader at `lua/neotex/plugins/ai/shared/extensions/`) and Layer 2 (.claude/ agent system), with explanation that Layer 1 manages which files exist in Layer 2
- [ ] Add "Source vs Loaded" vocabulary box to extension-system.md: "extension source" = `.claude/extensions/*/`, "loaded runtime" = `.claude/{agents,skills,...}/`
- [ ] Add two-layer lifecycle explanation to extension-development.md: picker triggers Lua loader, which copies files and regenerates CLAUDE.md, then Claude Code reads the resulting .claude/ structure
- [ ] Update project-overview.md to reference the two-layer architecture and show both the Lua loader path and the .claude/ consumer path
- [ ] Document the merge-sources/claudemd.md vs EXTENSION.md pattern: core extension uses merge-sources/claudemd.md as its CLAUDE.md source, all other extensions use EXTENSION.md
- [ ] Document copy_context_dirs() dual behavior: handles both directory names and individual file paths in provides.context

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/docs/architecture/extension-system.md` - Add two-layer section, vocabulary
- `.claude/extensions/core/context/guides/extension-development.md` - Add lifecycle explanation, vocabulary
- `.claude/extensions/core/context/repo/project-overview.md` - Add two-layer reference
- `.claude/extensions/README.md` - Add merge-sources pattern note

**Verification**:
- Grep for "Two-Layer" in extension-system.md returns at least 1 hit
- Grep for "lua/neotex/plugins/ai/shared/extensions" in extension-system.md returns at least 1 hit
- Grep for "source.*loaded" or "Source vs Loaded" in extension-system.md returns at least 1 hit
- project-overview.md mentions both Neovim loader and .claude/ agent system

---

### Phase 4: Create Loader Reference Context File [NOT STARTED]

**Goal**: Create agent-accessible loader function reference for future maintenance.

**Tasks**:
- [ ] Create `.claude/extensions/core/context/guides/loader-reference.md` with function-to-category table listing all 12 public loader.lua functions, their parameters, copy semantics (simple copy, recursive, permission-preserving, merge-copy), and target directories
- [ ] Include the 8 source files of the Lua loader with brief descriptions
- [ ] Add entry to core extension's `index-entries.json` for the new file with appropriate load_when conditions (agents: meta-builder-agent; task_types: meta)
- [ ] Cross-reference loader-reference.md from extension-system.md Related Documentation section

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/core/context/guides/loader-reference.md` - New file: loader function reference
- `.claude/extensions/core/index-entries.json` - Add index entry for new file
- `.claude/docs/architecture/extension-system.md` - Add link in Related Documentation

**Verification**:
- loader-reference.md exists and lists all 12 functions
- index-entries.json contains entry for loader-reference.md
- extension-system.md Related Documentation links to loader-reference.md

## Testing & Validation

- [ ] Grep for "inject_section" across all `.claude/docs/` and `.claude/extensions/` -- zero hits in behavioral descriptions (allowed only in sync.lua references)
- [ ] Grep for "loading is aborted" -- zero hits
- [ ] Grep for "mcp_servers" in extension-system.md Settings section -- replaced with merge_targets.settings
- [ ] Grep for "Two-Layer" or "two-layer" -- at least 1 hit in extension-system.md
- [ ] Grep for "generate_claudemd" -- appears in merger/merge documentation sections
- [ ] All internal cross-references between docs resolve (no broken links)
- [ ] loader-reference.md exists with complete function table

## Artifacts & Outputs

- `.claude/docs/architecture/extension-system.md` - Corrected and expanded architecture reference
- `.claude/docs/guides/creating-extensions.md` - Corrected authoring guide
- `.claude/extensions/core/context/guides/extension-development.md` - Corrected agent-facing guide
- `.claude/extensions/README.md` - Corrected overview
- `.claude/extensions/core/context/repo/project-overview.md` - Updated with two-layer reference
- `.claude/extensions/core/context/guides/loader-reference.md` - New loader function reference
- `.claude/extensions/core/index-entries.json` - Updated with new entry

## Rollback/Contingency

All changes are to git-tracked files. Revert with `git checkout HEAD -- .claude/docs/ .claude/extensions/core/ .claude/extensions/README.md` if documentation updates introduce issues. Since this is a documentation-only task with no code changes, rollback risk is minimal.
