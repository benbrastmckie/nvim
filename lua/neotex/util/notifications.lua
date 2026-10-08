-- Unified Notification System for Neovim Configuration
-- Provides consistent, intelligent notification management across all modules

local M = {}

-- Configuration
M.config = {
  enabled = true,
  debug_mode = false,
  rate_limit_ms = 1000,
  batch_delay_ms = 1500,
  max_history = 200,
  
  -- Module-specific settings
  modules = {
    himalaya = { enabled = true, debug_mode = false },
    ai = { enabled = true, debug_mode = false },
    lsp = { enabled = true, debug_mode = false },
    editor = { enabled = true, debug_mode = false },
    startup = { enabled = true, debug_mode = false }
  }
}

-- State persistence
local state_file = vim.fn.stdpath('data') .. '/neotex_debug_state.json'

-- Notification categories
M.categories = {
  -- Critical notifications (always shown)
  ERROR = { 
    level = vim.log.levels.ERROR, 
    always_show = true,
    name = "ERROR",
    examples = { "Connection failed", "Command error", "Plugin failure" }
  },
  
  -- Important warnings (always shown)
  WARNING = { 
    level = vim.log.levels.WARN, 
    always_show = true,
    name = "WARNING",
    examples = { "Config deprecated", "Missing dependency", "Large file" }
  },
  
  -- User-initiated actions (always shown unless disabled)
  USER_ACTION = { 
    level = vim.log.levels.INFO, 
    always_show = true,
    name = "USER_ACTION",
    examples = { "Email sent", "File saved", "Buffer closed", "Feature toggled" }
  },
  
  -- Status updates (debug mode only)
  STATUS = { 
    level = vim.log.levels.INFO, 
    debug_only = true,
    name = "STATUS",
    examples = { "Page loaded", "Cache updated", "Connection established" }
  },
  
  -- Background operations (debug mode only)
  BACKGROUND = { 
    level = vim.log.levels.DEBUG, 
    debug_only = true,
    name = "BACKGROUND",
    examples = { "Auto-sync", "Cleanup", "Initialization", "Plugin loading" }
  }
}

-- Notification history and statistics
M.history = {}
M.stats = {
  total_notifications = 0,
  filtered_notifications = 0,
  batched_notifications = 0,
  by_module = {},
  by_category = {},
  performance = {
    avg_processing_time = 0,
    max_processing_time = 0,
    total_processing_time = 0
  }
}

-- Rate limiting tracking
M.recent_notifications = {}
M.notification_cooldown = {}

-- Batching system
M.batch_queue = {}
M.batch_timer = nil

-- Forward declare load_debug_state function
local load_debug_state

-- Setup function
function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend('force', M.config, user_config)
  end
  
  -- Load debug state from persistence
  M.config.debug_mode = load_debug_state()
  
  -- Initialize statistics
  for module_name, _ in pairs(M.config.modules) do
    M.stats.by_module[module_name] = {
      total = 0,
      filtered = 0,
      by_category = {}
    }
  end
  
  for category_name, _ in pairs(M.categories) do
    M.stats.by_category[category_name] = 0
  end
end

-- Check if notification should be shown based on filtering rules
function M.should_show_notification(category, message, context)
  local start_time = vim.loop.hrtime()
  
  local module = context.module or 'general'
  local module_config = M.config.modules[module]
  
  -- Always show critical notifications
  if category.always_show and category ~= M.categories.USER_ACTION then
    M._record_processing_time(start_time)
    return true
  end
  
  -- Check if notifications are globally disabled
  if not M.config.enabled then
    M._record_processing_time(start_time)
    return false
  end
  
  -- Check module-specific settings
  if module_config and not module_config.enabled then
    M._record_processing_time(start_time)
    return false
  end
  
  -- Debug mode shows everything for enabled modules
  if M.config.debug_mode or (module_config and module_config.debug_mode) then
    M._record_processing_time(start_time)
    return true
  end
  
  -- Apply category filtering
  if category.debug_only then
    M._record_processing_time(start_time)
    return false
  end
  
  -- Check rate limiting
  if M._is_rate_limited(message, context) then
    M._record_processing_time(start_time)
    return false
  end
  
  M._record_processing_time(start_time)
  return true
end

