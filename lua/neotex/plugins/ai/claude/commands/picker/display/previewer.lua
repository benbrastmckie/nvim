-- neotex.plugins.ai.claude.commands.picker.display.previewer
-- Custom previewer for telescope picker with rich metadata display

local M = {}

-- Dependencies
local previewers = require("telescope.previewers")

-- Maximum lines for doc previews (to avoid performance issues)
local MAX_PREVIEW_LINES = 150

--- Helper function to scan directory for sync info
--- @param global_dir string Global directory
--- @param project_dir string Project directory
--- @param subdir string Subdirectory path
--- @param extension string File extension pattern
--- @return table Array of file sync info
local function scan_directory_for_sync(global_dir, project_dir, subdir, extension)
  local global_path = global_dir .. "/.claude/" .. subdir
  local local_path = project_dir .. "/.claude/" .. subdir
  local global_files = vim.fn.glob(global_path .. "/" .. extension, false, true)

  local files = {}
  for _, global_file in ipairs(global_files) do
    local filename = vim.fn.fnamemodify(global_file, ":t")
    local local_file = local_path .. "/" .. filename

    local action = vim.fn.filereadable(local_file) == 1 and "replace" or "copy"
    table.insert(files, {
      name = filename,
      global_path = global_file,
      local_path = local_file,
      action = action,
    })
  end

  return files
end

--- Count operations by action type
--- @param files table Array of file sync info
--- @return number copy_count Number of copy operations
--- @return number replace_count Number of replace operations
local function count_actions(files)
  local copy_count = 0
  local replace_count = 0
  for _, file in ipairs(files) do
    if file.action == "copy" then
      copy_count = copy_count + 1
    else
      replace_count = replace_count + 1
    end
  end
  return copy_count, replace_count
end

--- Create preview for heading entries (category headers)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_heading(self, entry)
  local ordinal = entry.value.ordinal or "Unknown"
  local readme_path = nil

  local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local local_path = vim.fn.getcwd() .. "/.claude/" .. ordinal .. "/README.md"
  local global_path = scan_mod.get_global_dir() .. "/.claude/" .. ordinal .. "/README.md"

  if vim.fn.filereadable(local_path) == 1 then
    readme_path = local_path
  elseif vim.fn.filereadable(global_path) == 1 then
    readme_path = global_path
  end

  if readme_path then
    local success, file = pcall(io.open, readme_path, "r")
    if success and file then
      local lines = {}
      local line_count = 0
      for line in file:lines() do
        table.insert(lines, line)
        line_count = line_count + 1
        if line_count >= MAX_PREVIEW_LINES then
          break
        end
      end
      file:close()

      local total_lines = #vim.fn.readfile(readme_path)
      if total_lines > MAX_PREVIEW_LINES then
        table.insert(lines, "")
        table.insert(lines, "...")
        table.insert(lines, string.format(
          "[Preview truncated - showing first %d of %d lines]",
          MAX_PREVIEW_LINES, total_lines
        ))
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      return
    end
  end

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
    "Category: " .. ordinal,
    "",
    entry.value.display or "",
    "",
    "This is a category heading to organize artifacts in the picker.",
    "Navigate past this entry to view items in this category."
  })
end

