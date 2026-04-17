# project Architecture: Three-Layer Delegation Pattern

**Created**: 2026-01-05  
**Purpose**: Document project's unique three-layer delegation architecture  
**Audience**: Meta-builder, system developers, architecture reviewers

---

## Overview

project implements a **three-layer delegation pattern** that separates routing, argument parsing, and work execution into distinct layers. This architecture differs fundamentally from traditional agent systems (like OpenAgents) and enables clean separation of concerns, robust error handling, and flexible workflow composition.

### Core Principle

**Commands are agents with workflows, not just entry points.**

Each command file is an autonomous agent responsible for:
1. Parsing and validating user arguments
2. Orchestrating workflow execution
3. Delegating work to specialized subagents
4. Aggregating results and returning to orchestrator

This pattern enables:
- **Modularity**: Each layer has a single, well-defined responsibility
- **Testability**: Each layer can be tested independently
- **Flexibility**: Workflows can be composed from reusable subagents
- **Robustness**: Errors are caught and handled at appropriate layers
- **Observability**: Each layer logs its decisions and actions

---

## Three-Layer Architecture

### Layer 1: Orchestrator (Pure Router)

**File**: `.claude/agent/orchestrator.md`  
**Responsibility**: Route user commands to appropriate command files  
**Input**: Raw user command string  
**Output**: Delegation to Layer 2 (command file)

**Key Characteristics**:
- **Stateless**: No workflow logic, no business logic
- **Pure Router**: Only routing decisions based on command name
- **Fast**: Minimal processing, immediate delegation
- **Transparent**: Logs routing decision, passes through to command

**Routing Logic**:
```
User: /plan 196
  ↓
Orchestrator: Identify command = "plan"
  ↓
Orchestrator: Route to .claude/command/plan.md
  ↓
Delegate to Layer 2
```

**What Orchestrator Does NOT Do**:
- ❌ Parse command arguments
- ❌ Validate argument formats
- ❌ Execute workflows
- ❌ Call subagents directly
- ❌ Aggregate results

**What Orchestrator DOES Do**:
- ✅ Identify command name from user input
- ✅ Route to appropriate command file
- ✅ Handle unknown commands (error)
- ✅ Log routing decision
- ✅ Pass full context to command file

**Example**:
```markdown
## Routing Decision

User command: "/implement 259"
Command identified: "implement"
Target: .claude/command/implement.md
Delegation depth: 0 → 1
```

---

### Layer 2: Command File (Argument Parsing Agent)

**Files**: `.claude/command/*.md`  
**Responsibility**: Parse arguments, validate inputs, orchestrate workflow  
**Input**: Raw command arguments from orchestrator  
**Output**: Delegation to Layer 3 (execution subagents)

**Key Characteristics**:
- **Argument Parser**: Extracts and validates command-specific arguments
- **Workflow Orchestrator**: Defines and executes multi-step workflows
- **Context Builder**: Assembles context for subagent delegation
- **Result Aggregator**: Collects subagent results and formats response
- **Error Handler**: Catches and handles workflow errors

**Command File Anatomy**:

```markdown
---
command: plan
description: Create implementation plan for a task
arguments:
  - name: task_number
    type: integer
    required: true
  - name: research_report
    type: string
    required: false
---

## Argument Parsing

<argument_parsing>
  Extract task_number from args[0]
  Validate task_number is positive integer
  Extract optional research_report from args[1]
  Load task context from state.json
</argument_parsing>

## Workflow Execution

<workflow_execution>
  Step 1: Validate task exists and is ready for planning
  Step 2: Delegate to planner subagent
  Step 3: Validate plan format
  Step 4: Delegate to status-sync-manager to update task status
  Step 5: Return plan artifact to orchestrator
</workflow_execution>
```

**Workflow Orchestration Pattern**:
```
Command File: Parse arguments
  ↓
Command File: Validate inputs
  ↓
Command File: Delegate to Subagent A
  ↓
Subagent A: Execute work, return result
  ↓
Command File: Validate result
  ↓
Command File: Delegate to Subagent B
  ↓
Subagent B: Execute work, return result
  ↓
Command File: Aggregate results
  ↓
Command File: Return to orchestrator
```

