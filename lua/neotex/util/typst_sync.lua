-- Typst <-> PDF synchronisation and live-PDF mode for Sioyek.
--
-- Three capabilities, all resting on the same project-scoped daemon
-- (`scripts/typst-sync-daemon.py`), which owns a headless `tinymist preview` and resolves
-- positions in both directions:
--
--   * live PDF mode -- on every write, wait for tinymist's `exportPdf = "onSave"` to land
--     a new PDF, then tell Sioyek to reload it. Sioyek does poll for changes on its own,
--     but only inside a narrow timing window, so an explicit reload is what makes the
--     refresh dependable rather than probable.
--   * forward search -- resolve the cursor to a page and point, scroll Sioyek there, and
--     mark the line.
--   * inverse search -- resolve a clicked page and point back to a file and position, and
--     move the cursor there. Driven by Sioyek's `control_click_command` through a
--     registry file this module maintains.
--
-- "Which document is this" is never decided here: it is delegated to
-- `neotex.util.typst` so the daemon, the PDF path, and the tinymist pin always agree.

local process = require("neotex.util.process")
local typst = require("neotex.util.typst")

local M = {}

-- Per-project state, keyed by normalized project root.
---@type table<string, { socket: string, job: integer|nil, pdf: string }>
local sessions = {}

-- Augroup id for live PDF mode, or nil when the mode is off. One group for all
-- projects: the autocmd resolves the main file per buffer, so a single group covers
-- every open Typst project.
local live_group = nil

local DAEMON_RELATIVE = "scripts/typst-sync-daemon.py"
-- How long to wait for tinymist to finish writing the PDF after a save, and how often
-- to look. tinymist exports asynchronously, so the reload has to follow the file rather
-- than the write event.
local EXPORT_POLL_MS = 150
local EXPORT_TIMEOUT_MS = 8000

--- Normalize a project root for use as a key.
---@param root string
---@return string
local function normalize(root)
  return (vim.fn.fnamemodify(root, ":p"):gsub("/$", ""))
end

--- Absolute path to the daemon script shipped with this configuration.
---@return string
local function daemon_script()
  return vim.fn.stdpath("config") .. "/" .. DAEMON_RELATIVE
end

--- Socket path for a project root.
---
--- Deliberately short and flat: `AF_UNIX` caps a socket path at 108 bytes, so a path
--- derived from the project directory would break for a deeply nested project. A hash
--- of the root keeps it bounded while staying one-to-one with the project.
---@param root string
---@return string
function M.socket_path(root)
  local base = vim.env.XDG_RUNTIME_DIR
  if not base or base == "" then
    base = "/tmp"
  end
  return base .. "/nvim-typst-sync-" .. vim.fn.sha256(normalize(root)):sub(1, 12) .. ".sock"
end

--- Path of the registry file describing how to reach Neovim for a given PDF.
---
--- Keyed by the PDF rather than the project, because the Sioyek side only knows which
--- file it has open.
---@param pdf string
---@return string
function M.registry_path(pdf)
  return vim.fn.stdpath("cache")
    .. "/typst-sync/"
    .. vim.fn.sha256(vim.fn.fnamemodify(pdf, ":p")):sub(1, 12)
    .. ".json"
end

--- Record how to reach this Neovim instance, and this project's daemon, for `pdf`.
---
--- The Sioyek click handler runs as a detached process with no connection to this
--- session, so the two facts it cannot discover -- the daemon socket and the Neovim
--- server address -- are written where it can find them by PDF path.
---@param pdf string
---@param root string
local function write_registry(pdf, root)
  local path = M.registry_path(pdf)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local ok, encoded = pcall(vim.json.encode, {
    pdf = vim.fn.fnamemodify(pdf, ":p"),
    root = normalize(root),
    socket = M.socket_path(root),
    servername = vim.v.servername,
    pid = vim.fn.getpid(),
  })
  if ok then
    pcall(vim.fn.writefile, { encoded }, path)
  end
