# Implementation Plan: Add UCSF Theme, PPTX Patterns, and Templates

- **Task**: 404 - Add UCSF theme, PPTX patterns, and templates to present/ context
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None (independent of tasks 403, 405-407)
- **Research Inputs**: specs/404_add_ucsf_theme_pptx_patterns_templates/reports/01_ucsf-pptx-context.md
- **Artifacts**: plans/01_ucsf-pptx-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port UCSF institutional theme, PPTX generation patterns, Slidev pitfall docs, and project templates from the zed configuration into the nvim present/ extension. This involves creating 13 new text files, copying 1 binary .pptx template, updating 5 existing files (theme footers, talk-structure, conclusions, talk/index.json), and adding 8 new entries to index-entries.json for context discovery. All changes are scoped to the present/ extension context subtree.

### Research Integration

The research report (01_ucsf-pptx-context.md) provides a complete file inventory with exact source/target paths, line counts, and precise edit instructions for each existing file update. All 19 file operations are documented with source content locations under `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Create ucsf-institutional.json theme file with UCSF color palette and fonts
- Add pptx-generation.md and slidev-pitfalls.md pattern files
- Create pptx-project/ and slidev-project/ template directories with all scaffold files
- Copy UCSF .pptx binary template into pptx-project/
- Update existing themes (academic-clean, clinical-teal) with footer sections
- Update talk-structure.md and conclusions-takeaway.md with format-specific notes
- Rewrite talk/index.json with new theme, pattern, and template entries
- Add 8 context discovery entries to index-entries.json

**Non-Goals**:
- Modifying agents, skills, or commands (covered by tasks 403, 405-407)
- Updating the present/ extension manifest (covered by task 407)
- Creating or modifying any agent definitions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Binary .pptx increases repo size by 3MB | L | H | One-time addition, unlikely to change frequently |
| Index entries reference future agent names | M | H | Entries only active when extension loaded; agents created by task 403 before reload |
| Large pptx-generation.md (829 lines) | L | L | Only loaded for pptx-assembly-agent, not all present tasks |
| Source files in zed may have changed since research | M | L | Verify source files exist before copying |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Create New Theme and Pattern Files [COMPLETED]

**Goal**: Create the 3 core content files: ucsf-institutional theme, pptx-generation pattern, slidev-pitfalls pattern.

**Tasks**:
- [ ] Create directory `context/project/present/talk/patterns/` if it does not exist
- [ ] Copy `ucsf-institutional.json` from zed source to `context/project/present/talk/themes/ucsf-institutional.json`
- [ ] Copy `pptx-generation.md` from zed source to `context/project/present/talk/patterns/pptx-generation.md`
- [ ] Copy `slidev-pitfalls.md` from zed source to `context/project/present/talk/patterns/slidev-pitfalls.md`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `context/project/present/talk/themes/ucsf-institutional.json` - CREATE (50 lines)
- `context/project/present/talk/patterns/pptx-generation.md` - CREATE (829 lines)
- `context/project/present/talk/patterns/slidev-pitfalls.md` - CREATE (254 lines)

**Verification**:
- All 3 files exist at target paths
- ucsf-institutional.json is valid JSON
- pptx-generation.md contains python-pptx API patterns
- slidev-pitfalls.md contains Slidev gotchas

---

### Phase 2: Create Template Directories and Files [COMPLETED]

**Goal**: Create pptx-project/, slidev-project/, and playwright-verify.mjs template files.

**Tasks**:
- [ ] Create directory `context/project/present/talk/templates/pptx-project/`
- [ ] Create directory `context/project/present/talk/templates/slidev-project/`
- [ ] Copy `playwright-verify.mjs` from zed source to templates/
- [ ] Copy `generate_deck.py` from zed source to templates/pptx-project/
- [ ] Copy `theme_mappings.json` from zed source to templates/pptx-project/
- [ ] Copy `README.md` from zed source to templates/pptx-project/
- [ ] Copy `README.md` from zed source to templates/slidev-project/
- [ ] Copy `package.json` from zed source to templates/slidev-project/
- [ ] Copy `vite.config.ts` from zed source to templates/slidev-project/
- [ ] Copy `lz-string-esm.js` from zed source to templates/slidev-project/
- [ ] Copy `.npmrc` from zed source to templates/slidev-project/

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `context/project/present/talk/templates/playwright-verify.mjs` - CREATE (128 lines)
- `context/project/present/talk/templates/pptx-project/generate_deck.py` - CREATE (291 lines)
- `context/project/present/talk/templates/pptx-project/theme_mappings.json` - CREATE (125 lines)
- `context/project/present/talk/templates/pptx-project/README.md` - CREATE (84 lines)
- `context/project/present/talk/templates/slidev-project/README.md` - CREATE (37 lines)
- `context/project/present/talk/templates/slidev-project/package.json` - CREATE (22 lines)
- `context/project/present/talk/templates/slidev-project/vite.config.ts` - CREATE (11 lines)
- `context/project/present/talk/templates/slidev-project/lz-string-esm.js` - CREATE (509 lines)
- `context/project/present/talk/templates/slidev-project/.npmrc` - CREATE (1 line)

**Verification**:
- All 9 template files exist at target paths
- theme_mappings.json is valid JSON
- generate_deck.py contains python-pptx imports
- package.json is valid JSON

---

### Phase 3: Update Existing Theme and Content Files [COMPLETED]

**Goal**: Add footer sections to existing themes, append format-specific notes to talk-structure.md and conclusions-takeaway.md, and rewrite talk/index.json.

**Tasks**:
- [ ] Add `"footer"` object to `academic-clean.json` after `"borders"` block (research report provides exact edit)
- [ ] Add `"footer"` object to `clinical-teal.json` after `"borders"` block (research report provides exact edit)
- [ ] Append format-specific implementation notes to `talk-structure.md` (5 lines at end)
- [ ] Append custom footer section to `conclusions-takeaway.md` (14 lines at end)
- [ ] Rewrite `talk/index.json` with new entries for ucsf theme, patterns, and templates

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `context/project/present/talk/themes/academic-clean.json` - UPDATE (add footer section, +4 lines)
- `context/project/present/talk/themes/clinical-teal.json` - UPDATE (add footer section, +4 lines)
- `context/project/present/patterns/talk-structure.md` - UPDATE (append 5 lines)
- `context/project/present/talk/contents/conclusions/conclusions-takeaway.md` - UPDATE (append 14 lines)
- `context/project/present/talk/index.json` - UPDATE (rewrite, 70 lines)

**Verification**:
- academic-clean.json and clinical-teal.json have `"footer"` objects and remain valid JSON
- talk-structure.md ends with format-specific implementation notes section
- conclusions-takeaway.md ends with custom footer section
- talk/index.json includes ucsf-institutional theme, slidev-pitfalls, pptx-generation, and templates entries

---

### Phase 4: Copy UCSF Binary Template [COMPLETED]

**Goal**: Copy the UCSF .pptx binary template into the pptx-project directory.

**Tasks**:
- [ ] Verify source file exists at `/home/benjamin/.config/zed/examples/test-files/UCSF_ZSFG_Template_16x9.pptx`
- [ ] Copy binary to `context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx`
- [ ] Verify copied file size matches source (~3MB)

**Timing**: 5 minutes

**Depends on**: 2

**Files to modify**:
- `context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx` - COPY (binary, ~3MB)

**Verification**:
- File exists at target path
- File size matches source (3,046,296 bytes)
- File is not corrupted (binary diff or size check)

---

### Phase 5: Add Index Entries for Context Discovery [NOT STARTED]

**Goal**: Add 8 new entries to index-entries.json so the new files are discoverable by the context loading system.

**Tasks**:
- [ ] Read current `index-entries.json` at extension root
- [ ] Append 8 new entries (slidev-pitfalls, pptx-generation, talk/index.json, playwright-verify, theme_mappings, generate_deck, pptx-project/README, slidev-project/README)
- [ ] Validate resulting JSON is well-formed
- [ ] Verify entry paths match actual file locations from phases 1-2

**Timing**: 15 minutes

**Depends on**: 3, 4

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - UPDATE (add 8 entries, +~80 lines)

**Verification**:
- index-entries.json is valid JSON
- All 8 new entries present with correct paths
- Entry paths correspond to files that exist on disk
- load_when fields reference appropriate agents and task types

## Testing & Validation

- [ ] All 13 new text files exist at expected paths under present/ extension
- [ ] UCSF .pptx binary copied successfully (size match)
- [ ] All JSON files (ucsf-institutional.json, academic-clean.json, clinical-teal.json, theme_mappings.json, package.json, talk/index.json, index-entries.json) are valid JSON
- [ ] Updated files retain existing content plus new additions
- [ ] index-entries.json entries reference files that exist on disk
- [ ] No existing functionality broken (existing theme files still valid)

## Artifacts & Outputs

- plans/01_ucsf-pptx-plan.md (this file)
- 13 new text files in context/project/present/talk/
- 1 binary file (UCSF_ZSFG_Template_16x9.pptx)
- 5 updated files (2 themes, talk-structure, conclusions, talk/index.json)
- 8 new index-entries.json entries
- summaries/01_ucsf-pptx-summary.md (post-implementation)

## Rollback/Contingency

All changes are additive file operations (new files + appends to existing files). Rollback is straightforward:
- Delete all new files created in phases 1-2 and 4
- Revert edits to the 5 updated files using git checkout
- Remove the 8 added entries from index-entries.json
- `git checkout -- .claude/extensions/present/` would revert all changes