**What Command Files Do NOT Do**:
- ❌ Execute implementation work directly
- ❌ Write files directly (delegate to subagents)
- ❌ Make git commits directly (delegate to git-workflow-manager)
- ❌ Update state.json directly (delegate to status-sync-manager)

**What Command Files DO Do**:
- ✅ Parse and validate command arguments
- ✅ Load task context from state.json
- ✅ Define workflow steps
- ✅ Delegate to specialized subagents
- ✅ Validate subagent returns
- ✅ Aggregate results
- ✅ Format response for orchestrator
- ✅ Handle workflow errors

---

### Layer 3: Execution Subagents (Work Executors)

**Files**: `.claude/agent/subagents/*.md`  
**Responsibility**: Execute specialized work, return standardized results  
**Input**: Delegation context from Layer 2  
**Output**: Standardized return format (see formats/subagent-return.md)

**Key Characteristics**:
- **Specialized**: Each subagent has a single, well-defined purpose
- **Stateless**: No persistent state between invocations
- **Standardized**: All returns follow subagent-return-format.md
- **Composable**: Can be combined in different workflows
- **Testable**: Clear inputs and outputs

**Subagent Categories**:

1. **Work Executors**:
   - `researcher`: Conduct research, create reports
   - `planner`: Create implementation plans
   - `implementer`: Execute implementation phases
   - Extension-provided agents for domain-specific implementations
   - `reviewer`: Review code and documentation

2. **State Managers**:
   - `status-sync-manager`: Update task status in state.json
   - `task-creator`: Create new tasks in state.json

3. **Workflow Managers**:
   - `git-workflow-manager`: Handle git operations
   - `task-executor`: Execute multi-phase implementations

**Subagent Return Format**:
```json
{
  "status": "completed|partial|failed",
  "summary": "Brief description of work done",
  "artifacts": [
    {
      "type": "implementation|research|plan|review",
      "path": "path/to/artifact.md",
      "summary": "Artifact description"
    }
  ],
  "metadata": {
    "session_id": "sess_20260105_abc123",
    "duration_seconds": 120,
    "agent_type": "researcher",
    "delegation_depth": 2
  },
  "errors": [],
  "next_steps": "What to do next"
}
```

**What Subagents Do NOT Do**:
- ❌ Parse user command arguments (Layer 2 responsibility)
- ❌ Route to other commands (Layer 1 responsibility)
- ❌ Define multi-command workflows (Layer 2 responsibility)

**What Subagents DO Do**:
- ✅ Execute specialized work
- ✅ Create artifacts (files, reports, plans)
- ✅ Update state (via status-sync-manager)
- ✅ Make git commits (via git-workflow-manager)
- ✅ Return standardized results
- ✅ Handle execution errors
- ✅ Log progress and decisions

---

## Delegation Flow

### Complete Example: `/plan 196`

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Orchestrator                                       │
│                                                              │
│ Input: "/plan 196"                                          │
│ Action: Identify command = "plan"                           │
│ Output: Delegate to .claude/command/plan.md              │
│ Delegation Depth: 0 → 1                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Command File (plan.md)                            │
│                                                              │
│ Input: args = ["196"]                                       │
│ Step 1: Parse task_number = 196                            │
│ Step 2: Validate task exists in state.json                 │
│ Step 3: Load task context                                  │
│ Step 4: Delegate to planner subagent                       │
│ Delegation Depth: 1 → 2                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Execution Subagent (planner)                      │
│                                                              │
│ Input: {task_number: 196, task_context: {...}}            │
│ Step 1: Analyze task requirements                          │
│ Step 2: Create implementation plan                         │
│ Step 3: Write plan to file                                 │
│ Step 4: Return standardized result                         │
│ Output: {status: "completed", artifacts: [...]}           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Command File (plan.md)                            │
│                                                              │
│ Input: Planner result                                       │
│ Step 5: Validate plan format                               │
│ Step 6: Delegate to status-sync-manager                    │
│ Delegation Depth: 1 → 2                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: State Manager (status-sync-manager)               │
│                                                              │
│ Input: {task_number: 196, status: "planned"}              │
│ Step 1: Update state.json                                  │
│ Step 2: Return success                                     │
│ Output: {status: "completed"}                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Command File (plan.md)                            │
│                                                              │
│ Step 7: Aggregate results                                  │
│ Step 8: Format response                                    │
│ Output: "Plan created: specs/196_.../plan.md"   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Orchestrator                                       │
│                                                              │
│ Input: Command result                                       │
│ Action: Display to user                                     │
│ Output: "Plan created successfully"                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Comparison with OpenAgents