end

--- Send one request to the project daemon and hand the reply to `callback`.
---
--- One connection per request, matching the daemon's line-in/line-out contract. The
--- daemon serializes the underlying resolutions itself, so there is nothing to
--- coordinate on this side.
---@param root string
---@param request string
---@param callback fun(ok: boolean, parts: string[], raw: string)
local function send(root, request, callback)
  local socket = M.socket_path(root)
  local pipe = vim.uv.new_pipe(false)
  if not pipe then
    callback(false, {}, "could not create pipe")
    return
  end

  local chunks = {}
  local settled = false
  local function settle(ok, raw)
    if settled then
      return
    end
    settled = true
    pcall(function()
      pipe:read_stop()
    end)
    pcall(function()
      pipe:close()
    end)
    local parts = vim.split(vim.trim(raw), " ", { trimempty = true })
    vim.schedule(function()
      callback(ok, parts, vim.trim(raw))
    end)
  end

  pipe:connect(socket, function(connect_err)
    if connect_err then
      settle(false, "daemon not reachable: " .. tostring(connect_err))
      return
    end
    pipe:read_start(function(read_err, data)
      if read_err then
        settle(false, tostring(read_err))
      elseif data then
        table.insert(chunks, data)
        local joined = table.concat(chunks)
        if joined:find("\n") then
          settle(true, joined)
        end
      else
        -- EOF: the daemon closes after replying.
        settle(true, table.concat(chunks))
      end
    end)
    pipe:write(request .. "\n")
  end)

  -- Never let a wedged daemon hang a keypress.
  vim.defer_fn(function()
    settle(false, "daemon timed out")
  end, 12000)
end

--- Start the daemon for `root` if it is not already answering.
---@param main_file string
---@param root string
---@param callback fun(ok: boolean, err: string|nil)
function M.ensure_daemon(main_file, root, callback)
  local key = normalize(root)
  send(root, "ping", function(ok, parts)
    if ok and parts[1] == "ok" then
      callback(true, nil)
      return
    end

    local script = daemon_script()
    if vim.fn.filereadable(script) == 0 then
      callback(false, "daemon script missing: " .. script)
      return
    end

    local socket = M.socket_path(root)
    -- A socket file left by a crashed daemon would otherwise shadow the new one.
    pcall(vim.fn.delete, socket)

    local job = vim.fn.jobstart({
      "python3", script,
      "--main", main_file,
      "--root", key,
      "--socket", socket,
    }, { detach = false })

    if job <= 0 then
      callback(false, "could not start the typst sync daemon")
      return
    end

    sessions[key] = { socket = socket, job = job, pdf = typst.pdf_path(main_file) }
    process.register_external({
      name = "typst-sync",
      cmd = "typst-sync-daemon " .. vim.fn.fnamemodify(main_file, ":t"),
      type = "server",
    })

    -- The daemon has to spawn tinymist and wait out a first compile before it can
    -- answer, so poll for readiness instead of guessing a delay.
    local waited = 0
    local function poll()
      send(root, "ping", function(ping_ok, ping_parts)
        if ping_ok and ping_parts[1] == "ok" then
          callback(true, nil)
          return
        end
        waited = waited + 500
        if waited >= 30000 then
          callback(false, "the typst sync daemon did not become ready")
          return
        end
        vim.defer_fn(poll, 500)
      end)
    end
    vim.defer_fn(poll, 1500)
  end)
end

--- Stop the daemon for the project owning `path`.
---@param path string
function M.stop_daemon(path)
  local root = typst.project_root(path)
  local key = normalize(root)
  send(root, "shutdown", function() end)
  local session = sessions[key]
  if session and session.job and session.job > 0 then
    pcall(vim.fn.jobstop, session.job)
  end
  sessions[key] = nil
  process.deregister("typst-sync")
end

-- ---------------------------------------------------------------------------
-- Sioyek
-- ---------------------------------------------------------------------------

