# Implementation Plan: Create /timeline Command for Present Extension

- **Task**: 388 - Create /timeline command for present extension
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None (sibling tasks 387, 389, 390 are independent; task 391 handles manifest integration separately)
- **Research Inputs**: specs/388_create_timeline_command_present/reports/01_timeline-command-research.md
- **Artifacts**: plans/01_timeline-command-plan.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: markdown

## Overview

This plan creates the /timeline command for the present extension, adapting the founder /project command's WBS/PERT/Gantt capabilities for medical research project management. The command follows the present extension's established command/skill/agent pattern (modeled after /grant) with a simpler initial scope: task creation mode plus a single research delegation mode (PLAN equivalent). TRACK, REPORT, and REVIEW modes are deferred to future tasks. The deliverables are 7 files: command, skill, agent, and 4 context files (domain knowledge, patterns, markdown template, Typst template).

### Research Integration

- Integrated report: `reports/01_timeline-command-research.md` (research round 1)
- Key findings: founder /project architecture fully analyzed; present extension patterns (grant.md, skill-grant, grant-agent) provide consistent templates; medical research domain requires specific aims scheduling, regulatory milestones (IRB, IACUC, DSMB), reporting periods, NCEs, and effort in calendar months

## Goals & Non-Goals

- **Goals**:
  - Create a fully functional /timeline command following present extension conventions
  - Adapt WBS/PERT/Gantt methodology for medical research project timelines
  - Support task creation mode and research/PLAN mode
  - Include domain context for regulatory milestones, reporting periods, and specific aims
  - Create self-contained Typst template (no cross-extension imports from founder)
  - Use "timeline" as the dedicated language identifier for routing

- **Non-Goals**:
  - TRACK, REPORT, REVIEW modes (deferred to future tasks)
  - Manifest.json updates (handled by task 391)
  - index-entries.json or EXTENSION.md updates (handled by task 391)
  - Multi-PI coordination features (future enhancement)
  - Integration with /grant timelines (future enhancement)

## Risks & Mitigations

- **Risk**: Typst template complexity -- research-timeline.typ is large with many components. **Mitigation**: Adapt core components (Gantt, PERT table, summary) first; defer specialized visualizations (recruitment tracker, regulatory timeline) to template body with placeholder implementations.
- **Risk**: Forcing question design may not fit all grant mechanisms. **Mitigation**: Make regulatory and reporting questions optional; core questions (aims, timeline, personnel) are universal.
- **Risk**: Agent file size -- the project-agent.md is very large (~500 lines). **Mitigation**: Focus on PLAN mode only; omit REVIEW/TRACK/REPORT branches to keep agent manageable.
- **Risk**: Language routing "timeline" may conflict if present extension loads other commands. **Mitigation**: Dedicated language avoids conflicts; task 391 will validate routing entries.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Domain Context and Templates [COMPLETED]

- **Goal:** Create the foundational domain knowledge, patterns, and template files that the agent and skill will reference.
- **Tasks:**
  - [ ] Create `research-timelines.md` domain context file at `.claude/extensions/present/context/project/present/domain/research-timelines.md`
    - Document specific aims as WBS phases, regulatory milestone categories (IRB, IACUC, DSMB, IND/IDE), reporting periods (RPPR, NSF annual), NCE mechanics, effort allocation in calendar months, budget period alignment
    - Adapt structure from `founder/context/project/founder/domain/timeline-frameworks.md` (WBS, PERT, CPM sections)
    - Add research-specific sections: regulatory milestones taxonomy, reporting schedule patterns, grant mechanism timeline patterns (R01 5-year, R21 2-year, K-series, etc.)
  - [ ] Create `timeline-patterns.md` patterns file at `.claude/extensions/present/context/project/present/patterns/timeline-patterns.md`
    - Adapt from `founder/context/project/founder/patterns/project-planning.md`
    - Include: research timeline validation rules, PERT calculation formulas for research tasks, milestone lead time estimates (IRB ~2-4 months, IACUC ~1-3 months), effort conversion rules
  - [ ] Create `timeline-template.md` markdown report template at `.claude/extensions/present/context/project/present/templates/timeline-template.md`
    - Define the structured output format for the timeline-agent research report
    - Sections: Project Overview, Specific Aims WBS, Regulatory Milestones, PERT Estimates Table, Resource Allocation (calendar months), Critical Path, Reporting Schedule, Risk Register, Raw JSON Data Block
  - [ ] Create `research-timeline.typ` Typst template at `.claude/extensions/present/context/project/present/templates/typst/research-timeline.typ`
    - Adapt from `founder/context/project/founder/templates/typst/project-timeline.typ`
    - Reimplement core components: `aims-gantt()`, `pert-table()`, `effort-allocation()`, `project-summary()`
    - Add research-specific components: `regulatory-timeline()`, `reporting-schedule()`
    - Self-contained (no imports from founder extension)
- **Timing:** 1.5 hours
- **Depends on:** none

### Phase 2: Timeline Agent [COMPLETED]

