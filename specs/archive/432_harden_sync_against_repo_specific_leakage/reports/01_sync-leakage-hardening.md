# Research Report: Harden Sync Engine Against Repo-Specific Content Leakage

- **Task**: 432 - Harden sync engine against repo-specific content leakage
- **Started**: 2026-04-14T21:00:00Z
- **Completed**: 2026-04-14T21:15:00Z
- **Effort**: medium
- **Dependencies**: None (task 433 depends on this)
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (834 lines) - Primary sync engine
  - `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (299 lines) - Directory scanning utilities
  - `.syncprotect` (root) - Currently empty (comments only)
  - `.claude/extensions/nvim/manifest.json` - Neovim extension manifest
  - `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Blocklist aggregation
  - Task 422 (completed) - Fixed sync overwriting all non-CLAUDE.md files (.syncprotect introduced)
  - Task 420 (completed) - Fixed extension loader overwriting repo-specific CLAUDE.md
- **Artifacts**: This report
- **Standards**: report-format.md, artifact-formats.md

## Project Context

- **Upstream Dependencies**: `sync.lua` depends on `scan.lua`, `manifest.lua`, `config.lua`, `merge.lua`, `state.lua`, `helpers.lua`
- **Downstream Dependents**: Task 433 (move nvim-specific content to extension) depends on this safety net
- **Alternative Paths**: Task 433's structural fix would eventually eliminate the need for content auditing, but the sync-exclude and auto-seed mechanisms remain independently valuable
- **Potential Extensions**: The audit pattern framework could be extended for other sync-target projects with domain-specific vocabularies

## Executive Summary

- The "Load Core" sync in `sync.lua` copies all non-extension core files to target repositories; currently `CONTEXT_EXCLUDE_PATTERNS` (4 entries) and `.syncprotect` provide the only protection against repo-specific leakage
- 35 core context files contain 198 occurrences of neovim/neotex-specific references that would be synced to non-Neovim repositories
- The `.syncprotect` file in the source repository is effectively empty (comments only, no protected paths)
- Three hardening mechanisms are needed: (1) expanded sync-exclude patterns for known repo-specific files, (2) post-sync content audit with configurable warning patterns, (3) auto-seeding `.syncprotect` on first sync to new repositories
- The extension blocklist system (`aggregate_extension_artifacts`) correctly excludes extension-declared files (agents, skills, rules, context directories) but does NOT prevent core files containing neovim examples from being synced

## Context & Scope

### Current Protection Mechanisms

1. **CONTEXT_EXCLUDE_PATTERNS** (sync.lua lines 24-29): Hardcoded list excluding 4 paths from context sync:
   - `project/repo/project-overview.md`
   - `project/repo/self-healing-implementation-details.md`
   - `index.json`
   - `index.json.backup`

2. **Extension blocklist** (manifest.lua `aggregate_extension_artifacts`): Builds per-category blocklists from all extension manifests' `provides` fields. The nvim extension declares `["project/neovim"]` under `provides.context`, so the entire `context/project/neovim/` directory is blocked from sync. This works correctly.

3. **.syncprotect** (root of target repo): Protects listed paths from replacement during sync. Read by `load_syncprotect()` (sync.lua lines 386-421). Currently empty in the source repo.

4. **CONFIG_MARKDOWN_FILES section preservation**: Preserves extension-injected `<!-- SECTION -->` blocks in CLAUDE.md and OPENCODE.md during full sync (sync.lua lines 35-83).

5. **README.md exclusion**: `scan.lua` line 100-105 skips all README.md files during sync.

6. **Root CLAUDE.md exclusion**: sync.lua line 568-572 intentionally does NOT sync the root-level CLAUDE.md (which contains Neovim-specific coding standards).

### What Leaks Through

The existing mechanisms leave gaps:

