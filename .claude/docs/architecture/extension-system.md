# Extension System Architecture

[Back to Docs](../README.md) | [Adding Domains](../guides/adding-domains.md) | [Creating Extensions](../guides/creating-extensions.md)

The extension system enables modular domain support that can be loaded and unloaded on demand. Extensions are self-contained packages containing agents, skills, rules, commands, and context files that integrate with the core .claude/ system when loaded. Extensions can optionally declare dependencies on other extensions for shared resources.

---

## System Overview

```
Extension Source                           Target Project
(.claude/extensions/)                      (.claude/)

┌────────────────────┐                    ┌──────────────────┐
│ latex/             │                    │ agents/          │
│  manifest.json     │    Load/Unload     │  (copied agents) │
│  EXTENSION.md      │  ===============>  │ skills/          │
│  index-entries.json│                    │  (copied skills) │
│  agents/           │                    │ rules/           │
│  skills/           │                    │  (copied rules)  │
│  rules/            │                    │ context/         │
│  context/          │                    │  (copied context)│
└────────────────────┘                    │ CLAUDE.md        │
                                          │  (regenerated)   │
                                          │ context/index.json
                                          │  (merged entries)│
                                          └──────────────────┘
```

**Key Design Principles**:
1. **File-Copy Based**: Extensions are loaded by copying files into the core structure
2. **Editor Managed**: Load/unload triggered via the extension picker
3. **Claude Code Agnostic**: Claude Code sees only standard `.claude/` structure
4. **State Tracked**: `extensions.json` tracks what is installed and where

---

## Directory Structure

### Extension Layout

Each extension lives in `.claude/extensions/{name}/`:

```
.claude/extensions/{name}/
├── manifest.json              # Extension metadata (REQUIRED)
├── EXTENSION.md               # Content appended to CLAUDE.md by generate_claudemd() (REQUIRED)
├── index-entries.json         # Context index entries (optional)
├── settings-fragment.json     # Settings to deep-merge into settings.json (optional)
├── agents/                    # Agent definitions
│   └── {name}-*-agent.md
├── skills/                    # Skill directories
│   └── skill-{name}-*/SKILL.md
├── rules/                     # Auto-applied rules
│   └── {name}.md
├── commands/                  # Slash commands (optional)
│   └── {command}.md
├── context/                   # Domain knowledge
│   └── project/{name}/
│       ├── domain/
│       ├── patterns/
│       ├── standards/
│       └── tools/
├── scripts/                   # Helper scripts (optional)
│   └── *.sh
├── hooks/                     # Hook scripts with execute permissions (optional)
│   └── *.sh
├── docs/                      # Documentation files (optional)
│   └── *.md
├── templates/                 # Template files (optional)
│   └── *.md
├── systemd/                   # Systemd unit files (optional)
│   └── *.service
├── root-files/                # Files copied to .claude/ root (optional)
│   └── settings.json
└── merge-sources/             # Alternative location for claudemd merge source (optional)
    └── claudemd.md
```

### State File

When extensions are loaded, state is tracked in `.claude/extensions.json`:

```json
{
  "version": "1.0.0",
  "extensions": {
    "latex": {
      "version": "1.0.0",
      "loaded_at": "2026-01-15T10:30:00Z",
      "source_dir": "$PROJECT_ROOT/.claude/extensions/latex",
      "installed_files": [
        ".claude/agents/latex-implementation-agent.md",
        ".claude/agents/latex-research-agent.md"
      ],
      "installed_dirs": [
        ".claude/context/project/latex"
      ],
      "merged_sections": {
        "claudemd": { "section_id": "extension_latex" },
        "index": { "paths": ["context/project/latex/patterns/..."] }
      },
      "status": "active"
    }
  }
}
```

---

## Core Components

### 1. Manifest (manifest.json)

The manifest declares what the extension provides:

