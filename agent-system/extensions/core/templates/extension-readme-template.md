<!--
Extension README Template

This template is derived from .claude/extensions/founder/README.md with a
section-applicability matrix for simple vs. complex extensions.

Section Applicability Matrix:

| Section              | Simple extensions               | Complex extensions              |
|----------------------|---------------------------------|---------------------------------|
| Overview             | Required                        | Required                        |
| Installation         | Required                        | Required                        |
| MCP Tool Setup       | Omit                            | Required if MCP present         |
| Commands             | Omit (if no dedicated commands) | Required                        |
| Architecture tree    | Optional                        | Required                        |
| Skill-Agent Mapping  | Required                        | Required                        |
| Language Routing     | Required                        | Required                        |
| Workflow diagram     | Optional                        | Required                        |
| Output Artifacts     | Omit                            | Required                        |
| Key Patterns         | Optional                        | Required                        |
| Tool Dependencies    | Optional                        | Required if external tools used |
| References           | Optional                        | Optional                        |

Simple extensions (e.g., latex, python, typst, z3) typically
produce README files under ~120 lines.
Complex extensions (e.g., filetypes, lean, formal, nix, web, epidemiology) use the
full template and typically produce README files of 200-400 lines.

Delete this comment block when creating a real extension README.
-->

# <Extension Name> Extension

<One- or two-sentence overview of what this extension provides.>

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `<type>` | `<agent>` | <purpose> |

<For command-providing extensions, add a second table:>

| Command | Purpose |
|---------|---------|
| `/<cmd>` | <purpose> |

## Installation

Loaded via the extension picker. Once loaded, `<type>` becomes a recognized task type<, and `/<cmd>` becomes available>.

## MCP Tool Setup

<Complex only. Omit if the extension registers no MCP server.>

### <server-name>

<One-sentence description.>

```bash
<install command>
```

Registration and permission are two independent, separately-owned steps -- see
[MCP Server Ownership](../context/patterns/mcp-server-ownership.md) before writing this
section:
- **Registration** happens in user-scope `~/.claude.json`, via a host-level/home-manager
  activation block or a `core/scripts/` setup script -- never via `manifest.json`'s `mcp_servers`
  field (inert) or an `mcpServers` key in this extension's `settings-fragment.json` (also inert).
  State plainly here which of the two registration mechanisms this server uses, or that it is not
  yet registered by anything in the repo if that is the case.
- **Permission** is a `mcp__<server-name>__*` wildcard in this extension's own
  `settings-fragment.json` `permissions.allow`. <API key requirements, if any.>

**Capabilities**:

| Tool | Purpose |
|------|---------|
| <tool_name> | <purpose> |

## Commands

<Complex only if the extension has commands. Omit if `commands: []`.>

### /<cmd>

<Description.>

**Syntax**:
```bash
/<cmd> <args>
```

## Architecture

<Complex only; optional for simple.>

```
<ext-name>/
├── manifest.json
├── EXTENSION.md
├── README.md
│
├── commands/
├── skills/
├── agents/
├── rules/
└── context/
```

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-<name> | <agent>-agent | <purpose> |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `<type>` | <tools> | <tools> |

## Workflow

<Complex only; optional for simple.>

```
research-phase dispatch for <task>    (task_type: <type>)
    |
    v
skill-<name>-research -> <name>-research-agent
    |
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
plan phase -> implement phase
```

## Output Artifacts

<Complex only.>

| Phase | Artifact |
|-------|----------|
| Research | `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` |
| Plan | `specs/{NNN}_{SLUG}/plans/MM_{slug}.md` |
| Implementation | <description> plus `specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md` |

## Key Patterns

<Complex only; optional for simple.>

### <Pattern Name>

<Description and code example.>

## Rules Applied

<If manifest declares rules. Omit if `rules: []`.>

- `<rule>.md` - <auto-applied file glob pattern>

## Tool Dependencies

<If external tools are required.>

| Tool | Purpose | Install |
|------|---------|---------|
| <tool> | <purpose> | <install command> |

## References

- [<External doc>](https://...)
