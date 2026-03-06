-- neotex.plugins.ai.claude.commands.picker.display.entries
-- Entry creation for telescope picker with hierarchical display

local M = {}

-- Dependencies
local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
local metadata = require("neotex.plugins.ai.claude.commands.picker.artifacts.metadata")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Format hook event header for display
--- @param event_name string Hook event name
--- @param indent_char string Tree character (├─ or └─)
--- @param event_hooks table Array of hooks associated with this event
--- @param is_event_local boolean|nil Whether the event itself is from local settings
--- @return string Formatted display string
local function format_hook_event(event_name, indent_char, event_hooks, is_event_local)
  local has_local_hook = false

  -- First check event-level locality (handles inline hooks)
  if is_event_local then
    has_local_hook = true
  end

  -- Also check individual hooks for backward compatibility with .sh files
  if not has_local_hook and event_hooks then
    for _, hook in ipairs(event_hooks) do
      if hook.is_local then
        has_local_hook = true
        break
      end
    end
  end

  local prefix = has_local_hook and "*" or " "

  local registry = require("neotex.plugins.ai.claude.commands.picker.artifacts.registry")
  local description = ""
  if registry.HOOK_EVENT_DESCRIPTIONS and registry.HOOK_EVENT_DESCRIPTIONS[event_name] then
    description = registry.HOOK_EVENT_DESCRIPTIONS[event_name].short
  end

  return string.format(
    "%s  %s %-37s %s",
    prefix,
    indent_char,
    event_name,
    description
  )
end

--- Format command entry for display
--- @param command table Command data
--- @param indent_char string Tree character
--- @param is_dependent boolean Whether this is a dependent command
--- @return string Formatted display string
local function format_command(command, indent_char, is_dependent)
  local prefix = command.is_local and "*" or " "
  local description = command.description or ""

  if is_dependent then
    return string.format(
      "%s   %s %-37s %s",
      prefix,
      indent_char,
      command.name,
      description
    )
  else
    return string.format(
      "%s %s %-38s %s",
      prefix,
      indent_char,
      command.name,
      description
    )
  end
end

