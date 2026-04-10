# Research Report: Rename ROAD_MAP.md to ROADMAP.md

**Task**: 395 - Rename ROAD_MAP.md to ROADMAP.md and ensure auto-creation on reference
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:15:00Z
**Effort**: Small-medium (many files, simple find-replace + one new pattern)
**Dependencies**: None
**Sources/Inputs**: - Codebase grep for `ROAD_MAP.md`, `roadmap_path`, `ROADMAP`
**Artifacts**: - specs/395_rename_road_map_to_roadmap/reports/01_rename-roadmap-research.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- Neither `specs/ROAD_MAP.md` nor `specs/ROADMAP.md` currently exists in the repository
- 23 files under `.claude/` reference `ROAD_MAP.md` and need renaming to `ROADMAP.md`
- 13 files under `.opencode/` reference `ROAD_MAP.md` and need the same rename
- 4 skills pass `"roadmap_path": "specs/ROAD_MAP.md"` in delegation contexts -- these are the primary injection points
- No "ensure file exists" logic currently exists anywhere; agents silently skip when the file is missing
- The `/todo` and `/review` commands are the only writers of the roadmap file; research/plan agents are read-only consumers

## Context & Scope

The task requires two changes:
1. **Rename**: Replace all references from `ROAD_MAP.md` to `ROADMAP.md` across the codebase
2. **Ensure exists**: Add logic so that commands/skills that reference the roadmap file create it with a default template if it does not exist

Scope is limited to `.claude/` and `.opencode/` system files. Archived specs and historical reports are excluded from modification (they are historical records).

## Findings

### Category 1: Delegation Context Injection Points (roadmap_path)

These 4 skill files hardcode `"roadmap_path": "specs/ROAD_MAP.md"` in the JSON delegation context passed to agents. This is the primary source of the path -- agents receive it, they do not define it themselves.

| File | Line | Current Value |
|------|------|---------------|
| `.claude/skills/skill-researcher/SKILL.md` | 142 | `"roadmap_path": "specs/ROAD_MAP.md"` |
| `.claude/skills/skill-planner/SKILL.md` | 170 | `"roadmap_path": "specs/ROAD_MAP.md"` |
| `.claude/skills/skill-reviser/SKILL.md` | 215 | `"roadmap_path": "specs/ROAD_MAP.md"` |
| `.claude/skills/skill-team-research/SKILL.md` | 207 | `"roadmap_path": "specs/ROAD_MAP.md"` |

**Change**: Replace `specs/ROAD_MAP.md` with `specs/ROADMAP.md` in each.

### Category 2: Agent Files (read-only consumers)

These agents reference `ROAD_MAP.md` in documentation/instructions but receive the actual path via `roadmap_path` from delegation context.

| File | References |
|------|------------|
| `.claude/agents/general-research-agent.md` | Lines 65, 72 -- "typically `specs/ROAD_MAP.md`", "Modify, write to, or create ROAD_MAP.md" |
| `.claude/agents/planner-agent.md` | Lines 69, 76, 177 -- same pattern as research agent, plus plan template |
| `.claude/agents/general-implementation-agent.md` | Line 154 -- roadmap_items description |
| `.claude/agents/reviser-agent.md` | Line 20 -- context reference comment |

**Change**: Replace `ROAD_MAP.md` with `ROADMAP.md` in descriptive text.

### Category 3: Command Files (active readers/writers)

These commands contain the actual logic that reads/writes the roadmap file.

| File | Lines | Role |
|------|-------|------|
| `.claude/commands/todo.md` | 138, 158, 176, 196, 209, 237, 238, 245, 250, 635, 1180, 1184, 1193, 1237 | Primary writer -- matches tasks against roadmap, annotates completions |
| `.claude/commands/review.md` | 69, 103, 160, 1477, 1478 | Secondary writer -- parses roadmap, annotates completed items, git adds |

**Change**: Replace all `ROAD_MAP.md` with `ROADMAP.md`. These files also contain `grep` commands with hardcoded paths (lines 196, 209 in todo.md; lines 1477-1478 in review.md).

### Category 4: Skill Files (orchestration logic)

| File | Lines | Role |
|------|-------|------|
| `.claude/skills/skill-todo/SKILL.md` | 119, 124, 602 | Roadmap scanning and updating stages |

**Change**: Replace `ROAD_MAP.md` with `ROADMAP.md`.

### Category 5: Context and Documentation Files

| File | Reference Type |
|------|---------------|
| `.claude/context/formats/roadmap-format.md` | Line 3 -- Purpose description |
| `.claude/context/formats/task-order-format.md` | Line 294 -- cross-reference |
| `.claude/context/formats/return-metadata-file.md` | Line 142 -- field description |
| `.claude/context/patterns/roadmap-update.md` | Line 100 -- cross-reference |
| `.claude/context/reference/state-management-schema.md` | Line 167 -- field description |
| `.claude/context/core-index-entries.json` | Line 232 -- summary field |
| `.claude/context/index.json` | Line 392 -- summary field |
| `.claude/CLAUDE.md` | Line 131 -- completion workflow description |
| `.claude/docs/guides/user-guide.md` | Line 305 -- description |
| `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md` | Line 232 |

