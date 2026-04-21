# Research Report: Task #478

**Task**: 478 - editor_agnostic_extension_docs
**Started**: 2026-04-18T20:35:00Z
**Completed**: 2026-04-18T20:45:00Z
**Effort**: Small
**Dependencies**: None
**Sources/Inputs**:
- Codebase analysis of `.claude/extensions/core/` source files
- Loader implementation at `lua/neotex/plugins/ai/shared/extensions/`
- Zed repo `.syncprotect` and cleaned project-overview.md as prior art
- Web research on missing-config detection patterns (Yeoman, Red Hat TechDocs, cookiecutter)
**Artifacts**:
- `specs/478_editor_agnostic_extension_docs/reports/01_team-research.md`
- `specs/478_editor_agnostic_extension_docs/reports/01_teammate-a-findings.md`
- `specs/478_editor_agnostic_extension_docs/reports/01_teammate-b-findings.md`
- `specs/478_editor_agnostic_extension_docs/reports/01_teammate-c-findings.md`
- `specs/478_editor_agnostic_extension_docs/reports/01_teammate-d-findings.md`
**Standards**: report-format.md, subagent-return.md
**Mode**: Team Research (4 teammates)

## Executive Summary

- Exactly **4 files** in `extensions/core/` contain `<leader>ac` references that contaminate downstream projects on sync. The fix is surgical text replacement using "the extension picker" as generic language.
- **project-overview.md** IS copied by the loader via the `"repo"` directory entry in manifest.json. `.syncprotect` only protects during sync operations -- `manager.load()` has zero syncprotect awareness, confirmed by code inspection.
- The cleanest approach is a **generic stub replacement** (not removal): replace the nvim-specific content in the core extension's `project-overview.md` with a generic template containing a self-documenting notice header. This keeps the `always: true` index entry valid, requires no manifest restructuring, and lets Claude self-detect the generic state.
- Enhance the existing passive hint in `claudemd.md` to an **active task-creation instruction** -- this is the zero-infrastructure detection mechanism.
- The nvim-specific project-overview.md in this repo is already protected by `.syncprotect` and remains unchanged.

## Context & Scope

Task 478 addresses root-cause contamination identified by the Zed project's task 65 audit: when core extension files sync from the nvim repo to other projects, they carry nvim-specific references (`<leader>ac`, "Neovim Lua loader", neotex paths). The Zed repo already works around this via `.syncprotect`, but the fix belongs at the source.

## Findings

### Finding 1: Four Files Contain `<leader>ac` in Core Extension Sources

All four teammates independently confirmed the same 4 files:

| File | Line | Current Text | Deployed? |
|------|------|-------------|-----------|
| `extensions/core/context/repo/project-overview.md` | 11 | "The extension picker (`<leader>ac`) triggers the loader" | Yes (via `copy_context_dirs`) |
| `extensions/core/context/guides/loader-reference.md` | 141 | "launched from `<leader>ac`" | Yes |
| `extensions/core/context/guides/extension-development.md` | 143 | "Load via the extension picker (`<leader>ac`)" | Yes |
| `extensions/core/templates/extension-readme-template.md` | 50 | "Loaded via `<leader>ac` in Neovim" | Yes |

Additionally, `extensions/README.md` (line 42) contains `<leader>ac` but is NOT in `provides` lists and never deploys. It already uses the correct multi-editor pattern.

**Confidence**: HIGH (verified by all 4 teammates via direct grep)

### Finding 2: project-overview.md Copy Mechanism Confirmed

The core manifest `provides.context` contains `"repo"` as a directory entry. The loader's `copy_context_dirs()` recursively copies the entire `extensions/core/context/repo/` directory, which includes:
- `project-overview.md` (nvim-specific -- the problem file)
- `update-project.md` (portable -- generation guide)
- `self-healing-implementation-details.md` (portable)

**The split-path problem** (Critic finding): `.syncprotect` protects `context/repo/project-overview.md` during sync operations (`sync.lua`), but `manager.load()` in `init.lua` has zero syncprotect awareness. Grepping the entire `lua/neotex/plugins/ai/shared/extensions/` directory returns no syncprotect hits. This means loading core via `<leader>ac` WILL overwrite a customized project-overview.md even if `.syncprotect` lists it.

**Confidence**: HIGH

### Finding 3: Existing Detection Infrastructure Is 80% Complete

