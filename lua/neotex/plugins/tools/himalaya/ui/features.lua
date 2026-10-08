-- Himalaya Phase 8 UI Features
-- UI components for advanced email features

local M = {}

local float = require('neotex.plugins.tools.himalaya.ui.float')
local utils = require('neotex.plugins.tools.himalaya.utils')
local config = require('neotex.plugins.tools.himalaya.core.config')
local state = require('neotex.plugins.tools.himalaya.core.state')
local notify = require('neotex.util.notifications')

-- Show unified inbox across all accounts
function M.show_unified_inbox(emails)
  local lines = { '# Unified Inbox', '' }
  
  -- Group by account
  local by_account = {}
  for _, email in ipairs(emails) do
    local account = email.account or 'default'
    by_account[account] = by_account[account] or {}
    table.insert(by_account[account], email)
  end
  
  -- Display emails grouped by account
  for account, account_emails in pairs(by_account) do
    table.insert(lines, '## ' .. account)
    table.insert(lines, '')
    
    for _, email in ipairs(account_emails) do
      local flags = utils.format_flags(email.flags)
      local date = utils.format_date(email.date)
      local from = utils.format_from(email.from)
      local subject = email.subject or '(no subject)'
      
      table.insert(lines, string.format('%s %s | %s | %s | %s',
        email.id, flags, date, from, subject))
    end
    
    table.insert(lines, '')
  end
  
  -- Create buffer and show
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_name(buf, 'Himalaya: Unified Inbox')
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Set keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local id = line:match('^(%S+)')
    if id and not line:match('^#') then
      -- Find email and open it
      for _, email in ipairs(emails) do
        if email.id == id then
          require('neotex.plugins.tools.himalaya.ui').open_email_window(email)
          break
        end
      end
    end
  end, vim.tbl_extend('force', opts, { desc = "Open selected email" }))
  
  vim.keymap.set('n', 'q', ':close<CR>', vim.tbl_extend('force', opts, { desc = "Close email list" }))
end

-- Show attachments list for an email
function M.show_attachments_list(email_id, attachments)
  local lines = { '# Attachments for Email: ' .. email_id, '' }
  
  for i, attachment in ipairs(attachments) do
    local size = utils.format_size(attachment.size)
    local icon = M.get_file_icon(attachment.content_type)
    
    table.insert(lines, string.format('%d. %s %s (%s) - %s',
      i, icon, attachment.filename or 'unnamed', size, attachment.content_type))
  end
  
  table.insert(lines, '')
  table.insert(lines, 'Actions:')
  table.insert(lines, '  <CR> - View attachment')
  table.insert(lines, '  s    - Save attachment')
  table.insert(lines, '  S    - Save all attachments')
  table.insert(lines, '  q    - Close')
  
  local buf = float.create_buffer(lines)
  local win = float.show_buffer(buf, {
    title = 'Attachments',
    width = 60,
    height = math.min(#lines + 2, 20)
  })
  
  -- Set keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  
  vim.keymap.set('n', '<CR>', function()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local attachment = attachments[line_num - 2] -- Account for header lines
    if attachment then
      require('neotex.plugins.tools.himalaya.features.attachments').view(
        email_id, attachment.id, attachment)
    end
  end, vim.tbl_extend('force', opts, { desc = "View selected attachment" }))
  
  vim.keymap.set('n', 's', function()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local attachment = attachments[line_num - 2]
    if attachment then
      local path = vim.fn.input('Save to: ', vim.fn.expand('~/Downloads/'))
      if path ~= '' then
        require('neotex.plugins.tools.himalaya.features.attachments').save(
          email_id, attachment.id, path)
      end
    end
  end, vim.tbl_extend('force', opts, { desc = "Save selected attachment" }))
  
  vim.keymap.set('n', 'S', function()
    local path = vim.fn.input('Save all to directory: ', vim.fn.expand('~/Downloads/'))
    if path ~= '' then
      for _, attachment in ipairs(attachments) do
        require('neotex.plugins.tools.himalaya.features.attachments').save(
          email_id, attachment.id, path)
      end
    end
  end, vim.tbl_extend('force', opts, { desc = "Save all attachments" }))
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, vim.tbl_extend('force', opts, { desc = "Close attachments window" }))
end

