# Implementation Plan: Interactive Slide Planning Workflow

- **Task**: 417 - Interactive slide planning workflow with narrative arc feedback and per-slide refinement
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/417_interactive_slide_planning_workflow/reports/01_slide-planning-analysis.md
- **Artifacts**: plans/01_slide-planning-workflow.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the 3-question design stage (D1-D3) in skill-slides with a dedicated skill-slide-planning skill that runs a 5-stage interactive workflow (theme, narrative arc, slide picker, per-slide feedback, delegation) and a new slide-planner-agent that produces slide-by-slide implementation plans. Update manifest routing so `/plan present:slides` routes to the new skill, remove Stage 3.5 and plan-workflow references from skill-slides, and register the new components in index-entries.json and manifest provides lists.

### Research Integration

Integrated findings from `reports/01_slide-planning-analysis.md`:
- Full 5-stage interactive flow design with AskUserQuestion formats (Sections 4.3-4.7)
- slide-planner-agent execution flow and plan output structure (Section 5)
- Routing changes to manifest.json and skill-slides cleanup scope (Section 6)
- Edge cases: no research report, existing design decisions, user-added slides, long talks (Section 8)
- Effort estimate: 500-700 net new lines across all components

### Roadmap Alignment

No ROADMAP.md items are directly addressed by this task. The "Agent System Quality" items in Phase 1 are tangential (agent frontmatter validation could be applied to the new agent, but that is a separate concern).

## Goals & Non-Goals

**Goals**:
- Create skill-slide-planning with 5-stage interactive Q&A flow (theme, arc, picker, detail, delegate)
- Create slide-planner-agent that produces slide-by-slide plans from design feedback and research reports
- Route `/plan present:slides` to the new skill via manifest.json
- Remove Stage 3.5 and plan-workflow routing from skill-slides
- Register new components in index-entries.json and manifest provides

**Non-Goals**:
- Modifying the research workflow (slides-research-agent is unchanged)
- Modifying the assembly workflow (pptx/slidev assembly agents are unchanged)
- Changing existing talk patterns, themes, or templates
- Implementing the actual slide generation (that remains in assembly agents)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| skill-slide-planning exceeds 400 lines, becoming hard to maintain | M | M | Follow progressive disclosure pattern; keep each stage concise with clear section boundaries |
| Removing plan routing from skill-slides breaks other present:slides workflows | H | L | Only remove Stage 3.5 and plan-specific code paths; verify research and assemble routes are untouched |
| slide-planner-agent plan format diverges from plan-format.md standard | M | L | Agent loads plan-format.md context; include standard metadata header plus slide-specific sections |
| index-entries.json merge conflicts with concurrent extension changes | L | L | Minimal additions (add agent name to existing entries + 2 new entries) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create slide-planner-agent [COMPLETED]

**Goal**: Define the slide-planner-agent that consumes design decisions and research reports to produce slide-by-slide implementation plans.

