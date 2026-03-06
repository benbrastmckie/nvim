# MCP Server Setup for Memory Vault

This guide explains how to set up the MCP (Model Context Protocol) server for advanced memory vault features like search and retrieval.

## Prerequisites

- Obsidian desktop app installed (available at [obsidian.md](https://obsidian.md))
- `.opencode/memory/` vault created
- Node.js/npm installed (for npx)

## Installation Steps

### 1. Open the Vault in Obsidian

1. Launch Obsidian desktop app
2. Click "Open folder as vault"
3. Select `.opencode/memory/` directory
4. The vault should open successfully

### 2. Install Obsidian CLI REST Plugin

1. In Obsidian, open Settings (gear icon)
2. Go to "Community Plugins"
3. Turn off "Safe mode" if it's on
4. Click "Browse" community plugins
5. Search for: "Obsidian CLI REST"
6. Click "Install"
7. Click "Enable"

### 3. Configure the Plugin

1. In plugin settings, note the **API Key** (you'll need this)
2. The default port is `27124` (change if there's a conflict)
3. Keep Obsidian running - the MCP server connects to it

### 4. Configure MCP Server

Add to your Claude Code MCP settings (usually in `~/.claude/settings.json` or similar):

```json
{
  "mcpServers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
      "env": {
        "OBSIDIAN_API_KEY": "your-api-key-here",
        "OBSIDIAN_PORT": "27124"
      }
    }
  }
}
```

Replace `your-api-key-here` with the API key from Obsidian plugin settings.

### 5. Test the Connection

Test the MCP server:
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://127.0.0.1:27124/vault/
```

You should see a list of vault files.

### 6. Test with OpenCode

Run a memory-augmented research query:
```
/research OC_136 --remember
```

If configured correctly, the system will:
1. Search existing memories
2. Include relevant memories in the research context
3. Show "memory-augmented" status

## Troubleshooting

### Connection Refused
- **Cause**: Obsidian not running
- **Solution**: Start Obsidian and open the memory vault

### Port Already in Use
- **Cause**: Another service using port 27124
- **Solution**: Change port in Obsidian plugin settings and MCP config

### API Key Issues
- **Cause**: Wrong API key or key regenerated
- **Solution**: Copy the correct API key from Obsidian plugin settings

### Plugin Not Found
- **Cause**: Plugin not in community list
- **Solution**: Ensure "Safe mode" is off and search again

## MCP Tools Available

When connected, these tools are available:

- `search_notes` - Search memories by keywords
- `read_note` - Retrieve full memory content
- `write_note` - Create new memory (alternative to direct file write)
- `list_notes` - Enumerate all memories

## Graceful Degradation

If the MCP server is unavailable:
- Direct file access still works
- Memory search is skipped during research
- System continues with reduced functionality

## Security Notes

- Keep your API key private (don't commit it)
- The MCP server only works when Obsidian is running
- Port 27124 is local-only (not exposed to network)
- Consider using environment variables for API keys
