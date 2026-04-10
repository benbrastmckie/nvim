---
paths: specs/**/*
---

# State Management Rules

## File Synchronization

specs/TODO.md and specs/state.json MUST stay synchronized. Any update to one requires updating the other.

### Canonical Sources
- **specs/state.json**: Machine-readable source of truth
  - next_project_number
  - active_projects array with status, language, priority
  - Faster to query (12ms vs 100ms for specs/TODO.md parsing)

- **specs/TODO.md**: User-facing source of truth
  - Human-readable task list with descriptions
  - Status markers in brackets: [STATUS]
  - Grouped by priority (High/Medium/Low)

## Status Transitions

### Valid Transitions
```
[NOT STARTED] → [RESEARCHING] → [RESEARCHED]
[RESEARCHED] → [PLANNING] → [PLANNED]
[PLANNED] → [IMPLEMENTING] → [COMPLETED]

Any state → [BLOCKED] (with reason)
Any state → [ABANDONED] (moves to archive)
Any non-terminal → [EXPANDED] (when divided into subtasks)
[IMPLEMENTING] → [PARTIAL] (on timeout/error)
```

**Checkpoint Reference**: Use `core/checkpoints/checkpoint-gate-in.md` and
`core/checkpoints/checkpoint-gate-out.md` for preflight/postflight update flow.

### Invalid Transitions
- Cannot skip phases (e.g., NOT STARTED → PLANNED)
- Cannot regress (e.g., PLANNED → RESEARCHED) except for revisions
- Cannot mark COMPLETED without all phases done

## Two-Phase Update Pattern

When updating task status:

### Phase 1: Prepare
```
1. Read current specs/state.json
2. Read current specs/TODO.md
3. Validate task exists in both
4. Prepare updated content in memory
5. Validate updates are consistent
```

### Phase 2: Commit
```
1. Write specs/state.json (machine state first)
2. Write specs/TODO.md (user-facing second)
3. Verify both writes succeeded
4. If either fails: log error, preserve original state
```

## Task Entry Format

### specs/TODO.md Entry
```markdown
### OC_{NUMBER}. {TITLE}
- **Effort**: {estimate}
- **Status**: [{STATUS}]
- **Priority**: {High|Medium|Low}
- **Language**: {lean|general|meta|markdown}
- **Started**: {ISO timestamp}
- **Completed**: {ISO timestamp}
- **Research**: [link to report]
- **Plan**: [link to plan]

**Description**: {full description}
```

**Note**: OpenCode tasks use `OC_` prefix (e.g., `OC_17`) to distinguish from Claude Code tasks. Internal state.json stores integer `project_number`; the prefix is display/path convention only.

### specs/state.json Entry
```json
{
  "project_number": 334,
  "project_name": "task_slug_here",
  "status": "planned",
  "language": "lean",
  "priority": "high",
  "effort": "4 hours",
  "created": "2026-01-08T10:00:00Z",
  "last_updated": "2026-01-08T14:30:00Z",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/OC_017_task_slug_here/reports/research-001.md",
      "summary": "Brief 1-sentence description of artifact"
    }
  ],
  "completion_summary": "1-3 sentence description of what was accomplished (required when status='completed')",
  "roadmap_items": ["Optional explicit roadmap item text to match"]
}
```

### Completion Fields Schema

When a task transitions to `status: "completed"`, these fields are populated:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `completion_summary` | string | **Yes** (when completed) | 1-3 sentence description of what was accomplished |
| `roadmap_items` | array of strings | No | Explicit list of ROADMAP.md item texts this task addresses (non-meta tasks only) |
| `readme_suggestions` | string | **Yes** (meta only) | Description of .opencode/ changes made, or `"none"` if no .opencode/ files modified |

**Responsibility Split**:
- **`/implement` (Producer)**: Reports what was changed factually. Always populates `readme_suggestions` for meta tasks describing .opencode/ modifications, or `"none"` if no .opencode/ files were modified.
- **`/todo` (Consumer)**: Evaluates `readme_suggestions` content and decides what warrants README.md updates. The filtering criteria belongs here, not in `/implement`.

**Producer Responsibility**: The `/implement` command populates these fields in skill postflight (Stage 7) when a task is successfully completed. The agent generates `completion_data` in the metadata file, and the skill propagates it to specs/state.json.

