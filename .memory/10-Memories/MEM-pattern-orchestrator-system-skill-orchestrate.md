---
title: "The .claude/ agent system has TWO distinct orchestrator concepts: (1) skill-orch"
created: 2026-06-08
tags: [PATTERN]
topic: "task-634"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/634_port_orchestrator_system/reports/01_port_orchestrator_research.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - orchestrator-system
  - skill-orchestrate
  - skill-orchestrator
  - lifecycle-state-machine
  - routing-skill
  - dual-system
summary: "The .claude/ agent system has TWO distinct orchestrator concepts: (1) skill-orch"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 178
---

# The .claude/ agent system has TWO distinct orchestrator concepts: (1) skill-orch

The .claude/ agent system has TWO distinct orchestrator concepts: (1) skill-orchestrator is a thin routing skill (160 lines) for command dispatch by task_type, and (2) skill-orchestrate is a 1129-line autonomous lifecycle state machine driving /orchestrate. The .opencode/ system has only the routing skill (128 lines, smaller, lacks context-protection directives) and is missing the state machine skill, the /orchestrate command, and the orchestrate-state-machine.md architecture doc. The .opencode/agent/orchestrator.md file is mislabeled - it documents a 'Read-only chat agent' for question answering, not the orchestrator system.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