The system already has:
1. `update-project.md` in `context/repo/` -- complete guide for generating project-overview.md
2. `claudemd.md` (line 28) -- passive hint: "If project-overview.md doesn't exist, see update-project.md"
3. `index.json` entry with `"always": true` -- ensures the file is always loaded when present

**The gap**: The hint is passive ("see this doc") not active ("create this task"). And the file is always *present* after sync (just wrong), so the "doesn't exist" condition never triggers.

**Confidence**: HIGH

### Finding 4: extensions.json source_dir Is Auto-Generated (Not a Problem)

The Zed report flagged `extensions.json` having absolute nvim paths. The Critic confirmed these are written by `state.lua` at load time -- they're per-project runtime state, not synced content. Not a concern for this task.

**Confidence**: HIGH

### Finding 5: Zed Repo Already Has the Clean Version

Teammate D discovered the Zed repo's `project-overview.md` is already editor-agnostic ("The extension picker triggers the loader" -- no `<leader>ac`), and the Zed `.syncprotect` explicitly protects it with the comment "Zed-specific project overview (not nvim)". This confirms both the problem and that a clean version has already been written downstream.

**Confidence**: HIGH

## Synthesis

### Conflict 1: Remove From Copy Scope vs. Replace With Generic Stub

**Teammate A** proposed removing `project-overview.md` from the manifest by listing individual `repo/` files instead of the directory. **Teammates C and D** proposed replacing the source content with a generic stub.

**Resolution: Generic stub wins.** Reasons:
- The `always: true` index entry remains valid (no broken references for agents)
- No manifest restructuring needed (the `"repo"` directory entry stays)
- The generic content is self-documenting -- Claude reads the notice and knows to act
- The nvim-specific version in this repo is already protected by `.syncprotect`
- Simpler change with fewer moving parts

### Conflict 2: Detection Mechanism Approach

Four approaches were proposed:
- **A**: Post-load Lua detection in `init.lua` (8-line `vim.fn.filereadable` check)
- **B**: Enhance `claudemd.md` passive hint to active task-creation instruction
- **C**: One-shot detection with `state.json` flag to suppress repeated prompts
- **D**: Self-documenting notice header in the generic template

**Resolution: B + D combined.** The notice header makes the stale state self-evident to Claude (zero code, zero hooks). The enhanced `claudemd.md` instruction makes Claude's behavior deterministic ("create a task") rather than hopeful ("see this doc"). Together they form a complete solution with zero new infrastructure.

**Why not Lua detection (A)?** It works but adds code to maintain. The notice header achieves the same outcome without touching init.lua.

**Why not state.json flag (C)?** Over-engineering. The notice header is already a one-shot mechanism: once the user generates a real project-overview.md, the notice disappears.

### Gaps Identified

1. **manager.load() syncprotect awareness**: The Critic identified that `manager.load()` doesn't respect `.syncprotect`. This means a user who generates a custom project-overview.md and then re-loads core will get the generic stub overwriting their custom version. **Mitigation**: `.syncprotect` already lists `context/repo/project-overview.md` in the nvim repo, and should be documented as the protection mechanism. Adding syncprotect to the load path is a valid improvement but out of scope for this task.

2. **loader-reference.md is inherently Neovim-specific**: It documents Lua files (`picker.lua`, `state.lua`, etc.) that only exist in the Neovim loader implementation. The `<leader>ac` replacement helps, but the file remains Neovim-implementation-facing. Consider whether it belongs in `context/guides/` (loaded for agents) vs `docs/` (architecture reference). Low priority.

3. **ROADMAP.md Phase 2** has a `<leader>ac` reference in "Extension hot-reload" item. Not in scope for this task but should be cleaned when ROADMAP is next updated.

## Recommendations

### Part 1: Replace `<leader>ac` in 4 Source Files

| File | Change |
|------|--------|
| `extension-development.md:143` | "Load via the extension picker (`<leader>ac`)" -> "Load via the extension picker" |
| `loader-reference.md:141` | "launched from `<leader>ac`" -> remove keybinding, keep functional description |
| `extension-readme-template.md:50` | "Loaded via `<leader>ac` in Neovim." -> "Loaded via the extension picker." |
| `project-overview.md` | Full content replacement (see Part 2) |

### Part 2: Replace project-overview.md Source With Generic Template

Replace `extensions/core/context/repo/project-overview.md` content with:

