-- Global Notification Configuration
-- User-configurable notification preferences for the unified notification system

local M = {}

-- Default notification configuration
M.config = {
  -- Global settings
  enabled = true,
  debug_mode = false,
  
  -- Module-specific notification preferences
  modules = {
    himalaya = {
      email_operations = true,     -- Send, delete, move operations
      background_sync = false,     -- Cache updates, auto-sync
      connection_status = false,   -- IMAP connection messages
      pagination = false           -- Page navigation
    },
    
    ai = {
      model_switching = true,      -- Provider/model changes
      api_errors = true,           -- Connection failures
      processing = false           -- Background AI operations
    },
    
    lsp = {
      diagnostics = true,          -- Error/warning updates
      server_status = false,       -- LSP server connection
      formatting = true,           -- Format operations
      linting = true               -- Lint operations
    },
    
    editor = {
      file_operations = true,      -- Save, open, close
      feature_toggles = true,      -- Setting changes
      buffer_management = true,    -- Buffer operations
      performance = false          -- Optimization reports
    },
    
    startup = {
      plugin_loading = false,      -- Plugin initialization
      config_errors = true,        -- Configuration issues
      performance = false          -- Startup timing
    }
  },
  
  -- Performance and behavior settings
  batching = {
    enabled = true,
    delay_ms = 1500,
    max_batch_size = 10
  },
  
  rate_limiting = {
    enabled = true,
    cooldown_ms = 1000,
    max_per_minute = 20
  },
  
  history = {
    enabled = true,
    max_entries = 200,
    persist = false
  }
}

-- Convert user-friendly module preferences to notification system config
function M._convert_preferences_to_config()
  local notifications = require('neotex.util.notifications')
  
  -- Convert module preferences to debug mode settings
  local converted_config = {
    enabled = M.config.enabled,
    debug_mode = M.config.debug_mode,
    rate_limit_ms = M.config.rate_limiting.cooldown_ms,
    batch_delay_ms = M.config.batching.delay_ms,
    max_history = M.config.history.max_entries,
    modules = {}
  }
  
  -- Convert each module's preferences
  for module_name, preferences in pairs(M.config.modules) do
    converted_config.modules[module_name] = {
      enabled = true, -- Always enable modules, control via debug mode
      debug_mode = false -- Will be set based on individual preferences
    }
    
    -- If any background operation is enabled, enable debug mode for that module
    local has_debug_prefs = false
    for pref_name, enabled in pairs(preferences) do
      if enabled and M._is_debug_preference(pref_name) then
        has_debug_prefs = true
        break
      end
    end
    
    converted_config.modules[module_name].debug_mode = has_debug_prefs
  end
  
  return converted_config
end

-- Check if a preference controls debug-only notifications
function M._is_debug_preference(pref_name)
  local debug_preferences = {
    'background_sync',
    'connection_status', 
    'pagination',
    'processing',
    'server_status',
    'performance',
    'plugin_loading'
  }
  
  return vim.tbl_contains(debug_preferences, pref_name)
end

-- Apply the configuration to the notification system
function M.apply()
  local notifications = require('neotex.util.notifications')
  local converted_config = M._convert_preferences_to_config()
  
  notifications.setup(converted_config)
  -- Note: notifications module doesn't have an init() function
end

-- Profile presets for common use cases
M.profiles = {
  minimal = {
    debug_mode = false,
    modules = {
      himalaya = { email_operations = true, background_sync = false, connection_status = false, pagination = false },
      ai = { model_switching = true, api_errors = true, processing = false },
      lsp = { diagnostics = true, server_status = false, formatting = true, linting = true },
      editor = { file_operations = true, feature_toggles = true, buffer_management = true, performance = false },
      startup = { plugin_loading = false, config_errors = true, performance = false }
    }
  },
  
  verbose = {
    debug_mode = false,
    modules = {
      himalaya = { email_operations = true, background_sync = true, connection_status = false, pagination = false },
      ai = { model_switching = true, api_errors = true, processing = true },
      lsp = { diagnostics = true, server_status = true, formatting = true, linting = true },
      editor = { file_operations = true, feature_toggles = true, buffer_management = true, performance = true },
      startup = { plugin_loading = true, config_errors = true, performance = false }
    }
  },
  
  debug = {
    debug_mode = true,
    modules = {
      himalaya = { email_operations = true, background_sync = true, connection_status = true, pagination = true },
      ai = { model_switching = true, api_errors = true, processing = true },
      lsp = { diagnostics = true, server_status = true, formatting = true, linting = true },
      editor = { file_operations = true, feature_toggles = true, buffer_management = true, performance = true },
      startup = { plugin_loading = true, config_errors = true, performance = true }
    }
  }
}

-- Set a notification profile
function M.set_profile(profile_name)
  if not M.profiles[profile_name] then
    vim.notify('Unknown notification profile: ' .. profile_name, vim.log.levels.ERROR)
    return
  end
  
  M.config = vim.tbl_deep_extend('force', M.config, M.profiles[profile_name])
  M.apply()
  
  vim.notify('Notification profile set to: ' .. profile_name, vim.log.levels.INFO)
