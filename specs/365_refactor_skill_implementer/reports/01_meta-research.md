# Research Report: Task #365

**Task**: 365 - Refactor skill-implementer for centralized status updates
**Generated**: 2026-04-03
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Replace inline status update code in skill-implementer with calls to centralized script
**Scope**: .claude/skills/skill-implementer/SKILL.md
**Affected Components**: skill-implementer
**Domain**: meta
**Language**: meta

## Task Requirements

Refactor skill-implementer's Stage 2 (preflight) and Stage 7 (postflight) to use the centralized `update-task-status.sh` script created in Task 362.

### Current State

skill-implementer is the MOST COMPLETE of the three skills regarding status updates:

1. **Stage 2 (Preflight)**: Updates state.json, TODO.md task entry, TODO.md Task Order section, AND plan file status. This is the gold standard that the other skills should match.
2. **Stage 7 (Postflight)**: Updates state.json with completion data (completion_summary, claudemd_suggestions, roadmap_items), TODO.md task entry, TODO.md Task Order section, plan file status, and Recommended Order section.
3. **Stage 9 (Git Commit)**: Performs `git add -A && git commit`.

### Target State

1. **Stage 2**: Replace inline code with `update-task-status.sh preflight $task_number implementing $session_id`
2. **Stage 7**: Replace inline code with `update-task-status.sh postflight $task_number completed $session_id` PLUS separate completion_data handling
3. **Stage 9**: Evaluate removing skill-level git commit

### Special Considerations

- The postflight for implement has MORE fields than research/plan:
  - `completion_summary` (always)
  - `claudemd_suggestions` (meta tasks only)
  - `roadmap_items` (non-meta tasks, optional)
  - `resume_phase` (for partial status)
- The centralized script may need an `--extra-fields` mechanism or the completion_data should remain inline
- The `update-recommended-order.sh` call should be preserved
- Partial status handling (keeping "implementing" and setting resume_phase) needs special logic

## Integration Points

- **Component Type**: Skill modification
- **Affected Area**: .claude/skills/skill-implementer/
- **Action Type**: Modify existing
- **Related Files**:
  - `.claude/skills/skill-implementer/SKILL.md`
  - `.claude/scripts/update-task-status.sh` (from Task 362)
  - `.claude/scripts/update-plan-status.sh` (existing)
  - `.claude/scripts/update-recommended-order.sh` (existing)
  - `.claude/commands/implement.md` (verify defensive GATE OUT still works)

## Dependencies

- Task #362: Create centralized update-task-status.sh script

## Interview Context

### Effort Assessment
- **Estimated Effort**: 1-2 hours (Medium)
- **Complexity Notes**: More complex than 363/364 due to completion_data fields and partial status handling. The centralized script must accommodate these extra fields or the skill must supplement the script call with additional inline updates.

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 365 [focus]` with a specific focus prompt.*
