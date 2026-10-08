-- Himalaya Advanced Search System
-- Implements search operators, filters, and intelligent email matching
-- Supports Gmail-style search operators and complex queries

local M = {}

local state = require('neotex.plugins.tools.himalaya.core.state')
local notify = require('neotex.util.notifications')
local logger = require('neotex.plugins.tools.himalaya.core.logger')
local utils = require('neotex.plugins.tools.himalaya.utils')
local config = require('neotex.plugins.tools.himalaya.core.config')

-- Search operators configuration
M.operators = {
  -- Text field operators
  from = { field = "from", type = "text", description = "Search sender address" },
  to = { field = "to", type = "text", description = "Search recipient address" },
  cc = { field = "cc", type = "text", description = "Search CC recipients" },
  bcc = { field = "bcc", type = "text", description = "Search BCC recipients" },
  subject = { field = "subject", type = "text", description = "Search email subject" },
  body = { field = "body", type = "text", description = "Search email body" },
  
  -- Date operators
  date = { field = "date", type = "date", op = "=", description = "Search by exact date" },
  before = { field = "date", type = "date", op = "<", description = "Search emails before date" },
  after = { field = "date", type = "date", op = ">", description = "Search emails after date" },
  newer_than = { field = "date", type = "relative_date", op = ">", description = "Search emails newer than X days" },
  older_than = { field = "date", type = "relative_date", op = "<", description = "Search emails older than X days" },
  
  -- Flag operators  
  has = { field = "flags", type = "flag", description = "Search emails with specific flags" },
  is = { field = "status", type = "status", description = "Search by read/unread status" },
  starred = { field = "starred", type = "boolean", description = "Search starred emails" },
  
  -- Metadata operators
  folder = { field = "folder", type = "text", description = "Search in specific folder" },
  account = { field = "account", type = "text", description = "Search in specific account" },
  size = { field = "size", type = "size", description = "Search by email size" },
  larger = { field = "size", type = "size", op = ">", description = "Search emails larger than size" },
  smaller = { field = "size", type = "size", op = "<", description = "Search emails smaller than size" },
  
  -- Attachment operators
  attachment = { field = "has_attachment", type = "boolean", description = "Search emails with attachments" },
  filename = { field = "attachment_names", type = "text", description = "Search by attachment filename" },
  
  -- Advanced operators
  label = { field = "labels", type = "text", description = "Search by label/tag" },
  thread = { field = "thread_id", type = "text", description = "Search by conversation thread" }
}

-- Status values for 'is:' operator
M.status_values = {
  read = "read",
  unread = "unread", 
  important = "important",
  starred = "starred",
  draft = "draft",
  sent = "sent",
  trash = "trash"
}

-- Flag values for 'has:' operator  
M.flag_values = {
  attachment = "attachment",
  star = "star",
  important = "important",
  draft = "draft",
  answered = "answered",
  flagged = "flagged"
}

-- Cache for search results
local search_cache = {}
local cache_ttl = 300 -- 5 minutes

-- Parse search query into structured criteria
function M.parse_query(query)
  if not query or query == "" then
    return nil, "Empty search query"
  end
  
  local tokens = {}
  local current = ""
  local in_quotes = false
  local quote_char = nil
  
  -- Enhanced tokenizer with quote support
  for i = 1, #query do
    local char = query:sub(i, i)
    
    if not in_quotes and (char == '"' or char == "'") then
      in_quotes = true
      quote_char = char
    elseif in_quotes and char == quote_char then
      in_quotes = false
      quote_char = nil
    elseif char == ' ' and not in_quotes then
      if current ~= "" then
        table.insert(tokens, current)
        current = ""
      end
    else
      current = current .. char
    end
  end
  
  if current ~= "" then
    table.insert(tokens, current)
  end
  
  -- Parse tokens into search criteria
  local criteria = {
    operators = {},
    text = {},
    logic = "AND" -- Default to AND logic
  }
  
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    
    -- Handle OR logic
    if token:upper() == "OR" then
      criteria.logic = "OR"
      i = i + 1
    -- Handle NOT logic  
    elseif token:upper() == "NOT" or token:sub(1, 1) == "-" then
      if token == "NOT" and i < #tokens then
        i = i + 1
        token = tokens[i]
      else
        token = token:sub(2) -- Remove - prefix
      end
      
      local operator, value = M.parse_operator_token(token)
      if operator then
        table.insert(criteria.operators, {
          operator = operator,
          value = value,
          config = M.operators[operator],
          negate = true
        })
      else
        table.insert(criteria.text, {
          value = token,
          negate = true
        })
      end
      i = i + 1
    else
      local operator, value = M.parse_operator_token(token)
      if operator then
        table.insert(criteria.operators, {
          operator = operator,
          value = value,
          config = M.operators[operator],
          negate = false
        })
      else
        -- Plain text search
        table.insert(criteria.text, {
          value = M.clean_quotes(token),
          negate = false
        })
      end
      i = i + 1
    end
  end
  
  return criteria
