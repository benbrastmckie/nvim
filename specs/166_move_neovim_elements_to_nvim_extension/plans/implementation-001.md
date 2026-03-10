# Implementation Plan: Task #166

- **Task**: 166 - move_neovim_elements_to_nvim_extension
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10
- **Feature**: Move neovim-specific agents, skills, context, and rules to nvim/ extension in both .claude/ and .opencode/ systems
- **Estimated Hours**: 3-4 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

Move all neovim-specific elements (agents, skills, context files, rules) from core locations in both the .claude/ and .opencode/ agent systems into a new `nvim/` extension directory within each system. This follows the established extension pattern (manifest.json, EXTENSION.md, index-entries.json) already used by z3, latex, nix, and other extensions. The two systems are independent but require parallel changes respecting their structural differences (agent paths, README conventions, merge target keys).

### Research Integration

Research identified 21 files to move in .claude/ and 27 in .opencode/ (extra READMEs and a stray lua-patterns.md). Key wiring points include command routing tables, CLAUDE.md/OPENCODE.md references, orchestration-core.md validation, and core index.json entries that reference neovim agents.

## Goals & Non-Goals

**Goals**:
- Create nvim/ extension directory in both .claude/extensions/ and .opencode/extensions/
- Move all neovim-specific files from core to extension directories
- Update all wiring points so routing still works after the move
- Follow the established extension pattern consistently

**Non-Goals**:
- Changing any neovim agent or skill behavior
- Modifying neovim context file content
- Adding new neovim capabilities
- Changing the "neovim" language value in state.json or routing tables

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking neovim task routing after move | H | M | Verify all routing tables updated; test with dry run |
| Missing file in move (stray references) | M | L | Compare file counts before/after; grep for orphaned references |
| .opencode README structure not matching convention | L | M | Use z3 opencode extension as reference template |
| Rule path pattern stops working | M | L | Verify extension rule discovery via manifest provides.rules |
| Core index.json entries still reference removed paths | H | M | Explicit verification step after index updates |

## Implementation Phases

### Phase 1: Create nvim extension scaffold in .claude/ [NOT STARTED]

**Goal**: Create the extension directory structure and metadata files for the .claude/ system, following the established pattern from z3/latex extensions.

**Tasks**:
- [ ] Create directory structure: `.claude/extensions/nvim/{agents,skills,context/project/neovim,rules}/`
- [ ] Create `.claude/extensions/nvim/manifest.json` with language="neovim", provides listing agents/skills/rules/context, merge_targets with claudemd key
- [ ] Create `.claude/extensions/nvim/EXTENSION.md` with neovim routing table, skill-agent mapping, and neovim-specific quick reference (keymaps, API patterns)
- [ ] Create `.claude/extensions/nvim/index-entries.json` with entries for neovim context files (project/neovim/README.md, project/neovim/patterns/plugin-spec.md, and all other context files) including language and agent load_when mappings

**Timing**: 0.5 hours

**Files to create**:
- `.claude/extensions/nvim/manifest.json` - Extension metadata
- `.claude/extensions/nvim/EXTENSION.md` - Merge content for CLAUDE.md
- `.claude/extensions/nvim/index-entries.json` - Context discovery entries

**Verification**:
- manifest.json matches z3/latex pattern with language="neovim"
- EXTENSION.md has routing table and skill-agent mapping
- index-entries.json has entries for all 16 context files with correct load_when

---

### Phase 2: Create nvim extension scaffold in .opencode/ [NOT STARTED]

**Goal**: Create the extension directory structure and metadata files for the .opencode/ system, respecting the README-at-every-level convention.

**Tasks**:
- [ ] Create directory structure: `.opencode/extensions/nvim/{agents,skills,context/project/neovim,rules}/`
- [ ] Create README.md files at each directory level (nvim/, agents/, skills/, context/, context/project/, context/project/neovim/, rules/) following .opencode convention
- [ ] Create `.opencode/extensions/nvim/manifest.json` with opencode_md merge_target key and section_id "extension_oc_nvim"
- [ ] Create `.opencode/extensions/nvim/EXTENSION.md` with neovim routing, skill-agent mapping
- [ ] Create `.opencode/extensions/nvim/index-entries.json` with entries for all 22 context files

**Timing**: 0.5 hours

**Files to create**:
- `.opencode/extensions/nvim/manifest.json` - Extension metadata (opencode variant)
- `.opencode/extensions/nvim/EXTENSION.md` - Merge content for OPENCODE.md
- `.opencode/extensions/nvim/index-entries.json` - Context discovery entries
- `.opencode/extensions/nvim/README.md` - Extension root README
- README.md files at each subdirectory level

**Verification**:
- manifest.json uses opencode_md merge target key, section_id "extension_oc_nvim"
- All subdirectories have README.md (matching .opencode convention)
- index-entries.json covers all 22 context files

---

### Phase 3: Move files from .claude/ core to nvim extension [NOT STARTED]

**Goal**: Move all neovim-specific files from their core locations to the nvim extension directory in the .claude/ system.

