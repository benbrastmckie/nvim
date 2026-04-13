# Implementation Plan: Remove Phase Checkpoint Protocol
- **Task**: 414 - Remove Phase Checkpoint Protocol from 10 extension agents
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/01_checkpoint-protocol-audit.md
- **Artifacts**: plans/01_checkpoint-removal-plan.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

Remove the `## Phase Checkpoint Protocol` sections and all inline references from 10 extension implementation agents. The protocol duplicates logic now handled by the core implementation agent and is no longer needed. Three complexity tiers exist: simple (5 agents), standard (2 agents), complex (3 agents). Total: ~286 lines removed across 10 files. Definition of done: zero matches for `Phase Checkpoint Protocol` in `.claude/extensions/`, all MUST DO/MUST NOT lists correctly renumbered, and grant-agent Stage 6/7 content preserved.

### Research Integration

- **01_checkpoint-protocol-audit.md**: Full agent-by-agent audit identifying exact line ranges for section removal, inline references to delete, and the grant-agent restructuring requirement.

## Goals & Non-Goals

**Goals**:
- Remove the `## Phase Checkpoint Protocol` section from all 10 extension agents
- Remove all inline references to plan file phase marker updates
- Preserve grant-agent Stage 6 and Stage 7 content by promoting them under Execution Flow
- Renumber all MUST DO / MUST NOT lists after line removals
- Leave no orphaned `---` separators or blank line artifacts

**Non-Goals**:
- Modifying core agents (only extension agents are in scope)
- Removing operational references to phase markers used for plan parsing or metadata partial_progress
- Changing any agent behavior beyond checkpoint protocol removal

## Risks & Mitigations

- **Risk**: Accidentally delete Stage 6/7 in grant-agent. **Mitigation**: Read content before and after edit; verify stages present post-edit.
- **Risk**: Break numbering in Critical Requirements lists. **Mitigation**: Renumber after each deletion; verify sequential ordering.
- **Risk**: Miss an inline reference. **Mitigation**: Research report provides complete inventory; grep verification in Phase 4 catches misses.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Simple Agents (5 files) [NOT STARTED]

- **Goal:** Remove the `## Phase Checkpoint Protocol` section and single inline reference from 5 agents with straightforward structure.
- **Tasks:**
  - [ ] `extensions/latex/agents/latex-implementation-agent.md`: Delete lines 131-148 (section), delete L164 inline ref, renumber MUST DO list
  - [ ] `extensions/typst/agents/typst-implementation-agent.md`: Delete lines 110-127 (section), delete L145 inline ref, renumber MUST DO list
  - [ ] `extensions/python/agents/python-implementation-agent.md`: Delete lines 129-156 (section), delete L164 inline ref, renumber MUST DO list
  - [ ] `extensions/z3/agents/z3-implementation-agent.md`: Delete lines 124-151 (section), delete L159 inline ref, renumber MUST DO list
  - [ ] `extensions/nix/agents/nix-implementation-agent.md`: Delete lines 698-720 (section only, no inline refs)
  - [ ] Verify: grep for `Phase Checkpoint Protocol` in each file returns 0 matches
- **Timing:** 15 minutes
- **Depends on:** none

Steps per file:
1. Delete the `## Phase Checkpoint Protocol` section (heading through end of section including trailing `---` and blank lines)
2. Delete the inline reference line in Critical Requirements MUST DO list (if present)
3. Renumber the MUST DO list after removal

Files and locations:

| File | Section to Remove | Inline Ref to Remove |
|------|-------------------|---------------------|
| `extensions/latex/agents/latex-implementation-agent.md` | Lines 131-148 | L164: `5. Update plan file phase markers with Edit tool` |
| `extensions/typst/agents/typst-implementation-agent.md` | Lines 110-127 | L145: `5. Update plan file phase markers with Edit tool` |
| `extensions/python/agents/python-implementation-agent.md` | Lines 129-156 | L164: `5. Update plan file phase markers with Edit tool` |
| `extensions/z3/agents/z3-implementation-agent.md` | Lines 124-151 | L159: `5. Update plan file phase markers with Edit tool` |
| `extensions/nix/agents/nix-implementation-agent.md` | Lines 698-720 | None |

### Phase 2: Standard Agents (2 files) [NOT STARTED]

- **Goal:** Remove checkpoint protocol section and inline Critical Requirements reference from 2 agents with slightly different reference locations.
- **Tasks:**
  - [ ] `extensions/nvim/agents/neovim-implementation-agent.md`: Delete lines 370-394 (section), delete L406 inline ref (`9. Always update plan file with phase status changes`), renumber MUST DO list
  - [ ] `extensions/web/agents/web-implementation-agent.md`: Delete lines 353-377 (section), delete L826 inline ref (`6. Always update plan file with phase status changes`), renumber MUST DO list
  - [ ] Verify: grep for `Phase Checkpoint Protocol` and `phase status changes` in each file
