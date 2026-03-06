-- neotex.plugins.ai.claude.commands.picker.utils.scan
-- Directory scanning utilities for artifacts

local M = {}

--- Get the global source directory from config with fallback
--- @return string Global source directory path
function M.get_global_dir()
  local ok, config = pcall(require, "neotex.plugins.ai.claude.config")
  if ok and config.options and config.options.global_source_dir then
    return config.options.global_source_dir
  end
  if ok and config.defaults and config.defaults.global_source_dir then
    return config.defaults.global_source_dir
  end
  return vim.fn.expand("~/.config/nvim")
end

--- Scan a directory for files matching a pattern
--- @param dir string Directory path to scan
--- @param pattern string File pattern (e.g., "*.md", "*.sh")
--- @return table Array of file info {name, filepath, is_local}
function M.scan_directory(dir, pattern)
  local files = {}
  local file_paths = vim.fn.glob(dir .. "/" .. pattern, false, true)

  for _, filepath in ipairs(file_paths) do
    local filename = vim.fn.fnamemodify(filepath, ":t")
    local is_readme = filename == "README.md"

    if not is_readme then
      local name = vim.fn.fnamemodify(filepath, ":t:r")
      table.insert(files, {
        name = name,
        filepath = filepath,
        is_local = false, -- Will be set by merge logic
      })
    end
  end

  return files
end