**Tasks**:
- [ ] Move `.claude/agents/neovim-research-agent.md` to `.claude/extensions/nvim/agents/neovim-research-agent.md`
- [ ] Move `.claude/agents/neovim-implementation-agent.md` to `.claude/extensions/nvim/agents/neovim-implementation-agent.md`
- [ ] Move `.claude/skills/skill-neovim-research/SKILL.md` to `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- [ ] Move `.claude/skills/skill-neovim-implementation/SKILL.md` to `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- [ ] Move entire `.claude/context/project/neovim/` directory tree (16 files) to `.claude/extensions/nvim/context/project/neovim/`
- [ ] Move `.claude/rules/neovim-lua.md` to `.claude/extensions/nvim/rules/neovim-lua.md`
- [ ] Remove empty source directories after move (skill-neovim-research/, skill-neovim-implementation/, context/project/neovim/)

**Timing**: 0.5 hours

**Files to move** (21 total):
- 2 agent files
- 2 skill files (in 2 directories)
- 16 context files (in 5 subdirectories)
- 1 rule file

**Verification**:
- All 21 files exist in new locations
- No neovim files remain in core .claude/agents/, .claude/skills/, .claude/context/project/neovim/, .claude/rules/
- Original directories cleaned up (no empty neovim dirs)

---

### Phase 4: Move files from .opencode/ core to nvim extension [NOT STARTED]

**Goal**: Move all neovim-specific files from their core locations to the nvim extension directory in the .opencode/ system.

**Tasks**:
- [ ] Move `.opencode/agent/subagents/neovim-research-agent.md` to `.opencode/extensions/nvim/agents/neovim-research-agent.md`
- [ ] Move `.opencode/agent/subagents/neovim-implementation-agent.md` to `.opencode/extensions/nvim/agents/neovim-implementation-agent.md`
- [ ] Move `.opencode/skills/skill-neovim-research/` (SKILL.md + README.md) to `.opencode/extensions/nvim/skills/skill-neovim-research/`
- [ ] Move `.opencode/skills/skill-neovim-implementation/` (SKILL.md + README.md) to `.opencode/extensions/nvim/skills/skill-neovim-implementation/`
- [ ] Move entire `.opencode/context/project/neovim/` directory tree (22 files including READMEs and lua-patterns.md) to `.opencode/extensions/nvim/context/project/neovim/`
- [ ] Move `.opencode/rules/neovim-lua.md` to `.opencode/extensions/nvim/rules/neovim-lua.md`
- [ ] Remove empty source directories after move

**Timing**: 0.5 hours

**Files to move** (27 total):
- 2 agent files
- 4 skill files (SKILL.md + README.md in 2 directories)
- 22 context files (including READMEs at every level and stray lua-patterns.md)
- 1 rule file

**Verification**:
- All 27 files exist in new locations
- No neovim files remain in core .opencode/agent/subagents/, .opencode/skills/, .opencode/context/project/neovim/, .opencode/rules/
- Original directories cleaned up

---

### Phase 5: Update wiring in .claude/ system [NOT STARTED]

**Goal**: Update all references, routing tables, and index entries in the .claude/ system so neovim routing works via the extension.

