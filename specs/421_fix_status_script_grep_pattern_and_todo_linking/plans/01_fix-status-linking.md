# Implementation Plan: Task #421

- **Task**: 421 - Fix update-task-status.sh grep pattern and TODO.md artifact linking
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/421_fix_status_script_grep_pattern_and_todo_linking/reports/01_status-script-bugs.md
- **Artifacts**: plans/01_fix-status-linking.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses two bugs in the task management pipeline. Bug 1: the `update_todo_task_entry()` function in `update-task-status.sh` uses a grep pattern that requires a dash-prefixed Status line (`^- **Status**:`) but several active tasks use space-indented format (` **Status**:`), causing all task entry status updates to silently fail. Bug 2: TODO.md artifact linking in skill postflights is LLM-dependent and sometimes skipped. The fix makes the grep tolerant of both formats, normalizes existing entries to canonical format, and creates a shell script to automate artifact linking.

### Research Integration

The research report confirmed: (1) the grep pattern `^- \*\*Status\*\*: \[` on line 197 never matches space-indented entries; (2) three active tasks (87, 420, 421) use the non-canonical space-indented format; (3) the artifact-linking-todo.md pattern explicitly states it cannot be a shell script due to "semantic matching" -- however, the four cases are well-defined and deterministic, making a script feasible; (4) state.json linking always works (jq commands) but TODO.md linking depends on LLM execution.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Agent System Quality" roadmap area indirectly. Fixing silent status update failures and automating artifact linking improves the reliability of the task management pipeline, which is foundational to all agent operations.

## Goals & Non-Goals

**Goals**:
- Fix the grep pattern in `update-task-status.sh` to match both dash-prefixed and space-indented Status lines
- Normalize existing non-canonical TODO.md entries to the canonical dash-prefixed format
- Create a `link-artifact-todo.sh` script that automates the four-case artifact linking logic
- Update skill postflight instructions to call the new script instead of relying on LLM Edit execution
- Verify task 421's TODO.md entry status is correctly synced after the fix

**Non-Goals**:
- Rewriting `update-task-status.sh` beyond the grep pattern fix
- Changing the artifact-linking-todo.md pattern document (it remains as reference documentation)
- Fixing extension skills (51 extensions reference the pattern -- out of scope, they can adopt the script later)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Broadened grep pattern matches unintended lines | M | L | The grep is scoped to 10 lines after the task heading; test with all active tasks |
| link-artifact-todo.sh fails on edge cases (multi-line, special chars) | M | M | Implement all four cases with careful sed/awk; test against existing TODO.md entries |
| Normalizing entries breaks existing artifact links | L | L | Links use relative paths independent of field indentation; verify after edit |
| Skill postflight changes break other skills | M | L | Only modify the four core skills; use consistent pattern; test one skill end-to-end |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix grep pattern and normalize TODO.md entries [COMPLETED]

**Goal**: Make `update_todo_task_entry()` work with both Status line formats and fix existing non-canonical entries.

**Tasks**:
- [ ] Change the grep pattern on line 197 of `update-task-status.sh` from `'^- \*\*Status\*\*: \['` to `'^\s*-?\s*\*\*Status\*\*: \['`
- [ ] Add a comment above the pattern explaining both formats and why the tolerant regex is needed
- [ ] Edit `specs/TODO.md` to normalize task entries 87, 420, and 421: change space-indented field lines (` **Field**:`) to dash-prefixed format (`- **Field**:`)
- [ ] Also normalize the sed extraction pattern on line 209 if it assumes dash-prefix format
- [ ] Run `bash .claude/scripts/update-task-status.sh postflight 421 plan sess_test --dry-run` to verify the fix matches

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Fix grep pattern on line 197, add explanatory comment
- `specs/TODO.md` - Normalize 3 task entries to canonical dash-prefixed format

**Verification**:
- Dry-run of update-task-status.sh against task 421 finds the Status line
- `grep -c '^ \*\*Status\*\*' specs/TODO.md` returns 0 (no space-indented Status lines remain)
- All active task entries use `- **Status**:` format

---

### Phase 2: Create link-artifact-todo.sh script [COMPLETED]

**Goal**: Automate the four-case artifact linking logic as a shell script that skills can call.

