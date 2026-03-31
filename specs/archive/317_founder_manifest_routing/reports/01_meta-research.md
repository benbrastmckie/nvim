# Research Report: Task #317

**Task**: 317 - Update founder manifest.json routing
**Generated**: 2026-03-27
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Add 'sheet' task type routing to manifest.json
**Scope**: .claude/extensions/founder/manifest.json
**Affected Components**: Manifest routing configuration
**Domain**: founder extension
**Language**: meta

## Task Requirements

Update manifest.json to add routing for "founder:sheet" language:
- Add skill-spreadsheet to provides.skills
- Add sheet.md to provides.commands
- Add spreadsheet-agent.md to provides.agents
- Add routing entries for research, plan, implement

## Integration Points

- **Component Type**: Configuration
- **Affected Area**: .claude/extensions/founder/manifest.json
- **Action Type**: Modify
- **Related Files**:
  - .claude/extensions/founder/manifest.json (target file)
  - .claude/extensions/founder/index-entries.json (needs update)

## Current Manifest Structure

```json
{
  "routing": {
    "research": {
      "founder": "skill-market",
      "founder:market": "skill-market",
      "founder:analyze": "skill-analyze",
      ...
    },
    "plan": {...},
    "implement": {...}
  }
}
```

## Required Changes

### routing.research
```json
"founder:sheet": "skill-spreadsheet"
```

### routing.plan
```json
"founder:sheet": "skill-founder-plan"
```

### routing.implement
```json
"founder:sheet": "skill-founder-implement"
```

### provides.skills
Add: `"skill-spreadsheet"`

### provides.commands
Add: `"sheet.md"`

### provides.agents
Add: `"spreadsheet-agent.md"`

### index-entries.json
Add entry for spreadsheet-frameworks.md with appropriate load_when conditions.

## Dependencies

- Task #315: Routing references skill-spreadsheet

## Interview Context

### User-Provided Information
Need 'sheet' task type routing for research/plan/implement workflow.

### Effort Assessment
- **Estimated Effort**: 30 minutes
- **Complexity Notes**: Low - straightforward JSON edits

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 317 [focus]` with a specific focus prompt.*
