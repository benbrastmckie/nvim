---
next_project_number: 166
---

# TODO

## Tasks

### 165. Review .opencode/ agent system extension language routing for correct agent and context loading
- **Effort**: 3-5 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Language**: meta
- **Research**: [research-001.md](165_review_opencode_extension_language_routing/reports/research-001.md)

**Description**: Review .opencode/ agent system to ensure that when extensions are added, the range of available language types for tasks is correctly updated so that the correct agents are called when running tasks with those types and the context files for those languages are loaded by the correct specialist agents.

---

### 164. Include /tag command and skill from Logos/Website in web extension
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Implementation Completed**: 2026-03-09
- **Language**: meta
- **Research**: [research-001.md](164_include_tag_command_skill_web_extension/reports/research-001.md)
- **Plan**: [implementation-001.md](164_include_tag_command_skill_web_extension/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260309.md](164_include_tag_command_skill_web_extension/summaries/implementation-summary-20260309.md)

**Description**: Include the /tag command and skill from /home/benjamin/Projects/Logos/Website/.claude/ in the web extension of the current .claude/ agent system, updating everything relevant to do so.

---

### 163. Review extension system language routing for correct agent and context loading
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Implementation Completed**: 2026-03-09
- **Language**: meta
- **Research**: [research-001.md](163_review_extension_language_routing/reports/research-001.md)
- **Plan**: [implementation-001.md](163_review_extension_language_routing/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260309.md](163_review_extension_language_routing/summaries/implementation-summary-20260309.md)

**Description**: Review extension system to ensure that when extensions are added, the range of available language types for tasks is correctly updated so that the correct agents are called when running tasks with those types and the context files for those languages are loaded by the correct specialist agents.

---

### 162. Create /deck command-skill-agent for typst pitch deck generation
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-09
- **Research Completed**: 2026-03-09
- **Planning Started**: 2026-03-09
- **Planning Completed**: 2026-03-09
- **Implementation Started**: 2026-03-09
- **Implementation Completed**: 2026-03-09
- **Language**: meta
- **Research**: [research-001.md](162_deck_command_skill_agent_typst_pitchdeck/reports/research-001.md)
- **Plan**: [implementation-001.md](162_deck_command_skill_agent_typst_pitchdeck/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260309.md](162_deck_command_skill_agent_typst_pitchdeck/summaries/implementation-summary-20260309.md)

**Description**: Create a /deck command-skill-agent following the existing pattern used in this claude agent system by drawing on https://www.ycombinator.com/library/2u-how-to-build-your-seed-round-pitch-deck and https://www.ycombinator.com/library/4T-how-to-design-a-better-pitch-deck as resources to draw on a prompt or file-path to create a clear 10 slide deck for presenting to startup investors. The decks should be generated using typst. It is important to conduct careful research into deck guides and into how best to generate slides with typst before designing the deck command-skill-agent to include in this .claude/ agent system. It is also important that this be included in the /home/benjamin/.config/nvim/.claude/extensions/filetypes/ extension rather than in the core agent system, populating appropriate resources including context files to add to that extension.

---

### 161. Fix nvim/.opencode/ source directory to include missing core files and fix scan bugs
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-07
- **Research Completed**: 2026-03-07
- **Planning Started**: 2026-03-07
- **Planning Completed**: 2026-03-07
- **Implementation Started**: 2026-03-07
- **Implementation Completed**: 2026-03-07
- **Language**: neovim
- **Research**: [research-001.md](161_fix_opencode_source_missing_files_and_scan_bugs/reports/research-001.md)
- **Plan**: [implementation-001.md](161_fix_opencode_source_missing_files_and_scan_bugs/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260307.md](161_fix_opencode_source_missing_files_and_scan_bugs/summaries/implementation-summary-20260307.md)

**Description**: Three fixes needed for the `<leader>ao` Load Core Agent System picker. (1) Copy 9 missing core files from `.claude/` into `.opencode/` in the nvim config (the true source for OpenCode syncs): `context/core/patterns/early-metadata-pattern.md`, `context/core/troubleshooting/workflow-interruptions.md`, `context/index.schema.json`, `docs/reference/standards/agent-frontmatter-standard.md`, `docs/reference/standards/multi-task-creation-standard.md`, `docs/templates/agent-template.md`, `docs/templates/command-template.md`, `scripts/update-plan-status.sh`, `scripts/validate-context-index.sh`. (2) Fix templates scan in `sync.lua` to include `*.json` in addition to `*.yaml` so `templates/settings.json` is synced. (3) Decide whether context `.sh` files (`context/core/patterns/command-execution.sh` and similar) should be synced and fix the context scan accordingly.

---

### 160. Fix 'Load Core Agent System' in which-key picker to include missing core files
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-07
- **Research Completed**: 2026-03-07
- **Planning Started**: 2026-03-07
- **Planning Completed**: 2026-03-07
- **Implementation Started**: 2026-03-07
- **Implementation Completed**: 2026-03-07
- **Language**: neovim
- **Research**: [research-001.md](160_fix_load_core_agent_system_missing_files/reports/research-001.md)
- **Plan**: [implementation-001.md](160_fix_load_core_agent_system_missing_files/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260307.md](160_fix_load_core_agent_system_missing_files/summaries/implementation-summary-20260307.md)

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