**Tasks**:
- [ ] Update `.claude/CLAUDE.md`:
  - Remove neovim row from the Language-Based Routing table (extension provides this via EXTENSION.md merge)
  - Remove neovim entries from Skill-to-Agent Mapping table (extension provides these)
  - Update Rules References section: remove neovim-lua.md line (or note it's extension-provided)
  - Remove neovim-specific Context Imports entries (extension provides these)
  - Remove neovim-specific Context Discovery examples (or update to use extension path)
  - Add note that neovim is provided by the nvim extension
- [ ] Update `.claude/context/index.json`:
  - Remove `project/neovim/README.md` entry (moves to extension index-entries.json)
  - Remove `project/neovim/patterns/plugin-spec.md` entry (moves to extension index-entries.json)
  - Remove `neovim-implementation-agent` from agents array in `core/formats/return-metadata-file.md` entry
  - Remove `neovim-implementation-agent` from agents array in `core/patterns/anti-stop-patterns.md` entry
- [ ] Check `.claude/commands/research.md` for neovim routing references - update comment if needed
- [ ] Check `.claude/commands/implement.md` for neovim routing references - update comment if needed

**Timing**: 0.75 hours

**Files to modify**:
- `.claude/CLAUDE.md` - Remove neovim-specific sections that extension now provides
- `.claude/context/index.json` - Remove neovim entries and agent references
- `.claude/commands/research.md` - Update routing comment if present
- `.claude/commands/implement.md` - Update routing comment if present

**Verification**:
- `grep -r "neovim" .claude/CLAUDE.md` shows only the extension note, not routing/skill/context entries
- `jq '.entries[] | select(.path | contains("neovim"))' .claude/context/index.json` returns empty
- `jq '.entries[] | select(.load_when.agents[]? == "neovim-implementation-agent")' .claude/context/index.json` returns only core entries that should still reference it (none expected)
- Extension index-entries.json covers all former core entries

---

### Phase 6: Update wiring in .opencode/ system [NOT STARTED]

**Goal**: Update all references, routing tables, and index entries in the .opencode/ system so neovim routing works via the extension.

**Tasks**:
- [ ] Update `.opencode/OPENCODE.md` (or README.md equivalent):
  - Remove neovim row from Language-Based Routing table
  - Remove neovim entries from Skill-Agent Mapping
  - Update Rules References: remove neovim-lua.md
  - Remove neovim Context Imports
  - Add note that neovim is provided by nvim extension
- [ ] Update `.opencode/context/index.json`:
  - Remove `project/neovim/README.md` entry
  - Remove `project/neovim/patterns/plugin-spec.md` entry
  - Remove `neovim-implementation-agent` from agents arrays in core entries
- [ ] Update `.opencode/context/core/orchestration/orchestration-core.md`:
  - Move neovim routing validation (lines 220-221) into the extension validation loop (lines 226-233)
  - Or remove the standalone neovim validation since extensions handle their own routing
- [ ] Check `.opencode/commands/research.md` and `.opencode/commands/implement.md` for neovim references

**Timing**: 0.75 hours

**Files to modify**:
- `.opencode/OPENCODE.md` (or equivalent README) - Remove neovim-specific sections
- `.opencode/context/index.json` - Remove neovim entries and agent references
- `.opencode/context/core/orchestration/orchestration-core.md` - Move neovim validation to extension loop
- `.opencode/commands/research.md` - Update routing if present
- `.opencode/commands/implement.md` - Update routing if present

**Verification**:
- Neovim entries removed from core index.json
- Orchestration-core no longer has standalone neovim validation block
- Extension validation loop handles neovim routing like other extension languages
- No orphaned neovim references in core .opencode/ files

---

### Phase 7: Cross-system verification [NOT STARTED]

**Goal**: Verify both systems are correctly wired after all moves and updates. Ensure no broken references or orphaned files.

**Tasks**:
- [ ] Run `find .claude/agents .claude/skills .claude/context/project .claude/rules -name "*neovim*" -o -name "*nvim*"` - expect empty (all moved to extension)
- [ ] Run `find .opencode/agent/subagents .opencode/skills .opencode/context/project .opencode/rules -name "*neovim*" -o -name "*nvim*"` - expect empty
- [ ] Verify .claude extension file count: `find .claude/extensions/nvim/ -type f | wc -l` should be >= 24 (21 moved + 3 new metadata files)
- [ ] Verify .opencode extension file count: `find .opencode/extensions/nvim/ -type f | wc -l` should be >= 37 (27 moved + 3 metadata + ~7 READMEs)
- [ ] Verify index.json entries: `jq '[.entries[] | select(.path | contains("neovim"))] | length' .claude/context/index.json` should be 0
- [ ] Verify extension index has entries: `jq '.entries | length' .claude/extensions/nvim/index-entries.json` should be >= 2
- [ ] Check that neovim-implementation-agent is NOT in core index agent arrays: `grep "neovim-implementation-agent" .claude/context/index.json` should be empty
- [ ] Verify manifest provides.rules includes neovim-lua.md in both extensions
- [ ] Grep both CLAUDE.md and OPENCODE.md for orphaned neovim skill/agent/context references that should have been removed

**Timing**: 0.5 hours

**Verification**:
- All checks pass with expected results
- No orphaned references remain in core files
- Extension file counts match expectations

## Testing & Validation

- [ ] All neovim files exist in extension directories (count verification)
- [ ] No neovim files remain in core directories
- [ ] Core index.json has no neovim-specific entries or agent references
- [ ] Extension manifest.json is valid JSON with correct structure
- [ ] Extension index-entries.json is valid JSON with entries for all context files
- [ ] CLAUDE.md and OPENCODE.md no longer have neovim routing/skill/context in core sections
- [ ] Orchestration-core.md handles neovim via extension loop (not standalone block)

## Artifacts & Outputs

- `.claude/extensions/nvim/` - Complete nvim extension for .claude/ system
- `.opencode/extensions/nvim/` - Complete nvim extension for .opencode/ system
- Updated `.claude/CLAUDE.md` - Neovim sections removed from core
- Updated `.opencode/OPENCODE.md` - Neovim sections removed from core
- Updated `index.json` files (both systems) - Neovim entries moved to extension

## Rollback/Contingency

Since this is a file reorganization (move, not delete), rollback is straightforward:
1. `git checkout HEAD -- .claude/agents/neovim-* .claude/skills/skill-neovim-* .claude/context/project/neovim/ .claude/rules/neovim-lua.md`
2. `git checkout HEAD -- .opencode/agent/subagents/neovim-* .opencode/skills/skill-neovim-* .opencode/context/project/neovim/ .opencode/rules/neovim-lua.md`
3. `git checkout HEAD -- .claude/CLAUDE.md .claude/context/index.json .opencode/OPENCODE.md .opencode/context/index.json`
4. Remove the nvim extension directories: `rm -rf .claude/extensions/nvim .opencode/extensions/nvim`

Phase-level rollback is also possible since each phase focuses on one system and one operation type.
