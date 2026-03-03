-- neotex.plugins.ai.claude.commands.picker.operations.sync
-- Load Core Agent System operation with simplified sync functionality
-- Excludes extension-owned artifacts from sync

local M = {}

-- Dependencies
local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")
local shared_config = require("neotex.plugins.ai.shared.extensions.config")
local shared_manifest = require("neotex.plugins.ai.shared.extensions.manifest")

-- Files to exclude from context sync (repository-specific files that should not be copied)
-- Note: update-project.md is intentionally NOT excluded as it is a guide/template
local CONTEXT_EXCLUDE_PATTERNS = {
  "project/repo/project-overview.md",
  "project/repo/self-healing-implementation-details.md",
}

--- Build extension exclusion sets from all extension manifests
--- @param global_dir string Global directory path (e.g., ~/.config/nvim)
--- @param config table|nil Picker config with base_dir field
--- @return table Exclusion sets per category (agents, commands, rules, scripts, hooks, skills, context)
local function build_extension_exclusions(global_dir, config)
  local exclusions = {
    agents = {},    -- Set of filenames to exclude
    commands = {},  -- Set of filenames to exclude
    rules = {},     -- Set of filenames to exclude
    scripts = {},   -- Set of filenames to exclude
    hooks = {},     -- Set of filenames to exclude
    skills = {},    -- Set of directory names to exclude
    context = {},   -- Array of directory prefixes to exclude
  }

  local base_dir = (config and config.base_dir) or ".claude"

  -- Derive extension config from base_dir
  local ext_config
  if base_dir == ".opencode" then
    ext_config = shared_config.opencode(global_dir)
  else
    ext_config = shared_config.claude(global_dir)
  end

  -- List all valid extensions
  local extensions = shared_manifest.list_extensions(ext_config)
  if #extensions == 0 then
    return exclusions
  end

  -- Iterate over each extension's manifest provides field
  for _, ext in ipairs(extensions) do
    local provides = ext.manifest.provides
    if provides then
      -- Agents: store filenames (e.g., "lean-research-agent.md")
      if provides.agents then
        for _, filename in ipairs(provides.agents) do
          exclusions.agents[filename] = true
        end
      end

      -- Commands: store filenames
      if provides.commands then
        for _, filename in ipairs(provides.commands) do
          exclusions.commands[filename] = true
        end
      end

      -- Rules: store filenames
      if provides.rules then
        for _, filename in ipairs(provides.rules) do
          exclusions.rules[filename] = true
        end
      end

      -- Scripts: store filenames
      if provides.scripts then
        for _, filename in ipairs(provides.scripts) do
          exclusions.scripts[filename] = true
        end
      end

      -- Hooks: store filenames
      if provides.hooks then
        for _, filename in ipairs(provides.hooks) do
          exclusions.hooks[filename] = true
        end
      end

      -- Skills: store directory names (e.g., "skill-lean-research")
      if provides.skills then
        for _, dirname in ipairs(provides.skills) do
          exclusions.skills[dirname] = true
        end
      end

      -- Context: store directory prefixes (e.g., "project/lean4")
      if provides.context then
        for _, prefix in ipairs(provides.context) do
          table.insert(exclusions.context, prefix)
        end
      end
    end
  end

  return exclusions
end

--- Filter file array by checking filename against exclusion set
--- Used for agents, commands, rules, scripts, hooks
--- @param files table Array of file sync info with name field
--- @param exclude_set table Set of filenames to exclude
--- @return table Filtered array of files
local function filter_extension_files(files, exclude_set)
  if vim.tbl_isempty(exclude_set) then
    return files
  end

  local filtered = {}
  for _, file in ipairs(files) do
    if not exclude_set[file.name] then
      table.insert(filtered, file)
    end
  end
  return filtered
end

--- Filter skill files by checking if path contains excluded skill directory
--- @param files table Array of file sync info with global_path field
--- @param skill_dirs_exclude table Set of skill directory names to exclude
--- @return table Filtered array of files
local function filter_extension_skills(files, skill_dirs_exclude)
  if vim.tbl_isempty(skill_dirs_exclude) then
    return files
  end

  local filtered = {}
  for _, file in ipairs(files) do
    local is_excluded = false
    for dirname, _ in pairs(skill_dirs_exclude) do
      -- Match path segment: "/skill-name/" to avoid partial matches
      if file.global_path:match("/" .. dirname .. "/") then
        is_excluded = true
        break
      end
    end
    if not is_excluded then
      table.insert(filtered, file)
    end
  end
  return filtered
