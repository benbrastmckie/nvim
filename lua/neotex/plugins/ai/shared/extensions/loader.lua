-- neotex.plugins.ai.shared.extensions.loader
-- File copy engine for extension loading/unloading (parameterized)

local M = {}

-- Dependencies
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Load .syncprotect file from a project directory
--- Reads from project root ({project_dir}/.syncprotect), falling back to
--- the legacy location ({project_dir}/{base_dir}/.syncprotect).
--- Protected files will not be overwritten during extension load/reload.
--- @param project_dir string Project root directory
--- @param base_dir string|nil Base directory name for legacy fallback (".claude" or ".opencode")
--- @return table protected_paths Set of relative paths {[path] = true}
function M.load_syncprotect(project_dir, base_dir)
  local protected = {}

  -- Try project root first (canonical location)
  local filepath = project_dir .. "/.syncprotect"
  local file = io.open(filepath, "r")

  -- Fall back to legacy location inside base_dir
  if not file and base_dir then
    local legacy_path = project_dir .. "/" .. base_dir .. "/.syncprotect"
    file = io.open(legacy_path, "r")
  end

  if not file then
    return protected
  end

  for line in file:lines() do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    -- Skip empty lines and comments
    if line ~= "" and line:sub(1, 1) ~= "#" then
      protected[line] = true
    end
  end
  file:close()

  return protected
end

--- Copy a single file with directory creation
--- @param source_path string Source file path
--- @param target_path string Target file path
--- @param preserve_perms boolean Preserve execute permissions
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}
--- @param rel_path string|nil Relative path for syncprotect check
--- @return boolean success True if copy succeeded
--- @return boolean skipped True if file was skipped due to syncprotect
local function copy_file(source_path, target_path, preserve_perms, protected_paths, rel_path)
  -- Check .syncprotect: skip protected files
  if protected_paths and rel_path and protected_paths[rel_path] then
    return false, true
  end

  -- Ensure parent directory exists
  local parent_dir = vim.fn.fnamemodify(target_path, ":h")
  helpers.ensure_directory(parent_dir)

  -- Read source file
  local content = helpers.read_file(source_path)
  if not content then
    return false, false
  end

  -- Write to target
  local success = helpers.write_file(target_path, content)
  if not success then
    return false, false
  end

  -- Preserve permissions for shell scripts
  if preserve_perms and source_path:match("%.sh$") then
    helpers.copy_file_permissions(source_path, target_path)
  end

  return true, false
end