- **Timing:** 10 minutes
- **Depends on:** 1

Files and locations:

| File | Section to Remove | Inline Ref to Remove |
|------|-------------------|---------------------|
| `extensions/nvim/agents/neovim-implementation-agent.md` | Lines 370-394 | L406: `9. Always update plan file with phase status changes` |
| `extensions/web/agents/web-implementation-agent.md` | Lines 353-377 | L826: `6. Always update plan file with phase status changes` |

### Phase 3: Complex Agents (3 files) [NOT STARTED]

- **Goal:** Remove checkpoint protocol from 3 agents that have additional inline references or require structural reorganization.
- **Tasks:**
  - [ ] `extensions/founder/agents/founder-implement-agent.md`: Delete section (L1486-1515), delete L27 tool ref, delete L1620 MUST DO item, delete L1639 MUST NOT item, renumber both lists
  - [ ] `extensions/present/agents/deck-builder-agent.md`: Delete section (L489-518 including preceding `---`), delete L26 tool ref, delete L178-195 inline duplicate block (18 lines)
  - [ ] `extensions/present/agents/grant-agent.md`: Delete protocol content only (L397-429), promote Stage 6 and Stage 7 as peers under Execution Flow
  - [ ] Verify grant-agent Stage 6 and Stage 7 are intact and correctly positioned after restructuring
- **Timing:** 25 minutes
- **Depends on:** 2

Detailed instructions per agent:

**3a. founder-implement-agent.md** (5 removals):
1. Delete `## Phase Checkpoint Protocol` section (lines 1486-1515)
2. Delete `- Edit - Update plan phase markers` from Allowed Tools (line 27)
3. Delete `3. Always update phase markers in plan file` from MUST DO list (line 1620)
4. Delete `8. Leave phase markers in [IN PROGRESS] state` from MUST NOT list (line 1639)
5. Renumber both MUST DO and MUST NOT lists

Keep (operational context, not checkpoint protocol):
- L111: `- Phase list with status markers` (plan parsing)
- L179, L349, L389: implicit_typst_phase marker logic (Phase 5 operational)

**3b. deck-builder-agent.md** (3 removals):
1. Delete `## Phase Checkpoint Protocol` section (lines 489-518, including preceding `---`)
2. Delete `- Edit - Update plan phase markers` from Allowed Tools (line 26)
3. Delete the 18-line inline duplicate in Stage 3 (lines 178-195): "Before each phase" / "After each phase" block with Edit tool examples and git commit instructions

Keep:
- Lines 170-177: Phase scan logic (resume point detection) -- this is operational, not the protocol

**3c. grant-agent.md** (restructure, most complex):
1. Stage 6 and Stage 7 content (lines 431-517) is currently nested under `## Phase Checkpoint Protocol`. These must be preserved.
2. Delete the protocol content only (lines 397-429)
3. Promote `### Stage 6: Write Metadata File` and `### Stage 7: Return Brief Text Summary` -- they become direct children of the Execution Flow, positioned where the Phase Checkpoint Protocol heading was

### Phase 4: Verify and Clean Up [NOT STARTED]

- **Goal:** Confirm all checkpoint protocol references are removed and no artifacts remain.
- **Tasks:**
  - [ ] Run `grep -r "Phase Checkpoint Protocol" .claude/extensions/` -- expect 0 matches
  - [ ] Run `grep -r "Update plan.*phase markers" .claude/extensions/` -- expect 0 matches in agent files (may still appear in context docs)
  - [ ] Verify no orphaned `---` separators or blank lines at section boundaries in all 10 files
  - [ ] Verify grant-agent Stage 6/7 content is intact
  - [ ] Verify all MUST DO / MUST NOT lists are correctly numbered
- **Timing:** 10 minutes
- **Depends on:** 3

## Testing & Validation

- [ ] `grep -r "Phase Checkpoint Protocol" .claude/extensions/` returns 0 matches
- [ ] `grep -r "Update plan.*phase markers" .claude/extensions/` returns 0 matches in agent files
- [ ] grant-agent Stage 6 and Stage 7 preserved and correctly placed under Execution Flow
- [ ] All MUST DO / MUST NOT lists correctly numbered (no gaps, no duplicates)
- [ ] No orphaned `---` separators or blank line artifacts at removal boundaries

## Artifacts & Outputs

- plans/01_checkpoint-removal-plan.md (this file)
- summaries/01_checkpoint-removal-summary.md (post-implementation)
- 10 modified agent files in `.claude/extensions/`

## Rollback/Contingency

All changes are to version-controlled markdown files. If any removal causes issues, revert individual files with `git checkout HEAD -- <path>`. No runtime dependencies or build steps are affected.
