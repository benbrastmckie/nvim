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
--- @return string Formatted display string
local function format_hook_event(event_name, indent_char, event_hooks)
  local has_local_hook = false
  if event_hooks then
    for _, hook in ipairs(event_hooks) do
      if hook.is_local then
        has_local_hook = true
        break
      end
    end
  end

  local prefix = has_local_hook and "*" or " "

  local descriptions = {
    Stop = "After command completion",
    SessionStart = "When session begins",
    SessionEnd = "When session ends",
    SubagentStop = "After subagent completes",
    Notification = "Permission/idle events",
    PreToolUse = "Before tool execution",
    PostToolUse = "After tool execution",
    UserPromptSubmit = "When prompt submitted",
    PreCompact = "Before context compaction",
  }

  return string.format(
    "%s  %s %-37s %s",
    prefix,
    indent_char,
    event_name,
    descriptions[event_name] or ""
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

--- Create entries for docs section
--- @return table Array of entries
function M.create_docs_entries()
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()

  local local_docs = scan.scan_directory(project_dir .. "/.claude/docs", "*.md")
  local global_docs = scan.scan_directory(global_dir .. "/.claude/docs", "*.md")
  local all_docs = scan.merge_artifacts(local_docs, global_docs)

  if #all_docs > 0 then
    table.sort(all_docs, function(a, b) return a.name < b.name end)

    for i, doc in ipairs(all_docs) do
      local is_first = (i == 1)
      local indent_char = helpers.get_tree_char(is_first)
      local description = metadata.parse_doc_description(doc.filepath)

      table.insert(entries, {
        display = helpers.format_display(
          doc.is_local and "*" or " ",
          " " .. indent_char,
          doc.name,
          description
        ),
        entry_type = "doc",
        name = doc.name,
        filepath = doc.filepath,
        is_local = doc.is_local,
        ordinal = "zzzz_doc_" .. doc.name
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~docs_heading",
      display = string.format("%-40s %s", "[Docs]", "Integration guides"),
      entry_type = "heading",
      ordinal = "docs"
    })
  end

  return entries
end

--- Create entries for lib section
--- @return table Array of entries
function M.create_lib_entries()
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()

  local local_lib = scan.scan_directory(project_dir .. "/.claude/lib", "*.sh")
  local global_lib = scan.scan_directory(global_dir .. "/.claude/lib", "*.sh")
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
      ordinal = "lib"
    })
  end

  return entries
end

--- Create entries for templates section
--- @return table Array of entries
function M.create_templates_entries()
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()

  local local_templates = scan.scan_directory(project_dir .. "/.claude/templates", "*.yaml")
  local global_templates = scan.scan_directory(global_dir .. "/.claude/templates", "*.yaml")
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
      ordinal = "templates"
    })
  end

  return entries
end

--- Create entries for scripts section
--- @return table Array of entries
function M.create_scripts_entries()
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()

  local local_scripts = scan.scan_directory(project_dir .. "/.claude/scripts", "*.sh")
  local global_scripts = scan.scan_directory(global_dir .. "/.claude/scripts", "*.sh")
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
      ordinal = "scripts"
    })
  end

  return entries
end

--- Create entries for tests section
--- @return table Array of entries
function M.create_tests_entries()
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()

  local local_tests = scan.scan_directory(project_dir .. "/.claude/tests", "test_*.sh")
  local global_tests = scan.scan_directory(global_dir .. "/.claude/tests", "test_*.sh")
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
      ordinal = "tests"
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
--- @return table Array of entries
function M.create_skills_entries(structure)
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
      ordinal = "skills"
    })
  end

  return entries
end

--- Create entries for agents section
--- @param structure table Extended structure from parser
--- @return table Array of entries
function M.create_agents_entries(structure)
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
      ordinal = "agents"
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
--- @return table Array of entries
function M.create_root_files_entries(structure)
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
      ordinal = "root_files"
    })
  end

  return entries
end