--- Strip Typst markup from a source line so Sioyek can match it against PDF text.
---
--- `focus_text` scores candidate lines by longest common subsequence, so the text need
--- not be exact -- only close enough that the intended line wins. Markup is removed
--- rather than approximated, and the characters that would break Sioyek's own command
--- parsing (`;` separates macro steps, parentheses delimit an argument) are dropped.
---@param line string
---@return string
-- Typst code statements. A line of one lays out nothing, so it has no counterpart in
-- the PDF to mark and must not contribute a near-miss string to match against.
local CODE_KEYWORDS = {
  import = true, include = true, set = true, show = true, let = true,
  ["if"] = true, ["else"] = true, ["for"] = true, ["while"] = true, ["return"] = true,
}

function M.plain_text(line)
  local keyword = line:match("^%s*#%s*(%a+)")
  if keyword and CODE_KEYWORDS[keyword] then
    return ""
  end

  local text = line
  text = text:gsub("#%a[%w_%-]*%b()", " ") -- function calls: #cite(...), #link(...)
  text = text:gsub('"[^"]*"', " ") -- quoted arguments: paths, keys, settings
  text = text:gsub("<[%w_%-:%.]+>", " ") -- labels: <sec-introduction>
  text = text:gsub("@[%w_%-:%.]+", " ") -- references: @sec-introduction
  text = text:gsub("%$[^$]*%$", " ") -- inline math
  text = text:gsub("^%s*=+%s*", "") -- heading markers
  text = text:gsub("[#_%*`%$%[%]%(%);]", " ") -- residual markup and unsafe characters
  text = text:gsub("%s+", " ")
  return vim.trim(text)
end

--- Scroll Sioyek to a document position and mark the line sitting there.
---
--- Two invocations, in this order, because Sioyek's own argument handling decides it:
--- a run that names a file ends by reopening the document, which resets the view and
--- clears the visual mark. So the positioning run goes first (`--page/--xloc/--yloc`
--- take exactly the page-relative points tinymist reports), and the marking run follows
--- without a file argument, leaving the mark as the last thing applied.
---@param pdf string
---@param page_no integer 1-based, as tinymist reports it
---@param x number
---@param y number
---@param text string|nil line text to mark, or nil to only scroll
function M.sioyek_show(pdf, page_no, x, y, text)
  vim.fn.jobstart({
    "sioyek", "--reuse-window", "--nofocus",
    "--page", tostring(page_no),
    "--xloc", string.format("%.3f", x),
    "--yloc", string.format("%.3f", y),
    pdf,
  }, { detach = true })

  if not text or text == "" then
    return
  end

  -- `focus_text` reads a leading `#<page>` as a 0-based page index, unlike `--page`.
  local payload = "#" .. tostring(page_no - 1) .. " " .. text
  vim.defer_fn(function()
    vim.fn.jobstart({
      "sioyek", "--nofocus",
      "--execute-command", "focus_text",
      "--execute-command-data", payload,
    }, { detach = true })
  end, 120)
end

--- Ask Sioyek to reload the PDF it already has open.
---@param pdf string
local function sioyek_reload(pdf)
  vim.fn.jobstart({
    "sioyek", "--nofocus", "--execute-command", "reload_no_flicker",
  }, { detach = true })
  local _ = pdf
end

-- ---------------------------------------------------------------------------
-- Forward and inverse search
-- ---------------------------------------------------------------------------

