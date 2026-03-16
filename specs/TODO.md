---
next_project_number: 216
---

# TODO

## Tasks

### 215. Revise /grant command design for elegant integration with core agent system
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Research**: [01_grant-command-design.md](215_revise_grant_command_design/reports/01_grant-command-design.md)

**Description**: Revise the /grant command to work like the /task command except that it should create a task with the type set to 'grant'. Review the best options for an elegant design that avoids redundancy with /research, /plan, and /implement commands while maintaining modularity. Consider whether /grant should support --draft and --budget flags for grant-specific stages, or whether these should be separate commands. The design should integrate naturally with the existing core agent system while fitting in among the other extensions.

---

### 210. Rename grant/ extension directory to present/
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Plan**: [01_rename-extension-dir.md](210_rename_grant_extension_to_present/plans/01_rename-extension-dir.md)
- **Summary**: [01_rename-extension-summary.md](210_rename_grant_extension_to_present/summaries/01_rename-extension-summary.md)

**Description**: Rename the extension directory from `.claude/extensions/grant/` to `.claude/extensions/present/`. Update manifest.json: change `name` field from "grant" to "present", `language` field from "grant" to "present", and `merge_targets.claudemd.section_id` from "extension_grant" to "extension_present". This is the foundational rename that all subsequent tasks depend on.

---

### 211. Move deck elements from filetypes/ to present/
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #210
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Plan**: [01_move-deck-files.md](211_move_deck_elements_to_present/plans/01_move-deck-files.md)
- **Summary**: [01_move-deck-summary.md](211_move_deck_elements_to_present/summaries/01_move-deck-summary.md)

**Description**: Move deck-related files from the filetypes/ extension into the renamed present/ extension. Files to move: `agents/deck-agent.md`, `commands/deck.md`, `skills/skill-deck/SKILL.md`, and context patterns `context/project/filetypes/patterns/pitch-deck-structure.md` and `context/project/filetypes/patterns/touying-pitch-deck-template.md`. Move context patterns to `context/project/present/patterns/` in the present/ extension.

---

### 212. Update present/ extension metadata for deck integration
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #211
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Plan**: [01_update-metadata.md](212_update_present_extension_metadata_for_deck/plans/01_update-metadata.md)
- **Summary**: [01_update-metadata-summary.md](212_update_present_extension_metadata_for_deck/summaries/01_update-metadata-summary.md)

**Description**: Update present/ extension configuration to register the newly moved deck components. Update `manifest.json` provides arrays: add "deck-agent.md" to agents, "skill-deck" to skills, "deck.md" to commands. Update `EXTENSION.md`: add a deck documentation section and revise the title to reflect both grant writing and presentation capabilities. Update `index-entries.json`: add the two deck context entries (pitch-deck-structure.md, touying-pitch-deck-template.md) with correct present/ paths and load_when referencing deck-agent and /deck command. Update `deck-agent.md` to change all `@context/project/filetypes/patterns/` references to `@context/project/present/patterns/`.

---

### 213. Clean up filetypes/ extension after deck migration
- **Effort**: 30 min
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #211
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_filetypes-cleanup-research.md](213_cleanup_filetypes_extension_after_deck_migration/reports/01_filetypes-cleanup-research.md)
- **Plan**: [02_cleanup-filetypes-plan.md](213_cleanup_filetypes_extension_after_deck_migration/plans/02_cleanup-filetypes-plan.md)
- **Summary**: [03_cleanup-filetypes-summary.md](213_cleanup_filetypes_extension_after_deck_migration/summaries/03_cleanup-filetypes-summary.md)

**Description**: Remove all deck-related references from the filetypes/ extension after deck components have been moved to present/. Remove "deck-agent.md" from `manifest.json` agents array, "skill-deck" from skills array, and "deck.md" from commands array. Remove the deck documentation section from `EXTENSION.md`. Remove the two deck context entries (pitch-deck-structure.md, touying-pitch-deck-template.md) from `index-entries.json`.

---

### 214. Restructure context/project/grant/ to context/project/present/
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #212
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_context-restructure-research.md](214_restructure_context_grant_to_present/reports/01_context-restructure-research.md)
- **Plan**: [01_context-restructure-plan.md](214_restructure_context_grant_to_present/plans/01_context-restructure-plan.md)
- **Summary**: [01_context-restructure-summary.md](214_restructure_context_grant_to_present/summaries/01_context-restructure-summary.md)

