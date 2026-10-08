-- Himalaya Email Templates System
-- Manages email templates with variable substitution and presets
-- Supports dynamic variables, conditional content, and template inheritance

local M = {}

local state = require('neotex.plugins.tools.himalaya.core.state')
local notify = require('neotex.util.notifications')
local logger = require('neotex.plugins.tools.himalaya.core.logger')
local config = require('neotex.plugins.tools.himalaya.core.config')

-- Template structure schema
local template_schema = {
  id = "",
  name = "",
  description = "",
  category = "general", -- general, business, personal, auto-reply
  subject = "",
  body = "",
  variables = {}, -- {name, description, default, type}
  attachments = {}, -- Default attachments
  headers = {}, -- Custom headers
  created_at = 0,
  updated_at = 0,
  used_count = 0,
  tags = {} -- For categorization
}

-- Variable types for validation
M.variable_types = {
  text = { validate = function(v) return type(v) == "string" end },
  email = { validate = function(v) return type(v) == "string" and v:match("@") end },
  date = { validate = function(v) return type(v) == "string" and v:match("%d%d%d%d%-%d%d%-%d%d") end },
  number = { validate = function(v) return tonumber(v) ~= nil end },
  boolean = { validate = function(v) return v == "true" or v == "false" end },
  url = { validate = function(v) return type(v) == "string" and v:match("^https?://") end }
}

