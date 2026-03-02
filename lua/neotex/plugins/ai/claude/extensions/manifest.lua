-- neotex.plugins.ai.claude.extensions.manifest
-- Extension manifest parsing and validation

local M = {}

--- Required fields in manifest.json
local REQUIRED_FIELDS = { "name", "version", "description" }

--- Valid provides categories
local VALID_PROVIDES = {
  "agents", "skills", "commands", "rules", "context", "scripts", "hooks"
}

--- Valid merge target types
local VALID_MERGE_TYPES = { "claudemd", "settings", "index" }

--- Read JSON file and parse it
--- @param filepath string Path to JSON file
--- @return table|nil Parsed JSON or nil on error
--- @return string|nil Error message if parsing failed
local function read_json(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Cannot open file: " .. filepath
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return nil, "Empty file: " .. filepath
  end

  local ok, result = pcall(vim.json.decode, content)
  if not ok then
    return nil, "JSON parse error: " .. tostring(result)
  end

  return result, nil
end

--- Validate that all required fields are present
--- @param manifest table Manifest data
--- @return boolean valid True if all required fields present
--- @return string|nil error Error message if validation failed
local function validate_required_fields(manifest)
  for _, field in ipairs(REQUIRED_FIELDS) do
    if not manifest[field] then
      return false, "Missing required field: " .. field
    end
    if type(manifest[field]) ~= "string" or manifest[field] == "" then
      return false, "Field must be non-empty string: " .. field
    end
  end
  return true, nil
end

--- Validate provides section has valid categories
--- @param manifest table Manifest data
--- @return boolean valid True if provides is valid
--- @return string|nil error Error message if validation failed
local function validate_provides(manifest)
  if not manifest.provides then
    return true, nil  -- provides is optional
  end

  if type(manifest.provides) ~= "table" then
    return false, "provides must be a table"
  end

  for category, files in pairs(manifest.provides) do
    local found = false
    for _, valid_cat in ipairs(VALID_PROVIDES) do
      if category == valid_cat then
        found = true
        break
      end
    end
    if not found then
      return false, "Invalid provides category: " .. category
    end
    if type(files) ~= "table" then
      return false, "provides." .. category .. " must be an array"
    end
  end

  return true, nil
end

--- Validate merge_targets section
--- @param manifest table Manifest data
--- @return boolean valid True if merge_targets is valid
--- @return string|nil error Error message if validation failed
local function validate_merge_targets(manifest)
  if not manifest.merge_targets then
    return true, nil  -- merge_targets is optional
  end

  if type(manifest.merge_targets) ~= "table" then
    return false, "merge_targets must be a table"
  end

  for target_type, config in pairs(manifest.merge_targets) do
    local found = false
    for _, valid_type in ipairs(VALID_MERGE_TYPES) do
      if target_type == valid_type then
        found = true
        break
      end
    end
    if not found then
      return false, "Invalid merge_targets type: " .. target_type
    end
    if type(config) ~= "table" then
      return false, "merge_targets." .. target_type .. " must be a table"
    end
    if not config.source then
      return false, "merge_targets." .. target_type .. ".source is required"
    end
    if not config.target then
      return false, "merge_targets." .. target_type .. ".target is required"
    end
  end

  return true, nil
end

--- Read and validate manifest from an extension directory
--- @param extension_dir string Path to extension directory
--- @return table|nil manifest Validated manifest or nil on error
--- @return string|nil error Error message if reading/validation failed
function M.read(extension_dir)
  local manifest_path = extension_dir .. "/manifest.json"

  local manifest, err = read_json(manifest_path)
  if not manifest then
    return nil, err
  end

  -- Store the source directory for later use
  manifest._source_dir = extension_dir

  local valid, validation_err = M.validate(manifest)
  if not valid then
    return nil, validation_err
  end

  return manifest, nil
end

--- Validate a manifest object
--- @param manifest table Manifest data
--- @return boolean valid True if manifest is valid
--- @return string|nil error Error message if validation failed
function M.validate(manifest)
  if type(manifest) ~= "table" then
    return false, "Manifest must be a table"
  end

  -- Validate required fields
  local valid, err = validate_required_fields(manifest)
  if not valid then
    return false, err
  end

  -- Validate provides section
  valid, err = validate_provides(manifest)
  if not valid then
    return false, err
  end

  -- Validate merge_targets section
  valid, err = validate_merge_targets(manifest)
  if not valid then
    return false, err
  end

  return true, nil
end

--- List all valid extensions from the global extensions directory
--- @param global_dir string|nil Global source directory (defaults to config value)
--- @return table extensions Array of {name, path, manifest} for valid extensions
function M.list_extensions(global_dir)
  -- Get global directory from config if not provided
  if not global_dir then
    local ok, scan = pcall(require, "neotex.plugins.ai.claude.commands.picker.utils.scan")
    if ok then
      global_dir = scan.get_global_dir()
    else
      global_dir = vim.fn.expand("~/.config/nvim")
    end
  end

  local extensions_dir = global_dir .. "/.claude/extensions"
  local extensions = {}

  -- Check if extensions directory exists
  if vim.fn.isdirectory(extensions_dir) ~= 1 then
    return extensions
  end

  -- Scan for subdirectories
  local entries = vim.fn.readdir(extensions_dir)
  for _, entry in ipairs(entries) do
    local extension_path = extensions_dir .. "/" .. entry

    -- Only process directories
    if vim.fn.isdirectory(extension_path) == 1 then
      local manifest, err = M.read(extension_path)
      if manifest then
        table.insert(extensions, {
          name = manifest.name,
          path = extension_path,
          manifest = manifest,
        })
      else
        -- Log warning for invalid extensions but continue
        vim.schedule(function()
          vim.notify(
            string.format("Extension '%s' has invalid manifest: %s", entry, err),
            vim.log.levels.WARN
          )
        end)
      end
    end
  end

  -- Sort by name
  table.sort(extensions, function(a, b)
    return a.name < b.name
  end)

  return extensions
end

--- Get extension by name
--- @param name string Extension name
--- @param global_dir string|nil Global source directory
--- @return table|nil extension Extension info or nil if not found
function M.get_extension(name, global_dir)
  local extensions = M.list_extensions(global_dir)
  for _, ext in ipairs(extensions) do
    if ext.name == name then
      return ext
    end
  end
  return nil
end

return M
