-----------------------------------------------------------
-- URL Detection and Handling Utilities
-- 
-- This module provides functions for working with URLs:
-- - URL detection and extraction (extract_urls_from_line)
-- - Opening URLs (open_url_at_position, open_url_under_cursor)
-- - Mouse integration (open_url_at_mouse)
-- - Keybinding setup (setup_url_mappings)
--
-- The module supports various URL formats including:
-- - Plain URLs (https://example.com)
-- - Markdown links ([text](url))
-- - HTML links (<a href="url">text</a>)
-- - Email addresses (user@example.com)
-- - Local file paths (/path/to/file.txt)
-----------------------------------------------------------

local notify = require('neotex.util.notifications')

local M = {}

-- Function to extract URLs from a line of text (supports more URL patterns)
function M.extract_urls_from_line(line)
  -- Handle nil or empty input
  if not line or line == "" then
    return {}
  end

  local urls = {}
  local url_patterns = {
    -- Markdown link format [text](url)
    "%[.-%]%((.-)%)",
    -- HTML link format <a href="url">
    "<a%s+[^>]*href=[\"']([^\"']+)[\"'][^>]*>",
    -- Plain URLs with various protocols
    "https?://[%w%.%-%+%_%:%&%=%?%/%(%)%#%$%@%!%~%*]+",
    "www%.[%w%.%-%+%_%:%&%=%?%/%(%)%#%$%@%!%~%*]+",
    "file://[%w%.%-%+%_%:%&%=%?%/%(%)%#%$%@%!%~%*]+",
    -- Email addresses
    "[%w%.%-%+_]+@[%w%.%-%+_]+%.[%w%.%-%+_]+",
    -- Local file paths (Unix style)
    "/[%w%.%-%+%_%/]+%.[%w%.%-%+_]+",
  }

  for _, pattern in ipairs(url_patterns) do
    for url_match in string.gmatch(line, pattern) do
      -- Process the URL based on the pattern
      local url = url_match

      -- Store the URL and its position
      local start_idx = string.find(line, url_match, 1, true)
      if start_idx then
        -- For markdown links, the pattern captures just the URL part
        if pattern == "%[.-%]%((.-)%)" then
          -- Safely escape the URL for pattern matching
          local escaped_url = url:gsub("([%%%-%+%_%:%&%=%?%/%(%)%#%$%@%!%~%*])", "%%%1")
          -- Find the actual text of the full markdown link for position calculation
          local full_link_start = line:find("%[.-%]%(" .. escaped_url .. "%)", 1)

          -- Only proceed if we found a valid start position
          if full_link_start then
            local full_link_end = full_link_start
            -- Find the closing parenthesis
            local depth = 0
            for i = full_link_start, #line do
              local char = line:sub(i, i)
              if char == "(" then
                depth = depth + 1
              elseif char == ")" then
                depth = depth - 1
                if depth == 0 then
                  full_link_end = i
                  break
                end
              end
            end

            -- Only proceed if we have valid positions
            local url_start = line:find("%(", full_link_start, true)
            if url_start and full_link_end and full_link_start then
              url_start = url_start + 1 -- Move past the opening parenthesis
              table.insert(urls, {
                url = url,
                start = full_link_start,
                finish = full_link_end,
                url_start = url_start,
                url_end = url_start + #url - 1
              })
            end
          end
          -- For HTML links, capture the href value
        elseif pattern == "<a%s+[^>]*href=[\"']([^\"']+)[\"'][^>]*>" then
          -- Find the full tag containing this href
          local tag_start = line:find(
            "<a%s+[^>]*href=[\"']" .. url_match:gsub("([%%%-%+%_%:%&%=%?%/%(%)%#%$%@%!%~%*])", "%%%1") .. "[\"'][^>]*>",
            1)
          if tag_start then
            -- Find the closing > of this tag
            local tag_end = line:find(">", tag_start)
            if tag_end then
              table.insert(urls, {
                url = url,
                start = tag_start,
                finish = tag_end,
                url_start = line:find(url, tag_start, true),
                url_end = line:find(url, tag_start, true) + #url - 1
              })
            end
          end
        else
          -- For regular URLs, store their positions directly
          table.insert(urls, {
            url = url,
            start = start_idx,
            finish = start_idx + #url - 1
          })
        end
      end
    end
  end

  return urls
end

-- Function to open URL at a specific position or under cursor
function M.open_url_at_position(line_num, col)
  -- Validate parameters
  if not line_num or line_num < 1 then
    notify.editor("Invalid line number", notify.categories.ERROR)
    return false
  end

  -- Get the content of the specified line
  local ok, line = pcall(vim.api.nvim_buf_get_lines, 0, line_num - 1, line_num, false)

  -- Handle errors or empty result
  if not ok or not line or #line == 0 then
    notify.editor("Could not read line " .. line_num, notify.categories.ERROR)
    return false
  end

  line = line[1]
  if not line or line == "" then return false end

  -- Extract all URLs from the line
  local urls = M.extract_urls_from_line(line)
  if #urls == 0 then return false end

  -- Find the URL at or closest to the position
  local selected_url = nil
  local min_distance = math.huge

  -- Only process URLs if we have valid column position
  if col and #urls > 0 then
    for _, url_info in ipairs(urls) do
      -- Ensure we have valid position information
      if url_info.start and url_info.finish then
        if col >= url_info.start and col <= url_info.finish then
          -- Position is directly on this URL
          selected_url = url_info.url
          break
        else
          -- Calculate distance to this URL
          local distance = math.min(math.abs(col - url_info.start), math.abs(col - url_info.finish))
          if distance < min_distance then
            min_distance = distance
            selected_url = url_info.url
          end
        end
      end
    end
  end

  if selected_url then
    -- Determine URL type and ensure proper protocol prefix

    -- Handle email addresses
    if selected_url:match("^[%w%.%-%+_]+@[%w%.%-%+_]+%.[%w%.%-%+_]+$") then
      selected_url = "mailto:" .. selected_url

      -- Handle local file paths
    elseif selected_url:match("^/[%w%.%-%+%_%/]+%.[%w%.%-%+_]+$") then
      selected_url = "file://" .. selected_url

      -- Make sure web URLs have protocol prefix
    elseif not selected_url:match("^https?://") and
        not selected_url:match("^file://") and
        not selected_url:match("^mailto:") then
      -- Handle www URLs
      if selected_url:match("^www%.") then
        selected_url = "https://" .. selected_url

        -- Only add https if it looks like a domain (contains a dot)
      elseif selected_url:match("%.") then
        selected_url = "https://" .. selected_url
      end
    end

    -- Detect the platform and use appropriate browser command
    local cmd
    if vim.fn.has("mac") == 1 then
      cmd = string.format("silent !open '%s' &", selected_url:gsub("'", "\\'"))
    elseif vim.fn.has("unix") == 1 then
      cmd = string.format("silent !xdg-open '%s' &", selected_url:gsub("'", "\\'"))
    elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
      cmd = string.format("silent !start \"\" \"%s\"", selected_url:gsub('"', '\\"'))
    else
      notify.editor("Platform not supported for opening URLs", notify.categories.ERROR)
      return false
    end

    -- Execute the command with error handling
    local ok, err = pcall(function()
      vim.cmd(cmd)
    end)

    if ok then
      notify.editor("Opening URL: " .. selected_url, notify.categories.USER_ACTION)
      return true
    else
      notify.editor("Error opening URL: " .. err, notify.categories.ERROR)
      return false
    end
  end

  return false
end

-- Function to open URL at mouse position
function M.open_url_at_mouse()
  local mouse_pos = vim.fn.getmousepos()
  if not mouse_pos or not mouse_pos.line or not mouse_pos.column then
    notify.editor("Invalid mouse position", notify.categories.WARNING)
    return false
  end

  local line_num = mouse_pos.line
  local col = mouse_pos.column - 1 -- Convert to 0-indexed

  if M.open_url_at_position(line_num, col) then
    return true
  else
    notify.editor("No URL found at mouse position", notify.categories.STATUS)
    return false
  end
end

-- Function to open URL under cursor
function M.open_url_under_cursor()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor_pos[1]
  local col = cursor_pos[2]

  if M.open_url_at_position(line_num, col) then
    return true
  else
    notify.editor("No URL found under cursor", notify.categories.STATUS)
    return false
  end
end

-- Function to setup global URL mappings for all buffers
function M.setup_url_mappings()
  -- Basic options for all mappings
  local opts = { noremap = true, silent = true }

  -- Track if we've already set up the mappings to avoid duplicates
  if M._url_mappings_setup then
    return
  end

  -- Add keybinding to open the URL under cursor with gx for familiar Vim behavior
  vim.keymap.set("n", "gx", function()
    M.open_url_under_cursor()
  end, vim.tbl_extend("force", opts, { desc = "Open URL under cursor" }))

  -- Enable Ctrl+Click to open URLs with error handling
  vim.keymap.set("n", "<C-LeftMouse>", function()
    -- We don't perform standard Ctrl+LeftMouse because we want to keep cursor position
    vim.schedule(function()
      local ok, err = pcall(M.open_url_at_mouse)
      if not ok then
        notify.editor("Error handling mouse click: " .. err, notify.categories.ERROR)
      end
    end)
  end, vim.tbl_extend("force", opts, { desc = "Open URL with Ctrl+Click" }))

  -- Handle mouse release to avoid issues
  vim.keymap.set("n", "<C-LeftRelease>", "<Nop>", vim.tbl_extend("force", opts, { desc = "No-op mouse release (pairs with Ctrl+Click URL open)" }))

  -- Mark mappings as set up
  M._url_mappings_setup = true
end

-- Set up global URL-related utilities
function M.setup()
  -- Setup global function aliases for backward compatibility
  _G.OpenUrlAtMouse = function()
    return M.open_url_at_mouse()
  end
  
  _G.OpenUrlUnderCursor = function()
    return M.open_url_under_cursor()
  end
  
  -- Set up URL mappings
  M.setup_url_mappings()
  
  return true
end

return M