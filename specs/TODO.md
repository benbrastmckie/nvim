---
next_project_number: 187
---

# TODO

## Tasks

### 186. Filter extension artifacts from "Load Core Agent System" sync
- **Effort**: 3-5 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-11
- **Research Completed**: 2026-03-11
- **Research**: [research-001.md](186_filter_extension_artifacts_from_core_sync/reports/research-001.md)
- **Language**: meta
- **Dependencies**: None

**Description**: The "Load Core Agent System" picker action (`<leader>ac` / `<leader>ao`) syncs artifacts from the global nvim config to the target project. Currently it has no mechanism to distinguish "core" artifacts from "extension" artifacts, causing extension-provided agents, skills, and (for .claude/) commands to leak into every project that loads the core system.

The root cause is `scan_directory_for_sync()` in `scan.lua` which performs an unfiltered glob of the global `.claude/` and `.opencode/` directories. For `.claude/`, extensions install symlinks into `agents/`, `skills/`, and `commands/` directories; the glob follows those symlinks and copies them as real files to the target. For `.opencode/`, extensions copy real files into `skills/` (30 extension skills currently present alongside 12 core skills); these are indistinguishable from core artifacts during sync.

**Scope of leakage** (approximate current state):

| System | Category | Core | Extension | Leaks |
|--------|----------|------|-----------|-------|
| .claude/ | Commands | 11 | 7 symlinks | 7 |
| .claude/ | Agents | 4 | 9 symlinks | 9 |
| .claude/ | Skills | 10 | 11 symlinks | 11 |
| .opencode/ | Commands | 12 | 0 | 0 |
| .opencode/ | Agents | 5 | 0 | 0 |
| .opencode/ | Skills | 12 | 30 copies | 30 |

**Proposed fix**: Filter extension artifacts from sync using extension manifests as the authoritative blocklist. Each extension declares `provides.agents`, `provides.commands`, `provides.skills` etc. in its `manifest.json`. The sync operation should aggregate all extension manifests' `provides` lists and exclude those filenames/directories from the scan result, for both `.claude/` and `.opencode/` systems.

