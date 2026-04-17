---
next_project_number: 475
---

# TODO

## Task Order

*Updated 2026-04-16. 4 active tasks remaining.*

### Pending

- **474** [NOT STARTED] -- Create core extension README.md
- **473** [NOT STARTED] -- Clean up stale permissions in settings.local.json
- **472** [NOT STARTED] -- Fix lean MCP script permissions
- **471** [NOT STARTED] -- Add model: opus to nix agent frontmatter
- **470** [NOT STARTED] -- Fix loader to handle root-level context files
- **469** [PLANNED] -- Systematically review agent system post-refactor
- **468** [NOT STARTED] -- Document extension loader architecture
- **467** [COMPLETED] -- Move remaining root files to extensions/core/
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 474. Create core extension README.md
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Create a README.md for the core extension at `extensions/core/README.md`. The core extension currently fails `check-extension-docs.sh` because it has no README. This is a ROADMAP item for doc generation. The README should document core's role as the foundational system payload (not a peer extension), its provides categories, and why it has no routing block.

### 473. Clean up stale permissions in settings.local.json
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Remove 40+ accumulated stale bash permission entries from `settings.local.json`. These are operational artifacts from past agent sessions (specific mv commands, specs directory paths for completed tasks, shell loop constructs). They add noise and should be pruned to keep the file auditable.

### 472. Fix lean MCP script permissions
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Add execute permissions to `setup-lean-mcp.sh` and `verify-lean-mcp.sh` in `extensions/core/scripts/`. Both have shebangs but are `-rw-r--r--` unlike all other scripts which are executable. The loader copies permissions verbatim, so fixing the source fixes the deployed copies on next load.

### 471. Add model: opus to nix agent frontmatter
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Add `model: opus` to the YAML frontmatter of `nix-research-agent.md` and `nix-implementation-agent.md`. All other research/implementation agents declare this field explicitly per the agent-frontmatter-standard. Functionally harmless (defaults to opus) but inconsistent with the documented standard.

### 470. Fix loader to handle root-level context files
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: neovim

**Description**: Fix `copy_context_dirs()` in `lua/neotex/plugins/ai/shared/extensions/loader.lua` to deploy individual files at the context root, not just subdirectories. Currently `vim.fn.isdirectory()` check silently skips root-level files like README.md, routing.md, and validation.md. The core manifest's `provides.context` only lists subdirectory names, so root files have no deployment path. Either add a `root_files` list within context provides, or have the loader scan for files alongside directories.

### 469. Systematically review agent system post-refactor for errors and improvements
- **Effort**: TBD
- **Status**: [PLANNED]
- **Task Type**: meta
- **Research**: [469_review_agent_system_post_refactor/reports/01_team-research.md]
- **Plan**: [469_review_agent_system_post_refactor/plans/01_system-review-fixes.md]

**Description**: Review the resulting agent system in .claude/ after loading nvim + memory + nix + core extensions following the recent refactoring in tasks 464, 465, 467. Systematically detect errors, inconsistencies, or opportunities for improvement across the loaded system.

### 468. Document extension loader architecture and .claude/ lifecycle
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Parent Task**: 465

**Description**: Systematically update all documentation to reflect how the extension system actually works after tasks 465 and 467. The system has two distinct layers that must not be conflated:

**Layer 1: The Extension Loader** (Neovim Lua code)
Lives in `lua/neotex/plugins/ai/shared/extensions/` — this is Neovim plugin code that manages which files are present in `.claude/`. It reads extension manifests from `.claude/extensions/*/manifest.json`, copies files via category-specific functions (copy_agents, copy_commands, copy_hooks, copy_scripts, copy_docs, copy_templates, copy_systemd, copy_root_files, copy_context_dirs, copy_data_dirs), handles merge targets (settings, index.json, CLAUDE.md generation), manages state in `extensions.json`, and provides the `<leader>ac` picker UI. The loader does NOT depend on any files in `.claude/` to function — it reads from `extensions/*/` and writes to `.claude/`.

**Layer 2: The Agent System** (Markdown/JSON files read by Claude Code)
Lives in `.claude/` AFTER extensions are loaded — commands, agents, skills, rules, hooks, context, scripts, settings, CLAUDE.md. These files are consumed by Claude Code (the CLI tool), not by Neovim. Claude Code reads CLAUDE.md for project instructions, discovers commands/skills/agents from their respective directories, applies rules, executes hooks, and loads context. None of this exists until extensions are loaded via the picker.

**The .claude/ lifecycle**:
1. Fresh state: `.claude/` contains only `extensions/` (extension source code) and runtime dirs (`logs/`, `output/`, `worktrees/`)
2. User opens picker (`<leader>ac`) and loads `core` extension
3. Loader copies ~210 files from `extensions/core/` into `.claude/{agents,commands,rules,skills,scripts,hooks,context,docs,templates,systemd}/` and root files (`settings.json`, `.gitignore`, `settings.local.json`)
4. Loader generates `CLAUDE.md` from header template + core's merge-sources fragment
5. Loader generates `context/index.json` from core-index-entries
6. User loads additional extensions (nvim, memory, etc.) — each adds its own files and merges into CLAUDE.md, index.json, settings
7. Unloading an extension removes its files and regenerates computed artifacts

