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
function M.write_json(filepath, data)
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

  local content = read_file_string(target_path) or ""
  local start_marker, end_marker = get_section_markers(section_id)

  -- Remove section including markers and surrounding newlines
  local pattern = "\n?" .. vim.pesc(start_marker) .. ".-" .. vim.pesc(end_marker) .. "\n?"
  content = content:gsub(pattern, "\n")

  -- Clean up multiple consecutive newlines
  content = content:gsub("\n\n\n+", "\n\n")

  local success = write_file_string(target_path, content)
  if not success then
    return false
  end

  return true
end

--- Check whether an array is shaped like a Claude Code hook-event array
--- (e.g. the value of settings.json's "Stop", "PreToolUse", etc.): a
--- non-empty array in which every item is a table carrying both a `matcher`
--- (string) key and an array-valued `hooks` key. This predicate is the sole
--- gate for the matcher-aware merge behavior below -- any other array shape
--- (e.g. `permissions.allow`'s flat string array, or `mcpServers`, which is
--- an object, not an array) falls through to the existing whole-item
--- vim.deep_equal merge in deep_merge(), untouched.
--- @param arr any Candidate value to test
--- @return boolean is_hook_array True if arr is a non-empty hook-event array
local function is_hook_event_array(arr)
  if type(arr) ~= "table" or not vim.isarray(arr) or #arr == 0 then
    return false
  end
  for _, item in ipairs(arr) do
    if
      type(item) ~= "table"
      or type(item.matcher) ~= "string"
      or type(item.hooks) ~= "table"
      or not vim.isarray(item.hooks)
    then
      return false
    end
  end
  return true
end

--- Resolve a hook's registration IDENTITY: the invoked hook script's basename (`NAME.sh`)
--- paired with the hook's own `type`, for a command recognizable as a `.claude/hooks/NAME.sh`
--- invocation -- whether CWD-relative (`bash .claude/hooks/NAME.sh`, the stale form) or the
--- fixed `$CLAUDE_PROJECT_DIR`-prefixed form (`bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/NAME.sh`),
--- and whether that invocation is bare or nested inside a `bash -c '...'` wrapper (the pattern
--- matches the substring anywhere in `command`, so nesting is transparent to it).
---
--- Returns nil for any command NOT recognizable in this shape -- a hand-written custom hook
--- (one that does not invoke a `.claude/hooks/*.sh` path at all) MUST NEVER be touched, moved,
--- or deduped by identity; this carve-out is mandatory, not best-effort, and every caller below
--- falls through to exact `vim.deep_equal` comparison whenever this returns nil.
---
--- WHY this exists: `vim.deep_equal(existing, hook)` on the whole `{type, command}` object is
--- the defect this function fixes. When a command string changes (e.g. the CWD-relative stale
--- form rewritten to the `$CLAUDE_PROJECT_DIR`-prefixed fixed form), the two objects no longer
--- compare equal, so the "already present?" check below used to say no and the new entry was
--- APPENDED BESIDE the stale one rather than replacing it -- confirmed in production: a real
--- redeploy against an already-deployed repo left stale and fixed registrations of the same
--- hook coexisting, both firing, the stale one still failing open. Identity (what hook script
--- this registration invokes) is the stable thing across that kind of command-string edit; the
--- exact command string is not.
--- @param hook table Hook object (`{type=, command=, [timeout=]}`)
--- @return string|nil identity `"<type>:<NAME.sh>"`, or nil when not identity-eligible
local function hook_identity(hook)
  if type(hook) ~= "table" or type(hook.command) ~= "string" or type(hook.type) ~= "string" then
    return nil
  end
  local name = hook.command:match("%.claude/hooks/([%w_%-]+%.sh)")
  if not name then
    return nil
  end
  return hook.type .. ":" .. name
end

--- Locate `hook` within `hooks` (an array of hook objects): by `hook_identity()` when `hook` is
--- identity-eligible (see that function's doc for the mandatory custom-hook carve-out), or by
--- exact `vim.deep_equal` otherwise. This is the single lookup both `normalize_hook_event_array`
--- and `merge_hook_event_array` use, so the two functions' "already present?" semantics can
--- never drift apart.
--- @param hooks table Array of hook objects to search
--- @param hook table Hook object to locate
--- @return integer|nil index 1-based index of the match in `hooks`, or nil if not found
local function find_hook_match(hooks, hook)
  local identity = hook_identity(hook)
  for i, existing in ipairs(hooks) do
    if identity ~= nil then
      if hook_identity(existing) == identity then
        return i
      end
    elseif vim.deep_equal(existing, hook) then
      return i
    end
  end
  return nil
end

--- Normalize a hook-event array so each distinct `matcher` value appears exactly once, with
--- that matcher's `hooks` entries concatenated in first-appearance order and individually
--- deduplicated via `find_hook_match` -- identity-based for a `.claude/hooks/*.sh` invocation
--- (REPLACING an earlier same-identity entry's command with the later one's, so a stale+fixed
--- pair already sitting in the same matcher block collapses to the later, presumably-corrected
--- occurrence), exact `vim.deep_equal` otherwise (a true duplicate, or any hand-written custom
--- hook -- never touched beyond the exact-duplicate check). Matchers are compared by exact
--- string equality only -- never by substring or pattern. Idempotent: normalizing an
--- already-normalized, already-converged array returns an equal array (every hook's match is
--- itself, `vim.deep_equal`-identical, so the "replace" is a same-value no-op).
---
--- Normalization is deliberately NOT reversed by unmerge_settings(): it is semantically neutral
--- (Claude Code runs every matching block regardless of how many blocks share a matcher), it is
--- idempotent, and restoring the pre-normalization block split on unload would reintroduce the
--- exact duplication hazard this function exists to close.
--- @param arr table Hook-event array (expected to satisfy is_hook_event_array)
--- @return table normalized New array, one block per distinct matcher, in
---   first-appearance order
local function normalize_hook_event_array(arr)
  local normalized = {}
  local index_by_matcher = {}
  for _, block in ipairs(arr) do
    local idx = index_by_matcher[block.matcher]
    if not idx then
      idx = #normalized + 1
      normalized[idx] = { matcher = block.matcher, hooks = {} }
      index_by_matcher[block.matcher] = idx
    end
    for _, hook in ipairs(block.hooks) do
      local match_idx = find_hook_match(normalized[idx].hooks, hook)
      if match_idx == nil then
        table.insert(normalized[idx].hooks, hook)
      else
        normalized[idx].hooks[match_idx] = hook
      end
    end
  end
  return normalized
end

--- Merge a source hook-event array into a (pre-normalized) target hook-event array by
--- `matcher`. For each source block: if a target block with an equal `matcher` already exists,
--- resolve each of the source block's hook entries against that target block's `hooks` array via
--- `find_hook_match` --
---   * no match: APPEND the source hook as a new entry (tracked in `hook_items`, exactly as
---     before).
---   * identity match with a DIFFERENT command (or other field): REPLACE the target's entry with
---     the source's IN PLACE, rather than appending beside it -- this is the fix for the
---     production defect `hook_identity`'s doc describes: a changed command string no longer
---     compared `vim.deep_equal`, so the stale entry was never recognized as "already present"
---     and a duplicate accumulated instead of a replacement. The replacement is tracked into the
---     SAME `hook_items` list, under the SAME `{matcher=, hook=<new hook>}` shape an append uses
---     -- deliberately, so `unmerge_settings` needs no new branch: on unload, it already finds
---     and removes a hook `vim.deep_equal` to the tracked (new) one, which is exactly "undo what
---     this merge changed" for a replacement too. It never resurrects the stale command that was
---     replaced; resurrecting it would reintroduce the very defect this closes.
---   * identity match (or exact match) already `vim.deep_equal`: no-op, untracked -- fully
---     idempotent, matching `normalize_hook_event_array`'s idempotency.
--- Otherwise (no target block for this matcher at all): append the whole source block as a new
--- matcher block, as before.
--- @param target_arr table Target hook-event array, modified in place
--- @param source_arr table Source hook-event array to merge in
--- @return table tracked `{ items = {<whole blocks appended>}, hook_items =
---   { { matcher = <string>, hook = <hook object> }, ... } }`
local function merge_hook_event_array(target_arr, source_arr)
  local tracked = { items = {}, hook_items = {} }
  for _, source_block in ipairs(source_arr) do
    local target_block = nil
    for _, block in ipairs(target_arr) do
      if block.matcher == source_block.matcher then
        target_block = block
        break
      end
    end
    if target_block then
      for _, hook in ipairs(source_block.hooks) do
        local match_idx = find_hook_match(target_block.hooks, hook)
        if match_idx == nil then
          table.insert(target_block.hooks, hook)
          table.insert(tracked.hook_items, { matcher = source_block.matcher, hook = hook })
        elseif not vim.deep_equal(target_block.hooks[match_idx], hook) then
          target_block.hooks[match_idx] = hook
          table.insert(tracked.hook_items, { matcher = source_block.matcher, hook = hook })
        end
      end
    else
      table.insert(target_arr, source_block)
      table.insert(tracked.items, source_block)
    end
  end
  return tracked
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
        if
          is_hook_event_array(value)
          and (
            target[key] == nil
            or (
              type(target[key]) == "table"
              and (vim.tbl_isempty(target[key]) or is_hook_event_array(target[key]))
            )
          )
        then
          -- Hook-event array (Stop, PreToolUse, etc.): normalize the
          -- target's existing blocks by matcher, then merge the source
          -- array by matcher instead of whole-item vim.deep_equal. This
          -- heals pre-existing same-matcher duplication (e.g. a stray
          -- second "*" block on Stop) and prevents new duplication of that
          -- class from ever landing again.
          if target[key] == nil then
            target[key] = {}
          end
          target[key] = normalize_hook_event_array(target[key])
          local hook_tracked = merge_hook_event_array(target[key], value)
          tracked[key] = {
            type = "hook_merged",
            items = hook_tracked.items,
            hook_items = hook_tracked.hook_items,
          }
        else
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
    target = read_json(target_path) or {}
  end

  -- Track what we add
  local tracked = {}

  -- Deep merge
  deep_merge(target, fragment, tracked)

  -- Validate result is valid JSON by re-encoding
  local ok = pcall(vim.json.encode, target)
  if not ok then
    return false, nil
  end

  local success = M.write_json(target_path, target)
  if not success then
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
        elseif info.type == "hook_merged" then
          -- Hook-event array (Stop, PreToolUse, etc.) merged by matcher via
          -- merge_hook_event_array(). Reverse both halves of what it tracked:
          if t[key] and vim.isarray(t[key]) then
            -- 1. Whole matcher blocks appended because no matching target
            --    block existed -- same removal as the "appended" branch.
            if info.items then
              for _, item in ipairs(info.items) do
                for i = #t[key], 1, -1 do
                  if vim.deep_equal(t[key][i], item) then
                    table.remove(t[key], i)
                    break
                  end
                end
              end
            end
            -- 2. Individual hook entries injected into a pre-existing
            --    matcher block -- located by matcher, removed by
            --    vim.deep_equal on the hook object.
            if info.hook_items then
              for _, hook_item in ipairs(info.hook_items) do
                for _, block in ipairs(t[key]) do
                  if block.matcher == hook_item.matcher and type(block.hooks) == "table" then
                    for i = #block.hooks, 1, -1 do
                      if vim.deep_equal(block.hooks[i], hook_item.hook) then
                        table.remove(block.hooks, i)
                        break
                      end
                    end
                  end
                end
              end
            end
            -- A matcher block left with no hooks after (2) is removed
            -- entirely. If that empties the event array, an empty array is
            -- left behind rather than deleting the key -- matching the
            -- existing "appended" behavior above.
            for i = #t[key], 1, -1 do
              local block = t[key][i]
              if type(block) == "table" and type(block.hooks) == "table" and #block.hooks == 0 then
                table.remove(t[key], i)
              end
            end
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

  local success = M.write_json(target_path, target)
  if not success then
    return false
  end

  return true
end

--- Append (upsert) entries to index.json
---
--- UPSERT, not append-only: if an entry's `path` already exists in the target index, its
--- object is REPLACED in place (position preserved, for a stable/diffable ordering on repeat
--- redeploys); a new path is appended as before. This is a deliberate behavior change from the
--- prior skip-if-exists semantics -- under skip-if-exists, a corrected/updated source entry
--- (e.g. a regenerated `line_count`) could never reach an already-populated deployed
--- `.claude/context/index.json`, since every subsequent merge would see the path as "already
--- present" and silently discard the update. `.claude/context/index.json` is itself a generated
--- deploy artifact (see .claude/rules/source-store-deploy-boundary.md), so overwriting a
--- deployed entry from its current source declaration is the intended direction; the source
--- `agent-system/extensions/*/index-entries.json` files remain the sole authored truth.
---
--- Also stamps the index's top-level `generated` (current UTC ISO8601 timestamp, refreshed on
--- every write) and `version` (semver; set to "1.0.0" the first time the index is created, left
--- untouched thereafter -- neither field was ever written before this change; both are optional
--- top-level properties already declared by index.schema.json).
---
--- Known dormant risk: a handful of paths are declared by more than one extension's
--- index-entries.json today (three `contracts/*.md` paths shared between `core` and `lean`, as
--- intentional lean4-specific overrides of core's generic contract content, not accidental
--- duplicates). Under upsert, whichever extension's merge_targets.index is processed LAST for a
--- given load/sync run wins for that path, replacing the prior extension's entry. This is an
--- improvement over skip-if-exists (which could silently drop a legitimate override forever,
--- depending on load order) but is still not an explicit override-priority mechanism. Currently
--- dormant: `lean` is not a loaded extension in this repository, so no collision fires in
--- practice. Resolving load-order-independent override priority is out of scope here.
---
--- @param target_path string Path to index.json
--- @param entries table Array of entries to append/upsert
--- @return boolean success True if append succeeded
--- @return table|nil tracked Tracking data for removal
function M.append_index_entries(target_path, entries)
  -- Ensure parent directory exists
  helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))

  -- Create or read index
  local index = { entries = {} }
  if vim.fn.filereadable(target_path) == 1 then
    index = read_json(target_path) or { entries = {} }
    if not index.entries then
      index.entries = {}
    end
  end

  -- Track added/updated paths (both count toward the tracked set consumed by
  -- remove_index_entries_tracked on unload)
  local added_paths = {}

  -- Upsert entries: replace-in-place if the path already exists (preserving array position),
  -- append if it does not.
  for _, entry in ipairs(entries) do
    -- Normalize path before dedupe/insertion (defense-in-depth)
    local normalized_path = normalize_index_path(entry.path)
    entry.path = normalized_path

    local replaced = false
    for idx, existing in ipairs(index.entries) do
      if existing.path == normalized_path then
        index.entries[idx] = entry
        replaced = true
        break
      end
    end
    if not replaced then
      table.insert(index.entries, entry)
    end
    table.insert(added_paths, normalized_path)
  end

  -- Stamp version/generated. version is set once and left untouched thereafter; generated is
  -- refreshed on every write so staleness is always detectable.
  if not index.version then
    index.version = "1.0.0"
  end
  index.generated = os.date("!%Y-%m-%dT%H:%M:%SZ")

  local success = M.write_json(target_path, index)
  if not success then
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

  local success = M.write_json(target_path, index)
  if not success then
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

  local ok = M.write_json(target_path, index)
  if not ok then
    return false, 0
  end

  return true, removed_count
