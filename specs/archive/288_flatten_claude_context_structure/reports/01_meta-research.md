# Research Report: Task #288

**Task**: 288 - Flatten .claude/context/ structure after file reassignment
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised after project context audit
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Simplify .claude/context/ by removing the core/ and project/ nesting levels
**Scope**: Flatten directory structure, update all paths
**Affected Components**: .claude/context/ directory structure, index.json
**Domain**: meta
**Language**: meta

## Task Requirements

After task 287 reassigns project/ files (core files promoted, nvim files moved to extension), flatten the remaining structure by removing the `core/` subdirectory.

### Current Structure (after task 287)

```
.claude/context/
├── core/                   # Agent system patterns (to flatten)
│   ├── orchestration/
│   ├── formats/
│   ├── standards/
│   ├── workflows/
│   ├── templates/
│   ├── schemas/
│   ├── checkpoints/
│   ├── patterns/
│   ├── guides/
│   ├── reference/
│   ├── architecture/
│   └── troubleshooting/
├── meta/                   # Promoted from project/meta/ by task 287
├── processes/              # Promoted from project/processes/ by task 287
├── repo/                   # Promoted from project/repo/ by task 287
├── index.json
├── index.schema.json
└── README.md
```

### Target Structure

```
.claude/context/
├── orchestration/          # Flattened from core/
├── formats/
├── standards/
├── workflows/
├── templates/
├── schemas/
├── checkpoints/
├── patterns/
├── guides/
├── reference/
├── architecture/
├── troubleshooting/
├── meta/                   # Already at correct level from task 287
├── processes/              # Already at correct level from task 287
├── repo/                   # Already at correct level from task 287
├── index.json              # Updated paths
├── index.schema.json
└── README.md
```

### Update Requirements

1. Move contents of `core/` to `.claude/context/` root
2. Remove empty `core/` directory
3. Update all paths in `index.json` (remove `core/` prefix)
4. Update all @-references in agents, skills, commands
5. Update README.md to reflect new structure

### Path Changes

| Old Path | New Path |
|----------|----------|
| `core/orchestration/` | `orchestration/` |
| `core/formats/` | `formats/` |
| `core/patterns/` | `patterns/` |
| etc. | etc. |

Note: `meta/`, `processes/`, `repo/` are already at the correct level after task 287's promotion step.

## Integration Points

- **Component Type**: directory restructure
- **Affected Area**: .claude/context/
- **Action Type**: refactor
- **Related Files**:
  - All files in .claude/context/core/ (moving up)
  - .claude/context/index.json
  - All agents, skills, commands with @-references

## Dependencies

- Task #287: Reassign project context files (project/ must be emptied first)

## Interview Context

### User-Provided Information
The flattening removes the now-unnecessary `core/` subdirectory since all remaining content is core agent system context. The `project/` directory is already gone after task 287's reassignment.

### Effort Assessment
- **Estimated Effort**: 2 hours
- **Complexity Notes**: Many file moves and path updates. Need to verify all @-references still work after restructure.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 to reflect updated task 287 (reassignment instead of migration).*
*For deeper investigation, run `/research 288 [focus]` with a specific focus prompt.*
