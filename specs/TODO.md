---
next_project_number: 113
---

# TODO

## Tasks

### 112. Fix <leader>ac artifact loader still loading project-overview.md and clarify CLAUDE.md placement
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: neovim
- **Dependencies**: None

**Description**: Load all artifacts in <leader>ac is still loading project-overview.md which it should skip. Also clarify whether both .claude/CLAUDE.md and root CLAUDE.md are needed, and which one should be preferred if only including one.

### 111. Systematically compare opencode agent systems to evaluate virtues and preference
- **Effort**: TBD
- **Status**: [RESEARCHING]
- **Research Started**: 2026-03-02
- **Language**: meta

**Description**: Systematically compare the /home/benjamin/.config/nvim/.opencode/ and /home/benjamin/Projects/ProofChecker/.opencode/ agent systems in order to evaluate which has which virtues, and which I should prefer.

### 110. Separate LaTeX/Typst extension files from core agent system for portability
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Implementation Started**: 2026-03-02
- **Implementation Completed**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](110_separate_extension_files_from_core_agent_system/reports/research-001.md)
- **Plan**: [implementation-001.md](110_separate_extension_files_from_core_agent_system/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](110_separate_extension_files_from_core_agent_system/summaries/implementation-summary-20260302.md)

**Description**: Restructure the .claude/ directory to exclude extension-specific files from the core agent system copied via `<leader>ac`. Files to move to extensions: `agents/document-converter-agent.md`, `agents/latex-implementation-agent.md`, `agents/typst-implementation-agent.md`, `context/project/typst/`, `context/project/latex/`, `skills/skill-latex-implementation/`, and `skills/skill-typst-implementation/`. Additionally, replace the neovim-specific `context/project/repo/project-overview.md` with a generic `agent-system.md` that applies to any repository using the .claude/ agent system, and include a mandate in documentation for users to create their own project-overview.md for project-specific details.

### 109. Make agent system portable for new repos by separating generic and project-specific content
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Implementation Started**: 2026-03-02
- **Implementation Completed**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](109_generic_agent_system_portability/reports/research-001.md)
- **Plan**: [implementation-002.md](109_generic_agent_system_portability/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260302.md](109_generic_agent_system_portability/summaries/implementation-summary-20260302.md)

**Description**: Separate neovim-specific content from generic agent system to enable portability when copying .claude/ to new repos via <leader>ac "Load All Artifacts". Create agent-system.md (generic overview, copied to new repos) and keep project-overview.md (neovim-specific, not copied). Make .claude/CLAUDE.md generic to the core agent system while linking project-overview.md for project specifics, with a note suggesting users generate this project-specific file if it doesn't exist. Reference .claude/context/project/repo/update-project.md for guidance when project-overview.md does not exist. This reduces maintenance by dividing files into portable agent system components vs project-specific configuration.

### 108. Show active/current extensions with '*' indicator in <leader>ac picker
- **Effort**: 0.5-1 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Implementation Started**: 2026-03-02
- **Implementation Completed**: 2026-03-02
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](108_extension_asterisk_indicator/reports/research-001.md)
- **Plan**: [implementation-001.md](108_extension_asterisk_indicator/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](108_extension_asterisk_indicator/summaries/implementation-summary-20260302.md)

**Description**: Show active/current extensions with '*' indicator in <leader>ac picker. Add an asterisk (*) next to extensions that are both loaded (active status) and do not differ from the available version (i.e., current/up-to-date). This visual indicator helps users quickly identify which extensions are loaded and current without needing to check each one individually.

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
