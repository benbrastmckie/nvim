-- Typst Preview Plugin Configuration
-- Live preview for Typst documents with cross-jump support
return {
  "chomosuke/typst-preview.nvim",
  version = "1.*",  -- Pin to 1.x for stability
  ft = "typst",
  config = function()
    require("typst-preview").setup({
      -- Use system-installed tinymist from NixOS, auto-download websocat
      dependencies_bin = {
        ["tinymist"] = "tinymist",
        ["websocat"] = nil, -- nil = auto-download, required for click-to-jump
      },
      -- Open preview in default browser
      open_cmd = nil, -- Uses xdg-open on Linux
      -- Invert colors for dark mode (optional)
      invert_colors = "never",
      -- Follow cursor in preview (forward sync: Neovim -> browser)
      follow_cursor = true,
      -- Debug mode (logs to ~/.local/share/nvim/typst-preview/log.txt)
      debug = false,
      -- Main file detection and project root: delegate to the shared helper so the web
      -- preview agrees with the CLI commands and tinymist about "which document is this".
      get_main_file = function(current_file)
        return require("neotex.util.typst").main_file(current_file)
      end,
      get_root = function(main_file)
        return require("neotex.util.typst").project_root(main_file)
      end,
    })
  end,
}
