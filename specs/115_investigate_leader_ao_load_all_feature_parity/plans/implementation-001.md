# Implementation Plan: Fix OpenCode Load All Feature Parity

- **Task**: 115 - investigate_leader_ao_load_all_feature_parity
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `<leader>ao` Load All Artifacts operation for OpenCode is missing 11 artifact categories because `scan_all_artifacts()` in `sync.lua` guards most scanning behind `if base_dir == ".claude"`. Additionally, the agents path is hardcoded as `"agents"` but OpenCode uses `"agent/subagents"`, and the orchestrator at `agent/orchestrator.md` is not synced. This plan removes the system-specific guard to make scanning unconditional, fixes the agents path to use the config value, adds orchestrator syncing, and expands the root files list.

### Research Integration

Research report `research-001.md` identified:
- The `if base_dir == ".claude"` guard at sync.lua:184-217 is the root cause, blocking hooks, templates, docs, scripts, rules, context, systemd, and settings from OpenCode syncing
- The agents path mismatch: code scans `agents/` but OpenCode uses `agent/subagents/`
- The orchestrator.md at `agent/orchestrator.md` is outside `agent/subagents/` and missed
- Root files list for OpenCode is incomplete (missing .gitignore, README.md, QUICK-START.md)
- `scan_directory_for_sync` safely returns empty arrays for non-existent directories, so unconditional scanning is safe

## Goals & Non-Goals

**Goals**:
- Achieve full feature parity between `<leader>ac` Load All and `<leader>ao` Load All for all artifact categories that exist in `.opencode/`
- Fix agents path to use config-provided `agents_subdir` instead of hardcoded `"agents"`
- Sync orchestrator.md for OpenCode
- Expand OpenCode root files to include .gitignore, README.md, QUICK-START.md

**Non-Goals**:
- Syncing extensions directory (has its own load/unload lifecycle via picker UI)
- Adding `lib/` or `tests/` scanning for OpenCode (directories do not exist in .opencode/)
- Changing the `update_artifact_from_global` single-file sync path (separate concern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Syncing 200+ context files could be slow for OpenCode | Low | Low | Same recursive scan already works for .claude context; no performance difference |
| Unconditional scanning could scan non-existent directories | None | N/A | `scan_directory_for_sync` already returns empty array for missing dirs |
| Breaking existing .claude Load All behavior | High | Low | Phase 3 includes headless verification for both systems |
| Root file settings.json appears in both root_files and settings category | Medium | Medium | OpenCode uses root_files for settings.json; the separate `settings` category only applies to .claude |

## Implementation Phases

### Phase 1: Fix agents path and orchestrator syncing [COMPLETED]

**Goal:** Make agents scanning use config-provided `agents_subdir` and add orchestrator.md syncing for OpenCode.

**Tasks:**
- [ ] In `scan_all_artifacts()`, change `sync_scan("agents", "*.md")` to use `(config and config.agents_subdir) or "agents"` for the agents subdirectory
- [ ] Add orchestrator.md scanning for OpenCode: after scanning `agent/subagents`, also scan `agent/orchestrator.md` and append to agents list
- [ ] Verify the config object is reliably passed through from `load_all_globally()` to `scan_all_artifacts()`

**Timing:** 30 minutes

**Files to modify:**
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Lines 169-170 (agents scan), add orchestrator logic after

**Verification:**
- Agents list populated for OpenCode config with `agents_subdir = "agent/subagents"`
- Orchestrator.md included in agents list for OpenCode

---

### Phase 2: Remove .claude-only guard and make scanning unconditional [COMPLETED]

**Goal:** Move all artifact scanning outside the `if base_dir == ".claude"` guard so both systems get the same categories scanned.

**Tasks:**
- [ ] Move `hooks`, `templates`, `docs`, `scripts`, `rules` scanning outside the guard to be unconditional (lines 185-191)
- [ ] Move context scanning (multi-type: md, json, yaml) outside the guard to be unconditional (lines 193-202)
- [ ] Move systemd scanning outside the guard to be unconditional (lines 204-213)
- [ ] Keep `lib`, `tests`, and `settings` scanning inside a `.claude`-only guard since those directories are .claude-specific
- [ ] Expand OpenCode `root_file_names` to include `.gitignore`, `README.md`, `QUICK-START.md` (line 222)

**Timing:** 45 minutes

**Files to modify:**
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Lines 183-226 (the entire conditional block restructured)

**Verification:**
- All shared artifact categories scanned regardless of base_dir
- .claude-specific categories (lib, tests, settings) still guarded
- OpenCode root files list includes 5 entries

---

### Phase 3: Verification and testing [NOT STARTED]

**Goal:** Verify the changes work correctly for both .claude and .opencode Load All operations without regressions.

**Tasks:**
- [ ] Run headless Neovim to verify sync.lua loads without errors: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"`
- [ ] Create a test script that calls `scan_all_artifacts()` with both Claude and OpenCode configs and verifies artifact counts
- [ ] Verify agents are found for OpenCode (should find 17 subagents + 1 orchestrator = 18 files)
- [ ] Verify context files are found for OpenCode (should find files from context/ subdirectories)
- [ ] Verify hooks, rules, docs, scripts, templates, systemd are found for OpenCode
- [ ] Verify .claude scanning still works identically (no regressions)
- [ ] Verify root files include the expanded list for OpenCode

**Timing:** 45 minutes

**Files to modify:**
- None (verification only)

**Verification:**
- Module loads cleanly in headless Neovim
- Both .claude and .opencode configs produce expected artifact counts
- No regressions in existing .claude Load All behavior

---

## Testing & Validation

- [ ] Headless Neovim module load test passes without errors
- [ ] `scan_all_artifacts()` with Claude config produces same results as before (regression check)
- [ ] `scan_all_artifacts()` with OpenCode config produces 300+ files across all categories
- [ ] OpenCode agents count = 18 (17 subagents + 1 orchestrator)
- [ ] OpenCode context files are found (previously 0, now 200+)
- [ ] OpenCode root files = 5 (OPENCODE.md, settings.json, .gitignore, README.md, QUICK-START.md)
- [ ] No errors in Neovim message log after Load All operation

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Modified with unconditional scanning and agents path fix
- `specs/115_investigate_leader_ao_load_all_feature_parity/summaries/implementation-summary-20260302.md` - Implementation summary

## Rollback/Contingency

The changes are confined to a single function (`scan_all_artifacts`) in one file (`sync.lua`). If any issues arise:
1. Revert the single file via `git checkout -- lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
2. The original `.claude`-only guard behavior is fully preserved in git history
3. No database or state changes are involved -- this is purely a scan configuration change
