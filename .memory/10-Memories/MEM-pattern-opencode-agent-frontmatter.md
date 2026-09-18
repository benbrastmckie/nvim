---
title: "OpenCode agent frontmatter pattern: Only `name` and `description` fields are sup"
created: 2026-06-08
tags: [PATTERN, STANDARD]
topic: "task-635"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/635_port_synthesis_domain_agents/summaries/01_synthesis_domain_agents_implementation-summary.md"
modified: 2026-09-18
retrieval_count: 0
last_retrieved: null
keywords:
  - agent-frontmatter
  - allowed-tools
  - model-field
  - opencode
  - port-pattern
  - synthesis-agent
  - validation
summary: "OpenCode agent frontmatter pattern: Only `name` and `description` fields are sup"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 289
---

# OpenCode agent frontmatter pattern: Only `name` and `description` fields are sup

OpenCode agent frontmatter pattern: Only `name` and `description` fields are supported. The `model` field causes 'Model not found' errors because parseModel() splits on '/'. When porting from .claude/ to .opencode/: (1) strip `model:` line entirely, (2) strip `allowed-tools:` line entirely (document minimal tool surface inline in Overview instead, since OpenCode does not enforce tool restrictions via frontmatter), (3) update all `.claude/context/` path references to `.opencode/context/`, (4) update all `.claude/extensions/` to `.opencode/extensions/`, (5) replace `Agent tool`/`Agent(...)` with `Task tool`/`Task(...)`. Frontmatter is exactly 5 lines: `---` opener, `name:`, `description:`, `---` closer.

## Merged From MEM-standard-opencode-agent-frontmatter

**Original Title**: OpenCode agent frontmatter must NOT include the 'model:' field
**Merged**: 2026-09-18
**Overlap Score**: 80%

OpenCode agent frontmatter must NOT include the 'model:' field. Per .opencode/docs/reference/standards/agent-frontmatter-standard.md, the model field causes 'Model not found' errors because OpenCode's parseModel() function splits model strings by '/', so bare aliases like 'opus' produce {providerID: 'opus', modelID: ''} which fails model resolution. OpenCode uses session model selection via the TUI model picker. When porting agents from .claude/ to .opencode/, the 'model: sonnet' / 'model: opus' / 'model: haiku' lines must be deleted. This applies to 24+ domain agents in present and founder extensions that still have the 'model: sonnet' line.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
