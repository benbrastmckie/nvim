# Research Report: Task #439

**Task**: 439 - Harden sync protection and clean deprecated index
**Started**: 2026-04-14T22:00:00Z
**Completed**: 2026-04-14T22:15:00Z
**Effort**: Small (2 files modified, index cleanup)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
- Codebase: `.claude/context/index.json`
- Codebase: `.syncprotect` (project root)
- Codebase: 6 deprecated context files
**Artifacts**:
- `specs/439_harden_sync_protection_and_clean_deprecated_index/reports/01_sync-protection.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The `.syncprotect` file at project root is NOT touched by sync (it lives outside `.claude/`), but the legacy `.claude/.syncprotect` location has no migration path -- entries are silently lost
- The auto-seed mechanism (lines 821-833) creates only minimal protection (`context/repo/project-overview.md`), discarding any entries from the legacy location
- 5 deprecated entries exist in `index.json` pointing to files marked `DEPRECATED (2026-01-19)`, plus a 6th deprecated file (`orchestration/orchestrator.md`) not in the index
- Fixes require: (1) legacy migration in `load_syncprotect`, (2) self-protection entry in seed content, (3) removal of 5 index entries

## Context & Scope

Task 433 moved `.syncprotect` from `.claude/.syncprotect` to the project root. Target repositories (e.g., zed) that had substantive `.claude/.syncprotect` files risk losing their protection entries because:
1. The current code warns about the legacy location but never migrates entries
2. The auto-seed creates a new minimal `.syncprotect` at project root without incorporating legacy entries
3. Once the root file exists, the legacy file is never consulted again

## Findings

### 1. Sync Architecture -- How .syncprotect Works

**Load path** (`load_syncprotect`, lines 430-465):
1. Try `{project_dir}/.syncprotect` (canonical, project root)
2. Fall back to `{project_dir}/{base_dir}/.syncprotect` (legacy, e.g., `.claude/.syncprotect`)
3. If legacy found, show deprecation warning
4. Parse non-comment, non-empty lines into a set `{[path] = true}`

**Usage in full sync** (`load_all_globally`, lines 818-833):
1. Call `load_syncprotect(project_dir, base_dir)` to get protected paths
2. If root `.syncprotect` does not exist, auto-seed it with minimal content
3. Re-read protected paths after seeding
4. Pass `protected_paths` to `execute_sync` -> `sync_files`

**Usage in single-file update** (`update_artifact_from_global`, lines 914-949):
1. Call `load_syncprotect(project_dir, base_dir)`
2. Build relative path for the artifact being updated
3. Skip if path is in protected set

### 2. The Destruction Scenario

The sync code itself does NOT delete files -- it only copies (new) or replaces (existing). The `.syncprotect` file is never included in any artifact scan because:
- `scan_all_artifacts` scans specific subdirectories with specific extensions (`.md`, `.sh`, `.json`, `.yaml`, `.service`, `.timer`)
- `.syncprotect` has no extension and is not in any scanned subdirectory
- Root file sync only covers: `.gitignore`, `README.md`, `CLAUDE.md`, `settings.local.json`

The actual destruction vector is **silent entry loss**, not file deletion:
1. Target repo has `.claude/.syncprotect` with 30 protection entries
2. User runs "Load Core" sync
3. `load_syncprotect` reads the legacy file (line 439), entries are used for THIS sync
4. Auto-seed check at line 823: root `.syncprotect` does NOT exist
5. Auto-seed creates root `.syncprotect` with ONLY `context/repo/project-overview.md`
6. Re-read at line 833 now reads the ROOT file (1 entry), NOT the legacy file (30 entries)
7. BUT: `protected_paths` was already loaded at line 819 with the legacy entries, and the re-read at line 833 overwrites it with just 1 entry
8. **Result**: 29 of 30 entries are lost for THIS sync operation, AND for all future syncs

This is the bug: the auto-seed at lines 821-833 happens AFTER `load_syncprotect` already read the legacy file, but the re-read replaces those entries with the minimal seed.

### 3. Deprecated Index Entries

6 files in `.claude/context/` contain `DEPRECATED (2026-01-19)` markers. 5 of these have entries in `index.json`:

| # | Path | Summary | line_count | load_when |
|---|------|---------|-----------|-----------|
| 1 | `orchestration/delegation.md` | Agent delegation patterns | 859 | agents: meta-builder-agent, task_types: meta |
| 2 | `orchestration/sessions.md` | Session management | 166 | task_types: meta |
| 3 | `orchestration/subagent-validation.md` | Subagent validation rules | 313 | task_types: meta |
| 4 | `orchestration/validation.md` | General validation patterns | 699 | agents: meta-builder-agent, task_types: meta |
| 5 | `workflows/status-transitions.md` | Valid status transitions | 86 | task_types: meta, commands: /task |

The 6th deprecated file (`orchestration/orchestrator.md`) is NOT in `index.json` -- no action needed for the index.

**Total stale line_count being loaded**: 2,123 lines of deprecated content that redirects to consolidated files. This wastes context budget when agents load these entries.

### 4. Current .syncprotect Content

The project root `.syncprotect` contains:
```
# Protected files - not overwritten during sync operations...
context/repo/project-overview.md
```

Only 1 active entry. The `.syncprotect` file does not protect itself.

## Decisions

- The sync code does not need file-deletion protection (sync never deletes)
- The real bug is the auto-seed overwriting legacy entries during migration
- All 5 deprecated index entries should be removed (files can stay as redirects)

## Recommendations

### Fix 1: Legacy Migration in load_syncprotect (Priority: HIGH)

Modify `load_all_globally` (around lines 818-834) to merge legacy entries into the new root file instead of discarding them:

```lua
-- Load syncprotect list from target repo (if it exists)
local protected_paths = load_syncprotect(project_dir, base_dir)

