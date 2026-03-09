# Implementation Plan: Task #163

- **Task**: 163 - review_extension_language_routing
- **Status**: [IMPLEMENTING]
- **Effort**: 3-5 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Date**: 2026-03-09

## Overview

The extension system has significant gaps in language routing: 8 of 10 extension languages are partially or completely missing from command routing tables, context index entries are not merged for 5 extensions, and no automated activation mechanism exists. This plan addresses these gaps in four phases, ordered by impact: first fixing command routing tables so existing extensions work, then merging missing context index entries, then creating an extension activation script for future extensions, and finally standardizing schemas and fixing inconsistencies.

### Research Integration

Research report research-001.md identified 11 findings across the extension routing chain. Key findings integrated into this plan:
- Finding 2-3: /research and /implement commands missing extension language routes (Phase 1)
- Finding 5: Missing context index entries for z3, python, nix, web, formal (Phase 2)
- Finding 6: No extension activation script (Phase 3)
- Finding 1, 7-8, 11: Schema inconsistencies, naming mismatches, path errors (Phase 4)

## Goals & Non-Goals

**Goals**:
- All extension languages route to their dedicated research and implementation skills
- Context index contains entries for all installed extensions
- An activation script automates extension installation (index merge, skill/agent discovery)
- Extension schemas and naming are consistent across all extensions

**Non-Goals**:
- Creating new extensions or adding new languages
- Modifying agent or skill internals (only routing and discovery)
- Changing the /plan command routing (language-agnostic by design per Finding 4)
- Full extension marketplace or dependency management

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing neovim/general routing while updating tables | High | Low | Test core languages first; keep existing entries unchanged |
| Extension skills not discovered by Claude Code at runtime | High | Medium | Verify skill discovery paths; create symlinks if needed |
| Index merge script corrupts index.json | Medium | Low | Validate JSON after merge; keep backup |
| lean4/lean naming fix breaks existing lean tasks | Medium | Medium | Check state.json for active lean tasks; update both manifest and skill triggers atomically |

## Implementation Phases

### Phase 1: Update Command Routing Tables [COMPLETED]

**Goal**: All extension languages route to their dedicated skills in /research and /implement commands.

**Tasks**:
- [ ] Update `.claude/commands/research.md` routing table to add all extension languages with their dedicated research skills
- [ ] Update `.claude/commands/implement.md` routing table to add all extension languages with their dedicated implementation skills
- [ ] Verify that the referenced skill names match actual skill directory names in `.claude/extensions/*/skills/`
- [ ] Update the CLAUDE.md Language-Based Routing table to list all supported languages (both core and extension)
- [ ] Verify extension skills are discoverable (check if Claude Code can find skills in `.claude/extensions/*/skills/` or if symlinks to `.claude/skills/` are needed)

**Timing**: 1-1.5 hours

**Files to modify**:
- `.claude/commands/research.md` - Add extension language routing entries
- `.claude/commands/implement.md` - Add extension language routing entries
- `.claude/CLAUDE.md` - Update Language-Based Routing table
- `.claude/skills/` - Create symlinks if extension skills are not discoverable at their extension paths

**Verification**:
- All extension languages appear in both routing tables
- Each language maps to a skill that exists at the referenced path
- Core language routing (neovim, general, meta) remains unchanged
- Run `ls -la .claude/skills/` to confirm skill discovery paths

---

### Phase 2: Merge Extension Context Index Entries [COMPLETED]

**Goal**: All extension context entries are present in the main index.json for agent context discovery.

