---
name: <agent-name>
description: <brief description of agent purpose>
model: sonnet
# Model tier guide:
#   opus   - Deep reasoning: planning, formal verification, architecture (planner, meta-builder, reviser, lean/formal/math/logic agents)
#   sonnet - General purpose: research, implementation, review, domain tasks (most agents)
#   (omit) - Inherit: utility agents that should respect CLAUDE_CODE_SUBAGENT_MODEL env var
---

# <Agent Name>

<Brief overview of what this agent does and the kind of tasks it handles.>

## Frontmatter Fields

**Required**: `name`, `description`.

**Optional**: `model` (`opus`, `sonnet`, `haiku`), `tools` (comma-separated allowlist, e.g.
`tools: Read, Glob, Grep` — omitting the field does **not** unconditionally grant every native
tool: `AskUserQuestion` is measured withheld from every `Agent`-tool dispatch regardless of this
field's value, see `agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
Subagents" section), `disallowedTools` (comma-separated denylist, camelCase), `mcpServers` (MCP
server access, camelCase). See `.claude/docs/reference/standards/agent-frontmatter-standard.md`
for the complete field table (`permissionMode`, `maxTurns`, `skills`, `hooks`, `memory`,
`background`, `effort`, `color`, `initialPrompt`).

**Do NOT include** these fields — they are not supported by the current Agent tool and are
silently ignored rather than rejected:
- `mode`
- `version`
- `temperature`
- `max_tokens`
- `timeout`
- `allowed-tools:` (SKILL.md/slash-command field, not a subagent field — use `tools:`)
- `mcp-servers:` (hyphenated misspelling — use `mcpServers:`)
- `return_format`

## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata schema (always load)
- `@.claude/context/formats/summary-format.md` - Summary structure (when writing summaries)
- `@.claude/context/patterns/context-discovery.md` - Query pattern for adaptive context loading

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create `specs/{NNN}_{SLUG}/.return-meta.json` with `"status": "in_progress"` BEFORE any substantive work. Include `agent_type`, `delegation_path`, and `session_id` from the delegation context. See `return-metadata-file.md` for the full schema.

Early metadata ensures the orchestrator can recover if the agent is interrupted.

### Stage 1: Parse Delegation Context

Extract standard delegation fields from the Agent tool invocation:
- `task_number`, `task_name`, `task_type`
- `session_id`
- `delegation_depth` (must be < 3)
- `plan_path` or `report_path` (if applicable)

Agent-specific fields go in the `task_context` object.

### Stage 2: Load Context

Use the adaptive query pattern from `context-discovery.md` to load only the files this agent needs for the current task type. Do not load everything up front.

### Stage 3: Execute Core Work

The heart of the agent: research, planning, implementation, etc. Keep this stage focused on producing the primary artifact(s). Read source files, run builds/tests, invoke MCP tools as needed.

### Stage 4: Write Artifacts

Create artifacts in `specs/{NNN}_{SLUG}/` subdirectories using the `MM_{short-slug}.md` naming convention. See `.claude/rules/artifact-formats.md` for the complete naming rules.

### Stage 5: Validate Artifacts

Before returning, verify:
- Artifact file(s) exist on disk
- File size > 0
- Required sections present (for plans and reports)

### Stage 6: Write Final Metadata

Update `specs/{NNN}_{SLUG}/.return-meta.json` with:
- `status`: `"researched"`, `"planned"`, `"implemented"`, `"partial"`, or `"failed"`
- `artifacts`: array of `{path, type, summary}` entries
- `completion_data`: object with `completion_summary` (1-3 sentences).
- `metadata`: agent-specific fields (e.g., `phases_completed`/`phases_total` for implementers)

**Never use status value "completed"** - that value triggers Claude's stop behavior.

### Stage 7: Return Brief Summary

Return 3-6 bullet points summarizing the work done. The skill's postflight step reads the metadata file for machine-readable data; the text return is for human review.

**Never return JSON to the console** - the skill reads metadata from disk.

## Error Handling

See `.claude/rules/error-handling.md` for general patterns. Agent-specific requirements:
- **Timeout**: Mark current phase `[PARTIAL]` in plan file, save progress, write partial metadata
- **Tool failure**: Retry once, then return partial with error description
- **Invalid delegation context**: Write `failed` status to metadata file and return

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0
2. Write final metadata before returning
3. Include session_id from delegation context
4. Validate artifacts before marking complete
5. Return brief text summary (3-6 bullets), NOT JSON

**MUST NOT**:
1. Use status value `"completed"`
2. Return JSON to the console
3. Assume the agent's return ends the workflow - the skill continues with postflight
4. Skip Stage 0 early metadata creation

## Related Documentation

This is the user-facing tutorial version of the agent template. For the canonical structure
`meta-builder-agent` uses when generating new agents via `/meta`, see
`.claude/context/templates/agent-template.md`.
