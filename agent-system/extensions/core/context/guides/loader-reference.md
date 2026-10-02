# Loader Function Reference

Quick reference for the Lua extension loader functions used when maintaining or extending
the extension loading system.

---

## Public Functions in loader.lua

The former 11 near-identical per-category `copy_*` functions have been collapsed into one
descriptor-driven copier, `M.copy_category`, plus a `CATEGORY_DESCRIPTORS` table that is the
single source of truth for how each `provides.*` category (and the two non-`provides`-keyed
special cases, `manifest` and `data`) maps declared entries to deployed paths. The symlink guard
and permission handling hold for every category by construction, since they are driven by the
descriptor rather than each category separately reimplementing them.

```lua
function M.copy_category(category, manifest, source_dir, target_dir, protected_paths, opts)
  -> copied_files, created_dirs, skipped_count, symlink_skipped_count
-- except check_conflicts and remove_installed_files (different signatures, unchanged)
```

### Category Descriptor Table

`M.CATEGORY_DESCRIPTORS`, keyed by category name:

| Category | `list_key` | `entry_kind` | `preserve_perms` | `symlink_guard` | Other fields |
|----------|-----------|--------------|-------------------|-----------------|--------------|
| `agents` | `agents` | `file` | `sh_only` | yes | target subdir overridable via `opts.agents_subdir` |
| `commands` | `commands` | `file` | `sh_only` | yes | |
| `rules` | `rules` | `file` | `sh_only` | yes | |
| `skills` | `skills` | `dir` | `sh_only` | yes | each entry is itself a directory, recursively copied |
| `context` | `context` | `file_or_dir` | `none` | no | an entry may be a file or a directory |
| `scripts` | `scripts` | `file` | `always` | no | entries may themselves contain `/` (subdirectory-declared) |
| `hooks` | `hooks` | `file` | `always` | no | |
| `docs` | `docs` | `file_or_dir` | `none` | no | |
| `templates` | `templates` | `file` | `none` | no | |
| `systemd` | `systemd` | `file` | `none` | no | |
| `root_files` | `root_files` | `file` | `none` | no | `target_subdir = ""` (lands at `target_dir` root); `install_once` set for `settings.json`/`settings.local.json` |
| `manifest` | n/a | n/a | `none` | n/a | `single_file = true`, `self_load_skip = true` -- one fixed source file, not a `provides.*` list |
| `data` | `data` | `dir` | `none` | n/a | `merge_copy_only = true`, `target_is_project_root = true` -- lands under `project_dir`, skips entries that already exist |

**`preserve_perms` modes**: `"always"` (every copied file keeps its execute bit -- scripts/hooks),
`"sh_only"` (only `.sh`-suffixed entries do -- agents/commands/rules/skills), `"none"`
(everything else).

**`entry_kind` values**: `"file"` (flat file per entry), `"dir"` (each entry is itself a
directory, recursively copied and symlink-guarded as a whole), `"file_or_dir"` (an entry may be
either -- context/docs).

**`root_files` cannot deliver a consumer repo-root contribution.** Its target is `{target_dir}/`
root -- for the core extension, `{target_dir}` is the consumer's `.claude/` directory, not the
repository root. A pattern intended for the repo's own root `/.gitignore` (e.g. a `specs/*/`
runtime-file ignore block) placed in `root-files/.gitignore` would deploy to `.claude/.gitignore`
and resolve relative to `.claude/`, matching nothing. There is currently no loader function that
writes to a consumer repo's root; such a contribution is applied by hand, once, per
`context/standards/orchestrator-runtime-files.md`'s "Consumer Repo Setup" section.

### Copy Semantics Detail

**"file" entries**: Read source file, write to target path. Parent directories created
automatically. Execute permissions preserved per the category's `preserve_perms` mode.

**"dir"/"file_or_dir" recursive entries**: Uses an internal `scan_directory_recursive()` to walk
all files under a directory, preserving subdirectory structure (`glob("**/*")` plus a top-level
file fallback).

**Permission-preserving copy**: After writing, calls `helpers.copy_file_permissions(src, tgt)` to
replicate the source file's mode bits on the target, when the category's `preserve_perms` mode
says to.

