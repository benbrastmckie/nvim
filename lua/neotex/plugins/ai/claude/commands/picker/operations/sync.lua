-- neotex.plugins.ai.claude.commands.picker.operations.sync
-- Load Core Agent System operation with manifest-based blocklist filtering
-- Extension artifacts are filtered via aggregate_extension_artifacts() to ensure
-- only core artifacts are synced, regardless of what extensions are loaded globally
--
-- Section Preservation: When syncing config markdown files (CLAUDE.md, OPENCODE.md),
-- any <!-- SECTION: {id} -->...<!-- END_SECTION: {id} --> blocks injected by loaded
-- extensions are preserved across the overwrite. After a full sync, merge targets
-- for all loaded extensions are also re-injected as defense-in-depth.

local M = {}

-- Dependencies
local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")
local manifest = require("neotex.plugins.ai.shared.extensions.manifest")
local ext_config = require("neotex.plugins.ai.shared.extensions.config")
local state_mod = require("neotex.plugins.ai.shared.extensions.state")
local merge_mod = require("neotex.plugins.ai.shared.extensions.merge")

-- Files to exclude from context sync (repository-specific and generated files that should not be copied)
-- Note: update-project.md is intentionally NOT excluded as it is a guide/template
-- index.json and index.json.backup are generated per-repo by the extension loader
local CONTEXT_EXCLUDE_PATTERNS = {
  "project/repo/project-overview.md",
  "project/repo/self-healing-implementation-details.md",
  "index.json",
  "index.json.backup",
}

-- Config markdown filenames that may contain extension-injected sections.
-- When these files are synced (overwritten from global), we preserve any
-- <!-- SECTION: {id} -->...<!-- END_SECTION: {id} --> blocks so that
-- loaded extensions' injected content survives a full sync.
local CONFIG_MARKDOWN_FILES = {
  ["CLAUDE.md"] = true,
  ["OPENCODE.md"] = true,
}

--- Strip all extension-injected section blocks from content
--- Removes <!-- SECTION: extension_* -->...<!-- END_SECTION: extension_* --> blocks
--- to prevent extension sections loaded in the source repo from leaking into sync targets.
--- @param content string File content to strip
--- @return string content Content with extension sections removed
local function strip_extension_sections(content)
  -- Remove extension section blocks (including surrounding blank lines)
  -- Match blocks like: <!-- SECTION: extension_nvim --> ... <!-- END_SECTION: extension_nvim -->
  content = content:gsub(
    "\n*<!%-%- SECTION: extension_[^\n]- %-%->.-<!%-%- END_SECTION: extension_[^\n]- %-%->\n*",
    "\n"
  )
  -- Clean up any trailing whitespace from removal
  content = content:gsub("\n\n\n+", "\n\n")
  return content
end

--- Strip extension-merged settings keys from settings.local.json content
--- Reads extensions.json from the global source directory to identify which keys
--- were merged by loaded extensions, then removes those keys from the content.
--- @param content string JSON content of settings.local.json
--- @param global_dir string Global source directory path
--- @return string content Content with extension settings stripped
local function strip_extension_settings(content, global_dir)
  -- Parse the settings content
  local ok, settings = pcall(vim.json.decode, content)
  if not ok or type(settings) ~= "table" then
    return content
  end

  -- Read extensions.json from the source repo to find merged keys
  -- Check both .claude and .opencode extensions.json
  local base_dirs = { ".claude", ".opencode" }
  local any_stripped = false

  for _, base_dir in ipairs(base_dirs) do
    local ext_state_path = global_dir .. "/" .. base_dir .. "/extensions.json"
    local state_file = io.open(ext_state_path, "r")
    if state_file then
      local state_content = state_file:read("*all")
      state_file:close()
      local state_ok, state_data = pcall(vim.json.decode, state_content)
      if state_ok and type(state_data) == "table" and state_data.extensions then
        for _, ext_info in pairs(state_data.extensions) do
          if ext_info.merged_sections and ext_info.merged_sections.settings then
            local tracked = ext_info.merged_sections.settings
            -- Remove tracked keys from settings using the same structure
            local function remove_tracked(t, track)
              for key, info in pairs(track) do
                if type(info) == "table" and info.type then
                  if info.type == "new_array" or info.type == "new_object" or info.type == "new_value" then
                    t[key] = nil
                    any_stripped = true
                  elseif info.type == "appended" and info.items then
                    if t[key] and vim.isarray(t[key]) then
                      for _, item in ipairs(info.items) do
                        for i = #t[key], 1, -1 do
                          if vim.deep_equal(t[key][i], item) then
                            table.remove(t[key], i)
                            any_stripped = true
                            break
                          end
                        end
                      end
                    end
                  elseif info.type == "merged" and info.children then
                    if t[key] then
                      remove_tracked(t[key], info.children)
                    end
                  end
                elseif type(info) == "table" then
                  if t[key] then
                    remove_tracked(t[key], info)
                  end
                end
              end
            end
            remove_tracked(settings, tracked)
          end
        end
      end
    end
  end

  if any_stripped then
    local encode_ok, encoded = pcall(vim.json.encode, settings)
    if encode_ok then
      -- Pretty-print with jq if available
      local formatted = vim.fn.system('echo ' .. vim.fn.shellescape(encoded) .. ' | jq .', '')
      if vim.v.shell_error == 0 and formatted ~= "" then
        return formatted
      end
      return encoded
    end
  end

  return content
