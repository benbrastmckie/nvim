-- sf1 Sapience Chat Plugin Specification
-- This file exports the plugin spec for lazy.nvim
--
-- Host-side wiring lives here, never inside `ai/sapience/`: that directory is
-- kept free of any `neotex.*` dependency so it can be lifted into a standalone
-- repository unchanged. The coding-agent coordination below reaches into
-- claude-code and opencode, so it belongs on this side of that boundary and is
-- handed to the module as its generic `on_open` hook.

--- Report whether any window currently displays one of `bufs`.
---@param bufs integer[]
---@return boolean visible
local function any_visible(bufs)
  for _, buf in ipairs(bufs) do
    if buf and vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) > 0 then
      return true
    end
  end
  return false
end

--- Collect live Claude Code terminal buffers.
---
--- Deliberately self-contained rather than reusing the two-stage tool picker's
--- own detection: that module's helpers are private, and sf1 is intentionally
--- absent from the `<C-CR>` picker (which enforces mutual exclusion between
--- Claude Code and OpenCode over the same right sidebar).
---@return integer[] bufs
local function claude_buffers()
  local ok, claude_code = pcall(require, "claude-code")
  if ok and claude_code.claude_code and type(claude_code.claude_code.instances) == "table" then
    local bufs = {}
    for _, bufnr in pairs(claude_code.claude_code.instances) do
      if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
        table.insert(bufs, bufnr)
      end
    end
    return bufs
  end
  return {}
end

--- Collect live OpenCode terminal buffers, matched on the snacks terminal cmd.
---@return integer[] bufs
local function opencode_buffers()
  local ok, snacks_terminal = pcall(require, "snacks.terminal")
  if not ok or not snacks_terminal.list then
    return {}
  end
  local bufs = {}
  for _, term in ipairs(snacks_terminal.list()) do
    local buf = term.buf
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local snacks_data = vim.b[buf].snacks_terminal
      if snacks_data then
        local cmd = snacks_data.cmd or snacks_data.args or {}
        local cmd_str = type(cmd) == "table" and table.concat(cmd, " ") or tostring(cmd)
        if cmd_str:match("opencode%s+%-%-port") then
          table.insert(bufs, buf)
        end
      end
    end
  end
  return bufs
end

--- Hide whichever coding agent is currently visible, so sf1 takes the split
--- rather than sharing the screen with it. Each toggle is the tool's own
--- documented hide path, so a hidden session keeps its buffer and running job
--- and can be re-shown unchanged.
local function hide_coding_agents()
  if any_visible(claude_buffers()) then
    pcall(vim.cmd, "ClaudeCode")
  end

  if any_visible(opencode_buffers()) then
    local ok, cfg = pcall(require, "opencode.config")
    if ok and cfg.opts and cfg.opts.server and cfg.opts.server.toggle then
      pcall(cfg.opts.server.toggle)
    end
  end
end

return {
  -- Virtual plugin for sf1 setup
  dir = vim.fn.stdpath('config') .. '/lua/neotex/plugins/ai/sapience',
  name = 'sapience-sf1',
  event = { 'VeryLazy' }, -- Load after startup
  config = function(_, opts)
    -- Defer loading to avoid static analysis issues
    local module_path = 'neotex.plugins.ai.sapience.init'
    local sapience = require(module_path)
    -- `force` order keeps an explicit user-supplied hook ahead of the default.
    sapience.setup(vim.tbl_deep_extend('force', { on_open = hide_coding_agents }, opts or {}))

    vim.api.nvim_create_user_command('Sf1', function()
      sapience.toggle()
    end, { desc = 'Toggle sf1 Sapience chat terminal' })
  end,
}
