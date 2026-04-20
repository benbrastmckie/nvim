# Implementation Plan: Widen load_when for State Management Context

- **Task**: 488 - widen_todo_entry_format_context
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/488_widen_todo_entry_format_context/reports/01_widen-load-when.md
- **Artifacts**: plans/01_widen-load-when.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `load_when` configuration for `state-management-schema.md` and `state-management.md` in `.claude/context/index.json` is too narrow, limiting context loading to only `/task` and `/todo` commands. Six commands create TODO.md entries (`/review`, `/fix-it`, `/meta`, `/spawn`, `/errors`, plus `/task` variants) but four of them lack access to the authoritative entry format specification. This plan widens `load_when.commands` and `load_when.agents` arrays for both entries and adds an explicit schema reference to the `/review` command's task creation section. Done when all task-creating commands load the schema and the review command references it explicitly.

### Research Integration

Key findings from research report `01_widen-load-when.md`:
- Both `state-management-schema.md` (352 lines) and `state-management.md` (337 lines) have `load_when.commands` restricted to `["/task", "/todo"]`
- `/review`, `/fix-it`, `/meta`, `/spawn`, and `/errors` all create tasks without guaranteed access to the format spec
- The `/review` command (Section 5.6.3, Step 4) says only "Add task entry following existing format" with no explicit schema reference
- `meta-builder-agent` and `spawn-agent` are the agents that perform task creation and should be added to `load_when.agents`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" priority area in Phase 1 of the roadmap, specifically the goal of eliminating stale references and ensuring correct context loading across commands.

## Goals & Non-Goals

**Goals**:
- Widen `load_when.commands` for both `state-management-schema.md` and `state-management.md` to include all task-creating commands
- Add `meta-builder-agent` and `spawn-agent` to `load_when.agents` for both entries
- Add explicit `@`-reference to `state-management-schema.md` in the `/review` command's task creation section

**Non-Goals**:
- Mirroring changes to the ProofChecker repository (separate task)
- Modifying other commands' source files beyond `/review`
- Changing the content of `state-management-schema.md` or `state-management.md` themselves

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Increased context budget (~689 lines) for commands that rarely create tasks | L | M | Commands only load context when matched; the schema is essential for correct task creation |
| Editing index.json incorrectly breaks context discovery | H | L | Validate JSON after edit; verify jq queries still work |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Widen load_when in index.json [NOT STARTED]

**Goal**: Update both `state-management-schema.md` and `state-management.md` entries in `.claude/context/index.json` to include all task-creating commands and agents.

**Tasks**:
- [ ] Edit `state-management-schema.md` entry: set `commands` to `["/task", "/todo", "/review", "/fix-it", "/meta", "/spawn", "/errors"]`
- [ ] Edit `state-management-schema.md` entry: set `agents` to `["meta-builder-agent", "spawn-agent"]`
- [ ] Edit `state-management.md` entry: set `commands` to `["/task", "/todo", "/review", "/fix-it", "/meta", "/spawn", "/errors"]`
- [ ] Edit `state-management.md` entry: set `agents` to `["meta-builder-agent", "spawn-agent"]`
- [ ] Validate JSON syntax with `jq . .claude/context/index.json > /dev/null`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/index.json` - Update two `load_when` entries

**Verification**:
- `jq . .claude/context/index.json` parses without error
- `jq '.entries[] | select(.path | test("state-management")) | {path, load_when}' .claude/context/index.json` shows updated commands and agents arrays

### Phase 2: Add Schema Reference to review.md [NOT STARTED]

**Goal**: Add an explicit `@`-reference to `state-management-schema.md` in the `/review` command's task creation section so the entry format is unambiguous.

**Tasks**:
- [ ] Locate Section 5.6.3, Step 4 in `.claude/commands/review.md`
- [ ] Replace "Add task entry following existing format in TODO.md frontmatter section" with "Add task entry to TODO.md following the format in @.claude/context/reference/state-management-schema.md (see 'TODO.md Entry Format' section)"
- [ ] Verify the reference path is correct

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/review.md` - Update task creation instruction in Section 5.6.3

**Verification**:
- The updated text references the correct file path
- No other formatting is broken in review.md

## Testing & Validation

- [ ] `jq . .claude/context/index.json` succeeds (valid JSON)
- [ ] Context query for `/review` returns both state-management files: `jq -r --arg cmd "/review" '.entries[] | select(any(.load_when.commands[]?; . == $cmd)) | .path' .claude/context/index.json | grep state-management`
- [ ] Context query for `/fix-it`, `/meta`, `/spawn`, `/errors` each returns both files
- [ ] `grep -c "state-management-schema" .claude/commands/review.md` returns at least 1

## Artifacts & Outputs

- `plans/01_widen-load-when.md` (this file)
- Modified `.claude/context/index.json` (two entries updated)
- Modified `.claude/commands/review.md` (one instruction updated)

## Rollback/Contingency

Revert with `git checkout HEAD -- .claude/context/index.json .claude/commands/review.md`. Both files are version-controlled and changes are isolated to specific entries/lines.
