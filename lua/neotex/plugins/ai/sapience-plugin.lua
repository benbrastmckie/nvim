-- sf1 Sapience Chat Plugin Specification
-- This file exports the plugin spec for lazy.nvim

return {
  -- Virtual plugin for sf1 setup
  dir = vim.fn.stdpath('config') .. '/lua/neotex/plugins/ai/sapience',
  name = 'sapience-sf1',
  event = { 'VeryLazy' }, -- Load after startup
  config = function(_, opts)
    -- Defer loading to avoid static analysis issues
    local module_path = 'neotex.plugins.ai.sapience.init'
    local sapience = require(module_path)
    sapience.setup(opts)

    vim.api.nvim_create_user_command('Sf1', function()
      sapience.toggle()
    end, { desc = 'Toggle sf1 Sapience chat terminal' })
  end,
}
