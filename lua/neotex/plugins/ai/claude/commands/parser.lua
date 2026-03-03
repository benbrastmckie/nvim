-- neotex.plugins.ai.claude.commands.parser
-- Parse Claude commands and artifacts from .claude/ directory
-- Extracts metadata and builds hierarchical structure

local M = {}

-- Dependencies
local plenary_path = require("plenary.path")

--- Parse YAML frontmatter from markdown content
--- @param content string The markdown file content
--- @return table|nil Parsed frontmatter or nil if not found
local function parse_frontmatter(content)
  local frontmatter_pattern = "^%-%-%-\n(.-)%-%-%-"
  local frontmatter_text = content:match(frontmatter_pattern)

  if not frontmatter_text then
    return nil
  end

  local metadata = {}

  -- Fields that should be treated as arrays (comma-separated)
  local array_fields = {
    allowed_tools = true,
    dependent_commands = true,
    parent_commands = true,
    context = true,
  }

  for line in frontmatter_text:gmatch("[^\n]+") do
    local key, value = line:match("^([%w%-_]+):%s*(.+)")
    if key and value then
      local normalized_key = key:gsub("%-", "_")

      if array_fields[normalized_key] and value:find(",") then
        local array = {}
        for item in value:gmatch("([^,]+)") do
          table.insert(array, vim.trim(item))
        end
        metadata[normalized_key] = array
      else
        metadata[normalized_key] = tostring(vim.trim(value))
      end
    end
  end

  return metadata
end

--- Extract command name from filename
--- @param filepath string Full path to command file
--- @return string Command name without .md extension
local function get_command_name(filepath)
  local filename = vim.fn.fnamemodify(filepath, ":t")
  return filename:gsub("%.md$", "")
end

--- Scan .claude/commands/ directory for command files
--- @param commands_dir string Path to commands directory
--- @return table Array of command file paths
function M.scan_commands_directory(commands_dir)
  commands_dir = commands_dir or ".claude/commands"
  local commands_path = plenary_path:new(commands_dir)

  if not commands_path:exists() then
    return {}
  end

  local command_files = {}
  local scandir_ok, scan_result = pcall(vim.fn.readdir, commands_dir)
  if not scandir_ok then
    return {}
  end

  for _, filename in ipairs(scan_result) do
    if filename:match("%.md$") then
      table.insert(command_files, filename)
    end
  end

  return command_files
end

--- Parse a single command file
--- @param filepath string Path to the command file
--- @return table|nil Parsed command data or nil if error
function M.parse_command_file(filepath)
  local path = plenary_path:new(filepath)

  if not path:exists() then
    return nil
  end

  local content = path:read()
  if not content then
    return nil
  end

  local metadata = parse_frontmatter(content)
  if not metadata then
    return nil
  end

  local command_name = get_command_name(filepath)

  local function ensure_array(value)
    if type(value) == "string" then
      return { value }
    elseif type(value) == "table" then
      return value
    else
      return {}
    end
  end

  return {
    name = command_name,
    filepath = filepath,
    command_type = metadata.command_type or "primary",
    description = metadata.description or "",
    argument_hint = metadata.argument_hint or "",
    allowed_tools = ensure_array(metadata.allowed_tools),
    dependent_commands = ensure_array(metadata.dependent_commands),
    parent_commands = ensure_array(metadata.parent_commands),
  }
end

--- Parse all commands in directory
--- @param commands_dir string Path to commands directory
--- @return table Parsed commands data
function M.parse_all_commands(commands_dir)
  commands_dir = commands_dir or ".claude/commands"

  local command_files = M.scan_commands_directory(commands_dir)
  local parsed_commands = {}

  for _, filename in ipairs(command_files) do
    local filepath = commands_dir .. "/" .. filename
    local command_data = M.parse_command_file(filepath)

    if command_data then
      parsed_commands[command_data.name] = command_data
    end
  end

  return parsed_commands
end

