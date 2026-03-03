# Checkpoint Execution Pattern

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Quick reference for command checkpoint-based execution
**Audience**: Command developers, skill implementers

---

## Overview

All workflow commands (/research, /plan, /implement, /revise) follow a three-checkpoint pattern that ensures consistent execution, traceability, and error recovery.

---

## Checkpoint Model

```
┌──────────────────────────────────────────────────────────────┐
│  CHECKPOINT 1    -->    STAGE 2    -->    CHECKPOINT 2    -->│
│   GATE IN               DELEGATE          GATE OUT           │
│  (Preflight)          (Skill/Agent)     (Postflight)         │
│                                                    |         │
│                                             CHECKPOINT 3     │
│                                               COMMIT         │
└──────────────────────────────────────────────────────────────┘
```

---

## Checkpoint 1: GATE IN (Preflight)

**Purpose**: Validate preconditions and prepare for execution.

**Operations**:
1. Generate session_id: `sess_{timestamp}_{random}`
2. Validate task exists in specs/state.json
3. Validate current status allows operation
4. Update status to "in_progress" variant
5. PROCEED or ABORT

**Status Transitions**:
| Command | From Status | To Status |
|---------|-------------|-----------|
| /research | not_started, researched | researching |
| /plan | researched | planning |
| /implement | planned, implementing | implementing |
| /revise | planned, researched | planning |

**Session ID Generation**:
```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

---

## Stage 2: DELEGATE

**Purpose**: Route to appropriate skill/agent and execute work.

**Operations**:
1. Determine target skill by language
2. Prepare delegation context (session_id, depth, path)
3. Invoke skill
4. Skill invokes agent via Task tool
5. Agent creates artifacts
6. Return structured result (JSON or metadata file)

**Language Routing**:
| Language | Research | Planning | Implementation |
|----------|----------|----------|----------------|
| lean | skill-lean-research | skill-planner | skill-lean-implementation |
| general | skill-researcher | skill-planner | skill-implementer |
| meta | skill-researcher | skill-planner | skill-implementer |
| latex | skill-researcher | skill-planner | skill-latex-implementation |

---

## Checkpoint 2: GATE OUT (Postflight)

**Purpose**: Validate results and update state.

**Operations**:
1. Validate return structure (JSON schema)
2. Verify artifacts exist on disk
3. Update status to success variant
4. Link artifacts to task in specs/state.json
5. Update specs/TODO.md with artifact links
6. PROCEED, RETRY, or PARTIAL

**Status Transitions**:
| Command | From Status | To Status |
|---------|-------------|-----------|
| /research | researching | researched |
| /plan | planning | planned |
| /implement | implementing | completed |

**Idempotency Check**:
Before adding artifact links, check if already present:
```bash
existing=$(jq -r ".active_projects[] | select(.project_number == $task_number) | .artifacts[] | select(.path == \"$artifact_path\")" specs/state.json)
if [ -z "$existing" ]; then
    # Add artifact link
fi
```

---

## Checkpoint 3: COMMIT

**Purpose**: Finalize operation with git commit.

**Operations**:
1. Stage all changes: `git add -A`
2. Create commit with session_id
3. Handle commit failure (non-blocking)
4. Return final result to user

**Commit Message Format**:
```
task {N}: {action}

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

**Action Values**:
| Command | Action |
|---------|--------|
| /research | complete research |
| /plan | create implementation plan |
| /implement | complete implementation |
| /implement (phase) | phase {P}: {phase_name} |

---

## Error Handling

### GATE IN Failure
- Task not found: Return error immediately
- Invalid status: Return error with current status
- Validation failure: Do not proceed to DELEGATE

### DELEGATE Failure
- Agent timeout: Return partial status
- Agent error: Pass through error to GATE OUT
- Keep status in "in_progress" variant

### GATE OUT Failure
- Missing artifacts: Log warning, return partial
- State update failure: Log error, artifacts still exist
- Keep operation recoverable

### COMMIT Failure
- Git error: Log but don't fail operation
- Artifacts and state already updated
- Non-blocking

---

## Implementation in Skills

Skills that manage lifecycle include checkpoints inline:

```markdown
## Execution

### 0. Preflight (GATE IN)
Update task status before starting work.
See: @.opencode/context/core/checkpoints/checkpoint-gate-in.md

### 1-4. Agent Delegation (DELEGATE)
Invoke subagent and execute work.

### 5. Postflight (GATE OUT)
Update task status after completion.
See: @.opencode/context/core/checkpoints/checkpoint-gate-out.md

### 6. Return
Return result (COMMIT happens in caller).
```

---

## Session Tracking

Session ID links all operations in a single command execution:

| Location | Purpose |
|----------|---------|
| GATE IN | Generated, stored |
| DELEGATE | Passed to skill/agent |
| Agent Metadata | Returned in metadata.session_id |
| GATE OUT | Verified match |
| COMMIT | Included in commit message |
| errors.json | Logged for traceability |

---

## Related Documentation

- @.opencode/context/core/checkpoints/ - Detailed checkpoint specifications
- @.opencode/context/core/patterns/skill-lifecycle.md - Skill lifecycle pattern
- @.opencode/context/core/patterns/inline-status-update.md - Status update patterns
- @.opencode/rules/git-workflow.md - Git commit conventions
