# Research Report: Task #460

**Task**: 460 - fix_link_artifact_todo_fallback
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:00:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- `.claude/scripts/link-artifact-todo.sh` (nvim)
- `~/.config/zed/.claude/scripts/link-artifact-todo.sh` (zed reference)
- `.claude/skills/skill-researcher/SKILL.md` (caller)
- `.claude/skills/skill-planner/SKILL.md` (caller)
- `.claude/skills/skill-implementer/SKILL.md` (caller)
- `.claude/context/patterns/artifact-linking-todo.md` (design doc)
**Artifacts**: - specs/460_fix_link_artifact_todo_fallback/reports/01_link-artifact-fallback.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The bug is in `.claude/scripts/link-artifact-todo.sh`, affecting only `/research` postflight which passes `next_field="**Plan**"`
- Two code locations need the fallback: Case 1 (line 119) and Case 3 (line 166)
- The error message on line 120 already mentions `**Description**` as a fallback but the code never searches for it
- The fix is straightforward: add a fallback search for `**Description**` before the error exit in both locations
- The Zed copy at `~/.config/zed/.claude/scripts/link-artifact-todo.sh` has the same bug and needs the same fix

## Context & Scope

When `/research` completes, its postflight calls:
```bash
bash .claude/scripts/link-artifact-todo.sh $task_number '**Research**' '**Plan**' "$artifact_path"
```

The `next_field="**Plan**"` parameter is used as the insertion anchor -- the script finds the `**Plan**` line in the TODO.md entry and inserts the `**Research**` link before it. On tasks that have never been planned, no `**Plan**` line exists, so the script fails with exit code 3.

`/plan` and `/implement` are not affected because they use `next_field="**Description**"` which always exists in every task entry.

## Findings

### Callers and Their Parameters

| Skill | field_name | next_field | Affected? |
|-------|-----------|-----------|-----------|
| skill-researcher | `**Research**` | `**Plan**` | YES - Plan may not exist |
| skill-planner | `**Plan**` | `**Description**` | No - Description always exists |
| skill-implementer | `**Summary**` | `**Description**` | No - Description always exists |

### Bug Location 1: Case 1 (No existing field line)

Lines 112-122 of `link-artifact-todo.sh`:
```bash
next_field_line=$(... safe_grep -nF -- "- ${next_field}:" ...)
if [[ -z "$next_field_line" ]]; then
  # Try bare format
  next_field_line=$(... safe_grep -nF -- "${next_field}:" ...)
fi
if [[ -z "$next_field_line" ]]; then
  echo "Error: could not find insertion point (${next_field} or **Description**) for task $task_number" >&2
  exit 3
fi
```

The error message on line 120 says "or **Description**" but the code never searches for `**Description**`. It searches for `next_field` in dash-prefixed and bare formats, then gives up.

### Bug Location 2: Case 3 (Field exists but empty, multi-line header)

Lines 163-169 have an identical pattern -- searching for `next_field` after `field_name` but with no fallback to `**Description**`.

### Zed Copy

The Zed version at `~/.config/zed/.claude/scripts/link-artifact-todo.sh` is identical (same 236 lines, same bug). It needs the same fix applied.

## Decisions

- The fallback should try `**Description**` using the same dash-prefixed then bare search pattern already used for the primary `next_field`
- The fallback should only activate when `next_field` is not `**Description**` (to avoid redundant searching)
- Both Case 1 and Case 3 need the fallback

## Recommendations

### Implementation Approach

For **Case 1** (after line 117, before line 119), insert a fallback block:

```bash
if [[ -z "$next_field_line" && "$next_field" != "**Description**" ]]; then
  # Fallback: try **Description** (always exists in task entries)
  next_field_line=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "- **Description**:" | head -1 | cut -d: -f1)
  if [[ -z "$next_field_line" ]]; then
    next_field_line=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "**Description**:" | head -1 | cut -d: -f1)
  fi
fi
```

For **Case 3** (after line 165, before line 166's inner check), insert a similar fallback:

```bash
if [[ -z "$next_field_line_abs" && "$next_field" != "**Description**" ]]; then
  next_field_line_abs=$(sed -n "$((field_actual_line+1)),${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "- **Description**:" | head -1 | cut -d: -f1)
  if [[ -z "$next_field_line_abs" ]]; then
    next_field_line_abs=$(sed -n "$((field_actual_line+1)),${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "**Description**:" | head -1 | cut -d: -f1)
  fi
fi
```

### Testing

Test the fix with a dry-run on a task that has no Plan line:
```bash
bash .claude/scripts/link-artifact-todo.sh <task_number> '**Research**' '**Plan**' 'specs/NNN_slug/reports/01_test.md' --dry-run
```

### Zed Sync

Apply the identical fix to `~/.config/zed/.claude/scripts/link-artifact-todo.sh`.

## Risks & Mitigations

- **Risk**: The fallback could insert before the wrong `**Description**` if the field appears in task description text. **Mitigation**: The search is scoped to the task entry block (heading_line to entry_end) and uses the dash-prefixed `- **Description**:` pattern first, which is specific to the field format.
- **Risk**: Edge case where neither `**Plan**` nor `**Description**` exists. **Mitigation**: The existing error exit (exit 3) handles this gracefully, and the calling skills treat linking errors as non-blocking.

## Appendix

### File Locations
- Script: `.claude/scripts/link-artifact-todo.sh`
- Zed copy: `~/.config/zed/.claude/scripts/link-artifact-todo.sh`
- Design doc: `.claude/context/patterns/artifact-linking-todo.md`
- Researcher skill: `.claude/skills/skill-researcher/SKILL.md` (line 358)
- Planner skill: `.claude/skills/skill-planner/SKILL.md` (line 360)
- Implementer skill: `.claude/skills/skill-implementer/SKILL.md` (line 427)