end

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
--- @param protected_paths table|nil Set of relative paths to protect from replacement {[path] = true}
--- @param base_path string|nil Base path for computing relative paths (e.g., project_dir .. "/" .. base_dir)
--- @param global_dir string|nil Global source directory for extension stripping
--- @return number success_count Number of successfully synced files
--- @return number protected_count Number of files skipped due to protection
local function sync_files(files, preserve_perms, merge_only, protected_paths, base_path, global_dir)
  local success_count = 0
  local protected_count = 0
  merge_only = merge_only or false
  protected_paths = protected_paths or {}

  for _, file in ipairs(files) do
    -- Skip replace actions if merge_only is true
    if merge_only and file.action == "replace" then
      goto continue
    end

    -- Skip protected files during replace operations
    if file.action == "replace" and base_path and next(protected_paths) then
      local rel_path = file.local_path:sub(#base_path + 2)
      if protected_paths[rel_path] then
        protected_count = protected_count + 1
        goto continue
      end
    end

    -- Ensure parent directory exists
    local parent_dir = vim.fn.fnamemodify(file.local_path, ":h")
    helpers.ensure_directory(parent_dir)

    -- Read global file
    local content = helpers.read_file(file.global_path)
    if content then
      -- Strip extension-injected content from source before syncing to target.
      -- This prevents extension artifacts loaded in the source repo from leaking
      -- into target repos during sync.
      if global_dir then
        -- Strip extension sections from config markdown files (CLAUDE.md, OPENCODE.md)
        if CONFIG_MARKDOWN_FILES[file.name] then
          content = strip_extension_sections(content)
        end

        -- Strip extension-merged keys from settings.local.json
        if file.name == "settings.local.json" then
          content = strip_extension_settings(content, global_dir)
        end
      end

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

  return success_count, protected_count
end

--- Perform sync with the chosen strategy
--- @param project_dir string Project directory path
--- @param all_artifacts table Map of artifact type -> array of files
--- @param merge_only boolean If true, only add new files (skip conflicts)
--- @param base_dir string|nil Base directory name (default: ".claude")
--- @param protected_paths table|nil Set of relative paths to protect {[path] = true}
--- @param global_dir string|nil Global source directory for extension stripping
--- @return number total_synced Total number of artifacts synced
local function execute_sync(project_dir, all_artifacts, merge_only, base_dir, protected_paths, global_dir)
  base_dir = base_dir or ".claude"
  protected_paths = protected_paths or {}
  local base_path = project_dir .. "/" .. base_dir

  -- Create base directory
  helpers.ensure_directory(base_path)

  -- Helper to call sync_files with protection support and extension stripping
  local function sync_with_protect(files, preserve_perms)
    return sync_files(files, preserve_perms, merge_only, protected_paths, base_path, global_dir)
  end

  -- Sync all artifact types
  local counts = {}
  local protect_counts = {}
  counts.commands, protect_counts.commands = sync_with_protect(all_artifacts.commands or {}, false)
  counts.hooks, protect_counts.hooks = sync_with_protect(all_artifacts.hooks or {}, true)
  counts.templates, protect_counts.templates = sync_with_protect(all_artifacts.templates or {}, false)
  counts.lib, protect_counts.lib = sync_with_protect(all_artifacts.lib or {}, true)
  counts.docs, protect_counts.docs = sync_with_protect(all_artifacts.docs or {}, false)
  counts.scripts, protect_counts.scripts = sync_with_protect(all_artifacts.scripts or {}, true)
  counts.tests, protect_counts.tests = sync_with_protect(all_artifacts.tests or {}, true)
  counts.skills, protect_counts.skills = sync_with_protect(all_artifacts.skills or {}, true)
  counts.agents, protect_counts.agents = sync_with_protect(all_artifacts.agents or {}, false)
  counts.rules, protect_counts.rules = sync_with_protect(all_artifacts.rules or {}, false)
  counts.context, protect_counts.context = sync_with_protect(all_artifacts.context or {}, false)
  counts.systemd, protect_counts.systemd = sync_with_protect(all_artifacts.systemd or {}, false)
  counts.settings, protect_counts.settings = sync_with_protect(all_artifacts.settings or {}, false)
  counts.root_files, protect_counts.root_files = sync_with_protect(all_artifacts.root_files or {}, false)

  local total_synced = 0
  local total_protected = 0
  for key, count in pairs(counts) do
    total_synced = total_synced + count
    total_protected = total_protected + (protect_counts[key] or 0)
  end

  -- Report results
  if total_synced > 0 or total_protected > 0 then
    local strategy_msg = merge_only and " (new only)" or " (all)"
    local protect_msg = total_protected > 0
      and string.format("\n  Protected: %d files skipped (.syncprotect)", total_protected)
      or ""

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
        "  Systemd: %d | Settings: %d | Root Files: %d%s",
        total_synced, strategy_msg,
        counts.commands, counts.hooks, counts.templates,
        counts.lib, lib_subdir, counts.docs, doc_subdir,
        counts.scripts, counts.tests, counts.skills, skill_subdir,
        counts.agents, counts.rules, counts.context,
        counts.systemd, counts.settings, counts.root_files,
        protect_msg
      ),
      "INFO"
    )
  end

  return total_synced
