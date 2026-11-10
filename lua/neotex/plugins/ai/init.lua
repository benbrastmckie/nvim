-----------------------------------------------------------
-- AI Plugin Category
--
-- This module returns AI-related plugin specifications.
-- It includes all AI tools and integrations.
-----------------------------------------------------------

-- Helper function to require a module with error handling
local function safe_require(module)
  local ok, result = pcall(require, module)
  if not ok then
    vim.notify("Failed to load plugin module: " .. module, vim.log.levels.WARN)
    return nil
  end

  -- Validate that the result is actually a valid plugin spec
  -- Most plugin specs are tables with a string at index 1 (the repo)
  if type(result) == "table" then
    -- It's already a valid spec if it has a string in position 1
    if type(result[1]) == "string" then
      return result
    end

    -- It's already a valid spec if it's an import directive
    if result.import then
      return result
    end

    -- For function-only modules (which would cause the "invalid plugin spec" error)
    -- Return nil instead of the function-containing table
    if result.setup and type(result.setup) == "function" and not result[1] then
      vim.notify("Skipping non-plugin module: " .. module, vim.log.levels.DEBUG)
      return nil
    end

    return result
  end

  return nil
end

local plugins = {}

-- Load AI plugin specifications
local ai_plugins = {
  "claudecode",
  "lectic",
  "mcp-hub",
  "opencode",
  "sapience-plugin",
}

-- Load each AI plugin spec
for _, plugin_name in ipairs(ai_plugins) do
  local plugin_spec = safe_require("neotex.plugins.ai." .. plugin_name)
  if plugin_spec then
    table.insert(plugins, plugin_spec)
  end
end

return plugins