**Core context files with neovim references (synced to all repos):**
- `context/orchestration/routing.md` - 41 occurrences (neovim routing examples, validation scripts)
- `context/standards/error-handling.md` - 13 occurrences (neotex paths, neovim agent references)
- `context/standards/task-management.md` - 12 occurrences (neovim task type detection, routing examples)
- `context/architecture/system-overview.md` - 10 occurrences (neovim delegation examples)
- `context/orchestration/orchestrator.md` - 9 occurrences (neovim routing)
- `context/formats/return-metadata-file.md` - 20 occurrences (neovim-specific examples, typos "Cneovim")
- Plus 29 additional files with 1-6 occurrences each

**Nature of references**: Most are illustrative examples (e.g., `"task_type": "neovim"`, routing examples) rather than functional neovim integration. However, they create confusion in non-Neovim repos by suggesting neovim-specific capabilities.

**.claude/CLAUDE.md** (synced as root_file): Lines 75, 120, 200, 222 contain neovim as example text. This is addressed by task 433.

## Findings

### Finding 1: Sync-Exclude Mechanism Location

The task description mentions a "sync-exclude file" approach. Currently:
- `CONTEXT_EXCLUDE_PATTERNS` is a hardcoded Lua table (sync.lua line 24)
- `.syncprotect` is for target repos to protect their local files
- There is no configurable exclude mechanism in the source repo

**Options for a configurable source-side exclude:**
- **Option A**: A `.sync-exclude` file at the project root (like `.syncprotect` but for the source)
- **Option B**: Extend `CONTEXT_EXCLUDE_PATTERNS` to be loaded from a file
- **Option C**: Add an `# exclude:` directive to `.syncprotect` (overloading an existing file)

Option A is cleanest -- separate concerns (`.syncprotect` = target protection, `.sync-exclude` = source exclusion).

### Finding 2: Post-Sync Content Audit Architecture

The task requires scanning synced files for configurable warning patterns after `execute_sync()` completes (sync.lua line 365-366). Key design decisions:

- **Pattern storage**: Could live in `.sync-exclude` as `# audit-patterns:` directives, or in a separate `.sync-audit-patterns` file. The task description suggests the sync-exclude file.
- **Scan scope**: Must scan only the files that were actually synced (available from `all_artifacts` map)
- **Output**: Non-blocking informational warnings in the sync results summary
- **Implementation point**: After `execute_sync()` returns on line 365 (before `reinject_loaded_extensions()` on line 674)

### Finding 3: Auto-Seed .syncprotect

The `load_all_globally()` function (sync.lua line 580) is the entry point for full sync. When it detects no `.syncprotect` in the target repo, it should create one with standard entries.

**Current behavior**: `load_syncprotect()` returns empty table if no file exists (line 407-408). No seeding occurs.

**Standard entries for auto-seeded .syncprotect**:
- `context/repo/project-overview.md` - Already excluded by CONTEXT_EXCLUDE_PATTERNS, but defense-in-depth
- Additional entries depend on what the target project customizes

### Finding 4: scan_directory_for_sync Exclude Mechanism

The `scan_directory_for_sync()` function (scan.lua line 54) already supports `exclude_patterns` parameter with both exact match and prefix match (lines 111-125). This is robust enough for expanded excludes.

However, the exclude only applies to the `context` artifact type (sync.lua line 516-518). Other artifact types (agents, skills, rules) only get the extension blocklist. Adding a general-purpose exclude would require either:
- Passing exclude patterns to all `sync_scan()` calls
- Or adding a separate exclusion layer in `sync_files()`

### Finding 5: Content Audit Pattern Candidates

For detecting neovim-specific content leakage, these Lua patterns would be appropriate:
- `neovim` (case-insensitive)
- `neotex`
- `lazy%.nvim` (Lua pattern escaping)
- `nvim%-lspconfig`
- `lazy%.vim`
- `wezterm` (from error-handling.md context)
- `nvim/lua/` (path patterns)

These should be configurable per source repo, not hardcoded.

