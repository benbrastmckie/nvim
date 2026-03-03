--------------------------------------------------------------------------------
-- OpenCode Visual Selection Integration
--------------------------------------------------------------------------------
-- Mirrors Claude visual module behavior for OpenCode
-- Sends visual selection to OpenCode with user prompt via opencode.prompt() API

local M = {}

-- Configuration
M.config = {
  -- Default prompt when none provided
  default_prompt = "Please help me with this code:",

  -- Show progress notifications
  show_progress = true,

  -- Interactive prompt configuration
  prompt_placeholder = "Ask OpenCode about this code...",
  prompt_title = "OpenCode Prompt",
  allow_empty_prompt = false,
}

--- Helper function to get visual selection text
--- @return string selection The selected text
local function get_visual_selection()
  -- First try to get the current visual selection if we're in visual mode
  if vim.fn.mode():match("^[vV\22]") then
    -- We're in visual mode, get the current selection
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")

    -- Ensure start comes before end
    if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
      start_pos, end_pos = end_pos, start_pos
    end

    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    -- Get the lines and extract selection
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    if #lines == 0 then
      return ""
    end

    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_col, end_col)
    else
      lines[1] = string.sub(lines[1], start_col)
      if #lines > 1 then
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
    end

    local result = table.concat(lines, '\n')
    if result ~= "" and not result:match("^%s*$") then
      return result
    end
  end

  -- Fall back to previous visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  -- Check if we have valid marks (they exist and are different from default)
  if start_line == 0 or end_line == 0 or start_line > end_line then
    return ""
  end

  -- Additional check: ensure we're not getting stale marks
  if start_line == end_line and start_col == end_col then
    return ""
  end

  -- Get the lines
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  if #lines == 0 then
    return ""
  end

  -- Handle single line selection
  if #lines == 1 then
    if end_col < start_col then
      return ""
    end
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    if #lines > 1 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end

  local result = table.concat(lines, '\n')

  -- Trim empty result or whitespace-only result
  if result == "" or result:match("^%s*$") then
    return ""
  end

  return result
end

--- Format message with file context for OpenCode
--- @param text string The selected text
--- @param prompt string|nil User prompt
--- @return string formatted Formatted message
function M.format_message(text, prompt)
  local parts = {}

  -- Add user prompt if provided
  if prompt and prompt ~= "" then
    table.insert(parts, prompt)
    table.insert(parts, "")
  end

  -- Add file context
  local filename = vim.fn.expand("%:p")
  local filetype = vim.bo.filetype

  if filename ~= "" then
    -- Use relative path from git root if possible
    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
    if git_root ~= "" and vim.v.shell_error == 0 then
      local relative = vim.fn.fnamemodify(filename, ":s?" .. git_root .. "/??")
      filename = relative
    end

    table.insert(parts, "**File:** `" .. filename .. "`")
    table.insert(parts, "")
  end

  -- Add code block with syntax highlighting
  if filetype ~= "" then
    table.insert(parts, "```" .. filetype)
  else
    table.insert(parts, "```")
  end

  -- Add the actual code
  for line in text:gmatch("[^\n]+") do
    table.insert(parts, line)
  end

  table.insert(parts, "```")

  return table.concat(parts, "\n")
end

--- Send formatted message to OpenCode
--- @param text string The text to send
--- @param prompt string|nil Optional prompt
--- @return boolean success Whether the send was successful
function M.send_to_opencode(text, prompt)
  -- Check if opencode is available
  local ok, opencode = pcall(require, "opencode")
  if not ok then
    vim.notify("OpenCode not available", vim.log.levels.ERROR)
    return false
  end

  -- Build formatted message
  local message = M.format_message(text, prompt)

  -- Send via opencode.prompt() API
  opencode.prompt(message)

  if M.config.show_progress then
    vim.notify("Selection sent to OpenCode", vim.log.levels.INFO)
  end

  return true
end

--- Interactive function to send visual selection with user-provided prompt
--- This function is called by the <leader>ao keymap in visual mode
function M.send_visual_to_opencode_with_prompt()
  -- Validate we're in visual mode
  local mode = vim.fn.mode()
  if not mode:match("^[vV\22]") then
    vim.notify("This function only works in visual mode. Please select text first.", vim.log.levels.WARN)
    return
  end

  -- Get the visual selection first
  local selection = get_visual_selection()
  if selection == "" or selection:match("^%s*$") then
    vim.notify("No text selected. Please select some text and try again.", vim.log.levels.WARN)
    return
  end

  -- Show progress notification
  if M.config.show_progress then
    vim.notify(string.format("Selected %d characters. Opening prompt...", #selection), vim.log.levels.INFO)
  end

  -- Collect user prompt with vim.ui.input
  vim.ui.input({
    prompt = M.config.prompt_title .. ": ",
    default = "",
    completion = nil,
  }, function(user_prompt)
    -- Handle cancellation (nil input)
    if user_prompt == nil then
      if M.config.show_progress then
        vim.notify("OpenCode prompt cancelled.", vim.log.levels.INFO)
      end
      return
    end

    -- Handle empty prompt
    if user_prompt == "" or user_prompt:match("^%s*$") then
      if not M.config.allow_empty_prompt then
        vim.notify("Empty prompt not allowed. Please provide a question or request.", vim.log.levels.WARN)
        return
      else
        user_prompt = M.config.default_prompt
      end
    end

    -- Validate prompt length
    if #user_prompt > 1000 then
      vim.notify("Prompt too long (max 1000 characters). Please shorten your request.", vim.log.levels.WARN)
      return
    end

    -- Show progress
    if M.config.show_progress then
      vim.notify("Sending selection to OpenCode with your prompt...", vim.log.levels.INFO)
    end

    -- Send to OpenCode
    M.send_to_opencode(selection, user_prompt)
  end)
end

return M
