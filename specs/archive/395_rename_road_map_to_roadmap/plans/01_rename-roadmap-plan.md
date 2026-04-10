# Implementation Plan: Rename ROAD_MAP.md to ROADMAP.md

- **Task**: 395 - Rename ROAD_MAP.md to ROADMAP.md
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/395_rename_road_map_to_roadmap/reports/01_rename-roadmap-research.md
- **Artifacts**: plans/01_rename-roadmap-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Rename all references from `ROAD_MAP.md` to `ROADMAP.md` across 36 files in `.claude/` and `.opencode/` directories, and add "ensure file exists" logic so the roadmap file is auto-created with a default template when commands like `/todo` and `/review` reference it. Neither `specs/ROAD_MAP.md` nor `specs/ROADMAP.md` currently exists, so the rename is purely a reference update with no actual file to move.

### Research Integration

Research identified 36 files requiring string replacement across 8 categories: delegation context injection points (4 skill files), agent files (4), command files (2), skill files (1), context/documentation files (10), extension agent files (3), and OpenCode mirror files (13). Additionally, 3 files need "ensure exists" logic added. Archived specs are excluded as historical records.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (file does not exist yet -- this task will establish the correct filename convention).

## Goals & Non-Goals

**Goals**:
- Replace all `ROAD_MAP.md` references with `ROADMAP.md` across `.claude/` and `.opencode/`
- Add auto-creation logic so `specs/ROADMAP.md` is created from a template when commands need it
- Maintain consistency between `.claude/` and `.opencode/` systems

**Non-Goals**:
- Modifying archived specs or historical task artifacts
- Creating the actual `specs/ROADMAP.md` file (auto-creation logic handles this at runtime)
- Changing roadmap format or structure (only the filename)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing a reference causes broken path | M | L | Research grep was comprehensive; verify with post-change grep |
| OpenCode files drift from Claude files | L | L | Update both systems in the same phase |
| Auto-creation template has wrong format | L | L | Base template on roadmap-format.md standard |
| Regex patterns in commands break | M | L | Test grep/regex patterns that reference the filename |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Claude System References [COMPLETED]

**Goal**: Replace all `ROAD_MAP.md` references with `ROADMAP.md` in `.claude/` files (23 files).

**Tasks**:
- [ ] Update 4 delegation context injection points in skill files:
  - `.claude/skills/skill-researcher/SKILL.md`
  - `.claude/skills/skill-planner/SKILL.md`
  - `.claude/skills/skill-reviser/SKILL.md`
  - `.claude/skills/skill-team-research/SKILL.md`
- [ ] Update 4 agent files:
  - `.claude/agents/general-research-agent.md`
  - `.claude/agents/planner-agent.md`
  - `.claude/agents/general-implementation-agent.md`
  - `.claude/agents/reviser-agent.md`
- [ ] Update 2 command files:
  - `.claude/commands/todo.md`
  - `.claude/commands/review.md`
- [ ] Update 1 skill file:
  - `.claude/skills/skill-todo/SKILL.md`
- [ ] Update 10 context and documentation files:
  - `.claude/context/formats/roadmap-format.md`
  - `.claude/context/formats/task-order-format.md`
  - `.claude/context/formats/return-metadata-file.md`
  - `.claude/context/patterns/roadmap-update.md`
  - `.claude/context/reference/state-management-schema.md`
  - `.claude/context/core-index-entries.json`
  - `.claude/context/index.json`
  - `.claude/CLAUDE.md`
  - `.claude/docs/guides/user-guide.md`
  - `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`
- [ ] Update 3 extension agent files:
  - `.claude/extensions/nix/agents/nix-implementation-agent.md`
  - `.claude/extensions/nvim/agents/neovim-implementation-agent.md`
  - `.claude/extensions/web/agents/web-implementation-agent.md`

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- All 23 `.claude/` files listed above -- string replacement `ROAD_MAP.md` -> `ROADMAP.md`

**Verification**:
- `grep -r "ROAD_MAP\.md" .claude/` returns zero results
- No broken references in skill delegation contexts

---

### Phase 2: Update OpenCode Mirror References [COMPLETED]

