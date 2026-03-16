# Supplemental Research Report: --revise Flag for /grant Command

**Task**: 216 - refactor_grant_implement_output_to_grants_dir
**Started**: 2026-03-16T12:00:00Z
**Completed**: 2026-03-16T12:45:00Z
**Effort**: Supplemental to main task
**Dependencies**: Phases 1-7 of main plan (grants/ directory structure must exist)
**Sources/Inputs**: Codebase analysis of task.md, grant.md, revise.md, state.json
**Artifacts**: This supplemental report (03_grant-revise-flag.md)
**Standards**: report-format.md

## Executive Summary

- The `--revise` flag enables creating revision tasks for existing grants in `grants/{NN}_{slug}/`
- Grant numbering should derive from directory structure (no separate state tracking needed)
- Revision tasks link back to the original grant via a `parent_grant` field
- The pattern follows `/task --recover` and `/revise` command designs
- Revision tasks use language="grant" and modify existing grant directories

## Context and Scope

This supplemental research extends task 216's plan with a `--revise` flag for the `/grant` command. After a grant is assembled via `/implement N` (as planned in the main task), users may need to revise it based on feedback. The `--revise` flag creates a new task specifically for revising an existing grant.

### Target Workflow with --revise

```
# Original grant workflow
/grant "NSF CAREER proposal"     -> Task 500, language="grant"
/research 500                    -> Research funders
/plan 500                        -> Create proposal plan
/grant 500 --draft               -> Draft narrative
/grant 500 --budget              -> Develop budget
/implement 500                   -> Assemble to grants/500_nsf_career_proposal/

# Revision workflow (after feedback)
/grant --revise 500 "Address reviewer feedback on methodology"
                                 -> Task 501, language="grant", parent_grant=500
/research 501                    -> Research specific feedback areas
/plan 501                        -> Create revision plan
/grant 501 --draft               -> Draft revised sections
/implement 501                   -> Update grants/500_nsf_career_proposal/
```

## Findings

### 1. Grant Numbering System Analysis

The plan specifies `grants/{NN}_{grant-slug}/` format for grant output directories. Questions about numbering:

**Q1: Should grant numbers be tracked separately from task numbers?**

**Analysis**: Task numbers and grant directory numbers can be unified. Each grant is created by a task, so the task number can serve as the grant identifier:

```
Task 500 creates -> grants/500_nsf_career_proposal/
Task 501 (revises 500) modifies -> grants/500_nsf_career_proposal/
```

**Recommendation**: Use task number in directory name. No separate `grants/state.json` needed.

**Q2: How should the grants/ directory be discovered?**

**Pattern**: The directory can be derived from state.json by finding the original task that created the grant:

```bash
# Find grant directory for task number
grant_num=500
slug=$(jq -r --argjson n "$grant_num" \
  '.active_projects[] | select(.project_number == $n) | .project_name' \
  specs/state.json)
grant_dir="grants/${grant_num}_${slug}"
```

For completed tasks, check `completed_projects` in archive/state.json.

### 2. --revise Flag Behavior Design

**Syntax**: `/grant --revise TASK_NUMBER "revision description"`

Where:
- `TASK_NUMBER` is the original task that created/last modified the grant
- The description explains what revisions are needed

**Implementation Steps**:

1. **Parse arguments**: Extract grant task number and revision description
2. **Validate grant exists**:
   - Check that task exists in state.json or archive
   - Verify grants/{N}_{slug}/ directory exists
3. **Create revision task**:
   - Get next_project_number from state.json
   - Language = "grant"
   - Add `parent_grant` field referencing original task
   - Add `revises_directory` field with path to grants/ directory
4. **Update state.json**: Add new task to active_projects
5. **Update TODO.md**: Add task entry with parent grant reference
6. **Git commit**: "task {NEW_N}: create revision for grant {N}"

### 3. Task-Grant Linking Design

The state.json entry for revision tasks should include:

