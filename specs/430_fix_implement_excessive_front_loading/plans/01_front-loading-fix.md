# Implementation Plan: Task #430

- **Task**: 430 - Fix /implement excessive front-loading
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/430_fix_implement_excessive_front_loading/reports/01_front-loading-fix.md
- **Artifacts**: plans/01_front-loading-fix.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: true

## Overview

The lead agent in both `skill-implementer` and `skill-team-implement` lacks an explicit "pre-delegation boundary" constraint, allowing it to read source files, grep, or use MCP tools before spawning sub-agents. This front-loads work that belongs to the sub-agent, wasting tokens and context window in the orchestrating skill. The fix adds pre-delegation boundary sections mirroring the existing postflight boundary pattern, plus inline constraints at specific stages where front-loading is tempted, and a responsibility claim in the implementation agent.

### Research Integration

The research report identified 5 specific insertion points across 3 files. Key findings: (1) Stage 5 heuristic "file overlap analysis" in skill-team-implement invites source reading; (2) Stage 7 prompt template variables are ambiguous about sourcing; (3) no pre-delegation boundary section exists in either skill; (4) the general-implementation-agent does not explicitly claim codebase exploration as its exclusive job. The existing postflight-tool-restrictions.md pattern provides the structural template.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances "Agent System Quality" under Phase 1 of the roadmap -- specifically improving the correctness of the agent delegation boundary, which reduces wasted tokens and improves implementation reliability.

## Goals & Non-Goals

**Goals**:
- Add pre-delegation boundary constraints to skill-team-implement/SKILL.md (3 insertions)
- Add pre-delegation boundary constraints to skill-implementer/SKILL.md (2 insertions)
- Add exclusive codebase responsibility claim to general-implementation-agent.md (1 insertion)
- Mirror the existing postflight boundary pattern for structural consistency

**Non-Goals**:
- Modifying postflight-tool-restrictions.md (constraint lives inline, not in a separate context file)
- Changing the agent's behavior or execution stages
- Modifying any other skill or agent files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Constraint too restrictive -- lead cannot parse plan adequately | M | L | Constraints explicitly allow reading the plan file; only source files are prohibited |
| Heuristic fallback in Stage 5 becomes unclear | L | L | Clarify that file-overlap analysis uses paths from plan text only |
| Future skills copy old pattern without seeing constraint | M | M | Constraint is prominent as a named section; matches existing postflight pattern |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add pre-delegation boundary to skill-team-implement [COMPLETED]

**Goal**: Add 3 insertions to skill-team-implement/SKILL.md establishing the pre-delegation boundary constraint.

**Tasks**:
- [ ] Insert "CRITICAL: Plan-Text-Only Analysis" constraint after Stage 5 heuristic block (after the "Heuristic signals" list around line 224)
- [ ] Insert "CRITICAL: Template Population from Plan Text Only" constraint before the Phase Implementer Prompt Template in Stage 7 (before line 267)
- [ ] Insert new "MUST NOT (Pre-Delegation Boundary)" section after the existing "MUST NOT (Postflight Boundary)" section (after line 662)

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-team-implement/SKILL.md` - 3 insertions: Stage 5 inline constraint, Stage 7 inline constraint, new boundary section

**Verification**:
- File contains "Pre-Delegation Boundary" section
- File contains "Plan-Text-Only Analysis" constraint in Stage 5
- File contains "Template Population from Plan Text Only" constraint in Stage 7
- Existing postflight boundary section is preserved unchanged

---

### Phase 2: Add pre-delegation boundary to skill-implementer [COMPLETED]

**Goal**: Add 2 insertions to skill-implementer/SKILL.md establishing the pre-delegation boundary.

**Tasks**:
- [ ] Insert "CRITICAL: No Source Reading Before Delegation" inline constraint between Stage 4 and Stage 4b (around line 160)
- [ ] Insert "Pre-Delegation Boundary" section before the existing "Postflight Boundary" line (before line 432)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - 2 insertions: inline constraint after Stage 4, boundary section before postflight

**Verification**:
- File contains "Pre-Delegation Boundary" section
- File contains "No Source Reading Before Delegation" constraint
- Existing postflight boundary is preserved unchanged

---

### Phase 3: Add codebase responsibility claim to general-implementation-agent [NOT STARTED]

**Goal**: Add 1 insertion to general-implementation-agent.md establishing that codebase exploration is the agent's exclusive responsibility.

**Tasks**:
- [ ] Insert "Codebase Exploration Responsibility" note after Stage 2 (after line 39, before Stage 3)

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` - 1 insertion after Stage 2

**Verification**:
- File contains "Codebase Exploration Responsibility" section
- Section explicitly states source reading, grepping, globbing, and MCP tools are the agent's job
- Existing Stage 2 and Stage 3 content is preserved

## Testing & Validation

- [ ] All 3 files parse correctly (no broken markdown)
- [ ] Each file contains its respective "Pre-Delegation Boundary" or "Codebase Exploration Responsibility" section
- [ ] Existing postflight boundary sections are unchanged
- [ ] No content was removed from any file (insertions only)
- [ ] Constraint language is consistent across all 3 files (same terminology: "source files", "sub-agent/subagent", "plan text only")

## Artifacts & Outputs

- `.claude/skills/skill-team-implement/SKILL.md` - Modified with 3 insertions
- `.claude/skills/skill-implementer/SKILL.md` - Modified with 2 insertions
- `.claude/agents/general-implementation-agent.md` - Modified with 1 insertion
- `specs/430_fix_implement_excessive_front_loading/plans/01_front-loading-fix.md` - This plan

## Rollback/Contingency

All changes are insertions only -- no existing content is modified or removed. Rollback via `git checkout` of the 3 modified files. Since the changes are additive constraints (behavioral documentation, not code), there is no risk of breaking runtime functionality.
