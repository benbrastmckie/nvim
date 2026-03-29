# Command File Structure: Commands as Agents with Workflows

**Created**: 2026-01-05  
**Purpose**: Document command file anatomy and patterns  
**Audience**: Command developers, meta-builder, system architects

---

## Overview

In this agent system, **command files are agents with workflows**, not just entry points or routers. Each command file is an autonomous agent responsible for:

1. **Parsing and validating** user arguments
2. **Orchestrating workflow execution** via subagent delegation
3. **Aggregating results** from multiple subagents
4. **Handling errors** and edge cases
5. **Returning formatted responses** to the orchestrator

This pattern enables:
- **Modularity**: Commands compose reusable subagents
- **Flexibility**: Workflows can be modified without changing routing
- **Robustness**: Errors caught and handled at command level
- **Testability**: Commands can be tested with mock subagents
- **Observability**: Clear workflow execution logs

---

## Command File Anatomy

### Complete Structure

```markdown
---
command: plan
description: Create implementation plan for a task
version: 1.0
arguments:
  - name: task_number
    type: integer
    required: true
    description: Task number to create plan for
  - name: research_report
    type: string
    required: false
    description: Optional research report number to integrate
delegation_depth: 1
max_delegation_depth: 3
---

# Command: /plan

**Purpose**: Create implementation plan for a task  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: planner, status-sync-manager

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Extract task_number from args[0]
    Validate task_number is positive integer
    If invalid: Return error "Invalid task number"
  </step_1>
  
  <step_2>
    Extract optional research_report from args[1]
    If provided: Validate research_report exists
  </step_2>
  
  <step_3>
    Load task context from state.json:
    task_status=$(jq -r ".tasks[] | select(.number == $task_number) | .status" .claude/state.json)
    task_title=$(jq -r ".tasks[] | select(.number == $task_number) | .title" .claude/state.json)
  </step_3>
  
  <step_4>
    Validate task is ready for planning:
    - Status must be "research_complete" or "ready"
    - Task must not already have a plan
    If not ready: Return error with current status
  </step_4>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Delegate to planner subagent</action>
    <input>
      - task_number: {task_number}
      - task_title: {task_title}
      - research_report: {research_report} (if provided)
      - session_id: sess_{timestamp}_{random}
      - delegation_depth: 2
    </input>
    <timeout>3600s</timeout>
    <expected_return>
      {
        "status": "planned",
        "artifacts": [{"type": "plan", "path": "..."}],
        "summary": "Plan created"
      }
    </expected_return>
  </step_1>
  
  <step_2>
    <action>Validate planner return</action>
    <validation>
      - status == "planned" (contextual success value)
      - artifacts array contains plan
      - plan file exists on disk
    </validation>
    <on_failure>
      Return error to orchestrator
      Do NOT proceed to step 3
    </on_failure>
  </step_2>
  
  <step_3>
    <action>Delegate to status-sync-manager</action>
    <input>
      - task_number: {task_number}
      - new_status: "planned"
      - artifact_path: {plan_path}
      - artifact_type: "plan"
      - session_id: {session_id}
      - delegation_depth: 2
    </input>
    <timeout>30s</timeout>
    <expected_return>
      {
        "status": "synced",
        "summary": "Status updated"
      }
    </expected_return>
  </step_3>
  
  <step_4>
    <action>Aggregate results and return</action>
    <output>
      Display: "Plan created: {plan_path}"
      Return to orchestrator
    </output>
  </step_4>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Missing task_number → "Usage: /plan <task_number> [research_report]"
    - Invalid task_number → "Task number must be a positive integer"
    - Task not found → "Task {task_number} not found in state.json"
    - Task not ready → "Task {task_number} status is {status}, expected research_complete or ready"
  </argument_errors>
  
  <workflow_errors>
    - Planner failure → Display planner error, suggest retry
    - Status update failure → Log warning (non-critical), continue
    - Timeout → Return partial result, suggest resume
  </workflow_errors>
  
  <recovery>
    - Transient errors → Retry once
    - Permanent errors → Return error to orchestrator
    - Partial success → Return partial result with next steps
  </recovery>
</error_handling>

---

## State Management

<state_management>
  <reads>
    # Fast, direct queries via jq
    task_status=$(jq -r ".tasks[] | select(.number == $task_number) | .status" .claude/state.json)
    task_title=$(jq -r ".tasks[] | select(.number == $task_number) | .title" .claude/state.json)
  </reads>
  
  <writes>
    # All writes delegated to status-sync-manager
    Delegate to status-sync-manager with:
      - task_number: {task_number}
      - new_status: "planned"
      - artifact_path: {plan_path}
  </writes>
</state_management>
```

