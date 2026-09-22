-- PdfAnnots
function PdfAnnots()
  local ok, pdf = pcall(vim.api.nvim_eval,
    "vimtex#context#get().handler.get_actions().entry.file")
  if not ok then
    vim.notify "No file found"
    return
  end

  local cwd = vim.fn.getcwd()
  vim.fn.chdir(vim.b.vimtex.root)

  if vim.fn.isdirectory('Annotations') == 0 then
    vim.fn.mkdir('Annotations')
  end

  local md = vim.fn.printf("Annotations/%s.md", vim.fn.fnamemodify(pdf, ":t:r"))
  -- vim.fn.system(vim.fn.printf('pdfannots -o "%s" "%s"', md, pdf))
  vim.fn.system(string.format('pdfannots -o "%s" "%s"', md, pdf))
  vim.cmd.edit(vim.fn.fnameescape(md))

  vim.fn.chdir(cwd)
end

-- Enable full-line syntax highlighting for LaTeX files
-- Override the global synmaxcol=200 setting for better LaTeX support
vim.opt_local.synmaxcol = 0  -- 0 means no limit

-- Helper function for bibexport
local function run_bibexport()
  local filedir = vim.fn.expand('%:p:h')
  local filename = vim.fn.expand('%:t:r')
  local output_bib = filename .. '.bib'
  local aux_file = 'build/' .. filename .. '.aux'

  local notify = require('neotex.util.notifications')

  -- Pre-check: .aux file must exist
  local aux_path = filedir .. '/' .. aux_file
  if vim.fn.filereadable(aux_path) == 0 then
    notify.editor('Bibexport failed: ' .. aux_file .. ' not found', notify.categories.ERROR, { file = filename })
    return
  end

  -- Build command and run asynchronously via jobstart
  local cmd = string.format('bibexport -o "%s" "%s"', output_bib, aux_file)
  local stderr_lines = {}

  vim.fn.jobstart(cmd, {
    cwd = filedir,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code == 0 then
          local output_path = filedir .. '/' .. output_bib
          notify.editor('Bibexport complete', notify.categories.USER_ACTION, { file = output_path })
        else
          local stderr_msg = table.concat(stderr_lines, "\n")
          if stderr_msg ~= "" then
            -- Truncate to last 5 lines to keep notification readable
            local lines = {}
            for line in stderr_msg:gmatch("[^\n]+") do
              table.insert(lines, line)
            end
            local truncated = {}
            local start_idx = math.max(1, #lines - 4)
            for i = start_idx, #lines do
              table.insert(truncated, lines[i])
            end
            stderr_msg = table.concat(truncated, "; ")
            notify.editor('Bibexport failed: ' .. stderr_msg, notify.categories.ERROR, { file = filename })
          else
            notify.editor('Bibexport failed (exit code: ' .. exit_code .. ')', notify.categories.ERROR, { file = filename })
          end
        end
      end)
    end,
  })
end