--- Create entries for context section
--- Scans .opencode/context/ for all markdown files
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_context_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  local context_files = scan.scan_context_directory(base_dir, project_dir, global_dir)

  if #context_files > 0 then
    -- Group files by category
    local by_category = {}
    for _, file in ipairs(context_files) do
      if not by_category[file.category] then
        by_category[file.category] = {}
      end
      table.insert(by_category[file.category], file)
    end

    -- Process categories in order
    local categories = { "core", "project" }
    local all_entries_added = {}

    for _, category in ipairs(categories) do
      local files = by_category[category]
      if files and #files > 0 then
        -- Add subheading for this category
        local category_display = category:sub(1, 1):upper() .. category:sub(2)

        -- Add entries for this category
        for i, file in ipairs(files) do
          local is_last = (i == #files)
          local indent_char = helpers.get_tree_char(is_last)
          local display_name = file.subpath:gsub("/", " > ")
          local description = metadata.parse_context_description(file.filepath)

          table.insert(all_entries_added, {
            display = helpers.format_display(
              file.is_local and "*" or " ",
              " " .. indent_char,
              display_name,
              description
            ),
            entry_type = "context",
            name = file.name,
            filepath = file.filepath,
            category = file.category,
            subpath = file.subpath,
            is_local = file.is_local,
            ordinal = "zzzz_context_" .. category .. "_" .. file.subpath:gsub("/", "_")
          })
        end

        -- Insert category subheading (will appear before entries due to reverse order)
        table.insert(all_entries_added, {
          is_subheading = true,
          name = "~~~context_" .. category .. "_heading",
          display = string.format("  %s", category_display),
          entry_type = "subheading",
          ordinal = "zzzz_context_sub_" .. category
        })
      end
    end

    -- Reverse to maintain correct order (since create_picker_entries reverses everything)
    for i = #all_entries_added, 1, -1 do
      table.insert(entries, all_entries_added[i])
    end

    -- Add main heading
    table.insert(entries, {
      is_heading = true,
      name = "~~~context_heading",
      display = string.format("%-40s %s", "[Context]", "Knowledge base and standards"),
      entry_type = "heading",
      ordinal = "context",
      config = config,
    })
  end

  return entries
end

--- Create entries for memory section
--- Scans .opencode/memory/10-Memories/ and 20-Indices/
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_memory_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  -- Scan 10-Memories/ for MEM-*.md files
  local local_memories = {}
  local global_memories = {}

  local local_mem_path = project_dir .. "/" .. base_dir .. "/memory/10-Memories"
  local global_mem_path = global_dir .. "/" .. base_dir .. "/memory/10-Memories"

  -- Scan local memories
  if vim.fn.isdirectory(local_mem_path) == 1 then
    local files = vim.fn.glob(local_mem_path .. "/MEM-*.md", false, true)
    for _, filepath in ipairs(files) do
      local filename = vim.fn.fnamemodify(filepath, ":t")
      local date_str, num = filename:match("MEM%-(%d%d%d%d%-%d%d%-%d%d)%-(%d+)%.md$")
      if date_str then
        table.insert(local_memories, {
          name = filename:gsub("%.md$", ""),
          filepath = filepath,
          date = date_str,
          num = tonumber(num),
          is_local = true,
        })
      end
    end
  end

  -- Scan global memories
  if vim.fn.isdirectory(global_mem_path) == 1 then
    local files = vim.fn.glob(global_mem_path .. "/MEM-*.md", false, true)
    for _, filepath in ipairs(files) do
      local filename = vim.fn.fnamemodify(filepath, ":t")
      local date_str, num = filename:match("MEM%-(%d%d%d%d%-%d%d%-%d%d)%-(%d+)%.md$")
      if date_str then
        -- Check if already in local
        local exists = false
        for _, local_mem in ipairs(local_memories) do
          if local_mem.name == filename:gsub("%.md$", "") then
            exists = true
            break
          end
        end
        if not exists then
          table.insert(global_memories, {
            name = filename:gsub("%.md$", ""),
            filepath = filepath,
            date = date_str,
            num = tonumber(num),
            is_local = false,
          })
        end
      end
    end
  end

  -- Merge memories
  local all_memories = {}
  vim.list_extend(all_memories, local_memories)
  vim.list_extend(all_memories, global_memories)

  -- Sort reverse-chronologically (newest first)
  table.sort(all_memories, function(a, b)
    if a.date ~= b.date then
      return a.date > b.date  -- Reverse chronological
    end
    return a.num > b.num
  end)

  -- Check for index.md in 20-Indices/
  local index_entries = {}
  local local_index = project_dir .. "/" .. base_dir .. "/memory/20-Indices/index.md"
  local global_index = global_dir .. "/" .. base_dir .. "/memory/20-Indices/index.md"
  local index_path = nil
  local index_is_local = false

  if vim.fn.filereadable(local_index) == 1 then
    index_path = local_index
    index_is_local = true
  elseif vim.fn.filereadable(global_index) == 1 then
    index_path = global_index
    index_is_local = false
  end

  if index_path then
    table.insert(index_entries, {
      display = helpers.format_display(
        index_is_local and "*" or " ",
        " ├─",
        "Index",
        "Memory index and navigation"
      ),
      entry_type = "memory",
      name = "index",
      filepath = index_path,
      is_local = index_is_local,
      ordinal = "zzzz_memory_index"
    })
  end

  -- Create memory entries
  if #all_memories > 0 then
    for i, mem in ipairs(all_memories) do
      local is_last = (i == #all_memories)
      local indent_char = helpers.get_tree_char(is_last)
      local title = metadata.parse_memory_title(mem.filepath)
      local display_name = mem.date .. ": " .. title

      table.insert(entries, {
        display = helpers.format_display(
          mem.is_local and "*" or " ",
          " " .. indent_char,
          display_name,
          ""
        ),
        entry_type = "memory",
        name = mem.name,
        filepath = mem.filepath,
        date = mem.date,
        is_local = mem.is_local,
        ordinal = "zzzz_memory_" .. mem.date .. "_" .. string.format("%03d", mem.num)
      })
    end

    -- Add index entry if exists
    for _, idx_entry in ipairs(index_entries) do
      table.insert(entries, idx_entry)
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~memories_heading",
      display = string.format("%-40s %s", "[Memories]", "Knowledge memories"),
      entry_type = "heading",
      ordinal = "memories",
      config = config,
    })
  end

  return entries
