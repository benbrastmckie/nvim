-----------------------------------------------------------
-- Process Manager
--
-- Centralized process manager for background jobs in Neovim.
-- Provides a job registry, lifecycle management (start/stop/list),
-- port auto-detection via vim.uv.new_tcp(), browser auto-open
-- with duplicate prevention, VimLeavePre cleanup, and a
-- filetype launcher registry for extensibility.
--
-- This module is required explicitly rather than auto-loaded
-- by util/init.lua to avoid generic name collisions.
-----------------------------------------------------------

local M = {}

-- Private state
M._registry = {}
M._next_id = 1
M._opened_ports = {}
M._launchers = {}
M._shutting_down = false

-- ---------------------------------------------------------------------------
-- Ring buffer for stdout/stderr capture
-- ---------------------------------------------------------------------------

--- Create a ring buffer with a maximum line count.
---@param max_size number Maximum number of lines to retain (default 200)
---@return table Ring buffer with :push(line) and :lines() methods
--- Strip ANSI escape sequences from a string.
---@param str string
---@return string
local function _strip_ansi(str)
  return str:gsub("\27%[[%d;]*[A-Za-z]", "")
end

local function _make_ring_buffer(max_size)
  max_size = max_size or 200
  local buf = { _data = {}, _max = max_size }

  --- Push a line into the ring buffer, evicting the oldest if full.
  ---@param line string
  function buf:push(line)
    if line == nil or line == "" then
      return
    end
    table.insert(self._data, line)
    while #self._data > self._max do
      table.remove(self._data, 1)
    end
  end

  --- Return all retained lines as an ordered array.
  ---@return string[]
  function buf:lines()
    return vim.list_extend({}, self._data)
  end

  return buf
end

-- ---------------------------------------------------------------------------
-- Port detection
-- ---------------------------------------------------------------------------

--- Find an available TCP port starting from base_port.
--- Scans base_port through base_port+100 using vim.uv.new_tcp() bind test.
---@param base_port number Starting port to scan (default 3030)
---@return number|nil port The first available port, or nil on failure
local function _find_available_port(base_port)
  base_port = base_port or 3030
  for offset = 0, 100 do
    local port = base_port + offset
    local tcp = vim.uv.new_tcp()
    if tcp then
      local ok = tcp:bind("127.0.0.1", port)
      tcp:close()
      if ok == 0 then
        return port
      end
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Browser auto-open (Phase 2)
-- ---------------------------------------------------------------------------

--- Open a browser to localhost:<port> with deduplication and delay.
---@param port number Port number to open
---@param delay number|nil Delay in ms before opening (default 1500)
local function _open_browser(port, delay)
  if M._opened_ports[port] then
    return
  end
  M._opened_ports[port] = true
  delay = delay or 1500

  vim.defer_fn(function()
    local cmd
    if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
      cmd = { "open", "http://localhost:" .. port }
    else
      cmd = { "xdg-open", "http://localhost:" .. port }
    end
    vim.fn.jobstart(cmd, { detach = true })
  end, delay)
end

-- ---------------------------------------------------------------------------
-- Notification helpers (Phase 2)
-- ---------------------------------------------------------------------------

--- Send a process-manager notification (suppressed during shutdown).
---@param msg string Message text
---@param category table Notification category from neotex.util.notifications
local function _notify(msg, category)
  if M._shutting_down then
    return
  end
  local ok, notify = pcall(require, "neotex.util.notifications")
  if ok then
    notify.editor(msg, category)
  else
    vim.notify(msg, (category and category.level) or vim.log.levels.INFO)
  end
end

--- Get notification categories table (lazy-loaded).
---@return table|nil categories
local function _categories()
  local ok, notify = pcall(require, "neotex.util.notifications")
  if ok then
    return notify.categories
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Slidev detection (Phase 3)
-- ---------------------------------------------------------------------------