end

--- Load .sync-exclude file from source (global) directory
--- Parses path exclusions and audit-pattern directives.
--- @param global_dir string Global directory path (source repo root)
--- @return table exclude_set Set of paths to exclude {[path] = true}
--- @return table audit_patterns Array of Lua pattern strings for content auditing
local function load_sync_exclude(global_dir)
  local exclude_set = {}
  local audit_patterns = {}

  local filepath = global_dir .. "/.sync-exclude"
  local file = io.open(filepath, "r")
  if not file then
    return exclude_set, audit_patterns
  end

  for line in file:lines() do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    if line == "" then
      goto continue
    end

    -- Check for audit-pattern directive
    local pattern = line:match("^# audit%-pattern:%s*(.+)$")
    if pattern then
      table.insert(audit_patterns, pattern:match("^%s*(.-)%s*$"))
      goto continue
    end

    -- Skip regular comments
    if line:sub(1, 1) == "#" then
      goto continue
    end

    -- Non-comment, non-empty line is a path exclusion
    exclude_set[line] = true

    ::continue::
  end
  file:close()

  return exclude_set, audit_patterns
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

--- Load .syncprotect file from target repository
--- Reads from project root first ({project_dir}/.syncprotect), falling back to
--- the legacy location ({project_dir}/{base_dir}/.syncprotect) with a deprecation warning.
--- Protected files will not be overwritten during sync operations.
--- @param project_dir string Project directory path
--- @param base_dir string|nil Base directory name for legacy fallback (".claude" or ".opencode")
--- @return table protected_paths Set of relative paths {[path] = true}
local function load_syncprotect(project_dir, base_dir)
  local protected = {}

  -- Try project root first (new canonical location)
  local filepath = project_dir .. "/.syncprotect"
  local file = io.open(filepath, "r")

  -- Fall back to legacy location inside base_dir
  if not file and base_dir then
    local legacy_path = project_dir .. "/" .. base_dir .. "/.syncprotect"
    file = io.open(legacy_path, "r")
    if file then
      helpers.notify(
        ".syncprotect found at legacy location (" .. base_dir .. "/.syncprotect). "
          .. "Please move it to the project root (.syncprotect).",
        "WARN"
      )
    end
  end

  if not file then
    return protected
  end

  for line in file:lines() do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    -- Skip empty lines and comments
    if line ~= "" and line:sub(1, 1) ~= "#" then
      protected[line] = true
    end
  end
  file:close()

  return protected
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

