---
next_project_number: 199
---

# TODO

## Tasks

### 198. Review recent .claude/ commits for consistency
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Research**: [01_claude-commit-review.md](198_review_recent_claude_commits_consistency/reports/01_claude-commit-review.md)

**Description**: Review the recent commits which make changes to .claude/ to ensure these are correct and consistent, making any natural improvements.

---

### OC_197. Fix workflow command task number header display
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Research**: [research-001.md](OC_197_fix_workflow_command_task_number_header_display/reports/research-001.md)

**Description**: When running workflow commands in opencode that have task numbers, the header does not always update to show the actual task number. When it does update, it shows generic placeholder 'OC_NNN' instead of the actual task number like 'OC_193'. This appears to be a display/UI bug in the workflow command output formatting. Investigate and fix the task number substitution in workflow command headers.

---

### OC_196. Port wezterm tab integration features from .claude/ to .opencode/
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Research**: [research-001.md](OC_196_port_wezterm_tab_integration_from_claude_to_opencode/reports/research-001.md)

**Description**: Port wezterm tab integration features from the .claude/ agent system to .opencode/. The .claude/ system currently: (1) updates wezterm tabs to show the task number immediately upon running a task-number-based command, and (2) announces the tab number when Claude Code finishes, needs input, or asks a question. These features need to be adapted for opencode-specific details while maintaining the same functionality. This involves examining how .claude/ implements these features (likely through OSC escape sequences or wezterm CLI commands) and creating equivalent functionality in .opencode/.

---

### 195. Standardize artifact naming convention with MM_padded_slug format
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Planning Started**: 2026-03-13
- **Planning Completed**: 2026-03-13
- **Implementation Started**: 2026-03-13
- **Completed**: 2026-03-13
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_195_standardize_artifact_naming_convention_mm_padded_slug/reports/research-001.md)
- **Plan**: [implementation-001.md](OC_195_standardize_artifact_naming_convention_mm_padded_slug/plans/implementation-001.md)
- **Summary**: [03_implementation-summary.md](OC_195_standardize_artifact_naming_convention_mm_padded_slug/summaries/03_implementation-summary.md)

**Description**: When artifacts are created for tasks with OpenCode, they are named such as `/home/benjamin/Projects/Logos/Theory/specs/OC_286_research_n_place_predicate_church_style_systems/reports/research-286.md` which is not correct. Instead, they should use a padded `MM_{short-slug}.md` where the short slug indicates the research topic such as `01_n-place-predicates.md`. Something similar should be done for plans and summaries. Review all commands/skills/agents/rules/context-files/etc that require revision to consistently impose this convention throughout the opencode agent system.

---

### OC_194. Standardize OpenCode task naming consistency
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Planning Started**: 2026-03-13
- **Planning Completed**: 2026-03-13
- **Implementation Started**: 2026-03-13
- **Completed**: 2026-03-13
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_194_standardize_opencode_task_naming_consistency/reports/research-001.md), [research-002.md](OC_194_standardize_opencode_task_naming_consistency/reports/research-002.md)
- **Plan**: [implementation-001.md](OC_194_standardize_opencode_task_naming_consistency/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260313.md](OC_194_standardize_opencode_task_naming_consistency/summaries/implementation-summary-20260313.md)

**Description**: When creating tasks in OpenCode, sometimes they use the OC_N for tasks in TODO.md and specs.json where project directories require padding as in OC_NNN_, but other times OpenCode uses N for tasks in TODO.md and specs.json where project directories are numbered NNN_. Improve consistency so that OC_ is always used for OpenCode tasks. Note: user still wants to be able to run `/research NNN` instead of only being able to run `/research OC_NNN` for an OpenCode created task.

---

### 193. Set default opencode model to Kimi K2.5 OpenCode Go
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-13
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Planning Started**: 2026-03-13
- **Planning Completed**: 2026-03-13
- **Implementation Started**: 2026-03-13
- **Language**: general
- **Dependencies**: None
- **Research**: [research-193.md](193_set_default_opencode_model_to_kimi_k2_5_opencode_go/reports/research-193.md)
- **Plan**: [implementation-001.md](193_set_default_opencode_model_to_kimi_k2_5_opencode_go/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260313.md](193_set_default_opencode_model_to_kimi_k2_5_opencode_go/summaries/implementation-summary-20260313.md)

