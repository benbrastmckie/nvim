# Implementation Plan: Remove Phase Checkpoint Protocol from assembly/implement agents

- **Task**: 409 - Remove Phase Checkpoint Protocol from assembly/implement agents
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_remove-checkpoint-protocol.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Remove the Phase Checkpoint Protocol from 3 extension agents that carry overly complex per-phase git commit logic, phase-to-stage mapping tables, and before/after phase checklists. This is a pure removal task -- no new content is added. Phase status markers (`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`) in plan files are NOT affected; they are a core system feature defined in `.claude/rules/artifact-formats.md` and updated by implementation agents during normal execution.

## Goals & Non-Goals

**Goals**:
- Remove the `## Phase Checkpoint Protocol` section from pptx-assembly-agent.md and slidev-assembly-agent.md
- Remove the `## Phase Checkpoint Protocol` section and inline before/after phase instructions from epi-implement-agent.md
- Remove associated references: per-phase git commit notes, preamble lines, and Critical Requirements items that reference the protocol
- Keep all agent functionality intact (only protocol overhead is removed)

**Non-Goals**:
- Modifying `.claude/rules/artifact-formats.md` (phase status markers are preserved there)
- Changing any agent's core execution stages (A1-A8, S1-S9, Phases 1-5)
- Adding replacement coordination logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Remove too much content (break agent logic) | H | L | Identify exact line ranges before editing; verify agent stages remain intact after edits |
| Miss a reference to the protocol elsewhere | L | L | Grep for "Phase Checkpoint" and "per-phase git" across all files after removal |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Clean pptx-assembly-agent.md [COMPLETED]

**Goal**: Remove Phase Checkpoint Protocol and all references from pptx-assembly-agent.md.

**Tasks**:
- [ ] Remove lines 100-144: the entire `## Phase Checkpoint Protocol` section (from `## Phase Checkpoint Protocol` through `**Resume behavior**:` paragraph, ending before `---`)
- [ ] Remove the preamble sentence at Stage A1 (line 150-151): `**Preamble**: Before processing slides, read the plan file and update the current phase to \`[IN PROGRESS]\` per the Phase Checkpoint Protocol above.`
- [ ] Remove the note at Stage A7 (line 265): `**Note**: Per-phase git commits (from the Phase Checkpoint Protocol) replace a single final commit. Each phase is committed individually with \`task {N} phase {P}: {phase_name}\` format.`
- [ ] Remove Critical Requirements items 8-10 (lines 372-374): `8. Follow Phase Checkpoint Protocol for all assembly operations`, `9. Update plan phase headings before and after each phase`, `10. Create per-phase git commits with session ID`
- [ ] Renumber remaining Critical Requirements items (items after the removed ones)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/agents/pptx-assembly-agent.md` - Remove protocol section and references

**Verification**:
- Agent stages A1-A8 remain intact with correct content
- No references to "Phase Checkpoint Protocol" remain in the file
- Critical Requirements numbering is sequential

---

### Phase 2: Clean slidev-assembly-agent.md [COMPLETED]

**Goal**: Remove Phase Checkpoint Protocol and all references from slidev-assembly-agent.md.

**Tasks**:
- [ ] Remove lines 118-162: the entire `## Phase Checkpoint Protocol` section (from `## Phase Checkpoint Protocol` through `**Resume behavior**:` paragraph, ending before `---`)
- [ ] Remove the preamble sentence at Stage S1 (line 168-169): `**Preamble**: Before processing slides, read the plan file and update the current phase to \`[IN PROGRESS]\` per the Phase Checkpoint Protocol above.`
- [ ] Remove the note at Stage S8 (line 313): `**Note**: Per-phase git commits (from the Phase Checkpoint Protocol) replace a single final commit. Each phase is committed individually with \`task {N} phase {P}: {phase_name}\` format.`
- [ ] Remove Critical Requirements items 10-12 (lines 403-405): `10. Follow Phase Checkpoint Protocol for all assembly operations`, `11. Update plan phase headings before and after each phase`, `12. Create per-phase git commits with session ID`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/agents/slidev-assembly-agent.md` - Remove protocol section and references

**Verification**:
- Agent stages S1-S9 remain intact with correct content
- No references to "Phase Checkpoint Protocol" remain in the file
- Critical Requirements numbering is sequential

---

### Phase 3: Clean epi-implement-agent.md [COMPLETED]

**Goal**: Remove Phase Checkpoint Protocol section and inline before/after phase instructions from epi-implement-agent.md.

**Tasks**:
- [ ] Remove lines 140-158 in Stage 3: the inline before/after phase instructions block (from `**Before each phase**` through the git commit code block ending with `6. **Proceed to next phase** or return if blocked`). This includes the `[IN PROGRESS]`/`[COMPLETED]` Edit-tool instructions and the per-phase git commit block. Keep the opening paragraph of Stage 3 (`Execute 5 R analysis phases sequentially...`) and the `Phase status lives ONLY in the heading` note.
- [ ] Remove lines 490-511: the entire `## Phase Checkpoint Protocol` section at the bottom of the file (from `## Phase Checkpoint Protocol` through `- Failed phases can be retried from beginning`)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/epidemiology/agents/epi-implement-agent.md` - Remove protocol sections

**Verification**:
- Stage 3 still introduces the 5-phase execution with `Update partial_progress metadata after each phase completes`
- Phase 1-5 subsections remain intact
- The `## Phase Checkpoint Protocol` section at the bottom is fully removed
- No references to "per-phase git commit" remain

---

### Phase 4: Verify removal across codebase [COMPLETED]

**Goal**: Confirm no stale references to the removed protocol remain.

**Tasks**:
- [ ] Run `grep -r "Phase Checkpoint Protocol" .claude/extensions/` to confirm zero matches
- [ ] Run `grep -r "per-phase git commit" .claude/extensions/` to confirm zero matches
- [ ] Verify each file parses correctly (no orphaned markdown headings or broken lists)

**Timing**: 5 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only)

**Verification**:
- Both grep commands return zero results
- All three agent files have clean markdown structure

## Testing & Validation

- [ ] No references to "Phase Checkpoint Protocol" in any of the 3 modified files
- [ ] No references to "per-phase git commit" in any of the 3 modified files
- [ ] All agent execution stages (A1-A8, S1-S9, Phase 1-5) are intact
- [ ] Critical Requirements numbering is sequential in both assembly agents
- [ ] Phase status markers in `.claude/rules/artifact-formats.md` are unchanged

## Artifacts & Outputs

- `specs/409_remove_phase_checkpoint_protocol/plans/01_remove-checkpoint-protocol.md` (this plan)
- `specs/409_remove_phase_checkpoint_protocol/summaries/01_remove-checkpoint-protocol-summary.md` (after implementation)

## Rollback/Contingency

All changes are tracked in git. Revert with `git revert <commit>` if any agent behavior is broken after removal. The removed sections are purely instructional overhead and do not affect agent tool access or execution stage logic.