end

-- Parse individual operator token (e.g., "from:john@example.com")
function M.parse_operator_token(token)
  local operator, value = token:match("^(%w+):(.+)$")
  
  if operator and M.operators[operator] then
    return operator, M.clean_quotes(value)
  end
  
  return nil, nil
end

-- Remove quotes from value
function M.clean_quotes(value)
  if not value then return value end
  return value:gsub('^["\']', ''):gsub('["\']$', '')
end

-- Execute search against email data
function M.search(query, options)
  options = options or {}
  
  -- Check cache first
  local cache_key = query .. vim.inspect(options)
  local cached = search_cache[cache_key]
  if cached and (os.time() - cached.timestamp) < cache_ttl then
    logger.debug("Returning cached search results", { query = query })
    return cached.results
  end
  
  local criteria, parse_error = M.parse_query(query)
  if not criteria then
    return nil, parse_error
  end
  
  logger.info("Executing search", { 
    query = query, 
    operators = #criteria.operators,
    text_terms = #criteria.text
  })
  
  -- Get emails to search
  local emails = M.get_searchable_emails(options)
  local results = {}
  
  -- Apply search criteria to each email
  for _, email in ipairs(emails) do
    if M.match_email(email, criteria) then
      -- Add relevance score
      email.search_score = M.calculate_relevance(email, criteria)
      table.insert(results, email)
    end
  end
  
  -- Sort results by relevance and date
  M.sort_results(results, options.sort or "relevance")
  
  -- Cache results
  search_cache[cache_key] = {
    results = results,
    timestamp = os.time()
  }
  
  logger.info("Search completed", {
    query = query,
    total_emails = #emails,
    results_count = #results
  })
  
  return results
end

-- Get emails to search from
function M.get_searchable_emails(options)
  local emails = {}
  
  if options.account and options.folder then
    -- Search specific account/folder
    local account_emails = utils.get_email_list(options.account, options.folder, 1, 1000)
    vim.list_extend(emails, account_emails)
  elseif options.account then
    -- Search all folders in account
    local folders = utils.get_folders(options.account)
    for _, folder in ipairs(folders or {}) do
      local folder_emails = utils.get_email_list(options.account, folder, 1, 1000)
      -- Add account/folder metadata
      for _, email in ipairs(folder_emails) do
        email.account = options.account
        email.folder = folder
      end
      vim.list_extend(emails, folder_emails)
    end
  else
    -- Search all accounts and folders
    local accounts = config.get_accounts()
    for account_name, account_config in pairs(accounts) do
      local folders = utils.get_folders(account_name)
      for _, folder in ipairs(folders or {}) do
        local folder_emails = utils.get_email_list(account_name, folder, 1, 1000)
        -- Add metadata
        for _, email in ipairs(folder_emails) do
          email.account = account_name
          email.folder = folder
        end
        vim.list_extend(emails, folder_emails)
      end
    end
  end
  
  return emails
end

-- Check if email matches search criteria
function M.match_email(email, criteria)
  -- Handle logic operator
  if criteria.logic == "OR" then
    return M.match_email_or(email, criteria)
  else
    return M.match_email_and(email, criteria)
  end
