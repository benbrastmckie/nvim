---
next_project_number: 117
---

# TODO

## Tasks

### 116. Verify ModelChecker .opencode/ directory and implement claude code extension feature parity
- **Effort**: TBD
- **Status**: [PLANNED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](116_verify_opencode_implement_extension_parity/reports/research-001.md), [research-002.md](116_verify_opencode_implement_extension_parity/reports/research-002.md)
- **Plan**: [implementation-002.md](116_verify_opencode_implement_extension_parity/plans/implementation-002.md)

**Description**: Check the directory copied to /home/benjamin/Projects/ModelChecker/.opencode/ including the formal/ and lean/ extensions to ensure nothing is missing. Then investigate extensions in .claude/extensions/ to implement feature parity so that opencode has exactly the same extensions as claude code with a core agent system with similar capabilities.

### 115. Investigate <leader>ao Load All Artifacts shortcomings and achieve full feature parity with <leader>ac
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Implementation Completed**: 2026-03-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](115_investigate_leader_ao_load_all_feature_parity/reports/research-001.md)
- **Plan**: [implementation-001.md](115_investigate_leader_ao_load_all_feature_parity/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](115_investigate_leader_ao_load_all_feature_parity/summaries/implementation-summary-20260302.md)

**Description**: The <leader>ao Load All Artifacts operation does not copy everything from ~/.config/nvim/.opencode/ as expected. Investigate what is missing compared to the <leader>ac Claude Code picker to achieve full feature parity between the two systems.

### 114. Make <leader>ao identical to <leader>ac and remove <leader>ae picker
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Implementation Completed**: 2026-03-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](114_make_leader_ao_identical_to_leader_ac/reports/research-001.md)
- **Plan**: [implementation-001.md](114_make_leader_ao_identical_to_leader_ac/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](114_make_leader_ao_identical_to_leader_ac/summaries/implementation-summary-20260302.md)

**Description**: Make <leader>ao identical to <leader>ac since <C-g> already opens OpenCode directly. Remove <leader>ae picker for both Claude Code and OpenCode as it is no longer needed.

### 113. Review the virtues of ProofChecker .opencode/ in order to incorporate any missing elements to improve the current .opencode/ agent system
- **Effort**: 10-14 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Implementation Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](113_review_proofchecker_opencode_virtues/reports/research-001.md), [research-002.md](113_review_proofchecker_opencode_virtues/reports/research-002.md), [research-003.md](113_review_proofchecker_opencode_virtues/reports/research-003.md)
- **Plan**: [implementation-001.md](113_review_proofchecker_opencode_virtues/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](113_review_proofchecker_opencode_virtues/summaries/implementation-summary-20260302.md)

**Description**: Review the virtues of /home/benjamin/Projects/ProofChecker/.opencode/ in order to incorporate any missing elements to improve the current .opencode/ agent system

### 112. Fix <leader>ac artifact loader still loading project-overview.md and clarify CLAUDE.md placement
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Implementation Completed**: 2026-03-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](112_fix_leader_ac_artifact_loader_project_overview/reports/research-001.md)
- **Plan**: [implementation-001.md](112_fix_leader_ac_artifact_loader_project_overview/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](112_fix_leader_ac_artifact_loader_project_overview/summaries/implementation-summary-20260302.md)

**Description**: Load all artifacts in <leader>ac is still loading project-overview.md which it should skip. Also clarify whether both .claude/CLAUDE.md and root CLAUDE.md are needed, and which one should be preferred if only including one.

### 111. Systematically compare opencode agent systems to evaluate virtues and preference
- **Effort**: 5-7 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Implementation Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](111_compare_opencode_agent_systems/reports/research-001.md), [research-002.md](111_compare_opencode_agent_systems/reports/research-002.md)
- **Plan**: [implementation-001.md](111_compare_opencode_agent_systems/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](111_compare_opencode_agent_systems/summaries/implementation-summary-20260303.md)

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
