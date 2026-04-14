# Implementation Plan: Task #428

- **Task**: 428 - Refactor agent system: syncprotect integration, backup elimination, and systematic organization review
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md
- **Artifacts**: plans/01_syncprotect-organization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses 22 issues discovered during team research of the agent system, organized into 5 phases. The work spans three domains: (1) syncprotect feature hardening -- relocating the file to project root, adding picker visibility, and checking during single-file updates; (2) backup mechanism elimination -- removing unconditional backup creation from merge.lua, resolving the rule contradiction between state-management.md and git-safety.md; (3) agent system hygiene -- fixing orphaned components, naming collisions, broken references, and missing frontmatter. The definition of done is: all critical/high-priority issues resolved, rules internally consistent, and no orphaned or phantom components remain.

### Research Integration

The team research report (4 teammates) provided comprehensive findings across .syncprotect design, backup mechanism analysis, component inventory, context organization, and picker UX. Key inputs integrated:

- **Teammate A**: Complete backup call inventory (10 sites in merge.lua), syncprotect code references
- **Teammate B**: skill-batch-dispatch missing, code-reviewer-agent orphaned, extension naming collisions
- **Teammate C**: Rule contradictions, deprecated orchestrator.md still loaded, index.json schema violations
- **Teammate D**: Picker integration proposals, strategic backup elimination framing

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the following ROADMAP.md items:

