# Implementation Plan: Task #433

- **Task**: 433 - Move nvim-specific content from core .claude/ files to neovim extension
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 432 (sync hardening) - completed
- **Research Inputs**: specs/433_move_nvim_specific_content_to_neovim_extension/reports/01_extension-restructuring.md
- **Artifacts**: plans/01_extension-restructuring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan restructures the agent system's core `.claude/` files to remove neovim-specific content, making the core truly generic and portable across projects. Work is organized into four phases: corruption fixes, full-file moves, section extraction from mixed files, and example generalization across format/orchestration documentation. Research identified 42 files with neovim references, categorized into 5 action groups (move, extract, generalize, leave, fix corruption).

### Research Integration

Key findings from the research report:
- 3 files are purely neovim-specific (move entirely)
- ~4 files contain extractable neovim-specific sections alongside generic content
- ~15 files use "neovim" as example data in routing tables and JSON samples
- 3 files contain "cneovim" corruption artifacts from a bad find-replace
- 1 deprecated file (`orchestration/routing.md`, 778 lines) should be deleted
- The existing neovim extension at `.claude/extensions/nvim/` is well-structured with 20+ context files and proper `index-entries.json`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances **"Subagent-return reference cleanup"** (Phase 2, Agent System Quality) -- cleaning core files of project-specific references is the same class of work
- Advances **"Zero stale references to removed/renamed files"** success metric

## Goals & Non-Goals

**Goals**:
- Make all core `.claude/context/` files generic (no neovim/nvim/neotex assumptions)
- Fix "cneovim" corruption artifacts in 3 files
- Delete the deprecated `orchestration/routing.md` file
- Replace `repo/project-overview.md` with a generic template
- Extract neovim-specific sections from mixed files into the extension
- Generalize example data in format and orchestration docs

**Non-Goals**:
- Modifying `nvim/CLAUDE.md` (intentionally project-specific)
- Restructuring the neovim extension itself (already well-organized)
- Changing the extension loader mechanism
- Modifying `.claude/CLAUDE.md` beyond removing hardcoded neovim references
- Touching files with only incidental neovim mentions (Category 4, 1-2 hits each)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing routing examples breaks agent understanding | H | M | Replace with clearly marked placeholder examples, never just delete |
| Extension loader depends on specific core file paths | M | L | Verify loader reads from extension `index-entries.json`, not hardcoded core paths |
| Over-generalization makes docs unhelpful | M | M | Keep one concrete example per pattern, annotate as "example from extension" |
| Corruption fix introduces new errors | M | L | Use targeted replacements, verify with grep after each fix |
| `index.json` entries become stale after file moves | H | M | Update `index.json` entries in the same phase as the file move |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix Corruption and Delete Deprecated File [COMPLETED]

**Goal**: Eliminate known bugs (cneovim corruption) and remove the deprecated routing file before restructuring begins. This prevents corruption from being propagated during later moves.

**Tasks**:
- [ ] Fix "cneovim" corruption in `.claude/context/standards/error-handling.md`:
  - "Cneovim" -> "Clean"
  - "cneovimup" -> "cleanup"
  - "Resource cneovimup" -> "Resource cleanup"
- [ ] Fix "cneovim" corruption in `.claude/context/orchestration/delegation.md`:
  - "PostflightCneovimup" -> "PostflightCleanup"
- [ ] Fix "cneovim" corruption in `.claude/context/formats/return-metadata-file.md`:
  - "Cneovimup" -> "Cleanup"
  - "booneovim" -> "boolean"