--- Build two-level hierarchy from parsed commands
--- @param commands table Parsed commands from parse_all_commands
--- @return table Hierarchical structure with primary and dependent commands
function M.build_hierarchy(commands)
  local hierarchy = {
    primary_commands = {},
    dependent_commands = {},
  }

  -- First pass: categorize commands
  for name, command in pairs(commands) do
    if command.command_type == "primary" then
      hierarchy.primary_commands[name] = {
        command = command,
        dependents = {}
      }
    else
      hierarchy.dependent_commands[name] = command
    end
  end

  -- Second pass: link dependents to their parents
  for name, dependent in pairs(hierarchy.dependent_commands) do
    local parent_commands = dependent.parent_commands or {}

    if #parent_commands == 0 then
      for primary_name, primary_data in pairs(hierarchy.primary_commands) do
        local dependent_list = primary_data.command.dependent_commands or {}
        for _, dep_name in ipairs(dependent_list) do
          if dep_name == name then
            table.insert(parent_commands, primary_name)
          end
        end
      end
    end

    for _, parent_name in ipairs(parent_commands) do
      if hierarchy.primary_commands[parent_name] then
        table.insert(hierarchy.primary_commands[parent_name].dependents, dependent)
      end
    end
  end

  -- Third pass: link primary commands listed as dependents of other primary commands
  for primary_name, primary_data in pairs(hierarchy.primary_commands) do
    local dependent_list = primary_data.command.dependent_commands or {}

    for _, dep_name in ipairs(dependent_list) do
      if hierarchy.primary_commands[dep_name] then
        local primary_as_dependent = vim.deepcopy(hierarchy.primary_commands[dep_name].command)
        table.insert(primary_data.dependents, primary_as_dependent)
      end
    end
  end

  return hierarchy
end

--- Sort commands alphabetically within hierarchy
--- @param hierarchy table Hierarchical structure from build_hierarchy
--- @return table Sorted hierarchy
function M.sort_hierarchy(hierarchy)
  local sorted_primary = {}
  local primary_names = {}

  for name, _ in pairs(hierarchy.primary_commands) do
    table.insert(primary_names, name)
  end
  table.sort(primary_names)

  for _, name in ipairs(primary_names) do
    local primary_data = hierarchy.primary_commands[name]

    table.sort(primary_data.dependents, function(a, b)
      return a.name < b.name
    end)

    sorted_primary[name] = primary_data
  end

  hierarchy.primary_commands = sorted_primary
  return hierarchy
end

--- Parse commands from both local and global directories with local priority
--- @param project_dir string|nil Path to project-specific commands directory
--- @param global_dir string Path to global commands directory
--- @return table Merged commands with is_local flag
function M.parse_with_fallback(project_dir, global_dir)
  local merged_commands = {}
  local local_command_names = {}

  -- Special case: when in .config/, project_dir equals global_dir
  if project_dir and project_dir == global_dir then
    if vim.fn.isdirectory(project_dir) == 1 then
      local commands = M.parse_all_commands(project_dir)
      for name, command in pairs(commands) do
        command.is_local = true
        merged_commands[name] = command
      end
    end
    return merged_commands
  end

  -- Normal case: Parse local project commands first
  if project_dir and project_dir ~= global_dir then
    local project_exists = vim.fn.isdirectory(project_dir) == 1
    if project_exists then
      local local_commands = M.parse_all_commands(project_dir)
      for name, command in pairs(local_commands) do
        command.is_local = true
        merged_commands[name] = command
        local_command_names[name] = true
      end
    end
  end

  -- Parse global commands from .config
  if vim.fn.isdirectory(global_dir) == 1 then
    local global_commands = M.parse_all_commands(global_dir)
    for name, command in pairs(global_commands) do
      if not local_command_names[name] then
        command.is_local = false
        merged_commands[name] = command
      end
    end
  end

  return merged_commands
end

--- Scan .claude/hooks/ directory for hook scripts
--- @param hooks_dir string Path to hooks directory
--- @return table Array of hook metadata
function M.scan_hooks_directory(hooks_dir)
  local hooks_path = plenary_path:new(hooks_dir)

  if not hooks_path:exists() then
    return {}
  end

  local hook_files = {}
  local scandir_ok, scan_result = pcall(vim.fn.readdir, hooks_dir)
  if not scandir_ok then
    return {}
  end

  for _, filename in ipairs(scan_result) do
    if filename:match("%.sh$") then
      local filepath = hooks_dir .. "/" .. filename
      local path = plenary_path:new(filepath)

      if path:exists() then
        local content = path:read()
        local description = ""

        if content then
          for line in content:gmatch("[^\n]+") do
            local purpose = line:match("^#%s*Purpose:%s*(.+)")
            if purpose then
              description = vim.trim(purpose)
              break
            end
          end
        end

        table.insert(hook_files, {
          name = filename,
          description = description,
          filepath = filepath,
          is_local = false,
          events = {}
        })
      end
    end
  end

  return hook_files
end

