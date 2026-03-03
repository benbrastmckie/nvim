# State Management Standard

**Version**: 3.0
**Status**: Active
**Created**: 2025-12-29
**Updated**: 2026-01-17
**Purpose**: Unified state management standard defining status markers, state schemas, synchronization, and fast lookup patterns

---

## Overview

This standard defines the complete state management system for Logos/Theory:

- **Status Markers**: Standardized markers for tracking task and phase progress
- **State Schemas**: JSON schemas for distributed state tracking
- **Fast Lookup Patterns**: Optimized jq patterns for task validation and metadata extraction
- **Status Synchronization**: Atomic multi-file update mechanisms
- **Timestamp Formats**: Consistent timestamp formatting across all files

---

## Status Markers

### Standard Status Markers

#### `[NOT STARTED]` → `[IN PROGRESS]` → `[COMPLETED]`
- **NOT STARTED**: Work not yet begun
- **IN PROGRESS**: Currently being worked on (requires `**Started**: YYYY-MM-DD`)
- **BLOCKED**: Blocked by dependencies (requires blocking reason)
- **ABANDONED**: Started but not completed (requires abandonment reason)
- **COMPLETED**: Successfully finished (terminal state)

### Command-Specific Status Markers

**In-Progress**: `[RESEARCHING]`, `[PLANNING]`, `[REVISING]`, `[IMPLEMENTING]`
**Completion**: `[RESEARCHED]`, `[PLANNED]`, `[REVISED]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`

### Valid Transitions

| From | To | Condition |
|------|-----|-----------|
| `[NOT STARTED]` | `[RESEARCHING]` | `/research` starts |
| `[RESEARCHED]` | `[PLANNING]` | `/plan` starts |
| `[PLANNED]` | `[IMPLEMENTING]` | `/implement` starts |
| `[IMPLEMENTING]` | `[COMPLETED]` | Implementation finishes |
| `[IMPLEMENTING]` | `[PARTIAL]` | Timeout/error |

---

## State Schemas

### File Locations

```
specs/
├── specs/state.json           # Main state (cross-references, health)
├── specs/TODO.md              # User-facing task list
├── specs/archive/state.json   # Archived project tracking
└── OC_NNN_project_name/       # Task directories use OC_ prefix
    └── ...                    # Task artifacts
```

**Directory Naming**: OpenCode tasks use `OC_NNN_slug` format (e.g., `OC_017_task_slug`). The `OC_` prefix distinguishes from Claude Code tasks.

### Main State File (`specs/state.json`)

```json
{
  "_schema_version": "1.1.0",
  "_last_updated": "2025-12-29T09:00:00Z",
  "next_project_number": 90,
  "active_projects": [
    {
      "project_number": 89,
      "project_name": "task_slug",
      "status": "planned",
      "language": "lean",
      "priority": "high",
      "description": "Detailed task description (50-500 chars)",
      "created": "2025-12-29T09:00:00Z",
      "last_updated": "2025-12-29"
    }
  ],
  "repository_health": {
    "overall_score": 94,
    "sorry_count": 5,
    "axiom_count": 24
  }
}
```

**Key Fields**:
- `project_number`: Unique task ID
- `project_name`: Slug from task title
- `status`: Current status (lowercase: `not_started`, `researching`, `planned`, etc.)
- `language`: Task language (`lean`, `general`, `meta`, `markdown`, `latex`)
- `description`: Task description (50-500 chars, optional for legacy tasks)

### Archive State File (`specs/specs/archive/state.json`)

Tracks archived projects with timeline, artifacts, and impact metadata.

---

## Fast Lookup Patterns

### Why specs/state.json for Reads?

- ✅ **8x faster**: JSON parsing (~12ms) vs markdown parsing (~100ms)
- ✅ **Structured**: Direct field access with jq
- ✅ **Reliable**: No regex/grep fragility
- ✅ **Synchronized**: status-sync-manager keeps specs/state.json ↔ specs/TODO.md in sync

### Read/Write Separation

- **Reads** (validation, routing): Use `specs/state.json` (this document)
- **Writes** (status updates, artifacts): Use `skill-status-sync`
- **Synchronization**: Automatic via skill-status-sync

### Pattern 1: Validate and Extract

```bash
# 1. Parse task number (strip OC_ prefix if present)
raw_input="$task_number"  # e.g., "OC_17" or "17"
task_num=$(echo "$raw_input" | sed 's/^OC_//')  # strips prefix if present

# 2. Lookup task (internal state uses integer project_number)
task_data=$(jq -r --arg num "$task_num" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

# 3. Validate exists
if [ -z "$task_data" ]; then
  echo "Error: Task OC_$task_num not found"
  exit 1
fi

# 4. Extract metadata (single pass)
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# 5. Build display/path forms
task_display="OC_$task_num"                           # e.g., OC_17
task_dir="OC_$(printf '%03d' "$task_num")_$project_name"  # e.g., OC_017_task_slug
```

**OC_ Prefix Convention**:
- User input: Accept `OC_17` or `17` (strip prefix for lookup)
- Display: Always show `OC_17` (unpadded)
- Directories: Always use `OC_017_slug` (3-digit padded)
- state.json: Store as integer `project_number: 17`

**Performance**: ~12ms total

### Pattern 2: Filter by Status/Language

```bash
# Get all tasks in progress
in_progress=$(jq -r '.active_projects[] | select(.status == "implementing") | .project_number' \
  specs/state.json)

# Get all Lean tasks
lean_tasks=$(jq -r '.active_projects[] | select(.language == "lean") | .project_number' \
  specs/state.json)
```

### Pattern 3: Bulk Queries

