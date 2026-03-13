---
paths: specs/**/*
---

# State Management Rules

## File Synchronization

TODO.md and state.json MUST stay synchronized. Any update to one requires updating the other.

### Canonical Sources
- **state.json**: Machine-readable source of truth
  - next_project_number
  - active_projects array with status, language
  - Faster to query (12ms vs 100ms for TODO.md parsing)

- **TODO.md**: User-facing source of truth
  - Human-readable task list with descriptions
  - Status markers in brackets: [STATUS]
  - Single `## Tasks` section (new tasks prepended at top)

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

### Invalid Transitions
- Cannot skip phases (e.g., NOT STARTED → PLANNED)
- Cannot regress (e.g., PLANNED → RESEARCHED) except for revisions
- Cannot mark COMPLETED without all phases done

## Two-Phase Update Pattern

When updating task status:

### Phase 1: Prepare
```
1. Read current state.json
2. Read current TODO.md
3. Validate task exists in both
4. Prepare updated content in memory
5. Validate updates are consistent
```

### Phase 2: Commit
```
1. Write state.json (machine state first)
2. Write TODO.md (user-facing second)
3. Verify both writes succeeded
4. If either fails: log error, preserve original state
```

## Task Entry Format

### TODO.md Entry
```markdown
### {NUMBER}. {TITLE}
- **Effort**: {estimate}
- **Status**: [{STATUS}]
- **Language**: {neovim|general|meta|markdown|latex|typst}
- **Dependencies**: Task #{N}, Task #{N}  OR  None
- **Started**: {ISO timestamp}
- **Completed**: {ISO timestamp}
- **Research**: [link to report]
- **Plan**: [link to plan]

**Description**: {full description}
```

### state.json Entry
```json
{
  "project_number": 334,
  "project_name": "task_slug_here",
  "status": "planned",
  "language": "neovim",
  "effort": "4 hours",
  "created": "2026-01-08T10:00:00Z",
  "last_updated": "2026-01-08T14:30:00Z",
  "dependencies": [332, 333],
  "artifacts": [
    {
      "type": "research",
      "path": "specs/334_task_slug_here/reports/research-001.md",
      "summary": "Brief 1-sentence description of artifact"
    }
  ],
  "completion_summary": "1-3 sentence description of what was accomplished (required when status='completed')",
  "roadmap_items": ["Optional explicit roadmap item text to match"]
}
```

### Repository Health Section

The `repository_health` section tracks repository-wide technical debt metrics:

```json
{
  "repository_health": {
    "last_assessed": "2026-01-29T18:38:22Z",
    "sorry_count": 295,
    "axiom_count": 10,
    "build_errors": 0,
    "status": "manageable"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `last_assessed` | string | ISO8601 timestamp of last metrics update |
| `sorry_count` | number | Total `sorry` occurrences in active Theories/ (excludes Boneyard/ and Examples/) |
| `axiom_count` | number | Total `axiom` declarations in Theories/ |
| `build_errors` | number | Current build error count (0 = clean build) |
| `status` | string | Overall debt status: `manageable`, `concerning`, `critical` |

**Update Mechanism**: The `/todo` command updates `repository_health` during postflight (Section 5.7). Values are computed via grep and synced to both state.json and TODO.md frontmatter.

### Completion Fields Schema

When a task transitions to `status: "completed"`, these fields are populated:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `completion_summary` | string | **Yes** (when completed) | 1-3 sentence description of what was accomplished |
| `roadmap_items` | array of strings | No | Explicit list of ROAD_MAP.md item texts this task addresses (non-meta tasks only) |
| `claudemd_suggestions` | string | **Yes** (meta only) | Description of .claude/ changes made, or `"none"` if no .claude/ files modified |

**Responsibility Split**:
- **`/implement` (Producer)**: Reports what was changed factually. Always populates `claudemd_suggestions` for meta tasks describing .claude/ modifications, or `"none"` if no .claude/ files were modified.
- **`/todo` (Consumer)**: Evaluates `claudemd_suggestions` content and decides what warrants CLAUDE.md updates. The filtering criteria belongs here, not in `/implement`.

**Producer Responsibility**: The `/implement` command populates these fields in skill postflight (Stage 7) when a task is successfully completed. The agent generates `completion_data` in the metadata file, and the skill propagates it to state.json.

**Consumer Usage**: The `/todo` command extracts these fields via `jq` to:
- Match non-meta tasks against ROAD_MAP.md items for annotation (using `roadmap_items`)
- Display CLAUDE.md modification suggestions for user review (using `claudemd_suggestions` from meta tasks)

### claudemd_suggestions Schema (Meta Tasks Only)

For meta tasks (language: "meta"), `claudemd_suggestions` is a **string** (not an object) that factually describes what .claude/ files were modified:

| Scenario | Value |
|----------|-------|
| Modified .claude/ files | Brief description of changes (e.g., "Added completion_data field to return-metadata-file.md, updated 3 agent definitions") |
| No .claude/ files modified | `"none"` |

**Examples**:

Meta task with .claude/ changes:
```json
{
  "completion_summary": "Implemented new /debug command with MCP diagnostics.",
  "claudemd_suggestions": "Added skill-debug/SKILL.md, updated CLAUDE.md Command Workflows section"
}
```

Meta task without .claude/ changes:
```json
{
  "completion_summary": "Created utility script for test automation.",
  "claudemd_suggestions": "none"
}
```

**Key Design Insight**: CLAUDE.md is loaded context for agents, not primarily user documentation. The `claudemd_suggestions` field exists to track .claude/ modifications, not to pre-filter what gets documented. The `/todo` command evaluates whether changes warrant CLAUDE.md updates

### Dependencies Field Schema

Tasks can declare dependencies on other tasks that must complete before work begins.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `dependencies` | array of integers | No | `[]` | Task numbers that must complete before this task can start |

**Format Conversion**:

| state.json | TODO.md |
|------------|---------|
| `[]` | `None` |
| `[35]` | `Task #35` |
| `[35, 36]` | `Task #35, Task #36` |

