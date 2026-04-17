# Orchestrator Design

**Created**: 2025-12-29
**Purpose**: Document the smart coordinator pattern and orchestrator architecture

---

> **DEPRECATED** (2026-01-19): This file has been consolidated into:
> - `orchestration-core.md` - Session tracking, delegation safety, return format, routing
> - `orchestration-reference.md` - Examples and troubleshooting
>
> This file is preserved for reference but should not be loaded for new development.

---

## Design Philosophy

The orchestrator is a **smart coordinator**, not a workflow executor. It handles:
- **Preflight**: Validation and safety checks
- **Routing**: Language extraction and agent selection
- **Delegation**: Context preparation and agent invocation
- **Postflight**: Return validation and cleanup

It does NOT handle:
- Workflow execution (delegated to agents)
- Status updates (delegated to status-sync-manager)
- Git commits (delegated to git-workflow-manager)
- Business logic (delegated to domain agents)

---

## Seven-Stage Workflow

### Stage 1: ParseCommand
**Purpose**: Extract command name and arguments from user input

**Actions**:
- Parse command name (e.g., "plan", "research", "implement")
- Extract arguments (task number, flags, prompts)
- Validate argument format

**Output**: Parsed command and arguments

---

### Stage 2: PreflightValidation
**Purpose**: Validate request before delegation

**Checks**:
- Task number is valid integer
- Task exists in TODO.md
- Delegation depth < 3
- No cycles in delegation path
- Session ID is unique

**Output**: Validation result (pass/fail)

**On Failure**: Return error immediately, don't delegate

---

### Stage 3: DetermineRouting
**Purpose**: Determine target agent based on command configuration

**For Task-Type-Based Routing** (routing.task_type_based: true):
1. Extract language from state.json (fast lookup):
   ```bash
   # Lookup task in state.json (8x faster than TODO.md)
   task_data=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber))' \
     specs/state.json)
   
   # Extract language
   task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
   ```
   
   **Performance**: ~12ms for state.json vs ~100ms for TODO.md (8x faster)

2. Map language to agent:
   - /research: Extension type → extension agent, default → general-research-agent
   - /implement: Extension type → extension agent, default → general-implementation-agent

**For Direct Routing** (routing.task_type_based: false):
- Use routing.target_agent from command frontmatter
- Examples: /plan → planner, /revise → reviser

**Output**: Target agent name

**Note**: Command files now use state.json for all task lookups. See `state-management.md` for patterns.

---

### Stage 4: PrepareContext
**Purpose**: Prepare delegation context for agent

**Actions**:
- Generate unique session ID (sess_{timestamp}_{random_6char})
- Build delegation context:
  ```json
  {
    "session_id": "sess_1735460684_a1b2c3",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "{command}", "{agent}"],
    "timeout": 3600,
    "task_context": {
      "task_number": 244,
      "description": "...",
      "task_type": "general"
    }
  }
  ```
- Register session in delegation registry
- Set timeout deadline

**Output**: Delegation context

---

### Stage 5: InvokeAgent
**Purpose**: Delegate to target agent

**Actions**:
- Load agent file (.claude/agent/subagents/{agent}.md)
- Invoke agent with delegation context
- Wait for agent return (with timeout)

**Output**: Agent return object

**On Timeout**: Return partial status with timeout error

---

### Stage 6: ValidateReturn
**Purpose**: Validate agent return format

**Checks**:
- Return is valid JSON
- Required fields present (status, summary, artifacts, metadata, session_id)
- Status is valid enum (completed|partial|failed|blocked)
- session_id matches expected
- Summary <100 tokens
- Artifacts exist on disk (if status=completed)

**Output**: Validation result

**On Failure**: Log error, return failed status

---

### Stage 7: PostflightCleanup
**Purpose**: Cleanup and format final return

**Actions**:
- Remove session from delegation registry
- Format return for user
- Log completion to session log

**Output**: Final return to user

---

## Context Budget

The orchestrator maintains a minimal context budget:

**Budget**: <5% of context window (~10KB)

**Always Loaded**:
- core/system/routing-guide.md (~9KB)
- core/workflows/delegation-guide.md (~2KB)

**Total**: ~11KB (within budget)

This enables the orchestrator to:
- Make routing decisions
- Enforce delegation safety
- Validate returns

