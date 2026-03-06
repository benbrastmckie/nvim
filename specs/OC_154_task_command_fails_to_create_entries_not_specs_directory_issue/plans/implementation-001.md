# Implementation Plan: Task #154

- **Task**: 154 - Task command fails to create entries - not a specs/ directory issue
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md, .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses the root cause of the `/task` command failure: agents interpret problem descriptions as requests to solve rather than following task.md CREATE mode instructions. The solution involves three layers of improvements - short-term documentation updates, medium-term skill creation to enforce behavior, and long-term validation mechanisms.

### Research Integration

The research identified that:
1. `/task` is the ONLY command that does NOT delegate to a skill (unlike `/implement`, `/research`, `/plan`)
2. Task 151 was successfully created when the agent followed instructions correctly
3. The issue is behavioral (agents want to help) rather than technical (system works when followed)
4. No `skill-task` exists to enforce CREATE mode execution

The plan implements all three recommendation tiers from the research report.

## Goals & Non-Goals

**Goals**:
- Update task.md with prominent visual warnings to prevent agents from implementing
- Create skill-task skill to enforce CREATE mode execution via delegation pattern
- Add pre-flight banners to task.md for immediate visual recognition
- Establish command validation to verify task creation completion
- Ensure backward compatibility with existing task workflows

**Non-Goals**:
- Redesign the entire command architecture
- Modify other commands' delegation patterns
- Implement automatic problem diagnosis during task creation
- Create breaking changes to existing task entries

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agents continue to diagnose instead of create despite warnings | High | Medium | Add skill-task skill to enforce behavior through delegation |
| Users frustrated with multiple failed attempts | Medium | Low | Add prominent warning in task.md header with visual banners |
| skill-task creates additional complexity | Low | Low | Keep skill simple - only loads context and enforces CREATE mode |
| Breaking existing workflows | Low | Low | Ensure all changes are additive and backward compatible |
| Agents ignore skill-task delegation | Medium | Low | Add validation step to verify task creation occurred |

## Implementation Phases

### Phase 1: Update task.md Header with Prominent Warnings [NOT STARTED]

**Goal**: Make the "DO NOT IMPLEMENT" warning impossible to miss

**Tasks**:
- [ ] Add prominent pre-flight banner at the very beginning of task.md
- [ ] Move CRITICAL warnings to the top with visual ASCII box
- [ ] Add explicit AGENT INSTRUCTION section before any other content
- [ ] Include warning field in YAML frontmatter
- [ ] Add examples of correct vs incorrect /task responses

**Timing**: 45 minutes

### Phase 2: Create skill-task/SKILL.md Structure [NOT STARTED]

**Goal**: Create the skill-task skill that enforces CREATE mode execution

**Tasks**:
- [ ] Create directory `.opencode/skills/skill-task/`
- [ ] Write SKILL.md with:
  - Description: Task creation with CREATE mode enforcement
  - Execution flow: Load task.md context → Enforce CREATE mode → Delegate to agent
  - Explicit prohibition on diagnosing/implementing
  - Validation requirements for task creation
- [ ] Define skill parameters (task_description, mode)
- [ ] Add error handling for agents that try to implement
- [ ] Reference task.md as the authoritative source

**Timing**: 1 hour

### Phase 3: Implement task.md Skill Delegation [NOT STARTED]

**Goal**: Modify task.md to use skill-task delegation instead of direct execution

**Tasks**:
- [ ] Update task.md to call skill tool instead of direct execution
- [ ] Add skill delegation section following implement.md/research.md patterns
- [ ] Define skill invocation with proper context passing
- [ ] Add post-flight validation section to verify task creation
- [ ] Maintain backward compatibility for edge cases
- [ ] Update command documentation to reflect new flow

**Timing**: 1 hour

### Phase 4: Add Command Validation and Testing [NOT STARTED]

**Goal**: Verify that task creation actually occurred before completing

**Tasks**:
- [ ] Add validation step that checks:
  - Task entry exists in state.json
  - Task entry exists in TODO.md
  - Task directory was created (if applicable)
- [ ] Create test cases for task command:
  - Test: Creating task with problem description (should NOT solve)
  - Test: Creating task with feature request (should NOT implement)
  - Test: Verification that task entry exists after command
- [ ] Add validation failure error messages
- [ ] Document validation criteria in task.md

**Timing**: 45 minutes

### Phase 5: Documentation and Verification [NOT STARTED]

**Goal**: Ensure all changes are documented and working correctly

**Tasks**:
- [ ] Update skill-task/SKILL.md with examples
- [ ] Add README.md to skill-task directory explaining purpose
- [ ] Update context index if applicable
- [ ] Run test: Create a test task to verify the fix works
- [ ] Document any deviations from plan
- [ ] Create summary of changes

**Timing**: 30 minutes

## Testing & Validation

- [ ] Test task creation with problem description - verify agent does NOT diagnose
- [ ] Test task creation with feature request - verify agent does NOT implement
- [ ] Verify task entry appears in state.json after /task command
- [ ] Verify task entry appears in TODO.md after /task command
- [ ] Test that skill-task delegation works correctly
- [ ] Verify validation catches missing task creation
- [ ] Confirm backward compatibility with existing tasks
- [ ] Test error messages are clear when validation fails

## Artifacts & Outputs

- `.opencode/commands/task.md` - Updated with prominent warnings and skill delegation
- `.opencode/skills/skill-task/SKILL.md` - New skill for task creation enforcement
- `.opencode/skills/skill-task/README.md` - Documentation for skill-task
- Test results confirming task creation works correctly

## Rollback/Contingency

If implementation fails:
1. **Immediate rollback**: Revert task.md to original version
2. **Partial skill removal**: Delete skill-task directory if causing issues
3. **Fallback to warnings-only**: Implement only Phase 1 if delegation causes problems
4. **Recovery procedure**: 
   - Restore task.md from git history
   - Remove skill-task directory
   - Update state.json to remove any test task entries

If agents still ignore warnings after skill-task implementation:
1. Increase validation strictness
2. Add more prominent visual cues
3. Consider requiring explicit user confirmation before marking task complete
