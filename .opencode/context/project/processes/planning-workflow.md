# Planning Workflow

**Version**: 1.0.0  
**Created**: 2025-12-29  
**Purpose**: Detailed planning workflow for creating implementation plans

---

## Overview

This document describes the complete planning workflow executed by the planner subagent. It covers plan creation, research integration, and plan revision.

---

## Planning Modes

### Initial Planning

**When**: Task has no existing plan  
**Characteristics**:
- Creates first plan version (implementation-001.md)
- Integrates research findings if available
- Breaks work into phases
- Estimates effort
- Defines success criteria

### Plan Revision

**When**: Task has existing plan that needs updating  
**Characteristics**:
- Creates new plan version (implementation-002.md, etc.)
- Preserves previous plan versions
- Incorporates new information
- Adjusts approach based on learnings
- Updates specs/TODO.md to point to latest version

---

## Detailed Workflow Steps

### Step 1: Read Task and Research

**Action**: Load task details and harvest research findings

**Process**:
1. Read task from specs/TODO.md using grep (selective loading):
   ```bash
   grep -A 50 "^### ${task_number}." specs/TODO.md > /tmp/task-${task_number}.md
   ```
2. Extract task metadata:
   - Task number
   - Task title
   - Language
   - Description
   - Acceptance criteria
   - Research links (if any)
3. Scan task entry for research artifact links:
   - Look for `**Research**: {path}` in task entry
   - Extract research report paths
4. If research links found:
   - Load research reports
   - Extract key findings
   - Extract recommendations
   - Note research inputs in plan metadata
5. If no research available:
   - Proceed without research context
   - Note in plan that no research was available

**Research Integration**:
- Research findings inform phase breakdown
- Research recommendations guide approach
- Research constraints noted in plan
- Research artifacts linked in plan metadata

**Checkpoint**: Task and research loaded

### Step 2: Analyze Requirements

**Action**: Analyze task requirements and determine approach

**Process**:
1. Analyze task description:
   - Identify core objective
   - Identify scope boundaries
   - Identify constraints
   - Identify dependencies
2. Analyze acceptance criteria:
   - Extract success criteria
   - Identify validation requirements
   - Identify testing requirements
3. Determine complexity:
   - Simple: 1-2 phases, <4 hours
   - Moderate: 3-4 phases, 4-8 hours
   - Complex: 5+ phases, >8 hours
4. Identify risks:
   - Technical risks
   - Dependency risks
   - Timeline risks
5. Determine approach:
   - Incremental vs big-bang
   - Top-down vs bottom-up
   - Test-driven vs implementation-first

**Checkpoint**: Requirements analyzed and approach determined

### Step 3: Create Phase Breakdown

**Action**: Break work into logical phases

**Process**:
1. Identify natural phase boundaries:
   - Setup/infrastructure
   - Core implementation
   - Integration
   - Testing/validation
   - Documentation
2. For each phase:
   - Define objective (what this phase accomplishes)
   - List tasks (specific work items)
   - Define deliverables (what gets created)
   - Define success criteria (how to know phase is complete)
   - Estimate effort (1-2 hours per phase target)
3. Ensure phases are:
   - Independent (can be executed separately)
   - Testable (can validate completion)
   - Sized appropriately (1-2 hours each)
   - Sequenced logically (dependencies clear)
4. Add phase status markers:
   - All phases start with [NOT STARTED]
   - Will be updated during implementation

**Phase Sizing Guidelines**:
- Target: 1-2 hours per phase
- Minimum: 30 minutes (too small = overhead)
- Maximum: 4 hours (too large = hard to resume)

**Checkpoint**: Phases defined

### Step 4: Create Plan Document

**Action**: Write plan document following plan.md template

**Process**:
1. Create plan file:
   - Path: `specs/{number}_{slug}/plans/implementation-{version:03d}.md`
   - Version: 001 for initial plan, incremented for revisions
   - Directory created lazily when writing
2. Write plan metadata (frontmatter):
   ```yaml
   ---
   task: {task_number}
   status: [NOT STARTED]
   effort: {total_hours} hours
   priority: {priority}
   complexity: {simple|moderate|complex}
   language: {language}
   created: {ISO8601}
   last_updated: {ISO8601}
   version: {version}
   research_inputs: [{research_paths}]  # if applicable
   ---
   ```
3. Write plan sections:
   - **Overview**: Problem, scope, constraints, definition of done
   - **Goals and Non-Goals**: What will/won't be done
   - **Risks and Mitigations**: Identified risks and how to handle
   - **Implementation Phases**: Each phase with [NOT STARTED] marker
   - **Testing and Validation**: How to validate implementation
   - **Artifacts and Outputs**: What will be created
   - **Rollback/Contingency**: How to handle failures
   - **Success Metrics**: How to measure success
