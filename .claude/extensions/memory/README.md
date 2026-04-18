# Memory Extension

Extension for an Obsidian-compatible memory vault. Stores knowledge as markdown files and
retrieves it on demand during research.

## Loading the Extension

```
Extension picker -> select "memory"
```

---

## The Three Commands

Everything in this extension comes down to three operations:

| Operation | Command | When to use |
|-----------|---------|-------------|
| **Write** | `/learn <input>` | After finishing work, to capture what you learned |
| **Read** | Automatic during `/research`, `/plan`, `/implement` | Relevant memories injected into agent context |
| **Maintain** | `/distill` | Periodically, to assess vault health and run maintenance |

**Note**: When this extension is loaded, memory retrieval is automatic. The `/research`, `/plan`,
and `/implement` preflight stages call `memory-retrieve.sh` to inject relevant memories into
agent context. Use the `--clean` flag to suppress auto-retrieval for a specific invocation.

---

## Writing Memories

### Quick Example

```bash
/learn "Always use pcall() in Lua for safe function calls when the function might fail"
```

### Input Modes

| Mode | Command | Best for |
|------|---------|----------|
| Text | `/learn "quoted text"` | Quick notes, single concepts, patterns you want to remember |
| File | `/learn /path/to/file.md` | Existing documentation, code files, external notes |
| Directory | `/learn /path/to/dir/` | Importing a knowledge base or project docs |
| Task | `/learn --task N` | Extracting learnings from a completed task |

### What Happens When You Write

For each input, the extension:
1. Segments the content by topic
2. Searches for related existing memories
3. Recommends an operation (UPDATE, EXTEND, or CREATE)
4. **Stops and asks you to confirm** before writing anything

You always see what it wants to do and can override or skip any segment.

### The Three Write Operations

| Overlap with existing memory | Operation | Effect |
|------------------------------|-----------|--------|
| >60% | **UPDATE** | Replaces memory content (old version preserved in History section) |
| 30-60% | **EXTEND** | Appends a dated section to the existing memory |
| <30% | **CREATE** | Creates a new memory file |

---

## Reading Memories

### Automatic Retrieval

When this extension is loaded, memory retrieval happens automatically during `/research`,
`/plan`, and `/implement`. The preflight stage calls `memory-retrieve.sh` to search the
vault for memories relevant to the current task and injects them into the agent context
under a `<memory-context>` section.

To suppress auto-retrieval for a specific invocation, pass the `--clean` flag:

```bash
/research N --clean    # Skip memory injection
```

### Manual Access

Since memories are plain markdown files, you can also:
- Open `.memory/10-Memories/` in Obsidian to browse and search visually
- Read individual files directly with any text editor
- Use grep: `grep -rl "telescope" .memory/10-Memories/`
- Consult the index: `.memory/20-Indices/index.md`

There is no `/recall` command. Outside of auto-retrieval, manual access is through the filesystem.

---

## Storage Details

### Vault Location