-- Rate limiting implementation
function M._is_rate_limited(message, context)
  local now = vim.loop.now()
  local key = string.format("%s:%s", context.module or 'general', message:gsub('%d+', 'N'))
  
  local last_time = M.recent_notifications[key]
  if last_time and (now - last_time) < M.config.rate_limit_ms then
    return true
  end
  
  M.recent_notifications[key] = now
  
  -- Clean up old entries
  for k, time in pairs(M.recent_notifications) do
    if (now - time) > (M.config.rate_limit_ms * 5) then
      M.recent_notifications[k] = nil
    end
  end
  
  return false
end

-- Record processing time for performance monitoring
function M._record_processing_time(start_time)
  local duration = (vim.loop.hrtime() - start_time) / 1000000 -- Convert to milliseconds
  M.stats.performance.total_processing_time = M.stats.performance.total_processing_time + duration
  M.stats.performance.max_processing_time = math.max(M.stats.performance.max_processing_time, duration)
  
  local count = M.stats.total_notifications + M.stats.filtered_notifications
  if count > 0 then
    M.stats.performance.avg_processing_time = M.stats.performance.total_processing_time / count
  end
end

-- Enhance message with context information
function M._enhance_message(message, context)
  if not context or vim.tbl_isempty(context) then
    return message
  end
  
  local enhanced = message
  
  -- Add count information
  if context.count and context.count > 1 then
    enhanced = string.format("%s (%d items)", enhanced, context.count)
  end
  
  -- Add file information
  if context.file then
    enhanced = string.format("%s [%s]", enhanced, context.file)
  end
  
  -- Add duration information
  if context.duration then
    enhanced = string.format("%s (%.1fs)", enhanced, context.duration / 1000)
  end
  
  return enhanced
end

-- Log notification to history
function M._log_to_history(message, category, context)
  local entry = {
    message = message,
    category = category.name,
    module = context.module or 'general',
    timestamp = os.time(),
    context = context
  }
  
  table.insert(M.history, entry)
  
  -- Trim history if too long
  while #M.history > M.config.max_history do
    table.remove(M.history, 1)
  end
end

-- Update statistics
function M._update_stats(category, context, filtered)
  M.stats.total_notifications = M.stats.total_notifications + 1
  
  if filtered then
    M.stats.filtered_notifications = M.stats.filtered_notifications + 1
  end
  
  -- Update category stats
  M.stats.by_category[category.name] = (M.stats.by_category[category.name] or 0) + 1
  
  -- Update module stats
  local module = context.module or 'general'
  if not M.stats.by_module[module] then
    M.stats.by_module[module] = { total = 0, filtered = 0, by_category = {} }
  end
  
  M.stats.by_module[module].total = M.stats.by_module[module].total + 1
  if filtered then
    M.stats.by_module[module].filtered = M.stats.by_module[module].filtered + 1
  end
  
  M.stats.by_module[module].by_category[category.name] = 
    (M.stats.by_module[module].by_category[category.name] or 0) + 1
end

-- Core notification function
function M.notify(message, category, context)
  category = category or M.categories.STATUS
  context = context or {}
  
  -- Apply filtering
  local should_show = M.should_show_notification(category, message, context)
  
  -- Update statistics
  M._update_stats(category, context, not should_show)
  
  -- Log to history regardless of whether it's shown
  M._log_to_history(message, category, context)
  
  if not should_show then
    return
  end
  
  -- Enhance message with context
  local enhanced_message = M._enhance_message(message, context)
  
  -- Check if batching is enabled and appropriate
  if M._should_batch(category, context) then
    M._add_to_batch(enhanced_message, category, context)
    return
  end
  
  -- Send the notification via Snacks.nvim (which overrides vim.notify)
  vim.notify(enhanced_message, category.level)
end

-- Check if notification should be batched
function M._should_batch(category, context)
  -- Don't batch errors or warnings
  if category == M.categories.ERROR or category == M.categories.WARNING then
    return false
  end
  
  -- Don't batch if batching is disabled
  if not context.allow_batching then
    return false
  end
  
  return true
end

-- Add notification to batch queue
function M._add_to_batch(message, category, context)
  table.insert(M.batch_queue, {
    message = message,
    category = category,
    context = context,
    timestamp = vim.loop.now()
  })
  
  -- Start or reset batch timer
  if M.batch_timer then
    M.batch_timer:stop()
    M.batch_timer:close()
  end
  
  M.batch_timer = vim.loop.new_timer()
  M.batch_timer:start(M.config.batch_delay_ms, 0, vim.schedule_wrap(function()
    M._process_batch()
    M.batch_timer:close()
    M.batch_timer = nil
  end))
end

