# Implementation Plan: Verify and Fix Agent Systems Wiring After Reload

- **Task**: 169 - verify_agent_systems_wired_after_reload
- **Status**: [NOT STARTED]
- **Effort**: 6-10 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Research identified three critical issues with the agent systems wiring: (1) extension content is committed into the core systems instead of being loaded dynamically, (2) index.json has inconsistent path prefixes and missing extension entries for neovim/filetypes, and (3) CLAUDE.md contains hardcoded references to all extensions rather than only core elements. This plan addresses all three by establishing a clean core/extension boundary, fixing index.json as the adaptive registry, trimming CLAUDE.md to core-only content, and adding post-load verification to the extension loader.

### Research Integration

- research-001.md: Identified 76 missing context files, neovim/filetypes entries not merged into index.json, .opencode index only 32 entries vs 97 in .claude
- research-002.md: Identified that ALL extension files already exist in core (making loader file copies a no-op), recommended true core/extension separation, documented loader architecture strengths and gaps

## Goals & Non-Goals

**Goals**:
- Establish a clean core system that works independently without any extensions
- Make index.json the single adaptive registry that extensions populate at load time
- Ensure CLAUDE.md contains only core references, with extensions injecting their sections
- Fix path normalization at the source (extension index-entries.json files)
- Add post-load verification to the extension loader
- Make both .claude/ and .opencode/ systems consistent

**Non-Goals**:
- Adding batch load/unload capability for extensions (UX improvement, separate task)
- Making .opencode match .claude command-for-command (the /fix and /todo skill differences are intentional)
- Rewriting the extension loader architecture (it is well-designed, just needs fixes)
- Creating missing context files for all 76 references (only fix path prefixes; content creation is separate)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing extension files from core breaks users who have not loaded extensions | High | Medium | Test full round-trip: clean core -> load extensions -> verify wiring |
| Path normalization changes break existing index.json queries in agents | Medium | Low | All agents use the same jq query pattern; normalize consistently |
| CLAUDE.md trimming removes content that core commands reference | Medium | Medium | Audit all core command files for references before removing CLAUDE.md sections |
| Parallel .opencode/ changes drift from .claude/ changes | Medium | Medium | Apply changes to both systems in same phase; verify symmetry |
| Extension loader merge logic breaks with new core index.json format | Medium | Low | The merge module already handles append/dedup; smaller core index is simpler |

## Implementation Phases

### Phase 1: Audit and Document Core Inventory [COMPLETED]

- **Goal:** Produce a definitive list of core-only elements (agents, skills, rules, context, index entries, CLAUDE.md sections) vs extension-provided elements, and verify no core command or agent references extension-only elements without a fallback.

- **Tasks:**
  - [ ] List all agents in `.claude/agents/` and classify as core vs extension-provided (research-002 provides initial classification)
  - [ ] List all skills in `.claude/skills/` and classify as core vs extension-provided
  - [ ] List all rules in `.claude/rules/` and classify as core vs extension-provided
  - [ ] List all context directories in `.claude/context/project/` and classify as core vs extension-provided
  - [ ] Grep all core commands (`.claude/commands/*.md`) for references to extension-specific agents, skills, or context paths
  - [ ] Grep all core agents for hardcoded references to extension-provided context files
  - [ ] Document the definitive core inventory in a checklist for Phase 2
  - [ ] Repeat classification for `.opencode/` system, noting differences

- **Timing:** 1-1.5 hours

- **Files to modify:**
  - Working document only (notes for subsequent phases)

- **Verification:**
  - Every agent/skill/rule/context item is classified as core or extension
  - No core command references an extension-only element without fallback
  - Inventory matches research-002 recommendations (4 core agents, ~10 core skills, 5 core rules)

---

### Phase 2: Clean Core Systems [COMPLETED]

- **Goal:** Remove all extension-provided elements from the core `.claude/` and `.opencode/` systems so only core elements remain. Extension loader will re-add them when extensions are loaded.

