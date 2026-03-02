-- neotex.plugins.ai.claude.extensions.merge
-- Merge strategies for shared files (CLAUDE.md sections, settings.json, index.json)

local M = {}

local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

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

--- Inject a section into CLAUDE.md
--- @param target_path string Path to CLAUDE.md
--- @param section_content string Section content (without markers)
--- @param section_id string Section identifier (e.g., "extension_lean")
--- @return boolean success True if injection succeeded
--- @return table|nil tracked Tracking data for unmerge
function M.inject_claudemd_section(target_path, section_content, section_id)
  -- Create file if it doesn't exist
  if vim.fn.filereadable(target_path) ~= 1 then
    helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))
    write_file_string(target_path, "")
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

--- Remove a section from CLAUDE.md
--- @param target_path string Path to CLAUDE.md
--- @param section_id string Section identifier
--- @return boolean success True if removal succeeded
function M.remove_claudemd_section(target_path, section_id)
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
      if vim.tbl_isarray(value) then
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
--- @param target_path string Path to settings.json or settings.local.json
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
          if t[key] and vim.tbl_isarray(t[key]) then
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
    local exists = false
    for _, existing in ipairs(index.entries) do
      if existing.path == entry.path then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(index.entries, entry)
      table.insert(added_paths, entry.path)
    end
  end

  local success = write_json(target_path, index)
  if not success then
    restore_from_backup(target_path)
    return false, nil
  end

  return true, { paths = added_paths }
end

--- Remove entries from index.json by path prefix
--- @param target_path string Path to index.json
--- @param path_prefix string Path prefix to match (entries starting with this are removed)
--- @return boolean success True if removal succeeded
function M.remove_index_entries(target_path, path_prefix)
  if vim.fn.filereadable(target_path) ~= 1 then
    return true
  end

  backup_file(target_path)

  local index = read_json(target_path) or { entries = {} }
  if not index.entries then
    return true
  end

  -- Filter out entries matching prefix
  local new_entries = {}
  for _, entry in ipairs(index.entries) do
    if not entry.path:match("^" .. vim.pesc(path_prefix)) then
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

--- Merge hooks.json from extension into target
--- @param target_hooks_path string Path to target hooks.json
--- @param extension_hooks table Hooks configuration to merge
--- @return boolean success True if merge succeeded
--- @return table|nil tracked Tracking data for unmerge
function M.merge_hooks(target_hooks_path, extension_hooks)
  -- Ensure parent directory exists
  helpers.ensure_directory(vim.fn.fnamemodify(target_hooks_path, ":h"))

  -- Read existing hooks
  local target = {}
  if vim.fn.filereadable(target_hooks_path) == 1 then
    backup_file(target_hooks_path)
    target = read_json(target_hooks_path) or {}
  end

  local tracked = {}

  -- Merge hook events
  for event, hooks in pairs(extension_hooks) do
    if type(hooks) == "table" and vim.tbl_isarray(hooks) then
      if not target[event] then
        target[event] = {}
        tracked[event] = { type = "new", items = vim.deepcopy(hooks) }
      else
        tracked[event] = { type = "appended", items = {} }
      end

      for _, hook in ipairs(hooks) do
        -- Deduplicate by command
        local exists = false
        for _, existing in ipairs(target[event]) do
          if existing.command == hook.command then
            exists = true
            break
          end
        end
        if not exists then
          table.insert(target[event], hook)
          if tracked[event].type == "appended" then
            table.insert(tracked[event].items, hook)
          end
        end
      end
    end
  end

  local success = write_json(target_hooks_path, target)
  if not success then
    restore_from_backup(target_hooks_path)
    return false, nil
  end

  return true, tracked
end

--- Remove extension hooks from target
--- @param target_hooks_path string Path to target hooks.json
--- @param tracked_hooks table Tracking data from merge_hooks
--- @return boolean success True if unmerge succeeded
function M.unmerge_hooks(target_hooks_path, tracked_hooks)
  if vim.fn.filereadable(target_hooks_path) ~= 1 then
    return true
  end

  if not tracked_hooks then
    return true
  end

  backup_file(target_hooks_path)

  local target = read_json(target_hooks_path) or {}

  for event, info in pairs(tracked_hooks) do
    if info.type == "new" then
      -- Remove entire event
      target[event] = nil
    elseif info.type == "appended" and info.items then
      -- Remove only appended hooks
      if target[event] then
        for _, hook in ipairs(info.items) do
          for i = #target[event], 1, -1 do
            if target[event][i].command == hook.command then
              table.remove(target[event], i)
              break
            end
          end
        end
        -- Clean up empty arrays
        if #target[event] == 0 then
          target[event] = nil
        end
      end
    end
  end

  local success = write_json(target_hooks_path, target)
  if not success then
    restore_from_backup(target_hooks_path)
    return false
  end

  return true
end

return M
