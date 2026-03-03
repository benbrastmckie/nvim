# System Overview

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: High-level architecture for Logos/Theory's command-skill-agent system

---

## Architecture Summary

Logos/Theory uses a three-layer delegation architecture:

1. **Commands**: Parse arguments and validate tasks
2. **Skills**: Own lifecycle and delegate to agents
3. **Agents**: Execute domain-specific work

---

## Component Responsibilities

| Component | Responsibility |
|----------|----------------|
| Command | Input validation, routing decision, delegation to skill |
| Skill | Preflight/postflight, artifact validation, status updates |
| Agent | Domain work, artifact creation, structured return |

---

## Workflow Example

```
/research 191
  -> command validates task
  -> skill-researcher handles lifecycle
  -> lean-research-agent writes report
  -> skill updates specs/state.json + specs/TODO.md
```

---

## Related Documentation

- `@.opencode/context/core/orchestration/orchestration-core.md`
- `@.opencode/context/core/orchestration/orchestration-validation.md`
- `@.opencode/context/core/orchestration/state-management.md`
