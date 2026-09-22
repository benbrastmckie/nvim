-----------------------------------------------------
-- nvim-surround - Surround text with quotes, brackets, and more
--
-- Default mappings (see which-key for the <leader>s group):
-- - ys{motion}{char} - Add surround around motion   (<leader>ss)
-- - ds{char}         - Delete surround              (<leader>sd)
-- - cs{old}{new}     - Change surround              (<leader>sc)
-- - S{char}          - Surround selection (visual)  (<leader>ss)
--
-- Filetype-specific surrounds are defined HERE, in one table, rather than in
-- after/ftplugin/*. Markup filetypes share one key vocabulary so the same
-- keystroke means the same thing everywhere:
--
--   key  meaning          markdown        latex               typst
--   b    bold             **x**           \textbf{x}          *x*
--   i    italic           *x*             \textit{x}          _x_
--   c    inline code      `x`             \texttt{x}          `x`
--   C    code block       ```lang         -                   ```lang
--   m    inline math      $x$             $x$                 $x$
--   M    display math     $$x$$           \[x\]               $ x $
--   l    link             [x](url)        \href{url}{x}       #link("url")[x]
--   e    environment      -               \begin{env}         #fn[x]
--   ~    strikethrough    ~~x~~           -                   #strike[x]
--   q/Q  quotes           -               `x' / ``x''         -
--
-- `$` is an alias for `m` in every markup filetype; legacy keys `t` (latex)
-- and `r` (typst) still work as aliases for `c` and `C`.
--
-- Why aliases are cleared: nvim-surround resolves aliases BEFORE surrounds,
-- and ships defaults such as b -> ")", r -> "]", q -> any quote. A custom
-- `b` surround is therefore unreachable unless the alias is disabled. The
-- apply step below does this automatically for every key a filetype defines.
-----------------------------------------------------

-- Build a symmetric, literal-delimiter surround with matching find/delete
-- patterns. `left`/`right` are plain strings; they are escaped for Lua patterns.
local function pair(left, right, inner)
  local l = vim.pesc(left)
  local r = vim.pesc(right)
  return {
    add = { left, right },
    find = l .. (inner or ".-") .. r,
    delete = "^(" .. l .. ")().-(" .. r .. ")()$",
  }
end

-- Prompt for a value; returns nil on <Esc>/empty so the surround is aborted.
local function prompt(label)
  local ok, value = pcall(require("nvim-surround.config").get_input, label)
  if ok and value and value ~= "" then
    return value
  end
end

-- Fenced code block on its own lines, optional language (empty is allowed).
local function fenced_block()
  return {
    add = function()
      local ok, lang = pcall(require("nvim-surround.config").get_input, "Language: ")
      if not ok or lang == nil then
        return nil
      end
      return { { "```" .. lang, "" }, { "", "```" } }
    end,
  }
end

local filetype_surrounds = {
  markdown = {
    b = pair("**", "**"),
    i = pair("*", "*", "[^*]+"),
    c = pair("`", "`", "[^`]+"),
    C = fenced_block(),
    m = pair("$", "$", "[^$]+"),
    M = pair("$$", "$$"),
    ["~"] = pair("~~", "~~"),
    l = {
      add = function()
        local url = prompt("URL: ")
        return url and { { "[" }, { "](" .. url .. ")" } }
      end,
      find = "%b[]%b()",
      delete = "^(%[)().-(%]%b())()$",
    },
  },

  tex = {
    -- `\%a-bf` also matches \mathbf, \boldsymbol-style commands ending in bf, etc.
    b = {
      add = { "\\textbf{", "}" },
      find = "\\%a-bf%b{}",
      delete = "^(\\%a-bf{)().-(})()$",
    },
    i = {
      add = { "\\textit{", "}" },
      find = "\\%a-it%b{}",
      delete = "^(\\%a-it{)().-(})()$",
    },
    c = {
      add = { "\\texttt{", "}" },
      find = "\\%a-tt%b{}",
      delete = "^(\\%a-tt{)().-(})()$",
    },
    m = pair("$", "$", "[^$]+"),
    M = pair("\\[", "\\]"),
    q = pair("`", "'", "[^`']-"),
    Q = pair("``", "''"),
    l = {
      add = function()
        local url = prompt("URL: ")
        return url and { { "\\href{" .. url .. "}{" }, { "}" } }
      end,
      find = "\\href%b{}%b{}",
      delete = "^(\\href%b{}{)().-(})()$",
    },
    e = {
      add = function()
        local env = prompt("Environment: ")
        return env and { { "\\begin{" .. env .. "}" }, { "\\end{" .. env .. "}" } }
      end,
    },
  },

  typst = {
    b = pair("*", "*", "[^*]+"),
    i = pair("_", "_", "[^_]+"),
    c = pair("`", "`", "[^`]+"),
    C = fenced_block(),
    m = pair("$", "$", "[^$]+"),
    M = pair("$ ", " $"),
    ["~"] = {
      add = { "#strike[", "]" },
      find = "#strike%b[]",
      delete = "^(#strike%[)().-(%])()$",
    },
    l = {
      add = function()
        local url = prompt("URL: ")
        return url and { { '#link("' .. url .. '")[' }, { "]" } }
      end,
      find = "#link%b()%b[]",
      delete = "^(#link%b()%[)().-(%])()$",
    },
    e = {
      add = function()
        local fn = prompt("Function: ")
        return fn and { { "#" .. fn .. "[" }, { "]" } }
      end,
      find = "#[%w%-]+%b[]",
      delete = "^(#[%w%-]+%[)().-(%])()$",
    },
  },
}

-- Aliases shared by every markup filetype above, plus per-filetype legacy keys
-- kept so older muscle memory still works.
local markup_aliases = { ["$"] = "m" }
local filetype_aliases = {
  tex = { t = "c" }, -- \texttt
  typst = { r = "C" }, -- raw block
}

-- Apply the filetype's surrounds to a buffer, clearing any default alias that
-- would otherwise shadow a custom key.
local function apply(buf)
  local ft = vim.bo[buf].filetype
  local surrounds = filetype_surrounds[ft]
  if not surrounds then
    return
  end

  local aliases = vim.tbl_extend("force", markup_aliases, filetype_aliases[ft] or {})
  for key in pairs(surrounds) do
    if aliases[key] == nil then
      aliases[key] = false
    end
  end

  vim.api.nvim_buf_call(buf, function()
    require("nvim-surround").buffer_setup({ surrounds = surrounds, aliases = aliases })
  end)
end

return {
  "kylechui/nvim-surround",
  version = "*", -- Use the latest stable release
  event = "VeryLazy", -- <Plug> maps used by which-key must exist in every buffer
  opts = {},
  config = function(_, opts)
    require("nvim-surround").setup(opts)

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("NeotexSurround", { clear = true }),
      pattern = vim.tbl_keys(filetype_surrounds),
      callback = function(args)
        apply(args.buf)
      end,
      desc = "Filetype-specific nvim-surround surrounds",
    })

    -- Buffers whose FileType fired before this plugin loaded
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        apply(buf)
      end
    end
  end,
}