Without loading:
- Domain-specific knowledge (loaded by agents)
- Workflow details (owned by agents)
- Business logic (owned by agents)

---

## Language Extraction Logic

### Priority 1: Project state.json
**Path**: `specs/{task_number}_{slug}/state.json`

**Field**: `language`

**Example**:
```json
{
  "task_number": 244,
  "task_type": "general",
  ...
}
```

**When to use**: Task has project directory with state.json

---

### Priority 2: TODO.md
**Path**: `specs/TODO.md`

**Field**: `**Task Type**:` in task entry

**Example**:
```markdown
### 244. Implement feature X
- **Task Type**: general
```

**When to use**: Task exists in TODO.md (always)

---

### Priority 3: Default
**Value**: "general"

**When to use**: Language not found in state.json or TODO.md (rare)

---

## Routing Configuration

Commands specify routing in frontmatter:

### Direct Routing
```yaml
routing:
  language_based: false
  target_agent: planner
```

**Used by**: /plan, /revise, /review, /todo, /task

---

### Task-Type-Based Routing
```yaml
routing:
  task_type_based: true
  default: general-research-agent
```

**Used by**: /research, /implement

---

## Delegation Safety

### Cycle Detection
Before delegating, check if target agent is in delegation_path:

```
delegation_path: ["orchestrator", "implement", "task-executor"]
target: "task-executor"
Result: ❌ CYCLE DETECTED - Block delegation
```

### Depth Limits
Maximum delegation depth: 3 levels

```
Level 0: User → Orchestrator
Level 1: Orchestrator → Command → Agent
Level 2: Agent → Utility (status-sync-manager, git-workflow-manager)
Level 3: Utility → Sub-Utility (rare)
```

### Timeout Enforcement
All delegations have timeouts:

| Command | Default Timeout | Max Timeout |
|---------|----------------|-------------|
| /research | 3600s (1 hour) | 7200s (2 hours) |
| /plan | 1800s (30 min) | 3600s (1 hour) |
| /implement | 7200s (2 hours) | 14400s (4 hours) |

---

## Validation Strategy

### What Orchestrator Validates
✅ Task exists in TODO.md  
✅ Task number format  
✅ Delegation safety (cycles, depth)  
✅ Return format (JSON schema)  
✅ Session ID match  

### What Orchestrator Does NOT Validate
❌ Plan exists (agent concern)  
❌ Research complete (agent concern)  
❌ File permissions (agent concern)  
❌ Domain rules (agent concern)  
❌ Artifact format (agent concern)  

See `core/system/validation-strategy.md` for detailed philosophy.

---

## Error Handling

### Validation Errors
**When**: Preflight validation fails  
**Action**: Return error immediately, don't delegate  
**Example**: "Task 999 not found in TODO.md"

### Agent Errors
**When**: Agent returns failed status  
**Action**: Return agent error to user  
**Example**: "Plan already exists at path/to/plan.md"

### Timeout Errors
**When**: Agent doesn't return within timeout  
**Action**: Return partial status with timeout error  
**Example**: "Implementation timed out after 7200s"

---

## Session Tracking

### Session ID Format
```
sess_{timestamp}_{random_6char}
Example: sess_1735460684_a1b2c3
```

### Delegation Registry
In-memory registry of active sessions:

```json
{
  "sess_1735460684_a1b2c3": {
    "command": "implement",
    "subagent": "task-executor",
    "task_number": 191,
    "start_time": "2025-12-26T10:00:00Z",
    "timeout": 7200,
    "deadline": "2025-12-26T12:00:00Z",
    "status": "running",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "task-executor"]
  }
}
```

Updated in Stage 4 (PrepareContext) and Stage 7 (PostflightCleanup).

---

## Design Principles

### 1. Minimal Context
Orchestrator loads <5% context window to stay lightweight

### 2. Smart Coordination
Handles preflight/postflight, delegates workflow execution

### 3. Language Awareness
Extracts language and routes to appropriate agents

### 4. Safety First
Enforces delegation safety (cycles, depth, timeouts)

### 5. Validation Boundaries
Validates structure, not business logic

### 6. Agent Ownership
Agents own workflows, orchestrator just coordinates

---

## Related Documentation

