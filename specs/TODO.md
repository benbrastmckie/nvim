---
next_project_number: 444
---

# TODO

## Task Order

*Updated 2026-04-14. 14 active tasks remaining.*

### Pending

- **443** [NOT STARTED] -- Optimize artifact format verbosity using caveman-inspired insights
- **440** [ABANDONED] -- Genericize documentation and examples (superseded by task 438 phase 4)
- **439** [COMPLETED] -- Harden sync protection and clean deprecated index entries
- **438** [COMPLETED] -- Comprehensive core genericization (depends: 437)
- **437** [COMPLETED] -- Move neovim-only files to extension and add to .sync-exclude
- **436** [COMPLETED] -- Resolve /convert command: documented but not implemented
- **435** [COMPLETED] -- Fix CLAUDE.md hierarchy for cross-project portability
- **434** [COMPLETED] -- Prevent lead agent post-delegation takeover after subagent returns
- **433** [COMPLETED] -- Move nvim-specific core content into neovim extension (depends: 432)
- **432** [COMPLETED] -- Harden sync engine against repo-specific content leakage
- **431** [COMPLETED] -- Fix artifact linking order and missing blank line in TODO.md
- **430** [COMPLETED] -- Fix /implement excessive front-loading: lead agent should read plan only, not codebase
- **429** [COMPLETED] -- Update .claude/docs/ to reflect task 428 changes
- **428** [COMPLETED] -- Refactor agent system: syncprotect integration, backup elimination, and systematic organization review
- **427** [COMPLETED] -- Remove Co-Authored-By trailers and refine README.md sync exclusion
- **426** [COMPLETED] -- Update slides command and manifest for --critic flag (depends: 425)
- **425** [COMPLETED] -- Create skill-slide-critic interactive critique skill (depends: 424)
- **424** [COMPLETED] -- Create slide-critic-agent (depends: 423)
- **423** [COMPLETED] -- Create critique rubric context file
- **422** [COMPLETED] -- Fix sync.lua overwriting all non-CLAUDE.md files
- **421** [COMPLETED] -- Fix status script grep pattern and TODO artifact linking
- **420** [COMPLETED] -- Prevent extension loader overwriting repo customizations
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **441** [COMPLETED] -- Update README.md documentation
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 443. Optimize artifact format verbosity using caveman-inspired insights
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Optimize artifact creation throughout the Claude Code agent system to be more readable and less verbose without removing anything important. Study the https://github.com/JuliusBrussee/caveman/blob/main/README.md repo for a comprehensive understanding of the strategy, then review artifact formats (reports, summaries, plans, etc.) for modest optimizations. Not "going full caveman" but drawing on the basic insight to reduce verbiage where it counts without over-complicating instructions. Look for elements that could be dropped or improved.

### 442. Optimize token usage with model routing and effort flags
- **Effort**: Medium
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Research**: [specs/442_optimize_token_usage_model_routing/reports/01_model-routing-research.md]

**Description**: Optimize token usage throughout the Claude Code agent system. Reserve Opus (most recent model) for Lean research and implementation tasks, using Sonnet for everything else. Add --fast and --hard flags to /research and /implement commands for low effort or high effort respectively. Add --opus flag to /research and /implement to allow designating Opus when desired.

### 441. Update README.md documentation
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: markdown

**Research**: [specs/441_update_readme_documentation/reports/01_readme-update-research.md]
- **Plan**: [441_update_readme_documentation/plans/01_readme-update-plan.md]
- **Summary**: [441_update_readme_documentation/summaries/01_readme-update-summary.md]

**Description**: Update the outdated README.md to reflect current configuration state. Key changes: remove Avante references and document Claude Code integration, add link to .claude/README.md for AI system details, and add link to https://github.com/benbrastmckie/zed at the beginning for users seeking a user-friendly alternative to NeoVim.

### 436. Resolve /convert command: documented but not implemented
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta

**Description**: The `/convert` command is extensively documented in `docs/guides/user-guide.md` (lines 28, 462-483, 511) and `docs/reference/standards/extension-slim-standard.md` (line 114) but no `commands/convert.md` file exists. Users attempting to use this command will fail silently.

**Decision required**: Either implement the command or remove all documentation references. The command is described as converting between document formats (PDF to Markdown, Markdown to PDF, etc.) with auto-detection of output format.

**If implementing**: Create `commands/convert.md` with format detection routing, likely delegating to the filetypes extension which already has conversion tables and tool detection. Register in appropriate extension manifests.

**If removing**: Delete all references from user-guide.md (4 locations) and extension-slim-standard.md (1 location).

### 440. Genericize documentation and examples
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #438

**Description**: Rewrite documentation files that use neovim as the primary/only example domain. After task 438 genericizes routing and agent references, these docs files still contain neovim-centric walkthroughs and examples that mislead agents in non-nvim repos.