-- Built-in templates
M.builtin_templates = {
  meeting_request = {
    name = "Meeting Request",
    description = "Request a meeting with someone",
    category = "business",
    subject = "Meeting Request: {{meeting_topic}}",
    body = [[Hi {{recipient_name}},

I hope this email finds you well. I would like to schedule a meeting to discuss {{meeting_topic}}.

Here are a few time options that work for me:
- {{option_1}}
- {{option_2}}
- {{option_3}}

The meeting would take approximately {{duration}} and can be held {{location}}.

Please let me know which option works best for you, or suggest alternative times.

Best regards,
{{sender_name}}]],
    variables = {
      {name = "recipient_name", description = "Name of the person you're meeting", default = "", type = "text"},
      {name = "meeting_topic", description = "What the meeting is about", default = "", type = "text"},
      {name = "option_1", description = "First time option", default = "", type = "text"},
      {name = "option_2", description = "Second time option", default = "", type = "text"},
      {name = "option_3", description = "Third time option", default = "", type = "text"},
      {name = "duration", description = "How long the meeting will be", default = "30 minutes", type = "text"},
      {name = "location", description = "Where the meeting will be", default = "via video call", type = "text"},
      {name = "sender_name", description = "Your name", default = "", type = "text"}
    }
  },
  
  follow_up = {
    name = "Follow Up",
    description = "Follow up on previous communication",
    category = "business",
    subject = "Following up on {{original_subject}}",
    body = [[Hi {{recipient_name}},

I wanted to follow up on my previous email about {{original_subject}}.

{{#if has_deadline}}
I noticed that the deadline of {{deadline}} is approaching, and I wanted to check on the status.
{{/if}}

{{custom_message}}

Please let me know if you need any additional information or clarification.

{{#if urgent}}
This is time-sensitive, so I would appreciate a response at your earliest convenience.
{{/if}}

Thank you for your time.

Best regards,
{{sender_name}}]],
    variables = {
      {name = "recipient_name", description = "Name of recipient", default = "", type = "text"},
      {name = "original_subject", description = "Subject of original email", default = "", type = "text"},
      {name = "has_deadline", description = "Does this have a deadline?", default = "false", type = "boolean"},
      {name = "deadline", description = "Deadline date", default = "", type = "date"},
      {name = "custom_message", description = "Your follow-up message", default = "", type = "text"},
      {name = "urgent", description = "Is this urgent?", default = "false", type = "boolean"},
      {name = "sender_name", description = "Your name", default = "", type = "text"}
    }
  },
  
  thank_you = {
    name = "Thank You",
    description = "Express gratitude",
    category = "personal",
    subject = "Thank you for {{reason}}",
    body = [[Dear {{recipient_name}},

I wanted to take a moment to thank you for {{reason}}. {{custom_message}}

{{#if specific_impact}}
This has particularly helped me with {{specific_impact}}.
{{/if}}

I truly appreciate your {{quality}} and look forward to {{future_interaction}}.

With gratitude,
{{sender_name}}]],
    variables = {
      {name = "recipient_name", description = "Name of person to thank", default = "", type = "text"},
      {name = "reason", description = "What you're thanking them for", default = "", type = "text"},
      {name = "custom_message", description = "Personal message", default = "", type = "text"},
      {name = "specific_impact", description = "How it helped you", default = "", type = "text"},
      {name = "quality", description = "Their quality you appreciate", default = "help", type = "text"},
      {name = "future_interaction", description = "Future interaction", default = "working together again", type = "text"},
      {name = "sender_name", description = "Your name", default = "", type = "text"}
    }
  },
  
  out_of_office = {
    name = "Out of Office",
    description = "Automatic out of office reply",
    category = "auto-reply",
    subject = "Re: {{original_subject}} - Out of Office",
    body = [[Thank you for your email. I am currently out of the office from {{start_date}} until {{end_date}} and will have limited access to email.

{{#if urgent_contact}}
For urgent matters, please contact {{urgent_contact}} at {{urgent_email}}.
{{/if}}

{{#if delayed_response}}
I will respond to your email when I return on {{return_date}}.
{{else}}
I will respond to your email as soon as possible upon my return.
{{/if}}

{{custom_message}}

Best regards,
{{sender_name}}]],
    variables = {
      {name = "start_date", description = "First day out", default = "", type = "date"},
      {name = "end_date", description = "Last day out", default = "", type = "date"},
      {name = "return_date", description = "Return date", default = "", type = "date"},
      {name = "urgent_contact", description = "Name of emergency contact", default = "", type = "text"},
      {name = "urgent_email", description = "Emergency contact email", default = "", type = "email"},
      {name = "delayed_response", description = "Will response be delayed?", default = "true", type = "boolean"},
      {name = "custom_message", description = "Additional message", default = "", type = "text"},
      {name = "sender_name", description = "Your name", default = "", type = "text"},
      {name = "original_subject", description = "Original email subject", default = "{{ORIGINAL_SUBJECT}}", type = "text"}
    }
  }
}

-- Get all templates (user + builtin)
function M.get_templates()
  local user_templates = state.get('email_templates', {})
  local all_templates = vim.deepcopy(user_templates)
  
  -- Add built-in templates if not overridden
  for id, template in pairs(M.builtin_templates) do
    if not all_templates[id] then
      local builtin = vim.deepcopy(template)
      builtin.id = id
      builtin.builtin = true
      builtin.created_at = 0
      builtin.updated_at = 0
      builtin.used_count = 0
      all_templates[id] = builtin
    end
  end
  
  return all_templates
end

-- Get template by ID
function M.get_template(id)
  local templates = M.get_templates()
  return templates[id]
end

-- Create new template
function M.create_template(template_data)
  local user_templates = state.get('email_templates', {})
  
  -- Generate ID from name
  local id = template_data.name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
  
  -- Check for duplicate
  local counter = 1
  local original_id = id
  while user_templates[id] or M.builtin_templates[id] do
    counter = counter + 1
    id = original_id .. "_" .. counter
  end
  
  -- Create template
  local template = vim.tbl_extend('force', {
    id = id,
    created_at = os.time(),
    updated_at = os.time(),
    used_count = 0,
    variables = {},
    attachments = {},
    headers = {},
    tags = {},
    category = "general"
  }, template_data)
  
  -- Extract variables from template text
  template.variables = M.extract_variables(template.subject, template.body)
  
  user_templates[id] = template
  state.set('email_templates', user_templates)
  
  notify.himalaya(
    "✅ Template created: " .. template.name,
    notify.categories.USER_ACTION
  )
  
  logger.info("Email template created", {
    id = id,
    name = template.name,
    variables = #template.variables
  })
  
  return template
end

-- Update existing template
function M.update_template(id, updates)
  local user_templates = state.get('email_templates', {})
  local template = user_templates[id]
  
  if not template then
    return nil, "Template not found"
  end
  
  if template.builtin then
    return nil, "Cannot modify built-in template"
  end
  
  -- Update template
  template = vim.tbl_extend('force', template, updates)
  template.updated_at = os.time()
  
  -- Re-extract variables if content changed
  if updates.subject or updates.body then
    template.variables = M.extract_variables(template.subject, template.body)
  end
  
  user_templates[id] = template
  state.set('email_templates', user_templates)
  
  notify.himalaya(
    "✅ Template updated: " .. template.name,
    notify.categories.USER_ACTION
  )
  
  return template
end

-- Delete template
function M.delete_template(id)
  local user_templates = state.get('email_templates', {})
  local template = user_templates[id]
  
  if not template then
    return false, "Template not found"
  end
  
  if template.builtin then
    return false, "Cannot delete built-in template"
  end
  
  user_templates[id] = nil
  state.set('email_templates', user_templates)
  
  notify.himalaya(
    "🗑️ Template deleted: " .. template.name,
    notify.categories.USER_ACTION
  )
  
  return true
end

-- Extract template variables from text
function M.extract_variables(subject, body)
  local variables = {}
  local seen = {}
  local text = (subject or "") .. " " .. (body or "")
  
  -- Find {{variable}} patterns
  for var in text:gmatch("{{%s*([%w_]+)%s*}}") do
    if not seen[var] and not var:match("^[A-Z_]+$") then -- Skip constants like {{ORIGINAL_SUBJECT}}
      seen[var] = true
      table.insert(variables, {
        name = var,
        description = M.generate_variable_description(var),
        default = "",
        type = M.guess_variable_type(var)
      })
    end
  end
  
  -- Find conditional blocks {{#if variable}}
  for var in text:gmatch("{{#if%s+([%w_]+)%s*}}") do
    if not seen[var] then
      seen[var] = true
      table.insert(variables, {
        name = var,
        description = M.generate_variable_description(var),
        default = "false",
        type = "boolean"
      })
    end
  end
  
  return variables
end

-- Generate description for variable based on name
function M.generate_variable_description(var_name)
  local descriptions = {
    recipient_name = "Name of the email recipient",
    sender_name = "Your name",
    subject = "Email subject",
    date = "Date (YYYY-MM-DD format)",
    time = "Time",
    company = "Company name",
    project = "Project name",
    deadline = "Deadline date",
    amount = "Amount or number",
    url = "Website URL",
    phone = "Phone number",
    address = "Address",
    email = "Email address"
  }
  
  -- Check for exact matches
  if descriptions[var_name] then
    return descriptions[var_name]
  end
  
  -- Check for partial matches
  for pattern, desc in pairs(descriptions) do
    if var_name:find(pattern) then
      return desc
    end
  end
  
  -- Generate from variable name
  return var_name:gsub("_", " "):gsub("^%l", string.upper)
end

-- Guess variable type based on name
function M.guess_variable_type(var_name)
  local var_lower = var_name:lower()
  
  -- Check for exact matches or specific patterns first
  if var_lower:match("_email$") or var_lower:match("^email") or var_lower == "email" then
    return "email"
  elseif var_lower:match("_date$") or var_lower:match("^date") or var_lower == "deadline" then
    return "date"
  elseif var_lower:match("_url$") or var_lower:match("^url") or var_lower == "link" or var_lower == "website" then
    return "url"
  elseif var_lower:match("^has_") or var_lower:match("^is_") or var_lower:match("^should_") or var_lower:match("^can_") or var_lower == "urgent" then
    return "boolean"
  elseif var_lower == "amount" or var_lower == "count" or var_lower:match("_number$") or var_lower == "quantity" then
    return "number"
  end
  
  return "text"
end

-- Apply template with variable substitution
function M.apply_template(template_id, variables, context)
  local template = M.get_template(template_id)
  if not template then
    return nil, "Template not found"
  end
  
  -- Update usage count (only for user templates)
  if not template.builtin then
    template.used_count = template.used_count + 1
    local user_templates = state.get('email_templates', {})
    user_templates[template_id] = template
    state.set('email_templates', user_templates)
  end
  
  context = context or {}
  
  -- Start with template content
  local result = {
    subject = template.subject,
    body = template.body,
    headers = vim.deepcopy(template.headers or {}),
    attachments = vim.deepcopy(template.attachments or {})
  }
  
  -- Add system variables
  local system_vars = M.get_system_variables(context)
  variables = vim.tbl_extend('force', system_vars, variables or {})
  
  -- Validate variables
  for _, var_def in ipairs(template.variables) do
    local value = variables[var_def.name]
    if value and var_def.type and M.variable_types[var_def.type] then
      if not M.variable_types[var_def.type].validate(value) then
        return nil, string.format("Invalid value for %s: expected %s", var_def.name, var_def.type)
      end
    end
  end
  
  -- Process conditional blocks first
  result.subject = M.process_conditionals(result.subject, variables)
  result.body = M.process_conditionals(result.body, variables)
  
  -- Replace variables
  for var_name, var_value in pairs(variables) do
    if var_value ~= nil then
      local pattern = "{{%s*" .. var_name .. "%s*}}"
      result.subject = result.subject:gsub(pattern, tostring(var_value))
      result.body = result.body:gsub(pattern, tostring(var_value))
    end
  end
  
  -- Apply defaults for missing variables
  for _, var_def in ipairs(template.variables) do
    if not variables[var_def.name] and var_def.default ~= "" then
      local pattern = "{{%s*" .. var_def.name .. "%s*}}"
      result.subject = result.subject:gsub(pattern, var_def.default)
      result.body = result.body:gsub(pattern, var_def.default)
    end
  end
  
  logger.info("Template applied", {
    template_id = template_id,
    template_name = template.name,
    variables_used = vim.tbl_count(variables)
  })
  
  return result
end

-- Process conditional blocks {{#if variable}}...{{/if}}
function M.process_conditionals(text, variables)
  -- Process {{#if variable}} blocks
  text = text:gsub("{{#if%s+([%w_]+)%s*}}(.-){{/if}}", function(var_name, content)
    local value = variables[var_name]
    if value and value ~= "false" and value ~= "" then
      return content
    else
      return ""
    end
  end)
  
  return text
end

-- Get system variables
function M.get_system_variables(context)
  local account_name = state.get_current_account()
  local account_config = nil
  
  -- Safely get account config
  if account_name and config.get_account then
    local ok, result = pcall(config.get_account, account_name)
    if ok then
      account_config = result
    end
  end
  
  return {
    current_date = os.date("%Y-%m-%d"),
    current_time = os.date("%H:%M"),
    current_datetime = os.date("%Y-%m-%d %H:%M"),
    day_of_week = os.date("%A"),
    month = os.date("%B"),
    year = os.date("%Y"),
    sender_name = account_config and account_config.display_name or account_name or "Test User",
    sender_email = account_config and account_config.email or "",
    original_subject = context.original_subject or ""
  }
end

-- Show template picker UI
function M.pick_template(callback)
  local templates = M.get_templates()
  local items = {}
  
  -- Group by category
  local by_category = {}
  for id, template in pairs(templates) do
    local category = template.category or "general"
    by_category[category] = by_category[category] or {}
    table.insert(by_category[category], {
      id = id,
      template = template
    })
  end
  
  -- Sort categories and templates
  local categories = vim.tbl_keys(by_category)
  table.sort(categories)
  
  for _, category in ipairs(categories) do
    table.sort(by_category[category], function(a, b)
      return a.template.used_count > b.template.used_count
    end)
    
    for _, item in ipairs(by_category[category]) do
      local template = item.template
      local label = string.format("[%s] %s - %s", 
        category:upper(), 
        template.name, 
        template.description or "No description")
      
      if template.builtin then
        label = label .. " (built-in)"
      end
      
      table.insert(items, {
        id = item.id,
        label = label,
        template = template
      })
    end
  end
  
  if #items == 0 then
    notify.himalaya("No templates available", notify.categories.STATUS)
    return
  end
  
  local labels = vim.tbl_map(function(item) return item.label end, items)
  
  vim.ui.select(labels, {
    prompt = "Select template:",
    format_item = function(item) return item end
  }, function(choice, idx)
    if choice and callback then
      local selected = items[idx]
      
      -- Get variables if needed
      if #selected.template.variables > 0 then
        M.get_template_variables(selected.template, function(variables)
          if variables then
            callback(selected.id, variables)
          end
        end)
      else
        callback(selected.id, {})
      end
    end
  end)
end

-- Get template variables from user
function M.get_template_variables(template, callback)
  local variables = {}
  local var_index = 1
  
  local function get_next_variable()
    if var_index > #template.variables then
      callback(variables)
      return
    end
    
    local var = template.variables[var_index]
    local prompt = string.format("%s (%s): ", var.name, var.description)
    
    vim.ui.input({
      prompt = prompt,
      default = var.default
    }, function(value)
      if value ~= nil then
        variables[var.name] = value
        var_index = var_index + 1
        get_next_variable()
      else
        callback(nil) -- Cancelled
      end
    end)
  end
  
  get_next_variable()
end

-- Template editor UI
function M.edit_template(template_id)
  local template = template_id and M.get_template(template_id) or {
    name = "",
    description = "",
    category = "general",
    subject = "",
    body = "",
    headers = {}
  }
  
  if template and template.builtin then
    notify.himalaya("Cannot edit built-in template. Create a copy instead.", notify.categories.ERROR)
    return
  end
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "Email Template Editor")
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  -- Template content
  local lines = {
    "# Email Template",
    "",
    "Name: " .. template.name,
    "Description: " .. (template.description or ""),
    "Category: " .. (template.category or "general"),
    "",
    "## Subject",
    template.subject,
    "",
    "## Body",
  }
  
  -- Add body lines
  for line in (template.body or ""):gmatch("[^\n]*") do
    table.insert(lines, line)
  end
  
  -- Add variables section
  table.insert(lines, "")
  table.insert(lines, "## Variables")
  table.insert(lines, "# Use {{variable_name}} in subject or body")
  table.insert(lines, "# Conditional blocks: {{#if variable}}...{{/if}}")
  table.insert(lines, "# Available types: text, email, date, number, boolean, url")
  
  if template.variables and #template.variables > 0 then
    table.insert(lines, "")
    for _, var in ipairs(template.variables) do
      table.insert(lines, string.format("# %s (%s): %s", 
        var.name, var.type or "text", var.description))
    end
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Save template on write
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.save_template_from_buffer(buf, template_id)
    end
  })
end

-- Save template from buffer content
function M.save_template_from_buffer(buf, template_id)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  -- Parse buffer content
  local template = {
    name = "",
    description = "",
    category = "general",
    subject = "",
    body = "",
    headers = {}
  }
  
  local section = nil
  local body_lines = {}
  
  for _, line in ipairs(lines) do
    if line:match("^Name: ") then
      template.name = line:match("^Name: (.+)$")
    elseif line:match("^Description: ") then
      template.description = line:match("^Description: (.*)$")
    elseif line:match("^Category: ") then
      template.category = line:match("^Category: (.+)$")
    elseif line == "## Subject" then
      section = "subject"
    elseif line == "## Body" then
      section = "body"
    elseif line == "## Variables" then
      section = "variables"
    elseif section == "subject" and not line:match("^#") and line ~= "" then
      template.subject = line
    elseif section == "body" and not line:match("^#") then
      table.insert(body_lines, line)
    end
  end
  
  template.body = table.concat(body_lines, "\n")
  
  -- Validate template
  if template.name == "" then
    notify.himalaya("Template name is required", notify.categories.ERROR)
    return
  end
  
  -- Save template
  if template_id then
    local updated, err = M.update_template(template_id, template)
    if not updated then
      notify.himalaya("Failed to update template: " .. err, notify.categories.ERROR)
      return
    end
  else
    M.create_template(template)
  end
  
  -- Mark buffer as saved
  vim.api.nvim_buf_set_option(buf, 'modified', false)
end

-- Show template management UI
function M.show_templates()
  local templates = M.get_templates()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "Email Templates")
  vim.api.nvim_buf_set_option(buf, 'filetype', 'himalaya-templates')
  
  local lines = {"📧 Email Templates", ""}
  
  -- Group by category
  local by_category = {}
  for id, template in pairs(templates) do
    local category = template.category or "general"
    by_category[category] = by_category[category] or {}
    table.insert(by_category[category], {id = id, template = template})
  end
  
  -- Display by category
  local categories = vim.tbl_keys(by_category)
  table.sort(categories)
  
  for _, category in ipairs(categories) do
    table.insert(lines, string.format("## %s", category:upper()))
    table.insert(lines, "")
    
    -- Sort templates by usage
    table.sort(by_category[category], function(a, b)
      return a.template.used_count > b.template.used_count
    end)
    
    for _, item in ipairs(by_category[category]) do
      local template = item.template
      local builtin_marker = template.builtin and " (built-in)" or ""
      local usage = template.used_count > 0 and string.format(" [used %dx]", template.used_count) or ""
      
      table.insert(lines, string.format("• %s - %s%s%s", 
        template.name,
        template.description or "No description",
        builtin_marker,
        usage
      ))
    end
    
    table.insert(lines, "")
  end
  
  table.insert(lines, "Commands:")
  table.insert(lines, "  'n' - New template")
  table.insert(lines, "  'e' - Edit template")
  table.insert(lines, "  'd' - Delete template")
  table.insert(lines, "  'p' - Preview template")
  table.insert(lines, "  'q' - Close")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Set up keymaps
  local opts = { buffer = buf, noremap = true, silent = true }
  
  vim.keymap.set('n', 'n', function()
    M.edit_template(nil)
  end, vim.tbl_extend('force', opts, { desc = "New template" }))
  
  vim.keymap.set('n', 'e', function()
    M.pick_template(function(template_id)
      M.edit_template(template_id)
    end)
  end, vim.tbl_extend('force', opts, { desc = "Edit template" }))
  
  vim.keymap.set('n', 'd', function()
    M.pick_template(function(template_id)
      local template = M.get_template(template_id)
      if template then
        vim.ui.select({"No", "Yes"}, {
          prompt = string.format("Delete template '%s'?", template.name)
        }, function(choice)
          if choice == "Yes" then
            M.delete_template(template_id)
            vim.cmd('bdelete')
            M.show_templates()
          end
        end)
      end
    end)
  end, vim.tbl_extend('force', opts, { desc = "Delete template" }))
  
  vim.keymap.set('n', 'p', function()
    M.pick_template(function(template_id, variables)
      local result = M.apply_template(template_id, variables)
      if result then
        local preview = string.format("Subject: %s\n\n%s", result.subject, result.body)
        local float = require('neotex.plugins.tools.himalaya.ui.float')
        float.show('Template Preview', vim.split(preview, '\n'))
      end
    end)
  end, vim.tbl_extend('force', opts, { desc = "Preview template" }))
  
  vim.keymap.set('n', 'q', ':bdelete<CR>', vim.tbl_extend('force', opts, { desc = "Close templates list" }))
  vim.keymap.set('n', '<Esc>', ':bdelete<CR>', vim.tbl_extend('force', opts, { desc = "Close templates list" }))
end

return M