end

--- Create entries for rules section
--- Scans .opencode/rules/ for *.md files
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_rules_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  local local_rules = scan.scan_directory(project_dir .. "/" .. base_dir .. "/rules", "*.md")
  local global_rules = scan.scan_directory(global_dir .. "/" .. base_dir .. "/rules", "*.md")
  local all_rules = scan.merge_artifacts(local_rules, global_rules)

  if #all_rules > 0 then
    table.sort(all_rules, function(a, b) return a.name < b.name end)

    for i, rule in ipairs(all_rules) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)
      local description = metadata.parse_rule_description(rule.filepath)

      table.insert(entries, {
        display = helpers.format_display(
          rule.is_local and "*" or " ",
          " " .. indent_char,
          rule.name,
          description
        ),
        entry_type = "rule",
        name = rule.name,
        filepath = rule.filepath,
        is_local = rule.is_local,
        ordinal = "zzzz_rule_" .. rule.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~rules_heading",
      display = string.format("%-40s %s", "[Rules]", "Behavioral rules and standards"),
      entry_type = "heading",
      ordinal = "rules",
      config = config,
    })
  end

  return entries
end

--- Create entries for docs section
--- Only shows docs/README.md (not all .md files in docs/)
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_docs_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  -- Only show docs/README.md (not all .md files in docs/)
  local readme_path = nil
  local is_local = false
  local local_readme = project_dir .. "/" .. base_dir .. "/docs/README.md"
  local global_readme = global_dir .. "/" .. base_dir .. "/docs/README.md"

  if vim.fn.filereadable(local_readme) == 1 then
    readme_path = local_readme
    is_local = true
  elseif vim.fn.filereadable(global_readme) == 1 then
    readme_path = global_readme
    is_local = false
  end

  if readme_path then
    local description = metadata.parse_doc_description(readme_path)

    table.insert(entries, {
      display = helpers.format_display(
        is_local and "*" or " ",
        " " .. helpers.get_tree_char(true),
        "README",
        description
      ),
      entry_type = "doc",
      name = "README",
      filepath = readme_path,
      is_local = is_local,
      ordinal = "zzzz_doc_README"
    })

    table.insert(entries, {
      is_heading = true,
      name = "~~~docs_heading",
      display = string.format("%-40s %s", "[Docs]", "Integration guides"),
      entry_type = "heading",
      ordinal = "docs",
      config = config,
    })
  end

  return entries
end

--- Create entries for lib section
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_lib_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  local local_lib = scan.scan_directory(project_dir .. "/" .. base_dir .. "/lib", "*.sh")
  local global_lib = scan.scan_directory(global_dir .. "/" .. base_dir .. "/lib", "*.sh")
  local all_lib = scan.merge_artifacts(local_lib, global_lib)

  if #all_lib > 0 then
    table.sort(all_lib, function(a, b) return a.name < b.name end)

    for i, lib in ipairs(all_lib) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)
      local description = metadata.parse_script_description(lib.filepath)

      table.insert(entries, {
        display = helpers.format_display(
          lib.is_local and "*" or " ",
          " " .. indent_char,
          lib.name,
          description
        ),
        entry_type = "lib",
        name = lib.name,
        filepath = lib.filepath,
        is_local = lib.is_local,
        ordinal = "zzzz_lib_" .. lib.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~lib_heading",
      display = string.format("%-40s %s", "[Lib]", "Utility libraries"),
      entry_type = "heading",
      ordinal = "lib",
      config = config,
    })
  end

  return entries
