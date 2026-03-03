# Status Transitions

---

> **DEPRECATED** (2026-01-19): This file is redundant. Use these instead:
> - `orchestration/state-management.md` - Status markers, transitions, synchronization
> - `standards/status-markers.md` - Complete status definitions (if more detail needed)
>
> This file is preserved for reference but should not be loaded for new development.

---

**Note**: For complete status marker definitions, see `.opencode/context/core/standards/status-markers.md` (authoritative source).

## Status Markers (Quick Reference)

| Status | Marker | Description |
|--------|--------|-------------|
| Not Started | `[NOT STARTED]` | Task created but not begun |
| Researching | `[RESEARCHING]` | Research in progress |
| Researched | `[RESEARCHED]` | Research completed |
| Planning | `[PLANNING]` | Planning in progress |
| Planned | `[PLANNED]` | Plan created |
| Revising | `[REVISING]` | Plan revision in progress |
| Revised | `[REVISED]` | Plan revision completed |
| Implementing | `[IMPLEMENTING]` | Implementation in progress |
| Completed | `[COMPLETED]` | Task fully completed |
| Partial | `[PARTIAL]` | Implementation partially complete |
| Blocked | `[BLOCKED]` | Task blocked by dependency |
| Abandoned | `[ABANDONED]` | Task abandoned |
| Expanded | `[EXPANDED]` | Task expanded into subtasks |

## Valid Transitions

```
[NOT STARTED] → [RESEARCHING] → [RESEARCHED] → [PLANNING] → [PLANNED] → [IMPLEMENTING] → [COMPLETED]
              ↘                ↗              ↘            ↗
                [PLANNING]                      [IMPLEMENTING]
```

**Shortcuts allowed**:
- `[NOT STARTED]` → `[PLANNING]` (skip research)
- `[NOT STARTED]` → `[IMPLEMENTING]` (skip research and planning)
- `[RESEARCHED]` → `[IMPLEMENTING]` (skip planning)

**Any status** → `[BLOCKED]` or `[ABANDONED]`

**Any non-terminal** → `[EXPANDED]` (when task is expanded into subtasks via `/task --expand`)

## Command → Status Mapping

| Command | Start Status | End Status |
|---------|-------------|------------|
| /research | [RESEARCHING] | [RESEARCHED] |
| /plan | [PLANNING] | [PLANNED] |
| /implement | [IMPLEMENTING] | [COMPLETED] |
| /revise | (no change) | (no change) |
| /review | (creates new tasks) | N/A |

## Status Update Delegation

**CRITICAL**: All status updates MUST be delegated to status-sync-manager for atomic synchronization.

**DO NOT** update specs/TODO.md or specs/state.json directly.

```json
{
  "agent": "status-sync-manager",
  "task_number": 244,
  "new_status": "researched",
  "timestamp": "2025-12-29T08:13:37Z",
  "artifacts": [
    "specs/244_phase_1/reports/research-001.md"
  ]
}
```

## Atomic Synchronization

status-sync-manager updates atomically:
1. specs/TODO.md (status marker, timestamps, artifact links)
2. specs/state.json (status field, timestamps, artifact_paths)
3. Project specs/state.json (if exists)
4. Plan file (phase status markers, if plan exists)

**Two-phase commit**: All files updated or all rolled back on failure.