--- Build hook event → hooks dependency map
--- @param hooks table Hook data
--- @param settings_path string Path to settings.local.json
--- @return table Map of event name → hooks triggered
function M.build_hook_dependencies(hooks, settings_path)
  local hook_events = {}

  if vim.fn.filereadable(settings_path) ~= 1 then
    return hook_events
  end

  local settings_content = table.concat(vim.fn.readfile(settings_path), "\n")
  local ok, settings = pcall(vim.fn.json_decode, settings_content)

  if not ok or not settings or not settings.hooks then
    return hook_events
  end

  for event_name, event_configs in pairs(settings.hooks) do
    hook_events[event_name] = {}

    for _, config in ipairs(event_configs) do
      if config.hooks then
        for _, hook_config in ipairs(config.hooks) do
          if hook_config.command then
            local hook_name = hook_config.command:match("([^/%s]+%.sh)")
            if hook_name then
              table.insert(hook_events[event_name], hook_name)
            end
          end
        end
      end
    end
  end

  for _, hook in ipairs(hooks) do
    hook.events = {}
    for event_name, hook_names in pairs(hook_events) do
      for _, hook_name in ipairs(hook_names) do
        if hook_name == hook.name then
          table.insert(hook.events, event_name)
        end
      end
    end
  end

  return hook_events
end

--- Scan .claude/agents/ directory for agent definitions
--- @param agents_dir string Path to agents directory
--- @return table Array of agent metadata
function M.scan_agents_directory(agents_dir)
  local agents_path = plenary_path:new(agents_dir)

  if not agents_path:exists() then
    return {}
  end

  local agents = {}
  local scandir_ok, files = pcall(vim.fn.readdir, agents_dir)
  if not scandir_ok then
    return {}
  end

  for _, filename in ipairs(files) do
    -- Look for *.md files, exclude archive/ subdirectory
    if filename:match("%.md$") and filename ~= "README.md" then
      local agent_file = agents_dir .. "/" .. filename
      local path = plenary_path:new(agent_file)

      if path:exists() then
        local content = path:read()
        if content then
          -- Extract agent name from filename (remove .md extension)
          local agent_name = filename:gsub("%.md$", "")

          -- Try to parse frontmatter for description
          local metadata = parse_frontmatter(content)
          local description = ""

          if metadata and metadata.description then
            description = metadata.description
          else
            -- Fall back to first heading or first line
            local first_heading = content:match("^#%s*(.-)[\r\n]")
            if first_heading then
              description = vim.trim(first_heading)
            end
          end

          table.insert(agents, {
            name = agent_name,
            description = description,
            filepath = agent_file,
            is_local = false,
          })
        end
      end
    end
  end

  return agents
end

--- Scan .claude/skills/ directory for skill definitions
--- @param skills_dir string Path to skills directory
--- @return table Array of skill metadata
function M.scan_skills_directory(skills_dir)
  local skills_path = plenary_path:new(skills_dir)

  if not skills_path:exists() then
    return {}
  end

  local skills = {}
  local scandir_ok, subdirs = pcall(vim.fn.readdir, skills_dir)
  if not scandir_ok then
    return {}
  end

  for _, dirname in ipairs(subdirs) do
    -- Look for skill-* directories
    if dirname:match("^skill%-") then
      local skill_file = skills_dir .. "/" .. dirname .. "/SKILL.md"
      local path = plenary_path:new(skill_file)

      if path:exists() then
        local content = path:read()
        if content then
          local metadata = parse_frontmatter(content)
          if metadata then
            local function ensure_array(value)
              if type(value) == "string" then
                return { value }
              elseif type(value) == "table" then
                return value
              else
                return {}
              end
            end

            table.insert(skills, {
              name = metadata.name or dirname,
              description = metadata.description or "",
              allowed_tools = ensure_array(metadata.allowed_tools),
              context = ensure_array(metadata.context),
              filepath = skill_file,
              dirname = dirname,
              is_local = false,
            })
          end
        end
      end
    end
  end

  return skills
end

--- Parse skills from both local and global directories with local priority
--- @param project_skills_dir string Path to project-specific skills directory
--- @param global_skills_dir string Path to global skills directory
--- @return table Merged skills with is_local flag
local function parse_skills_with_fallback(project_skills_dir, global_skills_dir)
  local merged_skills = {}
  local local_skill_names = {}

  -- Special case: when in .config/
  if project_skills_dir and project_skills_dir == global_skills_dir then
    if vim.fn.isdirectory(project_skills_dir) == 1 then
      local skills = M.scan_skills_directory(project_skills_dir)
      for _, skill in ipairs(skills) do
        skill.is_local = true
        table.insert(merged_skills, skill)
      end
    end
    return merged_skills
  end

  -- Normal case: Parse local skills first
  if vim.fn.isdirectory(project_skills_dir) == 1 then
    local local_skills = M.scan_skills_directory(project_skills_dir)
    for _, skill in ipairs(local_skills) do
      skill.is_local = true
      table.insert(merged_skills, skill)
      local_skill_names[skill.name] = true
    end
  end

  -- Parse global skills
  if vim.fn.isdirectory(global_skills_dir) == 1 then
    local global_skills = M.scan_skills_directory(global_skills_dir)
    for _, skill in ipairs(global_skills) do
      if not local_skill_names[skill.name] then
        skill.is_local = false
        table.insert(merged_skills, skill)
      end
    end
  end

  return merged_skills
