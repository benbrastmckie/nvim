-- neotex.config.autocmds
-- Autocommand configuration

local M = {}

function M.setup()
  local api = vim.api

  -- Set special buffers as fixed and map 'q' to close
  api.nvim_create_autocmd(
    "FileType",
    {
      pattern = { "man", "help", "qf", "lspinfo", "infoview", "NvimTree" }, -- "startuptime",
      callback = function(ev)
        -- Set the window as fixed
        vim.wo.winfixbuf = true
        -- Map q to close
        vim.keymap.set("n", "q", ":close<CR>", { buffer = ev.buf, silent = true })
      end,
    }
  )

  
  -- Setup terminal keymaps and suppress native terminal message
  api.nvim_create_autocmd({ "TermOpen" }, {
    pattern = { "term://*" }, -- use term://*toggleterm#* for only ToggleTerm
    callback = function(ev)
      set_terminal_keymaps()
      
      -- Aggressive suppression of the native terminal message
      local bufname = vim.api.nvim_buf_get_name(ev.buf)
      
      -- Set buffer-local option to suppress messages
      vim.bo[ev.buf].modifiable = true
      
      -- Multiple approaches to clear the message
      vim.cmd([[silent! echo ""]])
      vim.cmd([[silent! redraw!]])
      
      -- For Claude Code, use additional suppression
      if bufname:match("claude%-code") or bufname:match("ClaudeCode") then
        -- Clear any messages immediately and after a short delay
        vim.defer_fn(function()
          vim.cmd([[silent! echo ""]])
          vim.cmd([[silent! redraw!]])
        end, 1)
        
        -- Also try clearing with messages command
        vim.defer_fn(function()
          vim.cmd([[silent! messages clear]])
        end, 10)
      end
      
      -- Final clear for all terminals
      vim.defer_fn(function()
        vim.cmd([[silent! echo ""]])
      end, 50)
    end,
  })

  -- Setup markdown keymaps
  api.nvim_create_autocmd({ "BufEnter", "BufReadPre", "BufNewFile" }, {
    pattern = { "*.md" },
    command = "lua set_markdown_keymaps()",
  })

  -- Handle file changes silently - suppress the "File changed on disk" messages
  api.nvim_create_autocmd("FileChangedShell", {
    pattern = "*",
    callback = function(args)
      local bufname = vim.api.nvim_buf_get_name(args.buf)
      
      -- Ignore temp files (e.g., VimTeX compiler output in /tmp/nvim.*)
      if bufname:find("^/tmp/") then
        vim.v.fcs_choice = ""
        return
      end
      -- Check if file still exists
      if vim.fn.filereadable(bufname) == 0 then
        -- File was deleted - mark as not modified and don't reload
        vim.bo[args.buf].modified = false
        -- Tell vim we handled it by setting to "ignore"
        vim.v.fcs_choice = ""
      elseif vim.bo[args.buf].autoread == false then
        -- Buffer has autoread explicitly disabled - don't reload
        -- This respects buffer-local autoread settings (e.g., Himalaya compose buffers)
        vim.v.fcs_choice = ""
      else
        -- File was modified - reload silently
        vim.v.fcs_choice = "reload"
      end
    end,
  })

  -- Auto-reload on focus, buffer entry, and cursor idle
  -- CursorHold/CursorHoldI re-enabled: performance issue fixed in Neovim 0.8+ (PR #20198)
  -- This ensures external file changes (e.g., from Claude Code) are detected promptly
  api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    pattern = "*",
    callback = function()
      if vim.o.autoread and vim.fn.getcmdwintype() == '' then
        -- Skip temp files (e.g., VimTeX compiler output in /tmp/nvim.*)
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname:find("^/tmp/") then
          return
        end
        -- Silently check for file changes
        vim.cmd('silent! checktime')
      end
    end,
  })

  -- WezTerm OSC 7 integration for tab title updates
  -- Only runs when inside WezTerm (checked via WEZTERM_PANE env var)
  if vim.env.WEZTERM_PANE then
    -- Helper function to emit OSC 7 escape sequence with current working directory
    -- OSC 7 format: ESC ] 7 ; file://hostname/path ST
    -- WezTerm extracts the directory name from this for tab titles
    local function emit_osc7()
      local cwd = vim.fn.getcwd()
      local hostname = vim.fn.hostname()
      -- Use \027 (decimal) for ESC for Lua 5.1 compatibility
      -- \007 is BEL which serves as the string terminator (ST)
      local osc7 = string.format("\027]7;file://%s%s\007", hostname, cwd)
      io.write(osc7)
      io.flush()
    end

    -- Emit OSC 7 on directory changes (covers :cd, :lcd, :tcd, autochdir)
    api.nvim_create_autocmd("DirChanged", {
      pattern = "*",
      callback = emit_osc7,
      desc = "WezTerm: Update tab title on directory change",
    })

    -- Emit OSC 7 on Neovim startup to set initial tab title
    api.nvim_create_autocmd("VimEnter", {
      pattern = "*",
      callback = emit_osc7,
      desc = "WezTerm: Set initial tab title",
    })

    -- Emit OSC 7 when entering non-terminal buffers
    -- This restores the Neovim cwd display after terminal buffers (which emit their own OSC 7)
    api.nvim_create_autocmd("BufEnter", {
      pattern = "*",
      callback = function()
        -- Only emit for non-terminal buffers to avoid conflicts with shell's OSC 7
        if vim.bo.buftype ~= "terminal" then
          emit_osc7()
        end
      end,
      desc = "WezTerm: Restore tab title when leaving terminal buffer",
    })

    -- Claude Code task number integration for WezTerm tab title (task 795)
    --
    -- Simplified architecture:
    -- - Shell hook (wezterm-task-number.sh): Handles set/clear on UserPromptSubmit
    --   - Workflow commands (/research N, /plan N, /implement N, /revise N) -> Set
    --   - Non-workflow commands -> Clear
    --   - Claude output (no hook event) -> No change (preserves)
    -- - Neovim monitor (this file): Only handles terminal close cleanup
    --
    -- This separation ensures task numbers persist correctly during Claude's
    -- responses and only change when the user submits a new prompt.
    local wezterm = require('neotex.lib.wezterm')

    -- Track which buffers are Claude Code terminals for cleanup on close
    local claude_terminal_buffers = {}

    -- Function to check if a buffer is a Claude Code terminal
    local function is_claude_terminal(bufnr)
      local bufname = api.nvim_buf_get_name(bufnr)
      -- Match pattern used by claude-code.nvim plugin
      return bufname:match('claude') or bufname:match('ClaudeCode')
    end

    -- TermOpen autocmd to detect Claude Code terminals
    api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*',
      callback = function(ev)
        -- Defer to next tick to ensure buffer name is set
        vim.defer_fn(function()
          if is_claude_terminal(ev.buf) then
            claude_terminal_buffers[ev.buf] = true
          end
        end, 10)
      end,
      desc = 'WezTerm: Track Claude Code terminal for cleanup',
    })

    -- BufDelete/BufWipeout to cleanup state when terminal closes
    api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
      pattern = '*',
      callback = function(ev)
        if claude_terminal_buffers[ev.buf] then
          claude_terminal_buffers[ev.buf] = nil
          -- Clear task number when Claude terminal closes
          wezterm.clear_task_number()
        end
      end,
      desc = 'WezTerm: Clear task number when Claude Code terminal closes',
    })

    -- VimLeavePre to clear task number when Neovim exits with Claude terminal
    -- This handles the case where Neovim is closed (:qa, window close) while
    -- a Claude Code terminal is open with an active task number displayed
    api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        -- Clear task number if any Claude terminal was active
        for bufnr, _ in pairs(claude_terminal_buffers) do
          wezterm.clear_task_number()
          break  -- Only need to clear once
        end
      end,
      desc = 'WezTerm: Clear task number when Neovim exits with Claude terminal',
    })
  end

  return true
end

return M

