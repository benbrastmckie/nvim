# Loader Function Reference

Quick reference for the Lua extension loader functions used when maintaining or extending
the extension loading system.

---

## Public Functions in loader.lua

All 12 public functions follow the same signature pattern:

```lua
function M.{name}(manifest, source_dir, target_dir) -> copied_files, created_dirs
-- except check_conflicts and remove_installed_files (different signatures)
```

### Function-to-Category Table

| Function | Manifest Key | Copy Semantics | Source Subdir | Target Subdir |
|----------|-------------|----------------|---------------|---------------|
| `copy_simple_files()` | `agents`, `commands`, `rules` | Simple copy (flat .md files) | `{category}/` | `{category}/` (agents use `agents_subdir`) |
| `copy_skill_dirs()` | `skills` | Recursive copy (full directory tree) | `skills/{name}/` | `skills/{name}/` |
| `copy_context_dirs()` | `context` | Recursive copy (preserves structure) | `context/{path}/` | `context/{path}/` |
| `copy_scripts()` | `scripts` | Simple copy + preserve .sh permissions | `scripts/` | `scripts/` |
| `copy_hooks()` | `hooks` | Simple copy + always preserve execute perms | `hooks/` | `hooks/` |
| `copy_docs()` | `docs` | Simple copy (files) or recursive (dirs) | `docs/` | `docs/` |
| `copy_templates()` | `templates` | Simple copy (no execute permissions) | `templates/` | `templates/` |
| `copy_systemd()` | `systemd` | Simple copy (no execute permissions) | `systemd/` | `systemd/` |
| `copy_root_files()` | `root_files` | Simple copy (no execute permissions) | `root-files/` | `{target_dir}/` root |
| `copy_data_dirs()` | `data` | Merge-copy (skip existing files) | `data/{name}/` | `{project_dir}/{name}/` |
| `check_conflicts()` | all categories | Read-only scan; returns conflict list | n/a | `{target_dir}/{category}/` |
| `remove_installed_files()` | n/a (takes file list) | Delete files; remove empty dirs deepest-first | n/a | n/a |

### Copy Semantics Detail

**Simple copy**: Read source file, write to target path. Parent directories created automatically.
Execute permissions preserved only when `preserve_perms=true` AND file ends in `.sh`.

**Recursive copy**: Uses `scan_directory_recursive()` to walk all files under a directory,
preserving subdirectory structure. Uses `glob("**/*")` plus top-level file fallback.

**Permission-preserving copy**: After writing, calls `helpers.copy_file_permissions(src, tgt)`
to replicate the source file's mode bits on the target.

**Merge-copy**: Before writing, checks `vim.fn.filereadable(target_path)`. If the target already
exists it is **skipped** (user data preserved). Only new skeleton files are copied. These files
are tracked separately in `data_skeleton_files` so that unload can remove extension-provided
starters without touching user-created files.

---

## Function Signatures

```lua
--- Copy simple files (agents, commands, rules)
function M.copy_simple_files(manifest, source_dir, target_dir, category, extension, agents_subdir)
  -- manifest.provides[category] = array of filenames
  -- agents_subdir: optional override for agents target subdir (e.g., "agent/subagents" for OpenCode)
  -- returns: copied_files[], created_dirs[]

--- Copy skill directories (recursive)
function M.copy_skill_dirs(manifest, source_dir, target_dir)
  -- manifest.provides.skills = array of skill directory names
  -- returns: copied_files[], created_dirs[]

--- Copy context directories (preserving structure)
function M.copy_context_dirs(manifest, source_dir, target_dir)
  -- manifest.provides.context = array of relative paths (files or directories)
  -- returns: copied_files[], created_dirs[]

--- Copy scripts (with permission preservation)
function M.copy_scripts(manifest, source_dir, target_dir)
  -- manifest.provides.scripts = array of filenames
  -- .sh files get execute permissions copied from source
  -- returns: copied_files[], created_dirs[]

--- Copy hooks (execute permissions always preserved)
function M.copy_hooks(manifest, source_dir, target_dir)
  -- manifest.provides.hooks = array of filenames
  -- ALL files get execute permissions copied regardless of extension
  -- returns: copied_files[], created_dirs[]

--- Copy docs (flat files or recursive directories)
function M.copy_docs(manifest, source_dir, target_dir)
  -- manifest.provides.docs = array of filenames or directory names
  -- directories are copied recursively; files are copied flat
  -- returns: copied_files[], created_dirs[]

--- Copy templates (flat files, no execute permissions)
function M.copy_templates(manifest, source_dir, target_dir)
  -- manifest.provides.templates = array of filenames
  -- returns: copied_files[], created_dirs[]

--- Copy systemd unit files (flat files, no execute permissions)
function M.copy_systemd(manifest, source_dir, target_dir)
  -- manifest.provides.systemd = array of unit filenames
  -- returns: copied_files[], created_dirs[]

--- Copy root files (to target_dir root, not a subdirectory)
function M.copy_root_files(manifest, source_dir, target_dir)
  -- manifest.provides.root_files = array of filenames
  -- source reads from extension's root-files/ subdirectory
  -- target goes directly into target_dir/ (e.g., .claude/settings.json)
  -- returns: copied_files[], created_dirs[]

--- Copy data directories (merge-copy semantics)
function M.copy_data_dirs(manifest, source_dir, project_dir)
  -- manifest.provides.data = array of directory names
  -- NOTE: third arg is project_dir (not target_dir) - data goes to project root
  -- only copies files that do not already exist (preserves user data)
  -- returns: skeleton_files[], created_dirs[]

--- Check for conflicts before loading
function M.check_conflicts(manifest, target_dir, project_dir)
  -- project_dir is optional (only used for data conflict checking)
  -- returns: conflicts[] where each is {category, file, path, [merge=true]}
  -- merge=true means data directory merge scenario (not an overwrite conflict)

--- Remove installed files on unload
function M.remove_installed_files(installed_files, installed_dirs)
  -- installed_files: array of absolute file paths to delete
  -- installed_dirs: array of absolute directory paths; only empty dirs are removed
  -- dirs sorted deepest-first so nested empty dirs are cleaned before parents
  -- returns: removed_count (number of files deleted)
```

