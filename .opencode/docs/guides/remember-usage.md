# /remember Command Usage Guide

## Basic Usage

### Adding Text Memories

```
/remember "Your text content here"
```

**Example**:
```
/remember "Use pcall() in Lua to safely call functions that might error"
```

### Adding File Memories

```
/remember /path/to/file.md
```

**Example**:
```
/remember ~/notes/neovim-tips.md
```

## Checkbox Confirmation Options

When you run `/remember`, you'll see a preview and checkbox options:

```
Memory Preview:
─────────────────────────────────────────
ID: MEM-2026-03-06-001
Title: Use pcall() in Lua
Source: user input
Date: 2026-03-06

Content Preview (first 300 chars):
Use pcall() in Lua to safely call functions...
─────────────────────────────────────────

Similar Memories Found:
- MEM-2026-03-05-042: "Lua error handling patterns"

What would you like to do with this memory?
[ ] Add as new memory
[ ] Update existing similar memory
[ ] Edit content before saving
[ ] Skip - don't save
```

### Option Descriptions

**Add as new memory**: Creates a new memory file in `.opencode/memory/10-Memories/`

**Update existing**: If similar memories exist, appends content to the selected memory

**Edit content**: Opens the content in an editor before saving/updating

**Skip**: Cancels the operation without making changes

### Multiple Selection

You can select multiple options:
- **Add + Update**: Merge scenario - creates new memory AND updates existing
- **Edit + Add**: Modify content first, then create new memory
- **Edit + Update**: Modify content, then append to existing memory

## Memory-Augmented Research

### Using --remember Flag

Enhance research with prior knowledge from the memory vault:

```
/research OC_136 --remember
```

With focus prompt:
```
/research OC_136 "MCP server integration" --remember
```

### How It Works

1. Research extracts keywords from task description
2. Searches memory vault for relevant entries
3. Includes top 3 matching memories in research context
4. Research report includes "Prior Knowledge from Memory Vault" section

### Example Research Report Section

```markdown
## Prior Knowledge from Memory Vault

**Relevant Memories**:
- **MEM-2026-03-05-042**: Lua error handling patterns
- **MEM-2026-03-04-038**: Neovim configuration tips

**Memory-Augmented**: true
```

## Best Practices

### Writing Good Memories

1. **Use descriptive first lines** - The first line becomes the title
2. **Keep content focused** - One concept per memory
3. **Use natural language** - Write for future you
4. **Include context** - Source, date, why it's important

### Managing the Vault

1. **Review index.md** - Use it to navigate your memories
2. **Update existing** - Rather than creating many similar memories
3. **Use tags** - (Coming in Phase 2) Organize by topic
4. **Commit regularly** - `git add .opencode/memory/ && git commit`

### Git Workflow

```bash
# After adding memories
git add .opencode/memory/
git commit -m "memory: add neovim configuration tips"

# Push to sync with remote
git push
```

## Examples

### Example 1: Simple Add

```
/remember "vim.keymap.set accepts a table of options including silent and buffer"
```

Select: `[x] Add as new memory`

**Result**: New memory file created with ID MEM-2026-03-06-001

### Example 2: Update Existing

```
/remember "Additional keymap tip: use noremap=true to prevent recursion"
```

Similar memories found:
- MEM-2026-03-05-042: "vim-keymap-configuration.md"

Select: `[x] Update existing similar memory`
Choose: "vim-keymap-configuration.md"

**Result**: Content appended to existing memory with update history

### Example 3: Edit Before Save

```
/remember /tmp/draft.md
```

Select: `[x] Edit content before saving`

(Edit in buffer - add formatting, headers)

Then select: `[x] Add as new memory`

**Result**: Edited content saved as new memory

### Example 4: Research with Memory

```
/research OC_137 --remember
```

**Result**: Research report includes relevant prior knowledge from memory vault

## Quick Reference

| Command | Purpose |
|---------|---------|
| `/remember "text"` | Add text as memory |
| `/remember /path` | Add file as memory |
| `/research OC_N --remember` | Research with memory augmentation |

## See Also

- [Memory Vault README](../memory/README.md) - Vault organization
- [MCP Setup Guide](../docs/memory-setup.md) - MCP server configuration
- [Memory Troubleshooting](./memory-troubleshooting.md) - Common issues