-- Process batched notifications
function M._process_batch()
  if #M.batch_queue == 0 then
    return
  end
  
  -- Group notifications by category and module
  local groups = {}
  for _, notification in ipairs(M.batch_queue) do
    local key = string.format("%s:%s", notification.context.module or 'general', notification.category.name)
    if not groups[key] then
      groups[key] = {
        category = notification.category,
        module = notification.context.module or 'general',
        messages = {}
      }
    end
    table.insert(groups[key].messages, notification.message)
  end
  
  -- Create summary notifications for each group
  for _, group in pairs(groups) do
    local count = #group.messages
    if count > 1 then
      local summary = string.format("%d %s operations completed", count, string.lower(group.category.name))
      vim.notify(summary, group.category.level)
      M.stats.batched_notifications = M.stats.batched_notifications + count - 1
    else
      vim.notify(group.messages[1], group.category.level)
    end
  end
  
  -- Clear batch queue
  M.batch_queue = {}
end

-- Module-specific notification functions
function M.himalaya(message, category, context)
  context = vim.tbl_extend('force', context or {}, { module = 'himalaya' })
  return M.notify(message, category, context)
end

function M.ai(message, category, context)
  context = vim.tbl_extend('force', context or {}, { module = 'ai' })
  return M.notify(message, category, context)
end

function M.lsp(message, category, context)
  context = vim.tbl_extend('force', context or {}, { module = 'lsp' })
  return M.notify(message, category, context)
end

function M.editor(message, category, context)
  context = vim.tbl_extend('force', context or {}, { module = 'editor' })
  return M.notify(message, category, context)
end

function M.startup(message, category, context)
  context = vim.tbl_extend('force', context or {}, { module = 'startup' })
  return M.notify(message, category, context)
end

-- Convenience functions for common use cases
function M.error(message, context, module)
  if module then
    return M[module](message, M.categories.ERROR, context)
  else
    return M.notify(message, M.categories.ERROR, context)
  end
end

function M.warning(message, context, module)
  if module then
    return M[module](message, M.categories.WARNING, context)
  else
    return M.notify(message, M.categories.WARNING, context)
  end
end

function M.user_action(message, context, module)
  if module then
    return M[module](message, M.categories.USER_ACTION, context)
  else
    return M.notify(message, M.categories.USER_ACTION, context)
  end
end

function M.status(message, context, module)
  if module then
    return M[module](message, M.categories.STATUS, context)
  else
    return M.notify(message, M.categories.STATUS, context)
  end
end

function M.background(message, context, module)
  if module then
    return M[module](message, M.categories.BACKGROUND, context)
  else
    return M.notify(message, M.categories.BACKGROUND, context)
  end
end

-- Force notification (bypasses all filtering)
function M.notify_force(message, level, context)
  context = context or {}
  local enhanced_message = M._enhance_message(message, context)
  vim.notify(enhanced_message, level or vim.log.levels.INFO)
  
  -- Still log to history and stats
  local category = { name = "FORCED", level = level or vim.log.levels.INFO }
  M._log_to_history(enhanced_message, category, context)
  M._update_stats(category, context, false)
end

-- State persistence functions
load_debug_state = function()
  local ok, result = pcall(function()
    if vim.fn.filereadable(state_file) == 1 then
      local content = vim.fn.readfile(state_file)
      if content and #content > 0 then
        local state = vim.json.decode(table.concat(content, '\n'))
        if state and type(state.debug_mode) == 'boolean' then
          return state.debug_mode
        end
      end
    end
    return false -- Default to false if file doesn't exist or is invalid
  end)
  
  if ok then
    return result
  else
    return false -- Default on error
  end
end

local function save_debug_state()
  local ok = pcall(function()
    local state = { debug_mode = M.config.debug_mode }
    local encoded = vim.json.encode(state)
    vim.fn.writefile({ encoded }, state_file)
  end)
  
  if not ok then
    -- Silent failure - don't spam user with persistence errors
  end
end

-- Configuration management
function M.toggle_debug_mode()
  M.config.debug_mode = not M.config.debug_mode
  save_debug_state() -- Persist the new state
  local status = M.config.debug_mode and 'enabled' or 'disabled'
  M.notify_force(string.format('Global debug mode %s', status), vim.log.levels.INFO)
end

