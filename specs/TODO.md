---
next_project_number: 125
---

# TODO

## Tasks

### 124. Limit [Docs] section in pickers to single README entry
- **Effort**: TBD
- **Status**: [PLANNED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Language**: neovim
- **Research**: [research-001.md](124_limit_docs_section_in_pickers/reports/research-001.md)
- **Plan**: [implementation-001.md](124_limit_docs_section_in_pickers/plans/implementation-001.md)

**Description**: Limit [Docs] section in <leader>ao picker to show only .opencode/docs/README.md and in <leader>ac picker to show only .claude/docs/README.md.

### 123. Fix non-atomic extension loading causing orphaned files
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Language**: neovim
- **Research**: [research-001.md](123_fix_nonatomic_extension_loading/reports/research-001.md), [research-002.md](123_fix_nonatomic_extension_loading/reports/research-002.md)
- **Plan**: [implementation-002.md](123_fix_nonatomic_extension_loading/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260303.md](123_fix_nonatomic_extension_loading/summaries/implementation-summary-20260303.md)

**Description**: The extension loading system in `lua/neotex/plugins/ai/shared/extensions/init.lua` has a non-atomic loading sequence that causes state corruption when load operations fail mid-execution.

**Problem**: The current load sequence:
1. Check for conflicts (line 176)
2. Copy agents to `.claude/agents/` (line 210)
3. Copy commands to `.claude/commands/` (line 227)
4. Copy rules, skills, context, scripts (lines 234-252)
5. Process merge targets (line 255) - **FAILURE POINT** (e.g., `vim.tbl_isarray` crash)
6. Write `extensions.json` state file (line 258)

If step 5 fails, steps 2-4 have already copied files to disk, but step 6 never executes. This leaves:
- Extension files present in `.claude/` directories
- No `extensions.json` state record (or no entry for the failed extension)
- Extension appears "not loaded" but files exist

**Evidence**: Multiple project directories (`Logos/Theory/.claude/`, `ProofChecker/.claude/`) have lean extension files (agents, skills, rules) but no `extensions.json`. Attempting to load the lean extension again shows "files would be overwritten" warning because files exist but state doesn't track them.

**Impact**:
- Confusing UX: "overwrite" warnings for extensions that appear uninstalled
- State corruption: no way to unload properly (unload checks state, not files)
- Manual cleanup required: users must delete orphaned files manually

**Suggested Solutions** (research should evaluate trade-offs):

1. **Early state marker**: Write a preliminary `extensions.json` entry with `status: "loading"` before copying files. On success, update to `status: "loaded"`. On restart, detect `"loading"` state and offer cleanup.

2. **Atomic copy with rollback**: Copy files to a temp directory first, then move atomically. If merge fails, delete temp files. Only update state after successful move.

3. **Recovery detection**: In `check_conflicts()`, also check if files exist but state says "not loaded". Offer to either clean up orphaned files or mark as loaded.

4. **State-first with file tracking**: Write state entry with `files: []` array first, then append each file path as it's copied. On failure, use the array to clean up.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Main load function
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - File copy operations
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - State management

### 122. Expand document-converter extension to filetypes extension
- **Effort**: 10-14 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](122_expand_document_converter_to_filetypes/reports/research-001.md), [research-002.md](122_expand_document_converter_to_filetypes/reports/research-002.md)
- **Plan**: [implementation-002.md](122_expand_document_converter_to_filetypes/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260303.md](122_expand_document_converter_to_filetypes/summaries/implementation-summary-20260303.md)

**Description**: Expand the document-converter extension (`~/.config/nvim/.opencode/extensions/document-converter/`) to be renamed `filetypes/` and include utilities for working with additional filetypes such as Excel and PowerPoint. Equip the agent system with agents, commands, skills, and context files for converting between and developing these filetypes.

### 121. Clean up core skills directories to remove extension-specific skills
- **Effort**: 30-60 minutes
- **Status**: [COMPLETED]
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](121_clean_up_core_skills_directories/reports/research-001.md), [research-002.md](121_clean_up_core_skills_directories/reports/research-002.md), [research-003.md](121_clean_up_core_skills_directories/reports/research-003.md)
- **Plan**: [implementation-002.md](121_clean_up_core_skills_directories/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260303.md](121_clean_up_core_skills_directories/summaries/implementation-summary-20260303.md)

**Description**: Extension-specific skills currently exist in the core skills directories and should be removed. Two locations need cleanup:

1. `~/.config/nvim/.opencode/skills/` has 22 skills including extension-owned ones. Only the 11 core skills should remain (matching `.claude/skills/`): skill-git-workflow, skill-implementer, skill-learn, skill-meta, skill-neovim-implementation, skill-neovim-research, skill-orchestrator, skill-planner, skill-refresh, skill-researcher, skill-status-sync.

2. `~/.config/.claude/skills/` (live Claude config) has 14 skills including 3 extension-specific ones (skill-document-converter, skill-latex-implementation, skill-typst-implementation) that were inadvertently synced.

Skills to remove from `.opencode/skills/`: skill-document-converter (→ document-converter ext), skill-lake-repair (→ lean ext), skill-latex-implementation (→ latex ext), skill-latex-research (→ latex ext), skill-lean-implementation (→ lean ext), skill-lean-research (→ lean ext), skill-lean-version (→ lean ext), skill-logic-research (→ formal ext), skill-math-research (→ formal ext), skill-typst-implementation (→ typst ext), skill-typst-research (→ typst ext).

