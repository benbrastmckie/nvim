# Research Report: Task #172

**Task**: Investigate OPENCODE.md core content loss on reload
**Date**: 2026-03-10
**Focus**: Trace `<leader>ao` loader code path and identify why core content is dropped

## Summary

The root cause is an architectural gap between two design decisions: (1) Task OC_127 removed `OPENCODE.md` from the global `.opencode/` system, consolidating to `README.md`, but (2) extension manifests still target `.opencode/OPENCODE.md` for section injection. No mechanism exists to populate OPENCODE.md with core content -- it is created and populated exclusively by extension section injections. When extensions are fully reloaded, OPENCODE.md is rebuilt from scratch with only extension sections.

## Findings

### Code Path Trace: `<leader>ao`

**Keybinding definition**: `lua/neotex/plugins/editor/which-key.lua:257`
```
{ "<leader>ao", "<cmd>OpencodeCommands<CR>", desc = "opencode commands" }
```

**Full call chain**:
1. `<leader>ao` -> `:OpencodeCommands` user command
2. `neotex.plugins.ai.opencode.lua:59-61` -> `opencode.commands.picker.show_commands_picker()`
3. `opencode.commands.picker` delegates to `claude.commands.picker.init` with OpenCode config
4. Picker shows entries including "[Load Core Agent System]" and extension toggles

**Two code paths that affect OPENCODE.md**:

**Path A: "[Load Core Agent System]" entry** (line 93-101 of picker/init.lua)
- Calls `sync.load_all_globally(config)` in `picker/operations/sync.lua`
- Scans `~/.config/nvim/.opencode/` for all artifacts
- Root files list (sync.lua:248): `{ "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md" }`
- Since no global `OPENCODE.md` exists, it is NOT synced
- Result: Does NOT directly modify OPENCODE.md
- But: Replaces agent/skill/command files, potentially invalidating extension state

**Path B: Extension toggle** (lines 139-151 of picker/init.lua)
- Active extension: calls `exts.unload(ext.name)` -> `reverse_merge_targets` -> `merge.remove_section()`
- Inactive extension: calls `exts.load(ext.name)` -> `process_merge_targets` -> `merge.inject_section()`

### OPENCODE.md Assembly Logic

**Extension section injection** (`shared/extensions/merge.lua:137-169`):
```lua
function M.inject_section(target_path, section_content, section_id)
  -- If file doesn't exist, creates EMPTY file
  if vim.fn.filereadable(target_path) ~= 1 then
    write_file_string(target_path, "")  -- BUG: No core content
  end
  -- Then injects extension section
end
```

**Extension section removal** (`shared/extensions/merge.lua:175-199`):
- Uses `gsub` with non-greedy pattern `.-` to remove specific section
- Preserves all other content including core content
- File is always written back (never deleted)

### Why Core Content Is Being Dropped

**The architectural gap**:

1. **Task OC_127** (commit `d31ff91c`, 2026-03-03): Deleted `OPENCODE.md` from global `.opencode/` directory. All references updated to point to `README.md`. The global system now uses `README.md` as its canonical documentation file.

2. **Extension manifests** still have merge targets pointing to `OPENCODE.md`:
   ```json
   "merge_targets": {
     "opencode_md": {
       "source": "EXTENSION.md",
       "target": ".opencode/OPENCODE.md",
       "section_id": "extension_oc_epidemiology"
     }
   }
   ```

3. **No global source for OPENCODE.md**: `~/.config/nvim/.opencode/OPENCODE.md` does not exist, so the "Load Core Agent System" sync cannot restore it.

4. **No core content injection**: When `inject_section` creates OPENCODE.md for the first time, it creates an empty file. Nothing adds core content.

### Evidence: The Specific Content Loss Event

From git and filesystem timestamps:

| Time (PDT) | Event |
|-------------|-------|
| 14:33:28 | Task 171 commits OPENCODE.md with core + extension content (833 lines) |
| 14:35:57 | First extension (epidemiology) loaded |
| 14:35:58 | filetypes extension loaded |
| 14:36:00 | formal extension loaded |
| ... | (all 11 extensions loaded sequentially) |
| 14:36:18 | Last extension (z3) loaded; OPENCODE.md now 542 lines (extension-only) |

All 11 extensions were loaded between 14:35:57 and 14:36:18 (21 seconds). For `load()` to succeed, extensions must have been unloaded first (otherwise "Extension already loaded" error). This means somewhere between 14:33 and 14:35, all extensions were unloaded, and OPENCODE.md was at some point recreated as an empty file.

**The backup file** (`OPENCODE.md.backup`) also contains extension-only content, confirming the backup was created during this reload cycle.

### Existing Patterns

