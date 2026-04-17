# Research Report: Task #468

**Task**: Document extension loader architecture and .claude/ lifecycle
**Date**: 2026-04-17
**Mode**: Team Research (4 teammates)

## Summary

The extension system documentation has significant factual errors and a fundamental conceptual gap. Four parallel research angles converge on the same core finding: the two-layer architecture (Neovim Lua loader vs .claude/ agent system) is never explicitly documented anywhere, and the CLAUDE.md generation mechanism changed from section-injection to full-file regeneration but docs were never updated. All four teammates reached high confidence independently.

## Key Findings

### 1. CLAUDE.md Is a Computed Artifact (All 4 Teammates Confirmed)

**The single most critical inaccuracy across all documentation.** Every document that references CLAUDE.md generation describes the old `inject_section()` / `remove_section()` approach with `<!-- SECTION: ... -->` markers. The actual code (`init.lua`, `merge.lua`) uses `generate_claudemd()` which rebuilds the entire file from scratch on every load/unload operation.

Code evidence (`init.lua:81-83`):
```lua
-- Config markdown (CLAUDE.md or OPENCODE.md) is now a computed artifact.
-- Section injection is skipped here; generate_claudemd() regenerates the file
-- from all loaded extensions after each load/unload operation.
```

The `section_id` field in manifests is vestigial for load/unload (though still used by sync.lua -- see Finding 7).

**Stale references found in:**
- `docs/architecture/extension-system.md` -- section markers, inject_section docs
- `docs/guides/creating-extensions.md` -- EXTENSION.md as source, section marker test
- `extensions/core/context/guides/extension-development.md` -- section_id injection docs
- `.claude/extensions/README.md` -- load step 4 description, verification check

### 2. Two-Layer Architecture Is Never Named (All 4 Teammates Confirmed)

No document in `.claude/` or `docs/` explicitly explains that:

- **Layer 1 (Neovim Lua)**: Extension loader at `lua/neotex/plugins/ai/shared/extensions/` -- Neovim plugin code that manages which files exist in `.claude/`. 8 files, ~3,500 LOC. Has no dependency on `.claude/` to function.
- **Layer 2 (Claude Code Markdown/JSON)**: Agent system in `.claude/` -- files consumed by Claude Code CLI after extensions are loaded.

Confirmed by grep: zero hits for "shared/extensions", "two-layer", "Layer 1", "Neovim.*loader" across all `.claude/` docs. This conflation was the root cause of the "bootstrap impossibility" error in task 465 history. Cross-project users who sync the agent system to other repos would be especially confused since they never see the Lua layer.

### 3. Unload Dependents Is a Hard Block (Teammates A, C Confirmed)

Documentation says: "Show warning, proceed with user confirmation."
Actual code (`init.lua:575-587`): Hard block with `return false, msg` -- no confirmation path exists.

### 4. Missing Copy Categories in Documentation (Teammates A, C Confirmed)

`loader.lua` has 12 public functions but docs list only 6. Missing from docs:
- `copy_hooks()` -- .sh files with execute permissions preserved
- `copy_docs()` -- documentation files
- `copy_templates()` -- template files
- `copy_systemd()` -- systemd unit files
- `copy_root_files()` -- files placed at `.claude/` root
- `copy_data_dirs()` -- merge-copy semantics, copied to project root

The extension directory structure diagram also omits: `hooks/`, `docs/`, `templates/`, `systemd/`, `root-files/`, `merge-sources/`.

### 5. EXTENSION.md vs merge-sources/claudemd.md Pattern (Teammates A, B, C)

Core extension uses `merge-sources/claudemd.md` (353 lines) as its CLAUDE.md source, not `EXTENSION.md`. Other extensions use `EXTENSION.md`. This divergence is mentioned only in a generated HTML comment in CLAUDE.md but not in any guide. Extension creators would not know about the `merge-sources/` pattern.

### 6. Settings Merging Documentation Is Wrong (Teammate A)

`extension-system.md` shows settings merging via `mcp_servers` key in manifest root. Actual code uses `merge_targets.settings` with a `source` JSON fragment file. The documented `mcp_servers` field does not correspond to any code path.

### 7. Conflict Handling Is Wrong in Docs (Teammate A)

`extension-system.md` says "loading is aborted" on file conflicts. Actual code shows conflicts are presented in a confirmation dialog -- user can proceed. Only dependency failures or rollback failures abort loading.

### 8. Sync System Uses Different CLAUDE.md Strategy (Teammate C)

The sync system (`sync.lua`) uses `inject_section()` while load/unload uses `generate_claudemd()`. This represents either technical debt or an intentional design choice, but the relationship is not documented anywhere. The `section_id` field is still operative for sync but vestigial for load/unload.

### 9. copy_context_dirs() Dual Behavior Undocumented (Teammate C)

Task 470 fixed `copy_context_dirs()` to handle both directory names AND individual file paths in `provides.context`. Existing docs only show directory examples.

### 10. Routing Table Redundancy (Teammate B)

Routing tables appear in 3 places per extension: `manifest.json` (machine-readable), `EXTENSION.md` (agent-facing), `README.md` (human-facing). No tooling validates consistency. Minor divergences exist (column naming, tool lists). Two extensions exceed the 60-line EXTENSION.md standard: `nix` (62) and `present` (64).

