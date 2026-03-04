# Research Report: Task #123 (Supplemental)

**Task**: 123 - fix_nonatomic_extension_loading
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T01:00:00Z
**Effort**: Plan revision recommended (1-2 hours implementation, down from 2-4)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (init.lua, state.lua, loader.lua, merge.lua, config.lua), package manager patterns (Nix, lazy.nvim), research-001.md findings
**Artifacts**: - specs/123_fix_nonatomic_extension_loading/reports/research-002.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current 4-phase plan is overengineered for the actual failure mode. The core problem is that files get copied but state never gets written. The simplest fix is a single pcall around the copy+merge block with cleanup on failure -- no new state functions, no "loading" marker, no recovery detection.
- The "loading" state marker (Phase 1) and recovery detection (Phase 3) are **unnecessary** because the pcall rollback (Phase 2) already prevents orphaned files from occurring in the first place. If the process is killed mid-operation (the only scenario where pcall does not help), a "loading" state marker written to the same disk is equally unlikely to survive.
- The recommended simplified approach is a **single-phase change**: wrap the copy+merge block in pcall with file cleanup on failure, using infrastructure that already exists (`all_files`, `all_dirs`, `reverse_merge_targets`, `loader_mod.remove_installed_files`). This is approximately 20 lines of changes to one file.
- For historical orphans (files from past failed loads), the existing `unload` command already provides manual cleanup. No automated detection is needed for an edge case that occurs once.

## Context & Scope

The user raised a concern that the current 4-phase plan (implementation-001.md) is more complex than the problem warrants. This supplemental research evaluates whether simpler alternatives exist that achieve the same core objective: preventing orphaned files from failed extension loads.

### What the Current Plan Does (4 Phases, 2-4 Hours)

1. **Phase 1**: Add `mark_loading()` state marker to `state.lua` (30 min) -- writes "loading" status before copies begin
2. **Phase 2**: Wrap `manager.load()` copy+merge in pcall with rollback (1 hr) -- catches runtime errors, cleans up files and merges
3. **Phase 3**: Add `detect_incomplete_loads()` recovery detection (45 min) -- finds stale "loading" entries on next load attempt
4. **Phase 4**: Testing and validation (1 hr)

### The Actual Problem

When `manager.load()` hits a runtime error after file copies start (step 6, line 225) but before state write (step 14, line 259), orphaned files are left on disk. The documented crash site is `process_merge_targets` (step 12), specifically `vim.isarray(nil)` in `deep_merge()`.

## Analysis of Each Phase

### Phase 1 (Loading State Marker): Unnecessary

The "loading" state marker solves a problem that pcall already solves. The analysis:

**Scenario A: Runtime error (the common case)**
- pcall catches the error and rolls back files immediately
- No "loading" marker needed -- the cleanup happens in the same function call

**Scenario B: Process killed mid-operation (SIGKILL, power loss)**
- The "loading" marker *might* survive if it was written to disk before the kill
- But: the state write uses `io.open`/`file:write`/`file:close` followed by a `jq` shell-out. If the process is killed during the jq formatting step or between write and close, the "loading" marker itself could be corrupt
- More fundamentally: if we are protecting against catastrophic process death, writing a state marker to the same filesystem provides no additional guarantee. The marker write can fail for the same reasons the file copies fail

**Scenario C: Extension was loaded in a previous session and failed**
- This is a one-time historical issue already addressed by manual `unload` of the offending extension or manual file deletion
- Building automated detection for a problem that already occurred and will not recur (once pcall is in place) is overengineering

**Verdict**: Phase 1 adds complexity without meaningfully improving robustness. The "loading" marker is a belt-and-suspenders addition on top of pcall that only helps in a narrow window (process killed between state write and file copy start) that is unlikely and not worth the added code surface.

### Phase 2 (pcall with Rollback): The Essential Fix

This is the only phase that directly addresses the problem. It catches runtime errors (the actual documented failure mode) and cleans up. The key insight is that **all the rollback infrastructure already exists**:

- `all_files` and `all_dirs` are already tracked (init.lua lines 221-222)
- `loader_mod.remove_installed_files(installed_files, installed_dirs)` already exists (loader.lua lines 310-340)
- `reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)` already exists (init.lua lines 109-141)
- `merged_sections` is already returned from `process_merge_targets` (init.lua line 255)

The implementation is approximately 20 lines of restructuring in `manager.load()`.

**One simplification vs. the current plan**: The plan says to track `merged_sections` in outer scope for rollback. But this is already straightforward -- just declare the variable before the pcall block and assign it inside. The plan describes this as complex ("refactor process_merge_targets to track progress incrementally") but `process_merge_targets` already returns the tracking table progressively -- each merge step writes to `merged_sections` as it succeeds.

**Verdict**: Essential. This is the fix.

### Phase 3 (Recovery Detection): Unnecessary

Recovery detection (`detect_incomplete_loads`) is designed to find "loading" state entries from previous sessions. Since Phase 1 (loading marker) is unnecessary, Phase 3 has no data to detect and is therefore also unnecessary.

