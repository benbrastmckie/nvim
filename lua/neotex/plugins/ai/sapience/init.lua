-- sf1 Sapience chat -- public API
--
-- Opts schema, validation, project-string resolution, command construction,
-- and the lifecycle functions (`setup`/`open`/`close`/`toggle`/`set_position`)
-- for the sf1 terminal-chat integration. Every window call is delegated to
-- the backend in `terminal.lua`.
--
-- This file MUST NOT require anything from the neotex namespace, with one
-- deliberate exception: the backend require immediately below. That is the
-- only line to edit if this directory is ever lifted into a standalone repo.

local M = {}

local backend = require("neotex.plugins.ai.sapience.terminal")

--- @class SapienceStyling
--- @field enabled boolean Proxy sf1 through sf1_proxy.py to insert turn separators
--- @field separator "blank"|"rule"|"none" Separator rendering passed to the proxy

--- @class SapienceConfig
--- @field cmd string Executable name used to launch sf1
--- @field position "bottom"|"right"|"left"|"float" Window placement
--- @field size number Fraction in (0, 1], meaningful for split positions only
--- @field project "cwd"|"git"|false|fun():string|nil Project-scoping strategy
--- @field on_open fun()|nil Called immediately before a hidden window is shown
--- @field on_close fun()|nil Called immediately after a visible window is hidden
--- @field styling SapienceStyling Pane-separator proxy configuration

---@type SapienceConfig
local config = {
  cmd = "sf1",
  position = "right",
  -- Matches the Claude Code sidebar's own `split_ratio`, so the two AI
  -- surfaces occupy the same screen region at the same width.
  size = 0.40,
  project = "cwd",
  on_open = nil,
  on_close = nil,
  styling = {
    enabled = true,
    separator = "blank",
  },
}

local VALID_POSITIONS = { bottom = true, right = true, left = true, float = true }
local VALID_SEPARATORS = { blank = true, rule = true, none = true }

-- Latches the one-shot styling-unavailable warning so a repeated `toggle()` (or any other
-- lifecycle call) never spams the user more than once per session.
local _styling_warned = false

---@param v any
---@return boolean
local function _is_valid_position(v)
  return type(v) == "string" and VALID_POSITIONS[v] == true
end

---@param v any
---@return boolean
local function _is_valid_size(v)
  return type(v) == "number" and v > 0 and v <= 1
end

---@param v any
---@return boolean
local function _is_valid_hook(v)
  return v == nil or type(v) == "function"
end

---@param v any
---@return boolean
local function _is_valid_project(v)
  if v == false then
    return true
  end
  if type(v) == "function" then
    return true
  end
  return v == "cwd" or v == "git"
end

---@param v any
---@return boolean
local function _is_valid_styling(v)
  if type(v) ~= "table" then
    return false
  end
  if type(v.enabled) ~= "boolean" then
    return false
  end
  return type(v.separator) == "string" and VALID_SEPARATORS[v.separator] == true
end

--- Derive `sf1_proxy.py`'s absolute path from this file's own source location, never from
--- `vim.fn.stdpath('config')`: a self-relative derivation is what keeps this directory
--- liftable into a standalone repository, the property the module header above and
--- `terminal.lua`'s own header both already state.
---@return string path
local function _proxy_path()
  local source = debug.getinfo(1, "S").source
  local dir = vim.fn.fnamemodify(source:gsub("^@", ""), ":h")
  return dir .. "/sf1_proxy.py"
end

--- Warn once per session that styling was requested but is unavailable, naming which
--- precondition failed. A no-op after the first call.
---@param reason string
local function _warn_styling_unavailable(reason)
  if _styling_warned then
    return
  end
  _styling_warned = true
  vim.notify(
    "sf1: styling requested but unavailable (" .. reason .. "); falling back to unstyled sf1",
    vim.log.levels.WARN
  )
end