**Files requiring rewrites (~142 occurrences across 13 files):**
- `docs/examples/fix-it-flow-example.md` (60 refs) -- All examples use `nvim/lua/` paths and neovim task types. Rewrite with generic `src/` paths and a domain-neutral scenario.
- `docs/architecture/system-overview.md` (12 refs) -- "Neovim Configuration agent system" throughout. Replace with "Agent system" or "Project agent system".
- `docs/guides/component-selection.md` (13 refs) -- Neovim routing table examples. Use generic extension examples.
- `docs/examples/research-flow-example.md` (12 refs) -- Scenario C: "Neovim Task Routing". Replace with generic domain routing.
- `docs/guides/development/context-index-migration.md` (12 refs) -- Neovim context entry examples.
- `docs/guides/creating-agents.md` (8 refs) -- neovim agents listed as examples.
- `docs/guides/permission-configuration.md` (7 refs) -- "Neovim Implementation Agent" permission profile.
- `docs/reference/standards/agent-frontmatter-standard.md` (6 refs) -- neovim-research-agent as example.
- `docs/guides/creating-skills.md` (2 refs), `docs/guides/creating-extensions.md` (2 refs) -- minor references.
- `docs/reference/standards/multi-task-creation-standard.md` (1 ref) -- nvim/lua/ path in example.

**Approach**: Replace neovim-specific examples with generic placeholders (`{domain}`, `src/`, `{config-dir}/`) or multi-domain examples showing 2-3 different extensions. Do NOT use neovim as the sole worked example -- use a fictional or neutral domain if a concrete example is needed.

### 439. Harden sync protection and clean deprecated index entries
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta

**Description**: Two independent improvements to the sync mechanism and index hygiene.

**1. Harden .syncprotect against self-destruction**

The zed audit (task 65) revealed that a "Load Core" sync **deleted** `.claude/.syncprotect` (the old location) when the source repo moved it to project root, destroying all of zed's protection entries. Fixes:
- The sync must never overwrite or delete `.syncprotect` itself (either at project root or legacy `.claude/.syncprotect` location). Add it to the skip list in `sync_files()` or the scan exclusion.
- The auto-seed mechanism (sync.lua:822-834) correctly creates a minimal `.syncprotect`, but doesn't preserve existing entries at the legacy location during migration. Add migration logic: if `.claude/.syncprotect` exists and project-root `.syncprotect` doesn't, **move** the legacy file rather than seeding a new one.
- Consider showing the protected file count in the sync confirmation dialog (before the user commits), not just in the results summary.

**2. Remove 5 deprecated entries from `context/index.json`**

These files are marked `DEPRECATED (2026-01-19)` but still indexed:
- `orchestration/delegation.md`
- `orchestration/sessions.md`
- `orchestration/subagent-validation.md`
- `orchestration/validation.md`
- `workflows/status-transitions.md`

Remove the index entries. Optionally delete the deprecated files themselves.

### 438. Comprehensive core genericization
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: Task #437

**Description**: Systematic pass through ALL remaining core `.claude/` files to remove neovim-specific content. The zed audit (task 65) found 368 nvim/neovim occurrences across 53 files after a "Load Core" sync. Tasks 432-433 addressed ~30 files but left the majority untouched. This task completes the genericization.

**Scope (~190 changes across ~38 files):**

**Routing and agent hardcodes (Category B, ~12 occurrences, 6 files):**
- `agents/meta-builder-agent.md` -- Routes "nvim", "neovim", "plugin" keywords to `task_type = "neovim"`. Remove neovim-specific keyword detection; extensions should provide their own keyword lists.
- `agents/code-reviewer-agent.md` -- "Load For Neovim Code" section with nvim extension context paths. Remove or make conditional on loaded extensions.
- `agents/spawn-agent.md` -- Lists "neovim" as valid task_type example. Use generic placeholder.
- `skills/skill-fix-it/SKILL.md` -- `.lua (nvim/)` -> "neovim" type detection. Remove hardcoded detection.
- `context/architecture/system-overview.md` -- "Neovim Configuration agent system". Replace with "Agent system".
- `context/orchestration/orchestration-core.md` -- "Neovim Configuration's architecture". Genericize.

**Command examples (Category A+, ~36 occurrences, 8 files):**
- `commands/fix-it.md` (16 refs) -- All examples use `nvim/lua/` paths, neovim task types. Replace with `src/` paths.
- `commands/review.md` (7 refs) -- `nvim --headless`, `nvim/lua/` paths. Use generic build/test examples.
- `commands/task.md` (3 refs) -- neovim keyword detection, nvim path examples.
- `commands/learn.md` (1 ref) -- neovim directory example.
- `commands/todo.md` (4 refs) -- Health metrics grep `nvim/lua/`, `nvim --headless`.
- `rules/plan-format-enforcement.md` (1 ref) -- neovim task_type example.
- `skills/skill-orchestrator/SKILL.md` (2 refs) -- neovim routing entry.
- `CLAUDE.md` (4 refs) -- Extension list mentions neovim, task_type example.