- [ ] Delete deprecated `.claude/context/orchestration/routing.md` (778 lines)
- [ ] Remove routing.md entry from `.claude/context/index.json`
- [ ] Verify with grep that no "cneovim" or "booneovim" strings remain in `.claude/`

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/standards/error-handling.md` - Fix corruption
- `.claude/context/orchestration/delegation.md` - Fix corruption
- `.claude/context/formats/return-metadata-file.md` - Fix corruption
- `.claude/context/orchestration/routing.md` - Delete entirely
- `.claude/context/index.json` - Remove routing.md entry

**Verification**:
- `grep -r "cneovim\|booneovim" .claude/` returns zero matches
- `routing.md` no longer exists in orchestration directory
- `index.json` has no reference to `orchestration/routing.md`

---

### Phase 2: Move and Replace Full Neovim-Specific Files [COMPLETED]

**Goal**: Replace `repo/project-overview.md` with a generic template and ensure the neovim-specific content is available via the extension.

**Tasks**:
- [ ] Check if `.claude/extensions/nvim/context/project/neovim/README.md` already covers the content in `repo/project-overview.md` (research says it overlaps significantly)
- [ ] If overlap is sufficient: replace `repo/project-overview.md` with a generic template that describes specs/ and .claude/ directory structure, and directs readers to loaded extensions for project details
- [ ] If overlap is insufficient: copy unique content from `project-overview.md` to a new file in the extension (e.g., `.claude/extensions/nvim/context/project/neovim/project-structure.md`) and add an `index-entries.json` entry for it
- [ ] Update `repo/project-overview.md` to be generic (no lua, nvim, treesitter, lazy.nvim references)
- [ ] Update `index.json` entry for `repo/project-overview.md` if load_when conditions change
- [ ] Update `.claude/CLAUDE.md` reference to `project-overview.md` if the description changes
- [ ] Add `context/repo/project-overview.md` to `.syncprotect` to prevent sync from overwriting the generic version with a project-specific one

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/context/repo/project-overview.md` - Replace with generic template
- `.claude/extensions/nvim/context/project/neovim/project-structure.md` - New file (if needed)
- `.claude/extensions/nvim/index-entries.json` - Add entry (if new file created)
- `.claude/context/index.json` - Update entry if needed
- `.syncprotect` - Add protection for generic project-overview.md

**Verification**:
- `grep -c "neovim\|nvim\|neotex\|treesitter\|lazy\.nvim" .claude/context/repo/project-overview.md` returns 0
- The generic template describes specs/ and .claude/ directory layout
- Extension context covers all neovim project-specific information

---

### Phase 3: Extract Neovim Sections from Mixed Files [COMPLETED]

**Goal**: Remove neovim-specific sections from files that contain a mix of generic patterns and neovim content, relocating the neovim content to the extension where appropriate.

**Tasks**:
- [ ] Extract from `.claude/context/processes/research-workflow.md`:
  - Remove "Neovim Research" routing section (~lines 26-29)
  - Remove "Neovim-Specific Research Tools" section (~lines 553+)
  - Replace with generic extension routing pattern (e.g., "Extension-specific research tools are loaded from extension context")
- [ ] Extract from `.claude/context/meta/domain-patterns.md`:
  - Remove "Neovim Configuration Domain Pattern" section (~lines 133+)
  - Replace with a generic "{Extension} Domain Pattern" template showing the pattern structure without neovim specifics
  - Move the neovim domain pattern to `.claude/extensions/nvim/context/domain/neovim-domain-pattern.md` if not already covered
- [ ] Clean `.claude/context/standards/error-handling.md`:
  - Replace the neovim MCP server error example (lines 506-524) with a generic MCP server example
  - Ensure no neovim-specific content remains after corruption fixes from Phase 1
- [ ] Clean `.claude/context/processes/implementation-workflow.md`:
  - Generalize the neovim row in the routing table to use extension placeholder
  - Generalize file path pattern from nvim-specific to generic