--- Check whether a file belongs to a Slidev project.
--- Looks for package.json containing @slidev/cli in the file's directory
--- or parent, and also checks markdown frontmatter for slidev keys.
---@param filepath string Absolute path to a markdown file
---@return boolean
local function _is_slidev_project(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")

  -- Check package.json in current dir and one level up
  for _, d in ipairs({ dir, vim.fn.fnamemodify(dir, ":h") }) do
    local pkg_path = d .. "/package.json"
    if vim.fn.filereadable(pkg_path) == 1 then
      local lines = vim.fn.readfile(pkg_path)
      local content = table.concat(lines, "\n")
      if content:find("@slidev/cli", 1, true) then
        return true
      end
    end
  end

  -- Check markdown frontmatter for slidev keys
  if vim.fn.filereadable(filepath) == 1 then
    local lines = vim.fn.readfile(filepath, "", 20)
    if lines and #lines > 0 and lines[1] == "---" then
      local slidev_keys = { "theme:", "layout:", "highlighter:", "drawings:" }
      for i = 2, math.min(#lines, 20) do
        if lines[i] == "---" then
          break
        end
        for _, key in ipairs(slidev_keys) do
          if lines[i]:find(key, 1, true) then
            return true
          end
        end
      end
    end
  end

  return false
end

-- ---------------------------------------------------------------------------
-- Core API (Phase 1)
-- ---------------------------------------------------------------------------

--- Start a background process and register it in the process manager.
---
--- opts fields:
---   cmd        (table)   Command and arguments (required)
---   name       (string)  Display name (required)
---   cwd        (string)  Working directory (optional)
---   port       (true|number) true for auto-detect, number for explicit
---   base_port  (number)  Starting port for auto-detect (default 3030)
---   open_browser (bool)  Open browser to localhost:<port> after start
---   browser_delay (number) Delay in ms before browser open (default 1500)
---   on_stdout  (fn)      User callback for stdout lines
---   on_stderr  (fn)      User callback for stderr lines
---   on_exit    (fn)      User callback for process exit
---
---@param opts table Process options
---@return number|nil id Registry id, or nil on failure
function M.start(opts)
  if not opts or not opts.cmd or type(opts.cmd) ~= "table" or #opts.cmd == 0 then
    _notify("process.start: opts.cmd must be a non-empty table",
      (_categories() or {}).ERROR)
    return nil
  end

  -- Resolve port
  local port = nil
  if opts.port == true then
    port = _find_available_port(opts.base_port or 3030)
    if not port then
      _notify("No available port found", (_categories() or {}).ERROR)
      return nil
    end
  elseif type(opts.port) == "number" then
    port = opts.port
  end

  -- Substitute {port} placeholder in cmd args
  local cmd = {}
  for _, arg in ipairs(opts.cmd) do
    if type(arg) == "string" and port then
      table.insert(cmd, (arg:gsub("{port}", tostring(port))))
    else
      table.insert(cmd, arg)
    end
  end

  -- Prepare registry entry
  local id = M._next_id
  M._next_id = M._next_id + 1

  local stdout_buf = _make_ring_buffer(200)
  local stderr_buf = _make_ring_buffer(200)

  local entry = {
    id = id,
    job_id = nil,
    name = opts.name or "unnamed",
    cmd = cmd,
    port = port,
    cwd = opts.cwd,
    start_time = os.time(),
    stdout = stdout_buf,
    stderr = stderr_buf,
    status = "running",
    exit_code = nil,
  }

  -- Start the job
  local job_opts = {
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          stdout_buf:push(_strip_ansi(line))
        end
      end
      if opts.on_stdout and data then
        opts.on_stdout(data)
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          stderr_buf:push(_strip_ansi(line))
        end
      end
      if opts.on_stderr and data then
        opts.on_stderr(data)
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        entry.status = "exited"
        entry.exit_code = exit_code
        local cats = _categories()
        if exit_code == 0 then
          _notify(string.format("%s exited", entry.name),
            cats and cats.STATUS)
        else
          _notify(string.format("%s exited with code %d", entry.name, exit_code),
            cats and cats.WARNING)
        end
        if opts.on_exit then
          opts.on_exit(exit_code)
        end
      end)
    end,
  }

  if opts.cwd then
    job_opts.cwd = opts.cwd
  end

  local job_id = vim.fn.jobstart(cmd, job_opts)
  if job_id <= 0 then
    _notify(string.format("Failed to start %s", opts.name or "process"),
      (_categories() or {}).ERROR)
    M._next_id = M._next_id - 1
    return nil
  end

  entry.job_id = job_id
  M._registry[id] = entry

  -- Notifications
  local cats = _categories()
  if port then
    _notify(string.format("Started %s on port %d", entry.name, port),
      cats and cats.USER_ACTION)
  else
    _notify(string.format("Started %s", entry.name),
      cats and cats.USER_ACTION)
  end

  -- Browser auto-open
  if opts.open_browser and port then
    _open_browser(port, opts.browser_delay)
  end

  return id
end

--- Stop a tracked process by registry id.
---@param id number Registry id returned by M.start()
---@return boolean success
function M.stop(id)
  local entry = M._registry[id]
  if not entry then
    return false
  end

  if entry.job_id then
    pcall(vim.fn.jobstop, entry.job_id)
  end
  entry.status = "stopped"

  local cats = _categories()
  _notify(string.format("Stopped %s", entry.name),
    cats and cats.USER_ACTION)

  M._registry[id] = nil
  return true
end

--- Stop all tracked processes and clear the registry.
function M.stop_all()
  for id, entry in pairs(M._registry) do
    if entry.job_id then
      pcall(vim.fn.jobstop, entry.job_id)
    end
    entry.status = "stopped"
  end
  M._registry = {}
end

--- Return an array of info tables for all tracked processes.
---@return table[] entries Array of {id, name, cmd, port, cwd, start_time, status, exit_code}
function M.list()
  local result = {}
  for _, entry in pairs(M._registry) do
    table.insert(result, {
      id = entry.id,
      name = entry.name,
      cmd = entry.cmd,
      port = entry.port,
      cwd = entry.cwd,
      start_time = entry.start_time,
      status = entry.status,
      exit_code = entry.exit_code,
    })
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

--- Get a registry entry by id (includes stdout/stderr ring buffers).
---@param id number Registry id
---@return table|nil entry
function M.get(id)
  return M._registry[id]
end

--- Find the first registry entry matching a given name.
---@param name string Process name to search for
---@return table|nil entry
function M.find_by_name(name)
  for _, entry in pairs(M._registry) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

--- Find the first registry entry matching a given port.
---@param port number Port number
---@return table|nil entry
function M.find_by_port(port)
  for _, entry in pairs(M._registry) do
    if entry.port == port then
      return entry
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Browser tracking (Phase 2)
-- ---------------------------------------------------------------------------

--- Reset browser tracking to allow re-opening previously opened ports.
function M.reset_browser_tracking()
  M._opened_ports = {}
end

-- ---------------------------------------------------------------------------
-- Virtual process registration (Phase 3)
-- ---------------------------------------------------------------------------

--- Register an external process not managed by jobstart.
--- Useful for wrapping plugin-managed processes (e.g., TypstPreview).
---@param opts table {name, cmd (display string), type (string), port (optional)}
---@return number id Registry id
function M.register_external(opts)
  local id = M._next_id
  M._next_id = M._next_id + 1

  local entry = {
    id = id,
    job_id = nil,
    name = opts.name or "external",
    cmd = opts.cmd or "external",
    port = opts.port,
    cwd = nil,
    start_time = os.time(),
    stdout = _make_ring_buffer(200),
    stderr = _make_ring_buffer(200),
    status = "running",
    exit_code = nil,
    type = opts.type or "external",
  }

  M._registry[id] = entry
  return id
end

--- Remove a virtual entry by name or id.
---@param name_or_id string|number Process name or registry id
---@return boolean success
function M.deregister(name_or_id)
  if type(name_or_id) == "number" then
    if M._registry[name_or_id] then
      M._registry[name_or_id] = nil
      return true
    end
    return false
  end

  for id, entry in pairs(M._registry) do
    if entry.name == name_or_id then
      M._registry[id] = nil
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Filetype launcher registry (Phase 3)
-- ---------------------------------------------------------------------------

--- Register a launcher function for a filetype.
---@param ft string Filetype (e.g., "markdown", "typst")
---@param launcher_fn fun(filepath: string): table|nil Returns opts for M.start() or nil
function M.register_launcher(ft, launcher_fn)
  M._launchers[ft] = launcher_fn
end

--- Launch a process for the given file (or current buffer).
--- Looks up the filetype launcher and calls M.start() with the returned opts.
---@param filepath string|nil File path (defaults to current buffer)
---@return number|nil id Registry id, or nil if no launcher or launch failed
function M.launch(filepath)
  filepath = filepath or vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype
  if not ft or ft == "" then
    ft = vim.filetype.match({ filename = filepath })
  end

  -- Check if this file already has a running process
  for _, entry in pairs(M._registry) do
    if entry.status == "running" and entry.cmd then
      for _, arg in ipairs(entry.cmd) do
        if arg == filepath then
          local port = entry.port
          if port then
            _notify(string.format("Already open on port: %d", port))
          else
            _notify(string.format("Already running: %s (id %d)", entry.name, entry.id))
          end
          return entry.id
        end
      end
    end
  end

  local launcher = M._launchers[ft]
  if not launcher then
    local cats = _categories()
    _notify(string.format("No launcher registered for filetype: %s", ft or "unknown"),
      cats and cats.WARNING)
    return nil
  end

  local opts = launcher(filepath)
  if not opts then
    return nil
  end

  return M.start(opts)
end

--- Return a list of registered launcher filetypes.
---@return string[]
function M.get_launchers()
  return vim.tbl_keys(M._launchers)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

--- Initialize the process manager.
--- Creates the ProcessManager augroup with VimLeavePre cleanup and
--- registers default filetype launchers.
---@param opts table|nil Reserved for future configuration
function M.setup(opts)
  opts = opts or {}

  -- Create augroup for cleanup
  local augroup = vim.api.nvim_create_augroup("ProcessManager", { clear = true })

  -- Ensure all tracked processes are stopped on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      M._shutting_down = true
      M.stop_all()
    end,
    desc = "Stop all tracked processes on Neovim exit",
  })

  -- Register default launchers

  -- Slidev launcher for markdown files in slidev projects
  M.register_launcher("markdown", function(filepath)
    if not _is_slidev_project(filepath) then
      return nil
    end
    local dir = vim.fn.fnamemodify(filepath, ":h")
    return {
      cmd = { "npx", "slidev", filepath, "--port", "{port}" },
      name = "slidev",
      cwd = dir,
      port = true,
      base_port = 3030,
      open_browser = true,
      browser_delay = 2000,
    }
  end)

  -- Typst launcher wraps TypstPreview command (plugin manages its own process)
  M.register_launcher("typst", function(_)
    vim.cmd("TypstPreview")
    return nil -- TypstPreview manages its own process
  end)
end

-- Expose internals for testing/debugging
M._find_available_port = _find_available_port
M._make_ring_buffer = _make_ring_buffer
M._is_slidev_project = _is_slidev_project

-- Auto-initialize on first require
M.setup()

return M
