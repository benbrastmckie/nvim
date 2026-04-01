# Implementation Plan: Fix /plan Interactive Questions for founder:deck

- **Task**: 348 - Fix /plan command not showing interactive questions for founder:deck tasks
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: Task 347 (compound key routing - completed)
- **Research Inputs**: specs/348_fix_plan_interactive_questions_founder_deck/reports/02_interactive-picker-pattern.md
- **Artifacts**: plans/02_interactive-picker-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `deck-planner-agent` defines 4 interactive AskUserQuestion steps (pattern, theme, content, ordering), but these never reach the user because the spawning `skill-deck-plan` lacks AskUserQuestion in its allowed-tools and agents invoked via the Task tool cannot reliably surface interactive pickers. The fix moves all interactive question logic from the agent into the skill (matching the established `skill-fix-it` pattern), passes user selections as structured input to the agent, and strips the agent of its question-asking responsibilities.

### Research Integration

The round-2 research report confirmed the root cause is architectural (not routing), identified the exact allowed-tools gap, documented all 4 question schemas from the agent, and provided the `skill-fix-it` reference pattern with AskUserQuestion JSON examples.

## Goals & Non-Goals

**Goals**:
- Interactive AskUserQuestion pickers for pattern, theme, content, and ordering appear in the user's terminal when running `/plan` on a founder:deck task
- User selections are passed as structured data to `deck-planner-agent` for plan generation
- The `--quick` flag bypass continues to work (skipping pattern and theme questions)
- Library initialization happens in the skill so question options can be built from `index.json`

**Non-Goals**:
- Changing the plan output format or Deck Configuration section structure
- Modifying the deck library content or index schema
- Adding new question types beyond the existing 4
- Changing the agent's plan generation logic (Stages 7-10)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Skill becomes significantly longer and harder to maintain | M | M | Follow skill-fix-it structure closely; keep question logic in clearly labeled stages |
| Agent invoked by other paths breaks due to missing selections | H | L | Grep confirms deck-planner-agent is only invoked by skill-deck-plan; add fallback in agent for missing selections |
| Content selection question is very long for 10+ slide positions | M | M | Use the "Select all" pattern from skill-fix-it for large option lists |
| AskUserQuestion tool not available in skill runtime | H | L | Frontmatter allowed-tools is the standard mechanism; skill-fix-it proves it works |

## Implementation Phases

### Phase 1: Update skill-deck-plan with AskUserQuestion stages [COMPLETED]

**Goal**: Move interactive question logic from the agent into the skill, add AskUserQuestion to allowed-tools, and pass user selections to the agent.

