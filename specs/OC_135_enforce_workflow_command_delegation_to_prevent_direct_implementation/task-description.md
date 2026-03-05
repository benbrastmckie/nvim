# Task Description: OC_135

**Task**: Enforce workflow command delegation to prevent direct implementation  
**Number**: OC_135  
**Status**: [NOT STARTED]  
**Language**: meta  
**Priority**: HIGH  
**Created**: 2026-03-04

---

## Problem Statement

When users type workflow commands like `/plan 134`, the AI agent executes the command directly by following the steps in the command specification, instead of routing the command through the skill system with proper delegation to a subagent. This causes:

1. **Violation of Separation of Concerns**: The main agent implements when it should only be planning
2. **Loss of Workflow Boundaries**: Users cannot review plans before implementation because the agent skips straight to implementation
3. **Skill System Bypass**: The carefully designed skill→subagent delegation pattern is ignored
4. **Inconsistent State Management**: Status updates and artifact linking happen without proper subagent metadata

### Specific Example

**What happened with OC_134**:
- User typed: `/plan 134`
- Expected behavior: The system should route to `skill-planner` → `planner-agent` subagent to CREATE a plan document
- Actual behavior: The main AI agent read the `/plan` command spec and directly executed all steps, including actual implementation
- Result: The agent implemented instead of planned, violating the "Do NOT implement anything" rule in the plan command specification

---

## Root Cause Analysis

The current system lacks **command interception and routing infrastructure**. When a workflow command is detected in user input:

1. There is no router/orchestrator that intercepts the command
2. There is no mechanism to force delegation to the appropriate skill
3. The AI treats `/plan`, `/research`, `/implement` as direct instructions to execute
4. The skill system with `context: fork` delegation is not enforced

### Command Flow (Current - Broken)

```
User: "/plan 134"
  ↓
Main Agent receives prompt
  ↓
Agent reads .opencode/commands/plan.md specification
  ↓
Agent executes steps 1-9 directly
  ↓
Status: [PLANNED] (but actually fully implemented)
```

### Command Flow (Expected - Working)

```
User: "/plan 134"
  ↓
Command Router detects "/plan N" pattern
  ↓
Routes to skill-planner SKILL.md
  ↓
skill-planner Preflight: validation, status update
  ↓
skill-planner Delegate: Task tool → planner-agent subagent (forked)
  ↓
planner-agent creates plan document ONLY
  ↓
skill-planner Postflight: update state, link artifact
  ↓
User sees: Plan created at implementation-001.md
User then runs: "/implement 134" to execute the plan
```

---

## Requirements

### Must Have

1. **Command Detection**: System must detect workflow commands (`/plan`, `/research`, `/implement`, `/revise`) in user input
2. **Routing Enforcement**: Commands MUST be routed to appropriate skills, never executed directly by main agent
3. **Delegation Boundaries**: Skills MUST use `Task` tool with `subagent_type` to delegate to subagents (context: fork)
4. **Implementation Prevention**: Subagents MUST NOT implement (for /plan, /research), only the delegated work
5. **Clear Separation**: 
   - /plan → planner-agent creates plan document only
   - /research → general-research-agent creates research report only
   - /implement → general-implementation-agent executes implementation

### Should Have

6. **User Confirmation**: Before delegation, show what will happen: "Creating plan for OC_135 via planner-agent..."
7. **Command Validation**: Validate task number exists before routing
8. **Error Handling**: If skill fails, surface error to user with clear message
9. **Status Tracking**: Track command execution state separately from task state

### Nice to Have

10. **Command Queue**: Support multiple pending commands
11. **Undo Capability**: Ability to cancel/reroute commands
12. **Command History**: Track which commands were run on which tasks

---

## Success Criteria

- [ ] `/plan N` is intercepted and routed to skill-planner → planner-agent (creates plan only)
- [ ] `/research N` is intercepted and routed to skill-researcher → general-research-agent (creates research report only)
- [ ] `/implement N` is intercepted and routed to skill-implementer → general-implementation-agent (executes implementation)
- [ ] Main AI agent never directly executes workflow commands
- [ ] Users can review plans before running `/implement`
- [ ] Research reports are created without implementation
- [ ] Clear error messages when commands fail or are invalid

---

## Related Work

- Task OC_134 (just completed): Demonstrates the problem - the agent implemented when asked to plan
- skill-planner/SKILL.md: Defines proper planning workflow with delegation
- skill-researcher/SKILL.md: Defines proper research workflow with delegation
- skill-implementer/SKILL.md: Defines proper implementation workflow with delegation
- planner-agent.md: Subagent that should be delegated to for planning
- general-research-agent.md: Subagent that should be delegated to for research
- general-implementation-agent.md: Subagent that should be delegated to for implementation

---

## Implementation Notes

This is a **system-level infrastructure change** that affects how all workflow commands are processed. It requires:

1. Command parsing logic to detect workflow patterns
2. Routing logic to match commands to skills
3. Enforcement mechanism to prevent direct execution
4. Integration with existing skill system and context injection
5. Updates to command specifications to clarify delegation behavior

**Do NOT modify** the existing skills - they are correctly designed. The fix is in the routing layer that should invoke them.