--- Create entries for hooks section
--- @param structure table Extended structure from parser
--- @return table Array of entries
function M.create_hooks_entries(structure)
  local entries = {}
  local hook_events = structure.hook_events or {}
  local hooks = structure.hooks or {}

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

      table.insert(entries, {
        name = event_name,
        display = format_hook_event(event_name, indent_char, event_hooks),
        is_primary = true,
        entry_type = "hook_event",
        hooks = event_hooks
      })
    end

    table.insert(entries, {
      is_heading = true,
      name = "~~~hooks_heading",
      display = string.format("%-40s %s", "[Hook Events]", "Event-triggered scripts"),
      entry_type = "heading",
      ordinal = "hooks"
    })
  end

  return entries
end

--- Create entries for commands section
--- @param structure table Extended structure from parser
--- @return table Array of entries
function M.create_commands_entries(structure)
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
    ordinal = "commands"
  })

  return entries
end

--- Create entries for extensions section
--- @return table Array of entries
function M.create_extensions_entries()
  local entries = {}

  -- Try to load extensions module
  local ok, extensions = pcall(require, "neotex.plugins.ai.claude.extensions")
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

    local status_indicator
    if ext.status == "active" then
      status_indicator = "[active]"
    elseif ext.status == "update-available" then
      status_indicator = "[update]"
    else
      status_indicator = "[inactive]"
    end

    local display = string.format(
      "  %s %-28s %-10s %s",
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

--- Create special entries (help and load all)
--- @return table Array of entries
function M.create_special_entries()
  local entries = {}

  table.insert(entries, {
    is_load_all = true,
    name = "~~~load_all",
    display = string.format(
      "%-40s %s",
      "[Load All Artifacts]",
      "Sync commands, hooks, skills, agents, docs, lib"
    ),
    command = nil,
    entry_type = "special"
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
    entry_type = "special"
  })

  return entries
end

--- Create all picker entries from structure
--- Insertion order is REVERSED for descending sort: last inserted appears at TOP
--- @param structure table Extended structure from parser.get_extended_structure()
--- @return table Array of entries for telescope
function M.create_picker_entries(structure)
  local all_entries = {}

  -- Insert in reverse order (last inserted appears first with descending sort)

  -- 1. Special entries (appear at bottom)
  local special = M.create_special_entries()
  for _, entry in ipairs(special) do
    table.insert(all_entries, entry)
  end

  -- 2. Extensions section (after Load All)
  local ext_entries = M.create_extensions_entries()
  for _, entry in ipairs(ext_entries) do
    table.insert(all_entries, entry)
  end

  -- 3. Docs section
  local docs = M.create_docs_entries()
  for _, entry in ipairs(docs) do
    table.insert(all_entries, entry)
  end

  -- 3. Lib section
  local lib = M.create_lib_entries()
  for _, entry in ipairs(lib) do
    table.insert(all_entries, entry)
  end

  -- 4. Templates section
  local templates = M.create_templates_entries()
  for _, entry in ipairs(templates) do
    table.insert(all_entries, entry)
  end

  -- 5. Scripts section
  local scripts = M.create_scripts_entries()
  for _, entry in ipairs(scripts) do
    table.insert(all_entries, entry)
  end

  -- 6. Tests section
  local tests = M.create_tests_entries()
  for _, entry in ipairs(tests) do
    table.insert(all_entries, entry)
  end

  -- 7. Hooks section
  local hooks = M.create_hooks_entries(structure)
  for _, entry in ipairs(hooks) do
    table.insert(all_entries, entry)
  end

  -- 8. Skills section
  local skills = M.create_skills_entries(structure)
  for _, entry in ipairs(skills) do
    table.insert(all_entries, entry)
  end

  -- 9. Agents section
  local agents = M.create_agents_entries(structure)
  for _, entry in ipairs(agents) do
    table.insert(all_entries, entry)
  end

  -- 10. Root Files section (between Agents and Commands)
  local root_files = M.create_root_files_entries(structure)
  for _, entry in ipairs(root_files) do
    table.insert(all_entries, entry)
  end

  -- 11. Commands section (appears at top)
  local commands = M.create_commands_entries(structure)
  for _, entry in ipairs(commands) do
    table.insert(all_entries, entry)
  end

  return all_entries
end

return M
