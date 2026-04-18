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
                                          │  (merged section)│
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
├── EXTENSION.md               # Content merged into CLAUDE.md (REQUIRED)
├── index-entries.json         # Context index entries (optional)
├── settings-fragment.json     # MCP server configurations (optional)
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
└── scripts/                   # Helper scripts (optional)
    └── *.sh
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
- `copy_simple_files()` - Copy agents, commands, rules
- `copy_skill_dirs()` - Copy skill directories recursively
- `copy_context_dirs()` - Copy context directories preserving structure
- `copy_scripts()` - Copy shell scripts with preserved permissions
- `check_conflicts()` - Detect conflicts before loading
- `remove_installed_files()` - Clean up on unload

**Conflict Detection**:
Before loading, the loader checks if target files already exist in the core directory. If conflicts are found, loading is aborted to prevent overwriting core files.

### 3. Merger (merge.lua)

The merger handles shared file modifications:

**Functions**:
- `inject_section()` - Insert section into CLAUDE.md with markers
- `remove_section()` - Remove section from CLAUDE.md
- `append_index_entries()` - Add entries to index.json (with deduplication and tracking)
- `remove_index_entries_tracked()` - Remove tracked entries from index.json on unload
- `remove_orphaned_index_entries()` - Pre-load cleanup: remove stale project/ entries
  not matching loaded extensions, with optional file-existence verification
- `remove_index_entries_by_prefix()` - Remove entries by path prefix (utility)
- `merge_settings()` - Deep merge into settings.json
- `unmerge_settings()` - Remove merged settings

**Section Markers**:
Injected sections are wrapped with markers for clean removal:

```markdown
<!-- SECTION: extension_latex -->
## LaTeX Extension
[Extension content here]
<!-- END_SECTION: extension_latex -->
```

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
   g. copy_data_dirs() (merge-copy semantics)
5. Pre-load index cleanup:
   a. Collect provides.context prefixes from already-loaded extensions
   b. remove_orphaned_index_entries() - remove stale project/ entries
      not matching any loaded extension's prefix (or whose files don't
      exist on disk). The current extension is excluded from valid
      prefixes so its stale entries are removed before fresh ones are
      added, ensuring proper tracking.
6. Merge shared files (process_merge_targets):
   a. inject_section() into CLAUDE.md (claudemd merge target)
   b. append_index_entries() to index.json (index merge target, tracked)
      - Core index entries loaded via core's merge_targets.index (same as other extensions)
      - Extension-specific entries loaded via each extension's merge_targets.index
   c. merge_settings() if mcp_servers defined
7. Update state (mark_loaded)
8. Write extensions.json
9. Post-load verification
```

### Unloading an Extension

```
1. Read state (get extension info)
2. Check reverse dependencies:
   a. Scan loaded extensions for ones declaring this extension in dependencies
   b. If dependents exist, show warning: "Extension 'X' is required by: Y, Z"
   c. Proceed with unload if user confirms (dependents are NOT cascade-unloaded)
3. Remove merged content:
   a. remove_section() from CLAUDE.md
   b. remove_index_entries_tracked() from index.json
   c. unmerge_settings() if settings were merged
4. Remove files:
   a. remove_installed_files() (files first, then empty dirs)
5. Update state (mark_unloaded)
6. Write extensions.json
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

**Extension manifest**:
```json
{
  "mcp_servers": {
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
- Loading is aborted
- User is notified of conflicting files
- No partial state is created

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