- `.claude/context/orchestration/routing.md` - Routing rules and language mapping
- `.claude/context/orchestration/delegation.md` - Delegation safety patterns
- `.claude/context/orchestration/validation.md` - Validation philosophy
- `.claude/context/formats/subagent-return.md` - Return format standard
# Orchestrator Guide - Examples and Troubleshooting

**Created**: 2025-12-29 (Task 245 Phase 5)  
**Purpose**: Examples, troubleshooting, and detailed guidance for orchestrator usage

---

## Overview

This guide provides detailed examples and troubleshooting information for the orchestrator router pattern. The orchestrator itself is simplified to ~80 lines focusing on routing logic. This guide contains the supporting documentation.

**Related Files**:
- `.claude/context/orchestration/routing.md` - Command-to-Agent mapping
- `.claude/context/orchestration/delegation.md` - Delegation safety
- `.claude/context/formats/subagent-return.md` - Return validation

---

## Delegation Registry

### Purpose

The delegation registry tracks all active delegations in memory for monitoring, timeout enforcement, and debugging.

### Schema

```javascript
{
  "sess_20251226_abc123": {
    "session_id": "sess_20251226_abc123",
    "command": "implement",
    "subagent": "task-executor",
    "task_number": 191,
    "task_type": "markdown",
    "start_time": "2025-12-26T10:00:00Z",
    "timeout": 3600,
    "deadline": "2025-12-26T11:00:00Z",
    "status": "running",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "task-executor"],
    
    // Command stage tracking (workflow commands only)
    "is_command": true,
    "command_stages": {
      "current_stage": 4,
      "stages_completed": [1, 2, 3],
      "stage_7_completed": false,
      "stage_7_artifacts": {
        "status_sync_manager_invoked": false,
        "status_sync_manager_completed": false,
        "todo_md_updated": false,
        "state_json_updated": false,
        "git_commit_created": false
      }
    }
  }
}
```

**Note**: `command_stages` tracking is only populated for workflow commands (plan, research, implement, revise). For direct subagent delegations, `is_command = false` and `command_stages` is omitted.

### Operations

| Operation | When | Purpose |
|-----------|------|---------|
| Register | Delegation start | Add entry to registry with session_id |
| Monitor | Periodic (every 60s) | Check for timeouts, update status |
| Update | Status changes | Update delegation status field |
| Complete | Delegation completion | Mark as completed, optionally remove |
| Cleanup | Timeout or error | Remove from registry, log error |

### Example: Register Delegation

```javascript
function register_delegation(session_id, context) {
  registry[session_id] = {
    "session_id": session_id,
    "command": context.command,
    "subagent": context.target_agent,
    "task_number": context.task_number,
    "task_type": context.task_type,
    "start_time": new Date().toISOString(),
    "timeout": context.timeout,
    "deadline": new Date(Date.now() + context.timeout * 1000).toISOString(),
    "status": "running",
    "delegation_depth": context.delegation_depth,
    "delegation_path": context.delegation_path,
    "is_command": context.is_command || false
  };
  
  if (context.is_command) {
    registry[session_id].command_stages = {
      "current_stage": 1,
      "stages_completed": [],
      "stage_7_completed": false,
      "stage_7_artifacts": {
        "status_sync_manager_invoked": false,
        "status_sync_manager_completed": false,
        "todo_md_updated": false,
        "state_json_updated": false,
        "git_commit_created": false
      }
    };
  }
}
```

### Example: Monitor Timeouts

```javascript
function monitor_delegations() {
  const now = new Date();
  
  for (const [session_id, delegation] of Object.entries(registry)) {
    if (delegation.status !== "running") continue;
    
    const deadline = new Date(delegation.deadline);
    if (now > deadline) {
      handle_timeout(session_id, delegation);
    }
  }
}

function handle_timeout(session_id, delegation) {
  delegation.status = "timeout";
  
  log_error({
    "type": "timeout",
    "session_id": session_id,
    "command": delegation.command,
    "subagent": delegation.subagent,
    "timeout": delegation.timeout,
    "task_number": delegation.task_number
  });
  
  // Check for partial artifacts
  const partial_artifacts = check_for_artifacts(delegation.task_number);
  
  // Return timeout error to user
  return_timeout_error(session_id, partial_artifacts);
  
  // Remove from registry
  delete registry[session_id];
}
```

---

## Cycle Detection

### Purpose

Prevent infinite delegation loops by tracking delegation paths and enforcing maximum depth.

### Maximum Depth

