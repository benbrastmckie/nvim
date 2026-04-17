# Research Report: Document Extension Dependency System

- **Task**: 459 - document_extension_dependency_system
- **Started**: 2026-04-16T12:00:00Z
- **Completed**: 2026-04-16T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 457 (implementation)
- **Sources/Inputs**:
  - Codebase: `lua/neotex/plugins/ai/shared/extensions/init.lua` (manager implementation)
  - Codebase: `.claude/extensions/slidev/` (manifest, README, EXTENSION.md)
  - Codebase: `.claude/extensions/present/manifest.json`, `.claude/extensions/founder/manifest.json`
  - Codebase: `.claude/extensions/picker.lua` (dependency preview)
  - Docs: `.claude/context/guides/extension-development.md`
  - Docs: `.claude/docs/architecture/extension-system.md`
  - Docs: `.claude/docs/guides/creating-extensions.md`
  - Docs: `.claude/docs/guides/adding-domains.md`
  - Docs: `.claude/extensions/README.md`
  - Docs: `.claude/CLAUDE.md` (extension sections)
  - Docs: `.claude/context/repo/project-overview.md`
- **Artifacts**: `specs/459_document_extension_dependency_system/reports/01_extension-deps-docs.md`
- **Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- Task 457 implemented extension dependency auto-loading in `manager.load()` with circular detection, depth limits, state re-read fix, and unload safety warnings
- The extension development guide (`context/guides/extension-development.md`) was **already updated** as part of task 457 with full dependency documentation (Dependencies section at lines 164-240)
- Six documentation locations still need updates to mention dependency support: CLAUDE.md, extension-system.md, creating-extensions.md, adding-domains.md, extensions/README.md, and project-overview.md
- The slidev/ extension exists as a resource-only micro-extension (no agents, commands, routing) providing shared Slidev animation patterns and CSS presets for founder and present extensions

## Context & Scope

Task 457 implemented the extension dependency system. Task 459 is a documentation-only meta task to update all documentation locations that reference extensions. The implementation is complete and working; this task only needs to add/update documentation.

## Findings

### Implementation Details (from manager.load() in init.lua)

The dependency system in `manager.load()` (lines 248-298) implements:
- **Dependency declaration**: `dependencies` array in manifest.json lists extension names
- **Auto-loading**: Unloaded dependencies are recursively loaded via `manager.load()` with `confirm = false` (silent)
- **Circular detection**: A `_loading_stack` parameter tracks the recursion chain; if an extension appears twice, load fails with cycle message (e.g., "Circular dependency detected: A -> B -> C -> A")
- **Depth limit**: `max_depth = 5` prevents runaway chains even without explicit cycles
- **State re-read fix** (line 463): After dependency loads complete, state is re-read from disk (`state = state_mod.read(...)`) to avoid overwriting dependency entries written by recursive calls
- **Confirmation dialog** (lines 332-338): Shows dependency info -- either "Dependencies loaded: X" or "Dependencies (already loaded): X"

The unload safety system in `manager.unload()` (lines 512-525) implements:
- **Reverse dependency check**: Scans all loaded extensions for ones that depend on the target
- **Warning message**: Shows "WARNING: Extension 'X' is required by: Y, Z" in confirmation dialog
- **Non-cascading**: Only the named extension is removed; dependents are left loaded (may break)

The picker preview (`picker.lua` lines 60-82) shows:
- **Dependencies**: Lists declared dependencies
- **Required by**: Reverse lookup of which loaded extensions depend on the selected one

### Already-Updated Documentation

The extension development guide (`.claude/context/guides/extension-development.md`) was **fully updated** in task 457 with a complete "Dependencies" section (lines 164-240) covering:
- Declaring dependencies (manifest format)
- Auto-loading behavior (5-step process)
- Circular dependency detection (error message example)
- Unload safety (warning message example)
- Resource-only extensions (slidev example with full manifest)
- Picker preview (dependency/required-by display)

### Documentation Locations Needing Updates

#### 1. `.claude/CLAUDE.md` -- Extension Section (lines 73-77)

**Current text** (line 75):
> Extensions provide additional task type support (neovim, lean4, latex, typst, python, nix, web, z3, epi, formal, founder, present, etc.). See `.claude/extensions/*/manifest.json` for available extensions and their capabilities.

**Needed**: Add a note about dependency support. Suggested addition after line 77:
> Extensions can declare dependencies on other extensions via the `dependencies` array in manifest.json. Dependencies are auto-loaded when the parent extension is loaded. See `.claude/context/guides/extension-development.md` for details.

#### 2. `.claude/docs/architecture/extension-system.md` -- Multiple Sections

**a. System Overview (line 5)**:
Current: "Extensions are self-contained packages containing agents, skills, rules, commands, and context files"
**Update**: Qualify "self-contained" -- extensions can depend on other extensions for shared resources.

**b. Manifest Fields table (lines 148-156)**:
The `dependencies` field is already listed in the table at line 154: `dependencies | array | Other extensions that must be loaded first`. This is correct and complete.

**c. Load/Unload Process (lines 229-275)**:
The load process (lines 232-262) does NOT mention dependency resolution. The step-by-step load process needs a new step between "Read manifest.json" and "Check for conflicts":
> 1.5. Resolve dependencies: auto-load unloaded dependencies recursively (with circular detection and depth limit)

