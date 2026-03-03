-- neotex.config.keymaps
-- Centralized non-leader keybinding configuration
-- This module contains ALL non-leader keybindings for consistent management

--[[ KEYBINDINGS - COMPLETE REFERENCE
-----------------------------------------------------------

COMPLETE DOCUMENTATION: See docs/MAPPINGS.md for comprehensive keybinding reference
Please maintain consistency between this file and docs/MAPPINGS.md when making changes.

This file is the SINGLE SOURCE OF TRUTH for all non-leader keybindings in the configuration.
Leader-key mappings are defined in plugins/editor/which-key.lua for which-key integration.

Organization:
- Global keymaps use the `map()` function with descriptions
- Buffer-specific maps use `buf_map()` in setup functions (e.g., `set_terminal_keymaps()`)
- Plugin files should have empty `keys = {}` tables to prevent conflicting mappings
- AI assistant toggles (Claude Code, OpenCode) are defined globally in this file

----------------------------------------------------------------------------------
AI/ASSISTANT GLOBAL KEYBINDINGS                | DESCRIPTION
----------------------------------------------------------------------------------
<C-c>                                          | Toggle Claude Code (overridden in Telescope)
<leader>ao                                      | OpenCode commands (via which-key)

----------------------------------------------------------------------------------
TERMINAL MODE KEYBINDINGS                      | DESCRIPTION
----------------------------------------------------------------------------------
<Esc>                                          | Exit terminal mode to normal mode
<C-t>                                          | Toggle terminal window
<C-h>, <C-j>, <C-k>, <C-l>                     | Navigate between windows
<M-h>, <M-l>, <M-Left>, <M-Right>              | Resize terminal window horizontally

----------------------------------------------------------------------------------
GENERAL KEYBINDINGS                            | DESCRIPTION
----------------------------------------------------------------------------------
<Space>                                        | Leader key for command sequences
<C-z>                                          | Disabled (prevents accidental suspension)
<C-t>                                          | Toggle terminal window
<C-s>                                          | Show spelling suggestions with Telescope
<CR> (Enter)                                   | Clear search highlighting
<C-p>                                          | Find files with Telescope
<C-;>                                          | Toggle comments for current line/selection
<S-m>                                          | Show help for word under cursor
<C-m>                                          | Search man pages with Telescope

----------------------------------------------------------------------------------
NAVIGATION KEYBINDINGS                         | DESCRIPTION
----------------------------------------------------------------------------------
Y                                              | Yank (copy) from cursor to end of line
E                                              | Go to end of previous word
m                                              | Center cursor at top of screen
<C-h>, <C-j>, <C-k>, <C-l>                    | Navigate between windows
<A-Left>, <A-Right>, <A-h>, <A-l>             | Resize window horizontally
<Tab>                                          | Go to next buffer (by modified time)
<S-Tab>                                        | Go to previous buffer (by modified time)
<C-u>, <C-d>                                   | Scroll half-page up/down (with centering)
<S-h>, <S-l>                                   | Go to start/end of display line
J, K                                           | Navigate display lines (respects wrapping)

----------------------------------------------------------------------------------
TEXT MANIPULATION                              | DESCRIPTION
----------------------------------------------------------------------------------
<A-j>, <A-k>                                   | Move current line or selection up/down
<, >                                           | Decrease/increase indentation (preserves selection)

----------------------------------------------------------------------------------
MARKDOWN-SPECIFIC KEYBINDINGS                  | DESCRIPTION
----------------------------------------------------------------------------------
<CR> (Enter)                                   | Create new bullet point
o                                              | Create new bullet point below
O                                              | Create new bullet point above
<Tab>                                          | Indent bullet and recalculate numbers
<S-Tab>                                        | Unindent bullet and recalculate numbers
dd                                             | Delete line and recalculate list numbers
d (visual mode)                                | Delete selection and recalculate numbers
<C-n>                                          | Toggle checkbox status ([ ] ↔ [x])
<C-c>                                          | Toggle Claude Code (global binding, not autolist)
--]]

local M = {}

