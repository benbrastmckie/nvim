---
next_project_number: 174
---

# TODO

## Tasks

### 173. Rename /learn command to /fix-it in .claude/ system
- **Status**: [PLANNED]
- **Language**: meta
- **Research**: [research-001.md](173_rename_learn_command_to_fix_it/reports/research-001.md)
- **Plan**: [implementation-001.md](173_rename_learn_command_to_fix_it/plans/implementation-001.md)

**Description**: Rename the /learn command to /fix-it in the .claude/ system, updating all references throughout so nothing breaks. This includes: the command file itself (.claude/commands/learn.md -> fix-it.md), the skill file (skill-learn -> skill-fix-it or appropriate name), CLAUDE.md command reference table, agent frontmatter skill references, any keybinding or picker entries that reference the learn command, and any documentation that references /learn.

### 172. Investigate OPENCODE.md core content loss on <leader>ao reload
- **Status**: [COMPLETED]
- **Research Completed**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Completed**: 2026-03-10
- **Summary**: Created global AGENTS.md (165 lines), updated sync.lua root_file_names, modified all 11 extension manifests to target AGENTS.md, hardened merge.lua inject_section to seed from README.md.
- **Language**: neovim
- **Research**: [research-001.md](172_investigate_opencode_core_content_loss_on_reload/reports/research-001.md)
- **Plan**: [implementation-002.md](172_investigate_opencode_core_content_loss_on_reload/plans/implementation-002.md) (revised)

**Description**: Investigate why OPENCODE.md loses core content after reload via `<leader>ao`. Root cause analysis of whether the issue is in the agent system structure or the loader itself. Task 171 merged core README.md content into OPENCODE.md but a subsequent reload via `<leader>ao` reverted the file back to extension-only content (starting with `extension_oc_epidemiology` marker). This is the second occurrence: task 170 phase 2 applied the same fix and it was also lost. The loader appears to be regenerating OPENCODE.md from extension sections only, ignoring or overwriting the core content. Need to: (1) trace the `<leader>ao` loader code path that writes OPENCODE.md, (2) understand whether the loader assembles OPENCODE.md from `.opencode_core/README.md` + extension sections or only from extension sections, (3) determine why core content is being dropped, (4) implement a fix either in the loader (to include core content when generating OPENCODE.md) or in the agent system structure (e.g., make OPENCODE.md the source of truth and stop overwriting it).

### 171. Re-audit agent systems after core reload and extension re-load
- **Effort**: 0.25-0.5 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Completed**: 2026-03-10
- **Summary**: Merged core README.md content into OPENCODE.md in Vision project. File now has 833 lines with core content followed by 11 extension sections.
- **Language**: meta
- **Research**: [research-001.md](171_re_audit_agent_systems_post_reload/reports/research-001.md)
- **Plan**: [implementation-001.md](171_re_audit_agent_systems_post_reload/plans/implementation-001.md)

**Description**: Re-audit agent systems after core reload and extension re-load to verify no gaps remain following task 170 repairs. The user has deleted and reloaded .claude_core/ and .opencode_core/ (fresh core baselines) and reloaded all extensions into .claude/ and .opencode/ in /home/benjamin/Projects/Logos/Vision/. Verify: (1) core systems are clean with correct agent/skill/rule counts and no extension contamination, (2) extended systems have all core + extension content present, (3) context/index.json entries match disk files and counts are correct, (4) validate-wiring.sh passes 35/35 for both extended systems, (5) the 32 context files indexed in task 170 are still present and indexed correctly, (6) project-overview.md reference is still valid, (7) OPENCODE.md still has core content + all 11 extension sections.

### 170. Audit agent systems for complete wiring correctness
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Research**: [research-001.md](170_audit_agent_systems_wiring_correctness/reports/research-001.md)
- **Plan**: [implementation-001.md](170_audit_agent_systems_wiring_correctness/plans/implementation-001.md)
- **Summary**: Repaired .opencode extended system in Vision project (copied 5 core agents, 12 skills, 5 rules, 20 commands, 16 scripts, merged 155 index entries). Added 32 unindexed context files across 8 extensions. Created project-overview.md for Vision project.

**Description**: Carefully audit the core and extended agent systems in both .claude/ and .opencode/ (with .claude_core/ and .opencode_core/ available for comparison) to ensure everything is working correctly and no gaps remain from the work in tasks 163-169. The following must be verified:

**1. Core system completeness** (.claude_core/ and .opencode_core/):
- Exactly 4 agents present (general-research, general-implementation, planner, meta-builder) — no extension agents
- Exactly the right core skills present — no extension skills
- Core rules only (no neovim-lua.md, web-astro.md, lean4.md, etc.)
- Core context directories only (meta/, repo/, hooks/, processes/) — no project/neovim, project/lean4, etc.
- context/index.json references only core context files and all referenced files exist on disk
- CLAUDE.md routing table covers only core languages (general, meta, markdown) with extension note
- OPENCODE.md equivalent wiring correct
- settings.local.json / settings.json correctly scoped to core

**2. Extension source completeness** (.claude/extensions/{ext}/ and .opencode/extensions/{ext}/):
For each extension (epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3):
- manifest.json declares correct provides (agents, skills, rules, context) matching actual source files
- agents/ subdirectory contains all declared agent .md files
- skills/ subdirectory contains all declared skill directories with SKILL.md
- rules/ subdirectory contains all declared rule files (where applicable)
- context/ subdirectory contains all files referenced by index-entries.json
- EXTENSION.md exists and documents the extension's routing table and skill-to-agent mappings
- index-entries.json entries all reference files that actually exist in context/
- settings-fragment.json present where needed
- .claude vs .opencode manifests have correct system-specific merge_targets (claudemd vs opencode_md, correct section_id prefixes)