### 11. "Source vs Loaded" Vocabulary Missing (Teammate D)

No documentation distinguishes "extension source" (`.claude/extensions/*/`) from "loaded runtime" (`.claude/{agents,commands,...}/`). References to `.claude/agents/` are ambiguous -- could mean the source or the loaded destination.

### 12. ROADMAP Alignment (Teammate D)

Task 468 is a **prerequisite enabler** for all three ROADMAP Phase 1 documentation items:
- Manifest-driven README generation -- requires accurate architecture docs
- CI enforcement of doc-lint -- requires docs to be correct first
- `/review` drift detection -- requires defining what "correct" looks like

Task 474 (core README) is directly adjacent and should reference 468's architecture clarity.

## Synthesis

### Conflicts Resolved

1. **Scope of changes**: Teammates A and C cataloged all files needing updates (6+ files), while B recommended a minimal "Two-Layer Architecture" section (~25 lines) and D recommended targeted additions (~50-80 lines). **Resolution**: The factual errors (Findings 1, 3, 4, 6, 7) require multi-file updates regardless of approach. The two-layer architecture explanation (Finding 2) should be a targeted addition to the existing `extension-system.md` rather than a new document, as all teammates agree the existing doc is well-structured. One new document (loader function reference) is justified per D's recommendation since it serves future maintenance.

2. **New document vs update existing**: B favored pure updates to existing docs; D suggested one new reference document. **Resolution**: Both. Update existing docs for factual accuracy AND create one new `loader-reference.md` context file for agent-accessible loader documentation. This serves different audiences: docs/ for human developers, context/ for agents.

### Gaps Identified

1. **Sync system architecture** -- No teammate fully investigated sync.lua's relationship to the loader. The inject_section vs generate_claudemd inconsistency needs clarification before documenting.
2. **Verification system** -- verify.lua's fingerprint-based check (replacing section marker check) needs documentation update but was only partially covered.
3. **Test coverage for docs** -- No existing test validates that documentation matches code behavior. The `check-extension-docs.sh` script validates file existence but not content accuracy.

### Recommendations

**Priority 1 (Critical -- Factual Errors)**:
- Fix CLAUDE.md generation docs: replace inject_section with generate_claudemd across all files
- Fix unload dependents: "hard block" not "user confirmation"
- Fix conflict handling: "confirmation dialog" not "abort"
- Fix settings merging: merge_targets.settings not mcp_servers
- Expand loader function list and extension directory structure

**Priority 2 (High -- Architecture Gap)**:
- Add "Two-Layer Architecture" section to `extension-system.md` naming the Lua source path and explaining the separation
- Establish "source vs loaded" vocabulary in extension-development.md
- Update project-overview.md to show the two-phase lifecycle

**Priority 3 (Medium -- Missing Documentation)**:
- Document merge-sources/claudemd.md vs EXTENSION.md pattern
- Document copy_context_dirs() dual behavior (post-task-470)
- Create loader-reference.md context file (function-to-category table)

**Priority 4 (Low -- Maintenance)**:
- Add routing table validation to check-extension-docs.sh
- Coordinate with task 474 (core README)
- Fix nix/present EXTENSION.md exceeding 60-line standard
- Clarify sync.lua vs load/unload CLAUDE.md strategy

### Files Requiring Updates (Priority Order)

| File | Issues | Priority |
|------|--------|----------|
| `.claude/docs/architecture/extension-system.md` | Section markers, inject_section, conflict handling, settings merging, missing functions, unload behavior, add two-layer section | HIGH |
| `.claude/docs/guides/creating-extensions.md` | EXTENSION.md source, section_id, section marker test, missing categories | HIGH |
| `.claude/extensions/core/context/guides/extension-development.md` | Stale inject_section docs, source file name, structure template, add vocabulary | HIGH |
| `.claude/extensions/README.md` | Load step 4, verification check | MEDIUM |
| `.claude/extensions/core/context/repo/project-overview.md` | Missing loader architecture, two-phase lifecycle | MEDIUM |
| NEW: `.claude/extensions/core/context/guides/loader-reference.md` | Loader function-to-category table | MEDIUM |

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary (code audit) | completed | high |
| B | Alternatives (doc patterns) | completed | high |
| C | Critic (gap analysis) | completed | high |
| D | Horizons (strategic) | completed | high |

## References

### Source Code (Layer 1)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- Public API, load/unload orchestration
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` -- File copy engine (12 functions)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` -- generate_claudemd(), index/settings merge
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` -- Manifest parsing, VALID_PROVIDES
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` -- Post-load verification
- `lua/neotex/plugins/ai/shared/extensions/state.lua` -- extensions.json management
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` -- Telescope picker UI
- `lua/neotex/plugins/ai/shared/extensions/config.lua` -- Claude vs OpenCode presets

### Documentation (Layer 2)
- `.claude/docs/architecture/extension-system.md` -- Primary architecture reference
- `.claude/docs/guides/creating-extensions.md` -- Extension authoring guide
- `.claude/extensions/core/context/guides/extension-development.md` -- Agent-facing dev guide
- `.claude/extensions/README.md` -- Extensions directory overview
- `.claude/extensions/core/context/repo/project-overview.md` -- Project overview
- `specs/ROADMAP.md` -- Project roadmap (documentation items)
