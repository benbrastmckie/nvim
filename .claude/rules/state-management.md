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
  "task_type": null,
  "effort": "4 hours",
  "created": "2026-01-08T10:00:00Z",
  "last_updated": "2026-01-08T14:30:00Z",
  "dependencies": [332, 333],
  "artifacts": [
    {
      "type": "research",
      "path": "specs/334_task_slug_here/reports/01_research-findings.md",
      "summary": "Brief 1-sentence description of artifact"
    }
  ],
  "completion_summary": "1-3 sentence description of what was accomplished (required when status='completed')",
  "roadmap_items": ["Optional explicit roadmap item text to match"]
}
```

### task_type Field Schema

The `task_type` field enables finer-grained routing within a language. This is particularly useful for extension languages like `founder` where different commands (/market, /analyze, /strategy) need different research agents.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `task_type` | string or null | No | `null` | Sub-type for finer-grained routing within a language |

**Valid Values for Founder Extension**:

| task_type | Research Skill | Created By |
|-----------|----------------|------------|
| `market` | skill-market | /market command |
| `analyze` | skill-analyze | /analyze command |
| `strategy` | skill-strategy | /strategy command |
| `null` | skill-market (default) | Backward compatibility |

**Routing Behavior**:

When `/research` is invoked on a task with `language: "founder"`:
1. Check if `task_type` is set
2. If set, route to skill matching task_type (e.g., `task_type: "analyze"` -> `skill-analyze`)
3. If null or missing, fall back to default routing (skill-market)

**Format Conversion**:

| state.json | TODO.md |
|------------|---------|
| `null` | (not shown) |
| `"market"` | `- **Type**: market` |
| `"analyze"` | `- **Type**: analyze` |
| `"strategy"` | `- **Type**: strategy` |

**Note**: The task_type field is only relevant for extension languages that support multiple research paths. Core languages (general, meta, markdown) do not use task_type.

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
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

### Plan Completion
```markdown
- **Status**: [PLANNED]
- **Plan**: [02_implementation-plan.md]({NNN}_{SLUG}/plans/02_implementation-plan.md)
```

### Implementation Completion
```markdown
- **Status**: [COMPLETED]
- **Completed**: 2026-01-08
- **Summary**: [03_execution-summary.md]({NNN}_{SLUG}/summaries/03_execution-summary.md)
```

### Artifact Linking Format

**Rule**: Use inline format when there is exactly 1 artifact of a given type. Use multi-line list format when there are 2 or more artifacts of the same type.

#### Single artifact (inline):
```markdown
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

#### Multiple artifacts (multi-line list):
```markdown
- **Research**:
  - [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
  - [02_supplemental.md]({NNN}_{SLUG}/reports/02_supplemental.md)
```

The label line (`- **Research**:`) ends with a colon and no link when multi-line. Each artifact gets its own `  - [filename](path)` line indented with 2 spaces.

#### Count-Aware Insertion Logic

When adding a new artifact link:

1. **No existing line**: Insert inline format `- **Type**: [file](path)`
2. **Existing inline (1 artifact)**: Convert to multi-line, adding both old and new links
3. **Existing multi-line (2+ artifacts)**: Append new `  - [file](path)` item

#### Detection Patterns

- **No existing line**: `- **{Type}**:` not found in task entry
- **Existing inline**: Line matches `- **{Type}**: \[.*\]\(.*\)` (has link on same line)
- **Existing multi-line**: Line matches `- **{Type}**:$` (ends with colon, no link)

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

**System-specific naming**: Claude Code uses `specs/{NNN}_{SLUG}/` (no prefix).
OpenCode uses `specs/OC_{NNN}_{SLUG}/` (OC_ prefix). This distinction identifies
which system created each task.

**DO NOT** create directories at task creation time. The `/task` command only:
1. Updates `specs/state.json` (adds task to active_projects)
2. Updates `specs/TODO.md` (adds task entry)

**WHO creates directories**: Artifact-writing agents (researcher, planner, implementer) create directories with `mkdir -p` when writing their first artifact to a task.

**WHY**: Empty directories provide no value (git doesn't track them), clutter the filesystem, and make task creation unnecessarily complex.

### Correct Pattern
```bash
# When writing an artifact (e.g., research report)
padded_num=$(printf "%03d" "$task_num")
mkdir -p "specs/${padded_num}_${slug}/reports"
write "specs/${padded_num}_${slug}/reports/01_research-findings.md"
```

### Incorrect Pattern
```bash
# DO NOT do this at task creation time
mkdir -p "specs/${task_num}_${slug}"  # Wrong! Creates empty directory

# Also incorrect: unpadded directory numbers
mkdir -p "specs/14_${slug}/reports"   # Wrong! Use 014, not 14
```

## Recommended Order Section

The `## Recommended Order` section in TODO.md provides a topologically-sorted list of active tasks based on their dependencies. This helps users identify which tasks to work on next.

### Section Format

```markdown
## Recommended Order

1. **995** -> plan + implement (unblocks 988, 989, 997)
2. **996** -> research (independent)
3. **997** -> implement (independent)
```

### Entry Components

| Component | Description | Example |
|-----------|-------------|---------|
| Position | Auto-numbered, 1-indexed | `1.` |
| Task Number | Bold task identifier | `**995**` |
| Arrow | Visual separator | `->` |
| Action Hint | Next action based on status | `research`, `plan`, `implement` |
| Notes | Dependency relationships | `(unblocks 244)`, `(independent)` |

### Action Hint Derivation

| Task Status | Action Hint |
|-------------|-------------|
| `not_started`, `researching` | `research` |
| `researched`, `planning` | `plan` |
| `planned`, `implementing`, `partial` | `implement` |
| `completed` | `complete` |
| `blocked` | `blocked` |
| `abandoned`, `expanded` | `skip` |

### Utility Script

The `update-recommended-order.sh` script manages the Recommended Order section:

```bash
# Add a task (inserts after its dependencies)
.claude/scripts/update-recommended-order.sh add TASK_NUM

# Remove a task (renumbers remaining entries)
.claude/scripts/update-recommended-order.sh remove TASK_NUM

# Regenerate entire section from state.json dependency graph
.claude/scripts/update-recommended-order.sh refresh
```

### Integration Points

| Command/Skill | Operation | When |
|---------------|-----------|------|
| `/task` | `add TASK_NUM` | After creating new task entry |
| `skill-implementer` | `remove TASK_NUM` | In postflight after task completion |
| `skill-spawn` | `refresh` | After creating spawned tasks |
| `skill-todo` | `remove TASK_NUM` | For each archived task |

### Topological Sort Algorithm

The `refresh` command uses Kahn's algorithm to order tasks:

1. Build dependency graph from `state.json` active_projects
2. Initialize in-degree count for each task (number of uncompleted dependencies)
3. Queue tasks with in-degree 0 (no uncompleted dependencies)
4. Process queue: emit task, decrement in-degree of dependents
5. Repeat until queue is empty

**Circular Dependencies**: If detected, a warning is issued and affected tasks may be omitted from the output.

### Section Placement

The Recommended Order section is placed:
- Before the `## Tasks` section (when Tasks exists)
- At end of file (if no Tasks section)

### Graceful Handling

All operations handle missing section gracefully:
- `add`: Creates section if missing
- `remove`: No-op if section or task not found
- `refresh`: Creates section if missing

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
