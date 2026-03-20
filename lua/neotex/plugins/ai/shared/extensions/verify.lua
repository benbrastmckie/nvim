-- neotex.plugins.ai.shared.extensions.verify
-- Post-load verification for extension integrity

local M = {}

--- Verify that a file exists on disk
--- @param filepath string Path to file
--- @return boolean exists True if file exists
local function file_exists(filepath)
  return vim.fn.filereadable(filepath) == 1
end

--- Verify that a directory exists on disk
--- @param dirpath string Path to directory
--- @return boolean exists True if directory exists
local function dir_exists(dirpath)
  return vim.fn.isdirectory(dirpath) == 1
end

--- Normalize index entry path by stripping known bad prefixes
--- Mirrors the normalization in merge.lua so verification checks the same paths
--- @param path string Path to normalize
--- @return string normalized_path Path with bad prefixes stripped
local function normalize_index_path(path)
  -- Strip full extension path prefix: .claude/extensions/*/context/ or .opencode/extensions/*/context/
  path = path:gsub("^%.claude/extensions/[^/]+/context/", "")
  path = path:gsub("^%.opencode/extensions/[^/]+/context/", "")

  -- Strip partial context prefix
  path = path:gsub("^context/", "")

  -- Strip .claude/context/ or .opencode/context/ prefix
  path = path:gsub("^%.claude/context/", "")
  path = path:gsub("^%.opencode/context/", "")

  return path
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

--- Verify all agent files referenced by extension skills exist
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param config table Extension system configuration
--- @return table results Verification results with missing_agents array
local function verify_agents(manifest, target_dir, config)
  local results = {
    checked = 0,
    missing = {},
  }

  if not manifest.provides or not manifest.provides.agents then
    return results
  end

  -- Determine agent directory location
  local agents_dir = target_dir .. "/" .. (config.agents_subdir or "agents")

  for _, agent_name in ipairs(manifest.provides.agents) do
    results.checked = results.checked + 1
    local agent_path = agents_dir .. "/" .. agent_name
    if not file_exists(agent_path) then
      table.insert(results.missing, agent_name)
    end
  end

  return results
end

--- Verify all skill directories exist
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory
--- @return table results Verification results
local function verify_skills(manifest, target_dir)
  local results = {
    checked = 0,
    missing = {},
  }

  if not manifest.provides or not manifest.provides.skills then
    return results
  end

  local skills_dir = target_dir .. "/skills"

  for _, skill_name in ipairs(manifest.provides.skills) do
    results.checked = results.checked + 1
    local skill_path = skills_dir .. "/" .. skill_name
    if not dir_exists(skill_path) then
      table.insert(results.missing, skill_name)
    end
  end

  return results
end

--- Verify all rule files exist
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory
--- @return table results Verification results
local function verify_rules(manifest, target_dir)
  local results = {
    checked = 0,
    missing = {},
  }

  if not manifest.provides or not manifest.provides.rules then
    return results
  end

  local rules_dir = target_dir .. "/rules"

  for _, rule_name in ipairs(manifest.provides.rules) do
    results.checked = results.checked + 1
    local rule_path = rules_dir .. "/" .. rule_name
    if not file_exists(rule_path) then
      table.insert(results.missing, rule_name)
    end
  end

  return results
end

--- Verify context files referenced in extension index-entries.json exist
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory
--- @return table results Verification results
local function verify_context(extension_dir, target_dir)
  local results = {
    checked = 0,
    missing = {},
  }

  local index_path = extension_dir .. "/index-entries.json"
  local index_data = read_json(index_path)

  if not index_data or not index_data.entries then
    return results
  end

  local context_dir = target_dir .. "/context"

  for _, entry in ipairs(index_data.entries) do
    results.checked = results.checked + 1
    local normalized_path = normalize_index_path(entry.path)
    local context_path = context_dir .. "/" .. normalized_path
    if not file_exists(context_path) then
      table.insert(results.missing, entry.path)
    end
  end

  return results
end

--- Verify EXTENSION.md section was injected into main CLAUDE.md/OPENCODE.md/AGENTS.md
--- Uses the manifest's actual merge target path if available, falling back to config.config_file
--- @param extension_name string Extension name
--- @param target_dir string Target base directory
--- @param config table Extension system configuration
--- @param manifest table|nil Extension manifest (used to find actual merge target)
--- @return boolean injected True if section marker found
local function verify_section_injection(extension_name, target_dir, config, manifest)
  -- Prefer the manifest's declared merge target over the config default
  local main_md_path
  local merge_key = config.merge_target_key
  if manifest and merge_key and manifest.merge_targets and manifest.merge_targets[merge_key] then
    main_md_path = target_dir .. "/../" .. manifest.merge_targets[merge_key].target
  else
    main_md_path = target_dir .. "/" .. config.config_file
  end

  if not file_exists(main_md_path) then
    return false
  end

  local file = io.open(main_md_path, "r")
  if not file then
    return false
  end

  local content = file:read("*all")
  file:close()

  local marker = string.format("<!-- SECTION: %s%s -->", config.section_prefix or "extension_", extension_name)
  return content:find(marker, 1, true) ~= nil
end

