# Implementation Plan: Update skill-slides for multi-agent dispatch and plan workflow

- **Task**: 405 - Update skill-slides for multi-agent dispatch and plan workflow
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: Task 403 (completed -- three specialized agents exist)
- **Research Inputs**: specs/405_update_skill_slides_multi_agent_dispatch/reports/01_skill-slides-research.md
- **Artifacts**: plans/01_skill-slides-plan.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Rewrite `.claude/extensions/present/skills/skill-slides/SKILL.md` to transform the skill from a 2-workflow/1-agent model into a 3-workflow/4-agent dispatch model. The 12 discrete changes from DIFF.md section 3.1 add a `plan` workflow type with D1-D3 design questions (including new UCSF Institutional theme), multi-agent dispatch routing to slides-research-agent, planner-agent, pptx-assembly-agent, or slidev-assembly-agent, and plan postflight status mapping. All target agents already exist from task 403. The scope is a single file edit.

### Research Integration

The research report confirmed all 12 changes map cleanly to the existing file structure. Key findings integrated:
- All four target agents are available and ready (task 403 completed)
- The `ucsf-institutional.json` theme file exists (task 408)
- Stage 3.5 (~120 lines) is the largest new section
- Manifest routing already handles `/plan` -> `skill-slides`
- Changes are additive, not restructuring

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It is infrastructure work for the present extension's multi-agent dispatch capability.

## Goals & Non-Goals

**Goals**:
- Add `plan` workflow type with preflight/postflight status mapping
- Add Stage 3.5 with D1-D3 interactive design questions (including theme E: UCSF Institutional)
- Replace single-agent delegation with conditional multi-agent dispatch table
- Parameterize Stage 5 to use resolved `{target_agent}` instead of hardcoded `slides-agent`
- Preserve backward compatibility for existing `slides_research` and `assemble` workflows

**Non-Goals**:
- Modifying the `slides.md` command file (separate task scope)
- Changing manifest.json routing (already configured)
- Creating or modifying agent files (already exist from task 403)
- Modifying state.json or TODO.md directly

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage 3.5 design questions reference research report that may not exist | M | M | Include guard that skips D2 (message ordering) if no report found, provide sensible defaults |
| Existing `--design` workflow in slides.md may conflict with new plan workflow | L | L | Plan workflow is additive; `--design` note is replaced, not removed from command |
| Large insertion (~120 lines for Stage 3.5) may introduce formatting inconsistencies | L | M | Follow existing stage formatting patterns exactly; verify with read-back |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Frontmatter, intro, triggers, and routing table [COMPLETED]

**Goal**: Apply DIFF changes 1-7 -- the lightweight metadata and structural updates that establish the 3-workflow model.

**Tasks**:
- [ ] Change 1: Add "design-aware planning" to frontmatter description
- [ ] Change 2: Replace context/tools comments with subagent dispatch table listing all four agents
- [ ] Change 3: Rewrite intro text from "delegates to slides-agent" to listing three subagents with bullet descriptions
- [ ] Change 4: Add `/plan` trigger condition bullet for present task with task_type "slides"
- [ ] Change 5: Add `plan` row to Workflow Type Routing table (preflight: planning, success: planned, markers: [PLANNING] -> [PLANNED])
- [ ] Change 6: Replace `--design` routing note with plan workflow note explaining D1-D3 design questions and theme fallback chain (design_decisions -> research report "Recommended Theme" -> default `academic-clean`)
- [ ] Change 7: Add `plan` to workflow_type enum in Input Parameters section

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/skills/skill-slides/SKILL.md` - Lines 1-65 (frontmatter through input parameters)

**Verification**:
- Frontmatter description includes "design-aware planning"
- Comments block lists all four agents with workflow_type conditions
- Trigger conditions include `/plan` bullet
- Routing table has 3 rows (slides_research, plan, assemble)
- Input Parameters lists three workflow_type values

---

### Phase 2: Stage 3 preflight case and new Stage 3.5 (Design Questions) [COMPLETED]

**Goal**: Apply DIFF changes 8-9 -- add the `plan)` preflight case and the entire new Stage 3.5 Design Questions section (~120 lines).

**Tasks**:
- [ ] Change 8: Add `plan)` case to Stage 2 preflight switch setting `preflight_status="planning"` and `preflight_marker="[PLANNING]"`
- [ ] Change 9: Create new Stage 3.5 (Design Questions) section after Stage 3, containing:
  - Guard clause: only runs when `workflow_type == "plan"`
  - Check for existing `design_decisions` in task metadata; offer reuse via AskUserQuestion or reconfigure
  - Validate existing design_decisions schema (theme, message_order, section_emphasis fields)
  - Read research report to extract key messages (with guard if report missing)
  - D1: Visual Theme question with options A-E (A: Academic Clean, B: Clinical Teal, C: Conference Bold, D: Minimal Dark, E: UCSF Institutional -- Navy/blue, Garamond headings)
  - D2: Key Message Ordering (confirm or reorder extracted messages; skip if no report)
  - D3: Section Emphasis (multi-select: methods, results, background, clinical implications, future directions)
  - Store `design_decisions` object (theme, message_order, section_emphasis, confirmed_at) in state.json task metadata via jq

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/skills/skill-slides/SKILL.md` - Stage 2 switch block (~line 115-124) and new section after Stage 3 (~line 158)

