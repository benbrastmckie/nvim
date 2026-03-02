-- neotex.plugins.ai.claude.extensions
-- Public API for extension management

local M = {}

-- Dependencies
local manifest_mod = require("neotex.plugins.ai.claude.extensions.manifest")
local state_mod = require("neotex.plugins.ai.claude.extensions.state")
local loader_mod = require("neotex.plugins.ai.claude.extensions.loader")
local merge_mod = require("neotex.plugins.ai.claude.extensions.merge")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

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
--- @return table merged_sections Tracking data for unmerge
local function process_merge_targets(ext_manifest, source_dir, project_dir)
  local merged_sections = {}

  if not ext_manifest.merge_targets then
    return merged_sections
  end

  local target_dir = project_dir .. "/.claude"

  -- Process CLAUDE.md section injection
  if ext_manifest.merge_targets.claudemd then
    local config = ext_manifest.merge_targets.claudemd
    local source_path = source_dir .. "/" .. config.source
    local target_path = project_dir .. "/" .. config.target

    local section_content = read_file_string(source_path)
    if section_content then
      local success, tracked = merge_mod.inject_claudemd_section(
        target_path,
        section_content,
        config.section_id
      )
      if success then
        merged_sections.claudemd = tracked
      end
    end
  end

  -- Process settings merge
  if ext_manifest.merge_targets.settings then
    local config = ext_manifest.merge_targets.settings
    local source_path = source_dir .. "/" .. config.source
    local target_path = project_dir .. "/" .. config.target

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
    local config = ext_manifest.merge_targets.index
    local source_path = source_dir .. "/" .. config.source
    local target_path = project_dir .. "/" .. config.target

    local entries_data = read_json(source_path)
    if entries_data and entries_data.entries then
      local success, tracked = merge_mod.append_index_entries(target_path, entries_data.entries)
      if success then
        merged_sections.index = tracked
      end
    end
  end

  return merged_sections
end

--- Reverse merge operations for an extension
--- @param ext_manifest table Extension manifest
--- @param merged_sections table Tracking data from process_merge_targets
--- @param project_dir string Target project directory
local function reverse_merge_targets(ext_manifest, merged_sections, project_dir)
  if not ext_manifest or not merged_sections then
    return
  end

  -- Reverse CLAUDE.md section
  if merged_sections.claudemd and ext_manifest.merge_targets and ext_manifest.merge_targets.claudemd then
    local config = ext_manifest.merge_targets.claudemd
    local target_path = project_dir .. "/" .. config.target
    merge_mod.remove_claudemd_section(target_path, config.section_id)
  end

  -- Reverse settings merge
  if merged_sections.settings and ext_manifest.merge_targets and ext_manifest.merge_targets.settings then
    local config = ext_manifest.merge_targets.settings
    local target_path = project_dir .. "/" .. config.target
    merge_mod.unmerge_settings(target_path, merged_sections.settings)
  end

  -- Reverse index entries
  if merged_sections.index and ext_manifest.merge_targets and ext_manifest.merge_targets.index then
    local config = ext_manifest.merge_targets.index
    local target_path = project_dir .. "/" .. config.target
    merge_mod.remove_index_entries_tracked(target_path, merged_sections.index)
  end
end

