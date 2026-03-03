# Architecture Overview (Three-Layer Delegation)

**Version**: 2.0
**Created**: 2026-01-19
**Purpose**: Explain the command → skill → agent architecture used by Logos/Theory

---

## System Layers

### Layer 1: Commands

**Location**: `.opencode/commands/`

**Responsibilities**:
- Parse arguments
- Validate task exists and status transitions
- Load minimal routing context
- Delegate to skills (single call)

**Characteristics**:
- Stateless
- Deterministic
- Minimal context load (<10%)

---

### Layer 2: Skills

**Location**: `.opencode/skills/`

**Responsibilities**:
- Own the full lifecycle (preflight → delegate → postflight)
- Load required context files
- Invoke the correct agent via Task tool
- Validate agent return
- Update specs/state.json and specs/TODO.md

**Characteristics**:
- Thin wrapper pattern
- Single agent invocation
- Enforces checkpoint model

---

### Layer 3: Agents

**Location**: `.opencode/agent/`

**Responsibilities**:
- Perform domain-specific reasoning and work
- Create artifacts (plans, reports, summaries)
- Return structured JSON

**Characteristics**:
- Rich context loading
- Long-running operations
- Domain expertise

---

## Delegation Flow

```
User Request
    ↓
Command (/research, /plan, /implement)
    ↓
Skill (skill-researcher, skill-planner, skill-implementer)
    ↓
Agent (general-research-agent, planner-agent, etc.)
```

---

## Context Loading Strategy

| Layer | Context Load | Files |
|-------|--------------|-------|
| Command | Minimal | routing, validation, task state |
| Skill | Targeted | orchestration + formats + task data |
| Agent | Full | project domain + standards |

---

## Benefits

- **Modularity**: Clear separation of concerns
- **Traceability**: Session IDs tracked through each layer
- **Safety**: Validation gates prevent invalid state changes
- **Scalability**: New commands can be added without modifying core logic

---

## Related Documentation

- `orchestration-core.md` - Core patterns
- `orchestration-validation.md` - Validation strategy
- `state-management.md` - Status management
- `@.opencode/context/core/architecture/system-overview.md` - Extended architecture
