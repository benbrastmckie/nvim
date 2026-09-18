---
title: "When team skills (skill-team-research, skill-team-plan) need to synthesize outpu"
created: 2026-05-25
tags: [PATTERN]
topic: "task-609"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/609_refactor_team_research_context_protection/summaries/01_context-protection-summary.md"
modified: 2026-05-25
retrieval_count: 0
last_retrieved: null
keywords:
  - synthesis-agent
  - team-research
  - context-protection
  - lead-pattern
  - teammate-synthesis
  - skill-team-research
summary: "When team skills (skill-team-research, skill-team-plan) need to synthesize outpu"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 150
---

# When team skills (skill-team-research, skill-team-plan) need to synthesize outpu

When team skills (skill-team-research, skill-team-plan) need to synthesize outputs from multiple parallel teammates, dispatch a named synthesis-agent rather than having the lead read all files inline. The synthesis-agent runs in a fresh context, reads all teammate finding files as @-references, and returns a compact summary (~200 words) to the lead. This keeps lead context growth at ~900 tokens instead of 7-21k tokens. The synthesis-agent is at .claude/agents/synthesis-agent.md and has allowed-tools: Read, Write only.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
