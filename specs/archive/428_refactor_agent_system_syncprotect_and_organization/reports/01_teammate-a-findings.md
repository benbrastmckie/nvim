# Teammate A Findings: .syncprotect and Backup Elimination

**Task**: 428 - Refactor agent system: syncprotect integration, backup elimination, and systematic organization review
**Focus**: Primary angle - .syncprotect feature and backup elimination mechanism
**Date**: 2026-04-14

---

## Key Findings

### Finding 1: .syncprotect is stored INSIDE the directory it must protect
**Confidence**: HIGH
**Location**: `sync.lua:385-404` (`load_syncprotect` function)

The `.syncprotect` file is read from `{project_dir}/{base_dir}/.syncprotect` (e.g., `project/.claude/.syncprotect`). When a full sync replaces the contents of `.claude/`, the `.syncprotect` file itself is in the blocklist -- but ONLY if listed inside itself. This is a circular dependency: the file that controls protection must list itself to be protected. If it doesn't, sync can overwrite it. More critically, the `.syncprotect` file is inside the directory being synced from global source, meaning a "Sync all" operation on a fresh project would COPY the nvim global `.syncprotect` (which doesn't exist) to the target, destroying the target's existing `.syncprotect`.

**Verification**: `load_syncprotect` at `sync.lua:385`:
```lua
local filepath = project_dir .. "/" .. base_dir .. "/.syncprotect"
```
And `CONTEXT_EXCLUDE_PATTERNS` at `sync.lua:24-29` does NOT include `.syncprotect` itself. The protection check in `sync_files` at `sync.lua:244-250` applies to `file.action == "replace"` with relative paths from `base_path`. A `.syncprotect` file would only be protected if it exists in the global source (which it won't for the nvim repo) or the target has explicitly listed `.syncprotect` in itself.

### Finding 2: .syncprotect already implemented -- but location problem confirmed
**Confidence**: HIGH

The `.syncprotect` feature was implemented as part of task 422 and is FULLY FUNCTIONAL for the zed repo at `/home/benjamin/.config/zed/.claude/.syncprotect`. The zed `.syncprotect` currently protects 10 files including `CLAUDE.md`, `README.md`, `agents/README.md`, and several specific command/skill files.

The implementation is clean and correct for PROTECTING files. The only architectural problem is the LOCATION: `.syncprotect` lives inside `.claude/` which is the target of sync operations.

### Finding 3: Backup mechanism is pervasive but never used for rollback
**Confidence**: HIGH
**Location**: `merge.lua` -- every public function

The `backup_file()` function (`merge.lua:94-104`) creates `{filepath}.backup` before every write operation. It is called in ALL six public functions:
- `inject_section` (line 153): backup before modifying CLAUDE.md/OPENCODE.md
- `remove_section` (line 188): backup before removing a section
- `merge_settings` (line 273): backup before writing settings.json
- `unmerge_settings` (line 309): backup before writing settings.json
- `append_index_entries` (line 369): backup before writing index.json
- `remove_index_entries_tracked` (line 421): backup before writing index.json
- `remove_index_entries_by_prefix` (line 477): backup before writing index.json
- `remove_orphaned_index_entries` (line 578): backup before writing index.json
- `merge_opencode_agents` (line 604): backup before writing opencode.json
- `unmerge_opencode_agents` (line 654): backup before writing opencode.json

The `restore_from_backup()` function (`merge.lua:109-119`) is called in only THREE locations where the write itself failed:
- `inject_section` (line 172): restore if write failed
- `merge_settings` (line 291, 295): restore if encode or write failed
- `append_index_entries` (line 399): restore if write failed

The pattern is: backup ALWAYS before write, restore ONLY if write fails. This means every successful operation leaves a `.backup` file that is never cleaned up. The backup serves only as a rollback for write failures -- it is NOT used for content diffing, auditing, or user-visible rollback.

### Finding 4: index.json.backup is excluded from sync -- but that was added in task 422
**Confidence**: HIGH
**Location**: `sync.lua:24-29`

`CONTEXT_EXCLUDE_PATTERNS` currently includes `index.json.backup` (added by task 422). This means the backup file created by `append_index_entries` for `index.json` won't be accidentally synced to other repos. But `.backup` files for `settings.json`, `CLAUDE.md`, etc. are not excluded from sync -- they would be synced if they happen to exist in the global source.

---

## Current Implementation Analysis

### .syncprotect: How It Works

1. **File location**: `{project_dir}/{base_dir}/.syncprotect`
   - For Claude: `{project_dir}/.claude/.syncprotect`
   - For OpenCode: `{project_dir}/.opencode/.syncprotect`

2. **File format**: Plain text, one relative path per line (relative to the `base_dir`), `#` for comments, empty lines ignored. Example:
   ```
   # Files customized for this repository
   CLAUDE.md
   rules/git-workflow.md
   agents/README.md
   ```

3. **Loading**: `load_syncprotect()` at `sync.lua:385-404` reads the file and returns a set `{[rel_path] = true}`.

4. **Application**: `sync_files()` at `sync.lua:232-286` receives `protected_paths` and `base_path`. For each file with `action == "replace"`, it computes the relative path as:
   ```lua
   local rel_path = file.local_path:sub(#base_path + 2)
   ```
   If `protected_paths[rel_path]` is true, the file is skipped and `protected_count` is incremented.

5. **Scope**: Protection ONLY applies to "replace" actions. New files ("copy") are NEVER blocked.

6. **When loaded**: Only in `load_all_globally()` at `sync.lua:648-650`, just before `execute_sync()`. The `update_artifact_from_global()` function (single-file update, `sync.lua:670-769`) does NOT check `.syncprotect`.

### Backup Mechanism: Complete Call Inventory

| Function | Creates backup of | Restores on failure? | Backup file |
|----------|-------------------|---------------------|-------------|
| `inject_section` | `target_path` (CLAUDE.md) | Yes | `.backup` |
| `remove_section` | `target_path` (CLAUDE.md) | Yes | `.backup` |
| `merge_settings` | `target_path` (settings.json) | Yes | `.backup` |
| `unmerge_settings` | `target_path` (settings.json) | Yes | `.backup` |
| `append_index_entries` | `target_path` (index.json) | Yes | `.backup` |
| `remove_index_entries_tracked` | `target_path` (index.json) | Yes | `.backup` |
| `remove_index_entries_by_prefix` | `target_path` (index.json) | Yes | `.backup` |
| `remove_orphaned_index_entries` | `index_path` (index.json) | Yes | `.backup` |
| `merge_opencode_agents` | `target_path` (opencode.json) | Yes | `.backup` |
| `unmerge_opencode_agents` | `target_path` (opencode.json) | Yes | `.backup` |

Every write in the merge system follows: `backup_file()` -> write -> `restore_from_backup()` only if write fails.

### Extension Load/Unload Cycle and Where Backups Occur

During `manager.load()` (`init.lua:206-418`):
1. Files copied to target: agents, commands, rules, skills, context, scripts (NO backups created here -- these are new files)
2. `process_merge_targets()` called (`init.lua:72-152`)
   - `merge_mod.inject_section()` -- creates `.backup` of `CLAUDE.md`
   - `merge_mod.merge_settings()` -- creates `.backup` of `settings.json`
   - `merge_mod.append_index_entries()` -- creates `.backup` of `index.json`
   - `merge_mod.merge_opencode_agents()` -- creates `.backup` of `opencode.json`

During `manager.unload()` (`init.lua:425-501`):
1. `reverse_merge_targets()` called (`init.lua:159-193`)
   - `merge_mod.remove_section()` -- creates `.backup` of `CLAUDE.md`
   - `merge_mod.unmerge_settings()` -- creates `.backup` of `settings.json`
   - `merge_mod.remove_index_entries_tracked()` -- creates `.backup` of `index.json`
   - `merge_mod.unmerge_opencode_agents()` -- creates `.backup` of `opencode.json`
2. Installed files removed: no backups created

During `manager.reload()`: both unload and load sequences run, creating backups twice.

During `sync.load_all_globally()` (`sync.lua:563-661`) with `reinject_loaded_extensions()`:
- `merge_mod.inject_section()` -- creates `.backup` of `CLAUDE.md`
- `merge_mod.merge_settings()` -- creates `.backup` of `settings.json`
- `merge_mod.append_index_entries()` -- creates `.backup` of `index.json`

### Storage Location Problem: Detailed Analysis

The `.syncprotect` file at `{project_dir}/.claude/.syncprotect` is vulnerable because:

1. **Not in CONTEXT_EXCLUDE_PATTERNS**: The sync scan for root_files (`scan_all_artifacts()` lines 527-556) explicitly lists files to sync:
   ```lua
   root_file_names = { ".gitignore", "README.md", "CLAUDE.md", "settings.local.json" }
   ```
   `.syncprotect` is NOT in `root_file_names` so it wouldn't be synced. **BUT**: the file is inside the `.claude/` directory, and the sync system scans all subdirectories of `.claude/` recursively (commands, hooks, agents, etc.). A `.syncprotect` file at the BASE of `.claude/` (not a subdirectory) would only appear in `scan_all_artifacts()` via the `settings` scan:
   ```lua
   artifacts.settings = sync_scan("", "settings.json")
   ```
   This only scans for `settings.json` at the root level. So `.syncprotect` is NOT currently synced. It is safe from sync in the current implementation.

2. **However**: The real problem is the opposite direction -- `.syncprotect` WILL be wiped if the `.claude/` directory itself is DELETED and recreated. Fresh project setup copies the entire `.claude/` from global source, and `.syncprotect` is not in global source.

3. **The circular dependency**: For `.syncprotect` to protect itself, it would need to list itself (`".syncprotect"`) in its own contents. Currently the zed `.syncprotect` does NOT include itself. This is safe because `.syncprotect` isn't currently synced. But this creates a fragile assumption.

---

## Problems Identified

### Problem 1: .syncprotect should live outside .claude/
**Severity**: Medium
**Impact**: Philosophical/architectural -- the current implementation happens to work because `.syncprotect` is not scanned by the sync engine, but this is an accidental safety rather than a designed one.

The correct location should be at the project root level where it is clearly outside the managed `.claude/` directory. Proposed path: `{project_dir}/.claude-syncprotect` or `{project_dir}/.syncprotect` (at project root).

Alternatively, a convention of storing it at `{project_dir}/.syncprotect` with a comment header indicating it covers all agent config directories would be cleaner and more discoverable.

### Problem 2: .syncprotect not checked during single-file update
**Severity**: Low
**Impact**: `update_artifact_from_global()` (`sync.lua:670-769`) bypasses `.syncprotect` protection entirely. A user can explicitly update a single file that they've listed in `.syncprotect`, which may be intentional (they can always manually update), but the UI gives no indication of the protection status.

### Problem 3: Backup files accumulate without cleanup
**Severity**: Low-Medium
**Impact**: Every extension load/unload/reload creates `.backup` files for CLAUDE.md, settings.json, index.json, and opencode.json. These are never deleted, accumulating silently in the `.claude/` directory. In repos like zed with frequent extension reloads, these files clutter the repository.

The backup files ALSO appear in `.gitignore` consideration -- if `.gitignore` doesn't exclude `.backup` files, they appear in `git status` as untracked. In the nvim global repo, `.claude/.gitignore` should list these.

### Problem 4: Backups created even for idempotent no-op operations
**Severity**: Low
**Impact**: The `inject_section()` function creates a backup even when the section already exists (the idempotency check at `merge.lua:159` runs AFTER the backup at line 153). Similarly, `append_index_entries()` creates a backup even if all entries already exist (deduplication check runs AFTER backup). This means every reload creates 4-8 `.backup` files even when no content actually changes.

### Problem 5: No .syncprotect documentation or default content
**Severity**: Low
**Impact**: New project repos don't know about `.syncprotect`. There's no template or default content. The feature was implemented but not documented in a way that helps users discover it.

---

## Recommended Changes

### Recommendation 1: Move .syncprotect to project root
**Priority**: Medium
**Files**: `sync.lua:385-404` (`load_syncprotect` function)

Change the path resolution from:
```lua
local filepath = project_dir .. "/" .. base_dir .. "/.syncprotect"
```
To:
```lua
local filepath = project_dir .. "/.syncprotect"
```

This places `.syncprotect` at the project root, outside any managed directory. The file would cover both `.claude/` and `.opencode/` directories, which is better anyway since a project may use both.

**Update format to include base_dir prefix in paths**:
```
# .syncprotect - Files protected from agent system sync
# Paths are relative to the agent config directory (.claude/ or .opencode/)
.claude/CLAUDE.md
.claude/rules/git-workflow.md
.claude/agents/README.md
```

Or alternatively, keep paths relative but make the load function aware of which base_dir it's checking:
```lua
-- Filter protected paths to only those under base_dir
for line in file:lines() do
  -- If path starts with base_dir, strip the prefix
  -- If path doesn't start with any known prefix, assume it's base_dir-relative
end
```

**Simpler alternative**: Keep the format as relative-to-base_dir, but the FILE lives at project root. The loading function strips the `base_dir/` prefix if present.

### Recommendation 2: Make backup creation conditional
**Priority**: Low-Medium
**Files**: `merge.lua:94-104` (`backup_file` function), or callers

Option A: Remove backups entirely -- they're almost never needed since the merge operations are idempotent and reversible through the tracking system. If `inject_section` fails to write, the original content is still there (write failures typically leave files unchanged).

Option B: Keep backups but add cleanup -- after a successful write, delete the backup:
```lua
local function cleanup_backup(filepath)
  local backup_path = filepath .. ".backup"
  os.remove(backup_path)
end
```

Option C: Make backup conditional on actual content change -- only backup if the new content differs from current. This eliminates idempotent no-op backups.

**Recommendation**: Option B (keep but clean up). The backup is a safety net for power failures mid-write, which is a valid concern. But leaving backups forever is messy. Delete the backup after successful write.

### Recommendation 3: Add .syncprotect to default .gitignore
**Priority**: Low
**Files**: `/home/benjamin/.config/nvim/.claude/.gitignore`

Ensure `.backup` files and `.syncprotect` (if at root) are in the `.gitignore` pattern. Currently the `.gitignore` content should include:
```
*.backup
```

### Recommendation 4: Add default .syncprotect for this nvim repo
**Priority**: Low
**Files**: Create `/home/benjamin/.config/nvim/.syncprotect` (if moving to root) or `/home/benjamin/.config/nvim/.claude/.syncprotect`

For the nvim repo specifically, the files that would benefit from protection are:
- `CLAUDE.md` (contains nvim-specific content not appropriate for other repos)
- `context/repo/project-overview.md` (repo-specific, generated per project)

However, this repo IS the global source -- it's where syncs come FROM, not where they go TO. The global source doesn't need `.syncprotect` since sync operations guard against `project_dir == global_dir` check at `load_all_globally()` line 569-572:
```lua
if project_dir == global_dir then
  helpers.notify("Already in the global directory", "INFO")
  return 0
end
```

So `.syncprotect` in the nvim repo would only matter for the extension self-loading guard.

### Recommendation 5: Check .syncprotect in update_artifact_from_global
**Priority**: Low
**Files**: `sync.lua:670-769` (`update_artifact_from_global` function)

Either: load `.syncprotect` and show a warning when updating a protected file, or: honor the protection and refuse the update with a clear message. The current behavior silently ignores protection for single-file updates.

---

## Confidence Assessment

| Finding | Confidence | Basis |
|---------|------------|-------|
| .syncprotect location problem | HIGH | Direct code reading, path resolution traced exactly |
| Backup accumulation issue | HIGH | All 10 backup call sites enumerated, no cleanup code found |
| .syncprotect not checked in single-file update | HIGH | `update_artifact_from_global` read fully, no protection check present |
| Idempotent backup waste | HIGH | `inject_section` line order confirmed: backup at 153, check at 159 |
| .syncprotect not currently synced | HIGH | `root_file_names` and scan patterns examined, `.syncprotect` not included |
| Moving .syncprotect to root is safe | MEDIUM | Based on analysis of scan patterns, but edge cases may exist |
| Option B (cleanup after write) is best | MEDIUM | Balances safety vs cleanliness; alternatives viable |

---

## References

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - `load_syncprotect()` (lines 379-404), `sync_files()` (lines 232-286), `execute_sync()` (lines 288-366), `load_all_globally()` (lines 559-661)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - `backup_file()` (lines 94-104), `restore_from_backup()` (lines 109-119), all backup call sites
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - `process_merge_targets()` (lines 72-152), `reverse_merge_targets()` (lines 159-193), `manager.load()` (lines 206-418), `manager.unload()` (lines 425-501)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - `get_state_path()` (lines 70-72), state tracking
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - config presets defining `base_dir` values
- `/home/benjamin/.config/zed/.claude/.syncprotect` - existing real-world .syncprotect (only known instance)
- `specs/420_prevent_extension_loader_overwriting_repo_customizations/` - task that introduced section preservation and re-injection
- `specs/422_fix_sync_overwriting_all_non_claudemd_files/` - task that introduced .syncprotect implementation