function M.toggle_module_debug(module_name)
  if not M.config.modules[module_name] then
    M.notify_force(string.format('Unknown module: %s', module_name), vim.log.levels.ERROR)
    return
  end
  
  M.config.modules[module_name].debug_mode = not M.config.modules[module_name].debug_mode
  local status = M.config.modules[module_name].debug_mode and 'enabled' or 'disabled'
  M.notify_force(string.format('%s debug mode %s', module_name, status), vim.log.levels.INFO)
end

function M.set_profile(profile_name)
  if profile_name == 'minimal' then
    M.config.debug_mode = false
    for module_name, _ in pairs(M.config.modules) do
      M.config.modules[module_name].debug_mode = false
    end
    M.notify_force('Notification profile set to minimal', vim.log.levels.INFO)
  elseif profile_name == 'verbose' then
    M.config.debug_mode = false
    for module_name, _ in pairs(M.config.modules) do
      M.config.modules[module_name].debug_mode = true
    end
    M.notify_force('Notification profile set to verbose', vim.log.levels.INFO)
  elseif profile_name == 'debug' then
    M.config.debug_mode = true
    for module_name, _ in pairs(M.config.modules) do
      M.config.modules[module_name].debug_mode = true
    end
    M.notify_force('Notification profile set to debug', vim.log.levels.INFO)
  else
    M.notify_force(string.format('Unknown profile: %s', profile_name), vim.log.levels.ERROR)
  end
end

-- Utility functions
function M.show_history()
  local history_lines = {}
  local recent_count = math.min(50, #M.history)
  
  for i = #M.history, math.max(1, #M.history - recent_count + 1), -1 do
    local entry = M.history[i]
    table.insert(history_lines, string.format(
      "[%s] %s/%s: %s",
      os.date("%H:%M:%S", entry.timestamp),
      entry.module,
      entry.category,
      entry.message
    ))
  end
  
  if #history_lines == 0 then
    table.insert(history_lines, "No notifications in history")
  end
  
  -- Create popup window
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, history_lines)
  vim.bo[bufnr].filetype = 'text'
  vim.bo[bufnr].readonly = true
  
  local width = math.min(100, vim.o.columns - 10)
  local height = math.min(30, vim.o.lines - 10)
  
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Notification History ',
    title_pos = 'center'
  }
  
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  -- Set up keymaps for the popup
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification history popup" }))
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification history popup" }))
end

function M.show_stats()
  local stats_lines = {}
  
  -- Overall statistics
  table.insert(stats_lines, "=== Notification Statistics ===")
  table.insert(stats_lines, "")
  table.insert(stats_lines, string.format("Total notifications: %d", M.stats.total_notifications))
  table.insert(stats_lines, string.format("Filtered notifications: %d", M.stats.filtered_notifications))
  table.insert(stats_lines, string.format("Batched notifications: %d", M.stats.batched_notifications))
  
  if M.stats.total_notifications > 0 then
    local filter_rate = (M.stats.filtered_notifications / M.stats.total_notifications) * 100
    table.insert(stats_lines, string.format("Filter effectiveness: %.1f%%", filter_rate))
  end
  
  -- Performance statistics
  table.insert(stats_lines, "")
  table.insert(stats_lines, "=== Performance ===")
  table.insert(stats_lines, string.format("Avg processing time: %.2fms", M.stats.performance.avg_processing_time))
  table.insert(stats_lines, string.format("Max processing time: %.2fms", M.stats.performance.max_processing_time))
  
  -- Category breakdown
  table.insert(stats_lines, "")
  table.insert(stats_lines, "=== By Category ===")
  for category, count in pairs(M.stats.by_category) do
    table.insert(stats_lines, string.format("%s: %d", category, count))
  end
  
  -- Module breakdown
  table.insert(stats_lines, "")
  table.insert(stats_lines, "=== By Module ===")
  for module, stats in pairs(M.stats.by_module) do
    if stats.total > 0 then
      local filter_rate = stats.filtered > 0 and (stats.filtered / stats.total) * 100 or 0
      table.insert(stats_lines, string.format("%s: %d total, %d filtered (%.1f%%)", 
        module, stats.total, stats.filtered, filter_rate))
    end
  end
  
  -- Create popup window
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stats_lines)
  vim.bo[bufnr].filetype = 'text'
  vim.bo[bufnr].readonly = true
  
  local width = 60
  local height = math.min(25, #stats_lines + 2)
  
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Notification Statistics ',
    title_pos = 'center'
  }
  
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  -- Set up keymaps for the popup
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification stats popup" }))
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification stats popup" }))
end