**Validation Requirements**:
- **Valid References**: All task numbers in `dependencies` must exist in `active_projects`
- **No Circular Dependencies**: A task cannot create dependency cycles (A depends on B, B depends on A)
- **No Self-Reference**: A task cannot include its own `project_number` in `dependencies`

### Artifact Object Schema

Each artifact in the `artifacts` array:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `research`, `plan`, `summary`, `implementation` |
| `path` | string | Yes | Relative path from project root |
| `summary` | string | Yes | Brief 1-sentence description of artifact contents |

**Note**: The `summary` field enables skills to link artifacts with meaningful descriptions in postflight operations, without re-reading artifact contents.

## Status Values Mapping

| TODO.md Marker | state.json status |
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

When creating artifacts, update TODO.md with links:

### Research Completion
```markdown
- **Status**: [RESEARCHED]
- **Research**: [research-001.md]({NNN}_{SLUG}/reports/research-001.md)
```

### Plan Completion
```markdown
- **Status**: [PLANNED]
- **Plan**: [implementation-001.md]({NNN}_{SLUG}/plans/implementation-001.md)
```

### Implementation Completion
```markdown
- **Status**: [COMPLETED]
- **Completed**: 2026-01-08
- **Summary**: [implementation-summary-20260108.md]({NNN}_{SLUG}/summaries/implementation-summary-20260108.md)
```

## Directory Creation

### Lazy Directory Creation Rule

Create task directories **lazily** - only when the first artifact is written:
```
specs/{NNN}_{SLUG}/
├── reports/      # Created when research agent writes first report
├── plans/        # Created when planner agent writes first plan
└── summaries/    # Created when implementation agent writes summary
```

**Note**: Directory numbers use 3-digit zero-padding (e.g., `014_task_name`).
Use `printf "%03d" $task_num` for path construction. Task numbers 1000+ will
naturally have 4 digits.

**DO NOT** create directories at task creation time. The `/task` command only:
1. Updates `specs/state.json` (adds task to active_projects)
2. Updates `specs/TODO.md` (adds task entry)

**WHO creates directories**: Artifact-writing agents (researcher, planner, implementer) create directories with `mkdir -p` when writing their first artifact to a task.

**WHY**: Empty directories provide no value (git doesn't track them), clutter the filesystem, and make task creation unnecessarily complex.

### Correct Pattern
```bash
# When writing an artifact (e.g., research report)
padded_num=$(printf "%03d" "$task_num")
mkdir -p "specs/OC_${padded_num}_${slug}/reports"
write "specs/${padded_num}_${slug}/reports/research-001.md"
```

### Incorrect Pattern
```bash
# DO NOT do this at task creation time
mkdir -p "specs/${task_num}_${slug}"  # Wrong! Creates empty directory

# Also incorrect: unpadded directory numbers
mkdir -p "specs/14_${slug}/reports"   # Wrong! Use 014, not 14
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