```json
{
  "name": "latex",
  "version": "1.0.0",
  "description": "LaTeX document development with VimTeX integration",
  "task_type": "latex",
  "dependencies": [],
  "provides": {
    "agents": ["latex-implementation-agent.md", "latex-research-agent.md"],
    "skills": ["skill-latex-implementation", "skill-latex-research"],
    "commands": [],
    "rules": ["latex.md"],
    "context": ["project/latex"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": {
      "latex": "skill-latex-research"
    },
    "implement": {
      "latex": "skill-latex-implement"
    }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_latex"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Extension identifier (directory name) |
| `version` | string | Semantic version (e.g., "1.0.0") |
| `description` | string | Human-readable description for picker |
| `task_type` | string | Language code for routing (e.g., "latex") |
| `dependencies` | array | Other extensions that must be loaded first |
| `provides` | object | What files/directories the extension provides |
| `merge_targets` | object | Files that get merged (CLAUDE.md, index.json) |
| `mcp_servers` | object | MCP server configurations to merge into settings |

### 2. Loader (loader.lua)

The loader handles file copy operations:

**Functions**:
- `copy_simple_files()` - Copy agents, commands, rules (flat .md files)
- `copy_skill_dirs()` - Copy skill directories recursively
- `copy_context_dirs()` - Copy context directories preserving structure
- `copy_scripts()` - Copy shell scripts with preserved permissions
- `copy_hooks()` - Copy hook scripts with execute permissions preserved
- `copy_docs()` - Copy documentation files (flat files or recursive directories)
- `copy_templates()` - Copy template files (flat files, no execute permissions)
- `copy_systemd()` - Copy systemd unit files (flat files, no execute permissions)
- `copy_root_files()` - Copy files that live at the .claude/ root (e.g., settings.json); reads from extension's root-files/ subdirectory
- `copy_data_dirs()` - Copy data directories with merge-copy semantics (only copies files that don't already exist, preserving user data); copies to project root, not target_dir
- `check_conflicts()` - Detect conflicts before loading; reports overwrite conflicts and data-directory merge scenarios separately
- `remove_installed_files()` - Remove tracked files on unload (skips empty directories, preserves user data in data dirs)

**Conflict Detection**:
Before loading, the loader checks if target files already exist. Conflicts are categorized as overwrite (file will be replaced) or merge (data directory already has content, merge-copy will preserve existing files). Both types are reported in the confirmation dialog; the user can proceed or cancel.

### 3. Merger (merge.lua)

The merger handles shared file modifications:

**Functions**:
- `generate_claudemd()` - Rebuild CLAUDE.md as a fully computed artifact from all loaded extensions' EXTENSION.md content (core first, then others in sorted order). Called after every load and unload. Replaces section-injection approach.
- `inject_section()` - Insert section with markers into a config markdown file. Used internally and by sync.lua for non-load/unload operations. Note: section_id is vestigial for load/unload (CLAUDE.md is regenerated, not section-injected), but still used by sync.lua.
- `remove_section()` - Remove a section from a config markdown file. Used by sync.lua.
- `append_index_entries()` - Add entries to index.json (with deduplication and tracking)
- `remove_index_entries_tracked()` - Remove tracked entries from index.json on unload
- `remove_orphaned_index_entries()` - Pre-load cleanup: remove stale project/ entries
  not matching loaded extensions, with optional file-existence verification
- `remove_index_entries_by_prefix()` - Remove entries by path prefix (utility)
- `merge_settings()` - Deep merge into settings.json
- `unmerge_settings()` - Remove merged settings

**CLAUDE.md as Computed Artifact**:
CLAUDE.md is not built by injecting sections with markers. Instead, `generate_claudemd()` reads each loaded extension's merge_targets source file (e.g., EXTENSION.md) and concatenates them into a fresh CLAUDE.md on every load and unload. The file begins with a header template from the core extension, followed by each extension's content fragment. This means the file has no section markers and is fully deterministic given the set of loaded extensions.

### 4. State (state.lua)

State tracking via `extensions.json`:

**Functions**:
- `read()` - Read current state
- `write()` - Write updated state
- `mark_loaded()` - Record extension as loaded with tracking data
- `mark_unloaded()` - Remove extension from state
- `is_loaded()` - Check if extension is active
- `get_installed_files()` - Get list of installed files for unload
- `list_loaded()` - Get all loaded extension names

### 5. Config (config.lua)

Configuration presets for different agent systems:

**Claude Configuration**:
```lua
{
  base_dir = ".claude",
  config_file = "CLAUDE.md",
  section_prefix = "extension_",
  state_file = "extensions.json",
  global_extensions_dir = "$PROJECT_ROOT/.claude/extensions",
  merge_target_key = "claudemd"
}
```

---

## Load/Unload Process

### Loading an Extension

```
1. Read manifest.json
2. Resolve dependencies:
   a. Check manifest dependencies array
   b. Auto-load any unloaded dependencies recursively (confirm=false)
   c. Circular detection via loading stack; depth limit of 5
   d. Re-read state from disk after dependency loads complete
3. Check for conflicts (check_conflicts)
4. Copy files:
   a. copy_simple_files(agents, .md)
   b. copy_simple_files(commands, .md)
   c. copy_simple_files(rules, .md)
   d. copy_skill_dirs()
   e. copy_context_dirs()
   f. copy_scripts()
   g. copy_hooks() (execute permissions preserved)
   h. copy_docs()
   i. copy_templates()
   j. copy_systemd()
   k. copy_root_files() (reads from root-files/ subdirectory, copies to .claude/ root)
   l. copy_data_dirs() (merge-copy semantics, copies to project root not target_dir)
5. Pre-load index cleanup:
   a. Collect provides.context prefixes from already-loaded extensions
   b. remove_orphaned_index_entries() - remove stale project/ entries
      not matching any loaded extension's prefix (or whose files don't
      exist on disk). The current extension is excluded from valid
      prefixes so its stale entries are removed before fresh ones are
      added, ensuring proper tracking.
6. Merge shared files (process_merge_targets):
   a. (claudemd merge target skipped here; generate_claudemd() rebuilds CLAUDE.md after state update)
   b. append_index_entries() to index.json (index merge target, tracked)
      - Core index entries loaded via core's merge_targets.index (same as other extensions)
      - Extension-specific entries loaded via each extension's merge_targets.index
   c. merge_settings() if merge_targets.settings defined (reads fragment from settings-fragment.json source)
