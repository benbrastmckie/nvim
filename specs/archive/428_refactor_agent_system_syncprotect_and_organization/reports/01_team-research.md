# Research Report: Task #428

**Task**: Refactor agent system: syncprotect integration, backup elimination, and systematic organization review
**Date**: 2026-04-14
**Mode**: Team Research (4 teammates)

## Summary

A comprehensive investigation of the agent system with all extensions revealed 10 critical/high-priority issues and 15+ medium/low-priority improvements across .syncprotect integration, backup elimination, component inventory, context organization, and picker UX. The most significant findings are: (1) .syncprotect is stored inside the directory it protects, creating a fragile design; (2) backup files are created unconditionally but never cleaned up, duplicating git's recovery role; (3) `skill-batch-dispatch` is referenced by 3 commands but doesn't exist; (4) `code-reviewer-agent` is orphaned with no skill invoking it; (5) direct rule contradictions exist about backup file policy; (6) the picker has zero visibility into .syncprotect status; and (7) multiple naming collisions exist across extensions.

## Key Findings

### 1. .syncprotect Feature (from Teammates A, C, D)

#### 1.1 Storage Location Problem (HIGH confidence, all teammates agree)

The `.syncprotect` file is read from `{project_dir}/{base_dir}/.syncprotect` (i.e., inside `.claude/`). Since `.claude/` contents are replaced during sync operations, this placement is architecturally fragile. While the current sync scan patterns don't explicitly include `.syncprotect` as a synced file (so it's accidentally safe today), the file would be destroyed if `.claude/` is ever deleted and recreated from the global source.

**Code reference**: `sync.lua:385-404` (`load_syncprotect()`)

**Recommendation**: Move to `{project_dir}/.syncprotect` at the project root. Update `load_syncprotect()` to read from `project_dir .. "/.syncprotect"`. Keep paths inside the file relative to the base_dir (`.claude/` or `.opencode/`).

#### 1.2 Zero Picker Visibility (HIGH confidence, Teammate D)

The picker has NO pre-sync visibility into .syncprotect. Users only learn about protected files AFTER sync completes via a notification message. The `preview_load_all` function (`previewer.lua:160-236`) shows new/replace counts but never calls `load_syncprotect()` to display protection status.

**Recommendation**: Add a "Protected Files" section to the sync preview that shows which files will be skipped. Call existing `load_syncprotect()` from the preview function.

#### 1.3 Not Checked During Single-File Update (MEDIUM confidence, Teammate A)

`update_artifact_from_global()` (`sync.lua:670-769`) bypasses .syncprotect entirely. A user can explicitly update a protected file with no warning.

#### 1.4 No Documentation or Default Content (HIGH confidence, Teammates A, C)

No context file, CLAUDE.md section, README, or rule documents the .syncprotect feature. Users must read `sync.lua` source code to learn about it. No default `.syncprotect` exists in any repository.

### 2. Backup Mechanism (from Teammates A, C, D)

#### 2.1 Pervasive, Unconditional, Never Cleaned Up (HIGH confidence)

`merge.lua:94-104` (`backup_file()`) creates `.backup` files before every write operation across 10 call sites. Backups serve only as rollback for write failures (called `restore_from_backup()` in only 3 locations). Every successful operation leaves a `.backup` file permanently.

**Complete backup call inventory** (Teammate A):
- `inject_section`, `remove_section` (CLAUDE.md)
- `merge_settings`, `unmerge_settings` (settings.json)
- `append_index_entries`, `remove_index_entries_tracked`, `remove_index_entries_by_prefix`, `remove_orphaned_index_entries` (index.json)
- `merge_opencode_agents`, `unmerge_opencode_agents` (opencode.json)

#### 2.2 Rule Contradiction (HIGH confidence, Teammate C)

`rules/state-management.md` line 74 says "Create backup of overwritten version" while `context/standards/git-safety.md` says "Never create `.bak` files. Use git commits for safety." These directly contradict each other. Additionally, `context/repo/self-healing-implementation-details.md` contains shell script examples using `.backup` files.

#### 2.3 Backups Created Even for No-Op Operations (HIGH confidence, Teammate A)

`inject_section()` creates a backup before checking if the section already exists (backup at line 153, idempotency check at line 159). Every reload creates 4-8 `.backup` files even when no content changes.

#### 2.4 Strategic Assessment (Teammate D)

Backups duplicate git's recovery role. The right architecture is: `.syncprotect` prevents overwrites proactively, git handles recovery, and the picker makes both visible. Recommendation: clean up backups after successful writes, or eliminate backups entirely.

### 3. Commands, Skills, and Agents (from Teammate B)

#### 3.1 `skill-batch-dispatch` Missing (HIGH confidence, CRITICAL)

Three commands (`/research`, `/plan`, `/implement`) document multi-task parallel dispatch that invokes `skill: "skill-batch-dispatch"`, but no such skill exists. Multi-task mode (`/research 7, 22-24, 59`) is advertised in CLAUDE.md but the batch dispatch path is non-functional.

