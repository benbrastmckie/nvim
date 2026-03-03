# Supplementary Research Report: Task #121

**Task**: 121 - clean_up_core_skills_directories
**Started**: 2026-03-03
**Completed**: 2026-03-03
**Effort**: 2-4 hours
**Dependencies**: Task 118 (extension exclusion filtering) - already completed
**Sources/Inputs**: Codebase analysis (sync.lua, loader.lua, init.lua, config.lua, state.lua, manifest.lua, scan.lua, picker/init.lua), directory listings across all three artifact trees, extension manifests, web research on modular architecture patterns
**Artifacts**: specs/121_clean_up_core_skills_directories/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The current architecture has a fundamental asymmetry: `.claude/` source directories are already clean (extension artifacts only in `extensions/`), but `.opencode/` source directories are contaminated (extension artifacts exist in BOTH `extensions/` AND core directories)
- The user's request to "only load what you need" is achievable through a two-phase redesign: (1) clean the `.opencode/` source directories so they mirror `.claude/`'s clean separation, then (2) simplify sync.lua by removing the exclusion filter machinery entirely since clean sources need no filtering
- The recommended architecture follows the "single source of truth" principle: core artifacts live ONLY in core directories, extension artifacts live ONLY in `extensions/{name}/` directories, and the sync operation becomes a simple full-directory copy with no filtering
- This eliminates the need for post-hoc cleanup operations entirely -- the system produces no waste by design

## Context and Scope

### The User's Request

The user wants to redesign the system so that "Load Core Agent System" only loads core dependencies, and "Load Extension" only loads extension dependencies, without ever producing artifacts that require cleanup. This is a shift from the current "copy everything then filter" approach to a "clean source" approach.

### Prior Research (research-001.md)

Research-001 documented the contamination inventory and root cause (pre-task-118 syncs without filtering). It recommended a cleanup operation driven by extension manifests. However, the user's supplementary request asks for a deeper redesign that prevents contamination from ever occurring -- an architectural solution rather than a cleanup tool.

### Current Architecture

The system has three layers:

```
Global Source (~/.config/nvim/)
  |
  +-- .claude/          # Core artifacts (commands, agents, skills, rules, etc.)
  |     +-- extensions/ # Extension artifact packages (each with manifest.json)
  |
  +-- .opencode/        # Core artifacts (commands, agent/subagents, skills, rules, etc.)
        +-- extensions/ # Extension artifact packages (each with manifest.json)

Sync Operations:
  "Load Core Agent System" -> copies from global source core dirs to target project
  "Load Extension"         -> copies from global source extensions/{name}/ to target project
```

## Findings

### 1. The Asymmetry Problem

The `.claude/` and `.opencode/` source directories are NOT in the same state:

**`.claude/` source (CLEAN):**
- `agents/` contains ONLY 6 core agents (general-implementation, general-research, meta-builder, neovim-implementation, neovim-research, planner)
- `skills/` contains ONLY 11 core skills
- `commands/` contains ONLY 11 core commands
- `rules/` contains ONLY 6 core rules
- Extension artifacts live exclusively in `extensions/{name}/`

**`.opencode/` source (CONTAMINATED):**
- `agent/subagents/` contains 15 agents (6 core + 9 extension-owned)
- `skills/` contains 22 skills (11 core + 11 extension-owned)
- `commands/` contains 14 commands (11 core + 3 extension-owned)
- `rules/` contains 7 rules (5 core + 2 extension-owned)
- Extension artifacts exist in BOTH `extensions/{name}/` AND core directories

This means:
- For `.claude/`, the sync exclusion filter from task 118 is technically unnecessary because the source is already clean
- For `.opencode/`, the filter is necessary but also insufficient -- it only prevents NEW copies during sync; it does not prevent the source from being used by other tools (like direct file operations) that bypass the filter

### 2. Root Cause of the Asymmetry