--- Load an extension into the current project
--- @param extension_name string Extension name
--- @param opts table|nil Options {confirm = true, project_dir = nil}
--- @return boolean success True if load succeeded
--- @return string|nil error Error message if load failed
function M.load(extension_name, opts)
  opts = opts or {}
  local confirm = opts.confirm ~= false  -- Default to true
  local project_dir = opts.project_dir or vim.fn.getcwd()
  local target_dir = project_dir .. "/.claude"

  -- Find extension
  local extension = manifest_mod.get_extension(extension_name)
  if not extension then
    return false, "Extension not found: " .. extension_name
  end

  local ext_manifest = extension.manifest
  local source_dir = extension.path

  -- Check if already loaded
  local state = state_mod.read(project_dir)
  if state_mod.is_loaded(state, extension_name) then
    return false, "Extension already loaded: " .. extension_name
  end

  -- Check for conflicts
  local conflicts = loader_mod.check_conflicts(ext_manifest, target_dir)
  if #conflicts > 0 and confirm then
    local conflict_msg = "The following files would be overwritten:\n"
    for _, c in ipairs(conflicts) do
      conflict_msg = conflict_msg .. "  - " .. c.category .. "/" .. c.file .. "\n"
    end
    conflict_msg = conflict_msg .. "\nProceed anyway?"

    local choice = vim.fn.confirm(conflict_msg, "&Yes\n&No", 2)
    if choice ~= 1 then
      helpers.notify("Extension load cancelled", "INFO")
      return false, "Cancelled by user"
    end
  end

  -- Confirmation dialog
  if confirm then
    local provides_summary = ""
    if ext_manifest.provides then
      for category, files in pairs(ext_manifest.provides) do
        if #files > 0 then
          provides_summary = provides_summary .. "  " .. category .. ": " .. #files .. "\n"
        end
      end
    end

    local message = string.format(
      "Load extension '%s' v%s?\n\n%s\n%s",
      extension_name,
      ext_manifest.version,
      ext_manifest.description,
      provides_summary ~= "" and "\nFiles to install:\n" .. provides_summary or ""
    )

    local choice = vim.fn.confirm(message, "&Load\n&Cancel", 2)
    if choice ~= 1 then
      helpers.notify("Extension load cancelled", "INFO")
      return false, "Cancelled by user"
    end
  end

  -- Ensure .claude directory exists
  helpers.ensure_directory(target_dir)

  -- Track all installed files and directories
  local all_files = {}
  local all_dirs = {}

  -- Copy agents
  local files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "agents", ".md")
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

  -- Process merge targets (CLAUDE.md sections, settings, index)
  local merged_sections = process_merge_targets(ext_manifest, source_dir, project_dir)

  -- Update state
  state = state_mod.mark_loaded(state, extension_name, ext_manifest, all_files, all_dirs, merged_sections)
  state_mod.write(project_dir, state)

  helpers.notify(
    string.format("Loaded extension '%s' (%d files)", extension_name, #all_files),
    "INFO"
  )

  return true, nil
end

--- Unload an extension from the current project
--- @param extension_name string Extension name
--- @param opts table|nil Options {confirm = true, project_dir = nil}
--- @return boolean success True if unload succeeded
--- @return string|nil error Error message if unload failed
function M.unload(extension_name, opts)
  opts = opts or {}
  local confirm = opts.confirm ~= false
  local project_dir = opts.project_dir or vim.fn.getcwd()

  -- Check if loaded
  local state = state_mod.read(project_dir)
  if not state_mod.is_loaded(state, extension_name) then
    return false, "Extension not loaded: " .. extension_name
  end

  -- Get installed files and merged sections
  local installed_files = state_mod.get_installed_files(state, extension_name)
  local installed_dirs = state_mod.get_installed_dirs(state, extension_name)
  local merged_sections = state_mod.get_merged_sections(state, extension_name)

  -- Get extension manifest for reverse merge
  local extension = manifest_mod.get_extension(extension_name)

  -- Confirmation dialog
  if confirm then
    local message = string.format(
      "Unload extension '%s'?\n\nThis will remove %d files.",
      extension_name,
      #installed_files
    )

    local choice = vim.fn.confirm(message, "&Unload\n&Cancel", 2)
    if choice ~= 1 then
      helpers.notify("Extension unload cancelled", "INFO")
      return false, "Cancelled by user"
    end
  end

  -- Reverse merge operations
  if extension and extension.manifest then
    reverse_merge_targets(extension.manifest, merged_sections, project_dir)
  end

  -- Remove files
  local removed_count = loader_mod.remove_installed_files(installed_files, installed_dirs)

  -- Update state
  state = state_mod.mark_unloaded(state, extension_name)
  state_mod.write(project_dir, state)

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
function M.reload(extension_name, opts)
  opts = opts or {}
  local project_dir = opts.project_dir or vim.fn.getcwd()

  -- Check if loaded
  local state = state_mod.read(project_dir)
  if not state_mod.is_loaded(state, extension_name) then
    return false, "Extension not loaded: " .. extension_name
  end

  -- Unload without confirmation
  local success, err = M.unload(extension_name, { confirm = false, project_dir = project_dir })
  if not success then
    return false, "Failed to unload: " .. (err or "unknown error")
  end

  -- Load without confirmation
  success, err = M.load(extension_name, { confirm = false, project_dir = project_dir })
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
function M.get_status(extension_name, project_dir)
  project_dir = project_dir or vim.fn.getcwd()
  local state = state_mod.read(project_dir)

  if not state_mod.is_loaded(state, extension_name) then
    return "inactive"
  end

  -- Check for updates
  local extension = manifest_mod.get_extension(extension_name)
  if extension then
    if state_mod.needs_update(state, extension_name, extension.manifest.version) then
      return "update-available"
    end
  end

  return "active"
end

--- List all available extensions
--- @return table extensions Array of {name, version, description, status}
function M.list_available()
  local project_dir = vim.fn.getcwd()
  local state = state_mod.read(project_dir)
  local extensions = manifest_mod.list_extensions()

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
function M.list_loaded(project_dir)
  project_dir = project_dir or vim.fn.getcwd()
  local state = state_mod.read(project_dir)
  return state_mod.list_loaded(state)
end

--- Get extension details
--- @param extension_name string Extension name
--- @return table|nil details Extension details or nil if not found
function M.get_details(extension_name)
  local extension = manifest_mod.get_extension(extension_name)
  if not extension then
    return nil
  end

  local project_dir = vim.fn.getcwd()
  local state = state_mod.read(project_dir)
  local ext_info = state_mod.get_extension_info(state, extension_name)

  return {
    name = extension.name,
    version = extension.manifest.version,
    description = extension.manifest.description,
    language = extension.manifest.language,
    provides = extension.manifest.provides,
    merge_targets = extension.manifest.merge_targets,
    mcp_servers = extension.manifest.mcp_servers,
    status = M.get_status(extension_name, project_dir),
    loaded_at = ext_info and ext_info.loaded_at or nil,
    installed_files = ext_info and ext_info.installed_files or {},
  }
end

return M
