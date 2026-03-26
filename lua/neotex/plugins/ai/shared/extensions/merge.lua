-- neotex.plugins.ai.shared.extensions.merge
-- Merge strategies for shared files (parameterized for claude/opencode)

local M = {}

local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Normalize index entry path by stripping known bad prefixes
--- Handles three prefix conventions that have appeared in source index-entries.json files:
--- 1. ".claude/extensions/*/context/" or ".opencode/extensions/*/context/" (full path)
--- 2. "context/" (partial path from within extension directory)
--- 3. "project/" or "core/" (correct, left unchanged)
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

--- Read file contents as string
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

--- Write string to file
--- @param filepath string Path to file
--- @param content string Content to write
--- @return boolean success True if write succeeded
local function write_file_string(filepath, content)
  local file = io.open(filepath, "w")
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
end

--- Read JSON file
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

--- Write JSON file with pretty printing
--- @param filepath string Path to JSON file
--- @param data table Data to write
--- @return boolean success True if write succeeded
local function write_json(filepath, data)
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return false
  end

  -- Try to pretty print with jq
  local formatted = vim.fn.system('echo ' .. vim.fn.shellescape(encoded) .. ' | jq .', '')
  if vim.v.shell_error ~= 0 then
    formatted = encoded
  end

  return write_file_string(filepath, formatted)
end

--- Create backup of a file
--- @param filepath string Path to file
--- @return boolean success True if backup created
local function backup_file(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return true  -- No file to backup
  end
  local backup_path = filepath .. ".backup"
  local content = read_file_string(filepath)
  if content then
    return write_file_string(backup_path, content)
  end
  return false
end

--- Restore file from backup
--- @param filepath string Path to file
--- @return boolean success True if restore succeeded
local function restore_from_backup(filepath)
  local backup_path = filepath .. ".backup"
  if vim.fn.filereadable(backup_path) ~= 1 then
    return false
  end
  local content = read_file_string(backup_path)
  if content then
    return write_file_string(filepath, content)
  end
  return false
end

--- Generate section markers
--- @param section_id string Section identifier
--- @return string start_marker Start marker
--- @return string end_marker End marker
local function get_section_markers(section_id)
  local start_marker = "<!-- SECTION: " .. section_id .. " -->"
  local end_marker = "<!-- END_SECTION: " .. section_id .. " -->"
  return start_marker, end_marker
end

--- Inject a section into a config markdown file (CLAUDE.md, AGENTS.md, or OPENCODE.md)
--- @param target_path string Path to config file
--- @param section_content string Section content (without markers)
--- @param section_id string Section identifier
--- @return boolean success True if injection succeeded
--- @return table|nil tracked Tracking data for unmerge
function M.inject_section(target_path, section_content, section_id)
  -- Create file if it doesn't exist, seeding from sibling README.md to preserve
  -- core content. This defends against content loss when extensions are reloaded
  -- and the target file has been deleted or is missing.
  if vim.fn.filereadable(target_path) ~= 1 then
    helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))
    local target_dir = vim.fn.fnamemodify(target_path, ":h")
    local readme_path = target_dir .. "/README.md"
    local seed_content = ""
    if vim.fn.filereadable(readme_path) == 1 then
      seed_content = read_file_string(readme_path) or ""
    end
    write_file_string(target_path, seed_content)
  end

  -- Backup the file
  backup_file(target_path)

  local content = read_file_string(target_path) or ""
  local start_marker, end_marker = get_section_markers(section_id)

  -- Check if section already exists (idempotent)
  if content:find(start_marker, 1, true) then
    -- Section exists, update it
    local pattern = vim.pesc(start_marker) .. ".-" .. vim.pesc(end_marker)
    local new_section = start_marker .. "\n" .. section_content .. "\n" .. end_marker
    content = content:gsub(pattern, new_section)
  else
    -- Add section at the end
    local new_section = "\n" .. start_marker .. "\n" .. section_content .. "\n" .. end_marker .. "\n"
    content = content .. new_section
  end

  local success = write_file_string(target_path, content)
  if not success then
    restore_from_backup(target_path)
    return false, nil
  end

  return true, { section_id = section_id }
end

--- Remove a section from a config markdown file
--- @param target_path string Path to config file
--- @param section_id string Section identifier
--- @return boolean success True if removal succeeded
function M.remove_section(target_path, section_id)
  if vim.fn.filereadable(target_path) ~= 1 then
    return true  -- Nothing to remove
  end

  backup_file(target_path)

  local content = read_file_string(target_path) or ""
  local start_marker, end_marker = get_section_markers(section_id)

  -- Remove section including markers and surrounding newlines
  local pattern = "\n?" .. vim.pesc(start_marker) .. ".-" .. vim.pesc(end_marker) .. "\n?"
  content = content:gsub(pattern, "\n")

  -- Clean up multiple consecutive newlines
  content = content:gsub("\n\n\n+", "\n\n")

  local success = write_file_string(target_path, content)
  if not success then
    restore_from_backup(target_path)
    return false
  end

  return true
