-- Typst ftplugin configuration
-- Keybindings use <leader>l (same as LaTeX) - filetype isolation prevents conflicts

local process = require("neotex.util.process")
local typst = require("neotex.util.typst")

-- Keep tinymist pinned to the resolved main file across LspAttach (including after
-- :LspRestart) and BufEnter (switching chapters). Also sync immediately for this buffer,
-- in case tinymist is already attached (e.g. a buffer reload).
typst.setup_autocmds()
typst.sync_pin(0)

-- Pin current file as the project-wide main file (for multi-file projects). The pin lives
-- in the shared helper, keyed by project root, so it applies from any chapter buffer and
-- survives :LspRestart (re-sent on the next LspAttach via typst.setup_autocmds()).
local function pin_main_file()
  local current_file = vim.api.nvim_buf_get_name(0)
  local root = typst.project_root(current_file)
  typst.pin(root, current_file)
  typst.sync_pin(0)

  vim.notify(
    "Pinned " .. vim.fn.fnamemodify(current_file, ":t") .. " as main file for "
      .. vim.fn.fnamemodify(root, ":t"),
    vim.log.levels.INFO
  )
end

-- Unpin the main file for this project. tinymist stays pinned -- to the detected main
-- file, not to nothing -- so exportPdf=onSave keeps targeting a real document.
local function unpin_main_file()
  local root = typst.project_root(vim.api.nvim_buf_get_name(0))
  typst.unpin(root)
  typst.sync_pin(0)

  vim.notify("Unpinned main file for " .. vim.fn.fnamemodify(root, ":t"), vim.log.levels.INFO)
end

-- Parse typst short diagnostic format: file:line:col: level: message
-- Example: chapters/foo.typ:10:5: error: undefined variable
local function parse_typst_error(line, project_root)
  local file, lnum, col, level, msg = line:match("^(.+):(%d+):(%d+): (%w+): (.+)$")
  if file and lnum then
    -- Make path absolute if relative
    local abs_file = file
    if not file:match("^/") and project_root then
      abs_file = project_root .. "/" .. file
    elseif not file:match("^/") then
      abs_file = vim.fn.getcwd() .. "/" .. file
    end

    return {
      filename = abs_file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      type = level == "error" and "E" or (level == "warning" and "W" or "I"),
      text = msg,
    }
  end
  return nil
end