end

--- Scan root-level configuration files for a base directory
--- @param project_dir string Path to project directory
--- @param global_dir string Path to global directory
--- @param base_dir string Base directory name (.claude or .opencode)
--- @param root_config_file string Root config file name (CLAUDE.md or OPENCODE.md)
--- @param settings_file string Settings file name (settings.local.json or settings.json)
--- @return table Array of root file metadata with name, filepath, is_local, description
local function scan_root_files(project_dir, global_dir, base_dir, root_config_file, settings_file)
  base_dir = base_dir or ".claude"
  root_config_file = root_config_file or "CLAUDE.md"
  settings_file = settings_file or "settings.local.json"

  local root_files_config = {
    { name = ".gitignore", description = "Git ignore patterns" },
    { name = "README.md", description = "Documentation" },
    { name = root_config_file, description = base_dir:sub(2) .. " configuration" },
    { name = settings_file, description = "Local settings" },
  }

  local root_files = {}
  local seen = {}

  -- Check local project first
  local project_base_dir = project_dir .. "/" .. base_dir
  for _, config in ipairs(root_files_config) do
    local filepath = project_base_dir .. "/" .. config.name
    if vim.fn.filereadable(filepath) == 1 then
      table.insert(root_files, {
        name = config.name,
        filepath = filepath,
        is_local = true,
        description = config.description,
      })
      seen[config.name] = true
    end
  end

  -- Check global, but only if different from project and file not already found locally
  local global_base_dir = global_dir .. "/" .. base_dir
  if project_dir ~= global_dir then
    for _, config in ipairs(root_files_config) do
      if not seen[config.name] then
        local filepath = global_base_dir .. "/" .. config.name
        if vim.fn.filereadable(filepath) == 1 then
          table.insert(root_files, {
            name = config.name,
            filepath = filepath,
            is_local = false,
            description = config.description,
          })
        end
      end
    end
  end

  return root_files
end

--- Parse agents from both local and global directories with local priority
--- @param project_agents_dir string Path to project-specific agents directory
--- @param global_agents_dir string Path to global agents directory
--- @return table Merged agents with is_local flag
local function parse_agents_with_fallback(project_agents_dir, global_agents_dir)
  local merged_agents = {}
  local local_agent_names = {}

  -- Special case: when in .config/
  if project_agents_dir and project_agents_dir == global_agents_dir then
    if vim.fn.isdirectory(project_agents_dir) == 1 then
      local agents = M.scan_agents_directory(project_agents_dir)
      for _, agent in ipairs(agents) do
        agent.is_local = true
        table.insert(merged_agents, agent)
      end
    end
    return merged_agents
  end

  -- Normal case: Parse local agents first
  if vim.fn.isdirectory(project_agents_dir) == 1 then
    local local_agents = M.scan_agents_directory(project_agents_dir)
    for _, agent in ipairs(local_agents) do
      agent.is_local = true
      table.insert(merged_agents, agent)
      local_agent_names[agent.name] = true
    end
  end

  -- Parse global agents
  if vim.fn.isdirectory(global_agents_dir) == 1 then
    local global_agents = M.scan_agents_directory(global_agents_dir)
    for _, agent in ipairs(global_agents) do
      if not local_agent_names[agent.name] then
        agent.is_local = false
        table.insert(merged_agents, agent)
      end
    end
  end

  return merged_agents
end

