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
function M.show_commands_picker(opts)
  opts = opts or {}

  -- Get extended structure with all commands, skills, hooks
  local structure = parser.get_extended_structure()

  if not structure or not structure.primary_commands or vim.tbl_isempty(structure.primary_commands) then
    local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
    local global_dir = scan_mod.get_global_dir()
    helpers.notify(
      "No Claude commands found in .claude/commands/ or " .. global_dir .. "/.claude/commands/",
      "WARN"
    )
    return
  end

  -- Create entries for picker
  local picker_entries = entries.create_picker_entries(structure)

  -- Create picker
  pickers.new(opts, {
    prompt_title = "Claude Commands",
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

        -- Load All special entry
        if selection.value.is_load_all then
          local loaded = sync.load_all_globally()
          if loaded > 0 then
            actions.close(prompt_bufnr)
            vim.defer_fn(function()
              M.show_commands_picker(opts)
            end, 50)
          end
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
          -- Navigate to extension picker focused on this extension
          actions.close(prompt_bufnr)
          local ext_picker = require("neotex.plugins.ai.claude.extensions.picker")
          ext_picker.show(opts)
        end
      end)

      -- Load artifact locally with Ctrl-l
      map("i", "<C-l>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_load_all or selection.value.is_heading then
          return
        end

        -- Determine artifact type
        local artifact_type = selection.value.entry_type
        if selection.value.command then
          artifact_type = "command"
        end

        -- Load artifact
        local artifact = selection.value.command or selection.value
        edit.load_artifact_locally(artifact, artifact_type, parser)

        -- Refresh picker
        vim.defer_fn(function()
          actions.close(prompt_bufnr)
          M.show_commands_picker(opts)
        end, 100)
      end)

      -- Update from global with Ctrl-u
      map("i", "<C-u>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_load_all or selection.value.is_heading then
          return
        end

        -- Determine artifact type
        local artifact_type = selection.value.entry_type
        if selection.value.command then
          artifact_type = "command"
        end

        -- Update artifact
        local artifact = selection.value.command or selection.value
        sync.update_artifact_from_global(artifact, artifact_type, false)

        -- Refresh picker
        vim.defer_fn(function()
          actions.close(prompt_bufnr)
          M.show_commands_picker(opts)
        end, 100)
      end)

      -- Save to global with Ctrl-s
      map("i", "<C-s>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_load_all or selection.value.is_heading then
          return
        end

        -- Determine artifact type
        local artifact_type = selection.value.entry_type
        if selection.value.command then
          artifact_type = "command"
        end

        -- Save artifact
        local artifact = selection.value.command or selection.value
        edit.save_artifact_to_global(artifact, artifact_type)

        -- Refresh picker
        vim.defer_fn(function()
          actions.close(prompt_bufnr)
          M.show_commands_picker(opts)
        end, 100)
      end)

      -- Edit file with Ctrl-e
      map("i", "<C-e>", function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.is_help or selection.value.is_load_all or selection.value.is_heading then
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