function M.show_config()
  local config_lines = {}
  
  table.insert(config_lines, "=== Notification Configuration ===")
  table.insert(config_lines, "")
  table.insert(config_lines, string.format("Enabled: %s", M.config.enabled and "true" or "false"))
  table.insert(config_lines, string.format("Global debug mode: %s", M.config.debug_mode and "true" or "false"))
  table.insert(config_lines, string.format("Rate limit: %dms", M.config.rate_limit_ms))
  table.insert(config_lines, string.format("Batch delay: %dms", M.config.batch_delay_ms))
  table.insert(config_lines, string.format("Max history: %d", M.config.max_history))
  
  table.insert(config_lines, "")
  table.insert(config_lines, "=== Module Settings ===")
  for module, settings in pairs(M.config.modules) do
    table.insert(config_lines, string.format("%s:", module))
    table.insert(config_lines, string.format("  enabled: %s", settings.enabled and "true" or "false"))
    table.insert(config_lines, string.format("  debug_mode: %s", settings.debug_mode and "true" or "false"))
  end
  
  -- Create popup window
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, config_lines)
  vim.bo[bufnr].filetype = 'yaml'
  vim.bo[bufnr].readonly = true
  
  local width = 50
  local height = math.min(20, #config_lines + 2)
  
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Notification Configuration ',
    title_pos = 'center'
  }
  
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  -- Set up keymaps for the popup
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification config popup" }))
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification config popup" }))
end

function M.clear_history()
  M.history = {}
  M.notify_force('Notification history cleared', vim.log.levels.INFO)
end

function M.show_help()
  local help_lines = {
    "=== Unified Notification System Help ===",
    "",
    "Commands:",
    "  :Notifications history    - Show recent notifications",
    "  :Notifications stats      - Show statistics and performance",
    "  :Notifications config     - Show current configuration",
    "  :Notifications clear      - Clear notification history",
    "  :NotifyDebug [module]     - Toggle debug mode",
    "",
    "Available modules: himalaya, ai, lsp, editor, startup",
    "",
    "Profiles:",
    "  :lua require('neotex.util.notifications').set_profile('minimal')",
    "  :lua require('neotex.util.notifications').set_profile('verbose')",
    "  :lua require('neotex.util.notifications').set_profile('debug')",
    "",
    "Categories:",
    "  ERROR      - Always shown (connection failures, errors)",
    "  WARNING    - Always shown (deprecated configs, warnings)",
    "  USER_ACTION - Always shown (send email, save file, etc.)",
    "  STATUS     - Debug only (page loads, cache updates)",
    "  BACKGROUND - Debug only (auto-sync, cleanup, init)",
    "",
    "See docs/NOTIFICATIONS.md for complete documentation"
  }
  
  -- Create popup window
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)
  vim.bo[bufnr].filetype = 'text'
  vim.bo[bufnr].readonly = true
  
  local width = 70
  local height = math.min(25, #help_lines + 2)
  
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Notification System Help ',
    title_pos = 'center'
  }
  
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  -- Set up keymaps for the popup
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification help popup" }))
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, vim.tbl_extend('force', opts, { desc = "Close notification help popup" }))
end

-- Create notification management commands
function M._setup_commands()
  -- Main notification management command
  vim.api.nvim_create_user_command('Notifications', function(opts)
    if opts.args == 'history' then
      M.show_history()
    elseif opts.args == 'stats' then
      M.show_stats()
    elseif opts.args == 'config' then
      M.show_config()
    elseif opts.args == 'clear' then
      M.clear_history()
    else
      M.show_help()
    end
  end, {
    nargs = '?',
    complete = function()
      return { 'history', 'stats', 'config', 'clear', 'help' }
    end,
    desc = 'Manage unified notification system'
  })
  
  -- Module-specific debug toggles
  vim.api.nvim_create_user_command('NotifyDebug', function(opts)
    local module = opts.args
    
    if module == '' then
      M.toggle_debug_mode()
    else
      M.toggle_module_debug(module)
    end
  end, {
    nargs = '?',
    complete = function()
      return vim.tbl_keys(M.config.modules)
    end,
    desc = 'Toggle debug mode for notification modules'
  })
end

-- Initialize the notification system
function M.init()
  M._setup_commands()
  
  -- Initialize with default config if not already set up
  if not M._initialized then
    M.setup()
    -- Load persisted debug state
    M.config.debug_mode = load_debug_state()
    M._initialized = true
  end
end


return M