4. Validate plan document:
   - All required sections present
   - All phases have status markers
   - Effort estimates reasonable
   - Success criteria clear

**Plan Template Compliance**:
All plans must follow `.opencode/context/core/standards/plan.md` template exactly.

**Checkpoint**: Plan document created

### Step 5: Update Status

**Action**: Update task status to [PLANNED]

**Process**:
1. Delegate to status-sync-manager for atomic update:
   - Prepare update payload:
     ```json
     {
       "operation": "planning_complete",
       "task_number": {number},
       "status": "planned",
       "plan_path": "{plan_path}",
       "plan_metadata": {
         "version": {version},
         "phase_count": {count},
         "estimated_hours": {hours}
       }
     }
     ```
   - Invoke status-sync-manager
   - Wait for return
2. status-sync-manager performs atomic update:
   - Update specs/TODO.md:
     - Status: [NOT STARTED] or [RESEARCHED] → [PLANNED]
     - Add **Plan**: {plan_path}
     - Add **Completed**: {date}
   - Update specs/state.json:
     - Update status and timestamps
     - Add plan_path
     - Add plan_metadata
   - Two-phase commit (all or nothing)
3. Verify atomic update succeeded

**Checkpoint**: Status updated atomically

### Step 6: Create Git Commit

**Action**: Create git commit for plan

**Process**:
1. Delegate to git-workflow-manager:
   - Prepare commit payload:
     ```json
     {
       "operation": "planning_commit",
       "scope": ["{plan_path}", "specs/TODO.md", "specs/state.json"],
       "message": "task {number}: plan created"
     }
     ```
   - Invoke git-workflow-manager
   - Wait for return
2. git-workflow-manager creates commit:
   - Stage plan file, specs/TODO.md, specs/state.json
   - Create commit
   - Verify commit created
3. If commit fails:
   - Log error (non-critical)
   - Continue (plan already created)
   - Return success with warning

**Commit Message Format**: `task {number}: plan created`

**Checkpoint**: Git commit created

### Step 7: Prepare Return

**Action**: Format return object per subagent-return-format.md

**Process**:
1. Build return object:
   ```json
   {
     "status": "completed",
     "summary": "Plan created with {N} phases, {hours} hours estimated (<100 tokens)",
     "artifacts": [
       {
         "type": "plan",
         "path": "{plan_path}",
         "summary": "{N}-phase implementation plan"
       }
     ],
     "metadata": {
       "task_number": {number},
       "plan_version": {version},
       "phase_count": {count},
       "estimated_hours": {hours},
       "complexity": "{complexity}"
     },
     "session_id": "{session_id}"
   }
   ```
2. Validate return format:
   - Check all required fields present
   - Verify summary <100 tokens
   - Verify session_id matches input
   - Verify plan file exists on disk
3. If validation fails:
   - Log error
   - Fix issues
   - Re-validate

**Token Limit**: Summary must be <100 tokens (~400 characters)

**Checkpoint**: Return object prepared

### Step 8: Return

**Action**: Return to command

**Process**:
1. Return formatted object to command
2. Command validates return
3. Command relays to user

**Checkpoint**: Return sent

---

## Plan Revision Workflow

### When to Revise

Revise plans when:
- Requirements change
- Approach needs adjustment
- New information available
- Previous plan incomplete or incorrect

### Revision Process

1. **Load Existing Plan**:
   - Read current plan from specs/TODO.md link
   - Parse current plan version
   - Extract current phases and status
   - Note what worked/didn't work

2. **Determine Next Version**:
   - Parse version from current plan filename
   - Increment version: next_version = current + 1
   - Format new plan path: `implementation-{next_version:03d}.md`

3. **Create Revised Plan**:
   - Follow same process as initial planning
   - Incorporate learnings from previous plan
   - Adjust phases based on new information
   - Note revision reason in plan metadata

4. **Preserve Previous Plan**:
   - Never modify previous plan files
   - Keep all plan versions in plans/ directory
   - Update specs/TODO.md to point to latest version

5. **Update Status**:
   - Status: [PLANNED] → [REVISING]
   - Update plan link to new version
   - Preserve previous plan link in history

**Version Numbering**:
- First plan: `implementation-001.md`
- First revision: `implementation-002.md`
- Second revision: `implementation-003.md`
- etc.

---

## Status Transitions

| From | To | Condition |
|------|-----|-----------|
| [NOT STARTED] | [PLANNING] | Planning started |
| [RESEARCHED] | [PLANNING] | Planning started |
| [PLANNING] | [PLANNED] | Planning completed successfully |
| [PLANNING] | [PLANNING] | Planning failed or partial |
| [PLANNING] | [BLOCKED] | Planning blocked by dependency |
| [PLANNED] | [REVISING] | Plan revision started |
| [REVISING] | [REVISED] | Plan revision completed |