end

-- AND logic: all criteria must match
function M.match_email_and(email, criteria)
  -- Check operator criteria
  for _, op in ipairs(criteria.operators) do
    local match = M.match_operator(email, op)
    if op.negate then
      match = not match
    end
    if not match then
      return false
    end
  end
  
  -- Check text search terms
  for _, text_term in ipairs(criteria.text) do
    local match = M.match_text(email, text_term.value)
    if text_term.negate then
      match = not match
    end
    if not match then
      return false
    end
  end
  
  return true
end

-- OR logic: any criteria can match
function M.match_email_or(email, criteria)
  local has_match = false
  
  -- Check operator criteria
  for _, op in ipairs(criteria.operators) do
    local match = M.match_operator(email, op)
    if op.negate then
      match = not match
    end
    if match then
      has_match = true
      break
    end
  end
  
  -- Check text search terms
  if not has_match then
    for _, text_term in ipairs(criteria.text) do
      local match = M.match_text(email, text_term.value)
      if text_term.negate then
        match = not match
      end
      if match then
        has_match = true
        break
      end
    end
  end
  
  return has_match
end

-- Match specific operator against email
function M.match_operator(email, op)
  local config = op.config
  local email_value = email[config.field]
  local test_value = op.value
  
  if config.type == "text" then
    return M.match_text_field(email_value, test_value)
    
  elseif config.type == "date" then
    return M.match_date_field(email.date, test_value, config.op)
    
  elseif config.type == "relative_date" then
    return M.match_relative_date(email.date, test_value, config.op)
    
  elseif config.type == "flag" then
    return M.match_flag_field(email, test_value)
    
  elseif config.type == "status" then
    return M.match_status_field(email, test_value)
    
  elseif config.type == "size" then
    return M.match_size_field(email.size, test_value, config.op)
    
  elseif config.type == "boolean" then
    return M.match_boolean_field(email, config.field, test_value)
  end
  
  return false
end

-- Match text in any field
function M.match_text(email, text)
  local searchable_text = M.get_searchable_text(email):lower()
  return searchable_text:find(text:lower(), 1, true) ~= nil
end

-- Match text field (from, to, subject, etc.)
function M.match_text_field(field_value, test_value)
  if not field_value then
    return false
  end
  
  test_value = test_value:lower()
  
  if type(field_value) == "table" then
    -- Search in array fields (to, cc, etc)
    for _, val in ipairs(field_value) do
      if tostring(val):lower():find(test_value, 1, true) then
        return true
      end
    end
    return false
  else
    return tostring(field_value):lower():find(test_value, 1, true) ~= nil
  end
end

-- Match date field
function M.match_date_field(email_date, date_str, operator)
  local target_date = M.parse_date(date_str)
  if not target_date or not email_date then
    return false
  end
  
  if operator == "<" then
    return email_date < target_date
  elseif operator == ">" then
    return email_date > target_date
  else
    -- Exact date match (same day)
    local email_day = os.date("%Y-%m-%d", email_date)
    local target_day = os.date("%Y-%m-%d", target_date)
    return email_day == target_day
  end
end

-- Match relative date (newer_than:1d, older_than:1w)
function M.match_relative_date(email_date, relative_str, operator)
  local days_offset = M.parse_relative_date(relative_str)
  if not days_offset or not email_date then
    return false
  end
  
  local cutoff_date = os.time() - (days_offset * 24 * 60 * 60)
  
  if operator == ">" then
    return email_date > cutoff_date
  else
    return email_date < cutoff_date
  end
end

-- Match flag field (has:attachment, has:star)
function M.match_flag_field(email, flag_value)
  if flag_value == "attachment" then
    return email.attachments and #email.attachments > 0
  elseif flag_value == "star" or flag_value == "starred" then
    return email.starred == true
  elseif flag_value == "important" then
    return email.important == true
  elseif flag_value == "answered" then
    return email.flags and email.flags.answered
  elseif flag_value == "flagged" then
    return email.flags and email.flags.flagged
  elseif flag_value == "draft" then
    return email.flags and email.flags.draft
  end
  
  return false
