# Implementation Plan: Task #259

- **Task**: 259 - skill_project
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: project-agent.md (completed in task 256)
- **Research Inputs**: specs/259_skill_project/reports/01_skill-project-research.md
- **Artifacts**: plans/01_skill-project-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create skill-project as a thin wrapper following the 11-stage pattern established by skill-market and other founder extension skills. The skill validates input, manages preflight/postflight status updates, delegates to project-agent via Task tool, handles metadata file exchange, links artifacts to state.json and TODO.md, and commits changes. Output goes to `strategy/timelines/` directory.

### Research Integration

Key findings from research report:
- Identical 11-stage wrapper pattern used by all founder skills
- Mode-specific status values: PLAN->planned, TRACK->tracked, REPORT->reported
- Artifacts link to `strategy/timelines/` not `specs/` reports
- Use "| not" pattern for jq to avoid Issue #1132
- delegation_depth is 2 (skill sits between orchestrator and agent)

## Goals & Non-Goals

**Goals**:
- Implement skill-project following 11-stage thin wrapper pattern
- Support PLAN, TRACK, REPORT modes with mode-specific status values
- Delegate to project-agent via Task tool (NOT Skill)
- Handle metadata file reading and cleanup
- Link artifacts to state.json and TODO.md
- Commit changes with session ID

**Non-Goals**:
- Implementing project-agent (already done in task 256)
- Creating /project command (optional future enhancement)
- Adding custom status markers to CLAUDE.md (use existing markers creatively)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Custom status values (tracked/reported) not recognized | M | M | Map to existing markers or document as extension-specific |
| strategy/timelines/ directory may not exist | L | H | Agent creates it; skill verifies after agent returns |
| Typst compilation may fail | L | M | Non-blocking; preserve .typ file regardless |
| Mode parameter parsing issues | M | L | Strict validation with early return on invalid mode |

## Implementation Phases

### Phase 1: Skill File Structure [NOT STARTED]

**Goal**: Create SKILL.md with frontmatter and documentation sections

**Tasks**:
- [ ] Create `.claude/extensions/founder/skills/skill-project/SKILL.md`
- [ ] Add frontmatter with name, description, allowed-tools
- [ ] Add context pointers section referencing subagent-return.md
- [ ] Add trigger conditions section (direct and implicit invocation patterns)
- [ ] Add "When NOT to trigger" section

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Create new file

**Verification**:
- File exists with valid YAML frontmatter
- Trigger conditions match project-agent expectations

---

### Phase 2: Input Validation (Stage 1) [NOT STARTED]

**Goal**: Implement task lookup and mode validation

**Tasks**:
- [ ] Add Stage 1 heading and bash block for task lookup
- [ ] Extract task_data from state.json using jq
- [ ] Validate task exists with early return if not found
- [ ] Extract language, status, project_name, description, forcing_data
- [ ] Validate mode parameter (PLAN, TRACK, REPORT)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Add Stage 1

**Verification**:
- Invalid task numbers return clear error
- Invalid modes return clear error
- forcing_data extraction works for pre-gathered data

---

### Phase 3: Preflight Operations (Stages 2-3) [NOT STARTED]

**Goal**: Implement status update and postflight marker creation

**Tasks**:
- [ ] Add Stage 2: Preflight Status Update
  - Update state.json to "planning" status
  - Update TODO.md to `[PLANNING]` marker
- [ ] Add Stage 3: Create Postflight Marker
  - Create `.postflight-pending` file with JSON content
  - Include session_id, skill name, task_number, operation, reason

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Add Stages 2-3

**Verification**:
- state.json status updates correctly
- TODO.md marker changes to [PLANNING]
- .postflight-pending file created with valid JSON

---

### Phase 4: Delegation Context and Agent Invocation (Stages 4-5) [NOT STARTED]

**Goal**: Prepare delegation context and invoke project-agent via Task tool

**Tasks**:
- [ ] Add Stage 4: Prepare Delegation Context
  - Include task_context with project_name, description, language, task_type
  - Include forcing_data when available
  - Include mode parameter
  - Include metadata_file_path
  - Include metadata with session_id, delegation_depth=2, delegation_path
- [ ] Add Stage 5: Invoke Agent
  - CRITICAL: Use Task tool (NOT Skill)
  - Document required tool invocation parameters
  - Note agent responsibilities

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Add Stages 4-5

**Verification**:
- Delegation context JSON is valid
- delegation_depth is 2
- Tool usage clearly specifies Task (NOT Skill)

---

### Phase 5: Postflight Operations (Stages 6-8) [NOT STARTED]

**Goal**: Parse metadata, update status, link artifacts

**Tasks**:
- [ ] Add Stage 6: Parse Subagent Return
  - Read .return-meta.json file
  - Extract status, artifact_path, artifact_type, artifact_summary
  - Handle missing/invalid file gracefully
- [ ] Add Stage 7: Update Task Status
  - Mode-specific status mapping: PLAN->planned, TRACK->tracked, REPORT->reported
  - Update state.json with final status
  - Update TODO.md with appropriate marker
- [ ] Add Stage 8: Link Artifacts
  - Add artifact to state.json (strategy/timelines/ path)
  - Use two-step jq pattern with "| not" to avoid Issue #1132
  - Update TODO.md with artifact link (no specs/ prefix stripping needed)

**Timing**: 35 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Add Stages 6-8

**Verification**:
- Metadata file parsed correctly
- Mode-specific status values applied
- Artifacts linked to strategy/timelines/ paths

---

### Phase 6: Commit and Cleanup (Stages 9-11) [NOT STARTED]

**Goal**: Git commit changes, cleanup temporary files, return summary

**Tasks**:
- [ ] Add Stage 9: Git Commit
  - git add -A
  - Commit message format: "task {N}: complete project {mode}"
  - Include session ID in commit body
- [ ] Add Stage 10: Cleanup
  - Remove .postflight-pending
  - Remove .postflight-loop-guard (if exists)
  - Remove .return-meta.json
- [ ] Add Stage 11: Return Brief Summary
  - Mode-specific summary format
  - Include artifact path, status change, next steps

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Add Stages 9-11

**Verification**:
- Git commit succeeds with correct message format
- Temporary files removed
- Return summary is text (NOT JSON)

---

### Phase 7: Error Handling and Return Format [NOT STARTED]

**Goal**: Add error handling section and return format documentation

**Tasks**:
- [ ] Add Error Handling section
  - Input validation errors
  - Metadata file missing
  - User abandonment
  - Git commit failure (non-blocking)
  - Directory creation failure
- [ ] Add Return Format section
  - Expected successful return template
  - Mode-specific variations

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Add final sections

**Verification**:
- Error handling covers all edge cases from research
- Return format matches thin wrapper pattern

## Testing & Validation

- [ ] Skill file has valid YAML frontmatter
- [ ] All 11 stages documented with bash blocks
- [ ] jq commands use "| not" pattern (not !=)
- [ ] delegation_depth is 2 (not 1)
- [ ] Task tool specified (not Skill)
- [ ] Artifact paths use strategy/timelines/ (not specs/reports/)
- [ ] Mode-specific status values (planned/tracked/reported)
- [ ] Return format is text (not JSON)

## Artifacts & Outputs

- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Main skill definition
- specs/259_skill_project/summaries/01_skill-project-summary.md - Implementation summary (after execution)

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/extensions/founder/skills/skill-project/` directory
2. Task remains at [PLANNED] status
3. Re-run /implement 259 after addressing issues