- **Goal:** Create the timeline-agent that conducts interactive research through forcing questions and produces structured timeline reports.
- **Tasks:**
  - [ ] Create `timeline-agent.md` at `.claude/extensions/present/agents/timeline-agent.md`
  - [ ] Define agent metadata: name, description, purpose, invoked-by (skill-timeline), return format
  - [ ] Define allowed tools: AskUserQuestion, Read, Write, Edit, Glob
  - [ ] Define context references pointing to Phase 1 domain/patterns files
  - [ ] Implement Stage 0: Early metadata initialization (same pattern as project-agent)
  - [ ] Implement Stage 1: Parse delegation context (task_context, metadata_file_path, forcing_data if pre-gathered)
  - [ ] Implement Stage 2: Research-adapted forcing questions (Q1-Q3: grant mechanism + project period + completion criteria; stakeholders: PI, co-Is, Program Officer)
  - [ ] Implement Stage 3: Specific aims elicitation (Q4-Q6: aims with sub-aim structure, cross-aim dependencies, deliverables per aim)
  - [ ] Implement Stage 4: Task decomposition (Q7-Q8: experiments/milestones per aim, regulatory requirements checklist)
  - [ ] Implement Stage 5: PERT estimation -- three-point estimates per milestone, using timeline-frameworks methodology
  - [ ] Implement Stage 6: Resource allocation -- key personnel with effort in calendar months by budget year
  - [ ] Implement Stage 7: Schedule calculation -- critical path, regulatory prerequisite chains, reporting deadlines
  - [ ] Implement Stage 8: Report generation -- produce structured report using timeline-template.md format, include raw JSON data block
  - [ ] Implement Stage 9: Write metadata file with artifact path and summary
  - [ ] Include pre-gathered forcing_data support (skip questions if data available in task metadata)
  - [ ] Include optional questions: regulatory requirements (IRB/IACUC needed?), reporting schedule, recruitment targets, data sharing timeline
- **Timing:** 1.5 hours
- **Depends on:** 1

### Phase 3: Skill (skill-timeline) [COMPLETED]

- **Goal:** Create the thin wrapper skill that routes timeline requests to the timeline-agent subagent.
- **Tasks:**
  - [ ] Create `SKILL.md` at `.claude/extensions/present/skills/skill-timeline/SKILL.md`
  - [ ] Define frontmatter: name, description, allowed-tools (Task, Bash, Edit, Read, Write)
  - [ ] Follow skill-grant pattern: thin wrapper with skill-internal postflight
  - [ ] Implement workflow type routing table: `timeline_research` (researching -> researched), `timeline_plan` (planning -> planned)
  - [ ] Implement Stage 1: Input validation (task_number, workflow_type, session_id)
  - [ ] Implement Stage 2: Preflight status update via `update-task-status.sh`
  - [ ] Implement Stage 3: Postflight marker creation
  - [ ] Implement Stage 3a: Artifact number calculation (same pattern as skill-planner)
  - [ ] Implement Stage 4: Delegation context preparation for timeline-agent
  - [ ] Implement Stage 5: Task tool invocation of timeline-agent
  - [ ] Implement Stages 6-10: Standard postflight (parse metadata, update status, link artifacts, git commit, cleanup)
  - [ ] Implement Stage 11: Return brief text summary
- **Timing:** 0.5 hours
- **Depends on:** 2

### Phase 4: Command (timeline.md) [COMPLETED]

- **Goal:** Create the /timeline command definition following the /grant hybrid pattern.
- **Tasks:**
  - [ ] Create `timeline.md` at `.claude/extensions/present/commands/timeline.md`
  - [ ] Define frontmatter: description, allowed-tools (Skill, Bash, Read, Edit, AskUserQuestion), argument-hint
  - [ ] Implement mode detection: description string (task creation) vs task number (research delegation)
  - [ ] Implement task creation mode:
    - Read next_project_number from state.json
    - Parse and improve description
    - Set language="timeline"
    - Create task entry in state.json and TODO.md
    - Git commit
  - [ ] Implement research delegation mode:
    - Validate task exists with language="timeline"
    - Determine workflow_type based on current status
    - Route to skill-timeline via Skill tool
  - [ ] Include pre-task forcing questions (Stage 0) for PLAN mode:
    - Mode selection (PLAN only for now)
    - Essential forcing questions adapted for research (grant mechanism, project period, specific aims overview)
    - Store responses in task metadata as forcing_data
  - [ ] Document syntax: `/timeline "description"`, `/timeline N`
  - [ ] Note that manifest integration is handled separately by task 391
- **Timing:** 0.5 hours
- **Depends on:** 3

## Testing & Validation

- [ ] Verify all 7 files exist at correct paths after implementation
- [ ] Verify command frontmatter has required fields (description, allowed-tools, argument-hint)
- [ ] Verify skill frontmatter has required fields (name, description, allowed-tools)
- [ ] Verify agent has required sections (metadata, allowed tools, context references, execution flow)
- [ ] Verify domain context covers: specific aims, regulatory milestones, reporting periods, NCEs, effort allocation
- [ ] Verify Typst template compiles independently (no cross-extension imports)
- [ ] Verify forcing questions are adapted for research context (not copied verbatim from founder)
- [ ] Confirm no modifications to manifest.json, index-entries.json, or EXTENSION.md (task 391 scope)

## Artifacts & Outputs

- plans/01_timeline-command-plan.md (this file)
- summaries/01_timeline-command-summary.md (after implementation)

### Implementation Deliverables

| File | Purpose |
|------|---------|
| `.claude/extensions/present/commands/timeline.md` | /timeline command definition |
| `.claude/extensions/present/skills/skill-timeline/SKILL.md` | Thin wrapper skill |
| `.claude/extensions/present/agents/timeline-agent.md` | Research agent with forcing questions |
| `.claude/extensions/present/context/project/present/domain/research-timelines.md` | Domain knowledge |
| `.claude/extensions/present/context/project/present/patterns/timeline-patterns.md` | Validation rules and patterns |
| `.claude/extensions/present/context/project/present/templates/timeline-template.md` | Report structure template |
| `.claude/extensions/present/context/project/present/templates/typst/research-timeline.typ` | Typst template |

## Rollback/Contingency

- All files are new additions; rollback is simply deleting the 7 created files
- No existing files are modified (manifest update is task 391)
- If Typst template proves too complex, implement a minimal version with Gantt chart only and defer other visualizations
- If agent forcing questions are too numerous, reduce to 5 core questions and make the rest optional
