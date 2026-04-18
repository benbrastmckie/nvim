# Implementation Plan: Make Extension Core Docs Editor-Agnostic

- **Task**: 478 - editor_agnostic_extension_docs
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/478_editor_agnostic_extension_docs/reports/01_team-research.md
- **Artifacts**: plans/01_editor-agnostic-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Four files in `.claude/extensions/core/` contain `<leader>ac` references that contaminate downstream projects when synced. Additionally, `project-overview.md` carries nvim-specific content (Neovim Lua loader references, neotex paths) that overwrites project-specific content in other repositories. The fix replaces keybinding references with generic "the extension picker" language, replaces the core `project-overview.md` with a self-documenting generic template, enhances the `claudemd.md` detection instruction, and mirrors all changes to deployed copies. Done when all 8 files are updated and no `<leader>ac` remains in core extension sources.

### Research Integration

Team research (4 teammates) confirmed:
- Exactly 4 files contain `<leader>ac` in extension source directories
- The loader's `copy_context_dirs()` copies `project-overview.md` via the `"repo"` directory entry -- `.syncprotect` only protects during sync, not during `manager.load()`
- The Zed repo already has a clean editor-agnostic version, confirming the approach
- The existing `claudemd.md` hint is passive; upgrading to an active task-creation instruction completes the detection mechanism
- `extensions.json` absolute paths are runtime-generated, not a concern

### Roadmap Alignment

No ROADMAP.md items are directly addressed by this task. However, Phase 2's "Extension hot-reload" item also contains a `<leader>ac` reference that should be cleaned separately when ROADMAP is next updated.

## Goals & Non-Goals

**Goals**:
- Remove all `<leader>ac` keybinding references from core extension source files
- Replace nvim-specific `project-overview.md` with a generic self-documenting template
- Enhance `claudemd.md` to actively instruct task creation when project-overview.md is generic
- Update deployed copies to match source changes

**Non-Goals**:
- Modifying `.claude/context/repo/project-overview.md` (nvim-specific, protected by `.syncprotect`)
- Adding syncprotect awareness to `manager.load()` (separate concern)
- Changing `extensions/README.md` (already editor-agnostic)
- Modifying Lua loader code

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-loading core overwrites custom project-overview.md | M | M | `.syncprotect` protects during sync; document that users should add to `.syncprotect` after generating custom version |
| Generic stub confuses agents expecting real content | L | L | Stub contains valid generic content; agents degrade gracefully with less context |
| Deployed copies drift from sources | L | L | Update deployed copies in same phase as sources |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace `<leader>ac` in Extension Source Files [COMPLETED]

**Goal**: Remove all editor-specific keybinding references from the 3 guide/template source files (project-overview.md handled separately in Phase 2).

**Tasks**:
- [ ] Edit `.claude/extensions/core/context/guides/extension-development.md` line 143: change `"Load via the extension picker (\`<leader>ac\`)"` to `"Load via the extension picker"`
- [ ] Edit `.claude/extensions/core/context/guides/loader-reference.md` line 141: change `"launched from \`<leader>ac\`"` to `"launched from the extension picker"` (or equivalent functional description)
- [ ] Edit `.claude/extensions/core/templates/extension-readme-template.md` line 50: change `"Loaded via \`<leader>ac\` in Neovim."` to `"Loaded via the extension picker."`
- [ ] Update deployed copies to match:
  - `.claude/context/guides/extension-development.md`
  - `.claude/context/guides/loader-reference.md`
  - `.claude/templates/extension-readme-template.md`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/context/guides/extension-development.md` - remove `<leader>ac` reference
- `.claude/extensions/core/context/guides/loader-reference.md` - remove `<leader>ac` reference
- `.claude/extensions/core/templates/extension-readme-template.md` - remove `<leader>ac` and "in Neovim"
- `.claude/context/guides/extension-development.md` - mirror source change
- `.claude/context/guides/loader-reference.md` - mirror source change
- `.claude/templates/extension-readme-template.md` - mirror source change

**Verification**:
- `grep -r '<leader>ac' .claude/extensions/core/context/guides/ .claude/extensions/core/templates/` returns no results
- Deployed copies match source files for the changed lines

---

### Phase 2: Replace project-overview.md With Generic Template [NOT STARTED]

**Goal**: Replace the nvim-specific content in the core extension's `project-overview.md` with a generic self-documenting template that works for any project.

**Tasks**:
- [ ] Replace entire content of `.claude/extensions/core/context/repo/project-overview.md` with generic template containing:
  - HTML comment notice directing users to run `/task "Generate project-overview.md for this repository"`
  - Generic two-layer architecture description (no Neovim/neotex references)
  - Placeholder repository structure section
  - Related documentation links
- [ ] Verify the `always: true` index entry in `index-entries.json` still references the correct path (no changes needed, just verify)

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/context/repo/project-overview.md` - full content replacement with generic template

**Verification**:
- File contains the HTML comment notice header
- No references to `<leader>ac`, "Neovim Lua loader", or "neotex" in the file
- `.claude/context/repo/project-overview.md` (deployed nvim-specific version) is unchanged

---

### Phase 3: Enhance claudemd.md Detection Instruction [NOT STARTED]

**Goal**: Upgrade the passive "see update-project.md" hint to an active task-creation instruction that triggers when project-overview.md is missing or contains the generic template.

**Tasks**:
- [ ] Edit `.claude/extensions/core/merge-sources/claudemd.md` line 28: change the passive hint to an active instruction that references both the missing-file and generic-template conditions, and includes the `/task` command
- [ ] Verify the change by reading the file after edit
- [ ] Confirm the deployed `.claude/CLAUDE.md` contains the old text (it will be updated on next core load; no manual update needed since CLAUDE.md is auto-generated)

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - enhance detection instruction

**Verification**:
- The new text references both conditions: file doesn't exist OR contains generic template notice
- The new text includes a `/task` command for creating the generation task
- `grep -c '<leader>ac' .claude/extensions/core/` returns 0 across all source files

---

## Testing & Validation

- [ ] `grep -r '<leader>ac' .claude/extensions/core/` returns no matches
- [ ] `.claude/context/repo/project-overview.md` (nvim-specific deployed copy) is unchanged
- [ ] `.claude/extensions/core/context/repo/project-overview.md` contains HTML comment notice
- [ ] Deployed guide copies match their source counterparts on the changed lines
- [ ] `.claude/extensions/core/merge-sources/claudemd.md` contains active task-creation instruction

## Artifacts & Outputs

- `specs/478_editor_agnostic_extension_docs/plans/01_editor-agnostic-docs.md` (this plan)
- `specs/478_editor_agnostic_extension_docs/summaries/01_editor-agnostic-docs-summary.md` (after implementation)
- 5 modified extension source files
- 3 modified deployed copies

## Rollback/Contingency

All changes are text edits to markdown files with no build or runtime impact. Revert with `git checkout -- .claude/extensions/core/ .claude/context/guides/ .claude/templates/` to restore all files to their pre-change state.
