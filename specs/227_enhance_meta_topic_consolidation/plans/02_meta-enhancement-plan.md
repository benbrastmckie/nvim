# Implementation Plan: Enhance /meta with Topic Consolidation and Embedded Research

- **Task**: 227 - Enhance /meta with topic consolidation and embedded research
- **Status**: [COMPLETED]
- **Effort**: 3-5 hours
- **Dependencies**: None
- **Research Inputs**: [01_meta-enhancement-patterns.md](../reports/01_meta-enhancement-patterns.md)
- **Artifacts**: plans/02_meta-enhancement-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

This plan enhances the /meta command to actively consolidate related user-provided tasks into minimal topic-based groupings and to generate lightweight research artifacts during task creation so tasks start in RESEARCHED status. The implementation adds Stage 3.5 (TopicClustering) and Stage 4.5 (ResearchArtifactGeneration) to the meta-builder-agent interview workflow, integrates the /fix-it-style AskUserQuestion picker pattern for topic selection, and updates skill-meta postflight to handle the new RESEARCHED status.

### Research Integration

Key findings from research report 01_meta-enhancement-patterns.md:
- Current Stage 3 is passive (asks users to break down tasks) rather than proactive (analyzing and suggesting groupings)
- /fix-it provides reference pattern for topic clustering using key term extraction and similarity matching
- Tasks should use status "researched" (not "not_started") when research artifacts are generated
- Grouping confirmation should offer three options: accept suggested groups, keep separate, customize groupings

## Goals & Non-Goals

**Goals**:
- Add automatic topic clustering algorithm to analyze user-provided task breakdowns
- Present AskUserQuestion picker for grouping confirmation (accept/separate/customize)
- Generate lightweight research reports during task creation from interview context
- Have created tasks start in RESEARCHED status with linked research artifacts
- Update skill-meta postflight to include research artifacts in return
- Document "minimize tasks" principle in multi-task-creation-standard.md

