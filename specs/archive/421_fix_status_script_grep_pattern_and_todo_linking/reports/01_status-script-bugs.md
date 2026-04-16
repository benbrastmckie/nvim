# Research Report: Task #421

**Task**: 421 - Fix update-task-status.sh grep pattern and skill-planner TODO.md artifact linking
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:15:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/scripts/update-task-status.sh`
- Codebase: `specs/TODO.md` (live task entries)
- Codebase: `.claude/context/patterns/artifact-linking-todo.md`
- Codebase: `.claude/skills/skill-planner/SKILL.md`
- Codebase: `.claude/skills/skill-researcher/SKILL.md`
- Codebase: `.claude/skills/skill-implementer/SKILL.md`
- Codebase: `.claude/skills/skill-reviser/SKILL.md`
- Codebase: `.claude/context/reference/state-management-schema.md`
- Codebase: `.claude/commands/task.md`
**Artifacts**:
- specs/421_fix_status_script_grep_pattern_and_todo_linking/reports/01_status-script-bugs.md
**Standards**: report-format.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- Bug 1: The `update_todo_task_entry()` function in `update-task-status.sh` uses grep pattern `^- \*\*Status\*\*: \[` which fails to match tasks whose entries use space-indented format (` **Status**: [`). This causes ALL task entry status updates to silently fail for affected tasks while state.json and Task Order updates succeed.
- Bug 1 is actively causing data inconsistency right now: task 421 shows `[RESEARCHING]` in Task Order but `[NOT STARTED]` in the task entry.
- The root cause of the format mismatch is that some tasks were created with incorrect indentation (space-only instead of `- ` dash-prefix), violating the canonical format in `state-management-schema.md`.
- Bug 2: All three core skills (skill-researcher, skill-planner, skill-implementer) plus skill-reviser specify TODO.md artifact linking in their postflight Stage 8, but these instructions are textual references to the four-case Edit logic -- they rely on the LLM executing the Edit tool. This is not a "missing code" bug but rather a pattern that is sometimes skipped by the executing LLM.
- Recommended fix: Make the grep pattern in `update-task-status.sh` tolerant of both formats, AND fix existing TODO.md entries to use the canonical dash-prefixed format.

## Context & Scope

Two bugs were reported affecting TODO.md synchronization:

1. **Grep pattern mismatch** in `update-task-status.sh` line 197 -- the script cannot find Status lines for tasks that use space-indented format.
2. **Missing TODO.md artifact linking** in skill-planner postflight -- the Plan field is never added to TODO.md task entries after planning completes.

The research scope includes understanding the exact TODO.md format, what created the inconsistency, which skills are affected, and what the correct fix should be.

## Findings

### Bug 1: Grep Pattern Mismatch in update-task-status.sh

#### The Failing Pattern

In `update-task-status.sh` line 196-197, the `update_todo_task_entry()` function searches for the Status line:

```bash
status_line=$(sed -n "$((heading_line+1)),$((heading_line+10))p" "$TODO_FILE" \
  | grep -n -E '^- \*\*Status\*\*: \[' | head -1 | cut -d: -f1)
```

This pattern `^- \*\*Status\*\*: \[` requires:
- Line starts with `- ` (dash + space)
- Followed by `**Status**: [`

#### Actual TODO.md Formats Found

Two distinct formats exist in the current TODO.md:

**Format A (canonical, dash-prefixed)** -- used by task 78:
```
- **Status**: [PLANNED]
```

**Format B (non-canonical, space-indented)** -- used by tasks 87, 420, 421:
```
 **Status**: [NOT STARTED]
```

#### Format Provenance

- The canonical format is defined in `.claude/context/reference/state-management-schema.md` (line 46): `- **Status**: [{STATUS}]`
- The `/task` command template (`.claude/commands/task.md` line 167-168) correctly specifies dash-prefix: `- **Status**: [NOT STARTED]`
- All 444 archived tasks use the dash-prefixed format
- The space-indented format was introduced by agents that did not strictly follow the template when creating task entries

#### Active Data Inconsistency

Task 421 demonstrates the bug in action:
- **Task Order** (line 13): `- **421** [RESEARCHING]` -- CORRECT (updated by `update_todo_task_order()`)
- **Task Entry** (line 22): ` **Status**: [NOT STARTED]` -- STALE (update_todo_task_entry() failed silently)
- **state.json**: `"status": "researching"` -- CORRECT

The script returns success (exit 0) for state.json and Task Order, then warns about the task entry failure but continues.

#### Other Fields With Similar Pattern Risk

The script does NOT grep for other fields (Effort, Task Type, etc.) -- only the Status field. However, the same space-indentation issue would affect any future script that tries to match `^- \*\*FieldName\*\*:`.

No other fields in `update-task-status.sh` are affected because the script only modifies the Status line.

### Bug 2: Missing TODO.md Artifact Linking

#### How Artifact Linking Is Specified

All three core skills plus skill-reviser contain an identical pattern in their Stage 8 (Link Artifacts):

1. **state.json linking**: Done via jq commands (shell-executable, always works)
2. **TODO.md linking**: Specified as a textual instruction:
   > Apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Plan**`, `next_field=**Description**`.

This instruction tells the LLM executing the skill to use the Edit tool to modify TODO.md. It is NOT a shell command.

#### Why It Sometimes Fails

The artifact-linking-todo.md pattern explicitly states:

> **Constraint**: This logic uses the Edit tool for semantic text replacement. It cannot be implemented as a shell script.

This means the TODO.md artifact linking depends on the LLM reading the four-case logic, determining which case applies, and executing an Edit tool call. In practice:
- The state.json jq commands always execute (they are concrete bash)
- The TODO.md Edit instruction is sometimes skipped or not executed by the LLM

#### Affected Skills

All skills that reference `artifact-linking-todo.md` in their postflight Stage 8:

| Skill | Field Name | Next Field | Status |
|-------|-----------|------------|--------|
| skill-researcher | `**Research**` | `**Plan**` | Same pattern -- sometimes skipped |
| skill-planner | `**Plan**` | `**Description**` | Same pattern -- sometimes skipped |
| skill-implementer | `**Summary**` | `**Description**` | Same pattern -- sometimes skipped |
| skill-reviser | `**Plan**` | `**Description**` | Same pattern -- sometimes skipped |

Additionally, 51 extension skills reference the same pattern (found via grep).

#### Evidence From TODO.md

Looking at task 420 (recently completed), the TODO.md entry HAS Research, Plan, and Summary links. This means the artifact linking DOES work when the LLM follows through. The issue is inconsistency -- it works sometimes but not always.

Looking at task 421 (current), there is no Research link yet, but this is because we are currently in the research phase.

### Cross-Reference: Both Bugs Interact

If a task entry uses the non-canonical space-indented format AND the artifact linking uses the four-case Edit logic to find `- **Plan**:`, the Edit will also fail because it looks for the dash-prefixed format. The two bugs compound each other for non-canonical entries.

## Decisions

1. **Fix the grep pattern** to be tolerant of both formats (dash-prefixed and space-indented), since both exist in the wild and tasks may continue to be created in either format.
2. **Also fix existing non-canonical entries** in TODO.md to use the canonical dash-prefixed format, so that the four-case Edit logic works reliably.
3. **Do NOT attempt to convert the four-case Edit logic to a shell script** -- the pattern document explicitly says this cannot be done as a shell script due to the semantic matching needed.
4. **Consider adding a format normalization step** to `update-task-status.sh` that converts space-indented entries to dash-prefixed format when encountered.

## Recommendations

### Priority 1: Fix grep pattern in update-task-status.sh (Bug 1)

Change line 197 from:
```bash
grep -n -E '^- \*\*Status\*\*: \[' | head -1 | cut -d: -f1
```
To:
```bash
grep -n -E '^\s*-?\s*\*\*Status\*\*: \[' | head -1 | cut -d: -f1
```

This pattern matches both:
- `- **Status**: [` (canonical dash-prefixed)
- ` **Status**: [` (space-indented, no dash)
- `  **Status**: [` (any amount of leading whitespace)

### Priority 2: Fix existing TODO.md entries

Convert all 3 non-canonical entries (tasks 87, 420, 421) to use the canonical dash-prefixed format. This is a one-time cleanup.

### Priority 3: Fix the task 421 status inconsistency

After fixing the grep pattern, re-run the status update for task 421 to sync the task entry status with state.json.

### Priority 4: Strengthen artifact linking reliability (Bug 2)

The four-case Edit logic is inherently dependent on LLM execution. Two options to improve reliability:

**Option A** (recommended): Add format validation to the existing `validate-artifact.sh` or create a new `validate-todo-links.sh` script that can be run as part of postflight to detect missing links.

**Option B**: Accept the current LLM-dependent approach and rely on `/todo` or manual review to catch missing links. The state.json linking (which always works) is the machine-readable source of truth.

### Priority 5: Prevent future format drift

Add a comment to the grep pattern explaining both formats, and consider adding a normalization step to `update-task-status.sh` that fixes space-indented entries when encountered.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Overly broad grep pattern matches unintended lines | Low | Medium | The grep is scoped to 10 lines after the task heading, limiting false matches |
| Fixing existing entries breaks artifact links | Low | Low | Existing links use relative paths that are format-independent |
| LLM continues to create non-canonical entries | Medium | Low | The grep fix handles both formats; consider adding validation to `/task` |

## Appendix

### Files to Modify

1. `.claude/scripts/update-task-status.sh` -- line 197 grep pattern
2. `specs/TODO.md` -- normalize 3 task entries (87, 420, 421) to canonical format
3. Optionally: `.claude/context/patterns/artifact-linking-todo.md` -- note about space-indented format tolerance

### Verification Commands

```bash
# Dry-run to verify fix works
bash .claude/scripts/update-task-status.sh postflight 421 research test_session --dry-run

# Check all Status lines match one of the expected patterns
grep -n "Status" specs/TODO.md
```

### Format Statistics

- Canonical (dash-prefixed) entries in archives: 444
- Non-canonical (space-indented) entries in active TODO.md: 3 (tasks 87, 420, 421)
- Canonical entries in active TODO.md: 1 (task 78)