**Config files (Category A, ~30 occurrences, 6 files):**
- `settings.json` -- SessionStart hook runs nvim-specific script. Make hook path generic or remove.
- `settings.local.json` -- Bash permissions reference nvim paths. Remove nvim-specific permissions.
- `extensions.json` -- All `source_dir` entries point to nvim paths. These are generated at load time; verify they're not synced.
- `systemd/claude-refresh.service` -- ExecStart points to nvim script path. Use generic path.
- `scripts/validate-wiring.sh` -- Validates nonexistent neovim agents. Make validation dynamic.

**Context files (~15 occurrences across ~8 files):**
- `context/formats/frontmatter.md` -- "non-Neovim tasks", "Neovim plugin tooling"
- `context/standards/ci-workflow.md` -- "Neovim Lua files", "Neovim phases"
- `context/standards/documentation-standards.md` -- "Neovim configuration"
- `context/repo/update-project.md` -- "example for a Neovim configuration project"
- `context/guides/extension-development.md` (15 refs) -- Neovim as worked example

**`<leader>ac` references (19 occurrences across 10 files):**
Replace with "extension loader" or "the loader" -- the keybinding is Neovim-specific and meaningless in other editors.

### 437. Move neovim-only files to extension and add to .sync-exclude
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: meta

**Description**: Several core `.claude/` files are 100% neovim-specific and should not be synced to any other repository. Move them to the neovim extension and add source-side exclusions.

**Files to relocate to `.claude/extensions/neovim/` (or exclude):**

| File | Lines | Content | Action |
|------|-------|---------|--------|
| `docs/guides/neovim-integration.md` | ~336 | SessionStart hooks, nvim --remote-expr, terminal state management | Move to extension |
| `docs/guides/tts-stt-integration.md` | ~200 | neotex STT plugin, PulseAudio recording, Neovim-specific | Move to extension |
| `docs/guides/user-installation.md` | ~300 | "Setting Up a Neovim Configuration Project", telescope.nvim | Move to extension |
| `docs/guides/copy-claude-directory.md` | ~200 | "Copying .claude/ for Neovim configuration maintenance" | Move to extension |
| `context/project/memory/learn-usage.md` | ~100 | Neovim as the sole example memory topic throughout | Move to extension |

**Steps:**
1. Add all 5 files to `.sync-exclude` as path exclusions (immediate protection against future syncs)
2. Move files to `extensions/neovim/context/` or `extensions/neovim/docs/` directories
3. Update the neovim extension `manifest.json` to declare these files under `provides`
4. Update `context/index.json` to remove entries for moved files (or update paths to extension locations)
5. Add entries to neovim extension's `index-entries.json` so they're available when the neovim extension is loaded
6. Verify no other core files reference the moved files by path

**Memory files**: The `context/project/memory/` files (`learn-usage.md`, `knowledge-capture-usage.md`, `memory-setup.md`, `domain/memory-reference.md`) all use neovim as their example domain. The memory extension is separate from neovim, so these should be genericized in task 438 rather than moved here -- only `learn-usage.md` (12 refs, deeply neovim-specific) warrants moving.

### 435. Fix CLAUDE.md hierarchy for cross-project portability
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta

**Description**: The CLAUDE.md file chain that Claude Code loads (by walking up the directory tree) causes neovim-specific content to leak into non-nvim projects like zed. When Claude Code runs in `/home/benjamin/.config/zed/`, it loads:

```
/home/benjamin/.config/CLAUDE.md          <- Links to nvim/CLAUDE.md for "Neovim Configuration Guidelines"
/home/benjamin/.config/.claude/CLAUDE.md  <- "This repository uses nvim/.claude/ as primary", hardcodes nvim/ paths
/home/benjamin/.config/zed/.claude/CLAUDE.md  <- Correct generic agent system (this is fine)
```

The parent files inject nvim-specific paths and coding standards into every non-nvim session.

**Fixes:**

**1. `/home/benjamin/.config/.claude/CLAUDE.md`** -- Remove nvim-specific assumptions:
- Replace "This repository uses nvim/.claude/ as the primary Claude Code configuration" with generic language like "Each subdirectory maintains its own Claude Code configuration"
- Replace hardcoded paths (`nvim/specs/TODO.md`, `nvim/.claude/commands/`, etc.) with relative references (`specs/TODO.md`, `.claude/commands/`) that resolve correctly per-project
- Remove the "See nvim/.claude/CLAUDE.md" redirect

**2. `/home/benjamin/.config/CLAUDE.md`** -- Make the root config project-agnostic:
- Remove or conditionalize the link to `nvim/CLAUDE.md` ("Neovim Configuration Guidelines")
- Keep the link to `.claude/CLAUDE.md` (agent system) since that's shared
- Consider whether this file should exist at all -- each subdirectory (nvim/, zed/) could be self-contained

**3. Ensure `/home/benjamin/.config/zed/CLAUDE.md` exists** as a root config for zed, providing zed-specific project context and overriding any nvim references from parent files. The zed audit (task 65) notes this file was created by task 63 but no longer exists.