**Non-Goals**:
- Deep web research during task creation (users can run /research N for deeper investigation)
- Changing the existing interview stages 0-2 (purpose/scope gathering)
- Modifying dependency handling or topological sorting (already working correctly)
- Changing analyze mode behavior (read-only, no task creation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Topic clustering may not match user intent | Medium | Medium | Present as suggestion with user confirmation; include "Customize" option |
| Auto-generated research may be insufficient | Low | Medium | Label as auto-generated; include note about running /research N for deeper investigation |
| Interview flow becomes too long | Medium | Low | Skip Stage 3.5 for single tasks or when no shared indicators found |
| Research artifact generation delays task creation | Low | Low | Generate lightweight reports from existing interview data, no external calls |

## Implementation Phases

### Phase 1: Add Topic Clustering Algorithm to meta-builder-agent [COMPLETED]

**Goal**: Implement Stage 3.5 (AnalyzeTopics) with clustering logic following /fix-it pattern

**Tasks**:
- [ ] Add Stage 3.5 section after Interview Stage 3 in meta-builder-agent.md
- [ ] Implement topic indicator extraction (key terms, component type, affected area, action type)
- [ ] Implement clustering algorithm matching /fix-it pattern (2+ key terms OR same component_type AND affected_area)
- [ ] Add topic label generation from common terms
- [ ] Add skip condition: only trigger when 2+ tasks provided and shared indicators exist

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Add Stage 3.5 section (after line ~380, before Stage 4)

**Verification**:
- Stage 3.5 appears in agent with complete algorithm specification
- Skip conditions are documented
- Clustering algorithm matches /fix-it reference implementation

---

### Phase 2: Add Topic Consolidation Picker [COMPLETED]

**Goal**: Implement AskUserQuestion picker for grouping confirmation with three options

**Tasks**:
- [ ] Add AskUserQuestion JSON for topic consolidation (3 options: accept/separate/customize)
- [ ] Add tier-2 multiSelect picker for "Customize" option to let user specify which items to combine
- [ ] Add response handling logic for each option
- [ ] Update task_list modification to apply user-selected groupings

**Timing**: 1 hour

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Add picker in Stage 3.5, add response handling

**Verification**:
- AskUserQuestion follows exact pattern from multi-task-creation-standard.md
- All three options produce correct task_list modifications
- Customize flow correctly presents multiSelect for item selection

---

### Phase 3: Add Research Artifact Generation [COMPLETED]

**Goal**: Implement Stage 4.5 (GenerateResearchArtifacts) to create lightweight research reports

**Tasks**:
- [ ] Add Stage 4.5 section after Interview Stage 4 in meta-builder-agent.md
- [ ] Define research report template using interview context (purpose, scope, affected components, requirements)
- [ ] Implement task directory creation with reports/ subdirectory
- [ ] Implement report file writing (01_meta-research.md format)
- [ ] Add condition: execute after Stage 5 confirmation but before Stage 6 state updates

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Add Stage 4.5 section (after Stage 4, before Stage 6)

**Verification**:
- Stage 4.5 creates reports following artifact-formats.md naming convention
- Research report template captures all interview context
- Report includes note about running /research N for deeper investigation

---

### Phase 4: Update State Entry for RESEARCHED Status [COMPLETED]

**Goal**: Modify Stage 6 (CreateTasks) to set status="researched" and link research artifacts

**Tasks**:
- [ ] Update state.json entry template to use status="researched" instead of "not_started"
- [ ] Add artifacts array with research report entry
- [ ] Update TODO.md entry format to include Research link
- [ ] Ensure artifact summary field is populated

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Modify Stage 6 state.json and TODO.md templates

**Verification**:
- state.json entries have status="researched"
- artifacts array includes research report with path and summary
- TODO.md entries have - **Research**: link

---

### Phase 5: Update skill-meta Postflight and Return Format [COMPLETED]

**Goal**: Update skill-meta to handle RESEARCHED status and include research artifacts in return

**Tasks**:
- [ ] Update expected return format examples to include research artifacts
- [ ] Update return validation to accept status="researched" as valid success state
- [ ] Document that tasks start in RESEARCHED status

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/skills/skill-meta/SKILL.md` - Update return format examples and documentation

**Verification**:
- Return format examples show research artifacts
- RESEARCHED status documented as new default for created tasks

---

### Phase 6: Update Multi-Task Creation Standard Documentation [COMPLETED]

**Goal**: Document "minimize tasks" principle and topic consolidation enhancement

**Tasks**:
- [ ] Add "Task Minimization Principle" section explaining aggressive grouping goal
- [ ] Update /meta compliance row to note "automatic topic clustering" enhancement
- [ ] Add reference to topic clustering algorithm in Grouping section
- [ ] Update current compliance status table to reflect enhanced /meta capabilities

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/docs/reference/standards/multi-task-creation-standard.md` - Add principle, update compliance status

**Verification**:
- Task minimization principle clearly documented
- /meta row updated with new capabilities
- Grouping section references automatic clustering

## Testing & Validation

- [ ] Test Stage 3.5 skip condition: single task provided -> Stage 3.5 skipped
- [ ] Test Stage 3.5 skip condition: no shared indicators -> Stage 3.5 skipped
- [ ] Test clustering: 3 related tasks -> suggested grouping presented
- [ ] Test picker: "Accept suggested groups" -> tasks consolidated as suggested
- [ ] Test picker: "Keep as separate" -> tasks created individually
- [ ] Test picker: "Customize" -> multiSelect presented, user selection applied
- [ ] Test research generation: task directory created with reports/ subdirectory
- [ ] Test research generation: 01_meta-research.md contains interview context
- [ ] Test state.json: entries have status="researched" and artifacts array
- [ ] Test TODO.md: entries have Research link to generated report
- [ ] Test skill return: includes research artifacts in artifacts array

## Artifacts & Outputs

- `plans/02_meta-enhancement-plan.md` (this file)
- Modified: `.claude/agents/meta-builder-agent.md` (Stages 3.5, 4.5, updated Stage 6)
- Modified: `.claude/skills/skill-meta/SKILL.md` (return format)
- Modified: `.claude/docs/reference/standards/multi-task-creation-standard.md` (documentation)
- `summaries/03_meta-enhancement-summary.md` (after implementation)

## Rollback/Contingency

If the topic clustering proves problematic:
1. Stage 3.5 can be disabled by changing skip condition to always true
2. Stage 4.5 (research generation) is independent and can be kept even if clustering is removed
3. Status can revert to "not_started" by changing single line in Stage 6
4. All changes are localized to meta-builder-agent.md and skill-meta/SKILL.md
