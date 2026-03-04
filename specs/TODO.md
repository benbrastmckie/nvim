---
next_project_number: 131
---

# TODO

## Tasks

### OC_130. Make .opencode system self-contained
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [research-001.md](130_make_opencode_self_contained/reports/research-001.md)
- **Plan**: [implementation-001.md](130_make_opencode_self_contained/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](130_make_opencode_self_contained/summaries/implementation-summary-20260304.md)

**Description**: The .opencode system should be self-contained and not rely on references to .claude/ directories or files. Currently, files like `plan-format.md` are deprecated and claim to use Claude format specifications. The goal is to remove all references to `.claude/` within `.opencode/` and ensure `.opencode/` uses its own format specifications and is fully self-contained.

---

### OC_129. Fix plan format in implementation-001.md to follow plan-format.md standards
- **Effort**: 2-3 hours
- **Status**: [PLANNED]
- **Language**: meta
- **Research**: [research-001.md](129_fix_plan_format_in_implementation_001_md/reports/research-001.md)
- **Plan**: [implementation-001.md](129_fix_plan_format_in_implementation_001_md/plans/implementation-001.md)
- **Language**: meta

**Description**: The plan file /home/benjamin/.config/nvim/specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md was created with incorrect format. It contains `**Status**: [STATUS]` metadata lines after each phase heading instead of the correct format from plan-format.md which requires status markers ONLY in the phase headings (e.g., `### Phase N: Name [STATUS]`). Need to update the file to follow the standard format with status only in headings and no separate metadata lines per phase.


### 128. Ensure /task command only creates tasks and never implements solutions automatically
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Language**: general
- **Planning Started**: 2026-03-04
- **Planning Completed**: 2026-03-04
- **Implementation Started**: 2026-03-04
- **Implementation Completed**: 2026-03-04
- **Research**: [research-001.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/reports/research-001.md)
- **Plan**: [implementation-001.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/summaries/implementation-summary-20260304.md)

**Description**: Ensure /task command only creates tasks and never implements solutions automatically.

---

### 127. Migrate OPENCODE.md to README.md and rename QUICK-START.md to INSTALLATION.md
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Research**: [research-001.md](127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/reports/research-001.md)
- **Plan**: [implementation-001.md](127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/summaries/implementation-summary-20260303.md)

**Description**: Migrate /home/benjamin/.config/nvim/.opencode/OPENCODE.md into /home/benjamin/.config/nvim/.opencode/README.md to provide a single README.md file with systematic coverage of all features of the core .opencode/ agent system as well as the various extensions provided and cross links to relevant README.md files scattered throughout the subdirectories. Rename /home/benjamin/.config/nvim/.opencode/QUICK-START.md to INSTALLATION.md which should focus entirely on what is needed to install all dependencies.

---

### 126. Fix <leader>ao picker to load extensions into correct subdirectory
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](126_fix_ao_picker_extension_loading_path/reports/research-001.md)
- **Plan**: [implementation-001.md](126_fix_ao_picker_extension_loading_path/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](126_fix_ao_picker_extension_loading_path/summaries/implementation-summary-20260304.md)

**Description**: Fix the `<leader>ao` picker to load extensions into the correct `.opencode/agents/subagents/` subdirectory instead of directly into `.opencode/agents/`. Currently, when loading extensions via `<leader>ao` in `/home/benjamin/Projects/Logos/Theory/`, files are being placed at `.opencode/agents/formal-research-agent.md` instead of the desired `.opencode/agents/subagents/`. This functionality must be distinct from `<leader>ac` which should continue loading directly into `.claude/agents/`.

---

### 125. Add epidemiology research extension for R and related tooling
- **Effort**: 7 hours
- **Status**: [COMPLETED]
- **Planning Started**: 2026-03-04
- **Planning Completed**: 2026-03-04
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-04
- **Implementation Started**: 2026-03-04
- **Implementation Completed**: 2026-03-04
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](125_epidemiology_r_extension/reports/research-001.md)
- **Research**: [research-002.md](125_epidemiology_r_extension/reports/research-002.md)
- **Plan**: [implementation-001.md](125_epidemiology_r_extension/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](125_epidemiology_r_extension/summaries/implementation-summary-20260304.md)

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
