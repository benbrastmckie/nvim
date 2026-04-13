# Implementation Plan: Extract Artifact Linking Helper

- **Task**: 398 - Extract artifact linking helper
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (task 397 already completed)
- **Research Inputs**: specs/398_extract_artifact_linking_helper/reports/01_artifact-linking-helper.md
- **Artifacts**: plans/01_artifact-linking-helper.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Six core skills and approximately 20 extension skills carry near-identical four-case TODO.md artifact-linking logic (no link / insert inline / convert inline to multi-line / append to multi-line). This plan extracts that logic into a single canonical context pattern file (`.claude/context/patterns/artifact-linking-todo.md`) and replaces the duplicated inline instructions in all skills with a compact reference. The approach respects the postflight tool boundary (Edit tool remains invoked by the skill itself) and eliminates drift risk with zero runtime overhead.

### Research Integration

The research report confirmed that a shell script approach is not viable because the TODO.md linking requires the Edit tool, which is only available inside Claude Code. A reusable skill was rejected as over-engineered (adds delegation latency). The recommended Option C -- a context-only pattern file referenced via `@`-import -- was selected as the best balance of maintainability, simplicity, and constraint compliance. The research also identified all 26 files carrying the duplicated pattern and confirmed the three parameterized differences (field_name, artifact_type, next_field).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" items in Phase 1 of the roadmap, specifically reducing duplication and drift risk across skill files. It also indirectly supports the "Extension slim standard enforcement" item by establishing a shared pattern that extensions reference rather than duplicate.

## Goals & Non-Goals

**Goals**:
- Create a single canonical pattern file for count-aware TODO.md artifact linking
- Replace ~20-25 lines of duplicated instructions in each of 26 skill files with a 4-line reference
- Add the pattern file to index.json for context discovery
- Update state-management-schema.md to cross-reference the new pattern file

**Non-Goals**:
- Modifying the postflight shell scripts (they handle state.json correctly and are unchanged)
- Creating a lint/enforcement script (stretch goal deferred to a follow-up task)
- Changing the artifact linking behavior itself (only consolidating instructions)
- Modifying skill-status-sync's artifact_link operation

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Claude misinterprets parameterized instructions in pattern file | M | L | Include concrete Edit tool examples for each of the three artifact types |
| Extension skills have subtle variations from core skills | L | L | Research confirmed structural identity; audit each file during implementation |
| Pattern file not loaded in context at runtime | M | M | Add to index.json with appropriate load_when; skills also use direct `@`-reference |
| Breaking working skills during bulk refactor | H | L | Test one skill (skill-researcher) end-to-end first before batch updating others |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Canonical Pattern File [COMPLETED]

**Goal**: Author the single source of truth for TODO.md artifact linking logic.