**Tasks**:
- [ ] Create `.claude/extensions/present/agents/slide-planner-agent.md` with frontmatter (`name`, `description`, `model: opus`)
- [ ] Define agent execution flow: Stage 0 (early metadata), Stage 1 (parse delegation context with design_decisions), Stage 2 (read research report, extract slide map), Stage 3 (load talk pattern and theme JSON), Stage 4 (apply design decisions -- reorder, include/exclude, merge feedback), Stage 5 (generate plan with per-slide specifications), Stage 6 (write final metadata), Stage 7 (return summary)
- [ ] Define context references: return-metadata-file.md, plan-format.md, talk-structure.md, presentation-types.md, talk pattern JSONs, theme JSONs
- [ ] Specify the plan output structure: standard metadata header, Design Decisions Summary section, Slide Production Schedule (phases: scaffold, content generation, speaker notes, verification), Per-Slide Specifications section
- [ ] Include edge case handling: no research report (warn + fall back to pattern JSON), existing design decisions, custom slides from user additions

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/agents/slide-planner-agent.md` - New file (~200-300 lines)

**Verification**:
- Agent file exists with valid frontmatter (name, description, model)
- Execution flow covers all 8 stages from research report's Section 5.5
- Plan output structure matches the template in research report Section 5.4
- Context references include talk-structure.md and presentation-types.md

---

### Phase 2: Create skill-slide-planning [COMPLETED]

**Goal**: Define the interactive skill that runs 5-stage Q&A before delegating to slide-planner-agent.

**Tasks**:
- [ ] Create `.claude/extensions/present/skills/skill-slide-planning/` directory
- [ ] Create `SKILL.md` with frontmatter (`name: skill-slide-planning`, `description`, `allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion`, `context: fork`, `agent: slide-planner-agent`)
- [ ] Implement Stage 0: Input validation and preflight (validate task_type present:slides, set status to planning, create .postflight-pending marker)
- [ ] Implement Stage 1: Theme Selection -- read research report for recommended theme, present 5-option AskUserQuestion (A-E + custom), store as design_decisions.theme
- [ ] Implement Stage 2: Narrative Arc Outline -- build numbered outline from research slide map showing position, type, one-line summary, required/optional markers; AskUserQuestion for reorder/add/remove/emphasis feedback; parse and apply changes; store as design_decisions.narrative_arc and design_decisions.arc_feedback
- [ ] Implement Stage 3: Slide Picker -- present updated slide list with 2-3 line previews; AskUserQuestion for exclude-by-number; store as design_decisions.included_slides and design_decisions.excluded_slides
- [ ] Implement Stage 4: Per-Slide Detail -- show full content mapping, speaker notes, template for each included slide; single consolidated AskUserQuestion for feedback by slide number; store as design_decisions.slide_feedback
- [ ] Implement Stage 5: Delegation -- assemble complete delegation context JSON (session_id, design_decisions, research_report_path, forcing_data, metadata_file_path) and invoke slide-planner-agent via Task tool
- [ ] Implement Postflight (Stages 6-10): parse metadata file, update status to planned, link artifacts in state.json and TODO.md, git commit, cleanup marker files, return summary
- [ ] Handle edge cases: no research report (warn user, fall back to talk pattern), existing design_decisions (ask reuse or start fresh), long talks (group by section in Stage 4)

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/skills/skill-slide-planning/SKILL.md` - New file (~300-400 lines)

**Verification**:
- Skill file exists with valid frontmatter
- All 5 interactive stages are defined with AskUserQuestion formats
- Delegation context matches schema in research report Section 4.7
- Postflight stages match skill-slides pattern (Stages 6-10)
- Edge cases from research report Section 8 are addressed

---

### Phase 3: Update manifest routing and provides [COMPLETED]

**Goal**: Route `/plan present:slides` to skill-slide-planning and register new components in manifest.json.

**Tasks**:
- [ ] Update `manifest.json` routing.plan: change `"present:slides": "skill-slides"` to `"present:slides": "skill-slide-planning"`
- [ ] Update `manifest.json` routing.plan: change `"slides": "skill-slides"` to `"slides": "skill-slide-planning"`
- [ ] Add `"slide-planner-agent.md"` to `provides.agents` array
- [ ] Add `"skill-slide-planning"` to `provides.skills` array

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Update routing.plan entries and provides lists

**Verification**:
- `jq '.routing.plan["present:slides"]' manifest.json` returns `"skill-slide-planning"`
- `jq '.routing.plan["slides"]' manifest.json` returns `"skill-slide-planning"`
- `jq '.provides.agents' manifest.json` includes `"slide-planner-agent.md"`
- `jq '.provides.skills' manifest.json` includes `"skill-slide-planning"`
- Research and implement routes remain unchanged (still point to skill-slides)

---

### Phase 4: Update index-entries.json and clean up skill-slides [COMPLETED]

**Goal**: Register slide-planner-agent in context discovery index and remove plan-workflow code from skill-slides.

