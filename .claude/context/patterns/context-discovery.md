# Context Discovery Patterns

**Created**: 2026-02-24
**Updated**: 2026-03-30
**Purpose**: jq query patterns for three-layer context discovery

## Three-Layer Architecture

Context is discovered from three independent sources, loaded in parallel:

| Layer | Index | Path Prefix | Description |
|-------|-------|-------------|-------------|
| Agent context | `.claude/context/index.json` | `.claude/context/` | Core patterns + extension context (merged by loader) |
| Project context | `.context/index.json` | `.context/` | User-defined project conventions (may be empty) |
| Project memory | `.memory/` (no index) | `.memory/` | Learned facts, loaded directly as files |

Extension context is merged INTO `.claude/context/index.json` by the extension loader. There is no separate extension query.

## Layer 1: Agent Context

All paths in `.claude/context/index.json` are relative to `.claude/context/`.

### Query by Agent Name

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  .path' .claude/context/index.json
```

### Query by Language

```bash
jq -r '.entries[] |
  select(.load_when.languages[]? == "neovim") |
  .path' .claude/context/index.json
```

### Query by Command

```bash
jq -r '.entries[] |
  select(.load_when.commands[]? == "/implement") |
  .path' .claude/context/index.json
```

### Query by Domain

```bash
jq -r '.entries[] |
  select(.domain == "core") |
  .path' .claude/context/index.json
```

### Query Always-Load Files

```bash
jq -r '.entries[] |
  select(.load_when.always == true) |
  .path' .claude/context/index.json
```

### Exclude Deprecated Files

```bash
jq -r '.entries[] |
  select(.deprecated == true | not) |
  select(.load_when.agents[]? == "planner-agent") |
  .path' .claude/context/index.json
```

### Query by Topic or Keyword

```bash
# By topic
jq -r '.entries[] |
  select(.topics[]? == "delegation") |
  .path' .claude/context/index.json

# By keyword (case-insensitive)
jq -r '.entries[] |
  select(.keywords[]? | test("jq"; "i")) |
  .path' .claude/context/index.json
```

## Layer 2: Project Context

All paths in `.context/index.json` are relative to `.context/`. This layer may have no entries initially.

```bash
# Query project context (safe if file missing or entries empty)
jq -r '.entries[] | .path' .context/index.json 2>/dev/null
```

## Layer 3: Project Memory

`.memory/` files are loaded directly -- no index needed.

```bash
# List all memory files
find .memory -name "*.md" -type f 2>/dev/null
```

## Multi-Layer Discovery

### Full Context for an Agent

Query all three layers to build a complete context set:

```bash
# Layer 1: Agent context (core + extensions)
jq -r --arg a "planner-agent" '.entries[] |
  select(.load_when.agents[]? == $a) |
  ".claude/context/" + .path' .claude/context/index.json

# Layer 2: Project context (if any)
if [ -f .context/index.json ]; then
  jq -r '.entries[] | ".context/" + .path' .context/index.json
fi

# Layer 3: Project memory (independent)
if [ -d .memory ]; then
  find .memory -name "*.md" -type f
fi
```

## Budget-Aware Loading

### Get Line Counts

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  "\(.line_count)\t\(.path)"' .claude/context/index.json
```

### Filter by Line Count Budget

```bash
jq -r '.entries[] |
  select(.load_when.languages[]? == "neovim") |
  select(.line_count < 300) |
  .path' .claude/context/index.json
```

### Calculate Total Context Budget

```bash
jq '[.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  .line_count] | add' .claude/context/index.json
```

## Combined Queries

### Adaptive Context Loading (Recommended Pattern)

Load context that matches any active dimension - always, agent, language, or command:

```bash
# Full combined query for adaptive context loading
jq -r --arg agent "general-implementation-agent" \
      --arg lang "meta" \
      --arg cmd "/implement" '
  .entries[] |
  select(
    (.load_when.always == true) or
    any(.load_when.agents[]?; . == $agent) or
    any(.load_when.languages[]?; . == $lang) or
    any(.load_when.commands[]?; . == $cmd)
  ) |
  select(.deprecated == true | not) |
  .path' .claude/context/index.json
```

**Priority Order**:
1. `always: true` - Universal files loaded for all contexts
2. `agents[]?` - Agent-specific context
3. `languages[]?` - Language-specific context
4. `commands[]?` - Command-specific context

**Empty Array Semantics**:
- Empty arrays `[]` mean "never match this dimension"
- To load unconditionally, use `"always": true`
- Entries must match at least one dimension to be discoverable

### Agent + Language

```bash
jq -r '.entries[] |
  select(
    any(.load_when.agents[]?; . == "general-implementation-agent") or
    any(.load_when.languages[]?; . == "neovim")
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

## Priority Loading Strategy

1. Always-load files (critical patterns, standards)
2. Agent-specific files (from `load_when.agents`)
3. Language-specific files (from `load_when.languages`)
4. Project context (from `.context/index.json`)
5. Project memory (from `.memory/`)
6. Topic-specific files (as needed for task)

## Validation

### Validate Index with Script

```bash
# Run validation script
.claude/scripts/validate-index.sh .claude/context/index.json

# Outputs:
# - Orphaned entries (empty load_when without always:true)
# - Missing files
# - Duplicate paths
# - Budget estimates per agent/language
```

### Check All Paths Exist (Manual)

```bash
jq -r '.entries[].path' .claude/context/index.json | while read p; do
  [ -f ".claude/context/$p" ] || echo "MISSING: $p"
done
```

### Check Command Scope (Domain-Specific Files)

Domain-specific context files (paths under `project/*`) should never have generic workflow
commands in their `load_when.commands` arrays. These files should only be discovered via
their domain-specific agents, languages, and domain-specific commands.

**Generic commands (must NOT appear in project/* entries)**:
`/plan`, `/implement`, `/research`, `/task`, `/revise`, `/review`, `/errors`, `/todo`, `/spawn`

**Domain-specific commands (OK in project/* entries)**:
`/market`, `/analyze`, `/strategy`, `/legal`, `/project`, `/sheet`, `/convert`, `/table`,
`/slides`, `/scrape`, `/grant`, `/deck`, `/learn`

```bash
# Detect project/* entries with generic workflow commands (should return 0)
jq '[.entries[] | select(
  (.path | test("^project/")) and
  any(.load_when.commands[]?;
    . == "/plan" or . == "/implement" or . == "/research" or
    . == "/task" or . == "/revise" or . == "/review" or
    . == "/errors" or . == "/todo" or . == "/spawn")
)] | length' .claude/context/index.json
# Should return 0
```

**Rationale**: Generic commands like `/plan` and `/implement` match ALL tasks regardless of
language. If domain files include these commands, they get loaded for every planning or
implementation operation across all domains, wasting context budget and polluting unrelated
workflows.

### Check for Orphaned Entries

Entries with empty `load_when` arrays (no agents, languages, commands) and without `always: true` are orphaned and will never be loaded:

```bash
jq '[.entries[] | select(
  (.load_when.agents | length) == 0 and
  (.load_when.languages | length) == 0 and
  (.load_when.commands | length) == 0 and
  (.load_when.always == true | not)
)] | length' .claude/context/index.json
# Should return 0
```

## Maintenance

When adding new context files:

1. Add entry to the appropriate `index.json` (agent context or project context)
2. Set appropriate `load_when` conditions
3. Include accurate `line_count`
4. Run validation to ensure paths exist

When deprecating files:

1. Set `deprecated: true`
2. Add `replacement` field with new file path
3. Update agents that reference the deprecated file
