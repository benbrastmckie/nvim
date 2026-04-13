# Implementation Plan: Audit Implementation Agents for Phase Checkpoint Protocol

- **Task**: 408 - Audit all implementation agents for Phase Checkpoint Protocol compliance
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/408_audit_implementation_agents_phase_checkpoint/reports/01_phase-checkpoint-audit.md
- **Artifacts**: plans/01_phase-checkpoint-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add the Phase Checkpoint Protocol to 5 non-compliant implementation agents across 3 extensions (python, z3, epidemiology, founder). Three agents are partially compliant (have phase status tracking but lack per-phase git commits and explicit Edit tool instructions) and two are completely non-compliant (missing all phase tracking). The reference implementation is in `grant-agent.md` (lines 397-427). Each fix involves inserting a standardized markdown section and, for partial agents, expanding inline mentions into explicit Edit tool instructions with git commit steps.

### Research Integration

The research audit (report 01) identified 13 implementation agents total: 8 fully compliant, 3 partially compliant (python-implementation-agent, z3-implementation-agent, founder-implement-agent), and 2 non-compliant (epi-implement-agent, deck-builder-agent). The report provides a recommended fix template and priority ordering by usage frequency.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add full Phase Checkpoint Protocol section to all 5 non-compliant agents
- Add explicit Edit tool instructions (old_string/new_string) for phase heading updates
- Add per-phase git commit step to all 5 agents
- Verify all 13 implementation agents pass a grep-based compliance check

**Non-Goals**:
- Modifying compliant agents (the 8 already-compliant agents are unchanged)
- Restructuring agent execution flows beyond adding the protocol
- Adding new features or capabilities to any agent

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| epi-implement-agent has unique 5-phase R workflow that resists template insertion | M | M | Wrap existing phases rather than restructuring; add protocol section separately from inline changes |
| Edit tool old_string mismatch if agent files have been modified since research | L | L | Read each file before editing to confirm current content |
| Inconsistent protocol wording across agents | M | L | Use exact template from research report section 4 for all agents |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Partially Compliant Agents [COMPLETED]

**Goal**: Add per-phase git commit instructions, explicit Edit tool instructions, and a dedicated Phase Checkpoint Protocol section to the 3 partially compliant agents.

**Tasks**:
- [ ] Read `python-implementation-agent.md` and identify Stage 4 phase-tracking mentions
- [ ] Replace informal Stage 4 bullet list with explicit A/B/C/D substeps: Mark In Progress (with Edit tool old_string/new_string), Execute, Verify, Mark Complete (with Edit tool old_string/new_string), Git commit
- [ ] Insert `## Phase Checkpoint Protocol` section (from research report template) after execution flow and before error handling
- [ ] Read `z3-implementation-agent.md` and apply identical changes (same template structure as python agent)
- [ ] Replace informal Stage 4 bullet list with explicit substeps
- [ ] Insert `## Phase Checkpoint Protocol` section
- [ ] Read `founder-implement-agent.md` and identify phase-tracking code
- [ ] Add git commit step after each phase mark-complete in the execution flow
- [ ] Insert `## Phase Checkpoint Protocol` section

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/python/agents/python-implementation-agent.md` - Expand Stage 4 with Edit tool instructions, add Phase Checkpoint Protocol section, add git commit per phase
- `.claude/extensions/z3/agents/z3-implementation-agent.md` - Expand Stage 4 with Edit tool instructions, add Phase Checkpoint Protocol section, add git commit per phase
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Add git commit step per phase, add Phase Checkpoint Protocol section

**Verification**:
- Each file contains `## Phase Checkpoint Protocol` heading
- Each file contains `old_string:` and `new_string:` Edit tool instructions
- Each file contains `git add -A && git commit` per-phase commit instruction

---

### Phase 2: Fix Non-Compliant Agents [COMPLETED]

**Goal**: Add the full Phase Checkpoint Protocol (heading updates, Edit tool instructions, git commits) to the 2 completely non-compliant agents.

**Tasks**:
- [ ] Read `epi-implement-agent.md` and identify the 5 fixed analysis phases
- [ ] Add plan heading update steps (Edit tool with old_string/new_string) around each of the 5 phases
- [ ] Add git commit step after each phase completion
- [ ] Insert `## Phase Checkpoint Protocol` section
- [ ] Read `deck-builder-agent.md` and identify resume detection logic
- [ ] Add explicit Edit tool instructions for phase heading updates (to complement existing resume detection)
- [ ] Add git commit step per phase
- [ ] Insert `## Phase Checkpoint Protocol` section

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/epidemiology/agents/epi-implement-agent.md` - Add heading update steps around each of 5 phases, add git commits, add Phase Checkpoint Protocol section
- `.claude/extensions/founder/agents/deck-builder-agent.md` - Add explicit Edit tool instructions for heading updates, add git commits, add Phase Checkpoint Protocol section

**Verification**:
- Each file contains `## Phase Checkpoint Protocol` heading
- Each file contains `old_string:` and `new_string:` Edit tool instructions
- Each file contains `git add -A && git commit` per-phase commit instruction
- epi-implement-agent retains its 5-phase R analysis structure

---

### Phase 3: Verification and Compliance Check [COMPLETED]

**Goal**: Verify all 13 implementation agents now have the Phase Checkpoint Protocol and required patterns.

**Tasks**:
- [ ] Grep all implementation agent files for `## Phase Checkpoint Protocol` heading -- expect 13 matches (8 existing + 5 new)
- [ ] Grep all implementation agent files for `old_string:.*Phase.*NOT STARTED` pattern -- expect all 13 agents match
- [ ] Grep all implementation agent files for `git add -A && git commit` pattern -- expect all 13 agents match
- [ ] Verify no regressions in compliant agents (spot-check 2 compliant agents still have correct protocol)
- [ ] Confirm epi-implement-agent retains its 5-phase R workflow structure alongside the new protocol

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- None (verification only)

**Verification**:
- All 13 implementation agents have `## Phase Checkpoint Protocol` section
- All 13 implementation agents have explicit Edit tool instructions for heading updates
- All 13 implementation agents have per-phase git commit instructions
- Zero regressions in previously-compliant agents

## Testing & Validation

- [ ] Grep for `## Phase Checkpoint Protocol` across all agent files returns exactly 13 matches (8 pre-existing + 5 new)
- [ ] Grep for `git add -A && git commit` in all implementation agent files returns 13 matches
- [ ] Grep for `old_string:` Edit tool pattern in all implementation agent files returns 13 matches
- [ ] Spot-check: read python-implementation-agent.md and confirm Stage 4 has explicit A/B/C/D substeps
- [ ] Spot-check: read epi-implement-agent.md and confirm 5-phase R structure is preserved

## Artifacts & Outputs

- plans/01_phase-checkpoint-plan.md (this file)
- summaries/01_phase-checkpoint-summary.md (post-implementation)

## Rollback/Contingency

All changes are additive markdown insertions to agent definition files. Revert with `git checkout -- .claude/extensions/{python,z3,epidemiology,founder}/agents/` to restore original agent files. No behavioral or structural changes to existing code.
