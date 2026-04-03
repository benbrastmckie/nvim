# Implementation Plan: Centralized Status Update Script

- **Task**: 362 - Create centralized update-task-status.sh script
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_meta-research.md
- **Artifacts**: plans/01_status-script-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `.claude/scripts/update-task-status.sh` to centralize the duplicated status update logic currently spread across skill-researcher, skill-planner, and skill-implementer. The script accepts an operation type (preflight/postflight), task number, target status, and session ID, then atomically updates state.json first and TODO.md second (both the task entry and Task Order sections). This eliminates approximately 30 lines of duplicated jq/Edit code per skill and fixes the inconsistency where only skill-implementer updates the Task Order section.

### Research Integration

Research report `01_meta-research.md` confirmed:
- Three workflow skills duplicate the same jq patterns for state.json updates
- Only skill-implementer updates the TODO.md Task Order section; researcher and planner skip it
- The existing `update-plan-status.sh` script handles plan file status and can be called as a sub-step
- The two-step jq pattern is required to avoid Issue #1132 escaping bugs
- `specs/tmp/` must be used for atomic file operations (write-then-mv pattern)

## Goals & Non-Goals

**Goals**:
- Single script that handles all status updates across state.json and TODO.md
- Fix missing Task Order updates in researcher and planner workflows
- Provide a clean API that skills can call with a single bash invocation
- Maintain atomicity guarantees (state.json first, TODO.md second)
- Handle idempotent calls safely (no error if already at target status)