end

-- User configuration function
-- Setup function for user configuration
function M.configure(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend('force', M.config, user_config)
  end
  
  M.apply()
end

-- Convenience functions for quick configuration changes
function M.enable_module(module_name)
  if M.config.modules[module_name] then
    for pref_name, _ in pairs(M.config.modules[module_name]) do
      M.config.modules[module_name][pref_name] = true
    end
    M.apply()
    vim.notify(string.format('%s notifications enabled', module_name), vim.log.levels.INFO)
  else
    vim.notify(string.format('Unknown module: %s', module_name), vim.log.levels.ERROR)
  end
end

function M.disable_module(module_name)
  if M.config.modules[module_name] then
    for pref_name, _ in pairs(M.config.modules[module_name]) do
      if not M._is_critical_preference(pref_name) then
        M.config.modules[module_name][pref_name] = false
      end
    end
    M.apply()
    vim.notify(string.format('%s background notifications disabled', module_name), vim.log.levels.INFO)
  else
    vim.notify(string.format('Unknown module: %s', module_name), vim.log.levels.ERROR)
  end
end

-- Check if a preference is critical (should not be disabled)
function M._is_critical_preference(pref_name)
  local critical_preferences = {
    'email_operations',
    'api_errors',
    'diagnostics',
    'file_operations',
    'config_errors'
  }
  
  return vim.tbl_contains(critical_preferences, pref_name)
end

-- Show current configuration
function M.show_config()
  local config_lines = {}
  
  table.insert(config_lines, "=== Notification Configuration ===")
  table.insert(config_lines, "")
  table.insert(config_lines, string.format("Global debug mode: %s", M.config.debug_mode and "enabled" or "disabled"))
  table.insert(config_lines, "")
  
  for module_name, preferences in pairs(M.config.modules) do
    table.insert(config_lines, string.format("%s:", module_name))
    for pref_name, enabled in pairs(preferences) do
      local status = enabled and "✓" or "✗"
      table.insert(config_lines, string.format("  %s %s", status, pref_name))
    end
    table.insert(config_lines, "")
  end
  
  table.insert(config_lines, "Performance Settings:")
  table.insert(config_lines, string.format("  Batching: %s", M.config.batching.enabled and "enabled" or "disabled"))
  table.insert(config_lines, string.format("  Rate limiting: %s", M.config.rate_limiting.enabled and "enabled" or "disabled"))
  table.insert(config_lines, string.format("  History: %s", M.config.history.enabled and "enabled" or "disabled"))
  
  -- Create popup window
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, config_lines)
  vim.bo[bufnr].filetype = 'text'
  vim.bo[bufnr].readonly = true
  
  local width = 60
  local height = math.min(25, #config_lines + 2)
  
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Notification Preferences ',
    title_pos = 'center'
  }
  
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  -- Set up keymaps for the popup
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification preferences popup" }))
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification preferences popup" }))
end

-- Create configuration management commands
function M._setup_commands()
  vim.api.nvim_create_user_command('NotificationConfig', function(opts)
    if opts.args == 'show' or opts.args == '' then
      M.show_config()
    elseif opts.args:match('^profile%s+') then
      local profile = opts.args:match('^profile%s+(.+)')
      M.set_profile(profile)
    elseif opts.args:match('^enable%s+') then
      local module = opts.args:match('^enable%s+(.+)')
      M.enable_module(module)
    elseif opts.args:match('^disable%s+') then
      local module = opts.args:match('^disable%s+(.+)')
      M.disable_module(module)
    else
      vim.notify('Usage: :NotificationConfig [show|profile <name>|enable <module>|disable <module>]', vim.log.levels.INFO)
    end
  end, {
    nargs = '*',
    complete = function(arglead, cmdline)
      local args = vim.split(cmdline, '%s+')
      if #args == 2 then
        return { 'show', 'profile', 'enable', 'disable' }
      elseif #args == 3 then
        if args[2] == 'profile' then
          return vim.tbl_keys(M.profiles)
        elseif args[2] == 'enable' or args[2] == 'disable' then
          return vim.tbl_keys(M.config.modules)
        end
      end
      return {}
    end,
    desc = 'Manage notification configuration'
  })
end

-- Initialize the configuration system
function M.init()
  -- Setup commands with error handling
  local ok, err = pcall(M._setup_commands)
  if not ok then
    vim.notify('Failed to setup notification commands: ' .. tostring(err), vim.log.levels.WARN)
  end
  
  -- Apply default configuration with error handling
  ok, err = pcall(M.apply)
  if not ok then
    vim.notify('Failed to apply notification config: ' .. tostring(err), vim.log.levels.WARN)
  end
end

-- Setup function for integration with config system
function M.setup()
  -- Wrap in pcall to catch any errors
  local ok, err = pcall(M.init)
  if not ok then
    vim.notify('Notification setup error: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

return M