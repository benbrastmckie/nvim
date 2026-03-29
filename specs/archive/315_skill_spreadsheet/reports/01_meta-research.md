# Research Report: Task #315

**Task**: 315 - Create skill-spreadsheet
**Generated**: 2026-03-27
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Create thin wrapper skill routing to spreadsheet-agent
**Scope**: .claude/extensions/founder/skills/
**Affected Components**: Skill definition
**Domain**: founder extension
**Language**: meta

## Task Requirements

Create skill-spreadsheet/SKILL.md following thin wrapper pattern:
- Validate task_number exists in state.json
- Preflight status update to "researching"
- Create postflight marker
- Prepare delegation context with file path
- Invoke spreadsheet-agent via Task tool
- Parse subagent return
- Postflight status update to "researched"
- Link artifacts
- Git commit
- Cleanup and return

## Integration Points

- **Component Type**: Skill
- **Affected Area**: .claude/extensions/founder/skills/skill-spreadsheet/
- **Action Type**: Create
- **Related Files**:
  - .claude/extensions/founder/skills/skill-project/SKILL.md (pattern reference)
  - .claude/extensions/founder/skills/skill-market/SKILL.md (pattern reference)
  - .claude/context/templates/thin-wrapper-skill.md (template)
  - .claude/extensions/founder/agents/spreadsheet-agent.md (target agent - Task 314)

## Skill Design

### Trigger Conditions
- Direct `/sheet` command invocation
- `/research` on task with `task_type: "sheet"`
- `/research` on task with `language: "founder:sheet"`

### Delegation Context
```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{slug}",
    "description": "{description}",
    "language": "founder",
    "task_type": "sheet"
  },
  "input_file": "{path to cost breakdown file}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "sheet", "skill-spreadsheet"]
  }
}
```

## Dependencies

- Task #314: Requires spreadsheet-agent to route to

## Interview Context

### User-Provided Information
Skill should accept file path parameter and route to spreadsheet-agent.

### Effort Assessment
- **Estimated Effort**: 1 hour
- **Complexity Notes**: Low - follows established thin wrapper pattern

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 315 [focus]` with a specific focus prompt.*
