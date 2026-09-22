-- Enhanced Jupyter styling for Markdown files (.md)
if vim.fn.expand("%:e") == "md" then
  -- Check if this is a Jupyter-converted markdown file
  local lines = vim.api.nvim_buf_get_lines(0, 0, 20, false)
  local is_jupyter = false

  for _, line in ipairs(lines) do
    if line:match("^```python") then
      is_jupyter = true
      break
    end
  end

  if is_jupyter then
    -- Apply Jupyter notebook styling
    vim.opt_local.signcolumn = "yes:1"

    -- Ensure our styling module is loaded
    vim.defer_fn(function()
      local ok, styling = pcall(require, "neotex.plugins.tools.jupyter.styling")
      if ok and type(styling) == "table" and styling.setup then
        styling.setup()
      end
    end, 100)
  end
end

-- Apply custom markdown comment highlighting
vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter", "ColorScheme"}, {
  buffer = 0,
  callback = function()
    -- Define muted color for comments (Gruvbox gray)
    local muted_color = "#928374"

    -- Ensure HTML comment highlights are set
    vim.api.nvim_set_hl(0, "htmlComment", { fg = muted_color, italic = true })
    vim.api.nvim_set_hl(0, "htmlCommentPart", { fg = muted_color, italic = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownHtmlComment", { fg = muted_color, italic = true })
  end
})

-- ============================================================================
-- Slidev deck bindings (<leader>l)
--
-- Mirrors the <leader>l "document build/preview" group that after/ftplugin/tex.lua
-- and after/ftplugin/typst.lua register for their filetypes. Buffer-local, and only
-- registered for markdown buffers that are part of a Slidev project, so ordinary
-- markdown keeps <leader>l free.
--
-- The dev server is tracked by neotex.util.process, so decks started here show up in
-- the process picker (<leader>xp) and are stopped on exit alongside everything else.
-- ============================================================================

local ok_process, process = pcall(require, "neotex.util.process")

