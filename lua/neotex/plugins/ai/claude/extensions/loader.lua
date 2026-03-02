-- neotex.plugins.ai.claude.extensions.loader
-- File copy engine for extension loading/unloading

local M = {}

-- Dependencies
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Copy a single file with directory creation
--- @param source_path string Source file path
--- @param target_path string Target file path
--- @param preserve_perms boolean Preserve execute permissions
--- @return boolean success True if copy succeeded
local function copy_file(source_path, target_path, preserve_perms)
  -- Ensure parent directory exists
  local parent_dir = vim.fn.fnamemodify(target_path, ":h")
  helpers.ensure_directory(parent_dir)

  -- Read source file
  local content = helpers.read_file(source_path)
  if not content then
    return false
  end

  -- Write to target
  local success = helpers.write_file(target_path, content)
  if not success then
    return false
  end

  -- Preserve permissions for shell scripts
  if preserve_perms and source_path:match("%.sh$") then
    helpers.copy_file_permissions(source_path, target_path)
  end

  return true
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

--- Copy simple files (agents, commands, rules)
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target .claude directory
--- @param category string Category name (agents, commands, rules)
--- @param extension string File extension (.md)
--- @return table copied_files Array of copied file paths
--- @return table created_dirs Array of created directory paths
function M.copy_simple_files(manifest, source_dir, target_dir, category, extension)
  local copied_files = {}
  local created_dirs = {}

  if not manifest.provides or not manifest.provides[category] then
    return copied_files, created_dirs
  end

  local source_category_dir = source_dir .. "/" .. category
  local target_category_dir = target_dir .. "/" .. category

  -- Track if we created the category directory
  if vim.fn.isdirectory(target_category_dir) ~= 1 then
    helpers.ensure_directory(target_category_dir)
    table.insert(created_dirs, target_category_dir)
  end

  for _, filename in ipairs(manifest.provides[category]) do
    local source_path = source_category_dir .. "/" .. filename
    local target_path = target_category_dir .. "/" .. filename

    if vim.fn.filereadable(source_path) == 1 then
      local preserve_perms = filename:match("%.sh$")
      if copy_file(source_path, target_path, preserve_perms) then
        table.insert(copied_files, target_path)
      end
    end
  end

  return copied_files, created_dirs
end

--- Copy skill directories (recursive)
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target .claude directory
--- @return table copied_files Array of copied file paths
--- @return table created_dirs Array of created directory paths
function M.copy_skill_dirs(manifest, source_dir, target_dir)
  local copied_files = {}
  local created_dirs = {}

  if not manifest.provides or not manifest.provides.skills then
    return copied_files, created_dirs
  end

  local source_skills_dir = source_dir .. "/skills"
  local target_skills_dir = target_dir .. "/skills"

  -- Ensure skills directory exists
  if vim.fn.isdirectory(target_skills_dir) ~= 1 then
    helpers.ensure_directory(target_skills_dir)
    table.insert(created_dirs, target_skills_dir)
  end

  for _, skill_name in ipairs(manifest.provides.skills) do
    local source_skill_dir = source_skills_dir .. "/" .. skill_name
    local target_skill_dir = target_skills_dir .. "/" .. skill_name

    if vim.fn.isdirectory(source_skill_dir) == 1 then
      -- Create skill directory
      if vim.fn.isdirectory(target_skill_dir) ~= 1 then
        helpers.ensure_directory(target_skill_dir)
        table.insert(created_dirs, target_skill_dir)
      end

      -- Copy all files in skill directory
      local files = scan_directory_recursive(source_skill_dir)
      for _, rel_path in ipairs(files) do
        local source_path = source_skill_dir .. "/" .. rel_path
        local target_path = target_skill_dir .. "/" .. rel_path
        local preserve_perms = rel_path:match("%.sh$")

        if copy_file(source_path, target_path, preserve_perms) then
          table.insert(copied_files, target_path)
        end
      end
    end
  end

  return copied_files, created_dirs
end

--- Copy context directories (preserving structure)
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target .claude directory
--- @return table copied_files Array of copied file paths
--- @return table created_dirs Array of created directory paths
function M.copy_context_dirs(manifest, source_dir, target_dir)
  local copied_files = {}
  local created_dirs = {}

  if not manifest.provides or not manifest.provides.context then
    return copied_files, created_dirs
  end

  local source_context_dir = source_dir .. "/context"
  local target_context_dir = target_dir .. "/context"

  -- Ensure context directory exists
  if vim.fn.isdirectory(target_context_dir) ~= 1 then
    helpers.ensure_directory(target_context_dir)
    table.insert(created_dirs, target_context_dir)
  end

  for _, context_path in ipairs(manifest.provides.context) do
    local source_ctx_dir = source_context_dir .. "/" .. context_path
    local target_ctx_dir = target_context_dir .. "/" .. context_path

    if vim.fn.isdirectory(source_ctx_dir) == 1 then
      -- Create context subdirectory
      if vim.fn.isdirectory(target_ctx_dir) ~= 1 then
        helpers.ensure_directory(target_ctx_dir)
        table.insert(created_dirs, target_ctx_dir)
      end

      -- Copy all files preserving structure
      local files = scan_directory_recursive(source_ctx_dir)
      for _, rel_path in ipairs(files) do
        local source_path = source_ctx_dir .. "/" .. rel_path
        local target_path = target_ctx_dir .. "/" .. rel_path

        if copy_file(source_path, target_path, false) then
          table.insert(copied_files, target_path)
        end
      end
    end
  end

  return copied_files, created_dirs
end

--- Copy scripts
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target .claude directory
--- @return table copied_files Array of copied file paths
--- @return table created_dirs Array of created directory paths
function M.copy_scripts(manifest, source_dir, target_dir)
  local copied_files = {}
  local created_dirs = {}

  if not manifest.provides or not manifest.provides.scripts then
    return copied_files, created_dirs
  end

  local source_scripts_dir = source_dir .. "/scripts"
  local target_scripts_dir = target_dir .. "/scripts"

  -- Ensure scripts directory exists
  if vim.fn.isdirectory(target_scripts_dir) ~= 1 then
    helpers.ensure_directory(target_scripts_dir)
    table.insert(created_dirs, target_scripts_dir)
  end

  for _, script_name in ipairs(manifest.provides.scripts) do
    local source_path = source_scripts_dir .. "/" .. script_name
    local target_path = target_scripts_dir .. "/" .. script_name

    if vim.fn.filereadable(source_path) == 1 then
      if copy_file(source_path, target_path, true) then
        table.insert(copied_files, target_path)
      end
    end
  end

  return copied_files, created_dirs
end

--- Check for conflicts before loading
--- @param manifest table Extension manifest
--- @param target_dir string Target .claude directory
--- @return table conflicts Array of conflict descriptions
function M.check_conflicts(manifest, target_dir)
  local conflicts = {}

  if not manifest.provides then
    return conflicts
  end

  -- Check each category
  local categories = { "agents", "commands", "rules", "scripts" }
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

  return conflicts
end

--- Remove installed files
--- @param installed_files table Array of file paths to remove
--- @param installed_dirs table Array of directory paths to remove
--- @return number removed_count Number of files removed
function M.remove_installed_files(installed_files, installed_dirs)
  local removed_count = 0

  -- Remove files first
  for _, filepath in ipairs(installed_files) do
    if vim.fn.filereadable(filepath) == 1 then
      vim.fn.delete(filepath)
      removed_count = removed_count + 1
    end
  end

  -- Remove directories (in reverse order to handle nested dirs)
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

  return removed_count
end

return M