--- Create preview for help entry (keyboard shortcuts)
--- @param self table Telescope previewer state
local function preview_help(self)
  local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local global_dir = scan_mod.get_global_dir()

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
    "Keyboard Shortcuts:",
    "",
    "Commands:",
    "  Enter (CR)     - Execute action for selected item",
    "                   Commands: Insert into Claude Code",
    "                   All others: Open file for editing",
    "  Ctrl-n         - Create new command (opens Claude Code with prompt)",
    "  Ctrl-l         - Load artifact locally (copies with dependencies)",
    "  Ctrl-s         - Save local artifact to global (share across projects)",
    "  Ctrl-e         - Edit artifact file (all types)",
    "",
    "Navigation:",
    "  Ctrl-j/k       - Move selection down/up",
    "  Escape         - Close picker",
    "",
    "Preview Navigation:",
    "  Ctrl-u         - Scroll preview up (half page)",
    "  Ctrl-d         - Scroll preview down (half page)",
    "  Ctrl-b         - Scroll preview up (full page)",
    "  Ctrl-f         - Scroll preview down (full page)",
    "",
    "Artifact Types:",
    "  [Commands]     - Claude Code slash commands",
    "    Primary        - Main workflow commands",
    "    └─ command     - Supporting commands called by primary",
    "",
    "  [Hook Events]  - Event triggers for hooks",
    "    Hook files displayed in metadata preview area",
    "",
    "  [Skills]       - SKILL.md files for model-invoked capabilities",
    "",
    "  [Docs]         - Integration guides and documentation",
    "",
    "  [Lib]          - Utility libraries for sourcing",
    "",
    "  [Scripts]      - Standalone CLI tools",
    "",
    "  [Tests]        - Test suites",
    "",
    "Indicators:",
    "  *       - Artifact defined locally in project (.claude/)",
    "            Otherwise a global artifact from " .. global_dir .. "/.claude/",
    "",
    "File Operations:",
    "  Ctrl-l/u/s  - Commands, Hooks, Skills, Templates, Lib, Docs",
    "  Ctrl-e      - Edit file (all artifact types)",
    "                Preserves executable permissions for .sh files",
    "",
    "  [Load Core] - Batch synchronizes core system artifacts",
    "                (excludes extension-owned agents, skills, etc.)",
    "                Replaces local with global artifacts with the same",
    "                name while preserving local-only artifacts.",
    "",
    "Notes: All artifacts loaded from both project and global directories",
    "       Local artifacts override global ones from " .. global_dir .. "/"
  })
end

