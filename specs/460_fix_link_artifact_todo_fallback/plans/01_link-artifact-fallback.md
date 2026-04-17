# Implementation Plan: Fix link-artifact-todo.sh Fallback Chain

- **Task**: 460 - fix_link_artifact_todo_fallback
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/460_fix_link_artifact_todo_fallback/reports/01_link-artifact-fallback.md
- **Artifacts**: plans/01_link-artifact-fallback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

The `link-artifact-todo.sh` script fails when `/research` postflight tries to insert a Research link using `next_field="**Plan**"` on tasks that have never been planned (no `**Plan**` line exists in TODO.md). The error message already mentions `**Description**` as a fallback but the code never searches for it. The fix adds a fallback chain in two code locations (Case 1 and Case 3) so that when the primary `next_field` is not found, the script tries `**Description**` before exiting with an error. The same fix must be applied to the Zed copy.

### Research Integration

Research identified the exact bug locations (Case 1 at lines 112-122, Case 3 at lines 163-169), confirmed only `/research` is affected (passing `next_field="**Plan**"`), and provided tested code snippets for both fallback insertions. The Zed copy at `~/.config/zed/.claude/scripts/link-artifact-todo.sh` has the identical bug.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add a `**Description**` fallback search in Case 1 (no existing field line) when `next_field` is not found
- Add a `**Description**` fallback search in Case 3 (field exists but empty) when `next_field` is not found
- Apply the identical fix to the Zed copy
- Validate the fix with a dry-run on a task lacking a `**Plan**` line

**Non-Goals**:
- Changing the caller interface (skill postflight scripts)
- Modifying `/plan` or `/implement` behavior (they already use `**Description**`)
- Adding additional fallback fields beyond `**Description**`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fallback matches wrong `**Description**` in task body text | L | L | Search uses dash-prefixed `- **Description**:` pattern first, scoped to task entry block |
| Neither `**Plan**` nor `**Description**` exists in entry | L | L | Existing error exit (exit 3) still fires; linking errors are non-blocking in callers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Fallback Chain to Both Cases [NOT STARTED]

**Goal**: Insert `**Description**` fallback search logic in Case 1 and Case 3 of `link-artifact-todo.sh`, and apply the same changes to the Zed copy.

**Tasks**:
- [ ] In Case 1 (after line 117, before the error exit on line 119): add a conditional block that searches for `- **Description**:` then bare `**Description**:` when `next_field` is not `**Description**` and the primary search failed
- [ ] In Case 3 (after line 165, before the inner error exit): add an equivalent conditional block for `next_field_line_abs`
- [ ] Copy the identical changes to `~/.config/zed/.claude/scripts/link-artifact-todo.sh`

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/link-artifact-todo.sh` -- add fallback blocks in Case 1 and Case 3
- `~/.config/zed/.claude/scripts/link-artifact-todo.sh` -- identical changes

**Verification**:
- Script parses without bash syntax errors (`bash -n`)
- Dry-run on a task with no `**Plan**` line succeeds instead of exiting with code 3

---

### Phase 2: Validation [NOT STARTED]

**Goal**: Confirm the fix works end-to-end and does not regress existing behavior.

**Tasks**:
- [ ] Run dry-run test: `bash .claude/scripts/link-artifact-todo.sh <task_number> '**Research**' '**Plan**' 'specs/NNN_slug/reports/01_test.md' --dry-run` on a task without a Plan line -- should report Case 1 insertion before `**Description**`
- [ ] Run dry-run test on a task that HAS a `**Plan**` line -- should still use `**Plan**` as anchor (no fallback triggered)
- [ ] Verify both nvim and Zed copies are identical with `diff`

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None (validation only)

**Verification**:
- Dry-run exits 0 on tasks without `**Plan**` line
- Dry-run exits 0 on tasks with `**Plan**` line (existing behavior preserved)
- `diff` between nvim and Zed copies shows no differences

## Testing & Validation

- [ ] `bash -n .claude/scripts/link-artifact-todo.sh` passes (no syntax errors)
- [ ] Dry-run with `next_field="**Plan**"` on a task without Plan line exits 0
- [ ] Dry-run with `next_field="**Plan**"` on a task with Plan line exits 0 (no regression)
- [ ] Dry-run with `next_field="**Description**"` on any task exits 0 (no regression for /plan, /implement)
- [ ] `diff` between nvim and Zed copies shows identical content

## Artifacts & Outputs

- `.claude/scripts/link-artifact-todo.sh` -- updated script with fallback chain
- `~/.config/zed/.claude/scripts/link-artifact-todo.sh` -- identical updated script
- `specs/460_fix_link_artifact_todo_fallback/plans/01_link-artifact-fallback.md` -- this plan
- `specs/460_fix_link_artifact_todo_fallback/summaries/01_link-artifact-fallback-summary.md` -- execution summary (created by /implement)

## Rollback/Contingency

Both scripts are tracked in git. Revert with `git checkout HEAD -- .claude/scripts/link-artifact-todo.sh` if the fix introduces regressions. The Zed copy can be restored from its own git history. Since linking errors are non-blocking in caller skills, a broken script does not prevent research/plan/implement from completing.
