# Implementation Plan: Task #254

- **Task**: 254 - Update founder-implement-agent for typst output generation
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: Task #253 (completed)
- **Research Inputs**: specs/254_update_founder_implement_agent_typst/reports/01_meta-research.md
- **Artifacts**: plans/01_typst-execution-update.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update the founder-implement-agent to reliably execute typst generation phases and produce typst/PDF files as output. The agent currently has Phase 5 (Typst Document Generation) documented but needs enhancements for graceful degradation when typst is unavailable, and backward compatibility for plans that may lack the typst phase.

### Research Integration

From the research report:
- Task #253 fixed the plan agent to always include "Phase 5: Typst Document Generation"
- The implement agent needs to execute this phase reliably
- Graceful degradation required if typst is not installed
- Option B (dynamic phase addition) provides resilience for legacy plans

## Goals & Non-Goals

**Goals**:
- Ensure typst phase execution produces .typ and .pdf files in founder/ directory
- Handle graceful degradation when typst is not installed (skip with warning)
- Add backward compatibility: dynamically inject typst phase if plan lacks it
- Maintain existing functionality for all report types (market-sizing, competitive-analysis, gtm-strategy)

**Non-Goals**:
- Modifying the plan agent (already done in Task #253)
- Adding new report types
- Changing the typst template structure

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plans without typst phase fail silently | Medium | Low | Add dynamic phase detection and injection |
| typst compilation errors block task completion | High | Medium | Make Phase 5 non-blocking, mark [PARTIAL] on failure |
| Typst not installed on user system | Medium | Medium | Add availability check with helpful installation message |

## Implementation Phases

### Phase 1: Add Typst Availability Check Section [NOT STARTED]

**Goal**: Create a reusable typst availability check pattern at Stage 2 level

**Tasks**:
- [ ] Add "Stage 2.5: Detect Typst Availability" section after Stage 2
- [ ] Set `typst_available` flag based on `command -v typst` check
- [ ] Include NixOS installation hint: `nix profile install nixpkgs#typst`
- [ ] Flag used later to skip or execute Phase 5

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Add availability check section

**Verification**:
- New section exists between Stage 2 and Stage 3
- Check includes fallback installation instructions

---

### Phase 2: Add Dynamic Phase Injection Logic [NOT STARTED]

**Goal**: Add backward compatibility for plans that lack Phase 5

**Tasks**:
- [ ] Add "Stage 3.5: Ensure Typst Phase Exists" section after resume point detection
- [ ] Check if plan contains "Phase 5: Typst" heading
- [ ] If missing, document that agent should treat task as having implicit Phase 5
- [ ] Add guidance: "If plan lacks Phase 5, agent proceeds as if Phase 5 exists after Phase 4"

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Add phase injection section

**Verification**:
- Agent specification includes backward compatibility logic
- Clear guidance for handling legacy plans

---

### Phase 3: Enhance Phase 5 Execution Instructions [NOT STARTED]

**Goal**: Ensure Phase 5 produces typst files and handles errors gracefully

**Tasks**:
- [ ] Review existing Phase 5 documentation (already comprehensive)
- [ ] Add explicit guidance on checking `typst_available` flag from Stage 2.5
- [ ] Add explicit file path validation before compilation
- [ ] Clarify that Phase 5 failure does NOT block task completion
- [ ] Add guidance for marking phase [PARTIAL] vs [COMPLETED]

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Enhance Phase 5 section

**Verification**:
- Phase 5 references typst_available check
- Clear error handling documented
- Non-blocking failure behavior explicit

---

### Phase 4: Update Summary and Metadata Templates [NOT STARTED]

**Goal**: Ensure summary correctly reports typst generation status

**Tasks**:
- [ ] Update Stage 6 summary template to include typst generation status
- [ ] Update Stage 7 metadata template to include `typst_available` and `typst_skipped` fields
- [ ] Add conditional artifact entries for PDF/typ files

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Update Stage 6 and Stage 7

**Verification**:
- Summary template includes typst status
- Metadata includes typst_available boolean
- Conditional artifact listing works

---

### Phase 5: Verification and Testing [NOT STARTED]

**Goal**: Verify the updated agent specification is complete and coherent

**Tasks**:
- [ ] Re-read the full agent specification for consistency
- [ ] Verify all new sections integrate smoothly with existing flow
- [ ] Check that stage numbering is sequential (no gaps)
- [ ] Verify all placeholders are documented
- [ ] Test that the document renders correctly as markdown

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Final cleanup if needed

**Verification**:
- Document is coherent and complete
- No orphaned references
- Stage flow is logical

## Testing & Validation

- [ ] Agent specification markdown renders correctly
- [ ] All new sections have clear guidance
- [ ] Stage numbers are sequential
- [ ] Backward compatibility logic is clear
- [ ] Error handling is explicit and non-blocking
- [ ] Installation hints are platform-appropriate (NixOS)

## Artifacts & Outputs

- `.claude/extensions/founder/agents/founder-implement-agent.md` (modified)
- `specs/254_update_founder_implement_agent_typst/summaries/01_typst-execution-summary.md`

## Rollback/Contingency

If changes introduce issues:
1. Revert to previous version via git: `git checkout HEAD~1 -- .claude/extensions/founder/agents/founder-implement-agent.md`
2. The plan agent change (Task #253) remains functional independently
3. Founder workflow continues without typst enhancements