**Symlink guard**: For a category with `symlink_guard = true`, a pre-existing symlink at the
deployed target is left alone rather than written through -- the copy engine only ever owns paths
it created as regular files (see `extension-deploy-modes.md` for the full ownership rule and
`M.remove_installed_files`'s matching invariant on the removal side).

**Install-once**: For an entry present in a category's `install_once` set (currently only
`root_files`' `settings.json`/`settings.local.json`), the copy is skipped (counted, not written)
whenever a target copy already exists -- these files carry project-specific customizations that
must never be silently overwritten by a reload/regenerate.

**Merge-copy** (`data` only): Before writing, checks `vim.fn.filereadable(target_path)`. If the
target already exists it is **skipped** (user data preserved). Only new skeleton files are
copied. These files are tracked separately in `data_skeleton_files` so that unload can remove
extension-provided starters without touching user-created files.

**Additive-only, by design**: none of the semantics above ever delete a deployed file because its
source-store entry disappeared -- `copy_category` only ever adds or overwrites. Reverse-direction
detection (deployed files/index rows no active extension declares) is a separate mechanism,
`verify.lua`'s `M.find_orphans` (`verify-deploy.sh` gate 13); see
[Deploy Orphan Detection](../patterns/deploy-orphan-detection.md) for the exclusion contract and
[Extension System Architecture](../../../docs/architecture/extension-system.md)'s "Additive-Only
Copy/Index Merge and Orphan Detection" section for the full decision.

---

## Function Signature

```lua
--- Copy one provides.* category (or the manifest/data special cases) per its descriptor.
--- @param category string Category name; must be a key of M.CATEGORY_DESCRIPTORS
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}
--- @param opts table|nil { project_dir, extension_name, agents_subdir } -- required per
---   category: `data` needs project_dir; `manifest` needs extension_name; `agents` uses
---   agents_subdir if given (falls back to the descriptor's own "agents" target_subdir)
--- @return table copied_files
--- @return table created_dirs
--- @return number skipped_count Files skipped due to .syncprotect (or install-once/merge-copy)
--- @return number symlink_skipped_count Files/dirs skipped because the deployed target is a
---   pre-existing symlink
function M.copy_category(category, manifest, source_dir, target_dir, protected_paths, opts)

--- Check for conflicts before loading
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory
--- @param project_dir string|nil Project directory (for data conflict checking)
--- @return table conflicts Array of {category, file, path, [merge=true]}; merge=true means a
---   data-directory merge scenario, not an overwrite conflict
function M.check_conflicts(manifest, target_dir, project_dir)

--- Remove installed files on unload
--- @param installed_files table Array of absolute file paths to delete
--- @param installed_dirs table Array of absolute directory paths; only empty dirs are removed
--- @param opts table|nil { project_dir } -- bounds the symlinked-ancestor-directory walk; without
---   it, any path resolving through a symlink anywhere is skipped rather than deleted (fail-safe)
--- @return number removed_count
--- @return number skipped_count Paths left in place because they (or an ancestor) are a symlink
--- Dirs sorted deepest-first so nested empty dirs are cleaned before parents.
function M.remove_installed_files(installed_files, installed_dirs, opts)
```

---

## Loader Source Files

The extension loading system consists of 8 Lua source files:

| File | Description |
|------|-------------|
| `init.lua` | Public API. Provides `M.create(config)` returning a manager with `load()`, `unload()`, `reload()`, `resync_all()`, `compute_deploy_order()`, `wipe()`, `regenerate()`, `get_status()`, `list_available()`, `list_loaded()`, `get_details()`, `verify()`, `verify_all()`. Orchestrates all other modules. |
| `loader.lua` | File copy engine. `M.copy_category()` (descriptor-driven, covers all 13 category keys), `M.check_conflicts()`, `M.remove_installed_files()`, `M.load_syncprotect()`. Handles permission preservation, merge-copy, install-once, and symlink-guard semantics per `CATEGORY_DESCRIPTORS`. |
| `merge.lua` | Merge strategies. `generate_claudemd()`, `generate_opencode_json()`, `append_index_entries()`, `remove_index_entries_tracked()`, `remove_orphaned_index_entries()`, `merge_settings()`, `unmerge_settings()`, `inject_section()`, `remove_section()`. |
| `state.lua` | State tracking via `extensions.json`. `read()`, `write()`, `mark_loaded()`, `mark_unloaded()`, `is_loaded()`, `needs_update()`, `get_installed_files()`, `get_installed_dirs()`, `get_merged_sections()`, `get_data_skeleton_files()`, `list_loaded()`, `get_extension_info()`. |
| `manifest.lua` | Extension discovery and manifest validation. `get_extension()`, `list_extensions()`. Validates required fields (`name`, `version`, `description`) and known `provides` categories. |
| `config.lua` | Configuration presets. `M.create(opts)` for custom config, `M.claude()` preset for `.claude/` target, `M.opencode()` preset for `.opencode/` target. |
| `picker.lua` | Telescope picker UI. Provides the extension browser launched from the extension picker. Reads manager API from `init.lua` to show status, details, and trigger load/unload. |
| `verify.lua` | Post-load integrity checks. `verify_extension()` confirms all manifested files were actually copied to target, index entries exist in `index.json`, settings entries were merged, AND (declared-vs-deployed parity plus content-hash equality across every `provides.*` category, driven by `loader.CATEGORY_DESCRIPTORS`) that no deployed file's content has drifted from its source. Content-hash equality is **ownership-resolved**: `build_ownership_map()` determines, per deployed leaf, which active extension actually owns it (see "Cross-extension path ownership" below), and the hash comparison runs only for the owner -- a non-owner's declaration of the same path is reported as `overridden`, never as an error. `notify_results()` reports failures to the user. |

---

## Usage in init.lua

When `manager.load()` runs, it calls `loader_mod.copy_category` once per category, in a fixed
order:

```
1.  copy_category("agents", manifest, source, target, protected_paths, opts)
2.  copy_category("commands", manifest, source, target, protected_paths, opts)
3.  copy_category("rules", manifest, source, target, protected_paths, opts)
4.  copy_category("skills", manifest, source, target, protected_paths, opts)
5.  copy_category("context", manifest, source, target, protected_paths, opts)
6.  copy_category("scripts", manifest, source, target, protected_paths, opts)
7.  copy_category("hooks", manifest, source, target, protected_paths, opts)
8.  copy_category("docs", manifest, source, target, protected_paths, opts)
9.  copy_category("templates", manifest, source, target, protected_paths, opts)
10. copy_category("systemd", manifest, source, target, protected_paths, opts)
11. copy_category("root_files", manifest, source, target, protected_paths, opts)
12. copy_category("manifest", manifest, source, target, protected_paths, opts)
13. copy_category("data", manifest, source, target, protected_paths, opts)  -- opts.project_dir required
```

All operations run inside a `pcall` block. On failure, `remove_installed_files()` rolls back
all copied files and directories before the error is returned to the caller.

`manager.resync_all(opts)` force-resyncs (`opts.force = true`) every currently-active extension
in Kahn's-algorithm dependency order -- computed by `manager.compute_deploy_order(loaded)`, which
`resync_all` calls rather than inlining the sort itself -- reusing the same `manager.load` path
above rather than a separate loop. `manager.wipe(opts)` performs the full destructive sequence
(snapshot `settings.json`/`settings.local.json`/`.syncprotect`-listed paths -> `rm -rf target_dir`
-> `manager.regenerate`, which restores the snapshot as the merge base BEFORE re-running the load
loop above for every surviving active extension, then clears the snapshot staging directory).

---

## Cross-extension path ownership

Two active extensions may declare the same deployed path (e.g. both ship a file under
`provides.context`'s `contracts/` directory). `loader.copy_file` overwrites unconditionally, so
the extension that is LATER in `manager.compute_deploy_order`'s dependency-topological order is
the one whose copy actually survives on disk -- deploy order IS the cross-extension precedence
rule, with no separate `owner`/`precedence` manifest field.

Verification resolves ownership the same way: `verify.lua`'s `M.build_ownership_map(extensions,
target_dir, opts)` takes the already-deploy-ordered active set and, for every category
`loader.CATEGORY_DESCRIPTORS` covers, lets a later extension's leaf declaration overwrite an
earlier one's in the resulting `{rel_path -> {owner, source_path}}` map -- mirroring
`copy_file`'s own last-write-wins semantics exactly. Ownership is resolved strictly per leaf
`rel_path`, never per manifest directory entry: if extension A ships a file under a directory
that extension B also declares but does not itself ship, that file stays A-owned even though the
directory entry is declared by both.

`verify_manifest_category`'s hash comparison then runs ONLY for the resolved owner. A non-owner's
declaration of an overlapping path is reported in that category's `overridden` list (informational,
never an error, never affecting `passed`/`status`) instead of being hash-compared against a
source it does not actually own. `manager.verify_all` builds the ownership map once and shares it
across every per-extension `manager.verify` call; `manager.verify` also accepts a prebuilt map as
an optional third argument and otherwise builds its own, so a standalone single-extension verify
stays correct on its own. Omitting the map entirely (or a leaf with no recorded owner) preserves
the pre-ownership-resolution behavior exactly: every declared leaf is compared against its own
declarer's source.

**Rejected alternative**: a "matches-any-declarer" fallback (treat a hash match against ANY
declaring extension's source as clean, without resolving a single owner) was considered and
rejected, because a coincidental hash match against an unrelated extension's file would mask real
content drift -- the opposite of what this check exists to catch.

---

## Related Documentation

- [Extension Development Guide](extension-development.md) - How to create a new extension
- [Extension System Architecture](../../../docs/architecture/extension-system.md) - Full architecture overview
- [Deploy Orphan Detection](../patterns/deploy-orphan-detection.md) - Reverse-direction (deployed-but-undeclared) detection, exclusion contract
