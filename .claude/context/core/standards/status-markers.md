# Status Markers Convention

**Status**: Active  
**Created**: 2026-01-05  
**Purpose**: Single source of truth for status markers across TODO.md and state.json

---

## Overview

This document defines the complete set of status markers used throughout the ProofChecker project for tracking task and phase progress. It serves as the authoritative reference for:

- **Status Marker Definitions**: All valid status markers and their meanings
- **TODO.md Format**: How markers appear in TODO.md task entries
- **state.json Format**: How status values appear in state.json
- **Valid Transitions**: Which status changes are allowed
- **Command Mappings**: Which commands trigger which status changes

---

## Status Marker Definitions

### Standard Status Markers

#### `[NOT STARTED]`
**TODO.md Format**: `- **Status**: [NOT STARTED]`  
**state.json Value**: `"status": "not_started"`  
**Meaning**: Task or phase has not yet begun.

**Valid Transitions**:
- `[NOT STARTED]` → `[RESEARCHING]` (research begins)
- `[NOT STARTED]` → `[PLANNING]` (planning begins, skip research)
- `[NOT STARTED]` → `[IMPLEMENTING]` (implementation begins, skip research and planning)
- `[NOT STARTED]` → `[BLOCKED]` (blocked before starting)

#### `[RESEARCHING]`
**TODO.md Format**: `- **Status**: [RESEARCHING]`  
**state.json Value**: `"status": "researching"`  
**Meaning**: Research is actively underway.

**Valid Transitions**:
- `[RESEARCHING]` → `[RESEARCHED]` (research completes successfully)
- `[RESEARCHING]` → `[BLOCKED]` (research encounters blocker)
- `[RESEARCHING]` → `[ABANDONED]` (research is abandoned)

**Timestamps**: Always include `- **Researched**: YYYY-MM-DD` when started

#### `[RESEARCHED]`
**TODO.md Format**: `- **Status**: [RESEARCHED]`  
**state.json Value**: `"status": "researched"`  
**Meaning**: Research completed, deliverables created.

**Valid Transitions**:
- `[RESEARCHED]` → `[PLANNING]` (planning begins)
- `[RESEARCHED]` → `[IMPLEMENTING]` (implementation begins, skip planning)
- `[RESEARCHED]` → `[BLOCKED]` (blocked before next phase)

**Required Artifacts**: Research report linked in TODO.md

#### `[PLANNING]`
**TODO.md Format**: `- **Status**: [PLANNING]`  
**state.json Value**: `"status": "planning"`  
**Meaning**: Implementation plan is being created.

**Valid Transitions**:
- `[PLANNING]` → `[PLANNED]` (planning completes successfully)
- `[PLANNING]` → `[BLOCKED]` (planning encounters blocker)
- `[PLANNING]` → `[ABANDONED]` (planning is abandoned)

**Timestamps**: Always include `- **Planned**: YYYY-MM-DD` when started

#### `[PLANNED]`
**TODO.md Format**: `- **Status**: [PLANNED]`  
**state.json Value**: `"status": "planned"`  
**Meaning**: Implementation plan completed, ready for implementation.

**Valid Transitions**:
- `[PLANNED]` → `[REVISING]` (plan revision begins)
- `[PLANNED]` → `[IMPLEMENTING]` (implementation begins)
- `[PLANNED]` → `[BLOCKED]` (blocked before implementation)

**Required Artifacts**: Implementation plan linked in TODO.md

#### `[REVISING]`
**TODO.md Format**: `- **Status**: [REVISING]`  
**state.json Value**: `"status": "revising"`  
**Meaning**: Plan revision is in progress.

**Valid Transitions**:
- `[REVISING]` → `[REVISED]` (revision completes successfully)
- `[REVISING]` → `[BLOCKED]` (revision encounters blocker)
- `[REVISING]` → `[ABANDONED]` (revision is abandoned)