--- Audit synced files for repo-specific content patterns
--- Non-blocking: produces warnings only, never prevents sync
--- @param project_dir string Project directory path
--- @param all_artifacts table Map of artifact type -> array of files
--- @param audit_patterns table Array of Lua pattern strings
--- @param protected_paths table|nil Set of protected paths {[path] = true}
--- @return table matches Array of {file_path, pattern, match_count} entries
local function audit_synced_content(project_dir, all_artifacts, audit_patterns, protected_paths)
  local matches = {}
  protected_paths = protected_paths or {}

  if not audit_patterns or #audit_patterns == 0 then
    return matches
  end

  local max_file_size = 100 * 1024 -- 100KB

  for category, files in pairs(all_artifacts) do
    -- Skip internal keys (e.g., _audit_patterns)
    if type(category) == "string" and category:sub(1, 1) == "_" then
      goto next_category
    end
    if type(files) ~= "table" then
      goto next_category
    end

    for _, file in ipairs(files) do
      local local_path = file.local_path
      if not local_path then
        goto next_file
      end

      -- Skip protected files (they were not overwritten)
      if file.rel_path and protected_paths[file.rel_path] then
        goto next_file
      end

      -- Read file content
      local fh = io.open(local_path, "r")
      if not fh then
        goto next_file
      end

      -- Skip large files
      local size = fh:seek("end")
      if size and size > max_file_size then
        fh:close()
        goto next_file
      end
      fh:seek("set")

      local content = fh:read("*all")
      fh:close()
      if not content then
        goto next_file
      end

      local content_lower = content:lower()
      for _, pattern in ipairs(audit_patterns) do
        local count = 0
        local start_pos = 1
        local pattern_lower = pattern:lower()
        while true do
          local found = content_lower:find(pattern_lower, start_pos)
          if not found then
            break
          end
          count = count + 1
          start_pos = found + 1
        end
        if count > 0 then
          table.insert(matches, {
            file_path = local_path,
            pattern = pattern,
            match_count = count,
          })
        end
      end

      ::next_file::
    end

    ::next_category::
  end

  -- Sort by match count descending
  table.sort(matches, function(a, b)
    return a.match_count > b.match_count
  end)

  return matches
end