**Status Update**: Delegated to `status-sync-manager` for atomic synchronization across specs/TODO.md and specs/state.json.

**Timestamps**:
- `**Started**: {date}` added when status → [PLANNING]
- `**Completed**: {date}` added when status → [PLANNED]

---

## Context Loading

### Routing Stage (Command)

Load minimal context for routing decisions:
- `.opencode/context/system/routing-guide.md` (routing logic)

### Execution Stage (Planner)

Planner loads context on-demand per `.opencode/context/index.md`:
- `core/standards/subagent-return-format.md` (return format)
- `core/standards/status-markers.md` (status transitions)
- `core/system/artifact-management.md` (lazy directory creation)
- `core/standards/plan.md` (plan template)
- Task entry via `grep -A 50 "^### ${task_number}." specs/TODO.md` (~2KB vs 109KB full file)
- `specs/state.json` (project state)
- Research artifacts if linked in specs/TODO.md

**Optimization**: Task extraction reduces context from 109KB to ~2KB, 98% reduction.

---

## Error Handling

### Task Not Found

```
Error: Task {task_number} not found in specs/TODO.md

Recommendation: Verify task number exists in specs/TODO.md
```

### Invalid Task Number

```
Error: Task number must be an integer. Got: {input}

Usage: /plan TASK_NUMBER [PROMPT]
```

### Task Already Completed

```
Error: Task {task_number} is already [COMPLETED]

Recommendation: Cannot plan completed tasks
```

### Plan Already Exists

```
Warning: Plan already exists for task {task_number}

Existing plan: {plan_path}

Recommendation: Use /revise {task_number} to update existing plan
```

### Planning Timeout

```
Error: Planning timed out after 1800s

Status: Partial plan may exist
Task status: [PLANNING]

Recommendation: Resume with /plan {task_number}
```

### Validation Failure

```
Error: Plan validation failed

Details: {validation_error}

Recommendation: Fix planner subagent implementation
```

### Git Commit Failure (non-critical)

```
Warning: Git commit failed

Plan created successfully: {plan_path}
Task status updated to [PLANNED]

Manual commit required:
  git add {files}
  git commit -m "task {number}: plan created"

Error: {git_error}
```

---

## Quality Standards

### Plan Template Compliance

All plans must follow `.opencode/context/core/standards/plan.md` template:
- Metadata section with all required fields
- Phase breakdown with [NOT STARTED] markers
- Acceptance criteria per phase
- Effort estimates (1-2 hours per phase)
- Success metrics

### Atomic Updates

Status updates delegated to `status-sync-manager` for atomic synchronization:
- `specs/TODO.md` (status, timestamps, plan link)
- `specs/state.json` (status, timestamps, plan_path, plan_metadata)
- Project specs/state.json (lazy created if needed)

Two-phase commit ensures consistency across all files.

### Lazy Directory Creation

Directories created only when writing artifacts:
- `specs/{task_number}_{slug}/` created when writing plan
- `plans/` subdirectory created when writing implementation-001.md

No directories created during routing or validation stages.

### Research Integration

Planner automatically harvests research findings from specs/TODO.md:
1. Scan task entry for research artifact links
2. Load research reports and summaries if present
3. Extract key findings and recommendations
4. Incorporate into plan context and phases
5. Note research inputs in plan metadata

If no research available, planner proceeds without research context.

---

## Performance Optimization

### Task Extraction

Extract only specific task entry from specs/TODO.md to reduce context load:

```bash
grep -A 50 "^### ${task_number}." specs/TODO.md > /tmp/task-${task_number}.md
```

**Impact**: Reduces context from 109KB (full specs/TODO.md) to ~2KB (task entry only), 98% reduction.

### Lazy Context Loading

Load context on-demand:
- Required context loaded upfront
- Optional context loaded when needed
- Research artifacts loaded only if linked

### Delegation Safety

- Max delegation depth: 3 (orchestrator → command → planner → utility)
- Timeout: 1800s (30 minutes) for planning
- Session tracking: Unique session_id for all delegations
- Cycle detection: Prevent infinite delegation loops

---

## References

- **Command**: `.opencode/commands/plan.md`
- **Subagent**: `.opencode/agent/subagents/planner.md`
- **Plan Template**: `.opencode/context/core/standards/plan.md`
- **Return Format**: `.opencode/context/core/standards/subagent-return-format.md`
- **Status Markers**: `.opencode/context/core/standards/status-markers.md`
- **Artifact Management**: `.opencode/context/core/system/artifact-management.md`
