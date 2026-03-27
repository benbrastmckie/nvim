# State Management Schema Reference

Complete schema reference for state.json, TODO.md, and artifact formats. For behavioral rules (transitions, update patterns), see `.claude/rules/state-management.md`.

## state.json Full Structure

```json
{
  "next_project_number": 346,
  "active_projects": [
    {
      "project_number": 334,
      "project_name": "task_slug_here",
      "status": "planned",
      "language": "general",
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
      "completion_summary": "1-3 sentence description of what was accomplished",
      "roadmap_items": ["Optional explicit roadmap item text to match"],
      "claudemd_suggestions": "Description of .claude/ changes (meta tasks only)"
    }
  ],
  "repository_health": {
    "last_assessed": "2026-01-29T18:38:22Z",
    "status": "healthy"
  },
  "vault_count": 0,
  "vault_history": []
}
```

## TODO.md Entry Format

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

## Field Reference

### Project Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project_number` | number | Yes | Unique task identifier |
| `project_name` | string | Yes | Snake_case slug from title |
| `status` | string | Yes | Current status (see Status Values) |
| `language` | string | Yes | Task language (see Language Values) |
| `task_type` | string/null | No | Sub-type for finer-grained routing |
| `effort` | string | No | Estimated effort |
| `created` | string | Yes | ISO8601 creation timestamp |
| `last_updated` | string | Yes | ISO8601 last update timestamp |
| `dependencies` | array | No | Array of task numbers this depends on |
| `artifacts` | array | No | Array of artifact objects |
| `next_artifact_number` | number | No | Next artifact sequence number (default: 1) |

### task_type Field

The `task_type` field enables finer-grained routing within a language, particularly useful for extension languages.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `task_type` | string or null | No | `null` | Sub-type for routing within a language |

**Routing Behavior**: When a command is invoked on a task:
1. Check if `task_type` is set
2. If set, route to skill matching task_type
3. If null or missing, fall back to default routing

**Format Conversion**:

| state.json | TODO.md |
|------------|---------|
| `null` | (not shown) |
| `"market"` | `- **Type**: market` |
| `"analyze"` | `- **Type**: analyze` |

### Language Values

**Core Languages** (always available):

| Language | Description |
|----------|-------------|
| `general` | General programming, web research |
| `meta` | System building, .claude/ modifications |
| `markdown` | Documentation tasks |

**Extension Languages** (when extensions loaded): See `.claude/extensions/*/manifest.json`.

### Unified Artifact Numbering (next_artifact_number)

The `next_artifact_number` field enables unified artifact numbering where all artifact types (reports, plans, summaries) share a single sequence number per task within a "round" of work.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `next_artifact_number` | number | 1 | Next artifact sequence number to use |

**Semantics**:
- **Research advances the sequence**: Research reads `next_artifact_number`, uses it for artifact naming, then increments it in postflight
- **Plan/Summary reuse current**: Plan and summary skills use `(next_artifact_number - 1)` since they're completing the current round started by research
- **Round concept**: A research report starts a new "round", and the corresponding plan and summary share that round's number

**Example Flow**:
```
Round 1:
  /research 309  -> reads 1, creates 01_report.md, increments to 2
  /plan 309      -> reads 2, uses (2-1)=1, creates 01_plan.md
  /implement 309 -> reads 2, uses (2-1)=1, creates 01_summary.md

Round 2 (after blocker):
  /research 309  -> reads 2, creates 02_report.md, increments to 3
  /plan 309      -> reads 3, uses (3-1)=2, creates 02_plan.md
  /implement 309 -> reads 3, uses (3-1)=2, creates 02_summary.md
```

**Team Mode Naming**:
- Teammate artifacts use `{NN}_{letter}-findings.md` pattern (e.g., `01_teammate-a-findings.md`)
- Synthesis artifacts use `{NN}_{slug}.md` pattern (same number, no letter)
- All artifacts from the same research round share the same base number

**Backward Compatibility**:
When `next_artifact_number` is missing (legacy tasks), skills fall back to directory scanning:
```bash
# Fallback: count existing artifacts to determine next number
count=$(ls "specs/${padded_num}_${slug}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
artifact_number=$((count + 1))
```

### Artifact Object Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Artifact type: `research`, `plan`, `summary`, `implementation` |
| `path` | string | Yes | Relative path from project root |
| `summary` | string | Yes | Brief 1-sentence description |

### Completion Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `completion_summary` | string | Yes (when completed) | 1-3 sentence summary of accomplishment |
| `roadmap_items` | array | No | Explicit ROAD_MAP.md item texts (non-meta only) |
| `claudemd_suggestions` | string | Yes (meta only) | .claude/ changes made, or "none" |

**Responsibility Split**:
- **`/implement` (Producer)**: Reports what was changed factually
- **`/todo` (Consumer)**: Evaluates content and decides what warrants CLAUDE.md updates

### Dependencies Field

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `dependencies` | array of integers | No | `[]` | Task numbers that must complete before this task can start |

**Validation**:
- All task numbers must exist in `active_projects`
- No circular dependencies allowed
- No self-reference allowed

**Format Conversion**:

| state.json | TODO.md |
|------------|---------|
| `[]` | `None` |
| `[35]` | `Task #35` |
| `[35, 36]` | `Task #35, Task #36` |

### Repository Health Fields

| Field | Type | Description |
|-------|------|-------------|
| `last_assessed` | string | ISO8601 timestamp of last metrics update |
| `status` | string | `healthy`, `manageable`, `concerning`, or `critical` |

### Vault Fields

The vault system manages task number cycling when `next_project_number` exceeds 1000.

| Field | Type | Description |
|-------|------|-------------|
| `vault_count` | number | Number of completed vault archival operations (0 initially) |
| `vault_history` | array | History of vault operations with metadata |

**Vault History Entry Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `vault_number` | number | Sequential vault number (1-indexed) |
| `vault_dir` | string | Path to vault directory (e.g., `specs/vault/01-vault/`) |
| `created_at` | string | ISO8601 timestamp when vault was created |
| `task_range` | string | Range of task numbers archived (e.g., `1-999`) |
| `archived_count` | number | Number of tasks archived to vault |
| `final_task_number` | number | Last task number before reset |

**Vault Trigger Condition**: When `next_project_number > 1000`, the /todo command initiates vault operation.

**Vault Operation Steps**:
1. Move `specs/archive/` to `specs/vault/{NN-vault}/archive/`
2. Create `specs/vault/{NN-vault}/meta.json` with vault metadata
3. Reinitialize empty `specs/archive/` with fresh state.json
4. Renumber active tasks > 1000 by subtracting 1000
5. Rename task directories from 4-digit to 3-digit format
6. Update all artifact paths and dependencies
7. Reset `next_project_number` to max(renumbered tasks) + 1
8. Increment `vault_count` and add entry to `vault_history`

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

## Artifact Linking Formats

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

### Count-Aware Linking

**Rule**: Use inline format for 1 artifact, multi-line list for 2+ artifacts.

**Single artifact**:
```markdown
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

**Multiple artifacts**:
```markdown
- **Research**:
  - [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
  - [02_supplemental.md]({NNN}_{SLUG}/reports/02_supplemental.md)
```

**Detection Patterns**:
- **No existing line**: `- **{Type}**:` not found in task entry
- **Existing inline**: Line matches `- **{Type}**: \[.*\]\(.*\)` (has link on same line)
- **Existing multi-line**: Line matches `- **{Type}**:$` (ends with colon, no link)

## Directory Creation

### Lazy Directory Creation Rule

Create task directories **lazily** - only when the first artifact is written:
```
specs/{NNN}_{SLUG}/
|- reports/      # Created when research agent writes first report
|- plans/        # Created when planner agent writes first plan
|- summaries/    # Created when implementation agent writes summary
```

**Note**: Directory numbers use 3-digit zero-padding (e.g., `014_task_name`). Use `printf "%03d" $task_num` for path construction.

**System-specific naming**: Claude Code uses `specs/{NNN}_{SLUG}/` (no prefix). OpenCode uses `specs/OC_{NNN}_{SLUG}/` (OC_ prefix).

**Correct Pattern**:
```bash
padded_num=$(printf "%03d" "$task_num")
mkdir -p "specs/${padded_num}_${slug}/reports"
write "specs/${padded_num}_${slug}/reports/01_research-findings.md"
```

## Recommended Order Section

The `## Recommended Order` section in TODO.md provides a topologically-sorted list of active tasks.

### Section Format
```markdown
## Recommended Order

1. **995** -> plan + implement (unblocks 988, 989, 997)
2. **996** -> research (independent)
3. **997** -> implement (independent)
```

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

```bash
.claude/scripts/update-recommended-order.sh add TASK_NUM
.claude/scripts/update-recommended-order.sh remove TASK_NUM
.claude/scripts/update-recommended-order.sh refresh
```

## Examples

### New Task Entry
```json
{
  "project_number": 500,
  "project_name": "implement_new_feature",
  "status": "not_started",
  "language": "general",
  "created": "2026-02-25T10:00:00Z",
  "last_updated": "2026-02-25T10:00:00Z",
  "artifacts": []
}
```

### Task with Dependencies
```json
{
  "project_number": 502,
  "project_name": "integrate_feature",
  "status": "not_started",
  "language": "general",
  "dependencies": [500, 501],
  "created": "2026-02-25T10:30:00Z",
  "last_updated": "2026-02-25T10:30:00Z",
  "artifacts": []
}
```

### Completed Meta Task
```json
{
  "project_number": 510,
  "project_name": "add_merge_command",
  "status": "completed",
  "language": "meta",
  "created": "2026-02-26T09:00:00Z",
  "last_updated": "2026-02-26T12:00:00Z",
  "artifacts": [
    {
      "type": "implementation",
      "path": ".claude/commands/merge.md",
      "summary": "Unified /merge command with GitHub/GitLab detection"
    }
  ],
  "completion_summary": "Created /merge command with platform auto-detection.",
  "claudemd_suggestions": "Added merge.md command, updated CLAUDE.md command reference"
}
```

## Related Documentation

- [State Management Rule](../../../rules/state-management.md) - Behavioral constraints and update patterns
- [Artifact Formats Rule](../../../rules/artifact-formats.md) - Artifact naming conventions
