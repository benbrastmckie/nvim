# State JSON Schema

Complete schema reference for state.json. For quick overview, see CLAUDE.md.

## Full Structure

```json
{
  "next_project_number": 346,
  "active_projects": [
    {
      "project_number": 334,
      "project_name": "task_slug_here",
      "status": "planned",
      "language": "general",
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
  }
}
```

## Field Reference

### Project Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project_number` | number | Yes | Unique task identifier |
| `project_name` | string | Yes | Snake_case slug from title |
| `status` | string | Yes | Current status (see Status Values) |
| `language` | string | Yes | Task language (see Language Values) |
| `effort` | string | No | Estimated effort |
| `created` | string | Yes | ISO8601 creation timestamp |
| `last_updated` | string | Yes | ISO8601 last update timestamp |
| `dependencies` | array | No | Array of task numbers this depends on |
| `artifacts` | array | No | Array of artifact objects |

### Language Values

**Core Languages** (always available):

| Language | Description |
|----------|-------------|
| `general` | General programming, web research |
| `meta` | System building, .claude/ modifications |
| `markdown` | Documentation tasks |

**Extension Languages** (when extensions loaded):

Extensions define additional language values via `manifest.json`. Common examples:
- `neovim` - Neovim configuration
- `lean4` - Lean 4 theorem proving
- `latex` - LaTeX documentation
- `typst` - Typst documentation
- `python` - Python development

See `.claude/extensions/*/manifest.json` for available extension languages.

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

### Dependencies Field

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `dependencies` | array of integers | No | `[]` | Task numbers that must complete before this task can start |

**Validation**:
- All task numbers must exist in `active_projects`
- No circular dependencies allowed
- No self-reference allowed

### Repository Health Fields

| Field | Type | Description |
|-------|------|-------------|
| `last_assessed` | string | ISO8601 timestamp of last metrics update |
| `status` | string | `healthy`, `manageable`, `concerning`, or `critical` |

**Note**: Repository-specific metrics (error counts, technical debt indicators) can be added as needed. The /todo command updates this section during archival.

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
| `final_task_number` | number | Last task number before reset (e.g., 1003) |

**Vault Trigger Condition**: When `next_project_number > 1000`, the /todo command initiates vault operation.

**Vault Operation Steps**:
1. Move `specs/archive/` to `specs/vault/{NN-vault}/archive/`
2. Move `specs/archive/state.json` to `specs/vault/{NN-vault}/state.json`
3. Create `specs/vault/{NN-vault}/meta.json` with vault metadata
4. Reinitialize empty `specs/archive/` with fresh state.json
5. Renumber active tasks > 1000 by subtracting 1000
6. Rename task directories from 4-digit to 3-digit format
7. Update all artifact paths and dependencies
8. Reset `next_project_number` to max(renumbered tasks) + 1
9. Increment `vault_count` and add entry to `vault_history`

## Status Values

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

### Completed Task Entry
```json
{
  "project_number": 500,
  "project_name": "implement_new_feature",
  "status": "completed",
  "language": "general",
  "created": "2026-02-25T10:00:00Z",
  "last_updated": "2026-02-25T16:00:00Z",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/500_implement_new_feature/reports/01_research-findings.md",
      "summary": "Research on feature implementation approaches"
    },
    {
      "type": "plan",
      "path": "specs/500_implement_new_feature/plans/02_implementation-plan.md",
      "summary": "4-phase implementation plan"
    },
    {
      "type": "summary",
      "path": "specs/500_implement_new_feature/summaries/03_implementation-summary.md",
      "summary": "Implementation summary with verification results"
    }
  ],
  "completion_summary": "Implemented new feature with full test coverage."
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

- [State Management Rule](../../../rules/state-management.md) - Enforcement and update patterns
- [Artifact Formats Rule](../../../rules/artifact-formats.md) - Artifact naming conventions
- [Skill-Agent Mapping](skill-agent-mapping.md) - Skill routing by language