---

## Why Commands Have Workflows

### Traditional Pattern (Two-Layer)

```
User → Orchestrator → Execution Agent
```

**Problems**:
- Orchestrator must parse arguments (mixing routing and parsing)
- Execution agents must handle multiple responsibilities
- Hard to compose complex workflows
- Difficult to test

### Agent System Pattern (Three-Layer)

```
User → Orchestrator → Command File → Execution Subagent(s)
```

**Benefits**:
- Orchestrator only routes (pure router)
- Command files orchestrate workflows (clear responsibility)
- Execution subagents are specialized (single purpose)
- Easy to compose and test

### Example: Complex Workflow

**Task**: Implement a feature (requires multiple steps)

**Without Command Workflows** (two-layer):
```
Orchestrator:
  - Parse task_number
  - Validate task
  - Load context
  - Execute implementation
  - Update status
  - Create git commit
  - Return result
```
Problem: Orchestrator does too much, hard to test, inflexible

**With Command Workflows** (three-layer):
```
Orchestrator:
  - Route to /implement command

Command File (/implement):
  - Parse task_number
  - Validate task
  - Delegate to task-executor
  - Delegate to status-sync-manager
  - Delegate to git-workflow-manager
  - Aggregate results
  - Return to orchestrator

Subagents:
  - task-executor: Execute implementation
  - status-sync-manager: Update status
  - git-workflow-manager: Create commit
```
Benefit: Clear separation, easy to test, flexible composition

---

## Command File Responsibilities

### ✅ What Command Files DO

1. **Parse Arguments**:
   - Extract arguments from user input
   - Validate argument types and formats
   - Provide clear error messages for invalid arguments

2. **Load Context**:
   - Query state.json for task metadata
   - Load related artifacts (plans, reports)
   - Validate preconditions

3. **Orchestrate Workflows**:
   - Define workflow steps
   - Delegate to specialized subagents
   - Wait for subagent returns
   - Validate subagent results

4. **Aggregate Results**:
   - Collect results from multiple subagents
   - Format response for orchestrator
   - Include all artifacts and metadata

5. **Handle Errors**:
   - Catch subagent errors
   - Decide: retry, fallback, or propagate
   - Provide recovery recommendations

6. **Manage State Transitions**:
   - Delegate status updates to status-sync-manager
   - Ensure atomic state changes
   - Link artifacts to tasks

### ❌ What Command Files DO NOT Do

1. **Execute Work Directly**:
   - ❌ Write implementation files directly
   - ❌ Create git commits directly
   - ❌ Update state.json directly
   - ✅ Delegate to specialized subagents instead

2. **Route to Other Commands**:
   - ❌ Call other command files directly
   - ✅ Return to orchestrator, let it route

3. **Parse User Input**:
   - ❌ Parse raw user command string
   - ✅ Receive pre-parsed arguments from orchestrator

4. **Make Architectural Decisions**:
   - ❌ Decide which subagent to use based on system state
   - ✅ Follow predefined workflow pattern

---

## Common Patterns

### Pattern 1: Simple Delegation

**Use Case**: Single subagent execution

```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to {subagent}
    Wait for return
    Validate return
  </step_1>
  
  <step_2>
    Return result to orchestrator
  </step_2>
</workflow_execution>
```

**Example**: `/research 197` → researcher → return report

### Pattern 2: Sequential Delegation

**Use Case**: Multiple subagents in sequence

