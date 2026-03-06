# Implementation Plan: Simplify /task Command

**Task**: OC_157 - Fix task-creation-agent not found error and simplify the /task command  
**Plan Version**: 001  
**Date**: 2026-03-06  
**Approach**: Option A - Direct execution, no delegation

---

## Overview

This plan implements the simplification of the `/task` command by removing the triple-layered delegation (command → skill → agent) and performing task creation directly. This reduces code complexity by 97% (from ~2,142 lines to ~60 lines) while maintaining identical functionality.

### Key Changes
- Remove skill-task delegation entirely
- Execute task creation directly in the command
- Eliminate intermediate CREATING status
- Remove .return-meta.json protocol overhead
- Remove marker file overhead

---

## Phase Breakdown

### Phase 1: Update task.md CREATE Mode Section

**Estimated Effort**: 30 minutes  
**Files Modified**: `.opencode/commands/task.md`  

#### Actions

1. **Rewrite CREATE mode section** (lines 23-239):
   - Replace Step 3 (Preflight) with simplified initialization
   - Remove Step 4 (Delegate to Task Agent) entirely
   - Replace Step 5 (Postflight) with direct file operations

2. **New CREATE mode structure**:
   ```markdown
   ## CREATE mode
   
   ### Step 1: Validate Input (unchanged)
   [Current lines 54-71]
   
   ### Step 2: Initialize specs/ Directory (unchanged)
   [Current lines 74-94]
   
   ### Step 3: Calculate Task Details
   - Read state.json to get next_project_number (N)
   - Generate slug from title
   - Infer language
   - Estimate effort
   - Zero-pad N to 3 digits
   - Set directory path
   
   ### Step 4: Create Task Entry (DIRECT - replaces steps 3-5)
   
   **4a. Update state.json**:
   ```bash
   jq --argjson n "$N" \
      --arg name "$project_name" \
      --arg desc "$description" \
      --arg lang "$language" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.next_project_number = ($n + 1) |
       .active_projects += [{
         "project_number": $n,
         "project_name": $name,
         "status": "not_started",
         "language": $lang,
         "description": $desc,
         "created": $ts,
         "last_updated": $ts,
         "artifacts": []
       }]' specs/state.json > specs/tmp/state.json && \
       mv specs/tmp/state.json specs/state.json
   ```
   
   **4b. Create task directory**:
   ```bash
   mkdir -p "specs/OC_${padded_num}_${project_name}"
   ```
   
   **4c. Prepend to TODO.md**:
   - Insert before `## Tasks` section:
   ```markdown
   ### OC_N. Title
   - **Effort**: X hours
   - **Status**: [NOT STARTED]
   - **Language**: general
   
   **Description**: Full description here.
   
   ---
   ```
   
   **4d. Git commit**:
   ```bash
   git add -A
   git commit -m "task N: create task entry
   
   Session: ${session_id}"
   ```
   
   **4e. Report**:
   - Show: "Created task OC_N: Title"
   - Show: Directory path
   - Show: Git commit confirmation
   ```

#### Validation
- [ ] CREATE mode section rewritten
- [ ] No references to task-creation-agent
- [ ] No CREATING status transitions
- [ ] No marker file creation
- [ ] No .return-meta.json handling
- [ ] Direct jq commands for state.json updates
- [ ] Direct Edit commands for TODO.md updates

---

### Phase 2: Update Other Task Modes

**Estimated Effort**: 15 minutes  
**Files Modified**: `.opencode/commands/task.md`  

#### Actions

1. **Review RECOVER mode** (lines 242-248):
   - Verify no dependency on skill-task
   - Current implementation is direct - no changes needed

2. **Review EXPAND mode** (lines 252-257):
   - Verify no dependency on skill-task
   - Current implementation is direct - no changes needed

3. **Review SYNC mode** (lines 261-265):
   - Verify no dependency on skill-task
   - Current implementation is direct - no changes needed

4. **Review ABANDON mode** (lines 269-292):
   - Verify no dependency on skill-task
   - Current implementation is direct - no changes needed

5. **Update Rules section** (lines 296-305):
   - Remove references to skill-task delegation
   - Remove references to preflight/postflight for CREATE mode
   - Keep rules for other modes if applicable

6. **Update Critical Notes section** (lines 309-321):
   - Remove notes about skill-task
   - Remove notes about preflight/postflight for CREATE mode
   - Keep general workflow phase information

#### Validation
- [ ] All non-CREATE modes verified to work without skill-task
- [ ] Rules section updated
- [ ] Critical Notes section updated
- [ ] No remaining references to skill-task

---

### Phase 3: Update Documentation References

**Estimated Effort**: 10 minutes  
**Files Modified**: `.opencode/commands/task.md`  

#### Actions

1. **Remove obsolete sections**:
   - Delete "CREATE Mode: Task Entry Details" section (lines 209-239)
   - This section described what the agent would do - no longer needed

2. **Update Workflow Phases table** (lines 324-333):
   - Verify it still accurately describes the workflow
   - No changes likely needed

3. **Update header comments if present**:
   - Remove any references to task-creation-agent
   - Remove any references to delegation

#### Validation
- [ ] CREATE Mode: Task Entry Details section removed
- [ ] No references to task-creation-agent remain
- [ ] Workflow documentation is accurate

---

### Phase 4: Delete skill-task Directory

**Estimated Effort**: 5 minutes  
**Files Deleted**: `.opencode/skills/skill-task/` (entire directory)  

#### Actions

1. **Verify no other dependencies**:
   ```bash
   grep -r "skill-task" .opencode/ --include="*.md"
   grep -r "task-creation-agent" .opencode/ --include="*.md"
   ```

2. **Delete directory**:
   ```bash
   rm -rf .opencode/skills/skill-task/
   ```

#### Validation
- [ ] No references to skill-task found in other files
- [ ] No references to task-creation-agent found
- [ ] Directory successfully removed

---

### Phase 5: Testing

**Estimated Effort**: 20 minutes  

#### Test Cases

1. **Basic task creation**:
   ```bash
   # Test: Create a simple task
   /task "Test task for validation"
   
   # Verify:
   # - state.json updated with new task entry
   # - TODO.md updated with new task entry
   # - Directory created at specs/OC_NNN_slug/
   # - Git commit created
   ```

2. **Task with special characters**:
   ```bash
   # Test: Task with quotes and special chars
   /task "Test task with \"quotes\" and 'apostrophes'"
   
   # Verify: Proper escaping in state.json and TODO.md
   ```

3. **Concurrent task creation**:
   ```bash
   # Test: Create two tasks in rapid succession
   /task "First concurrent task"
   /task "Second concurrent task"
   
   # Verify: Both tasks created with correct sequential numbers
   ```

4. **Other modes still work**:
   ```bash
   # Test: Recover mode
   /task --recover OC_N
   
   # Test: Expand mode
   /task --expand OC_N "additional details"
   
   # Test: Sync mode
   /task --sync
   
   # Test: Abandon mode
   /task --abandon OC_N
   ```

#### Validation Checklist
- [ ] Task creation works without errors
- [ ] state.json correctly updated
- [ ] TODO.md correctly updated
- [ ] Task directory created
- [ ] Git commit created
- [ ] Special characters handled correctly
- [ ] Concurrent creation works (sequential numbering)
- [ ] All other modes (recover, expand, sync, abandon) still work

---

### Phase 6: Final Verification and Documentation

**Estimated Effort**: 15 minutes  
**Files Modified**: `specs/state.json` (if needed)  

#### Actions

1. **Code review**:
   - Review all changes in task.md
   - Verify no syntax errors in jq commands
   - Verify no syntax errors in bash commands
   - Check for consistent formatting

2. **Update state.json if needed**:
   - If state.json tracks architecture documentation, update it to reflect:
     - Removed skill-task skill
     - Simplified /task command architecture
   - This is only if state.json contains architecture metadata

3. **Documentation updates**:
   - Update any architecture diagrams if they exist
   - Update skill inventory if maintained

4. **Git commit all changes**:
   ```bash
   git add -A
   git commit -m "task 157: simplify /task command