end

-- Match status field (is:read, is:unread)
function M.match_status_field(email, status_value)
  if status_value == "read" then
    return email.read == true or (email.flags and email.flags.seen)
  elseif status_value == "unread" then
    return not email.read and not (email.flags and email.flags.seen)
  elseif status_value == "starred" then
    return email.starred == true
  elseif status_value == "important" then
    return email.important == true
  elseif status_value == "draft" then
    return email.flags and email.flags.draft
  elseif status_value == "sent" then
    return email.folder and email.folder:lower():match("sent")
  elseif status_value == "trash" then
    return email.folder and email.folder:lower():match("trash")
  end
  
  return false
end

-- Match size field
function M.match_size_field(email_size, size_str, operator)
  local target_size = M.parse_size(size_str)
  if not target_size or not email_size then
    return false
  end
  
  if operator == ">" then
    return email_size > target_size
  elseif operator == "<" then
    return email_size < target_size
  else
    return email_size == target_size
  end
end

-- Match boolean field
function M.match_boolean_field(email, field, value)
  if field == "has_attachment" then
    local has_attachment = (email.attachments and #email.attachments > 0) or email.has_attachment == true
    return has_attachment == value
  end
  
  return false
end

-- Get searchable text from email
function M.get_searchable_text(email)
  local parts = {}
  
  -- Add from field
  if email.from then
    if type(email.from) == "string" then
      table.insert(parts, email.from)
    elseif type(email.from) == "table" and email.from.email then
      table.insert(parts, email.from.email)
    end
  end
  
  -- Add to field
  if email.to then
    if type(email.to) == "string" then
      table.insert(parts, email.to)
    elseif type(email.to) == "table" then
      for _, recipient in ipairs(email.to) do
        if type(recipient) == "string" then
          table.insert(parts, recipient)
        elseif type(recipient) == "table" and recipient.email then
          table.insert(parts, recipient.email)
        end
      end
    end
  end
  
  -- Add cc field
  if email.cc then
    if type(email.cc) == "string" then
      table.insert(parts, email.cc)
    elseif type(email.cc) == "table" then
      for _, recipient in ipairs(email.cc) do
        if type(recipient) == "string" then
          table.insert(parts, recipient)
        elseif type(recipient) == "table" and recipient.email then
          table.insert(parts, recipient.email)
        end
      end
    end
  end
  
  -- Add subject
  if email.subject then
    table.insert(parts, tostring(email.subject))
  end
  
  -- Add body/preview
  if email.body then
    table.insert(parts, tostring(email.body))
  elseif email.preview then
    table.insert(parts, tostring(email.preview))
  end
  
  return table.concat(parts, " ")
end

-- Parse date string into timestamp
function M.parse_date(date_str)
  -- Support various formats
  if date_str == "today" then
    local today = os.date("*t")
    today.hour = 0
    today.min = 0
    today.sec = 0
    return os.time(today)
  elseif date_str == "yesterday" then
    local yesterday = os.date("*t", os.time() - 86400)
    yesterday.hour = 0
    yesterday.min = 0
    yesterday.sec = 0
    return os.time(yesterday)
  end
  
  -- Parse YYYY-MM-DD format
  local year, month, day = date_str:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if year and month and day then
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = 0,
      min = 0,
      sec = 0
    })
  end
  
  -- Parse MM/DD/YYYY format
  local month2, day2, year2 = date_str:match("^(%d+)/(%d+)/(%d%d%d%d)$")
  if month2 and day2 and year2 then
    return os.time({
      year = tonumber(year2),
      month = tonumber(month2),
      day = tonumber(day2),
      hour = 0,
      min = 0,
      sec = 0
    })
  end
  
  return nil
end

-- Parse relative date (1d, 2w, 3m)
function M.parse_relative_date(relative_str)
  local num, unit = relative_str:match("^(%d+)([dwmy])$")
  if not num or not unit then
    return nil
  end
  
  local multipliers = {
    d = 1,      -- days
    w = 7,      -- weeks
    m = 30,     -- months (approximate)
    y = 365     -- years (approximate)
  }
  
  return tonumber(num) * (multipliers[unit] or 1)