### OpenAgents Pattern (Two-Layer)

```
User → Orchestrator → Execution Agent
```

**Characteristics**:
- Orchestrator parses arguments AND routes
- Execution agents are called directly
- No intermediate workflow layer
- Simpler but less flexible

### project Pattern (Three-Layer)

```
User → Orchestrator → Command File → Execution Subagent
```

**Characteristics**:
- Orchestrator only routes (pure router)
- Command files parse arguments and orchestrate workflows
- Execution subagents are specialized and composable
- More complex but more flexible and robust

### Why Three Layers?

**Separation of Concerns**:
- Layer 1: Routing logic (what command?)
- Layer 2: Workflow logic (how to execute?)
- Layer 3: Execution logic (do the work)

**Flexibility**:
- Command files can compose multiple subagents
- Subagents can be reused across commands
- Workflows can be modified without changing routing

**Robustness**:
- Errors caught at appropriate layer
- Validation at each layer
- Clear error propagation path

**Testability**:
- Each layer can be tested independently
- Mock subagents for command testing
- Mock commands for orchestrator testing

---

## State Management Integration

### State.json Optimization

project uses `state.json` as the single source of truth for task metadata, enabling fast lookups and consistent state management.

**Phase 1 Optimization** (Implemented):
- Command files use `jq` queries for task lookup (8x faster: 100ms → 12ms)
- Read-only queries bypass markdown parsing
- status-sync-manager handles all writes

**Phase 2 Optimization** (Implemented):
- /todo command uses state.json for scanning (13x faster: 200ms → 15ms)
- /meta and /task commands use status-sync-manager.create_task()
- Bulk operations via status-sync-manager.archive_tasks()

**Read/Write Separation**:
- **Reads**: Command files query state.json directly via jq
- **Writes**: All updates delegated to status-sync-manager

**Pattern**:
```bash
# Read (fast, direct query)
task_status=$(jq -r ".tasks[] | select(.number == $task_number) | .status" .claude/state.json)

# Write (delegated to status-sync-manager)
Delegate to status-sync-manager with:
  - task_number: 196
  - new_status: "planned"
  - artifact_path: "specs/196_.../plan.md"
```

**Benefits**:
- Fast reads (12ms vs 100ms)
- Atomic writes (via status-sync-manager)
- Consistent state across all commands
- Single source of truth

**See Also**:
- `orchestration/state-management.md` - Detailed state management patterns
- `orchestration/state-management.md` - State management and query patterns

---

## Delegation Depth Tracking

### Why Track Delegation Depth?

**Purpose**: Prevent infinite delegation loops and enforce architectural boundaries

**Limits**:
- Layer 1 → Layer 2: Depth 0 → 1 (orchestrator → command)
- Layer 2 → Layer 3: Depth 1 → 2 (command → subagent)
- Layer 3 → Layer 3: Depth 2 → 3 (subagent → subagent, rare)
- **Maximum Depth**: 3 (hard limit)

**Enforcement**:
- Each delegation increments depth
- Subagents check depth before delegating
- Depth > 3 triggers error

**Example**:
```
Orchestrator (depth 0)
  → /implement command (depth 1)
    → task-executor subagent (depth 2)
      → implementer subagent (depth 3)
        → STOP (max depth reached)
```