**Key files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` — add manifest-based filtering to `scan_directory_for_sync()`
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — thread the extension blocklist into `scan_all_artifacts()`
- Possibly `lua/neotex/plugins/ai/shared/extensions/manifest.lua` — add a utility to aggregate `provides` across all extensions

**Alternative considered**: Symlink detection (skip symlinks in `.claude/` scans) — simpler but only works for `.claude/`, not `.opencode/`.

---

### 185. Remove extension-specific commands from core agent system
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-11
- **Research Completed**: 2026-03-11
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Implementation Started**: 2026-03-11
- **Implementation Completed**: 2026-03-11
- **Research**: [research-001.md](185_remove_extension_commands_from_core_system/reports/research-001.md)
- **Plan**: [implementation-001.md](185_remove_extension_commands_from_core_system/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260311.md](185_remove_extension_commands_from_core_system/summaries/implementation-summary-20260311.md)
- **Language**: meta
- **Dependencies**: None

**Description**: Remove extension-specific commands from core agent system - lake, lean, convert, deck, slides, and table commands belong in their respective extensions (lean and filetypes), not in core; also clean up the language routing tables in research.md and implement.md to only list core languages (general, meta, markdown), with extension languages injected by the extension loader when extensions are activated.

---

### 184. Revise /learn command input modes
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-11
- **Research Completed**: 2026-03-11
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Implementation Started**: 2026-03-11
- **Implementation Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-002.md](184_revise_learn_command_input_modes/reports/research-002.md) - MCP tools, recursive scanning, content mapping, memory deduplication, topic organization
- **Plan**: [implementation-002.md](184_revise_learn_command_input_modes/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260311.md](184_revise_learn_command_input_modes/summaries/implementation-summary-20260311.md)

**Description**: Revise /learn command in .opencode/ to accept file path, directory path, prompt text, or --task N flag for extracting memories from different sources.

---

### 183. Manage opencode.json via extension system
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-11
- **Research Completed**: 2026-03-11
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Implementation Started**: 2026-03-11
- **Implementation Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](183_manage_opencode_json_via_extension_system/reports/research-001.md)
- **Plan**: [implementation-001.md](183_manage_opencode_json_via_extension_system/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260311.md](183_manage_opencode_json_via_extension_system/summaries/implementation-summary-20260311.md)

**Description**: Design and implement opencode.json management in the `<leader>ao` extension system. Currently opencode.json is not managed by the extension loader, creating a fragile dependency where agents referenced via `{file:...}` in opencode.json fail at startup if the required extensions haven't been loaded. The fix: the core agent system should install a base opencode.json (backing up any existing one), and extensions should be able to add agent definitions to opencode.json when loaded and remove them when unloaded — similar to how extensions currently merge into AGENTS.md. This makes opencode.json a fully managed artifact with clean extension lifecycle semantics.

---

### 182. Fix Website opencode multi-extension agent dependency
- **Effort**: 0.5-1 hours
- **Status**: [COMPLETED]
- **Implementation Started**: 2026-03-11
- **Implementation Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: None
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Research**: [research-001.md](182_fix_website_opencode_multi_extension_agent_dependency/reports/research-001.md), [research-002.md](182_fix_website_opencode_multi_extension_agent_dependency/reports/research-002.md), [research-003.md](182_fix_website_opencode_multi_extension_agent_dependency/reports/research-003.md) - Zero-overlap architecture
- **Plan**: [implementation-003.md](182_fix_website_opencode_multi_extension_agent_dependency/plans/implementation-003.md) (zero-overlap)
- **Summary**: [implementation-summary-20260311.md](182_fix_website_opencode_multi_extension_agent_dependency/summaries/implementation-summary-20260311.md)

**Description**: Eliminate extension overlap: remove document-converter-agent from web extension (filetypes provides document-agent), keep neovim agents in nvim extension only, update Website opencode.json to remove unused agent references.

---

### 181. Fix Website opencode missing agent files
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](181_fix_website_opencode_missing_agent_files/reports/research-001.md)
- **Plan**: [implementation-001.md](181_fix_website_opencode_missing_agent_files/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](181_fix_website_opencode_missing_agent_files/summaries/implementation-summary-20260310.md)

**Description**: Opencode fails to start in `/home/benjamin/Projects/Logos/Website/` because `opencode.json` references 5 agent files via `{file:...}` that don't exist: `web-research-agent.md`, `web-implementation-agent.md`, `neovim-research-agent.md`, `neovim-implementation-agent.md`, `document-converter-agent.md`. Root cause is an incomplete refactoring from `.opencode/agents/*.md` to `.opencode/agent/subagents/*-agent.md` - old files were deleted but 5 new ones were never created. Fix: create the 5 missing agent files in `.opencode/agent/subagents/` (content can be recovered from git history).

---

### 180. Investigate .opencode/ dependency on .claude/ MCP server settings
- **Effort**: 0.5-1 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](180_investigate_opencode_claude_dependency/reports/research-001.md)
- **Plan**: [implementation-001.md](180_investigate_opencode_claude_dependency/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](180_investigate_opencode_claude_dependency/summaries/implementation-summary-20260310.md)

**Description**: Investigation of cross-system dependency between .opencode/ and .claude/ agent systems. When loading the memory extension in the Website repo, the opencode.json references agents (web-research, neovim-research, etc.) that don't exist. The memory extension only provides memory-specific functionality (commands, skills, context, data) and does NOT provide general-purpose agents. This creates a dependency issue where repos with custom opencode.json configurations expect a full agent system that the memory extension doesn't provide. Documented findings and proposed solutions: 1) Create missing agents directly in Website repo, 2) Create separate "core" extension for general agents, 3) Modify Website repo to not reference non-existent agents.

---

### 179. Fix memory extension data directory loading location
- **Effort**: 0.5 hours
- **Status**: [COMPLETED]
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](179_fix_memory_extension_data_directory_loading/reports/research-001.md)
- **Plan**: [implementation-001.md](179_fix_memory_extension_data_directory_loading/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](179_fix_memory_extension_data_directory_loading/summaries/implementation-summary-20260310.md)

**Description**: When loading the memory extension via `<leader>ao`, the data directory is incorrectly placed at `.opencode/memory/` instead of the project root `.memory/`. This happens because `copy_data_dirs()` in `lua/neotex/plugins/ai/shared/extensions/init.lua:297` is called with `target_dir` (which is `.opencode/`) instead of `project_dir` (which is the project root). The loader function expects `project_dir` but receives `target_dir`, causing the vault to be created in the wrong location. Additionally, verify that existing `.memory/` directories are not overwritten - the merge-copy semantics should preserve existing user data. Required fix: Change line 297 parameter from `target_dir` to `project_dir`.

---

### 178. Fix memory extension MCP server port configuration
- **Effort**: 0.5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](178_fix_memory_extension_mcp_port/reports/research-001.md)
- **Plan**: [implementation-001.md](178_fix_memory_extension_mcp_port/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260310.md](178_fix_memory_extension_mcp_port/summaries/implementation-summary-20260310.md)

**Description**: Fix the memory extension's `--remember` flag which fails because the research command attempts to connect to the MCP server on port 3000 instead of the correct port 27124. The Obsidian CLI REST plugin runs on port 27124, causing all memory-augmented research to silently fail with "MCP unavailable". Required fixes: 1) Update research command to use port 27124, 2) Add MCP server configuration to settings.local.json, 3) Document user setup requirements (Obsidian plugin installation, API key configuration).

---

### 177. Remove all model preferences from opencode system
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](177_remove_model_preferences_from_opencode/reports/research-001.md)
- **Plan**: [implementation-001.md](177_remove_model_preferences_from_opencode/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)

**Description**: Remove all model preferences from the opencode agent system to fix ProviderModelNotFoundError when invoking planner-agent. The issue is that agent files (like planner-agent.md) specify `model: opus` in their frontmatter, but settings.json only has `"model": "sonnet"` with no `models` configuration section. This causes delegation to fail when the system cannot find a provider for "opus". Systematically remove all model preferences from:
1. `.opencode/settings.json` - remove `"model": "sonnet"`
2. All agent files in `.opencode/agent/subagents/*.md` - remove `model:` from frontmatter
3. Any other files that specify model preferences

This ensures the system uses the default model without provider lookup failures.

---

### 176. Port Vision memory system changes to neovim configuration
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-11
- **Planning Completed**: 2026-03-11
- **Implementation Started**: 2026-03-11
- **Implementation Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-002.md](176_port_vision_memory_system_changes_to_neovim/reports/research-002.md)
- **Plan**: [implementation-002.md](176_port_vision_memory_system_changes_to_neovim/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260311.md](176_port_vision_memory_system_changes_to_neovim/summaries/implementation-summary-20260311.md)

**Description**: Review the recent changes to /home/benjamin/Projects/Logos/Vision/ where the obsidian memory system was successfully implemented. Note the change from .opencode/memory/ to .memory/ directory structure (matching the specs/ location outside both agent systems). Review the recent changes and git commits in Vision to port all those changes to this neovim configuration system, keeping in mind that neovim contains the memory extension itself which gets loaded elsewhere in other repos using <leader>ao for opencode.

---

### 175. Port memory/ extension to .claude/ agent system
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-11
- **Language**: meta
- **Dependencies**: Task 176
- **Research**: [research-001.md](175_port_memory_extension_to_claude/reports/research-001.md), [research-002.md](175_port_memory_extension_to_claude/reports/research-002.md), [research-003.md](175_port_memory_extension_to_claude/reports/research-003.md) - Claude Code MCP and Obsidian integration
- **Plan**: [implementation-001.md](177_remove_model_preferences_from_opencode/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)

**Description**: Port the memory/ extension included in .opencode/ over to .claude/ while respecting any differences that may exist for proper integration into the .claude/ agent system.

---

### 174. Study .opencode/memory/ systems for memory extension creation
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-10
- **Research Completed**: 2026-03-10
- **Planning Started**: 2026-03-10
- **Planning Completed**: 2026-03-10
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](174_study_opencode_memory_extension/reports/research-001.md)
- **Plan**: [implementation-001.md](177_remove_model_preferences_from_opencode/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)
- **Plan**: [implementation-001.md](174_study_opencode_memory_extension/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)
- **Summary**: [implementation-summary-20260310.md](174_study_opencode_memory_extension/summaries/implementation-summary-20260310.md)

**Description**: Study the .opencode/memory/ systems and related commands, skills, agents, rules, context files, etc., in order to move this to a memory/ extension that I can selectively load. Carefully review the existing extensions and how they are loaded in order to identify exactly how to proceed, and what changes if any are required to be made to the extension system for memory/ to be an extension.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)
- **Plan**: [implementation-001.md](177_remove_model_preferences_from_opencode/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](177_remove_model_preferences_from_opencode/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)
- **Implementation Started**: 2026-03-10
- **Implementation Completed**: 2026-03-10
- **Summary**: [implementation-summary-20260310.md](177_remove_model_preferences_from_opencode/summaries/implementation-summary-20260310.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

### 72. Fix himalaya sidebar help showing leader keybindings that conflict with toggle selection
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: neovim
- **Dependencies**: None

**Description**: Fix himalaya sidebar help display (shown via '?') incorrectly showing leader keybindings (`<leader>mA` - Switch account, `<leader>mf` - Change folder, `<leader>ms` - Sync folder) in the Folder Management section. These leader commands should not be accessible or defined in the sidebar since `<leader>` is `<Space>` which is used for toggle selections in that buffer.

---