- **Agent frontmatter validation**: Phase 5 adds missing frontmatter fields to commands and agents
- **Zero stale references to removed/renamed files in .claude/**: Phases 2, 3, and 4 remove deprecated entries, fix broken cross-references, and eliminate phantom components

## Goals & Non-Goals

**Goals**:
- Relocate .syncprotect to project root and integrate with picker preview and single-file updates
- Eliminate unconditional backup file creation, resolving rule contradictions
- Remove orphaned/phantom components (deprecated orchestrator.md, phantom skill-batch-dispatch, orphaned code-reviewer-agent)
- Fix naming collisions across extensions
- Correct schema violations and broken cross-references
- Add missing frontmatter fields and documentation

**Non-Goals**:
- Implementing .syncprotect wizard or interactive file selection (picker enhancement, separate task)
- Adding manifest validation or dependency resolution to the extension system
- Consolidating duplicate taxonomy directories (processes/ vs workflows/) -- requires separate architectural review
- Creating a system health check tool
- Adding sync history logging

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backup removal causes data loss on write failure | H | L | Keep restore_from_backup for error path only; test write-failure recovery via git |
| .syncprotect path change breaks existing users | M | L | Check both old and new locations during transition; log deprecation warning for old path |
| Removing deprecated orchestrator.md breaks /meta context | M | L | Verify no agent currently depends on its content before removal from index |
| Extension naming changes break loaded extensions | M | M | Rename skill files and update manifests atomically; test with both extensions loaded |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | -- |

Phases within the same wave can execute in parallel.

---

### Phase 1: Syncprotect Hardening [COMPLETED]
- **Completed:** 2026-04-14T17:55:00Z

**Goal**: Move .syncprotect to project root, add picker preview visibility, and enforce during single-file updates.

**Tasks**:
- [ ] Update `load_syncprotect()` in `sync.lua:385-404` to read from `project_dir .. "/.syncprotect"` instead of `project_dir .. "/" .. base_dir .. "/.syncprotect"`
- [ ] Add backward-compatibility check: if new path not found, try old path and log deprecation warning via `helpers.notify`
- [ ] Update `update_artifact_from_global()` in `sync.lua:670+` to call `load_syncprotect()` and skip protected files with a warning notification
- [ ] Update `preview_load_all()` in `previewer.lua:160-236` to call `load_syncprotect()` and display a "Protected Files" section showing which files will be skipped during sync
- [ ] Add .syncprotect documentation section to `.claude/CLAUDE.md` under a new "Syncprotect" heading (3-5 lines explaining location, format, and purpose)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - relocate .syncprotect path, add single-file update check
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - add protected files section to preview
- `.claude/CLAUDE.md` - add syncprotect documentation section

**Verification**:
- `load_syncprotect()` reads from project root path
- Old path still works with deprecation warning
- Single-file update respects .syncprotect
- Picker preview shows protected files section

---

### Phase 2: Backup Mechanism Elimination [COMPLETED]
- **Completed:** 2026-04-14T17:55:00Z

**Goal**: Remove unconditional backup creation from merge.lua, resolve rule contradiction, and clean up backup references.

**Tasks**:
- [ ] Remove `backup_file()` function from `merge.lua:94-104`
- [ ] Remove `restore_from_backup()` function from `merge.lua:109+`
- [ ] Remove all 10 `backup_file()` calls from: `inject_section`, `remove_section`, `merge_settings`, `unmerge_settings`, `append_index_entries`, `remove_index_entries_tracked`, `remove_index_entries_by_prefix`, `remove_orphaned_index_entries`, `merge_opencode_agents`, `unmerge_opencode_agents`
- [ ] Remove 3 `restore_from_backup()` calls (error recovery paths) -- replace with direct error return since git provides recovery
- [ ] Update `rules/state-management.md` line 74: change "Create backup of overwritten version" to "Use git for recovery of overwritten versions"
- [ ] Update `context/repo/self-healing-implementation-details.md`: remove shell script examples using `.backup` files
- [ ] Verify `context/standards/git-safety.md` "Never create .bak files" remains authoritative

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - remove backup_file, restore_from_backup, and all call sites
- `.claude/rules/state-management.md` - resolve contradiction by removing backup reference
- `.claude/context/repo/self-healing-implementation-details.md` - remove .backup examples

**Verification**:
- No `backup_file` or `restore_from_backup` references remain in merge.lua
- No `.backup` file creation in the codebase
- state-management.md and git-safety.md are consistent on backup policy
- All merge operations (inject, remove, merge, unmerge) still function without backups

---

### Phase 3: Syncprotect Default and Cleanup [COMPLETED]

**Goal**: Create a default .syncprotect file for the project and add cleanup of existing .backup files to /refresh.

**Tasks**:
- [ ] Create `.syncprotect` at project root with sensible defaults: header comment explaining format, empty body (no files protected by default)
- [ ] Add `.backup` file cleanup to the refresh skill: scan for `*.backup` files in `.claude/` and remove them
- [ ] Add `.syncprotect` to `.gitignore` if not already present (project-specific, should not be committed to global source)

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.syncprotect` (new file) - default syncprotect with documentation header
- `.claude/skills/skill-refresh.md` - add .backup file cleanup instruction
- `.gitignore` - add .syncprotect entry

**Verification**:
- `.syncprotect` exists at project root with comment header
- `/refresh` skill documentation includes .backup cleanup
- `.syncprotect` is gitignored

---

### Phase 4: Orphaned Components and Broken References [COMPLETED]

**Goal**: Remove deprecated/phantom components, fix broken cross-references, and resolve extension naming collisions.

**Tasks**:
- [ ] Remove `orchestration/orchestrator.md` entry from `.claude/context/index.json` (deprecated since 2026-01-19, 873 lines wasted)
- [ ] Fix `index.json` `"version": null` -- set to valid semver string (e.g., `"1.0.0"`)
- [ ] Fix broken cross-reference in `rules/artifact-formats.md`: update reference from `rules/state-management.md` to `context/reference/state-management-schema.md` for "count-aware format"
- [ ] Document `skill-batch-dispatch` absence: update `context/patterns/multi-task-operations.md` to clarify that batch dispatch is handled by the orchestrator loop in each command, not a separate skill
- [ ] Update `/research`, `/plan`, `/implement` command files: remove or correct any `skill: "skill-batch-dispatch"` references in multi-task sections
- [ ] Decide on `code-reviewer-agent`: document `/review` as intentionally direct-execution in CLAUDE.md (add note to Skill-to-Agent Mapping table that /review executes directly, code-reviewer-agent available for future skill integration)
- [ ] Resolve `spreadsheet-agent` naming collision: rename `filetypes` extension's version to `skill-filetypes-spreadsheet` and `founder` extension's version to `skill-founder-spreadsheet`; update corresponding manifests and agent files
- [ ] Remove duplicate `skill-tag` and `tag.md` from `web` extension

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/index.json` - remove orchestrator.md entry, fix version field
- `.claude/rules/artifact-formats.md` - fix cross-reference
- `.claude/context/patterns/multi-task-operations.md` - document batch dispatch approach
- `.claude/commands/research.md` - remove skill-batch-dispatch reference
- `.claude/commands/plan.md` - remove skill-batch-dispatch reference
- `.claude/commands/implement.md` - remove skill-batch-dispatch reference
- `.claude/CLAUDE.md` - add /review direct-execution note
- `.claude/extensions/filetypes/` - rename spreadsheet skill and agent
- `.claude/extensions/founder/` - rename spreadsheet skill and agent
- `.claude/extensions/web/skills/skill-tag.md` - remove duplicate
- `.claude/extensions/web/commands/tag.md` - remove duplicate

**Verification**:
- No orchestrator.md entry in index.json
- index.json version is a valid semver string
- artifact-formats.md cross-reference points to correct file
- No skill-batch-dispatch references in command files
- No naming collision between filetypes and founder spreadsheet components
- No duplicate skill-tag in web extension

---

### Phase 5: Frontmatter, Schema, and Documentation Polish [COMPLETED]

**Goal**: Add missing frontmatter fields, fix schema inconsistencies, and clean up non-standard metadata.

**Tasks**:
- [ ] Add `model` field to commands: `merge.md`, `refresh.md`, `tag.md`
- [ ] Add `argument-hint` field to commands: `refresh.md`, `tag.md`
- [ ] Add explicit `model` field to agents: `general-implementation-agent.md`, `meta-builder-agent.md` (use default/sonnet as appropriate)
- [ ] Remove non-standard `version` and `author` fields from `skill-spawn.md`
- [ ] Remove redundant `model: opus` from `skill-reviser.md` (agent already declares it)
- [ ] Add `skill-fix-it` to CLAUDE.md Skill-to-Agent Mapping table
- [ ] Fix `task_type: null` in `filetypes` and `memory` extension manifests -- set to appropriate string values
- [ ] Update `extension-development.md` guide: correct manifest format (object vs array for merge_targets), remove reference to non-existent `merge-extensions.sh`, remove central manifest registry description

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/merge.md` - add model field
- `.claude/commands/refresh.md` - add model, argument-hint fields
- `.claude/commands/tag.md` - add model, argument-hint fields
- `.claude/agents/general-implementation-agent.md` - add model field
- `.claude/agents/meta-builder-agent.md` - add model field
- `.claude/skills/skill-spawn.md` - remove non-standard fields
- `.claude/skills/skill-reviser.md` - remove redundant model
- `.claude/CLAUDE.md` - add skill-fix-it to mapping table
- `.claude/extensions/filetypes/manifest.json` - fix task_type
- `.claude/extensions/memory/manifest.json` - fix task_type
- `.claude/docs/guides/extension-development.md` - update to match current system

**Verification**:
- All commands have model field in frontmatter
- All agents have explicit model field
- No non-standard frontmatter fields in skills
- skill-fix-it appears in CLAUDE.md mapping table
- No task_type: null in any manifest
- extension-development.md matches current manifest format

## Testing & Validation

- [ ] Load extensions via `<leader>ac` and verify no naming collisions
- [ ] Verify picker preview shows .syncprotect section
- [ ] Verify single-file update respects .syncprotect
- [ ] Verify sync-all operation skips protected files
- [ ] Run `/refresh` and confirm .backup cleanup works
- [ ] Verify no .backup files created during extension load/unload cycle
- [ ] Confirm all index.json entries resolve to existing files
- [ ] Verify state-management.md and git-safety.md have consistent backup policy

## Artifacts & Outputs

- Modified `sync.lua` with relocated .syncprotect path and single-file protection
- Modified `previewer.lua` with .syncprotect visibility in picker
- Modified `merge.lua` with backup mechanism removed
- Updated `.claude/rules/state-management.md` with consistent backup policy
- Updated `.claude/context/index.json` with fixed version and removed deprecated entry
- Fixed cross-references in `artifact-formats.md` and `multi-task-operations.md`
- Renamed extension components to resolve naming collisions
- Updated frontmatter across commands, agents, and skills
- New `.syncprotect` file at project root
- Updated `.claude/CLAUDE.md` with syncprotect docs and mapping table additions

## Rollback/Contingency

All changes are to configuration files (markdown, JSON) and Lua source. Git provides full rollback capability. If syncprotect relocation causes issues, the backward-compatibility check (Phase 1) ensures the old path continues to work. If backup removal causes write-failure issues, `git checkout` of merge.lua restores the backup mechanism immediately. Extension renames can be reverted by restoring original filenames from git.
