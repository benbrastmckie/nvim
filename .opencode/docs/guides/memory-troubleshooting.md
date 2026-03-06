# Memory System Troubleshooting

## Common Issues and Solutions

### MCP Server Not Connecting

**Symptoms**:
- `/research --remember` doesn't find memories
- "Connection refused" errors
- Memory search step skipped

**Causes & Solutions**:

1. **Obsidian not running**
   - Start Obsidian desktop app
   - Open `.opencode/memory/` as vault
   - Verify Obsidian CLI REST plugin is enabled

2. **Wrong API key**
   - Check plugin settings for correct API key
   - Verify key matches in MCP configuration
   - Regenerate key if needed

3. **Port conflict**
   - Default port: 27124
   - Check if another service uses this port
   - Change port in Obsidian plugin settings and MCP config

4. **Plugin not installed**
   - Install "Obsidian CLI REST" from Community Plugins
   - Enable the plugin
   - Note the API key

**Verification**:
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://127.0.0.1:27124/vault/
```

### Checkbox Confirmation Not Appearing

**Symptoms**:
- `/remember` runs but no interactive dialog shown
- No preview displayed
- Operation completes without confirmation

**Causes & Solutions**:

1. **AskUserQuestion tool unavailable**
   - Verify skill has `allowed-tools: AskUserQuestion`
   - Check tool permissions

2. **Invalid input**
   - Verify file path exists if using file input
   - Check for empty content

3. **Context not loaded**
   - Ensure skill context is properly configured
   - Verify template file exists

### Memories Not Found in Research

**Symptoms**:
- `/research OC_N --remember` shows "No relevant memories found"
- Memory vault appears empty in research context

**Causes & Solutions**:

1. **Vault empty**
   - Add some memories first using `/remember`
   - Check `.opencode/memory/10-Memories/` for files

2. **MCP server not connected**
   - See "MCP Server Not Connecting" above

3. **Keywords don't match**
   - Use more specific keywords in task description
   - Check memory titles for relevant terms

4. **--remember flag missing**
   - Verify flag is present in command
   - Check for typos

### Similar Memory Detection Not Working

**Symptoms**:
- `/remember` shows "Similar Memories Found: (none)" when similar memories exist
- Duplicate memories created

**Causes & Solutions**:

1. **MCP unavailable**
   - Uses file-based fallback which is less accurate
   - Connect MCP server for better search

2. **Poor titles**
   - Ensure memories have descriptive titles
   - First line of text becomes the title

3. **Very different content**
   - Similarity detection looks for keyword matches
   - Memories with different terminology won't match

### Git Conflicts in index.md

**Symptoms**:
- Git merge conflicts in `.opencode/memory/20-Indices/index.md`
- Multiple entries for same memory

**Solution**:

1. **Simple list structure** makes resolution easy:
   ```markdown
   - [Memory Title](path/to/file.md)
   ```

2. **Conflict resolution**:
   ```bash
   # Pull latest changes first
git pull
   
   # If conflict occurs, edit index.md manually
   # Keep both entries or merge duplicates
   
   # Commit resolution
   git add index.md
   git commit -m "Resolve index.md merge conflict"
   ```

3. **Prevention**:
   - Pull before adding memories
   - Commit frequently
   - Keep vault synchronized

### Memory Files Not Created

**Symptoms**:
- `/remember` reports success but no files in `10-Memories/`
- Index.md not updated

**Causes & Solutions**:

1. **User selected "Skip"**
   - This is expected behavior
   - No files created when skipping

2. **Permission denied**
   - Check directory permissions
   - Ensure write access to `.opencode/memory/`

3. **Disk full**
   - Check available disk space
   - Memory files are small (usually < 10KB)

### Obsidian Not Recognizing Vault

**Symptoms**:
- "No vault found" when opening `.opencode/memory/`
- Missing configuration

**Solution**:

1. **Verify structure**:
   ```
   .opencode/memory/
   ├── .obsidian/
   │   ├── app.json
   │   ├── appearance.json
   │   └── core-plugins.json
   └── ... (other directories)
   ```

2. **Check permissions**:
   - Ensure `.obsidian/` is readable
   - Configuration files must be valid JSON

3. **Re-initialize**:
   - Delete `.obsidian/` directory
   - Recreate with proper configuration
   - Restart Obsidian

### Index.md Not Updating

**Symptoms**:
- New memories created but not in index
- Links missing

**Causes**:

1. **Git conflict** (see above)
2. **Permission issue**
3. **Process interrupted**

**Solution**:

Manually add to index.md:
```markdown
- [Memory Title](10-Memories/MEM-2026-03-06-001-title.md)
```

## Debug Steps

When troubleshooting, check these in order:

1. **Is Obsidian running?**
   ```bash
   ps aux | grep Obsidian
   ```

2. **Is the vault structure correct?**
   ```bash
   ls -la .opencode/memory/
   ls -la .opencode/memory/10-Memories/
   ```

3. **Is MCP responding?**
   ```bash
   curl http://127.0.0.1:27124/vault/ -H "Authorization: Bearer KEY"
   ```

4. **Are there memory files?**
   ```bash
   ls .opencode/memory/10-Memories/
   wc -l .opencode/memory/10-Memories/*.md
   ```

5. **Check git status**:
   ```bash
   git status --short .opencode/memory/
   ```

## Getting Help

If issues persist:

1. Check [Usage Guide](../docs/remember-usage.md) for correct syntax
2. Review [MCP Setup Guide](../docs/memory-setup.md) for configuration
3. Verify [Memory Vault README](../memory/README.md) for organization
4. Check OpenCode logs for error messages

## Known Limitations

1. **MCP requires Obsidian running**: Can't search memories without it
2. **Vault size**: Phase 1 optimized for < 1,000 memories
3. **No auto-tagging**: Tags must be added manually (Phase 2+)
4. **No semantic search**: Keyword matching only (Phase 3+)

## See Also

- [Usage Guide](../docs/remember-usage.md) - How to use /remember
- [MCP Setup Guide](../docs/memory-setup.md) - Server configuration
- [Memory Vault README](../memory/README.md) - Vault structure
