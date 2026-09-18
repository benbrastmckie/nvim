---
title: "OpenCode's synthesis-agent pattern differs from .claude/: (1) The .claude/ team-"
created: 2026-06-08
tags: [PATTERN]
topic: "task-635"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/635_port_synthesis_domain_agents/reports/01_synthesis_domain_agents_research.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - synthesis-agent
  - opencode
  - team-mode
  - context-protection
  - port-pattern
  - team-research
summary: "OpenCode's synthesis-agent pattern differs from .claude/: (1) The .claude/ team-"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 193
---

# OpenCode's synthesis-agent pattern differs from .claude/: (1) The .claude/ team-

OpenCode's synthesis-agent pattern differs from .claude/: (1) The .claude/ team-mode skills fork a dedicated synthesis-agent that reads teammate outputs in fresh context; the .opencode/ team-mode skills do synthesis INLINE in the lead, causing lead context to grow by 7-21k tokens per team run vs ~250 tokens with the synthesis-agent pattern. (2) The .opencode/ context/reference/team-wave-helpers.md describes synthesis as an inline lead procedure (lines 232-281), contradicting the .claude/ pattern. (3) Porting the synthesis-agent requires: strip 'model: sonnet' from frontmatter, update .claude/context/ -> .opencode/context/ path references, preserve allowed-tools: Read, Write restriction.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