```json
{
  "project_number": 501,
  "project_name": "revise_nsf_career_methodology",
  "status": "not_started",
  "language": "grant",
  "description": "Address reviewer feedback on methodology",
  "parent_grant": 500,
  "revises_directory": "grants/500_nsf_career_proposal",
  "created": "2026-03-16T12:00:00Z",
  "last_updated": "2026-03-16T12:00:00Z"
}
```

**New Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `parent_grant` | number | Yes (for revisions) | Task number of original grant |
| `revises_directory` | string | Yes (for revisions) | Path to grants/{N}_{slug}/ being revised |

**TODO.md Entry Format**:

```markdown
### 501. Revise NSF CAREER methodology
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: grant
- **Parent Grant**: Task #500
- **Revises**: [grants/500_nsf_career_proposal/](../../grants/500_nsf_career_proposal/)

**Description**: Address reviewer feedback on methodology
```

### 4. /implement Routing for Revision Tasks

When `/implement N` is invoked on a revision task:

1. Detect `parent_grant` field in task data
2. Use `revises_directory` as output path (instead of creating new directory)
3. Pass workflow_type=assemble with `is_revision=true` flag
4. Grant-agent reads existing grant content, applies revisions, writes updates

**Modified assemble workflow**:

For revision tasks, the grant-agent:
- Loads existing grant from `revises_directory`
- Loads revision plan from `specs/{NNN}_{SLUG}/plans/`
- Applies changes to existing narrative/budget/etc.
- Writes updated files back to same directory
- Optionally archives previous version to `grants/{N}_{slug}/revisions/v{V}/`

### 5. Comparison with Existing Patterns

**Pattern A: /task --recover (from task.md)**

- Takes task number from archive
- Moves task data between JSON files
- Moves task directory
- Updates TODO.md

**Relevance**: The `--revise` flag similarly references an existing entity but creates a NEW task rather than moving existing data.

**Pattern B: /revise (from revise.md)**

- Takes task number
- Routes by current status:
  - Planned/implementing -> Creates new plan version
  - Not started -> Updates task description
- Uses sequential versioning for plans

**Relevance**: The grant `--revise` is different - it creates a new task, not a new version of an existing artifact. However, the pattern of checking existence before proceeding is relevant.

**Key Differences**:

| Aspect | /revise N | /grant --revise N |
|--------|-----------|-------------------|
| Input | Existing task | Completed grant task |
| Output | New plan version | New task |
| Modifies | Same task's artifacts | Creates new task |
| Relationship | Version increment | Parent-child |

### 6. Grant Directory Discovery

Since grants/ directory doesn't have its own state file, discovery works by:

1. **From task number**: Look up task in state.json -> get project_name -> construct path
2. **From directory scan**: `ls grants/` -> extract task numbers from directory names
3. **Validation**: Verify directory contains expected files (narrative.md, budget.md)

**Discovery Code Pattern**:

```bash
# Given a task number, find associated grant directory
find_grant_directory() {
  local task_num="$1"

  # Check active projects
  local slug=$(jq -r --argjson n "$task_num" \
    '.active_projects[] | select(.project_number == $n) | .project_name' \
    specs/state.json 2>/dev/null)

  # If not found, check completed/archived
  if [ -z "$slug" ] || [ "$slug" = "null" ]; then
    slug=$(jq -r --argjson n "$task_num" \
      '.completed_projects[] | select(.project_number == $n) | .project_name' \
      specs/archive/state.json 2>/dev/null)
  fi

  if [ -n "$slug" ] && [ "$slug" != "null" ]; then
    local grant_dir="grants/${task_num}_${slug}"
    if [ -d "$grant_dir" ]; then
      echo "$grant_dir"
      return 0
    fi
  fi

  return 1
}
```

## Recommendations

### Recommended Design: Minimal State Extension