```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to subagent_a
    Wait for return
    Validate return
  </step_1>
  
  <step_2>
    Delegate to subagent_b (using result from step 1)
    Wait for return
    Validate return
  </step_2>
  
  <step_3>
    Aggregate results
    Return to orchestrator
  </step_3>
</workflow_execution>
```

**Example**: `/plan 196` → planner → status-sync-manager → return

### Pattern 3: Conditional Delegation

**Use Case**: Different subagents based on conditions

```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Validate preconditions
    Determine which subagent to use
  </step_1>
  
  <step_2>
    If condition_a:
      Delegate to subagent_a
    Else if condition_b:
      Delegate to subagent_b
    Else:
      Return error
  </step_2>
  
  <step_3>
    Return result to orchestrator
  </step_3>
</workflow_execution>
```

**Example**: `/revise` → Check mode → If plan: planner, Else: reviser

### Pattern 4: Iterative Delegation

**Use Case**: Loop over items, delegate for each

```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Load items from state.json
  </step_1>
  
  <step_2>
    For each item:
      Delegate to subagent
      Collect result
  </step_2>
  
  <step_3>
    Aggregate all results
    Return to orchestrator
  </step_3>
</workflow_execution>
```

**Example**: `/todo` → For each task: format status → return list

### Pattern 5: Preflight/Postflight

**Use Case**: Status updates before and after work

```markdown
## Workflow Execution

<workflow_execution>
  <preflight>
    Delegate to status-sync-manager
    Update status to "in_progress"
    Log start time
  </preflight>
  
  <work>
    Delegate to execution subagent
    Wait for return
    Validate return
  </work>
  
  <postflight>
    Delegate to status-sync-manager
    Update status to "completed"
    Link artifacts
    Log completion time
  </postflight>
  
  <return>
    Return result to orchestrator
  </return>
</workflow_execution>
```

**Example**: `/implement 259` → preflight → task-executor → postflight → return

**See Also**: `workflows/preflight-postflight.md` for detailed timing requirements

---

## Argument Parsing Patterns

### Pattern 1: Required Positional Argument

```markdown
## Argument Parsing

<argument_parsing>
  <step_1>
    Extract arg from args[0]
    If missing: Return "Usage: /command <arg>"
    Validate arg format
    If invalid: Return "Invalid arg format"
  </step_1>
</argument_parsing>
```

### Pattern 2: Optional Positional Argument

```markdown
## Argument Parsing

<argument_parsing>
  <step_1>
    Extract required_arg from args[0]
    Validate required_arg
  </step_1>
  
  <step_2>
    Extract optional_arg from args[1]
    If provided: Validate optional_arg
    Else: Use default value
  </step_2>
</argument_parsing>
```

### Pattern 3: Named Arguments

```markdown
## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    - Extract --flag values
    - Extract positional arguments
    - Validate all required arguments present
  </step_1>
  
  <step_2>
    Validate argument combinations:
    - Check mutually exclusive flags
    - Check required dependencies
  </step_2>
</argument_parsing>
```

### Pattern 4: State.json Lookup

```markdown
## Argument Parsing

<argument_parsing>
  <step_1>
    Extract task_number from args[0]
    Validate task_number is positive integer
  </step_1>
  
  <step_2>
    Load task context from state.json:
    task_status=$(jq -r ".tasks[] | select(.number == $task_number) | .status" .claude/state.json)
    
    If task not found: Return "Task {task_number} not found"
  </step_2>
  
  <step_3>
    Validate task status:
    If status not in [expected_statuses]:
      Return "Task status is {status}, expected {expected_statuses}"
  </step_3>
</argument_parsing>
```

**See Also**: `orchestration/state-management.md` for query patterns

---

## Validation Patterns

### Pattern 1: Argument Validation

```markdown
<validation>
  <argument_validation>
    - task_number is positive integer
    - task_number exists in state.json
    - task status is valid for this command
    - All required arguments provided
  </argument_validation>
</validation>
```

### Pattern 2: Precondition Validation

```markdown
<validation>
  <precondition_validation>
    - Task has required artifacts (plan, research)
    - Task is not blocked by dependencies
    - System is in valid state for this operation
  </precondition_validation>
</validation>
```