### Finding 6: Implementation Insertion Points

1. **Expanded sync-exclude** (Finding 1): New file `.sync-exclude` at project root, loaded by a new `load_sync_exclude()` function in sync.lua. Patterns merged into `CONTEXT_EXCLUDE_PATTERNS` or passed alongside it.

2. **Post-sync audit** (Finding 2): New function `audit_synced_files()` called after `execute_sync()` on sync.lua line 366. Takes the `all_artifacts` map and a list of audit patterns. Reads each synced file and checks for pattern matches.

3. **Auto-seed .syncprotect** (Finding 3): In `load_all_globally()`, after line 664 (where `load_syncprotect()` is called), check if the returned table is empty AND no `.syncprotect` file exists. If so, write a default one.

## Decisions

- The three mechanisms are independent and can be implemented in any order
- `.sync-exclude` (source-side) and `.syncprotect` (target-side) should remain separate files for clarity
- Post-sync audit should be non-blocking (warnings only) to avoid disrupting sync workflow
- Auto-seeded `.syncprotect` should contain only `context/repo/project-overview.md` as the single standard entry
- Audit patterns should be stored in `.sync-exclude` using a `# audit-pattern: <pattern>` directive to avoid yet another config file

## Recommendations

1. **Create `.sync-exclude` file format**: Lines are relative paths (like `.syncprotect`) that prevent source files from being included in sync. Supports `# audit-pattern: <lua-pattern>` directives for post-sync content auditing. Loaded once at the start of `load_all_globally()`.

2. **Implement `load_sync_exclude()` in sync.lua**: Similar structure to `load_syncprotect()`. Returns two values: `{[path] = true}` exclude set and `{pattern1, pattern2, ...}` audit patterns array.

3. **Thread exclude paths into `scan_all_artifacts()`**: Pass the exclude set as an additional parameter. Apply it in `sync_scan()` wrapper alongside the existing blocklist. This is cleaner than filtering after scanning.

4. **Add `audit_synced_content()` function**: After `execute_sync()`, iterate through `all_artifacts`, read each synced file, check against audit patterns. Collect matches and display summary. Include file path and match count in the notification.

5. **Auto-seed `.syncprotect` in `load_all_globally()`**: Before the sync choice dialog, check if `.syncprotect` exists. If not, write default entries and notify user. This ensures protection before any files are synced.

6. **Populate initial `.sync-exclude` with known neovim-specific paths**: While task 433 will eventually move these to the extension, having them in `.sync-exclude` provides an immediate safety net.

## Risks and Mitigations

- **Risk**: Audit false positives from generic mentions of "neovim" in extension documentation. **Mitigation**: Audit is non-blocking; patterns are configurable and can be tuned per-repo.
- **Risk**: Auto-seeded `.syncprotect` may overwrite a user-created file. **Mitigation**: Only seed if file does not exist (explicit existence check, not empty-return check).
- **Risk**: `.sync-exclude` adds complexity to the sync workflow. **Mitigation**: File is optional; if missing, behavior is identical to current (no excludes, no audit).
- **Risk**: Performance impact of reading all synced files for content audit. **Mitigation**: Only read files that were actually synced (not skipped), and pattern matching is fast.

## Appendix

### File Count Summary

| Artifact Type | Files Synced | With Neovim Refs |
|---------------|-------------|-----------------|
| Context (md) | ~60 | 35 |
| Rules | ~6 | 1 |
| Agents | ~7 | 3 |
| Skills | ~20+ | unknown |
| Commands | ~10 | unknown |
| Total estimated | ~100+ | 39+ |

### Related Tasks

- Task 422: Fixed sync overwriting all non-CLAUDE.md files (introduced .syncprotect)
- Task 420: Fixed extension loader overwriting repo-specific customizations
- Task 428: Refactored agent system with syncprotect integration
- Task 433: Will move nvim-specific content to extension (depends on this task)
