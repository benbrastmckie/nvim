# Context Organization

**Updated**: 2026-03-25 (Task 288 - Flatten context structure)
**Purpose**: Organize context files for efficient loading and clear separation of concerns

---

## Directory Structure

```
.claude/context/
├── orchestration/              # System orchestration
├── formats/                    # Output formats and structures
├── standards/                  # Quality standards
├── workflows/                  # Workflow patterns
├── templates/                  # Reusable templates
├── schemas/                    # JSON/YAML schemas
├── checkpoints/                # Checkpoint patterns (gate-in, gate-out)
├── patterns/                   # Implementation patterns
├── guides/                     # Usage guides
├── reference/                  # Reference documentation
├── architecture/               # Architecture documentation
├── troubleshooting/            # Troubleshooting guides
├── meta/                       # Meta-builder context
├── processes/                  # Process documentation
├── repo/                       # Repository-specific context
├── routing.md                  # Language-based routing
├── validation.md               # Return validation
├── index.json                  # Automated context discovery index (rebuilt by loader)
├── core-index-entries.json     # Core index entries (always loaded, survives reloads)
├── index.schema.json           # Schema for index.json
└── README.md                   # This file
```

---

## Role Boundaries

This directory contains **core agent system patterns** plus **extension domain
knowledge** merged by the extension loader. It is the primary context source
for agent orchestration, command execution, and domain-specific work.

What belongs here:
- Orchestration patterns, formats, standards, templates for agents
- Extension context (copied here automatically when extensions are loaded)

What does NOT belong here:
- Project-specific conventions -- use `.context/`
- Learned facts from development -- use `.memory/`
- User preferences -- handled by Claude auto-memory

For the full multi-layer architecture, see `architecture/context-layers.md`.

---

## Directory Purposes

### Agent System Context
- **orchestration/** - System architecture, routing, delegation, state management
- **formats/** - Output formats for plans, reports, summaries, returns
- **standards/** - Quality standards for code, errors, git, documentation, testing
- **workflows/** - Workflow patterns for commands, status transitions, reviews
- **templates/** - Reusable templates for agents, commands, orchestrator
- **schemas/** - JSON/YAML schemas for validation
- **checkpoints/** - Gate-in/gate-out checkpoint patterns
- **patterns/** - Implementation patterns (thin-wrapper, metadata, jq workarounds)
- **guides/** - Usage guides for context loading and discovery
- **reference/** - Reference documentation (artifact templates, workflow diagrams)
- **architecture/** - System architecture overview and component checklists
- **troubleshooting/** - Workflow interruption recovery guides

### Domain-Specific Context
- **meta/** - Meta-builder context (domain patterns, architecture principles)
- **processes/** - Process documentation (research, planning, implementation workflows)
- **repo/** - Repository-specific information (project overview, self-healing details)

---

## Context Loading Strategy

### Three-Tier Loading

**Tier 1: Orchestrator (Minimal)**
- Budget: <5% context window (~10KB)
- Files: `orchestration/routing.md`, `orchestration/delegation.md`
- Purpose: Routing and delegation safety

**Tier 2: Commands (Targeted)**
- Budget: 10-20% context window (~20-40KB)
- Files: `formats/subagent-return.md`, `workflows/status-transitions.md`, command-specific
- Purpose: Command validation and formatting

**Tier 3: Agents (Domain-Specific)**
- Budget: 60-80% context window (~120-160KB)
- Files: Domain-specific context, extension context
- Purpose: Domain-specific work with full context

**Performance Optimization**:
- State.json queries are 8x faster than TODO.md parsing (12ms vs 100ms)
- See `orchestration/state-management.md` for query patterns

---

## File Naming Conventions

**Pattern**: `{topic}-{type}.md`

**Examples**:
- `subagent-return.md` (not `subagent-return-format.md`)
- `plan-format.md` (not `plan.md`)
- `code-patterns.md` (not `code.md` or `patterns.md`)

**Rules**:
- Use kebab-case
- Be descriptive but concise
- Avoid redundant suffixes (e.g., `-format` only when needed for clarity)
- Group by purpose in appropriate directory

---

## Adding New Context Files

Place files in the appropriate top-level directory:
- Orchestration -> `orchestration/`
- Formats -> `formats/`
- Standards -> `standards/`
- Workflows -> `workflows/`
- Templates -> `templates/`
- Schemas -> `schemas/`
- Patterns -> `patterns/`
- Meta-builder -> `meta/`
- Repo-specific -> `repo/`

---

## Index.json Schema

The `index.json` file enables automated context discovery:

### Entry Structure

```json
{
  "version": "1.0",
  "generated": "2026-03-11T22:13:42Z",
  "entries": [
    {
      "path": "README.md",
      "domain": "core",
      "subdomain": "overview",
      "topics": ["context-system", "lazy-loading"],
      "keywords": ["index", "context", "loading"],
      "summary": "Overview of context system",
      "line_count": 100,
      "load_when": {
        "always": true
      }
    }
  ]
}
```

### Entry Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Relative path from context/ directory |
| `domain` | string | Domain category (core, project, extension) |
| `subdomain` | string | Subcategory within domain |
| `topics` | array | High-level topics covered |
| `keywords` | array | Search keywords |
| `summary` | string | Brief description |
| `line_count` | integer | File size for budget calculation |
| `load_when` | object | Loading conditions |

### Load Conditions

```json
// Always load
"load_when": { "always": true }

// Load for specific agents
"load_when": { "agents": ["planner-agent"] }

// Load for specific commands
"load_when": { "commands": ["/research", "/implement"] }

// Load for specific languages
"load_when": { "task_types": ["meta", "general"] }
```

### Query Examples

```bash
# Find context for an agent
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | .path' .claude/context/index.json

# Find context by topic
jq -r '.entries[] | select(.topics[]? == "routing") | .path' .claude/context/index.json

# Get line counts for budget
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | "\(.line_count)\t\(.path)"' .claude/context/index.json
```