if ok_process and process.is_slidev_deck(vim.api.nvim_buf_get_name(0)) then
  local deck = vim.api.nvim_buf_get_name(0)
  local deck_dir = vim.fn.fnamemodify(deck, ":h")
  local deck_name = vim.fn.fnamemodify(deck, ":t")
  local deck_pdf = vim.fn.fnamemodify(deck, ":r") .. ".pdf"

  -- Find the running dev server for *this* deck (not merely the first process named
  -- "slidev"), so several decks can be served at once without stepping on each other.
  -- Matched on the deck path in argv, which every start path puts there.
  local function deck_entry()
    for _, entry in ipairs(process.list()) do
      if entry.status == "running" and type(entry.cmd) == "table" then
        for _, arg in ipairs(entry.cmd) do
          if arg == deck then
            return entry
          end
        end
      end
    end
    return nil
  end

  local function open_browser(path)
    local entry = deck_entry()
    if not entry or not entry.port then
      vim.notify("No Slidev server running for " .. deck_name, vim.log.levels.WARN)
      return
    end
    local url = "http://localhost:" .. entry.port .. (path or "")
    local opener = (vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1) and "open" or "xdg-open"
    vim.fn.jobstart({ opener, url }, { detach = true })
  end

  -- Start the dev server and open `path` once it is actually serving.
  --
  -- Mirrors the "markdown" launcher in neotex/util/process.lua, but drives the browser
  -- ourselves for two reasons: the presenter view needs to open somewhere other than
  -- the root URL, and process.lua's fixed browser_delay (2000ms) races a cold Slidev
  -- start, which takes ~4s here. The banner line Slidev prints once the port is live is
  -- the reliable signal; the timer is only a fallback if that banner ever changes.
  local function start_server(path)
    local opened = false
    local function open_once()
      if not opened then
        opened = true
        open_browser(path)
      end
    end

    local id = process.start({
      cmd = { "npx", "@slidev/cli", deck, "--port", "{port}" },
      name = "slidev",
      cwd = deck_dir,
      port = true,
      base_port = 3030,
      open_browser = false,
      on_stdout = function(data)
        if opened then
          return
        end
        for _, line in ipairs(data) do
          if line and line:find("public slide show", 1, true) then
            vim.schedule(open_once)
            return
          end
        end
      end,
    })

    if id then
      vim.defer_fn(open_once, 15000)
    end
    return id
  end

  -- One-shot `slidev <subcommand>`; progress and failures are reported via notify.
  local function run_slidev(label, args)
    local stderr_lines = {}
    vim.notify("slidev " .. label .. ": " .. deck_name .. "...", vim.log.levels.INFO)
    process.start({
      cmd = vim.list_extend({ "npx", "@slidev/cli" }, args),
      name = "slidev-" .. label,
      cwd = deck_dir,
      on_stderr = function(data)
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end,
      on_exit = function(code)
        vim.schedule(function()
          if code == 0 then
            vim.notify("slidev " .. label .. " finished", vim.log.levels.INFO)
          else
            local msg = table.concat(stderr_lines, "\n")
            vim.notify("slidev " .. label .. " failed (exit " .. code .. ")"
              .. (msg ~= "" and ("\n" .. msg) or ""), vim.log.levels.ERROR)
          end
        end)
      end,
    })
  end

  local function deck_toggle()
    local entry = deck_entry()
    if entry then
      process.stop(entry.id)
    else
      start_server("")
    end
  end

  local function deck_open()
    if deck_entry() then
      open_browser("")
    else
      start_server("")
    end
  end

  local function deck_presenter()
    if deck_entry() then
      open_browser("/presenter/")
    else
      start_server("/presenter/")
    end
  end

  local function deck_stop()
    local entry = deck_entry()
    if entry then
      process.stop(entry.id)
    else
      vim.notify("No Slidev server running for " .. deck_name, vim.log.levels.WARN)
    end
  end

  local function deck_build()
    run_slidev("build", { "build", deck })
  end

  local function deck_export()
    run_slidev("export", { "export", deck, "--output", deck_pdf })
  end

  local function deck_view_pdf()
    -- Prefer the deterministic path we pass to --output; fall back to Slidev's
    -- default `<name>-export.pdf` in case the deck was exported outside nvim.
    local candidates = { deck_pdf, vim.fn.fnamemodify(deck, ":r") .. "-export.pdf" }
    for _, pdf in ipairs(candidates) do
      if vim.fn.filereadable(pdf) == 1 then
        vim.fn.jobstart({ "sioyek", pdf }, { detach = true })
        return
      end
    end
    vim.notify("No exported PDF found. Build one first with <leader>lb", vim.log.levels.WARN)
  end

  local ok_wk_slidev, wk_slidev = pcall(require, "which-key")
  if ok_wk_slidev then
    wk_slidev.add({
      { "<leader>l", group = "slidev", icon = "󰐊", buffer = 0 },

      -- Shared core verbs (same meaning in the latex and typst groups). lb builds the
      -- artifact that lv then opens, exactly as in those groups -- for a deck that is
      -- the exported PDF, not the static site, which sits on lB.
      { "<leader>ll", deck_toggle, desc = "live preview (toggle)", icon = "󰆈", buffer = 0 },
      { "<leader>lb", deck_export, desc = "build pdf (export)", icon = "󰈙", buffer = 0 },
      { "<leader>lv", deck_view_pdf, desc = "view pdf (Sioyek)", icon = "󰛓", buffer = 0 },
      { "<leader>lx", deck_stop, desc = "stop server", icon = "󰅚", buffer = 0 },

      -- Slidev-specific extras
      { "<leader>ls", deck_build, desc = "build site (dist/)", icon = "󰸞", buffer = 0 },
      { "<leader>lo", deck_open, desc = "open in browser", icon = "󰌝", buffer = 0 },
      { "<leader>lp", deck_presenter, desc = "presenter view", icon = "󰐩", buffer = 0 },
    })
  end
end