end

--- Deep merge two tables (arrays are appended, objects merged)
--- @param target table Target table (modified in place)
--- @param source table Source table to merge from
--- @param tracked table Table to track added entries
--- @return table target Modified target table
local function deep_merge(target, source, tracked)
  for key, value in pairs(source) do
    if type(value) == "table" then
      if vim.isarray(value) then
        -- Array: append elements, track what we added
        if target[key] == nil then
          target[key] = {}
          tracked[key] = { type = "new_array", items = {} }
        elseif not tracked[key] then
          tracked[key] = { type = "appended", items = {} }
        end

        for _, item in ipairs(value) do
          -- Deduplicate
          local exists = false
          for _, existing in ipairs(target[key]) do
            if vim.deep_equal(existing, item) then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(target[key], item)
            table.insert(tracked[key].items, item)
          end
        end
      else
        -- Object: recurse
        if target[key] == nil then
          target[key] = {}
          tracked[key] = { type = "new_object", children = {} }
        elseif not tracked[key] then
          tracked[key] = { type = "merged", children = {} }
        end
        deep_merge(target[key], value, tracked[key].children or tracked[key])
      end
    else
      -- Scalar: only add if not exists (don't overwrite)
      if target[key] == nil then
        target[key] = value
        tracked[key] = { type = "new_value", value = value }
      end
    end
  end
  return target
end

--- Merge settings fragment into target settings file
--- @param target_path string Path to settings file
--- @param fragment table Settings fragment to merge
--- @return boolean success True if merge succeeded
--- @return table|nil tracked Tracking data for unmerge
function M.merge_settings(target_path, fragment)
  -- Ensure parent directory exists
  helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))

  -- Create file if it doesn't exist
  local target = {}
  if vim.fn.filereadable(target_path) == 1 then
    backup_file(target_path)
    target = read_json(target_path) or {}
  end

  -- Track what we add
  local tracked = {}

  -- Deep merge
  deep_merge(target, fragment, tracked)

  -- Validate result is valid JSON by re-encoding
  local ok = pcall(vim.json.encode, target)
  if not ok then
    restore_from_backup(target_path)
    return false, nil
  end

  local success = write_json(target_path, target)
  if not success then
    restore_from_backup(target_path)
    return false, nil
  end

  return true, tracked
end

--- Remove entries that were added by merge_settings
--- @param target_path string Path to settings file
--- @param tracked_entries table Tracking data from merge_settings
--- @return boolean success True if unmerge succeeded
function M.unmerge_settings(target_path, tracked_entries)
  if vim.fn.filereadable(target_path) ~= 1 then
    return true
  end

  backup_file(target_path)

  local target = read_json(target_path) or {}

  -- Recursive function to remove tracked entries
  local function remove_tracked(t, track)
    for key, info in pairs(track) do
      if type(info) == "table" and info.type then
        if info.type == "new_array" or info.type == "new_object" or info.type == "new_value" then
          -- Remove entirely
          t[key] = nil
        elseif info.type == "appended" and info.items then
          -- Remove only appended items
          if t[key] and vim.isarray(t[key]) then
            for _, item in ipairs(info.items) do
              for i = #t[key], 1, -1 do
                if vim.deep_equal(t[key][i], item) then
                  table.remove(t[key], i)
                  break
                end
              end
            end
          end
        elseif info.type == "merged" and info.children then
          -- Recurse
          if t[key] then
            remove_tracked(t[key], info.children)
          end
        end
      elseif type(info) == "table" then
        -- Old format or nested tracking
        if t[key] then
          remove_tracked(t[key], info)
        end
      end
    end
  end

  remove_tracked(target, tracked_entries)

  local success = write_json(target_path, target)
  if not success then
    restore_from_backup(target_path)
    return false
  end

  return true
end

--- Append entries to index.json
--- @param target_path string Path to index.json
--- @param entries table Array of entries to append
--- @return boolean success True if append succeeded
--- @return table|nil tracked Tracking data for removal
function M.append_index_entries(target_path, entries)
  -- Ensure parent directory exists
  helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))

  -- Create or read index
  local index = { entries = {} }
  if vim.fn.filereadable(target_path) == 1 then
    backup_file(target_path)
    index = read_json(target_path) or { entries = {} }
    if not index.entries then
      index.entries = {}
    end
  end

  -- Track added paths
  local added_paths = {}

  -- Append entries (deduplicate by path)
  for _, entry in ipairs(entries) do
    -- Normalize path before deduplication and insertion (defense-in-depth)
    local normalized_path = normalize_index_path(entry.path)
    entry.path = normalized_path

    local exists = false
    for _, existing in ipairs(index.entries) do
      if existing.path == normalized_path then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(index.entries, entry)
      table.insert(added_paths, normalized_path)
    end
  end

  local success = write_json(target_path, index)
  if not success then
    restore_from_backup(target_path)
    return false, nil
  end

  return true, { paths = added_paths }