-- Auto-seed .syncprotect if target repo has none at root
local syncprotect_path = project_dir .. "/.syncprotect"
if vim.fn.filereadable(syncprotect_path) == 0 then
  local seed_content = "# Protected files - not overwritten during sync\n"
    .. "# Add relative paths (one per line) to protect local customizations\n"
    .. "# Paths are relative to the base directory (e.g., rules/my-rule.md)\n"
    .. "\n"
    .. "# Repository-specific context (defense-in-depth, also in CONTEXT_EXCLUDE_PATTERNS)\n"
    .. "context/repo/project-overview.md\n"

  -- Migrate entries from legacy location if they exist
  local legacy_path = project_dir .. "/" .. base_dir .. "/.syncprotect"
  if vim.fn.filereadable(legacy_path) == 1 then
    local legacy_file = io.open(legacy_path, "r")
    if legacy_file then
      local legacy_lines = {}
      for line in legacy_file:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
          -- Only add entries not already in seed
          if trimmed ~= "context/repo/project-overview.md" then
            table.insert(legacy_lines, trimmed)
          end
        end
      end
      legacy_file:close()
      if #legacy_lines > 0 then
        seed_content = seed_content .. "\n# Migrated from " .. base_dir .. "/.syncprotect\n"
        for _, entry in ipairs(legacy_lines) do
          seed_content = seed_content .. entry .. "\n"
        end
      end
    end
  end

  helpers.write_file(syncprotect_path, seed_content)
  helpers.notify("Created .syncprotect with default entries", "INFO")
  -- Re-read includes migrated entries
  protected_paths = load_syncprotect(project_dir, base_dir)
end
```

### Fix 2: Self-Protection (Priority: MEDIUM)

The `.syncprotect` file is currently safe because sync never touches it (it lives at project root, outside `.claude/`). However, as defense-in-depth, the seed content should document this:

Add a comment to the seed content:
```
# Note: this file lives at project root, outside the sync base directory,
# so it is inherently safe from sync operations.
```

No code change needed for self-protection since the file is already outside the sync scope.

### Fix 3: Remove 5 Deprecated Index Entries (Priority: HIGH)

Remove these 5 entries from `.claude/context/index.json`:
1. `orchestration/delegation.md`
2. `orchestration/sessions.md`
3. `orchestration/subagent-validation.md`
4. `orchestration/validation.md`
5. `workflows/status-transitions.md`

This recovers 2,123 lines of context budget that currently loads deprecated redirect stubs. The deprecated files themselves should remain as redirects for anyone who has bookmarked or referenced them.

### Fix 4: Add .syncprotect to .sync-exclude (Priority: LOW)

If `.syncprotect` were ever placed inside `.claude/` by accident, the `.sync-exclude` file in the source repo should exclude it:

```
# .sync-exclude
.syncprotect
```

This is belt-and-suspenders protection.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Legacy migration creates duplicate entries | Low | Low | Dedup against seed entries before writing |
| Removing index entries breaks agent context loading | Low | None | Deprecated files only redirect; agents already have the consolidated files |
| Future sync changes scan `.syncprotect` | Low | Medium | Document in code comments that `.syncprotect` must never be synced |

## Appendix

### Files Examined
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (full file, 1038 lines)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (scan_directory_for_sync function)
- `.claude/context/index.json` (deprecated entry search)
- `.syncprotect` (current content)
- 6 deprecated context files (DEPRECATED marker verification)

### Key Line References in sync.lua
- `load_syncprotect`: lines 430-465
- `sync_files` (protection check): lines 232-286, specifically 245-249
- `load_all_globally` (auto-seed): lines 818-834
- `scan_all_artifacts` (what gets synced): lines 577-723
- `root_file_names` (root files in sync): lines 691-696