**Key constraint**: Changes to the parent CLAUDE.md files must not break the nvim workflow. The nvim-specific coding standards currently in `nvim/CLAUDE.md` should remain but not leak upward.

### 434. Prevent lead agent post-delegation takeover after subagent returns
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [specs/434_prevent_lead_agent_post_delegation_takeover/reports/01_post-delegation-takeover.md](specs/434_prevent_lead_agent_post_delegation_takeover/reports/01_post-delegation-takeover.md)
- **Plan**: [434_prevent_lead_agent_post_delegation_takeover/plans/01_post-delegation-takeover.md]
- **Summary**: [434_prevent_lead_agent_post_delegation_takeover/summaries/01_post-delegation-takeover-summary.md]

**Description**: When a subagent returns with incomplete or partial work, the lead agent (skill-implementer, skill-team-implement, or extension implementation skills) sometimes takes over and continues implementation itself -- reading source files, running builds, grepping patterns, and attempting to finish the work. This violates the postflight boundary and must never happen.

**Observed behavior** (from /implement on a Lean4 task):
After lean-implementation-agent returned from Wave 2 Phase 2, the lead agent: (1) searched for patterns in source files, (2) ran `lake build` to check sorry sites, (3) analyzed build output, (4) announced "let me tackle the core problem myself." The lead should have immediately proceeded to postflight (read metadata, update status to partial, commit, return).

**Task 430 fixed the pre-delegation boundary** (lead reading codebase before spawning agent). This task fixes the **post-delegation boundary** -- the mirror problem.

**Affected files:**
1. `skills/skill-implementer/SKILL.md` -- The "Postflight Boundary" section exists (line ~end) but needs stronger enforcement language. Add an explicit **PROHIBITION** block (matching the anti-bypass pattern in implement.md) that names the specific violation: after any Agent/Task tool returns, the skill MUST NOT read source files, run builds, grep/glob codebase, use MCP tools, or attempt to continue implementation. It must proceed directly to Stage 6 (read metadata file).
2. `skills/skill-team-implement/SKILL.md` -- Same enforcement needed after wave/phase agents return. The lead must not "fill in" incomplete phases.
3. `agents/general-implementation-agent.md` -- Add a note that partial results are acceptable and the agent should write `.return-meta.json` with status "partial" rather than leaving work for the caller.
4. Extension implementation skills (check `extensions/*/skills/skill-*-implement*/SKILL.md`) -- Apply the same post-delegation boundary constraint.
5. `commands/implement.md` -- Consider adding a GATE OUT validation that detects if the skill performed source-file reads after delegation (checking tool call sequence) and warns.

**Key constraint to add:** "After a subagent returns -- whether with status implemented, partial, or failed -- the lead skill MUST proceed immediately to postflight. The lead MUST NOT: read source files, grep/glob the codebase, run build/test commands, use MCP tools, edit source files, or attempt to continue/complete the subagent's work. If the subagent returned partial results, the lead reports partial status. The user re-runs /implement to resume."

### 433. Move nvim-specific core content into neovim extension
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: Task #432
- **Research**: [specs/433_move_nvim_specific_content_to_neovim_extension/reports/01_extension-restructuring.md]
- **Plan**: [433_move_nvim_specific_content_to_neovim_extension/plans/01_extension-restructuring.md]
- **Summary**: [433_move_nvim_specific_content_to_neovim_extension/summaries/01_extension-restructuring-summary.md]

**Description**: Several files in core .claude/ contain neovim-specific content that gets synced to all repos via "Load Core", causing repo-specific leakage. Move this content into the neovim extension so the existing extension blocklist excludes it during sync and it only appears in repos where the neovim extension is loaded.

**Scope:**
1. Move `docs/guides/neovim-integration.md` (336 lines) into `extensions/neovim/` (e.g., `extensions/neovim/context/` or a new `extensions/neovim/docs/` directory). Update the neovim extension manifest to declare it under `provides`.
2. Move the `neovim` routing row from `context/routing.md` line 17 into the neovim extension as a merge target. The extension loader should inject this row when loaded, similar to how CLAUDE.md sections are injected. This may require adding a new merge target type for routing.md, or appending the row via the index merge mechanism.
3. Templatize CLAUDE.md example references: lines 75, 120, 200, 222 use `neovim` as example text (`e.g., skill-neovim-research`, `e.g., neovim-lua.md`). Replace with generic examples (`e.g., python`, `e.g., skill-python-research`) so the core CLAUDE.md is editor-agnostic. The neovim extension's CLAUDE.md merge section can add neovim-specific examples if needed.
4. Audit `README.md` lines 119, 188 for neovim references that should be extension-provided.
5. Similarly audit `docs/guides/tts-stt-integration.md` -- if it's neovim-specific (uses nvim remote-expr, neotex modules), move it to the neovim extension.

**Depends on 432** because the sync-exclude mechanism from 432 provides an immediate safety net, while this task does the proper structural fix.

