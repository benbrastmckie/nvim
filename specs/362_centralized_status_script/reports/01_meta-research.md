# Research Report: Task #362

**Task**: 362 - Create centralized update-task-status.sh script
**Generated**: 2026-04-03
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Eliminate duplicated status update logic across workflow skills by creating a single shell script
**Scope**: .claude/scripts/, skill infrastructure
**Affected Components**: skill-researcher, skill-planner, skill-implementer, skill-status-sync
**Domain**: meta
**Language**: meta

## Task Requirements

Create `.claude/scripts/update-task-status.sh` -- a centralized shell script that atomically updates task status across all three locations:

1. **state.json** - Update status field, timestamps, session_id
2. **TODO.md task entry** - Update `- **Status**: [STATUS]` line
3. **TODO.md Task Order section** - Update `**{N}** [STATUS]` line
4. **Plan file** (optional) - Update plan Status field when applicable

### Script API

```bash
# Preflight: set in-progress status
.claude/scripts/update-task-status.sh preflight <task_number> <target_status> <session_id>

# Postflight: set final status
.claude/scripts/update-task-status.sh postflight <task_number> <target_status> <session_id>
```

### Status Mapping (from skill-status-sync)

| Operation | state.json | TODO.md |
|-----------|-----------|---------|
| preflight:research | researching | [RESEARCHING] |
| preflight:plan | planning | [PLANNING] |
| preflight:implement | implementing | [IMPLEMENTING] |
| postflight:research | researched | [RESEARCHED] |
| postflight:plan | planned | [PLANNED] |
| postflight:implement | completed | [COMPLETED] |

### Key Requirements

- Must update state.json FIRST (machine state), then TODO.md (user-facing) per state-management.md rules
- Must use two-step jq pattern to avoid Issue #1132 escaping bug
- Must handle the Task Order section in TODO.md (currently missing from researcher and planner)
- Must be idempotent (safe to call multiple times)
- Must handle plan file status updates via existing `update-plan-status.sh` when applicable
- Must use `specs/tmp/` for atomic file operations (mv pattern)

## Integration Points

- **Component Type**: Script (.claude/scripts/)
- **Affected Area**: All workflow skills, all workflow commands
- **Action Type**: Create new
- **Related Files**:
  - `.claude/scripts/update-plan-status.sh` (existing, for plan file updates)
  - `.claude/skills/skill-status-sync/SKILL.md` (reference implementation for jq patterns)
  - `.claude/rules/state-management.md` (canonical rules)

## Dependencies

None - this task can be started independently.

## Interview Context

### Key Findings from Infrastructure Analysis

1. skill-researcher, skill-planner, and skill-implementer each have ~30 lines of duplicated jq/Edit code for preflight and postflight status updates
2. Only skill-implementer updates the TODO.md Task Order section; researcher and planner skip it
3. The existing skill-status-sync skill is explicitly marked "standalone use only" and cannot be used by workflow skills
4. The `update-plan-status.sh` script already exists for plan file status but is only called by skill-implementer
5. The state-management.md rule requires state.json update BEFORE TODO.md update (two-phase pattern)

### Design Considerations

- Script should accept operation type (preflight/postflight), task number, target status, and session_id
- Script should be sourced or called as a function from within skill execution
- Script should handle both the task entry and Task Order section in TODO.md
- Script should optionally call update-plan-status.sh for implement operations
- Error handling: if state.json update succeeds but TODO.md fails, log error but don't rollback state.json

### Effort Assessment
- **Estimated Effort**: 2-3 hours (Medium)
- **Complexity Notes**: The jq patterns are well-established; main work is consolidation and testing

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 362 [focus]` with a specific focus prompt.*