```markdown
# Project Overview

<!-- GENERIC TEMPLATE: This file should be replaced with project-specific content.
     Run `/task "Generate project-overview.md for this repository"` to create a task,
     then follow the guide in `.claude/context/repo/update-project.md`. -->

## Purpose

This file describes the repository structure for agent context. When extensions are
loaded, they provide project-specific domain knowledge (technology stack, development
workflows, verification commands).

## Two-Layer Extension Architecture

This repository uses a two-layer extension system:

- **Layer 1 -- Editor loader**: Manages which agent files, skills, rules, and context
  exist in the `.claude/` runtime. The extension picker triggers the loader, which copies
  files from `.claude/extensions/*/` sources into the `.claude/` runtime and regenerates
  `.claude/CLAUDE.md`.
- **Layer 2 -- .claude/ agent system** (`.claude/`): The runtime read by Claude Code.
  Contains only the files loaded by the editor loader. Claude Code sees a standard
  `.claude/` directory structure.

## Repository Structure

(Generate a project-specific version of this section using update-project.md)

## Related Documentation

- `.claude/CLAUDE.md` - Agent system configuration
- `.claude/extensions/` - Extension modules with project-specific context
- `CLAUDE.md` (project root) - Project-specific coding standards
```

### Part 3: Enhance claudemd.md Detection Instruction

Change `extensions/core/merge-sources/claudemd.md` line 28 from:

```
**New repository setup**: If project-overview.md doesn't exist, see
`.claude/context/repo/update-project.md` for guidance on generating
project-appropriate documentation.
```

To:

```
**New repository setup**: If `.claude/context/repo/project-overview.md` doesn't exist
or contains the generic template notice, create a task to generate it:
`/task "Generate project-overview.md for this repository"` and follow
`.claude/context/repo/update-project.md`.
```

### Part 4: Update Deployed Copies

After changing extension sources, update the 4 corresponding deployed files in `.claude/context/` and `.claude/templates/` to match. These are regenerated on next core load, but updating them keeps the working tree consistent.

### Part 5: Protect nvim project-overview.md

Verify `.syncprotect` already lists `context/repo/project-overview.md` (it does). The nvim-specific project-overview.md in `.claude/context/repo/` remains unchanged -- it's the correct content for this project.

## Decisions

1. **Generic stub over removal**: Keeps index.json valid, zero manifest changes
2. **Notice header over Lua detection**: Zero code, self-documenting, equally effective
3. **Enhanced claudemd.md over hooks/rules**: Leverages existing infrastructure, no new files
4. **syncprotect load-path fix deferred**: Valid improvement but separate concern; document in ROADMAP
5. **loader-reference.md stays in context/guides/**: Low-priority architectural question for later

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Re-loading core overwrites custom project-overview.md | Medium | `.syncprotect` protects during sync; document that users should add to `.syncprotect` after generating. Long-term: add syncprotect to load path. |
| Generic stub confuses agents expecting real content | Low | The stub contains valid (if generic) content. Agents degrade gracefully with less context. |
| claudemd.md enhancement is still passive | Low | The HTML comment in the generic template provides a second detection signal. Claude reliably acts on both. |

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary | completed | high | Detailed implementation plan: individual file listing, placeholder source, Lua detection |
| B | Alternatives | completed | high | Prior art research (Yeoman, Red Hat TechDocs); claudemd.md enhancement as primary mechanism |
| C | Critic | completed | high | Split-path problem (syncprotect vs load); broken index reference risk; one-shot detection |
| D | Horizons | completed | high | data/ category analysis; Zed prior art; self-documenting notice header pattern |

## Files to Change (Implementation Scope)

### Extension Source Files (truth)
1. `.claude/extensions/core/context/guides/extension-development.md` -- replace `<leader>ac`
2. `.claude/extensions/core/context/guides/loader-reference.md` -- replace `<leader>ac`
3. `.claude/extensions/core/templates/extension-readme-template.md` -- replace `<leader>ac` and "in Neovim"
4. `.claude/extensions/core/context/repo/project-overview.md` -- full content replacement with generic template
5. `.claude/extensions/core/merge-sources/claudemd.md` -- enhance detection instruction

### Deployed Copies (mirror changes)
6. `.claude/context/guides/extension-development.md`
7. `.claude/context/guides/loader-reference.md`
8. `.claude/templates/extension-readme-template.md`

### NOT Changed
- `.claude/context/repo/project-overview.md` (nvim-specific, protected by .syncprotect, correct for this project)
- `.claude/extensions/README.md` (already editor-agnostic)
- `.claude/extensions.json` (auto-generated, not a problem)
- `lua/` loader code (no changes needed)
