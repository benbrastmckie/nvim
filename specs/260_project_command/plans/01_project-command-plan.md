# Implementation Plan: Task #260

- **Task**: 260 - project_command
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 258 (project-agent - COMPLETED), Task 259 (skill-project - COMPLETED)
- **Research Inputs**: specs/260_project_command/reports/01_project-command-research.md
- **Artifacts**: plans/01_project-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create the `/project` command for the founder extension, implementing the user-facing entry point for project timeline management. The command follows the established founder extension command pattern with STAGE 0 pre-task forcing questions, gathering project scope, team, timeline, and risk information before task creation. This task completes the project timeline workflow by connecting the user interface to the existing skill-project (task 259) and project-agent (task 258) components.

### Research Integration

Integrated findings from `reports/01_project-command-research.md`:
- Command structure pattern from existing founder commands (market.md, strategy.md, analyze.md, legal.md)
- Seven forcing questions identified for project planning context
- Forcing questions framework principles (one at a time, push-back on vague answers)
- Routing pattern using `task_type: "project"` for composite key `founder:project`
- Three operational modes: PLAN, TRACK, REPORT

## Goals & Non-Goals

**Goals**:
- Create `/project` command following founder extension command pattern
- Implement 7 forcing questions covering: project name/completion criteria, goals/deliverables, team members (roles + allocation %), timeline constraints, resource needs, external dependencies, and risk factors
- Support all input types: description string, task number, file path, --quick mode
- Route to skill-project with `task_type: "project"` in state.json
- Support three operational modes: PLAN, TRACK, REPORT

**Non-Goals**:
- Modifying project-agent behavior (already implemented in task 258)
- Modifying skill-project behavior (already implemented in task 259)
- Implementing new forcing question push-back patterns beyond existing framework
- Adding new operational modes beyond PLAN/TRACK/REPORT

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Seven forcing questions may frustrate users | Medium | Low | Keep questions focused, allow partial completion |
| Complex team member allocation parsing | Medium | Low | Accept free-form text, let agent parse during execution |
| TRACK/REPORT modes require existing timeline | Low | Medium | Add validation message recommending PLAN mode first |
| Command file becomes too long | Low | Low | Follow modular section pattern from market.md |

## Implementation Phases

### Phase 1: Create Command File [COMPLETED]

**Goal**: Create the `/project` command file with frontmatter and basic structure

**Tasks**:
- [ ] Create `.claude/extensions/founder/commands/project.md`
- [ ] Add frontmatter with description, allowed-tools, and argument-hint
- [ ] Add Overview section describing command purpose and workflow
- [ ] Add Syntax section with all four input types
- [ ] Add Input Types table
- [ ] Add Modes table (PLAN, TRACK, REPORT)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/commands/project.md` - New file

**Verification**:
- File exists with correct frontmatter
- All sections through Modes table are present
- Format matches existing founder commands (market.md)

---

### Phase 2: Implement STAGE 0 Forcing Questions [COMPLETED]

**Goal**: Add pre-task forcing questions section with all 7 questions

**Tasks**:
- [ ] Add STAGE 0 header and skip conditions
- [ ] Add Step 0.1: Mode selection (PLAN/TRACK/REPORT)
- [ ] Add Step 0.2: Question 1 - Project name and completion criteria
- [ ] Add Question 2 - Goals and deliverables
- [ ] Add Question 3 - Team members with roles and allocation
- [ ] Add Question 4 - Timeline constraints (start, end, milestones)
- [ ] Add Question 5 - Resource needs
- [ ] Add Question 6 - External dependencies
- [ ] Add Question 7 - Risk factors
- [ ] Add Step 0.3: Store forcing data as JSON schema
- [ ] Include push-back triggers for each question

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/commands/project.md` - Add STAGE 0 section

**Verification**:
- All 7 questions present with storage field specifications
- Push-back triggers included for vague patterns
- Forcing data JSON schema matches research specification

---

### Phase 3: Implement CHECKPOINT 1 and Task Creation [COMPLETED]

**Goal**: Add GATE IN checkpoint with input detection and task creation logic

