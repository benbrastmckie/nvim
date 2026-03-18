---
next_project_number: 224
---

# TODO

## Tasks

### 223. Improve /deck slide themes with polished examples and documentation
- **Effort**: 6-9 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-17
- **Research Completed**: 2026-03-17
- **Language**: general
- **Dependencies**: None
- **Research**: [01_investor-pitch-themes.md](223_improve_deck_themes_examples_documentation/reports/01_investor-pitch-themes.md)

**Description**: The slide decks created by /deck in the present/ extension need improvement. This task covers: (1) Research online to find the best, most polished slide themes suitable for investor pitch decks - focus on professional VC presentation aesthetics, modern typography, color schemes, and Typst/Touying-compatible patterns; (2) Create .claude/extensions/present/examples/ directory with sample pitch decks demonstrating each recommended theme style - each example should be a complete, compilable Typst file showing the theme applied to a mock startup pitch; (3) Create .claude/extensions/present/README.md documentation explaining extension purpose and capabilities, /deck and /grant commands, available themes with visual descriptions, how to compile and customize decks, and links to the examples/ directory.

---

### 222. Document memory extension usage patterns and expectations
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Started**: 2026-03-17
- **Completed**: 2026-03-17
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_memory-extension-analysis.md](222_document_memory_extension_usage/reports/01_memory-extension-analysis.md)
- **Plan**: [02_implementation-plan.md](222_document_memory_extension_usage/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](222_document_memory_extension_usage/summaries/03_implementation-summary.md)

**Description**: Understand how the memory extension works and create detailed documentation in .claude/extensions/memory/README.md to inform expectations and usage patterns.

---

### 221. Fix phase status marker updates in grant-agent, skill-grant, and latex/typst implementation agents
- **Effort**: 2.25 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-17
- **Research**: [01_phase-status-markers.md](221_fix_phase_status_markers_implementation_agents/reports/01_phase-status-markers.md)
- **Plan**: [02_implementation-plan.md](221_fix_phase_status_markers_implementation_agents/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](221_fix_phase_status_markers_implementation_agents/summaries/03_implementation-summary.md)
- **Language**: meta
- **Dependencies**: None

**Description**: Fix phase status marker updates across implementation agents in the Vision repository. Three issues to address: (1) grant-agent lacks Phase Checkpoint Protocol - does not update plan-level or phase-level status markers ([NOT STARTED] -> [IN PROGRESS] -> [COMPLETED]) during the assemble workflow, unlike general-implementation-agent which has Stage 4A (mark phase in progress) and Stage 4D (mark phase complete) with per-phase git commits; (2) skill-grant lacks calls to update-plan-status.sh at preflight and postflight, unlike skill-implementer which calls this script; (3) latex-implementation-agent and typst-implementation-agent have incomplete phase marker instructions - they mention updates but lack detailed Edit tool patterns and a Phase Checkpoint Protocol section. Fix all three by: adding a Phase Checkpoint Protocol section to grant-agent mirroring general-implementation-agent, adding update-plan-status.sh calls to skill-grant, and expanding phase marker instructions in latex/typst implementation agents. All agents should update TODO.md, state.json, plan file phase headers, and plan metadata consistently.

---

### 220. Add `--fix-it` flag to `/grant` command with grant directory scanning
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-17
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_fix-it-flag-research.md](220_add_fix_it_flag_to_grant_command/reports/01_fix-it-flag-research.md)
- **Plan**: [02_implementation-plan.md](220_add_fix_it_flag_to_grant_command/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](220_add_fix_it_flag_to_grant_command/summaries/03_implementation-summary.md)

**Description**: Add a `--fix-it N` mode to the `/grant` command (`.claude/extensions/present/commands/grant.md`) that scans the grant project directory for embedded `FIX:` and `TODO:` tags and creates structured tasks to implement those changes, following the same interactive pattern as the `/fix-it` command.

