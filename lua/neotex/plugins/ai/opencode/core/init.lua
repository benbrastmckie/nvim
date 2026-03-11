-- neotex.plugins.ai.opencode.core
-- Core OpenCode setup and initialization

local M = {}

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

--- Write string to file
--- @param filepath string Path to file
--- @param content string Content to write
--- @return boolean success True if write succeeded
local function write_file_string(filepath, content)
  local file = io.open(filepath, "w")
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
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

--- Check if an opencode.json is managed by the extension system
--- @param json_path string Path to opencode.json
--- @return boolean is_managed True if managed by neotex-extensions
local function is_managed(json_path)
  local data = read_json(json_path)
  if not data then
    return false
  end
  return data._managed_by == "neotex-extensions"
end

--- Install base opencode.json template
--- If opencode.json exists but is not managed, backs up to opencode.json.user-backup
--- @param project_dir string Project directory (defaults to cwd)
--- @param global_dir string Global directory for templates (defaults to ~/.config/nvim)
--- @return boolean success True if template installed
--- @return string|nil message Status message
function M.install_base_opencode_json(project_dir, global_dir)
  project_dir = project_dir or vim.fn.getcwd()
  global_dir = global_dir or vim.fn.expand("~/.config/nvim")

  local target_path = project_dir .. "/opencode.json"
  local template_path = global_dir .. "/.opencode/templates/opencode.json"

  -- Check if template exists
  if vim.fn.filereadable(template_path) ~= 1 then
    return false, "Template not found: " .. template_path
  end

  -- Read template
  local template_content = read_file_string(template_path)
  if not template_content then
    return false, "Failed to read template"
  end

  -- Check if opencode.json exists
  if vim.fn.filereadable(target_path) == 1 then
    -- Check if managed
    if is_managed(target_path) then
      -- Overwrite managed file
      local success = write_file_string(target_path, template_content)
      if success then
        return true, "Updated managed opencode.json"
      else
        return false, "Failed to update opencode.json"
      end
    else
      -- Backup unmanaged file first
      local backup_path = target_path .. ".user-backup"
      local existing = read_file_string(target_path)
      if existing then
        local backup_ok = write_file_string(backup_path, existing)
        if not backup_ok then
          return false, "Failed to create backup"
        end
      end
      -- Now install template
      local success = write_file_string(target_path, template_content)
      if success then
        return true, "Installed template (user config backed up to opencode.json.user-backup)"
      else
        return false, "Failed to install template"
      end
    end
  else
    -- No existing file, just install
    local success = write_file_string(target_path, template_content)
    if success then
      return true, "Installed base opencode.json"
    else
      return false, "Failed to install opencode.json"
    end
  end
end

--- Check if base opencode.json needs to be installed
--- @param project_dir string|nil Project directory
--- @return boolean needs_install True if install needed
function M.needs_base_install(project_dir)
  project_dir = project_dir or vim.fn.getcwd()
  local target_path = project_dir .. "/opencode.json"

  if vim.fn.filereadable(target_path) ~= 1 then
    return true
  end

  -- If exists but not managed, we might want to install
  return not is_managed(target_path)
end

return M
