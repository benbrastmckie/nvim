# Implementation Plan: Task #110

- **Task**: 110 - separate_extension_files_from_core_agent_system
- **Status**: [COMPLETED]
- **Effort**: 2-4 hours
- **Dependencies**: Task #109 (completed)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Date**: 2026-03-02

## Overview

Restructure the core `.claude/` directory to remove 25 extension-specific files (LaTeX, Typst, document-converter) that duplicate content already provided by the extension system. This creates a clean, portable core that new projects receive via `<leader>ac` sync, while domain-specific capabilities remain installable through the extension picker. The document-converter agent, skill, and command will be moved to a new `extensions/document-converter/` extension. All 10 core reference files that mention the removed agents/skills will be updated to remove extension-specific entries.

### Research Integration

Research report `research-001.md` identified the complete inventory of 25 extension-specific files in core, confirmed that extension versions are equivalent or richer (making removal safe), mapped all 10+ reference files requiring updates, and validated that the sync mechanism naturally handles fewer files without code changes.

## Goals & Non-Goals

**Goals**:
- Remove all 21 LaTeX and Typst files from core `.claude/` that are duplicated in extensions
- Create a new `extensions/document-converter/` extension containing the agent, skill, and command
- Remove the 4 document-converter files from core after migration to extension
- Update all core reference files (CLAUDE.md, routing.md, index.json, etc.) to remove extension-specific entries
- Ensure the extension loader can install LaTeX, Typst, and document-converter cleanly without conflicts

**Non-Goals**:
- Moving neovim-specific agents/skills/context to an extension (future task)
- Modifying the sync.lua mechanism itself (fewer files in core is sufficient)
- Adding permission fragment merging to the extension loader
- Modifying settings.json LaTeX permissions (harmless allow-list entries)
- Updating existing projects that already received extension files via sync

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking loaded extensions in this repo | High | Medium | Immediately reload LaTeX/Typst extensions via picker after removal to reinstall from extension source |
| Missing reference updates (stale mentions of removed agents) | Medium | Medium | Use grep to find ALL references to removed agents/skills before and after changes |
| Index.json entries pointing to deleted files | Medium | High | Remove all 16 LaTeX/Typst context entries from index.json |
| /convert command unavailable after removal | Low | High | Move command to document-converter extension; users can load extension if needed |
| Extension loader conflicts if files still exist | Low | Low | Delete core files before testing extension loading |

## Implementation Phases

### Phase 1: Create Document-Converter Extension [COMPLETED]

- **Goal:** Establish a new `extensions/document-converter/` extension with manifest, EXTENSION.md, and copies of the core document-converter files, following the same structure as existing extensions (latex, typst).

- **Tasks:**
  - [ ] Read existing extension structure (latex/manifest.json, latex/EXTENSION.md) as template
  - [ ] Create `extensions/document-converter/manifest.json` with provides for agent, skill, and command
  - [ ] Create `extensions/document-converter/EXTENSION.md` with CLAUDE.md merge content for the skill-to-agent mapping entry and skills architecture entry
  - [ ] Copy `.claude/agents/document-converter-agent.md` to `extensions/document-converter/agents/document-converter-agent.md`
  - [ ] Copy `.claude/skills/skill-document-converter/SKILL.md` to `extensions/document-converter/skills/skill-document-converter/SKILL.md`
  - [ ] Copy `.claude/commands/convert.md` to `extensions/document-converter/commands/convert.md`
  - [ ] Create `extensions/document-converter/index-entries.json` if the document-converter has any context index entries (likely empty array since it has no context files)

- **Timing:** 30-45 minutes

- **Files to create:**
  - `.claude/extensions/document-converter/manifest.json` - Extension manifest
  - `.claude/extensions/document-converter/EXTENSION.md` - CLAUDE.md merge content
  - `.claude/extensions/document-converter/agents/document-converter-agent.md` - Agent definition (copy)
  - `.claude/extensions/document-converter/skills/skill-document-converter/SKILL.md` - Skill definition (copy)
  - `.claude/extensions/document-converter/commands/convert.md` - Command definition (copy)
  - `.claude/extensions/document-converter/index-entries.json` - Index entries (empty or minimal)

- **Verification:**
  - manifest.json is valid JSON matching the schema of existing extensions
  - All files from core are copied to extension directory
  - EXTENSION.md contains the document-converter skill-to-agent mapping row

