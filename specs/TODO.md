---
next_project_number: 190
---

# TODO

## Tasks

### 189. Improve memory naming conventions and deduplication for agent systems
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-12
- **Research Completed**: 2026-03-12
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](189_improve_memory_naming_and_deduplication/reports/research-001.md)

**Description**: Improve the .claude/ and .opencode/ memory systems to use short, suggestive slugs (e.g., `research-directions.md`) instead of verbose timestamp-based names (e.g., `MEM-2026-03-12-1773330053135-4d32`). Remove redundant 'MEM' prefix and date from filenames since directory context and internal metadata provide this information. Implement overlap scanning before storing new memories to integrate with existing memories rather than create duplicates. All memories should include basic metadata with dates for all additions.

---

### 188. Review memory extension durability: identify and fix overwrite risks, loader conflicts, and dual-system storage conflicts
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-12
- **Research Completed**: 2026-03-12
- **Planning Started**: 2026-03-12
- **Planning Completed**: 2026-03-12
- **Implementation Started**: 2026-03-12
- **Implementation Completed**: 2026-03-12
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](188_review_memory_extension_durability/reports/research-001.md)
- **Plan**: [implementation-001.md](188_review_memory_extension_durability/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260312.md](188_review_memory_extension_durability/summaries/implementation-summary-20260312.md)

**Description**: Review memory extension durability: identify and fix overwrite risks, loader conflicts, and dual-system (claude+opencode) storage conflicts to enhance memory system reliability. Specifically investigate: (1) overwrite risks when loading the extension via .claude/ (<leader>ac) or .opencode/ (<leader>ao) extension loaders, (2) conflicts when both Claude Code and OpenCode agents are storing memories to the same .memory/ vault, and (3) any other improvements to enhance durability and reliability of the shared memory system.

---

### 187. Port memory extension to .claude/ agent system
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-11
- **Research Completed**: 2026-03-11
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Implementation Started**: 2026-03-11
- **Implementation Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](187_port_memory_extension_to_claude/reports/research-001.md)
- **Plan**: [implementation-001.md](187_port_memory_extension_to_claude/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260311.md](187_port_memory_extension_to_claude/summaries/implementation-summary-20260311.md)

**Description**: Port the .opencode/ memory extension system to .claude/ while adapting to existing .claude/ agent system patterns and best practices. The memory extension was tested successfully in /home/benjamin/Projects/Logos/Vision/ and provides persistent memory capabilities that should be integrated into the Claude Code agent architecture.

---

### 176. Port Vision memory system changes to neovim configuration
- **Effort**: 2-3 hours
- **Status**: [IMPLEMENTING]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Implementation Started**: 2026-03-11
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-002.md](176_port_vision_memory_system_changes_to_neovim/reports/research-002.md)
- **Plan**: [implementation-002.md](176_port_vision_memory_system_changes_to_neovim/plans/implementation-002.md)

**Description**: Review the recent changes to /home/benjamin/Projects/Logos/Vision/ where the obsidian memory system was successfully implemented. Note the change from .opencode/memory/ to .memory/ directory structure (matching the specs/ location outside both agent systems). Review the recent changes and git commits in Vision to port all those changes to this neovim configuration system, keeping in mind that neovim contains the memory extension itself which gets loaded elsewhere in other repos using <leader>ao for opencode.

---

### 175. Port memory/ extension to .claude/ agent system
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: Task 176
- **Research**: [research-001.md](175_port_memory_extension_to_claude/reports/research-001.md), [research-002.md](175_port_memory_extension_to_claude/reports/research-002.md), [research-003.md](175_port_memory_extension_to_claude/reports/research-003.md) - Claude Code MCP and Obsidian integration

**Description**: Port the memory/ extension included in .opencode/ over to .claude/ while respecting any differences that may exist for proper integration into the .claude/ agent system.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

### 72. Fix himalaya sidebar help showing leader keybindings that conflict with toggle selection
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: neovim
- **Dependencies**: None

**Description**: Fix himalaya sidebar help display (shown via '?') incorrectly showing leader keybindings (`<leader>mA` - Switch account, `<leader>mf` - Change folder, `<leader>ms` - Sync folder) in the Folder Management section. These leader commands should not be accessible or defined in the sidebar since `<leader>` is `<Space>` which is used for toggle selections in that buffer.

---