- **Tasks:**
  - [ ] Remove extension-provided agent files from `.claude/agents/` (27 agents per research-002)
  - [ ] Remove extension-provided skill directories from `.claude/skills/` (~28 skill directories)
  - [ ] Remove extension-provided rule files from `.claude/rules/` (5 rules: neovim-lua.md, latex.md, lean4.md, nix.md, web-astro.md)
  - [ ] Remove extension-provided context directories from `.claude/context/project/` (13 directories per research-002)
  - [ ] Trim `.claude/CLAUDE.md` to contain only core content:
    - Core routing table (general, meta, markdown only)
    - Core skill-to-agent mapping (5 core agents only)
    - Core rules references (5 core rules only)
    - Adaptive discovery directive pointing to index.json
    - Remove all extension section markers and injected content
  - [ ] Apply same removals to `.opencode/` system (agents in `agent/subagents/`, skills, rules, context)
  - [ ] Trim `.opencode/OPENCODE.md` (or equivalent) to core-only content
  - [ ] Verify both systems still have complete core functionality by checking all core commands parse correctly

- **Timing:** 1.5-2 hours

- **Files to modify:**
  - `.claude/agents/` - Remove 27 extension agents
  - `.claude/skills/` - Remove ~28 extension skill directories
  - `.claude/rules/` - Remove 5 extension rules
  - `.claude/context/project/` - Remove 13 extension context directories
  - `.claude/CLAUDE.md` - Trim to core-only content
  - `.opencode/` - Mirror all removals

- **Verification:**
  - `.claude/agents/` contains only: general-implementation-agent.md, general-research-agent.md, meta-builder-agent.md, planner-agent.md
  - `.claude/skills/` contains only ~10 core skills
  - `.claude/rules/` contains only 5 core rules
  - `.claude/CLAUDE.md` has no extension-specific routing entries
  - Same for `.opencode/` system

---

### Phase 3: Fix index.json as Adaptive Registry [NOT STARTED]

- **Goal:** Rebuild index.json to contain only core entries with canonical paths, fix extension index-entries.json files to use correct path format, and ensure the merge module handles the clean union correctly.

