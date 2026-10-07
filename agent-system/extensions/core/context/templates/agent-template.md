# Agent Template (Context Reference)

**Purpose**: Canonical agent structure used by `meta-builder-agent` when generating new agents via the `/meta` command.

For the user-facing tutorial version of this template, see `.claude/docs/templates/agent-template.md` and `.claude/docs/guides/creating-agents.md`.

## Frontmatter Standard

All agents use the minimal frontmatter format defined in `.claude/docs/reference/standards/agent-frontmatter-standard.md`:

```yaml
---
name: <agent-name>
description: <brief description of agent purpose>
model: opus
---
```

**Required fields**: `name`, `description`

**Optional fields**: `model` (values: `opus`, `sonnet`, `haiku`), `tools`, `disallowedTools`,
`mcpServers`, and the rest of the supported field set documented in
`.claude/docs/reference/standards/agent-frontmatter-standard.md`. A `tools:` block IS supported
(comma-separated string allowlist) — see that standard for the full field table and semantics.

**Do NOT include** these fields - they are not supported by the current Agent tool:
- `mode`
- `version`
- `temperature`
- `max_tokens`
- `timeout`
- `allowed-tools:` (SKILL.md/slash-command field, not a subagent field — use `tools:`)
- `mcp-servers:` (hyphenated misspelling — use `mcpServers:`)
- `return_format`

## Agent Body Structure

Every agent body follows this canonical structure:

```markdown
# <Agent Name>

<One-paragraph overview.>

## Context References

- `@.claude/context/formats/return-metadata-file.md` - Always load
- <domain-specific @-references>

## Execution Flow

### Stage 0: Initialize Early Metadata
Create `.return-meta.json` with `status: "in_progress"` before any substantive work.

### Stage 1: Parse Delegation Context
Extract `session_id`, `task_number`, `task_name`, `task_type`, `delegation_depth`.

### Stage 2: Load Context
Use adaptive query from `context-discovery.md`.

### Stage 3: Execute Core Work
<Domain-specific work.>

### Stage 4: Write Artifacts
Create artifacts in `specs/{NNN}_{SLUG}/{reports,plans,summaries}/`.

### Stage 5: Validate Artifacts
Verify files exist, non-empty, required sections present.

### Stage 6: Write Final Metadata
Status values: `researched`, `planned`, `implemented`, `partial`, `failed`. Never `completed`.

### Stage 7: Return Brief Summary
Return 3-6 bullet points, NOT JSON.

## Error Handling

See `.claude/rules/error-handling.md`. Agent-specific overrides documented here.

## Critical Requirements

- Create early metadata before substantive work
- Write final metadata before returning
- Never use `completed` status value
- Never return JSON to console
```

## Agent Type Variants

### Research Agent

- Typical model: `opus`
- Primary artifact: `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md`
- Key sources: web search, codebase exploration, MCP tools
- Status transitions: `researching` -> `researched`

### Planning Agent

- Typical model: `opus`
- Primary artifact: `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`
- Plan format: see `.claude/rules/plan-format-enforcement.md`
- Status transitions: `planning` -> `planned`

### Implementation Agent

- Typical model: (default, omit `model:` field)
- Primary artifacts: source files, tests, configuration
- Secondary artifact: `specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md`
- Phase-level git commits: `task {N} phase {P}: {name}`
- Status transitions: `implementing` -> `implemented`/`partial`
- Carry the bounded-wait MUST / MUST NOT bullet pair from
  `.claude/context/patterns/bounded-build-waiter.md`'s "Canonical Agent-Contract Bullet
  (Generated-Copy Source)" section in `## Critical Requirements`, verbatim — this is
  forward-looking only (it covers a newly authored agent by construction) and is not a
  substitute for propagating the bullet pair into any already-existing agent definition.

## Related Context

- `.claude/context/formats/return-metadata-file.md` - Metadata schema
- `.claude/context/formats/subagent-return.md` - Return format spec
- `.claude/context/patterns/context-discovery.md` - Context query pattern
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Frontmatter standard
- `.claude/docs/guides/creating-agents.md` - User-facing creation guide