end

--- Create entries for templates section
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_templates_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  local local_templates = scan.scan_directory(project_dir .. "/" .. base_dir .. "/templates", "*.yaml")
  local global_templates = scan.scan_directory(global_dir .. "/" .. base_dir .. "/templates", "*.yaml")
  local all_templates = scan.merge_artifacts(local_templates, global_templates)

  if #all_templates > 0 then
    table.sort(all_templates, function(a, b) return a.name < b.name end)

    for i, tmpl in ipairs(all_templates) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)
      local description = metadata.parse_template_description(tmpl.filepath)

      table.insert(entries, {
        display = helpers.format_display(
          tmpl.is_local and "*" or " ",
          " " .. indent_char,
          tmpl.name,
          description
        ),
        entry_type = "template",
        name = tmpl.name,
        filepath = tmpl.filepath,
        is_local = tmpl.is_local,
        ordinal = "zzzz_template_" .. tmpl.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~templates_heading",
      display = string.format("%-40s %s", "[Templates]", "Workflow templates"),
      entry_type = "heading",
      ordinal = "templates",
      config = config,
    })
  end

  return entries
end

--- Create entries for scripts section
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_scripts_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  local local_scripts = scan.scan_directory(project_dir .. "/" .. base_dir .. "/scripts", "*.sh")
  local global_scripts = scan.scan_directory(global_dir .. "/" .. base_dir .. "/scripts", "*.sh")
  local all_scripts = scan.merge_artifacts(local_scripts, global_scripts)

  if #all_scripts > 0 then
    table.sort(all_scripts, function(a, b) return a.name < b.name end)

    for i, script in ipairs(all_scripts) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)
      local description = metadata.parse_script_description(script.filepath)

      table.insert(entries, {
        display = helpers.format_display(
          script.is_local and "*" or " ",
          " " .. indent_char,
          script.name,
          description
        ),
        entry_type = "script",
        name = script.name,
        filepath = script.filepath,
        is_local = script.is_local,
        ordinal = "zzzz_script_" .. script.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~scripts_heading",
      display = string.format("%-40s %s", "[Scripts]", "Standalone CLI tools"),
      entry_type = "heading",
      ordinal = "scripts",
      config = config,
    })
  end

  return entries
end

--- Create entries for tests section
--- @param config table|nil Picker configuration for config-aware path construction
--- @return table Array of entries
function M.create_tests_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  local local_tests = scan.scan_directory(project_dir .. "/" .. base_dir .. "/tests", "test_*.sh")
  local global_tests = scan.scan_directory(global_dir .. "/" .. base_dir .. "/tests", "test_*.sh")
  local all_tests = scan.merge_artifacts(local_tests, global_tests)

  if #all_tests > 0 then
    table.sort(all_tests, function(a, b) return a.name < b.name end)

    for i, test in ipairs(all_tests) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)
      local description = metadata.parse_script_description(test.filepath)

      table.insert(entries, {
        display = helpers.format_display(
          test.is_local and "*" or " ",
          " " .. indent_char,
          test.name,
          description
        ),
        entry_type = "test",
        name = test.name,
        filepath = test.filepath,
        is_local = test.is_local,
        ordinal = "zzzz_test_" .. test.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~tests_heading",
      display = string.format("%-40s %s", "[Tests]", "Test suites"),
      entry_type = "heading",
      ordinal = "tests",
      config = config,
    })
  end

  return entries
end

--- Format skill entry for display
--- @param skill table Skill data
--- @param indent_char string Tree character (├─ or └─)
--- @return string Formatted display string
local function format_skill(skill, indent_char)
  local prefix = skill.is_local and "*" or " "
  local description = skill.description or ""

  return string.format(
    "%s %s %-38s %s",
    prefix,
    indent_char,
    skill.name,
    description
  )
end

--- Format agent entry for display
--- @param agent table Agent data
--- @param indent_char string Tree character (├─ or └─)
--- @return string Formatted display string
local function format_agent(agent, indent_char)
  local prefix = agent.is_local and "*" or " "
  local description = agent.description or ""

  return string.format(
    "%s %s %-38s %s",
    prefix,
    indent_char,
    agent.name,
    description
  )
