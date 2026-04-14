# Implementation Plan: Prevent Lead Agent Post-Delegation Takeover

- **Task**: 434 - Prevent lead agent post-delegation takeover after subagent returns
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None (task 430 fixed pre-delegation mirror problem)
- **Research Inputs**: specs/434_prevent_lead_agent_post_delegation_takeover/reports/01_post-delegation-takeover.md
- **Artifacts**: plans/01_post-delegation-takeover.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
- **Type**: meta

## Overview

After a subagent returns (with any status), the lead skill must proceed immediately to postflight operations. The observed violation is the lead agent "picking up where the subagent left off" -- reading source files, running builds, and attempting to complete work itself. This produces untracked, unvalidated changes that bypass the delegation model.

The fix adds explicit PROHIBITION blocks to all implementation skills and updates the canonical standard template. Research identified 13 files requiring edits: 2 core skills, 1 agent definition, 3 extension skills missing postflight boundaries entirely, 8 extension skills missing PROHIBITION blocks, and 2 standards/command files.

### Research Integration

- Report: `reports/01_post-delegation-takeover.md` (integrated in plan version 1)

## Goals & Non-Goals

- **Goals**:
  - Add PROHIBITION blocks to skill-implementer and skill-team-implement postflight boundaries
  - Add "partial is acceptable" guidance to general-implementation-agent
  - Add MUST NOT sections to 3 extension skills that lack them entirely
  - Add PROHIBITION blocks to 8 extension skills with existing postflight boundaries
  - Update the canonical MUST NOT template in postflight-tool-restrictions.md
  - Add future-detection note to implement.md GATE OUT
- **Non-Goals**:
  - Automated GATE OUT detection of tool-call violations (documented as future work)
  - Modifying non-implementation skills (planner, researcher, etc.)
  - Changing subagent behavior or metadata schemas

## Risks & Mitigations

- **Risk**: Adding text to already-long SKILL.md files reduces readability
  - **Mitigation**: PROHIBITION block is 4-5 lines with distinctive bold formatting for high salience
- **Risk**: Extension skills diverge in PROHIBITION language over time
  - **Mitigation**: Canonical template in postflight-tool-restrictions.md serves as single source of truth

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Core Skills and Agent -- Add PROHIBITION Blocks [COMPLETED]

- **Goal:** Add structured PROHIBITION blocks to the two core implementation skills and add partial-is-acceptable guidance to the implementation agent
- **Tasks:**
  - [ ] Replace the one-line postflight boundary in `.claude/skills/skill-implementer/SKILL.md` (line 453) with a full "MUST NOT (Postflight Boundary)" section including PROHIBITION block matching the format from research Decision 2
  - [ ] Add PROHIBITION block to `.claude/skills/skill-team-implement/SKILL.md` (before the existing numbered list at lines 648-666), including "proceed immediately to postflight" language and partial/failed status handling
  - [ ] Add to `.claude/agents/general-implementation-agent.md` Critical Requirements MUST DO list: "Return `status: partial` with `partial_progress` when work cannot be completed within timeout or after errors -- partial results are preferred over forced/incomplete completion"
- **Timing:** 20 minutes
- **Depends on:** none

### Phase 2: Extension Skills -- Add Missing Sections and PROHIBITION Blocks [COMPLETED]

- **Goal:** Add MUST NOT sections to 3 extension skills missing them entirely, and add PROHIBITION blocks to 8 extension skills with existing postflight boundaries
- **Tasks:**
  - [ ] Add full "MUST NOT (Postflight Boundary)" section with PROHIBITION block to `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md`
  - [ ] Add full "MUST NOT (Postflight Boundary)" section with PROHIBITION block to `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`
  - [ ] Add full "MUST NOT (Postflight Boundary)" section with PROHIBITION block to `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/python/skills/skill-python-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/typst/skills/skill-typst-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/latex/skills/skill-latex-implementation/SKILL.md`
  - [ ] Add PROHIBITION block to `.claude/extensions/z3/skills/skill-z3-implementation/SKILL.md`
- **Timing:** 30 minutes
- **Depends on:** 1

### Phase 3: Standards and Command Documentation [COMPLETED]

- **Goal:** Update the canonical MUST NOT template and add GATE OUT future-detection note
- **Tasks:**
  - [ ] Update `.claude/context/standards/postflight-tool-restrictions.md` MUST NOT Section Template (lines 156-179) to include the PROHIBITION block template
  - [ ] Add GATE OUT note to `.claude/commands/implement.md` (in CHECKPOINT 2 section) documenting the desired future validation: if skill return indicates source-file reads/builds were performed by the skill, log a warning
- **Timing:** 15 minutes
- **Depends on:** 1

### Phase 4: Verification and Consistency Check [COMPLETED]

- **Goal:** Verify all 13 files have consistent PROHIBITION language and no regressions
- **Tasks:**
  - [ ] Grep all implementation SKILL.md files for "PROHIBITION" to confirm presence in all 13 targets
  - [ ] Verify the PROHIBITION block text is consistent across all files (matching the canonical template)
  - [ ] Verify general-implementation-agent.md contains the partial-is-acceptable guidance
  - [ ] Confirm no unintended changes to non-implementation skills
- **Timing:** 10 minutes
- **Depends on:** 2, 3

## Testing & Validation

- [ ] Grep for `PROHIBITION` across all `.claude/skills/skill-*-implement*/SKILL.md` and `.claude/extensions/*/skills/skill-*-implement*/SKILL.md` -- expect 13 matches
- [ ] Grep for `partial_progress` in `general-implementation-agent.md` -- expect match
- [ ] Verify postflight-tool-restrictions.md template includes PROHIBITION block
- [ ] Verify implement.md GATE OUT section includes future-detection note

## Artifacts & Outputs

- plans/01_post-delegation-takeover.md (this file)
- summaries/01_post-delegation-takeover-summary.md (after implementation)

## Rollback/Contingency

- All changes are additive text insertions to existing markdown files
- `git revert` of the implementation commit cleanly removes all changes
- No code logic or configuration changes -- only documentation/instruction updates