- **Tasks:**
  - [ ] Create new core `.claude/context/index.json` with only core entries (~9 entries for core/* and project/meta/, project/repo/, project/hooks/, project/processes/)
  - [ ] Audit all extension `index-entries.json` files for path prefix consistency
  - [ ] Fix any extension index-entries.json files that use wrong path prefixes (`.claude/context/project/...` or `context/project/...` instead of `project/...`)
  - [ ] Verify `normalize_index_path()` in `merge.lua` still works correctly with clean paths
  - [ ] Create new core `.opencode/context/index.json` with only core entries
  - [ ] Fix `.opencode/` extension index-entries.json files similarly
  - [ ] Add missing entries for formal-research-agent and physics-research-agent to relevant extension index-entries.json files (they exist as agents but have no index entries in .opencode)

- **Timing:** 1-1.5 hours

- **Files to modify:**
  - `.claude/context/index.json` - Rebuild with core-only entries
  - `.opencode/context/index.json` - Rebuild with core-only entries
  - `.claude/extensions/*/index-entries.json` - Fix path prefixes as needed
  - `.opencode/extensions/*/index-entries.json` - Fix path prefixes as needed
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Verify normalize function (may need no changes)

- **Verification:**
  - `jq '.entries | length' .claude/context/index.json` returns ~9 (core only)
  - All extension index-entries.json files use `project/*` or `core/*` paths consistently
  - `jq '.entries[].path' .claude/context/index.json` shows no `.claude/context/` or `context/` prefixes
  - Same checks for `.opencode/`

---

### Phase 4: Update Extension Loader with Post-Load Verification [NOT STARTED]

- **Goal:** Add a verification pass to the extension loader that checks wiring integrity after loading extensions, and fix the absolute path tracking issue in extensions.json.

- **Tasks:**
  - [ ] Add a `verify_loaded_extension()` function to `shared/extensions/loader.lua` (or a new `verify.lua` module) that checks:
    - All agent files referenced by extension skills exist on disk
    - All context files referenced in merged index.json entries exist on disk
    - All rules referenced by extension manifest exist on disk
    - CLAUDE.md/OPENCODE.md section markers are properly injected
  - [ ] Call verification after each successful extension load
  - [ ] Report verification results to the user via notification
  - [ ] Fix `extensions.json` to use relative paths instead of absolute paths for `installed_files`
  - [ ] Add verification to the `<leader>ac` / `<leader>ao` extension picker UI (show verification status in picker)

- **Timing:** 1.5-2 hours

- **Files to modify:**
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Add post-load verification call
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua` - New module for verification logic
  - `lua/neotex/plugins/ai/shared/extensions/state.lua` - Fix absolute path tracking
  - `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Show verification status
  - `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Show verification status

- **Verification:**
  - Loading an extension triggers verification and reports results
  - Verification catches missing files (test by temporarily renaming a file)
  - extensions.json stores relative paths that work regardless of project location
  - Picker shows green/red verification status for each loaded extension

---

### Phase 5: End-to-End Wiring Validation [NOT STARTED]

- **Goal:** Perform a full validation of the complete wiring chain: task type -> skill -> agent -> context loading, for both systems, after loading all extensions.

- **Tasks:**
  - [ ] Start with clean core systems (from Phase 2)
  - [ ] Load all 11 extensions via `<leader>ac` for .claude and `<leader>ao` for .opencode
  - [ ] Verify post-load verification passes for all extensions
  - [ ] For each language type (neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal, general, meta):
    - Verify skill file exists and references correct agent
    - Verify agent file exists
    - Run index.json query `jq '.entries[] | select(.load_when.languages[]? == "LANG")' .claude/context/index.json` and verify non-empty results
    - Run index.json query for agent name and verify non-empty results
    - Verify all context files referenced in index entries exist on disk
  - [ ] Verify .opencode/ has equivalent wiring (may have structural differences but same coverage)
  - [ ] Document any remaining gaps or issues found during validation
  - [ ] Create a validation script that can be re-run after future changes: `.claude/scripts/validate-wiring.sh`

- **Timing:** 1-1.5 hours

- **Files to modify:**
  - `.claude/scripts/validate-wiring.sh` - New validation script
  - Any files found to have remaining issues during validation

- **Verification:**
  - Validation script runs and reports all-green for both .claude/ and .opencode/
  - Every language type has: skill -> agent -> index entries -> context files on disk
  - No "0 results" from any index.json agent/language query after extensions are loaded
  - neovim-research-agent and filetypes-router-agent (the original broken cases) now get full context

---

### Phase 6: Documentation and Cleanup [NOT STARTED]

- **Goal:** Update documentation to reflect the new core/extension architecture, clean up any residual issues, and ensure the changes are maintainable.

- **Tasks:**
  - [ ] Update `.claude/docs/concepts/directory-organization.md` to document core vs extension element separation
  - [ ] Update extension loader documentation to describe post-load verification
  - [ ] Add a note to `.claude/extensions/README.md` about canonical path format for index-entries.json
  - [ ] Clean up any backup files (.backup) created during testing
  - [ ] Verify git status is clean and all changes are committed
  - [ ] Update `.opencode/` documentation equivalently

- **Timing:** 0.5-1 hour

- **Files to modify:**
  - `.claude/docs/concepts/directory-organization.md`
  - `.claude/extensions/README.md` (or create if needed)
  - `.opencode/` documentation equivalents

- **Verification:**
  - Documentation accurately describes new core/extension boundary
  - No stale references to extension elements in core documentation
  - Extension authoring guide includes path format requirements

## Testing & Validation

- [ ] Clean core .claude/ system starts up without errors (no extension files present)
- [ ] Loading all extensions via picker succeeds and passes verification
- [ ] index.json contains correct entries after extension loading (core + all extension entries)
- [ ] CLAUDE.md contains core sections + injected extension sections after loading
- [ ] Every language type routes to correct skill -> agent -> context chain
- [ ] neovim-research-agent gets 16 context entries from index.json (was 0 before)
- [ ] filetypes-router-agent gets 8 context entries from index.json (was 0 before)
- [ ] Unloading an extension removes its entries from index.json
- [ ] validate-wiring.sh script passes for both systems
- [ ] extensions.json uses relative paths

## Artifacts & Outputs

- `specs/169_verify_agent_systems_wired_after_reload/plans/implementation-001.md` (this file)
- `.claude/scripts/validate-wiring.sh` (new wiring validation script)
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` (new verification module)
- `specs/169_verify_agent_systems_wired_after_reload/summaries/implementation-summary-YYYYMMDD.md` (on completion)

## Rollback/Contingency

If the core cleanup (Phase 2) causes issues:
- Git revert to the pre-cleanup commit restores all extension files to core
- The extension loader still works with the old state (it detects conflicts and skips existing files)

If the index.json rebuild (Phase 3) breaks queries:
- The old index.json is preserved in git history
- Agents fall back to hardcoded @-references in their definition files

If the loader verification (Phase 4) has false positives:
- Verification is advisory (notifications), not blocking
- Can be disabled via a config flag while issues are resolved