**Consumer Usage**: The `/todo` command extracts these fields via `jq` to:
- Match non-meta tasks against ROADMAP.md items for annotation (using `roadmap_items`)
- Display README.md modification suggestions for user review (using `readme_suggestions` from meta tasks)

### readme_suggestions Schema (Meta Tasks Only)

For meta tasks (language: "meta"), `readme_suggestions` is a **string** (not an object) that factually describes what .opencode/ files were modified:

| Scenario | Value |
|----------|-------|
| Modified .opencode/ files | Brief description of changes (e.g., "Added completion_data field to return-metadata-file.md, updated 3 agent definitions") |
| No .opencode/ files modified | `"none"` |

**Examples**:

Meta task with .opencode/ changes:
```json
{
  "completion_summary": "Implemented new /debug command with MCP diagnostics.",
  "readme_suggestions": "Added skill-debug/SKILL.md, updated README.md Command Workflows section"
}
```

Meta task without .opencode/ changes:
```json
{
  "completion_summary": "Created utility script for test automation.",
  "readme_suggestions": "none"
}
```

**Key Design Insight**: README.md is loaded context for agents, not primarily user documentation. The `readme_suggestions` field exists to track .opencode/ modifications, not to pre-filter what gets documented. The `/todo` command evaluates whether changes warrant README.md updates

### Artifact Object Schema

Each artifact in the `artifacts` array:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `research`, `plan`, `summary`, `implementation` |
| `path` | string | Yes | Relative path from project root |
| `summary` | string | Yes | Brief 1-sentence description of artifact contents |

**Note**: The `summary` field enables skills to link artifacts with meaningful descriptions in postflight operations, without re-reading artifact contents.

## Status Values Mapping

| specs/TODO.md Marker | specs/state.json status |
|----------------|-------------------|
| [NOT STARTED] | not_started |
| [RESEARCHING] | researching |
| [RESEARCHED] | researched |
| [PLANNING] | planning |
| [PLANNED] | planned |
| [IMPLEMENTING] | implementing |
| [COMPLETED] | completed |
| [BLOCKED] | blocked |
| [ABANDONED] | abandoned |
| [PARTIAL] | partial |
| [EXPANDED] | expanded |

## Artifact Linking

When creating artifacts, update specs/TODO.md with links:

### Research Completion
```markdown
- **Status**: [RESEARCHED]
- **Research**: [specs/OC_{NNN}_{SLUG}/reports/research-001.md]
```

### Plan Completion
```markdown
- **Status**: [PLANNED]
- **Plan**: [specs/OC_{NNN}_{SLUG}/plans/implementation-001.md]
```

### Implementation Completion
```markdown
- **Status**: [COMPLETED]
- **Completed**: 2026-01-08
- **Summary**: [specs/OC_{NNN}_{SLUG}/summaries/implementation-summary-20260108.md]
```

**Note**: `{NNN}` is 3-digit padded (e.g., `017`), so directory paths are `specs/OC_017_task_slug/`.

## Directory Creation

### Lazy Directory Creation Rule

Create task directories **lazily** - only when the first artifact is written:
```
specs/{NUMBER}_{SLUG}/
├── reports/      # Created when research agent writes first report
├── plans/        # Created when planner agent writes first plan
└── summaries/    # Created when implementation agent writes summary
```

**DO NOT** create directories at task creation time. The `/task` command only:
1. Updates `specs/state.json` (adds task to active_projects)
2. Updates `specs/TODO.md` (adds task entry)

**WHO creates directories**: Artifact-writing agents (researcher, planner, implementer) create directories with `mkdir -p` when writing their first artifact to a task.

**WHY**: Empty directories provide no value (git doesn't track them), clutter the filesystem, and make task creation unnecessarily complex.

### Correct Pattern
```bash
# When writing an artifact (e.g., research report)
mkdir -p "specs/${task_num}_${slug}/reports"
write "specs/${task_num}_${slug}/reports/research-001.md"
```

### Incorrect Pattern
```bash
# DO NOT do this at task creation time
mkdir -p "specs/${task_num}_${slug}"  # Wrong! Creates empty directory
```

## Error Handling

### On Write Failure
1. Do not update either file partially
2. Log error with context
3. Preserve original state
4. Return error to caller

### On Inconsistency Detection
1. Log the inconsistency
2. Use git blame to determine latest
3. Sync to latest version
4. Create backup of overwritten version