- [ ] Update `index-entries.json` in the neovim extension if new files were created
- [ ] Verify extraction did not break any cross-references

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/context/processes/research-workflow.md` - Remove neovim sections
- `.claude/context/meta/domain-patterns.md` - Extract neovim domain pattern
- `.claude/context/standards/error-handling.md` - Replace neovim MCP example
- `.claude/context/processes/implementation-workflow.md` - Generalize routing row
- `.claude/extensions/nvim/context/domain/neovim-domain-pattern.md` - New file (if needed)
- `.claude/extensions/nvim/index-entries.json` - Update entries (if new files)

**Verification**:
- `grep -c "neovim\|nvim\|neotex" .claude/context/processes/research-workflow.md` returns 0 or only incidental enum mentions
- `grep -c "neovim\|nvim" .claude/context/meta/domain-patterns.md` returns 0 or only the generic template placeholder
- All extracted content is accessible via extension context when neovim extension is loaded

---

### Phase 4: Generalize Example Data in Format and Orchestration Docs [COMPLETED]

**Goal**: Replace neovim-specific example values (agent names, file paths, task types) in format and orchestration documentation with generic placeholders or neutral examples.

**Tasks**:
- [ ] Generalize `.claude/context/formats/return-metadata-file.md`:
  - Replace `neovim-research-agent` with `{extension}-research-agent` or generic agent name
  - Replace `nvim/lua/...` paths with `src/module.ext` or similar generic paths
  - Ensure corruption fixes from Phase 1 are preserved
- [ ] Generalize `.claude/context/formats/subagent-return.md`:
  - Replace neovim agent names and lua file paths with generic examples
- [ ] Generalize `.claude/context/formats/frontmatter.md`:
  - Replace neovim-specific agent frontmatter example with generic example
- [ ] Generalize `.claude/context/orchestration/delegation.md`:
  - Replace neovim agent names in JSON examples with generic placeholders
  - Ensure corruption fix from Phase 1 is preserved
- [ ] Generalize `.claude/context/orchestration/orchestration-core.md`:
  - Replace neovim entries in routing tables with `{extension}` placeholder pattern
- [ ] Generalize `.claude/context/orchestration/orchestration-reference.md`:
  - Replace neovim log examples with generic examples
- [ ] Generalize `.claude/context/architecture/system-overview.md`:
  - Replace neovim routing flow and skill mapping with generic extension pattern
- [ ] Generalize `.claude/context/standards/task-management.md`:
  - Replace neovim task type detection rules with generic extension pattern
- [ ] Generalize `.claude/context/formats/report-format.md`:
  - Replace telescope.nvim context gap example with generic example
- [ ] Review `.claude/context/templates/thin-wrapper-skill.md` and `.claude/context/orchestration/orchestrator.md` for neovim references and generalize
- [ ] Final sweep: `grep -rn "neovim\|nvim\|neotex\|treesitter\|telescope\|lazy\.nvim\|mason\|busted\|plenary\|ftplugin" .claude/context/` (excluding extensions/) to catch any remaining references
- [ ] For any remaining references: determine if incidental (leave) or substantive (fix)

**Timing**: 1 hour

**Depends on**: 2, 3

**Files to modify**:
- `.claude/context/formats/return-metadata-file.md` - Generalize examples
- `.claude/context/formats/subagent-return.md` - Generalize examples
- `.claude/context/formats/frontmatter.md` - Generalize examples
- `.claude/context/formats/report-format.md` - Generalize examples
- `.claude/context/orchestration/delegation.md` - Generalize examples
- `.claude/context/orchestration/orchestration-core.md` - Generalize routing tables
- `.claude/context/orchestration/orchestration-reference.md` - Generalize log examples
- `.claude/context/architecture/system-overview.md` - Generalize routing diagram
- `.claude/context/standards/task-management.md` - Generalize detection rules
- `.claude/context/templates/thin-wrapper-skill.md` - Generalize if needed
- `.claude/context/orchestration/orchestrator.md` - Generalize if needed

**Verification**:
- Final grep sweep of `.claude/context/` (excluding `extensions/`) returns only:
  - Incidental mentions in enum lists (e.g., "neovim|general|meta")
  - References to the extension directory itself (e.g., "extensions/nvim/")
  - The extension-development guide (which appropriately uses neovim as a worked example)
- All generalized examples are still clear and useful (not just empty placeholders)
- No broken cross-references

## Testing & Validation

- [ ] `grep -rn "cneovim\|booneovim" .claude/` returns zero matches (corruption eliminated)
- [ ] `grep -rn "neovim\|nvim\|neotex" .claude/context/repo/project-overview.md` returns zero matches
- [ ] Deprecated `orchestration/routing.md` no longer exists
- [ ] `index.json` has no entry for deleted/moved files that no longer exist
- [ ] All new extension files (if created) have corresponding `index-entries.json` entries
- [ ] `.syncprotect` protects the generic `project-overview.md` from overwrite
- [ ] Final sweep of `.claude/context/` (excluding `extensions/`) shows only incidental or appropriate neovim references

## Artifacts & Outputs

- Modified core context files (~15-20 files edited)
- Generic `repo/project-overview.md` template
- Deleted `orchestration/routing.md`
- New extension context files (1-2, if content gaps found)
- Updated `.syncprotect` with protected paths
- Updated `index.json` (removed stale entries, updated descriptions)
- Updated `index-entries.json` in neovim extension (if new files added)

## Rollback/Contingency

All changes are to documentation and context files -- no code changes. Git revert of any phase's commit will cleanly restore the previous state. If generalization makes documentation too abstract, individual files can be reverted independently since phases are scoped to file categories.