--- Scan all artifact types from global directory
--- Filters extension artifacts via manifest-driven allow-list (preferred) or blocklist (fallback)
--- to ensure only core artifacts are synced.
--- @param global_dir string Global directory path
--- @param project_dir string Project directory path
--- @param config table|nil Picker config with base_dir field (defaults to .claude config)
--- @return table Map of artifact type -> array of files
function M.scan_all_artifacts(global_dir, project_dir, config)
  local base_dir = (config and config.base_dir) or ".claude"
  local artifacts = {}

  -- Load source-side exclusions from .sync-exclude (if present)
  local sync_exclude_set, audit_patterns = load_sync_exclude(global_dir)
  local sync_exclude_array = set_to_array(sync_exclude_set)

  -- Build filtering strategy: prefer allow-list from core manifest, fall back to blocklist
  local extension_cfg = get_extension_config(base_dir, global_dir)
  local core_provides = manifest.get_core_provides(extension_cfg)
  local allow_list = core_provides and manifest.build_allow_list(core_provides) or nil
  local blocklist = manifest.aggregate_extension_artifacts(extension_cfg)

  -- For .claude base_dir, core artifact categories (agents, commands, rules, skills, etc.)
  -- are now physically located in extensions/core/ after the Phase 2 migration.
  -- We read from {global_dir}/.claude/extensions/core/{subdir} but write to
  -- {project_dir}/.claude/{subdir} to maintain the standard project layout.
  -- For .opencode, no core extension migration has occurred, so paths are unchanged.
  local core_source_base = (base_dir == ".claude") and ".claude/extensions/core" or nil

  -- Helper to scan with base_dir and filtering threaded through.
  -- When an allow-list exists for the category, files are post-filtered to only
  -- include those in the allow-list. Otherwise, falls back to blocklist exclusion.
  -- @param subdir string Subdirectory to scan
  -- @param ext string File extension pattern
  -- @param recursive boolean|nil Recursive scanning (default true)
  -- @param extra_exclude table|nil Additional exclude patterns to merge
  -- @param filter_category string|nil Which category to filter (e.g., "agents", "skills")
  -- @param use_core_source boolean|nil Read from extensions/core/ instead of base_dir root (default: true for .claude)
  local function sync_scan(subdir, ext, recursive, extra_exclude, filter_category, use_core_source)
    local exclude = extra_exclude and vim.deepcopy(extra_exclude) or {}

    -- Merge source-side exclusions from .sync-exclude
    for _, entry in ipairs(sync_exclude_array) do
      table.insert(exclude, entry)
    end

    -- Blocklist fallback: when no allow-list exists for this category
    if not allow_list or (filter_category and not allow_list[filter_category]) then
      if filter_category and blocklist[filter_category] then
        local blocklist_entries = set_to_array(blocklist[filter_category])
        for _, entry in ipairs(blocklist_entries) do
          table.insert(exclude, entry)
        end
      end
    end

    -- Determine source base: core categories use extensions/core/ as the global source
    -- (use_core_source defaults to true when core_source_base is set, false when nil)
    local source_base
    if use_core_source == false then
      source_base = nil  -- Use standard base_dir for source
    else
      source_base = core_source_base  -- nil for .opencode (no override), path for .claude
    end

    local results = scan.scan_directory_for_sync(global_dir, project_dir, subdir, ext, recursive, exclude, base_dir, nil, source_base)

    -- Allow-list post-filter: only keep files that appear in the core provides
    if allow_list and filter_category and allow_list[filter_category] then
      local allowed = allow_list[filter_category]
      local filtered = {}
      for _, file_info in ipairs(results) do
        -- For context, use prefix matching (context entries are directory names)
        if filter_category == "context" then
          local rel_name = file_info.name
          -- Extract the top-level context subdirectory from the relative path
          local rel_path = file_info.global_path:match("/context/(.+)$")
          if rel_path then
            local top_dir = rel_path:match("^([^/]+)")
            if top_dir and allowed[top_dir] then
              table.insert(filtered, file_info)
            end
          end
        else
          -- For other categories, check the filename directly
          if allowed[file_info.name] then
            table.insert(filtered, file_info)
          end
        end
      end
      return filtered
    end

    return results
  end

  -- Core artifacts common to both systems (with blocklist filtering)
  -- These categories are sourced from extensions/core/ in the global .claude directory
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
  local ctx_json = sync_scan("context", "*.json", true, CONTEXT_EXCLUDE_PATTERNS, "context")
  local ctx_yaml = sync_scan("context", "*.yaml", true, CONTEXT_EXCLUDE_PATTERNS, "context")
  artifacts.context = {}
  for _, files in ipairs({ ctx_md, ctx_json, ctx_yaml }) do
    for _, file in ipairs(files) do
      table.insert(artifacts.context, file)
    end
  end

  -- Systemd: not a core extension category; read from base_dir root (not extensions/core/)
  local systemd_service = sync_scan("systemd", "*.service", true, nil, nil, false)
  local systemd_timer = sync_scan("systemd", "*.timer", true, nil, nil, false)
  artifacts.systemd = {}
  for _, file in ipairs(systemd_service) do
    table.insert(artifacts.systemd, file)
  end
  for _, file in ipairs(systemd_timer) do
    table.insert(artifacts.systemd, file)
  end

  -- .claude-specific artifacts (directories that don't exist in .opencode/)
  -- lib and tests are not core extension categories; read from base_dir root
  if base_dir == ".claude" then
    artifacts.lib = sync_scan("lib", "*.sh", true, nil, nil, false)
    artifacts.tests = sync_scan("tests", "test_*.sh", true, nil, nil, false)
    -- Settings are not in extensions/core/; read from base_dir root
    artifacts.settings = sync_scan("", "settings.json", true, nil, nil, false)
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

  -- Store audit patterns for post-sync content audit (Phase 3)
  artifacts._audit_patterns = audit_patterns

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

  -- Migration notice: detect repos with old-style core files (pre-extension-system layout).
  -- A legacy repo has .claude/agents/ files without an extensions.json core entry.
  -- We log a notice but do not block sync -- the overwrite dialog handles conflict resolution.
  if base_dir == ".claude" then
    local agents_dir = project_dir .. "/" .. base_dir .. "/agents"
    local ext_json_path = project_dir .. "/" .. base_dir .. "/extensions.json"
    if vim.fn.isdirectory(agents_dir) == 1 then
      -- Check whether core is tracked in extensions.json
      local is_core_tracked = false
      local ext_file = io.open(ext_json_path, "r")
      if ext_file then
        local ext_content = ext_file:read("*all")
        ext_file:close()
        local ok_ext, ext_data = pcall(vim.json.decode, ext_content)
        if ok_ext and type(ext_data) == "table" and type(ext_data.extensions) == "table" then
          is_core_tracked = ext_data.extensions.core ~= nil
        end
      end
      if not is_core_tracked then
        helpers.notify(
          "Migration notice: This repo has legacy core files (pre-extension-system layout).\n"
            .. "Sync will update them to the current versions. To use the full extension\n"
            .. "system, load core via the extension picker after syncing.",
          "INFO"
        )
      end
    end
  end

  -- Count totals
  local total_files = 0
  local total_copy = 0
  local total_replace = 0

  for key, files in pairs(all_artifacts) do
    -- Skip internal metadata keys (e.g., _audit_patterns)
    if type(key) == "string" and key:sub(1, 1) == "_" then
      goto continue_count
    end
    total_files = total_files + #files
    local copy, replace = count_actions(files)
    total_copy = total_copy + copy
    total_replace = total_replace + replace
    ::continue_count::
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

  -- Load syncprotect list from target repo (if it exists)
  local protected_paths = load_syncprotect(project_dir, base_dir)

  -- Auto-seed .syncprotect if target repo has none (defense-in-depth)
  local syncprotect_path = project_dir .. "/.syncprotect"
  if vim.fn.filereadable(syncprotect_path) == 0 then
    local seed_entries = { "context/repo/project-overview.md" }
    local seed_content = "# Protected files - not overwritten during sync\n"
      .. "# Add relative paths (one per line) to protect local customizations\n"
      .. "# Paths are relative to the base directory (e.g., rules/my-rule.md)\n"
      .. "#\n"
      .. "# Note: this file lives at project root, outside the sync base directory,\n"
      .. "# so it is inherently safe from sync operations.\n"
      .. "\n"
      .. "# Repository-specific context (defense-in-depth, also in CONTEXT_EXCLUDE_PATTERNS)\n"
      .. "context/repo/project-overview.md\n"

    -- Migrate entries from legacy .claude/.syncprotect (if it exists)
    local legacy_path = project_dir .. "/" .. base_dir .. "/.syncprotect"
    if vim.fn.filereadable(legacy_path) == 1 then
      local legacy_content = helpers.read_file(legacy_path)
      if legacy_content then
        local migrated = {}
        local seed_set = {}
        for _, e in ipairs(seed_entries) do
          seed_set[e] = true
        end
        for line in legacy_content:gmatch("[^\n]+") do
          local trimmed = line:match("^%s*(.-)%s*$")
          if trimmed ~= "" and not trimmed:match("^#") and not seed_set[trimmed] then
            seed_set[trimmed] = true
            table.insert(migrated, trimmed)
          end
        end
        if #migrated > 0 then
          seed_content = seed_content .. "\n# Migrated from " .. base_dir .. "/.syncprotect\n"
          for _, entry in ipairs(migrated) do
            seed_content = seed_content .. entry .. "\n"
          end
        end
      end
    end

    helpers.write_file(syncprotect_path, seed_content)
    local msg = "Created .syncprotect with default entries"
    if vim.fn.filereadable(legacy_path) == 1 then
      msg = msg .. " (migrated legacy entries)"
    end
    helpers.notify(msg, "INFO")
    -- Re-read protected paths after seeding
    protected_paths = load_syncprotect(project_dir, base_dir)
  end

  local total_synced = execute_sync(project_dir, all_artifacts, merge_only, base_dir, protected_paths, global_dir)

  -- Post-sync content audit: check synced files for repo-specific references
  local audit_pats = all_artifacts._audit_patterns
  if audit_pats and #audit_pats > 0 and total_synced > 0 then
    local audit_matches = audit_synced_content(project_dir, all_artifacts, audit_pats, protected_paths)
    if #audit_matches > 0 then
      -- Deduplicate by file path for the summary count
      local seen_files = {}
      for _, m in ipairs(audit_matches) do
        seen_files[m.file_path] = true
      end
      local file_count = 0
      for _ in pairs(seen_files) do
        file_count = file_count + 1
      end

      -- Build notification with top 5 entries
      local lines = { string.format("Content audit: %d files contain repo-specific references", file_count) }
      local shown = 0
      for _, m in ipairs(audit_matches) do
        if shown >= 5 then
          break
        end
        -- Show relative path from project_dir for readability
        local display_path = m.file_path
        if display_path:sub(1, #project_dir + 1) == project_dir .. "/" then
          display_path = display_path:sub(#project_dir + 2)
        end
        table.insert(lines, string.format("  %s (%dx '%s')", display_path, m.match_count, m.pattern))
        shown = shown + 1
      end
      if #audit_matches > 5 then
        table.insert(lines, string.format("  ... and %d more matches", #audit_matches - 5))
      end
      table.insert(lines, "Review these files or add paths to .sync-exclude")
      helpers.notify(table.concat(lines, "\n"), "WARN")
    end
  end

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

  -- Check blocklist: block individual updates of extension-provided artifacts
  local extension_cfg = get_extension_config(base_dir, global_dir)
  local blocklist = manifest.aggregate_extension_artifacts(extension_cfg)

  -- Map singular artifact_type to plural blocklist category
  local type_to_category = {
    agent = "agents",
    skill = "skills",
    command = "commands",
    rule = "rules",
    script = "scripts",
    hook = "hooks",
    hook_event = "hooks",
  }
  local blocklist_category = type_to_category[artifact_type]
  if blocklist_category and blocklist[blocklist_category] then
    -- Check if the artifact name (with extension) is in the blocklist
    local check_name = artifact.name
    -- For types where the name doesn't include the extension, add it
    local ext_map = {
      agent = ".md", skill = ".md", command = ".md",
      rule = ".md", script = ".sh", hook = ".sh", hook_event = ".sh",
    }
    local suffix = ext_map[artifact_type] or ""
    -- Check both with and without extension suffix
    if blocklist[blocklist_category][check_name]
        or blocklist[blocklist_category][check_name .. suffix] then
      if not silent then
        helpers.notify(
          string.format(
            "Blocked: '%s' is provided by an extension and cannot be individually updated from global. "
              .. "Use the extension system to manage this artifact.",
            artifact.name
          ),
          "WARN"
        )
      end
      return false
    end
  end

  -- Also block context artifacts that match extension context directories
  if artifact_type == "context" and blocklist.context then
    for ctx_prefix, _ in pairs(blocklist.context) do
      if artifact.name:sub(1, #ctx_prefix) == ctx_prefix then
        if not silent then
          helpers.notify(
            string.format(
              "Blocked: '%s' is provided by an extension and cannot be individually updated from global.",
              artifact.name
            ),
            "WARN"
          )
        end
        return false
      end
    end
  end

  -- Check syncprotect: skip protected files with a warning
  local protected_paths = load_syncprotect(project_dir, base_dir)
  if next(protected_paths) then
    -- Build the relative path that would be checked against syncprotect
    -- For root_files: just the filename; for others: subdir/filename.ext
    local rel_check
    if artifact_type == "root_file" then
      rel_check = artifact.name
    else
      local subdir_map_check = {
        command = { dir = "commands", ext = ".md" },
        hook = { dir = "hooks", ext = ".sh" },
        hook_event = { dir = "hooks", ext = ".sh" },
        lib = { dir = "lib", ext = ".sh" },
        doc = { dir = "docs", ext = ".md" },
        template = { dir = "templates", ext = "" },
        script = { dir = "scripts", ext = ".sh" },
        test = { dir = "tests", ext = ".sh" },
        skill = { dir = "skills", ext = ".md" },
        agent = { dir = "agents", ext = ".md" },
        systemd = { dir = "systemd", ext = "" },
      }
      local tc = subdir_map_check[artifact_type]
      if tc then
        rel_check = tc.dir .. "/" .. artifact.name .. tc.ext
      end
    end
    if rel_check and protected_paths[rel_check] then
      if not silent then
        helpers.notify(
          string.format("Skipped protected file: %s (listed in .syncprotect)", rel_check),
          "WARN"
        )
      end
      return false
    end
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

--- Public wrapper for load_syncprotect, used by previewer to display protected files.
--- @param project_dir string Project directory path
--- @param base_dir string|nil Base directory name (".claude" or ".opencode")
--- @return table protected_paths Set of relative paths {[path] = true}
function M.load_syncprotect_for_preview(project_dir, base_dir)
  return load_syncprotect(project_dir, base_dir)
end

return M
