---
description: Analyze errors and create fix plans
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, Task
argument-hint: [--fix TASK_NUMBER]
model: opus
---

# /errors Command

Analyze errors.json, identify patterns, and create fix plans.

## Arguments

- No args: Analyze all errors and suggest fixes
- `--fix N` - Implement fixes for specific error task

## Execution (Analysis Mode - Default)

### 1. Load Error Data

Read specs/errors.json:
```json
{
  "errors": [
    {
      "id": "err_001",
      "timestamp": "ISO_DATE",
      "type": "delegation_hang|timeout|build_error|...",
      "severity": "critical|high|medium|low",
      "message": "Error description",
      "context": {
        "command": "/implement",
        "task": 259,
        "agent": "implementer",
        "file": "path/to/file"
      },
      "fix_status": "unfixed|in_progress|fixed",
      "recurrence_count": 1
    }
  ]
}
```

### 2. Analyze Patterns

Group errors by:
- **Type**: delegation_hang, timeout, build_error, etc.
- **Severity**: critical, high, medium, low
- **Recurrence**: How often each error repeats
- **Context**: Which commands/agents trigger them

Identify:
- Most frequent error types
- Highest severity unfixed errors
- Patterns suggesting root causes
- Quick wins (easy fixes)

### 3. Create Analysis Report

Write to `specs/errors/analysis-{DATE}.md`:

```markdown
# Error Analysis Report

**Date**: {ISO_DATE}
**Total errors**: {N}
**Unfixed**: {N}
**Fixed**: {N}

## Summary by Type

| Type | Count | Unfixed | Severity |
|------|-------|---------|----------|
| delegation_hang | {N} | {N} | high |
| timeout | {N} | {N} | medium |
| build_error | {N} | {N} | high |

## Critical Errors (Unfixed)

### {Error Type}: {Message}
**ID**: err_{N}
**Occurrences**: {N}
**Last seen**: {date}
**Context**: {command} on task {N}

**Root cause analysis**:
{Analysis of why this happens}

**Recommended fix**:
{Steps to fix}

**Estimated effort**: {time}

## Pattern Analysis

### Pattern 1: {Name}
**Errors involved**: err_{N1}, err_{N2}
**Common factor**: {what they share}
**Root cause**: {underlying issue}
**Fix approach**: {how to address}

## Recommended Fix Plan

### Priority 1: {High-impact fixes}
1. {Fix description} - addresses {N} errors
2. {Fix description} - addresses {N} errors

### Priority 2: {Medium-impact fixes}
...

### Priority 3: {Low-impact/preventive}
...

## Suggested Tasks

Create these tasks to address errors:
1. Task: "Fix {error type}" - High priority
2. Task: "Fix {error type}" - Medium priority
```

### 4. Create Fix Tasks

For significant error patterns, create tasks:

```
/task "Fix: {error description} ({N} occurrences)"
```

Note task numbers in report.

### 5. Output

```
Error Analysis Complete

Report: specs/errors/analysis-{DATE}.md

Errors: {N} total
- Critical unfixed: {N}
- High unfixed: {N}

Tasks created: {N}
- Task #{N1}: {title}
- Task #{N2}: {title}

Next: /implement {N}
```

## Execution (Fix Mode - --fix N)

### 1. Load Fix Task

Read task {N} from state.json
Verify it's an error-fix task

### 2. Identify Related Errors

Find errors in errors.json linked to this task
or matching the task description

### 3. Execute Fixes

For each error:
1. Analyze root cause
2. Implement fix
3. Update error status to "in_progress"
4. Verify fix works
5. Update error status to "fixed"

### 4. Update errors.json

Mark fixed errors:
```json
{
  "fix_status": "fixed",
  "fixed_date": "ISO_DATE",
  "fix_task": N
}
```

### 5. Git Commit

```bash
git add -A
git commit -m "errors: fix {N} errors (task {M})"
```

## Standards Reference

This command implements the multi-task creation pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard.

**Compliance Level**: Partial (intentionally simplified)

| Component | Status | Notes |
|-----------|--------|-------|
| Discovery | Yes | Error patterns from errors.json |
| Selection | No | Automatic task creation |
| Grouping | Partial | Groups by error type/severity |
| Dependencies | No | Not implemented |
| Ordering | No | Sequential creation |
| Visualization | No | Not implemented |
| Confirmation | No | Automatic mode |
| State Updates | Yes | Standard task creation |

**Rationale**: The `/errors` command intentionally uses automatic task creation without interactive selection. This design prioritizes quick error triage - when errors are detected, immediate task creation is more valuable than manual curation.

**Gap**: No interactive selection or dependency support.

**Future Enhancement**: Add `--interactive` flag for manual selection mode when desired.