---

### Phase 2: Remove Extension-Specific Files from Core [COMPLETED]

- **Goal:** Delete all 25 extension-specific files from the core `.claude/` directory. These files are duplicated in their respective extensions and their presence in core pollutes new project syncs.

- **Tasks:**
  - [ ] Delete `.claude/agents/latex-implementation-agent.md`
  - [ ] Delete `.claude/agents/typst-implementation-agent.md`
  - [ ] Delete `.claude/agents/document-converter-agent.md`
  - [ ] Delete `.claude/skills/skill-latex-implementation/` directory (SKILL.md)
  - [ ] Delete `.claude/skills/skill-typst-implementation/` directory (SKILL.md)
  - [ ] Delete `.claude/skills/skill-document-converter/` directory (SKILL.md)
  - [ ] Delete `.claude/rules/latex.md`
  - [ ] Delete `.claude/context/project/latex/` directory tree (8 files: README.md, 3 standards, 2 patterns, 1 tools, 1 templates)
  - [ ] Delete `.claude/context/project/typst/` directory tree (8 files: README.md, 3 standards, 2 patterns, 1 tools, 1 templates)
  - [ ] Delete `.claude/commands/convert.md`

- **Timing:** 15-20 minutes

- **Files to delete:**
  - `.claude/agents/latex-implementation-agent.md`
  - `.claude/agents/typst-implementation-agent.md`
  - `.claude/agents/document-converter-agent.md`
  - `.claude/skills/skill-latex-implementation/` (directory)
  - `.claude/skills/skill-typst-implementation/` (directory)
  - `.claude/skills/skill-document-converter/` (directory)
  - `.claude/rules/latex.md`
  - `.claude/commands/convert.md`
  - `.claude/context/project/latex/` (entire directory tree)
  - `.claude/context/project/typst/` (entire directory tree)

- **Verification:**
  - None of the deleted files exist in `.claude/`
  - Remaining agents: neovim-research-agent, neovim-implementation-agent, general-research-agent, general-implementation-agent, planner-agent, meta-builder-agent
  - Remaining skills: skill-neovim-research, skill-neovim-implementation, skill-researcher, skill-planner, skill-implementer, skill-meta, skill-orchestrator, skill-status-sync, skill-refresh
  - Extension directories (`.claude/extensions/latex/`, `.claude/extensions/typst/`, `.claude/extensions/document-converter/`) still intact

---

### Phase 3: Update Core Reference Files [COMPLETED]

- **Goal:** Remove all references to LaTeX, Typst, and document-converter agents/skills from core configuration files so that the core system is self-consistent and does not reference non-existent files.

- **Tasks:**
  - [ ] Update `.claude/CLAUDE.md`:
    - Remove latex-implementation, typst-implementation, document-converter rows from Skill-to-Agent Mapping table
    - Remove latex/typst rows from Language-Based Routing table (or annotate as extension-provided)
    - Remove latex/typst context paths from Context Imports section
    - Remove document-converter from Skills Architecture section if present
  - [ ] Update `.claude/context/core/routing.md`:
    - Remove or annotate latex and typst routing rows as extension-provided
  - [ ] Update `.claude/context/index.json`:
    - Remove all entries with paths under `project/latex/` and `project/typst/`
  - [ ] Update `.claude/skills/skill-orchestrator/SKILL.md`:
    - Remove latex/typst/document-converter routing rows
  - [ ] Update `.claude/commands/implement.md`:
    - Remove latex/typst from language routing table
  - [ ] Update `.claude/docs/architecture/system-overview.md`:
    - Remove latex-implementation-agent, typst-implementation-agent, document-converter entries
  - [ ] Update `.claude/docs/guides/creating-agents.md`:
    - Replace latex-implementation-agent example with a generic agent name (e.g., general-implementation-agent)
  - [ ] Update `.claude/docs/guides/component-selection.md`:
    - Remove extension-specific component entries
  - [ ] Update `.claude/context/project/processes/implementation-workflow.md`:
    - Remove latex/typst agent routing rows
  - [ ] Update `.claude/context/core/orchestration/routing.md`:
    - Remove latex/typst validation references

- **Timing:** 45-60 minutes

