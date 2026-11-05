-- neotex.plugins.ai.claude.commands.picker.init
-- Main orchestration module for Claude artifacts picker

local M = {}

-- Telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values

-- Local modules
local parser = require("neotex.plugins.ai.claude.commands.parser")
local entries = require("neotex.plugins.ai.claude.commands.picker.display.entries")
local previewer = require("neotex.plugins.ai.claude.commands.picker.display.previewer")
local sync = require("neotex.plugins.ai.claude.commands.picker.operations.sync")
local edit = require("neotex.plugins.ai.claude.commands.picker.operations.edit")
local terminal = require("neotex.plugins.ai.claude.commands.picker.operations.terminal")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Show the Claude artifacts picker
--- @param opts table Telescope options
--- @param config table|nil Picker configuration from shared.picker.config (optional)
function M.show_commands_picker(opts, config)
  opts = opts or {}

  -- Extract restore target (set after extension load/unload to preserve cursor)
  local restore_ext_name = opts._restore_extension_name
  opts._restore_extension_name = nil

  -- Get config values with defaults for Claude
  local label = config and config.label or "Claude"
  local base_dir = config and config.base_dir or ".claude"
  local extensions_module = config and config.extensions_module or "neotex.plugins.ai.claude.extensions"

  -- Get extended structure with all commands, skills, hooks
  local structure = parser.get_extended_structure(config)

  -- Ensure structure is always a table so entry creators can iterate safely
  if not structure then
    structure = { primary_commands = {}, skills = {}, agents = {}, hooks = {}, hook_events = {}, root_files = {}, event_is_local = {} }
  end

  -- Create entries for picker (pass config for extension loading)
  local picker_entries = entries.create_picker_entries(structure, config)

  -- Create picker
  pickers.new(opts, {
    prompt_title = label .. " Commands",
    finder = finders.new_table {
      results = picker_entries,
      entry_maker = function(entry)
        local name = entry.name or entry.ordinal or ""
        local description = entry.command and entry.command.description or entry.description or ""

        return {
          value = entry,
          display = entry.display,
          ordinal = name .. " " .. description,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    sorting_strategy = "descending",
    default_selection_index = 2,
    previewer = previewer.create_command_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- Restore cursor to previously selected extension after load/unload
      if restore_ext_name then
        local p = action_state.get_current_picker(prompt_bufnr)
        p:register_completion_callback(function(self)
          vim.schedule(function()
            if not self.manager then
              return
            end
            for idx = 1, self.manager:num_results() do
              local entry = self.manager:get_entry(idx)
              if entry and entry.value and entry.value.name == restore_ext_name then
                self:set_selection(self:get_row(idx))
                return
              end
            end
          end)
        end)
      end

      -- Escape key: close picker immediately
      map("i", "<Esc>", actions.close)
      map("n", "<Esc>", actions.close)

      -- Preview scrolling
      map("i", "<C-u>", actions.preview_scrolling_up)
      map("i", "<C-d>", actions.preview_scrolling_down)
      map("i", "<C-f>", actions.preview_scrolling_down)
      map("i", "<C-b>", actions.preview_scrolling_up)

      -- Context-aware Enter key: direct action execution
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        -- Skip heading entries
        if selection.value.is_heading then
          return
        end

        -- Regenerate special entry: destructive wipe + rebuild from the surviving
        -- project-root extension manifest (manager.wipe: snapshot -> rm -rf base_dir ->
        -- regenerate -> restore settings/.syncprotect -> clear staging). Replaces the
        -- retired glob+allow-list "Load Core" entry point.
        if selection.value.is_regenerate then
          local confirmed = vim.fn.confirm(
            "Regenerate " .. base_dir .. "/ from the extension manifest?\n\n"
              .. "This deletes " .. base_dir .. "/ and rebuilds it from scratch.\n"
              .. "settings.local.json and .syncprotect-listed paths are snapshotted\n"
              .. "and restored automatically.",
            "&Regenerate\n&Cancel",
            2
          )
          if confirmed ~= 1 then
            return
          end
          local exts = require(extensions_module)
          local wipe_ok, wipe_result = exts.wipe({ project_dir = vim.fn.getcwd() })
          if wipe_ok then
            local loaded_count = (wipe_result and wipe_result.loaded and #wipe_result.loaded) or 0
            local failed = (wipe_result and wipe_result.failed) or {}
            if #failed == 0 then
              helpers.notify(
                string.format("Regenerated %s (%d extension(s) reloaded)", base_dir, loaded_count),
                "INFO"
              )
            else
              local failed_list = {}
              for _, f in ipairs(failed) do
                table.insert(failed_list, (f.name or "?") .. ": " .. (f.error or "unknown"))
              end
              helpers.notify(
                string.format(
                  "Regenerated %s with %d error(s): %s",
                  base_dir, #failed, table.concat(failed_list, ", ")
                ),
                "WARN"
              )
            end
            actions.close(prompt_bufnr)
            vim.defer_fn(function()
              M.show_commands_picker(opts, config)
            end, 50)
          else
            helpers.notify(tostring(wipe_result), "ERROR")
          end
          return
        end

        -- Reload All special entry: submenu for bulk operations
        if selection.value.is_reload_all then
          local exts = require(extensions_module)
          local loaded = exts.list_loaded()
          if not loaded or #loaded == 0 then
            vim.notify("No extensions loaded", vim.log.levels.INFO)
            return
          end
          actions.close(prompt_bufnr)
          vim.schedule(function()
            vim.ui.select(
              -- Decision 4 (recorded with reasoning): "Step Through" was removed rather than
              -- implemented. It was a silent no-op that only reopened the picker; implementing a
              -- real stepwise resync is unscoped new feature work, and the submenu already
              -- offers both real bulk operations ("Reload All", "Unload All"). Removal is the
              -- honest minimal change -- a future task may reintroduce it as a working stepwise
              -- resync if that is ever wanted.
              { "Reload All", "Unload All", "Cancel" },
              { prompt = "Bulk action for " .. #loaded .. " loaded extension(s):" },
              function(choice)
                if not choice or choice == "Cancel" then
                  vim.defer_fn(function()
                    M.show_commands_picker(opts, config)
                  end, 100)
                  return
                end

                if choice == "Unload All" then
                  -- Build dependency graph for topological sort (needed so leaves unload before
                  -- roots -- manager.unload hard-blocks unloading an extension that still has a
                  -- loaded dependent). Local to this branch: "Reload All" below no longer needs
                  -- its own copy of this ordering -- it delegates entirely to
                  -- manager.resync_all, which owns the same Kahn's-algorithm ordering.
                  local loaded_set = {}
                  for _, name in ipairs(loaded) do
                    loaded_set[name] = true
                  end
                  local deps_of = {}
                  for _, name in ipairs(loaded) do
                    local details = exts.get_details(name)
                    local deps = {}
                    if details and details.dependencies then
                      for _, dep in ipairs(details.dependencies) do
                        if loaded_set[dep] then
                          table.insert(deps, dep)
                        end
                      end
                    end
                    deps_of[name] = deps
                  end
                  local in_degree = {}
                  for _, name in ipairs(loaded) do
                    in_degree[name] = 0
                  end
                  for _, name in ipairs(loaded) do
                    for _, dep in ipairs(deps_of[name]) do
                      in_degree[name] = (in_degree[name] or 0) + 1
                    end
                  end
                  local load_order = {}
                  local queue = {}
                  for _, name in ipairs(loaded) do
                    if in_degree[name] == 0 then
                      table.insert(queue, name)
                    end
                  end
                  while #queue > 0 do
                    local name = table.remove(queue, 1)
                    table.insert(load_order, name)
                    for _, other in ipairs(loaded) do
                      for _, dep in ipairs(deps_of[other]) do
                        if dep == name then
                          in_degree[other] = in_degree[other] - 1
                          if in_degree[other] == 0 then
                            table.insert(queue, other)
                          end
                        end
                      end
                    end
                  end

                  -- Unload in reverse order (leaves first, roots/core last)
                  local errors = {}
                  for i = #load_order, 1, -1 do
                    local ok, err = exts.unload(load_order[i], { confirm = false })
                    if not ok then
                      table.insert(errors, load_order[i] .. ": " .. (err or "unknown"))
                    end
                  end
                  local unloaded = #load_order - #errors
                  if #errors == 0 then
                    vim.notify(
                      string.format("Unloaded %d extension(s)", unloaded),
                      vim.log.levels.INFO
                    )
                  else
                    vim.notify(
                      string.format("Unloaded %d/%d. Errors: %s",
                        unloaded, #load_order, table.concat(errors, ", ")),
                      vim.log.levels.WARN
                    )
                  end
                  vim.defer_fn(function()
                    M.show_commands_picker(opts, config)
                  end, 100)
                  return
                end

                -- Reload All: manager-level non-destructive force-resync, in dependency order.
                -- Replaces the former picker-local unload-all/load-all reimplementation
                -- entirely -- exts.resync_all (neotex.plugins.ai.shared.extensions.init's
                -- manager.resync_all) owns the Kahn's-algorithm ordering and never unloads.
                local result = exts.resync_all()
                if #result.failed == 0 then
                  vim.notify(
                    string.format("Resynced %d extension(s)", #result.succeeded),
                    vim.log.levels.INFO
                  )
                else
                  local failed_list = {}
                  for _, f in ipairs(result.failed) do
                    table.insert(failed_list, f.name .. ": " .. (f.error or "unknown"))
                  end
                  vim.notify(
                    string.format("Resynced %d/%d. Errors: %s",
                      #result.succeeded, result.total, table.concat(failed_list, ", ")),
                    vim.log.levels.WARN
                  )
                end
                vim.defer_fn(function()
                  M.show_commands_picker(opts, config)
                end, 100)
              end
            )
          end)
          return
        end

        -- Global Update special entry: cross-repo, non-destructive resync of every registered
        -- repo's OWN loaded-extension set (never the host repo's set applied elsewhere -- each
        -- repo's resync_all call only touches the extensions that repo itself has loaded).
        -- Never uses exts.wipe -- only the same non-destructive manager.resync_all path
        -- [Reload All] uses, scoped per repo via repo_registry.lua's registered rows.
        if selection.value.is_global_update then
          actions.close(prompt_bufnr)
          local exts = require(extensions_module)
          local repo_registry = require("neotex.plugins.ai.shared.extensions.repo_registry")
          local rows = repo_registry.list()

          if #rows == 0 then
            helpers.notify(
              "Global Update: no repos registered yet (a repo is registered the first time "
                .. "<leader>al loads an extension into it).",
              "INFO"
            )
            return
          end

          local total_succeeded = 0
          local per_repo_failures = {}
          local unreachable = {}

          for _, row in ipairs(rows) do
            if vim.fn.isdirectory(row.project_dir) ~= 1 then
              table.insert(unreachable, row.project_dir)
            else
              local result = exts.resync_all({ project_dir = row.project_dir })
              total_succeeded = total_succeeded + #result.succeeded
              if #result.failed > 0 then
                local failed_names = {}
                for _, f in ipairs(result.failed) do
                  table.insert(failed_names, f.name .. ": " .. (f.error or "unknown"))
                end
                table.insert(per_repo_failures,
                  row.project_dir .. " -- " .. table.concat(failed_names, ", "))
              end
            end
          end

          -- Self-maintaining registry: an unreachable registered repo is pruned automatically
          -- (per Phase 4's prune_unreachable) rather than aborting the whole operation or
          -- requiring a separate confirmation -- Global Update stays non-destructive to repo
          -- contents while still keeping its own registry honest.
          if #unreachable > 0 then
            repo_registry.prune_unreachable()
          end

          local message_parts = {
            string.format("Global Update: %d extension(s) resynced across %d repo(s)",
              total_succeeded, #rows - #unreachable),
          }
          if #unreachable > 0 then
            table.insert(message_parts, string.format(
              "%d unreachable repo(s) pruned from the registry: %s",
              #unreachable, table.concat(unreachable, ", ")
            ))
          end
          if #per_repo_failures > 0 then
            table.insert(message_parts, "Failures: " .. table.concat(per_repo_failures, "; "))
          end

          helpers.notify(
            table.concat(message_parts, "\n"),
            (#per_repo_failures > 0) and "WARN" or "INFO"
          )
          return
        end

        -- Help section: does nothing
        if selection.value.is_help then
          return
        end

        -- Execute action based on artifact type
        if selection.value.command then
          actions.close(prompt_bufnr)
          terminal.send_command_to_terminal(selection.value.command)
        elseif selection.value.entry_type == "skill" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "doc" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "lib" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "template" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "hook_event" and selection.value.hooks then
          actions.close(prompt_bufnr)
          if #selection.value.hooks > 0 then
            edit.edit_artifact_file(selection.value.hooks[1].filepath)
          end
        elseif selection.value.entry_type == "script" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "test" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "agent" and selection.value.filepath then
          actions.close(prompt_bufnr)
          edit.edit_artifact_file(selection.value.filepath)
        elseif selection.value.entry_type == "extension" then
          -- Cursor restore: only extension toggle needs this because the entry
          -- list is stable across load/unload. Other reopen cycles (Ctrl-l,
          -- Ctrl-u, Ctrl-s, Load All) change the list, so cursor reset is expected.
          local ext = selection.value
          actions.close(prompt_bufnr)
          local exts = require(extensions_module)
          if ext.status == "active" or ext.status == "update-available" then
            -- Show submenu for loaded extensions: Unload / Reload / Cancel
            vim.schedule(function()
              vim.ui.select(
                { "Unload", "Reload", "Cancel" },
                { prompt = "Extension: " .. ext.name },
                function(choice)
                  if choice == "Unload" then
                    exts.unload(ext.name, { confirm = false })
                  elseif choice == "Reload" then
                    exts.reload(ext.name, {})
                  end
                  vim.defer_fn(function()
                    M.show_commands_picker(
                      vim.tbl_extend("force", opts, { _restore_extension_name = ext.name }),
                      config
                    )
                  end, 100)
                end
              )
            end)
          else
            vim.schedule(function()
              vim.ui.select(
                { "Load", "Cancel" },
                { prompt = "Extension: " .. ext.name },
                function(choice)
                  if choice == "Load" then
                    exts.load(ext.name, { confirm = false })
                  end
                  vim.defer_fn(function()
                    M.show_commands_picker(
                      vim.tbl_extend("force", opts, { _restore_extension_name = ext.name }),
                      config
                    )
                  end, 100)
                end
              )
            end)
          end
        end
      end)

      -- Load artifact locally with Ctrl-l
      map("i", "<C-l>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_reload_all or selection.value.is_regenerate or selection.value.is_global_update or selection.value.is_heading then
          return
        end

        -- Determine artifact type
        local artifact_type = selection.value.entry_type
        if selection.value.command then
          artifact_type = "command"
        end

        -- Load artifact
        local artifact = selection.value.command or selection.value
        edit.load_artifact_locally(artifact, artifact_type, parser, config)

        -- Refresh picker
        vim.defer_fn(function()
          actions.close(prompt_bufnr)
          M.show_commands_picker(opts, config)
        end, 100)
      end)

      -- Update from global with Ctrl-u
      map("i", "<C-u>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_reload_all or selection.value.is_regenerate or selection.value.is_global_update or selection.value.is_heading then
          return
        end

        -- Determine artifact type
        local artifact_type = selection.value.entry_type
        if selection.value.command then
          artifact_type = "command"
        end

        -- Update artifact
        local artifact = selection.value.command or selection.value
        sync.update_artifact_from_global(artifact, artifact_type, false, config)

        -- Refresh picker
        vim.defer_fn(function()
          actions.close(prompt_bufnr)
          M.show_commands_picker(opts, config)
        end, 100)
      end)

      -- Save to global with Ctrl-s
      map("i", "<C-s>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_reload_all or selection.value.is_regenerate or selection.value.is_global_update or selection.value.is_heading then
          return
        end

        -- Determine artifact type
        local artifact_type = selection.value.entry_type
        if selection.value.command then
          artifact_type = "command"
        end

        -- Save artifact
        local artifact = selection.value.command or selection.value
        edit.save_artifact_to_global(artifact, artifact_type, config)

        -- Refresh picker
        vim.defer_fn(function()
          actions.close(prompt_bufnr)
          M.show_commands_picker(opts, config)
        end, 100)
      end)

      -- Edit file with Ctrl-e
      map("i", "<C-e>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_reload_all or selection.value.is_regenerate or selection.value.is_global_update or selection.value.is_heading then
          return
        end

        actions.close(prompt_bufnr)

        -- Determine filepath
        local filepath = nil
        if selection.value.command then
          filepath = selection.value.command.filepath
        elseif selection.value.filepath then
          filepath = selection.value.filepath
        elseif selection.value.entry_type == "hook_event" and selection.value.hooks and #selection.value.hooks > 0 then
          filepath = selection.value.hooks[1].filepath
        end

        if filepath then
          edit.edit_artifact_file(filepath)
        end
      end)

      -- Create new command with Ctrl-n
      map("i", "<C-n>", function()
        actions.close(prompt_bufnr)
        terminal.create_new_command()
      end)

      -- Run script with Ctrl-r (prompts for arguments)
      map("i", "<C-r>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.entry_type ~= "script" then
          return
        end

        actions.close(prompt_bufnr)
        terminal.run_script_with_args(selection.value.filepath, selection.value.name)
      end)

      -- Run test with Ctrl-t
      map("i", "<C-t>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.entry_type ~= "test" then
          return
        end

        actions.close(prompt_bufnr)
        terminal.run_test(selection.value.filepath, selection.value.name)
      end)

      return true
    end,
  }):find()
end

return M