- Remove skill-task delegation layer
- Perform task creation directly in command
- Eliminate CREATING intermediate status
- Remove .return-meta.json protocol overhead
- Reduce code from 2,142 lines to ~60 lines (97% reduction)

Session: <session_id>"
   ```

#### Validation
- [ ] Code review completed
- [ ] All changes committed
- [ ] Documentation updated if applicable
- [ ] Task 157 marked as completed

---

## Rollback Plan

If issues are discovered during or after implementation:

### Immediate Rollback (within session)

1. **Restore task.md from git**:
   ```bash
   git checkout -- .opencode/commands/task.md
   ```

2. **Restore skill-task directory from git**:
   ```bash
   git checkout -- .opencode/skills/skill-task/
   ```

3. **Verify restoration**:
   ```bash
   ls -la .opencode/skills/skill-task/
   grep "skill-task" .opencode/commands/task.md
   ```

### Post-Commit Rollback

1. **Revert commit**:
   ```bash
   git revert HEAD
   ```

2. **Or reset to previous state**:
   ```bash
   git log --oneline -5
   git reset --hard <commit_before_changes>
   ```

### Partial Rollback (if only some changes problematic)

1. **Identify problematic changes**:
   - Review error messages
   - Check which specific operation failed

2. **Selective revert**:
   ```bash
   git diff HEAD~1 .opencode/commands/task.md
   # Manually restore specific sections
   ```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| jq syntax errors | Low | High | Test jq commands before committing; use two-phase write pattern |
| State corruption | Low | High | Backup state.json before testing; atomic jq writes |
| Concurrent task creation conflicts | Low | Medium | jq operations are atomic; sequential numbering handled by next_project_number |
| Git commit failures | Low | Low | Continue without commit; user can commit manually |
| Other modes broken | Low | Medium | Test all modes in Phase 5 |

---

## Effort Summary

| Phase | Description | Estimated Time |
|-------|-------------|----------------|
| 1 | Rewrite CREATE mode section | 30 min |
| 2 | Update other task modes | 15 min |
| 3 | Update documentation references | 10 min |
| 4 | Delete skill-task directory | 5 min |
| 5 | Testing | 20 min |
| 6 | Final verification and commit | 15 min |
| **Total** | | **95 minutes (~1.5 hours)** |

---

## Success Criteria

- [ ] task.md CREATE mode rewritten with direct execution
- [ ] skill-task directory deleted
- [ ] No references to task-creation-agent remain
- [ ] Task creation works correctly
- [ ] All other modes (recover, expand, sync, abandon) still work
- [ ] 97% code reduction achieved (~60 lines vs 2,142 lines)
- [ ] All tests pass
- [ ] Changes committed to git

---

## Notes

### Key jq Patterns for Phase 1

**Update next_project_number and add task**:
```bash
jq --argjson n "$N" \
   --arg name "$project_name" \
   --arg desc "$description" \
   --arg lang "$language" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.next_project_number = ($n + 1) |
    .active_projects += [{
      "project_number": $n,
      "project_name": $name,
      "status": "not_started",
      "language": $lang,
      "description": $desc,
      "created": $ts,
      "last_updated": $ts,
      "artifacts": []
    }]' specs/state.json > specs/tmp/state.json && \
    mv specs/tmp/state.json specs/state.json
```

### TODO.md Format Template

```markdown
### OC_N. Title Here
- **Effort**: X hours
- **Status**: [NOT STARTED]
- **Language**: general

**Description**: Full description here.

---
```

### Testing Command Template

```bash
# Quick validation test
/task "OC_157 validation test task"
# Then verify:
git show HEAD --stat
cat specs/state.json | jq '.active_projects[-1]'
grep -A 10 "OC_N" specs/TODO.md
ls -la specs/OC_NNN_*/
```

---

**Plan Author**: Implementation Planner Agent  
**Review Status**: Ready for implementation  
**Next Step**: Execute Phase 1 - Update task.md CREATE mode section
