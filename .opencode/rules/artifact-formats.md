---
paths: specs/**/*
---

# Artifact Format Rules

## Placeholder Conventions

Placeholders in path templates and content follow these conventions:

| Placeholder | Format | Usage | Examples |
|-------------|--------|-------|----------|
| `{OC_N}` | `OC_` + unpadded integer | OpenCode task numbers in text, commits | `OC_17`, `task OC_17:` |
| `{OC_NNN}` | `OC_` + 3-digit padded | OpenCode directory names | `OC_017`, `OC_017_task_slug` |
| `{NNN}` | 3-digit padded | Artifact versions | `001`, `research-001.md` |
| `{P}` | Unpadded integer | Phase numbers | `1`, `phase 1:` |
| `{DATE}` | YYYYMMDD | Date stamps in filenames | `20260111` |
| `{ISO_DATE}` | YYYY-MM-DD | ISO dates in content | `2026-01-11` |
| `{SLUG}` | snake_case | Task slug from title | `fix_bug_name` |

**Key distinctions**:
- OpenCode tasks use `OC_` prefix to distinguish from Claude Code tasks (unprefixed)
- Task numbers in text (`{OC_N}`) are unpadded: `OC_17`
- Directory names (`{OC_NNN}`) use 3-digit padding: `OC_017_task_slug`
- Artifact versions (`{NNN}`) are padded: `research-001.md`
- Internal storage in state.json uses integer `project_number` (e.g., `17`); prefix is for display/paths only

## Research Reports

**Location**: `specs/{OC_NNN}_{SLUG}/reports/research-{NNN}.md`

```markdown
# Research Report: Task #{OC_N}

**Task**: {title}
**Date**: {ISO_DATE}
**Focus**: {optional focus}

## Summary

{2-3 sentence overview}

## Findings

### {Topic}

{Details with evidence}

## Recommendations

1. {Actionable recommendation}

## References

- {Source with link if applicable}

## Next Steps

{What to do next}
```

## Implementation Plans

**Location**: `specs/{OC_NNN}_{SLUG}/plans/implementation-{NNN}.md`

```markdown
# Implementation Plan: Task #{OC_N}

**Task**: {title}
**Version**: {NNN}
**Created**: {ISO_DATE}
**Language**: {language}

## Overview

{Approach summary}

## Phases

### Phase 1: {Name}

**Estimated effort**: {hours}
**Status**: [NOT STARTED]

**Objectives**:
1. {Objective}

**Files to modify**:
- `path/to/file` - {changes}

**Steps**:
1. {Step}

**Verification**:
- {How to verify}

---

## Dependencies

- {Dependency}

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|

## Success Criteria

- [ ] {Criterion}
```

## Implementation Summaries

**Location**: `specs/{OC_NNN}_{SLUG}/summaries/implementation-summary-{DATE}.md`

```markdown
# Implementation Summary: Task #{OC_N}

**Completed**: {ISO_DATE}
**Duration**: {time}

## Changes Made

{Overview}

## Files Modified

- `path/to/file` - {change}

## Verification

- {What was verified}

## Notes

{Additional notes}
```

## Phase Status Markers

Use in plan files:
- `[NOT STARTED]` - Phase not begun
- `[IN PROGRESS]` - Currently executing
- `[COMPLETED]` - Phase finished
- `[PARTIAL]` - Partially complete (interrupted)
- `[BLOCKED]` - Cannot proceed

## Versioning

### Research Reports
Increment: research-001.md, research-002.md
- Multiple reports for same task allowed
- Later reports supplement earlier ones

### Plans
Increment: implementation-001.md, implementation-002.md
- New version = revised approach
- Previous versions preserved for history

### Summaries
Date-based: implementation-summary-20260109.md
- One per completion
- Includes all phases