**Description**: Rename the context subdirectory from `context/project/grant/` to `context/project/present/` within the present/ extension. Update all 16 path entries in `index-entries.json` from `project/grant/` to `project/present/` (including README and all domain/patterns/standards/templates/tools files). Update `grant-agent.md` all `@context/project/grant/` @-references to `@context/project/present/`. Update any `@.claude/context/project/grant/` references in `EXTENSION.md` to `@.claude/context/project/present/`. Update the `provides.context` field in `manifest.json` from "project/grant" to "project/present".

---

### 209. Create EXTENSION.md and index-entries.json for grant extension
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #207, Task #208
- **Created**: 2026-03-15
- **Completed**: 2026-03-16
- **Research**: [01_extension-metadata-research.md](209_create_extension_metadata/reports/01_extension-metadata-research.md)
- **Plan**: [02_extension-metadata-plan.md](209_create_extension_metadata/plans/02_extension-metadata-plan.md)
- **Summary**: [03_extension-metadata-summary.md](209_create_extension_metadata/summaries/03_extension-metadata-summary.md)

**Description**: Create the EXTENSION.md file with content to inject into CLAUDE.md when the grant extension is loaded, and index-entries.json with canonical paths for context discovery. This finalizes the extension for use with the `<leader>ac` loader.

---

### 208. Create grant context files for domain knowledge
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #204
- **Created**: 2026-03-15
- **Research**: [01_grant-context-patterns.md](208_create_grant_context_files/reports/01_grant-context-patterns.md)
- **Plan**: [01_grant-context-plan.md](208_create_grant_context_files/plans/01_grant-context-plan.md)
- **Summary**: [01_grant-context-summary.md](208_create_grant_context_files/summaries/01_grant-context-summary.md)

**Description**: Create context files in grant/context/ containing domain knowledge for grant writing. Include templates, funder research patterns, proposal structure guidelines, and budget justification formats. These files will be progressively loaded by the grant-agent based on task needs.

---

### 207. Create /grant command
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #206
- **Created**: 2026-03-15
- **Completed**: 2026-03-16
- **Research**: [01_grant-command-research.md](207_create_grant_command/reports/01_grant-command-research.md)
- **Plan**: [02_grant-command-plan.md](207_create_grant_command/plans/02_grant-command-plan.md)
- **Summary**: [03_grant-command-summary.md](207_create_grant_command/summaries/03_grant-command-summary.md)

**Description**: Create grant/commands/grant.md command following existing command patterns. The command should parse arguments (e.g., project name, funder, deadline), invoke skill-grant via the Skill tool, and handle postflight operations including git commits.

---

### 206. Create skill-grant thin wrapper
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #205
- **Created**: 2026-03-15
- **Research**: [01_skill-wrapper-patterns.md](206_create_skill_grant_wrapper/reports/01_skill-wrapper-patterns.md)
- **Plan**: [01_skill-grant-plan.md](206_create_skill_grant_wrapper/plans/01_skill-grant-plan.md)
- **Summary**: [01_skill-grant-summary.md](206_create_skill_grant_wrapper/summaries/01_skill-grant-summary.md)

**Description**: Create grant/skills/skill-grant/SKILL.md as a thin wrapper that validates inputs, prepares delegation context, invokes grant-agent via the Agent tool, validates the return, and propagates results. Follow the skill-meta pattern for internal postflight handling.

---

### 205. Create grant-agent with research and writing capabilities
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #204
- **Created**: 2026-03-15
- **Research**: [01_grant-agent-patterns.md](205_create_grant_agent/reports/01_grant-agent-patterns.md)
- **Plan**: [01_grant-agent-plan.md](205_create_grant_agent/plans/01_grant-agent-plan.md)
- **Summary**: [01_grant-agent-summary.md](205_create_grant_agent/summaries/01_grant-agent-summary.md)

**Description**: Create grant/agents/grant-agent.md with capabilities for grant proposal research and writing. The agent should support: funder research (using WebSearch, WebFetch), proposal drafting, budget justification, and progress tracking. Include progressive context loading from grant/context/ files.

---

### 204. Create grant extension scaffold with manifest.json
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-15
- **Research**: [01_extension-scaffold-patterns.md](204_create_grant_extension_scaffold/reports/01_extension-scaffold-patterns.md), [02_grant-best-practices.md](204_create_grant_extension_scaffold/reports/02_grant-best-practices.md)
- **Plan**: [01_extension-scaffold-plan.md](204_create_grant_extension_scaffold/plans/01_extension-scaffold-plan.md)
- **Summary**: [01_extension-scaffold-summary.md](204_create_grant_extension_scaffold/summaries/01_extension-scaffold-summary.md)

**Description**: Create the foundational grant/ extension directory structure following existing extension patterns (nvim, lean). Create manifest.json with extension metadata including name, version, description, provides arrays (commands, skills, agents), and merge_targets for context index integration.

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
