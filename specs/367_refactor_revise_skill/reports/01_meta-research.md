# Research Report: Task #367

**Task**: 367 - Refactor /revise to use skill delegation pattern
**Generated**: 2026-04-03
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Refactor /revise command to follow the same skill delegation pattern as /research, /plan, /implement
**Scope**: .claude/commands/revise.md, new skill-reviser
**Affected Components**: /revise command, new skill
**Domain**: meta
**Language**: meta

## Task Requirements

The /revise command currently handles everything inline -- it does its own work (reading plans, creating revised plans, updating state) without delegating to a skill or agent. This breaks the pattern established by /research, /plan, and /implement.

### Current /revise Architecture

```
/revise N
  -> GATE IN (validate, route by status)
  -> Stage 2A (Plan Revision - does ALL work inline)
     - Loads plan, analyzes changes, creates revised plan
     - Updates state.json inline with jq
     - Updates TODO.md inline with Edit
  -> Stage 2B (Description Update - alternative path)
  -> GATE OUT (verify)
  -> COMMIT
```

### Target Architecture

```
/revise N
  -> GATE IN (validate, route by status)
  -> STAGE 1.5: PARSE FLAGS
  -> STAGE 2: DELEGATE to skill-reviser
     - skill-reviser handles:
       - Preflight: update-task-status.sh preflight (if applicable)
       - Create postflight marker
       - Invoke planner-agent (or work inline for description updates)
       - Postflight: update-task-status.sh postflight
       - Artifact linking
       - Cleanup
  -> GATE OUT (verify with defensive corrections)
  -> COMMIT
```

### Design Decisions

1. **Plan Revision (Stage 2A)**: Should delegate to planner-agent, similar to how skill-planner works. The agent receives the existing plan plus revision context and creates a new version.
2. **Description Update (Stage 2B)**: Simple enough to remain inline in the command or skill. No agent needed.
3. **Status transitions**: For plan revision, status goes planned/implementing/partial -> planned. This is a regression, which is explicitly allowed "except for revisions" per state-management.md.
4. **Postflight marker**: Needed for plan revision (subagent invocation). Not needed for description update (inline work).

### Considerations

- /revise is used less frequently than /research, /plan, /implement
- The Plan Revision path is complex enough to benefit from skill delegation
- The Description Update path is simple enough to stay inline
- A hybrid approach may be best: skill delegates to agent for plan revision, handles description update directly

## Integration Points

- **Component Type**: Command modification + new skill
- **Affected Area**: .claude/commands/, .claude/skills/
- **Action Type**: Create new (skill-reviser) + modify existing (revise.md)
- **Related Files**:
  - `.claude/commands/revise.md`
  - `.claude/skills/skill-planner/SKILL.md` (pattern reference)
  - `.claude/agents/planner-agent.md` (reuse for plan revision)
  - `.claude/scripts/update-task-status.sh` (from Task 362)

## Dependencies

- Task #362: Create centralized update-task-status.sh script

## Interview Context

### Effort Assessment
- **Estimated Effort**: 2-3 hours (Medium)
- **Complexity Notes**: Requires creating a new skill following the thin-wrapper pattern plus modifying the command. The description update path complicates the design since it doesn't need agent delegation.

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 367 [focus]` with a specific focus prompt.*
