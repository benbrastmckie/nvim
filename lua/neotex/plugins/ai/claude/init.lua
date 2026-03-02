-- lua/neotex/ai-claude/init.lua
-- Main entry point for Claude AI integration
-- Initially forwards to existing modules during migration

local M = {}

-- Track initialization state
M._initialized = false

-- Load internal modules
local claude_session = require("neotex.plugins.ai.claude.core.session")
local claude_worktree = require("neotex.plugins.ai.claude.core.worktree")
local claude_visual = require("neotex.plugins.ai.claude.core.visual")
local claude_native = require("neotex.plugins.ai.claude.ui.native-sessions")
local claude_picker = require("neotex.plugins.ai.claude.ui.pickers")
local commands_picker = require("neotex.plugins.ai.claude.commands.picker")

-- Session state tracking (forward from worktree module)
M.sessions = {}  -- Will be populated from claude_worktree
M.current_session = nil  -- Will be populated from claude_worktree

-- Public API (keep same interface)

-- Session management
M.smart_toggle = function()
  return claude_session.smart_toggle()
end

M.resume_session = function(id)
  -- Use session manager for validated resumption if id provided
  if id then
    local session_manager = require("neotex.plugins.ai.claude.core.session-manager")
    return session_manager.resume_session(id)
  else
    -- Otherwise use the interactive session picker
    return claude_session.resume_session()
  end
end

M.save_session_state = function()
  return claude_session.save_session_state()
end

M.load_session_state = function()
  return claude_session.load_session_state()
end

M.get_claude_sessions = function()
  return claude_session.get_claude_sessions()
end

M.check_for_recent_session = function()
  return claude_session.check_for_recent_session()
end

M.create_preview_content = function(...)
  return claude_session.create_preview_content(...)
end

M.open_claude = function()
  return claude_session.open_claude()
end

-- Worktree management
M.create_worktree_with_claude = function(opts)
  return claude_worktree.create_worktree_with_claude(opts)
end

M.telescope_sessions = function()
  return claude_worktree.telescope_sessions()
end

M.telescope_worktrees = function()
  return claude_worktree.telescope_worktrees()
end

M.setup_worktree = function(opts)
  return claude_worktree.setup(opts)
end

M.cleanup_sessions = function(silent)
  return claude_worktree.cleanup_sessions and claude_worktree.cleanup_sessions(silent)
end

-- Visual selection handling
M.send_visual_to_claude = function()
  return claude_visual.send_visual_to_claude()
end

-- Native sessions
M.get_native_sessions = function()
  return claude_native.get_sessions()
end

M.format_time_ago = function(timestamp)
  return claude_native.format_time_ago(timestamp)
end

-- Sessions picker
M.show_session_picker = function(sessions, on_select)
  return claude_picker.show_session_picker(sessions, on_select)
end

-- Commands picker
M.show_commands_picker = function(opts)
  return commands_picker.show_commands_picker(opts)
end

-- Helper to sync session state from worktree module
local function sync_session_state()
  M.sessions = claude_worktree.sessions or {}
  M.current_session = claude_worktree.current_session
end

-- Module setup
M.setup = function(opts)
  -- Prevent duplicate initialization
  if M._initialized then
    return M
  end
  M._initialized = true

  -- Setup configuration
  local config = require("neotex.plugins.ai.claude.config")
  M.config = config.setup(opts)

  -- Initialize session management
  if claude_session.setup then
    claude_session.setup()
  end

  -- Initialize worktree module if not already done
  if claude_worktree.setup then
    claude_worktree.setup(opts and opts.worktree or {})
  end

  -- Initialize visual selection module
  if claude_visual.setup then
    claude_visual.setup()
  end

  -- Sync initial state
  sync_session_state()

  -- Register user commands
  vim.api.nvim_create_user_command("ClaudeCommands", M.show_commands_picker, {
    desc = "Browse Claude commands in hierarchical picker",
    nargs = 0,
  })

  vim.api.nvim_create_user_command("ClaudeExtensions", function()
    require("neotex.plugins.ai.claude.extensions.picker").show()
  end, {
    desc = "Manage Claude extensions",
    nargs = 0,
  })

  -- Set up a timer to periodically sync state
  vim.defer_fn(function()
    local timer = vim.loop.new_timer()
    timer:start(1000, 1000, vim.schedule_wrap(function()
      sync_session_state()
    end))
  end, 100)

  return M
end

return M