**3. Extension loading correctness** (compare .claude/ vs .claude_core/ after loading all extensions):
- All extension agents appear in .claude/agents/ after loading
- All extension skills appear in .claude/skills/ after loading
- All extension rules appear in .claude/rules/ after loading
- All extension context files appear in .claude/context/project/ after loading
- context/index.json in .claude/ contains both core entries AND all extension entries
- CLAUDE.md contains injected EXTENSION.md sections for each loaded extension with correct section markers (<!-- SECTION: extension_{name} -->)
- OPENCODE.md contains correct markers (<!-- SECTION: extension_oc_{name} -->)
- extensions.json state file correctly tracks loaded extensions and installed files

**4. Routing wiring end-to-end** (for each language type):
- CLAUDE.md routing table maps each language to correct skill
- That skill exists in .claude/skills/ and its SKILL.md delegates to the correct agent
- That agent exists in .claude/agents/ with correct model, skills frontmatter
- Agent's skills frontmatter references skills that exist
- context/index.json has entries with load_when.agents matching the agent name
- Those context files exist on disk

**5. Loader mechanics** (Neovim Lua loaders <leader>ac and <leader>ao):
- Loader correctly identifies extension source directories
- Loader copies agents/skills/rules/context from extension source to target
- Loader merges index-entries.json into context/index.json (additive, no duplicates)
- Loader injects EXTENSION.md into CLAUDE.md/OPENCODE.md with correct section markers
- Loader updates extensions.json state for rollback/unload support
- Loader's post-load verify.lua correctly uses config.section_prefix (not hardcoded)
- verify.lua verify_context checks files in index-entries.json against TARGET directory (not source)
- Unloader correctly removes all installed files and reverts merged sections

**6. Cross-system parity and independence**:
- .claude/ and .opencode/ systems are independent (no shared state files)
- Equivalent extensions exist in both systems with appropriate system-specific differences
- .opencode/ uses correct path conventions (agent/subagents/ not agents/)
- .opencode/ uses extension_oc_ section prefix, not extension_

**7. Known issues from tasks 163-169 to recheck**:
- All 474 extension files correctly placed in extension source dirs (not just core)
- verify.lua config.section_prefix fix applied (not hardcoded extension_)
- nvim .opencode index-entries.json synced with .claude version
- No stray files in core from previous extension merges
- No broken @-references in CLAUDE.md pointing to extension paths that no longer exist in core

---

### 169. Verify agent systems are wired correctly after reload
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Research**: [research-001.md](169_verify_agent_systems_wired_after_reload/reports/research-001.md), [research-002.md](169_verify_agent_systems_wired_after_reload/reports/research-002.md)
- **Plan**: [implementation-001.md](169_verify_agent_systems_wired_after_reload/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](169_verify_agent_systems_wired_after_reload/summaries/implementation-summary-20260310.md)

**Description**: Verify agent systems are wired correctly after reload. Check .claude/ and .opencode/ have appropriate task types available so the right subagents are called by task type, and agents load an index with correct context files.

---

### 168. Verify core agent system loading without extensions
- **Effort**: TBD
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Research**: [research-001.md](168_verify_core_agent_system_loading/reports/research-001.md), [research-002.md](168_verify_core_agent_system_loading/reports/research-002.md)
- **Plan**: [implementation-002.md](168_verify_core_agent_system_loading/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260310.md](168_verify_core_agent_system_loading/summaries/implementation-summary-20260310.md)

**Description**: Verify that the core agent systems reloaded in .claude/ and .opencode/ in /home/benjamin/Projects/Logos/Vision/ contain no missing elements and are wired together correctly. These should ONLY include the core agent systems without extensions, where just the task types covered by the core system are available, and agents have access to an appropriate index of the context files included in the core agent systems.

---

### 167. Verify and revise agent system loaders for .claude/ and .opencode/
- **Effort**: 6-8 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: neovim
- **Research**: [research-001.md](167_verify_revise_agent_system_loaders/reports/research-001.md), [research-002.md](167_verify_revise_agent_system_loaders/reports/research-002.md)
- **Plan**: [implementation-001.md](167_verify_revise_agent_system_loaders/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](167_verify_revise_agent_system_loaders/summaries/implementation-summary-20260310.md)

**Description**: Verify that the core agent systems loaded via <leader>ac and <leader>ao keymaps for .claude/ and .opencode/ respectively in /home/benjamin/Projects/Logos/Vision/ are correct with no missing elements or inappropriate additions. Revise the agent system loaders or the agent system contents if needed while making no unnecessary changes.

---

### 166. Move NeoVim-specific elements to nvim/ extension in .claude/ and .opencode/ agent systems
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Research**: [research-001.md](166_move_neovim_elements_to_nvim_extension/reports/research-001.md)
- **Plan**: [implementation-001.md](166_move_neovim_elements_to_nvim_extension/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](166_move_neovim_elements_to_nvim_extension/summaries/implementation-summary-20260310.md)

**Description**: Move the NeoVim-specific elements of both the .claude/ and .opencode/ agent systems to a nvim/ extension within each system, making sure that everything is wired up correctly so that when loaded these are available for use (adding 'neovim' to the available task types so that the correct agents get called which then have access to the correct context files). The systems should be kept separate and independent, though similar changes are required (be careful to respect any differences that may be required).

---

### 165. Review .opencode/ agent system extension language routing for correct agent and context loading
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Research**: [research-001.md](165_review_opencode_extension_language_routing/reports/research-001.md)
- **Plan**: [implementation-001.md](165_review_opencode_extension_language_routing/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](165_review_opencode_extension_language_routing/summaries/implementation-summary-20260310.md)

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
