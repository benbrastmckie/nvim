---
title: "OpenCode agent frontmatter must NOT include the 'model:' field"
created: 2026-06-08
tags: [STANDARD]
topic: "task-635"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/635_port_synthesis_domain_agents/reports/01_synthesis_domain_agents_research.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - opencode
  - agent-frontmatter
  - model-field
  - port-pattern
  - validation
summary: "OpenCode agent frontmatter must NOT include the 'model:' field"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "merged_into:MEM-pattern-opencode-agent-frontmatter"
token_count: 182
---

# OpenCode agent frontmatter must NOT include the 'model:' field

OpenCode agent frontmatter must NOT include the 'model:' field. Per .opencode/docs/reference/standards/agent-frontmatter-standard.md, the model field causes 'Model not found' errors because OpenCode's parseModel() function splits model strings by '/', so bare aliases like 'opus' produce {providerID: 'opus', modelID: ''} which fails model resolution. OpenCode uses session model selection via the TUI model picker. When porting agents from .claude/ to .opencode/, the 'model: sonnet' / 'model: opus' / 'model: haiku' lines must be deleted. This applies to 24+ domain agents in present and founder extensions that still have the 'model: sonnet' line.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