### Pattern 3: Subagent Return Validation

```markdown
<validation>
  <return_validation>
    - status is "completed", "partial", or "failed"
    - artifacts array is present
    - All artifact paths exist on disk
    - metadata is complete
  </return_validation>
  
  <on_validation_failure>
    Log error: "Subagent return validation failed"
    Return error to orchestrator
    Do NOT proceed to next step
  </on_validation_failure>
</validation>
```

**See Also**: `orchestration/validation.md` for validation strategies

---

## Error Handling Patterns

### Pattern 1: Argument Errors (Immediate Return)

```markdown
<error_handling>
  <argument_errors>
    If argument invalid:
      Display error message
      Display usage
      Return immediately (do NOT delegate)
  </argument_errors>
</error_handling>
```

### Pattern 2: Subagent Errors (Retry or Propagate)

```markdown
<error_handling>
  <subagent_errors>
    If subagent returns {status: "failed"}:
      Check if error is transient
      If transient: Retry once
      If permanent: Propagate error to orchestrator
      Include recovery recommendation
  </subagent_errors>
</error_handling>
```

### Pattern 3: Partial Success (Continue or Stop)

```markdown
<error_handling>
  <partial_success>
    If subagent returns {status: "partial"}:
      Collect partial artifacts
      Decide: continue with next step or stop
      If stop: Return partial result with resume instructions
      If continue: Proceed with caution
  </partial_success>
</error_handling>
```

### Pattern 4: Two-Level Error Logging

```markdown
<error_handling>
  <critical_errors>
    # Errors that prevent task completion
    - Argument parsing failure
    - Subagent execution failure
    - State update failure (if critical)
    
    Action: Log to errors.json, return error to orchestrator
  </critical_errors>
  
  <non_critical_errors>
    # Warnings or recoverable errors
    - Git commit failure (if non-blocking)
    - Optional artifact creation failure
    - Performance warnings
    
    Action: Log warning, continue execution
  </non_critical_errors>
</error_handling>
```

**See Also**: `standards/error-handling.md` for error handling standards

---

## State Management Patterns

### Pattern 1: Read-Only Query

```markdown
<state_management>
  <read>
    # Fast, direct query via jq
    task_status=$(jq -r ".tasks[] | select(.number == $task_number) | .status" .claude/state.json)
    
    # No delegation needed for reads
  </read>
</state_management>
```

### Pattern 2: Status Update (Delegated)

```markdown
<state_management>
  <write>
    # All writes delegated to status-sync-manager
    Delegate to status-sync-manager with:
      - task_number: {task_number}
      - new_status: "completed"
      - session_id: {session_id}
      - delegation_depth: 2
    
    # Wait for confirmation
    # Validate return status
  </write>
</state_management>
```

### Pattern 3: Artifact Linking (Delegated)

```markdown
<state_management>
  <artifact_linking>
    # Link artifact to task via status-sync-manager
    Delegate to status-sync-manager with:
      - task_number: {task_number}
      - artifact_path: {artifact_path}
      - artifact_type: "plan|research|implementation"
      - session_id: {session_id}
      - delegation_depth: 2
  </artifact_linking>
</state_management>
```

**See Also**: `orchestration/state-management.md` for state management patterns

---

## Common Mistakes vs Correct Patterns

### ❌ Mistake 1: Command Executes Work Directly

**Wrong**:
```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Create implementation plan
    Write plan to file: specs/{task_number}_.../plan.md
  </step_1>
  
  <step_2>
    Update state.json directly:
    jq ".tasks[] | select(.number == $task_number) | .status = \"planned\"" state.json
  </step_2>
</workflow_execution>
```

**Correct**:
```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to planner subagent
    Wait for return
    Validate return
  </step_1>
  
  <step_2>
    Delegate to status-sync-manager
    Wait for confirmation
  </step_2>
</workflow_execution>
```

### ❌ Mistake 2: Skipping Validation

**Wrong**:
```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to subagent
    # Assume success, don't validate return
  </step_1>
  
  <step_2>
    Proceed to next step
  </step_2>
</workflow_execution>
```