**Goal**: Replace all `ROAD_MAP.md` references with `ROADMAP.md` in `.opencode/` files (13 files).

**Tasks**:
- [ ] Update 2 command files:
  - `.opencode/commands/todo.md`
  - `.opencode/commands/review.md`
- [ ] Update 1 skill file:
  - `.opencode/skills/skill-todo/SKILL.md`
- [ ] Update 6 context/documentation files:
  - `.opencode/docs/guides/user-guide.md`
  - `.opencode/rules/state-management.md`
  - `.opencode/context/core/formats/roadmap-format.md`
  - `.opencode/context/core/formats/return-metadata-file.md`
  - `.opencode/context/core/patterns/roadmap-update.md`
  - `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md`
- [ ] Update 4 agent files:
  - `.opencode/agent/subagents/general-implementation-agent.md`
  - `.opencode/extensions/nix/agents/nix-implementation-agent.md`
  - `.opencode/extensions/nvim/agents/neovim-implementation-agent.md`
  - `.opencode/extensions/web/agents/web-implementation-agent.md`

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- All 13 `.opencode/` files listed above -- string replacement `ROAD_MAP.md` -> `ROADMAP.md`

**Verification**:
- `grep -r "ROAD_MAP\.md" .opencode/` returns zero results

---

### Phase 3: Add Ensure-File-Exists Logic [COMPLETED]

**Goal**: Add auto-creation logic so `specs/ROADMAP.md` is created with a default template when commands reference it and it does not exist.

**Tasks**:
- [ ] Add existence check and template creation to `.claude/skills/skill-todo/SKILL.md` (Stage 5: ScanRoadmap) -- before reading the roadmap, check if `specs/ROADMAP.md` exists; if not, create it with default template
- [ ] Add existence check and template creation to `.claude/commands/todo.md` -- before grep commands that search the roadmap file (around line 196/209 area)
- [ ] Add existence check and template creation to `.claude/commands/review.md` -- in Section 2.5 (Roadmap Integration), before parsing
- [ ] Define the default template inline (based on roadmap-format.md):
  ```markdown
  # Project Roadmap

  ## Phase 1: Current Priorities (High Priority)

  - [ ] (No items yet -- add roadmap items here)

  ## Success Metrics

  - (Define success metrics here)
  ```
- [ ] Replicate ensure-exists logic in corresponding `.opencode/` files:
  - `.opencode/skills/skill-todo/SKILL.md`
  - `.opencode/commands/todo.md`
  - `.opencode/commands/review.md`

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` -- add existence check before roadmap read
- `.claude/commands/todo.md` -- add existence check before roadmap grep
- `.claude/commands/review.md` -- add existence check before roadmap parse
- `.opencode/skills/skill-todo/SKILL.md` -- mirror ensure-exists logic
- `.opencode/commands/todo.md` -- mirror ensure-exists logic
- `.opencode/commands/review.md` -- mirror ensure-exists logic

**Verification**:
- Confirm ensure-exists pattern is present in all 6 files
- Template matches roadmap-format.md structure
- Read-only consumers (research/plan agents) remain unchanged

## Testing & Validation

- [ ] `grep -r "ROAD_MAP\.md" .claude/` returns zero results (excluding specs/archive)
- [ ] `grep -r "ROAD_MAP\.md" .opencode/` returns zero results
- [ ] `grep -r "ROADMAP\.md" .claude/` returns expected count (~23 references)
- [ ] All 4 skill delegation contexts pass `"roadmap_path": "specs/ROADMAP.md"`
- [ ] Ensure-exists logic is present in skill-todo, commands/todo.md, and commands/review.md for both systems
- [ ] No archived specs or historical reports were modified

## Artifacts & Outputs

- `specs/395_rename_road_map_to_roadmap/plans/01_rename-roadmap-plan.md` (this file)
- `specs/395_rename_road_map_to_roadmap/summaries/01_rename-roadmap-summary.md` (after implementation)

## Rollback/Contingency

All changes are string replacements and small logic additions. Rollback via `git revert` of the implementation commit(s). If partial rollback is needed, `ROADMAP.md` can be globally replaced back to `ROAD_MAP.md` with a single find-replace pass.