end

-- Parse size string (10MB, 5KB, etc.)
function M.parse_size(size_str)
  local num, unit = size_str:match("^(%d+)([KMGT]?B?)$")
  if not num then
    return nil
  end
  
  local multipliers = {
    [""] = 1,
    ["B"] = 1,
    ["K"] = 1024,
    ["KB"] = 1024,
    ["M"] = 1024 * 1024,
    ["MB"] = 1024 * 1024,
    ["G"] = 1024 * 1024 * 1024,
    ["GB"] = 1024 * 1024 * 1024,
    ["T"] = 1024 * 1024 * 1024 * 1024,
    ["TB"] = 1024 * 1024 * 1024 * 1024
  }
  
  return tonumber(num) * (multipliers[unit:upper()] or 1)
end

-- Calculate relevance score for search result
function M.calculate_relevance(email, criteria)
  local score = 0
  
  -- Base score
  score = score + 10
  
  -- Boost for text matches in subject
  for _, text_term in ipairs(criteria.text) do
    if email.subject and email.subject:lower():find(text_term.value:lower(), 1, true) then
      score = score + 50
    end
  end
  
  -- Boost for exact operator matches
  for _, op in ipairs(criteria.operators) do
    if op.operator == "from" or op.operator == "to" then
      score = score + 30
    end
  end
  
  -- Recency boost (newer emails score higher)
  if email.date then
    local days_old = (os.time() - email.date) / 86400
    score = score + math.max(0, 100 - days_old)
  end
  
  -- Important email boost
  if email.important or email.starred then
    score = score + 25
  end
  
  return score
end

-- Sort search results
function M.sort_results(results, sort_by)
  if sort_by == "date" then
    table.sort(results, function(a, b) 
      return (a.date or 0) > (b.date or 0) 
    end)
  elseif sort_by == "relevance" then
    table.sort(results, function(a, b)
      if (a.search_score or 0) == (b.search_score or 0) then
        return (a.date or 0) > (b.date or 0)
      end
      return (a.search_score or 0) > (b.search_score or 0)
    end)
  elseif sort_by == "sender" then
    table.sort(results, function(a, b) 
      return (a.from or "") < (b.from or "")
    end)
  elseif sort_by == "subject" then
    table.sort(results, function(a, b)
      return (a.subject or "") < (b.subject or "")
    end)
  end
end

