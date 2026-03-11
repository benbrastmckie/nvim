# MCP Port Configuration Fix - Research Report

**Task**: 178 - Fix memory extension MCP server port configuration  
**Date**: 2026-03-10  
**Status**: Research Complete  

## Problem Summary

The memory extension's `--remember` flag fails because the research command attempts to connect to the MCP server on **port 3000**, but the Obsidian CLI REST plugin actually runs on **port 27124**.

### Error Evidence

```bash
$ curl -s http://localhost:3000/mcp/v1/server/info
Connection failed

$ ss -tlnp | grep :3000
Port 3000 not in use
```

## Root Cause Analysis

### 1. Port Mismatch

The research command (`.opencode/commands/research.md`) uses incorrect port:

```bash
curl -s -X POST "http://localhost:3000/mcp/v1/tools/search_notes" \
  -H "Content-Type: application/json" \
  -d '{"query": "...", "limit": 5}'
```

**Should be**: Port 27124 (Obsidian CLI REST default)

### 2. Missing MCP Configuration

The user's `~/.claude/settings.json` (managed by Nix) lacks the `mcpServers` section. This needs to be added via `settings.local.json`.

### 3. Incomplete Documentation

The memory setup documentation (`.opencode/context/project/memory/memory-setup.md`) correctly identifies port 27124, but the research command implementation doesn't match.

## Required Fixes

### Fix 1: Update Research Command Port

**File**: `.opencode/commands/research.md` (or equivalent in `.claude/`)

Change port 3000 to 27124:
```bash
curl -s -X POST "http://localhost:27124/vault/" \
  -H "Authorization: Bearer $OBSIDIAN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "..."}'
```

### Fix 2: Add MCP Server Configuration

**File**: `~/.claude/settings.local.json` (create if doesn't exist)

```json
{
  "mcpServers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
      "env": {
        "OBSIDIAN_API_KEY": "YOUR_API_KEY_HERE",
        "OBSIDIAN_PORT": "27124"
      }
    }
  }
}
```

### Fix 3: User Setup Requirements

1. **Install Obsidian CLI REST Plugin**:
   - Open Obsidian
   - Settings → Community Plugins
   - Search for "Obsidian CLI REST"
   - Install and Enable
   - Copy the API key from plugin settings

2. **Update API Key**:
   ```bash
   sed -i 's/YOUR_API_KEY_HERE/your-actual-api-key/' ~/.claude/settings.local.json
   ```

3. **Keep Obsidian Running**:
   The MCP server only works when Obsidian is open with the `.memory/` vault.

## Files Affected

1. `.opencode/commands/research.md` - Port 3000 → 27124
2. `.claude/commands/research.md` - Port 3000 → 27124 (if exists)
3. `~/.claude/settings.local.json` - Add MCP server config

## Verification Steps

After fixes applied:

```bash
# 1. Start Obsidian with vault
obsidian .memory/

# 2. Test MCP connection
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://127.0.0.1:27124/vault/

# 3. Test research with --remember
/research 20 --remember
```

## Related Context

- **Memory Extension Location**: `.opencode/extensions/memory/`
- **Vault Location**: `.memory/` (migrated from `.opencode/memory/`)
- **Setup Docs**: `.opencode/context/project/memory/memory-setup.md`
- **Troubleshooting**: `.opencode/context/project/memory/memory-troubleshooting.md`

## Dependencies

- Obsidian desktop app must be installed
- Node.js/npm for npx
- Obsidian CLI REST plugin enabled
- `.memory/` vault initialized

## Impact

This fix enables the `--remember` flag on `/research` commands to:
1. Search the memory vault for relevant prior knowledge
2. Include matching memories in research context
3. Add "Prior Knowledge from Memory Vault" section to reports

Without this fix, all memory-augmented research silently fails with "MCP unavailable".

---

**Related Tasks**:
- Task 174: Study opencode memory extension
- Task 175: Port memory extension to claude
- Task 176: Port Vision memory system changes to neovim

**External Resources**:
- Obsidian CLI REST MCP: https://www.npmjs.com/package/@dsebastien/obsidian-cli-rest-mcp
- MCP Protocol: https://modelcontextprotocol.io/
