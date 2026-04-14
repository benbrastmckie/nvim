-- neotex.plugins.ai.claude.commands.picker.operations.sync
-- Load Core Agent System operation with manifest-based blocklist filtering
-- Extension artifacts are filtered via aggregate_extension_artifacts() to ensure
-- only core artifacts are synced, regardless of what extensions are loaded globally

local M = {}

-- Dependencies
local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")
local manifest = require("neotex.plugins.ai.shared.extensions.manifest")
local ext_config = require("neotex.plugins.ai.shared.extensions.config")
local state_mod = require("neotex.plugins.ai.shared.extensions.state")
local merge_mod = require("neotex.plugins.ai.shared.extensions.merge")

-- Files to exclude from context sync (repository-specific files that should not be copied)
-- Note: update-project.md is intentionally NOT excluded as it is a guide/template
local CONTEXT_EXCLUDE_PATTERNS = {
  "project/repo/project-overview.md",
  "project/repo/self-healing-implementation-details.md",
}

-- Config markdown filenames that may contain extension-injected sections.
-- When these files are synced (overwritten from global), we preserve any
-- <!-- SECTION: {id} -->...<!-- END_SECTION: {id} --> blocks so that
-- loaded extensions' injected content survives a full sync.
local CONFIG_MARKDOWN_FILES = {
  ["CLAUDE.md"] = true,
  ["OPENCODE.md"] = true,
}

--- Extract all section blocks from content
--- Finds all <!-- SECTION: {id} -->...<!-- END_SECTION: {id} --> blocks
--- and returns them as an ordered array of strings (including markers).
--- @param content string File content to extract sections from
--- @return table sections Array of section block strings (with markers)
local function preserve_sections(content)
  local sections = {}
  -- Match section blocks including their markers and content.
  -- The markers use HTML comment syntax: <!-- SECTION: id --> ... <!-- END_SECTION: id -->
  for block in content:gmatch("(<!%-%- SECTION: [^\n]- %-%->.-<!%-%- END_SECTION: [^\n]- %-%->)") do
    table.insert(sections, block)
  end
  return sections
end

--- Restore preserved section blocks into new content
--- Appends each section block to the end of content, separated by newlines.
--- Skips sections whose id already exists in the new content (idempotent).
--- @param content string New file content (from global source)
--- @param sections table Array of section block strings from preserve_sections()
--- @return string content Content with sections restored
local function restore_sections(content, sections)
  if not sections or #sections == 0 then
    return content
  end

  for _, block in ipairs(sections) do
    -- Extract the section id from the opening marker
    local section_id = block:match("<!%-%- SECTION: ([^\n]-) %-%->")
    if section_id then
      -- Only restore if this section id is not already in the new content
      local marker = "<!-- SECTION: " .. section_id .. " -->"
      if not content:find(marker, 1, true) then
        -- Ensure content ends with a newline before appending
        if content:sub(-1) ~= "\n" then
          content = content .. "\n"
        end
        content = content .. "\n" .. block .. "\n"
      end
    end
  end

  return content
end

--- Read file contents as string (local helper for re-injection)
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

--- Read JSON file (local helper for re-injection)
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