Even if we kept Phase 1, Phase 3 adds:
- A new function to iterate state entries
- A cleanup function that builds file paths from manifest provides data
- Integration logic at the start of `manager.load()`
- Edge case handling (what if the manifest changed since the failed load?)

All of this to handle a scenario (process killed between state write and load completion) that is already vanishingly rare, and for which manual recovery already works.

**Verdict**: Unnecessary overhead. The existing `unload` command handles historical orphans.

### Phase 4 (Testing): Scales With Scope

With phases 1 and 3 removed, the testing scope shrinks proportionally. Only the pcall+rollback behavior needs testing.

## Alternative Approaches Evaluated

### Alternative A: State-First (Write State Before Files)

**Concept**: Reverse the order -- write `extensions.json` with the full file manifest *before* copying any files. If the load fails, state already knows what was intended.

**Why it does not work well here**:
- The state entry format (state.lua `mark_loaded`) stores `installed_files` (actual target paths). These paths are computed during the copy process (e.g., `loader.lua` determines created directories, actual target paths). You would need to pre-compute all paths, duplicating the logic in loader.lua.
- If state writes first and files copy partially, you have the *inverse* inconsistency: state says "active" but files are missing. This is worse than the current problem because `unload` would try to remove files that do not exist (which is handled, but state would be corrupt).
- Does not prevent orphaned files -- it prevents orphaned *state*. The actual problem is orphaned *files*.

**Verdict**: Rejected. Inverts the problem rather than solving it.

### Alternative B: Staging Directory with Atomic Rename

**Concept**: Copy all files to a temporary staging directory, then rename (move) the staging directory into the target in one operation.

**Why it does not work here**:
- Extension files go to multiple target directories: `agents/`, `commands/`, `rules/`, `skills/`, `context/`, `scripts/`. There is no single target directory to atomically rename.
- Merge targets modify existing files (`CLAUDE.md`, `settings.local.json`, `index.json`). You cannot stage these because the target files already have other content.
- `rename()` across filesystem boundaries (if staging is on a different mount) falls back to copy+delete, losing atomicity.
- This approach works for package managers like Nix that install to isolated paths (`/nix/store/hash-name/`). It does not work when files are scattered across a shared directory tree.

**Verdict**: Rejected. Fundamentally incompatible with the extension system's file layout.

### Alternative C: Just pcall (No State Changes At All)

**Concept**: Wrap the copy+merge block in pcall. On failure, clean up copied files and reverse merges. No new functions, no state changes.

**This is the recommended approach.** It requires:
1. Moving `merged_sections` declaration before the pcall block (so rollback can access it)
2. Wrapping lines 225-255 in pcall
3. Adding an error handler that calls `remove_installed_files` and `reverse_merge_targets`
4. Returning the error

That is the entire change. No new modules. No new state functions. No recovery detection.

### Alternative D: Detect-and-Recover Only (No Prevention)

**Concept**: Skip pcall entirely. Instead, detect orphaned files by comparing `extensions.json` entries against files on disk. Offer cleanup when orphans are found.

**Why it is worse**:
- Detection is hard: how do you know a file in `.claude/agents/` was placed by an extension vs. created by the user? You would need to maintain a "known extension files" registry, which is effectively reimplementing state tracking.
- Reactive instead of preventive: the user still sees the orphaned files until they trigger detection.
- More code than the pcall approach (file scanning, path matching, user prompts) for a worse user experience.

**Verdict**: Rejected. More complex and less effective than pcall.

## Recommended Simplified Approach

### Single Change: pcall Wrapping in manager.load()

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`

**Conceptual diff** (approximately 20 lines of changes):

```lua
-- BEFORE (current code, lines 220-266):
local all_files = {}
local all_dirs = {}
-- Copy agents (line 225)
-- Copy commands (line 230)
-- Copy rules (line 235)
-- Copy skills (line 240)
-- Copy context (line 245)
-- Copy scripts (line 250)
-- Process merge targets (line 255)
-- Update state (lines 258-259)

-- AFTER (proposed):
local all_files = {}
local all_dirs = {}
local merged_sections = {}

local load_ok, load_err = pcall(function()
  -- Copy agents
  local files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "agents", ".md")
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Copy commands
  files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "commands", ".md")
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Copy rules
  files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "rules", ".md")
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Copy skills
  files, dirs = loader_mod.copy_skill_dirs(ext_manifest, source_dir, target_dir)
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Copy context
  files, dirs = loader_mod.copy_context_dirs(ext_manifest, source_dir, target_dir)
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Copy scripts
  files, dirs = loader_mod.copy_scripts(ext_manifest, source_dir, target_dir)
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Process merge targets
  merged_sections = process_merge_targets(ext_manifest, source_dir, project_dir, config)
end)

if not load_ok then
  -- Rollback: remove copied files
  loader_mod.remove_installed_files(all_files, all_dirs)
  -- Rollback: reverse any completed merge operations
  reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)
  return false, "Extension load failed: " .. tostring(load_err)
end

