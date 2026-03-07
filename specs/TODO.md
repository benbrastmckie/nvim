---
next_project_number: 161
---

# TODO

## Tasks

### 160. Fix 'Load Core Agent System' in which-key picker to include missing core files
- **Effort**: TBD
- **Status**: [PLANNED]
- **Research Started**: 2026-03-07
- **Research Completed**: 2026-03-07
- **Planning Started**: 2026-03-07
- **Planning Completed**: 2026-03-07
- **Language**: neovim
- **Research**: [research-001.md](160_fix_load_core_agent_system_missing_files/reports/research-001.md)
- **Plan**: [implementation-001.md](160_fix_load_core_agent_system_missing_files/plans/implementation-001.md)

**Description**: Fix the 'Load Core Agent System' action in the which-key `<leader>ao` picker to include 9 missing core files that should be part of the portable agent system: `context/core/patterns/early-metadata-pattern.md`, `context/core/troubleshooting/workflow-interruptions.md`, `context/index.schema.json`, `docs/reference/standards/agent-frontmatter-standard.md`, `docs/reference/standards/multi-task-creation-standard.md`, `docs/templates/agent-template.md`, `docs/templates/command-template.md`, `scripts/update-plan-status.sh`, and `scripts/validate-context-index.sh`.

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

### 999. Test plan format compliance
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: None

**Description**: Test task for verifying plan format compliance.
