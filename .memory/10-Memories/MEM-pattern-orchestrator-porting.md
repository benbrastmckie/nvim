---
title: "When porting the orchestrator system from .claude/ to .opencode/, the dependency"
created: 2026-06-08
tags: [PATTERN]
topic: "task-634"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/634_port_orchestrator_system/summaries/01_port_orchestrator_implementation-summary.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - orchestrator
  - porting
  - state-machine
  - skill-orchestrate
  - dependency-driven
summary: "When porting the orchestrator system from .claude/ to .opencode/, the dependency"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 166
---

# When porting the orchestrator system from .claude/ to .opencode/, the dependency

When porting the orchestrator system from .claude/ to .opencode/, the dependency-driven 4-phase approach (architecture docs first, then state machine skill, then command, then verification) works well for complex multi-file ports. Sub-phases for the state machine (single-task, multi-task, drift+escalation, integration) provide independent verification gates. The skill-orchestrate SKILL.md is 1129 lines and requires careful section-by-section porting to preserve algorithmic structure (Kahn's algorithm, drift thresholds, loop guard limits) while only changing paths and tool names.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