**Timestamps**: Always include `- **Revised**: YYYY-MM-DD` when started

#### `[REVISED]`
**TODO.md Format**: `- **Status**: [REVISED]`  
**state.json Value**: `"status": "revised"`  
**Meaning**: Plan revision completed, new plan version created.

**Valid Transitions**:
- `[REVISED]` → `[IMPLEMENTING]` (implementation begins with revised plan)
- `[REVISED]` → `[REVISING]` (another revision needed)
- `[REVISED]` → `[BLOCKED]` (blocked before implementation)

**Required Artifacts**: Revised plan linked in TODO.md (replaces previous plan link)

#### `[IMPLEMENTING]`
**TODO.md Format**: `- **Status**: [IMPLEMENTING]`  
**state.json Value**: `"status": "implementing"`  
**Meaning**: Implementation work is actively underway.

**Valid Transitions**:
- `[IMPLEMENTING]` → `[COMPLETED]` (implementation finishes successfully)
- `[IMPLEMENTING]` → `[PARTIAL]` (implementation partially complete, timeout)
- `[IMPLEMENTING]` → `[BLOCKED]` (implementation encounters blocker)
- `[IMPLEMENTING]` → `[ABANDONED]` (implementation is abandoned)

**Timestamps**: Always include `- **Implemented**: YYYY-MM-DD` when started

#### `[COMPLETED]`
**TODO.md Format**: `- **Status**: [COMPLETED]`  
**state.json Value**: `"status": "completed"`  
**Meaning**: Task is finished successfully.

**Valid Transitions**: Terminal state (no further transitions)

**Required Information**:
- `- **Completed**: YYYY-MM-DD` timestamp
- Do not add emojis; rely on status marker and text alone

#### `[PARTIAL]`
**TODO.md Format**: `- **Status**: [PARTIAL]`  
**state.json Value**: `"status": "partial"`  
**Meaning**: Implementation partially completed (can resume).

**Valid Transitions**:
- `[PARTIAL]` → `[IMPLEMENTING]` (resume implementation)
- `[PARTIAL]` → `[COMPLETED]` (finish remaining work)
- `[PARTIAL]` → `[ABANDONED]` (abandon partial work)

#### `[BLOCKED]`
**TODO.md Format**: `- **Status**: [BLOCKED]`  
**state.json Value**: `"status": "blocked"`  
**Meaning**: Task is blocked by dependencies or issues.

**Valid Transitions**:
- `[BLOCKED]` → `[RESEARCHING]` (blocker resolved, resume research)
- `[BLOCKED]` → `[PLANNING]` (blocker resolved, resume planning)
- `[BLOCKED]` → `[IMPLEMENTING]` (blocker resolved, resume implementation)
- `[BLOCKED]` → `[ABANDONED]` (blocker cannot be resolved)

**Required Information**:
- `- **Blocked**: YYYY-MM-DD` timestamp
- `- **Blocking Reason**: {reason}` or `- **Blocked by**: {dependency}`

#### `[ABANDONED]`
**TODO.md Format**: `- **Status**: [ABANDONED]`  
**state.json Value**: `"status": "abandoned"`  
**Meaning**: Task was started but abandoned without completion.

**Valid Transitions**:
- `[ABANDONED]` → `[NOT STARTED]` (restart from scratch, rare)
- `[ABANDONED]` is typically terminal

**Required Information**:
- `- **Abandoned**: YYYY-MM-DD` timestamp
- `- **Abandonment Reason**: {reason}`

#### `[EXPANDED]`
**TODO.md Format**: `- **Status**: [EXPANDED]`
**state.json Value**: `"status": "expanded"`
**Meaning**: Parent task has been expanded into subtasks; work continues in subtasks.

**Valid Transitions**:
- `[NOT STARTED]` → `[EXPANDED]` (when task is divided into subtasks)
- `[RESEARCHED]` → `[EXPANDED]` (when researched task is divided)
- `[PLANNED]` → `[EXPANDED]` (when planned task is divided)
- Any non-terminal status → `[EXPANDED]` (when divided)