**Correct**:
```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to subagent
    Wait for return
    Validate return:
      - status == "completed"
      - artifacts present
      - files exist on disk
    If validation fails: Return error, do NOT proceed
  </step_1>
  
  <step_2>
    Proceed to next step (only if step 1 validated)
  </step_2>
</workflow_execution>
```

### ❌ Mistake 3: Updating State Directly

**Wrong**:
```markdown
## State Management

<state_management>
  <write>
    # Direct write to state.json
    jq ".tasks[] | select(.number == $task_number) | .status = \"completed\"" .claude/state.json > tmp.json
    mv tmp.json .claude/state.json
  </write>
</state_management>
```

**Correct**:
```markdown
## State Management

<state_management>
  <write>
    # Delegated write via status-sync-manager
    Delegate to status-sync-manager with:
      - task_number: {task_number}
      - new_status: "completed"
      - session_id: {session_id}
      - delegation_depth: 2
  </write>
</state_management>
```

### ❌ Mistake 4: Missing Error Handling

**Wrong**:
```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to subagent
    # No error handling
  </step_1>
  
  <step_2>
    Return result
  </step_2>
</workflow_execution>
```

**Correct**:
```markdown
## Workflow Execution

<workflow_execution>
  <step_1>
    Delegate to subagent
    If subagent returns {status: "failed"}:
      Log error
      Return error to orchestrator with recovery recommendation
      Do NOT proceed to step 2
  </step_1>
  
  <step_2>
    Return result (only if step 1 succeeded)
  </step_2>
</workflow_execution>
```

---

## Template Reference

### Command File Template

See `templates/command-template.md` for complete template with:
- Frontmatter structure
- Argument parsing section
- Workflow execution section
- Error handling section
- State management section
- Validation section

### Subagent Template

See `templates/subagent-template.md` for subagent structure

### Delegation Context Template

See `templates/delegation-context.md` for delegation context format

---

## Integration with Architecture

### Three-Layer Pattern

Command files are **Layer 2** in the three-layer architecture:

```
Layer 1: Orchestrator (Pure Router)
  ↓
Layer 2: Command File (Argument Parsing Agent) ← YOU ARE HERE
  ↓
Layer 3: Execution Subagent (Work Executor)
```

**Command File Responsibilities in Three-Layer Pattern**:
1. Receive arguments from orchestrator (Layer 1)
2. Parse and validate arguments
3. Orchestrate workflow via subagent delegation (Layer 3)
4. Aggregate results
5. Return to orchestrator (Layer 1)

**See Also**: `orchestration/architecture.md` for complete architecture documentation

---

## Summary

**Key Principles**:

1. ✅ **Commands are agents with workflows**, not just entry points
2. ✅ **Commands orchestrate, never execute** work directly
3. ✅ **Commands delegate to specialized subagents** for all work
4. ✅ **Commands validate** arguments and subagent returns
5. ✅ **Commands aggregate** results from multiple subagents
6. ✅ **Commands handle errors** and provide recovery recommendations
7. ✅ **Commands use state.json** for fast reads, delegate writes

**Common Patterns**:
- Simple delegation (one subagent)
- Sequential delegation (multiple subagents)
- Conditional delegation (branching)
- Iterative delegation (loops)
- Preflight/postflight (status updates)

**Avoid**:
- ❌ Executing work directly
- ❌ Updating state.json directly
- ❌ Skipping validation
- ❌ Missing error handling

**Remember**: Command files are the **orchestration layer** that composes specialized subagents into coherent workflows. They are agents, not just routers.

---

**Related Documentation**:
- `orchestration/architecture.md` - Three-layer delegation pattern
- `orchestration/delegation.md` - Delegation patterns and depth tracking
- `orchestration/state-management.md` - State management patterns
- `orchestration/state-management.md` - State management and query patterns
- `workflows/preflight-postflight.md` - Workflow timing standards
- `standards/error-handling.md` - Error handling patterns
- `formats/subagent-return.md` - Subagent return format
- `templates/command-template.md` - Command file template
- `templates/subagent-template.md` - Subagent template
