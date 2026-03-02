---
next_project_number: 100
---

# TODO

## Tasks

### 99. Review agent systems to identify core features and extensions architecture
- **Effort**: 10-14 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-01
- **Research Completed**: 2026-03-01
- **Planning Started**: 2026-03-01
- **Planning Completed**: 2026-03-01
- **Implementation Started**: 2026-03-01
- **Implementation Completed**: 2026-03-01
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](099_review_agent_systems_core_extensions/reports/research-001.md), [research-002.md](099_review_agent_systems_core_extensions/reports/research-002.md), [research-003.md](099_review_agent_systems_core_extensions/reports/research-003.md), [research-004.md](099_review_agent_systems_core_extensions/reports/research-004.md)
- **Plan**: [implementation-003.md](099_review_agent_systems_core_extensions/plans/implementation-003.md)
- **Summary**: [implementation-summary-20260301.md](099_review_agent_systems_core_extensions/summaries/implementation-summary-20260301.md)

**Description**: Review .claude/ agent systems in ProofChecker/ and Theory/ directories to identify general-purpose features (commands, skills, agents, rules, context files) missing from the current nvim/.claude/ system. Design a core + extensions architecture where the core agent system is managed by `<leader>ac`, and extensions (e.g., Lean development support) are optional additions loadable through `<leader>ac` but not active by default. Goal: ProofChecker/ agent = core system + Lean extension.

### 98. Remove deprecated index.md and consolidate context index to JSON
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-01
- **Research Completed**: 2026-03-01
- **Planning Started**: 2026-03-01
- **Planning Completed**: 2026-03-01
- **Implementation Started**: 2026-03-01
- **Implementation Completed**: 2026-03-01
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](098_consolidate_context_index_to_json/reports/research-001.md)
- **Plan**: [implementation-001.md](098_consolidate_context_index_to_json/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260301.md](098_consolidate_context_index_to_json/summaries/implementation-summary-20260301.md)

**Description**: Remove index.md from .claude/context/ and all references, given that index.json has been implemented. Verify removal won't break anything by ensuring the system uses index.json consistently. Also evaluate index.schema.json - determine if it should be removed or moved to context files to document the index.json schema pattern rather than being an active part of the system.

### 97. Add typst clear-cache keymap under <leader>l
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](097_add_typst_clear_cache_keymap/reports/research-001.md)

**Description**: Add a `<leader>l` keymap that runs tinymist's clear-cache command (or equivalent typst cache invalidation). The mapping should appear in the which-key group alongside the other typst/tinymist mappings so it's discoverable. Context: stale tinymist preview cache causes old compiled output to persist even after source files are updated.

### 96. Add QUESTION: tag support to /learn command
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-25
- **Research Completed**: 2026-02-25
- **Planning Started**: 2026-02-25
- **Planning Completed**: 2026-02-25
- **Implementation Started**: 2026-02-25
- **Implementation Completed**: 2026-02-25
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](096_add_question_tag_support_to_learn_command/reports/research-001.md)
- **Plan**: [implementation-001.md](096_add_question_tag_support_to_learn_command/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260225.md](096_add_question_tag_support_to_learn_command/summaries/implementation-summary-20260225.md)

**Description**: Expand the /learn command to recognize QUESTION: tags in source code comments. When found, create research tasks aimed at answering these questions. Group questions by topic when natural (shared terms, file section proximity), but keep tasks focused enough that all questions can be completely answered. Map QUESTION: tags to a new "research-task" type, following the same interactive selection pattern as TODO: tags (including optional topic grouping for multiple questions).

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
