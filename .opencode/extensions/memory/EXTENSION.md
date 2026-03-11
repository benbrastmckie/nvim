## Memory Extension

This project includes the memory vault extension for knowledge capture and retrieval.

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/learn` | `/learn "text"` | Add text as memory (with content mapping and deduplication) |
| `/learn` | `/learn /path/to/file` | Add file content as memory |
| `/learn` | `/learn /path/to/dir/` | Scan directory for learnable content |
| `/learn` | `/learn --task N` | Review task artifacts and create memories |

All input modes flow through content mapping, MCP-based memory search (or grep fallback), and three memory operations (UPDATE, EXTEND, CREATE).

### Memory-Augmented Research

The `--remember` flag on `/research` enables memory-augmented research:

```bash
/research N --remember
```

When the memory extension is loaded, this flag:
1. Searches the memory vault for relevant prior knowledge
2. Includes top matching memories in research context
3. Adds "Prior Knowledge from Memory Vault" section to the report

**Note**: The `--remember` flag requires this extension to be loaded. If the extension is not loaded, the flag is ignored gracefully.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-memory | (direct execution) | Memory creation and management |

### MCP Integration

The `obsidian-memory` MCP server provides memory search via the two-tool pattern:

| Tool | Usage | Description |
|------|-------|-------------|
| `execute("search", {...})` | `execute("search", {query: "...", vault: ".memory", limit: 5})` | Search memories by keywords |
| `execute("read", {...})` | `execute("read", {path: "..."})` | Retrieve full memory content |
| `execute("write", {...})` | `execute("write", {path: "...", content: "..."})` | Create new memory |
| `execute("list", {...})` | `execute("list", {vault: ".memory"})` | Enumerate all memories |

**Setup**: See memory-setup.md context file for MCP server configuration.

**Graceful Degradation**: If MCP is unavailable, grep-based search on .memory/10-Memories/*.md still works.

### Memory Vault Structure

```
.memory/
+-- .obsidian/           # Obsidian configuration
+-- 00-Inbox/            # Quick capture for new memories
+-- 10-Memories/         # Stored memory entries
+-- 20-Indices/          # Navigation and organization
+-- 30-Templates/        # Memory entry templates
```

### Memory Classification

When using `/learn --task N`, memories are classified into categories:

- **[TECHNIQUE]** - Reusable method or approach
- **[PATTERN]** - Design or implementation pattern
- **[CONFIG]** - Configuration or setup knowledge
- **[WORKFLOW]** - Process or procedure
- **[INSIGHT]** - Key learning or understanding

### Memory Operations

The `/learn` command uses three memory operations based on overlap scoring:

| Operation | Overlap | Description |
|-----------|---------|-------------|
| **UPDATE** | >60% | Replace existing memory content (old content preserved in History section) |
| **EXTEND** | 30-60% | Append dated section to existing memory |
| **CREATE** | <30% | Create new memory file |

### Topic Organization

Memories now include a `topic` field in frontmatter with slash-separated hierarchical paths:

```yaml
topic: "neovim/plugins/telescope"
```

The index.md includes both "By Category" and "By Topic" sections for navigation.