The `.claude/` system was developed first and evolved organically. Extension artifacts were moved from core directories into `extensions/` as the extension system was built. The source `.claude/` directories were cleaned at that time.

The `.opencode/` system was created later as a parallel of `.claude/`. When its directories were initially populated (Feb 27), ALL artifacts (core + extension) were placed into the core directories. The `extensions/` copies were also created, resulting in duplication.

### 3. The "Load Only What You Need" Design

The user's desired behavior maps to a clean architectural principle:

```
Principle: Sources contain EXACTLY what they provide. No filtering needed.

"Load Core Agent System" for .claude:
  Scan .claude/agents/*.md        -> copy all (these are ALL core)
  Scan .claude/skills/*/           -> copy all (these are ALL core)
  Scan .claude/commands/*.md       -> copy all (these are ALL core)
  ... etc.
  NO FILTERING NEEDED.

"Load Extension: lean" for .claude:
  Scan .claude/extensions/lean/agents/      -> copy all
  Scan .claude/extensions/lean/skills/      -> copy all
  Scan .claude/extensions/lean/commands/    -> copy all
  ... etc.
  NO FILTERING NEEDED.
```

This is already how `.claude/` works today (with the unnecessary filter as dead code). The `.opencode/` system needs to be brought to parity.

### 4. Best Practices from Package Management Systems

Research into modular architecture patterns confirms the "single source of truth" principle:

**Nix/Home-Manager**: Each package declares what it provides. The store contains isolated package outputs. No package's outputs are mixed with another's. When activating a profile, symlinks compose the final environment from isolated sources.

**lazy.nvim**: Each plugin spec declares its files. The plugin directory contains only that plugin's files. Dependencies are declared explicitly and loaded on demand. No plugin's files contaminate another plugin's directory.

**npm/cargo**: Packages live in isolated directories. The registry contains no cross-package mixing. Installation copies from the isolated source to `node_modules/{package}/`.

The common thread: **the source of truth for what a module provides is the module's own directory, and that directory contains ONLY that module's files.**

### 5. Recommended Architecture: Clean Source Directories

**Design principle**: The `.opencode/` core directories should contain ONLY core artifacts. Extension artifacts should exist ONLY in `extensions/{name}/`.

**Required changes:**

#### Phase 1: Clean the `.opencode/` Source Directories

Remove extension-owned artifacts from `.opencode/` core directories at the global source (`~/.config/nvim/.opencode/`):

| Category | Files to Remove | Count |
|----------|----------------|-------|
| agent/subagents/ | document-converter-agent.md, latex-implementation-agent.md, latex-research-agent.md, lean-implementation-agent.md, lean-research-agent.md, logic-research-agent.md, math-research-agent.md, typst-implementation-agent.md, typst-research-agent.md | 9 |
| skills/ | skill-document-converter, skill-latex-implementation, skill-latex-research, skill-lean-implementation, skill-lean-research, skill-lake-repair, skill-lean-version, skill-logic-research, skill-math-research, skill-typst-implementation, skill-typst-research | 11 |
| commands/ | convert.md, lake.md, lean.md | 3 |
| rules/ | latex.md, lean4.md | 2 |

**Total**: 25 artifacts to remove from source.

All of these already have copies in their respective `extensions/{name}/` directories, so no data is lost.

#### Phase 2: Clean Target Directories

Same removal for any previously-synced target directories:
- `~/.config/.claude/` (3 extra skills, 3 extra agents, 1 extra command, 1 extra rule)
- Any other project directories that were synced before task 118

#### Phase 3: Simplify sync.lua

With clean source directories, the extension exclusion filter becomes dead code and can be removed. This simplifies `scan_all_artifacts()`:

**Current flow** (451 lines in sync.lua):
```
scan_all_artifacts():
  build_extension_exclusions()     # ~80 lines
  scan each category               # ~100 lines
  filter_extension_files()         # for agents, commands, rules, scripts, hooks
  filter_extension_skills()        # for skills
  filter_extension_context()       # for context
```