end

--- Remove index entries by tracked paths
--- @param target_path string Path to index.json
--- @param tracked table Tracking data from append_index_entries
--- @return boolean success True if removal succeeded
function M.remove_index_entries_tracked(target_path, tracked)
  if vim.fn.filereadable(target_path) ~= 1 then
    return true
  end

  if not tracked or not tracked.paths then
    return true
  end

  backup_file(target_path)

  local index = read_json(target_path) or { entries = {} }
  if not index.entries then
    return true
  end

  -- Create set of paths to remove
  local paths_to_remove = {}
  for _, path in ipairs(tracked.paths) do
    paths_to_remove[path] = true
  end

  -- Filter entries
  local new_entries = {}
  for _, entry in ipairs(index.entries) do
    if not paths_to_remove[entry.path] then
      table.insert(new_entries, entry)
    end
  end
  index.entries = new_entries

  local success = write_json(target_path, index)
  if not success then
    restore_from_backup(target_path)
    return false
  end

  return true
end

--- Remove index entries whose path starts with any of the given prefixes
--- Used for cleaning orphaned entries that bypass tracked append/remove
--- @param target_path string Path to index.json
--- @param prefixes table Array of path prefixes to match (e.g., {"project/lean4"})
--- @return boolean success True if removal succeeded
--- @return number removed_count Number of entries removed
function M.remove_index_entries_by_prefix(target_path, prefixes)
  if vim.fn.filereadable(target_path) ~= 1 then
    return true, 0
  end

  local index = read_json(target_path)
  if not index or not index.entries then
    return true, 0
  end

  -- Normalize prefixes to ensure trailing slash for safe matching
  local normalized = {}
  for _, prefix in ipairs(prefixes) do
    if prefix:sub(-1) ~= "/" then
      table.insert(normalized, prefix .. "/")
    else
      table.insert(normalized, prefix)
    end
  end

  backup_file(target_path)

  -- Filter entries: keep those that do NOT match any prefix
  local new_entries = {}
  local removed_count = 0
  for _, entry in ipairs(index.entries) do
    local dominated = false
    for _, prefix in ipairs(normalized) do
      if entry.path and entry.path:sub(1, #prefix) == prefix then
        dominated = true
        break
      end
    end
    if dominated then
      removed_count = removed_count + 1
    else
      table.insert(new_entries, entry)
    end
  end

  if removed_count == 0 then
    return true, 0
  end

  index.entries = new_entries

  local ok = write_json(target_path, index)
  if not ok then
    restore_from_backup(target_path)
    return false, 0
  end

  return true, removed_count
end

--- Merge opencode.json agent definitions
--- Adds agent definitions from fragment to target opencode.json.
--- Only adds keys that don't already exist (no overwrite).
--- @param target_path string Path to opencode.json
--- @param fragment table Fragment with agent definitions {agent = {...}}
--- @return boolean success True if merge succeeded
--- @return table|nil tracked Tracking data for unmerge {keys = {...}}
function M.merge_opencode_agents(target_path, fragment)
  -- Ensure parent directory exists
  helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))

  -- Read or create target opencode.json
  local target = {}
  if vim.fn.filereadable(target_path) == 1 then
    backup_file(target_path)
    target = read_json(target_path) or {}
  end

  -- Ensure agent section exists
  if not target.agent then
    target.agent = {}
  end

  -- Track added keys for unmerge
  local added_keys = {}

  -- Get agent definitions from fragment (handle both {agent = {...}} and bare {...} formats)
  local source_agents = fragment.agent or (type(fragment) == "table" and not vim.isarray(fragment) and fragment) or {}

  -- Add each agent key if it doesn't exist
  for key, value in pairs(source_agents) do
    if target.agent[key] == nil then
      target.agent[key] = value
      table.insert(added_keys, key)
    end
  end

  -- Write updated opencode.json
  local success = write_json(target_path, target)
  if not success then
    restore_from_backup(target_path)
    return false, nil
  end

  return true, { keys = added_keys }
end

--- Unmerge opencode.json agent definitions
--- Removes agent keys that were previously added by merge_opencode_agents.
--- @param target_path string Path to opencode.json
--- @param tracked table Tracking data from merge_opencode_agents {keys = {...}}
--- @return boolean success True if unmerge succeeded
function M.unmerge_opencode_agents(target_path, tracked)
  if vim.fn.filereadable(target_path) ~= 1 then
    return true  -- Nothing to unmerge
  end

  if not tracked or not tracked.keys then
    return true  -- Nothing to unmerge
  end

  backup_file(target_path)

  local target = read_json(target_path) or {}
  if not target.agent then
    return true  -- No agent section
  end

  -- Remove tracked keys
  for _, key in ipairs(tracked.keys) do
    target.agent[key] = nil
  end

  local success = write_json(target_path, target)
  if not success then
    restore_from_backup(target_path)
    return false
  end

  return true
end

return M