--- Verify merged index.json has extension entries
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory
--- @return boolean merged True if entries were merged
local function verify_index_merge(extension_dir, target_dir)
  local ext_index_path = extension_dir .. "/index-entries.json"
  local ext_index = read_json(ext_index_path)

  if not ext_index or not ext_index.entries or #ext_index.entries == 0 then
    -- No entries to merge
    return true
  end

  local main_index_path = target_dir .. "/context/index.json"
  local main_index = read_json(main_index_path)

  if not main_index or not main_index.entries then
    return false
  end

  -- Check if at least one extension entry is in main index
  -- Normalize the extension path since merge.lua normalizes paths during append
  local first_ext_path = normalize_index_path(ext_index.entries[1].path)
  for _, entry in ipairs(main_index.entries) do
    if entry.path == first_ext_path then
      return true
    end
  end

  return false
end

--- Perform full verification of a loaded extension
--- @param extension_name string Extension name
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param config table Extension system configuration
--- @return table verification Verification report
function M.verify_extension(extension_name, extension_dir, target_dir, config)
  local manifest_path = extension_dir .. "/manifest.json"
  local manifest = read_json(manifest_path)

  local verification = {
    extension = extension_name,
    status = "passed",
    agents = { passed = true },
    skills = { passed = true },
    rules = { passed = true },
    context = { passed = true },
    section = { passed = true },
    index = { passed = true },
    errors = {},
  }

  if not manifest then
    verification.status = "failed"
    table.insert(verification.errors, "Cannot read manifest.json")
    return verification
  end

  -- Verify agents
  local agent_results = verify_agents(manifest, target_dir, config)
  if #agent_results.missing > 0 then
    verification.agents = {
      passed = false,
      checked = agent_results.checked,
      missing = agent_results.missing,
    }
    for _, agent in ipairs(agent_results.missing) do
      table.insert(verification.errors, "Missing agent: " .. agent)
    end
  end

  -- Verify skills
  local skill_results = verify_skills(manifest, target_dir)
  if #skill_results.missing > 0 then
    verification.skills = {
      passed = false,
      checked = skill_results.checked,
      missing = skill_results.missing,
    }
    for _, skill in ipairs(skill_results.missing) do
      table.insert(verification.errors, "Missing skill: " .. skill)
    end
  end

  -- Verify rules
  local rule_results = verify_rules(manifest, target_dir)
  if #rule_results.missing > 0 then
    verification.rules = {
      passed = false,
      checked = rule_results.checked,
      missing = rule_results.missing,
    }
    for _, rule in ipairs(rule_results.missing) do
      table.insert(verification.errors, "Missing rule: " .. rule)
    end
  end

  -- Verify context files
  local context_results = verify_context(extension_dir, target_dir)
  if #context_results.missing > 0 then
    verification.context = {
      passed = false,
      checked = context_results.checked,
      missing = context_results.missing,
    }
    -- Only include first 5 missing context files to avoid verbose output
    for i, ctx in ipairs(context_results.missing) do
      if i <= 5 then
        table.insert(verification.errors, "Missing context: " .. ctx)
      elseif i == 6 then
        table.insert(verification.errors, "... and " .. (#context_results.missing - 5) .. " more missing context files")
        break
      end
    end
  end

  -- Verify section injection (pass manifest so it can check the actual merge target)
  local section_ok = verify_section_injection(extension_name, target_dir, config, manifest)
  if not section_ok then
    verification.section = { passed = false }
    local merge_key = config.merge_target_key
    local actual_target = (manifest and merge_key and manifest.merge_targets and manifest.merge_targets[merge_key])
      and manifest.merge_targets[merge_key].target
      or config.config_file
    table.insert(verification.errors, "Section '" .. (config.section_prefix or "extension_") .. extension_name .. "' not injected into " .. actual_target)
  end

  -- Verify index merge
  local index_ok = verify_index_merge(extension_dir, target_dir)
  if not index_ok then
    verification.index = { passed = false }
    table.insert(verification.errors, "Index entries not merged into context/index.json")
  end

  -- Determine overall status
  if #verification.errors > 0 then
    verification.status = "warnings"
  end

  -- Critical failures change status to failed
  if not verification.agents.passed or not verification.skills.passed then
    verification.status = "failed"
  end

  return verification
end

--- Format verification report for display
--- @param verification table Verification report
--- @return string formatted Formatted report string
function M.format_report(verification)
  local lines = {}

  local status_icon = verification.status == "passed" and "[OK]"
    or verification.status == "warnings" and "[WARN]"
    or "[FAIL]"

  table.insert(lines, string.format("%s Extension: %s", status_icon, verification.extension))

  if verification.status ~= "passed" then
    for _, err in ipairs(verification.errors) do
      table.insert(lines, "  - " .. err)
    end
  end

  return table.concat(lines, "\n")
end

--- Notify user of verification results
--- @param verification table Verification report
function M.notify_results(verification)
  local msg = M.format_report(verification)

  if verification.status == "passed" then
    vim.notify(msg, vim.log.levels.INFO, { title = "Extension Verified" })
  elseif verification.status == "warnings" then
    vim.notify(msg, vim.log.levels.WARN, { title = "Extension Warnings" })
  else
    vim.notify(msg, vim.log.levels.ERROR, { title = "Extension Verification Failed" })
  end
end

return M