**Component 1 — Modify `/grant` command** (`grant.md`): Add `--fix-it` to the Modes table and Mode Detection section. Syntax: `/grant N --fix-it`. Parse the grant number N, validate the task exists in state.json (or archive), extract the slug to locate `grants/{N}_{slug}/`, and abort with a clear message if the directory does not exist. Then delegate to `skill-grant-fix-it` with args `task_number={N} grant_dir=grants/{N}_{slug}/ session_id={session_id}`. Implement GATE IN / GATE OUT checkpoints matching the pattern used by `--draft` and `--budget` modes. Output on success: list of task numbers created and suggested next steps.

**Component 2 — Create `skill-grant-fix-it`** (new file `.claude/extensions/present/skills/skill-grant-fix-it/SKILL.md`): Direct-execution skill that mirrors the logic of `skill-fix-it` but scoped to a grant directory. Steps: (1) Accept `task_number` and `grant_dir` from args. (2) Scan `{grant_dir}` recursively for `FIX:` and `TODO:` tags across all relevant file types (`.tex`, `.md`, `.bib`, `.txt`). Use comment-style patterns appropriate to each type: `% FIX:` / `% TODO:` for `.tex`, `<!-- FIX:` / `<!-- TODO:` for `.md`, `# FIX:` / `# TODO:` for `.bib`/`.txt`. (3) Display tag scan results to the user before any selection. If no tags found, report and exit. (4) Prompt for task type selection via `AskUserQuestion` with `multiSelect: true` — offer "fix-it task" (combine all FIX: tags into one task) and/or "TODO tasks" (one task per selected TODO: item, or grouped by topic). (5) For TODO tasks with 2+ items, offer topic grouping using the same clustering algorithm as `skill-fix-it` (shared key terms, directory proximity, action type). (6) Confirm before creating. (7) Create selected tasks in `specs/state.json` and `specs/TODO.md` with `language="grant"` so they route through the grant workflow. Task descriptions include file paths and line numbers from the scan. (8) Git commit with message `fix-it: create {N} tasks from grant {M} tags`.

**Component 3 — Register in manifest.json**: Add `skill-grant-fix-it` to the `skills` array in `.claude/extensions/present/manifest.json`.

---

### 219. Incorporate ProofChecker documentation, patterns, and /merge command into nvim .claude/ system
- **Effort**: 6-8 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-16
- **Completed**: 2026-03-16
- **Language**: meta
- **Research**: [01_proofchecker-integration.md](219_incorporate_proofchecker_docs_and_patterns/reports/01_proofchecker-integration.md)
- **Plan**: [02_implementation-plan.md](219_incorporate_proofchecker_docs_and_patterns/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](219_incorporate_proofchecker_docs_and_patterns/summaries/03_implementation-summary.md)

**Description**: Incorporate missing documentation, patterns, format schemas, and commands from ProofChecker's `.claude/` system to make the nvim agent system more complete and portable across both GitHub and GitLab repositories. Specifically: (1) Add `blocked-mcp-tools.md` to the lean extension's context as a standalone doc with the unblocking procedure (currently only embedded in mcp-tools-guide.md without formal recovery steps); (2) Create `context/core/reference/state-json-schema.md` — a complete schema reference for state.json; (3) Create `context/core/reference/skill-agent-mapping.md` — maps skills to agents and routing rules (currently only in CLAUDE.md); (4) Create `context/core/patterns/early-metadata-pattern.md` — pattern for writing metadata early to enable recovery from interrupted delegation; (5) Create `context/core/patterns/mcp-tool-recovery.md` — structured retry/fallback patterns for MCP tool failures; (6) Create `context/core/formats/handoff-artifact.md` — schema for teammate handoff documents enabling context-efficient continuation (needed for --team successor pattern); (7) Create `context/core/formats/progress-file.md` — schema for progress-tracking JSON files supporting resumable work; (8) Update `context/index.json` with entries for all new files so agents can discover them; (9) Create `/merge` command in core `.claude/commands/merge.md` — adapt ProofChecker's GitLab-only `/merge` command to auto-detect whether the current repo is GitHub or GitLab (check for `.git/config` remote URL patterns or `gh`/`glab` auth status) and use the appropriate CLI (`gh pr create` for GitHub, `glab mr create` for GitLab), supporting --draft, --title, --body flags and providing unified MR/PR workflow regardless of platform. The reference source is `/home/benjamin/Projects/ProofChecker/.claude/` — read each ProofChecker file, adapt it to the nvim extension-based architecture (removing ProofChecker-specific content, generalizing for a multi-extension/multi-platform system), and place in the correct location.

