-- neotex.plugins.ai.claude.extensions.picker
-- Dedicated extension management picker (via :ClaudeExtensions command)

local M = {}

-- Telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")

-- Extension modules
local extensions = require("neotex.plugins.ai.claude.extensions")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Format extension entry for display
--- @param ext table Extension data
--- @return string display Formatted display string
local function format_entry(ext)
  local status_indicator
  if ext.status == "active" then
    status_indicator = "[active]"
  elseif ext.status == "update-available" then
    status_indicator = "[update]"
  else
    status_indicator = "[inactive]"
  end

  return string.format(
    " %-20s %-10s %s",
    ext.name,
    status_indicator,
    ext.description or ""
  )
end

--- Create previewer for extension details
--- @return table previewer Telescope previewer
local function create_previewer()
  return previewers.new_buffer_previewer({
    title = "Extension Details",
    define_preview = function(self, entry, _)
      local ext = entry.value
      local details = extensions.get_details(ext.name)

      local lines = {
        "# " .. ext.name .. " v" .. ext.version,
        "",
        "**Status**: " .. ext.status,
        "**Language**: " .. (ext.language or "any"),
        "",
        "## Description",
        ext.description or "No description",
        "",
      }

      -- Provides section
      if details and details.provides then
        table.insert(lines, "## Provides")
        for category, items in pairs(details.provides) do
          if type(items) == "table" and #items > 0 then
            table.insert(lines, "")
            table.insert(lines, "### " .. category)
            for _, item in ipairs(items) do
              table.insert(lines, "- " .. item)
            end
          end
        end
      end

      -- MCP Servers section
      if details and details.mcp_servers then
        table.insert(lines, "")
        table.insert(lines, "## MCP Servers")
        for name, config in pairs(details.mcp_servers) do
          table.insert(lines, "- **" .. name .. "**: " .. config.command)
        end
      end

      -- Installed files (if active)
      if details and #details.installed_files > 0 then
        table.insert(lines, "")
        table.insert(lines, "## Installed Files (" .. #details.installed_files .. ")")
        for i, file in ipairs(details.installed_files) do
          if i <= 10 then
            table.insert(lines, "- " .. file)
          end
        end
        if #details.installed_files > 10 then
          table.insert(lines, "- ... and " .. (#details.installed_files - 10) .. " more")
        end
      end

      -- Loaded at timestamp
      if details and details.loaded_at then
        table.insert(lines, "")
        table.insert(lines, "**Loaded**: " .. details.loaded_at)
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_set_option_value("filetype", "markdown", { buf = self.state.bufnr })
    end,
  })
end

--- Show the extension management picker
--- @param opts table|nil Telescope options
function M.show(opts)
  opts = opts or {}

  -- Get all available extensions
  local available = extensions.list_available()

  if #available == 0 then
    helpers.notify("No extensions found in global directory", "WARN")
    return
  end

  -- Create picker
  pickers.new(opts, {
    prompt_title = "Claude Extensions",
    finder = finders.new_table({
      results = available,
      entry_maker = function(ext)
        return {
          value = ext,
          display = format_entry(ext),
          ordinal = ext.name .. " " .. (ext.description or ""),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = create_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- Enter: Toggle extension (load/unload)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local ext = selection.value
        actions.close(prompt_bufnr)

        if ext.status == "active" or ext.status == "update-available" then
          -- Unload
          extensions.unload(ext.name, { confirm = true })
        else
          -- Load
          extensions.load(ext.name, { confirm = true })
        end

        -- Refresh picker after action
        vim.defer_fn(function()
          M.show(opts)
        end, 100)
      end)

      -- Ctrl-r: Reload extension
      map("i", "<C-r>", function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local ext = selection.value
        if ext.status ~= "active" and ext.status ~= "update-available" then
          helpers.notify("Extension not loaded, cannot reload", "WARN")
          return
        end

        actions.close(prompt_bufnr)
        extensions.reload(ext.name, { confirm = false })

        vim.defer_fn(function()
          M.show(opts)
        end, 100)
      end)

      -- Ctrl-d: Show detailed file list
      map("i", "<C-d>", function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local ext = selection.value
        local details = extensions.get_details(ext.name)

        if not details or #details.installed_files == 0 then
          helpers.notify("No files installed for this extension", "INFO")
          return
        end

        -- Show file list in floating window
        local lines = { "Installed files for " .. ext.name .. ":", "" }
        for _, file in ipairs(details.installed_files) do
          table.insert(lines, "  " .. file)
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local width = 80
        local height = math.min(#lines + 2, 30)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = row,
          col = col,
          style = "minimal",
          border = "rounded",
          title = " Installed Files ",
          title_pos = "center",
        })

        -- Close on q or Escape
        vim.keymap.set("n", "q", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf })
        vim.keymap.set("n", "<Esc>", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf })
      end)

      -- Tab: Multi-select (for future batch operations)
      map("i", "<Tab>", actions.toggle_selection + actions.move_selection_worse)
      map("i", "<S-Tab>", actions.toggle_selection + actions.move_selection_better)

      -- Escape: Close
      map("i", "<Esc>", actions.close)
      map("n", "<Esc>", actions.close)

      return true
    end,
  }):find()
end

return M