--- Create preview for Load All entry
--- @param self table Telescope previewer state
local function preview_load_all(self)
  local project_dir = vim.fn.getcwd()
  local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local global_dir = scan.get_global_dir()

  local commands = scan_directory_for_sync(global_dir, project_dir, "commands", "*.md")
  local hooks = scan_directory_for_sync(global_dir, project_dir, "hooks", "*.sh")
  local skills = scan_directory_for_sync(global_dir, project_dir, "skills", "*.md")
  local templates = scan_directory_for_sync(global_dir, project_dir, "templates", "*.yaml")
  local lib_utils = scan_directory_for_sync(global_dir, project_dir, "lib", "*.sh")
  local docs = scan_directory_for_sync(global_dir, project_dir, "docs", "*.md")
  local scripts = scan_directory_for_sync(global_dir, project_dir, "scripts", "*.sh")
  local tests = scan_directory_for_sync(global_dir, project_dir, "tests", "test_*.sh")
  local rules = scan_directory_for_sync(global_dir, project_dir, "rules", "*.md")
  local output = scan_directory_for_sync(global_dir, project_dir, "output", "*.md")
  local systemd_service = scan_directory_for_sync(global_dir, project_dir, "systemd", "*.service")
  local systemd_timer = scan_directory_for_sync(global_dir, project_dir, "systemd", "*.timer")
  local systemd = {}
  for _, file in ipairs(systemd_service) do
    table.insert(systemd, file)
  end
  for _, file in ipairs(systemd_timer) do
    table.insert(systemd, file)
  end
  local settings = scan_directory_for_sync(global_dir, project_dir, "", "settings.json")

  local cmd_copy, cmd_replace = count_actions(commands)
  local hook_copy, hook_replace = count_actions(hooks)
  local skill_copy, skill_replace = count_actions(skills)
  local tmpl_copy, tmpl_replace = count_actions(templates)
  local lib_copy, lib_replace = count_actions(lib_utils)
  local doc_copy, doc_replace = count_actions(docs)
  local script_copy, script_replace = count_actions(scripts)
  local test_copy, test_replace = count_actions(tests)
  local rule_copy, rule_replace = count_actions(rules)
  local out_copy, out_replace = count_actions(output)
  local sys_copy, sys_replace = count_actions(systemd)
  local set_copy, set_replace = count_actions(settings)

  local total_copy = cmd_copy + hook_copy + skill_copy + tmpl_copy + lib_copy +
                     doc_copy + script_copy + test_copy + rule_copy +
                     out_copy + sys_copy + set_copy
  local total_replace = cmd_replace + hook_replace + skill_replace + tmpl_replace +
                        lib_replace + doc_replace + script_replace + test_replace +
                        rule_replace + out_replace + sys_replace + set_replace

  local lines = {
    "Load All Artifacts",
    "",
    "This action will sync all artifacts from " .. global_dir .. "/.claude/ to your",
    "local project's .claude/ directory.",
    "",
  }

  if total_copy + total_replace > 0 then
    table.insert(lines, "**Operations by Type:**")
    table.insert(lines, string.format("  Commands:   %d new, %d replace", cmd_copy, cmd_replace))
    table.insert(lines, string.format("  Hooks:      %d new, %d replace", hook_copy, hook_replace))
    table.insert(lines, string.format("  Skills:     %d new, %d replace", skill_copy, skill_replace))
    table.insert(lines, string.format("  Templates:  %d new, %d replace", tmpl_copy, tmpl_replace))
    table.insert(lines, string.format("  Lib:        %d new, %d replace", lib_copy, lib_replace))
    table.insert(lines, string.format("  Docs:       %d new, %d replace", doc_copy, doc_replace))
    table.insert(lines, string.format("  Scripts:    %d new, %d replace", script_copy, script_replace))
    table.insert(lines, string.format("  Tests:      %d new, %d replace", test_copy, test_replace))
    table.insert(lines, string.format("  Rules:      %d new, %d replace", rule_copy, rule_replace))
    table.insert(lines, string.format("  Output:     %d new, %d replace", out_copy, out_replace))
    table.insert(lines, string.format("  Systemd:    %d new, %d replace", sys_copy, sys_replace))
    table.insert(lines, string.format("  Settings:   %d new, %d replace", set_copy, set_replace))
    table.insert(lines, "")
    table.insert(lines, string.format("**Total:** %d new, %d replace", total_copy, total_replace))
    table.insert(lines, "")
    table.insert(lines, "**Note:** Local-only artifacts will not be affected.")
    table.insert(lines, "          Execute permissions preserved for .sh files.")
  else
    table.insert(lines, "**All artifacts already in sync!**")
  end

  table.insert(lines, "")
  table.insert(lines, "**Current Status:**")
  table.insert(lines, string.format("  Project directory: %s", project_dir))
  table.insert(lines, "  Global directory:  " .. global_dir .. "/.claude/")
  table.insert(lines, "")
  table.insert(lines, "Press Enter to proceed with confirmation, or Escape to cancel.")

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
end

--- Create preview for skill entries
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_skill(self, entry)
  local lines = {
    "# Skill: " .. entry.value.name,
    "",
  }

  if entry.value.description and entry.value.description ~= "" then
    table.insert(lines, "**Description**: " .. entry.value.description)
    table.insert(lines, "")
  end

  if entry.value.allowed_tools and #entry.value.allowed_tools > 0 then
    table.insert(lines, "**Allowed Tools**:")
    table.insert(lines, table.concat(entry.value.allowed_tools, ", "))
    table.insert(lines, "")
  end

  if entry.value.context and #entry.value.context > 0 then
    table.insert(lines, "**Context Files**:")
    for _, ctx in ipairs(entry.value.context) do
      table.insert(lines, "  - " .. ctx)
    end
    table.insert(lines, "")
  end

  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, "**Directory**: " .. (entry.value.dirname or "Unknown"))
  table.insert(lines, "**File**: " .. (entry.value.filepath or "Unknown"))
  table.insert(lines, "**Status**: " .. (entry.value.is_local and "[Local]" or "[Global]"))

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create preview for hook event entries
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_hook_event(self, entry)
  local event_descriptions = {
    Stop = "Triggered after command completion",
    SessionStart = "When Claude Code session begins",
    SessionEnd = "When Claude Code session ends",
    SubagentStop = "After subagent completes",
    Notification = "Permission or idle notification events",
    PreToolUse = "Before tool execution",
    PostToolUse = "After tool execution",
    UserPromptSubmit = "When user prompt submitted",
    PreCompact = "Before context compaction",
  }

  local lines = {
    "# Hook Event: " .. entry.value.name,
    "",
    "**Description**: " .. (event_descriptions[entry.value.name] or "Unknown event"),
    "",
    "**Registered Hooks**: " .. #entry.value.hooks .. " hook(s)",
    "",
    "Hooks:",
  }
  for _, hook in ipairs(entry.value.hooks) do
    table.insert(lines, "- " .. hook.name .. " (" .. hook.filepath .. ")")
  end

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create preview for script entries (shell scripts)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_script(self, entry)
  local filepath = entry.value.filepath
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not found"})
    return
  end

  local lines = vim.fn.readfile(filepath)

  table.insert(lines, "")
  table.insert(lines, "# " .. string.rep("=", 60))
  table.insert(lines, "")
  table.insert(lines, "# File: " .. entry.value.name)

  local perms = vim.fn.getfperm(filepath)
  table.insert(lines, "# Permissions: " .. (perms or "N/A"))

  table.insert(lines, "# Status: " .. (entry.value.is_local and "[Local]" or "[Global]"))
  table.insert(lines, "# Action: Run with <C-r> (prompts for arguments)")

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "sh")
end

