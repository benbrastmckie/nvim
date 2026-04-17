# Implementation Plan: Document Extension Dependency System

- **Task**: 459 - document_extension_dependency_system
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task 457 (implementation complete)
- **Research Inputs**: reports/01_extension-deps-docs.md
- **Artifacts**: plans/01_extension-deps-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Update six documentation files to reflect the extension dependency system implemented in task 457. Each file edit is specified with exact old/new text or insertion points. The extension development guide was already updated in task 457 and needs no changes.

### Research Integration

Research report (`reports/01_extension-deps-docs.md`) identified six files needing updates with specific line numbers and suggested changes. Integrated in plan version 1; this revision (v2) adds concrete edit instructions derived from reading each file's actual content.

### Prior Plan Reference

Plan version 1 (same path). This revision adds exact edit text for every change.

### Roadmap Alignment

Advances "Agent System Quality" by reducing documentation drift. Supports "Extension slim standard enforcement" by ensuring dependency features are documented in the creating-extensions guide.

## Goals & Non-Goals

**Goals**:
- Add dependency support mention to CLAUDE.md extension section
- Update extension-system.md load/unload process with dependency steps
- Add resource-only extension pattern to creating-extensions.md
- Qualify "self-contained" language in adding-domains.md
- Add slidev to extensions/README.md table and mention dependencies
- Mention slidev and dependencies in project-overview.md

**Non-Goals**:
- Modifying extension-development.md (already complete from task 457)
- Changing any implementation code
- Adding new features to the dependency system

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Over-documenting in CLAUDE.md wastes context budget | M | M | Keep to 2-3 lines, point to extension-development.md |
| Inconsistent "self-contained" phrasing across docs | L | M | Use consistent wording: "self-contained packages that can optionally declare dependencies" |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Update High-Visibility Docs [COMPLETED]

**Goal**: Update the three most-read documentation files: CLAUDE.md, extensions/README.md, and project-overview.md.

**Tasks**:

- [ ] **`.claude/CLAUDE.md`** -- Insert after line "When an extension is loaded, its routing entries are merged into the command tables and context index."

  Add the following paragraph:

  ```
  Extensions can declare dependencies on other extensions via the `dependencies` array in manifest.json. Dependencies are auto-loaded silently when the parent extension is loaded, with circular detection and a depth limit of 5. See `.claude/context/guides/extension-development.md` for details.
  ```

- [ ] **`.claude/extensions/README.md`** -- Two changes:

  **(a)** Add slidev row to the Available Extensions table, after the `memory` row:

  ```
  | slidev | - | Shared Slidev animation patterns and CSS style presets |
  ```

  **(b)** Add a new paragraph at the end of the "Loading Extensions" section (after step 7 "Post-load verification runs to check integrity"), before "## Extension Structure":

  ```
  Extensions can declare dependencies on other extensions via the `dependencies` array in manifest.json. When an extension with dependencies is loaded, unloaded dependencies are auto-loaded silently before proceeding. The picker preview shows each extension's dependencies and which loaded extensions depend on it.
  ```