7. Update state (mark_loaded)
8. Write extensions.json
9. generate_claudemd() - rebuilds CLAUDE.md from all loaded extensions' content (non-fatal if fails)
10. Post-load verification
```

### Unloading an Extension

```
1. Read state (get extension info)
2. Check reverse dependencies:
   a. Scan loaded extensions for ones declaring this extension in dependencies
   b. If dependents exist: hard block with error, return false
      (message: "Cannot unload 'X': required by loaded extension(s): Y, Z. Unload dependent(s) first.")
3. Show confirmation dialog (if confirm=true), cancel if user declines
4. Remove merged content:
   a. (CLAUDE.md section removal skipped; generate_claudemd() regenerates after state update)
   b. remove_index_entries_tracked() from index.json
   c. unmerge_settings() if settings were merged
5. Remove files:
   a. remove_installed_files() (files first, then empty dirs)
6. Update state (mark_unloaded)
7. Write extensions.json
8. generate_claudemd() - rebuilds CLAUDE.md excluding unloaded extension's content (non-fatal if fails)
```

### Index Lifecycle

The extension loader maintains `index.json` with entries from all loaded extensions:

1. **Core entries** (core extension's `index-entries.json`): ~95 entries for agent system
   context files (orchestration, patterns, standards, etc.). Loaded via the standard
   `merge_targets.index` mechanism, same as all other extensions.
2. **Extension entries** (each extension's `index-entries.json`): Domain-specific context.
   Tracked for clean removal on unload.
3. **Stale entries**: Remnants from previous sessions or external modifications. Removed by
   the pre-load cleanup before fresh entries are appended.

The pre-load cleanup ensures that `append_index_entries()` always adds fresh entries
(rather than deduplicating against stale ones), so all entries are properly tracked
for future unload.

---

## Integration with Claude Code

Claude Code has no knowledge of the extension system. It only sees the standard `.claude/` directory structure.

When an extension is loaded:
- Agents appear in `.claude/agents/`
- Skills appear in `.claude/skills/`
- Rules appear in `.claude/rules/`
- Commands appear in `.claude/commands/`
- Context appears in `.claude/context/`
- Routing info appears in CLAUDE.md

This means:
- Extension routing (e.g., `task_type: latex`) only works when extension is loaded
- Orchestrator routes to extension skills just like core skills
- Context index includes extension entries
- Rules auto-apply based on file patterns

---

## Extension Index Entries

Extensions can provide context file metadata via `index-entries.json`:

```json
{
  "entries": [
    {
      "path": "context/project/latex/patterns/document-structure.md",
      "description": "LaTeX document organization patterns",
      "tags": ["latex", "structure"],
      "load_when": {
        "task_types": ["latex"],
        "agents": ["latex-implementation-agent"]
      }
    }
  ]
}
```

When loaded, these entries are appended to the main `context/index.json`. Agents can then discover extension context using the same query patterns as core context.

---

## Settings Merging

Extensions can provide MCP server configurations that get merged into `settings.json`:

**Extension manifest** (`merge_targets.settings` entry):
```json
{
  "merge_targets": {
    "settings": {
      "source": "settings-fragment.json",
      "target": ".claude/settings.json"
    }
  }
}
```

**Extension source fragment** (`settings-fragment.json`):
```json
{
  "mcpServers": {
    "latex-compile": {
      "command": "latex-mcp",
      "args": ["--format", "pdf"]
    }
  }
}
```

**Merge behavior**:
- Arrays are appended (deduplicated)
- Objects are deep merged
- Scalars only added if not present (no overwrite)
- Tracked for clean removal on unload

---

## Picker Integration

The extension picker provides the user interface:

1. Scans `global_extensions_dir` for available extensions
2. Reads state to identify loaded extensions
3. Presents selection UI with status indicators
4. Triggers load or unload based on current state

**Display Format**:
```
[x] latex - LaTeX document development with VimTeX integration
[ ] lean - Lean theorem prover support
[x] formal - Formal verification tools
```

---

## Error Handling

### Conflict Handling
If loading would overwrite existing files:
- Conflicts are detected before any files are copied
- Conflict count and type (overwrite vs. merge) are shown in the confirmation dialog
- User can proceed with load (which overwrites conflicting files) or cancel
- If load proceeds, conflicting files are overwritten; no partial state is created on failure (pcall rollback)

### Recovery

Extension files are tracked by git. Use `git checkout HEAD -- .claude/extensions/{ext}/` to recover any extension file, or `git log --oneline -- .claude/extensions/` to find when changes occurred.

### State Consistency
- State is only updated after successful operations
- Installed file/directory lists enable clean unload
- Merged section tracking enables clean removal

---

## Related Documentation

- [Adding Domains](../guides/adding-domains.md) - When to use extensions vs core
- [Creating Extensions](../guides/creating-extensions.md) - Step-by-step guide
- [Context Loading](../guides/context-loading-best-practices.md) - How agents load context

---

[Back to Docs](../README.md) | [Adding Domains](../guides/adding-domains.md) | [Creating Extensions](../guides/creating-extensions.md)