-- Success: update state
state = state_mod.mark_loaded(state, extension_name, ext_manifest, all_files, all_dirs, merged_sections)
state_mod.write(project_dir, state, config)
```

### Why This Is Sufficient

| Failure Mode | Current Plan | Simplified Plan | Difference |
|-------------|-------------|-----------------|------------|
| Runtime error in copy | pcall catches, rolls back | pcall catches, rolls back | Same |
| Runtime error in merge | pcall catches, rolls back files + merges | pcall catches, rolls back files + merges | Same |
| Runtime error in state write | Files already committed to state | Files already committed to state | Same |
| Process killed mid-copy | "loading" marker may survive for recovery | Orphaned files remain | Loading marker has same survival odds as the file copy |
| Historical orphans | detect_incomplete_loads() cleans up | Manual unload or file deletion | One-time issue, already occurred |

The only scenario where the simplified plan is weaker is process kill during file copy, and the loading marker provides minimal additional protection in that case (same disk, same failure modes).

### Estimated Effort

| Component | Time |
|-----------|------|
| pcall wrapping + rollback in init.lua | 30 min |
| Test: simulate error in copy, verify cleanup | 30 min |
| Test: simulate error in merge, verify file + merge rollback | 30 min |
| Test: verify normal load path unchanged | 15 min |
| **Total** | **~1.5 hours** |

This is down from 2-4 hours in the original plan.

## Decisions

1. **pcall-only over hybrid approach**: The loading state marker and recovery detection add complexity without meaningfully improving robustness. The pcall approach handles the documented failure mode (runtime errors) completely.

2. **No new state functions**: The existing `mark_loaded`, `mark_unloaded`, and `is_loaded` functions are sufficient. No `mark_loading`, `is_loading`, or `detect_incomplete_loads` needed.

3. **Reuse existing rollback infrastructure**: `reverse_merge_targets` and `remove_installed_files` already exist and are tested (they power the `unload` command). No new rollback functions needed.

4. **No rollback for rollback failures**: If `remove_installed_files` or `reverse_merge_targets` throws during rollback, we catch that too (the outer pcall is already protecting us). The worst case is partially cleaned up files, which is the same state as the current code but with better error reporting.

5. **Historical orphans handled manually**: The documented orphaned files in `Logos/Theory/.claude/` and `ProofChecker/.claude/` are a one-time issue. Running `unload` (if state exists) or manual deletion is sufficient.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Rollback leaves partial files (cleanup error) | Low | Medium | Return error message; user can manually clean up or use unload |
| pcall overhead affects normal load performance | None | None | pcall is negligible overhead in Lua |
| `merged_sections` partially populated when error occurs | Expected | None | `reverse_merge_targets` already handles partial sections (checks each key individually) |
| Process killed between file copy and state write | Very Low | Medium | Same risk as current code; loading marker does not meaningfully help |

## Context Extension Recommendations

None for this supplemental research. The previous report (research-001.md) already identified a gap around transactional file operations patterns.

## Appendix

### How Lazy.nvim Handles Install Failures

Lazy.nvim uses git for plugin installation (`git clone`). If a clone fails, the partial directory is left in place but not activated. Recovery is via the lockfile (`lazy-lock.json`) which records successful commit hashes. The `:Lazy restore` command re-clones to the locked version. This is a detect-and-recover approach, not a rollback approach, and works because each plugin is in its own isolated directory.

Key difference from our situation: lazy.nvim plugins are isolated directories (one per plugin), making cleanup trivial. Our extensions scatter files across shared directories (`agents/`, `commands/`, etc.), making isolation-based approaches infeasible.

### How Nix Handles Atomic Installs

Nix installs each package to an isolated path (`/nix/store/hash-name/`) and switches between configurations by flipping a symlink atomically. This is the theoretically cleanest approach but requires an entirely different file layout -- packages cannot share directories.

Not applicable to our situation because extension files must live in the shared `.claude/` directory structure.

### The pcall Pattern in Neovim Lua

pcall (protected call) is the standard Lua error handling mechanism. It runs a function in protected mode -- any error thrown inside the function is caught and returned as a second value:

```lua
local ok, err = pcall(function()
  -- code that might throw
end)
if not ok then
  -- err contains the error message
  -- clean up here
end
```

This is the idiomatic Lua approach to transactional operations. The codebase already uses pcall extensively (merge.lua uses it for JSON encoding validation, state.lua uses it for JSON decoding, init.lua uses it in `read_json`).

### References

- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- Main load function, rollback functions
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` -- File copy engine, remove_installed_files
- `lua/neotex/plugins/ai/shared/extensions/state.lua` -- State tracking
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` -- Merge strategies, backup/restore
- `lua/neotex/plugins/ai/shared/extensions/config.lua` -- Configuration schema
- [lazy.nvim](https://github.com/folke/lazy.nvim) -- Plugin manager install/recovery patterns
- [How Nix Works](https://nixos.org/guides/how-nix-works/) -- Atomic symlink-based package management
- [AerynOS atomic upgrades](https://aerynos.com/blog/2025/11/04/musings-on-inode-watchers-and-atomic-live-upgrades/) -- Staging directory + rename pattern