- [ ] **`.claude/context/repo/project-overview.md`** -- Two changes:

  **(a)** In the "Extension-Provided Context" section, after the bullet list ending with "Tool-specific guides", add:

  ```
  Extensions can declare dependencies on other extensions (e.g., founder and present both depend on slidev for shared Slidev animation patterns). Resource-only extensions like slidev/ provide only context files with no agents, skills, or routing.
  ```

  **(b)** Update the "See" line to:

  ```
  See `.claude/extensions/*/manifest.json` for available extensions, their capabilities, and dependency declarations.
  ```

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/CLAUDE.md` - Add dependency support paragraph after extension routing line
- `.claude/extensions/README.md` - Add slidev table row + dependency paragraph in Loading section
- `.claude/context/repo/project-overview.md` - Add dependency and resource-only extension note

**Verification**:
- All three files mention dependency support
- slidev appears in the extensions README table
- CLAUDE.md note is concise (3 lines)
- project-overview.md mentions resource-only pattern with slidev example

---

### Phase 2: Update Architecture and Guide Docs [COMPLETED]

**Goal**: Update the three architecture/guide documents to reflect dependency resolution in load/unload processes and add resource-only extension pattern.

**Tasks**:

- [ ] **`.claude/docs/architecture/extension-system.md`** -- Three changes:

  **(a)** Line 5 overview sentence. Replace:
  ```
  Extensions are self-contained packages containing agents, skills, rules, commands, and context files that integrate with the core .claude/ system when loaded.
  ```
  With:
  ```
  Extensions are self-contained packages containing agents, skills, rules, commands, and context files that integrate with the core .claude/ system when loaded. Extensions can optionally declare dependencies on other extensions for shared resources.
  ```

  **(b)** Load process: Insert a new step between step 1 ("Read manifest.json") and step 2 ("Check for conflicts") in the loading process (lines 234-235). The existing steps 2-9 shift down by one:
  ```
  2. Resolve dependencies:
     a. Check manifest dependencies array
     b. Auto-load any unloaded dependencies recursively (confirm=false)
     c. Circular detection via loading stack; depth limit of 5
     d. Re-read state from disk after dependency loads complete
  ```

  **(c)** Unload process: Insert a new step between step 1 ("Read state") and step 2 ("Remove merged content") in the unloading process (lines 266-267):
  ```
  2. Check reverse dependencies:
     a. Scan loaded extensions for ones declaring this extension in dependencies
     b. If dependents exist, show warning: "Extension 'X' is required by: Y, Z"
     c. Proceed with unload if user confirms (dependents are NOT cascade-unloaded)
  ```

- [ ] **`.claude/docs/guides/creating-extensions.md`** -- Three changes:

  **(a)** Line 11 overview sentence. Replace:
  ```
  Extensions are self-contained packages that add domain-specific support (agents, skills, rules, context) to the .claude/ system. Extensions can be loaded/unloaded via the extension picker without modifying core files.
  ```
  With:
  ```
  Extensions are self-contained packages that add domain-specific support (agents, skills, rules, context) to the .claude/ system. Extensions can be loaded/unloaded via the extension picker without modifying core files. Extensions can optionally declare dependencies on other extensions for shared resources.
  ```

  **(b)** In the Field Reference table (line 107), expand the `dependencies` row. Replace:
  ```
  | `dependencies` | No | Extensions that must load first |
  ```
  With:
  ```
  | `dependencies` | No | Extensions that must load first (auto-loaded silently) |
  ```

  **(c)** Add a new section "Resource-Only Extensions" before the "## Creating Agents" section (before line 207). Insert:

  ```markdown
  ## Resource-Only Extensions

  Extensions that provide only shared context (no agents, skills, commands, or routing) are called resource-only extensions. They exist to share resources between other extensions.

  **Example**: The `slidev` extension provides Slidev animation patterns and CSS style presets consumed by `founder` and `present`:

  ```json
  {
    "name": "slidev",
    "version": "1.0.0",
    "description": "Shared Slidev animation patterns and CSS style presets",
    "dependencies": [],
    "provides": {
      "agents": [], "skills": [], "commands": [],
      "rules": [], "context": ["project/slidev"],
      "scripts": [], "hooks": []
    },
    "merge_targets": {
      "index": { "source": "index-entries.json", "target": ".claude/context/index.json" }
    }
  }
  ```

  Consuming extensions declare the dependency: `"dependencies": ["slidev"]`. When founder or present is loaded, slidev is auto-loaded first if not already present.

  **Key characteristics**:
  - No `task_type` field (no routing)
  - No `EXTENSION.md` or `claudemd` merge target (nothing injected into CLAUDE.md)
  - Only `provides.context` populated
  - Loaded automatically as a dependency, not typically selected directly

  ---
  ```

- [ ] **`.claude/docs/guides/adding-domains.md`** -- Two changes:

  **(a)** In the "Why Extensions?" bullet list (lines 29-32). Replace:
  ```
  - Extensions are self-contained packages that can be loaded/unloaded
  - Extensions are portable across projects without modification
  - Extensions keep the core system clean and focused
  - Extensions can be versioned and shared independently
  ```
  With:
  ```
  - Extensions are self-contained packages that can be loaded/unloaded
  - Extensions can declare dependencies on other extensions for shared resources
  - Extensions are portable across projects without modification
  - Extensions keep the core system clean and focused
  - Extensions can be versioned and shared independently
  ```

  **(b)** In the comparison table (line 15). Replace:
  ```
  | **Extension** (Recommended) | Adding any new domain | High - portable across projects | Moderate - self-contained package |
  ```
  With:
  ```
  | **Extension** (Recommended) | Adding any new domain | High - portable across projects | Moderate - self-contained package with optional dependencies |
  ```

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/extension-system.md` - Qualify overview, add load/unload dependency steps
- `.claude/docs/guides/creating-extensions.md` - Qualify overview, expand dependencies field, add resource-only section
- `.claude/docs/guides/adding-domains.md` - Add dependency bullet, qualify comparison table

**Verification**:
- extension-system.md load process includes dependency resolution step with circular detection
- extension-system.md unload process includes reverse dependency check with warning
- creating-extensions.md has resource-only extension section with slidev manifest example
- adding-domains.md mentions dependency support in "Why Extensions?" list
- No docs describe extensions as purely "self-contained" without qualification

## Testing & Validation

- [ ] All six files updated with consistent dependency language
- [ ] No file describes extensions as only "self-contained" without dependency qualification
- [ ] slidev appears in extensions README table
- [ ] CLAUDE.md extension section mentions dependency support concisely
- [ ] extension-system.md load/unload processes include dependency steps
- [ ] creating-extensions.md includes resource-only extension pattern with slidev example
- [ ] adding-domains.md mentions dependency support

## Artifacts & Outputs

- plans/01_extension-deps-docs.md (this plan)
- summaries/01_extension-deps-docs-summary.md (post-implementation)
- Six updated documentation files (listed in phases above)

## Rollback/Contingency

All changes are documentation-only edits to existing files. Revert with `git checkout` on the six modified files if any changes introduce inaccuracies.