**Reference**: `context/patterns/multi-task-operations.md` notes it as `"skill-batch-dispatch" # or integrated into skill-orchestrator`, confirming this was deferred.

#### 3.2 `code-reviewer-agent` Orphaned (HIGH confidence, Teammates B and C independently)

`code-reviewer-agent.md` exists with `model: opus`, is listed in CLAUDE.md's Agents table, context/index.json, and core-index-entries.json. However, no skill invokes it. The `/review` command executes directly at command level without delegating through the skill-agent pattern.

**Recommendation**: Either create `skill-reviewer` as a thin wrapper to connect `/review` -> `skill-reviewer` -> `code-reviewer-agent`, or remove the orphaned agent and document `/review` as intentionally direct-execution.

#### 3.3 Extension Naming Collisions (HIGH confidence)

- `filetypes` and `founder` extensions both define `spreadsheet-agent` and `skill-spreadsheet` with completely different purposes. Active collision when both extensions loaded.
- `web` extension duplicates core `skill-tag` and `tag.md` command identically.

**Recommendation**: Enforce extension-prefixed naming (`skill-filetypes-spreadsheet`, `skill-founder-spreadsheet`). Remove duplicated `skill-tag` from web extension.

#### 3.4 Missing Frontmatter Fields (HIGH confidence)

- 3 commands (`merge.md`, `refresh.md`, `tag.md`) missing `model` field
- 2 commands (`refresh.md`, `tag.md`) missing `argument-hint`
- 2 agents (`general-implementation-agent`, `meta-builder-agent`) missing explicit `model` field
- `skill-spawn` has non-standard `version` and `author` fields
- `skill-reviser` has redundant `model: opus` (agent already declares it)
- `skill-fix-it` missing from CLAUDE.md's Skill-to-Agent mapping table

#### 3.5 Present Extension Colon-Suffix Routing (MEDIUM confidence)

The `present` extension uses `skill-grant:assemble` routing notation, which is not supported by the Skill tool dispatch mechanism. The colon suffix appears to indicate an internal workflow mode but no skill directory named `skill-grant:assemble` exists.

### 4. Rules and Context Organization (from Teammate C)

#### 4.1 Deprecated `orchestrator.md` Still Loaded (HIGH confidence, P3)

`context/orchestration/orchestrator.md` (873 lines) is self-declared DEPRECATED since 2026-01-19, but `index.json` still loads it for every `/meta` command. This wastes significant context budget on outdated patterns.

#### 4.2 `index.json` Violates Its Own Schema (HIGH confidence)

`index.json` has `"version": null` but `index.schema.json` requires a semver string. The index file violates its own schema.

#### 4.3 Duplicate Taxonomy Boundaries (MEDIUM-HIGH confidence)

| Overlap | Files/Lines | Problem |
|---------|-------------|---------|
| `processes/` vs `workflows/` | Both contain research/planning/implementation workflow docs | No clear boundary |
| `orchestration/architecture.md` vs `architecture/system-overview.md` vs `docs/architecture/system-overview.md` | 3 "architecture overview" files, 1540 combined lines | Unclear which is canonical |
| `templates/thin-wrapper-skill.md` vs `patterns/thin-wrapper-skill.md` | Same name, different sizes (273 vs 204 lines) | Divergent canonical references |
| Preflight/postflight across 3 files | 1,142 combined lines | Any update requires 3-file sync |
| `checkpoints/` directory + `patterns/checkpoint-execution.md` | Overlapping checkpoint documentation | Two approaches to same concept |

#### 4.4 Broken Cross-Reference (HIGH confidence)

`rules/artifact-formats.md` references `rules/state-management.md` for "count-aware format" documentation, but the content actually lives in `context/reference/state-management-schema.md`.

#### 4.5 Rule Path Coverage Gaps (MEDIUM confidence)

`error-handling.md` and `workflows.md` only trigger on `.claude/**/*` paths, but errors and workflow patterns apply to all command executions including `specs/` operations.

#### 4.6 Single-File Directories (LOW confidence)

`context/guides/` (1 file) and `context/troubleshooting/` (1 file) add navigation overhead without organizational benefit.

### 5. Extension System (from Teammates B, D)

#### 5.1 Extension Development Guide Outdated (HIGH confidence, Teammate D)

`extension-development.md` describes a different manifest format (array vs object for `merge_targets`), references a non-existent `merge-extensions.sh` script, and describes a central manifest registry that doesn't exist.

#### 5.2 `dependencies` Field Always Empty (HIGH confidence)

All 14 manifests have `dependencies: []`. The field is dead weight that misleads extension developers. At 30+ extensions, it needs to become functional for conflict detection and load-order resolution.

#### 5.3 Two Extensions Lack `task_type` (MEDIUM confidence)

`filetypes` and `memory` have `task_type: null` but both have routing tables for their respective task types, creating a schema inconsistency.

### 6. Picker Integration (from Teammate D)

#### 6.1 Creative Improvements (ranked by impact/effort)

