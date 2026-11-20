return {
  'MeanderingProgrammer/render-markdown.nvim',
  event = "BufRead",
  ft = { "markdown" },
  opts = {
    file_types = { "markdown" },
    -- Top-level options. The `render` table accepts only `diff`.
    max_file_size = 10.0,
    debounce = 100,
    render_modes = { 'n', 'c' },
    anti_conceal = {
      enabled = true,
      above = 0,
      below = 0,
      disabled_modes = { 'i' },
    },
    heading = {
      enabled = true,
      sign = true,
      position = 'overlay',
      icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
      backgrounds = {
        'RenderMarkdownH1Bg',
        'RenderMarkdownH2Bg',
        'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg',
        'RenderMarkdownH5Bg',
        'RenderMarkdownH6Bg',
      },
      foregrounds = {
        'RenderMarkdownH1',
        'RenderMarkdownH2',
        'RenderMarkdownH3',
        'RenderMarkdownH4',
        'RenderMarkdownH5',
        'RenderMarkdownH6',
      },
    },
    paragraph = {
      enabled = true,
      left_margin = 0,
      min_width = 0,
    },
    code = {
      enabled = true,
      sign = true,
      -- `style` is a preset: 'normal' expands to `language = false`, cancelling the
      -- language row. 'full' expands to nothing, leaving the keys below authoritative.
      style = 'full',
      position = 'left',
      language = true,
      language_pad = 0,
      language_name = true,
      disable_background = { 'diff' },
      width = 'full',
      left_margin = 0,
      left_pad = 0,
      right_pad = 0,
      min_width = 0,
      border = 'thin',
      above = '▄',
      below = '▀',
      highlight = 'RenderMarkdownCode',
      highlight_inline = 'RenderMarkdownCodeInline',
    },
    dash = {
      enabled = true,
      icon = '─',
      width = 'full',
      highlight = 'RenderMarkdownDash',
    },
    bullet = {
      enabled = true,
      icons = { '●', '○', '◆', '◇' },
      left_pad = 0,
      right_pad = 0,
      highlight = 'RenderMarkdownBullet',
    },
    checkbox = {
      enabled = true,
      -- `bullet = false` conceals the list marker so the icon stands in for it.
      -- `right_pad = 0` aligns checkbox text with plain bullet text, since the icons
      -- below already carry a trailing space.
      bullet = false,
      left_pad = 0,
      right_pad = 0,
      unchecked = {
        icon = '󰄱 ',
        highlight = 'RenderMarkdownUnchecked',
        scope_highlight = nil,
      },
      checked = {
        icon = '󰱒 ',
        highlight = 'RenderMarkdownChecked',
        scope_highlight = nil,
      },
      custom = {
        todo = { raw = '[-]', rendered = '󰥔 ', highlight = 'RenderMarkdownTodo' },
      },
    },
    quote = {
      enabled = true,
      icon = '▋',
      repeat_linebreak = false,
      highlight = 'RenderMarkdownQuote',
    },
    pipe_table = {
      enabled = true,
      preset = 'none',
      -- `style` is a preset: 'normal' expands to `border_enabled = false`, leaving the
      -- corner glyphs unused. 'full' expands to nothing, so the keys below govern.
      style = 'full',
      cell = 'padded',
      padding = 1,
      min_width = 0,
      border = {
        '┌', '┬', '┐',
        '├', '┼', '┤',
        '└', '┴', '┘',
        '│', '─',
      },
      border_enabled = true,
      border_virtual = false,
      alignment_indicator = '━',
      head = 'RenderMarkdownTableHead',
      row = 'RenderMarkdownTableRow',
    },
    callout = {
      note = { raw = '[!NOTE]', rendered = '󰋽 Note', highlight = 'RenderMarkdownInfo' },
      tip = { raw = '[!TIP]', rendered = '󰌶 Tip', highlight = 'RenderMarkdownSuccess' },
      important = { raw = '[!IMPORTANT]', rendered = '󰅾 Important', highlight = 'RenderMarkdownHint' },
      warning = { raw = '[!WARNING]', rendered = '󰀪 Warning', highlight = 'RenderMarkdownWarn' },
      caution = { raw = '[!CAUTION]', rendered = '󰳦 Caution', highlight = 'RenderMarkdownError' },
      abstract = { raw = '[!ABSTRACT]', rendered = '󰨸 Abstract', highlight = 'RenderMarkdownInfo' },
      summary = { raw = '[!SUMMARY]', rendered = '󰨸 Summary', highlight = 'RenderMarkdownInfo' },
      tldr = { raw = '[!TLDR]', rendered = '󰨸 Tldr', highlight = 'RenderMarkdownInfo' },
      info = { raw = '[!INFO]', rendered = '󰋽 Info', highlight = 'RenderMarkdownInfo' },
      todo = { raw = '[!TODO]', rendered = '󰗡 Todo', highlight = 'RenderMarkdownInfo' },
      hint = { raw = '[!HINT]', rendered = '󰌶 Hint', highlight = 'RenderMarkdownSuccess' },
      success = { raw = '[!SUCCESS]', rendered = '󰄬 Success', highlight = 'RenderMarkdownSuccess' },
      check = { raw = '[!CHECK]', rendered = '󰄬 Check', highlight = 'RenderMarkdownSuccess' },
      done = { raw = '[!DONE]', rendered = '󰄬 Done', highlight = 'RenderMarkdownSuccess' },
      question = { raw = '[!QUESTION]', rendered = '󰘥 Question', highlight = 'RenderMarkdownWarn' },
      help = { raw = '[!HELP]', rendered = '󰘥 Help', highlight = 'RenderMarkdownWarn' },
      faq = { raw = '[!FAQ]', rendered = '󰘥 Faq', highlight = 'RenderMarkdownWarn' },
      attention = { raw = '[!ATTENTION]', rendered = '󰀪 Attention', highlight = 'RenderMarkdownWarn' },
      failure = { raw = '[!FAILURE]', rendered = '󰅖 Failure', highlight = 'RenderMarkdownError' },
      fail = { raw = '[!FAIL]', rendered = '󰅖 Fail', highlight = 'RenderMarkdownError' },
      missing = { raw = '[!MISSING]', rendered = '󰅖 Missing', highlight = 'RenderMarkdownError' },
      danger = { raw = '[!DANGER]', rendered = '󱐌 Danger', highlight = 'RenderMarkdownError' },
      error = { raw = '[!ERROR]', rendered = '󰅖 Error', highlight = 'RenderMarkdownError' },
      bug = { raw = '[!BUG]', rendered = '󰨰 Bug', highlight = 'RenderMarkdownError' },
      example = { raw = '[!EXAMPLE]', rendered = '󰉹 Example', highlight = 'RenderMarkdownHint' },
      quote = { raw = '[!QUOTE]', rendered = '󱆨 Quote', highlight = 'RenderMarkdownQuote' },
      cite = { raw = '[!CITE]', rendered = '󱆨 Cite', highlight = 'RenderMarkdownQuote' },
    },
    link = {
      enabled = true,
      image = '󰥶 ',
      email = '󰀓 ',
      hyperlink = '󰌹 ',
      highlight = 'RenderMarkdownLink',
      custom = {
        web = { pattern = '^http[s]?://', icon = '󰖟 ', highlight = 'RenderMarkdownLink' },
      },
    },
    sign = {
      enabled = true,
      highlight = 'RenderMarkdownSign',
    },
    indent = {
      enabled = false,
      per_level = 2,
      skip_level = 1,
      skip_heading = false,
    },
    latex = {
      enabled = false,
    },
    document = {
      enabled = true,
      conceal = {
        -- Generated markdown (specs/ROADMAP.md and friends) carries explicit HTML
        -- anchor targets so in-page links survive heading renames. They are link
        -- plumbing, not content, so hide the whole line rather than leaving a blank
        -- one behind. anti_conceal reveals the line again when the cursor is on it.
        char_patterns = {},
        line_patterns = { '<a id="[^"]*"></a>' },
      },
    },
    html = {
      enabled = true,
      comment = {
        -- Turn off HTML comment concealing so comments are always visible
        conceal = false,
        -- Optional: Add text/icon before comments
        text = '<!-- -->',
        highlight = 'RenderMarkdownHtmlComment',
      },
    },
    win_options = {
      conceallevel = {
        default = vim.o.conceallevel,
        rendered = 3,
      },
      concealcursor = {
        default = vim.o.concealcursor,
        rendered = '',
      },
    },
    -- Log level: 'debug', 'info', 'warn', 'error', 'off'
    log_level = 'error',
  },
  config = function(_, opts)
    require('render-markdown').setup(opts)
  end,
}