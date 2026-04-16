# Implementation Plan: Harden Sync Protection and Clean Deprecated Index

- **Task**: 439 - Harden sync protection and clean deprecated index entries
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_sync-protection.md
- **Artifacts**: plans/01_sync-protection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the auto-seed migration bug in sync.lua where legacy `.claude/.syncprotect` entries are silently discarded when the root `.syncprotect` is created, and remove 5 deprecated entries from `index.json` that waste 2,123 lines of context budget. The auto-seed code in `load_all_globally` (lines 818-834) must merge legacy entries into the new root file rather than overwriting them with a minimal seed.

### Research Integration

Research report `01_sync-protection.md` identified the precise destruction vector: the auto-seed at lines 821-833 creates a minimal root `.syncprotect` and the subsequent re-read overwrites the previously-loaded legacy entries. The fix is to read legacy entries before seeding and incorporate them into the seed content. The report also catalogued 5 deprecated index.json entries totaling 2,123 stale context lines.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Zero stale references to removed/renamed files in `.claude/`" success metric by removing 5 deprecated index entries
- Related to "Agent System Quality" phase 1 priorities (cleanup of outdated references)

## Goals & Non-Goals

**Goals**:
- Merge legacy `.claude/.syncprotect` entries into root `.syncprotect` during auto-seed migration
- Add documentation comment to seed content clarifying self-protection status
- Remove 5 deprecated entries from `.claude/context/index.json` to recover 2,123 lines of context budget

**Non-Goals**:
- Deleting the deprecated context files themselves (they serve as redirects)
- Adding `.syncprotect` to `.sync-exclude` (belt-and-suspenders, low priority per research)
- Changing the `load_syncprotect` function itself (it already handles fallback correctly)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Legacy migration creates duplicate entries | L | L | Dedup against seed entries before writing |
| Removing index entries breaks agent context loading | L | L | Deprecated files only redirect; consolidated files already indexed |
| Auto-seed change introduces syntax error | M | L | Test with fresh target repo simulation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix auto-seed legacy migration in sync.lua [COMPLETED]

**Goal**: Merge legacy `.claude/.syncprotect` entries into the new root `.syncprotect` during auto-seed, preventing silent entry loss.

**Tasks**:
- [ ] Modify the auto-seed block in `load_all_globally` (lines ~818-834) to read legacy entries before writing the seed file
- [ ] Add legacy entry parsing: read non-comment, non-empty lines from `{project_dir}/{base_dir}/.syncprotect`
- [ ] Append migrated entries under a `# Migrated from {base_dir}/.syncprotect` comment header
- [ ] Dedup migrated entries against entries already in the seed content
- [ ] Add documentation comment to seed content: note that `.syncprotect` lives at project root and is inherently safe from sync

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Modify auto-seed block in `load_all_globally` (~lines 818-834)

**Verification**:
- Auto-seed block reads legacy file when it exists
- Migrated entries appear in new root `.syncprotect`
- Seed content includes self-protection documentation comment
- No duplicate entries in output

---

### Phase 2: Remove deprecated index.json entries [COMPLETED]

**Goal**: Remove 5 deprecated entries from `.claude/context/index.json` to recover 2,123 lines of wasted context budget.

**Tasks**:
- [ ] Remove entry for `orchestration/delegation.md` (859 lines)
- [ ] Remove entry for `orchestration/sessions.md` (166 lines)
- [ ] Remove entry for `orchestration/subagent-validation.md` (313 lines)
- [ ] Remove entry for `orchestration/validation.md` (699 lines)
- [ ] Remove entry for `workflows/status-transitions.md` (86 lines)
- [ ] Verify no remaining entries reference the removed paths

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/index.json` - Remove 5 deprecated entries

**Verification**:
- `index.json` parses as valid JSON after edits
- No entries with deprecated file paths remain
- Deprecated files themselves still exist as redirects (not deleted)

## Testing & Validation

- [ ] `index.json` is valid JSON (run `jq . .claude/context/index.json`)
- [ ] sync.lua has no Lua syntax errors (load in Neovim, check for parse errors)
- [ ] Auto-seed block includes legacy migration logic with dedup
- [ ] Deprecated entries no longer appear in context discovery queries

## Artifacts & Outputs

- `plans/01_sync-protection.md` (this plan)
- `summaries/01_sync-protection-summary.md` (post-implementation)
- Modified: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Modified: `.claude/context/index.json`

## Rollback/Contingency

- `git revert` the implementation commit to restore both files to their pre-change state
- The deprecated index entries and original auto-seed logic are preserved in git history