All extension-specific skills already exist in their correct extension directories (`.opencode/extensions/{ext}/skills/`) and are declared in `provides.skills` in each extension's `manifest.json`. The sync exclusion mechanism in `sync.lua` (`build_extension_exclusions` + `filter_extension_skills`) already correctly filters based on manifests — the problem is the stale copies in the core directories. After cleanup, "Load Core Agent System" will only sync the 11 core skills to projects.

### 120. Fix PreToolUse hook picker display for inline-command hooks
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](120_fix_pretooluse_hook_picker_display/reports/research-001.md), [research-002.md](120_fix_pretooluse_hook_picker_display/reports/research-002.md)
- **Plan**: [implementation-001.md](120_fix_pretooluse_hook_picker_display/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](120_fix_pretooluse_hook_picker_display/summaries/implementation-summary-20260303.md)

**Description**: Fix PreToolUse hook picker display: extend build_hook_dependencies to recognize inline-command hooks so they show '*' when present in the local project's settings.json. Currently parser.lua:build_hook_dependencies uses regex ([^/%s]+%.sh) to extract hook names from command strings, which only matches .sh file references. The PreToolUse hook in settings.json uses an inline bash -c '...' command with no .sh filename, so hook_events["PreToolUse"] stays empty, event_hooks is empty in create_hooks_entries, has_local_hook is always false in format_hook_event, and no '*' is ever shown. The fix should: (1) detect inline-command hooks (those that don't reference a .sh file) in build_hook_dependencies, (2) represent them as a synthetic hook entry so the event can still show '*' when the event key exists in the LOCAL project's settings.json hooks section, (3) determine is_local by checking whether the local project's settings.json has the same hook event key configured (not by checking for a .sh file). The same gap affects any other hook event using inline commands. Key files: lua/neotex/plugins/ai/claude/commands/parser.lua (build_hook_dependencies ~line 334), lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua (format_hook_event ~line 16, create_hooks_entries ~line 494).

### 119. Fix hardcoded paths in picker for config-aware directory scanning
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](119_fix_hardcoded_paths_in_picker/reports/research-001.md)
- **Plan**: [implementation-001.md](119_fix_hardcoded_paths_in_picker/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](119_fix_hardcoded_paths_in_picker/summaries/implementation-summary-20260303.md)

**Description**: Fix hardcoded `.claude/` paths in picker so all directory scanning adapts to the active config (base_dir). Functions `create_scripts_entries`, `create_tests_entries`, `create_lib_entries`, `create_docs_entries`, `create_templates_entries`, and `update_artifact_from_global` should use config.base_dir instead of hardcoded strings, working correctly for both `<leader>ac` (Claude) and `<leader>ao` (OpenCode).

### 118. Redesign <leader>ao picker: rename 'Load All Artifacts' to 'Load Core Agent System'
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](118_redesign_leader_ao_load_core_agent_system/reports/research-001.md), [research-002.md](118_redesign_leader_ao_load_core_agent_system/reports/research-002.md)
- **Plan**: [implementation-001.md](118_redesign_leader_ao_load_core_agent_system/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](118_redesign_leader_ao_load_core_agent_system/summaries/implementation-summary-20260303.md)

**Description**: Redesign the <leader>ao picker so that 'Load All Artifacts' is renamed to 'Load Core Agent System' where this loads everything NOT in an extension. Currently, the global .opencode/ directory has no separation between core system artifacts and extension-specific artifacts (agents/skills/commands). When 'Load All Artifacts' runs, it syncs ALL global content to the project including lean agents, formal agents, python skills, z3 skills, etc. that belong to opt-in extensions. The fix requires: (1) building an exclusion list from all extension manifest.json 'provides' fields to identify extension-owned files/directories, (2) modifying scan_all_artifacts() in sync.lua to skip content that belongs to any extension (checking agents, skills, commands, rules, context, scripts entries), (3) renaming the picker entry from 'Load All Artifacts' to 'Load Core Agent System', (4) verifying that after the change, syncing to /home/benjamin/Projects/ModelChecker/ only loads core system content (general-*, planner, meta-builder agents; core skills; system commands) not extension content (lean, formal, latex, python, nix, web, z3, typst, document-converter). Extensions should only be synced when explicitly loaded via the extension picker entries. Key files: lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua (scan_all_artifacts), lua/neotex/plugins/ai/claude/commands/picker/init.lua (picker entry label), lua/neotex/plugins/ai/shared/picker/config.lua (config), the global .opencode/extensions/*/manifest.json files for building the exclusion list.

### 117. Study core artifacts and extension overlap for Load All Artifacts
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](117_study_core_artifacts_extension_overlap/reports/research-001.md)
- **Plan**: [implementation-001.md](117_study_core_artifacts_extension_overlap/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](117_study_core_artifacts_extension_overlap/summaries/implementation-summary-20260303.md)

**Description**: Study the overlap between core artifacts loaded to /home/benjamin/Projects/ModelChecker/.opencode/ and the extensions. Ensure 'Load All Artifacts' only loads the core agent system, with extensions integrating separately. Before removing elements, verify no important content is lost and keep/integrate the best versions when eliminating redundancies.

### 116. Verify ModelChecker .opencode/ directory and implement claude code extension feature parity
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Implementation Started**: 2026-03-03
- **Implementation Completed**: 2026-03-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](116_verify_opencode_implement_extension_parity/reports/research-001.md), [research-002.md](116_verify_opencode_implement_extension_parity/reports/research-002.md)
- **Plan**: [implementation-003.md](116_verify_opencode_implement_extension_parity/plans/implementation-003.md)
- **Summary**: [implementation-summary-20260303.md](116_verify_opencode_implement_extension_parity/summaries/implementation-summary-20260303.md)

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