--- Resolve the configured `project` strategy into a project-name string.
---@return string|nil project_name
local function _resolve_project()
  local project = config.project

  if project == false then
    return nil
  end

  if type(project) == "function" then
    local ok, result = pcall(project)
    if ok and type(result) == "string" and result ~= "" then
      return result
    end
    return nil
  end

  if project == "cwd" then
    return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  end

  if project == "git" then
    local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
    if root == "" then
      -- Not inside a git repository; fall back to the cwd derivation.
      return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    end
    return vim.fn.fnamemodify(root, ":t")
  end

  return nil
end

--- Build the full sf1 command string, including `--project` when scoped.
---@return string command
local function _command()
  local name = _resolve_project()
  local sf1_cmd = config.cmd
  if name ~= nil then
    sf1_cmd = sf1_cmd .. " --project " .. vim.fn.shellescape(name)
  end

  if not config.styling.enabled then
    return sf1_cmd
  end

  local proxy_path = _proxy_path()
  if vim.fn.filereadable(proxy_path) == 0 then
    _warn_styling_unavailable("sf1_proxy.py not found at " .. proxy_path)
    return sf1_cmd
  end
  if vim.fn.executable("python3") == 0 then
    _warn_styling_unavailable("python3 not found on PATH")
    return sf1_cmd
  end

  return "python3 "
    .. vim.fn.shellescape(proxy_path)
    .. " --separator "
    .. config.styling.separator
    .. " -- "
    .. sf1_cmd
end

--- Configure the sf1 integration. Safe to call with no arguments.
---@param opts SapienceConfig|table|nil
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)

  vim.validate("cmd", config.cmd, "string")
  vim.validate(
    "position",
    config.position,
    _is_valid_position,
    'one of "bottom", "right", "left", "float"'
  )
  vim.validate("size", config.size, _is_valid_size, "a number in (0, 1]")
  vim.validate(
    "project",
    config.project,
    _is_valid_project,
    '"cwd", "git", false, or a function'
  )
  vim.validate("on_open", config.on_open, _is_valid_hook, "a function or nil")
  vim.validate("on_close", config.on_close, _is_valid_hook, "a function or nil")
  vim.validate(
    "styling",
    config.styling,
    _is_valid_styling,
    'a table with enabled:boolean and separator one of "blank", "rule", "none"'
  )
end

--- Run one of the two lifecycle hooks, if configured. A hook that errors
--- warns rather than propagating: a misbehaving host-side callback must never
--- prevent the window itself from opening or closing.
---@param name "on_open"|"on_close"
local function _run_hook(name)
  local hook = config[name]
  if type(hook) ~= "function" then
    return
  end
  local ok, err = pcall(hook)
  if not ok then
    vim.notify("sf1: " .. name .. " hook failed: " .. tostring(err), vim.log.levels.WARN)
  end
end

--- Report whether an sf1 window is currently displayed.
---@return boolean visible
function M.is_visible()
  return backend.visible(_command())
end

--- Open (or re-focus) the sf1 terminal window.
function M.open()
  local cmd = _command()
  local was_visible = backend.visible(cmd)
  if not was_visible then
    _run_hook("on_open")
  end
  backend.show(cmd, config.position, config.size)
end

--- Close the sf1 terminal window, if one is open.
function M.close()
  local cmd = _command()
  local was_visible = backend.visible(cmd)
  backend.close(cmd)
  if was_visible then
    _run_hook("on_close")
  end
end

--- Toggle the sf1 terminal window's visibility.
function M.toggle()
  local cmd = _command()
  local was_visible = backend.visible(cmd)
  if was_visible then
    _run_hook("on_close")
  else
    _run_hook("on_open")
  end
  backend.open(cmd, config.position, config.size)
end

--- Change the sf1 window's position, re-placing a live window immediately
--- without restarting its REPL.
---@param pos "bottom"|"right"|"left"|"float"
function M.set_position(pos)
  vim.validate(
    "pos",
    pos,
    _is_valid_position,
    'one of "bottom", "right", "left", "float"'
  )
  config.position = pos

  local cmd = _command()
  if backend.find(cmd) then
    backend.reposition(cmd, config.position, config.size)
  end
end

return M
