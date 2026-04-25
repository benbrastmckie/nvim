return {
  "lervag/vimtex",
  init = function()
    -- Viewer settings
    vim.g.vimtex_view_method = 'sioyek'            -- Sioyek PDF viewer for academic documents
    -- Note: Not setting vimtex_view_sioyek_options allows VimTeX to handle window management
    -- It will open new windows when needed but reuse for the same document
    vim.g.vimtex_context_pdf_viewer = 'okular'     -- External PDF viewer for the Vimtex menu

    -- Formatting settings
    -- vim.g.vimtex_format_enabled = true             -- Enable formatting with latexindent
    -- vim.g.vimtex_format_program = 'latexindent'

    -- Indentation settings
    vim.g.vimtex_indent_enabled = false            -- Disable auto-indent from Vimtex
    vim.g.tex_indent_items = false                 -- Disable indent for enumerate
    vim.g.tex_indent_brace = false                 -- Disable brace indent

    -- Compiler settings
    vim.g.vimtex_compiler_method = 'latexmk'       -- Explicit compiler backend selection
    vim.g.vimtex_compiler_latexmk = {              -- latexmk configuration
      build_dir = 'build',                         -- Build artifacts directory
      out_dir = 'build',                           -- Output directory for PDF and aux files
      aux_dir = 'build',                           -- Auxiliary files directory
      options = {
        '-interaction=nonstopmode',                -- Don't stop on errors
        '-file-line-error',                        -- Better error messages
        '-synctex=1',                              -- Enable SyncTeX
      },
    }

    -- Quickfix settings
    vim.g.vimtex_quickfix_mode = 0                 -- Open quickfix window on errors (2 = auto-close when empty)
    vim.g.vimtex_quickfix_ignore_filters = {       -- Filter out common noise
      'Underfull',
      'Overfull',
      'specifier changed to',
      'Token not allowed in a PDF string',
      'Package hyperref Warning',
    }
    vim.g.vimtex_log_ignore = {                    -- Suppress specific log messages
      'Underfull',
      'Overfull',
      'specifier changed to',
      'Token not allowed in a PDF string',
    }

    -- Other settings
    vim.g.vimtex_mappings_enabled = false          -- Disable default mappings
    vim.g.tex_flavor = 'latex'                     -- Set file type for TeX files
  end,
}
