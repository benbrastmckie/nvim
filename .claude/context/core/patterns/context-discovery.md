# Context Discovery Patterns

**Created**: 2026-02-24
**Purpose**: jq query patterns for automated context discovery using index.json

## Overview

The `index.json` file provides machine-readable metadata for all context files, enabling agents to dynamically discover relevant context without hardcoded file lists.

## Index Location

```
.claude/context/index.json
```

## Query Patterns

### Query by Agent Name

Find all context files that should be loaded for a specific agent:

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "neovim-research-agent") |
  .path' .claude/context/index.json
```

### Query by Language

Find context files for a specific task language:

```bash
jq -r '.entries[] |
  select(.load_when.languages[]? == "neovim") |
  .path' .claude/context/index.json
```

### Query by Command

Find context files relevant to a specific command:

```bash
jq -r '.entries[] |
  select(.load_when.commands[]? == "/implement") |
  .path' .claude/context/index.json
```

### Query by Domain

Find all files in a domain (core, project, system):

```bash
jq -r '.entries[] |
  select(.domain == "core") |
  .path' .claude/context/index.json
```

### Query by Subdomain

Find files in a specific subdomain:

```bash
jq -r '.entries[] |
  select(.subdomain == "neovim") |
  .path' .claude/context/index.json
```

### Query by Topic

Find files covering a specific topic:

```bash
jq -r '.entries[] |
  select(.topics[]? == "delegation") |
  .path' .claude/context/index.json
```

### Query by Keyword

Find files mentioning a keyword:

```bash
jq -r '.entries[] |
  select(.keywords[]? | test("jq"; "i")) |
  .path' .claude/context/index.json
```

### Query Always-Load Files

Find files that should always be loaded:

```bash
jq -r '.entries[] |
  select(.load_when.always == true) |
  .path' .claude/context/index.json
```

### Exclude Deprecated Files

Filter out deprecated files:

```bash
jq -r '.entries[] |
  select(.deprecated == true | not) |
  select(.load_when.agents[]? == "planner-agent") |
  .path' .claude/context/index.json
```

## Budget-Aware Loading

### Get Line Counts for Budget Calculation

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "neovim-research-agent") |
  "\(.line_count)\t\(.path)"' .claude/context/index.json
```

### Filter by Line Count Budget

Load files under a certain line count (e.g., < 300 lines):

```bash
jq -r '.entries[] |
  select(.load_when.languages[]? == "neovim") |
  select(.line_count < 300) |
  .path' .claude/context/index.json
```

### Calculate Total Context Budget

```bash
jq '[.entries[] |
  select(.load_when.agents[]? == "neovim-research-agent") |
  .line_count] | add' .claude/context/index.json
```

## Combined Queries

### Agent + Language

```bash
jq -r '.entries[] |
  select(
    (.load_when.agents[]? == "neovim-implementation-agent") or
    (.load_when.languages[]? == "neovim")
  ) |
  select(.deprecated == true | not) |
  .path' .claude/context/index.json
```

### Command with Budget Limit

```bash
jq -r '.entries[] |
  select(.load_when.commands[]? == "/implement") |
  select(.line_count < 500) |
  "\(.path) (\(.line_count) lines)"' .claude/context/index.json
```

## Agent Integration Pattern

### Standard Agent Context Loading

Agents should load context using this pattern:

```markdown
## Context Discovery

Load context dynamically using index.json:

1. Query for agent-specific context:
   ```bash
   jq -r '.entries[] |
     select(.load_when.agents[]? == "{AGENT_NAME}") |
     .path' .claude/context/index.json
   ```

2. Query for language-specific context (from task):
   ```bash
   jq -r '.entries[] |
     select(.load_when.languages[]? == "{TASK_LANGUAGE}") |
     .path' .claude/context/index.json
   ```

3. Load discovered files using @-references
```

### Priority Loading Strategy

1. Always-load files (critical patterns, standards)
2. Agent-specific files (from `load_when.agents`)
3. Language-specific files (from `load_when.languages`)
4. Topic-specific files (as needed for task)

## Validation

### Check All Paths Exist

```bash
jq -r '.entries[].path' .claude/context/index.json | while read p; do
  [ -f ".claude/context/$p" ] || echo "MISSING: $p"
done
```

### Check Schema Compliance

```bash
# Using ajv-cli if available
ajv validate -s .claude/context/index.schema.json -d .claude/context/index.json
```

## Maintenance

When adding new context files:

1. Add entry to `index.json` with all required fields
2. Set appropriate `load_when` conditions
3. Include accurate `line_count`
4. Run validation to ensure paths exist

When deprecating files:

1. Set `deprecated: true`
2. Add `replacement` field with new file path
3. Update agents that reference the deprecated file