--- Re-inject merge targets for all loaded extensions after a full sync.
--- This provides defense-in-depth: even if section preservation missed something
--- (e.g., settings.json or index.json which don't have section markers),
--- re-running merge targets restores all extension-injected content.
--- All merge operations (inject_section, merge_settings, append_index_entries) are
--- idempotent, so re-injection is safe even when section preservation already worked.
--- @param project_dir string Project directory path
--- @param config table Extension system configuration
local function reinject_loaded_extensions(project_dir, config)
  local state = state_mod.read(project_dir, config)
  local loaded_names = state_mod.list_loaded(state)

  if #loaded_names == 0 then
    return
  end

  for _, ext_name in ipairs(loaded_names) do
    local extension = manifest.get_extension(ext_name, config)
    if extension and extension.manifest and extension.manifest.merge_targets then
      local ext_manifest = extension.manifest
      local source_dir = extension.path
      local merge_key = config.merge_target_key

      -- Re-inject config markdown section (CLAUDE.md or OPENCODE.md)
      if ext_manifest.merge_targets[merge_key] then
        local mt_config = ext_manifest.merge_targets[merge_key]
        local source_path = source_dir .. "/" .. mt_config.source
        local target_path = project_dir .. "/" .. mt_config.target

        local section_content = read_file_string(source_path)
        if section_content then
          merge_mod.inject_section(target_path, section_content, mt_config.section_id)
        end
      end

      -- Re-inject settings merge
      if ext_manifest.merge_targets.settings then
        local mt_config = ext_manifest.merge_targets.settings
        local source_path = source_dir .. "/" .. mt_config.source
        local target_path = project_dir .. "/" .. mt_config.target

        local fragment = read_json(source_path)
        if fragment then
          merge_mod.merge_settings(target_path, fragment)
        end
      end

      -- Re-inject index.json entries
      if ext_manifest.merge_targets.index then
        local mt_config = ext_manifest.merge_targets.index
        local source_path = source_dir .. "/" .. mt_config.source
        local target_path = project_dir .. "/" .. mt_config.target

        local entries_data = read_json(source_path)
        if entries_data then
          local entries = entries_data.entries or (vim.isarray(entries_data) and entries_data) or nil
          if entries then
            merge_mod.append_index_entries(target_path, entries)
          end
        end
      end

      -- Re-inject opencode.json agent definitions (only for OpenCode config)
      if config.merge_target_key == "opencode_md" and ext_manifest.merge_targets.opencode_json then
        local mt_config = ext_manifest.merge_targets.opencode_json
        local source_path = source_dir .. "/" .. mt_config.source
        local target_path = project_dir .. "/" .. mt_config.target

        local fragment = read_json(source_path)
        if fragment then
          merge_mod.merge_opencode_agents(target_path, fragment)
        end
      end
    end
  end
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
      -- For config markdown files (CLAUDE.md, OPENCODE.md), preserve any
      -- extension-injected section blocks before overwriting with global content.
      -- This prevents sync from destroying sections added by loaded extensions.
      if CONFIG_MARKDOWN_FILES[file.name] and file.action == "replace" then
        local local_content = helpers.read_file(file.local_path)
        if local_content then
          local sections = preserve_sections(local_content)
          content = restore_sections(content, sections)
        end
      end

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

--- Convert set-based blocklist to array for exclude_patterns parameter
--- @param set table Set table {[key] = true}
--- @return table array Array of keys
local function set_to_array(set)
  local arr = {}
  for k, _ in pairs(set) do
    table.insert(arr, k)
  end
  return arr
end

--- Get extension config for the given base_dir
--- @param base_dir string Base directory (".claude" or ".opencode")
--- @param global_dir string Global directory path
--- @return table ext_cfg Extension system configuration
local function get_extension_config(base_dir, global_dir)
  if base_dir == ".opencode" then
    return ext_config.opencode(global_dir)
  end
  return ext_config.claude(global_dir)
end

--- Scan all artifact types from global directory
--- Filters extension artifacts via manifest-based blocklist to ensure only core artifacts are synced
--- @param global_dir string Global directory path
--- @param project_dir string Project directory path
--- @param config table|nil Picker config with base_dir field (defaults to .claude config)
--- @return table Map of artifact type -> array of files
function M.scan_all_artifacts(global_dir, project_dir, config)
  local base_dir = (config and config.base_dir) or ".claude"
  local artifacts = {}

  -- Build blocklist from all extension manifests
  local extension_cfg = get_extension_config(base_dir, global_dir)
  local blocklist = manifest.aggregate_extension_artifacts(extension_cfg)

  -- Helper to scan with base_dir and blocklist threaded through
  -- @param subdir string Subdirectory to scan
  -- @param ext string File extension pattern
  -- @param recursive boolean|nil Recursive scanning (default true)
  -- @param extra_exclude table|nil Additional exclude patterns to merge
  -- @param blocklist_category string|nil Which blocklist category to apply (e.g., "agents", "skills")
  local function sync_scan(subdir, ext, recursive, extra_exclude, blocklist_category)
    local exclude = extra_exclude and vim.deepcopy(extra_exclude) or {}

    -- Merge blocklist entries for this category
    if blocklist_category and blocklist[blocklist_category] then
      local blocklist_entries = set_to_array(blocklist[blocklist_category])
      for _, entry in ipairs(blocklist_entries) do
        table.insert(exclude, entry)
      end
    end

    return scan.scan_directory_for_sync(global_dir, project_dir, subdir, ext, recursive, exclude, base_dir)
  end

  -- Core artifacts common to both systems (with blocklist filtering)
  artifacts.commands = sync_scan("commands", "*.md", true, nil, "commands")

  -- Use config-provided agents_subdir (different for .claude vs .opencode)
  local agents_subdir = (config and config.agents_subdir) or "agents"
  artifacts.agents = sync_scan(agents_subdir, "*.md", true, nil, "agents")

  -- For OpenCode, also sync orchestrator.md from agent/ root (outside subagents/)
  if base_dir == ".opencode" then
    local orchestrator_files = sync_scan("agent", "orchestrator.md", false)
    for _, file in ipairs(orchestrator_files) do
      table.insert(artifacts.agents, file)
    end
  end

  -- Skills (multiple file types) with blocklist filtering
  local skills_md = sync_scan("skills", "*.md", true, nil, "skills")
  local skills_yaml = sync_scan("skills", "*.yaml", true, nil, "skills")
  artifacts.skills = {}
  for _, file in ipairs(skills_md) do
    table.insert(artifacts.skills, file)
  end
  for _, file in ipairs(skills_yaml) do
    table.insert(artifacts.skills, file)
  end

  -- Shared artifacts: scanned unconditionally for both .claude and .opencode
  -- (scan_directory_for_sync returns empty array for non-existent directories)
  artifacts.hooks = sync_scan("hooks", "*.sh", true, nil, "hooks")

  -- Templates (multiple file types: yaml, json)
  local templates_yaml = sync_scan("templates", "*.yaml")
  local templates_json = sync_scan("templates", "*.json")
  artifacts.templates = {}
  for _, file in ipairs(templates_yaml) do
    table.insert(artifacts.templates, file)
  end
  for _, file in ipairs(templates_json) do
    table.insert(artifacts.templates, file)
  end

  artifacts.docs = sync_scan("docs", "*.md")
  artifacts.scripts = sync_scan("scripts", "*.sh", true, nil, "scripts")
  artifacts.rules = sync_scan("rules", "*.md", true, nil, "rules")

  -- Context (multiple file types: md, json, yaml) - shared by both systems
  -- CONTEXT_EXCLUDE_PATTERNS filters repository-specific files (project-overview.md, etc.)
  -- Blocklist context entries use prefix matching for directory-based filtering
  local ctx_md = sync_scan("context", "*.md", true, CONTEXT_EXCLUDE_PATTERNS, "context")
  local ctx_json = sync_scan("context", "*.json", true, nil, "context")
  local ctx_yaml = sync_scan("context", "*.yaml", true, nil, "context")
  artifacts.context = {}
  for _, files in ipairs({ ctx_md, ctx_json, ctx_yaml }) do
    for _, file in ipairs(files) do
      table.insert(artifacts.context, file)
    end
  end

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
    root_file_names = { "AGENTS.md", "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md" }
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
  local all_artifacts = M.scan_all_artifacts(global_dir, project_dir, config)

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

  local total_synced = execute_sync(project_dir, all_artifacts, merge_only, base_dir)

  -- After a full sync (not merge-only), re-inject merge targets for all loaded
  -- extensions. This provides defense-in-depth: section preservation in sync_files()
  -- handles CLAUDE.md/OPENCODE.md, while re-injection also restores settings.json
  -- and index.json content that would be overwritten by a full sync.
  if not merge_only and total_synced > 0 then
    local extension_cfg = get_extension_config(base_dir, scan.get_global_dir())
    reinject_loaded_extensions(project_dir, extension_cfg)
  end

  return total_synced
end

--- Update local artifact from global version
--- @param artifact table Artifact data with filepath and name
--- @param artifact_type string Type of artifact (for directory determination)
--- @param silent boolean Don't show notifications
--- @param picker_config table|nil Picker configuration with base_dir field
--- @return boolean success
function M.update_artifact_from_global(artifact, artifact_type, silent, picker_config)
  if not artifact or not artifact.name then
    if not silent then
      helpers.notify("No artifact selected", "ERROR")
    end
    return false
  end

  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()
  local base_dir = (picker_config and picker_config.base_dir) or ".claude"

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
    template = { dir = "templates", ext = "" },  -- Templates: name includes extension (.yaml/.json)
    script = { dir = "scripts", ext = ".sh" },
    test = { dir = "tests", ext = ".sh" },
    skill = { dir = "skills", ext = ".md" },
    agent = { dir = "agents", ext = ".md" },
    systemd = { dir = "systemd", ext = "" },  -- Systemd files have full extension in name
    root_file = { dir = "", ext = "" },  -- Root files have no subdir, name includes extension
  }

  local type_config = subdir_map[artifact_type]
  if not type_config then
    if not silent then
      helpers.notify("Unknown artifact type: " .. artifact_type, "ERROR")
    end
    return false
  end

  -- Find the global version
  local global_filepath
  if artifact_type == "root_file" then
    -- Root files: name already includes extension, no subdirectory
    global_filepath = global_dir .. "/" .. base_dir .. "/" .. artifact.name
  else
    global_filepath = global_dir .. "/" .. base_dir .. "/" .. type_config.dir .. "/" .. artifact.name .. type_config.ext
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
    -- Root files go directly in base_dir/
    local_dir = project_dir .. "/" .. base_dir
    local_filepath = local_dir .. "/" .. artifact.name
  else
    local_dir = project_dir .. "/" .. base_dir .. "/" .. type_config.dir
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
  if type_config.ext == ".sh" then
    helpers.copy_file_permissions(global_filepath, local_filepath)
  end

  if not silent then
    helpers.notify(string.format("Updated %s from global version", artifact.name), "INFO")
  end

  return true
end

return M