**Proposed flow** (~250 lines estimated):
```
scan_all_artifacts():
  scan each category               # ~100 lines
  (no filtering needed - source is clean)
```

Functions that can be removed:
- `build_extension_exclusions()` (lines 24-107)
- `filter_extension_files()` (lines 114-126)
- `filter_extension_skills()` (lines 132-152)
- `filter_extension_context()` (lines 159-188)

The `CONTEXT_EXCLUDE_PATTERNS` constant (lines 15-18) should be retained as it serves a different purpose (excluding repository-specific files, not extension files).

#### Phase 4: Verify Parity Between Systems

After cleanup, both systems should have matching core artifact counts:

| Category | .claude Count | .opencode Count | Location |
|----------|--------------|----------------|----------|
| Agents | 6 | 6 (+1 orchestrator) | agents/ or agent/subagents/ |
| Skills | 11 | 11 | skills/ |
| Commands | 11 | 11 | commands/ |
| Rules | 6 | 5-6 | rules/ |

### 6. Uniform Treatment of .claude and .opencode

Both systems should follow the same invariant:

```
INVARIANT: For every artifact A in {base_dir}/{category}/,
           there exists NO extension E where A is in E.manifest.provides[category].

Equivalently: core directories and extension directories are DISJOINT.
```

The sync.lua code already supports both systems through the `config.base_dir` parameter. The cleanup and simplification should be applied uniformly.

### 7. Extension Loading Architecture (Already Correct)

The extension loader (`loader.lua`) already follows the correct pattern. When "Load Extension" runs:

1. Reads manifest from `extensions/{name}/manifest.json`
2. Copies from `extensions/{name}/agents/` to target `{base_dir}/agents/`
3. Copies from `extensions/{name}/skills/` to target `{base_dir}/skills/`
4. Tracks installed files in `extensions.json` for clean unload

This is already "load only what you need" for extensions. No changes needed.

### 8. Context Directory Handling

Context directories require special treatment. The `CONTEXT_EXCLUDE_PATTERNS` list in sync.lua excludes repository-specific files (like `project/repo/project-overview.md`) that should not be synced to other projects. This is NOT related to extensions and should be preserved.

Extension context (like `project/lean4/`) should follow the same clean-source rule: it should exist ONLY in `extensions/{name}/context/`, not in the core `context/` directory. This is already the case for `.claude/` but needs verification for `.opencode/`.

### 9. Impact on Active Sessions

Cleaning the source directories at `~/.config/nvim/` is safe because:
- The source directories are not directly used by Claude Code or OpenCode
- Target project directories have their own copies
- Extensions are loaded from `extensions/{name}/` (which retains all files)

Cleaning target directories (like `~/.config/.claude/`) may affect active sessions. Recommendation: close active AI sessions before cleaning.

## Decisions

1. **Clean source directories first** (`.opencode/` core dirs), then clean targets, then simplify code. This order ensures the most impactful change (preventing future contamination) happens first.

2. **Remove the exclusion filter code from sync.lua** after source directories are clean. The filter is defensive code that compensates for dirty sources. With clean sources, it becomes unnecessary complexity.

3. **Use extension manifests as the authoritative list** of what to remove. The manifest.json `provides` field is the single source of truth for what belongs to each extension.

4. **Do NOT change the extension loader** (loader.lua, init.lua). It already works correctly with the "load from extension directory" pattern.

5. **Preserve `CONTEXT_EXCLUDE_PATTERNS`** in sync.lua. This serves a different purpose (repository-specific exclusions) and should not be removed.

6. **Apply changes uniformly to both `.claude` and `.opencode`** even though `.claude/` source is already clean. This ensures the code simplification applies to both systems.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Removing extension artifacts from `.opencode/` source breaks syncs to projects that rely on them | Medium | The exclusion filter already prevents extension artifacts from being synced; removing them from source is the natural completion of that intent |
| Removing the exclusion filter code makes the system vulnerable if someone later adds extension artifacts to core dirs | Low | Add a validation script or pre-commit check that enforces the disjointness invariant |
| Active sessions affected by target directory cleanup | Medium | Document to close AI sessions before cleanup; or clean only source dirs first and let subsequent syncs naturally "clean" targets |
| `.opencode/` context directory may also contain extension context | Low | Verify and clean as part of the same operation |