1. **No grants/state.json**: Use existing specs/state.json task entries
2. **Add two fields for revision tasks**: `parent_grant`, `revises_directory`
3. **Discovery via task lookup**: Grant directory derived from task number + slug
4. **Versioning optional**: Can add revisions/ subdirectory for version history

### Implementation Plan Extension

Add new phase to task 216 plan:

#### Phase 8: Add --revise flag to /grant command [NOT STARTED]

**Goal**: Enable creating revision tasks for existing grants

**Tasks**:
- [ ] Add `| --revise N "desc" | Create revision task for grant N |` to Modes table
- [ ] Add mode detection for `--revise` flag in grant.md
- [ ] Implement Revise Mode section:
  - Parse task number and description
  - Validate grant directory exists
  - Create new task with parent_grant and revises_directory fields
  - Update state.json and TODO.md
  - Git commit
- [ ] Update skill-grant to handle revision context in assemble workflow
- [ ] Update grant-agent to read existing grant content during revision assembly
- [ ] Update EXTENSION.md documentation

**Timing**: 45-60 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add Revise Mode
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Handle revision context
- `.claude/extensions/present/agents/grant-agent.md` - Revision-aware assemble
- `.claude/extensions/present/EXTENSION.md` - Document --revise flag

**Verification**:
- `/grant --revise N "desc"` creates new task with parent_grant field
- New task TODO.md entry shows "Parent Grant: Task #N"
- state.json entry includes revises_directory path

### State.json Schema Extension

Add to state-management.md or document in extension:

```json
{
  "parent_grant": 500,
  "revises_directory": "grants/500_nsf_career_proposal"
}
```

These fields are optional and only present on grant revision tasks.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Original grant task deleted/archived | Cannot find grant directory | Store revises_directory explicitly; validate at --revise time |
| Grant directory renamed/moved | Path mismatch | Use revises_directory as source of truth, not reconstructed path |
| Multiple concurrent revisions | Merge conflicts in grant files | Document that only one revision task should be active per grant |
| Revision of a revision | Confusion about parent_grant chain | Document: always reference original grant task, not intermediate revision |

## Next Steps

1. Complete Phases 1-7 of main task (grants/ directory structure exists)
2. Add Phase 8 to implementation plan
3. Implement --revise flag
4. Update documentation with revision workflow examples

## Appendix

### Grant Lifecycle Diagram

```
                  /grant "Description"
                          |
                          v
                  Task N created (language=grant)
                          |
          +---------------+---------------+
          |               |               |
     /research N    /plan N        /grant N --draft
          |               |               |
          v               v               v
     [RESEARCHED]   [PLANNED]      (drafts created)
                          |               |
                          v               v
                    /grant N --budget
                          |
                          v
                    (budgets created)
                          |
                          v
                    /implement N
                          |
                          v
                    grants/{N}_{slug}/
                          |
         +----------------+----------------+
         |                                 |
    [COMPLETED]                  /grant --revise N "desc"
                                           |
                                           v
                                   Task M created
                                   (parent_grant=N)
                                           |
                        +------------------+------------------+
                        |                  |                  |
                   /research M       /plan M         /grant M --draft
                        |                  |                  |
                        v                  v                  v
                   [RESEARCHED]      [PLANNED]        (revision drafts)
                                           |                  |
                                           v                  v
                                     /implement M
                                           |
                                           v
                                   grants/{N}_{slug}/ (updated)
                                           |
                                           v
                                      [COMPLETED]
```

### Search Queries Used

- `Read: task.md` - Analyzed --recover flag pattern
- `Read: revise.md` - Analyzed plan revision pattern
- `Read: grant.md` - Current command structure
- `Read: state.json` - Task state schema
- `Grep: parent_task` - Found /task --review uses similar linking pattern

### References

- Task creation pattern: `.claude/commands/task.md` lines 44-182
- State management schema: `.claude/rules/state-management.md`
- Plan revision command: `.claude/commands/revise.md`
- Grant command: `.claude/extensions/present/commands/grant.md`