end

--- Remove orphaned index entries from non-loaded extensions
--- Called before extension entries are appended to clean stale entries from previous loads.
--- Keeps: entries not under "project/" (core/other) and entries matching valid prefixes
--- whose files exist on disk.
--- @param index_path string Path to index.json
--- @param valid_prefixes table Array of path prefixes from loaded extensions' provides.context
--- @param context_dir string|nil Optional context directory for file existence checks
--- @return boolean success True if cleanup succeeded
--- @return number removed_count Number of entries removed
function M.remove_orphaned_index_entries(index_path, valid_prefixes, context_dir)
  if vim.fn.filereadable(index_path) ~= 1 then
    return true, 0
  end

  local index = read_json(index_path)
  if not index or not index.entries then
    return true, 0
  end

  -- Normalize prefixes to ensure trailing slash for safe matching
  local normalized = {}
  for _, prefix in ipairs(valid_prefixes) do
    if prefix:sub(-1) ~= "/" then
      table.insert(normalized, prefix .. "/")
    else
      table.insert(normalized, prefix)
    end
  end

  -- Filter entries: keep non-project entries and those matching valid prefixes
  local new_entries = {}
  local removed_count = 0
  for _, entry in ipairs(index.entries) do
    if not entry.path or entry.path:sub(1, 8) ~= "project/" then
      -- Not a project entry (core, or no path) -- always keep
      table.insert(new_entries, entry)
    else
      -- Project entry -- keep only if it matches a valid prefix
      local matched = false
      for _, prefix in ipairs(normalized) do
        if entry.path:sub(1, #prefix) == prefix then
          matched = true
          break
        end
      end
      if matched then
        -- Verify file exists on disk if context_dir provided
        if context_dir and entry.path then
          local file_path = context_dir .. "/" .. entry.path
          if not vim.loop.fs_stat(file_path) then
            matched = false
          end
        end
      end
      if matched then
        table.insert(new_entries, entry)
      else
        removed_count = removed_count + 1
      end
    end
  end

  if removed_count == 0 then
    return true, 0
  end

  index.entries = new_entries

  local ok = M.write_json(index_path, index)
  if not ok then
    return false, 0
  end

  return true, removed_count
end

--- Generate CLAUDE.md (or equivalent config markdown) as a fully computed artifact.
--- Starts from a header template, then appends each loaded extension's claudemd source
--- content in dependency order (core first, then extensions sorted by load order).
---
--- This replaces the section-injection approach: the generated file has no section
--- markers and is fully deterministic given the set of loaded extensions.
---
--- @param project_dir string Project directory
--- @param config table Extension system configuration (needs base_dir, merge_target_key,
---   global_extensions_dir, state_file)
--- @return boolean success True if generation succeeded
--- @return string|nil error Error message if generation failed
function M.generate_claudemd(project_dir, config)
  -- Lazy-require to avoid circular deps (manifest/state require helpers, not merge)
  local state_mod = require("neotex.plugins.ai.shared.extensions.state")
  local manifest_mod = require("neotex.plugins.ai.shared.extensions.manifest")

  local target_dir = project_dir .. "/" .. config.base_dir
  local merge_key = config.merge_target_key  -- "claudemd" or "opencode_md"

  -- Determine the target CLAUDE.md path from state or fallback convention.
  -- We derive it from the first loaded extension that declares a claudemd target,
  -- falling back to a sensible default.
  local target_path = nil
  local header_template_path = nil

  -- Find the target path from loaded extensions' manifests
  local state = state_mod.read(project_dir, config)
  local loaded_names = state_mod.list_loaded(state)

  -- Build dependency-ordered list: core always first, then others
  local ordered_names = {}
  local seen = {}

  -- Core goes first
  for _, name in ipairs(loaded_names) do
    if name == "core" then
      table.insert(ordered_names, name)
      seen[name] = true
      break
    end
  end

  -- Remaining extensions in sorted order (stable ordering)
  for _, name in ipairs(loaded_names) do
    if not seen[name] then
      table.insert(ordered_names, name)
      seen[name] = true
    end
  end

  -- Collect content fragments
  local fragments = {}

  for _, ext_name in ipairs(ordered_names) do
    local extension = manifest_mod.get_extension(ext_name, config)
    if extension and extension.manifest and extension.manifest.merge_targets then
      local mt = extension.manifest.merge_targets[merge_key]
      if mt and mt.source and mt.target then
        -- Resolve target path (use the first one found; all should agree)
        if not target_path then
          target_path = project_dir .. "/" .. mt.target
        end

        -- For core: also find the header template
        if ext_name == "core" and not header_template_path then
          -- Header template lives in core's templates/ directory
          local core_templates_dir = extension.path .. "/templates"
          local candidate = core_templates_dir .. "/claudemd-header.md"
          if vim.fn.filereadable(candidate) == 1 then
            header_template_path = candidate
          end
        end

        -- Read source fragment
        local source_path = extension.path .. "/" .. mt.source
        local content = read_file_string(source_path)
        if content then
          table.insert(fragments, content)
        end
      end
    end
  end

  -- If no fragments (no loaded extensions with claudemd targets), nothing to generate
  if #fragments == 0 then
    return true, nil
  end

  -- If no target_path found, we cannot write
  if not target_path then
    return false, "generate_claudemd: could not determine target path from loaded extensions"
  end

  -- Build output: header + fragments
  local parts = {}

  -- Prepend header template if found
  if header_template_path then
    local header = read_file_string(header_template_path)
    if header then
      table.insert(parts, header)
    end
  end

  -- Append each fragment (ensure separation)
  for _, fragment in ipairs(fragments) do
    -- Strip any trailing whitespace/newlines from fragment, then add two newlines
    local trimmed = fragment:gsub("%s+$", "")
    table.insert(parts, trimmed)
  end

  local output = table.concat(parts, "\n\n") .. "\n"

  -- Ensure parent directory exists
  helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))

  local success = write_file_string(target_path, output)
  if not success then
    return false, "generate_claudemd: failed to write " .. target_path
  end

  return true, nil
