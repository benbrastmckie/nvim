# Implementation Plan: Remove check_core_purity from check-extension-docs.sh

- **Task**: 481 - Remove check_core_purity() function from check-extension-docs.sh
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_remove-core-purity.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Remove the `check_core_purity()` function and its invocation from `check-extension-docs.sh`. This function was added by task 480 to detect stale nvim/neovim references in non-nvim extension sources, but since extensions are now loaded via a picker and merged at load time, core purity checking is no longer needed. The function exists in two identical copies of the script that must both be updated.

### Research Integration

No research report. The task is well-scoped from the task description.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any roadmap item. It removes unnecessary lint infrastructure from the doc-lint script referenced in the roadmap's "CI enforcement of doc-lint" item, simplifying the script before CI integration.

## Goals & Non-Goals

**Goals**:
- Remove the `check_core_purity()` function definition (lines 192-241) from both script copies
- Remove the `check_core_purity` invocation (line 243) from both script copies
- Verify the script still runs correctly after removal

**Non-Goals**:
- Replacing core purity checking with an alternative mechanism
- Modifying any other checks in the script
- Updating task 480 artifacts (they are historical records)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script breaks after removal | M | L | Run script after edit to verify exit 0 |
| Copies diverge | L | L | Edit both files identically |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

### Phase 1: Remove check_core_purity from both script copies [COMPLETED]

**Goal**: Delete the function definition and its call from both copies of check-extension-docs.sh.

**Tasks**:
- [ ] Remove `check_core_purity()` function definition (lines 192-241) from `.claude/extensions/core/scripts/check-extension-docs.sh`
- [ ] Remove the blank comment line before the function (line 192 comment)
- [ ] Remove the `check_core_purity` invocation call (line 243) from the same file
- [ ] Apply identical changes to `.claude/scripts/check-extension-docs.sh`
- [ ] Run `bash .claude/scripts/check-extension-docs.sh --quiet` to verify the script still works
- [ ] Verify exit code is 0 (or expected non-zero if extensions have other issues)

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/check-extension-docs.sh` -- remove check_core_purity function (lines 192-243)
- `.claude/scripts/check-extension-docs.sh` -- remove check_core_purity function (lines 192-243)

**Verification**:
- Both files no longer contain `check_core_purity`
- Script runs without errors: `bash .claude/scripts/check-extension-docs.sh --quiet`
- The summary table and exit code logic still work correctly

## Testing & Validation

- [ ] `grep -c check_core_purity .claude/scripts/check-extension-docs.sh` returns 0
- [ ] `grep -c check_core_purity .claude/extensions/core/scripts/check-extension-docs.sh` returns 0
- [ ] `bash .claude/scripts/check-extension-docs.sh --quiet` runs without error
- [ ] `diff .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh` shows no differences

## Artifacts & Outputs

- Modified `.claude/extensions/core/scripts/check-extension-docs.sh`
- Modified `.claude/scripts/check-extension-docs.sh`

## Rollback/Contingency

Revert via `git checkout HEAD -- .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh`.
