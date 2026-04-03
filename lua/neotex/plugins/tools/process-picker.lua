-----------------------------------------------------------
-- Process Picker (Telescope)
--
-- Telescope picker for viewing and managing background
-- processes tracked by neotex.util.process. Shows process
-- name, command, port, uptime, and status in a searchable
-- list with stdout/stderr preview.
--
-- Actions:
--   <CR>  - Kill selected process and refresh picker
--   <C-o> - Open process port in browser
--
-- Usage:
--   require("neotex.plugins.tools.process-picker").show()
--
-- This is a utility module, NOT a lazy.nvim plugin spec.
-- Do NOT add to tools/init.lua.
-----------------------------------------------------------

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Format elapsed time since start_time as human-readable string.
---@param start_time number os.time() timestamp
---@return string Formatted uptime (e.g., "5s", "2m 30s", "1h 15m")
local function format_uptime(start_time)
  local elapsed = os.difftime(os.time(), start_time)
  if elapsed < 0 then
    elapsed = 0
  end

  local hours = math.floor(elapsed / 3600)
  local mins = math.floor((elapsed % 3600) / 60)
  local secs = math.floor(elapsed % 60)

  if hours > 0 then
    return string.format("%dh %dm", hours, mins)
  elseif mins > 0 then
    return string.format("%dm %ds", mins, secs)
  else
    return string.format("%ds", secs)
  end
end

--- Truncate a string to max_len, appending ellipsis if needed.
---@param str string
---@param max_len number
---@return string
local function truncate(str, max_len)
  if #str <= max_len then
    return str
  end
  return str:sub(1, max_len - 1) .. "~"
end

-- ---------------------------------------------------------------------------
-- Entry maker
-- ---------------------------------------------------------------------------

--- Create a telescope entry maker for process entries.
---@return function entry_maker
local function create_entry_maker()
  return function(proc)
    if proc._is_help then
      return {
        value = proc,
        display = "[Keyboard Shortcuts]",
        ordinal = "keyboard shortcuts help",
      }
    end

    local name = truncate(proc.name or "unnamed", 15)
    local cmd_str = table.concat(proc.cmd or {}, " ")
    cmd_str = truncate(cmd_str, 30)
    local port = proc.port and tostring(proc.port) or "-"
    local uptime = format_uptime(proc.start_time or os.time())
    local status = proc.status or "unknown"

    local display = string.format(
      "%-15s %-30s %-8s %-8s %s",
      name, cmd_str, port, uptime, status
    )

    return {
      value = proc,
      display = display,
      ordinal = (proc.name or "") .. " " .. table.concat(proc.cmd or {}, " "),
    }
  end
end

-- ---------------------------------------------------------------------------
-- Previewer
-- ---------------------------------------------------------------------------