**Verification**:
- Stage 2 preflight has three cases: slides_research, plan, assemble
- Stage 3.5 heading exists with "Design Questions" title
- D1 has five theme options (A-E), with E being UCSF Institutional
- D2 includes guard for missing research report
- D3 uses multi-select pattern
- design_decisions storage uses jq with Issue #1132 safe patterns
- Reuse check for existing design_decisions is present

---

### Phase 3: Multi-agent dispatch (Stages 4-5) and postflight updates (Stages 6-9) [NOT STARTED]

**Goal**: Apply DIFF changes 10-12 -- add agent resolution logic, parameterize subagent invocation, and add plan postflight mappings.

**Tasks**:
- [ ] Change 10: Add agent resolution logic to Stage 4 (Prepare Delegation Context):
  - `slides_research` -> `slides-research-agent`
  - `plan` -> `planner-agent`
  - `assemble` + `pptx` -> `pptx-assembly-agent`
  - `assemble` + other -> `slidev-assembly-agent`
  - Update delegation path to include `{target_agent}` as final element
  - Update delegation context JSON to show parameterized agent
- [ ] Change 11: Update Stage 5 (Invoke Subagent) from hardcoded `slides-agent` to `{target_agent}`, add routing table showing all four dispatch combinations
- [ ] Change 12: Add plan rows to Stage 7 postflight status mapping table (planned/planning for success/partial) and Stage 9 git commit case (`plan)` with action "create implementation plan")
- [ ] Read back the complete file to verify all 12 changes are correctly applied and formatting is consistent

**Timing**: 25 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/skills/skill-slides/SKILL.md` - Stages 4-9 (~lines 162-261)

**Verification**:
- Stage 4 contains agent resolution switch/case with all four routes
- Stage 5 uses `{target_agent}` variable, not hardcoded agent name
- Stage 7 postflight table includes plan rows (planned/planning)
- Stage 9 git commit has `plan)` case
- Full file read-back confirms structural integrity and consistent formatting
- No references to `slides-agent` remain (replaced by parameterized dispatch)

## Testing & Validation

- [ ] Read complete SKILL.md after all edits and verify no broken markdown
- [ ] Confirm frontmatter YAML is valid (name, description, allowed-tools present)
- [ ] Verify all 12 DIFF.md section 3.1 changes are accounted for
- [ ] Confirm no references to old `slides-agent` remain in the file
- [ ] Verify Stage 3.5 D1 includes all five theme options (A-E)
- [ ] Verify routing table has exactly 3 rows (slides_research, plan, assemble)
- [ ] Verify agent dispatch covers all four (workflow_type, output_format) combinations

## Artifacts & Outputs

- Modified file: `.claude/extensions/present/skills/skill-slides/SKILL.md` (~450 lines, up from 337)
- This plan: `specs/405_update_skill_slides_multi_agent_dispatch/plans/01_skill-slides-plan.md`

## Rollback/Contingency

The implementation modifies a single file. If changes must be reverted:
```bash
git checkout HEAD -- .claude/extensions/present/skills/skill-slides/SKILL.md
```
Since all changes are in one file and the git history preserves the original, rollback is a single checkout command.
