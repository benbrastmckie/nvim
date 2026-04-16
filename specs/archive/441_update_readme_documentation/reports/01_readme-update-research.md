# Research Report: Task #441

**Task**: 441 - Update README Documentation
**Started**: 2026-04-15T12:00:00Z
**Completed**: 2026-04-15T12:05:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- README.md (root)
- lua/neotex/plugins/ai/init.lua (current plugin list)
- lua/neotex/plugins/ai/README.md (AI plugins documentation)
- .claude/README.md (agent system documentation)
- .claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md
**Artifacts**: - specs/441_update_readme_documentation/reports/01_readme-update-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Avante has been fully removed from the plugin system (no `avante.lua`, no `avante/` directory) but the README.md still contains extensive Avante documentation spanning lines 50-270
- The README references Avante in 6 distinct sections: Features Overview, Module Documentation links, "Using Avante AI" (entire section ~90 lines), Avante buffer keybindings, configuration help, and Quick Access
- Current AI plugins are: claudecode, lectic, mcp-hub, and opencode (per `init.lua`)
- `.claude/README.md` exists as a comprehensive agent system documentation hub and should be linked from the README
- The task description requests adding a link to `https://github.com/benbrastmckie/zed` at the beginning for users seeking a user-friendly alternative

## Context & Scope

The README.md is 583 lines and serves as the primary user-facing documentation for the Neovim configuration. The task requires three targeted changes: (1) remove all Avante references and replace with Claude Code integration documentation, (2) add a link to `.claude/README.md` for AI system details, and (3) add a Zed editor link at the top for users wanting a simpler alternative.

## Findings

### 1. Avante References to Remove

All Avante references in `README.md` with their line numbers:

| Line(s) | Section | Content |
|---------|---------|---------|
| 52 | Features Overview - AI Assistance | `[Avante](lua/neotex/plugins/ai/avante/README.md)` bullet point |
| 122 | Module Documentation | `Avante, Claude Code, and MCP Hub` link description |
| 179-274 | "Using Avante AI" | Entire section (~95 lines) including subsections: Basic Usage, Managing AI Settings, Using Avante to Work with this Configuration, Special Keybindings in Avante Buffers, Using Avante for Configuration Help |
| 307 | Quick Access | `Avante AI integration: Ask Avante about specific keybindings with <leader>ai` |

**Key observation**: The Avante directory (`lua/neotex/plugins/ai/avante/`) no longer exists. The `avante.lua` plugin spec file is also gone. The `init.lua` does not load any Avante module. Avante has been completely removed from the codebase but its documentation remains.

### 2. Current AI Plugin Landscape

Per `lua/neotex/plugins/ai/init.lua`, the active AI plugins are:

| Plugin | File | Description |
|--------|------|-------------|
| claudecode | `claudecode.lua` | External plugin wrapper for `greggh/claude-code.nvim` |
| lectic | `lectic.lua` | AI-assisted writing for markdown files |
| mcp-hub | `mcp-hub.lua` | MCP-Hub integration (still references Avante in its README) |
| opencode | `opencode.lua` | OpenCode TUI with context placeholders |

Additionally, the `claude/` subdirectory contains the comprehensive internal Claude AI integration system (9,626+ lines).

### 3. Claude Code Integration Details

Claude Code is the primary AI integration. Key keybindings (from AI README):
- `<C-CR>` - Toggle Claude Code (all modes)
- `<C-g>` - Toggle OpenCode interface (all modes)
- `<leader>ac` - Send selection to Claude (visual) / Claude commands (normal)
- `<leader>as` - Claude sessions
- `<leader>ay` - Toggle Claude yolo mode

### 4. .claude/README.md Content

`.claude/README.md` is a comprehensive documentation hub for the "Claude Code Agent System" (version 3.0). It documents the task management and automation framework including commands, architecture, and component references. This is appropriate to link from the main README as supplementary documentation about the AI-powered development system.

### 5. Sections Requiring Updates

**Section: Features Overview (line 50-53)**
- Remove Avante bullet, keep Claude Code and Lectic
- Add OpenCode as a bullet point (currently missing from Features Overview)

**Section: Module Documentation (line 122)**
- Change "Avante, Claude Code, and MCP Hub" to reflect current plugins

**Section: "Using Avante AI" (lines 179-274)**
- Replace entire section with Claude Code / AI integration documentation
- Incorporate relevant keybindings from the current AI plugin setup
- Can reference Claude Code, OpenCode, and Lectic as the three AI tools

**Section: Quick Access (line 307)**
- Remove Avante reference, update with Claude Code equivalent

**New content needed at top:**
- Zed editor link as described in the task: `https://github.com/benbrastmckie/zed`
- Framed as a user-friendly alternative for those not wanting the NeoVim learning curve

**New content needed in documentation section:**
- Link to `.claude/README.md` for AI system/agent architecture details

### 6. Other Stale References

The AI README (`lua/neotex/plugins/ai/README.md`) also contains Avante references but is out of scope for this task (line 14-15, 56, 86, 182, 196). The `MIGRATION.md` file documents the Avante separation but the migration itself is complete. These could be addressed in a separate task.

## Decisions

- The "Using Avante AI" section (lines 179-274) should be replaced with a "Using AI Tools" section covering Claude Code, OpenCode, and Lectic
- The Zed link should go near the very top, before or within the introductory paragraph
- The `.claude/README.md` link should be placed in the Documentation Structure section or near the AI Assistance feature description

## Recommendations

1. **Replace Avante section** (lines 179-274) with a consolidated "AI Integration" section documenting Claude Code (primary), OpenCode, and Lectic with their keybindings
2. **Add Zed link** in the opening paragraph or as a callout immediately after the title
3. **Add .claude/README.md link** in the Documentation Structure section, possibly under a new "AI System Architecture" entry
4. **Update Features Overview AI bullet** (line 50-53) to list Claude Code, OpenCode, and Lectic (removing Avante)
5. **Update Module Documentation link** (line 122) to say "Claude Code, OpenCode, Lectic, and MCP Hub"
6. **Update Quick Access** (line 307) to reference Claude Code instead of Avante
7. **Keep Lectic section** (lines 310-325) as-is since it's already accurate

## Risks & Mitigations

- **Risk**: Some keybinding references from Avante section may still be accurate for other tools. **Mitigation**: Cross-reference with current `which-key.lua` and `keymaps.lua` during implementation.
- **Risk**: Users who found this config via Avante documentation may be confused. **Mitigation**: The migration is already complete in the codebase; the README just needs to catch up.

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/README.md` (583 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/init.lua` (61 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/README.md` (208 lines)
- `/home/benjamin/.config/nvim/.claude/README.md` (80+ lines)
- `/home/benjamin/.config/nvim/.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`
- `/home/benjamin/.config/nvim/docs/AI_TOOLING.md`

### Avante File Status
- `lua/neotex/plugins/ai/avante.lua` - Does not exist
- `lua/neotex/plugins/ai/avante/` - Does not exist
- Avante is not loaded in `init.lua`
- Only remnants are in documentation files (README.md, MIGRATION.md, ai/README.md, claude/README.md)
