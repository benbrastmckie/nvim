-- neotex.plugins.ai.shared.extensions
-- Shared extension management public API (parameterized)

local M = {}

-- Dependencies
local manifest_mod = require("neotex.plugins.ai.shared.extensions.manifest")
local state_mod = require("neotex.plugins.ai.shared.extensions.state")
local loader_mod = require("neotex.plugins.ai.shared.extensions.loader")
local merge_mod = require("neotex.plugins.ai.shared.extensions.merge")
local verify_mod = require("neotex.plugins.ai.shared.extensions.verify")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Convert absolute path to relative (from project_dir)
--- @param abs_path string Absolute file path
--- @param project_dir string Project directory
--- @return string rel_path Relative path
local function to_relative_path(abs_path, project_dir)
  if abs_path:sub(1, #project_dir) == project_dir then
    local rel = abs_path:sub(#project_dir + 2)  -- +2 to skip trailing /
    return rel
  end
  return abs_path
end

--- Convert array of absolute paths to relative paths
--- @param abs_paths table Array of absolute paths
--- @param project_dir string Project directory
--- @return table rel_paths Array of relative paths
local function paths_to_relative(abs_paths, project_dir)
  local rel_paths = {}
  for _, abs_path in ipairs(abs_paths) do
    table.insert(rel_paths, to_relative_path(abs_path, project_dir))
  end
  return rel_paths
end

--- Read file contents as string
--- @param filepath string Path to file
--- @return string|nil content File contents or nil
local function read_file_string(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

--- Read JSON file
--- @param filepath string Path to JSON file
--- @return table|nil data Parsed JSON or nil
local function read_json(filepath)
  local content = read_file_string(filepath)
  if not content then
    return nil
  end
  local ok, result = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  return result
end

--- Process merge targets for an extension
--- @param ext_manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param project_dir string Target project directory
--- @param config table Extension system configuration
--- @return table merged_sections Tracking data for unmerge
local function process_merge_targets(ext_manifest, source_dir, project_dir, config)
  local merged_sections = {}

  if not ext_manifest.merge_targets then
    return merged_sections
  end

  local target_dir = project_dir .. "/" .. config.base_dir

  -- Process config markdown section injection (CLAUDE.md or OPENCODE.md)
  local merge_key = config.merge_target_key
  if ext_manifest.merge_targets[merge_key] then
    local mt_config = ext_manifest.merge_targets[merge_key]
    local source_path = source_dir .. "/" .. mt_config.source
    local target_path = project_dir .. "/" .. mt_config.target

    local section_content = read_file_string(source_path)
    if section_content then
      local success, tracked = merge_mod.inject_section(
        target_path,
        section_content,
        mt_config.section_id
      )
      if success then
        merged_sections[merge_key] = tracked
      end
    end
  end

  -- Process settings merge
  if ext_manifest.merge_targets.settings then
    local mt_config = ext_manifest.merge_targets.settings
    local source_path = source_dir .. "/" .. mt_config.source
    local target_path = project_dir .. "/" .. mt_config.target

    local fragment = read_json(source_path)
    if fragment then
      local success, tracked = merge_mod.merge_settings(target_path, fragment)
      if success then
        merged_sections.settings = tracked
      end
    end
  end

  -- Process index.json entries
  if ext_manifest.merge_targets.index then
    local mt_config = ext_manifest.merge_targets.index
    local source_path = source_dir .. "/" .. mt_config.source
    local target_path = project_dir .. "/" .. mt_config.target

    local entries_data = read_json(source_path)
    if entries_data then
      -- Handle both {entries: [...]} object format and bare [...] array format
      local entries = entries_data.entries or (vim.isarray(entries_data) and entries_data) or nil
      if entries then
        local success, tracked = merge_mod.append_index_entries(target_path, entries)
        if success then
          merged_sections.index = tracked
        end
      end
    end
  end

  -- Process opencode.json agent definitions (only for OpenCode config)
  if config.merge_target_key == "opencode_md" and ext_manifest.merge_targets.opencode_json then
    local mt_config = ext_manifest.merge_targets.opencode_json
    local source_path = source_dir .. "/" .. mt_config.source
    -- opencode.json is at project root, not inside base_dir
    local target_path = project_dir .. "/" .. mt_config.target

    local fragment = read_json(source_path)
    if fragment then
      local success, tracked = merge_mod.merge_opencode_agents(target_path, fragment)
      if success then
        merged_sections.opencode_json = tracked
      end
    end
  end

  return merged_sections
end

--- Reverse merge operations for an extension
--- @param ext_manifest table Extension manifest
--- @param merged_sections table Tracking data from process_merge_targets
--- @param project_dir string Target project directory
--- @param config table Extension system configuration
local function reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)
  if not ext_manifest or not merged_sections then
    return
  end

  local merge_key = config.merge_target_key

  -- Reverse config markdown section
  if merged_sections[merge_key] and ext_manifest.merge_targets and ext_manifest.merge_targets[merge_key] then
    local mt_config = ext_manifest.merge_targets[merge_key]
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.remove_section(target_path, mt_config.section_id)
  end

  -- Reverse settings merge
  if merged_sections.settings and ext_manifest.merge_targets and ext_manifest.merge_targets.settings then
    local mt_config = ext_manifest.merge_targets.settings
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.unmerge_settings(target_path, merged_sections.settings)
  end

  -- Reverse index entries
  if merged_sections.index and ext_manifest.merge_targets and ext_manifest.merge_targets.index then
    local mt_config = ext_manifest.merge_targets.index
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.remove_index_entries_tracked(target_path, merged_sections.index)
  end

  -- Reverse opencode.json agent definitions (only for OpenCode config)
  if config.merge_target_key == "opencode_md" and merged_sections.opencode_json and ext_manifest.merge_targets and ext_manifest.merge_targets.opencode_json then
    local mt_config = ext_manifest.merge_targets.opencode_json
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.unmerge_opencode_agents(target_path, merged_sections.opencode_json)
  end
end

--- Create an extension manager instance with the given configuration
--- @param config table Extension system configuration from config.lua
--- @return table manager Extension manager with load, unload, reload, etc.
function M.create(config)
  local manager = {}

  --- Load an extension into the current project
  --- @param extension_name string Extension name
  --- @param opts table|nil Options {confirm = true, project_dir = nil, force = false}
  --- @return boolean success True if load succeeded
  --- @return string|nil error Error message if load failed
  function manager.load(extension_name, opts)
    opts = opts or {}
    local confirm = opts.confirm ~= false  -- Default to true
    local project_dir = opts.project_dir or vim.fn.getcwd()
    local target_dir = project_dir .. "/" .. config.base_dir

    -- Self-loading guard: prevent loading extensions into the global source directory
    -- This would contaminate the source and cause extension artifacts to leak into core sync
    local global_dir = vim.fn.expand("~/.config/nvim")
    if project_dir == global_dir and not opts.force then
      return false, "Cannot load extensions into source directory (~/.config/nvim). " ..
        "Extensions loaded here would leak into core sync for all projects. " ..
        "Use opts.force = true to bypass this check (not recommended)."
    end

    -- Log warning if force is used
    if project_dir == global_dir and opts.force then
      vim.schedule(function()
        vim.notify(
          "WARNING: Loading extension into source directory with force=true. " ..
          "This may cause extension artifacts to leak into core sync.",
          vim.log.levels.WARN
        )
      end)
    end

    -- Find extension
    local extension = manifest_mod.get_extension(extension_name, config)
    if not extension then
      return false, "Extension not found: " .. extension_name
    end

    local ext_manifest = extension.manifest
    local source_dir = extension.path

    -- Check if already loaded
    local state = state_mod.read(project_dir, config)
    if state_mod.is_loaded(state, extension_name) then
      return false, "Extension already loaded: " .. extension_name
    end

    -- Dependency resolution: auto-load declared dependencies before proceeding
    local loading_stack = opts._loading_stack or {}
    local max_depth = 5

    -- Circular dependency detection
    for _, stack_name in ipairs(loading_stack) do
      if stack_name == extension_name then
        local cycle = table.concat(loading_stack, " -> ") .. " -> " .. extension_name
        return false, "Circular dependency detected: " .. cycle
      end
    end

    -- Depth limit check
    if #loading_stack >= max_depth then
      return false, string.format(
        "Dependency depth limit (%d) exceeded while loading '%s'",
        max_depth, extension_name
      )
    end

    -- Resolve dependencies
    local deps = ext_manifest.dependencies or {}
    local deps_to_load = {}
    for _, dep_name in ipairs(deps) do
      -- Re-read state each iteration (previous dep may have changed it)
      state = state_mod.read(project_dir, config)
      if not state_mod.is_loaded(state, dep_name) then
        table.insert(deps_to_load, dep_name)
      end
    end

    -- Load unloaded dependencies recursively
    if #deps_to_load > 0 then
      local child_stack = vim.list_extend({}, loading_stack)
      table.insert(child_stack, extension_name)

      for _, dep_name in ipairs(deps_to_load) do
        local dep_ok, dep_err = manager.load(dep_name, {
          confirm = false,  -- dependencies load silently
          project_dir = project_dir,
          force = opts.force,
          _loading_stack = child_stack,
        })
        if not dep_ok then
          return false, string.format(
            "Failed to load dependency '%s' for '%s': %s",
            dep_name, extension_name, dep_err or "unknown error"
          )
        end
      end
    end

    -- Check for conflicts (used in confirmation dialog)
    local conflicts = loader_mod.check_conflicts(ext_manifest, target_dir, project_dir)

    -- Single merged confirmation dialog
    if confirm then
      local provides_summary = ""
      if ext_manifest.provides then
        for category, files in pairs(ext_manifest.provides) do
          if type(files) == "table" and #files > 0 then
            provides_summary = provides_summary .. "  " .. category .. ": " .. #files .. "\n"
          end
        end
      end

      -- Include conflict info in the message if conflicts exist
      local conflict_note = ""
      local overwrite_count = 0
      local merge_count = 0
      for _, conflict in ipairs(conflicts) do
        if conflict.merge then
          merge_count = merge_count + 1
        else
          overwrite_count = overwrite_count + 1
        end
      end
      if overwrite_count > 0 then
        conflict_note = string.format("\n\nNote: %d existing file(s) will be overwritten.", overwrite_count)
      end
      if merge_count > 0 then
        conflict_note = conflict_note .. string.format("\n%d data director%s will be merged (existing files preserved).",
          merge_count, merge_count > 1 and "ies" or "y")
      end

      -- Include dependency info in message
      local dep_note = ""
      if #deps_to_load > 0 then
        dep_note = "\nDependencies loaded: " .. table.concat(deps_to_load, ", ")
      elseif #deps > 0 then
        dep_note = "\nDependencies (already loaded): " .. table.concat(deps, ", ")
      end

      local message = string.format(
        "Load extension '%s' v%s?\n\n%s\n%s%s%s",
        extension_name,
        ext_manifest.version,
        ext_manifest.description,
        provides_summary ~= "" and "\nFiles to install:\n" .. provides_summary or "",
        dep_note,
        conflict_note
      )

      local choice = vim.fn.confirm(message, "&Load\n&Cancel", 2)
      if choice ~= 1 then
        helpers.notify("Extension load cancelled", "INFO")
        return false, "Cancelled by user"
      end
    end

    -- Ensure base directory exists
    helpers.ensure_directory(target_dir)

    -- Track all installed files, directories, merged sections, and data skeleton files
    -- Declared before pcall so rollback can access them
    local all_files = {}
    local all_dirs = {}
    local merged_sections = {}
    local data_skeleton_files = {}

    -- Wrap copy+merge in pcall for atomic rollback on failure
    local load_ok, load_err = pcall(function()
      -- Copy agents (use configured agents_subdir for target path)
      local files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "agents", ".md", config.agents_subdir)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)

      -- Copy commands
      files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "commands", ".md")
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)

      -- Copy rules
      files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "rules", ".md")
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)

      -- Copy skills
      files, dirs = loader_mod.copy_skill_dirs(ext_manifest, source_dir, target_dir)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)

      -- Copy context
      files, dirs = loader_mod.copy_context_dirs(ext_manifest, source_dir, target_dir)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)

      -- Copy scripts
      files, dirs = loader_mod.copy_scripts(ext_manifest, source_dir, target_dir)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)

      -- Copy data directories (merge-copy semantics - preserves existing files)
      -- Data skeleton files are tracked separately for safe unload
      local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, project_dir)
      vim.list_extend(all_dirs, data_dirs)
      -- Track data files separately - they go into data_skeleton_files, not all_files
      -- This allows unload to only remove skeleton files, not user-created data
      for _, f in ipairs(data_files) do
        table.insert(data_skeleton_files, f)
      end

      -- Pre-load cleanup: remove stale index entries before appending fresh ones.
      -- Excludes the current extension from valid prefixes so its stale entries
      -- are removed. Fresh entries are then added by process_merge_targets()
      -- and properly tracked for future unload.
      local index_path = target_dir .. "/context/index.json"
      if vim.fn.filereadable(index_path) == 1 then
        local updated_state = state_mod.read(project_dir, config)
        local loaded_names = state_mod.list_loaded(updated_state)
        -- Do NOT include the current extension -- its stale entries must be
        -- removed so fresh entries from process_merge_targets() are added
        -- and tracked (append_index_entries deduplicates, so stale entries
        -- would prevent tracking and survive unload)
        local valid_prefixes = {}
        for _, ext_name in ipairs(loaded_names) do
          local ext = manifest_mod.get_extension(ext_name, config)
          if ext and ext.manifest and ext.manifest.provides and ext.manifest.provides.context then
            for _, prefix in ipairs(ext.manifest.provides.context) do
              table.insert(valid_prefixes, prefix)
            end
          end
        end
        -- Always run cleanup, even with empty valid_prefixes.
        -- When no extensions are loaded yet, all project/ entries are stale.
        local context_dir = target_dir .. "/context"
        merge_mod.remove_orphaned_index_entries(index_path, valid_prefixes, context_dir)
      end

      -- Load core context entries (always included, not extension-specific)
      local core_index_path = target_dir .. "/context/core-index-entries.json"
      local core_stat = vim.loop.fs_stat(core_index_path)
      if core_stat then
        local ok_core, core_data = pcall(read_json, core_index_path)
        if ok_core and core_data then
          local core_entries = core_data.entries or (vim.isarray(core_data) and core_data) or nil
          if core_entries then
            merge_mod.append_index_entries(index_path, core_entries)
          end
        end
      end

      -- Process merge targets
      merged_sections = process_merge_targets(ext_manifest, source_dir, project_dir, config)
    end)

    -- Rollback on failure
    if not load_ok then
      loader_mod.remove_installed_files(all_files, all_dirs)
      reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)
      return false, "Extension load failed: " .. tostring(load_err)
    end

    -- Update state (convert to relative paths for portability)
    local rel_files = paths_to_relative(all_files, project_dir)
    local rel_dirs = paths_to_relative(all_dirs, project_dir)
    local rel_data_files = paths_to_relative(data_skeleton_files, project_dir)
    state = state_mod.mark_loaded(state, extension_name, ext_manifest, rel_files, rel_dirs, merged_sections, rel_data_files)
    state_mod.write(project_dir, state, config)

    helpers.notify(
      string.format("Loaded extension '%s' (%d files)", extension_name, #all_files),
      "INFO"
    )

    -- Run post-load verification
    local verification = verify_mod.verify_extension(extension_name, source_dir, target_dir, config)
    if verification.status ~= "passed" then
      verify_mod.notify_results(verification)
    end

    return true, nil
  end

  --- Unload an extension from the current project
  --- @param extension_name string Extension name
  --- @param opts table|nil Options {confirm = true, project_dir = nil}
  --- @return boolean success True if unload succeeded
  --- @return string|nil error Error message if unload failed
  function manager.unload(extension_name, opts)
    opts = opts or {}
    local confirm = opts.confirm ~= false
    local project_dir = opts.project_dir or vim.fn.getcwd()

    -- Check if loaded
    local state = state_mod.read(project_dir, config)
    if not state_mod.is_loaded(state, extension_name) then
      return false, "Extension not loaded: " .. extension_name
    end

    -- Get installed files, data skeleton files, and merged sections
    local installed_files = state_mod.get_installed_files(state, extension_name)
    local installed_dirs = state_mod.get_installed_dirs(state, extension_name)
    local merged_sections = state_mod.get_merged_sections(state, extension_name)
    local data_skeleton_files = state_mod.get_data_skeleton_files(state, extension_name)

    -- Get extension manifest for reverse merge
    local extension = manifest_mod.get_extension(extension_name, config)

    -- Check if any loaded extensions depend on this one
    local dependents = {}
    local loaded_names = state_mod.list_loaded(state)
    for _, loaded_name in ipairs(loaded_names) do
      if loaded_name ~= extension_name then
        local loaded_ext = manifest_mod.get_extension(loaded_name, config)
        if loaded_ext and loaded_ext.manifest and loaded_ext.manifest.dependencies then
          for _, dep in ipairs(loaded_ext.manifest.dependencies) do
            if dep == extension_name then
              table.insert(dependents, loaded_name)
            end
          end
        end
      end
    end

    -- Confirmation dialog
    if confirm then
      local total_files = #installed_files + #data_skeleton_files
      local data_note = ""
      if #data_skeleton_files > 0 then
        data_note = "\n(User-created data files will be preserved)"
      end

      -- Warn about active dependents
      local dep_warning = ""
      if #dependents > 0 then
        dep_warning = string.format(
          "\n\nWARNING: Extension '%s' is required by: %s",
          extension_name,
          table.concat(dependents, ", ")
        )
      end

      local message = string.format(
        "Unload extension '%s'?\n\nThis will remove %d files.%s%s",
        extension_name,
        total_files,
        data_note,
        dep_warning
      )

      local choice = vim.fn.confirm(message, "&Unload\n&Cancel", 2)
      if choice ~= 1 then
        helpers.notify("Extension unload cancelled", "INFO")
        return false, "Cancelled by user"
      end
    end

    -- Reverse merge operations
    if extension and extension.manifest then
      reverse_merge_targets(extension.manifest, merged_sections, project_dir, config)
    end

    -- Convert relative paths back to absolute for file removal
    local abs_files = {}
    for _, rel_path in ipairs(installed_files) do
      table.insert(abs_files, project_dir .. "/" .. rel_path)
    end
    -- Also add data skeleton files (these are safe to remove - they're extension-provided)
    for _, rel_path in ipairs(data_skeleton_files) do
      table.insert(abs_files, project_dir .. "/" .. rel_path)
    end
    local abs_dirs = {}
    for _, rel_path in ipairs(installed_dirs) do
      table.insert(abs_dirs, project_dir .. "/" .. rel_path)
    end

    -- Remove files (includes both regular files and data skeleton files)
    -- User-created files in data directories are NOT in the abs_files list,
    -- so they will be preserved. The remove_installed_files function only
    -- removes empty directories, so user data directories will also be preserved.
    local removed_count = loader_mod.remove_installed_files(abs_files, abs_dirs)

    -- Update state
    state = state_mod.mark_unloaded(state, extension_name)
    state_mod.write(project_dir, state, config)

    helpers.notify(
      string.format("Unloaded extension '%s' (%d files removed)", extension_name, removed_count),
      "INFO"
    )

    return true, nil
  end

  --- Reload an extension (unload then load)
  --- @param extension_name string Extension name
  --- @param opts table|nil Options {confirm = true, project_dir = nil}
  --- @return boolean success True if reload succeeded
  --- @return string|nil error Error message if reload failed
  function manager.reload(extension_name, opts)
    opts = opts or {}
    local project_dir = opts.project_dir or vim.fn.getcwd()

    -- Check if loaded
    local state = state_mod.read(project_dir, config)
    if not state_mod.is_loaded(state, extension_name) then
      return false, "Extension not loaded: " .. extension_name
    end

    -- Unload without confirmation
    local success, err = manager.unload(extension_name, { confirm = false, project_dir = project_dir })
    if not success then
      return false, "Failed to unload: " .. (err or "unknown error")
    end

    -- Load without confirmation
    success, err = manager.load(extension_name, { confirm = false, project_dir = project_dir })
    if not success then
      return false, "Failed to load: " .. (err or "unknown error")
    end

    helpers.notify(string.format("Reloaded extension '%s'", extension_name), "INFO")
    return true, nil
  end

  --- Get extension status
  --- @param extension_name string Extension name
  --- @param project_dir string|nil Project directory
  --- @return string status "active", "inactive", or "update-available"
  function manager.get_status(extension_name, project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)

    if not state_mod.is_loaded(state, extension_name) then
      return "inactive"
    end

    -- Check for updates
    local extension = manifest_mod.get_extension(extension_name, config)
    if extension then
      if state_mod.needs_update(state, extension_name, extension.manifest.version) then
        return "update-available"
      end
    end

    return "active"
  end

  --- List all available extensions
  --- @return table extensions Array of {name, version, description, status}
  function manager.list_available()
    local project_dir = vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)
    local extensions = manifest_mod.list_extensions(config)

    local result = {}
    for _, ext in ipairs(extensions) do
      local status = "inactive"
      if state_mod.is_loaded(state, ext.name) then
        if state_mod.needs_update(state, ext.name, ext.manifest.version) then
          status = "update-available"
        else
          status = "active"
        end
      end

      table.insert(result, {
        name = ext.name,
        version = ext.manifest.version,
        description = ext.manifest.description,
        language = ext.manifest.language,
        status = status,
        path = ext.path,
      })
    end

    return result
  end

  --- List extensions loaded in current project
  --- @param project_dir string|nil Project directory
  --- @return table extensions Array of extension names
  function manager.list_loaded(project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)
    return state_mod.list_loaded(state)
  end

  --- Get extension details
  --- @param extension_name string Extension name
  --- @return table|nil details Extension details or nil if not found
  function manager.get_details(extension_name)
    local extension = manifest_mod.get_extension(extension_name, config)
    if not extension then
      return nil
    end

    local project_dir = vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)
    local ext_info = state_mod.get_extension_info(state, extension_name)

    return {
      name = extension.name,
      version = extension.manifest.version,
      description = extension.manifest.description,
      language = extension.manifest.language,
      dependencies = extension.manifest.dependencies or {},
      provides = extension.manifest.provides,
      merge_targets = extension.manifest.merge_targets,
      mcp_servers = extension.manifest.mcp_servers,
      status = manager.get_status(extension_name, project_dir),
      loaded_at = ext_info and ext_info.loaded_at or nil,
      installed_files = ext_info and ext_info.installed_files or {},
    }
  end

  --- Verify a loaded extension
  --- @param extension_name string Extension name
  --- @param project_dir string|nil Project directory
  --- @return table verification Verification report
  function manager.verify(extension_name, project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local target_dir = project_dir .. "/" .. config.base_dir

    -- Get extension source directory
    local extension = manifest_mod.get_extension(extension_name, config)
    if not extension then
      return {
        extension = extension_name,
        status = "failed",
        errors = { "Extension not found: " .. extension_name },
      }
    end

    return verify_mod.verify_extension(extension_name, extension.path, target_dir, config)
  end

  --- Verify all loaded extensions
  --- @param project_dir string|nil Project directory
  --- @return table results Array of verification reports
  function manager.verify_all(project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local loaded = manager.list_loaded(project_dir)
    local results = {}

    for _, ext_name in ipairs(loaded) do
      local verification = manager.verify(ext_name, project_dir)
      table.insert(results, verification)
    end

    return results
  end

  return manager
end

return M