**Change**: Replace `ROAD_MAP.md` with `ROADMAP.md` in all descriptive text.

### Category 6: Extension Agent Files

| File | Line | Reference |
|------|------|-----------|
| `.claude/extensions/nix/agents/nix-implementation-agent.md` | 252 | roadmap_items description |
| `.claude/extensions/nvim/agents/neovim-implementation-agent.md` | 218 | roadmap_items description |
| `.claude/extensions/web/agents/web-implementation-agent.md` | 274 | roadmap_items description |

**Change**: Replace `ROAD_MAP.md` with `ROADMAP.md`.

### Category 7: OpenCode Mirror Files

The `.opencode/` directory mirrors much of `.claude/`. These 13 files also need updating:

| File | Role |
|------|------|
| `.opencode/commands/todo.md` | Roadmap references (lines 39, 87, 124, 133) |
| `.opencode/commands/review.md` | Roadmap references (lines 67, 108, 177, 223, 231) |
| `.opencode/skills/skill-todo/SKILL.md` | Scanning/updating stages (lines 174, 179, 351) |
| `.opencode/docs/guides/user-guide.md` | Description (line 297) |
| `.opencode/rules/state-management.md` | Field descriptions (lines 114, 124) |
| `.opencode/context/core/formats/roadmap-format.md` | Purpose description |
| `.opencode/context/core/formats/return-metadata-file.md` | Field description |
| `.opencode/context/core/patterns/roadmap-update.md` | Cross-reference |
| `.opencode/agent/subagents/general-implementation-agent.md` | roadmap_items description |
| `.opencode/extensions/nix/agents/nix-implementation-agent.md` | roadmap_items description |
| `.opencode/extensions/nvim/agents/neovim-implementation-agent.md` | roadmap_items description |
| `.opencode/extensions/web/agents/web-implementation-agent.md` | roadmap_items description |
| `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md` | Description |

### Category 8: Files Excluded from Changes

The following contain `ROAD_MAP.md` references but should NOT be modified:

- `specs/archive/**` -- Historical records, frozen
- `specs/393_*/**` -- Completed task reports, frozen
- `specs/382_*/**`, `specs/383_*/**`, etc. -- Historical task artifacts

### Where to Add "Ensure File Exists" Logic

Currently, no command creates `ROADMAP.md` if it is missing. The behavior is:
- **Research/plan agents**: Skip gracefully if file does not exist (correct behavior, but no file is ever created)
- **`/todo` command**: Reads roadmap for matching, silently gets no matches if file missing
- **`/review` command**: Has error handling -- "If ROAD_MAP.md doesn't exist or fails to parse, log warning and continue"

**Recommended locations for "ensure exists" logic**:

1. **`.claude/skills/skill-todo/SKILL.md`** -- Stage 5 (ScanRoadmap). Before reading the roadmap, check if it exists. If not, create it with a default template from `roadmap-format.md`. This is the most natural place because `/todo` is the primary roadmap writer.

2. **`.claude/commands/review.md`** -- Section 2.5 (Roadmap Integration). Before parsing, create with template if missing. The `/review` command already has error handling for missing roadmap, so this is a natural enhancement.

3. **`.claude/commands/todo.md`** -- Step 3.5 area. Add an existence check before the grep commands that search the roadmap file.

4. **Delegation context injection points** (skill-researcher, skill-planner, skill-reviser, skill-team-research) -- These could add a note that the roadmap should be created if missing, but since these agents are read-only consumers, it is better to have the writers (todo/review) handle creation.

**Recommended template** for auto-creation (based on `roadmap-format.md`):

```markdown
# Project Roadmap

## Phase 1: Current Priorities (High Priority)

- [ ] (No items yet -- add roadmap items here)

## Success Metrics

- (Define success metrics here)
```

## Decisions

- Archived specs and historical reports will NOT be modified
- The `.opencode/` mirror files will be updated alongside `.claude/` files
- "Ensure exists" logic should be added to `/todo` (primary writer) and `/review` (secondary writer)
- Research/plan agents should remain read-only consumers with graceful skip behavior
- A minimal default template will be used for auto-creation

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Missing a reference causes broken path | Low | Comprehensive grep already performed; use `replace_all` during implementation |
| OpenCode files diverge from Claude files | Low | Update both systems in the same implementation phase |
| Auto-created roadmap has wrong format | Low | Use format from `roadmap-format.md` standard |

## Appendix

### Search Queries Used

1. `grep -r "ROAD_MAP\.md"` across entire repository
2. `grep -r "roadmap_path"` in `.claude/` directory
3. `grep -r "ROAD_MAP\|ROADMAP"` for variant spellings
4. `grep -r "roadmap.*exist\|exist.*roadmap\|create.*roadmap"` for existing creation logic

### Complete File Change Summary

**Total files requiring changes**: 36 (23 in `.claude/`, 13 in `.opencode/`)

**Change type breakdown**:
- String replacement `ROAD_MAP.md` -> `ROADMAP.md`: All 36 files
- Add "ensure exists" logic: 3 files (skill-todo SKILL.md, commands/todo.md, commands/review.md)
