-- neotex.plugins.ai.claude.commands.picker.display.previewer
-- Custom previewer for telescope picker with rich metadata display

local M = {}

-- Dependencies
local previewers = require("telescope.previewers")

-- Maximum lines for doc previews (to avoid performance issues)
local MAX_PREVIEW_LINES = 150

--- Create preview for heading entries (category headers)
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_heading(self, entry)
  local ordinal = entry.value.ordinal or "Unknown"
  local readme_path = nil

  local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local entry_config = entry.value.config
  local base_dir = (entry_config and entry_config.base_dir) or ".claude"
  local global_dir = (entry_config and entry_config.global_source_dir) or scan_mod.get_global_dir()
  local local_path = vim.fn.getcwd() .. "/" .. base_dir .. "/" .. ordinal .. "/README.md"
  local global_path = global_dir .. "/" .. base_dir .. "/" .. ordinal .. "/README.md"

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
--- @param config table|nil Picker configuration with base_dir
local function preview_help(self, config)
  local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local global_dir = scan_mod.get_global_dir()
  local base_dir = (config and config.base_dir) or ".claude"

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
    "  *       - Artifact defined locally in project (" .. base_dir .. "/)",
    "            Otherwise a global artifact from " .. global_dir .. "/" .. base_dir .. "/",
    "",
    "File Operations:",
    "  Ctrl-l/u/s  - Commands, Hooks, Skills, Templates, Lib, Docs",
    "  Ctrl-e      - Edit file (all artifact types)",
    "                Preserves executable permissions for .sh files",
    "",
    "  [Reload All]  - Force-resyncs every currently loaded extension",
    "                  in dependency order (non-destructive).",
    "  [Regenerate]  - Wipes " .. base_dir .. "/ and rebuilds it from the",
    "                  surviving extension manifest (destructive; snapshots",
    "                  and restores settings.local.json and .syncprotect",
    "                  paths automatically). Confirmation required.",
    "",
    "Notes: All artifacts loaded from both project and global directories",
    "       Local artifacts override global ones from " .. global_dir .. "/"
  })
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
  local registry = require("neotex.plugins.ai.claude.commands.picker.artifacts.registry")

  local long_desc = "Unknown event"
  if registry.HOOK_EVENT_DESCRIPTIONS and registry.HOOK_EVENT_DESCRIPTIONS[entry.value.name] then
    long_desc = registry.HOOK_EVENT_DESCRIPTIONS[entry.value.name].long
  end

  local hooks = entry.value.hooks or {}
  local lines = {
    "# Hook Event: " .. entry.value.name,
    "",
    "**Description**: " .. long_desc,
    "",
    "**Registered Hooks**: " .. #hooks .. " hook(s)",
    "",
    "Hooks:",
  }
  for _, hook in ipairs(hooks) do
    if hook.is_inline then
      -- Display inline command snippet instead of filepath
      table.insert(lines, "- " .. hook.name .. " [Inline command]: " .. (hook.command or ""))
    else
      table.insert(lines, "- " .. hook.name .. " (" .. (hook.filepath or "") .. ")")
    end
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
  local lang = (type(ext.language) == "string") and ext.language or "any"
  local lines = {
    "# " .. ext.name .. " v" .. (ext.version or "unknown"),
    "",
    "**Status**: " .. (ext.status or "unknown"),
    "**Language**: " .. lang,
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

--- Create preview for a special entry (a picker-shipped bulk operation such as [Reload All],
--- [Regenerate], or [Global Update]) that carries a per-entry `description`/`detail` payload.
--- This is ONE shared branch for every `entry_type == "special"` entry that is not `is_help`
--- (the `is_help` entry is intercepted earlier in the dispatch chain and keeps its own
--- `preview_help` rendering) -- see entries.lua's SYNC OBLIGATION comment at the special-entry
--- definitions: the `display` one-liner, this preview payload, and the implementation they both
--- describe must always agree.
--- @param self table Telescope previewer state
--- @param entry table Telescope entry
local function preview_special(self, entry)
  local value = entry.value
  local lines = {
    "# " .. (value.title or value.name or "Special Entry"),
    "",
    value.description or "(no description provided)",
    "",
  }
  if value.detail then
    for _, line in ipairs(value.detail) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "(no detail payload provided for this special entry)")
  end
  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
end

--- Create custom previewer for command documentation
--- @return table Telescope previewer
function M.create_command_previewer()
  return previewers.new_buffer_previewer({
    title = "Command Details",
    define_preview = function(self, entry, status)
      -- Extract config from entry value for config-aware preview functions
      local entry_config = entry.value.config

      if entry.value.is_heading then
        preview_heading(self, entry)
      elseif entry.value.is_help then
        preview_help(self, entry_config)
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
      elseif entry.value.entry_type == "special" then
        -- Shared branch for every special entry that is not is_help (intercepted above):
        -- [Reload All], [Regenerate], and any future bulk-operation entry (e.g. Global Update)
        -- that carries the same description/detail payload shape. See Decision 2 at this
        -- dispatch chain's call site and the SYNC OBLIGATION comment in entries.lua.
        preview_special(self, entry)
      else
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
          string.format(
            "Unknown entry type '%s' for entry '%s' -- no preview branch handles this entry; "
              .. "add one to define_preview's dispatch chain.",
            tostring(entry.value.entry_type), tostring(entry.value.name)
          ),
        })
      end
    end,
  })
end

return M
