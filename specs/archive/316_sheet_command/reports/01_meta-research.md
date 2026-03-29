# Research Report: Task #316

**Task**: 316 - Create /sheet command
**Generated**: 2026-03-27
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Create /sheet command that accepts file with cost breakdowns
**Scope**: .claude/extensions/founder/commands/
**Affected Components**: Command definition
**Domain**: founder extension
**Language**: meta

## Task Requirements

Create sheet.md command following command template pattern:
- Accept file path argument (required)
- Validate file exists
- Create task with language: "founder:sheet", task_type: "sheet"
- Invoke skill-spreadsheet
- Support research/plan/implement workflow

## Integration Points

- **Component Type**: Command
- **Affected Area**: .claude/extensions/founder/commands/
- **Action Type**: Create
- **Related Files**:
  - .claude/extensions/founder/commands/project.md (pattern reference)
  - .claude/extensions/founder/commands/market.md (pattern reference)
  - .claude/extensions/founder/skills/skill-spreadsheet/SKILL.md (target skill - Task 315)

## Command Design

### Usage
```
/sheet <file-path> [description]
```

### Arguments
- `file-path` (required): Path to file containing cost breakdowns
- `description` (optional): Task description for TODO.md

### Flow
1. Validate file path exists
2. Create task with:
   - language: "founder:sheet"
   - task_type: "sheet"
   - input_file: <file-path>
3. Route to skill-spreadsheet for research
4. Support subsequent /plan and /implement

### Example
```
/sheet /path/to/budget.typ "Analyze Q1 budget projections"
```

## Dependencies

- Task #315: Requires skill-spreadsheet to invoke

## Interview Context

### User-Provided Information
Command should take a file with cost breakdowns as primary input.

### Effort Assessment
- **Estimated Effort**: 1 hour
- **Complexity Notes**: Low - follows established command pattern

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 316 [focus]` with a specific focus prompt.*
