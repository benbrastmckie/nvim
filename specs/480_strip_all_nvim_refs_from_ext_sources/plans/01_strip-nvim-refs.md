# Implementation Plan: Strip All Nvim Refs from Extension Sources

- **Task**: 480 - strip_all_nvim_refs_from_ext_sources
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/480_strip_all_nvim_refs_from_ext_sources/reports/01_team-research.md
- **Artifacts**: plans/01_strip-nvim-refs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Third and final pass to strip all remaining nvim/neovim/neotex/VimTeX references from core, latex, memory, and typst extension source files. Tasks 478 and 479 each fixed only a subset; a post-reload audit still finds ~75 actionable references across 18+ files. The implementation edits extension source files by priority tier, mirrors every change to deployed copies under `.claude/`, and verifies with grep returning zero actionable results. Definition of done: the expanded verification grep returns zero lines.

### Research Integration

Team research (4 teammates) produced a comprehensive audit cataloging ~75 references across 3 extension directories. Key findings integrated:
- Priority 1 files confirmed present and untouched by prior tasks
- Memory files are in `extensions/memory/` (not `extensions/core/` as task description stated)
- `settings.local.json` contains 14 stale migration commands (gap found by critic)
- `latex/manifest.json` VimTeX description feeds CLAUDE.md generation (gap found by critic)
- Functional references in postflight-tool-restrictions.md and lint-postflight-boundary.sh must be preserved

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Zero stale references to removed/renamed files in `.claude/`" success metric
- Supports "Subagent-return reference cleanup" pattern (systematic reference elimination)

## Goals & Non-Goals

**Goals**:
- Remove all non-functional nvim/neovim/neotex/VimTeX references from extension sources
- Mirror every source change to its deployed copy under `.claude/`
- Verify zero actionable references remain via grep
- Add prevention check to `check-extension-docs.sh`