**Tasks**:
- [ ] Create `.claude/scripts/link-artifact-todo.sh` implementing all four cases from artifact-linking-todo.md
- [ ] Script interface: `link-artifact-todo.sh <task_number> <field_name> <next_field> <artifact_path>`
  - `field_name`: One of `**Research**`, `**Plan**`, `**Summary**`
  - `next_field`: The field that follows (e.g., `**Plan**`, `**Description**`)
  - `artifact_path`: Full path like `specs/421_slug/plans/01_plan.md`
- [ ] Implement Case 1 (no existing line): Use sed to insert before `next_field` line
- [ ] Implement Case 2 (existing inline link): Detect single-line link, convert to multi-line
- [ ] Implement Case 3 (existing multi-line): Append new bullet before `next_field`
- [ ] Implement Case 4 (already present): Detect existing path, skip
- [ ] Strip `specs/` prefix from path for TODO.md-relative links (per pattern doc)
- [ ] Add `--dry-run` flag for safe testing
- [ ] Make script executable
- [ ] Test all four cases against TODO.md: Case 1 with a fake field, Case 4 with task 421's existing Research link

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/link-artifact-todo.sh` - New file implementing four-case linking logic

**Verification**:
- `--dry-run` shows correct output for each case
- Running the script for task 421 Plan field correctly links this plan artifact
- Running the script again for the same artifact is a no-op (Case 4)

---

### Phase 3: Update skill postflights to use the script [COMPLETED]

**Goal**: Replace LLM-dependent Edit instructions with calls to `link-artifact-todo.sh` in the four core skills.

**Tasks**:
- [ ] Update `skill-planner/SKILL.md` Stage 8: replace the "Apply the four-case Edit logic" instruction with a bash command calling `link-artifact-todo.sh`
- [ ] Update `skill-researcher/SKILL.md` Stage 8: same replacement for Research field linking
- [ ] Update `skill-implementer/SKILL.md` Stage 8: same replacement for Summary field linking
- [ ] Update `skill-reviser/SKILL.md` Stage 8: same replacement for Plan field linking
- [ ] Ensure each skill passes correct `field_name` and `next_field` parameters per the parameterization map
- [ ] Add a note to `artifact-linking-todo.md` that `link-artifact-todo.sh` now automates this logic

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Replace Edit instruction with script call in Stage 8
- `.claude/skills/skill-researcher/SKILL.md` - Replace Edit instruction with script call in Stage 8
- `.claude/skills/skill-implementer/SKILL.md` - Replace Edit instruction with script call in Stage 8
- `.claude/skills/skill-reviser/SKILL.md` - Replace Edit instruction with script call in Stage 8
- `.claude/context/patterns/artifact-linking-todo.md` - Add note about shell script automation

**Verification**:
- Each skill's Stage 8 contains a `bash .claude/scripts/link-artifact-todo.sh` command
- The parameterization matches the table in artifact-linking-todo.md
- No skill still contains the old "Apply the four-case Edit logic" text instruction

## Testing & Validation

- [ ] Dry-run `update-task-status.sh` for tasks 87, 78, 421 -- all should find Status lines
- [ ] Run `link-artifact-todo.sh --dry-run` for each case type
- [ ] Verify task 421 TODO.md entry has correct Plan link after implementation
- [ ] `grep -E '^ \*\*' specs/TODO.md` returns no space-indented field lines (all normalized)
- [ ] Full status update cycle works: state.json, Task Order, AND task entry all update

## Artifacts & Outputs

- `.claude/scripts/update-task-status.sh` - Fixed grep pattern (modified)
- `.claude/scripts/link-artifact-todo.sh` - New artifact linking script (created)
- `specs/TODO.md` - Normalized task entries (modified)
- `.claude/skills/skill-{planner,researcher,implementer,reviser}/SKILL.md` - Updated postflights (modified)
- `.claude/context/patterns/artifact-linking-todo.md` - Added script reference (modified)

## Rollback/Contingency

All changes are to text files tracked by git. If the grep pattern fix causes issues, revert the single line in `update-task-status.sh`. If `link-artifact-todo.sh` has edge case failures, skills can fall back to the original LLM-dependent Edit approach (the pattern document is preserved). The TODO.md normalization can be reverted via `git checkout specs/TODO.md`.
