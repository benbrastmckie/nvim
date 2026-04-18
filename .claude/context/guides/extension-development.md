# Extension Development Guide

Guide for creating and managing domain extensions in the Claude Code system.

## Overview

Extensions provide task-type-specific and domain-specific capabilities to the core system. They include agents, skills, context, and rules tailored to specific domains.

## Two-Layer Architecture

The extension system is split across two layers:

- **Layer 1 -- Neovim Lua loader** (`lua/neotex/plugins/ai/shared/extensions/`): Manages which files exist in the `.claude/` runtime. Triggered by the extension picker (`<leader>ac`), it copies files from extension sources into the loaded runtime and regenerates CLAUDE.md.
- **Layer 2 -- .claude/ agent system** (`.claude/`): The runtime that Claude Code reads. Contains only what the loader has installed. Claude Code has no knowledge of the extension system itself.

**Lifecycle**:
1. User opens the extension picker in Neovim
2. Picker calls `manager.load(extension_name)` via `init.lua`
3. Lua loader copies agent, skill, rule, context files from `.claude/extensions/{name}/` into `.claude/agents/`, `.claude/skills/`, etc.
4. Loader merges index entries into `.claude/context/index.json`
5. `generate_claudemd()` rebuilds `.claude/CLAUDE.md` from all loaded extensions' CLAUDE.md source files
6. Claude Code reads the resulting `.claude/` structure -- routing, agents, and context are now available

When unloading, the loader removes the copied files and regenerates CLAUDE.md without that extension's content.

### Source vs Loaded Vocabulary

> **Extension source**: Files in `.claude/extensions/*/` -- edit these when developing extensions.
>
> **Loaded runtime**: Files in `.claude/{agents,skills,rules,...}/` -- copies made by the loader.
> Do not edit runtime files directly; they are overwritten on reload.

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
  "name": "python",
  "version": "1.0.0",
  "description": "Python development support",
  "task_type": "python",
  "dependencies": [],
  "provides": {
    "agents": ["python-research-agent.md", "python-implementation-agent.md"],
    "skills": ["skill-python-research", "skill-python-implementation"],
    "commands": [],
    "rules": [],
    "context": ["project/python"],
    "scripts": [],
    "hooks": [],
    "docs": [],
    "templates": [],
    "systemd": [],
    "root_files": [],
    "data": []
  },
  "routing": {
    "research": { "python": "skill-python-research" },
    "plan": { "python": "skill-planner" },
    "implement": { "python": "skill-python-implementation" }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_python"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  }
}
```

### Manifest Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Extension identifier |
| `version` | string | Semver version |
| `description` | string | Brief description |
| `task_type` | string | Task type this extension handles |
| `dependencies` | array | Other extensions required |
| `provides` | object | Agents, skills, commands, rules, context, scripts, hooks, docs, templates, systemd, root_files, data |
| `routing` | object | Task-type to skill mapping for research/plan/implement |
| `merge_targets` | object | Source-to-target file mappings for system integration |

## Merge Process

Extensions are loaded via the extension picker. The loader reads each extension's `manifest.json` and merges content according to `merge_targets`:

### 1. Context Index Merging

Extension context entries from `index-entries.json` are merged into `.claude/context/index.json`:

```json
{
  "entries": [
    {
      "path": "extensions/python/context/project/python/coding-patterns.md",
      "domain": "project",
      "subdomain": "python",
      "load_when": {
        "task_types": ["python"]
      }
    }
  ]
}
```

### 2. CLAUDE.md Generation

`.claude/CLAUDE.md` is a computed artifact. When an extension is loaded or unloaded, the loader regenerates CLAUDE.md by concatenating the CLAUDE.md source from every currently loaded extension. The `section_id` field in `merge_targets.claudemd` is used for tracking which sections to remove on unload, not for locating a content placement point.

### CLAUDE.md Source Files: merge-sources/claudemd.md vs EXTENSION.md

There are two patterns for providing CLAUDE.md content:

- **Standard extensions** (all domain extensions): use `EXTENSION.md` at the extension root. The manifest specifies `"source": "EXTENSION.md"` in `merge_targets.claudemd`.
- **Core extension** (`.claude/extensions/core/`): uses `merge-sources/claudemd.md` as its CLAUDE.md source. This allows the core extension to maintain its CLAUDE.md content separately from a potential top-level `EXTENSION.md`. The manifest specifies `"source": "merge-sources/claudemd.md"`.

When `generate_claudemd()` runs, it reads each loaded extension's `merge_targets.claudemd.source` file and concatenates them: core first, then all other extensions in sorted order.

### copy_context_dirs() Dual Behavior

The `copy_context_dirs()` function in `loader.lua` handles two types of entries in `provides.context`:

1. **Directory names** (common case): `"project/latex"` -- copies the entire directory tree from the extension source to `.claude/context/project/latex/`
2. **Individual file paths**: `"project/latex/specific-file.md"` -- copies a single file to `.claude/context/project/latex/specific-file.md`

The function detects which case applies by checking `vim.fn.isdirectory()` first, then falling back to `vim.fn.filereadable()` for individual files.

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
  "task_type": "mydomain",
  "dependencies": [],
  "provides": {
    "agents": ["mydomain-research-agent.md"],
    "skills": ["skill-mydomain-research"],
    "commands": [],
    "rules": [],
    "context": ["project/mydomain"],
    "scripts": [],
    "hooks": [],
    "docs": [],
    "templates": [],
    "systemd": [],
    "root_files": [],
    "data": []
  },
  "routing": {
    "research": { "mydomain": "skill-mydomain-research" },
    "plan": { "mydomain": "skill-planner" },
    "implement": { "mydomain": "skill-implementer" }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_mydomain"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  }
}
```