### 432. Harden sync engine against repo-specific content leakage
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Research**: [01_sync-leakage-hardening.md](432_harden_sync_against_repo_specific_leakage/reports/01_sync-leakage-hardening.md)
- **Plan**: [432_harden_sync_against_repo_specific_leakage/plans/01_sync-leakage-hardening.md]
- **Summary**: [432_harden_sync_against_repo_specific_leakage/summaries/01_sync-leakage-hardening-summary.md]

**Description**: The "Load Core" sync in `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` copies all non-extension core files to target repos, but some core files are source-repo-specific (neovim integration guides, neovim routing entries, neotex references). Add three protection mechanisms to prevent repo-specific content from leaking during sync.

**Changes:**
1. **Source-side sync exclusion file** (`sync-exclude` at project root or `.claude/sync-exclude`): A file listing paths/globs that should never be exported during "Load Core". The `scan_all_artifacts()` function (line ~440) already builds an extension blocklist -- add a source exclusion list loaded from this file, applied the same way. Populate it with known nvim-specific files: `docs/guides/neovim-integration.md`, `docs/guides/tts-stt-integration.md`. This is the source-side mirror of `.syncprotect`.
2. **Post-sync content audit**: After `execute_sync()` completes (line ~366), scan synced files for configurable warning patterns (e.g., `neovim`, `neotex`, `lazy.nvim`, `nvim-lspconfig`). Display warnings in the sync results summary: "N files may contain source-repo-specific references". Non-blocking -- informational only. Pattern list could live in the sync-exclude file as a `# audit-patterns:` directive, or in a separate config.
3. **Auto-seed `.syncprotect` on first sync**: When `load_all_globally()` detects no `.syncprotect` in the target repo, create one with standard entries (`context/repo/project-overview.md`). This ensures every synced repo gets baseline protection without manual setup.

### 431. Fix artifact linking order and missing blank line in TODO.md
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_artifact-linking-bug.md](431_fix_artifact_linking_order_todo/reports/01_artifact-linking-bug.md)
- **Plan**: [01_artifact-linking-fix.md](431_fix_artifact_linking_order_todo/plans/01_artifact-linking-fix.md)
- **Completed**: 2026-04-14
- **Summary**: Fixed blank line preservation and bracket-only link format in link-artifact-todo.sh, updated 3 documentation files

**Description**: Investigate how artifacts are being linked in task 429 where they appear out of order and there is no empty line above the description. Determine the root cause and create a targeted fix.

### 430. Fix /implement excessive front-loading: lead agent should read plan only, not codebase
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [front-loading-fix](specs/430_fix_implement_excessive_front_loading/reports/01_front-loading-fix.md)

- **Plan**: [01_front-loading-fix.md](430_fix_implement_excessive_front_loading/plans/01_front-loading-fix.md)
- **Summary**: [01_front-loading-fix-summary.md](430_fix_implement_excessive_front_loading/summaries/01_front-loading-fix-summary.md)
**Description**: Fix excessive front-loading in /implement: the lead agent (both skill-team-implement and skill-implementer) reads the entire codebase before spawning sub-agents, instead of just reading the plan file. The lead should only read the plan to extract phase structure/dependencies/waves, then immediately delegate to agents. Source file reading, grepping, and MCP tool usage must be the sub-agent's responsibility. Affected files: `.claude/skills/skill-team-implement/SKILL.md` (add anti-front-loading constraint to Stages 5-7), `.claude/skills/skill-implementer/SKILL.md` (add constraint to Stages 4-5), and potentially `.claude/agents/general-implementation-agent.md` (clarify that codebase exploration is the agent's job, not the delegator's).

### 429. Update .claude/docs/ to reflect task 428 changes
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [docs-audit](specs/429_update_docs_for_task_428_changes/reports/01_docs-audit.md), [docs-update-research](specs/429_update_docs_for_task_428_changes/reports/02_docs-update-research.md)
- **Plan**: [02_docs-update-plan.md](429_update_docs_for_task_428_changes/plans/02_docs-update-plan.md)
- **Summary**: [02_implementation-summary.md](specs/429_update_docs_for_task_428_changes/summaries/02_implementation-summary.md)
- **Completed**: 2026-04-14

**Description**: Update .claude/docs/ to reflect task 428 changes: fix stale backup system docs in extension-system.md, manifest schema examples (language->task_type, add routing object), renamed spreadsheet agents in extension-slim-standard.md, and agent frontmatter examples for model enforcement