end

--- Create entries for skills section
--- @param structure table Extended structure from parser
--- @param config table|nil Picker configuration for threading to heading entries
--- @return table Array of entries
function M.create_skills_entries(structure, config)
  local entries = {}
  local skills = structure.skills or {}

  if #skills > 0 then
    table.sort(skills, function(a, b) return a.name < b.name end)

    for i, skill in ipairs(skills) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)

      table.insert(entries, {
        display = format_skill(skill, indent_char),
        entry_type = "skill",
        name = skill.name,
        description = skill.description,
        allowed_tools = skill.allowed_tools,
        context = skill.context,
        filepath = skill.filepath,
        dirname = skill.dirname,
        is_local = skill.is_local,
        ordinal = "zzzz_skill_" .. skill.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~skills_heading",
      display = string.format("%-40s %s", "[Skills]", "Model-invoked capabilities"),
      entry_type = "heading",
      ordinal = "skills",
      config = config,
    })
  end

  return entries
end

--- Create entries for agents section
--- @param structure table Extended structure from parser
--- @param config table|nil Picker configuration for threading to heading entries
--- @return table Array of entries
function M.create_agents_entries(structure, config)
  local entries = {}
  local agents = structure.agents or {}

  if #agents > 0 then
    table.sort(agents, function(a, b) return a.name < b.name end)

    for i, agent in ipairs(agents) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)

      table.insert(entries, {
        display = format_agent(agent, indent_char),
        entry_type = "agent",
        name = agent.name,
        description = agent.description,
        filepath = agent.filepath,
        is_local = agent.is_local,
        ordinal = "zzzz_agent_" .. agent.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~agents_heading",
      display = string.format("%-40s %s", "[Agents]", "AI agent definitions"),
      entry_type = "heading",
      ordinal = "agents",
      config = config,
    })
  end

  return entries
end

--- Format root file entry for display
--- @param root_file table Root file data
--- @param indent_char string Tree character (├─ or └─)
--- @return string Formatted display string
local function format_root_file(root_file, indent_char)
  local prefix = root_file.is_local and "*" or " "
  local description = root_file.description or ""

  return string.format(
    "%s %s %-38s %s",
    prefix,
    indent_char,
    root_file.name,
    description
  )
end

--- Create entries for root files section
--- @param structure table Extended structure from parser
--- @param config table|nil Picker configuration for threading to heading entries
--- @return table Array of entries
function M.create_root_files_entries(structure, config)
  local entries = {}
  local root_files = structure.root_files or {}

  if #root_files > 0 then
    table.sort(root_files, function(a, b) return a.name < b.name end)

    for i, root_file in ipairs(root_files) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)

      table.insert(entries, {
        display = format_root_file(root_file, indent_char),
        entry_type = "root_file",
        name = root_file.name,
        description = root_file.description,
        filepath = root_file.filepath,
        is_local = root_file.is_local,
        ordinal = "zzzz_root_file_" .. root_file.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~root_files_heading",
      display = string.format("%-40s %s", "[Root Files]", "Configuration files"),
      entry_type = "heading",
      ordinal = "root_files",
      config = config,
    })
  end

  return entries
end