**Tasks**:
- [ ] Create `.claude/context/patterns/artifact-linking-todo.md`
- [ ] Document the four cases with concrete Edit tool examples
- [ ] Parameterize with `field_name`, `artifact_filename`, `artifact_path`, `next_field`
- [ ] Include the parameterization map (research/plan/summary with their field names and anchors)
- [ ] Add entry to `.claude/context/index.json` with `load_when` targeting all skill agents that perform artifact linking

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/artifact-linking-todo.md` - new file, canonical four-case logic
- `.claude/context/index.json` - add entry for the new pattern file

**Verification**:
- Pattern file exists and covers all four cases with concrete examples
- index.json entry is valid JSON and targets appropriate agents/commands

---

### Phase 2: Update 6 Core Skills [COMPLETED]

**Goal**: Replace inline artifact-linking instructions in all core skills with a reference to the pattern file.

**Tasks**:
- [ ] Update `skill-researcher/SKILL.md` Stage 8 -- replace ~25 lines with 4-line reference
- [ ] Update `skill-planner/SKILL.md` Stage 8 -- replace ~25 lines with 4-line reference
- [ ] Update `skill-implementer/SKILL.md` Stage 8 -- replace ~25 lines with 4-line reference
- [ ] Update `skill-team-research/SKILL.md` Stage 10 -- replace ~25 lines with 4-line reference
- [ ] Update `skill-team-plan/SKILL.md` Stage 10 -- replace ~25 lines with 4-line reference
- [ ] Update `skill-team-implement/SKILL.md` Stage 12 -- replace ~25 lines with 4-line reference

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - replace Stage 8 artifact-linking block
- `.claude/skills/skill-planner/SKILL.md` - replace Stage 8 artifact-linking block
- `.claude/skills/skill-implementer/SKILL.md` - replace Stage 8 artifact-linking block
- `.claude/skills/skill-team-research/SKILL.md` - replace Stage 10 artifact-linking block
- `.claude/skills/skill-team-plan/SKILL.md` - replace Stage 10 artifact-linking block
- `.claude/skills/skill-team-implement/SKILL.md` - replace Stage 12 artifact-linking block

**Verification**:
- Each skill file contains the compact reference block (4 lines) instead of the inline logic (20+ lines)
- Each reference uses the correct parameters (field_name, next_field) for its artifact type
- No skill file still contains the old four-case inline instructions

---

### Phase 3: Update Extension Skills [COMPLETED]

**Goal**: Apply the same replacement to all ~20 extension skill files.

**Tasks**:
- [ ] Update nix extension skill (skill-nix-implementation)
- [ ] Update web extension skills (skill-web-research, skill-web-implementation)
- [ ] Update present extension skills (skill-timeline, skill-grant, skill-funds, skill-budget)
- [ ] Update founder extension skills (skill-strategy, skill-spreadsheet, skill-project, skill-meeting, skill-market, skill-legal, skill-finance, skill-deck-research, skill-analyze)
- [ ] Update skill-reviser
- [ ] Verify no other extension skills were missed by searching for the four-case pattern

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.claude/extensions/web/skills/skill-web-research/SKILL.md`
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- `.claude/extensions/present/skills/skill-timeline/SKILL.md`
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
- `.claude/extensions/present/skills/skill-funds/SKILL.md`
- `.claude/extensions/present/skills/skill-budget/SKILL.md`
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md`
- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md`
- `.claude/extensions/founder/skills/skill-project/SKILL.md`
- `.claude/extensions/founder/skills/skill-meeting/SKILL.md`
- `.claude/extensions/founder/skills/skill-market/SKILL.md`
- `.claude/extensions/founder/skills/skill-legal/SKILL.md`
- `.claude/extensions/founder/skills/skill-finance/SKILL.md`
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md`
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md`
- `.claude/skills/skill-reviser/SKILL.md`

**Verification**:
- All extension skill files use the compact reference
- A grep for the old inline pattern across `.claude/skills/` and `.claude/extensions/` returns zero matches

---

### Phase 4: Update Cross-References and Final Validation [COMPLETED]

**Goal**: Update documentation cross-references and validate the complete refactor.

**Tasks**:
- [ ] Update `.claude/context/reference/state-management-schema.md` "Count-Aware Linking" section to cross-reference the new pattern file
- [ ] Verify `.claude/context/processes/research-workflow.md` and `planning-workflow.md` reference the pattern file (or confirm they are reference-only and need no change)
- [ ] Run a final grep across the entire `.claude/` tree for remnants of the old inline four-case logic
- [ ] Confirm the pattern file is discoverable via `jq` query on index.json

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - add cross-reference to pattern file

**Verification**:
- `grep -r "No existing line" .claude/skills/ .claude/extensions/` returns no matches (old inline logic fully removed)
- state-management-schema.md references the new pattern file
- index.json entry resolves correctly for relevant agents

## Testing & Validation

- [ ] Verify pattern file exists at `.claude/context/patterns/artifact-linking-todo.md` with all four cases documented
- [ ] Verify all 6 core skills reference the pattern file instead of carrying inline logic
- [ ] Verify all ~17 extension skills reference the pattern file
- [ ] Grep for remnants of old inline instructions (e.g., "No existing line", "convert inline to multi-line") across skill files returns zero results
- [ ] Validate index.json is valid JSON after adding the new entry

## Artifacts & Outputs

- `.claude/context/patterns/artifact-linking-todo.md` - canonical four-case artifact-linking pattern (new)
- `.claude/context/index.json` - updated with new entry
- `.claude/context/reference/state-management-schema.md` - updated cross-reference
- 6 core skill SKILL.md files - updated with compact references
- ~17 extension skill SKILL.md files - updated with compact references

## Rollback/Contingency

All changes are to markdown instruction files with no runtime code. If the refactor causes issues:
1. `git revert` the implementation commit to restore all inline instructions
2. The pattern file can be deleted without side effects since it is purely instructional
3. No shell scripts, no new skill wiring, and no schema changes make rollback trivial
