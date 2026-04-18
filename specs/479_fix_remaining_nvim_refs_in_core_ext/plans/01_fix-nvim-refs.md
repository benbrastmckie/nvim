# Implementation Plan: Task #479

- **Task**: 479 - fix_remaining_nvim_refs_in_core_ext
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: None (task 478 completed)
- **Research Inputs**: specs/479_fix_remaining_nvim_refs_in_core_ext/reports/01_nvim-refs-audit.md
- **Artifacts**: plans/01_fix-nvim-refs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Fix 6 remaining nvim/neotex references in core extension source files and their deployed copies. All changes are targeted text replacements identified by the research audit. The meta-guide.md duplicate path bug is also fixed in the same pass.

### Research Integration

The research report identified 6 distinct issues across 7 source files (plus deployed copies), totaling ~12 file edits. All replacements are exact string substitutions with no logic changes.

### Roadmap Alignment

Advances "Zero stale references to removed/renamed files in `.claude/`" success metric. Also tangentially supports "Subagent-return reference cleanup" by continuing the pattern of sweeping project-specific references from core files.

## Goals & Non-Goals

**Goals**:
- Remove all nvim/neotex-specific language from core extension source files
- Fix the duplicate path bug in meta-guide.md
- Mirror all source changes to deployed copies for immediate effect

**Non-Goals**:
- Modifying project-specific files (e.g., project-overview.md)
- Editing `.claude/CLAUDE.md` directly (regenerated from templates on reload)
- Changing extension-system.md box dimensions (only replace text within existing alignment)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Box-drawing misalignment in extension-system.md | M | M | Count characters carefully; verify column alignment matches 65-char internal width |
| Stale CLAUDE.md after template fix | L | L | Deployed template is updated; CLAUDE.md regenerates on next extension reload |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Source Files [COMPLETED]

**Goal**: Apply all 6 text replacements to core extension source files.

**Tasks**:
- [ ] Issue 1: In `.claude/extensions/core/templates/claudemd-header.md` line 5, replace `neotex extension loader` with `extension loader`
- [ ] Issue 2: In `.claude/extensions/core/context/guides/extension-development.md` line 11, replace `a Neovim Lua loader` with `an extension loader`
- [ ] Issue 2b: In `.claude/extensions/core/docs/architecture/extension-system.md` line 45, replace `Neovim Lua Loader` with `Extension Loader` (preserve box-drawing alignment to 65-char internal width)
- [ ] Issue 2b: In same file line 54, replace `Extension picker UI in Neovim` with `Extension picker UI (editor-specific)` (preserve box-drawing alignment)
- [ ] Issue 3a: In `.claude/extensions/core/context/architecture/system-overview.md` line 387, replace `neovim, lean4, latex, typst` with `nix, lean4, latex, typst`
- [ ] Issue 3b: In `.claude/extensions/core/docs/architecture/system-overview.md` line 198, replace `neovim, latex, typst, python` with `nix, latex, typst, python`
- [ ] Issue 3c: In `.claude/extensions/core/merge-sources/claudemd.md` line 73, replace `neovim, lean4, latex, typst, python, nix,` with `lean4, latex, typst, python, nix,`
- [ ] Issue 4: In `.claude/extensions/core/context/meta/meta-guide.md` line 450, replace `'.claude/README.md', '.claude/README.md'` with `'.claude/docs/README.md', '.claude/README.md'`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/templates/claudemd-header.md` - Remove "neotex" prefix
- `.claude/extensions/core/context/guides/extension-development.md` - Replace "Neovim Lua loader"
- `.claude/extensions/core/docs/architecture/extension-system.md` - Replace box-drawing labels (2 lines)
- `.claude/extensions/core/context/architecture/system-overview.md` - Replace "neovim" in example list
- `.claude/extensions/core/docs/architecture/system-overview.md` - Replace "neovim" in example list
- `.claude/extensions/core/merge-sources/claudemd.md` - Remove "neovim" from example list
- `.claude/extensions/core/context/meta/meta-guide.md` - Fix duplicate path

**Verification**:
- Grep for `neotex` in `.claude/extensions/core/` returns no hits
- Grep for `Neovim Lua` in `.claude/extensions/core/` returns no hits (case-insensitive)
- Grep for `neovim` in `.claude/extensions/core/` returns no hits in the modified files (may exist in nvim extension references which are expected)
- meta-guide.md contains `.claude/docs/README.md` (not duplicated)

---

### Phase 2: Mirror to Deployed Copies [COMPLETED]

**Goal**: Apply identical replacements to deployed copies under `.claude/` for immediate effect.

**Tasks**:
- [ ] In `.claude/templates/claudemd-header.md` line 5, apply same Issue 1 fix
- [ ] In `.claude/context/guides/extension-development.md` line 11, apply same Issue 2 fix
- [ ] In `.claude/docs/architecture/extension-system.md` lines 45 and 54, apply same Issue 2b fixes
- [ ] In `.claude/context/architecture/system-overview.md` line 387, apply same Issue 3a fix
- [ ] In `.claude/docs/architecture/system-overview.md` line 198, apply same Issue 3b fix
- [ ] In `.claude/context/meta/meta-guide.md` line 450, apply same Issue 4 fix

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/templates/claudemd-header.md` - Mirror Issue 1
- `.claude/context/guides/extension-development.md` - Mirror Issue 2
- `.claude/docs/architecture/extension-system.md` - Mirror Issue 2b
- `.claude/context/architecture/system-overview.md` - Mirror Issue 3a
- `.claude/docs/architecture/system-overview.md` - Mirror Issue 3b
- `.claude/context/meta/meta-guide.md` - Mirror Issue 4

**Verification**:
- Grep for `neotex` in `.claude/` (excluding extensions/) returns no hits
- Grep for `Neovim Lua` in `.claude/` (excluding extensions/ and project-specific files) returns no hits
- meta-guide.md deployed copy contains `.claude/docs/README.md`

## Testing & Validation

- [ ] `grep -ri "neotex" .claude/extensions/core/` returns no matches
- [ ] `grep -ri "neovim lua loader" .claude/extensions/core/` returns no matches
- [ ] `grep -ri "neotex" .claude/templates/ .claude/context/ .claude/docs/` returns no matches
- [ ] Box-drawing in extension-system.md visually inspected for alignment
- [ ] meta-guide.md contains correct `.claude/docs/README.md` path (both source and deployed)

## Artifacts & Outputs

- plans/01_fix-nvim-refs.md (this plan)
- summaries/01_fix-nvim-refs-summary.md (after implementation)

## Rollback/Contingency

All changes are text replacements in tracked files. Revert with `git checkout -- .claude/` to restore previous state. No structural or logic changes are involved.
