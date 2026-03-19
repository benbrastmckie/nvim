# Implementation Plan: Task #243

**Date**: 2026-03-19
**Feature**: Create Recommended Order helper utility script
**Status**: [NOT STARTED]
**Estimated Hours**: 2-3 hours
**Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
**Research Reports**: [01_recommended-order-research.md](../reports/01_recommended-order-research.md)

## Overview

This task creates a centralized utility script `.claude/scripts/update-recommended-order.sh` that provides three functions for maintaining the "## Recommended Order" section in TODO.md. The script will handle adding tasks (with dependency-aware positioning), removing tasks, and regenerating the entire section from the state.json dependency graph using topological sort. Additionally, the Recommended Order section format will be documented in state-management.md.

## Goals and Non-Goals

**Goals**:
1. Create `update-recommended-order.sh` with three functions: `add_to_recommended_order`, `remove_from_recommended_order`, `refresh_recommended_order`
2. Implement topological sort (Kahn's algorithm) for ordering tasks by dependencies
3. Document the Recommended Order section format in state-management.md
4. Ensure graceful handling when the section does not exist

**Non-Goals**:
- Integrating the utility into workflow commands (that is task #244)
- Modifying the existing TODO.md section format (use the established format from research)
- Adding manual override positions (keeping scope minimal per Task Minimization Principle)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Circular dependencies break topological sort | Medium | Low | Detect cycles and report error; skip affected tasks |
| TODO.md section not found | Low | Medium | Graceful no-op with warning message |
| Race conditions on TODO.md writes | Low | Low | Use atomic sed operations; rely on single-process model |

## Implementation Phases

### Phase 1: Create Script Skeleton and remove_from_recommended_order [NOT STARTED]

**Estimated effort**: 0.5 hours

**Objectives**:
1. Create the script file with shebang, usage docs, and `set -euo pipefail`
2. Implement `remove_from_recommended_order TASK_NUM` function
3. Add helper function to locate TODO.md

**Files to modify**:
- `.claude/scripts/update-recommended-order.sh` - New file with skeleton and remove function

**Steps**:
1. Create script with header comments explaining usage
2. Add `TODO_FILE` variable pointing to `specs/TODO.md`
3. Implement `remove_from_recommended_order`:
   - Find line matching `^\d+\. \*\*{TASK_NUM}\*\*`
   - Delete the line using sed
   - Renumber remaining entries (1., 2., 3., ...)
4. Add main entry point that dispatches based on first argument (remove/add/refresh)

**Verification**:
- Script exists and is executable
- Running `update-recommended-order.sh remove 243` removes entry for task 243
- Remaining entries are renumbered correctly
- Running on non-existent task is a no-op (no error)

---

### Phase 2: Implement refresh_recommended_order with Topological Sort [NOT STARTED]

**Estimated effort**: 1 hour

**Objectives**:
1. Implement topological sort using Kahn's algorithm
2. Build dependency graph from state.json active_projects
3. Generate Recommended Order section entries in sorted order
4. Replace existing section content (or create section if missing)

**Files to modify**:
- `.claude/scripts/update-recommended-order.sh` - Add refresh function and topological sort

**Steps**:
1. Add `refresh_recommended_order` function:
   - Read state.json using jq
   - Extract non-completed tasks with their dependencies
   - Build adjacency list for dependency graph
2. Implement Kahn's algorithm in bash:
   - Initialize in-degree counts for each task
   - Initialize queue with tasks having in-degree 0
   - Process queue: emit task, decrement in-degree of dependents
   - Detect cycles (remaining tasks with non-zero in-degree)
3. Generate section entries using format: `{N}. **{TASK_NUM}** -> {action_hint} ({dependency_notes})`
   - Action hint derived from status: not_started -> "research", researched -> "plan", planned -> "implement"
   - Dependency notes: "unblocks X, Y" for tasks depending on current task
4. Replace section between `## Recommended Order` and next `##` header (or EOF)
5. Handle missing section by appending after `## Tasks` section

**Verification**:
- Running `update-recommended-order.sh refresh` regenerates section
- Tasks with no dependencies appear before tasks that depend on them
- Circular dependencies produce warning but don't crash
- Section format matches research specification

---

### Phase 3: Implement add_to_recommended_order with Dependency Position [NOT STARTED]

**Estimated effort**: 0.5 hours

**Objectives**:
1. Implement `add_to_recommended_order TASK_NUM` function
2. Insert task at correct position based on its dependencies
3. Handle edge cases (no dependencies, all dependencies already present)

**Files to modify**:
- `.claude/scripts/update-recommended-order.sh` - Add add function

**Steps**:
1. Add `add_to_recommended_order` function:
   - Look up task's dependencies from state.json
   - Find latest position of any dependency in current Recommended Order
   - Insert new entry after that position (or at end if no dependencies)
2. Generate entry format: `{position}. **{TASK_NUM}** -> {action_hint} ({dependency_notes})`
3. Renumber subsequent entries
4. Handle missing section: create section if it doesn't exist

**Verification**:
- Adding task with dependencies inserts after those dependencies
- Adding task without dependencies appends to end
- Entry format matches specification
- Subsequent entries are renumbered correctly

---

### Phase 4: Document Recommended Order Section in state-management.md [NOT STARTED]

**Estimated effort**: 0.5 hours

**Objectives**:
1. Add new section documenting Recommended Order format
2. Document integration points for workflow commands
3. Include examples of common operations

**Files to modify**:
- `.claude/rules/state-management.md` - Add Recommended Order section documentation

**Steps**:
1. Add `## Recommended Order Section` after existing sections (before Error Handling)
2. Document section format:
   ```markdown
   ## Recommended Order

   1. **995** -> plan + implement (unblocks 988, 989, 997)
   2. **996** -> soundness wiring (independent, bounded)
   ```
3. Document field meanings:
   - Position number (auto-managed, 1-indexed)
   - Bold task number
   - Arrow separator
   - Action hint (research/plan/implement based on status)
   - Parenthetical notes (dependency relationships)
4. Document utility script usage:
   - `update-recommended-order.sh add TASK_NUM`
   - `update-recommended-order.sh remove TASK_NUM`
   - `update-recommended-order.sh refresh`
5. Document integration points: /task (add), skill-implementer (remove), skill-spawn (refresh), skill-todo (remove)

**Verification**:
- state-management.md contains Recommended Order section
- Format documentation matches actual script behavior
- Integration points are clearly documented

---

### Phase 5: Testing and Edge Cases [NOT STARTED]

**Estimated effort**: 0.5 hours

**Objectives**:
1. Test all three functions with various scenarios
2. Verify graceful handling of edge cases
3. Ensure script is idempotent where appropriate

**Files to modify**:
- No new files; validation of existing script

**Steps**:
1. Test `refresh` with:
   - Empty active_projects
   - Tasks with no dependencies
   - Tasks with linear dependency chain
   - Tasks with diamond dependency pattern
   - Circular dependency detection
2. Test `add` with:
   - Task that depends on tasks already in section
   - Task that depends on tasks not in section
   - Task with no dependencies
   - Duplicate add (should be idempotent)
3. Test `remove` with:
   - Task that exists in section
   - Task that doesn't exist (no-op)
   - First/last/middle positions
4. Test edge cases:
   - Missing ## Recommended Order section
   - Empty ## Recommended Order section
   - Malformed entries in section

**Verification**:
- All test scenarios pass
- No errors on edge cases
- Idempotent operations remain idempotent
- Script returns appropriate exit codes

## Dependencies

- None (this is a standalone utility script)

## Testing and Validation

- [ ] Script creates valid Recommended Order entries
- [ ] Topological sort correctly orders tasks by dependencies
- [ ] Circular dependencies are detected and handled gracefully
- [ ] Missing section is handled (created or skipped based on operation)
- [ ] Renumbering works correctly after add/remove
- [ ] state-management.md documentation is accurate

## Artifacts and Outputs

- `.claude/scripts/update-recommended-order.sh` - New utility script (~150-200 lines)
- `.claude/rules/state-management.md` - Updated with Recommended Order documentation

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/scripts/update-recommended-order.sh`
2. Revert changes to state-management.md using `git checkout .claude/rules/state-management.md`
3. Task #244 (integration) should be blocked until this task succeeds
