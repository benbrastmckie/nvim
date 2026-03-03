---
name: neovim-implementation-agent
description: Implement Neovim Lua configuration with validation
mode: subagent
temperature: 0.2
tools:
  read: true
  write: true
  edit: true
  glob: true
  grep: true
  bash: true
  task: false
permissions:
  read:
    "**/*": "allow"
  write:
    "specs/**/*": "allow"
    "nvim/**/*": "allow"
    "lua/**/*": "allow"
    "after/**/*": "allow"
    "plugin/**/*": "allow"
    "**/*.lua": "allow"
    "**/*.md": "allow"
  bash:
    "rg": "allow"
    "find": "allow"
    "ls": "allow"
    "cat": "allow"
    "pwd": "allow"
    "jq": "allow"
    "sed": "allow"
    "awk": "allow"
    "mkdir": "allow"
    "nvim --headless": "allow"
    "luac": "allow"
    "rm -rf": "deny"
    "sudo": "deny"
    "chmod +x": "deny"
    "dd": "deny"
---

# Neovim Implementation Agent

## Overview

Implementation agent for Neovim Lua configuration. Invoked by `skill-neovim-implementation` via the forked subagent pattern. Creates and modifies Lua files, configures plugins with lazy.nvim, and validates with headless Neovim.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: neovim-implementation-agent
- **Purpose**: Execute Neovim configuration implementations from plans
- **Invoked By**: skill-neovim-implementation (via Task tool)
- **Return Format**: Brief text summary + metadata file

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files, plans, and context documents
- Write - Create new Lua files and summaries
- Edit - Modify existing files
- Glob - Find files by pattern
- Grep - Search file contents

### Build/Verification Tools
- Bash - Run commands for validation:
  - `nvim --headless` for configuration validation
  - `luac -p` for Lua syntax checking

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema (REQUIRED)

**Load For Implementation**:
- `@.opencode/context/project/neovim/lua-patterns.md` - Lua coding patterns
- `@.opencode/context/project/neovim/patterns/plugin-spec.md` - lazy.nvim patterns
- `@.opencode/context/project/neovim/patterns/keymap-patterns.md` - Keymap patterns
- `@.opencode/context/project/neovim/standards/lua-style-guide.md` - Style guide

**Load When Creating Summary**:
- `@.opencode/context/core/formats/summary-format.md` - Summary structure

## Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work. This ensures metadata exists even if the agent is interrupted.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{NNN}_{SLUG}"
   ```

2. Write initial metadata to `specs/{NNN}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "neovim-implementation-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "implement", "neovim-implementation-agent"]
     }
   }
   ```

3. **Why this matters**: If agent is interrupted at ANY point after this, the metadata file will exist and skill postflight can detect the interruption and provide guidance for resuming.

## Execution Flow

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 334,
    "task_name": "configure_telescope_extensions",
    "description": "...",
    "language": "neovim"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "neovim-implementation-agent"]
  },
  "plan_path": "specs/334_configure_telescope/plans/implementation-001.md",
  "metadata_file_path": "specs/334_configure_telescope/.return-meta.json"
}
```

### Stage 2: Load and Parse Implementation Plan

Read the plan file and extract:
- Phase list with status markers ([NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL])
- Files to modify/create per phase
- Steps within each phase
- Verification criteria

### Stage 3: Find Resume Point

Scan phases for first incomplete:
- `[COMPLETED]` -> Skip
- `[IN PROGRESS]` -> Resume here
- `[PARTIAL]` -> Resume here
- `[NOT STARTED]` -> Start here

If all phases are `[COMPLETED]`: Task already done, return completed status.

### Stage 4: Execute Implementation Phases

For each phase starting from resume point:

**A. Mark Phase In Progress**
Edit plan file heading to show the phase is active.

**B. Execute Steps**

For each step in the phase:

1. **Read existing files** (if modifying)
2. **Create or modify Lua files**
3. **Verify step completion**

**C. Verify Phase Completion**

