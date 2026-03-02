-- neotex.plugins.ai.claude.extensions.state
-- Extension state tracking via extensions.json

local M = {}

--- Default empty state structure
local function default_state()
  return {
    version = "1.0.0",
    extensions = {},
  }
end

--- Read JSON file
--- @param filepath string Path to JSON file
--- @return table|nil data Parsed JSON or nil on error
local function read_json(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return nil
  end

  local ok, result = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end

  return result
end

--- Write JSON file
--- @param filepath string Path to JSON file
--- @param data table Data to write
--- @return boolean success True if write succeeded
local function write_json(filepath, data)
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return false
  end

  -- Pretty print the JSON
  local formatted = vim.fn.system('echo ' .. vim.fn.shellescape(encoded) .. ' | jq .', '')
  if vim.v.shell_error ~= 0 then
    -- Fallback to raw JSON if jq not available
    formatted = encoded
  end

  local file = io.open(filepath, "w")
  if not file then
    return false
  end

  file:write(formatted)
  file:close()

  return true
end

--- Get path to extensions.json in a project
--- @param project_dir string Project directory path
--- @return string path Path to extensions.json
local function get_state_path(project_dir)
  return project_dir .. "/.claude/extensions.json"
end

--- Read extensions.json from target project
--- @param project_dir string|nil Project directory (defaults to cwd)
--- @return table state Extension state (empty if file doesn't exist)
function M.read(project_dir)
  project_dir = project_dir or vim.fn.getcwd()
  local state_path = get_state_path(project_dir)

  local state = read_json(state_path)
  if not state then
    return default_state()
  end

  -- Ensure extensions table exists
  if not state.extensions then
    state.extensions = {}
  end

  return state
end

--- Write extensions.json to target project
--- @param project_dir string|nil Project directory (defaults to cwd)
--- @param state table Extension state to write
--- @return boolean success True if write succeeded
function M.write(project_dir, state)
  project_dir = project_dir or vim.fn.getcwd()
  local state_path = get_state_path(project_dir)

  -- Ensure .claude directory exists
  local claude_dir = project_dir .. "/.claude"
  if vim.fn.isdirectory(claude_dir) ~= 1 then
    vim.fn.mkdir(claude_dir, "p")
  end

  return write_json(state_path, state)
end

--- Mark an extension as loaded in state
--- @param state table Current state
--- @param extension_name string Extension name
--- @param manifest table Extension manifest
--- @param installed_files table Array of installed file paths
--- @param installed_dirs table Array of created directories
--- @param merged_sections table|nil Map of merge operations performed
--- @return table state Updated state
function M.mark_loaded(state, extension_name, manifest, installed_files, installed_dirs, merged_sections)
  state.extensions[extension_name] = {
    version = manifest.version,
    loaded_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    source_dir = manifest._source_dir,
    installed_files = installed_files or {},
    installed_dirs = installed_dirs or {},
    merged_sections = merged_sections or {},
    status = "active",
  }
  return state
end

--- Mark an extension as unloaded in state
--- @param state table Current state
--- @param extension_name string Extension name
--- @return table state Updated state
function M.mark_unloaded(state, extension_name)
  if state.extensions[extension_name] then
    state.extensions[extension_name] = nil
  end
  return state
end

--- Check if an extension is loaded
--- @param state table Current state
--- @param extension_name string Extension name
--- @return boolean loaded True if extension is loaded
function M.is_loaded(state, extension_name)
  return state.extensions[extension_name] ~= nil
      and state.extensions[extension_name].status == "active"
end

--- Get loaded extension info
--- @param state table Current state
--- @param extension_name string Extension name
--- @return table|nil info Extension info or nil if not loaded
function M.get_extension_info(state, extension_name)
  return state.extensions[extension_name]
end

--- Get installed files for an extension
--- @param state table Current state
--- @param extension_name string Extension name
--- @return table files Array of installed file paths
function M.get_installed_files(state, extension_name)
  local ext_info = state.extensions[extension_name]
  if not ext_info then
    return {}
  end
  return ext_info.installed_files or {}
end

--- Get installed directories for an extension
--- @param state table Current state
--- @param extension_name string Extension name
--- @return table dirs Array of installed directory paths
function M.get_installed_dirs(state, extension_name)
  local ext_info = state.extensions[extension_name]
  if not ext_info then
    return {}
  end
  return ext_info.installed_dirs or {}
end

--- Get merged sections for an extension
--- @param state table Current state
--- @param extension_name string Extension name
--- @return table sections Map of merged sections
function M.get_merged_sections(state, extension_name)
  local ext_info = state.extensions[extension_name]
  if not ext_info then
    return {}
  end
  return ext_info.merged_sections or {}
end

--- Check if extension needs update (version comparison)
--- @param state table Current state
--- @param extension_name string Extension name
--- @param current_version string Current manifest version
--- @return boolean needs_update True if extension needs update
function M.needs_update(state, extension_name, current_version)
  local ext_info = state.extensions[extension_name]
  if not ext_info then
    return false
  end
  return ext_info.version ~= current_version
end

--- List all loaded extensions
--- @param state table Current state
--- @return table extensions Array of extension names
function M.list_loaded(state)
  local extensions = {}
  for name, info in pairs(state.extensions) do
    if info.status == "active" then
      table.insert(extensions, name)
    end
  end
  table.sort(extensions)
  return extensions
end

return M