**Non-Goals**:
- Replacing skill-status-sync (standalone manual tool remains separate)
- Handling artifact linking (stays in skill postflight logic)
- Handling completion_summary, claudemd_suggestions, or roadmap_items fields (those are skill-implementer-specific and will remain inline; task 365 addresses this)
- Modifying the existing `update-plan-status.sh` script

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq escaping (Issue #1132) breaks state.json updates | H | M | Use two-step jq pattern; avoid `!=` operator; test with edge cases |
| sed regex fails on unusual task titles in TODO.md | M | L | Use anchored patterns matching task number, not title text |
| Race condition if two agents update simultaneously | M | L | Use atomic write-then-mv; tasks are single-threaded in practice |
| Task Order section format changes break grep patterns | M | L | Pattern matches `**{N}**` which is stable; verify in tests |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core Script Skeleton and state.json Updates [COMPLETED]

**Goal**: Create the script file with argument parsing, validation, status mapping, and state.json update logic.

**Tasks**:
- [ ] Create `.claude/scripts/update-task-status.sh` with shebang, `set -euo pipefail`, and usage documentation
- [ ] Implement argument parsing: `$1` = operation (preflight|postflight), `$2` = task_number, `$3` = target_status, `$4` = session_id
- [ ] Implement status mapping function that converts target_status to both state.json and TODO.md formats:
  - preflight:research -> state:researching, todo:[RESEARCHING]
  - preflight:plan -> state:planning, todo:[PLANNING]
  - preflight:implement -> state:implementing, todo:[IMPLEMENTING]
  - postflight:research -> state:researched, todo:[RESEARCHED]
  - postflight:plan -> state:planned, todo:[PLANNED]
  - postflight:implement -> state:completed, todo:[COMPLETED]
- [ ] Validate task exists in state.json using jq
- [ ] Implement state.json update: status field and last_updated timestamp using atomic write-to-tmp-then-mv pattern via `specs/tmp/`
- [ ] Make script executable (`chmod +x`)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Create new file

**Verification**:
- Script accepts all four arguments and validates them
- state.json status field updates correctly for a test task
- Atomic mv pattern leaves no temporary files on success

---

### Phase 2: TODO.md Task Entry Updates [COMPLETED]

**Goal**: Add logic to update the status marker in the task entry section (`## Tasks`) of TODO.md.

**Tasks**:
- [ ] Find the task entry line using pattern: `^### {task_number}\.` in TODO.md
- [ ] Extract current status marker from the `- **Status**: [...]` line within the task entry
- [ ] Replace the status marker with the new TODO.md-format status using sed
- [ ] Handle edge case where Status line may not exist (log warning, skip)
- [ ] Ensure only the specific task's Status line is updated (not other tasks)

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add TODO.md task entry update function

**Verification**:
- Task entry status marker changes from old to new value
- Other task entries in TODO.md remain unchanged
- Script handles missing Status line gracefully

---

### Phase 3: TODO.md Task Order Section Updates [COMPLETED]

**Goal**: Add logic to update the status marker in the Task Order section of TODO.md.

**Tasks**:
- [ ] Find the Task Order section (between `## Task Order` and next `## ` heading)
- [ ] Locate the line matching `**{task_number}**` with a status marker pattern `\[...\]`
- [ ] Replace the status marker on that line with the new TODO.md-format status using sed
- [ ] Handle edge case where task is not listed in Task Order section (log warning, skip)

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add Task Order section update function

**Verification**:
- Task Order line status marker updates correctly
- Other entries in Task Order section remain unchanged
- Script does not error if task is absent from Task Order

---

### Phase 4: Plan File Status Integration [COMPLETED]

**Goal**: Optionally update the plan file status by calling the existing `update-plan-status.sh`.

**Tasks**:
- [ ] Add optional `--plan-status` flag or detect when operation is `preflight:implement` or `postflight:implement`
- [ ] Look up project_name from state.json for the given task_number (needed by update-plan-status.sh)
- [ ] Call `.claude/scripts/update-plan-status.sh` with appropriate arguments when applicable
- [ ] Map operation to plan status: preflight:implement -> IMPLEMENTING, postflight:implement -> COMPLETED, postflight with partial -> PARTIAL
- [ ] Handle case where plan file does not exist (non-fatal, log and continue)

**Timing**: 20 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add plan file integration

**Verification**:
- Plan file status updates when implementing
- No error when plan file does not exist
- Non-implement operations skip plan file update

---

### Phase 5: Error Handling, Idempotency, and Edge Cases [COMPLETED]

**Goal**: Harden the script with proper error handling, idempotency checks, and edge case coverage.

**Tasks**:
- [ ] Add idempotency check: if state.json already at target status, exit 0 silently
- [ ] Add idempotency for TODO.md: if marker already matches, skip sed operations
- [ ] Ensure `specs/tmp/` directory exists before write operations (`mkdir -p specs/tmp`)
- [ ] Add error output to stderr for all failure paths
- [ ] Add exit codes: 0 = success/no-op, 1 = validation error, 2 = state.json update failed, 3 = TODO.md update failed
- [ ] Handle missing TODO.md gracefully (error code 3, but state.json still updated)
- [ ] Add `--dry-run` flag that prints what would change without modifying files
- [ ] Clean up any temporary files in error paths (trap cleanup)

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add error handling throughout

**Verification**:
- Calling with already-current status exits 0 with no changes
- Invalid arguments produce clear error messages on stderr
- Temporary files are cleaned up even on failure
- `--dry-run` shows planned changes without writing

---

### Phase 6: Verification Testing [NOT STARTED]

**Goal**: Manually verify the script works correctly across all status transitions and edge cases.

**Tasks**:
- [ ] Test preflight:research transition (not_started -> researching)
- [ ] Test postflight:research transition (researching -> researched)
- [ ] Test preflight:plan transition (researched -> planning)
- [ ] Test postflight:plan transition (planning -> planned)
- [ ] Test preflight:implement transition (planned -> implementing)
- [ ] Test postflight:implement transition (implementing -> completed, with plan file)
- [ ] Test idempotency (call same transition twice, verify no error and no double-write)
- [ ] Test with task not in Task Order section
- [ ] Test with task that has no plan file
- [ ] Test `--dry-run` output for each operation
- [ ] Verify state.json and TODO.md remain in sync after all tests

**Timing**: 25 minutes

**Depends on**: 5

**Files to modify**:
- None (verification only, may create temporary test state)

**Verification**:
- All status transitions produce correct results in both files
- No regressions in existing functionality
- Script is ready for integration by tasks 363-365

## Testing & Validation

- [ ] state.json updates atomically (no partial writes) for each operation type
- [ ] TODO.md task entry status marker updates correctly for all 6 transitions
- [ ] TODO.md Task Order section status marker updates correctly for all 6 transitions
- [ ] Plan file status updates via update-plan-status.sh for implement operations
- [ ] Idempotent calls produce no errors and no file changes
- [ ] Invalid arguments produce clear error messages and non-zero exit codes
- [ ] Script handles missing Task Order entries without errors
- [ ] Atomic mv pattern prevents data loss on interrupted writes

## Artifacts & Outputs

- `.claude/scripts/update-task-status.sh` - The centralized status update script
- `specs/362_centralized_status_script/plans/01_status-script-plan.md` - This plan file
- `specs/362_centralized_status_script/summaries/01_status-script-summary.md` - Execution summary (post-implementation)

## Rollback/Contingency

The script is a new file with no existing dependencies. Rollback is straightforward:
1. Delete `.claude/scripts/update-task-status.sh`
2. Continue using inline status update code in each skill (current behavior)
3. Tasks 363-365 (skill refactoring) depend on this script; if rolled back, those tasks would need to be abandoned or redesigned

No existing functionality is modified by this task; all changes are additive.