---

## Loader Source Files

The extension loading system consists of 8 Lua source files:

| File | Description |
|------|-------------|
| `init.lua` | Public API. Provides `M.create(config)` returning a manager with `load()`, `unload()`, `reload()`, `get_status()`, `list_available()`, `list_loaded()`, `get_details()`, `verify()`, `verify_all()`. Orchestrates all other modules. |
| `loader.lua` | File copy engine. All 12 public functions for copying extension files into the target project. Handles permission preservation, merge-copy, and conflict detection. |
| `merge.lua` | Merge strategies. `generate_claudemd()`, `append_index_entries()`, `remove_index_entries_tracked()`, `remove_orphaned_index_entries()`, `merge_settings()`, `unmerge_settings()`, `inject_section()`, `remove_section()`. |
| `state.lua` | State tracking via `extensions.json`. `read()`, `write()`, `mark_loaded()`, `mark_unloaded()`, `is_loaded()`, `needs_update()`, `get_installed_files()`, `get_installed_dirs()`, `get_merged_sections()`, `get_data_skeleton_files()`, `list_loaded()`, `get_extension_info()`. |
| `manifest.lua` | Extension discovery and manifest validation. `get_extension()`, `list_extensions()`. Validates required fields (`name`, `version`, `description`) and known `provides` categories. |
| `config.lua` | Configuration presets. `M.create(opts)` for custom config, `M.claude()` preset for `.claude/` target, `M.opencode()` preset for `.opencode/` target. |
| `picker.lua` | Telescope picker UI. Provides the extension browser launched from `<leader>ac`. Reads manager API from `init.lua` to show status, details, and trigger load/unload. |
| `verify.lua` | Post-load integrity checks. `verify_extension()` confirms all manifested files were actually copied to target, index entries exist in `index.json`, and settings entries were merged. `notify_results()` reports failures to the user. |

---

## Usage in init.lua

When `manager.load()` runs, it calls these loader functions in order:

```
1. copy_simple_files(manifest, source, target, "agents", ".md", config.agents_subdir)
2. copy_simple_files(manifest, source, target, "commands", ".md")
3. copy_simple_files(manifest, source, target, "rules", ".md")
4. copy_skill_dirs(manifest, source, target)
5. copy_context_dirs(manifest, source, target)
6. copy_scripts(manifest, source, target)
7. copy_hooks(manifest, source, target)
8. copy_docs(manifest, source, target)
9. copy_templates(manifest, source, target)
10. copy_systemd(manifest, source, target)
11. copy_root_files(manifest, source, target)
12. copy_data_dirs(manifest, source, project_dir)   -- note: project_dir not target
```

All operations run inside a `pcall` block. On failure, `remove_installed_files()` rolls back
all copied files and directories before the error is returned to the caller.

---

## Related Documentation

- [Extension Development Guide](extension-development.md) - How to create a new extension
- [Extension System Architecture](../../../docs/architecture/extension-system.md) - Full architecture overview