**Note**: `[EXPANDED]` is terminal-like. The parent delegates work to subtasks.

**Required Information**:
- `- **Subtasks**: {list}` in TODO.md
- `"subtasks": [...]` array in state.json

---

## TODO.md vs state.json Mapping

| TODO.md Marker | state.json Value | Description |
|----------------|------------------|-------------|
| `[NOT STARTED]` | `not_started` | Task not begun |
| `[RESEARCHING]` | `researching` | Research in progress |
| `[RESEARCHED]` | `researched` | Research completed |
| `[PLANNING]` | `planning` | Planning in progress |
| `[PLANNED]` | `planned` | Plan created |
| `[REVISING]` | `revising` | Plan revision in progress |
| `[REVISED]` | `revised` | Plan revision completed |
| `[IMPLEMENTING]` | `implementing` | Implementation in progress |
| `[COMPLETED]` | `completed` | Task fully completed |
| `[PARTIAL]` | `partial` | Implementation partially complete |
| `[BLOCKED]` | `blocked` | Task blocked |
| `[ABANDONED]` | `abandoned` | Task abandoned |
| `[EXPANDED]` | `expanded` | Task expanded into subtasks |

**Conversion Rules**:
- TODO.md uses uppercase with underscores in brackets: `[NOT STARTED]`
- state.json uses lowercase with underscores: `"not_started"`
- Conversion: Remove brackets, convert to lowercase

---

## Command → Status Mapping

| Command | Preflight Status | Postflight Status | Notes |
|---------|------------------|-------------------|-------|
| `/research` | `[RESEARCHING]` | `[RESEARCHED]` | Creates research report |
| `/plan` | `[PLANNING]` | `[PLANNED]` | Creates implementation plan |
| `/revise` | `[REVISING]` | `[REVISED]` | Creates new plan version |
| `/implement` | `[IMPLEMENTING]` | `[COMPLETED]` or `[PARTIAL]` | Executes implementation |
| `/review` | N/A | N/A | Creates new tasks |

**Preflight**: Status updated BEFORE work begins  
**Postflight**: Status updated AFTER work completes

---

## Valid Transition Diagram

```
[NOT STARTED] ─────────────────────────────────────────────────┐
    │                                                           │
    │ (/research)         (/plan)          (/implement)        │
    ▼                     ▼                 ▼                  ▼
[RESEARCHING]    [PLANNING]        [IMPLEMENTING]         [BLOCKED]
    │                │                     │                   │
    ▼                ▼                     ▼                   │
[RESEARCHED] ──→ [PLANNED] ──(/revise)──→ [REVISING]          │
                    │            │             │               │
                    │            │             ▼               │
                    │            │        [REVISED]            │
                    │            └─────────────┘               │
                    │ (/implement)                             │
                    ▼                                          │
             [IMPLEMENTING] ─────────────────────────────────> │
                    │                                          │
                    ├────> [COMPLETED] (all phases done)       │
                    ├────> [PARTIAL] (some phases done)        │
                    └────> [BLOCKED] (cannot proceed) ─────────┘

    ┌──────────────────────────────────────────────────────────┘
    │ (work abandoned)
    ▼
[ABANDONED]

Any non-terminal ──(/task --expand)──> [EXPANDED] (delegates to subtasks)
```

---

## Status Update Protocol

**CRITICAL**: All status updates MUST be delegated to status-sync-manager for atomic synchronization.

**DO NOT** update TODO.md or state.json directly.

### Preflight Status Update

**When**: BEFORE work begins (in step_0_preflight)  
**Purpose**: Signal work has started  
**Example**: `/research` updates status to `[RESEARCHING]` before beginning research