**Non-Goals**:
- Modifying the nvim extension itself (it is the nvim extension's own domain)
- Changing functional references (lint regex, postflight tool restrictions)
- Modifying `extensions/core/README.md` (does not deploy)
- Modifying `extensions/latex/README.md` (extension's own docs)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incomplete mirror causes re-contamination on reload | H | M | Phase 4 explicitly maps each source to deployed copy |
| Removing functional references breaks lint or postflight | H | L | Exclusion list verified in research; skip known functional files |
| Replacement examples in memory docs are inconsistent | M | M | Use single canonical set: python/libs/requests throughout |
| Prevention check produces false positives | M | L | Whitelist known functional files in check function |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases are sequential because each priority level builds on the previous, mirroring depends on all source edits being complete, and verification must follow mirroring.

---

### Phase 1: Priority 1 -- Core and Latex Source Fixes [COMPLETED]

**Goal**: Remove all 17+ Priority 1 references from 8 source files (6 from task description + 2 gaps).

**Tasks**:
- [ ] `extensions/latex/EXTENSION.md` (lines 17-22): Remove entire VimTeX Integration subsection
- [ ] `extensions/latex/manifest.json` (line 4): Replace "VimTeX integration" with "latexmk/pdflatex toolchain" in description
- [ ] `extensions/core/agents/code-reviewer-agent.md` (lines 36-38): Remove "Load For Neovim Code" block
- [ ] `extensions/core/docs/README.md` (line 120): Remove nvim routing table row
- [ ] `extensions/core/docs/README.md` (line 191): Remove "moved to nvim extension" tombstone note
- [ ] `extensions/core/docs/docs-README.md` (lines 18, 19): Remove 2 "moved to nvim extension" entries
- [ ] `extensions/core/docs/docs-README.md` (lines 56, 57): Remove 2 more "moved to nvim extension" entries
- [ ] `extensions/core/scripts/validate-wiring.sh` (lines 240-245): Remove nvim) case block
- [ ] `extensions/core/templates/extension-readme-template.md` (line 26): Remove "nvim, " from example list
- [ ] `extensions/core/root-files/settings.local.json` (lines 16-52): Remove 14 stale nvim migration `mv` commands

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `extensions/latex/EXTENSION.md` -- remove VimTeX subsection
- `extensions/latex/manifest.json` -- update description field
- `extensions/core/agents/code-reviewer-agent.md` -- remove neovim code block
- `extensions/core/docs/README.md` -- remove nvim row and tombstone
- `extensions/core/docs/docs-README.md` -- remove 4 tombstone entries
- `extensions/core/scripts/validate-wiring.sh` -- remove nvim case block
- `extensions/core/templates/extension-readme-template.md` -- remove nvim from example
- `extensions/core/root-files/settings.local.json` -- remove stale migration commands

**Verification**:
- `grep -riE 'nvim|vimtex' extensions/core/agents/code-reviewer-agent.md extensions/core/docs/README.md extensions/core/docs/docs-README.md extensions/core/scripts/validate-wiring.sh extensions/core/templates/extension-readme-template.md extensions/latex/EXTENSION.md extensions/latex/manifest.json extensions/core/root-files/settings.local.json` returns zero results

---

### Phase 2: Priority 2 -- Memory Extension Example Replacements [COMPLETED]

**Goal**: Replace all ~26 neovim/telescope example references across 7 memory extension files with python/libs/requests equivalents.

**Tasks**:
- [ ] `extensions/memory/skills/skill-memory/SKILL.md` (~10 refs): Replace neovim/telescope topic examples with python/libs/requests
- [ ] `extensions/memory/context/project/memory/learn-usage.md` (~12 refs): Replace neovim topic paths with python examples
- [ ] `extensions/memory/context/project/memory/memory-setup.md` (1 ref): Replace MEM-neovim-lsp slug with MEM-project-code-patterns
- [ ] `extensions/memory/context/project/memory/knowledge-capture-usage.md` (1 ref): Replace neovim example with python equivalent
- [ ] `extensions/memory/context/project/memory/domain/memory-reference.md` (1 ref): Replace topic path
- [ ] `extensions/memory/commands/learn.md` (1 ref): Replace ~/notes/neovim/ path with ~/notes/python/
- [ ] `extensions/memory/data/.memory/README.md` (3 refs): Replace MEM-neovim examples with MEM-project-code-patterns

**Canonical replacements**:
- Topic path: `neovim/telescope` -> `python/libs/requests`
- Slug: `MEM-neovim-lsp` -> `MEM-project-code-patterns`
- Directory: `~/notes/neovim/` -> `~/notes/python/`
- Subject matter: telescope.nvim, LSP config -> requests library, HTTP patterns

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `extensions/memory/skills/skill-memory/SKILL.md` -- replace example topics
- `extensions/memory/context/project/memory/learn-usage.md` -- replace example topics
- `extensions/memory/context/project/memory/memory-setup.md` -- replace slug
- `extensions/memory/context/project/memory/knowledge-capture-usage.md` -- replace example
- `extensions/memory/context/project/memory/domain/memory-reference.md` -- replace topic path
- `extensions/memory/commands/learn.md` -- replace directory path
- `extensions/memory/data/.memory/README.md` -- replace slug examples

**Verification**:
- `grep -riE 'nvim|neovim|neotex|telescope' extensions/memory/ --include='*.md'` returns zero results

---

### Phase 3: Priority 3 -- Compilation Guide Fixes [COMPLETED]

**Goal**: Remove or genericize nvim references in latex and typst compilation guides.

**Tasks**:
- [ ] `extensions/latex/context/project/latex/tools/compilation-guide.md` (line 222): Remove "Neovim with VimTeX" from editor list
- [ ] `extensions/typst/context/project/typst/tools/compilation-guide.md` (lines 58-64): Replace "Neovim Integration" section with generic "Editor Integration" section
- [ ] `extensions/latex/context/project/latex/tools/README.md` (line 9): Replace "VimTeX integration" with generic tool reference
- [ ] `extensions/core/docs/architecture/extension-system.md` (lines 163, 513): Replace "VimTeX integration" in example JSON descriptions

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `extensions/latex/context/project/latex/tools/compilation-guide.md` -- remove VimTeX from editor list
- `extensions/typst/context/project/typst/tools/compilation-guide.md` -- genericize editor integration section
- `extensions/latex/context/project/latex/tools/README.md` -- genericize tool reference
- `extensions/core/docs/architecture/extension-system.md` -- update example descriptions

**Verification**:
- `grep -riE 'nvim|neovim|vimtex' extensions/latex/context/ extensions/typst/context/ extensions/core/docs/architecture/extension-system.md` returns zero results (excluding extensions/latex/README.md)

---

### Phase 4: Mirror All Changes to Deployed Copies [COMPLETED]

**Goal**: Copy every modified source file to its deployed location under `.claude/`.

**Tasks**:
- [ ] Mirror `extensions/core/agents/code-reviewer-agent.md` -> `.claude/agents/code-reviewer-agent.md`
- [ ] Mirror `extensions/core/docs/README.md` -> `.claude/docs/README.md`
- [ ] Mirror `extensions/core/docs/docs-README.md` -> `.claude/docs/docs-README.md`
- [ ] Mirror `extensions/core/scripts/validate-wiring.sh` -> `.claude/scripts/validate-wiring.sh`
- [ ] Mirror `extensions/core/templates/extension-readme-template.md` -> `.claude/templates/extension-readme-template.md`
- [ ] Mirror `extensions/core/root-files/settings.local.json` -> `.claude/settings.local.json`
- [ ] Mirror `extensions/core/docs/architecture/extension-system.md` -> `.claude/docs/architecture/extension-system.md`
- [ ] Mirror `extensions/memory/skills/skill-memory/SKILL.md` -> `.claude/skills/skill-memory/SKILL.md`
- [ ] Mirror `extensions/memory/context/project/memory/learn-usage.md` -> `.claude/context/project/memory/learn-usage.md`
- [ ] Mirror `extensions/memory/context/project/memory/memory-setup.md` -> `.claude/context/project/memory/memory-setup.md`
- [ ] Mirror `extensions/memory/context/project/memory/knowledge-capture-usage.md` -> `.claude/context/project/memory/knowledge-capture-usage.md`
- [ ] Mirror `extensions/memory/context/project/memory/domain/memory-reference.md` -> `.claude/context/project/memory/domain/memory-reference.md`
- [ ] Mirror `extensions/memory/commands/learn.md` -> `.claude/commands/learn.md`
- [ ] Note: `extensions/memory/data/.memory/README.md` has no deployed copy (skip)
- [ ] Note: latex/typst context files deploy within their extension directories (verify paths)

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- All deployed copies listed above (cp from source)

**Verification**:
- `diff` each source against its deployed copy shows no differences

---

### Phase 5: Add Prevention Check [COMPLETED]

**Goal**: Extend `check-extension-docs.sh` with a `check_core_purity()` function that detects nvim/neovim/VimTeX references in non-nvim extension sources.

**Tasks**:
- [ ] Add `check_core_purity()` function to `extensions/core/scripts/check-extension-docs.sh`
- [ ] Function should grep for `nvim|neovim|neotex|vimtex` in `extensions/core/`, `extensions/latex/`, `extensions/memory/`, `extensions/typst/`
- [ ] Whitelist known functional files: `lint-postflight-boundary.sh`, `postflight-tool-restrictions.md`, `extensions/core/README.md`, `extensions/latex/README.md`
- [ ] Exit non-zero if any non-whitelisted match found
- [ ] Mirror updated script to `.claude/scripts/check-extension-docs.sh`

**Timing**: 20 minutes

**Depends on**: 4

**Files to modify**:
- `extensions/core/scripts/check-extension-docs.sh` -- add check_core_purity function
- `.claude/scripts/check-extension-docs.sh` -- mirror

**Verification**:
- Run `bash extensions/core/scripts/check-extension-docs.sh` and confirm check_core_purity passes (exit 0)

---

### Phase 6: Final Verification [NOT STARTED]

**Goal**: Run comprehensive grep to confirm zero actionable nvim references remain across all extension sources and deployed copies.

**Tasks**:
- [ ] Run expanded verification grep across all extension directories and `.claude/`
- [ ] Exclude known functional files and nvim extension's own files
- [ ] Confirm zero results
- [ ] If any results found, fix and re-mirror

**Verification grep**:
```bash
grep -riE 'nvim|neovim|neotex|vimtex' \
  .claude/extensions/core/ \
  .claude/extensions/latex/ \
  .claude/extensions/memory/ \
  .claude/extensions/typst/ \
  .claude/agents/ .claude/docs/ .claude/scripts/ \
  .claude/skills/ .claude/context/ .claude/commands/ \
  .claude/templates/ \
  --include='*.md' --include='*.sh' --include='*.json' \
  | grep -v 'extensions/core/README.md' \
  | grep -v 'extensions/latex/README.md' \
  | grep -v 'lint-postflight-boundary.sh' \
  | grep -v 'postflight-tool-restrictions.md' \
  | grep -v 'extensions/nvim/' \
  | grep -v 'context/project/neovim/'
```

**Timing**: 10 minutes

**Depends on**: 5

**Verification**:
- Grep returns zero lines

## Testing & Validation

- [ ] Priority 1 grep returns zero results after Phase 1
- [ ] Priority 2 grep returns zero results after Phase 2
- [ ] Priority 3 grep returns zero results after Phase 3
- [ ] All source-to-deployed diffs show zero differences after Phase 4
- [ ] check-extension-docs.sh exits 0 after Phase 5
- [ ] Comprehensive verification grep returns zero actionable lines after Phase 6

## Artifacts & Outputs

- `specs/480_strip_all_nvim_refs_from_ext_sources/plans/01_strip-nvim-refs.md` (this plan)
- `specs/480_strip_all_nvim_refs_from_ext_sources/summaries/01_strip-nvim-refs-summary.md` (after implementation)
- Modified extension source files (~20 files across core, latex, memory, typst)
- Modified deployed copies (~15 files under `.claude/`)
- Updated `check-extension-docs.sh` with prevention check

## Rollback/Contingency

All changes are text edits to markdown, JSON, and shell files tracked in git. Rollback via `git checkout HEAD -- <file>` for any individual file, or `git revert` for the entire commit. The extension loader will re-deploy source versions on next reload, so reverting source files is sufficient.