function M.setup()
  ------------------------------------------
  -- HELPER FUNCTIONS FOR KEYMAP SETUP   --
  ------------------------------------------
  local opts = { noremap = true, silent = true }

  -- Helper function for global keymap definitions with descriptions
  local function map(mode, key, cmd, options, description)
    local opts = vim.tbl_deep_extend("force",
      { noremap = true, silent = true, desc = description },
      options or {}
    )
    vim.keymap.set(mode, key, cmd, opts)
  end

  -- Helper function for buffer-local keymap definitions
  local function buf_map(bufnr, mode, key, cmd, description)
    vim.api.nvim_buf_set_keymap(
      bufnr or 0,
      mode,
      key,
      cmd,
      { noremap = true, silent = true, desc = description }
    )
  end

  ----------------------------------------
  -- BUFFER-SPECIFIC KEYMAP FUNCTIONS  --
  ----------------------------------------

  -- Terminal-specific keybindings (called by terminal filetype autocmd)
  function _G.set_terminal_keymaps()
    -- Lock terminal window to prevent buffer switching
    vim.wo.winfixbuf = true

    -- Check terminal type for specialized keybindings
    local bufname = vim.api.nvim_buf_get_name(0)
    local is_claude = bufname:match("claude") or bufname:match("ClaudeCode")
    local is_opencode = vim.bo.filetype == "opencode_terminal"

    -- Terminal navigation
    -- Skip escape mapping for Claude Code to allow its internal normal mode
    if not is_claude then
      buf_map(0, "t", "<Esc>", "<C-\\><C-n>", "Exit terminal mode")
      -- In normal mode, Esc sends escape to the terminal app (for closing menus)
      buf_map(0, "n", "<Esc>", "i<Esc><C-\\><C-n>", "Send Esc to terminal app")
    end

    -- OpenCode terminals: Ctrl+j/k send arrow keys for menu navigation
    -- Other terminals: Ctrl+hjkl for window navigation
    if is_opencode then
      buf_map(0, "t", "<C-j>", "<Down>", "Menu down")
      buf_map(0, "t", "<C-k>", "<Up>", "Menu up")
      buf_map(0, "t", "<C-h>", "<Cmd>wincmd h<CR>", "Navigate left")
      buf_map(0, "t", "<C-l>", "<Cmd>wincmd l<CR>", "Navigate right")
      buf_map(0, "t", "<C-g>", "<cmd>lua require('opencode').toggle()<CR>", "Toggle Opencode")
    else
      buf_map(0, "t", "<C-h>", "<Cmd>wincmd h<CR>", "Navigate left")
      buf_map(0, "t", "<C-j>", "<Cmd>wincmd j<CR>", "Navigate down")
      buf_map(0, "t", "<C-k>", "<Cmd>wincmd k<CR>", "Navigate up")
      buf_map(0, "t", "<C-l>", "<Cmd>wincmd l<CR>", "Navigate right")
    end

    -- Terminal resizing
    buf_map(0, "t", "<M-Right>", "<Cmd>vertical resize -2<CR>", "Resize right")
    buf_map(0, "t", "<M-Left>", "<Cmd>vertical resize +2<CR>", "Resize left")
    buf_map(0, "t", "<M-l>", "<Cmd>vertical resize -2<CR>", "Resize right")
    buf_map(0, "t", "<M-h>", "<Cmd>vertical resize +2<CR>", "Resize left")
  end

  -- Markdown-specific keybindings (called by markdown filetype autocmd)
  function _G.set_markdown_keymaps()
    -- Attempt to load autolist module for intelligent list management
    local ok, autolist = pcall(require, "neotex.plugins.tools.autolist.util")

    -- Configure markdown-appropriate tab settings
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
    vim.opt.softtabstop = 2

    -- Configure keybindings with autolist integration if available
    if ok and autolist and autolist.operations then
      -- Smart list management through autolist handlers

      -- Intelligent Enter key handling for list continuation
      vim.keymap.set("i", "<CR>", autolist.operations.enter_handler,
        { expr = true, buffer = true, desc = "Smart list handling for Enter" })

      -- Smart tab handling for list indentation
      vim.keymap.set("i", "<Tab>", autolist.operations.tab_handler,
        { expr = true, buffer = true, desc = "Smart list indent" })

      vim.keymap.set("i", "<S-Tab>", autolist.operations.shift_tab_handler,
        { expr = true, buffer = true, desc = "Smart list unindent" })

      vim.keymap.set("i", "<C-D>", autolist.operations.shift_tab_handler,
        { expr = true, buffer = true, desc = "Smart list unindent (C-D)" })

      -- Normal mode list operations
      vim.keymap.set("n", "<C-n>", "<cmd>AutolistIncrementCheckbox<CR>",
        { buffer = true, desc = "Increment checkbox" })

      vim.keymap.set("n", "<A-n>", "<cmd>AutolistDecrementCheckbox<CR>",
        { buffer = true, desc = "Decrement checkbox" })

      vim.keymap.set("n", "o", "o<cmd>AutolistNewBullet<cr>",
        { buffer = true, desc = "New bullet below" })

      vim.keymap.set("n", "O", "O<cmd>AutolistNewBulletBefore<cr>",
        { buffer = true, desc = "New bullet above" })

      vim.keymap.set("n", ">", "><cmd>AutolistRecalculate<cr>",
        { buffer = true, desc = "Indent bullet" })

      vim.keymap.set("n", "<", "<<cmd>AutolistRecalculate<cr>",
        { buffer = true, desc = "Unindent bullet" })

      -- List recalculation is handled by <leader>rr in which-key

      -- Smart deletion that maintains list consistency
      vim.keymap.set("n", "dd", "dd<cmd>AutolistRecalculate<cr>",
        { buffer = true, desc = "Delete and recalculate" })

      vim.keymap.set("v", "d", "d<cmd>AutolistRecalculate<cr>",
        { buffer = true, desc = "Delete and recalculate" })
    else
      -- Fallback keybindings when autolist module is unavailable
      buf_map(0, "i", "<CR>", "<CR><cmd>AutolistNewBullet<cr>", "New bullet point")
      buf_map(0, "n", "o", "o<cmd>AutolistNewBullet<cr>", "New bullet below")
      buf_map(0, "n", "O", "O<cmd>AutolistNewBulletBefore<cr>", "New bullet above")
      buf_map(0, "n", "<C-n>", "<cmd>lua IncrementCheckbox()<CR>", "Increment checkbox")
      buf_map(0, "n", "<A-n>", "<cmd>lua DecrementCheckbox()<CR>", "Decrement checkbox")
    end
  end

  ---------------------------------
  -- GLOBAL KEYBOARD MAPPINGS   --
  ---------------------------------

  -- Disable potentially problematic default mappings
  map("n", "<C-z>", "<nop>", {}, "Disable suspend")
  map("n", "gc", "<nop>", {}, "Disable gc mappings")
  map("n", "gcc", "<nop>", {}, "Disable gcc mappings")

  -- Terminal window management
  map("n", "<C-t>", "<cmd>ToggleTerm<CR>", { remap = true }, "Toggle terminal")
  map("t", "<C-t>", "<cmd>ToggleTerm<CR>", { remap = true }, "Toggle terminal")

  -- Telescope-based spelling suggestions
  map("n", "<C-s>", function()
    require("telescope.builtin").spell_suggest(require("telescope.themes").get_cursor({
      previewer = false,
      layout_config = { width = 50, height = 15 }
    }))
  end, { remap = true }, "Spelling suggestions")

  -- Search and file finding
  map("n", "<CR>", "<cmd>noh<CR>", {}, "Clear search highlights")
  map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { remap = true }, "Find files")

  -- Code commenting with mini.comment plugin
  map("n", "<C-;>", function()
    local mini_comment = require('mini.comment')
    if mini_comment.toggle_lines then
      mini_comment.toggle_lines(vim.fn.line('.'), vim.fn.line('.'))
    else
      mini_comment.toggle()
    end
  end, {}, "Toggle comment on current line")

  -- Visual mode commenting (remaps to gc from mini.comment)
  map("v", "<C-;>", "gc", { remap = true }, "Toggle comment on selection")

  -- Documentation and help access
  map("n", "<S-m>", '<cmd>Telescope help_tags cword=true<cr>', {}, "Help for word under cursor")
  map("n", "<C-m>", '<cmd>Telescope man_pages<cr>', {}, "Search man pages")

  --------------------------------
  -- AI/ASSISTANT GLOBAL KEYS --
  --------------------------------

  -- Claude Code toggle (smart session management)
  map("n", "<C-CR>", function()
    require("neotex.plugins.ai.claude").smart_toggle()
  end, {}, "Toggle Claude Code")

  map("i", "<C-CR>", function()
    require("neotex.plugins.ai.claude").smart_toggle()
  end, {}, "Toggle Claude Code")

  map("v", "<C-CR>", function()
    require("neotex.plugins.ai.claude").smart_toggle()
  end, {}, "Toggle Claude Code")

  map("t", "<C-CR>", function()
    require("neotex.plugins.ai.claude").smart_toggle()
  end, {}, "Toggle Claude Code")

  -- OpenCode toggle
  -- Note: This global mapping is overridden by buffer-local mappings in Telescope pickers (<C-g> closes picker)
  map({ "n", "i" }, "<C-g>", function() require("opencode").toggle() end, {}, "Toggle Opencode")
 
   -- OpenCode toggle: Use <leader>aoo via which-key (preserves <C-o> for jump list)

  ------------------------
  -- TEXT EDITING KEYS --
  ------------------------

  -- Improved default text manipulation behaviors
  map("n", "Y", "y$", {}, "Yank to end of line")
  map("n", "E", "ge", {}, "Go to end of previous word")
  map("v", "Y", "y$", {}, "Yank to end of line")

  -- Screen positioning and cursor centering
  map("n", "m", "zt", {}, "Center cursor at top")
  map("v", "m", "zt", {}, "Center cursor at top")

  -- Window navigation using Ctrl+hjkl
  map("n", "<C-h>", "<C-w>h", {}, "Navigate left")
  map("n", "<C-j>", "<C-w>j", {}, "Navigate down")
  map("n", "<C-k>", "<C-w>k", {}, "Navigate up")
  map("n", "<C-l>", "<C-w>l", {}, "Navigate right")

  -- Window resizing with Alt+arrows and Alt+hl
  map("n", "<A-Left>", ":vertical resize -2<CR>", {}, "Decrease width")
  map("n", "<A-Right>", ":vertical resize +2<CR>", {}, "Increase width")
  map("n", "<A-h>", ":vertical resize -2<CR>", {}, "Decrease width")
  map("n", "<A-l>", ":vertical resize +2<CR>", {}, "Increase width")

  -- Smart buffer navigation with fallback chain
  local buffer_utils_loaded = false

  -- Attempt to load advanced buffer utilities
  local ok, buffer_utils = pcall(require, "neotex.util.buffer")
  if ok and buffer_utils and buffer_utils.goto_buffer then
    buffer_utils_loaded = true

    -- Use intelligent buffer switching (sorted by modification time)
    map("n", "<TAB>", function() buffer_utils.goto_buffer(1, 1) end, {}, "Next buffer")
    map("n", "<S-TAB>", function() buffer_utils.goto_buffer(1, -1) end, {}, "Previous buffer")

    -- Restore <C-i> for jump-forward navigation (requires Kitty keyboard protocol)
    -- Note: <C-i> and <Tab> send identical keycodes in traditional terminals.
    -- Modern keyboard protocols (Kitty, CSI u) can distinguish them.
    -- This mapping ensures <C-i> jumps forward in jump list when protocol is enabled.
    map("n", "<C-i>", "<C-i>", { noremap = true }, "Jump forward in jump list")
  end

  -- Fallback chain if advanced utils are unavailable
  if not buffer_utils_loaded then
    -- Try global function if available
    if _G.GotoBuffer then
      map("n", "<TAB>", function() _G.GotoBuffer(1, 1) end, {}, "Next buffer")
      map("n", "<S-TAB>", function() _G.GotoBuffer(1, -1) end, {}, "Previous buffer")
      map("n", "<C-i>", "<C-i>", { noremap = true }, "Jump forward in jump list")
    else
      -- Safe buffer navigation that excludes terminal and unlisted buffers
      local function safe_buffer_next()
        local buffers = vim.fn.getbufinfo({ buflisted = 1 })
        local normal_buffers = {}
        
        for _, buf in ipairs(buffers) do
          -- Only include normal buffers (not terminals)
          if vim.api.nvim_buf_is_valid(buf.bufnr) and 
             vim.api.nvim_buf_get_option(buf.bufnr, 'buftype') == '' then
            table.insert(normal_buffers, buf)
          end
        end
        
        if #normal_buffers > 1 then
          local current = vim.fn.bufnr('%')
          local current_index = 1
          for i, buf in ipairs(normal_buffers) do
            if buf.bufnr == current then
              current_index = i
              break
            end
          end
          
          local next_index = current_index >= #normal_buffers and 1 or current_index + 1
          vim.cmd('buffer ' .. normal_buffers[next_index].bufnr)
        end
      end
      
      local function safe_buffer_prev()
        local buffers = vim.fn.getbufinfo({ buflisted = 1 })
        local normal_buffers = {}
        
        for _, buf in ipairs(buffers) do
          -- Only include normal buffers (not terminals)
          if vim.api.nvim_buf_is_valid(buf.bufnr) and 
             vim.api.nvim_buf_get_option(buf.bufnr, 'buftype') == '' then
            table.insert(normal_buffers, buf)
          end
        end
        
        if #normal_buffers > 1 then
          local current = vim.fn.bufnr('%')
          local current_index = 1
          for i, buf in ipairs(normal_buffers) do
            if buf.bufnr == current then
              current_index = i
              break
            end
          end
          
          local prev_index = current_index <= 1 and #normal_buffers or current_index - 1
          vim.cmd('buffer ' .. normal_buffers[prev_index].bufnr)
        end
      end
      
      map("n", "<TAB>", safe_buffer_next, {}, "Next buffer")
      map("n", "<S-TAB>", safe_buffer_prev, {}, "Previous buffer")
      map("n", "<C-i>", "<C-i>", { noremap = true }, "Jump forward in jump list")
    end
  end

  -- Line and selection movement with Alt+jk
  map("n", "<A-j>", "<Esc>:m .+1<CR>==", {}, "Move line down")
  map("n", "<A-k>", "<Esc>:m .-2<CR>==", {}, "Move line up")
  map("x", "<A-j>", ":move '>+1<CR>gv-gv", {}, "Move selection down")
  map("x", "<A-k>", ":move '<-2<CR>gv-gv", {}, "Move selection up")
  map("v", "<A-j>", ":m'>+<CR>gv", {}, "Move selection down")
  map("v", "<A-k>", ":m-2<CR>gv", {}, "Move selection up")

  -- Enhanced scrolling that keeps cursor centered
  map("n", "<c-u>", "<c-u>zz", {}, "Scroll up with centering")
  map("n", "<c-d>", "<c-d>zz", {}, "Scroll down with centering")

  -- Quickfix list navigation (centered cursor for visibility)
  map("n", "]q", "<cmd>cnext<cr>zz", {}, "Next quickfix item")
  map("n", "[q", "<cmd>cprev<cr>zz", {}, "Previous quickfix item")
  map("n", "]Q", "<cmd>clast<cr>zz", {}, "Last quickfix item")
  map("n", "[Q", "<cmd>cfirst<cr>zz", {}, "First quickfix item")

  -- Location list navigation (buffer-local quickfix)
  map("n", "]l", "<cmd>lnext<cr>zz", {}, "Next location list item")
  map("n", "[l", "<cmd>lprev<cr>zz", {}, "Previous location list item")
  map("n", "]L", "<cmd>llast<cr>zz", {}, "Last location list item")
  map("n", "[L", "<cmd>lfirst<cr>zz", {}, "First location list item")

  -- Display line navigation (respects word wrapping)
  map("v", "<S-h>", "g^", {}, "Go to start of display line")
  map("v", "<S-l>", "g$", {}, "Go to end of display line")
  map("n", "<S-h>", "g^", {}, "Go to start of display line")
  map("n", "<S-l>", "g$", {}, "Go to end of display line")

  -- Smart indentation that preserves selection
  map("v", "<", "<gv", {}, "Decrease indent and reselect")
  map("v", ">", ">gv", {}, "Increase indent and reselect")
  map("n", "<", "<S-v><<esc>", {}, "Decrease indent for line")
  map("n", ">", "<S-v>><esc>", {}, "Increase indent for line")

  -- Visual line navigation (J/K for wrapped lines)
  map("n", "J", "gj", {}, "Move down display line")
  map("n", "K", "gk", {}, "Move up display line")
  map("v", "J", "gj", {}, "Move down display line")
  map("v", "K", "gk", {}, "Move up display line")

  return true
end

return M