--- Scan directory for files to sync (used by Load All operation)
--- @param global_dir string Global base directory (e.g., ~/.config/nvim)
--- @param local_dir string Local base directory (e.g., current project)
--- @param subdir string Subdirectory to scan (e.g., "commands", "hooks")
--- @param extension string File extension pattern (e.g., "*.md", "*.sh")
--- @param recursive boolean Enable recursive scanning with ** pattern (default: true)
--- @param exclude_patterns table|nil Optional array of relative path strings to exclude (e.g., {"project/repo/project-overview.md"})
--- @param base_dir string|nil Base directory name (default: ".claude", use ".opencode" for OpenCode)
--- @return table Array of file sync info {name, global_path, local_path, action, is_subdir}
function M.scan_directory_for_sync(global_dir, local_dir, subdir, extension, recursive, exclude_patterns, base_dir)
  if recursive == nil then recursive = true end
  base_dir = base_dir or ".claude"

  local global_path = global_dir .. "/" .. base_dir .. "/" .. subdir
  local local_path = local_dir .. "/" .. base_dir .. "/" .. subdir

  local all_files = {}
  local seen = {}  -- Deduplication table to prevent copying same file twice

  if recursive then
    -- Scan nested subdirectories with ** pattern (e.g., lib/core/utils.sh, docs/architecture/design.md)
    -- This is critical for copying all infrastructure files, not just top-level files
    local recursive_files = vim.fn.glob(global_path .. "/**/" .. extension, false, true)
    for _, global_file in ipairs(recursive_files) do
      seen[global_file] = true
      table.insert(all_files, global_file)
    end

    -- Scan top-level files separately (e.g., lib/README.md)
    -- **/ pattern doesn't match files directly in base directory, so we need both scans
    local top_level_files = vim.fn.glob(global_path .. "/" .. extension, false, true)
    for _, global_file in ipairs(top_level_files) do
      if not seen[global_file] then  -- Skip if already found by recursive scan
        seen[global_file] = true
        table.insert(all_files, global_file)
      end
    end
  else
    -- Original behavior: top-level only (for backward compatibility)
    all_files = vim.fn.glob(global_path .. "/" .. extension, false, true)
  end

  local files = {}
  exclude_patterns = exclude_patterns or {}

  for _, global_file in ipairs(all_files) do
    -- Calculate relative path from global_path base (e.g., "core/utils.sh" from "/path/lib/core/utils.sh")
    local rel_path = global_file:sub(#global_path + 2)

    -- Check if file matches any exclusion pattern (exact string match)
    local should_exclude = false
    for _, pattern in ipairs(exclude_patterns) do
      if rel_path == pattern then
        should_exclude = true
        break
      end
    end

    if not should_exclude then
      local local_file = local_path .. "/" .. rel_path

      -- Detect if file is in subdirectory (for reporting depth breakdown)
      local is_subdir = rel_path:match("/") ~= nil

      local action = vim.fn.filereadable(local_file) == 1 and "replace" or "copy"
      table.insert(files, {
        name = vim.fn.fnamemodify(global_file, ":t"),
        global_path = global_file,
        local_path = local_file,
        action = action,
        is_subdir = is_subdir,
      })
    end
  end

  return files
end

--- Merge local and global artifacts (local overrides global)
--- @param local_artifacts table Array of local artifacts
--- @param global_artifacts table Array of global artifacts
--- @return table Merged array with is_local flag set correctly
function M.merge_artifacts(local_artifacts, global_artifacts)
  local all_artifacts = {}
  local artifact_map = {}

  -- Add local artifacts first and mark them as local
  for _, artifact in ipairs(local_artifacts) do
    artifact.is_local = true
    table.insert(all_artifacts, artifact)
    artifact_map[artifact.name] = true
  end

  -- Add global artifacts only if not overridden by local
  for _, artifact in ipairs(global_artifacts) do
    if not artifact_map[artifact.name] then
      artifact.is_local = false
      table.insert(all_artifacts, artifact)
    end
  end

  return all_artifacts
end

--- Filter artifacts by name pattern
--- @param artifacts table Array of artifacts
--- @param pattern string Lua pattern (e.g., "^tts%-")
--- @return table Filtered array
function M.filter_by_pattern(artifacts, pattern)
  local filtered = {}

  for _, artifact in ipairs(artifacts) do
    if artifact.name:match(pattern) then
      table.insert(filtered, artifact)
    end
  end

  return filtered
end

--- Get project and global directories
--- @return table {project_dir, global_dir}
function M.get_directories()
  return {
    project_dir = vim.fn.getcwd(),
    global_dir = M.get_global_dir(),
  }
end

--- Scan artifacts for picker display
--- @param type_config table Artifact type configuration from registry
--- @param base_dir string|nil Base directory name (default: ".claude")
--- @return table Array of artifacts with metadata
function M.scan_artifacts_for_picker(type_config, base_dir)
  local dirs = M.get_directories()
  local local_artifacts = {}
  local global_artifacts = {}
  base_dir = base_dir or ".claude"

  -- Scan each subdirectory defined in type_config
  for _, subdir in ipairs(type_config.subdirs) do
    local local_path = dirs.project_dir .. "/" .. base_dir .. "/" .. subdir
    local global_path = dirs.global_dir .. "/" .. base_dir .. "/" .. subdir

    local local_files = M.scan_directory(local_path, "*" .. type_config.extension)
    local global_files = M.scan_directory(global_path, "*" .. type_config.extension)

    vim.list_extend(local_artifacts, local_files)
    vim.list_extend(global_artifacts, global_files)
  end

  -- Apply pattern filter if defined (e.g., tts-*.sh)
  if type_config.pattern_filter then
    local_artifacts = M.filter_by_pattern(local_artifacts, type_config.pattern_filter)
    global_artifacts = M.filter_by_pattern(global_artifacts, type_config.pattern_filter)
  end

  -- Merge artifacts (local overrides global)
  return M.merge_artifacts(local_artifacts, global_artifacts)
end

--- Scan context directory recursively for markdown files
--- @param base_dir string Base directory (".claude" or ".opencode")
--- @param project_dir string Project directory to scan
--- @param global_dir string Global directory to scan
--- @return table Array of context files grouped by category
function M.scan_context_directory(base_dir, project_dir, global_dir)
  base_dir = base_dir or ".claude"
  local context_files = {}
  local seen = {}

  -- Categories to scan (only top-level directories under context/)
  local categories = { "core", "project" }

  for _, category in ipairs(categories) do
    local local_path = project_dir .. "/" .. base_dir .. "/context/" .. category
    local global_path = global_dir .. "/" .. base_dir .. "/context/" .. category

    -- Scan local context files first
    if vim.fn.isdirectory(local_path) == 1 then
      local local_files = vim.fn.glob(local_path .. "/**/*.md", false, true)
      for _, filepath in ipairs(local_files) do
        local filename = vim.fn.fnamemodify(filepath, ":t")
        local rel_path = filepath:sub(#local_path + 2)
        if filename ~= "README.md" and not seen[rel_path] then
          seen[rel_path] = true
          table.insert(context_files, {
            name = filename:gsub("%.md$", ""),
            filepath = filepath,
            category = category,
            subpath = rel_path:gsub("%.md$", ""),
            is_local = true,
          })
        end
      end
    end

    -- Scan global context files
    if vim.fn.isdirectory(global_path) == 1 then
      local global_files = vim.fn.glob(global_path .. "/**/*.md", false, true)
      for _, filepath in ipairs(global_files) do
        local filename = vim.fn.fnamemodify(filepath, ":t")
        local rel_path = filepath:sub(#global_path + 2)
        if filename ~= "README.md" and not seen[rel_path] then
          seen[rel_path] = true
          table.insert(context_files, {
            name = filename:gsub("%.md$", ""),
            filepath = filepath,
            category = category,
            subpath = rel_path:gsub("%.md$", ""),
            is_local = false,
          })
        end
      end
    end
  end

  -- Sort by category then subpath
  table.sort(context_files, function(a, b)
    if a.category ~= b.category then
      return a.category < b.category
    end
    return a.subpath < b.subpath
  end)

  return context_files
end

return M