--- Forward search: show the PDF position matching the cursor.
---@param bufnr integer|nil
function M.forward(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    vim.notify("Save the buffer before syncing to the PDF", vim.log.levels.WARN)
    return
  end

  local main_file = typst.main_file(file)
  local root = typst.project_root(main_file)
  local pdf = typst.pdf_path(main_file)
  if vim.fn.filereadable(pdf) == 0 then
    vim.notify("No PDF yet -- save the file or build with <leader>lb", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line0, col0 = cursor[1] - 1, cursor[2]
  local text = M.plain_text(vim.api.nvim_buf_get_lines(bufnr, line0, line0 + 1, false)[1] or "")

  write_registry(pdf, root)
  M.ensure_daemon(main_file, root, function(ready, err)
    if not ready then
      vim.notify("Typst sync: " .. (err or "daemon unavailable"), vim.log.levels.ERROR)
      return
    end
    local request = ("forward %d %d %s"):format(line0, col0, file)
    send(root, request, function(ok, parts, raw)
      if not ok or parts[1] ~= "ok" then
        vim.notify("Typst sync: " .. raw, vim.log.levels.WARN)
        return
      end
      local page_no = tonumber(parts[2])
      local x, y = tonumber(parts[3]), tonumber(parts[4])
      if not (page_no and x and y) then
        vim.notify("Typst sync: malformed reply: " .. raw, vim.log.levels.WARN)
        return
      end
      M.sioyek_show(pdf, page_no, x, y, text)
    end)
  end)
end

--- Inverse search: move the cursor to the source position behind a PDF point.
---
--- Called over Neovim's RPC by the Sioyek click handler, so it takes the raw document
--- position Sioyek reports: a 0-based page index, and x/y in page-relative points.
---@param sioyek_page integer 0-based, as Sioyek's `%{mouse_pos_document}` reports it
---@param x number
---@param y number
---@param pdf string
function M.inverse(sioyek_page, x, y, pdf)
  local main_file = vim.fn.fnamemodify(pdf, ":r") .. ".typ"
  if vim.fn.filereadable(main_file) == 0 then
    vim.notify("Typst sync: no source beside " .. pdf, vim.log.levels.WARN)
    return
  end
  local root = typst.project_root(main_file)

  M.ensure_daemon(main_file, root, function(ready, err)
    if not ready then
      vim.notify("Typst sync: " .. (err or "daemon unavailable"), vim.log.levels.ERROR)
      return
    end
    -- tinymist counts pages from one, Sioyek from zero.
    local request = ("inverse %d %f %f"):format(sioyek_page + 1, x, y)
    send(root, request, function(ok, parts, raw)
      if not ok or parts[1] ~= "ok" then
        vim.notify("Typst sync: nothing at that point (" .. raw .. ")", vim.log.levels.WARN)
        return
      end
      local line0, col0 = tonumber(parts[2]), tonumber(parts[3])
      local path = table.concat(vim.list_slice(parts, 4), " ")
      if not (line0 and path ~= "") then
        vim.notify("Typst sync: malformed reply: " .. raw, vim.log.levels.WARN)
        return
      end
      M.jump_to(path, line0, col0 or 0)
    end)
  end)
end

--- Inverse search entry point for the Sioyek click handler.
---
--- The call arrives over `nvim --remote-expr`, so the arguments cross a shell and then
--- Vimscript. Only three numbers and the registry key travel that way -- all of them
--- quote-free by construction -- and the PDF path is read back from the registry file
--- instead of being passed. A document path containing a space or a quote therefore
--- cannot break the call.
---@param args table { page0, x, y, key }
function M.inverse_rpc(args)
  if type(args) ~= "table" then
    vim.notify("Typst sync: malformed inverse-search call", vim.log.levels.WARN)
    return
  end
  local page0 = tonumber(args[1])
  local x, y = tonumber(args[2]), tonumber(args[3])
  local key = tostring(args[4] or "")

  if not (page0 and x and y) or not key:match("^%x+$") then
    vim.notify("Typst sync: malformed inverse-search call", vim.log.levels.WARN)
    return
  end

  local registry = vim.fn.stdpath("cache") .. "/typst-sync/" .. key .. ".json"
  local ok, lines = pcall(vim.fn.readfile, registry)
  if not ok or not lines or not lines[1] then
    vim.notify("Typst sync: no registry entry for that PDF", vim.log.levels.WARN)
    return
  end
  local decoded_ok, decoded = pcall(vim.json.decode, lines[1])
  if not decoded_ok or type(decoded) ~= "table" or not decoded.pdf then
    vim.notify("Typst sync: unreadable registry entry", vim.log.levels.WARN)
    return
  end

  M.inverse(page0, x, y, decoded.pdf)
end

--- Open `path` and place the cursor at a 0-based position.
---@param path string
---@param line0 integer
---@param col0 integer
function M.jump_to(path, line0, col0)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  local last = vim.api.nvim_buf_line_count(0)
  local lnum = math.min(line0 + 1, last)
  local width = #(vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or "")
  pcall(vim.api.nvim_win_set_cursor, 0, { lnum, math.min(col0, width) })
  vim.cmd("normal! zz")
end

-- ---------------------------------------------------------------------------
-- Live PDF mode
-- ---------------------------------------------------------------------------

--- Whether live PDF mode is on.
---@return boolean
function M.live_active()
  return live_group ~= nil
end

--- Reload the PDF in Sioyek once tinymist has finished rewriting it.
---
--- The export is asynchronous and the write is not atomic from a reader's point of
--- view, so this waits for the modification time to advance and then for it to hold
--- steady before asking Sioyek to reload.
---@param pdf string
local function reload_when_exported(pdf)
  local function mtime()
    local stat = vim.uv.fs_stat(pdf)
    return stat and (stat.mtime.sec * 1000 + math.floor(stat.mtime.nsec / 1e6)) or 0
  end

  local before = mtime()
  local waited = 0
  local function poll()
    local now = mtime()
    if now > before then
      -- Let the writer finish before reading the file into the viewer.
      vim.defer_fn(function()
        sioyek_reload(pdf)
      end, EXPORT_POLL_MS)
      return
    end
    waited = waited + EXPORT_POLL_MS
    if waited >= EXPORT_TIMEOUT_MS then
      return
    end
    vim.defer_fn(poll, EXPORT_POLL_MS)
  end
  vim.defer_fn(poll, EXPORT_POLL_MS)
end

--- Turn live PDF mode on: open the PDF, then reload it after every write.
function M.live_on()
  local file = vim.api.nvim_buf_get_name(0)
  local main_file = typst.main_file(file)
  local root = typst.project_root(main_file)
  local pdf = typst.pdf_path(main_file)

  if vim.fn.filereadable(pdf) == 1 then
    vim.fn.jobstart({ "sioyek", "--reuse-window", pdf }, { detach = true })
  else
    vim.notify(
      "No PDF yet for " .. vim.fn.fnamemodify(main_file, ":t") .. " -- it appears on the next save",
      vim.log.levels.INFO
    )
  end

  write_registry(pdf, root)

  live_group = vim.api.nvim_create_augroup("NeotexTypstLivePdf", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = live_group,
    pattern = "*.typ",
    callback = function(args)
      -- Resolve per write: switching chapters must keep targeting the same document,
      -- and tinymist exports whichever main file it is pinned to.
      local buf_main = typst.main_file(vim.api.nvim_buf_get_name(args.buf))
      reload_when_exported(typst.pdf_path(buf_main))
    end,
  })

  vim.notify(
    "Live PDF: on (" .. vim.fn.fnamemodify(pdf, ":t") .. " reloads on save)",
    vim.log.levels.INFO
  )
end

--- Turn live PDF mode off. Sioyek and the daemon are left alone: the viewer is still
--- useful, and `<leader>lx` is the verb for tearing processes down.
function M.live_off()
  if live_group then
    pcall(vim.api.nvim_del_augroup_by_id, live_group)
    live_group = nil
  end
  vim.notify("Live PDF: off", vim.log.levels.INFO)
end

--- Toggle live PDF mode.
function M.live_toggle()
  if M.live_active() then
    M.live_off()
  else
    M.live_on()
  end
end

return M
