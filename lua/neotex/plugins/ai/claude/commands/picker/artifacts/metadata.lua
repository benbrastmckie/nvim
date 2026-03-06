-- neotex.plugins.ai.claude.commands.picker.artifacts.metadata
-- Metadata extraction from various artifact file types

local M = {}

--- Parse description from YAML template file
--- @param filepath string Path to YAML file
--- @return string Description (empty if not found)
function M.parse_template_description(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return ""
  end

  local success, lines = pcall(vim.fn.readfile, filepath, "", 50) -- Read first 50 lines
  if not success or not lines then
    return ""
  end

  -- Look for description: field in YAML
  for _, line in ipairs(lines) do
    local desc = line:match("^description:%s*(.+)$")
    if desc then
      -- Strip surrounding quotes (double or single)
      desc = desc:gsub('^"(.-)"$', '%1')
      desc = desc:gsub("^'(.-)'$", '%1')
      return desc:sub(1, 40) -- Limit to 40 chars
    end
  end

  return ""
end

--- Parse description from shell script header comments
--- @param filepath string Path to .sh file
--- @return string Description (empty if not found)
function M.parse_script_description(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return ""
  end

  local success, lines = pcall(vim.fn.readfile, filepath, "", 20) -- Read first 20 lines
  if not success or not lines then
    return ""
  end

  -- Look for "# Purpose:" or "# Description:" or first non-shebang comment
  local first_comment = nil
  for _, line in ipairs(lines) do
    if line:match("^#%s*Purpose:%s*(.+)$") then
      local desc = line:match("^#%s*Purpose:%s*(.+)$")
      return desc:sub(1, 40)
    elseif line:match("^#%s*Description:%s*(.+)$") then
      local desc = line:match("^#%s*Description:%s*(.+)$")
      return desc:sub(1, 40)
    elseif line:match("^#[^!]") and not first_comment then
      -- First comment that's not shebang
      first_comment = line:match("^#%s*(.+)$")
    end
  end

  return first_comment and first_comment:sub(1, 40) or ""
end

--- Parse description from markdown document
--- @param filepath string Path to .md file
--- @return string Description (empty if not found)
function M.parse_doc_description(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return ""
  end

  local success, lines = pcall(vim.fn.readfile, filepath, "", 30) -- Read first 30 lines
  if not success or not lines then
    return ""
  end

  local in_frontmatter = false
  local after_title = false

  for _, line in ipairs(lines) do
    -- Check for YAML frontmatter
    if line == "---" then
      if not in_frontmatter then
        in_frontmatter = true
      else
        in_frontmatter = false
      end
    elseif in_frontmatter then
      local desc = line:match("^description:%s*(.+)$")
      if desc then
        return desc:sub(1, 40)
      end
    elseif line:match("^#%s+[^#]") then
      -- Found a title heading (# Title, not ## Subheading)
      after_title = true
    elseif line:match("^##") then
      -- Found subheading - stop looking for description
      after_title = false
    elseif after_title and line ~= "" and not line:match("^#") then
      -- Plain text after title, before any subheading
      return line:sub(1, 40)
    end
  end

  return ""
end

--- Parse description from context markdown file
--- @param filepath string Path to .md file
--- @return string Description (empty if not found)
function M.parse_context_description(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return ""
  end

  local success, lines = pcall(vim.fn.readfile, filepath, "", 30)
  if not success or not lines then
    return ""
  end

  -- Look for first heading or description in frontmatter
  local in_frontmatter = false
  local after_title = false

  for _, line in ipairs(lines) do
    -- Check for YAML frontmatter
    if line == "---" then
      if not in_frontmatter then
        in_frontmatter = true
      else
        in_frontmatter = false
      end
    elseif in_frontmatter then
      local desc = line:match("^description:%s*(.+)$")
      if desc then
        return desc:sub(1, 40)
      end
    elseif line:match("^#%s+[^#]") then
      -- Found a title heading
      after_title = true
    elseif after_title and line ~= "" and not line:match("^#") then
      -- First non-empty line after title
      return line:sub(1, 40)
    end
  end

  return ""
end

--- Parse title from memory markdown file (MEM-YYYY-MM-DD-NNN.md)
--- @param filepath string Path to memory .md file
--- @return string Title (filename if not found)
function M.parse_memory_title(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return ""
  end

  local success, lines = pcall(vim.fn.readfile, filepath, "", 20)
  if not success or not lines then
    return ""
  end

  -- Look for first heading
  for _, line in ipairs(lines) do
    local title = line:match("^#%s+(.+)$")
    if title then
      return title
    end
  end

  -- Fallback to filename
  local filename = vim.fn.fnamemodify(filepath, ":t:r")
  return filename
end

--- Parse description from rule markdown file
--- @param filepath string Path to rule .md file
--- @return string Description (empty if not found)
function M.parse_rule_description(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return ""
  end

  local success, lines = pcall(vim.fn.readfile, filepath, "", 30)
  if not success or not lines then
    return ""
  end

  local in_frontmatter = false
  local after_title = false

  for _, line in ipairs(lines) do
    if line == "---" then
      if not in_frontmatter then
        in_frontmatter = true
      else
        in_frontmatter = false
      end
    elseif in_frontmatter then
      local desc = line:match("^description:%s*(.+)$")
      if desc then
        return desc:sub(1, 40)
      end
    elseif line:match("^#%s+[^#]") then
      after_title = true
    elseif after_title and line ~= "" and not line:match("^#") then
      return line:sub(1, 40)
    end
  end

  return ""
end

--- Get description parser function for artifact type
--- @param type_name string Artifact type (command, skill, etc.)
--- @return function|nil Parser function or nil if not found
function M.get_parser_for_type(type_name)
  local parsers = {
    template = M.parse_template_description,
    skill = M.parse_doc_description,
    lib = M.parse_script_description,
    hook_event = M.parse_script_description,
    script = M.parse_script_description,
    test = M.parse_script_description,
    doc = M.parse_doc_description,
    context = M.parse_context_description,
    memory = M.parse_memory_title,
    rule = M.parse_rule_description,
  }

  return parsers[type_name]
end

return M