end

--- Filter context files by checking if path relative to context/ starts with excluded prefix
--- @param files table Array of file sync info with global_path field
--- @param context_prefixes table Array of directory prefixes to exclude (e.g., {"project/lean4", "project/latex"})
--- @param base_dir string Base directory name (.claude or .opencode)
--- @return table Filtered array of files
local function filter_extension_context(files, context_prefixes, base_dir)
  if #context_prefixes == 0 then
    return files
  end

  local filtered = {}
  for _, file in ipairs(files) do
    local is_excluded = false

    -- Extract path relative to context/ directory
    -- Pattern: /base_dir/context/relative/path/to/file.md
    local context_pattern = "/" .. base_dir .. "/context/"
    local _, context_start = file.global_path:find(context_pattern, 1, true)
    if context_start then
      local relative_path = file.global_path:sub(context_start + 1)
      -- Check if relative path starts with any excluded prefix
      for _, prefix in ipairs(context_prefixes) do
        if relative_path:sub(1, #prefix) == prefix then
          is_excluded = true
          break
        end
      end
    end

    if not is_excluded then
      table.insert(filtered, file)
    end
  end
  return filtered
end

--- Count files by depth (top-level vs subdirectory)
--- @param files table Array of file sync info with is_subdir field
--- @return number top_level_count Number of top-level files
--- @return number subdir_count Number of files in subdirectories
local function count_by_depth(files)
  local top_level_count = 0
  local subdir_count = 0
  for _, file in ipairs(files) do
    if file.is_subdir then
      subdir_count = subdir_count + 1
    else
      top_level_count = top_level_count + 1
    end
  end
  return top_level_count, subdir_count
end

--- Count operations by action type
--- @param files table Array of file sync info
--- @return number copy_count Number of copy operations
--- @return number replace_count Number of replace operations
local function count_actions(files)
  local copy_count = 0
  local replace_count = 0
  for _, file in ipairs(files) do
    if file.action == "copy" then
      copy_count = copy_count + 1
    else
      replace_count = replace_count + 1
    end
  end
  return copy_count, replace_count
end

--- Sync files from global to local directory
--- @param files table List of file sync info
--- @param preserve_perms boolean Preserve execute permissions for shell scripts
--- @param merge_only boolean If true, skip "replace" actions (only copy new files)
--- @return number success_count Number of successfully synced files
local function sync_files(files, preserve_perms, merge_only)
  local success_count = 0
  merge_only = merge_only or false

  for _, file in ipairs(files) do
    -- Skip replace actions if merge_only is true
    if merge_only and file.action == "replace" then
      goto continue
    end

    -- Ensure parent directory exists
    local parent_dir = vim.fn.fnamemodify(file.local_path, ":h")
    helpers.ensure_directory(parent_dir)

    -- Read global file
    local content = helpers.read_file(file.global_path)
    if content then
      -- Write to local
      local write_success = helpers.write_file(file.local_path, content)
      if write_success then
        -- Preserve permissions for shell scripts
        if preserve_perms and file.name:match("%.sh$") then
          helpers.copy_file_permissions(file.global_path, file.local_path)
        end
        success_count = success_count + 1
      end
    end

    ::continue::
  end

  return success_count
end

--- Perform sync with the chosen strategy
--- @param project_dir string Project directory path
--- @param all_artifacts table Map of artifact type -> array of files
--- @param merge_only boolean If true, only add new files (skip conflicts)
--- @param base_dir string|nil Base directory name (default: ".claude")
--- @return number total_synced Total number of artifacts synced
local function execute_sync(project_dir, all_artifacts, merge_only, base_dir)
  base_dir = base_dir or ".claude"
  -- Create base directory
  helpers.ensure_directory(project_dir .. "/" .. base_dir)

  -- Sync all artifact types
  local counts = {}
  counts.commands = sync_files(all_artifacts.commands or {}, false, merge_only)
  counts.hooks = sync_files(all_artifacts.hooks or {}, true, merge_only)
  counts.templates = sync_files(all_artifacts.templates or {}, false, merge_only)
  counts.lib = sync_files(all_artifacts.lib or {}, true, merge_only)
  counts.docs = sync_files(all_artifacts.docs or {}, false, merge_only)
  counts.scripts = sync_files(all_artifacts.scripts or {}, true, merge_only)
  counts.tests = sync_files(all_artifacts.tests or {}, true, merge_only)
  counts.skills = sync_files(all_artifacts.skills or {}, true, merge_only)
  counts.agents = sync_files(all_artifacts.agents or {}, false, merge_only)
  counts.rules = sync_files(all_artifacts.rules or {}, false, merge_only)
  counts.context = sync_files(all_artifacts.context or {}, false, merge_only)
  counts.systemd = sync_files(all_artifacts.systemd or {}, false, merge_only)
  counts.settings = sync_files(all_artifacts.settings or {}, false, merge_only)
  counts.root_files = sync_files(all_artifacts.root_files or {}, false, merge_only)

  local total_synced = 0
  for _, count in pairs(counts) do
    total_synced = total_synced + count
  end

  -- Report results
  if total_synced > 0 then
    local strategy_msg = merge_only and " (new only)" or " (all)"

    -- Calculate subdirectory counts for key directories
    local _, lib_subdir = count_by_depth(all_artifacts.lib or {})
    local _, doc_subdir = count_by_depth(all_artifacts.docs or {})
    local _, skill_subdir = count_by_depth(all_artifacts.skills or {})

    helpers.notify(
      string.format(
        "Synced %d artifacts%s:\n" ..
        "  Commands: %d | Hooks: %d | Templates: %d\n" ..
        "  Lib: %d (%d nested) | Docs: %d (%d nested)\n" ..
        "  Scripts: %d | Tests: %d | Skills: %d (%d nested)\n" ..
        "  Agents: %d | Rules: %d | Context: %d\n" ..
        "  Systemd: %d | Settings: %d | Root Files: %d",
        total_synced, strategy_msg,
        counts.commands, counts.hooks, counts.templates,
        counts.lib, lib_subdir, counts.docs, doc_subdir,
        counts.scripts, counts.tests, counts.skills, skill_subdir,
        counts.agents, counts.rules, counts.context,
        counts.systemd, counts.settings, counts.root_files
      ),
      "INFO"
    )
  end

  return total_synced
end

--- Scan all artifact types from global directory
--- Filters out extension-owned artifacts to sync only core system files
--- @param global_dir string Global directory path
--- @param project_dir string Project directory path
--- @param config table|nil Picker config with base_dir field (defaults to .claude config)
--- @return table Map of artifact type -> array of files
local function scan_all_artifacts(global_dir, project_dir, config)
  local base_dir = (config and config.base_dir) or ".claude"
  local artifacts = {}

  -- Build extension exclusion sets (filtering is a no-op when no extensions exist)
  local exclusions = build_extension_exclusions(global_dir, config)

  -- Helper to scan with base_dir threaded through
  local function sync_scan(subdir, ext, recursive, exclude)
    return scan.scan_directory_for_sync(global_dir, project_dir, subdir, ext, recursive, exclude, base_dir)
  end

  -- Core artifacts common to both systems
  artifacts.commands = sync_scan("commands", "*.md")
  artifacts.commands = filter_extension_files(artifacts.commands, exclusions.commands)

  -- Use config-provided agents_subdir (different for .claude vs .opencode)
  local agents_subdir = (config and config.agents_subdir) or "agents"
  artifacts.agents = sync_scan(agents_subdir, "*.md")

  -- For OpenCode, also sync orchestrator.md from agent/ root (outside subagents/)
  if base_dir == ".opencode" then
    local orchestrator_files = sync_scan("agent", "orchestrator.md", false)
    for _, file in ipairs(orchestrator_files) do
      table.insert(artifacts.agents, file)
    end
  end
  artifacts.agents = filter_extension_files(artifacts.agents, exclusions.agents)

  -- Skills (multiple file types)
  local skills_md = sync_scan("skills", "*.md")
  local skills_yaml = sync_scan("skills", "*.yaml")
  artifacts.skills = {}
  for _, file in ipairs(skills_md) do
    table.insert(artifacts.skills, file)
  end
  for _, file in ipairs(skills_yaml) do
    table.insert(artifacts.skills, file)
  end
  artifacts.skills = filter_extension_skills(artifacts.skills, exclusions.skills)

  -- Shared artifacts: scanned unconditionally for both .claude and .opencode
  -- (scan_directory_for_sync returns empty array for non-existent directories)
  artifacts.hooks = sync_scan("hooks", "*.sh")
  artifacts.hooks = filter_extension_files(artifacts.hooks, exclusions.hooks)

  artifacts.templates = sync_scan("templates", "*.yaml")
  artifacts.docs = sync_scan("docs", "*.md")

  artifacts.scripts = sync_scan("scripts", "*.sh")
  artifacts.scripts = filter_extension_files(artifacts.scripts, exclusions.scripts)

  artifacts.rules = sync_scan("rules", "*.md")
  artifacts.rules = filter_extension_files(artifacts.rules, exclusions.rules)

  -- Context (multiple file types: md, json, yaml) - shared by both systems
  local ctx_md = sync_scan("context", "*.md", true, CONTEXT_EXCLUDE_PATTERNS)
  local ctx_json = sync_scan("context", "*.json")
  local ctx_yaml = sync_scan("context", "*.yaml")
  artifacts.context = {}
  for _, files in ipairs({ ctx_md, ctx_json, ctx_yaml }) do
    for _, file in ipairs(files) do
      table.insert(artifacts.context, file)
    end
  end
  artifacts.context = filter_extension_context(artifacts.context, exclusions.context, base_dir)

  -- Systemd (multiple file types: .service, .timer) - shared by both systems
  local systemd_service = sync_scan("systemd", "*.service")
  local systemd_timer = sync_scan("systemd", "*.timer")
  artifacts.systemd = {}
  for _, file in ipairs(systemd_service) do
    table.insert(artifacts.systemd, file)
  end
  for _, file in ipairs(systemd_timer) do
    table.insert(artifacts.systemd, file)
  end

  -- .claude-specific artifacts (directories that don't exist in .opencode/)
  if base_dir == ".claude" then
    artifacts.lib = sync_scan("lib", "*.sh")
    artifacts.tests = sync_scan("tests", "test_*.sh")
    artifacts.settings = sync_scan("", "settings.json")
  end

  -- Root files vary by system
  local root_file_names
  if base_dir == ".opencode" then
    root_file_names = { "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md" }
  else
    root_file_names = { ".gitignore", "README.md", "CLAUDE.md", "settings.local.json" }
  end

  artifacts.root_files = {}
  for _, filename in ipairs(root_file_names) do
    local global_path = global_dir .. "/" .. base_dir .. "/" .. filename
    local local_path = project_dir .. "/" .. base_dir .. "/" .. filename
    if vim.fn.filereadable(global_path) == 1 then
      local action = vim.fn.filereadable(local_path) == 1 and "replace" or "copy"
      table.insert(artifacts.root_files, {
        name = filename,
        global_path = global_path,
        local_path = local_path,
        action = action,
        is_subdir = false,
      })
    end
  end

  -- NOTE: Root-level CLAUDE.md (outside .claude/) is intentionally NOT synced.
  -- The global CLAUDE.md contains Neovim-specific coding standards that are irrelevant
  -- to non-Neovim projects. The .claude/CLAUDE.md (synced via root_file_names above)
  -- contains the agent system configuration which IS appropriate for all projects.

  return artifacts
end

--- Load all global artifacts locally
--- Scans global directory, copies new artifacts, with option to replace existing
--- @param config table|nil Picker config with base_dir field (defaults to .claude)
--- @return number count Total number of artifacts loaded or updated
function M.load_all_globally(config)
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()
  local base_dir = (config and config.base_dir) or ".claude"

  -- Don't load if we're in the global directory
  if project_dir == global_dir then
    helpers.notify("Already in the global directory", "INFO")
    return 0
  end

  -- Scan all artifact types using config-appropriate base_dir
  local all_artifacts = scan_all_artifacts(global_dir, project_dir, config)

  -- Count totals
  local total_files = 0
  local total_copy = 0
  local total_replace = 0

  for _, files in pairs(all_artifacts) do
    total_files = total_files + #files
    local copy, replace = count_actions(files)
    total_copy = total_copy + copy
    total_replace = total_replace + replace
  end

  if total_files == 0 then
    helpers.notify("No global artifacts found in " .. global_dir .. "/" .. base_dir .. "/", "WARN")
    return 0
  end

  -- Skip if no operations needed
  if total_copy + total_replace == 0 then
    helpers.notify("All artifacts already in sync", "INFO")
    return 0
  end

  -- Simple 2-option dialog
  local message, buttons, default_choice

  if total_replace > 0 then
    message = string.format(
      "Load artifacts from global directory?\n\n" ..
      "New: %d | Existing: %d\n\n" ..
      "1: Sync all (replace existing)\n" ..
      "2: Add new only\n" ..
      "3: Cancel",
      total_copy, total_replace
    )
    buttons = "&Sync all\n&New only\n&Cancel"
    default_choice = 3
  else
    message = string.format(
      "Load artifacts from global directory?\n\n" ..
      "New: %d | No conflicts\n\n" ..
      "1: Add all\n" ..
      "2: Cancel",
      total_copy
    )
    buttons = "&Add all\n&Cancel"
    default_choice = 2
  end

  local choice = vim.fn.confirm(message, buttons, default_choice)

  local merge_only
  if total_replace > 0 then
    if choice == 1 then
      merge_only = false
    elseif choice == 2 then
      merge_only = true
    else
      helpers.notify("Sync cancelled", "INFO")
      return 0
    end
  else
    if choice == 1 then
      merge_only = false
    else
      helpers.notify("Sync cancelled", "INFO")
      return 0
    end
  end

  return execute_sync(project_dir, all_artifacts, merge_only, base_dir)
end

--- Update local artifact from global version
--- @param artifact table Artifact data with filepath and name
--- @param artifact_type string Type of artifact (for directory determination)
--- @param silent boolean Don't show notifications
--- @return boolean success
function M.update_artifact_from_global(artifact, artifact_type, silent)
  if not artifact or not artifact.name then
    if not silent then
      helpers.notify("No artifact selected", "ERROR")
    end
    return false
  end

  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()

  -- Don't update if we're in the global directory
  if project_dir == global_dir then
    if not silent then
      helpers.notify("Cannot update artifacts in the global directory", "WARN")
    end
    return false
  end

  -- Determine directory and extension based on artifact type
  local subdir_map = {
    command = { dir = "commands", ext = ".md" },
    hook = { dir = "hooks", ext = ".sh" },
    hook_event = { dir = "hooks", ext = ".sh" },
    lib = { dir = "lib", ext = ".sh" },
    doc = { dir = "docs", ext = ".md" },
    template = { dir = "templates", ext = ".yaml" },
    script = { dir = "scripts", ext = ".sh" },
    test = { dir = "tests", ext = ".sh" },
    skill = { dir = "skills", ext = ".md" },
    agent = { dir = "agents", ext = ".md" },
    systemd = { dir = "systemd", ext = "" },  -- Systemd files have full extension in name
    root_file = { dir = "", ext = "" },  -- Root files have no subdir, name includes extension
  }

  local config = subdir_map[artifact_type]
  if not config then
    if not silent then
      helpers.notify("Unknown artifact type: " .. artifact_type, "ERROR")
    end
    return false
  end

  -- Find the global version
  local global_filepath
  if artifact_type == "root_file" then
    -- Root files: name already includes extension, no subdirectory
    global_filepath = global_dir .. "/.claude/" .. artifact.name
  else
    global_filepath = global_dir .. "/.claude/" .. config.dir .. "/" .. artifact.name .. config.ext
  end

  -- Check if global version exists
  if not helpers.is_file_readable(global_filepath) then
    if not silent then
      helpers.notify(string.format("Global version not found: %s", artifact.name), "ERROR")
    end
    return false
  end

  -- Create local directory if needed
  local local_dir
  local local_filepath
  if artifact_type == "root_file" then
    -- Root files go directly in .claude/
    local_dir = project_dir .. "/.claude"
    local_filepath = local_dir .. "/" .. artifact.name
  else
    local_dir = project_dir .. "/.claude/" .. config.dir
    local_filepath = local_dir .. "/" .. vim.fn.fnamemodify(global_filepath, ":t")
  end
  helpers.ensure_directory(local_dir)
  local content = helpers.read_file(global_filepath)
  if not content then
    if not silent then
      helpers.notify("Failed to read global file", "ERROR")
    end
    return false
  end

  local write_success = helpers.write_file(local_filepath, content)
  if not write_success then
    if not silent then
      helpers.notify("Failed to write local file", "ERROR")
    end
    return false
  end

  -- Preserve permissions for shell scripts
  if config.ext == ".sh" then
    helpers.copy_file_permissions(global_filepath, local_filepath)
  end

  if not silent then
    helpers.notify(string.format("Updated %s from global version", artifact.name), "INFO")
  end

  return true
end

return M
