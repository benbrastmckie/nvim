# Context Index Migration Guide

**Created**: 2026-02-24
**Updated**: 2026-03-01 (Migration Complete)
**Purpose**: Historical reference for the migration from index.md to index.json

## Migration Status: COMPLETED

The migration from `index.md` to `index.json` has been completed as of 2026-03-01. The deprecated `index.md` file has been removed from the repository.

## Overview

The context discovery system uses a machine-readable `index.json` format that enables automated context discovery via jq queries. This guide is preserved as historical reference for the migration process.

## Current Architecture

### Benefits of index.json

1. **Automated Discovery**: Agents can query for relevant context without hardcoded file lists
2. **Budget-Aware Loading**: `line_count` field enables context budget management
3. **Agent-Specific Loading**: `load_when.agents[]` field allows automatic context for agents
4. **Language Routing**: `load_when.task_types[]` supports task-type-based context selection
5. **Deprecation Tracking**: `deprecated` and `replacement` fields for clean transitions
6. **Validation**: JSON Schema enables automated validation

## File Locations

```
.claude/context/
├── index.json           # Machine-readable context discovery (primary)
└── index.schema.json    # JSON Schema definition for validation
```

**Note**: `index.md` was removed on 2026-03-01 after a deprecation period. All agent references now use `index.json`.

## Entry Structure

### Minimal Entry

```json
{
  "path": "core/orchestration/orchestration-core.md",
  "domain": "core",
  "summary": "Essential orchestration patterns",
  "line_count": 248
}
```

### Full Entry

```json
{
  "path": "project/neovim/domain/neovim-api.md",
  "domain": "project",
  "subdomain": "neovim",
  "topics": ["vim-api", "vim-fn", "vim-opt"],
  "keywords": ["vim.api", "vim.fn", "vim.opt", "Neovim"],
  "summary": "vim.* API patterns for Neovim",
  "line_count": 236,
  "load_when": {
    "agents": ["neovim-research-agent", "neovim-implementation-agent"],
    "task_types": ["neovim"]
  }
}
```

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Relative path from `.claude/context/` |
| `domain` | string | `core`, `project`, or `system` |
| `summary` | string | Brief description (max 200 chars) |
| `line_count` | integer | Line count for budget calculation |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `subdomain` | string | Subdomain category (e.g., `neovim`, `latex`) |
| `topics` | array | Semantic topics covered |
| `keywords` | array | Search keywords |
| `load_when` | object | Automatic loading conditions |
| `deprecated` | boolean | If true, file is deprecated |
| `replacement` | string | Path to replacement file |

## load_when Object

The `load_when` object controls automatic context loading:

```json
"load_when": {
  "agents": ["agent-name"],       // Load for specific agents
  "commands": ["/command"],       // Load for specific commands
  "task_types": ["neovim"],        // Load for task languages
  "always": true                  // Always load for domain
}
```

## Migration Steps

### Step 1: Add New Context File Entry

When adding a new context file:

```bash
# Get line count
wc -l < .claude/context/path/to/new-file.md
```

Add entry to `index.json`:

```json
{
  "path": "path/to/new-file.md",
  "domain": "project",
  "subdomain": "neovim",
  "topics": ["topic1", "topic2"],
  "keywords": ["keyword1", "keyword2"],
  "summary": "Brief description",
  "line_count": 150,
  "load_when": {
    "agents": ["relevant-agent"],
    "task_types": ["neovim"]
  }
}
```

### Step 2: Update Existing Entry

When modifying a context file:

1. Update `line_count` if file size changed significantly
2. Update `topics` and `keywords` if content scope changed
3. Update `load_when` if applicable agents/commands changed

### Step 3: Deprecate File

When deprecating a context file:

```json
{
  "path": "old/deprecated-file.md",
  "domain": "core",
  "summary": "Deprecated - use replacement instead",
  "line_count": 100,
  "deprecated": true,
  "replacement": "new/replacement-file.md"
}
```

### Step 4: Update Agent Context References

Update agents to use index.json queries:

```markdown
## Dynamic Context Discovery

Use index.json for automated context discovery:

\`\`\`bash
# Find context files for this agent
jq -r '.entries[] |
  select(.load_when.agents[]? == "agent-name") |
  .path' .claude/context/index.json
\`\`\`
```

## Validation

Run validation script to check index.json:

```bash
.claude/scripts/validate-context-index.sh
```

Checks performed:
- JSON syntax validation
- All paths exist
- Required fields present
- Line counts approximately accurate
- Domain values valid
- Deprecated entries have replacements

## Query Examples

### Find Agent Context

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "neovim-research-agent") |
  .path' .claude/context/index.json
```

### Find Language Context

```bash
jq -r '.entries[] |
  select(.load_when.task_types[]? == "neovim") |
  .path' .claude/context/index.json
```

### Calculate Context Budget

```bash
jq '[.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  .line_count] | add' .claude/context/index.json
```

### Find Non-Deprecated Files

```bash
jq -r '.entries[] |
  select(.deprecated == true | not) |
  .path' .claude/context/index.json
```

## Troubleshooting

### Entry Not Found in Query

Check that:
1. `load_when` field includes the agent/language/command
2. Entry is not marked `deprecated: true`
3. Path exists and is correctly formatted

### Line Count Mismatch

Run validation with fix option:

```bash
.claude/scripts/validate-context-index.sh --fix
```

### Schema Validation Fails

Use JSON Schema validator:

```bash
# If ajv-cli is available
ajv validate -s .claude/context/index.schema.json -d .claude/context/index.json
```

## Related Documentation

- [Context Discovery Patterns](.claude/context/patterns/context-discovery.md)
- [Agent Frontmatter Standard](.claude/docs/reference/standards/agent-frontmatter-standard.md)
