-- neotex.plugins.editor.which-key
-- Keybinding configuration and display using which-key.nvim v3 API

--[[ WHICH-KEY MAPPINGS - COMPLETE REFERENCE
-----------------------------------------------------------

This module configures which-key.nvim using the modern v3 API with icon support.
All mappings are organized alphabetically by leader letter and use `cond` functions
for filetype-specific features instead of autocmds.

The configuration provides:
- Helper functions for filetype detection
- All mappings grouped by letter with conditional visibility
- Clean separation of concerns without autocmd pollution

----------------------------------------------------------------------------------
TOP-LEVEL MAPPINGS (<leader>)                   | DESCRIPTION
----------------------------------------------------------------------------------
<leader>b - Close other buffers                 | Close all buffers except current
<leader>c - Create vertical split               | Split window vertically
<leader>d - Save and delete buffer              | Save file and close buffer
<leader>e - Toggle NvimTree explorer            | Open/close file explorer
<leader>k - Kill/close split                    | Close current split window
<leader>q - Save all and quit                   | Save all files and exit Neovim
<leader>u - Open Telescope undo                 | Show undo history with preview
<leader>w - Write all files                     | Save all open files

GROUP MAPPINGS (<leader>X)
----------------------------------------------------------------------------------
<leader>r - Run/Execute commands                  | Contains format (<leader>rf), debug, etc.
<leader>rf - Format with conform.nvim           | Async formatting with LSP fallback

[Additional documentation continues as before...]
]]