**See Also**:
- `orchestration/delegation.md` - Delegation patterns and depth tracking

---

## Error Handling

### Error Propagation

Errors propagate up through layers:

```
Layer 3: Subagent encounters error
  ↓
Layer 3: Return {status: "failed", errors: [...]}
  ↓
Layer 2: Command file receives error
  ↓
Layer 2: Decide: retry, fallback, or propagate
  ↓
Layer 2: Return error to orchestrator
  ↓
Layer 1: Orchestrator displays error to user
```

### Error Handling Strategies

**Layer 1 (Orchestrator)**:
- Unknown command → Display error, suggest alternatives
- Delegation failure → Display error, log for debugging

**Layer 2 (Command File)**:
- Argument parsing error → Display usage, return immediately
- Subagent failure → Retry (if transient), fallback (if alternative), or propagate
- Validation error → Display error, suggest fix

**Layer 3 (Subagent)**:
- Execution error → Return {status: "failed", errors: [...]}
- Partial success → Return {status: "partial", artifacts: [...]}
- Recoverable error → Include recovery recommendation

**Two-Level Error Logging**:
- **CRITICAL**: Errors that prevent task completion (logged to errors.json)
- **NON-CRITICAL**: Warnings or recoverable errors (logged but don't fail task)

**See Also**:
- `standards/error-handling.md` - Error handling patterns
- `workflows/preflight-postflight.md` - Error logging standards

---

## Workflow Patterns

### Common Workflow Patterns

**1. Simple Delegation** (one subagent):
```
Command → Subagent → Return
```
Example: `/research 197` → researcher → return report

**2. Sequential Delegation** (multiple subagents):
```
Command → Subagent A → Subagent B → Return
```
Example: `/plan 196` → planner → status-sync-manager → return plan

**3. Conditional Delegation** (branching):
```
Command → Validate → If valid: Subagent A, Else: Subagent B → Return
```
Example: `/revise` → Check mode → If plan: planner, Else: reviser → return

**4. Iterative Delegation** (loops):
```
Command → For each item: Subagent → Aggregate → Return
```
Example: `/todo` → For each task: status-sync-manager → return list

**5. Parallel Delegation** (concurrent):
```
Command → [Subagent A, Subagent B, Subagent C] → Aggregate → Return
```
Example: Multi-file implementation → [implementer × N] → return all

### Preflight/Postflight Pattern

**Preflight** (before work begins):
- Update task status to "in_progress"
- Log start time
- Validate preconditions

**Postflight** (after work completes):
- Update task status to "completed"
- Link artifacts to task
- Log completion time
- Return results

**Timing Requirements**:
- Preflight MUST occur BEFORE work begins
- Postflight MUST occur BEFORE returning to caller
- Status updates MUST be atomic (via status-sync-manager)

**See Also**:
- `workflows/preflight-postflight.md` - Detailed workflow standards
- `workflows/status-transitions.md` - Status transition rules

---

## Architectural Principles

### 1. Single Responsibility

Each layer has ONE responsibility:
- Layer 1: Route commands
- Layer 2: Orchestrate workflows
- Layer 3: Execute work

### 2. Separation of Concerns

Routing, workflow orchestration, and execution are separate:
- Routing logic in orchestrator
- Workflow logic in command files
- Execution logic in subagents

### 3. Standardized Interfaces

All subagents return standardized format:
- Enables composability
- Simplifies error handling
- Facilitates testing

### 4. Delegation Over Direct Execution

Command files delegate, never execute directly:
- Enables reuse
- Simplifies testing
- Improves modularity

### 5. State Centralization

All task state in state.json:
- Single source of truth
- Fast lookups
- Consistent state

### 6. Error Transparency

Errors propagate with context:
- Clear error messages
- Recovery recommendations
- Debugging information

### 7. Workflow Composability

Subagents are composable building blocks:
- Reusable across commands
- Testable independently
- Flexible combinations

---

## Meta-Builder Integration

### How Meta-Builder Uses This Architecture

The meta-builder (`/meta` command) uses this architecture documentation to:

1. **Understand System Structure**: Three-layer pattern guides system generation
2. **Generate Commands**: Command files follow Layer 2 pattern
3. **Generate Subagents**: Subagents follow Layer 3 pattern
4. **Ensure Consistency**: All generated components follow architectural principles

### Key Architecture Concepts for Meta-Builder

**Commands as Agents**:
- Commands are NOT just entry points
- Commands ARE agents with workflows
- Commands orchestrate, never execute directly

**Delegation Pattern**:
- Orchestrator → Command → Subagent
- Each layer has clear responsibility
- Depth tracking prevents loops

**Standardized Returns**:
- All subagents return same format
- Enables composability
- Simplifies aggregation

**State Management**:
- state.json is single source of truth
- Read/write separation
- Atomic updates via status-sync-manager

**See Also**:
- `formats/command-structure.md` - Command file anatomy
- `templates/command-template.md` - Command file template
- `templates/subagent-template.md` - Subagent template

---

## Common Mistakes and Correct Patterns

### ❌ Mistake 1: Orchestrator Parses Arguments

**Wrong**:
```markdown
## Orchestrator
User: /plan 196
Parse task_number = 196
Validate task exists
Delegate to planner
```

**Correct**:
```markdown
## Orchestrator
User: /plan 196
Identify command = "plan"
Delegate to .claude/command/plan.md with args = ["196"]
```

### ❌ Mistake 2: Command Executes Work Directly

**Wrong**:
```markdown
## Command File (plan.md)
Parse task_number = 196
Create implementation plan (write file directly)
Update state.json (write directly)
Return plan path
```

**Correct**:
```markdown
## Command File (plan.md)
Parse task_number = 196
Delegate to planner subagent
Delegate to status-sync-manager
Return plan path
```

### ❌ Mistake 3: Subagent Calls Other Subagents Directly

**Wrong**:
```markdown
## Subagent (planner)
Create plan
Call status-sync-manager directly
Return plan
```

**Correct**:
```markdown
## Subagent (planner)
Create plan
Return plan (let command file call status-sync-manager)
```

### ❌ Mistake 4: Skipping Delegation Depth Tracking

**Wrong**:
```markdown
## Subagent
Delegate to another subagent (no depth check)
```

**Correct**:
```markdown
## Subagent
Check delegation_depth < 3
If depth OK: Delegate to another subagent
Else: Return error "Max delegation depth exceeded"
```

---

## Future Enhancements

### Potential Improvements

1. **Parallel Delegation**: Enable concurrent subagent execution
2. **Delegation Tracing**: Visualize delegation chains
3. **Performance Monitoring**: Track delegation overhead
4. **Adaptive Routing**: Route based on system load
5. **Workflow Caching**: Cache common workflow results

### Backward Compatibility

Any architectural changes MUST:
- Preserve three-layer pattern
- Maintain standardized return format
- Keep state.json as single source of truth
- Support existing commands and subagents

---

## Summary

project's three-layer delegation pattern provides:

✅ **Clear Separation**: Routing, orchestration, execution are separate  
✅ **Flexibility**: Workflows compose reusable subagents  
✅ **Robustness**: Errors handled at appropriate layers  
✅ **Testability**: Each layer tested independently  
✅ **Performance**: State.json optimization enables fast lookups  
✅ **Consistency**: Standardized interfaces across all subagents  
✅ **Observability**: Clear delegation chains and error propagation

**Key Takeaway**: Commands are agents with workflows, not just entry points. This pattern enables project to build complex, robust, and maintainable automation systems.

---

**Related Documentation**:
- `formats/command-structure.md` - Command file anatomy and patterns
- `orchestration/delegation.md` - Delegation patterns and depth tracking
- `orchestration/routing.md` - Routing logic and patterns
- `orchestration/state-management.md` - State management and optimization
- `workflows/preflight-postflight.md` - Workflow timing standards
- `standards/error-handling.md` - Error handling patterns
- `templates/command-template.md` - Command file template
- `templates/subagent-template.md` - Subagent template
