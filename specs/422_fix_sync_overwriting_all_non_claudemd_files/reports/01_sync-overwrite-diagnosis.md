# Research Report: Task #422

**Task**: 422 - Fix sync.lua overwriting all non-CLAUDE.md files in target repos
**Started**: 2026-04-13T12:00:00Z
**Completed**: 2026-04-13T12:30:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (full read)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (full read)
- Zed task 62 audit report: `~/.config/zed/specs/062_triage_nvim_sync_changes/reports/01_sync-triage-audit.md`
- Extension state module: `lua/neotex/plugins/ai/shared/extensions/state.lua`
**Artifacts**:
- `specs/422_fix_sync_overwriting_all_non_claudemd_files/reports/01_sync-overwrite-diagnosis.md` (this report)
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The sync mechanism has three distinct root causes that produce unwanted overwrites in target repos: (1) no exclusion of generated JSON files from context sync, (2) `scan_directory_for_sync` not skipping README.md unlike `scan_directory`, (3) no mechanism for target repos to protect locally-customized files from replacement.
- `context/index.json` and `context/index.json.backup` are synced via the `ctx_json` scan (line 440 of sync.lua) even though they are generated/merged per-repo by the extension loader.
- `extensions.json` is NOT synced by sync.lua -- it is written locally by the extension state module (`state.lua:write()`). Its appearance in the zed audit was from the extension loader, not from sync. No fix needed for this file.
- The section preservation mechanism (lines 42-80 of sync.lua) correctly handles CLAUDE.md and OPENCODE.md but all other files are blindly overwritten when "Sync all" is chosen.
- Two complementary solutions are recommended: (A) add built-in exclusions for generated JSON files, and (B) add `.syncprotect` file support for per-repo file protection.

## Context & Scope

The "Load Core Agent System" operation (`sync.lua:load_all_globally()`) copies agent system files from the nvim global config to target project repositories. When a user chooses "Sync all (replace existing)", every scanned file is overwritten except CLAUDE.md and OPENCODE.md which receive section preservation treatment. This destroys per-repo customizations like:
- `rules/git-workflow.md` (zed omits Co-Authored-By, nvim includes it)
- `agents/README.md` (zed lists slide-planner-agent, nvim does not)
- `CLAUDE.md` (zed has slide-planner and hooks sections, nvim does not)
- `context/index.json` (each repo has extension entries merged in)

The zed task 62 audit found 5 DISCARD files and 14 KEEP files across 19 changed files from a sync operation. Three of the five DISCARDs were content regressions; two were generated JSON noise.

## Findings

### Root Cause 1: Generated JSON files synced without exclusion

**Location**: `sync.lua` lines 440-441

```lua
local ctx_json = sync_scan("context", "*.json", true, nil, "context")
```

This scans `context/*.json` recursively, which picks up:
- `context/index.json` -- the merged context index containing both core and extension entries
- `context/index.json.backup` -- backup of the above

These files are generated per-repo by the extension loader's `merge_mod.append_index_entries()` function. Syncing them from nvim to another repo overwrites the target's merged index with nvim's merged index, which may contain different extension entries.

**Fix**: Add `index.json` and `index.json.backup` to `CONTEXT_EXCLUDE_PATTERNS`.

**Note on extensions.json**: The audit report listed this as a DISCARD file, but it is NOT synced by sync.lua. It is written by `state.lua:write()` when extensions are loaded/unloaded. The key reordering seen in the zed audit was caused by the extension loader running locally, not by sync. No fix needed in sync.lua for this file.

### Root Cause 2: scan_directory_for_sync does not skip README.md

**Location**: `scan.lua` lines 54-140 (`scan_directory_for_sync`)

The `scan_directory` function (line 23-42) explicitly skips `README.md`:
```lua
local is_readme = filename == "README.md"
if not is_readme then
  -- ... add to results
end
```

But `scan_directory_for_sync` (line 54-140) has no such check. This means README.md files in subdirectories (like `agents/README.md`) are included in sync operations and overwrite the target's README.md files, which may contain repo-specific content (like the slide-planner-agent entry in zed's `agents/README.md`).

**Fix**: Add a README.md skip check in `scan_directory_for_sync`, matching the behavior of `scan_directory`.

### Root Cause 3: No per-repo file protection mechanism

**Location**: `sync.lua` lines 226-269 (`sync_files`)

The `sync_files` function has two modes:
1. `merge_only = true`: Only copies NEW files (skips "replace" actions)
2. `merge_only = false`: Overwrites everything, with section preservation ONLY for `CONFIG_MARKDOWN_FILES` (CLAUDE.md, OPENCODE.md)

There is no mechanism for a target repo to say "these specific files should not be replaced during sync." When a user chooses "Sync all," files like `rules/git-workflow.md` (which has zed-specific Co-Authored-By preferences) are unconditionally overwritten.

**Fix**: Add `.syncprotect` file support -- a simple newline-delimited list of relative paths (relative to `.claude/`) that should be skipped during "replace" operations.

### Root Cause Analysis: CLAUDE.md section preservation is necessary but insufficient

The existing section preservation (lines 42-80) correctly handles the case where extensions inject `<!-- SECTION: id -->` blocks into CLAUDE.md. However, the zed audit showed that CLAUDE.md changes from sync were ALL regressions -- not because sections were lost, but because the BASE content of nvim's CLAUDE.md lacks zed-specific entries (slide-planner-agent, hooks documentation, present:slides routing).

These are not extension-injected sections; they are manual edits to CLAUDE.md that exist only in zed. The section preservation mechanism cannot help here because the content is not wrapped in section markers.