-- Register LaTeX-specific which-key mappings for this buffer
local ok_wk, wk = pcall(require, "which-key")
if ok_wk then
  -- LaTeX commands
  wk.add({
    { "<leader>l", group = "latex", icon = "󰙩", buffer = 0 },

    -- Shared core verbs (same meaning in the typst and slidev groups)
    { "<leader>ll", "<cmd>VimtexCompile<CR>", desc = "live compile", icon = "󰖷", buffer = 0 },
    { "<leader>lb", "<cmd>terminal latexmk -pdf %:p<CR>", desc = "build once", icon = "󰸞", buffer = 0 },
    { "<leader>lv", "<cmd>VimtexView<CR>", desc = "view pdf", icon = "󰛓", buffer = 0 },
    { "<leader>le", "<cmd>VimtexErrors<CR>", desc = "errors", icon = "󰅚", buffer = 0 },
    { "<leader>lf", "<cmd>terminal latexindent -w %:p:r.tex<CR>", desc = "format", icon = "󰉣", buffer = 0 },
    -- Both recovery steps at once: VimtexClean drops the aux files, VimtexClearCache
    -- drops vimtex's parse cache. They were separate keys (lk / lx) but are only ever
    -- wanted together, and splitting them cost a letter for no benefit.
    { "<leader>lk", "<cmd>VimtexClean<CR><cmd>VimtexClearCache All<CR>", desc = "clean aux + cache", icon = "󰩺", buffer = 0 },
    { "<leader>lx", "<cmd>VimtexStop<CR>", desc = "stop compiler", icon = "󰃢", buffer = 0 },
    { "<leader>li", "<cmd>VimtexTocOpen<CR>", desc = "index", icon = "󰋽", buffer = 0 },

    -- LaTeX-specific extras
    { "<leader>la", "<cmd>lua PdfAnnots()<CR>", desc = "annotate", icon = "󰏪", buffer = 0 },
    { "<leader>lr", function() run_bibexport() end, desc = "bib export (references)", icon = "󰈝", buffer = 0 },
    { "<leader>ld", "<cmd>terminal LATEXMK_DRAFT_MODE=1 latexmk -pdf -e '$draft_mode=1' %:p<CR>", desc = "draft mode", icon = "󰌶", buffer = 0 },
    { "<leader>lg", "<cmd>e ~/.config/nvim/templates/Glossary.tex<CR>", desc = "glossary", icon = "󰈚", buffer = 0 },
    { "<leader>lm", "<plug>(vimtex-context-menu)", desc = "menu", icon = "󰍉", buffer = 0 },
    { "<leader>lw", "<cmd>VimtexCountWords!<CR>", desc = "word count", icon = "󰆿", buffer = 0 },
    { "<leader>ls", function()
      local vimtex = vim.b.vimtex
      if vimtex and vim.fn.expand('%:p') == vimtex.tex then
        vim.notify("Already on main file", vim.log.levels.INFO)
      else
        vim.cmd('VimtexToggleMain')
      end
    end, desc = "subfile toggle", icon = "󰔏", buffer = 0 },
  })

  -- Template mappings
  wk.add({
    { "<leader>T", group = "templates", icon = "󰈭", buffer = 0 },
    { "<leader>Ta", "<cmd>read ~/.config/nvim/templates/article.tex<CR>", desc = "article.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tb", "<cmd>read ~/.config/nvim/templates/beamer_slides.tex<CR>", desc = "beamer_slides.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tg", "<cmd>read ~/.config/nvim/templates/glossary.tex<CR>", desc = "glossary.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Th", "<cmd>read ~/.config/nvim/templates/handout.tex<CR>", desc = "handout.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tl", "<cmd>read ~/.config/nvim/templates/letter.tex<CR>", desc = "letter.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tm", "<cmd>read ~/.config/nvim/templates/MultipleAnswer.tex<CR>", desc = "MultipleAnswer.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tr", function()
      local template_dir = vim.fn.expand("~/.config/nvim/templates/report")
      local current_dir = vim.fn.getcwd()
      vim.fn.system("cp -r " .. vim.fn.shellescape(template_dir) .. " " .. vim.fn.shellescape(current_dir))
      require('neotex.util.notifications').editor('Template copied', require('neotex.util.notifications').categories.USER_ACTION, { template = 'report', directory = current_dir })
    end, desc = "Copy report/ directory", icon = "󰉖", buffer = 0 },
    { "<leader>Ts", function()
      local template_dir = vim.fn.expand("~/.config/nvim/templates/springer")
      local current_dir = vim.fn.getcwd()
      vim.fn.system("cp -r " .. vim.fn.shellescape(template_dir) .. " " .. vim.fn.shellescape(current_dir))
      require('neotex.util.notifications').editor('Template copied', require('neotex.util.notifications').categories.USER_ACTION, { template = 'springer', directory = current_dir })
    end, desc = "Copy springer/ directory", icon = "󰉖", buffer = 0 },
  })
end



-- -- LSP menu to preserve vimtex citation data
-- require('cmp').setup.buffer {
--   formatting = {
--     format = function(entry, vim_item)
--         vim_item.menu = ({
--           omni = (vim.inspect(vim_item.menu):gsub('%"', "")),
--           buffer = "[Buffer]",
--           -- formatting for other sources
--           })[entry.source.name]
--         return vim_item
--       end,
--   },
--   sources = {
--     { name = 'omni' },
--     { name = 'buffer' },
--     -- other sources
--   },
-- }
