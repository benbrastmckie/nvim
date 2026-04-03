# Research Report: Task #363

**Task**: 363 - Refactor skill-researcher for centralized status updates
**Generated**: 2026-04-03
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Replace inline status update code in skill-researcher with calls to centralized script
**Scope**: .claude/skills/skill-researcher/SKILL.md
**Affected Components**: skill-researcher
**Domain**: meta
**Language**: meta

## Task Requirements

Refactor skill-researcher's Stage 2 (preflight) and Stage 7 (postflight) to use the centralized `update-task-status.sh` script created in Task 362.

### Current State (Gaps Identified)

1. **Stage 2 (Preflight)**: Updates state.json inline with jq, updates TODO.md task entry. Does NOT update TODO.md Task Order section.
2. **Stage 7 (Postflight)**: Updates state.json inline with jq, updates TODO.md task entry. Does NOT update TODO.md Task Order section.
3. **Stage 9 (Git Commit)**: Performs its own `git add -A && git commit`. This duplicates the command-level CHECKPOINT 3: COMMIT.

### Target State

1. **Stage 2**: Replace ~15 lines of inline jq/Edit with single call to `update-task-status.sh preflight $task_number researching $session_id`
2. **Stage 7**: Replace ~15 lines of inline jq/Edit with single call to `update-task-status.sh postflight $task_number researched $session_id`
3. **Stage 9**: Evaluate whether to remove skill-level git commit (let command handle it) or keep for safety

### Specific Lines to Replace

**Stage 2 (Preflight)** - Replace:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status, last_updated: $ts, session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
Plus TODO.md Edit instructions.

**Stage 7 (Postflight)** - Replace:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status, last_updated: $ts, researched: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
Plus TODO.md Edit instructions.

## Integration Points

- **Component Type**: Skill modification
- **Affected Area**: .claude/skills/skill-researcher/
- **Action Type**: Modify existing
- **Related Files**:
  - `.claude/skills/skill-researcher/SKILL.md`
  - `.claude/scripts/update-task-status.sh` (from Task 362)
  - `.claude/commands/research.md` (verify GATE OUT still works)

## Dependencies

- Task #362: Create centralized update-task-status.sh script

## Interview Context

### Effort Assessment
- **Estimated Effort**: 1-2 hours (Medium)
- **Complexity Notes**: Straightforward replacement; main risk is ensuring artifact linking (Stage 8) still works correctly after status script handles the base status update

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 363 [focus]` with a specific focus prompt.*
