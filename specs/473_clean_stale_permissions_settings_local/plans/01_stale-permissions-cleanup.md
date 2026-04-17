# Implementation Plan: Clean Stale Permissions in settings.local.json

- **Task**: 473 - Clean stale permissions in settings.local.json
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/473_clean_stale_permissions_settings_local/reports/01_stale-permissions-audit.md
- **Artifacts**: plans/01_stale-permissions-cleanup.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

The `.claude/settings.local.json` file has accumulated 52 permission entries in its `permissions.allow` array, of which 43 are stale operational artifacts from past agent sessions. These include completed `mv` commands, archived task directory references, shell loop fragments, and variable assignments that serve no ongoing purpose. This plan removes all stale entries, retaining 7 useful entries plus 2 MCP tool permissions, reducing the array to approximately 9 entries. Done when the file contains only active, functional permission entries and validates as correct JSON.

### Research Integration

The research report (01_stale-permissions-audit.md) categorized all 52 entries into 5 groups:
- **Category 1**: 16 file move commands with non-existent source paths (all stale)
- **Category 2**: 5 archived/completed task references (all stale)
- **Category 3**: 12 shell loop and variable constructs (all stale, non-functional as standalone)
- **Category 4**: 5 one-off utility commands (all stale)
- **Category 5**: 4 python JSON validation commands (borderline, subsumed by `python3:*` wildcard)
- **Retain**: 7 entries providing ongoing utility (echo, check-extension-docs.sh variants, python3 wildcard, broad read access, MCP permissions)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Advances roadmap item: "Zero stale references to removed/renamed files in `.claude/`" (Success Metrics).

## Goals & Non-Goals

**Goals**:
- Remove all 45 stale permission entries (Categories 1-5) from `permissions.allow`
- Retain the 7 useful entries identified in research
- Ensure the resulting file is valid JSON
- Keep the file auditable by maintaining only functional entries

**Non-Goals**:
- Consolidating the three `check-extension-docs.sh` entries into a wildcard (deferred)
- Modifying the `permissions.deny` array or any other settings
- Adding new permission entries

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing a permission needed by an active workflow | L | L | All entries verified against filesystem; Claude Code re-prompts if a removed permission is needed again |
| JSON syntax error after editing | M | L | Validate with `python3 -c "import json; json.load(open(...))"` after edit |
| Removing MCP permissions accidentally | M | L | Explicitly enumerate retained entries from research report |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace Stale Permissions Array [COMPLETED]

**Goal**: Remove all 45 stale entries and retain only the 7 useful entries in `permissions.allow`.

**Tasks**:
- [ ] Read current `.claude/settings.local.json` to get exact content
- [ ] Replace the `permissions.allow` array with the clean version containing only retained entries:
  - `Bash(echo:*)`
  - `Bash(bash .claude/scripts/check-extension-docs.sh)`
  - `Bash(bash .claude/scripts/check-extension-docs.sh --quiet)`
  - `Bash(bash /home/benjamin/.config/nvim/.claude/scripts/check-extension-docs.sh)`
  - `Bash(python3:*)`
  - `Read(//home/benjamin/.config/nvim/**)`
  - `mcp__nixos__nix`
  - `mcp__nixos__nix_versions`
- [ ] Write the updated file

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/settings.local.json` - Replace `permissions.allow` array contents

**Verification**:
- File is valid JSON (parse with python3)
- Array contains exactly 8 entries
- No stale entries remain

---

### Phase 2: Validate and Verify [COMPLETED]

**Goal**: Confirm the cleanup is correct and the file functions properly.

**Tasks**:
- [ ] Validate JSON syntax with `python3 -c "import json; json.load(open('.claude/settings.local.json'))"`
- [ ] Count entries in the permissions array to confirm exactly 8
- [ ] Verify no stale category entries remain (spot-check for `mv`, `for f:`, `done`, `ZED_SRC`, `NVM_DST`)
- [ ] Confirm the file structure is otherwise unchanged (deny array, other settings intact)

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None (read-only verification)

**Verification**:
- JSON parses without error
- Entry count matches expected (8)
- No stale patterns found in the array

## Testing & Validation

- [ ] `python3 -c "import json; json.load(open('.claude/settings.local.json'))"` exits 0
- [ ] `jq '.permissions.allow | length' .claude/settings.local.json` returns 8
- [ ] `jq '.permissions.allow[]' .claude/settings.local.json` shows only retained entries
- [ ] No references to `specs/4` task directories, `mv .claude/context/project/`, `ZED_SRC`, `for f:`, or `done` in the array

## Artifacts & Outputs

- `.claude/settings.local.json` - Cleaned permissions file (8 entries, down from 52)
- `specs/473_clean_stale_permissions_settings_local/plans/01_stale-permissions-cleanup.md` - This plan
- `specs/473_clean_stale_permissions_settings_local/summaries/01_stale-permissions-cleanup-summary.md` - Execution summary

## Rollback/Contingency

Git history preserves the original file. To revert: `git checkout HEAD~1 -- .claude/settings.local.json`. If a specific removed permission is needed again, Claude Code will automatically prompt for re-approval on next use -- no manual intervention required.
