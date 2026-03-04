---
next_project_number: 128
---

# TODO

## Tasks

### 127. Migrate OPENCODE.md to README.md and rename QUICK-START.md to INSTALLATION.md
- **Effort**: 2-3 hours
- **Status**: [RESEARCHING]
- **Language**: meta
- **Research Started**: 2026-03-03

**Description**: Migrate /home/benjamin/.config/nvim/.opencode/OPENCODE.md into /home/benjamin/.config/nvim/.opencode/README.md to provide a single README.md file with systematic coverage of all features of the core .opencode/ agent system as well as the various extensions provided and cross links to relevant README.md files scattered throughout the subdirectories. Rename /home/benjamin/.config/nvim/.opencode/QUICK-START.md to INSTALLATION.md which should focus entirely on what is needed to install all dependencies.

---

### 126. Fix <leader>ao picker to load extensions into correct subdirectory
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](126_fix_ao_picker_extension_loading_path/reports/research-001.md)
- **Plan**: [implementation-001.md](126_fix_ao_picker_extension_loading_path/plans/implementation-001.md)

**Description**: Fix the `<leader>ao` picker to load extensions into the correct `.opencode/agents/subagents/` subdirectory instead of directly into `.opencode/agents/`. Currently, when loading extensions via `<leader>ao` in `/home/benjamin/Projects/Logos/Theory/`, files are being placed at `.opencode/agents/formal-research-agent.md` instead of the desired `.opencode/agents/subagents/`. This functionality must be distinct from `<leader>ac` which should continue loading directly into `.claude/agents/`.

---

### 125. Add epidemiology research extension for R and related tooling
- **Effort**: TBD
- **Status**: [RESEARCHING]
- **Research Started**: 2026-03-03
- **Language**: meta
- **Dependencies**: None

**Description**: Add an extension for conducting epidemiology research using R and any other standard software, MCP servers, agents, skills, and commands that would help to streamline the workflow. The same extension should be added to both .opencode/extensions/ and .claude/extensions/

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

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

### 72. Fix himalaya sidebar help showing leader keybindings that conflict with toggle selection
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: neovim
- **Dependencies**: None

**Description**: Fix himalaya sidebar help display (shown via '?') incorrectly showing leader keybindings (`<leader>mA` - Switch account, `<leader>mf` - Change folder, `<leader>ms` - Sync folder) in the Folder Management section. These leader commands should not be accessible or defined in the sidebar since `<leader>` is `<Space>` which is used for toggle selections in that buffer.