---

### 218. Implement `--team` flag for `/research` command
- **Effort**: 12-16 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-16
- **Completed**: 2026-03-16
- **Language**: meta
- **Research**: [01_team-flag-research.md](218_implement_team_flag_for_research_command/reports/01_team-flag-research.md)
- **Plan**: [02_team-flag-implementation.md](218_implement_team_flag_for_research_command/plans/02_team-flag-implementation.md)
- **Summary**: [03_team-flag-summary.md](218_implement_team_flag_for_research_command/summaries/03_team-flag-summary.md)

**Description**: Implement `--team` flag for `/research` command to enable parallel multi-agent research using the research-coordinator pattern. Root cause: `--team` is silently ignored — passed as part of the focus prompt text with no flag parsing in research.md. Fix requires: (1) add `--team` flag parsing to research.md, (2) add team routing for the grant language (and other languages), (3) implement or wire up research-coordinator pattern for parallel multi-agent research. Investigation found `--team` was planned in archived task 093 but never implemented.

---

### 217. Revise /grant workflow order: --draft and --budget before /plan
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_grant-improvements.md](217_revise_grant_workflow_order_draft_budget_before_plan/reports/01_grant-improvements.md)
- **Plan**: [02_workflow-improvements.md](217_revise_grant_workflow_order_draft_budget_before_plan/plans/02_workflow-improvements.md)
- **Summary**: [03_workflow-improvements-summary.md](217_revise_grant_workflow_order_draft_budget_before_plan/summaries/03_workflow-improvements-summary.md)

**Description**: Revise the /grant command and related utilities in the present/ extension so that the recommended workflow places --draft and --budget before /plan N. The correct order is: (1) /grant "Description", (2) /research N, (3) /grant N --draft, (4) /grant N --budget, (5) /plan N, (6) /implement N. This means drafting and budgeting happen as part of exploratory work that informs the formal plan, and /plan N creates the implementation plan based on the draft/budget artifacts before /implement N assembles everything into grants/{N}_{slug}/. Update all references to the recommended workflow in grant.md, skill-grant/SKILL.md, grant-agent.md, and EXTENSION.md.

---

### 216. Refactor /grant command to output final materials via /implement to grants/ directory
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_grant-implement-routing.md](216_refactor_grant_implement_output_to_grants_dir/reports/01_grant-implement-routing.md)
- **Plan**: [04_grant-refactor-revised.md](216_refactor_grant_implement_output_to_grants_dir/plans/04_grant-refactor-revised.md)
- **Summary**: [05_grant-refactor-summary.md](216_refactor_grant_implement_output_to_grants_dir/summaries/05_grant-refactor-summary.md)

**Description**: Remove the `--finish` flag from the /grant command and update the grant workflow so that running `/implement N` on a grant task assembles all intermediate artifacts (drafts, budgets from `specs/{NNN}_{SLUG}/`) and writes the final grant output to a new `grants/{NN}_{grant-slug}/` directory in the project root. Files to modify: (1) `grant.md` command — remove Finish Mode section and update recommended workflow output; (2) `skill-grant/SKILL.md` — remove finish workflow type from routing table, validation, and all case statements; (3) `grant-agent.md` — remove finish workflow execution and update routing table; (4) `EXTENSION.md` — update documentation to reflect new workflow ending with `/implement N`; and the grant-specific implementation handling needs to be added so that `/implement N` on a grant task generates the final assembled output in `grants/{NN}_{grant-slug}/`.

---

### 215. Revise /grant command design for elegant integration with core agent system
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_grant-command-design.md](215_revise_grant_command_design/reports/01_grant-command-design.md)
- **Plan**: [03_grant-command-plan.md](215_revise_grant_command_design/plans/03_grant-command-plan.md)
- **Summary**: [04_grant-command-summary.md](215_revise_grant_command_design/summaries/04_grant-command-summary.md)

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