### 428. Refactor agent system: syncprotect integration, backup elimination, and systematic organization review
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_team-research.md](specs/428_refactor_agent_system_syncprotect_and_organization/reports/01_team-research.md)
- **Plan**: [01_syncprotect-organization.md](428_refactor_agent_system_syncprotect_and_organization/plans/01_syncprotect-organization.md)
- **Summary**: [01_implementation-summary.md](428_refactor_agent_system_syncprotect_and_organization/summaries/01_implementation-summary.md)
**Description**: Systematic agent system refactoring: review and improve organization, naming, documentation, .syncprotect integration, and backup elimination across all commands, skills, agents, context files, rules, and extensions. Key objectives: (1) Eliminate .backup file creation during extension loading by leveraging .syncprotect and section preservation -- the backup mechanism in merge.lua should be made conditional or removed where .syncprotect coverage makes it redundant; (2) Create .syncprotect files in project repos (NOT in .claude/) that protect repo-specific customizations like CLAUDE.md, settings.local.json, and any other files that should survive sync operations; (3) Improve .syncprotect documentation, integration with the extension loader, and visibility in the leader-ac picker UI; (4) Conduct systematic review of all 14 commands, 8 agents, 16 core skills, 15 extensions, 6 rules, 94+ context files for naming consistency, documentation gaps, redundancy, and organizational improvements; (5) Update the neovim leader-ac picker (sync.lua, merge.lua, and related files) to handle .syncprotect more prominently and stop creating .backup files when protection is adequate; (6) Ensure .syncprotect is stored in the main repo root (e.g., nvim/.syncprotect or project-root/.syncprotect) not inside .claude/ which gets replaced during updates.

### 427. Remove Co-Authored-By trailers and refine README.md sync exclusion
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_coauthored-by-removal.md](specs/427_remove_coauthored_by_and_refine_readme_sync/reports/01_coauthored-by-removal.md)
- **Plan**: [01_coauthored-by-removal.md](specs/427_remove_coauthored_by_and_refine_readme_sync/plans/01_coauthored-by-removal.md)
- **Summary**: [01_coauthored-by-removal-summary.md](specs/427_remove_coauthored_by_and_refine_readme_sync/summaries/01_coauthored-by-removal-summary.md)

**Description**: Two issues remain after task 422 that affect all target repos loading the agent system via `<leader>ac`:

**Issue 1: Co-Authored-By saturates the system (HIGH priority)**

80+ files across .claude/ contain Co-Authored-By trailer lines in commit templates and examples. This contradicts the CLAUDE.md note "omit Co-Authored-By trailers from all commits" and the user's preference to suppress all co-author details. Every target repo inherits these contradictory instructions.