**Tasks**:
- [ ] Add `AskUserQuestion` to `allowed-tools` in SKILL.md frontmatter (line 4): change from `Task, Bash, Edit, Read, Write` to `Task, Bash, Edit, Read, Write, AskUserQuestion`
- [ ] Add `Glob` to allowed-tools (needed for library queries)
- [ ] Insert new Stage 4.1: Library Initialization -- move library init logic from agent Stage 1.5 into the skill (check for `.context/deck/index.json`, copy from extension seed if missing)
- [ ] Insert new Stage 4.2: Load Research Report -- read research report to extract slide content analysis for building content question options
- [ ] Insert new Stage 4.3: Interactive Questions -- implement 4 sequential AskUserQuestion calls:
  - Pattern selection (single select, options from `index.json` category=pattern)
  - Theme selection (single select, options from `index.json` category=theme)
  - Content selection (multi select per slide position, options from library + NEW marker)
  - Slide ordering (single select, options from selected pattern's ordering strategies)
- [ ] Insert new Stage 4.4: Prepare Enhanced Delegation Context -- bundle `user_selections` object with pattern, theme, content_manifest, main_slides, appendix_slides, ordering
- [ ] Update Stage 5 (Invoke Agent) to include `user_selections` in the agent prompt
- [ ] Add `--quick` flag handling: if `--quick`, skip pattern and theme questions (use YC 10-slide + dark-blue defaults), still execute content and ordering questions
- [ ] Update the "When NOT to trigger" section to remove the `--quick` exclusion (quick mode now handled inside the skill)
- [ ] Update Return Format section to include pattern/theme/ordering from user selections

**Files to modify**:
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` - Add AskUserQuestion stages, update frontmatter

**Timing**: 1 hour

**Verification**:
- Frontmatter contains `AskUserQuestion` in allowed-tools
- Stages 4.1-4.4 are present between existing Stage 4 and Stage 5
- Each AskUserQuestion call uses proper JSON format with question, header, multiSelect, and options fields
- `--quick` flag bypass is documented
- User selections are included in the delegation context passed to Stage 5

---

### Phase 2: Update deck-planner-agent to receive selections as input [COMPLETED]

**Goal**: Remove interactive question logic from the agent and replace it with input parsing of pre-gathered user selections.

**Tasks**:
- [ ] Update Overview section to state the agent receives pre-selected choices from the skill rather than asking questions
- [ ] Remove `AskUserQuestion` from Allowed Tools section (line 24-25)
- [ ] Remove Stage 1.5 (Library Initialization) -- this now happens in the skill
- [ ] Replace Stages 3-6 (interactive questions) with a single new Stage 3: Parse User Selections -- extract `user_selections` from delegation context containing pattern, theme, content_manifest, main_slides, appendix_slides, ordering
- [ ] Renumber subsequent stages (Stage 7 Plan Generation becomes Stage 4, etc.)
- [ ] Update delegation context schema in Stage 1 to include `user_selections` field
- [ ] Remove "User Abandonment" error handling case (now handled in skill)
- [ ] Remove "All Slides Deselected" error handling case (now handled in skill)
- [ ] Add "Missing User Selections" error handling case for when the skill fails to pass selections
- [ ] Update Critical Requirements to remove "Ask 4-5 AskUserQuestion interactions" and add "Parse user_selections from delegation context"

**Files to modify**:
- `.claude/extensions/founder/agents/deck-planner-agent.md` - Remove interactive stages, add selection parsing

**Timing**: 45 minutes

**Verification**:
- No `AskUserQuestion` references remain in allowed tools
- Stages 3-6 (interactive) are removed
- New Stage 3 parses `user_selections` from delegation context
- Error handling covers "Missing User Selections" case
- Stage numbering is sequential with no gaps
- Plan generation logic (former Stage 7) is unchanged

---

### Phase 3: Validation and smoke test [NOT STARTED]

**Goal**: Verify both files are internally consistent, cross-reference each other correctly, and the delegation contract is aligned.

**Tasks**:
- [ ] Verify skill's delegation context schema matches agent's expected input schema (especially `user_selections` structure)
- [ ] Verify skill's `--quick` bypass produces the same default selections the agent previously used
- [ ] Verify the agent's metadata return format still matches what the skill's Stage 6 (Parse Subagent Return) expects
- [ ] Verify no other files reference `deck-planner-agent` AskUserQuestion (grep check)
- [ ] Read both files end-to-end to confirm stage numbering, cross-references, and consistency

**Files to modify**:
- None (read-only verification), or minor fixups to either file if inconsistencies found

**Timing**: 15 minutes

**Verification**:
- Grep for `AskUserQuestion` in `deck-planner-agent.md` returns zero matches
- Grep for `user_selections` appears in both files with matching schema
- Skill delegation context matches agent input parsing
- No broken cross-references between the two files

## Testing & Validation

- [ ] `skill-deck-plan/SKILL.md` frontmatter includes `AskUserQuestion` in allowed-tools
- [ ] `deck-planner-agent.md` does NOT include `AskUserQuestion` in allowed tools
- [ ] Skill contains 4 AskUserQuestion calls with proper JSON format
- [ ] Agent contains `user_selections` parsing stage
- [ ] Delegation context schema matches between skill output and agent input
- [ ] `--quick` flag bypass documented in skill with correct defaults
- [ ] Library initialization moved from agent to skill
- [ ] Error handling updated in both files (skill handles user abandonment, agent handles missing selections)

## Artifacts & Outputs

- `plans/02_interactive-picker-fix.md` (this plan)
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` (modified)
- `.claude/extensions/founder/agents/deck-planner-agent.md` (modified)

## Rollback/Contingency

Both files are tracked in git. If implementation fails or introduces regressions:
1. `git checkout HEAD -- .claude/extensions/founder/skills/skill-deck-plan/SKILL.md .claude/extensions/founder/agents/deck-planner-agent.md`
2. Task status reverts to [PLANNED] for retry
