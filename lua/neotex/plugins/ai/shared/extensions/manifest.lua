-- neotex.plugins.ai.shared.extensions.manifest
-- Extension manifest parsing and validation (parameterized)

local M = {}

--- Required fields in manifest.json
local REQUIRED_FIELDS = { "name", "version", "description" }

--- Valid provides categories
local VALID_PROVIDES = {
  "agents", "skills", "commands", "rules", "context", "scripts", "hooks", "data", "docs", "templates", "systemd"
}

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

--- List all valid extensions from a global extensions directory
--- @param config table Extension system configuration
--- @return table extensions Array of {name, path, manifest} for valid extensions
function M.list_extensions(config)
  local extensions_dir = config.global_extensions_dir
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
--- @param config table Extension system configuration
--- @return table|nil extension Extension info or nil if not found
function M.get_extension(name, config)
  local extensions = M.list_extensions(config)
  for _, ext in ipairs(extensions) do
    if ext.name == name then
      return ext
    end
  end
  return nil
end

--- Aggregate all extension artifacts into a blocklist for sync filtering
--- Reads all extension manifests and builds a set-based blocklist keyed by category.
--- This allows core sync operations to exclude extension-provided artifacts.
--- @param config table Extension system configuration
--- @return table blocklist Map of category -> {[filename] = true} for O(1) lookup
function M.aggregate_extension_artifacts(config)
  local blocklist = {
    agents = {},
    skills = {},
    commands = {},
    rules = {},
    context = {},
    scripts = {},
    hooks = {},
    data = {},
  }

  local extensions = M.list_extensions(config)

  for _, ext in ipairs(extensions) do
    local manifest = ext.manifest
    if manifest.provides then
      for category, files in pairs(manifest.provides) do
        if type(files) == "table" and blocklist[category] then
          for _, filename in ipairs(files) do
            blocklist[category][filename] = true
          end
        end
      end
    end
  end

  return blocklist
end

--- Get the core extension's provides map
--- Reads the core manifest and returns its provides entries.
--- Returns nil if the core extension doesn't exist or has no provides.
--- @param config table Extension system configuration
--- @return table|nil provides Map of category -> array of filenames, or nil
function M.get_core_provides(config)
  local core = M.get_extension("core", config)
  if not core or not core.manifest or not core.manifest.provides then
    return nil
  end
  return core.manifest.provides
end

--- Build an allow-list from core provides for sync filtering
--- Converts the core provides map into a category-keyed set of allowed filenames.
--- When an allow-list is available, only files in the list are synced (whitelist approach).
--- @param core_provides table Core provides map from get_core_provides()
--- @return table allow_list Map of category -> {[filename] = true} for O(1) lookup
function M.build_allow_list(core_provides)
  local allow_list = {}
  for category, files in pairs(core_provides) do
    if type(files) == "table" then
      allow_list[category] = {}
      for _, filename in ipairs(files) do
        allow_list[category][filename] = true
      end
    end
  end
  return allow_list
end

return M
