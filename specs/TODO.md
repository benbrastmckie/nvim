---
next_project_number: 176
---

# TODO

## Tasks

### 175. Port memory/ extension to .claude/ agent system
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](175_port_memory_extension_to_claude/reports/research-001.md)

**Description**: Port the memory/ extension included in .opencode/ over to .claude/ while respecting any differences that may exist for proper integration into the .claude/ agent system.

---

### 174. Study .opencode/memory/ systems for memory extension creation
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](174_study_opencode_memory_extension/reports/research-001.md)
- **Plan**: [implementation-001.md](174_study_opencode_memory_extension/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](174_study_opencode_memory_extension/summaries/implementation-summary-20260310.md)

**Description**: Study the .opencode/memory/ systems and related commands, skills, agents, rules, context files, etc., in order to move this to a memory/ extension that I can selectively load. Carefully review the existing extensions and how they are loaded in order to identify exactly how to proceed, and what changes if any are required to be made to the extension system for memory/ to be an extension.

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