--- Create a buffer previewer that shows process metadata and output.
---@return table previewer
local function create_previewer()
  local previewers = require("telescope.previewers")

  return previewers.new_buffer_previewer({
    title = "Process Details",
    define_preview = function(self, entry, _status)
      local proc = entry.value
      if not proc then
        return
      end

      -- Help entry: show keybindings
      if proc._is_help then
        local help_lines = {
          "Keyboard Shortcuts",
          "==================",
          "",
          "  <C-j> / <C-k>    Navigate up/down",
          "  <CR>              Kill selected process",
          "  <C-o>             Open port in browser",
          "  <Esc> / <C-c>     Close picker",
          "",
          "Column Legend",
          "=============",
          "",
          "  NAME              Process name",
          "  COMMAND            Launch command (truncated)",
          "  PORT              Listening port (- if none)",
          "  UPTIME            Time since launch",
          "  STATUS            running / exited / stopped",
        }
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, help_lines)
        return
      end

      local lines = {}

      -- Header: metadata
      local cmd_str = table.concat(proc.cmd or {}, " ")
      table.insert(lines, "Command:    " .. cmd_str)
      table.insert(lines, "ID:         " .. tostring(proc.id or "?"))
      table.insert(lines, "Port:       " .. (proc.port and tostring(proc.port) or "-"))
      table.insert(lines, "CWD:        " .. (proc.cwd or "-"))
      table.insert(lines, "Started:    " .. (proc.start_time and os.date("%Y-%m-%d %H:%M:%S", proc.start_time) or "-"))
      table.insert(lines, "Status:     " .. (proc.status or "unknown"))
      table.insert(lines, "")
      table.insert(lines, string.rep("-", 60))

      -- Fetch full entry with ring buffers
      local ok_proc, process = pcall(require, "neotex.util.process")
      if ok_proc then
        local full = process.get(proc.id)
        if full then
          -- stdout
          table.insert(lines, "")
          table.insert(lines, "--- stdout (last 50 lines) ---")
          local stdout_lines = full.stdout and full.stdout:lines() or {}
          if #stdout_lines == 0 then
            table.insert(lines, "  No output captured")
          else
            -- Take last 50
            local start_idx = math.max(1, #stdout_lines - 49)
            for i = start_idx, #stdout_lines do
              table.insert(lines, stdout_lines[i])
            end
          end

          -- stderr
          table.insert(lines, "")
          table.insert(lines, "--- stderr (last 20 lines) ---")
          local stderr_lines = full.stderr and full.stderr:lines() or {}
          if #stderr_lines == 0 then
            table.insert(lines, "  No output captured")
          else
            local stderr_start = math.max(1, #stderr_lines - 19)
            for i = stderr_start, #stderr_lines do
              table.insert(lines, stderr_lines[i])
            end
          end
        end
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.bo[self.state.bufnr].filetype = "log"
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Show the telescope process picker.
---
--- Displays all background processes from the process registry with
--- name, command, port, uptime, and status columns. Preview pane shows
--- full metadata and recent stdout/stderr output.
---
---@param opts table|nil Telescope picker options (passed through)
---@return nil
function M.show(opts)
  opts = opts or {}

  -- Guard: process module availability
  local ok, process = pcall(require, "neotex.util.process")
  if not ok then
    vim.notify(
      "Process manager not available (neotex.util.process)",
      vim.log.levels.WARN
    )
    return
  end

  -- Get process list
  local processes = process.list()
  if #processes == 0 then
    vim.notify("No background processes running", vim.log.levels.INFO)
    return
  end

  -- Add help entry at the end
  table.insert(processes, {
    _is_help = true,
    name = "[Keyboard Shortcuts]",
    cmd = {},
    status = "Help",
  })

  -- Telescope requires
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  pickers.new(opts, {
    prompt_title = "Background Processes",
    finder = finders.new_table({
      results = processes,
      entry_maker = create_entry_maker(),
    }),
    sorter = conf.generic_sorter(opts),
    previewer = create_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- <CR>: Kill selected process and refresh
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value._is_help then
          return
        end
        actions.close(prompt_bufnr)
        local proc_entry = selection.value
        process.stop(proc_entry.id)

        -- Re-open picker if processes remain
        vim.defer_fn(function()
          local remaining = process.list()
          if #remaining > 0 then
            M.show(opts)
          end
        end, 100)
      end)

      -- <C-o>: Open port in browser
      local function open_in_browser()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        local proc_entry = selection.value
        if not proc_entry.port then
          vim.notify("No port associated with this process", vim.log.levels.WARN)
          return
        end
        local url = "http://localhost:" .. tostring(proc_entry.port)
        local cmd
        if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
          cmd = { "open", url }
        else
          cmd = { "xdg-open", url }
        end
        vim.fn.jobstart(cmd, { detach = true })
        vim.notify("Opening " .. url, vim.log.levels.INFO)
      end

      map("i", "<C-o>", open_in_browser)
      map("n", "<C-o>", open_in_browser)

      return true
    end,
  }):find()
end

return M