--- Parse hooks from both local and global directories with local priority
--- @param project_hooks_dir string Path to project-specific hooks directory
--- @param global_hooks_dir string Path to global hooks directory
--- @return table Merged hooks with is_local flag
local function parse_hooks_with_fallback(project_hooks_dir, global_hooks_dir)
  local merged_hooks = {}
  local local_hook_names = {}

  -- Special case: when in .config/
  if project_hooks_dir and project_hooks_dir == global_hooks_dir then
    if vim.fn.isdirectory(project_hooks_dir) == 1 then
      local hooks = M.scan_hooks_directory(project_hooks_dir)
      for _, hook in ipairs(hooks) do
        hook.is_local = true
        table.insert(merged_hooks, hook)
      end
    end
    return merged_hooks
  end

  -- Normal case: Parse local hooks first
  if vim.fn.isdirectory(project_hooks_dir) == 1 then
    local local_hooks = M.scan_hooks_directory(project_hooks_dir)
    for _, hook in ipairs(local_hooks) do
      hook.is_local = true
      table.insert(merged_hooks, hook)
      local_hook_names[hook.name] = true
    end
  end

  -- Parse global hooks
  if vim.fn.isdirectory(global_hooks_dir) == 1 then
    local global_hooks = M.scan_hooks_directory(global_hooks_dir)
    for _, hook in ipairs(global_hooks) do
      if not local_hook_names[hook.name] then
        hook.is_local = false
        table.insert(merged_hooks, hook)
      end
    end
  end

  return merged_hooks
end

--- Get extended structure with commands, hooks, and skills
--- @param config table|nil Picker config from shared.picker.config (optional, defaults to claude)
--- @return table Structure with commands, hooks, skills, and dependencies
function M.get_extended_structure(config)
  local project_dir = vim.fn.getcwd()
  local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local global_dir = config and config.global_source_dir or scan.get_global_dir()

  -- Get config values with defaults for Claude
  local base_dir = config and config.base_dir or ".claude"
  local commands_subdir = config and config.commands_subdir or "commands"
  local skills_subdir = config and config.skills_subdir or "skills"
  local agents_subdir = config and config.agents_subdir or "agents"
  local hooks_subdir = config and config.hooks_subdir or "hooks"
  local settings_file = config and config.settings_file or "settings.local.json"
  local root_config_file = config and config.root_config_file or "CLAUDE.md"

  -- Get command structure
  local project_commands_dir = project_dir .. "/" .. base_dir .. "/" .. commands_subdir
  local global_commands_dir = global_dir .. "/" .. base_dir .. "/" .. commands_subdir
  local commands = M.parse_with_fallback(project_commands_dir, global_commands_dir)
  local hierarchy = M.build_hierarchy(commands)
  local sorted_hierarchy = M.sort_hierarchy(hierarchy)

  -- Get hooks (only if hooks_subdir is configured)
  local hooks = {}
  local hook_events = {}
  if hooks_subdir then
    local project_hooks_dir = project_dir .. "/" .. base_dir .. "/" .. hooks_subdir
    local global_hooks_dir = global_dir .. "/" .. base_dir .. "/" .. hooks_subdir
    hooks = parse_hooks_with_fallback(project_hooks_dir, global_hooks_dir)

    -- Build hook dependencies
    local settings_path = project_dir .. "/" .. base_dir .. "/" .. settings_file
    if vim.fn.filereadable(settings_path) ~= 1 then
      settings_path = global_dir .. "/" .. base_dir .. "/" .. settings_file
    end
    hook_events = M.build_hook_dependencies(hooks, settings_path)
  end

  -- Get skills
  local project_skills_dir = project_dir .. "/" .. base_dir .. "/" .. skills_subdir
  local global_skills_dir = global_dir .. "/" .. base_dir .. "/" .. skills_subdir
  local skills = parse_skills_with_fallback(project_skills_dir, global_skills_dir)

  -- Get agents
  local project_agents_dir = project_dir .. "/" .. base_dir .. "/" .. agents_subdir
  local global_agents_dir = global_dir .. "/" .. base_dir .. "/" .. agents_subdir
  local agents = parse_agents_with_fallback(project_agents_dir, global_agents_dir)

  -- Get root files
  local root_files = scan_root_files(project_dir, global_dir, base_dir, root_config_file, settings_file)

  return {
    primary_commands = sorted_hierarchy.primary_commands,
    dependent_commands = sorted_hierarchy.dependent_commands,
    hooks = hooks,
    hook_events = hook_events,
    skills = skills,
    agents = agents,
    root_files = root_files,
  }
end

--- Main function to get organized command structure
--- @param commands_dir string Path to commands directory (optional)
--- @return table Organized, sorted command hierarchy
function M.get_command_structure(commands_dir)
  if commands_dir then
    local commands = M.parse_all_commands(commands_dir)
    local hierarchy = M.build_hierarchy(commands)
    return M.sort_hierarchy(hierarchy)
  end

  local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local project_dir = vim.fn.getcwd() .. "/.claude/commands"
  local global_dir = scan_mod.get_global_dir() .. "/.claude/commands"

  local commands = M.parse_with_fallback(project_dir, global_dir)
  local hierarchy = M.build_hierarchy(commands)
  return M.sort_hierarchy(hierarchy)
end

return M