--- Create preview for test entries (shell scripts)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_test(self, entry)
  local filepath = entry.value.filepath
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not found"})
    return
  end

  local lines = vim.fn.readfile(filepath)

  table.insert(lines, "")
  table.insert(lines, "# " .. string.rep("=", 60))
  table.insert(lines, "")
  table.insert(lines, "# File: " .. entry.value.name)

  local perms = vim.fn.getfperm(filepath)
  table.insert(lines, "# Permissions: " .. (perms or "N/A"))

  table.insert(lines, "# Status: " .. (entry.value.is_local and "[Local]" or "[Global]"))
  table.insert(lines, "# Action: Run with <C-t> (executes test)")

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "sh")
end

--- Create preview for lib entries (shell scripts)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_lib(self, entry)
  local filepath = entry.value.filepath
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not found"})
    return
  end

  local lines = vim.fn.readfile(filepath)

  table.insert(lines, "")
  table.insert(lines, "# " .. string.rep("=", 60))
  table.insert(lines, "")
  table.insert(lines, "# File: " .. entry.value.name)

  local perms = vim.fn.getfperm(filepath)
  table.insert(lines, "# Permissions: " .. (perms or "N/A"))

  table.insert(lines, "# Status: " .. (entry.value.is_local and "[Local]" or "[Global]"))

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "sh")
end

--- Create preview for template entries (YAML files)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_template(self, entry)
  local filepath = entry.value.filepath
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not found"})
    return
  end

  local lines = vim.fn.readfile(filepath)

  table.insert(lines, "")
  table.insert(lines, "# " .. string.rep("=", 60))
  table.insert(lines, "")
  table.insert(lines, "# File: " .. entry.value.name)
  table.insert(lines, "# Status: " .. (entry.value.is_local and "[Local]" or "[Global]"))

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "yaml")
end

