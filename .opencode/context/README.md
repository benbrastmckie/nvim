# Context Organization

**Version**: 3.0  
**Updated**: 2026-01-05 (Task 314 - Context Refactor)  
**Purpose**: Organize context files for efficient loading and clear separation of concerns

---

## Directory Structure

```
.opencode/context/
├── core/                           # General/reusable context (36 files)
│   ├── orchestration/              # System orchestration (8 files)
│   │   ├── architecture.md         # Three-layer delegation pattern
│   │   ├── orchestrator.md         # Orchestrator design and guide
│   │   ├── routing.md              # Routing logic and patterns
│   │   ├── delegation.md           # Delegation patterns and safety
│   │   ├── validation.md           # Validation strategies and rules
│   │   ├── state-management.md     # State and artifact management
│   │   └── sessions.md             # Session management
│   │
│   ├── formats/                    # Output formats and structures (7 files)
│   │   ├── command-structure.md    # Command files as agents
│   │   ├── subagent-return.md      # Subagent return format
│   │   ├── command-output.md       # Command output format
│   │   ├── plan-format.md          # Implementation plan format
│   │   ├── report-format.md        # Research report format
│   │   ├── summary-format.md       # Summary format
│   │   └── frontmatter.md          # Frontmatter standard
│   │
│   ├── standards/                  # Quality standards (8 files)
│   │   ├── code-patterns.md        # Code and pattern standards
│   │   ├── error-handling.md       # Error handling patterns
│   │   ├── git-safety.md           # Git safety patterns
│   │   ├── documentation.md        # Documentation standards
│   │   ├── testing.md              # Testing standards
│   │   ├── xml-structure.md        # XML structure patterns
│   │   ├── task-management.md      # Task management standards
│   │   └── analysis-framework.md   # Analysis framework
│   │
│   ├── workflows/                  # Workflow patterns (5 files)
│   │   ├── command-lifecycle.md    # Command lifecycle
│   │   ├── status-transitions.md   # Status transition rules
│   │   ├── task-breakdown.md       # Task breakdown patterns
│   │   ├── review-process.md       # Review process workflow
│   │   └── preflight-postflight.md # Workflow timing standards
│   │
│   ├── templates/                  # Reusable templates (6 files)
│   │   ├── agent-template.md       # Agent template
│   │   ├── subagent-template.md    # Subagent template
│   │   ├── command-template.md     # Command template
│   │   ├── orchestrator-template.md # Orchestrator template
│   │   ├── delegation-context.md   # Delegation context template
│   │   └── state-template.json     # State.json template
│   │
│   └── schemas/                    # JSON/YAML schemas (2 files)
│       ├── frontmatter-schema.json # Frontmatter JSON schema
│       └── subagent-frontmatter.yaml # Subagent frontmatter template
│
├── project/                        # Logos/Theory-specific context
│   ├── meta/                       # Meta-builder context (4 files)
│   │   ├── domain-patterns.md      # Domain pattern recognition
│   │   ├── architecture-principles.md # Architecture principles
│   │   ├── meta-guide.md           # Meta-builder guide
│   │   └── interview-patterns.md   # Interview patterns
│   │
│   ├── lean4/                      # Lean 4 domain knowledge
│   │   ├── domain/
│   │   ├── patterns/
│   │   ├── processes/
│   │   ├── standards/
│   │   ├── templates/
│   │   └── tools/
│   │
│   ├── logic/                      # Logic domain knowledge
│   │   ├── domain/
│   │   ├── processes/
│   │   └── standards/
│   │
│   ├── math/                       # Math domain knowledge
│   │   ├── algebra/
│   │   ├── lattice-theory/
│   │   ├── order-theory/
│   │   └── topology/
│   │
│   ├── physics/                    # Physics domain knowledge
│   │   └── dynamical-systems/
│   │
│   └── repo/                       # Repository-specific
│       ├── project-overview.md
│       └── self-healing-implementation-details.md
│
└── README.md                       # This file
```

---

## Core vs Project

### core/ (36 files across 6 directories)
**Purpose**: General, reusable context applicable to any project