-- Show trash folder
function M.show_trash_list(trash_items)
  local lines = { '# Trash Folder', '' }
  
  for _, item in ipairs(trash_items) do
    local deleted_date = os.date('%Y-%m-%d %H:%M', item.deleted_at)
    local original_date = utils.format_date(item.email.date)
    local from = utils.format_from(item.email.from)
    local subject = item.email.subject or '(no subject)'
    
    table.insert(lines, string.format('%s | Deleted: %s | %s | %s | %s',
      item.id, deleted_date, original_date, from, subject))
  end
  
  table.insert(lines, '')
  table.insert(lines, 'Actions:')
  table.insert(lines, '  <CR> - View email')
  table.insert(lines, '  r    - Recover email')
  table.insert(lines, '  d    - Delete permanently')
  table.insert(lines, '  D    - Empty trash')
  table.insert(lines, '  q    - Close')
  
  -- Create buffer and show
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_name(buf, 'Himalaya: Trash')
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Set keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local id = line:match('^(%S+)')
    if id and not line:match('^#') then
      -- Find and display email
      for _, item in ipairs(trash_items) do
        if item.id == id then
          require('neotex.plugins.tools.himalaya.ui').open_email_window(item.email)
          break
        end
      end
    end
  end, vim.tbl_extend('force', opts, { desc = "View selected trashed email" }))
  
  vim.keymap.set('n', 'r', function()
    local line = vim.api.nvim_get_current_line()
    local id = line:match('^(%S+)')
    if id and not line:match('^#') then
      vim.cmd('HimalayaTrashRecover ' .. id)
      -- Refresh view
      vim.defer_fn(function()
        vim.cmd('HimalayaTrashList')
      end, 500)
    end
  end, vim.tbl_extend('force', opts, { desc = "Recover selected trashed email" }))
  
  vim.keymap.set('n', 'd', function()
    local line = vim.api.nvim_get_current_line()
    local id = line:match('^(%S+)')
    if id and not line:match('^#') then
      local confirm = vim.fn.input('Permanently delete? (y/N): ')
      if confirm:lower() == 'y' then
        -- Complex trash system removed - use standard delete
        -- Refresh view
        vim.defer_fn(function()
          vim.cmd('HimalayaTrashList')
        end, 500)
      end
    end
  end, vim.tbl_extend('force', opts, { desc = "Permanently delete selected trashed email" }))
  
  vim.keymap.set('n', 'D', function()
    vim.cmd('HimalayaTrashEmpty')
  end, vim.tbl_extend('force', opts, { desc = "Empty trash" }))
  
  vim.keymap.set('n', 'q', ':close<CR>', vim.tbl_extend('force', opts, { desc = "Close trash list" }))
end

-- Picker for attachments
function M.pick_attachment(email_id, attachments, callback)
  local items = {}
  
  for _, attachment in ipairs(attachments) do
    local size = utils.format_size(attachment.size)
    table.insert(items, {
      text = string.format('%s (%s)', attachment.filename or 'unnamed', size),
      value = attachment
    })
  end
  
  vim.ui.select(items, {
    prompt = 'Select attachment:',
    format_item = function(item) return item.text end
  }, function(choice)
    if choice then
      callback(choice.value)
    end
  end)
end

-- Show email headers
function M.show_headers(headers)
  local lines = { '# Email Headers', '' }
  
  -- Sort headers for better display
  local sorted_headers = {}
  for name, value in pairs(headers) do
    table.insert(sorted_headers, { name = name, value = value })
  end
  
  table.sort(sorted_headers, function(a, b)
    -- Put important headers first
    local priority = {
      From = 1, To = 2, Subject = 3, Date = 4,
      ['Message-ID'] = 5, ['Reply-To'] = 6
    }
    
    local a_pri = priority[a.name] or 999
    local b_pri = priority[b.name] or 999
    
    if a_pri ~= b_pri then
      return a_pri < b_pri
    end
    
    return a.name < b.name
  end)
  
  -- Display headers
  for _, header in ipairs(sorted_headers) do
    table.insert(lines, string.format('%s: %s', header.name, header.value))
  end
  
  local buf = float.create_buffer(lines)
  float.show_buffer(buf, {
    title = 'Email Headers',
    width = 80,
    height = math.min(#lines + 2, 40)
  })
end

-- Helper function to get file icon based on content type
function M.get_file_icon(content_type)
  if not content_type then return '📎' end
  
  if content_type:match('^image/') then
    return '🖼️'
  elseif content_type:match('^video/') then
    return '🎥'
  elseif content_type:match('^audio/') then
    return '🎵'
  elseif content_type:match('pdf') then
    return '📄'
  elseif content_type:match('zip') or content_type:match('compressed') then
    return '📦'
  elseif content_type:match('text/') then
    return '📝'
  else
    return '📎'
  end
end

return M