--- Create preview for doc entries (markdown files)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_doc(self, entry)
  local filepath = entry.value.filepath
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not found"})
    return
  end

  local success, file = pcall(io.open, filepath, "r")
  if not success or not file then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Failed to open file"})
    return
  end

  local lines = {}
  local line_count = 0
  for line in file:lines() do
    table.insert(lines, line)
    line_count = line_count + 1
    if line_count >= MAX_PREVIEW_LINES then
      break
    end
  end
  file:close()

  local total_lines = #vim.fn.readfile(filepath)
  if total_lines > MAX_PREVIEW_LINES then
    table.insert(lines, "")
    table.insert(lines, "...")
    table.insert(lines, string.format(
      "[Preview truncated - showing first %d of %d lines]",
      MAX_PREVIEW_LINES, total_lines
    ))
  end

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, "**File**: " .. entry.value.name)
  table.insert(lines, "**Status**: " .. (entry.value.is_local and "[Local]" or "[Global]"))

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create preview for command entries
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_command(self, entry)
  local command = entry.value.command
  if not command then
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"No command data available"})
    return
  end

  local lines = {}

  table.insert(lines, string.format("# %s", command.name))

  table.insert(lines, "")
  table.insert(lines, "**Type**: " .. (command.command_type == "primary" and "Primary Command" or "Dependent Command"))

  if entry.value.parent then
    table.insert(lines, "**Parent**: " .. entry.value.parent)
  end

  if command.description and command.description ~= "" then
    table.insert(lines, "")
    table.insert(lines, "**Description**:")
    table.insert(lines, command.description)
  end

  if command.argument_hint and command.argument_hint ~= "" then
    table.insert(lines, "")
    table.insert(lines, "**Usage**: /" .. command.name .. " " .. command.argument_hint)
  end

  if command.command_type == "primary" and #command.dependent_commands > 0 then
    table.insert(lines, "")
    table.insert(lines, "**Dependent Commands**:")
    for _, dep in ipairs(command.dependent_commands) do
      table.insert(lines, "  - " .. dep)
    end
  elseif command.command_type == "dependent" and #command.parent_commands > 0 then
    table.insert(lines, "")
    table.insert(lines, "**Used By**:")
    for _, parent in ipairs(command.parent_commands) do
      table.insert(lines, "  - " .. parent)
    end
  end

  if command.allowed_tools and type(command.allowed_tools) == "table" and #command.allowed_tools > 0 then
    table.insert(lines, "")
    table.insert(lines, "**Allowed Tools**:")
    table.insert(lines, table.concat(command.allowed_tools, ", "))
  end

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "**File**: " .. (command.filepath or "Unknown"))
  table.insert(lines, "**Status**: " .. (command.is_local and "[Local]" or "[Global]"))

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create preview for extension entries
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_extension(self, entry)
  local ext = entry.value
  local lines = {
    "# " .. ext.name .. " v" .. (ext.version or "unknown"),
    "",
    "**Status**: " .. (ext.status or "unknown"),
    "**Language**: " .. (ext.language or "any"),
    "",
    "## Description",
    ext.description or "No description",
    "",
  }

  -- Try to get detailed info from extensions module
  local ok, extensions = pcall(require, "neotex.plugins.ai.claude.extensions")
  if ok then
    local details = extensions.get_details(ext.name)

    -- Provides section
    if details and details.provides then
      table.insert(lines, "## Provides")
      for category, items in pairs(details.provides) do
        if type(items) == "table" and #items > 0 then
          table.insert(lines, "")
          table.insert(lines, "### " .. category)
          for _, item in ipairs(items) do
            table.insert(lines, "- " .. item)
          end
        end
      end
    end

    -- MCP Servers section
    if details and details.mcp_servers then
      table.insert(lines, "")
      table.insert(lines, "## MCP Servers")
      for name, config in pairs(details.mcp_servers) do
        table.insert(lines, "- **" .. name .. "**: " .. config.command)
      end
    end

    -- Installed files (if active)
    if details and details.installed_files and #details.installed_files > 0 then
      table.insert(lines, "")
      table.insert(lines, "## Installed Files (" .. #details.installed_files .. ")")
      for i, file in ipairs(details.installed_files) do
        if i <= 10 then
          table.insert(lines, "- " .. file)
        end
      end
      if #details.installed_files > 10 then
        table.insert(lines, "- ... and " .. (#details.installed_files - 10) .. " more")
      end
    end

    -- Loaded at timestamp
    if details and details.loaded_at then
      table.insert(lines, "")
      table.insert(lines, "**Loaded**: " .. details.loaded_at)
    end
  end

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create preview for agent entries
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_agent(self, entry)
  local agent = entry.value
  local lines = {
    "# Agent: " .. agent.name,
    "",
  }

  if agent.description and agent.description ~= "" then
    table.insert(lines, "**Description**: " .. agent.description)
    table.insert(lines, "")
  end

  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, "**File**: " .. (agent.filepath or "Unknown"))
  table.insert(lines, "**Status**: " .. (agent.is_local and "[Local]" or "[Global]"))
  table.insert(lines, "")

  -- Try to read first lines of agent file for additional context
  local filepath = agent.filepath
  if filepath and vim.fn.filereadable(filepath) == 1 then
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Agent Definition")
    table.insert(lines, "")

    local success, file = pcall(io.open, filepath, "r")
    if success and file then
      local line_count = 0
      for line in file:lines() do
        table.insert(lines, line)
        line_count = line_count + 1
        if line_count >= MAX_PREVIEW_LINES then
          break
        end
      end
      file:close()

      local total_lines = #vim.fn.readfile(filepath)
      if total_lines > MAX_PREVIEW_LINES then
        table.insert(lines, "")
        table.insert(lines, "...")
        table.insert(lines, string.format(
          "[Preview truncated - showing first %d of %d lines]",
          MAX_PREVIEW_LINES, total_lines
        ))
      end
    end
  end

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create preview for root_file entries
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_root_file(self, entry)
  local root_file = entry.value
  local filepath = root_file.filepath

  local lines = {
    "# " .. root_file.name,
    "",
  }

  if root_file.description and root_file.description ~= "" then
    table.insert(lines, "**Description**: " .. root_file.description)
    table.insert(lines, "")
  end

  table.insert(lines, "**Path**: " .. (filepath or "Unknown"))
  table.insert(lines, "**Status**: " .. (root_file.is_local and "[Local]" or "[Global]"))
  table.insert(lines, "")

  -- Read and display file contents
  if filepath and vim.fn.filereadable(filepath) == 1 then
    table.insert(lines, "---")
    table.insert(lines, "")

    local success, file = pcall(io.open, filepath, "r")
    if success and file then
      local line_count = 0
      for line in file:lines() do
        table.insert(lines, line)
        line_count = line_count + 1
        if line_count >= MAX_PREVIEW_LINES then
          break
        end
      end
      file:close()

      local total_lines = #vim.fn.readfile(filepath)
      if total_lines > MAX_PREVIEW_LINES then
        table.insert(lines, "")
        table.insert(lines, "...")
        table.insert(lines, string.format(
          "[Preview truncated - showing first %d of %d lines]",
          MAX_PREVIEW_LINES, total_lines
        ))
      end
    else
      table.insert(lines, "Failed to read file")
    end
  else
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "File not found or not readable")
  end

  -- Determine appropriate filetype for syntax highlighting
  local ext = vim.fn.fnamemodify(filepath or "", ":e")
  local filetype = "text"
  if ext == "md" then
    filetype = "markdown"
  elseif ext == "json" then
    filetype = "json"
  elseif ext == "yaml" or ext == "yml" then
    filetype = "yaml"
  elseif ext == "lua" then
    filetype = "lua"
  end

  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", filetype)
end

--- Create custom previewer for command documentation
--- @return table Telescope previewer
function M.create_command_previewer()
  return previewers.new_buffer_previewer({
    title = "Command Details",
    define_preview = function(self, entry, status)
      if entry.value.is_heading then
        preview_heading(self, entry)
      elseif entry.value.is_help then
        preview_help(self)
      elseif entry.value.is_load_all then
        preview_load_all(self)
      elseif entry.value.entry_type == "skill" then
        preview_skill(self, entry)
      elseif entry.value.entry_type == "hook_event" then
        preview_hook_event(self, entry)
      elseif entry.value.entry_type == "lib" then
        preview_lib(self, entry)
      elseif entry.value.entry_type == "script" then
        preview_script(self, entry)
      elseif entry.value.entry_type == "test" then
        preview_test(self, entry)
      elseif entry.value.entry_type == "template" then
        preview_template(self, entry)
      elseif entry.value.entry_type == "doc" then
        preview_doc(self, entry)
      elseif entry.value.entry_type == "command" then
        preview_command(self, entry)
      elseif entry.value.entry_type == "extension" then
        preview_extension(self, entry)
      elseif entry.value.entry_type == "agent" then
        preview_agent(self, entry)
      elseif entry.value.entry_type == "root_file" then
        preview_root_file(self, entry)
      else
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Unknown entry type"})
      end
    end,
  })
end

return M
