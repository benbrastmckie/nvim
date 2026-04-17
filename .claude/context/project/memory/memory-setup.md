# MCP Server Setup for Memory Vault (Claude Code)

This guide explains how to set up the MCP (Model Context Protocol) server for advanced memory vault features like search and retrieval in Claude Code.

## Multi-System Architecture

The memory extension is designed to work across both Claude Code and OpenCode:

### Shared Components
- `.memory/` vault at project root (single source of truth)
- Memory filename format: `MEM-{semantic-slug}.md` (e.g., `MEM-telescope-custom-pickers.md`)
- Index regeneration from filesystem

### System-Specific Components
- MCP server configuration (different ports, different protocols)
- Context reference paths (`.claude/` vs `.opencode/`)
- Extension loading mechanics

### Concurrent Usage Safety

| Scenario | Safety | Notes |
|----------|--------|-------|
| Both reading memories | Safe | No conflicts |
| One writing, one reading | Safe | Atomic file writes |
| Both writing different memories | Safe | Unique IDs per write |
| Both updating same memory | Last-write-wins | Rare edge case |
| Both using MCP | Avoid | Use one system's MCP at a time |

## Overview

Claude Code uses MCP servers configured in `.mcp.json` at the project root. The memory extension supports two MCP server options:

| Server | Connection | Requirements | Best For |
|--------|------------|--------------|----------|
| `obsidian-claude-code-mcp` | WebSocket (port 22360) | Obsidian + plugin | Primary (real-time) |
| `@dsebastien/obsidian-cli-rest-mcp` | HTTP REST (port 27124) | Obsidian + Local REST API plugin | Fallback |

## Prerequisites

- Obsidian desktop app installed (available at [obsidian.md](https://obsidian.md))
- `.memory/` vault created at project root
- Node.js/npm installed (for npx)

---

## Option 1: obsidian-claude-code-mcp (Primary)

This is the recommended option for Claude Code, using WebSocket connections.

### 1. Install the Obsidian Plugin

1. Launch Obsidian desktop app
2. Open `.memory/` as vault (File -> Open folder as vault)
3. Open Settings (gear icon)
4. Go to "Community Plugins"
5. Turn off "Safe mode" if prompted
6. Click "Browse" community plugins
7. Search for: **"Claude Code MCP"** or similar WebSocket-based Claude connector
8. Click "Install", then "Enable"

### 2. Configure the Plugin

1. Open the plugin settings
2. Note the WebSocket port (default: 22360)
3. Enable the server

### 3. Add MCP Server to .mcp.json

Create or update `.mcp.json` at project root:

```json
{
  "mcpServers": {
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

### 4. Test the Connection

1. Ensure Obsidian is running with the `.memory/` vault open
2. Restart Claude Code to pick up the MCP configuration
3. Run a memory-augmented research query:
   ```
   /research N --remember
   ```

If configured correctly, the system will:
1. Search existing memories via MCP
2. Include relevant memories in the research context
3. Show "memory-augmented" status

---

## Option 2: @dsebastien/obsidian-cli-rest-mcp (Fallback)

Use this option if the primary WebSocket approach is unavailable.

### 1. Install Local REST API Plugin

1. In Obsidian, open Settings (gear icon)
2. Go to "Community Plugins"
3. Turn off "Safe mode" if prompted
4. Click "Browse" community plugins
5. Search for: **"Local REST API"** (by coddingtonbear)
6. Click "Install", then "Enable"

### 2. Get the API Key

1. Open the **Local REST API** plugin settings
2. The API key is auto-generated and shown on the settings page
3. Copy it -- you'll need it in the next step

### 3. Set Environment Variable

The MCP server uses `${OBSIDIAN_API_KEY}`, so set it in your shell:

**Fish** (`~/.config/fish/config.fish`):
```fish
set -gx OBSIDIAN_API_KEY "your-api-key-here"
```

**Bash/Zsh** (`~/.bashrc` or `~/.zshrc`):
```bash
export OBSIDIAN_API_KEY="your-api-key-here"
```

### 4. Add MCP Server to .mcp.json

```json
{
  "mcpServers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
      "env": {
        "OBSIDIAN_API_KEY": "${OBSIDIAN_API_KEY}",
        "OBSIDIAN_PORT": "27124"
      }
    }
  }
}
```

The `${OBSIDIAN_API_KEY}` placeholder is substituted from your environment at runtime -- never hardcode the key in the config file.

### 5. Test the Connection

```bash
curl -H "Authorization: Bearer $OBSIDIAN_API_KEY" \
  http://127.0.0.1:27124/vault/
```

You should see a list of vault files. If Obsidian is not running, you'll get "connection refused".

---

## MCP Tools Available

When connected, these tools are available:

| Tool | Description |
|------|-------------|
| `search` | Search memories by keywords |
| `read` | Retrieve full memory content |
| `write` | Create new memory |
| `list` | Enumerate all memories |

### Tool Usage Pattern

```
execute("search", {query: "telescope picker", vault: ".memory", limit: 5})
execute("read", {path: ".memory/10-Memories/MEM-telescope-custom-pickers.md"})
execute("write", {path: ".memory/10-Memories/MEM-neovim-lsp-best-practices.md", content: "..."})
execute("list", {vault: ".memory"})
```

---

## Graceful Degradation

If the MCP server is unavailable:
- Direct file access still works
- Memory search uses grep-based fallback
- System continues with reduced functionality

The skill automatically detects MCP unavailability and falls back to:
```bash
grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
```

---

## Troubleshooting

### Connection Refused
- **Cause**: Obsidian not running
- **Solution**: Start Obsidian and open the memory vault

### Port Already in Use
- **Cause**: Another service using the port
- **Solution**: Change port in Obsidian plugin settings and .mcp.json config

### API Key Issues (REST fallback only)
- **Cause**: Wrong API key or key regenerated
- **Solution**: Copy the correct API key from Obsidian plugin settings

### Plugin Not Found
- **Cause**: Plugin not in community list, or searching wrong name
- **Solution**: Ensure "Safe mode" is off; search for the correct plugin name

### MCP Server Not Starting
- **Cause**: npm/npx not available
- **Solution**: Install Node.js; verify `npx --version` works

---

## Security Notes

- Keep your API key private (don't commit it)
- The MCP server only works when Obsidian is running
- WebSocket port 22360 and HTTP port 27124 are local-only (not exposed to network)
- Use environment variables for API keys

---

## Quick Reference

| Action | Primary (WebSocket) | Fallback (REST) |
|--------|---------------------|-----------------|
| Plugin | Claude Code MCP | Local REST API |
| Port | 22360 | 27124 |
| Auth | None (WebSocket) | API Key |
| Config | `.mcp.json` | `.mcp.json` + env var |

---

## See Also

- [Usage Guide](./learn-usage.md) - How to use /learn
- [Troubleshooting](./memory-troubleshooting.md) - Common issues