### Step 3: Create Agents

Create research and implementation agents in `agents/`.

### Step 4: Create Skills

Create skills in `skills/skill-{name}/SKILL.md`.

### Step 5: Create Context

Add domain knowledge to `context/project/{domain}/`.

### Step 6: Load Extension

Extensions are loaded via the extension picker. The loader discovers extensions by scanning `.claude/extensions/*/manifest.json` directories automatically -- no central registry is needed.

## Dependencies

Extensions can declare dependencies on other extensions. The loader resolves and auto-loads dependencies before the dependent extension.

### Declaring Dependencies

Add extension names to the `dependencies` array in `manifest.json`:

```json
{
  "name": "founder",
  "dependencies": ["slidev"]
}
```

### Auto-Loading Behavior

When an extension is loaded (via picker or API):

1. The loader reads `dependencies` from the manifest
2. For each dependency not already loaded, `manager.load()` is called recursively
3. Dependencies load silently (no confirmation dialog)
4. If a dependency fails to load, the parent extension also fails (before copying any files)
5. The confirmation dialog shows which dependencies were loaded

### Circular Dependency Detection

The loader maintains a loading stack during recursive resolution. If an extension appears twice in the stack, the load fails with an error message showing the cycle:

```
Circular dependency detected: A -> B -> C -> A
```

A recursion depth limit of 5 prevents runaway chains even without explicit cycles.

### Unload Safety

Unloading an extension that other loaded extensions depend on triggers a warning:

```
WARNING: Extension 'slidev' is required by: founder, present
```

The user can confirm to proceed. Unload does NOT cascade -- only the named extension is removed.

### Resource-Only Extensions

Extensions that only provide shared resources (no agents, commands, or routing) can omit `task_type` entirely. Example: the `slidev` extension provides animation and CSS style files consumed by both `founder` and `present`.

```json
{
  "name": "slidev",
  "version": "1.0.0",
  "description": "Shared Slidev animation patterns and CSS style presets",
  "dependencies": [],
  "provides": {
    "agents": [],
    "skills": [],
    "commands": [],
    "rules": [],
    "context": ["project/slidev"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  }
}
```

### Picker Preview

The extension picker shows dependency information:
- **Dependencies**: Lists declared dependencies for each extension
- **Required by**: Shows which loaded extensions depend on the selected extension

## Best Practices

1. **Lazy Loading**: Extensions should not load context until needed
2. **Agent Separation**: Always create both research and implementation agents
3. **Context Organization**: Follow the `context/project/{domain}/` structure
4. **Merge Safety**: Always verify after merging
5. **Documentation**: Document domain-specific patterns in context files

## Example: Minimal Extension

See `extensions/template/` for a minimal extension structure.

## Troubleshooting

### Load Failures

If loading fails:
1. Check manifest.json syntax
2. Verify all referenced files exist
3. Ensure merge_targets point to valid source files

### Context Not Loading

1. Check index.json has correct load_when conditions
2. Verify path is relative to context/ directory
3. Test with jq query

### Routing Not Working

1. Verify task_type is set in manifest
2. Check agent names match skill mappings
3. Ensure routing entries map task_type to correct skills