```json
{
  "operation": "update_status",
  "task_number": 321,
  "new_status": "researching",
  "timestamp": "2026-01-05",
  "session_id": "sess_20260105_abc123"
}
```

### Postflight Status Update

**When**: AFTER work completes (in step_7_postflight or equivalent)  
**Purpose**: Signal work has finished, link artifacts  
**Example**: `/research` updates status to `[RESEARCHED]` after creating research report

```json
{
  "operation": "update_status",
  "task_number": 321,
  "new_status": "researched",
  "timestamp": "2026-01-05",
  "session_id": "sess_20260105_abc123",
  "validated_artifacts": [
    {
      "type": "research_report",
      "path": "specs/321_topic/reports/01_research-findings.md",
      "summary": "Research findings",
      "validated": true
    }
  ]
}
```

---

## Atomic Synchronization

status-sync-manager updates atomically:
1. TODO.md (status marker, timestamps, artifact links)
2. state.json (status field, timestamps, artifact_paths)
3. Plan file (phase status markers, if plan exists)

**Atomic Write Pattern**: All files updated or none (uses temp files + atomic rename)

---

## Validation Rules

### Status Transition Validation

**Valid Transitions**:
- `[NOT STARTED]` → `[RESEARCHING]`, `[PLANNING]`, `[IMPLEMENTING]`, `[BLOCKED]`, `[EXPANDED]`
- `[RESEARCHING]` → `[RESEARCHED]`, `[BLOCKED]`, `[ABANDONED]`
- `[RESEARCHED]` → `[PLANNING]`, `[IMPLEMENTING]`, `[BLOCKED]`, `[EXPANDED]`
- `[PLANNING]` → `[PLANNED]`, `[BLOCKED]`, `[ABANDONED]`
- `[PLANNED]` → `[REVISING]`, `[IMPLEMENTING]`, `[BLOCKED]`, `[EXPANDED]`
- `[REVISING]` → `[REVISED]`, `[BLOCKED]`, `[ABANDONED]`
- `[REVISED]` → `[IMPLEMENTING]`, `[REVISING]`, `[BLOCKED]`, `[EXPANDED]`
- `[IMPLEMENTING]` → `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`, `[ABANDONED]`
- `[PARTIAL]` → `[IMPLEMENTING]`, `[COMPLETED]`, `[ABANDONED]`
- `[BLOCKED]` → `[RESEARCHING]`, `[PLANNING]`, `[IMPLEMENTING]`, `[ABANDONED]`, `[EXPANDED]`

**Invalid Transitions**:
- `[COMPLETED]` → any (completed is terminal)
- `[EXPANDED]` → any (expanded is terminal-like, work in subtasks)
- `[NOT STARTED]` → `[COMPLETED]` (must go through work phases)
- `[NOT STARTED]` → `[ABANDONED]` (cannot abandon work never started)
- `[ABANDONED]` → `[COMPLETED]` (abandoned work not complete)

### Required Fields Validation

**For `[BLOCKED]` status**:
- MUST include `blocking_reason` or `blocked_by` parameter
- MUST include `- **Blocked**: YYYY-MM-DD` timestamp in TODO.md

**For `[ABANDONED]` status**:
- MUST include `abandonment_reason` parameter
- MUST include `- **Abandoned**: YYYY-MM-DD` timestamp in TODO.md

**For `[EXPANDED]` status**:
- MUST include `subtasks` array with subtask numbers
- MUST include `- **Subtasks**: {list}` in TODO.md

**For completion statuses** (`[RESEARCHED]`, `[PLANNED]`, `[REVISED]`, `[COMPLETED]`):
- MUST include `validated_artifacts` array with artifact paths
- Artifacts MUST exist on disk and be non-empty

---

## References

- **state-management.md**: Complete state management standard
- **status-transitions.md**: Status transition workflows
- **status-sync-manager.md**: Atomic synchronization implementation

---

**Last Updated**: 2026-01-05  
**Maintained By**: ProofChecker Development Team
