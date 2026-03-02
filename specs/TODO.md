---
next_project_number: 106
---

# TODO

## Tasks

### 105. Create web/ extension from Logos Website .claude configuration
- **Effort**: 3 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](105_create_web_extension/reports/research-001.md)
- **Plan**: [implementation-001.md](105_create_web_extension/plans/implementation-001.md)

**Description**: Create a .claude/extensions/web/ extension by carefully studying /home/benjamin/Projects/Logos/Website/.claude/ as the reference source. Follow the same pattern established in task 102 (populating lean, latex, typst, z3, python, formal extensions), adapting content to be project-agnostic. Include appropriate agents, skills, context files, rules, EXTENSION.md, and manifest.json.

### 104. Fix /implement phase status live updates
- **Effort**: 3-4 hours
- **Status**: [IMPLEMENTING]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Implementation Started**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-003.md](104_fix_implement_phase_status_live_updates/reports/research-003.md)
- **Plan**: [implementation-002.md](104_fix_implement_phase_status_live_updates/plans/implementation-002.md)

**Description**: Investigate and fix the /implement command's phase status update behavior. Currently, when running `/implement`, the plan status is correctly changed to '[IMPLEMENTING]' but the same status field is added to all phases simultaneously instead of updating each phase one at a time. The expected behavior is to cycle each phase header through '[NOT STARTED]' to '[IMPLEMENTING]' to '[COMPLETED]' (or '[BLOCKED]', '[PARTIAL]', etc.) sequentially, providing live feedback so users can follow the plan as a dashboard displaying progress.

### 103. Compare .opencode agent systems against .claude North Star
- **Effort**: 9.5 hours
- **Status**: [COMPLETED]
- **Implementation Started**: 2026-03-02
- **Implementation Completed**: 2026-03-02
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](103_compare_opencode_agent_systems_against_claude/reports/research-001.md), [research-002.md](103_compare_opencode_agent_systems_against_claude/reports/research-002.md)
- **Plan**: [implementation-001.md](103_compare_opencode_agent_systems_against_claude/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](103_compare_opencode_agent_systems_against_claude/summaries/implementation-summary-20260302.md)

**Description**: Compare the .opencode agent systems in /home/benjamin/Projects/Logos/Theory/.opencode/ and /home/benjamin/.config/nvim/.opencode/ to evaluate their capacities and determine which to prefer. Goal is to make these agent systems provide the same functionality as /home/benjamin/.config/nvim/.claude/, which serves as the North Star reference.

### 102. Review extensions and populate missing resources from Logos, ModelChecker, ProofChecker
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Implementation Started**: 2026-03-02
- **Implementation Completed**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-002.md](102_review_extensions_populate_missing_resources/reports/research-002.md)
- **Plan**: [implementation-001.md](102_review_extensions_populate_missing_resources/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](102_review_extensions_populate_missing_resources/summaries/implementation-summary-20260302.md)
- **Plan**: [implementation-001.md](102_review_extensions_populate_missing_resources/plans/implementation-001.md)

**Description**: Review the extensions in .claude/extensions/ to identify resources in /home/benjamin/Projects/Logos/Theory/.claude/, /home/benjamin/Projects/ModelChecker/.claude/, and /home/benjamin/Projects/ProofChecker/.claude/ that should be included but are not already. Fill all gaps such as missing commands (e.g., lean.md missing from lean/commands/).

### 101. Add contents to lean, latex, z3, typst, and python extensions
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-02
- **Research Completed**: 2026-03-02
- **Planning Started**: 2026-03-02
- **Planning Completed**: 2026-03-02
- **Implementation Started**: 2026-03-02
- **Implementation Completed**: 2026-03-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](101_add_contents_to_language_extensions/reports/research-001.md)
- **Plan**: [implementation-001.md](101_add_contents_to_language_extensions/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260302.md](101_add_contents_to_language_extensions/summaries/implementation-summary-20260302.md)

**Description**: Add appropriate contents to language extensions (lean/, latex/, z3/, typst/, python/) by referencing configurations from: /home/benjamin/Projects/ProofChecker/.claude/ for lean (including math), /home/benjamin/Projects/Logos/Theory/.claude/ for typst and latex, and /home/benjamin/Projects/ModelChecker/.claude/ for z3 and python.

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