**Tasks**:
- [ ] Read each extension's `index-entries.json` file (z3, python, nix, web, formal)
- [ ] Normalize entries to match the main index.json schema (handle both flat array and `{ "entries": [...] }` formats)
- [ ] Merge entries into `.claude/context/index.json`, preserving existing entries
- [ ] Validate the merged index.json is valid JSON with no duplicate paths
- [ ] Verify merged entries are queryable: test `jq` queries for each new language

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/index.json` - Add entries from z3, python, nix, web, formal extensions

**Verification**:
- `jq '.entries[] | select(.load_when.languages[]? == "z3")' .claude/context/index.json` returns entries
- Same query succeeds for python, nix, web, formal, logic, math, physics
- Existing entries for neovim, lean4, latex, typst, epidemiology remain intact
- index.json passes JSON validation

---

### Phase 3: Create Extension Activation Script [COMPLETED]

**Goal**: A script that reads an extension's manifest.json and performs all necessary merges and discovery setup.

**Tasks**:
- [ ] Create `.claude/scripts/install-extension.sh` that:
  - Reads `manifest.json` from a given extension directory
  - Merges `index-entries.json` into main `index.json` (handles both schema formats)
  - Creates symlinks for skills from extension path to `.claude/skills/` (if needed based on Phase 1 findings)
  - Creates symlinks for agents from extension path to `.claude/agents/` (if needed)
  - Validates the result (JSON validity, no duplicates)
- [ ] Create `.claude/scripts/uninstall-extension.sh` that reverses the install
- [ ] Add error handling for missing files, invalid JSON, duplicate entries
- [ ] Document usage in script header comments

**Timing**: 1-1.5 hours

**Files to modify**:
- `.claude/scripts/install-extension.sh` - New file
- `.claude/scripts/uninstall-extension.sh` - New file

**Verification**:
- `bash .claude/scripts/install-extension.sh .claude/extensions/z3` succeeds and adds z3 entries to index.json
- `bash .claude/scripts/uninstall-extension.sh .claude/extensions/z3` removes z3 entries cleanly
- Script handles both index-entries.json schema formats
- Script fails gracefully with clear error messages on invalid input
- Running install twice does not create duplicates (idempotent)

---

### Phase 4: Standardize Schemas and Fix Inconsistencies [COMPLETED]

**Goal**: All extensions use consistent schemas and naming, with no broken references.

**Tasks**:
- [ ] Standardize all `index-entries.json` files to use the `{ "entries": [...] }` format (update lean, nix, web, epidemiology from flat array to object format)
- [ ] Fix lean4/lean naming: update lean skill trigger conditions to accept both "lean4" and "lean", or standardize on one name across manifest, skills, and state.json
- [ ] Fix epidemiology extension: replace `.opencode/` path references with `.claude/` in EXTENSION.md
- [ ] Update `/task` command language detection to recognize extension language keywords (lean, latex, typst, python, z3, nix, web, formal, epidemiology)
- [ ] Verify all extension EXTENSION.md files use correct paths

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/lean/index-entries.json` - Normalize schema
- `.claude/extensions/nix/index-entries.json` - Normalize schema
- `.claude/extensions/web/index-entries.json` - Normalize schema
- `.claude/extensions/epidemiology/index-entries.json` - Normalize schema
- `.claude/extensions/epidemiology/EXTENSION.md` - Fix .opencode/ paths
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` - Fix language trigger
- `.claude/commands/task.md` - Add extension language keyword detection

**Verification**:
- All `index-entries.json` files parse with `jq '.entries'` (consistent schema)
- `grep -r '.opencode/' .claude/extensions/` returns no results
- Lean skill triggers on both "lean" and "lean4" (or one standardized name)
- `/task "create z3 solver"` auto-detects language as z3 (or appropriate mapping)

## Testing & Validation

- [ ] Core language routing still works: neovim, general, meta tasks route correctly
- [ ] Extension language routing works: latex, typst, lean tasks route to dedicated skills
- [ ] Context discovery works: `jq` queries for all languages return expected entries
- [ ] Install script is idempotent: running twice produces no duplicates
- [ ] Uninstall script cleanly removes entries
- [ ] No broken path references in any extension files

## Artifacts & Outputs

- `.claude/commands/research.md` - Updated routing table
- `.claude/commands/implement.md` - Updated routing table
- `.claude/context/index.json` - Merged extension entries
- `.claude/scripts/install-extension.sh` - New activation script
- `.claude/scripts/uninstall-extension.sh` - New removal script
- Multiple extension files - Schema and path fixes
- `specs/163_review_extension_language_routing/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

All changes are to `.claude/` configuration files (commands, context index, extension metadata). If implementation causes issues:

1. **Routing table rollback**: Revert research.md and implement.md to only list core languages (neovim, general, meta, markdown)
2. **Index rollback**: `git checkout .claude/context/index.json` to restore pre-merge state
3. **Script rollback**: Delete install/uninstall scripts (no dependencies on them yet)
4. **Schema rollback**: Individual extension files can be reverted independently via git

No production code or Neovim configuration is modified by this task.
