-- neotex.config.options
-- NeoVim options configuration

local M = {}

function M.setup()
  -- Disable unused built-in plugins to improve startup performance
  vim.g.loaded_matchit = 1        -- Disable enhanced % matching
  vim.g.loaded_matchparen = 1     -- Disable highlight of matching parentheses
  vim.g.loaded_tutor_mode_plugin = 1  -- Disable tutorial
  vim.g.loaded_2html_plugin = 1   -- Disable 2html converter
  vim.g.loaded_zipPlugin = 1      -- Disable zip file browsing
  vim.g.loaded_tarPlugin = 1      -- Disable tar file browsing
  vim.g.loaded_gzip = 1           -- Disable gzip file handling
  vim.g.loaded_netrw = 1          -- Disable netrw (using nvim-tree instead)
  vim.g.loaded_netrwPlugin = 1    -- Disable netrw plugin
  vim.g.loaded_netrwSettings = 1  -- Disable netrw settings
  vim.g.loaded_netrwFileHandlers = 1  -- Disable netrw file handlers
  vim.g.loaded_spellfile_plugin = 1  -- Disable spellfile plugin
  
  -- Set clipboard provider BEFORE clipboard=unnamedplus to prevent Neovim
  -- from caching the default wl-copy provider (which steals Wayland focus
  -- on GNOME, causing title bar flicker -- see Neovim #12622, wl-clipboard #90).
  -- OSC 52 writes through the terminal escape sequence (no external process).
  -- Paste reads the system clipboard via wl-paste so text copied in other apps works.
  -- OSC 52 and wl-paste carry only text, not the register type, so the last yank's
  -- lines and regtype are cached: if the clipboard still holds that yank, its type
  -- (e.g. linewise "V" from yy) is restored; otherwise the content is pasted charwise.
  if vim.env.WAYLAND_DISPLAY then
    local osc52 = require("vim.ui.clipboard.osc52")
    local last_yank = {}

    -- Linewise yanks arrive as { ..., "" }; wl-paste --no-newline drops that trailing
    -- line, so compare without it.
    local function strip_trailing_empty(lines)
      local copy = vim.deepcopy(lines)
      if #copy > 1 and copy[#copy] == "" then
        table.remove(copy)
      end
      return copy
    end

    local function make_copy(reg)
      local send = osc52.copy(reg)
      return function(lines, regtype)
        last_yank[reg] = { lines = strip_trailing_empty(lines), regtype = regtype }
        send(lines)
      end
    end

    local function make_paste(reg, cmd)
      return function()
        local output = vim.fn.systemlist(cmd)
        if vim.v.shell_error ~= 0 then
          output = {}
        end
        local cached = last_yank[reg]
        if cached and vim.deep_equal(cached.lines, strip_trailing_empty(output)) then
          return { output, cached.regtype }
        end
        return { output, "v" }
      end
    end

    vim.g.clipboard = {
      name = "osc52",
      copy = {
        ["+"] = make_copy("+"),
        ["*"] = make_copy("*"),
      },
      paste = {
        ["+"] = make_paste("+", "wl-paste --no-newline"),
        ["*"] = make_paste("*", "wl-paste --no-newline --primary"),
      },
    }
  end

  local options = {
    -- GENERAL
    timeoutlen = 100,               -- time to wait for a mapped sequence to complete (in milliseconds)
    updatetime = 200,               -- faster completion (4000ms default)
    swapfile = false,               -- creates a swapfile
    undofile = true,                -- enable persistent undo
    writebackup = false,            -- if a file is being edited by another program, it is not allowed to be edited

    -- APPEARANCE
    laststatus = 3,                 -- views can only be fully collapsed with the global statusline
    fileencoding = "utf-8",         -- the encoding written to a file
    guifont = "monospace:h17",      -- the font used in graphical neovim applications
    background = "dark",            -- colorschemes that can be light or dark will be made dark
    termguicolors = true,           -- set term gui colors (most terminals support this)
    conceallevel = 0,               -- so that `` is visible in markdown files
    number = true,                  -- set numbered lines
    relativenumber = true,          -- set relative numbered lines
    numberwidth = 2,                -- set number column width to 2 {default 4}
    signcolumn = "yes",             -- always show the sign column, otherwise it would shift the text each time
    fillchars = "eob: ,horiz:─,horizup:┴,horizdown:┬,vert:│", -- thin window separators
    cursorline = true,              -- highlight the current line
    -- colorcolumn = "100",             -- highlight vertical colorcolumn (moved to after/python.lua)
    wrap = true,                    -- display lines as one long line
    showbreak = "  ",               -- set indent of wrapped lines
    cmdheight = 1,                  -- space in the neovim command line for displaying messages
    pumheight = 7,                  -- pop up menu height
    showmode = false,               -- we don't need to see things like -- INSERT -- anymore
    splitbelow = true,              -- force all horizontal splits to go below current window
    splitright = true,              -- force all vertical splits to go to the right of current window
    scrolloff = 7,                  -- minimal number of screen lines to keep above and below the cursor
    sidescrolloff = 7,              -- minimal number of screen columns either side of cursor if wrap is `false`
    shortmess = "filnxtToOFcI",     -- which errors to suppress (I suppresses intro message)
    mousemoveevent = true,

    -- INDENT
    tabstop = 2,                    -- insert 2 spaces for a tab
    shiftwidth = 2,                 -- the number of spaces inserted for each indentation
    softtabstop = 2,                -- insert 2 spaces for a tab
    expandtab = true,               -- convert tabs to spaces
    breakindent = true,             -- tab wrapped lines
    linebreak = true,               -- companion to wrap, don't split words
    backspace = "indent,eol,start", -- allow backspace on indent, end of line or insert mode start position

    -- EDIT
    spell = true,                   -- turns on spellchecker
    spelllang = { 'en_us' },        -- sets spelling dictionary
    clipboard = "unnamedplus",      -- allows neovim to access the system clipboard
    mouse = "a",                    -- allow the mouse to be used in neovim
    mousefocus = true,              -- window focus follows mouse pointer (enables hover scrolling)
    mousescroll = "ver:1,hor:2",    -- change the speed of the scroll wheel
    ignorecase = true,              -- ignore case in search patterns
    smartcase = true,               -- smart case
    virtualedit = "block",          -- vitualblock mode doesn't get stuck at the end of line
    inccommand = "split",           -- shows all inline replacements in split
    autoread = true,  -- Auto-reload files when changed externally

    -- FOLDING
    foldenable = true,      -- Disable folding by default
    foldmethod = "manual",   -- Set manual folding
    foldlevel = 99,         -- Open all folds by default
  }

  -- Apply all options
  for k, v in pairs(options) do
    vim.opt[k] = v
  end
  
  -- Disable Ctrl+click tag jumping for markdown files
  vim.api.nvim_create_autocmd({"FileType"}, {
    pattern = {"markdown", "lectic.markdown"},
    callback = function()
      vim.opt_local.tagfunc = ""
    end
  })

  -- Load utilities for folding and URL handling
  local ok, utils = pcall(require, "neotex.util")
  if not ok then
    vim.notify("Failed to load neotex.util module", vim.log.levels.WARN)
  end
  
  -- Load the persistent folding state when entering any buffer
  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = {"*"},
    callback = function()
      -- Try to use the new util module first
      local ok, fold_utils = pcall(require, "neotex.util.fold")
      if ok and fold_utils and fold_utils.load_folding_state then
        fold_utils.load_folding_state()
      else
        -- Fall back to global function if available
        if _G.LoadFoldingState then
          _G.LoadFoldingState()
        end
      end
    end
  })
  
  -- Set up global URL handling for all buffers
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      vim.defer_fn(function()
        -- Try to use the new util module first
        local ok, url_utils = pcall(require, "neotex.util.url")
        if ok and url_utils and url_utils.setup_url_mappings then
          url_utils.setup_url_mappings()
        else
          -- Fall back to global function if available
          if _G.SetupUrlMappings then
            _G.SetupUrlMappings()
          end
        end
      end, 200)
    end,
    once = true
  })

  -- CLIPBOARD -- (for yanky)
  -- May help Arch/Debian Linux users
  -- vim.g.clipboard = {
  --   name = "xsel_override",
  --   copy = {
  --     ["+"] = "xsel --input --clipboard",
  --     ["*"] = "xsel --input --primary",
  --   },
  --   paste = {
  --     ["+"] = "xsel --output --clipboard",
  --     ["*"] = "xsel --output --primary",
  --   },
  --   cache_enabled = 1,
  -- }
  
  -- Performance optimizations
  -- Reduce the frequency of status line updates
  -- lazyredraw removed: causes visual blinking on yank (Neovim #2253, #11806)
  
  -- Set higher CursorHold time to reduce CPU usage
  vim.opt.updatetime = 300
  
  -- Limit syntax highlighting for better performance
  vim.opt.synmaxcol = 200
  
  -- Limit the number of screen lines to be redrawn
  vim.opt.redrawtime = 1500
  
  -- Limit backups to improve performance
  vim.opt.history = 500
  
  -- Limit jumplist to improve performance
  vim.opt.jumpoptions = "stack"
  vim.opt.shada = "!,'100,<50,s10,h"
  
  return true
end

return M