---
description: Analyze errors and create fix plans
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, Agent
argument-hint: "[--fix TASK_NUMBER]"
model: sonnet
---

# /errors Command

Analyze errors.json, identify patterns, and create fix plans.

## Arguments

- No args: Analyze all errors and suggest fixes
- `--fix N` - Implement fixes for specific error task

## Execution (Analysis Mode - Default)

### 1. Load Error Data

Read `specs/errors.json`. The top-level shape is `{"errors": [...]}` -- an object holding the
array, never a bare array. The formal machine-checkable contract lives in
`context/schemas/errors-schema.json`, with the full field/CLI prose contract in
`context/formats/errors-format.md`; the two must stay in sync. Each record's `context` sub-object
is a union superset (`session_id`, `command`, `task`, `phase`, `checkpoint`, `agent`, `file`),
`fix_status` is a closed enum (`unfixed|in_progress|fixed`, plus the deprecated `resolved`
synonym read-only), and `type` is an open string.

### 2. Analyze Patterns

Group errors by:
- **Type**: delegation_hang, timeout, build_error, etc.
- **Severity**: critical, high, medium, low
- **Recurrence**: How often each error repeats -- COMPUTED at analysis time by grouping records on
  `type` (not read from a stored field; the schema has no `recurrence_count` field, since no
  writer has ever populated one)
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

### 3.5 Consolidate findings before drafting tasks

Before drafting fix-task entries, apply a mechanical, non-interactive pre-merge of the error
patterns identified in Step 2: group the patterns that would otherwise each become a separate
task when they share a narrow file target or resolve the same named acceptance gate/check, and
draft one task per resulting group. This is the Task-Count Reasoning default from Component 0 in
`.claude/docs/reference/standards/multi-task-creation-standard.md`: default to one task per group
unless a named divide reason applies — see that component for the full default statement and
reason list rather than restating them here.

This step adds **no user gate and no `AskUserQuestion`** — `/errors` keeps its fast, automatic
triage posture. The separate `--interactive` enhancement (manual selection) remains a distinct,
still-open item tracked in the standard's Gaps section, not part of this pre-merge.

A shared broad, widely-edited infrastructure file or directory-root scope does not, by itself,
merge two findings — see Component 0's narrowness qualifier.

The `## Suggested Tasks` report above presents the **consolidated** set of tasks (after this
pre-merge), not the pre-merge set of raw patterns.

### 4. Create Fix Tasks

For significant error patterns (after Step 3.5's consolidation pre-merge), create tasks:

```
/task "Fix: {error description} ({N} occurrences)"
```

Note task numbers in report.

**Topic Note**: Tasks are created via the `/task` command, which handles topic detection and `active_topics` array maintenance internally (Step 4.5 of Create Mode). No separate `active_topics` update is needed here.

### 4a. Update Task Order Section (Non-Blocking)

After all fix tasks have been created, regenerate the Task Order section in TODO.md:

```bash
if [ -f ".claude/scripts/generate-task-order.sh" ]; then
  bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
    2>/dev/null || echo "Note: Failed to regenerate Task Order (non-fatal)" >&2
fi
```

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
3. Update error status to "in_progress" via `scripts/errors-append.sh update --id ERR_ID
   --fix-status in_progress`
4. Verify fix works
5. Update error status to "fixed" via `scripts/errors-append.sh update` (see step 4 below)

### 4. Update errors.json

Mark fixed errors via `errors-append.sh update`, which mutates the record in place under `flock`
and validates the merged document before writing:
```bash
.claude/scripts/errors-append.sh update --id ERR_ID --fix-status fixed --fix-task "$M"
```

This sets `fix_status: "fixed"`, a `fixed_date` (defaulting to now when omitted), and `fix_task`.
Never pass `--fix-status resolved` -- it is a deprecated synonym for `fixed`, schema-valid for
reading but rejected as an `update` input. See `context/formats/errors-format.md` for the full
CLI contract.

### 5. Git Commit

Apply targeted staging per `.claude/context/standards/git-staging-scope.md` — scope to
`specs/errors.json` plus the generated fix-task directory, never a repo-wide add:

```bash
padded_m=$(printf "%03d" "$M")
task_m_name=$(jq -r --argjson num "$M" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
stage_paths=("specs/errors.json" "specs/TODO.md" "specs/state.json")
[ -n "$task_m_name" ] && stage_paths+=("specs/${padded_m}_${task_m_name}/")
bash .claude/scripts/git-commit-scoped.sh \
  --message "errors: fix {N} errors (task {M})" \
  --session "${session_id}" \
  --honest-index-rows "$M" \
  -- "${stage_paths[@]}"
```

## Standards Reference

This command implements the multi-task creation pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard.

**Compliance Level**: Partial (intentionally simplified)

| Component | Status | Notes |
|-----------|--------|-------|
| Task-Count Reasoning (0) | Yes (non-interactive) | Step 3.5 mechanical pre-merge on shared file target/acceptance gate |
| Discovery | Yes | Error patterns from errors.json |
| Selection | No | Automatic task creation |
| Grouping | Partial | Groups by error type/severity |
| Dependencies | No | Not implemented |
| Ordering | No | Sequential creation |
| Visualization | No | Not implemented |
| Confirmation | No | Automatic mode |
| State Updates | Yes | Standard task creation |

**Rationale**: The `/errors` command intentionally uses automatic task creation without interactive selection. This design prioritizes quick error triage - when errors are detected, immediate task creation is more valuable than manual curation. The Task-Count Reasoning pre-merge (Step 3.5) is mechanical and non-interactive, consistent with that design.

**Gap**: No interactive selection or dependency support.

**Future Enhancement**: Add `--interactive` flag for manual selection mode when desired.