**Limit**: 3 levels

**Depth Counting**:
- Orchestrator → Command: depth = 0 (not counted)
- Command → Subagent: depth = 1
- Subagent → Specialist: depth = 2
- Specialist → Helper: depth = 3 (max)
- Helper → Another Agent: **BLOCKED** (exceeds limit)

### Detection Logic

```javascript
function check_cycle(delegation_path, target_agent) {
  // Check if target already in path (cycle)
  if (delegation_path.includes(target_agent)) {
    throw new CycleError(
      `Cycle detected: ${delegation_path.join(" → ")} → ${target_agent}`
    );
  }
  
  // Check depth limit
  if (delegation_path.length >= 3) {
    throw new DepthError(
      `Max delegation depth (3) exceeded: ${delegation_path.join(" → ")}`
    );
  }
  
  return false;
}
```

### Example: Valid Delegation Chain

```
Orchestrator → /implement → task-executor → implementer → git-workflow-manager
    (depth 0)      (depth 1)      (depth 2)       (depth 3)
                                                   ↑ MAX DEPTH
```

### Example: Blocked Delegation

```
Orchestrator → /implement → task-executor → implementer → git-workflow-manager → ???
    (depth 0)      (depth 1)      (depth 2)       (depth 3)         (BLOCKED)
```

**Error**: "Max delegation depth (3) exceeded"

---

## Session Tracking

### Purpose

Unique session IDs enable tracking, debugging, and validation of delegation chains.

### Format

`sess_{timestamp}_{random_6char}`

**Example**: `sess_1703606400_a1b2c3`

### Generation

```javascript
function generate_session_id() {
  const timestamp = Math.floor(Date.now() / 1000);
  const random_chars = Array.from({length: 6}, () => 
    '0123456789abcdefghijklmnopqrstuvwxyz'[Math.floor(Math.random() * 36)]
  ).join('');
  
  return `sess_${timestamp}_${random_chars}`;
}
```

### Usage

1. **Generate** before invoking subagent
2. **Pass** to subagent in delegation context
3. **Validate** in subagent return metadata
4. **Track** in delegation registry
5. **Log** for debugging and error tracking

---

## Timeout Enforcement

### Purpose

Prevent indefinite hangs by enforcing timeouts on all delegations with partial result recovery.

### Default Timeouts

| Operation | Timeout | Justification |
|-----------|---------|---------------|
| Research | 3600s (1 hour) | Research can be extensive |
| Planning | 1800s (30 min) | Planning is structured |
| Implementation | 7200s (2 hours) | Most complex, multiple phases |
| Simple operations | 300s (5 min) | Quick operations |

### Timeout Handling

```javascript
try {
  result = invoke_subagent(timeout=3600);
} catch (TimeoutError) {
  // Graceful degradation
  partial_results = check_for_artifacts();
  
  return {
    "status": "partial",
    "summary": "Operation timed out after 3600s",
    "artifacts": partial_results,
    "errors": [{
      "type": "timeout",
      "message": "Subagent exceeded timeout",
      "code": "TIMEOUT",
      "recoverable": true,
      "recommendation": "Resume with same command to continue"
    }]
  };
}
```

### Principles

- Never wait indefinitely
- Return partial results if available
- Mark task as IN PROGRESS (not failed)
- Provide actionable recovery message

---

## Return Validation

### Purpose

Validate all subagent returns against standardized format to ensure consistent parsing.

### Validation Steps

1. Check return is valid JSON/structured format
2. Validate against `subagent-return.md` schema
3. Check session_id matches expected
4. Validate all required fields present
5. Check status is valid enum value
6. Validate summary within length limits
7. Validate artifacts have valid paths

### Validation Logic

```javascript
function validate_return(return_obj, expected_session_id) {
  // 1. Check JSON structure
  if (typeof return_obj !== 'object') {
    throw new ValidationError("Return must be JSON object");
  }
  
  // 2. Check required fields
  const required = ["status", "summary", "artifacts", "metadata"];
  for (const field of required) {
    if (!(field in return_obj)) {
      throw new ValidationError(`Missing required field: ${field}`);
    }
  }
  
  // 3. Validate status
  const valid_statuses = ["completed", "failed", "partial", "blocked"];
  if (!valid_statuses.includes(return_obj.status)) {
    throw new ValidationError(`Invalid status: ${return_obj.status}`);
  }
  
  // 4. Check session ID
  const actual_session = return_obj.metadata.session_id;
  if (actual_session !== expected_session_id) {
    throw new ValidationError(
      `Session ID mismatch: ${actual_session} != ${expected_session_id}`
    );
  }
  
  // 5. Validate summary length
  const summary = return_obj.summary;
  if (summary.length === 0) {
    throw new ValidationError("Summary cannot be empty");
  }
  if (summary.length > 500) {
    throw new ValidationError("Summary too long (max 500 chars)");
  }
  
  return true;
}
```