--- Create entries for hooks section
--- @param structure table Extended structure from parser
--- @param config table|nil Picker configuration for threading to heading entries
--- @return table Array of entries
function M.create_hooks_entries(structure, config)
  local entries = {}
  local hook_events = structure.hook_events or {}
  local hooks = structure.hooks or {}
  local event_is_local_map = structure.event_is_local or {}

  if vim.tbl_count(hook_events) > 0 then
    local sorted_event_names = {}
    for event_name, _ in pairs(hook_events) do
      table.insert(sorted_event_names, event_name)
    end
    table.sort(sorted_event_names)

    for i, event_name in ipairs(sorted_event_names) do
      local event_hook_names = hook_events[event_name]

      local event_hooks = {}
      for _, hook_name in ipairs(event_hook_names) do
        for _, hook in ipairs(hooks) do
          if hook.name == hook_name then
            table.insert(event_hooks, hook)
            break
          end
        end
      end

      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)

      -- Get event-level locality
      local is_event_local = event_is_local_map[event_name]

      table.insert(entries, {
        name = event_name,
        display = format_hook_event(event_name, indent_char, event_hooks, is_event_local),
        is_primary = true,
        entry_type = "hook_event",
        hooks = event_hooks,
        is_event_local = is_event_local,
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~hooks_heading",
      display = string.format("%-40s %s", "[Hook Events]", "Event-triggered scripts"),
      entry_type = "heading",
      ordinal = "hooks",
      config = config,
    })
  end

  return entries
end

