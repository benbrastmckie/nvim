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

--- @class SapienceConfig
--- @field cmd string Executable name used to launch sf1
--- @field position "bottom"|"right"|"left"|"float" Window placement
--- @field size number Fraction in (0, 1], meaningful for split positions only
--- @field project "cwd"|"git"|false|fun():string|nil Project-scoping strategy

---@type SapienceConfig
local config = {
  cmd = "sf1",
  position = "bottom",
  size = 0.35,
  project = "cwd",
}

local VALID_POSITIONS = { bottom = true, right = true, left = true, float = true }

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
local function _is_valid_project(v)
  if v == false then
    return true
  end
  if type(v) == "function" then
    return true
  end
  return v == "cwd" or v == "git"
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
  if name == nil then
    return config.cmd
  end
  return config.cmd .. " --project " .. vim.fn.shellescape(name)
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
end

--- Open (or re-focus) the sf1 terminal window.
function M.open()
  backend.open(_command(), config.position, config.size)
end

--- Close the sf1 terminal window, if one is open.
function M.close()
  backend.close(_command())
end

--- Toggle the sf1 terminal window's visibility.
function M.toggle()
  backend.open(_command(), config.position, config.size)
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