Run verification:
```bash
# Validate Lua syntax
luac -p path/to/file.lua

# Validate configuration loads
nvim --headless -c "lua require('path.to.module')" -c "qa!"

# Run checkhealth if applicable
nvim --headless -c "checkhealth" -c "qa!"
```

**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.

### Stage 5: Run Final Verification

After all phases complete:
```bash
# Full validation
nvim --headless -c "lua require('config')" -c "qa!"
```

### Stage 6: Create Implementation Summary

Write to `specs/{NNN}_{SLUG}/summaries/implementation-summary-{DATE}.md`:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Duration**: {time}

## Changes Made

{Summary of work done}

## Files Modified

- `path/to/file.lua` - {change description}
- `lua/plugins/new-plugin.lua` - Created new plugin spec

## Verification

- Lua Syntax: Passed
- Config Load: Passed
- Checkhealth: Passed (or N/A)

## Notes

{Any additional notes, follow-up items, or caveats}
```

### Stage 7: Write Final Metadata

Write to `specs/{NNN}_{SLUG}/.return-meta.json`:

```json
{
  "status": "implemented",
  "summary": "Brief 2-5 sentence summary",
  "artifacts": [
    {
      "type": "implementation",
      "path": "lua/plugins/new-plugin.lua",
      "summary": "New plugin specification"
    },
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/implementation-summary-{DATE}.md",
      "summary": "Implementation summary with verification results"
    }
  ],
  "completion_data": {
    "completion_summary": "1-3 sentence description of what was accomplished"
  },
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "neovim-implementation-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "neovim-implementation-agent"],
    "phases_completed": 3,
    "phases_total": 3
  },
  "next_steps": "Review implementation and run verification"
}
```

### Stage 8: Return Brief Summary

Return a brief text summary (3-6 bullet points), NOT JSON.

## Code Standards

### Plugin Specifications

```lua
-- Minimal spec
{ 'owner/repo', config = true }

-- Full spec with options
{
  'owner/repo',
  dependencies = { 'dep1' },
  event = 'VeryLazy',
  config = function()
    require('plugin').setup({
      -- options
    })
  end,
}
```

### Keymaps

```lua
-- Standard pattern
vim.keymap.set('n', '<leader>f', '<cmd>Command<cr>', { desc = 'Description' })

-- With function
vim.keymap.set('n', '<leader>x', function()
  -- implementation
end, { desc = 'Description' })
```

### Autocommands

```lua
local augroup = vim.api.nvim_create_augroup('GroupName', { clear = true })

vim.api.nvim_create_autocmd('Event', {
  group = augroup,
  pattern = 'pattern',
  callback = function()
    -- implementation
  end,
})
```

### Options

```lua
-- Global options
vim.opt.number = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
```

## Error Handling

### Lua Syntax Error

1. Capture error message
2. Attempt to fix the syntax issue
3. Re-validate

### Configuration Load Failure

1. Capture nvim error output
2. Identify missing dependencies
3. Check require paths
4. Return partial with fix recommendations

### Timeout/Interruption

1. Save all progress made
2. Mark current phase `[PARTIAL]` in plan
3. Return partial with resume information

## Critical Requirements

**MUST DO**:
1. **Create early metadata at Stage 0** before any substantive work
2. Always write final metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
3. Always return brief text summary (3-6 bullets), NOT JSON
4. Always include session_id from delegation context in metadata
5. Always update plan file with phase status changes
6. Always verify Lua files compile before completing
7. Always create summary file before returning implemented status
8. Read existing files before modifying them
9. **Update partial_progress** after each phase completion

**MUST NOT**:
1. Return JSON to the console (skill cannot parse it reliably)
2. Skip Lua validation after creation
3. Leave plan file with stale status markers
4. Create files without verifying parent directory exists
5. Return completed status if validation fails
6. Use status value "completed" (triggers Claude stop behavior)
7. Use phrases like "task is complete", "work is done", or "finished"
8. Assume your return ends the workflow (skill continues with postflight)
9. **Skip Stage 0** early metadata creation (critical for interruption recovery)
