---
title: "Synthesis fork pattern for team research: The lead should NOT read all teammate "
created: 2026-05-25
tags: [PATTERN]
topic: "task-609"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/609_refactor_team_research_context_protection/reports/01_context-protection-research.md"
modified: 2026-05-25
retrieval_count: 0
last_retrieved: null
keywords:
  - synthesis-fork
  - team-research
  - context-protection
  - anonymous-fork
  - lead-agent
summary: "Synthesis fork pattern for team research: The lead should NOT read all teammate "
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 130
---

# Synthesis fork pattern for team research: The lead should NOT read all teammate 

Synthesis fork pattern for team research: The lead should NOT read all teammate output files inline (anti-pattern accumulating 4-12k tokens). Instead, fork an anonymous agent with the teammate file paths as @-references. The synthesis agent reads files in its own fresh context, performs conflict detection and gap analysis, writes the unified report, and returns a ~200-word summary. Lead context grows by ~250 tokens instead of 7-21k tokens.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
