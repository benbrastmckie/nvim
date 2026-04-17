# Subagent Template

Canonical template for subagents invoked via the Task tool. See `.claude/context/templates/agent-template.md` for the primary agent template - all subagents share the same structure.

## Frontmatter

Subagents use the minimal agent frontmatter defined in `.claude/docs/reference/standards/agent-frontmatter-standard.md`:

```yaml
---
name: <subagent-name>
description: <brief description of subagent purpose>
model: opus
---
```

## Subagent Body

Subagents follow the same Stage 0 through Stage 7 execution flow documented in `agent-template.md`. The only distinction is that subagents are invoked by skills (not directly by commands) and receive their delegation context from the parent skill rather than from $ARGUMENTS parsing.

### Subagent-Specific Stage 1 (Parse Delegation Context)

When the skill spawns a subagent via the Task tool, the subagent receives delegation context as the initial message:

```json
{
  "session_id": "sess_1736700000_abc123",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "/research", "skill-researcher", "general-research-agent"],
  "timeout": 1800,
  "task_context": {
    "task_number": 42,
    "task_name": "task_slug",
    "task_type": "general"
  },
  "resume_from_partial": false
}
```

The subagent parses this context and extracts the fields it needs. Subagent-specific fields go inside `task_context`.

### Subagent Return Pattern

Subagents write metadata to disk and return a brief text summary to the parent skill. The skill reads the metadata file in its postflight stage.

See `.claude/context/formats/subagent-return.md` for the complete return-format specification.

## Depth Limits

Subagents enforce `delegation_depth < 3` to prevent runaway recursion. A subagent at depth 2 may NOT spawn further subagents via the Task tool.

## Related Context

- `.claude/context/templates/agent-template.md` - Primary agent template
- `.claude/context/formats/subagent-return.md` - Return format specification
- `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- `.claude/context/orchestration/delegation.md` - Delegation safety patterns
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Frontmatter standard
