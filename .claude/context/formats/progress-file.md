# Progress File Schema

## Overview

Progress files enable incremental tracking of work within implementation phases. They serve two purposes:
1. **Resume point identification**: When a teammate exhausts context or is interrupted
2. **Handoff context**: Successor teammates can see exactly what was completed vs pending

**Design Principle**: Progress is tracked at the objective level, not the step level. This provides meaningful checkpoints without excessive overhead.

## File Location

```
specs/{N}_{SLUG}/progress/phase-{P}-progress.json
```

Where:
- `{N}` = Task number (unpadded)
- `{SLUG}` = Task slug in snake_case
- `{P}` = Phase number (unpadded)

Example: `specs/259_configure_feature/progress/phase-3-progress.json`

## Directory Structure

```
specs/{N}_{SLUG}/
├── reports/          # Research reports
├── plans/            # Implementation plans
├── summaries/        # Implementation summaries
├── handoffs/         # Handoff artifacts
└── progress/         # Progress tracking files
    ├── phase-1-progress.json
    ├── phase-2-progress.json
    └── phase-3-progress.json
```

## Schema

```json
{
  "phase": 3,
  "phase_name": "Implement validation framework",
  "started_at": "2026-02-12T10:30:00Z",
  "last_updated": "2026-02-12T11:45:00Z",
  "objectives": [
    {
      "id": 1,
      "description": "Define ValidationResult type",
      "status": "done"
    },
    {
      "id": 2,
      "description": "Implement field validators",
      "status": "in_progress",
      "note": "3 of 5 validators completed (string, number, boolean)"
    },
    {
      "id": 3,
      "description": "Integrate with main handler",
      "status": "not_started"
    }
  ],
  "current_objective": 2,
  "approaches_tried": [
    {
      "approach": "Regex-based string validation",
      "result": "failed",
      "reason": "Performance issues with complex patterns on large inputs"
    },
    {
      "approach": "Use existing validation library",
      "result": "partial",
      "reason": "Works for basic types but needs custom extensions for domain types"
    }
  ],
  "handoff_count": 0
}
```

## Field Specifications

### phase (required)

**Type**: integer
**Description**: Phase number matching the plan file

### phase_name (required)

**Type**: string
**Description**: Human-readable phase name from the plan

### started_at (required)

**Type**: string (ISO8601)
**Description**: Timestamp when work on this phase began

### last_updated (required)

**Type**: string (ISO8601)
**Description**: Timestamp of last progress update

### objectives (required)

**Type**: array of objects
**Description**: Ordered list of objectives within the phase

Each objective:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | Yes | Unique identifier within phase (1-indexed) |
| `description` | string | Yes | Brief description of the objective |
| `status` | string | Yes | `not_started`, `in_progress`, `done`, `blocked` |
| `note` | string | No | Additional context (partial completion, blockers) |

**Immutability**: Objective `id` and `description` are immutable once created. Only `status` and `note` change during execution.

### current_objective (required)

**Type**: integer
**Description**: ID of the objective currently being worked on (or next to start)

### approaches_tried (optional)

**Type**: array of objects
**Description**: Log of attempted approaches and their outcomes

Each approach:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `approach` | string | Yes | Brief description of what was tried |
| `result` | string | Yes | `failed`, `partial`, `blocked` |
| `reason` | string | Yes | Why it didn't fully succeed |

**Purpose**: Prevents successor teammates from retrying approaches that already failed.

### handoff_count (required)

**Type**: integer
**Description**: Number of times this phase has been handed off due to context exhaustion

## Update Protocol

Teammates should update the progress file:

1. **When starting a phase**: Create the file with objectives from the plan
2. **After completing each objective**: Set status to `done`, update `current_objective`
3. **When an approach fails**: Add to `approaches_tried`
4. **Before writing handoff**: Ensure progress file reflects current state
5. **On handoff**: Increment `handoff_count`

## Progress File Lifecycle

```
Phase Start
    │
    ▼
┌─────────────────────┐
│ Create progress file│
│ with all objectives │
│ as not_started      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ For each objective: │
│ 1. Mark in_progress │
│ 2. Do work          │
│ 3. Mark done        │
│ 4. Update file      │
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
    ▼             ▼
┌────────┐  ┌────────────────┐
│Complete│  │Context exhaust │
│ phase  │  │Write handoff   │
└────────┘  │Increment count │
            └────────────────┘
```

## Integration with Handoff

When writing a handoff document, reference the progress file:

```markdown
## Current State
- **File**: ...
- **Progress**: `specs/259_configure_feature/progress/phase-3-progress.json`
  - Objectives 1-2 done, objective 3 in_progress
```

The successor reads the progress file to understand exactly what was completed.

## Example: Implementation Progress

```json
{
  "phase": 3,
  "phase_name": "Implement validation framework",
  "started_at": "2026-02-12T10:30:00Z",
  "last_updated": "2026-02-12T12:15:00Z",
  "objectives": [
    {
      "id": 1,
      "description": "Define ValidationResult type and error codes",
      "status": "done"
    },
    {
      "id": 2,
      "description": "Implement field validators for primitive types",
      "status": "done"
    },
    {
      "id": 3,
      "description": "Implement field validators for domain types",
      "status": "in_progress",
      "note": "Date and URL validators done, custom type validators remaining"
    },
    {
      "id": 4,
      "description": "Integrate validators with main handler",
      "status": "not_started"
    }
  ],
  "current_objective": 3,
  "approaches_tried": [
    {
      "approach": "Use closure-based validator factory",
      "result": "failed",
      "reason": "Lost type information needed for error messages"
    },
    {
      "approach": "Use table-based validator registry",
      "result": "partial",
      "reason": "Works for primitives, need adaptation for domain types"
    }
  ],
  "handoff_count": 1
}
```

## Related Documentation

- [Handoff Artifact Schema](handoff-artifact.md) - Handoff document schema
- [Return Metadata Format](return-metadata-file.md) - Metadata schema
- [Artifact Formats Rule](../../rules/artifact-formats.md) - Overall artifact conventions