```
.memory/
+-- .obsidian/           # Obsidian app configuration
+-- 00-Inbox/            # Quick capture (reserved for future use)
+-- 10-Memories/         # Memory files (MEM-*.md)
+-- 20-Indices/          # index.md with category and topic sections
+-- 30-Templates/        # memory-template.md
+-- README.md
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
Returns two values: success (boolean) and result (or error message).

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

### Naming Convention

Files follow the `MEM-{semantic-slug}.md` pattern:

- `MEM-lua-pcall-safe-calls.md`
- `MEM-telescope-custom-pickers.md`
- `MEM-neovim-lazy-loading.md`

The `MEM-` prefix keeps files grep-discoverable. Slugs are derived from topic and title.
Collision handling appends `-2`, `-3`, etc.

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Memory title (from summary or first line) |
| `created` | date | Original creation date (YYYY-MM-DD) |
| `tags` | list | Comma-separated keywords |
| `topic` | string | Hierarchical path, e.g. `neovim/plugins/telescope` |
| `source` | string | Origin: "user input", "file: /path", etc. |
| `modified` | date | Last modification date |

### Index Structure

`.memory/20-Indices/index.md` organizes memories two ways:

- **By Category**: grouped by tags (error-handling, patterns, config, ...)
- **By Topic**: hierarchical tree (neovim/plugins/telescope, ...)

The index regenerates from filesystem state on each write, so it stays accurate even if
you manually add or delete files.

---

## Configuration

### MCP Server Setup

The extension uses an MCP server for enhanced memory search. Without it, a grep-based
fallback provides basic search.

Two MCP server options:

| Server | Connection | Requirements |
|--------|------------|--------------|
| obsidian-claude-code-mcp | WebSocket :22360 | Obsidian desktop + plugin |
| obsidian-cli-rest-mcp | HTTP REST :27124 | Obsidian + Local REST API plugin |

The WebSocket option is configured in `manifest.json` and runs automatically when
Obsidian is open with the `.memory/` vault.

**Prerequisites**:
1. Obsidian desktop app installed and open
2. Node.js (for npx)
3. `.memory/` vault open in Obsidian

### Graceful Degradation

When MCP is unavailable, the extension falls back to grep-based search:

```bash
grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
```

Memory creation and retrieval still work without MCP; you lose Obsidian graph and
backlinks integration but not core functionality.

---

## Troubleshooting

### "No memories found" during auto-retrieval

1. Is the vault empty? Check: `ls .memory/10-Memories/MEM-*.md`
2. Are search terms too specific? Try broader terms
3. Is MCP connected? Check Obsidian is open with the vault

### MCP connection issues

Symptom: "MCP search unavailable. Using grep-based fallback."

1. Is Obsidian running with `.memory/` open?
2. Is port 22360 in use by something else? `lsof -i :22360`

### Memories not appearing in Obsidian

Obsidian needs to re-index after new files are added externally. Go to
Settings > Files & Links > Detect all file extensions, or close and reopen the vault.

### Directory scan: "too many files"

Limit is 200 files. Narrow the path or run multiple `/learn` invocations.

---

## Best Practices

### When to Write

- After completing a task: `/learn --task N` to capture what you learned
- After figuring out a non-obvious pattern: `/learn "..."`
- When you find documentation you'll want again: `/learn /path/to/file.md`

### When to Read

- Memory retrieval is automatic when this extension is loaded -- just run `/research N`
- When manually starting work on something familiar: browse `.memory/20-Indices/index.md`

### Writing Effective Memories

- Be specific: "Lua pcall for error handling" > "Lua patterns"
- Include a code example: it makes the memory actionable
- One concept per memory: the overlap-scoring works best on focused content
- Accept UPDATE recommendations: they keep your vault clean

### Topic Hierarchy

Use 2-3 levels. Examples:
- `neovim/config`
- `neovim/plugins/telescope`
- `lua/patterns`

Avoid 4+ levels. The index becomes hard to navigate.

### Vault Maintenance

The extension is optimized for under 1000 memories. Periodically:
- Run `/distill` to see a health report with maintenance recommendations
- Accept UPDATE/EXTEND over CREATE when content overlaps
- Use `/distill --purge` to remove low-value memories (when available)
- Use `/distill --merge` to combine duplicate memories (when available)
- Run `/learn --task N` on recent tasks to consolidate learnings

---

## Subdirectories

- `commands/` - `/learn` command implementation
- `skills/` - `skill-memory` skill definition
- `context/` - Extended usage guides

### Context Documentation

- [Learn Usage Guide](context/project/memory/learn-usage.md) - Detailed `/learn` examples
- [Memory Setup](context/project/memory/memory-setup.md) - MCP configuration details
- [Memory Troubleshooting](context/project/memory/memory-troubleshooting.md) - Extended troubleshooting
- [Knowledge Capture Usage](context/project/memory/knowledge-capture-usage.md) - Example workflows

---

## Navigation

- [Parent Directory](../README.md)
