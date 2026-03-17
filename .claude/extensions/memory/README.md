# Memory Extension

Extension for Obsidian-compatible memory vault with knowledge capture and retrieval.

## Quick Start

### Loading the Extension

Load via keybinding or command:
```
<leader>ac -> select "memory"
```

### Basic Usage

| Mode | Command | Description |
|------|---------|-------------|
| Text | `/learn "your text here"` | Add quoted text as memory |
| File | `/learn /path/to/file.md` | Add file content as memory |
| Directory | `/learn /path/to/dir/` | Scan directory for learnable content |
| Task | `/learn --task N` | Review task artifacts for extraction |

### First Memory

```bash
/learn "Always use pcall() in Lua for safe function calls when the function might fail"
```

The extension will:
1. Analyze your input for topic and key terms
2. Search for related existing memories
3. Recommend an operation (UPDATE, EXTEND, or CREATE)
4. Ask for your confirmation before writing anything

**Important**: All write operations require explicit user confirmation. The extension will never modify your vault without asking first.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Storage: Where Memories Live](#storage-where-memories-live)
3. [Usage: How Memories Work](#usage-how-memories-work)
4. [Configuration](#configuration)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)
7. [Subdirectories](#subdirectories)

---

## Storage: Where Memories Live

### Vault Location

Memories are stored in an Obsidian-compatible vault at the project root:

```
.memory/                      # Memory vault (project root)
+-- .obsidian/               # Obsidian app configuration
+-- 00-Inbox/                # Quick capture (future use)
+-- 10-Memories/             # Memory entries (MEM-*.md files)
+-- 20-Indices/              # Navigation and organization
|   +-- index.md            # Main index with category/topic sections
+-- 30-Templates/            # Templates for new memories
|   +-- memory-template.md  # Standard memory format
+-- README.md                # Vault overview
```

### Memory File Format

Each memory is a markdown file with YAML frontmatter:

```yaml
---
title: "Lua pcall for safe function calls"
created: 2026-03-15
tags: lua, error-handling, patterns
topic: "neovim/lua/patterns"
source: "user input"
modified: 2026-03-15
---

# Lua pcall for safe function calls

Use pcall() in Lua for safe function calls when the function might fail.
The function returns two values: success (boolean) and result (or error).

## Example

```lua
local ok, result = pcall(require, "optional_module")
if not ok then
  return  -- Module not available, graceful exit
end
```

## Connections
<!-- Links to related memories using [[MEM-filename]] syntax -->
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Memory title (from summary or first line) |
| `created` | date | Original creation date (YYYY-MM-DD) |
| `tags` | list | Comma-separated keywords for categorization |
| `topic` | string | Hierarchical topic path (slash-separated) |
| `source` | string | Origin: "user input", "file: /path", etc. |
| `modified` | date | Last modification date |

### Naming Convention

Memory files follow the `MEM-{semantic-slug}.md` pattern:

- **MEM-** prefix enables grep discoverability
- **semantic-slug** is derived from topic and title
- Collision handling appends `-2`, `-3`, etc.

Examples:
- `MEM-lua-pcall-safe-calls.md`
- `MEM-telescope-custom-pickers.md`
- `MEM-neovim-lazy-loading.md`

### Index Structure

The `20-Indices/index.md` file organizes memories two ways:

1. **By Category**: Groups memories by tags (error-handling, patterns, config)
2. **By Topic**: Hierarchical tree (neovim/plugins/telescope)

The index regenerates from filesystem state, making it self-healing if entries become stale.

---

## Usage: How Memories Work

### The Three Operations

When you add content, the extension compares it against existing memories using keyword overlap scoring:

| Overlap | Operation | Description |
|---------|-----------|-------------|
| >60% | **UPDATE** | High similarity - replace memory content (preserves history) |
| 30-60% | **EXTEND** | Medium similarity - append dated section to existing memory |
| <30% | **CREATE** | Low similarity - create new memory file |

### Overlap Scoring Example

Your input: "telescope custom picker creation"
Key terms: `["telescope", "picker", "custom", "creation", "finders"]`

Existing memory: `MEM-telescope-custom-pickers.md`
Memory terms: `["telescope", "picker", "finders", "sorters", "attach_mappings"]`

Overlap: 3 matches / 5 terms = 60% -> Recommended: UPDATE

### Interactive Workflow

Every segment requires explicit confirmation:

```
Segment: Telescope custom picker creation pattern
Topic: neovim/plugins/telescope
Key terms: telescope, picker, finders, sorters, attach_mappings

Related Memories:
1. MEM-telescope-custom-pickers (72% overlap) -> Recommended: UPDATE
2. MEM-neovim-plugin-patterns (45% overlap) -> Recommended: EXTEND
3. MEM-lua-module-structure (18% overlap) -> Recommended: CREATE

What would you like to do with this segment?
[ ] UPDATE MEM-telescope-custom-pickers (replace content)
[ ] EXTEND MEM-neovim-plugin-patterns (append section)
[ ] CREATE new memory
[ ] SKIP - don't save this segment
```

**You can override any recommendation.** Want to keep the existing memory and create a new one instead of updating? Select CREATE.

### Content Mapping (Segmentation)

Large inputs (>500 tokens) are automatically segmented:

| File Type | Split Strategy |
|-----------|---------------|
| Markdown | At heading boundaries (# ## ### ####) |
| Code | At function/class definitions |
| Text | At paragraph boundaries (double newlines) |
| Directory | Per file, then large files split |

Small inputs (<500 tokens) become a single segment without splitting.

### Input Modes

#### Text Mode

```bash
/learn "Pattern: always use explicit returns in Lua modules"
```

Best for: Quick notes, single concepts, remembered patterns

#### File Mode

```bash
/learn /path/to/notes.md
/learn ~/docs/telescope-setup.txt
```

Best for: Existing documentation, code files, external notes

#### Directory Mode

```bash
/learn ./src/utils/
/learn ~/notes/neovim/
```

The extension:
- Scans recursively (excludes .git, node_modules, __pycache__, .obsidian)
- Presents paginated file list (10 per page)
- Respects size limits (100KB per file, 200 files max)

Best for: Importing existing knowledge bases, project documentation

#### Task Mode

```bash
/learn --task 142
```

Reviews task artifacts and offers classification:

| Category | Description |
|----------|-------------|
| [TECHNIQUE] | Reusable method or approach |
| [PATTERN] | Design or implementation pattern |
| [CONFIG] | Configuration or setup knowledge |
| [WORKFLOW] | Process or procedure |
| [INSIGHT] | Key learning or understanding |
| [SKIP] | Not valuable for memory |

Best for: Extracting learnings from completed tasks

### Topic Inference

Topics are inferred with this priority:

1. **Source path**: `/project/src/utils/` -> `project/utils`
2. **Keyword analysis**: Contains "telescope" -> `neovim/plugins/telescope`
3. **Related memories**: If updating, inherit existing topic
4. **User confirmation**: Always confirm/override before writing

Topic paths use 2-3 levels: `domain/category/specific`

---

## Configuration

### MCP Server Setup

The extension uses MCP for enhanced memory search. Two options:

| Server | Connection | Requirements |
|--------|------------|--------------|
| obsidian-claude-code-mcp | WebSocket :22360 | Obsidian desktop + plugin |
| obsidian-cli-rest-mcp | HTTP REST :27124 | Obsidian + Local REST API plugin |

#### Primary Option: WebSocket (Recommended)

Configured in `manifest.json`:
```json
{
  "mcp_servers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/obsidian-claude-code-mcp@latest"],
      "env": {
        "OBSIDIAN_WS_PORT": "22360"
      }
    }
  }
}
```

**Prerequisites**:
1. Obsidian desktop app installed
2. Node.js (for npx)
3. Obsidian vault opened (`.memory/` directory)

#### Alternative: REST API

For the REST API option, install the "Local REST API" Obsidian plugin and configure:
```json
{
  "command": "npx",
  "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp"],
  "env": {
    "OBSIDIAN_REST_PORT": "27124"
  }
}
```

### MCP Tools Available

| Tool | Description |
|------|-------------|
| `search` | Search memories by keywords |
| `read` | Retrieve full memory content |
| `write` | Create new memory |
| `list` | Enumerate all memories |

### Graceful Degradation

When MCP is unavailable, the extension falls back to grep-based search:

```bash
grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
```

This provides basic functionality without Obsidian running:
- Memory search works (keyword matching)
- Memory creation works (direct file writes)
- No Obsidian graph/backlinks integration

---

## Troubleshooting

### "No memories found" when searching

**Causes**:
1. Vault is empty (no memories created yet)
2. MCP not connected and grep finds no matches
3. Search terms too specific

**Solutions**:
```bash
# Check if memories exist
ls .memory/10-Memories/MEM-*.md