| Rank | Proposal | Impact | Effort |
|------|----------|--------|--------|
| 1 | Add .syncprotect status to Load preview | HIGH | LOW |
| 2 | .syncprotect wizard in picker (interactive file selection) | HIGH | MEDIUM |
| 3 | Auto-populate .syncprotect from extension state | HIGH | MEDIUM |
| 4 | /refresh scans for .backup files | MEDIUM | LOW |
| 5 | Per-file merge strategies in .syncprotect | MEDIUM | HIGH |
| 6 | Picker as documentation surface (health status, quick start) | MEDIUM | MEDIUM |
| 7 | Sync history logging | LOW | LOW |

#### 6.2 Long-Term Vision

The picker is evolving toward being the complete control plane for the agent system. The `.syncprotect` mechanism is a fundamental primitive for the "shared global core + project-specific customization" pattern. The backup mechanism duplicates git's role and should be replaced by proactive protection (.syncprotect) + reactive recovery (git).

## Synthesis

### Conflicts Resolved

1. **Backup policy**: Teammate A documented the mechanism; Teammate C found the rule contradiction; Teammate D provided strategic framing. Resolution: the git-safety.md position is correct -- backups should be eliminated in favor of .syncprotect + git. Update state-management.md to remove backup references.

2. **.syncprotect location safety**: Teammate A noted the file is "accidentally safe" (not in sync scan patterns); Teammate C called it a "functional bug." Resolution: While currently safe from being overwritten by sync, the placement inside `.claude/` is architecturally wrong because `.claude/` deletion would destroy it. Move to project root.

### Gaps Identified

1. **No system health check**: No automated validation that the agent system itself is healthy (rules consistent, index valid, skills-agent mappings correct, no orphans).
2. **No migration tooling**: When agent system format changes, no tooling detects or helps migrate existing components.
3. **No sub-type registry**: Users must read 14 manifests to discover all available task types and sub-types.
4. **Manifest validation**: No pre-load validation exists; typos in manifest keys silently fail.

### Recommendations

**Phase 1 - Critical Fixes** (system correctness):
1. Move .syncprotect to project root, update `load_syncprotect()` path
2. Resolve backup rule contradiction (update state-management.md, self-healing-implementation-details.md)
3. Remove deprecated orchestrator.md from index.json
4. Fix index.json version: null schema violation
5. Fix broken cross-reference in artifact-formats.md
6. Resolve spreadsheet-agent naming collision between filetypes and founder
7. Remove duplicate skill-tag from web extension

**Phase 2 - Architecture Improvements**:
8. Add .syncprotect visibility to picker preview
9. Make backup creation conditional (clean up after successful write, or eliminate entirely)
10. Create skill-reviewer to connect /review -> code-reviewer-agent (or document exception)
11. Implement or document absence of skill-batch-dispatch
12. Consolidate duplicate taxonomy (processes/ vs workflows/, architecture overlaps)
13. Update extension-development.md guide to match current system

**Phase 3 - Polish and Consistency**:
14. Add missing frontmatter fields to commands and agents
15. Remove non-standard frontmatter from skill-spawn
16. Remove redundant model from skill-reviser
17. Add skill-fix-it to CLAUDE.md mapping table
18. Merge single-file directories into parent directories
19. Standardize extension naming convention (extension-prefixed skills)
20. Validate/fix present extension's colon-suffix routing
21. Create default .syncprotect for active project repos
22. Add .syncprotect documentation to context files

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Findings |
|----------|-------|--------|------------|--------------|
| A | .syncprotect & Backup Mechanism | completed | high | 5 detailed findings with exact code references; complete backup call inventory |
| B | Commands, Skills, Agents Inventory | completed | high | 13 issues across 4 categories; discovered missing skill-batch-dispatch |
| C | Critic (Rules, Context, Accuracy) | completed | high | 10 priority issues; rule contradiction; deprecated files still loaded |
| D | Strategic Horizons & Picker | completed | high | 7 creative proposals; picker gap analysis; long-term vision |

## References

### Primary Source Files
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - .syncprotect implementation
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - backup mechanism
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - extension load/unload cycle
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - picker preview

### Agent System Components
- `.claude/CLAUDE.md` - Central configuration (942 lines)
- `.claude/context/index.json` - Context discovery index (96 entries)
- `.claude/rules/` - 6 rule files
- `.claude/commands/` - 14 commands
- `.claude/skills/` - 16 core skills
- `.claude/agents/` - 7 agents + README
- `.claude/extensions/` - 14 extensions

### Teammate Reports
- `specs/428_refactor_agent_system_syncprotect_and_organization/reports/01_teammate-a-findings.md`
- `specs/428_refactor_agent_system_syncprotect_and_organization/reports/01_teammate-b-findings.md`
- `specs/428_refactor_agent_system_syncprotect_and_organization/reports/01_teammate-c-findings.md`
- `specs/428_refactor_agent_system_syncprotect_and_organization/reports/01_teammate-d-findings.md`