```bash
# Get completed + abandoned tasks (for archival)
archival_tasks=$(jq -r '.active_projects[] |
  select(.status == "completed" or .status == "abandoned") |
  {project_number, project_name, status}' \
  specs/state.json)
```

**Performance**: ~15ms (vs ~200ms with specs/TODO.md scanning)

---

## Timestamp Formats

### specs/TODO.md: Date Only
```markdown
**Started**: 2025-12-20
**Completed**: 2025-12-20
```

### State Files: ISO 8601
```json
{
  "created": "2025-12-20T10:00:00Z",
  "last_updated": "2025-12-20"
}
```

### Field Naming (NO `_at` suffix)
- `started`, `completed`, `researched`, `planned` (NOT `started_at`, etc.)
- `created`, `last_updated` (system timestamps)

---

## Status Synchronization

### Multi-File Synchronization

Commands must keep status synchronized across:
- `specs/TODO.md` (user-facing)
- `specs/state.json` (machine-readable)
- Plan files (phase markers)

### Atomic Update Requirement

All status updates must be **atomic** - all files updated or none.

### skill-status-sync

All writes go through `skill-status-sync` which provides:

**Phase 1 (Prepare)**:
1. Read all files
2. Validate transition is allowed
3. Prepare updates in memory
4. If validation fails, abort

**Phase 2 (Commit)**:
1. Write specs/state.json → specs/TODO.md → plan (dependency order)
2. Verify each write
3. On failure, rollback all
4. Atomic guarantee: all updated or none updated

### Usage in Commands

```bash
# Preflight: Mark in-progress
skill-status-sync operation=preflight_update task_number=$N new_status=implementing

# Postflight: Mark complete + link artifacts
skill-status-sync operation=postflight_update task_number=$N new_status=completed artifacts=[...]
```

---

## Validation

### Status Marker Validation
- Format: `[STATUS]` (brackets required)
- Case: Uppercase only
- No extra whitespace

### Timestamp Validation
- specs/TODO.md: YYYY-MM-DD
- State files: ISO 8601
- Required for all status transitions

### Transition Validation
- Must follow transition diagram
- Blocking/abandonment reasons required
- Timestamp order: Started < Completed

---

## Best Practices

### 1. Use specs/state.json for Reads

✅ **Good**: Fast jq lookup with OC_ prefix handling
```bash
# Strip OC_ prefix before numeric lookup
task_num=$(echo "$task_number" | sed 's/^OC_//')
task_data=$(jq -r --arg num "$task_num" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)
```

❌ **Bad**: Slow specs/TODO.md parsing
```bash
grep -A 20 "### OC_${task_number}\." specs/TODO.md
```

### 2. Use skill-status-sync for Writes

✅ **Good**: Atomic via skill-status-sync
❌ **Bad**: Manual updates (risk of desync)

### 3. Provide Default Values

```bash
language=$(echo "$task_data" | jq -r '.language // "general"')
description=$(echo "$task_data" | jq -r '.description // ""')
```

### 4. Extract All Fields Once

✅ **Good**: Single pass
❌ **Bad**: Multiple jq calls (slower)

---

## Status Transition Rules

### Valid Transitions

```
[NOT STARTED] -> [RESEARCHING] | [PLANNING] | [IMPLEMENTING] | [BLOCKED] | [EXPANDED]
[RESEARCHING] -> [RESEARCHED] | [BLOCKED] | [ABANDONED]
[RESEARCHED] -> [PLANNING] | [IMPLEMENTING] | [BLOCKED] | [EXPANDED]
[PLANNING] -> [PLANNED] | [BLOCKED] | [ABANDONED]
[PLANNED] -> [REVISING] | [IMPLEMENTING] | [BLOCKED] | [EXPANDED]
[REVISING] -> [REVISED] | [BLOCKED] | [ABANDONED]
[REVISED] -> [IMPLEMENTING] | [REVISING] | [BLOCKED] | [EXPANDED]
[IMPLEMENTING] -> [COMPLETED] | [PARTIAL] | [BLOCKED] | [ABANDONED]
[PARTIAL] -> [IMPLEMENTING] | [COMPLETED] | [ABANDONED]
[BLOCKED] -> [RESEARCHING] | [PLANNING] | [IMPLEMENTING] | [ABANDONED] | [EXPANDED]
```

### Terminal States

- `[COMPLETED]` - No further transitions
- `[EXPANDED]` - Terminal-like (work continues in subtasks)
- `[ABANDONED]` - Typically terminal (rare restart to [NOT STARTED])

### Invalid Transitions

- `[NOT STARTED]` -> `[COMPLETED]` (must go through work phases)
- `[NOT STARTED]` -> `[ABANDONED]` (cannot abandon work never started)
- `[ABANDONED]` -> `[COMPLETED]` (abandoned work not complete)

### Command Mappings

| Command | Preflight | Postflight |
|---------|-----------|------------|
| /research | RESEARCHING | RESEARCHED |
| /plan | PLANNING | PLANNED |
| /revise | REVISING | REVISED |
| /implement | IMPLEMENTING | COMPLETED or PARTIAL |

---

## Related Documentation

- `.opencode/skills/skill-status-sync/` - Atomic status updates (**primary reference for writes**)
- `.opencode/context/core/standards/status-markers.md` - Complete status definitions
- `.opencode/context/core/patterns/inline-status-update.md` - jq patterns for direct updates
- `.opencode/commands/` - Command file implementations

---

## Schema Versioning

All state files include `"_schema_version": "MAJOR.MINOR.PATCH"` using Semantic Versioning:
- **MAJOR**: Breaking changes requiring migration
- **MINOR**: New optional fields (backward compatible)
- **PATCH**: Documentation only
