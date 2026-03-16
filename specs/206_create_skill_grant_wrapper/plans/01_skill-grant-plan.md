# Implementation Plan: Task #206

- **Task**: 206 - create_skill_grant_wrapper
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #205 (grant-agent, already created)
- **Research Inputs**: [01_skill-wrapper-patterns.md](../reports/01_skill-wrapper-patterns.md)
- **Artifacts**: plans/01_skill-grant-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Create skill-grant as a thin wrapper that implements the skill-internal postflight pattern. The skill validates inputs, maps workflow types to status transitions, delegates to grant-agent via the Task tool, parses the returned metadata file, updates task status and artifacts, commits changes, and returns a brief text summary. This follows the established pattern from skill-researcher while adding grant-specific workflow type routing for four workflows: funder_research, proposal_draft, budget_develop, and progress_track.

### Research Integration

Key findings from 01_skill-wrapper-patterns.md:
- 11-stage execution flow with internal postflight (eliminates "continue" prompt issue)
- Task tool invocation pattern (NOT Skill tool)
- Postflight marker protocol for interruption recovery
- Two-step jq pattern to avoid Issue #1132 escaping bug
- Workflow type to status mapping table for grant-specific routing
- Brief text summary return format (NOT JSON)

## Goals & Non-Goals

**Goals**:
- Implement complete 11-stage execution flow in skill-grant/SKILL.md
- Add workflow_type routing for four grant workflows
- Map each workflow type to appropriate preflight/postflight status transitions
- Follow skill-researcher pattern for delegation and metadata exchange
- Include postflight marker protocol for interruption recovery
- Handle all error cases gracefully

