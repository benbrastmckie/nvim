# Implementation Plan: Task #128

**Task**: OC_128 - Ensure /task command only creates tasks and never implements solutions automatically
**Version**: 001
**Created**: 2026-03-04
**Language**: general

## Overview

The /task command has been incorrectly auto-implementing solutions when users create task entries with problem descriptions. This plan addresses the root cause (agent misinterpretation of user intent) by adding explicit "DO NOT IMPLEMENT" boundaries to the task command specification, clarifying agent role, and documenting workflow phase separation.

## Phases

### Phase 1: Add Critical "DO NOT IMPLEMENT" Warning Header

**Status**: [COMPLETED]
**Estimated effort**: 30 minutes

**Objectives**:
1. Add prominent warning at the top of `.opencode/commands/task.md`
2. Establish strict boundaries for task creation behavior
3. Prevent agents from interpreting problem descriptions as implementation requests

**Files to modify**:
- `.opencode/commands/task.md` - Add CRITICAL warning block after the existing description

**Steps**:
1. Read current `.opencode/commands/task.md` to understand structure
2. Insert new section after line 5 (the "Do NOT implement" line) with the following:
   ```markdown
   ## CRITICAL: DO NOT IMPLEMENT
   
   When processing /task command:
   - **ONLY** create task entries in specs/TODO.md and specs/state.json
   - **NEVER** write code, scripts, or solutions
   - **NEVER** create files outside of specs/TODO.md and specs/state.json
   - **NEVER** interpret problem descriptions as requests to fix the problem
   
   If the task description mentions a problem or bug, create the task entry ONLY.
   Let the user decide later if they want to research/plan/implement via separate commands.
   ```
3. Verify the warning is visible at the top of the file

**Verification**:
- [ ] File contains new "CRITICAL: DO NOT IMPLEMENT" section
- [ ] Section appears early in the file (before mode descriptions)
- [ ] All four bullet points are present and clearly formatted

---

### Phase 2: Add Agent Role Clarification

**Status**: [COMPLETED]
**Estimated effort**: 30 minutes

**Objectives**:
1. Clarify the agent's role when processing /task commands
2. Differentiate task administration from problem-solving
3. Establish that agents should stay within task management boundaries only

**Files to modify**:
- `.opencode/commands/task.md` - Add agent role section near the beginning

**Steps**:
1. Add the following section after the CRITICAL warning (or integrate with it):
   ```markdown
   ### Agent Role for /task
   
   You are a **task administrator**, not a problem solver. Your job is to:
   - Record tasks in the tracking system
   - Update task statuses
   - Manage task lifecycle (create, abandon, recover, expand, sync)
   
   You do NOT:
   - Write implementation code
   - Create scripts or tools
   - Research solutions
   - Execute plans
   
   Stay within the boundaries of task management only. If a task description 
   describes a problem, your only action is to create the task entry.
   ```
2. Ensure the tone is firm but clear
3. Format with proper markdown headers and bullet points

**Verification**:
- [ ] Agent role section is present and clearly labeled
- [ ] Section explicitly states "task administrator, not a problem solver"
- [ ] Boundaries between task management and implementation are clearly defined

---

### Phase 3: Add Input Validation Checks

**Status**: [COMPLETED]
**Estimated effort**: 45 minutes

**Objectives**:
1. Add validation checks in CREATE mode section
2. Help agents identify when they're overstepping boundaries
3. Provide clear guidance on appropriate actions

**Files to modify**:
- `.opencode/commands/task.md` - Add validation section in CREATE mode

**Steps**:
1. Locate the CREATE mode section in task.md
2. Add a new subsection after the CREATE mode introduction:
   ```markdown
   ### CREATE Mode: Input Validation
   
   Before processing a task creation request, check:
   
   **CHECK**: Does the description mention a problem that needs fixing?  
   **ACTION**: Create task entry ONLY. Do NOT attempt to fix the problem.  
   **WHY**: /task creates tracking entries. Use /research, /plan, /implement to solve problems.
   
   **CHECK**: Does the user seem to be asking for code, scripts, or solutions?  
   **ACTION**: Create task entry with the description as-is. Do NOT write the code.  
   **WHY**: Let the user explicitly invoke /implement when they're ready.
   
   **CHECK**: Is the user describing a bug or issue they want tracked?  
   **ACTION**: Create task entry. Do NOT investigate or fix the bug.  
   **WHY**: Investigation belongs in /research phase, fixes in /implement phase.
   ```
3. Ensure the validation checks are placed where agents will see them before acting

**Verification**:
- [ ] Three validation checks are present with CHECK/ACTION/WHY format
- [ ] Checks are placed in CREATE mode section
- [ ] Each check reinforces the "create only, don't implement" rule

---

### Phase 4: Document Workflow Phase Separation

**Status**: [COMPLETED]
**Estimated effort**: 45 minutes

**Objectives**:
1. Document the clear separation between workflow phases
2. Explain that creating a task does not imply researching, planning, or implementing
3. Provide context on when to use each command

**Files to modify**:
- `.opencode/commands/task.md` - Add workflow phases section

**Steps**:
1. Add a new section near the beginning of the file (after agent role clarification):
   ```markdown
   ## Workflow Phases
   
   The agent system follows a strict phased workflow. Each command corresponds to 
   a specific phase. **Never skip phases.**
   
   | Phase | Command | Purpose | Creates Artifacts? |
   |-------|---------|---------|-------------------|
   | 1 | `/task` | Create tracking entry only | No (only TODO.md/state.json) |
   | 2 | `/research OC_N` | Investigate and document findings | Yes (research-NNN.md) |
   | 3 | `/plan OC_N` | Create implementation strategy | Yes (implementation-NNN.md) |
   | 4 | `/implement OC_N` | Execute the solution | Yes (code files, summaries) |
   
   ### Key Principle
   
   **Creating a task does NOT imply researching, planning, or implementing it.**
   
   When a user runs `/task "Fix the login bug"`, they are saying:
   - "I want to track this problem"
   - NOT "Fix this problem now"
   
   The user will explicitly invoke subsequent commands when ready:
   - `/research OC_N` when they want investigation
   - `/plan OC_N` when they want a strategy
   - `/implement OC_N` when they want execution
   ```
2. Ensure the table is properly formatted with clear column alignment
3. Add explanatory text after the table to reinforce the concept

**Verification**:
- [ ] Workflow phases table is present with all 4 phases
- [ ] Table clearly shows that /task does NOT create artifacts
- [ ] "Key Principle" section explicitly states task creation is independent of implementation
- [ ] Example clarifies user intent vs. agent action

---

## Dependencies

- Existing `.opencode/commands/task.md` file (assumed present)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Future agents may still misinterpret intent | Validation checks provide explicit checkpoints before action |
| Documentation bloat | Keep sections concise; use tables and bullet points for scannability |
| Agent ignores warnings | Multiple redundant warnings at different points in the file |
| Backwards compatibility | Changes are additive only; existing functionality preserved |

## Success Criteria

- [ ] `.opencode/commands/task.md` contains a prominent "CRITICAL: DO NOT IMPLEMENT" section
- [ ] Agent role is clearly defined as "task administrator, not problem solver"
- [ ] CREATE mode includes input validation checks
- [ ] Workflow phases are documented with clear separation
- [ ] Task status updated to PLANNED with plan artifact
- [ ] Changes committed to repository