### Validation Failure Handling

If validation fails:
1. Log validation error with details
2. Return failed status
3. Include original return for debugging
4. Recommend subagent fix

---

## Troubleshooting

### Symptom: Delegation Hangs

**Cause**: Missing timeout or return validation

**Fix**:
1. Check timeout is set (default 3600s)
2. Verify subagent returns standardized format
3. Check session_id tracking
4. Enable delegation registry monitoring

### Symptom: Infinite Loop

**Cause**: Cycle in delegation path

**Fix**:
1. Enable cycle detection
2. Check delegation_path before routing
3. Verify depth limit enforced (max 3)
4. Log delegation paths for debugging

### Symptom: Timeout Too Short/Long

**Cause**: Incorrect timeout for operation type

**Fix**:
1. Adjust timeout based on operation:
   - Research: 3600s (1 hour)
   - Planning: 1800s (30 min)
   - Implementation: 7200s (2 hours)
2. Make timeout configurable per command
3. Monitor actual durations and adjust

### Symptom: Return Validation Failures

**Cause**: Subagent not following standard format

**Fix**:
1. Update subagent to follow subagent-return.md
2. Add validation before returning
3. Test subagent independently
4. Check session_id matches

### Symptom: Stage 7 Not Executing

**Cause**: Command skips postflight stage

**Fix**:
1. Check command_stages tracking in registry
2. Verify stage_7_completed flag
3. Check status-sync-manager invocation
4. Validate TODO.md and state.json updates

### Symptom: Wrong Agent Routed

**Cause**: Language extraction failed or routing logic incorrect

**Fix**:
1. Verify language extracted from TODO.md
2. Check routing-guide.md for correct mapping
3. Log routing decision for debugging
4. Validate task_type field in task entry

---

## Examples

### Example 1: Simple Research Delegation

```
User: /research 197

Orchestrator:
1. Load command file: .claude/command/research.md
2. Extract task_type from state.json: "general"
3. Route to: general-research-agent
4. Generate session_id: sess_1703606400_a1b2c3
5. Register delegation in registry
6. Invoke general-research-agent with context
7. Monitor timeout (3600s)
8. Receive return, validate format
9. Complete delegation, remove from registry
10. Return success to user
```

### Example 2: Phased Implementation with Timeout

```
User: /implement 191

Orchestrator:
1. Load command file: .claude/command/implement.md
2. Extract language from TODO.md: "markdown"
3. Check for plan: Yes (plan-001.md)
4. Route to: task-executor
5. Generate session_id: sess_1703606401_d4e5f6
6. Register delegation in registry
7. Invoke task-executor with plan_path
8. Monitor timeout (7200s)
9. Timeout after 3600s (phase 2 incomplete)
10. Check for partial artifacts: phase 1 complete
11. Return partial status with resume instructions
12. Keep delegation in registry as "partial"
```

### Example 3: Cycle Detection

```
User: /implement 192 (complex delegation chain)

Orchestrator:
1. Load command file: .claude/command/implement.md
2. Route to: task-executor
3. task-executor delegates to: implementer
4. implementer delegates to: git-workflow-manager
5. git-workflow-manager attempts to delegate to: task-executor
6. Cycle detected: ["orchestrator", "implement", "task-executor", "implementer", "git-workflow-manager", "task-executor"]
7. Block delegation, return error
8. Error: "Cycle detected: orchestrator → implement → task-executor → implementer → git-workflow-manager → task-executor"
```

---

## Related Documentation

- **Routing Guide**: `.claude/context/orchestration/routing.md`
- **Delegation Guide**: `.claude/context/orchestration/delegation.md`
- **Return Format**: `.claude/context/formats/subagent-return.md`
- **Command Lifecycle**: `.claude/context/workflows/command-lifecycle.md`