**Contents**:
- **orchestration/** - System architecture, routing, delegation, state management
- **formats/** - Output formats for plans, reports, summaries, returns
- **standards/** - Quality standards for code, errors, git, documentation, testing
- **workflows/** - Workflow patterns for commands, status transitions, reviews
- **templates/** - Reusable templates for agents, commands, orchestrator
- **schemas/** - JSON/YAML schemas for validation

**When to use**: Context that doesn't depend on Logos/Theory specifics

**Key Files**:
- `orchestration/architecture.md` - Three-layer delegation pattern (critical for meta-builder)
- `formats/command-structure.md` - Commands as agents pattern
- `workflows/preflight-postflight.md` - Workflow timing standards
- `orchestration/state-management.md` - State management and fast lookup patterns (8x faster than specs/TODO.md)

### project/
**Purpose**: Logos/Theory-specific domain knowledge

**Contents**:
- **meta/** - Meta-builder context (domain patterns, architecture principles)
- **lean4/** - Lean 4 theorem proving knowledge
- **logic/** - Logic domain knowledge (modal, temporal)
- **math/** - Math domain knowledge (algebra, topology, etc.)
- **physics/** - Physics domain knowledge
- **repo/** - Repository-specific information

**When to use**: Context specific to Logos/Theory's domains

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
- Files: `project/lean4/*`, `project/logic/*`, etc.
- Purpose: Domain-specific work with full context

**Performance Optimization**:
- State.json queries are 8x faster than specs/TODO.md parsing (12ms vs 100ms)
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

### For General/Reusable Context
Add to `core/`:
- Orchestration → `core/orchestration/`
- Formats → `core/formats/`
- Standards → `core/standards/`
- Workflows → `core/workflows/`
- Templates → `core/templates/`
- Schemas → `core/schemas/`

### For Logos/Theory-Specific Context
Add to `project/`:
- Meta-builder → `project/meta/`
- Lean 4 → `project/lean4/`
- Logic → `project/logic/`
- Math → `project/math/`
- Physics → `project/physics/`
- Repo-specific → `project/repo/`

---

## Migration from Old Structure (Task 314 - 2026-01-05)

### Changes Summary
- **File Count**: 48 → 36 files (25% reduction)
- **Directories**: 5 → 6 directories (better organization)
- **New Files**: 3 critical architecture files added
- **Merged Files**: 6 pairs of redundant files consolidated
- **Renamed Files**: 9 files renamed for consistency

### Directory Mapping

**Old** → **New**:
- `system/` → `orchestration/` (system-level files)
- `standards/` → `formats/` (format files) + `standards/` (quality standards)
- `workflows/` → `workflows/` (kept, some files moved)
- `templates/` → `templates/` (kept, some files moved to schemas/)
- `schemas/` → `schemas/` (kept, added subagent-frontmatter.yaml)

### New Files Created
1. `orchestration/architecture.md` - Three-layer delegation pattern
2. `formats/command-structure.md` - Commands as agents
3. `workflows/preflight-postflight.md` - Workflow timing standards

### Merged Files
1. `orchestrator-design.md` + `orchestrator-guide.md` → `orchestration/orchestrator.md`
2. `routing-guide.md` + `routing-logic.md` → `orchestration/routing.md`
3. `delegation.md` + `delegation-guide.md` → `orchestration/delegation.md`
4. `validation-strategy.md` + `validation-rules.md` → `orchestration/validation.md`
5. `state-management.md` + `artifact-management.md` → `orchestration/state-management.md`
6. `code.md` + `patterns.md` → `standards/code-patterns.md`

### Meta-Builder Files Moved
- `standards/domain-patterns.md` → `project/meta/domain-patterns.md`
- `standards/architecture-principles.md` → `project/meta/architecture-principles.md`
- `templates/meta-guide.md` → `project/meta/meta-guide.md`
- `workflows/interview-patterns.md` → `project/meta/interview-patterns.md`

### Benefits
- ✅ Single source of truth for each concept
- ✅ Clear naming and logical grouping
- ✅ Critical architecture documentation for meta-builder
- ✅ Improved organization (orchestration vs formats vs standards)
- ✅ State.json optimization patterns documented
- ✅ Workflow timing standards integrated