Affected areas: rules/git-workflow.md (4 occurrences), CLAUDE.md (1 occurrence referencing a feedback file that may not exist in target repos), commands/*.md (research, plan, implement, review batch commit templates), skills/*/SKILL.md (git-workflow, implementer, planner, reviser, team-*, spawn, fix-it, researcher), agents/general-implementation-agent.md, context/*.md (checkpoint-commit, ci-workflow, multi-task-operations, file-metadata-exchange, workflow-interruptions), all extension skills/commands/agents, docs/examples and docs/guides.

Fix: Remove all Co-Authored-By lines from commit templates/examples. Update CLAUDE.md to state the no-trailer policy directly. Update rules/git-workflow.md commit format.

**Issue 2: README.md sync exclusion too broad (MEDIUM priority)**

Task 422 added README.md skip to scan_directory_for_sync (scan.lua line ~100-103). This correctly prevents agents/README.md (repo-specific) from being overwritten, but also blocks 5 useful documentation README.md files: context/checkpoints/README.md (100 lines), context/README.md (203 lines), context/reference/README.md (31 lines), docs/README.md (100 lines), docs/templates/README.md (352 lines).

Fix: Make README.md exclusion more targeted - only skip in agents/ subdirectory, or add per-category readme_exclude flag.

### 426. Update slides command and manifest for --critic flag
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: 425

- **Research**: [01_slides-critic-flag-research.md](426_update_slides_command_manifest_critic_flag/reports/01_slides-critic-flag-research.md)
- **Plan**: [01_slides-critic-flag-plan.md](426_update_slides_command_manifest_critic_flag/plans/01_slides-critic-flag-plan.md)
- **Summary**: [01_slides-critic-flag-summary.md](426_update_slides_command_manifest_critic_flag/summaries/01_slides-critic-flag-summary.md)
**Description**: Add `--critic` flag parsing to the `/slides` command (`slides.md`). Accept `--critic /path/to/file`, `--critic N` (task number), or `--critic "prompt"` as input. Route to `skill-slide-critic`. Update `manifest.json` with critic routing entry. Update `index-entries.json` with context entries for the critic agent and rubric. Update EXTENSION.md documentation.

### 425. Create skill-slide-critic interactive critique skill
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: 424

- **Research**: [01_skill-slide-critic-research.md](425_create_skill_slide_critic/reports/01_skill-slide-critic-research.md)
- **Plan**: [01_skill-slide-critic-plan.md](425_create_skill_slide_critic/plans/01_skill-slide-critic-plan.md)
- **Summary**: [01_skill-slide-critic-summary.md](425_create_skill_slide_critic/summaries/01_skill-slide-critic-summary.md)
**Description**: Create `skill-slide-critic` in the present extension. This skill runs an interactive critique loop: (1) delegates to `slide-critic-agent` for initial material review, (2) presents identified issues to user via AskUserQuestion grouped by category, (3) for each issue the user can accept, reject, modify, or provide an alternative response, (4) loops until all issues are addressed or dismissed, (5) produces a final critique report at `specs/{NNN}_{SLUG}/reports/{MM}_slide-critique.md` that can be consumed by `/plan` to guide slide design. Implements skill-internal postflight pattern.

### 424. Create slide-critic-agent
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: 423

- **Research**: [01_slide-critic-agent-research.md](424_create_slide_critic_agent/reports/01_slide-critic-agent-research.md)
- **Plan**: [01_slide-critic-agent-plan.md](424_create_slide_critic_agent/plans/01_slide-critic-agent-plan.md)
- **Summary**: [01_slide-critic-agent-summary.md](424_create_slide_critic_agent/summaries/01_slide-critic-agent-summary.md)
**Description**: Create `slide-critic-agent` in the present extension. This agent loads the critique rubric context and reviews all provided materials (source files, research reports, plans, existing slides). It evaluates against rubric criteria: narrative flow, audience alignment, timing balance, content depth, evidence quality, visual design considerations. Produces a structured issue list with severity (critical/high/medium/low), category, description, location in materials, and suggested improvement. Writes `.return-meta.json` with critique artifacts.

### 423. Create critique rubric context file
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: meta

- **Research**: [01_critique-rubric-research.md](423_create_critique_rubric_context/reports/01_critique-rubric-research.md)
- **Plan**: [01_critique-rubric-plan.md](423_create_critique_rubric_context/plans/01_critique-rubric-plan.md)
- **Summary**: [01_critique-rubric-summary.md](423_create_critique_rubric_context/summaries/01_critique-rubric-summary.md)
**Description**: Create a critique rubric context file at `.claude/extensions/present/context/project/present/talk/critique-rubric.md`. Define review criteria and scoring patterns for slide presentations across categories: narrative flow (logical progression, story arc, transitions), audience alignment (jargon level, assumed knowledge, engagement), timing balance (slides per section, pacing), content depth (too shallow vs too detailed), evidence quality (data presentation, citations, claims), and visual design considerations (text density, figure placement). Include talk-type-specific criteria for conference, seminar, defense, poster, and journal club presentations.

### 422. Fix sync.lua overwriting all non-CLAUDE.md files in target repos
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_sync-overwrite-diagnosis.md](422_fix_sync_overwriting_all_non_claudemd_files/reports/01_sync-overwrite-diagnosis.md)

- **Plan**: [01_sync-overwrite-fix.md](422_fix_sync_overwriting_all_non_claudemd_files/plans/01_sync-overwrite-fix.md)
- **Summary**: [01_sync-overwrite-fix-summary.md](422_fix_sync_overwriting_all_non_claudemd_files/summaries/01_sync-overwrite-fix-summary.md)
**Description**: Follow-up to task 420 (prevent extension loader overwriting repo customizations). Task 420 added section-aware sync for CLAUDE.md and post-sync re-injection of merge targets, but the fix is insufficient -- the zed config (`~/.config/zed/.claude/`) is still getting clobbered on every sync. This has now caused three wasted tasks in zed: task 60 (incorrectly "fixed" the diffs thinking they were stale references), task 61 (reverted task 60), and task 62 (initially misdiagnosed the same diffs again).

**Root cause analysis from the zed codebase:**

The `sync_files()` function in `sync.lua` (line ~246) only applies section preservation to files in `CONFIG_MARKDOWN_FILES` (CLAUDE.md and OPENCODE.md). The `execute_sync()` function (lines ~284-296) syncs ALL other .claude/ files with `action = "replace"`, which does a full overwrite. This means every file synced from nvim to zed gets its local content destroyed.

**Specific files being clobbered in the zed repo (evidence from `git diff .claude/`):**

1. `.claude/CLAUDE.md` -- Content NOT inside `<!-- SECTION -->` markers is lost: the Hooks section (validate-plan-write.sh), slide-planner-agent/skill-slide-planning table rows (3 tables), and `present:slides` compound task type routing. Task 420's section-marker fix does not protect content that the extension system didn't inject via markers.

2. `.claude/agents/README.md` -- Full overwrite removes slide-planner-agent row and the "Extension-specific agents" note. Not in `CONFIG_MARKDOWN_FILES`, so no protection at all.

3. `.claude/rules/git-workflow.md` -- Full overwrite removes the zed-specific "omit Co-Authored-By" user preference note and replaces it with nvim's Co-Authored-By trailer format. Not in `CONFIG_MARKDOWN_FILES`.

4. `.claude/agents/document-agent.md` -- Full overwrite replaces zed's pymupdf-as-primary version with nvim's markitdown-as-primary version. (The pymupdf improvement was done in zed but reverted as collateral damage when reverting task 60.)

5. `.claude/context/project/filetypes/` (3 files: conversion-tables.md, dependency-guide.md, tool-detection.md) -- Full overwrite replaces zed's pymupdf-aware versions with nvim's markitdown-only versions.

6. 7 skill files (skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-team-research, skill-team-plan, skill-team-implement) -- Full overwrite replaces each skill's artifact-linking postflight. The nvim versions reference `link-artifact-todo.sh` script; the zed committed versions use inline Edit-based four-case logic.

7. `.claude/scripts/update-task-status.sh` -- Full overwrite replaces the committed version with nvim's version (which has a tolerant status regex).

8. `.claude/context/index.json` and `.claude/extensions.json` -- Re-injection is idempotent but the full overwrite first replaces the file, causing key reordering churn.

**Three categories of failure:**

| Category | Files affected | Why task 420 doesn't help |
|----------|---------------|---------------------------|
| Non-CLAUDE.md files | agents/README.md, rules/git-workflow.md, all skill files, context files, scripts | `CONFIG_MARKDOWN_FILES` only contains CLAUDE.md and OPENCODE.md; all other files get full overwrite |
| CLAUDE.md content outside section markers | Hooks section, slide-planner table rows, present:slides routing | Section preservation only protects `<!-- SECTION -->` blocks; manually-added content in CLAUDE.md is unprotected |
| Bidirectional improvements | document-agent.md (pymupdf), skill artifact-linking (script vs inline) | Sync is unidirectional (nvim -> target); improvements made in target repos are overwritten |

**Requirements for a proper fix:**

The sync system needs to handle the fact that target repos (zed, other projects) may have legitimate local customizations to ANY .claude/ file, not just CLAUDE.md sections. Possible approaches include: (a) expanding section-marker protection to all synced files, (b) adding a per-repo "protected files" list that sync skips, (c) making sync diff-aware rather than full-overwrite, or (d) only syncing files whose local content matches the previous sync snapshot (detecting local modifications and skipping those files).

### 421. Fix update-task-status.sh grep pattern and skill-planner TODO.md artifact linking
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [01_status-script-bugs.md](421_fix_status_script_grep_pattern_and_todo_linking/reports/01_status-script-bugs.md)
- **Plan**: [01_fix-status-linking.md](421_fix_status_script_grep_pattern_and_todo_linking/plans/01_fix-status-linking.md)
- **Summary**: [01_fix-status-linking-summary.md](421_fix_status_script_grep_pattern_and_todo_linking/summaries/01_fix-status-linking-summary.md)

**Description**: Fix update-task-status.sh grep pattern that fails to match TODO.md task entry status lines: script uses `^- \*\*Status\*\*:` but actual format is ` **Status**:` (space-indented, no dash). This causes all task entry status updates to silently fail, while Task Order and state.json updates succeed. Also fix skill-planner postflight to actually perform TODO.md artifact linking (Plan field) which was specified but never executed.

---

### 420. Prevent extension loader sync from overwriting repo-specific CLAUDE.md customizations
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [01_extension-loader-sync.md](420_prevent_extension_loader_overwriting_repo_customizations/reports/01_extension-loader-sync.md)
- **Plan**: [01_prevent-loader-overwrite.md](420_prevent_extension_loader_overwriting_repo_customizations/plans/01_prevent-loader-overwrite.md)
- **Summary**: [01_prevent-loader-overwrite-summary.md](420_prevent_extension_loader_overwriting_repo_customizations/summaries/01_prevent-loader-overwrite-summary.md)

**Description**: Investigation and fix for a systemic issue: when the `<leader>ac` extension loader syncs .claude/ files from the nvim config into other repos (like zed), it overwrites repo-specific additions to CLAUDE.md documentation tables. This caused slide-planner-agent and skill-slide-planning (added by task 56 in zed) to be silently removed from CLAUDE.md when the next sync occurred. Root cause analysis needed: (1) Identify how the extension loader syncs CLAUDE.md content between repos, (2) Determine why repo-specific additions are not preserved during sync, (3) Investigate whether extensions.json or manifest.json should declare documentation table entries that get merged rather than overwritten, (4) Check if other repos have similar repo-specific CLAUDE.md customizations at risk. Design and implement a fix: consider merge-based documentation table updates, repo-local sections in CLAUDE.md, extension manifest declarations for table entries, and validation that warns when a sync would remove entries added by tasks in the target repo.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
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
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

## Recommended Order

### Portability refactor (tasks 435-440)
1. **435** [NOT STARTED] -> implement (independent, quick win)
2. **439** [NOT STARTED] -> implement (independent, quick win)
3. **437** [NOT STARTED] -> research (unblocks 438)
4. **438** [NOT STARTED] -> research (depends: 437, large)
5. **440** [NOT STARTED] -> research (depends: 438)
6. **436** [NOT STARTED] -> research (independent, decision needed)

### Existing backlog
7. **78** [PLANNED] -> implement
8. **87** [RESEARCHED] -> plan
9. **442** [RESEARCHED] -> plan (independent)
10. **443** -> research (independent)