--- Recursively scan a directory for files
--- @param dir string Directory path
--- @return table files Array of relative file paths
local function scan_directory_recursive(dir)
  local files = {}

  if vim.fn.isdirectory(dir) ~= 1 then
    return files
  end

  -- Use glob to find all files
  local all_files = vim.fn.glob(dir .. "/**/*", false, true)
  for _, filepath in ipairs(all_files) do
    if vim.fn.isdirectory(filepath) ~= 1 then
      -- Get relative path from base directory
      local rel_path = filepath:sub(#dir + 2)
      table.insert(files, rel_path)
    end
  end

  -- Also check for top-level files (glob **/* doesn't match them)
  local top_files = vim.fn.glob(dir .. "/*", false, true)
  for _, filepath in ipairs(top_files) do
    if vim.fn.isdirectory(filepath) ~= 1 then
      local rel_path = filepath:sub(#dir + 2)
      -- Only add if not already found
      local found = false
      for _, f in ipairs(files) do
        if f == rel_path then
          found = true
          break
        end
      end
      if not found then
        table.insert(files, rel_path)
      end
    end
  end

  return files
end

--- Root files that are install-once: copied only when no project copy exists yet, never
--- overwritten on subsequent loads/reloads. Mirrors the OpenCode install-only pattern in
--- picker/operations/sync.lua's root_file_names handling (settings.json/opencode.json/
--- package.json there use the same "copy" vs "skip" distinction). Claude Code hardcodes the
--- `.claude/settings.json` / `.claude/settings.local.json` read paths, so these two files
--- cannot relocate out of `.claude/` -- install-once semantics (rather than a path move) is
--- the fix for the live clobber-on-reload bug: a hand-edited project settings file must
--- survive every future "Load Core" / extension reload.
local INSTALL_ONCE_ROOT_FILES = {
  ["settings.json"] = true,
  ["settings.local.json"] = true,
}

-- Exposed so manager.unload (init.lua) can also exclude these root files from
-- removal: without this, unload always deletes tracked installed_files first,
-- so a subsequent load (e.g. via manager.reload's unload-then-load) would find
-- the target absent and copy fresh regardless of the install-once guard above
-- -- the "live clobber-on-reload bug" this phase closes requires both halves.
M.INSTALL_ONCE_ROOT_FILES = INSTALL_ONCE_ROOT_FILES

--- Per-key carve-out from the install-once guard above: these keys are re-asserted from the
--- source store into an existing install-once root file on every load, while every other key
--- in that file keeps full install-once protection.
---
--- The guard above protects a target file's in-place edits, which is right for a personal
--- preference and wrong for a value the source store is meant to govern: because the file is
--- never re-copied once present, editing the template reaches only repos that do not have the
--- file yet. A key listed here is governed by the template instead, so changing it there and
--- reloading propagates it everywhere.
---
--- Keep this list minimal. Every entry removes a key from the protection the guard exists to
--- provide, so a key belongs here only when the source store is genuinely its owner.
local AUTHORITATIVE_ROOT_FILE_KEYS = {
  ["settings.local.json"] = { "outputStyle" },
}

M.AUTHORITATIVE_ROOT_FILE_KEYS = AUTHORITATIVE_ROOT_FILE_KEYS

--- Re-assert the declared authoritative keys from a source root file into an existing target.
---
--- Reads both as JSON, overwrites only the declared keys, and rewrites the target through
--- merge.write_json (jq pretty-print) so a hand-editable file stays readable. Every other key
--- in the target, and any key the template does not define, is left exactly as it was.
---
--- Fails soft in every degenerate case (unreadable file, malformed JSON, non-object root): the
--- install-once skip it replaces is already the conservative outcome, so a reconcile that
--- cannot run must leave the target untouched rather than risk truncating a settings file.
---
--- @param source_path string Source-store root file
--- @param target_path string Existing deployed root file
--- @param keys table List of key names the source store governs
--- @return boolean changed True when the target was rewritten
local function reconcile_authoritative_keys(source_path, target_path, keys)
  if vim.fn.filereadable(source_path) ~= 1 or vim.fn.filereadable(target_path) ~= 1 then
    return false
  end

  local ok_source, source = pcall(vim.json.decode, table.concat(vim.fn.readfile(source_path), "\n"))
  local ok_target, target = pcall(vim.json.decode, table.concat(vim.fn.readfile(target_path), "\n"))
  if not ok_source or not ok_target or type(source) ~= "table" or type(target) ~= "table" then
    return false
  end

  local changed = false
  for _, key in ipairs(keys) do
    -- A key the template does not define is not governed; absence is not an instruction
    -- to delete the target's value.
    if source[key] ~= nil and not vim.deep_equal(target[key], source[key]) then
      target[key] = source[key]
      changed = true
    end
  end

  if not changed then
    return false
  end

  local merge = require("neotex.plugins.ai.shared.extensions.merge")
  return merge.write_json(target_path, target) and true or false
end

--- Category descriptor table: the single source of truth for how every `provides.*` category
--- (plus the two non-`provides`-keyed special cases, `manifest` and `data`) is copied. Collapses
--- what used to be 11 near-identical `copy_*` functions (symlink guard present in only 2 of 11,
--- `preserve_perms` hardcoded per call site, return arity inconsistent) into one descriptor-
--- driven copier (`M.copy_category` below), so the symlink guard and permission handling hold
--- for every category by construction rather than by each function separately remembering to
--- implement them.
---
--- Fields:
---   source_subdir        Directory under the extension source (`source_dir`) entries are read
---                         from. `nil`/absent for the two special-cased entries (`manifest`,
---                         handled entirely inline; and any future single-file category).
---   target_subdir         Directory under `target_dir` entries are written to. `""` means
---                         entries land directly at `target_dir`'s root (root_files).
---   list_key              Key into `manifest.provides` holding the array of declared entries.
---   entry_kind             "file" (flat file per entry; agents/commands/rules/scripts/hooks/
---                         systemd/templates/root_files), "dir" (each entry is itself a
---                         directory, recursively copied; skills), or "file_or_dir" (an entry
---                         may be either; context/docs).
---   preserve_perms        "always" (scripts/hooks: every copied file keeps its execute bit),
---                         "sh_only" (agents/commands/rules/skills: only `.sh` entries do), or
---                         "none" (everything else). Mirrors today's effective behavior exactly
---                         -- see the historical per-category `preserve_perms` call-site values
---                         this table replaces.
---   symlink_guard          When true, a pre-existing symlink at the deployed target is left
---                         alone rather than written through (see `M.remove_installed_files`'s
---                         matching ownership invariant). True for exactly the categories the
---                         former `copy_simple_files` (agents/commands/rules) and
---                         `copy_skill_dirs` (skills) functions guarded -- "2 of 11" functions,
---                         now 4 category rows sharing the same two behaviors.
---   install_once           Optional set `{[entry_name] = true}`; an entry present here is
---                         skipped (counted, not copied) whenever a target copy already exists.
---                         Only `root_files` uses this (`INSTALL_ONCE_ROOT_FILES`).
---   authoritative_keys     Optional map `{[entry_name] = {"key", ...}}`, meaningful only
---                         alongside `install_once`. On a skip, those keys are re-asserted
---                         from the source into the existing target JSON, so the source store
---                         governs them while the rest of the file stays install-once
---                         protected. Only `root_files` uses this
---                         (`AUTHORITATIVE_ROOT_FILE_KEYS`).
---   merge_copy_only         True for `data`: an entry already present at the target is skipped
---                         rather than overwritten (merge-copy semantics preserving user data).
---   target_is_project_root  True for `data`: entries land under `project_dir`, not `target_dir`
---                         (data directories such as `.claude/memory/` are addressed relative to
---                         the project root, mirroring the historical `copy_data_dirs` contract).
---   single_file             True for `manifest`: not a `provides.*`-keyed list at all -- one
---                         fixed source file copied to one fixed target path.
---   self_load_skip           True for `manifest`: skip the copy when source and target resolve
---                         (via `vim.uv.fs_realpath`) to the same file (the home-repo case).
local CATEGORY_DESCRIPTORS = {
  agents = {
    source_subdir = "agents", target_subdir = "agents", list_key = "agents",
    entry_kind = "file", preserve_perms = "sh_only", symlink_guard = true,
  },
  commands = {
    source_subdir = "commands", target_subdir = "commands", list_key = "commands",
    entry_kind = "file", preserve_perms = "sh_only", symlink_guard = true,
  },
  rules = {
    source_subdir = "rules", target_subdir = "rules", list_key = "rules",
    entry_kind = "file", preserve_perms = "sh_only", symlink_guard = true,
  },
  skills = {
    source_subdir = "skills", target_subdir = "skills", list_key = "skills",
    entry_kind = "dir", preserve_perms = "sh_only", symlink_guard = true,
  },
  context = {
    source_subdir = "context", target_subdir = "context", list_key = "context",
    entry_kind = "file_or_dir", preserve_perms = "none",
  },
  scripts = {
    source_subdir = "scripts", target_subdir = "scripts", list_key = "scripts",
    entry_kind = "file", preserve_perms = "always",
  },
  hooks = {
    source_subdir = "hooks", target_subdir = "hooks", list_key = "hooks",
    entry_kind = "file", preserve_perms = "always",
  },
  docs = {
    source_subdir = "docs", target_subdir = "docs", list_key = "docs",
    entry_kind = "file_or_dir", preserve_perms = "none",
  },
  templates = {
    source_subdir = "templates", target_subdir = "templates", list_key = "templates",
    entry_kind = "file", preserve_perms = "none",
  },
  systemd = {
    source_subdir = "systemd", target_subdir = "systemd", list_key = "systemd",
    entry_kind = "file", preserve_perms = "none",
  },
  root_files = {
    source_subdir = "root-files", target_subdir = "", list_key = "root_files",
    entry_kind = "file", preserve_perms = "none", install_once = INSTALL_ONCE_ROOT_FILES,
    authoritative_keys = AUTHORITATIVE_ROOT_FILE_KEYS,
  },
  manifest = {
    single_file = true, self_load_skip = true, preserve_perms = "none",
  },
  data = {
    source_subdir = "data", list_key = "data", entry_kind = "dir",
    preserve_perms = "none", merge_copy_only = true, target_is_project_root = true,
  },
}

M.CATEGORY_DESCRIPTORS = CATEGORY_DESCRIPTORS

--- Resolve whether a given entry's execute permissions should be preserved, per the
--- descriptor's `preserve_perms` mode. Mirrors each historical call site's inline check exactly.
--- @param mode string "always" | "sh_only" | "none"
--- @param filename string Entry filename (basename or relative path) being copied
--- @return boolean|string preserve Truthy iff permissions should be preserved
local function resolve_preserve_perms(mode, filename)
  if mode == "always" then
    return true
  elseif mode == "sh_only" then
    return filename:match("%.sh$")
  end
  return false
end

--- Copy the `manifest` single-file special case (manifest.json -> extensions/{name}/manifest.json).
local function copy_manifest_entry(descriptor, source_dir, target_dir, protected_paths, opts)
  local copied_files, created_dirs, skipped_count, symlink_skipped_count = {}, {}, 0, 0
  local extension_name = opts.extension_name

  local source_path = source_dir .. "/manifest.json"
  local target_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"
  local rel_path = "extensions/" .. extension_name .. "/manifest.json"

  if descriptor.self_load_skip then
    local source_real = vim.uv.fs_realpath(source_path)
    local target_real = vim.uv.fs_realpath(target_path)
    if source_real and target_real and source_real == target_real then
      return copied_files, created_dirs, skipped_count, symlink_skipped_count
    end
  end

  if vim.fn.filereadable(source_path) ~= 1 then
    return copied_files, created_dirs, skipped_count, symlink_skipped_count
  end

  local ext_dir = target_dir .. "/extensions/" .. extension_name
  if vim.fn.isdirectory(ext_dir) ~= 1 then
    helpers.ensure_directory(ext_dir)
    table.insert(created_dirs, ext_dir)
  end

  local ok, skipped = copy_file(source_path, target_path, false, protected_paths, rel_path)
  if skipped then
    skipped_count = skipped_count + 1
  elseif ok then
    table.insert(copied_files, target_path)
  end

  return copied_files, created_dirs, skipped_count, symlink_skipped_count
end

--- Copy the `data` merge-copy, project-root-targeted special case.
local function copy_data_entry(descriptor, manifest, source_dir, protected_paths, opts)
  local copied_files, created_dirs, skipped_count, symlink_skipped_count = {}, {}, 0, 0

  if not manifest.provides or not manifest.provides[descriptor.list_key] then
    return copied_files, created_dirs, skipped_count, symlink_skipped_count
  end

  local project_dir = opts.project_dir
  local source_category_dir = source_dir .. "/" .. descriptor.source_subdir

  for _, entry_name in ipairs(manifest.provides[descriptor.list_key]) do
    local source_entry_dir = source_category_dir .. "/" .. entry_name
    local target_entry_dir = project_dir .. "/" .. entry_name

    if vim.fn.isdirectory(source_entry_dir) == 1 then
      if vim.fn.isdirectory(target_entry_dir) ~= 1 then
        helpers.ensure_directory(target_entry_dir)
        table.insert(created_dirs, target_entry_dir)
      end

      local files = scan_directory_recursive(source_entry_dir)
      for _, file_rel in ipairs(files) do
        local source_path = source_entry_dir .. "/" .. file_rel
        local target_path = target_entry_dir .. "/" .. file_rel
        local rel_path = descriptor.list_key .. "/" .. entry_name .. "/" .. file_rel

        if protected_paths and protected_paths[rel_path] then
          skipped_count = skipped_count + 1
        elseif vim.fn.filereadable(target_path) ~= 1 then
          -- Merge-copy semantics: only copy if target doesn't already exist (preserve user data)
          local subdir = vim.fn.fnamemodify(target_path, ":h")
          if vim.fn.isdirectory(subdir) ~= 1 then
            helpers.ensure_directory(subdir)
            table.insert(created_dirs, subdir)
          end
          local content = helpers.read_file(source_path)
          if content then
            if helpers.write_file(target_path, content) then
              table.insert(copied_files, target_path)
            end
          end
        else
          skipped_count = skipped_count + 1
        end
      end
    end
  end

  return copied_files, created_dirs, skipped_count, symlink_skipped_count
end

--- Copy one `provides.*` category (or the `manifest`/`data` special cases) per its descriptor.
--- The single copier every category flows through -- the symlink guard and permission handling
--- hold for every category by construction, since they are descriptor-driven rather than each
--- category separately reimplementing them.
--- @param category string Category name; must be a key of `M.CATEGORY_DESCRIPTORS`
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}
--- @param opts table|nil { project_dir, extension_name, agents_subdir } -- required per category:
---   `data` needs `project_dir`; `manifest` needs `extension_name`; `agents` uses
---   `agents_subdir` if given (falls back to the descriptor's own "agents" target_subdir).
--- @return table copied_files
--- @return table created_dirs
--- @return number skipped_count Files skipped due to .syncprotect (or install-once/merge-copy)
--- @return number symlink_skipped_count Files/dirs skipped because the deployed target is a
---   pre-existing symlink
function M.copy_category(category, manifest, source_dir, target_dir, protected_paths, opts)
  opts = opts or {}
  local descriptor = CATEGORY_DESCRIPTORS[category]
  if not descriptor then
    error("loader.copy_category: unknown category '" .. tostring(category) .. "'")
  end

  if descriptor.single_file then
    return copy_manifest_entry(descriptor, source_dir, target_dir, protected_paths, opts)
  end

  if descriptor.target_is_project_root and descriptor.merge_copy_only then
    return copy_data_entry(descriptor, manifest, source_dir, protected_paths, opts)
  end

  local copied_files, created_dirs, skipped_count, symlink_skipped_count = {}, {}, 0, 0

  if not manifest.provides or not manifest.provides[descriptor.list_key] then
    return copied_files, created_dirs, skipped_count, symlink_skipped_count
  end

  -- Resolve the target category directory name. "agents" is the one category whose target
  -- subdir varies by config (agents_subdir, e.g. "agent/subagents" for OpenCode); every other
  -- category uses its fixed descriptor.target_subdir. "" (root_files) means "target_dir itself".
  local target_category_name = descriptor.target_subdir
  if category == "agents" and opts.agents_subdir then
    target_category_name = opts.agents_subdir
  end
  local target_category_dir = target_category_name == "" and target_dir
    or (target_dir .. "/" .. target_category_name)

  if target_category_name ~= "" then
    if vim.fn.isdirectory(target_category_dir) ~= 1 then
      helpers.ensure_directory(target_category_dir)
      table.insert(created_dirs, target_category_dir)
    end
  end

  local source_category_dir = source_dir .. "/" .. descriptor.source_subdir

  for _, entry_name in ipairs(manifest.provides[descriptor.list_key]) do
    if descriptor.entry_kind == "dir" then
      -- skills: each entry is a directory, recursively copied, symlink-guarded as a whole.
      local source_entry_dir = source_category_dir .. "/" .. entry_name
      local target_entry_dir = target_category_dir .. "/" .. entry_name

      if vim.fn.isdirectory(source_entry_dir) == 1 then
        if descriptor.symlink_guard and vim.fn.getftype(target_entry_dir) == "link" then
          symlink_skipped_count = symlink_skipped_count + 1
        else
          if vim.fn.isdirectory(target_entry_dir) ~= 1 then
            helpers.ensure_directory(target_entry_dir)
            table.insert(created_dirs, target_entry_dir)
          end

          local files = scan_directory_recursive(source_entry_dir)
          for _, file_rel in ipairs(files) do
            local source_path = source_entry_dir .. "/" .. file_rel
            local target_path = target_entry_dir .. "/" .. file_rel
            local preserve = resolve_preserve_perms(descriptor.preserve_perms, file_rel)
            local rel_path = target_category_name .. "/" .. entry_name .. "/" .. file_rel

            local ok, skipped = copy_file(source_path, target_path, preserve, protected_paths, rel_path)
            if skipped then
              skipped_count = skipped_count + 1
            elseif ok then
              table.insert(copied_files, target_path)
            end
          end
        end
      end
    elseif descriptor.entry_kind == "file_or_dir" then
      -- context/docs: an entry may itself be a directory (recursive copy) or a flat file.
      local source_entry_path = source_category_dir .. "/" .. entry_name
      local target_entry_path = target_category_dir .. "/" .. entry_name

      if vim.fn.isdirectory(source_entry_path) == 1 then
        if vim.fn.isdirectory(target_entry_path) ~= 1 then
          helpers.ensure_directory(target_entry_path)
          table.insert(created_dirs, target_entry_path)
        end

        local files = scan_directory_recursive(source_entry_path)
        for _, file_rel in ipairs(files) do
          local source_path = source_entry_path .. "/" .. file_rel
          local target_path = target_entry_path .. "/" .. file_rel
          local rel_path = target_category_name .. "/" .. entry_name .. "/" .. file_rel

          local ok, skipped = copy_file(source_path, target_path, false, protected_paths, rel_path)
          if skipped then
            skipped_count = skipped_count + 1
          elseif ok then
            table.insert(copied_files, target_path)
          end
        end
      elseif vim.fn.filereadable(source_entry_path) == 1 then
        local rel_path = target_category_name .. "/" .. entry_name
        local ok, skipped = copy_file(source_entry_path, target_entry_path, false, protected_paths, rel_path)
        if skipped then
          skipped_count = skipped_count + 1
        elseif ok then
          table.insert(copied_files, target_entry_path)
        end
      end
    else
      -- "file": flat per-entry copy (agents/commands/rules/scripts/hooks/systemd/templates/
      -- root_files). rel_path for root_files (target_category_name == "") is the bare filename,
      -- matching the historical copy_root_files behavior exactly.
      local source_path = source_category_dir .. "/" .. entry_name
      local target_path = target_category_dir .. "/" .. entry_name
      local rel_path = target_category_name == "" and entry_name or (target_category_name .. "/" .. entry_name)

      if descriptor.install_once and descriptor.install_once[entry_name] and vim.fn.filereadable(target_path) == 1 then
        -- Still install-once for the file as a whole, but any key the source store declares
        -- authoritative is re-asserted here, so a template change reaches repos that already
        -- have the file. Counted as a skip either way: the file was not replaced.
        local authoritative = descriptor.authoritative_keys and descriptor.authoritative_keys[entry_name]
        if authoritative then
          reconcile_authoritative_keys(source_path, target_path, authoritative)
        end
        skipped_count = skipped_count + 1
      elseif vim.fn.filereadable(source_path) == 1 then
        if descriptor.symlink_guard and vim.fn.getftype(target_path) == "link" then
          symlink_skipped_count = symlink_skipped_count + 1
        else
          local preserve = resolve_preserve_perms(descriptor.preserve_perms, entry_name)
          local ok, skipped = copy_file(source_path, target_path, preserve, protected_paths, rel_path)
          if skipped then
            skipped_count = skipped_count + 1
          elseif ok then
            table.insert(copied_files, target_path)
          end
        end
      end
    end
  end

  return copied_files, created_dirs, skipped_count, symlink_skipped_count
end

--- Check for conflicts before loading
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory
--- @param project_dir string|nil Project directory (for data conflict checking)
--- @return table conflicts Array of conflict descriptions
function M.check_conflicts(manifest, target_dir, project_dir)
  local conflicts = {}

  if not manifest.provides then
    return conflicts
  end

  -- Check each category
  local categories = { "agents", "commands", "rules", "scripts", "hooks", "docs", "templates", "systemd" }
  for _, category in ipairs(categories) do
    if manifest.provides[category] then
      local target_category_dir = target_dir .. "/" .. category
      for _, filename in ipairs(manifest.provides[category]) do
        local target_path = target_category_dir .. "/" .. filename
        if vim.fn.filereadable(target_path) == 1 then
          table.insert(conflicts, {
            category = category,
            file = filename,
            path = target_path,
          })
        end
      end
    end
  end

  -- Check skills
  if manifest.provides.skills then
    local target_skills_dir = target_dir .. "/skills"
    for _, skill_name in ipairs(manifest.provides.skills) do
      local target_skill_dir = target_skills_dir .. "/" .. skill_name
      if vim.fn.isdirectory(target_skill_dir) == 1 then
        table.insert(conflicts, {
          category = "skills",
          file = skill_name,
          path = target_skill_dir,
        })
      end
    end
  end

  -- Check data directories (only if project_dir provided)
  -- Note: data directories use merge-copy, so existing files are not conflicts
  -- We only check if the directory already exists with content
  if manifest.provides.data and project_dir then
    for _, data_name in ipairs(manifest.provides.data) do
      local target_data_dir = project_dir .. "/" .. data_name
      if vim.fn.isdirectory(target_data_dir) == 1 then
        local contents = vim.fn.readdir(target_data_dir)
        if #contents > 0 then
          -- Directory exists with content - this is informational, not a hard conflict
          -- since we use merge-copy semantics
          table.insert(conflicts, {
            category = "data",
            file = data_name,
            path = target_data_dir,
            merge = true, -- Flag indicating this is a merge scenario, not overwrite
          })
        end
      end
    end
  end

  return conflicts
end

--- Find the first symlinked ancestor directory of a path, bounded below root.
--- Walks upward from the path's parent directory. Stops without inspecting
--- `root` itself (or anything above it): the walk only ever tests strict
--- descendants of `root`. This bound is load-bearing -- an unbounded walk
--- would find a symlinked project root (a common stow/dotfiles setup) and
--- classify every deployed file as symlink-descended, silently turning
--- unload into a no-op.
--- @param path string Path whose ancestor directories are inspected
--- @param root string Directory the walk must not reach or cross
--- @return string|nil ancestor The first symlinked ancestor found, or nil
local function find_symlinked_ancestor(path, root)
  local root_norm = root:gsub("/+$", "")
  local current = vim.fn.fnamemodify(path, ":h")

  while current ~= root_norm and current:sub(1, #root_norm + 1) == root_norm .. "/" do
    if vim.fn.getftype(current) == "link" then
      return current
    end
    local parent = vim.fn.fnamemodify(current, ":h")
    if parent == current then
      -- Filesystem-root guard: stop rather than loop forever.
      return nil
    end
    current = parent
  end

  return nil
end

--- Remove installed files.
---
--- Ownership invariant: this copy engine owns only paths it created as
--- regular files. Symlinked deployed paths -- whether the deployed path
--- itself is a symlink, or a plain file reached through a symlinked
--- ancestor directory -- belong to install-extension.sh and are never
--- deleted here. This distinction matters because of POSIX unlink()
--- semantics: deleting a symlink-to-file removes only the link (safe), but
--- deleting a plain file reached through a symlinked ancestor directory
--- destroys the real target, since only the final path component's own
--- symlink-ness is consulted during deletion and ancestor-directory
--- symlinks are followed transparently by path resolution.
--- @param installed_files table Array of file paths to remove
--- @param installed_dirs table Array of directory paths to remove
--- @param opts table|nil Options: { project_dir = string|nil }. When
---   `project_dir` is set, the ancestor walk is bounded strictly below it.
---   When absent, the walk cannot be safely bounded, so any path involving
---   a symlink anywhere (`vim.fn.resolve(path) ~= path`) is skipped rather
---   than walked -- refusing to delete is always the safe direction.
--- @return number removed_count Number of files removed
--- @return number skipped_count Number of files skipped for symlink reasons
function M.remove_installed_files(installed_files, installed_dirs, opts)
  opts = opts or {}
  local removed_count = 0
  local skipped_count = 0

  -- Remove files first
  for _, filepath in ipairs(installed_files) do
    if vim.fn.filereadable(filepath) == 1 then
      local is_symlink = vim.fn.getftype(filepath) == "link"
      local ancestor_symlinked = false

      if not is_symlink then
        if opts.project_dir then
          ancestor_symlinked = find_symlinked_ancestor(filepath, opts.project_dir) ~= nil
        else
          -- Fail-safe: no project_dir to bound the walk, so skip anything
          -- symlink-involved rather than deleting through an unbounded walk.
          ancestor_symlinked = vim.fn.resolve(filepath) ~= filepath
        end
      end

      if is_symlink or ancestor_symlinked then
        skipped_count = skipped_count + 1
      else
        vim.fn.delete(filepath)
        removed_count = removed_count + 1
      end
    end
  end

  -- Remove directories (in reverse order to handle nested dirs).
  -- vim.fn.readdir() on a symlinked directory reports the target
  -- directory's contents, so a non-empty result here already prevents
  -- removal -- no additional symlink check is needed in this loop.
  local sorted_dirs = {}
  for _, dir in ipairs(installed_dirs) do
    table.insert(sorted_dirs, dir)
  end
  -- Sort by length descending (deepest first)
  table.sort(sorted_dirs, function(a, b) return #a > #b end)

  for _, dir in ipairs(sorted_dirs) do
    -- Only remove if empty
    if vim.fn.isdirectory(dir) == 1 then
      local contents = vim.fn.readdir(dir)
      if #contents == 0 then
        vim.fn.delete(dir, "d")
      end
    end
  end

  return removed_count, skipped_count
end

return M