**Documentation to update**:
- `.claude/extensions/core/EXTENSION.md` — describe what core provides, the root-files mechanism, how CLAUDE.md is generated
- `.claude/extensions/core/docs/README.md` — update system overview to reflect real-extension architecture
- `.claude/CLAUDE.md` merge source (`extensions/core/merge-sources/claudemd.md`) — update context discovery, structure sections
- Project overview (`extensions/core/context/repo/project-overview.md`) — update .claude/ directory description
- Extension development guide (`extensions/core/context/guides/extension-development.md`) — document root_files and systemd provides categories
- Any context files that reference old paths (`.claude/agents/` vs `extensions/core/agents/` in the source repo)
- Clarify in all docs: "extension source" (in `extensions/*/`) vs "loaded files" (in `.claude/` root dirs)

---

### 467. Move remaining .claude/ root files into extensions/core/
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Completed**: 2026-04-16
- **Summary**: Moved 8 remaining root files into extensions/core/, added copy_systemd to loader, updated core-index-entries path
- **Task Type**: meta
- **Parent Task**: 465
- **Research**: [467_move_remaining_root_files_to_core/reports/01_root-files-investigation.md]

**Description**: After task 465 moved ~203 core agent system files into `.claude/extensions/core/`, 10 files remain in `.claude/` root directories that are core extension content rather than loader infrastructure. These should move to `extensions/core/` so that `.claude/` root directories are empty until the core extension is loaded. Files to move: `context/core-index-entries.json`, `context/index.schema.json`, `context/README.md`, `context/routing.md`, `context/validation.md`, `systemd/claude-refresh.service`, `systemd/claude-refresh.timer`, and root `README.md`. Requires updating init.lua (core-index-entries path), adding `copy_systemd()` to loader, updating manifest provides, and handling root README.md copy/generation on load. Should execute before task 466 (which changes how core-index-entries.json is consumed).

---

### 466. Convert core-index-entries.json from static fixture to standard merge_targets
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Parent Task**: 465

**Description**: Convert `core-index-entries.json` from a static fixture (special-cased in `init.lua:451-462`) to a standard `merge_targets` entry in the core extension manifest. Currently the core extension uses a hardcoded path to `.claude/context/core-index-entries.json` which is loaded via special-case code in the extension loader. This should instead use the standard `merge_targets` mechanism that other extensions use (e.g., `index-entries.json` merged into `context/index.json`). This eliminates the last piece of core-specific special-casing in the loader and makes core fully uniform with other extensions. Follow-up to task 465 (restructure core as real extension).

---

### 465. Restructure core agent system as a real extension in .claude/extensions/core/
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Completed**: 2026-04-16
- **Summary**: Restructured core agent system from virtual extension to real physical extension at .claude/extensions/core/
- **Task Type**: meta
- **Research**: [465_restructure_core_as_real_extension/reports/01_team-research.md]
- **Plan**: [465_restructure_core_as_real_extension/plans/01_restructure-core-extension.md]
- **Summary**: [465_restructure_core_as_real_extension/summaries/01_implementation-summary.md]

**Description**: Restructure the core agent system as a real (non-virtual) extension in `.claude/extensions/core/`. The Round 2 research report for task 464 claimed a "bootstrap impossibility" for making core a real extension, but this is incorrect — the Lua extension loader (neovim plugin) is completely separate from the Claude agent system (markdown/json files read by Claude Code). The loader manages which files are present in `.claude/` and does not depend on those files to function.

Currently a virtual core manifest exists at `.claude/extensions/core/manifest.json` with `"virtual": true`, which skips file copy on load/unload. The goal is to physically move core agent system files (agents, commands, rules, skills, context, scripts, hooks, docs — ~280 files) into `.claude/extensions/core/` and make core loadable via `<leader>ac` just like any other extension. This enables loading core + nvim + memory in the source repository.

Key changes: (1) Move core files from `.claude/{agents,commands,rules,skills,context,scripts,hooks,docs}/` into `.claude/extensions/core/` following the standard extension directory structure. (2) Update core manifest to remove `"virtual": true` and add proper `merge_targets` (EXTENSION.md for CLAUDE.md injection, index-entries.json for context). (3) Show core in the picker (remove virtual filter). (4) No special loader handling needed — core loads like any extension. (5) Verify extension-to-extension dependencies work (all 15 extensions already declare `"dependencies": ["core"]`). (6) Update sync system to source from `.claude/extensions/core/` or operate on loaded state. (7) Restructure CLAUDE.md into a minimal shell populated by core's EXTENSION.md merge. Files that stay in `.claude/`: CLAUDE.md (shell), README.md, settings.json, extensions.json, extensions/ directory, context/index.json, context/core-index-entries.json.

---

### 464. Enable extension loading in global source repository without sync leakage
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**:
  - [464_enable_extensions_in_source_repo/reports/01_team-research.md]
  - [464_enable_extensions_in_source_repo/reports/02_team-research.md]
- **Plan**: [464_enable_extensions_in_source_repo/plans/02_enable-extensions-source.md]
- **Summary**: [464_enable_extensions_in_source_repo/summaries/02_enable-extensions-source-summary.md]

**Description**: Allow loading extensions (nvim/, memory/, etc.) in the global source repository (~/.config/nvim) so they function normally for development, without those extension artifacts becoming part of the core agent system that "Load Core Agent System" syncs to other repos. Currently a self-loading guard prevents any extension from being loaded in this repo. The desired behavior is that this repo is just another consumer of the extension system: it loads core + nvim + memory the same way any other repo loads core + its own extensions. The sync mechanism must ensure that only core artifacts propagate to other projects — no extension-injected content in CLAUDE.md sections, context/index.json entries, settings fragments, or discrete files (agents, skills, rules, context) should travel with the core sync. One possible direction is restructuring the core agent system as a base layer that every extension depends on, but the research phase should evaluate approaches before committing to an architecture.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

## Recommended Order

1. **465** [COMPLETED]
2. **469** -> research (independent)
(none)