## Implementation Recommendations

### Implementation Order

1. **Remove extension artifacts from `.opencode/` source directories** (scripted, manifest-driven)
2. **Remove extension artifacts from target directories** (`~/.config/.claude/` and any other synced projects)
3. **Remove exclusion filter functions from sync.lua** (4 functions, ~130 lines)
4. **Update `scan_all_artifacts()` to remove filter calls** (~20 lines of call sites)
5. **Add disjointness validation** (optional but recommended: a script that checks no artifact in core dirs appears in any extension manifest)
6. **Test**: run "Load Core Agent System" and verify only core artifacts are synced

### Estimated Effort

- Phase 1 (Clean source): 30 minutes (scripted removal)
- Phase 2 (Clean targets): 15 minutes (same script, different target)
- Phase 3 (Simplify sync.lua): 45 minutes (remove filter code, update call sites)
- Phase 4 (Validation): 30 minutes (create validation script)
- Phase 5 (Testing): 30 minutes (manual verification)

Total: 2.5-3 hours

### Files to Modify

1. **Remove files from**: `~/.config/nvim/.opencode/agent/subagents/`, `.opencode/skills/`, `.opencode/commands/`, `.opencode/rules/` (25 artifacts)
2. **Remove files from**: `~/.config/.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.claude/rules/` (8 artifacts)
3. **Modify**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (remove ~130 lines of filter code, update ~20 lines of call sites)
4. **Optional new file**: validation script to enforce disjointness invariant

## Context Extension Recommendations

None -- this is a meta task.

## Appendix

### Source Directory State Summary

#### .claude/ Source (ALREADY CLEAN)

```
.claude/
  agents/        6 files (all core)
  skills/       11 dirs  (all core)
  commands/     11 files (all core)
  rules/         6 files (all core)
  extensions/
    document-converter/  (own agents, skills, commands)
    formal/              (own agents, skills, context)
    latex/               (own agents, skills, rules, context)
    lean/                (own agents, skills, commands, rules, context, scripts)
    nix/                 (own agents, skills, rules, context)
    python/              (own agents, skills, context)
    typst/               (own agents, skills, context)
    web/                 (own agents, skills, rules, context)
    z3/                  (own agents, skills, context)
```

#### .opencode/ Source (NEEDS CLEANUP)

```
.opencode/
  agent/subagents/  15 files (6 core + 9 extension = MIXED)
  skills/           22 dirs  (11 core + 11 extension = MIXED)
  commands/         14 files (11 core + 3 extension = MIXED)
  rules/             7 files (5 core + 2 extension = MIXED)
  extensions/
    (same structure as .claude/extensions/)
```

### Web Research References

- [Plugin Architecture Design Pattern](https://dev.to/devleader/plugin-architecture-design-pattern-a-beginners-guide-to-modularity-4bo8) - Modularity principles
- [Managing dotfiles with Nix](https://seroperson.me/2024/01/16/managing-dotfiles-with-nix/) - Configuration management with clean separation
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Selective loading and dependency resolution in Neovim
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - XDG-compliant configuration management
- [Patterns of Modular Architecture](https://dzone.com/refcardz/patterns-modular-architecture) - Dependency management patterns

### Key Files Examined

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Core sync operation (648 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning utilities (206 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua` - Extension file copy engine (342 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua` - Extension manager API (452 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/config.lua` - Extension configuration (71 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Manifest validation (228 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/state.lua` - Extension state tracking (225 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Picker orchestration (283 lines)
- All 9 extension manifest.json files in both `.claude/extensions/` and `.opencode/extensions/`