- **Files to modify:**
  - `.claude/CLAUDE.md` - Skill mapping, routing, imports
  - `.claude/context/core/routing.md` - Language routing
  - `.claude/context/index.json` - Context index entries
  - `.claude/skills/skill-orchestrator/SKILL.md` - Orchestrator routing
  - `.claude/commands/implement.md` - Implementation routing
  - `.claude/docs/architecture/system-overview.md` - Architecture docs
  - `.claude/docs/guides/creating-agents.md` - Agent creation guide
  - `.claude/docs/guides/component-selection.md` - Component selection guide
  - `.claude/context/project/processes/implementation-workflow.md` - Workflow process
  - `.claude/context/core/orchestration/routing.md` - Orchestration routing

- **Verification:**
  - grep for "latex-implementation" in `.claude/` returns no results (excluding extensions/)
  - grep for "typst-implementation" in `.claude/` returns no results (excluding extensions/)
  - grep for "document-converter" in `.claude/` returns no results (excluding extensions/ and skills architecture noting it as an extension)
  - index.json is valid JSON with no entries pointing to deleted paths

---

### Phase 4: Verification and Consistency Check [COMPLETED]

- **Goal:** Validate that the core system is self-consistent after all removals and updates, and that extensions can load cleanly without conflicts.

- **Tasks:**
  - [ ] Run comprehensive grep for all removed agent/skill names across `.claude/` (excluding extensions/) to catch any missed references
  - [ ] Validate index.json is valid JSON and contains no entries referencing deleted paths
  - [ ] Verify all remaining agent files in `.claude/agents/` are referenced in CLAUDE.md Skill-to-Agent Mapping table
  - [ ] Verify all remaining skill directories in `.claude/skills/` are referenced in CLAUDE.md Skill-to-Agent Mapping table
  - [ ] Verify the routing tables in core only reference agents/skills that exist in core
  - [ ] Check that the document-converter extension manifest.json references the correct file paths
  - [ ] Run `.claude/scripts/validate-all-standards.sh --links` to check for broken internal links (if available)

- **Timing:** 20-30 minutes

- **Verification:**
  - Zero grep hits for removed agents/skills in core (excluding extensions/)
  - index.json parses without error
  - All skill-to-agent mapping entries correspond to existing files
  - No broken internal links in documentation

## Testing & Validation

- [ ] grep for "latex-implementation-agent" in `.claude/` (excluding extensions/) returns empty
- [ ] grep for "typst-implementation-agent" in `.claude/` (excluding extensions/) returns empty
- [ ] grep for "document-converter-agent" in `.claude/` (excluding extensions/) returns empty (or only in skills architecture noting extensions)
- [ ] grep for "skill-latex-implementation" in `.claude/` (excluding extensions/) returns empty
- [ ] grep for "skill-typst-implementation" in `.claude/` (excluding extensions/) returns empty
- [ ] grep for "skill-document-converter" in `.claude/` (excluding extensions/) returns empty (or only in skills architecture)
- [ ] `jq . .claude/context/index.json` succeeds (valid JSON)
- [ ] No index.json entries with paths containing `project/latex/` or `project/typst/`
- [ ] `.claude/extensions/document-converter/manifest.json` is valid JSON
- [ ] All files listed in document-converter manifest exist in the extension directory
- [ ] Remaining `.claude/agents/*.md` files match CLAUDE.md Skill-to-Agent table entries

## Artifacts & Outputs

- `specs/110_separate_extension_files_from_core_agent_system/plans/implementation-001.md` (this file)
- `specs/110_separate_extension_files_from_core_agent_system/summaries/implementation-summary-20260302.md` (post-implementation)
- `.claude/extensions/document-converter/` (new extension directory)

## Rollback/Contingency

All removed files exist in git history and can be restored with:
```bash
git checkout HEAD~1 -- .claude/agents/latex-implementation-agent.md .claude/agents/typst-implementation-agent.md .claude/agents/document-converter-agent.md .claude/skills/skill-latex-implementation/ .claude/skills/skill-typst-implementation/ .claude/skills/skill-document-converter/ .claude/rules/latex.md .claude/commands/convert.md .claude/context/project/latex/ .claude/context/project/typst/
```

For reference file updates, `git diff` against the pre-implementation commit shows all changes and each file can be individually reverted. The extension directory can simply be deleted if the extension approach is abandoned.