**Non-Goals**:
- Modifying grant-agent (already complete per Task #205)
- Creating new grant context files (separate task scope)
- Implementing the /grant command (Task #207)
- Adding unit tests for skill-grant (separate task scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| workflow_type routing logic error | Incorrect status transitions | Medium | Use explicit status mapping table in implementation |
| jq escaping bug (Issue #1132) | Artifact linking fails | Medium | Use two-step jq pattern from research report |
| Postflight marker not cleaned on success | Stale marker files | Low | Always cleanup in Stage 10 regardless of success/failure |
| grant-agent returns JSON to console | Metadata parsing fails | Medium | Validate metadata file exists before parsing, handle both cases |
| Extension not loaded when skill invoked | Missing context | Medium | Validate language == "grant" in Stage 1 |

## Implementation Phases

### Phase 1: Frontmatter and Structure Setup [NOT STARTED]

**Goal**: Create the skill file with proper frontmatter and section skeleton

**Tasks**:
- [ ] Create skill-grant/SKILL.md with correct frontmatter (name, description, allowed-tools)
- [ ] Add Context References section with lazy-loaded paths
- [ ] Add Trigger Conditions section
- [ ] Create Execution Flow section headers for all 11 stages
- [ ] Add Error Handling section header
- [ ] Add Return Format section header

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Replace placeholder with full implementation

**Verification**:
- Skill file has correct frontmatter fields
- All 11 stages are listed in Execution Flow section
- Structure matches skill-researcher pattern

---

### Phase 2: Input Validation and Preflight Status [NOT STARTED]

**Goal**: Implement Stages 1-3 (validation, preflight status, postflight marker)

**Tasks**:
- [ ] Implement Stage 1: Input Validation
  - Validate task_number exists in state.json
  - Validate language == "grant"
  - Validate workflow_type is one of four valid values
  - Extract project_name, description, and other fields
- [ ] Implement Stage 2: Preflight Status Update
  - Create status mapping table for workflow types
  - Update state.json with workflow-specific in-progress status
  - Update TODO.md with corresponding status marker
- [ ] Implement Stage 3: Create Postflight Marker
  - Ensure task directory exists
  - Write .postflight-pending with session_id, skill name, workflow_type, operation reason

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Add Stages 1-3 content

**Verification**:
- Stage 1 validates all required inputs
- Stage 2 uses correct status mapping per workflow type
- Stage 3 creates marker with all required fields

---

### Phase 3: Delegation Context and Subagent Invocation [NOT STARTED]

**Goal**: Implement Stages 4-5 (delegation context, Task tool invocation)

**Tasks**:
- [ ] Implement Stage 4: Prepare Delegation Context
  - Build JSON structure with session_id, delegation_path, timeout
  - Include task_context with task_number, task_name, description, language
  - Add workflow_type and focus_prompt
  - Add metadata_file_path for grant-agent to write to
- [ ] Implement Stage 5: Invoke Subagent
  - Document Task tool invocation (NOT Skill tool)
  - Include grant-agent as subagent_type
  - Provide complete prompt with delegation context
  - Add description for task spawning
- [ ] Implement Stage 5a: Validate Return Format
  - Check if subagent erroneously returned JSON to console
  - Log warning if detected

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Add Stages 4-5 content

**Verification**:
- Delegation context JSON is well-formed
- Task tool invocation is clearly documented
- Stage 5a handles console JSON detection

---

### Phase 4: Postflight Operations [NOT STARTED]

**Goal**: Implement Stages 6-10 (metadata parsing, status update, artifact linking, git commit, cleanup)

**Tasks**:
- [ ] Implement Stage 6: Parse Metadata File
  - Read .return-meta.json from task directory
  - Extract status, artifacts, and metadata
  - Handle missing or invalid metadata file
- [ ] Implement Stage 7: Update Task Status (Postflight)
  - Map workflow_type + metadata status to final state.json status
  - Update state.json with final status and timestamps
  - Update TODO.md with corresponding status marker
  - Handle partial/failed status cases
- [ ] Implement Stage 8: Link Artifacts
  - Use two-step jq pattern (Issue #1132 workaround)
  - Filter existing artifacts of same type
  - Add new artifact with path, type, and summary
  - Update TODO.md with artifact link
- [ ] Implement Stage 9: Git Commit
  - Stage all changes
  - Commit with session ID and standard message format
  - Handle commit failure as non-blocking
- [ ] Implement Stage 10: Cleanup
  - Remove .postflight-pending marker
  - Remove .postflight-loop-guard if exists
  - Remove .return-meta.json metadata file

**Timing**: 50 minutes

**Files to modify**:
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Add Stages 6-10 content

**Verification**:
- Stage 6 validates metadata file before parsing
- Stage 7 uses correct status mapping per workflow type
- Stage 8 uses two-step jq pattern to avoid escaping bug
- Stage 9 includes session ID in commit message
- Stage 10 removes all temporary files

---

### Phase 5: Return Format and Error Handling [NOT STARTED]

**Goal**: Implement Stage 11 (return summary) and complete error handling

**Tasks**:
- [ ] Implement Stage 11: Return Brief Summary
  - Create workflow-specific return templates
  - Include 3-6 bullet points summarizing actions
  - Never return JSON
  - Include artifact path and status change
- [ ] Complete Error Handling section
  - Input validation errors (task not found, invalid workflow_type)
  - Metadata file missing or invalid
  - Git commit failure (non-blocking)
  - Subagent timeout (return partial status)
- [ ] Add Return Format section
  - Document expected return structure
  - Include examples for each workflow type
  - Include partial and failed examples

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Add Stage 11, Error Handling, and Return Format content

**Verification**:
- Stage 11 provides clear brief summary for each workflow type
- Error handling covers all identified error cases
- Return format examples match expected patterns

---

### Phase 6: Final Review and Documentation [NOT STARTED]

**Goal**: Review complete implementation and ensure consistency

**Tasks**:
- [ ] Review all 11 stages for completeness and consistency
- [ ] Verify Status field is present in file header (plan-format.md requirement)
- [ ] Ensure workflow_type status mappings are consistent across all stages
- [ ] Verify all bash code blocks use proper escaping patterns
- [ ] Check all context references are correct paths
- [ ] Ensure skill integrates correctly with /grant command (Task #207)
- [ ] Update placeholder content if any remains

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Final review and polish

**Verification**:
- Complete skill file with no placeholders
- Consistent status mappings throughout
- All bash patterns follow standards
- Ready for integration with /grant command

## Testing & Validation

- [ ] Manual test: Invoke skill-grant with funder_research workflow
- [ ] Verify state.json status transitions correctly (researching -> researched)
- [ ] Verify TODO.md markers update correctly
- [ ] Verify artifact is created and linked in state.json
- [ ] Verify postflight marker is cleaned up after completion
- [ ] Verify git commit is created with session ID
- [ ] Test error case: Invalid task number
- [ ] Test error case: Invalid workflow_type

## Artifacts & Outputs

- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Complete skill implementation
- `specs/206_create_skill_grant_wrapper/plans/01_skill-grant-plan.md` - This plan
- `specs/206_create_skill_grant_wrapper/summaries/01_execution-summary.md` - Completion summary (on implementation)

## Rollback/Contingency

If implementation introduces issues:
1. Restore placeholder SKILL.md from git history
2. Mark task as [BLOCKED] with blocking reason
3. Review grant-agent integration points
4. Consider creating simpler single-workflow skill first, then expanding

If skill-internal postflight pattern causes issues:
1. Fall back to orchestrator-based postflight
2. Document deviation from standard pattern
3. Create follow-up task to align with pattern later