The unload process (lines 267-275) does NOT mention dependency safety check. Needs a new step:
> 1.5. Check if loaded extensions depend on this one; warn user if so

#### 3. `.claude/docs/guides/creating-extensions.md` -- Multiple Sections

**a. Overview (line 11)**:
Current: "Extensions are self-contained packages that add domain-specific support"
**Update**: Same qualification as extension-system.md.

**b. Field Reference table (line 107)**:
Current: `dependencies | No | Extensions that must load first`
**Update**: This is already correct but could be expanded to note auto-loading behavior.

**c. Missing section**: No section about creating resource-only extensions. Should add a brief note about the resource-only pattern (no task_type, no routing, no agents) with slidev as example.

#### 4. `.claude/docs/guides/adding-domains.md` (lines 15, 29, 32)

**Line 15**: "self-contained package" in comparison table
**Line 29**: "Extensions are self-contained packages that can be loaded/unloaded"
**Line 32**: "Extensions can be versioned and shared independently"
**Update**: Qualify "self-contained" and "independently" -- extensions can depend on other extensions. Add note about shared resource pattern.

#### 5. `.claude/extensions/README.md` -- Available Extensions Table (lines 21-36)

**Current table** does not list `slidev` extension. The table lists all 14 extensions but is missing slidev.
**Update**: Add slidev to the table:
> | slidev | - | Shared Slidev animation patterns and CSS style presets |

Also needs a brief mention of the dependency system in the "Loading Extensions" section or a new subsection.

#### 6. `.claude/context/repo/project-overview.md` (lines 26-30)

**Current**: Brief mention of extensions directory structure but no mention of dependency relationships or shared resource extensions.
**Update**: Add a note about slidev/ as a shared resource extension, and briefly mention that extensions can declare dependencies.

### The slidev/ Micro-Extension

The slidev extension (`manifest.json`) provides:
- **No** task_type, agents, skills, commands, rules, scripts, or hooks
- **Only** context: `["project/slidev"]` (6 animation patterns, 9 CSS style presets)
- **Consumed by**: founder (pitch decks) and present (academic talks) via `"dependencies": ["slidev"]`
- Pattern: "resource-only micro-extension" -- exists solely to share resources between extensions

## Decisions

- The extension development guide does NOT need updating (already done in task 457)
- Six other documentation files need updates with varying scope
- The "self-contained" language in multiple docs should be qualified, not removed -- extensions are still self-contained in terms of packaging, but can declare dependencies
- The slidev extension should be added to the extensions README table

## Recommendations

### Priority Order for Implementation

1. **`.claude/CLAUDE.md`** -- Highest impact, most-read file. Add dependency support note to extension section.
2. **`.claude/extensions/README.md`** -- Add slidev to table, add dependency mention to loading section.
3. **`.claude/docs/architecture/extension-system.md`** -- Update load/unload process steps, qualify "self-contained".
4. **`.claude/docs/guides/creating-extensions.md`** -- Add resource-only pattern section, qualify "self-contained".
5. **`.claude/docs/guides/adding-domains.md`** -- Qualify "self-contained" and "independently" language.
6. **`.claude/context/repo/project-overview.md`** -- Add note about slidev/ and dependencies.

### Specific Changes Per File

| File | Change Type | Estimated Lines |
|------|------------|----------------|
| `.claude/CLAUDE.md` | Add 2-3 lines after line 77 | Small |
| `.claude/extensions/README.md` | Add table row + 3-4 lines | Small |
| `.claude/docs/architecture/extension-system.md` | Update overview + add load/unload steps | Medium |
| `.claude/docs/guides/creating-extensions.md` | Add resource-only section (~15 lines) | Medium |
| `.claude/docs/guides/adding-domains.md` | Qualify 3 phrases | Small |
| `.claude/context/repo/project-overview.md` | Add 2-3 lines | Small |

## Risks & Mitigations

- **Risk**: Over-documenting dependency features in CLAUDE.md wastes context budget
  - **Mitigation**: Keep CLAUDE.md note to 2-3 lines, point to extension-development.md for details
- **Risk**: Inconsistent language across docs about "self-contained"
  - **Mitigation**: Use consistent phrasing: "self-contained packages that can optionally declare dependencies on other extensions"

## Appendix

### Files Already Documenting Dependencies (No Changes Needed)
- `.claude/context/guides/extension-development.md` -- Full dependency section (lines 164-240)
- `.claude/extensions/slidev/README.md` -- Complete resource-only extension docs
- `.claude/extensions/slidev/EXTENSION.md` -- Brief description with usage
- `.claude/extensions/slidev/manifest.json` -- Correct resource-only manifest
- `.claude/extensions/present/manifest.json` -- Correctly declares `["slidev"]` dependency
- `.claude/extensions/founder/manifest.json` -- Correctly declares `["slidev"]` dependency

### Key Source Code References
- `lua/neotex/plugins/ai/shared/extensions/init.lua` lines 248-298: Dependency resolution in load
- `lua/neotex/plugins/ai/shared/extensions/init.lua` lines 512-525: Unload dependency check
- `lua/neotex/plugins/ai/shared/extensions/init.lua` line 463: State re-read fix
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` lines 60-82: Picker dependency preview
