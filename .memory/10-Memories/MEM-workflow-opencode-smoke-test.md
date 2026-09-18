---
title: "OpenCode static structural smoke test pattern for agent files: when live Task to"
created: 2026-06-08
tags: [WORKFLOW]
topic: "task-635"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/635_port_synthesis_domain_agents/summaries/01_synthesis_domain_agents_implementation-summary.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - opencode
  - smoke-test
  - agent-validation
  - port-verification
  - static-validation
summary: "OpenCode static structural smoke test pattern for agent files: when live Task to"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 194
---

# OpenCode static structural smoke test pattern for agent files: when live Task to

OpenCode static structural smoke test pattern for agent files: when live Task tool dispatch is not available in the agent's context, validate the agent file statically with: (1) `head -5` to verify `---` frontmatter delimiters, (2) `awk` to extract and count frontmatter fields (must be exactly 2: name, description), (3) `grep -nE '^model:|^allowed-tools:'` to confirm none of the unsupported fields exist, (4) extract all `@.opencode/path.md` references and verify each resolves to a real file, (5) `grep -n '\.claude/'` to confirm no .claude/ path leakage, (6) heading-by-heading diff against source to confirm no semantic content dropped. This pattern works for any .opencode/agent/*/port task.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