end

--- Validate that all {file:...} references in an opencode fragment point to existing files.
--- Iterates over agent entries and checks each prompt that uses {file:PATH} syntax, collecting
--- EVERY missing reference (not just the first) so a caller gets the full, deterministic extent
--- of a fragment's breakage in one report instead of one nondeterministic %pairs()%-order name
--- per invocation.
--- @param fragment table Fragment with agent definitions {agent = {...}}
--- @param project_dir string Project directory for resolving relative paths
--- @return boolean valid True if all references exist
--- @return string|nil error Single message enumerating every missing reference, sorted by agent
---   name for deterministic output across repeated runs; nil when valid is true
--- @return table|nil missing_by_key Map of agent_name -> missing file_path for every agent whose
---   {file:...} reference failed to resolve; nil when valid is true. Callers needing per-key
---   degradation (see M.generate_opencode_json) consume this directly instead of re-parsing the
---   error message string.
function M.validate_opencode_fragment(fragment, project_dir)
  local source_agents = fragment.agent or (type(fragment) == "table" and not vim.isarray(fragment) and fragment) or {}

  -- Sort agent names first so iteration order -- and therefore the accumulated miss list and
  -- the resulting message -- is deterministic across repeated runs, independent of pairs()'s
  -- nondeterministic table iteration order.
  local agent_names = {}
  for agent_name, _ in pairs(source_agents) do
    table.insert(agent_names, agent_name)
  end
  table.sort(agent_names)

  local miss_messages = {}
  local missing_by_key = {}

  for _, agent_name in ipairs(agent_names) do
    local agent_def = source_agents[agent_name]
    if type(agent_def) == "table" and agent_def.prompt then
      local prompt = agent_def.prompt
      -- Check for {file:PATH} syntax
      local file_path = prompt:match("^%{file:(.+)%}$")
      if file_path then
        local abs_path = project_dir .. "/" .. file_path
        if vim.fn.filereadable(abs_path) ~= 1 then
          table.insert(miss_messages, string.format(
            "Agent '%s' references missing file: %s",
            agent_name, file_path
          ))
          missing_by_key[agent_name] = file_path
        end
      end
    end
  end

  if #miss_messages > 0 then
    return false, table.concat(miss_messages, "; "), missing_by_key
  end

  return true, nil, nil
