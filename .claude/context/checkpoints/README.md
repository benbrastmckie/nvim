# Checkpoint-Based Execution Model

This directory defines the three-gate checkpoint model for command execution.

## Overview

Every command (/research, /plan, /implement, /revise) follows a three-checkpoint pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                     COMMAND EXECUTION                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  CHECKPOINT 1│    │    STAGE 2   │    │  CHECKPOINT 2│  │
│  │   GATE IN    │───▶│   DELEGATE   │───▶│   GATE OUT   │  │
│  │  (Preflight) │    │  (Skill/Agent)│   │ (Postflight) │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                                        │          │
│         │                                        ▼          │
│         │                              ┌──────────────┐     │
│         │                              │  CHECKPOINT 3│     │
│         │                              │    COMMIT    │     │
│         │                              │(Finalization)│     │
│         │                              └──────────────┘     │
│         │                                        │          │
│         │                                        ▼          │
│         │                              ┌──────────────┐     │
│         └────────────ABORT────────────▶│   RETURN     │     │
│                                        └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Checkpoints

### GATE IN (checkpoint-gate-in.md)
- Generate session ID for traceability
- Validate task exists and status allows operation
- Update status to in-progress variant
- ABORT or PROCEED

### DELEGATE (command-specific)
- Route to appropriate skill by language
- Pass session_id and context
- Receive structured return

### GATE OUT (checkpoint-gate-out.md)
- Validate return structure
- Verify artifacts exist on disk
- Update status to completed variant
- Link artifacts with idempotency check
- PROCEED, RETRY, or PARTIAL

### COMMIT (checkpoint-commit.md)
- Git commit with session metadata
- Non-blocking error handling
- Return final result

## Session ID

Format: `sess_{unix_timestamp}_{6_char_random}`

Example: `sess_1736700000_a1b2c3`

Generated at GATE IN, passed through entire operation, included in git commit for traceability.

## Benefits

1. **Consistency**: All commands follow identical patterns
2. **Traceability**: Session IDs link all actions in a single operation
3. **Recovery**: Each checkpoint can be verified independently
4. **Idempotency**: Artifact linking checks prevent duplicates
5. **Debugging**: Session ID in commits enables operation reconstruction

## Files

- `checkpoint-gate-in.md` - Preflight validation and status update
- `checkpoint-gate-out.md` - Postflight validation and artifact linking
- `checkpoint-commit.md` - Git commit and finalization
- `README.md` - This overview

## Usage

Commands reference these checkpoints instead of duplicating patterns:

```markdown
### CHECKPOINT 1: GATE IN
Execute checkpoint-gate-in.md with:
- task_number: {N}
- target_status: researching

### STAGE 2: DELEGATE
Invoke skill-researcher with session context.

### CHECKPOINT 2: GATE OUT
Execute checkpoint-gate-out.md with skill return.

### CHECKPOINT 3: COMMIT
Execute checkpoint-commit.md with operation: research.
```
