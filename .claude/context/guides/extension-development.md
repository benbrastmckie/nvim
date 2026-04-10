# Extension Development Guide

Guide for creating and managing domain extensions in the Claude Code system.

## Overview

Extensions provide task-type-specific and domain-specific capabilities to the core system. They include agents, skills, context, and rules tailored to specific domains.

## Extension Structure

```
.claude/extensions/{name}/
├── manifest.json           # Extension metadata
├── context/                # Domain-specific context
│   ├── index.json          # Context discovery entries
│   └── project/
│       └── {domain}/
├── agents/                 # Domain agents
│   ├── {domain}-research-agent.md
│   └── {domain}-implementation-agent.md
└── skills/                 # Domain skills
    └── skill-{domain}-research/SKILL.md
```

## Manifest Format

```json
{
  "name": "neovim",
  "version": "1.0.0",
  "description": "Neovim configuration development support",
  "task_types": ["neovim", "lua"],
  "agents": [
    "neovim-research-agent",
    "neovim-implementation-agent"
  ],
  "skills": [
    "skill-neovim-research",
    "skill-neovim-implementation"
  ],
  "merge_targets": [
    ".claude/context/index.json",
    ".claude/CLAUDE.md"
  ]
}
```

### Manifest Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Extension identifier |
| `version` | string | Semver version |
| `description` | string | Brief description |
| `languages` | array | Supported languages |
| `agents` | array | Agent names provided |
| `skills` | array | Skill names provided |
| `merge_targets` | array | Files to merge into core system |

## Merge Process

The extension merger (`scripts/merge-extensions.sh`) combines extension content:

### 1. Context Index Merging

Extension context entries are appended to `.claude/context/index.json`:

```bash
# From extension context/index.json
{
  "entries": [
    {
      "path": "extensions/neovim/context/project/neovim/lua-patterns.md",
      "domain": "project",
      "subdomain": "neovim",
      "load_when": {
        "task_types": ["neovim"]
      }
    }
  ]
}
```

### 2. CLAUDE.md Merging

Routing tables and command references are merged into CLAUDE.md.

### 3. Verification

Run verification after merging:

```bash
.claude/scripts/merge-extensions.sh --verify
```

## Creating an Extension

### Step 1: Create Directory Structure

```bash
mkdir -p .claude/extensions/{name}/{context,agents,skills}
```

### Step 2: Create Manifest

```json
{
  "name": "myextension",
  "version": "1.0.0",
  "description": "My domain extension",
  "task_types": ["mydomain"],
  "agents": ["mydomain-research-agent"],
  "skills": ["skill-mydomain-research"],
  "merge_targets": [".claude/context/index.json"]
}
```

### Step 3: Create Agents

Create research and implementation agents in `agents/`.

### Step 4: Create Skills

Create skills in `skills/skill-{name}/SKILL.md`.

### Step 5: Create Context

Add domain knowledge to `context/project/{domain}/`.

### Step 6: Register Extension

Add to `.claude/extensions/manifest.json`:

```json
{
  "extensions": [
    "neovim",
    "lean",
    "myextension"
  ]
}
```

### Step 7: Merge and Verify

```bash
.claude/scripts/merge-extensions.sh
.claude/scripts/merge-extensions.sh --verify
```

## Extension Loading

Extensions are loaded via `<leader>ac>` in Neovim:

1. Reads `.claude/extensions/manifest.json`
2. Runs merge script
3. Updates context index
4. Reloads routing tables

## Best Practices

1. **Lazy Loading**: Extensions should not load context until needed
2. **Agent Separation**: Always create both research and implementation agents
3. **Context Organization**: Follow the `context/project/{domain}/` structure
4. **Merge Safety**: Always verify after merging
5. **Documentation**: Document domain-specific patterns in context files

## Example: Minimal Extension

See `extensions/template/` for a minimal extension structure.

## Troubleshooting

### Merge Conflicts

If merging fails:
1. Check manifest.json syntax
2. Verify all referenced files exist
3. Run with `--verify` for detailed errors

### Context Not Loading

1. Check index.json has correct load_when conditions
2. Verify path is relative to context/ directory
3. Test with jq query

### Routing Not Working

1. Verify language is registered in manifest
2. Check agent names match skill mappings
3. Ensure merge updated CLAUDE.md