--- Create entries for commands section
--- @param structure table Extended structure from parser
--- @param config table|nil Picker configuration for threading to heading entries
--- @return table Array of entries
function M.create_commands_entries(structure, config)
  local entries = {}

  local sorted_primary_names = {}
  for primary_name, _ in pairs(structure.primary_commands) do
    table.insert(sorted_primary_names, primary_name)
  end
  table.sort(sorted_primary_names)

  for _, primary_name in ipairs(sorted_primary_names) do
    local primary_data = structure.primary_commands[primary_name]
    local primary_command = primary_data.command
    local dependents = primary_data.dependents

    -- Insert dependents
    for i, dep in ipairs(dependents) do
      local is_last = (i == #dependents)
      local tree_char = is_last and "└─" or "├─"

      table.insert(entries, {
        name = dep.name,
        display = format_command(dep, tree_char, true),
        command = dep,
        parent_command = primary_command,
        is_primary = false,
        entry_type = "command",
        ordinal = "command_" .. primary_name .. "_dep_" .. dep.name
      })
    end

    -- Insert primary command
    local has_children = #dependents > 0
    local tree_char = has_children and "├─" or "└─"

    table.insert(entries, {
      name = primary_command.name,
      display = format_command(primary_command, tree_char, false),
      command = primary_command,
      is_primary = true,
      entry_type = "command",
      ordinal = "command_" .. primary_name
    })
  end

  table.insert(entries, {
    is_heading = true,
    name = "~~~commands_heading",
    display = string.format("%-40s %s", "[Commands]", "Slash commands"),
    entry_type = "heading",
    ordinal = "commands",
    config = config,
  })

  return entries
end

--- Create entries for extensions section
--- @param config table|nil Picker configuration with extensions_module
--- @return table Array of entries
function M.create_extensions_entries(config)
  local entries = {}

  -- Get extensions module from config or default to claude
  local extensions_module = config and config.extensions_module or "neotex.plugins.ai.claude.extensions"

  -- Try to load extensions module
  local ok, extensions = pcall(require, extensions_module)
  if not ok then
    return entries
  end

  local available = extensions.list_available()
  if #available == 0 then
    return entries
  end

  -- Sort by name
  table.sort(available, function(a, b) return a.name < b.name end)

  for i, ext in ipairs(available) do
    local is_first = (i == 1)
    local indent_char = helpers.get_tree_char(is_first)

    -- Asterisk prefix for active extensions (loaded and current)
    local prefix = (ext.status == "active") and "*" or " "

    local status_indicator
    if ext.status == "active" then
      status_indicator = "[active]"
    elseif ext.status == "update-available" then
      status_indicator = "[update]"
    else
      status_indicator = "[inactive]"
    end

    local display = string.format(
      "%s %s %-28s %-10s %s",
      prefix,
      indent_char,
      ext.name,
      status_indicator,
      ext.description or ""
    )

    table.insert(entries, {
      display = display,
      entry_type = "extension",
      name = ext.name,
      description = ext.description,
      status = ext.status,
      version = ext.version,
      language = ext.language,
      ordinal = "zzzz_extension_" .. ext.name,
    })
  end

  if #entries > 0 then
    table.insert(entries, {
      is_heading = true,
      name = "~~~extensions_heading",
      display = string.format("%-40s %s", "[Extensions]", "Domain-specific capability packs"),
      entry_type = "heading",
      ordinal = "extensions"
    })
  end

  return entries
end

--- Create special entries (help and load core agent system)
--- @param config table|nil Picker configuration for threading to previewer
--- @return table Array of entries
function M.create_special_entries(config)
  local entries = {}

  table.insert(entries, {
    is_load_all = true,
    name = "~~~load_all",
    display = string.format(
      "%-40s %s",
      "[Load Core Agent System]",
      "Sync core system artifacts (excludes extensions)"
    ),
    command = nil,
    entry_type = "special",
    config = config,  -- Thread config for previewer access
  })

  table.insert(entries, {
    is_help = true,
    name = "~~~help",
    display = string.format(
      "%-40s %s",
      "[Keyboard Shortcuts]",
      "Help"
    ),
    command = nil,
    entry_type = "special",
    config = config,  -- Thread config for previewer access
  })

  return entries
end

--- Create all picker entries from structure
--- Insertion order is REVERSED for descending sort: last inserted appears at TOP
--- @param structure table Extended structure from parser.get_extended_structure()
--- @param config table|nil Picker configuration from shared.picker.config
--- @return table Array of entries for telescope
function M.create_picker_entries(structure, config)
  local all_entries = {}

  -- Insert in reverse order (last inserted appears first with descending sort)

  -- 1. Special entries (appear at bottom)
  local special = M.create_special_entries(config)
  for _, entry in ipairs(special) do
    table.insert(all_entries, entry)
  end

  -- 2. Extensions section (after Load All)
  local ext_entries = M.create_extensions_entries(config)
  for _, entry in ipairs(ext_entries) do
    table.insert(all_entries, entry)
  end

  -- 3. Docs section
  local docs = M.create_docs_entries(config)
  for _, entry in ipairs(docs) do
    table.insert(all_entries, entry)
  end

  -- 4. Context section
  local context = M.create_context_entries(config)
  for _, entry in ipairs(context) do
    table.insert(all_entries, entry)
  end

  -- 5. Lib section
  local lib = M.create_lib_entries(config)
  for _, entry in ipairs(lib) do
    table.insert(all_entries, entry)
  end

  -- 4. Templates section
  local templates = M.create_templates_entries(config)
  for _, entry in ipairs(templates) do
    table.insert(all_entries, entry)
  end

  -- 5. Scripts section
  local scripts = M.create_scripts_entries(config)
  for _, entry in ipairs(scripts) do
    table.insert(all_entries, entry)
  end

  -- 6. Tests section
  local tests = M.create_tests_entries(config)
  for _, entry in ipairs(tests) do
    table.insert(all_entries, entry)
  end

  -- 7. Rules section
  local rules = M.create_rules_entries(config)
  for _, entry in ipairs(rules) do
    table.insert(all_entries, entry)
  end

  -- 8. Memory section
  local memories = M.create_memory_entries(config)
  for _, entry in ipairs(memories) do
    table.insert(all_entries, entry)
  end

  -- 9. Hooks section
  local hooks = M.create_hooks_entries(structure, config)
  for _, entry in ipairs(hooks) do
    table.insert(all_entries, entry)
  end

  -- 8. Skills section
  local skills = M.create_skills_entries(structure, config)
  for _, entry in ipairs(skills) do
    table.insert(all_entries, entry)
  end

  -- 9. Agents section
  local agents = M.create_agents_entries(structure, config)
  for _, entry in ipairs(agents) do
    table.insert(all_entries, entry)
  end

  -- 10. Root Files section (between Agents and Commands)
  local root_files = M.create_root_files_entries(structure, config)
  for _, entry in ipairs(root_files) do
    table.insert(all_entries, entry)
  end

  -- 11. Commands section (appears at top)
  local commands = M.create_commands_entries(structure, config)
  for _, entry in ipairs(commands) do
    table.insert(all_entries, entry)
  end

  return all_entries
end

return M