end

--- Generate opencode.json as a fully computed artifact.
--- Starts from the base template, then merges agent definitions from each loaded
--- extension's opencode-agents.json fragment in dependency order (core first,
--- then others in stable sorted order).
---
--- This replaces the per-extension merge/unmerge approach: the generated file
--- is fully deterministic given the set of loaded extensions and base template.
---
--- @param project_dir string Project directory
--- @param config table Extension system configuration
--- @return boolean success True if generation succeeded
--- @return string|nil error Error message if generation failed
function M.generate_opencode_json(project_dir, config)
  -- Lazy-require to avoid circular deps
  local state_mod = require("neotex.plugins.ai.shared.extensions.state")
  local manifest_mod = require("neotex.plugins.ai.shared.extensions.manifest")

  local target_path = project_dir .. "/opencode.json"
  local managed_marker = target_path .. ".managed"

  -- Step 1.2: Managed/unmanaged gating
  if vim.fn.filereadable(managed_marker) ~= 1 then
    return true, nil
  end

  -- Read base template (project-local first, then global fallback)
  local template_path = project_dir .. "/.opencode/templates/opencode.json"
  if vim.fn.filereadable(template_path) ~= 1 then
    template_path = vim.fn.expand("~/.config/nvim/.opencode/templates/opencode.json")
  end

  local base = {}
  if vim.fn.filereadable(template_path) == 1 then
    base = read_json(template_path) or {}
  end

  -- Ensure agent table exists
  if not base.agent then
    base.agent = {}
  end

  -- Read state and build ordered loaded extension list
  local state = state_mod.read(project_dir, config)
  local loaded_names = state_mod.list_loaded(state)

  local ordered_names = {}
  local seen = {}

  -- Core always first
  for _, name in ipairs(loaded_names) do
    if name == "core" then
      table.insert(ordered_names, name)
      seen[name] = true
      break
    end
  end

  -- Remaining extensions in stable sorted order
  for _, name in ipairs(loaded_names) do
    if not seen[name] then
      table.insert(ordered_names, name)
      seen[name] = true
    end
  end

  -- Collect and merge fragments
  for _, ext_name in ipairs(ordered_names) do
    local extension = manifest_mod.get_extension(ext_name, config)
    if extension and extension.path then
      local fragment_path = extension.path .. "/opencode-agents.json"
      if vim.fn.filereadable(fragment_path) == 1 then
        local fragment = read_json(fragment_path)
        if fragment then
          -- Per-agent-key degradation: a fragment with one bad {file:...} reference no longer
          -- discards its whole agent set. Every agent whose own reference resolves is merged;
          -- only the individual offending key(s) are skipped, using the missing_by_key map
          -- validate_opencode_fragment now returns for exactly this purpose.
          local _, _, missing_by_key = M.validate_opencode_fragment(fragment, project_dir)
          missing_by_key = missing_by_key or {}
          local source_agents = fragment.agent
            or (type(fragment) == "table" and not vim.isarray(fragment) and fragment)
            or {}
          local skipped_keys = {}
          for key, value in pairs(source_agents) do
            if missing_by_key[key] then
              table.insert(skipped_keys, key)
            elseif base.agent[key] == nil then
              -- First-writer-wins semantics preserved for keys that do merge.
              base.agent[key] = value
            end
          end
          if #skipped_keys > 0 then
            table.sort(skipped_keys)
            local skip_details = {}
            for _, key in ipairs(skipped_keys) do
              table.insert(skip_details, string.format("%s (missing %s)", key, missing_by_key[key]))
            end
            vim.schedule(function()
              vim.notify(
                string.format(
                  "Extension '%s' opencode-agents.json: skipped agent key(s) %s due to unresolved "
                    .. "{file:...} reference(s); the rest of this fragment was merged.",
                  ext_name, table.concat(skip_details, ", ")
                ),
                vim.log.levels.WARN
              )
            end)
          end
        end
      end
    end
  end

  -- Step 1.3: Validate final computed table before writing
  local ok = pcall(vim.json.encode, base)
  if not ok then
    return false, "generate_opencode_json: failed to encode computed JSON"
  end

  -- Atomic write: write to temp then rename
  local temp_path = target_path .. ".tmp." .. tostring(os.time())
  local write_ok = M.write_json(temp_path, base)
  if not write_ok then
    return false, "generate_opencode_json: failed to write temporary file"
  end

  local rename_ok = os.rename(temp_path, target_path)
  if not rename_ok then
    -- Fallback: direct write
    write_ok = M.write_json(target_path, base)
    if not write_ok then
      return false, "generate_opencode_json: failed to write opencode.json"
    end
  end

  return true, nil
end

return M