**Tasks**:
- [ ] Add `"slide-planner-agent"` to the `load_when.agents` array of existing entries for: `presentation-types.md`, `talk-structure.md`, `slidev-pitfalls.md`, `talk/index.json`, theme JSON entries
- [ ] Add new index entry for talk-structure.md with `load_when.agents: ["slide-planner-agent"]` (or merge into existing entry if agents array already exists -- which it does, so just append)
- [ ] Add new index entry for presentation-types.md with `load_when.agents: ["slide-planner-agent"]` (same: append to existing agents array)
- [ ] In `skill-slides/SKILL.md`: remove Stage 3.5 (Design Questions D1-D3, approximately lines 175-273)
- [ ] In `skill-slides/SKILL.md`: remove `/plan` from trigger conditions
- [ ] In `skill-slides/SKILL.md`: remove `plan` case from workflow_type routing table
- [ ] In `skill-slides/SKILL.md`: remove `planner-agent` from header comment subagent list
- [ ] In `skill-slides/SKILL.md`: remove plan-specific code paths from preflight status (Stage 2), delegation (Stage 4), postflight (Stage 7), and commit (Stage 9)

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - Add slide-planner-agent to existing load_when.agents arrays
- `.claude/extensions/present/skills/skill-slides/SKILL.md` - Remove Stage 3.5 and plan workflow references (~100 lines removed)

**Verification**:
- `jq '.entries[] | select(.path == "project/present/patterns/talk-structure.md") | .load_when.agents' index-entries.json` includes `"slide-planner-agent"`
- `jq '.entries[] | select(.path == "project/present/domain/presentation-types.md") | .load_when.agents' index-entries.json` includes `"slide-planner-agent"`
- skill-slides/SKILL.md contains no references to "Stage 3.5", "D1", "D2", "D3", or "design question"
- skill-slides/SKILL.md trigger conditions do not mention `/plan`
- skill-slides/SKILL.md workflow routing table has no `plan` entry

---

### Phase 5: End-to-end validation [COMPLETED]

**Goal**: Verify the complete routing chain works and all components are internally consistent.

**Tasks**:
- [ ] Verify routing chain: manifest plan route for present:slides points to skill-slide-planning
- [ ] Verify skill-slide-planning references slide-planner-agent in its agent field and delegation
- [ ] Verify slide-planner-agent context references match entries in index-entries.json
- [ ] Verify manifest provides lists include both new components
- [ ] Verify skill-slides no longer contains plan workflow code but retains research and assemble workflows
- [ ] Verify no broken cross-references between modified files
- [ ] Read each new/modified file to confirm internal consistency

**Timing**: 15 minutes

**Depends on**: 4

**Files to modify**:
- None (read-only verification)

**Verification**:
- All verification checks from Phases 1-4 pass
- No orphaned references to old routing (skill-slides for plan)
- New components are discoverable via manifest provides and index-entries.json

## Testing & Validation

- [ ] manifest.json routes `/plan present:slides` to `skill-slide-planning`
- [ ] manifest.json routes `/plan slides` to `skill-slide-planning`
- [ ] manifest.json research and implement routes for present:slides remain unchanged
- [ ] skill-slide-planning SKILL.md has valid frontmatter with agent: slide-planner-agent
- [ ] skill-slide-planning defines all 5 interactive stages with AskUserQuestion
- [ ] slide-planner-agent has valid frontmatter with model: opus
- [ ] slide-planner-agent execution flow covers stages 0-7
- [ ] index-entries.json includes slide-planner-agent in talk-related entries
- [ ] skill-slides SKILL.md has no Stage 3.5 or plan workflow references
- [ ] No broken cross-references across all modified files

## Artifacts & Outputs

- `.claude/extensions/present/agents/slide-planner-agent.md` - New agent definition
- `.claude/extensions/present/skills/skill-slide-planning/SKILL.md` - New skill definition
- `.claude/extensions/present/manifest.json` - Updated routing and provides
- `.claude/extensions/present/index-entries.json` - Updated agent load_when entries
- `.claude/extensions/present/skills/skill-slides/SKILL.md` - Cleaned up (Stage 3.5 removed)

## Rollback/Contingency

- Revert manifest.json routing changes to restore skill-slides as plan handler
- Keep skill-slides Stage 3.5 removal as a separate commit so it can be reverted independently
- New files (skill-slide-planning, slide-planner-agent) can be deleted without affecting existing functionality
- If partial implementation: manifest routing is the switch -- only flip it after both new components are verified