# Test grep fallback manually
grep -l -i "your keyword" .memory/10-Memories/*.md
```

### MCP connection issues

**Symptoms**: "MCP search unavailable. Using grep-based fallback."

**Diagnosis**:
1. Is Obsidian running? The desktop app must be open
2. Is the vault open? Open `.memory/` in Obsidian
3. Is the plugin installed? Check Obsidian settings
4. Port conflict? Check if port 22360 is in use

**Test connection**:
```bash
# Check if MCP server is listening
lsof -i :22360
```

### Memories not appearing in Obsidian

**Cause**: Obsidian needs to index new files

**Solution**:
1. Force Obsidian to re-index: Settings > Files & Links > Detect all file extensions
2. Or close and reopen the vault

### "Too many files" error in directory mode

**Limit**: 200 files maximum per scan

**Solutions**:
- Narrow your path: `/learn ./src/specific-module/`
- Use file mode for specific files: `/learn /path/to/important.md`
- Split into multiple `/learn` invocations

### Index out of sync

**Cause**: Manual file operations outside `/learn` command

**Solution**: The index regenerates from filesystem state. Run:
```bash
/learn "trigger reindex"  # Then skip the segment
```

Or manually regenerate by re-running any `/learn` operation.

---

## Best Practices

### Writing Good Memories

1. **Be specific**: "Lua pcall for error handling" > "Lua patterns"
2. **Include examples**: Code snippets make memories actionable
3. **Use descriptive titles**: First line becomes the title
4. **Add connections**: Link related memories with `[[MEM-filename]]`

### Topic Organization

Recommended hierarchy depths:
- 2 levels: `neovim/config`, `lua/patterns`
- 3 levels: `neovim/plugins/telescope`, `lua/modules/loading`
- Avoid 4+ levels (too granular)

### Managing Vault Size

- Review and merge similar memories periodically
- Use UPDATE over CREATE when content overlaps
- Delete obsolete memories (they're just markdown files)
- The extension is optimized for <1000 memories

### Multi-System Usage

The vault supports concurrent access between Claude Code and OpenCode:
- Single `.memory/` vault at project root (shared)
- Different MCP ports per system (no conflicts)
- Index regenerates from filesystem (self-healing)
- Last-write-wins for concurrent edits (rare edge case)

### Git Integration

The vault is text-based and git-friendly:
- All memories are markdown files
- Commit after `/learn` operations (automatic)
- Track memory evolution in git history
- `.obsidian/` can be gitignored if desired

---

## Subdirectories

- [commands/](commands/README.md) - Command implementations
- [skills/](skills/README.md) - Skill definitions
- [context/](context/README.md) - Context documentation
- [data/](data/README.md) - Vault skeleton structure

### Context Documentation

- [Learn Usage Guide](context/project/memory/learn-usage.md) - Detailed usage examples
- [Memory Setup](context/project/memory/memory-setup.md) - MCP configuration details
- [Memory Troubleshooting](context/project/memory/memory-troubleshooting.md) - Extended troubleshooting
- [Knowledge Capture Usage](context/project/memory/knowledge-capture-usage.md) - Example workflows

---

## Navigation

- [Parent Directory](../README.md)
