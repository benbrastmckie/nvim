-- sf1 Sapience chat -- window backend
--
-- All window/split handling for the sf1 terminal lives behind this module's
-- public functions (`open`, `show`, `close`, `find`, `visible`, `reposition`),
-- so the snacks.terminal backend can be swapped for another implementation
-- (e.g. a plain `termopen` split) by editing this file alone.
--
-- This file MUST NOT require anything from the neotex namespace. It is
-- intentionally dependency-free so the containing directory can later be
-- lifted into a standalone repository unchanged.

local M = {}

--- Load the snacks.terminal module, warning once per call site on failure
--- rather than erroring.
---@return table|nil snacks_terminal The snacks.terminal module, or nil if unavailable
local function _snacks()
  local ok, snacks_terminal = pcall(require, "snacks.terminal")
  if not ok then
    vim.notify(
      "sf1: snacks.nvim is required but could not be loaded (snacks.terminal)",
      vim.log.levels.WARN
    )
    return nil
  end
  return snacks_terminal
end

--- Build the `snacks.terminal` window options for a given position/size.
---
--- For the three split positions (`bottom`/`left`/`right`), both `height` and
--- `width` are set to `size`: a split's own `open_win()` consumes only the one
--- dimension its orientation needs, so setting both is harmless. For `float`,
--- neither dimension is set, letting the snacks `"float"` style defaults
--- apply instead of producing an unintentionally square window -- `size` is
--- meaningful only for the three split positions.
---@param position "bottom"|"right"|"left"|"float"
---@param size number Fraction in (0, 1], ignored when position is "float"
---@return table win_opts `{ win = { ... } }` suitable for `snacks.terminal` calls
local function _win_opts(position, size)
  local win = { position = position, enter = true }
  if position ~= "float" then
    win.height = size
    win.width = size
  end
  return { win = win }
end

--- Open (or toggle-hide, if already visible) an sf1 terminal window.
---@param cmd string The shell command to run (e.g. "sf1 --project foo")
---@param position "bottom"|"right"|"left"|"float"
---@param size number Fraction in (0, 1], ignored when position is "float"
---@return table|nil term The snacks terminal window object, or nil on failure
function M.open(cmd, position, size)
  local snacks_terminal = _snacks()
  if not snacks_terminal then
    return nil
  end
  return snacks_terminal.toggle(cmd, _win_opts(position, size))
end

--- Open or re-focus an sf1 terminal window, never hiding a visible one.
---
--- Unlike `open` above (which is `snacks.terminal.toggle`), this is the
--- idempotent form: calling it on an already-visible window re-focuses it.
---
--- `snacks.terminal.open` is deliberately NOT used here: it unconditionally
--- creates a new terminal, so repeated calls would spawn one sf1 process per
--- call. `get` reuses the existing terminal (keyed on cmd/cwd/env/count1) and
--- creates one only when none exists; `show()` is itself a no-op on an
--- already-valid window.
---@param cmd string The shell command to run (e.g. "sf1 --project foo")
---@param position "bottom"|"right"|"left"|"float"
---@param size number Fraction in (0, 1], ignored when position is "float"
---@return table|nil term The snacks terminal window object, or nil on failure
function M.show(cmd, position, size)
  local snacks_terminal = _snacks()
  if not snacks_terminal then
    return nil
  end
  local term, created = snacks_terminal.get(cmd, _win_opts(position, size))
  if term and not created then
    term:show():focus()
  end
  return term
end

--- Find an existing sf1 terminal window without creating one.
---@param cmd string The shell command the terminal was opened with
---@return table|nil term The snacks terminal window object, or nil if absent
function M.find(cmd)
  local snacks_terminal = _snacks()
  if not snacks_terminal then
    return nil
  end
  -- `create = false` is load-bearing: `get`'s own default is `create = true`,
  -- which would spawn a terminal from a mere lookup.
  local term = snacks_terminal.get(cmd, { create = false })
  return term
end

--- Report whether an sf1 terminal is currently displayed in a window.
---
--- Distinct from `find`: a hidden terminal still exists (its buffer and job
--- are alive), so `find` returning non-nil does not mean a window is shown.
---@param cmd string The shell command the terminal was opened with
---@return boolean visible
function M.visible(cmd)
  local term = M.find(cmd)
  if not term then
    return false
  end
  local buf = term.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  return #vim.fn.win_findbuf(buf) > 0
end

--- Close an sf1 terminal window if one exists; a no-op otherwise.
---@param cmd string The shell command the terminal was opened with
function M.close(cmd)
  local term = M.find(cmd)
  if term then
    term:close()
  end
end

--- Mutate a live terminal's window options and re-place it, without killing
--- the underlying job.
---
--- `snacks.terminal`'s terminal id is derived from `cmd`, `cwd`, `env`, and
--- `vim.v.count1` only -- never from `win` options -- so merely re-toggling
--- after a position change would reuse the same terminal object and re-show
--- it at its *original* position. Mutating the live object's own `opts` and
--- then hiding/showing it works because `open_win()` re-reads
--- `self.opts.position` (and the resolved height/width) at open time, and
--- `hide()` is `close({ buf = false })`, which preserves the terminal buffer
--- and its running job.
---@param term table The snacks terminal window object (from `find`)
---@param position "bottom"|"right"|"left"|"float"
---@param size number Fraction in (0, 1], ignored when position is "float"
local function _reposition(term, position, size)
  local opts = _win_opts(position, size).win
  term.opts.position = opts.position
  term.opts.height = opts.height
  term.opts.width = opts.width
  if term:valid() then
    term:hide()
    term:show()
  end
end

--- Re-place an existing sf1 terminal at a new position/size, live, without
--- restarting its REPL. A no-op when no terminal currently exists.
---@param cmd string The shell command the terminal was opened with
---@param position "bottom"|"right"|"left"|"float"
---@param size number Fraction in (0, 1], ignored when position is "float"
function M.reposition(cmd, position, size)
  local term = M.find(cmd)
  if term then
    _reposition(term, position, size)
  end
end

return M
