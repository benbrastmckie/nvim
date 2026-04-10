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

Simple extensions (e.g., latex, python, typst, z3, epidemiology) typically
produce README files under ~120 lines.
Complex extensions (e.g., filetypes, lean, formal, nvim, nix, web) use the
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

Loaded via `<leader>ac` in Neovim. Once loaded, `<type>` becomes a recognized task type<, and `/<cmd>` becomes available>.

## MCP Tool Setup

<Complex only. Omit if the extension has no mcp_servers entries in manifest.json.>

### <server-name>

<One-sentence description.>

```bash
<install command>
```

Configured automatically in `manifest.json`. <API key requirements, if any.>

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
/research <task>    (task_type: <type>)
    |
    v
skill-<name>-research -> <name>-research-agent
    |
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
/plan -> /implement
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