-- Show interactive search UI
function M.show_search_ui()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'himalaya-search')
  
  local width = math.floor(vim.o.columns * 0.8)
  local height = 15
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = 5,
    style = 'minimal',
    border = 'rounded',
    title = ' Advanced Email Search ',
    title_pos = 'center'
  })
  
  local help_lines = {
    "╭─ Search Examples ────────────────────────────────────────╮",
    "│ from:john subject:meeting                                │",
    "│ has:attachment larger:10MB                               │", 
    "│ after:2024-01-01 before:2024-12-31                     │",
    "│ is:unread from:github.com                               │",
    "│ newer_than:7d older_than:30d                            │",
    "│ \"exact phrase\" OR alternative                           │",
    "│ important NOT from:spam                                 │",
    "╰──────────────────────────────────────────────────────────╯",
    "",
    "╭─ Available Operators ────────────────────────────────────╮",
    "│ Text: from: to: cc: subject: body: filename:            │",
    "│ Date: date: before: after: newer_than: older_than:      │",
    "│ Status: is: has: starred: attachment:                   │",
    "│ Size: size: larger: smaller:                            │",
    "╰──────────────────────────────────────────────────────────╯",
    "",
    "Enter your search query:"
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  
  -- Position cursor on input line
  vim.api.nvim_win_set_cursor(win, {#help_lines, 0})
  
  -- Set up search execution with proper vim.keymap.set syntax
  local keymap_opts = { buffer = buf, silent = true, noremap = true }

  vim.keymap.set('n', '<CR>', function()
    local query = vim.api.nvim_get_current_line()
    vim.api.nvim_win_close(win, true)
    M.execute_search(query)
  end, vim.tbl_extend('force', keymap_opts, { desc = "Execute search" }))

  vim.keymap.set('i', '<CR>', function()
    local query = vim.api.nvim_get_current_line()
    vim.api.nvim_win_close(win, true)
    M.execute_search(query)
  end, vim.tbl_extend('force', keymap_opts, { desc = "Execute search" }))

  vim.keymap.set('n', '<Esc>', ':close<CR>', vim.tbl_extend('force', keymap_opts, { desc = "Close search" }))
  
  -- Start in insert mode (unless in test mode)
  if not _G.HIMALAYA_TEST_MODE then
    vim.cmd('startinsert')
  end
end

-- Execute search and display results
function M.execute_search(query)
  if not query or query == "" then
    notify.himalaya("Empty search query", notify.categories.ERROR)
    return
  end
  
  notify.himalaya("🔍 Searching: " .. query, notify.categories.STATUS)
  
  local results, error_msg = M.search(query)
  
  if not results then
    notify.himalaya("❌ Search error: " .. (error_msg or "Unknown error"), notify.categories.ERROR)
    return
  end
  
  if #results == 0 then
    notify.himalaya("No results found for: " .. query, notify.categories.STATUS)
    return
  end
  
  notify.himalaya(string.format("✅ Found %d results", #results), notify.categories.USER_ACTION)
  
  -- Display results in email list UI
  M.show_search_results(results, query)
end

-- Show search results in a dedicated buffer
function M.show_search_results(results, query)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "Search Results: " .. query)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'himalaya-search-results')
  
  local lines = {
    string.format("🔍 Search Results: %s", query),
    string.format("Found %d emails", #results),
    string.rep("─", 80),
    ""
  }
  
  -- Format results
  for i, email in ipairs(results) do
    local date = email.date and os.date("%m/%d %H:%M", email.date) or "Unknown"
    local from = utils.truncate_string(email.from or "Unknown", 25)
    local subject = utils.truncate_string(email.subject or "No subject", 35)
    local account_folder = ""
    
    if email.account then
      account_folder = string.format("[%s:%s]", 
        email.account:sub(1, 8), 
        email.folder or "INBOX")
    end
    
    local score_str = email.search_score and string.format(" (%.0f)", email.search_score) or ""
    
    table.insert(lines, string.format(
      "%3d. %s %s %s %s%s",
      i,
      date,
      from,
      subject,
      account_folder,
      score_str
    ))
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press 'r' to refine search, 'n' for new search, 'q' to close")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Set up keymaps
  local opts = { buffer = buf, noremap = true, silent = true }
  
  vim.keymap.set('n', 'r', function()
    vim.ui.input({
      prompt = "Refine search: ",
      default = query
    }, function(new_query)
      if new_query then
        vim.cmd('bdelete')
        M.execute_search(new_query)
      end
    end)
  end, vim.tbl_extend('force', opts, { desc = "Refine search" }))
  
  vim.keymap.set('n', 'n', function()
    vim.cmd('bdelete')
    M.show_search_ui()
  end, vim.tbl_extend('force', opts, { desc = "New search" }))
  
  vim.keymap.set('n', 'q', ':bdelete<CR>', vim.tbl_extend('force', opts, { desc = "Close search results" }))
  vim.keymap.set('n', '<Esc>', ':bdelete<CR>', vim.tbl_extend('force', opts, { desc = "Close search results" }))
end

-- Clear search cache
function M.clear_cache()
  search_cache = {}
  logger.debug("Search cache cleared")
end

-- Get search suggestions based on email data
function M.get_suggestions(partial_query)
  -- This could be enhanced with auto-completion
  local suggestions = {}
  
  -- Common operators
  local common_ops = {
    "from:", "to:", "subject:", "has:attachment", "is:unread", 
    "before:", "after:", "larger:", "smaller:"
  }
  
  for _, op in ipairs(common_ops) do
    if op:find(partial_query, 1, true) then
      table.insert(suggestions, op)
    end
  end
  
  return suggestions
end

return M