**Description**: Configure opencode to always start with the model 'Kimi K2.5 OpenCode Go' instead of 'Kimi K2.5 OpenCode Zen' as it does currently. This requires finding where the default model is configured in the opencode system and updating it to use the preferred model.

---

### 192. Bypass opencode permission requests
- **Effort**: 8-10 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-13
- **Research Started**: 2026-03-13
- **Research Completed**: 2026-03-13
- **Planning Started**: 2026-03-13
- **Planning Completed**: 2026-03-13
- **Implementation Started**: 2026-03-13
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](192_bypass_opencode_permission_requests/reports/research-001.md), [research-002.md](192_bypass_opencode_permission_requests/reports/research-002.md), [research-003.md](192_bypass_opencode_permission_requests/reports/research-003.md)
- **Plan**: [implementation-001.md](192_bypass_opencode_permission_requests/plans/implementation-001.md), [implementation-002.md](192_bypass_opencode_permission_requests/plans/implementation-002.md), [implementation-003.md](192_bypass_opencode_permission_requests/plans/implementation-003.md)
- **Summary**: [implementation-summary-20260313.md](192_bypass_opencode_permission_requests/summaries/implementation-summary-20260313.md)

**Description**: Investigate and implement a way to bypass all permission requests in the local .opencode/ agent system. Currently, opencode frequently asks for permission to access external directories (e.g., `/tmp/*`) with dialog options for Once, Always, or Reject. The user wants to prevent these permission prompts always by configuring the system to automatically allow such permissions.

---

### 191. Fix typst compilation error reporting
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-12
- **Implementation Started**: 2026-03-12
- **Planning Completed**: 2026-03-12
- **Planning Started**: 2026-03-12
- **Research Completed**: 2026-03-12
- **Research Started**: 2026-03-12
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](191_typst_compilation_error_reporting/reports/research-001.md)
- **Plan**: [implementation-001.md](191_typst_compilation_error_reporting/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260312.md](191_typst_compilation_error_reporting/summaries/implementation-summary-20260312.md)

**Description**: Fix typst compilation error reporting in neovim. When running `<leader>lr` (compile once) on a chapter file, compilation fails with exit code 1 but the error details are not captured. When running `<leader>le` (show errors), no errors appear in quickfix even though compilation failed. Errors should be captured from typst stderr and displayed in the quickfix list.

---

### 190. Investigate UX inconsistencies and improve command outputs
- **Effort**: 6-8 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-12
- **Research Completed**: 2026-03-12
- **Planning Started**: 2026-03-12
- **Planning Completed**: 2026-03-12
- **Implementation Started**: 2026-03-12
- **Completed**: 2026-03-12
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](190_investigate_ux_inconsistencies_and_improve_command_outputs/reports/research-001.md), [research-002.md](190_investigate_ux_inconsistencies_and_improve_command_outputs/reports/research-002.md), [research-003.md](190_investigate_ux_inconsistencies_and_improve_command_outputs/reports/research-003.md)
- **Plan**: [implementation-002.md](190_investigate_ux_inconsistencies_and_improve_command_outputs/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260312.md](190_investigate_ux_inconsistencies_and_improve_command_outputs/summaries/implementation-summary-20260312.md)

**Description**: Investigate UX inconsistencies throughout the .claude/ agent system (commands, skills, agents) in order to standardize the approach where it makes sense and otherwise improve the UX by making simplifications or additions as appropriate. Key known issues include: inconsistent "next step" suggestion formats across commands (some use `Next: /cmd N`, others use numbered lists, others use varied vocabulary like "Suggested", "Recommended", "Next Steps"); lack of a unified output formatting standard for command completions; and the finding that Claude Code's auto-suggest feature is not triggered by command output formatting (it's session-level) meaning users must type suggestions manually. The investigation should audit all commands for output consistency, identify other UX pain points, and propose/implement a clean, unified approach.

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
