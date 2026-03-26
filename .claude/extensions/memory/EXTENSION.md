## Memory Extension

Knowledge capture and retrieval via the memory vault. Supports text, file, directory, and task-based memory creation with MCP-backed search and deduplication.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-memory | (direct execution) | Memory creation and management |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/learn` | `/learn "text"` | Add text as memory (with content mapping and deduplication) |
| `/learn` | `/learn /path/to/file` | Add file content as memory |
| `/learn` | `/learn /path/to/dir/` | Scan directory for learnable content |
| `/learn` | `/learn --task N` | Review task artifacts and create memories |

### Memory-Augmented Research

The `--remember` flag on `/research` searches the memory vault for relevant prior knowledge and includes matches in the research context. Requires this extension to be loaded; ignored gracefully if not.

```bash
/research N --remember
```

### Context

- @context/project/memory/domain/memory-reference.md - MCP integration, vault structure, classification, operations
- @context/project/memory/learn-usage.md - Usage guide for /learn command
- @context/project/memory/memory-setup.md - MCP server setup for Obsidian vault