**CLAUDE.md equivalent**: The Claude system has the same architecture but avoids this issue because:
- Global `~/.config/nvim/.claude/CLAUDE.md` EXISTS and is synced as a root file
- It contains core content that extensions append to
- The sync operation can always restore the core content

**The asymmetry**: After task OC_127, `.opencode/` diverged from `.claude/` by removing OPENCODE.md. The extension system was not updated to account for this change.

## Recommendations

### Fix Option 1: Create global OPENCODE.md (Recommended - Simplest)

Create `~/.config/nvim/.opencode/OPENCODE.md` with core system documentation (copied from `.opencode_core/README.md` or the `.opencode/README.md`). This mirrors how `.claude/CLAUDE.md` works.

**Pros**:
- Mirrors the working `.claude/` pattern
- "Load Core Agent System" sync will automatically restore core content
- No code changes needed

**Cons**:
- Duplicates content between README.md and OPENCODE.md
- Must keep both files in sync

### Fix Option 2: Modify inject_section to include core content

Update `merge.lua:inject_section` to read core content from a template when creating a new OPENCODE.md file:

```lua
if vim.fn.filereadable(target_path) ~= 1 then
  -- Read core content from README.md as template
  local readme_path = vim.fn.fnamemodify(target_path, ":h") .. "/README.md"
  local core_content = read_file_string(readme_path) or ""
  write_file_string(target_path, core_content)
end
```

**Pros**:
- Automatically includes core content when OPENCODE.md is created fresh
- Single source of truth (README.md)

**Cons**:
- Changes shared code that affects both Claude and OpenCode systems
- README.md may not always be the right source

### Fix Option 3: Add core content assembly to extension loading

Add a step in the extension `load` flow that ensures core content exists in OPENCODE.md before injecting extension sections. This could use a marker like `<!-- CORE_CONTENT -->` to detect whether core content is present.

**Pros**:
- Explicit handling of the core/extension content boundary

**Cons**:
- More complex implementation
- Another marker convention to maintain

### Fix Option 4: Change manifests to target README.md

Update all extension manifests to inject into `.opencode/README.md` instead of `.opencode/OPENCODE.md`, aligning with the task OC_127 decision.

**Pros**:
- Consistent with the OC_127 decision to use README.md
- Single file, no duplication

**Cons**:
- README.md serves a different purpose (documentation vs config file)
- OpenCode may specifically require OPENCODE.md as its config file name

## Decisions

- Root cause is an architectural gap, not a code bug
- The fix should address the gap at the architectural level
- Option 1 (create global OPENCODE.md) is the simplest and most reliable fix
- The fix location is in the global `.opencode/` directory, not in Lua code

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Content loss recurrence | High - Agent system loses documentation | Create global OPENCODE.md as definitive source |
| Sync overwriting manual changes | Medium - Project customizations lost | Document that OPENCODE.md core content comes from global, project adds extension sections |
| Dual maintenance (README.md + OPENCODE.md) | Low - Content drift | Generate OPENCODE.md from README.md, or keep one as symlink |

## Key Files

| File | Purpose |
|------|---------|
| `lua/neotex/plugins/editor/which-key.lua:257` | `<leader>ao` keybinding definition |
| `lua/neotex/plugins/ai/opencode/commands/picker.lua` | OpencodeCommands facade |
| `lua/neotex/plugins/ai/claude/commands/picker/init.lua:93-101` | "Load All" handler |
| `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua:248` | Root file list (OPENCODE.md included but no global source) |
| `lua/neotex/plugins/ai/shared/extensions/merge.lua:137-169` | `inject_section` - creates empty OPENCODE.md |
| `lua/neotex/plugins/ai/shared/extensions/init.lua:282` | `process_merge_targets` - extension load merge |
| `lua/neotex/plugins/ai/shared/extensions/config.lua:68` | OpenCode config: `config_file = "OPENCODE.md"` |
| `~/.config/nvim/.opencode/` | Global source (no OPENCODE.md since task OC_127) |
| `~/.config/nvim/.opencode_core/README.md` | Core system documentation |

## References

- Task OC_127 (commit `d31ff91c`): Removed OPENCODE.md from global `.opencode/`, updated references to README.md
- Task 170: First manual fix (merged core content into project OPENCODE.md)
- Task 171: Second manual fix (same approach, lost again)

## Next Steps

1. Implement Fix Option 1: Create `~/.config/nvim/.opencode/OPENCODE.md` from `.opencode_core/README.md`
2. Optionally: Add a `## Extension Sections` header at the end of the global OPENCODE.md so extensions inject after it
3. Test by running "Load Core Agent System" sync, then reloading extensions
4. Verify core content survives the full cycle
