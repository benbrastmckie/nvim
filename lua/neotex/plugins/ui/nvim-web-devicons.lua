return {
  "nvim-tree/nvim-web-devicons",
  config = function()
    -- No icon overrides: the plugin's built-in table already covers every
    -- extension we care about. `default = true` makes get_icon() fall back to
    -- the generic file glyph instead of returning nil, so unknown extensions
    -- still render an icon in neo-tree, telescope, bufferline and lualine.
    require("nvim-web-devicons").setup({
      default = true,
    })
  end,
}