**Tasks**:
- [ ] Add CHECKPOINT 1: GATE IN header
- [ ] Add Step 1: Generate Session ID
- [ ] Add Step 2: Detect Input Type (description, task_number, file_path, --quick)
- [ ] Add Step 3: Handle Input Type with branch logic
- [ ] Add Step 4: Create Task (state.json update with task_type: "project")
- [ ] Add Step 5: Update TODO.md with forcing data summary
- [ ] Add Step 6: Git Commit for task creation
- [ ] Add Step 7: Display Task Created Summary and STOP instruction

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/commands/project.md` - Add CHECKPOINT 1 section

**Verification**:
- Input type detection covers all four types
- Task creation includes task_type: "project" and forcing_data
- STOP instruction present for new tasks

---

### Phase 4: Implement STAGE 2 and CHECKPOINT 2 [COMPLETED]

**Goal**: Add delegation logic and gate out checkpoint

**Tasks**:
- [ ] Add STAGE 2: DELEGATE header
- [ ] Add STAGE 2A: Legacy Mode (--quick) with direct skill invocation
- [ ] Add STAGE 2B: Task Workflow Mode with skill-project routing
- [ ] Add CHECKPOINT 2: GATE OUT header
- [ ] Add verification for Task Workflow Mode
- [ ] Add verification for Legacy Mode
- [ ] Add artifact retrieval and display

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/commands/project.md` - Add STAGE 2 and CHECKPOINT 2 sections

**Verification**:
- Skill invocation uses correct skill name (skill-project)
- Mode-specific output display included
- Status verification present

---

### Phase 5: Add Error Handling and Examples [COMPLETED]

**Goal**: Complete command with error handling, artifacts, workflow summary, and examples

**Tasks**:
- [ ] Add Error Handling section with all error cases
- [ ] Add Output Artifacts section with path conventions
- [ ] Add Workflow Summary section with visual flow
- [ ] Add Examples section with practical usage examples
- [ ] Review entire command for consistency with market.md pattern

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/commands/project.md` - Add remaining sections

**Verification**:
- All error cases documented (task not found, file not found, incomplete, abandonment)
- Artifact paths follow specs/{NNN}_{SLUG}/ convention
- Examples cover all input types

---

### Phase 6: Update Extension Configuration [COMPLETED]

**Goal**: Register the command in extension configuration files

**Tasks**:
- [ ] Update `.claude/extensions/founder/EXTENSION.md` command table
- [ ] Add /project to routing table
- [ ] Update `.claude/extensions/founder/index-entries.json` with founder:project routing
- [ ] Verify routing entry structure matches existing patterns

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/EXTENSION.md` - Add command and routing entries
- `.claude/extensions/founder/index-entries.json` - Add routing entry

**Verification**:
- /project appears in command table
- founder:project routing entry points to skill-project
- Index entry format matches existing entries

---

### Phase 7: Verification and Testing [COMPLETED]

**Goal**: Verify command integration and document test cases

**Tasks**:
- [ ] Verify command file syntax (no YAML errors in frontmatter)
- [ ] Verify command can be loaded by Claude Code
- [ ] Test input type detection patterns with edge cases
- [ ] Verify forcing_data schema matches skill-project expectations
- [ ] Document manual test scenarios for all modes

**Timing**: 15 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- Command file passes syntax validation
- All forcing questions present
- Routing to skill-project confirmed

## Testing & Validation

- [ ] Verify command frontmatter is valid (no YAML errors)
- [ ] Confirm command appears in /help output when founder extension loaded
- [ ] Test description input triggers STAGE 0 forcing questions
- [ ] Test task number input skips to STAGE 2B
- [ ] Test --quick flag triggers legacy mode
- [ ] Verify forcing_data JSON structure matches skill-project expectations
- [ ] Confirm task creation includes task_type: "project"
- [ ] Verify routing entry in index-entries.json is valid JSON

## Artifacts & Outputs

- `.claude/extensions/founder/commands/project.md` - Command file (~500 lines)
- `.claude/extensions/founder/EXTENSION.md` - Updated with /project command
- `.claude/extensions/founder/index-entries.json` - Updated with founder:project routing
- `specs/260_project_command/summaries/01_project-command-summary.md` - Execution summary (post-implementation)

## Rollback/Contingency

If implementation fails or causes issues:
1. Remove `.claude/extensions/founder/commands/project.md`
2. Revert changes to `EXTENSION.md` (remove /project entries)
3. Revert changes to `index-entries.json` (remove founder:project routing)
4. Existing skill-project and project-agent remain functional
5. Users can invoke skill-project directly until command is fixed