-- Helper functions for Typst operations
local function typst_compile()
  local main_file = typst.main_file(vim.api.nvim_buf_get_name(0))
  local main_filename = vim.fn.fnamemodify(main_file, ":t")
  local root = typst.project_root(main_file)

  local cmd = {
    "typst", "compile", "--diagnostic-format", "short", "--root", root, main_file,
  }

  local root_info = " (root: " .. vim.fn.fnamemodify(root, ":t") .. ")"
  vim.notify("Compiling " .. main_filename .. root_info .. "...", vim.log.levels.INFO)

  local stderr_lines = {}

  process.start({
    name = "typst-compile",
    cmd = cmd,
    cwd = root,
    on_stderr = function(data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          -- Clear quickfix on success
          vim.fn.setqflist({}, "r", { title = "Typst Errors", items = {} })
          vim.notify("Compilation successful", vim.log.levels.INFO)
        else
          -- Parse stderr and populate quickfix
          local qf_items = {}
          for _, line in ipairs(stderr_lines) do
            local item = parse_typst_error(line, root)
            if item then
              table.insert(qf_items, item)
            end
          end

          if #qf_items > 0 then
            vim.fn.setqflist({}, "r", { title = "Typst Errors", items = qf_items })
            vim.cmd("copen")
            vim.notify(
              "Compilation failed: " .. #qf_items .. " error(s)",
              vim.log.levels.ERROR
            )
          else
            -- No parseable errors, show raw stderr
            vim.fn.setqflist({}, "r", { title = "Typst Errors", items = {} })
            local stderr_msg = table.concat(stderr_lines, "\n")
            if stderr_msg ~= "" then
              vim.notify("Compilation failed:\n" .. stderr_msg, vim.log.levels.ERROR)
            else
              vim.notify("Compilation failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
            end
          end
        end
      end)
    end,
  })
end

local function typst_watch()
  -- Toggle: stop if running
  local entry = process.find_by_name("typst-watch")
  if entry then
    process.stop(entry.id)
    return
  end

  local main_file = typst.main_file(vim.api.nvim_buf_get_name(0))
  local main_filename = vim.fn.fnamemodify(main_file, ":t")
  local root = typst.project_root(main_file)

  local cmd = { "typst", "watch", "--root", root, main_file }

  local root_info = " (root: " .. vim.fn.fnamemodify(root, ":t") .. ")"
  vim.notify("Starting watch on " .. main_filename .. root_info .. "...", vim.log.levels.INFO)
  process.start({
    name = "typst-watch",
    cmd = cmd,
    cwd = root,
    on_stdout = function(data)
      if data and #data > 0 then
        local msg = table.concat(data, "\n")
        if msg:match("compiled successfully") then
          vim.notify("Compiled successfully", vim.log.levels.INFO)
        end
      end
    end,
    on_exit = function(exit_code)
      if exit_code ~= 0 and exit_code ~= 143 then -- 143 is SIGTERM (normal stop)
        vim.notify("Watch stopped (exit code: " .. exit_code .. ")", vim.log.levels.WARN)
      end
    end,
  })
end

local function typst_view_pdf()
  local main_file = typst.main_file(vim.api.nvim_buf_get_name(0))
  local pdf = typst.pdf_path(main_file)

  if vim.fn.filereadable(pdf) == 1 then
    vim.fn.jobstart({ "sioyek", pdf }, { detach = true })
  else
    local pdf_name = vim.fn.fnamemodify(pdf, ":t")
    vim.notify("PDF not found: " .. pdf_name .. ". Build one first with <leader>lb", vim.log.levels.WARN)
  end
end

local function typst_format()
  vim.lsp.buf.format({ async = true })
end

local function show_diagnostics()
  vim.diagnostic.open_float(nil, { focus = false, scope = "line" })
end

local function show_compilation_errors()
  vim.cmd("copen")
end

local function tinymist_clear_cache()
  -- Delete stale compiled artifacts (same base name as main .typ file)
  local main_file = typst.main_file(vim.api.nvim_buf_get_name(0))
  local main_dir = vim.fn.fnamemodify(main_file, ":h")
  local main_base = vim.fn.fnamemodify(main_file, ":t:r")
  local deleted = {}
  for _, ext in ipairs({ ".svg", ".pdf" }) do
    local path = main_dir .. "/" .. main_base .. ext
    if vim.fn.filereadable(path) == 1 then
      vim.fn.delete(path)
      table.insert(deleted, main_base .. ext)
    end
  end

  pcall(vim.cmd, "TypstPreviewStop")
  process.deregister("typst-preview")
  vim.cmd("LspRestart tinymist")

  local msg = "tinymist cache cleared"
  if #deleted > 0 then
    msg = msg .. " | deleted: " .. table.concat(deleted, ", ")
  end
  vim.notify(msg .. " | run <leader>ll to reopen", vim.log.levels.INFO)
end

-- TypstPreview wrappers with process registry tracking
local function typst_preview_start()
  vim.cmd("TypstPreview")
  process.register_external({ name = "typst-preview", cmd = "tinymist preview", type = "browser" })
end

local function typst_preview_stop()
  vim.cmd("TypstPreviewStop")
  process.deregister("typst-preview")
end

local function typst_preview_toggle()
  local entry = process.find_by_name("typst-preview")
  if entry then
    typst_preview_stop()
  else
    typst_preview_start()
  end
end

-- Stop every background process this document owns. Typst runs two independent ones
-- (a `typst watch` compiler and the tinymist web preview); <leader>lx stops whichever
-- are live, so the shared "stop" verb does not need the caller to know which is which.
local function typst_stop_all()
  local stopped = {}

  local watch = process.find_by_name("typst-watch")
  if watch then
    process.stop(watch.id)
    table.insert(stopped, "watch")
  end

  if process.find_by_name("typst-preview") then
    typst_preview_stop()
    table.insert(stopped, "preview")
  end

  if #stopped == 0 then
    vim.notify("Nothing running for this document", vim.log.levels.WARN)
  else
    vim.notify("Stopped " .. table.concat(stopped, " + "), vim.log.levels.INFO)
  end
end

-- Register which-key bindings for Typst (uses <leader>l like LaTeX)
-- NOTE: Sync features (forward/backward) only work with the web preview (<leader>ll)
--       PDF viewer (<leader>lv) does not support sync (similar to LaTeX without SyncTeX)
local ok_wk, wk = pcall(require, "which-key")
if ok_wk then
  wk.add({
    { "<leader>l", group = "typst", icon = "󰬛", buffer = 0 },

    -- Shared core verbs (same meaning in the latex and slidev groups)
    { "<leader>ll", typst_preview_toggle, desc = "live preview (web)", icon = "", buffer = 0 },
    { "<leader>lb", typst_compile, desc = "build once", icon = "", buffer = 0 },
    { "<leader>lv", typst_view_pdf, desc = "view pdf (Sioyek)", icon = "", buffer = 0 },
    { "<leader>le", show_diagnostics, desc = "errors (LSP)", icon = "", buffer = 0 },
    { "<leader>lf", typst_format, desc = "format", icon = "", buffer = 0 },
    { "<leader>lk", tinymist_clear_cache, desc = "clean artifacts", icon = "󰃢", buffer = 0 },
    { "<leader>lx", typst_stop_all, desc = "stop (watch + preview)", icon = "󰅚", buffer = 0 },

    -- Typst-specific extras
    { "<leader>lw", typst_watch, desc = "watch (toggle)", icon = "", buffer = 0 },
    { "<leader>lq", show_compilation_errors, desc = "quickfix (compile)", icon = "", buffer = 0 },
    { "<leader>ls", "<cmd>TypstPreviewSyncCursor<CR>", desc = "sync cursor (web)", icon = "", buffer = 0 },
    { "<leader>lp", pin_main_file, desc = "pin main file", icon = "", buffer = 0 },
    { "<leader>lu", unpin_main_file, desc = "unpin main file", icon = "", buffer = 0 },
  })
end

-- Enable treesitter highlighting for Typst
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

-- Set up formatting options
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Enable spell checking for prose
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"

-- Disable winfixbuf for Typst files to allow typst-preview cross-jump
vim.opt_local.winfixbuf = false
