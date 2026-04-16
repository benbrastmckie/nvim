# Implementation Plan: Fix Artifact Linking in TODO.md

- **Task**: 431 - Fix artifact linking order and missing blank line in TODO.md
- **Status**: [COMPLETED]
- **Effort**: small
- **Dependencies**: None
- **Research Inputs**: specs/431_fix_artifact_linking_order_todo/reports/01_artifact-linking-bug.md
- **Artifacts**: specs/431_fix_artifact_linking_order_todo/plans/01_artifact-linking-fix.md
- **Standards**: state-management-schema.md, artifact-formats.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Fix three issues in `link-artifact-todo.sh`: (1) blank line above `**Description**:` is consumed during insertion, (2) link format uses `[text](path)` instead of bracket-only `[path]`, and (3) the `specs/` prefix stripping is already correct but the link format must change to bracket-only style. The state-management-schema.md artifact linking format spec must also be updated to reflect the bracket-only link style.

## Goals & Non-Goals

**Goals:**
- Preserve blank line between last artifact field and `**Description**:` during insertion
- Change link format from `[text](path)` to bracket-only `[path]` throughout the script
- Keep `specs/` prefix stripping (current behavior on line 69 is correct)
- Update state-management-schema.md to document the bracket-only link format

**Non-Goals:**
- Fixing pre-existing malformed TODO.md entries
- Auditing task creation commands for artifact placement
- Changing `next_field` parameterization

## Risks & Mitigations

- **Risk**: Blank line logic change may break entries without a blank line above Description
  - **Mitigation**: Only adjust insertion point when a blank line is detected; entries without a blank line insert normally
- **Risk**: Bracket-only links may not render as clickable in some markdown renderers
  - **Mitigation**: This is the user's preferred format; TODO.md is primarily for human reading, not rendered markdown

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2      | 1          |

### Phase 1: Fix link-artifact-todo.sh [COMPLETED]

**Goal:** Fix blank line preservation and change link format to bracket-only style.

**Tasks:**
- [ ] In Case 1 (lines 124-134): Before inserting at `actual_next_line`, check if the line at `actual_next_line - 1` (relative to the TODO file) is blank. If so, insert at `actual_next_line - 1` instead, so the blank line remains between the new artifact line and `**Description**:`
- [ ] In Case 3 (lines 156-178): Apply the same blank line check before `insert_before`
- [ ] Change link format on line 125 from `[${artifact_filename}](${todo_link_path})` to `[${todo_link_path}]`
- [ ] Change link format on line 168 (Case 3 bullet) from `[${artifact_filename}](${todo_link_path})` to `[${todo_link_path}]`
- [ ] Change link format on line 182-194 (Case 2 inline-to-multiline) from `[${artifact_filename}](${todo_link_path})` to `[${todo_link_path}]`
- [ ] Change link format on line 219 (replace non-link value) from `[${artifact_filename}](${todo_link_path})` to `[${todo_link_path}]`
- [ ] Add a comment explaining the blank line preservation logic

**Timing:** 15 minutes

**Depends on:** none

### Phase 2: Update state-management-schema.md [COMPLETED]

**Goal:** Update the artifact linking format documentation to reflect bracket-only link style.

**Tasks:**
- [ ] In `.claude/context/reference/state-management-schema.md`, update the "Artifact Linking Formats" section: change all `[filename](path)` examples to `[path]` format
- [ ] Update the "Count-Aware Linking" examples similarly
- [ ] Update the "Detection Patterns" inline detection regex from `\[.*\]\(.*\)` to `\[.*\]`

**Timing:** 5 minutes

**Depends on:** 1

## Testing & Validation

- Run `--dry-run` against a task entry with blank line above Description: verify insertion happens before the blank line
- Run `--dry-run` against a task entry without blank line above Description: verify normal insertion
- Run `--dry-run` and verify link format shows `[path]` not `[text](path)`
- Run `--dry-run` and verify no `specs/` prefix in output paths
- Verify Case 2 (inline-to-multiline) dry-run output shows bracket-only format

## Artifacts & Outputs

| Artifact | Path |
|----------|------|
| Modified script | `.claude/scripts/link-artifact-todo.sh` |
| Updated schema | `.claude/context/reference/state-management-schema.md` |
| This plan | `specs/431_fix_artifact_linking_order_todo/plans/01_artifact-linking-fix.md` |

## Rollback/Contingency

Both files are version-controlled. Revert with `git checkout HEAD~1 -- .claude/scripts/link-artifact-todo.sh .claude/context/reference/state-management-schema.md`. Changes are isolated with no downstream dependencies.