This reinforces the need for `.syncprotect` -- repos with manually-customized CLAUDE.md (beyond extension sections) need a way to protect it.

## Decisions

1. **extensions.json is out of scope**: It is not synced by sync.lua. The audit report's observation was from the extension loader, not sync.
2. **Built-in exclusions over configuration**: For generated files like index.json, a built-in exclusion is better than requiring every target repo to add them to .syncprotect.
3. **Two-layer protection**: Built-in exclusions for generated files (automatic) + .syncprotect for per-repo customizations (opt-in).
4. **README.md consistency**: scan_directory_for_sync should match scan_directory behavior for README.md skipping.

## Recommendations

### Priority 1: Add index.json to CONTEXT_EXCLUDE_PATTERNS (sync.lua)

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
**Change**: Add two entries to `CONTEXT_EXCLUDE_PATTERNS`:

```lua
local CONTEXT_EXCLUDE_PATTERNS = {
  "project/repo/project-overview.md",
  "project/repo/self-healing-implementation-details.md",
  "index.json",          -- Generated per-repo by extension loader
  "index.json.backup",   -- Backup of generated index
}
```

These use exact-match semantics in `scan_directory_for_sync`, matching the `rel_path` which for top-level context files is just the filename.

**Risk**: Low. These files should never be synced between repos.

### Priority 2: Skip README.md in scan_directory_for_sync (scan.lua)

**File**: `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
**Change**: Add a README.md check inside the file processing loop (after line 100, before the exclude_patterns check):

```lua
-- Skip README.md files (consistent with scan_directory behavior)
local filename = vim.fn.fnamemodify(global_file, ":t")
if filename == "README.md" then
  goto continue
end
```

**Risk**: Low. README.md files are documentation files specific to each repo. The `scan_directory` function already skips them for the same reason.

### Priority 3: Add .syncprotect file support (sync.lua)

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
**Design**:

1. Define a new function `load_syncprotect(project_dir, base_dir)` that reads `{project_dir}/{base_dir}/.syncprotect` and returns a set of relative paths.

2. Pass the protected set to `sync_files()` as a new parameter.

3. In `sync_files()`, when `file.action == "replace"`, check if the file's relative path (from base_dir) is in the protected set. If so, skip it.

**File format** (`.claude/.syncprotect`):
```
# Files protected from sync overwrite
# Relative paths from .claude/ directory
# Lines starting with # are comments, empty lines ignored
rules/git-workflow.md
agents/README.md
CLAUDE.md
```

**Loading logic**:
```lua
local function load_syncprotect(project_dir, base_dir)
  local protect_path = project_dir .. "/" .. base_dir .. "/.syncprotect"
  local file = io.open(protect_path, "r")
  if not file then return {} end
  local protected = {}
  for line in file:lines() do
    line = vim.trim(line)
    if line ~= "" and not line:match("^#") then
      protected[line] = true
    end
  end
  file:close()
  return protected
end
```

**Integration points**:
- `execute_sync()` loads the .syncprotect set and passes it through to `sync_files()`
- `sync_files()` receives a `protected_paths` parameter
- Before writing a "replace" file, compute the relative path from base_dir and check if it's protected
- Protected files are counted separately in the notification (e.g., "Skipped: 3 protected")

**Risk**: Medium. Requires changes to function signatures (`sync_files`, `execute_sync`). Protected files should be logged so users know why files were skipped.

### Priority 4: Consider section preservation for additional markdown files

Currently only CLAUDE.md and OPENCODE.md get section preservation. Other markdown files with extension-injected sections (if any exist in the future) would be overwritten. This is a future consideration, not an immediate fix.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| `.syncprotect` file not created by default | Low | Document in README.md; consider prompting user on first "Sync all" |
| Excluding index.json breaks fresh project setup | None | Fresh projects get index.json via extension loading, not sync |
| README.md skip might hide wanted README updates | Low | Users can manually copy READMEs; this matches existing scan_directory behavior |
| .syncprotect path matching edge cases (subdirs) | Low | Use relative paths from base_dir; normalize separators |
| Protected file notification clutter | Low | Only show protected count if > 0 |

## Appendix

### Key Code Locations

| Component | File | Lines |
|-----------|------|-------|
| sync_files (overwrite logic) | `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | 226-269 |
| section preservation | same | 42-80 |
| CONFIG_MARKDOWN_FILES | same | 32-35 |
| CONTEXT_EXCLUDE_PATTERNS | same | 22-26 |
| execute_sync | same | 277-333 |
| scan_all_artifacts (ctx_json scan) | same | 440-441 |
| root_file_names | same | 469-473 |
| scan_directory (skips README) | `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` | 23-42 |
| scan_directory_for_sync (no README skip) | same | 54-140 |
| extension state write | `lua/neotex/plugins/ai/shared/extensions/state.lua` | 95+ |

### Zed Audit Reference

The zed task 62 audit (`~/.config/zed/specs/062_triage_nvim_sync_changes/reports/01_sync-triage-audit.md`) identified these DISCARD files:

| File | Root Cause in This Analysis |
|------|----------------------------|
| CLAUDE.md | Root Cause 3 (no per-repo protection) |
| agents/README.md | Root Cause 2 (README not skipped) + Root Cause 3 |
| rules/git-workflow.md | Root Cause 3 (no per-repo protection) |
| context/index.json | Root Cause 1 (generated JSON synced) |
| context/index.json.backup | Root Cause 1 (generated JSON synced) |
| extensions.json | NOT a sync issue (extension loader writes locally) |