-- Import notification module for TTS toggle functionality
local notify = require('neotex.util.notifications')

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  dependencies = {
    'echasnovski/mini.nvim',
  },
  opts = {
    preset = "classic",
    delay = function(ctx)
      return ctx.plugin and 0 or 200
    end,
    show_help = false,    -- Remove bottom help/status bar
    show_keys = false,    -- Remove key hints
    win = {
      border = "rounded",
      padding = { 1, 2 },
      title = false,
      title_pos = "center",
      zindex = 1000,
      wo = {
        winblend = 10,
      },
      bo = {
        filetype = "which_key",
        buftype = "nofile",
      },
    },
    icons = {
      breadcrumb = "»",
      separator = "➜",
      group = "+",
    },
    layout = {
      width = { min = 20, max = 50 },
      height = { min = 4, max = 25 },
      spacing = 3,
      align = "left",
    },
    keys = {
      scroll_down = "<c-d>",
      scroll_up = "<c-u>",
    },
    sort = { "local", "order", "group", "alphanum", "mod" },
    disable = {
      bt = { "help", "quickfix", "terminal", "prompt" },
      ft = { "neo-tree" }
    },
    triggers = {
      { "<leader>", mode = { "n", "v" } }
    }
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- ============================================================================
    -- GLOBAL FUNCTIONS
    -- ============================================================================

    -- RunModelChecker: Find and run dev_cli.py for model checking
    _G.RunModelChecker = function()
      -- Try to find dev_cli.py in the current project or its parent
      local current_dir = vim.fn.getcwd()
      local dev_cli_path = nil

      -- Check current directory
      if vim.fn.filereadable(current_dir .. "/code/dev_cli.py") == 1 then
        dev_cli_path = current_dir .. "/code/dev_cli.py"
      -- Check if we're in a worktree and look in parent
      elseif current_dir:match("-feature-") or current_dir:match("-bugfix-") or current_dir:match("-refactor-") then
        local parent = current_dir:match("(.*/[^/]+)%-[^/]+%-[^/]+$")
        if parent and vim.fn.filereadable(parent .. "/code/dev_cli.py") == 1 then
          dev_cli_path = parent .. "/code/dev_cli.py"
        end
      -- Fallback to known ModelChecker location
      elseif vim.fn.filereadable("/home/benjamin/Documents/Philosophy/Projects/ModelChecker/code/dev_cli.py") == 1 then
        dev_cli_path = "/home/benjamin/Documents/Philosophy/Projects/ModelChecker/code/dev_cli.py"
      end

      if dev_cli_path then
        local file = vim.fn.expand("%:p:r") .. ".py"
        vim.cmd(string.format("TermExec cmd='%s %s'", dev_cli_path, file))
      else
        vim.notify("Could not find code/dev_cli.py in project", vim.log.levels.ERROR)
      end
    end

    -- ============================================================================
    -- HELPER FUNCTIONS FOR FILETYPE DETECTION
    -- ============================================================================

    -- Toggle TTS_ENABLED in the project-specific config file
    -- @param config_path string Path to the tts-config.sh file
    -- @return success boolean True if toggle succeeded
    -- @return message string Success message ("TTS enabled" or "TTS disabled")
    -- @return error string Error message if success is false
    local function toggle_tts_config(config_path)
      -- Validate file exists (redundant check, but safe)
      if vim.fn.filereadable(config_path) ~= 1 then
        return false, nil, "Config file not readable: " .. config_path
      end

      -- Read file with error handling
      local ok, lines = pcall(vim.fn.readfile, config_path)
      if not ok then
        return false, nil, "Failed to read config: " .. tostring(lines)
      end

      -- Find and toggle TTS_ENABLED
      local modified = false
      local message
      for i, line in ipairs(lines) do
        if line:match("^TTS_ENABLED=") then
          if line:match("=true$") then
            lines[i] = "TTS_ENABLED=false"
            message = "TTS disabled"
          else
            lines[i] = "TTS_ENABLED=true"
            message = "TTS enabled"
          end
          modified = true
          break
        end
      end

      if not modified then
        return false, nil, "TTS_ENABLED not found in config file"
      end

      -- Write file with error handling
      local write_ok, write_err = pcall(vim.fn.writefile, lines, config_path)
      if not write_ok then
        return false, nil, "Failed to write config: " .. tostring(write_err)
      end

      return true, message, nil
    end

    local function is_python()
      return vim.bo.filetype == "python"
    end

    local function is_markdown()
      return vim.tbl_contains({ "markdown", "md" }, vim.bo.filetype)
    end

    local function is_lectic()
      return vim.tbl_contains({ "lec", "markdown", "md" }, vim.bo.filetype)
    end

    local function is_jupyter()
      return vim.bo.filetype == "ipynb"
    end

    local function is_jupyter_or_python()
      return vim.bo.filetype == "ipynb" or vim.bo.filetype == "python"
    end

    local function is_pandoc_compatible()
      return vim.tbl_contains({ "markdown", "md", "tex", "latex", "org", "rst", "html", "docx" }, vim.bo.filetype)
    end


    -- Helper function for bibexport
    local function run_bibexport()
      local filepath = vim.fn.expand('%:p')
      local filedir = vim.fn.expand('%:p:h')
      local filename = vim.fn.expand('%:t:r')
      local output_bib = filename .. '.bib'
      local aux_file = 'build/' .. filename .. '.aux'

      -- Build the command to run in terminal
      local cmd = string.format('cd "%s" && bibexport -o "%s" "%s"', filedir, output_bib, aux_file)
      vim.cmd('terminal ' .. cmd)
    end

    -- ============================================================================
    -- TOP-LEVEL SINGLE KEY MAPPINGS
    -- ============================================================================

    wk.add({
      { "<leader>b", "<cmd>lua CloseOtherBuffers()<CR>", desc = "close other buffers", icon = "󰅚" },
      { "<leader>c", "<cmd>vert sb<CR>", desc = "create split", icon = "󰯌" },
      { "<leader>d", "<cmd>update! | lua smart_bufdelete()<CR>", desc = "delete buffer", icon = "󰩺" },
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "explorer", icon = "󰙅" },
      { "<leader>k", "<cmd>close<CR>", desc = "kill split", icon = "󰆴" },
      { "<leader>q", "<cmd>wa! | qa!<CR>", desc = "quit", icon = "󰗼" },
      { "<leader>u", "<cmd>Telescope undo<CR>", desc = "undo", icon = "󰕌" },
      { "<leader>w", "<cmd>wa!<CR>", desc = "write", icon = "󰆓" },
    })

    -- CloseOtherBuffers: Close all listed buffers except the current one
    _G.CloseOtherBuffers = function()
      local current = vim.api.nvim_get_current_buf()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
          vim.api.nvim_buf_delete(buf, { force = false })
        end
      end
    end

    -- Global AI toggles are now in keymaps.lua for centralized management

    -- ============================================================================
    -- <leader>a - AI/ASSISTANT GROUP
    -- ============================================================================

    wk.add({
      { "<leader>a", group = "ai", icon = "󰚩", mode = { "n", "v" } },

      -- Claude AI commands
      { "<leader>ac", "<cmd>ClaudeCommands<CR>", desc = "claude commands", icon = "󰘳" },
      { "<leader>ac",
        function() require("neotex.plugins.ai.claude.core.visual").send_visual_to_claude_with_prompt() end,
        desc = "send selection to claude with prompt",
        mode = { "v" },
        icon = "󰘳"
      },
      { "<leader>as", function() require("neotex.plugins.ai.claude").resume_session() end, desc = "claude sessions", icon = "󰑐" },

      -- OpenCode AI commands
      -- { "<leader>aa", function() require("opencode").ask() end, desc = "opencode ask", icon = "󰘳", mode = { "n", "v" } },
      { "<leader>ab", function() require("opencode").prompt("@buffer") end, desc = "opencode buffer context", icon = "󰈙" },
      { "<leader>ad", function() require("opencode").prompt("@diagnostics") end, desc = "opencode diagnostics", icon = "󰒓" },
      { "<leader>as", function() require("opencode").select() end, desc = "opencode select", icon = "󰒋" },
      { "<leader>ah", function() require("opencode").command("session.list") end, desc = "opencode history", icon = "󰆼" },
      -- { "<leader>ai", function() require("opencode").command("session.new") end, desc = "opencode init session", icon = "󰐕" },
      -- { "<leader>ap", function() require("opencode").prompt("@this") end, desc = "opencode prompt", icon = "󰏪", mode = { "n", "v" } },

      -- OpenCode commands (mirrors <leader>ac behavior)
      { "<leader>ao", "<cmd>OpencodeCommands<CR>", desc = "opencode commands", icon = "󰘳" },
      { "<leader>ao",
        function() require("neotex.plugins.ai.opencode.core.visual").send_visual_to_opencode_with_prompt() end,
        desc = "send selection to opencode with prompt",
        mode = { "v" },
        icon = "󰘳"
      },

      -- TTS toggle - project-specific only (DISABLED: 2025-12-09 - User preference)
      -- { "<leader>at", function()
      --   local config_path = vim.fn.getcwd() .. "/.claude/tts/tts-config.sh"

      --   if vim.fn.filereadable(config_path) ~= 1 then
      --     notify.editor(
      --       "No TTS config found. Use <leader>ac to create project-specific config.",
      --       notify.categories.ERROR,
      --       { project_root = vim.fn.getcwd() }
      --     )
      --     return
      --   end

      --   local success, message, error = toggle_tts_config(config_path)

      --   if success then
      --     notify.editor(
      --       message,
      --       notify.categories.USER_ACTION,
      --       { config_path = config_path }
      --     )
      --   else
      --     notify.editor(
      --       "Failed to toggle TTS: " .. error,
      --       notify.categories.ERROR,
      --       { config_path = config_path }
      --     )
      --   end
      -- end, desc = "toggle tts", icon = "󰔊" },

      -- Yolo mode toggle - enables/disables --dangerously-skip-permissions flag
      { "<leader>ay", function()
        local config_path = vim.fn.expand("~/.config/nvim/lua/neotex/plugins/ai/claudecode.lua")

        if vim.fn.filereadable(config_path) ~= 1 then
          notify.editor(
            "Claude Code config not found",
            notify.categories.ERROR,
            { config_path = config_path }
          )
          return
        end

        local lines = vim.fn.readfile(config_path)
        local modified = false
        local yolo_enabled = false

        for i, line in ipairs(lines) do
          if line:match('%s*command = "claude') then
            if line:match('--dangerously%-skip%-permissions') then
              -- Disable yolo mode
              lines[i] = '    command = "claude",'
              yolo_enabled = false
            else
              -- Enable yolo mode
              lines[i] = '    command = "claude --dangerously-skip-permissions",'
              yolo_enabled = true
            end
            modified = true
            break
          end
        end

        if not modified then
          notify.editor(
            "Could not find command line in config",
            notify.categories.ERROR,
            { config_path = config_path }
          )
          return
        end

        local write_ok = pcall(vim.fn.writefile, lines, config_path)
        if not write_ok then
          notify.editor(
            "Failed to write config file",
            notify.categories.ERROR,
            { config_path = config_path }
          )
          return
        end

        notify.editor(
          yolo_enabled and "Yolo mode enabled (restart required)" or "Yolo mode disabled (restart required)",
          notify.categories.USER_ACTION,
          { config_path = config_path, yolo_enabled = yolo_enabled }
        )
      end, desc = "toggle yolo mode", icon = "󰒓" },

      -- Model picker - select Claude Code model
      { "<leader>am", function()
        local config_path = vim.fn.expand("~/.claude/settings.json")

        -- Model definitions (Opus first per task description)
        local models = {
          { id = "opus", label = "Opus 4.6", desc = "Most powerful - complex reasoning" },
          { id = "sonnet", label = "Sonnet 4.6", desc = "Balanced - everyday coding" },
          { id = "haiku", label = "Haiku 4.5", desc = "Fastest - quick tasks" },
        }

        -- Read current settings
        local current_model = "sonnet"  -- default fallback
        local file = io.open(config_path, "r")
        if file then
          local content = file:read("*all")
          file:close()
          local ok, settings = pcall(vim.fn.json_decode, content)
          if ok and settings and settings.model then
            current_model = settings.model
          end
        end

        -- Show picker
        vim.ui.select(models, {
          prompt = "Select Claude model:",
          format_item = function(item)
            local marker = (item.id == current_model) and " [*]" or ""
            return string.format("%s - %s%s", item.label, item.desc, marker)
          end,
        }, function(choice)
          if not choice then return end

          -- Read current settings (re-read for freshness)
          local settings = {}
          local read_file = io.open(config_path, "r")
          if read_file then
            local content = read_file:read("*all")
            read_file:close()
            local ok, data = pcall(vim.fn.json_decode, content)
            if ok and data then settings = data end
          end

          settings.model = choice.id

          local write_ok, write_err = pcall(function()
            local write_file = io.open(config_path, "w")
            if not write_file then error("Cannot open file for writing") end
            write_file:write(vim.fn.json_encode(settings))
            write_file:close()
          end)

          if not write_ok then
            notify.editor("Failed to write settings: " .. tostring(write_err), notify.categories.ERROR)
            return
          end

          notify.editor(
            string.format("Model set to %s (restart required)", choice.label),
            notify.categories.USER_ACTION,
            { model = choice.id }
          )
        end)
      end, desc = "model (claude)", icon = "󰘦" },
    })

    -- ============================================================================
    -- <leader>f - FIND GROUP
    -- ============================================================================

    wk.add({
      { "<leader>f", group = "find", icon = "󰍉", mode = { "n", "v" } },
      { "<leader>fa", "<cmd>lua require('telescope.builtin').find_files({ no_ignore = true, hidden = true, search_dirs = { '~/' } })<CR>", desc = "all files", icon = "󰈙" },
      { "<leader>fb", "<cmd>lua require('telescope.builtin').buffers(require('telescope.themes').get_dropdown{previewer = false})<CR>", desc = "buffers", icon = "󰓩" },
      { "<leader>fc", "<cmd>Telescope bibtex format_string=\\citet{%s}<CR>", desc = "citations", icon = "󰈙" },
      { "<leader>ff", "<cmd>Telescope live_grep theme=ivy<CR>", desc = "project", icon = "󰊄" },
      { "<leader>fl", "<cmd>Telescope resume<CR>", desc = "last search", icon = "󰺄" },
      { "<leader>fp", "<cmd>lua require('neotex.util.misc').copy_buffer_path()<CR>", desc = "copy buffer path", icon = "󰆏" },
      { "<leader>fq", "<cmd>Telescope quickfix<CR>", desc = "quickfix", icon = "󰁨" },
      { "<leader>fg", "<cmd>Telescope git_commits<CR>", desc = "git history", icon = "󰊢" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "help", icon = "󰞋" },
      { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "keymaps", icon = "󰌌" },
      { "<leader>fr", "<cmd>Telescope registers<CR>", desc = "registers", icon = "󰊄" },
      { "<leader>fs", "<cmd>Telescope grep_string<CR>", desc = "string", icon = "󰊄", mode = { "n", "v" } },
      { "<leader>fw", "<cmd>lua SearchWordUnderCursor()<CR>", desc = "word", icon = "󰊄", mode = { "n", "v" } },
      { "<leader>fy", function() _G.YankyTelescopeHistory() end, desc = "yanks", icon = "󰆏", mode = { "n", "v" } },
    })

    -- ============================================================================
    -- <leader>g - GIT GROUP
    -- ============================================================================

    wk.add({
      { "<leader>g", group = "git", icon = "󰊢", mode = { "n", "v" } },
      { "<leader>gb", "<cmd>Telescope git_branches<CR>", desc = "branches", icon = "󰘬" },
      { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "commits", icon = "󰜘" },
      { "<leader>gd", "<cmd>lua vim.lsp.buf.definition()<CR>", desc = "definition", icon = "󰳦" },
      -- { "<leader>gf", "<cmd>Telescope git_worktree create_git_worktree<CR>", desc = "new feature", icon = "󰊕" },
      { "<leader>gg", function() require("snacks").lazygit() end, desc = "lazygit", icon = "󰊢" },
      { "<leader>gh", "<cmd>Gitsigns prev_hunk<CR>", desc = "prev hunk", icon = "󰮲" },
      { "<leader>gj", "<cmd>Gitsigns next_hunk<CR>", desc = "next hunk", icon = "󰮰" },
      { "<leader>gl", "<cmd>Gitsigns blame_line<CR>", desc = "line blame", icon = "󰊢", mode = { "n", "v" } },
      { "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", desc = "preview hunk", icon = "󰆈" },
      { "<leader>gr", "<cmd>ClaudeRestoreWorktree<CR>", desc = "restore claude worktree", icon = "󰑐" },
      { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "status", icon = "󰊢" },
      { "<leader>gt", "<cmd>Gitsigns toggle_current_line_blame<CR>", desc = "toggle blame", icon = "󰔡" },
      { "<leader>gv", "<cmd>ClaudeSessions<CR>", desc = "view claude worktrees", icon = "󰔡" },
      { "<leader>gw", "<cmd>ClaudeWorktree<CR>", desc = "create claude worktree", icon = "󰘬" },
    })

    -- ============================================================================
    -- <leader>h - HELP GROUP
    -- ============================================================================

    wk.add({
      { "<leader>h", group = "help", icon = "󰞋" },
      { "<leader>ha", "<cmd>Telescope autocommands<CR>", desc = "autocommands", icon = "󰆘" },
      { "<leader>hc", "<cmd>Telescope commands<CR>", desc = "commands", icon = "󰘳" },
      { "<leader>hh", "<cmd>Telescope help_tags<CR>", desc = "help tags", icon = "󰞋" },
      { "<leader>hH", "<cmd>Telescope highlights<CR>", desc = "highlights", icon = "󰸱" },
      { "<leader>hk", "<cmd>Telescope keymaps<CR>", desc = "keymaps", icon = "󰌌" },
      { "<leader>hl", "<cmd>LspInfo<CR>", desc = "lsp info", icon = "󰅴" },
      { "<leader>hL", "<cmd>Lazy<CR>", desc = "lazy plugin manager", icon = "󰒲" },
      { "<leader>hm", "<cmd>Telescope man_pages<CR>", desc = "man pages", icon = "󰈙" },
      { "<leader>hM", "<cmd>Mason<CR>", desc = "mason lsp installer", icon = "󰏖" },
      { "<leader>hn", "<cmd>NullLsInfo<CR>", desc = "null-ls info", icon = "󰅴" },
      { "<leader>hN", function() require("wezterm").switch_tab.relative(-1) end, desc = "wezterm prev", icon = "󰮲" },
      { "<leader>ho", "<cmd>Telescope vim_options<CR>", desc = "vim options", icon = "󰒕" },
      { "<leader>hP", function() require("wezterm").switch_tab.relative(1) end, desc = "wezterm next", icon = "󰮰" },
      { "<leader>hr", "<cmd>Telescope reloader<CR>", desc = "reload modules", icon = "󰜉" },
      { "<leader>ht", "<cmd>TSPlaygroundToggle<CR>", desc = "treesitter playground", icon = "󰔡" },
      { "<leader>hT", function()
        local wezterm = require("wezterm")
        local count = vim.v.count
        if count > 0 then
          wezterm.switch_tab.index(count - 1) -- WezTerm uses 0-based indexing
        else
          vim.notify("Use count to specify tab (e.g., 2<leader>hT for tab 2)", vim.log.levels.INFO)
        end
      end, desc = "wezterm tab N", icon = "󰓩" },
    })

    -- ============================================================================
    -- <leader>i - LSP & LINT GROUP
    -- ============================================================================

    wk.add({
      { "<leader>i", group = "lsp", icon = "󰅴", mode = { "n", "v" } },
      { "<leader>ib", "<cmd>Telescope diagnostics bufnr=0<CR>", desc = "buffer diagnostics", icon = "󰒓" },
      { "<leader>iB", "<cmd>LintToggle buffer<CR>", desc = "toggle buffer linting", icon = "󰔡" },
      { "<leader>ic", "<cmd>lua vim.lsp.buf.code_action()<CR>", desc = "code action", icon = "󰌵", mode = { "n", "v" } },
      { "<leader>id", "<cmd>Telescope lsp_definitions<CR>", desc = "definition", icon = "󰳦" },
      { "<leader>iD", "<cmd>lua vim.lsp.buf.declaration()<CR>", desc = "declaration", icon = "󰳦" },
      { "<leader>ig", "<cmd>LintToggle<CR>", desc = "toggle global linting", icon = "󰔡" },
      { "<leader>ih", "<cmd>lua vim.lsp.buf.hover()<CR>", desc = "help", icon = "󰞋" },
      { "<leader>ii", "<cmd>Telescope lsp_implementations<CR>", desc = "implementations", icon = "󰡱" },
      { "<leader>il", "<cmd>lua vim.diagnostic.open_float()<CR>", desc = "line diagnostics", icon = "󰒓" },
      { "<leader>iL", function() require("lint").try_lint() end, desc = "lint file", icon = "󰁨" },
      { "<leader>in", "<cmd>lua vim.diagnostic.goto_next()<CR>", desc = "next diagnostic", icon = "󰮰" },
      { "<leader>ip", "<cmd>lua vim.diagnostic.goto_prev()<CR>", desc = "previous diagnostic", icon = "󰮲" },
      { "<leader>ir", "<cmd>Telescope lsp_references<CR>", desc = "references", icon = "󰌹" },
      { "<leader>iR", "<cmd>lua vim.lsp.buf.rename()<CR>", desc = "rename", icon = "󰑕" },
      { "<leader>is", "<cmd>LspRestart<CR>", desc = "restart lsp", icon = "󰜉" },
      { "<leader>it", function()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients > 0 then
          vim.cmd('LspStop')
          require('neotex.util.notifications').lsp('LSP stopped', require('neotex.util.notifications').categories.USER_ACTION)
        else
          vim.cmd('LspStart')
          require('neotex.util.notifications').lsp('LSP started', require('neotex.util.notifications').categories.USER_ACTION)
        end
      end, desc = "toggle lsp", icon = "󰔡" },
      { "<leader>iy", "<cmd>lua CopyDiagnosticsToClipboard()<CR>", desc = "copy diagnostics", icon = "󰆏" },
    })

    -- ============================================================================
    -- <leader>j - JUPYTER GROUP
    -- ============================================================================

    wk.add({
      -- Group header (static name, conditional visibility)
      { "<leader>j", group = "jupyter", icon = "󰌠", cond = is_jupyter },

      -- Jupyter-specific mappings
      { "<leader>ja", "<cmd>lua require('notebook-navigator').run_all_cells()<CR>", desc = "run all cells", icon = "󰐊", cond = is_jupyter },
      { "<leader>jb", "<cmd>lua require('notebook-navigator').run_cells_below()<CR>", desc = "run cells below", icon = "󰐊", cond = is_jupyter },
      { "<leader>jc", "<cmd>lua require('notebook-navigator').comment_cell()<CR>", desc = "comment cell", icon = "󰆈", cond = is_jupyter },
      { "<leader>jd", "<cmd>lua require('notebook-navigator').merge_cell('d')<CR>", desc = "merge with cell below", icon = "󰅀", cond = is_jupyter },
      { "<leader>je", "<cmd>lua require('notebook-navigator').run_cell()<CR>", desc = "execute cell", icon = "󰐊", cond = is_jupyter },
      { "<leader>jf", "<cmd>lua require('iron.core').send(nil, vim.fn.readfile(vim.fn.expand('%')))<CR>", desc = "send file to REPL", icon = "󰊠", cond = is_jupyter },
      { "<leader>ji", "<cmd>lua require('iron.core').repl_for('python')<CR>", desc = "start IPython REPL", icon = "󰌠", cond = is_jupyter },
      { "<leader>jj", "<cmd>lua require('notebook-navigator').move_cell('d')<CR>", desc = "next cell", icon = "󰮰", cond = is_jupyter },
      { "<leader>jk", "<cmd>lua require('notebook-navigator').move_cell('u')<CR>", desc = "previous cell", icon = "󰮲", cond = is_jupyter },
      { "<leader>jl", "<cmd>lua require('iron.core').send_line()<CR>", desc = "send line to REPL", icon = "󰊠", cond = is_jupyter },
      { "<leader>jn", "<cmd>lua require('notebook-navigator').run_and_move()<CR>", desc = "execute and next", icon = "󰒭", cond = is_jupyter },
      { "<leader>jo", "<cmd>lua require('neotex.util.diagnostics').add_jupyter_cell_with_closing()<CR>", desc = "insert cell below", icon = "󰐕", cond = is_jupyter },
      { "<leader>jO", "<cmd>lua require('notebook-navigator').add_cell_above()<CR>", desc = "insert cell above", icon = "󰐖", cond = is_jupyter },
      { "<leader>jq", "<cmd>lua require('iron.core').close_repl()<CR>", desc = "exit REPL", icon = "󰚌", cond = is_jupyter },
      { "<leader>jr", "<cmd>lua require('iron.core').send(nil, string.char(12))<CR>", desc = "clear REPL", icon = "󰃢", cond = is_jupyter },
      { "<leader>js", "<cmd>lua require('notebook-navigator').split_cell()<CR>", desc = "split cell", icon = "󰤋", cond = is_jupyter },
      { "<leader>jt", "<cmd>lua require('iron.core').run_motion('send_motion')<CR>", desc = "send motion to REPL", icon = "󰊠", cond = is_jupyter },
      { "<leader>ju", "<cmd>lua require('notebook-navigator').merge_cell('u')<CR>", desc = "merge with cell above", icon = "󰅂", cond = is_jupyter },
      { "<leader>jv", "<cmd>lua require('iron.core').visual_send()<CR>", desc = "send visual selection to REPL", icon = "󰊠", mode = { "n", "v" }, cond = is_jupyter_or_python },
    })

    -- ============================================================================
    -- <leader>m - MAIL GROUP
    -- ============================================================================

    wk.add({
      { "<leader>m", group = "mail", icon = "󰇮" },
      { "<leader>mA", "<cmd>HimalayaAccounts<CR>", desc = "switch account", icon = "󰌏" },
      { "<leader>mf", "<cmd>HimalayaFolder<CR>", desc = "change folder", icon = "󰉋" },
      { "<leader>mF", "<cmd>HimalayaRecreateFolders<CR>", desc = "recreate folders", icon = "󰝰" },
      { "<leader>mh", "<cmd>HimalayaHealth<CR>", desc = "health check", icon = "󰸉" },
      { "<leader>mi", "<cmd>HimalayaSyncInfo<CR>", desc = "sync status", icon = "󰋼" },
      { "<leader>mm", "<cmd>HimalayaToggle<CR>", desc = "toggle sidebar", icon = "󰊫" },
      { "<leader>ms", "<cmd>HimalayaSyncInbox<CR>", desc = "sync inbox", icon = "󰜉" },
      { "<leader>mS", "<cmd>HimalayaSyncFull<CR>", desc = "full sync", icon = "󰜉" },
      { "<leader>mr", "<cmd>TermExec cmd='find ~/Mail/Logos -name .mbsyncstate -delete; find ~/Mail/Logos -name .uidvalidity -delete; rm -f /home/benjamin/Mail/.claude/output/email.md; mbsync logos'<CR><C-w>l", desc = "maildir resync", icon = "󰔟" },
      { "<leader>mt", "<cmd>HimalayaAutoSyncToggle<CR>", desc = "toggle auto-sync", icon = "󰑖" },
      { "<leader>mw", "<cmd>HimalayaWrite<CR>", desc = "write email", icon = "󰝒" },
      { "<leader>mW", "<cmd>HimalayaSetup<CR>", desc = "setup wizard", icon = "󰗀" },
      { "<leader>mx", "<cmd>HimalayaCancelSync<CR>", desc = "cancel all syncs", icon = "󰚌" },
      { "<leader>mX", "<cmd>HimalayaBackupAndFresh<CR>", desc = "backup & fresh", icon = "󰁯" },
    })

    -- NOTE: Compose buffer and email preview keymaps are now registered
    -- buffer-locally in email_composer.lua and email_preview.lua respectively.
    -- This enables them to appear in which-key menu for their specific buffers.
    -- (Task 73 - buffer-local which-key registration pattern)

    -- ============================================================================
    -- <leader>n - NIXOS GROUP
    -- ============================================================================

    wk.add({
      { "<leader>n", group = "nixos", icon = "󱄅" },
      { "<leader>nd", "<cmd>TermExec cmd='nix develop'<CR><C-w>j", desc = "develop", icon = "󰐊" },
      { "<leader>nf", "<cmd>TermExec cmd='sudo nixos-rebuild switch --flake ~/.dotfiles/'<CR><C-w>l", desc = "rebuild flake", icon = "󰜉" },
      { "<leader>ng", "<cmd>TermExec cmd='nix-collect-garbage --delete-older-than 15d'<CR><C-w>j", desc = "garbage", icon = "󰩺" },
      { "<leader>nh", "<cmd>TermExec cmd='home-manager switch --flake ~/.dotfiles/'<CR><C-w>l", desc = "home-manager", icon = "󰋜" },
      { "<leader>nm", "<cmd>TermExec cmd='brave https://mynixos.com' open=0<CR>", desc = "my-nixos", icon = "󰖟" },
      { "<leader>np", "<cmd>TermExec cmd='brave https://search.nixos.org/packages' open=0<CR>", desc = "packages", icon = "󰏖" },
      { "<leader>nr", "<cmd>TermExec cmd='~/.dotfiles/update.sh'<CR><C-w>l", desc = "rebuild nix", icon = "󰜉" },
      { "<leader>nu", "<cmd>TermExec cmd='nix flake update'<CR><C-w>j", desc = "update", icon = "󰚰" },
    })

    -- ============================================================================
    -- <leader>p - PANDOC GROUP
    -- ============================================================================

    wk.add({
      -- Group header (static name, conditional visibility)
      { "<leader>p", group = "pandoc", icon = "󰈙", cond = is_pandoc_compatible },

      -- Pandoc-specific mappings
      { "<leader>ph", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.html'<CR>", desc = "html", icon = "󰌝", cond = is_pandoc_compatible },
      { "<leader>pl", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.tex'<CR>", desc = "latex", icon = "󰐺", cond = is_pandoc_compatible },
      { "<leader>pm", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.md'<CR>", desc = "markdown", icon = "󱀈", cond = is_pandoc_compatible },
      { "<leader>pp", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf' open=0<CR>", desc = "pdf", icon = "󰈙", cond = is_pandoc_compatible },
      { "<leader>pv", "<cmd>TermExec cmd='sioyek %:p:r.pdf &' open=0<CR>", desc = "view", icon = "󰛓", cond = is_pandoc_compatible },
      { "<leader>pw", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.docx'<CR>", desc = "word", icon = "󰈭", cond = is_pandoc_compatible },
    })

    -- ============================================================================
    -- <leader>r - RUN GROUP
    -- ============================================================================

    wk.add({
      { "<leader>r", group = "run", icon = "󰌵" },
      { "<leader>rc", "<cmd>TermExec cmd='rm -rf ~/.cache/nvim' open=0<CR>", desc = "clear plugin cache", icon = "󰃢" },
      { "<leader>rd", function()
          local notify = require('neotex.util.notifications')
          notify.toggle_debug_mode()
        end, desc = "toggle debug mode", icon = "󰃤" },
      { "<leader>rl", "<cmd>lua require('neotex.util.diagnostics').show_all_errors()<CR>", desc = "show linter errors", icon = "󰅚" },
      -- Format via conform.nvim with LSP fallback
      -- Uses filetype-specific formatters (prettier, stylua, black, etc.)
      -- Falls back to LSP formatting if no formatter is configured
      -- Supports both normal and visual mode for range formatting
      { "<leader>rf", function() require("conform").format({ async = true, lsp_fallback = true }) end, desc = "format", icon = "󰉣", mode = { "n", "v" } },
      { "<leader>rF", "<cmd>lua ToggleAllFolds()<CR>", desc = "toggle all folds", icon = "󰘖" },
      { "<leader>rh", "<cmd>LocalHighlightToggle<CR>", desc = "highlight", icon = "󰠷" },
      { "<leader>rk", "<cmd>BufDeleteFile<CR>", desc = "kill file and buffer", icon = "󰆴" },
      { "<leader>rK", "<cmd>TermExec cmd='rm -rf ~/.local/share/nvim/lazy && rm -f ~/.config/nvim/lazy-lock.json' open=0<CR>", desc = "wipe plugins and lock file", icon = "󰩺" },
      { "<leader>rb", "<cmd>TermExec cmd='lake build'<CR>", desc = "lean build", icon = "󰐊" },
      { "<leader>ri", function() require('lean.infoview').toggle() end, desc = "toggle infoview", icon = "󰊕" },
      { "<leader>rm", "<cmd>lua RunModelChecker()<CR>", desc = "model checker", icon = "󰐊", mode = "n" },
      { "<leader>rM", "<cmd>lua Snacks.notifier.show_history()<cr>", desc = "show messages", icon = "󰍡" },
      { "<leader>ro", "za", desc = "toggle fold under cursor", icon = "󰘖" },
      { "<leader>rp", "<cmd>TermExec cmd='python %:p:r.py'<CR>", desc = "python run", icon = "󰌠", cond = is_python },
      { "<leader>rr", "<cmd>AutolistRecalculate<CR>", desc = "reorder list", icon = "󰔢", cond = is_markdown },
      { "<leader>rR", "<cmd>ReloadConfig<cr>", desc = "reload configs", icon = "󰜉" },
      { "<leader>re", "<cmd>Neotree ~/.config/nvim/snippets/<CR>", desc = "snippets edit", icon = "󰩫" },
      { "<leader>rs", "<cmd>TermExec cmd='ssh brastmck@eofe10.mit.edu'<CR>", desc = "ssh", icon = "󰣀" },
      -- { "<leader>rt", "<cmd>HimalayaTest<cr>", desc = "test himalaya", icon = "󰙨" },
      { "<leader>rt", "<cmd>lua ToggleFoldingMethod()<CR>", desc = "toggle folding method", icon = "󰘖" },
      { "<leader>ru", "<cmd>cd %:p:h | Neotree reveal<CR>", desc = "update cwd", icon = "󰉖" },
      { "<leader>rz", function()
          require('neotex.util.sleep-inhibit').toggle()
        end, desc = "toggle sleep inhibitor", icon = "󰒲" },
      { "<leader>rg", "<cmd>lua OpenUrlUnderCursor()<CR>", desc = "go to URL", icon = "󰖟" },
    })

    -- ============================================================================
    -- <leader>s - SURROUND GROUP
    -- ============================================================================

    wk.add({
      { "<leader>s", group = "surround", icon = "󰅪", mode = { "n", "v" } },
      { "<leader>sc", "<Plug>(nvim-surround-change)", desc = "change", icon = "󰏫" },
      { "<leader>sd", "<Plug>(nvim-surround-delete)", desc = "delete", icon = "󰚌" },
      { "<leader>ss", "<Plug>(nvim-surround-normal)", desc = "surround", icon = "󰅪", mode = "n" },
      { "<leader>ss", "<Plug>(nvim-surround-visual)", desc = "surround selection", icon = "󰅪", mode = "v" },
    })

    -- ============================================================================
    -- <leader>S - SESSIONS GROUP
    -- ============================================================================

    wk.add({
      { "<leader>S", group = "sessions", icon = "󰆔" },
      { "<leader>Sd", "<cmd>SessionManager delete_session<CR>", desc = "delete", icon = "󰚌" },
      { "<leader>Sl", "<cmd>SessionManager load_session<CR>", desc = "load", icon = "󰉖" },
      { "<leader>Ss", "<cmd>SessionManager save_current_session<CR>", desc = "save", icon = "󰆓" },
    })

    -- ============================================================================
    -- <leader>t - TODO GROUP
    -- ============================================================================

    wk.add({
      { "<leader>t", group = "todo", icon = "󰄬" },
      { "<leader>tl", "<cmd>TodoLocList<CR>", desc = "todo location list", icon = "󰈙" },
      { "<leader>tn", function() require("todo-comments").jump_next() end, desc = "next todo", icon = "󰮰" },
      { "<leader>tp", function() require("todo-comments").jump_prev() end, desc = "previous todo", icon = "󰮲" },
      { "<leader>tq", "<cmd>TodoQuickFix<CR>", desc = "todo quickfix", icon = "󰁨" },
      { "<leader>tt", "<cmd>TodoTelescope<CR>", desc = "todo telescope", icon = "󰄬" },
    })

    -- ============================================================================
    -- <leader>x - TEXT GROUP
    -- ============================================================================

    wk.add({
      { "<leader>x", group = "text", icon = "󰤌", mode = { "n", "v" } },
      { "<leader>xa", desc = "align", icon = "󰉞", mode = { "n", "v" } },
      { "<leader>xA", desc = "align with preview", icon = "󰉞", mode = { "n", "v" } },
      { "<leader>xd", desc = "toggle diff overlay", icon = "󰦓" },
      { "<leader>xs", desc = "split/join toggle", icon = "󰤋", mode = { "n", "v" } },
      { "<leader>xw", desc = "toggle word diff", icon = "󰦓" },
    })

    -- ============================================================================
    -- <leader>v - VOICE GROUP (STT)
    -- ============================================================================

    wk.add({
      { "<leader>v", group = "voice", icon = "󰍬" },
      { "<leader>vh", function() require('neotex.plugins.tools.stt').health() end, desc = "health check", icon = "󰸉" },
      { "<leader>vr", function() require('neotex.plugins.tools.stt').start_recording() end, desc = "start recording", icon = "󰑊" },
      { "<leader>vs", function() require('neotex.plugins.tools.stt').stop_recording() end, desc = "stop recording", icon = "󰓛" },
      { "<leader>vv", function() require('neotex.plugins.tools.stt').toggle_recording() end, desc = "toggle recording", icon = "󰔊" },
    })

    -- ============================================================================
    -- <leader>y - YANK GROUP
    -- ============================================================================

    wk.add({
      { "<leader>y", group = "yank", icon = "󰆏", mode = { "n", "v" } },
      { "<leader>yc", function() require("yanky").clear_history() end, desc = "clear history", icon = "󰃢" },
      { "<leader>yh", function() _G.YankyTelescopeHistory() end, desc = "yank history", icon = "󰞋", mode = { "n", "v" } },
    })
  end,
}
