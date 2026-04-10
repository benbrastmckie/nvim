# Implementation Summary: Task #395

- **Task**: 395 - Rename ROAD_MAP.md to ROADMAP.md
- **Status**: [COMPLETED]
- **Started**: 2026-04-10T00:00:00Z
- **Completed**: 2026-04-10T00:30:00Z
- **Effort**: ~30 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_rename-roadmap-plan.md, summaries/01_rename-roadmap-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md

## Overview

Renamed all references from `ROAD_MAP.md` to `ROADMAP.md` across 36 files in `.claude/` and `.opencode/` directories, and added auto-creation logic so `specs/ROADMAP.md` is created with a default template when commands like `/todo` and `/review` reference it.

## What Changed

- Replaced `ROAD_MAP.md` with `ROADMAP.md` in 23 `.claude/` files (skills, agents, commands, context, docs, extensions)
- Replaced `ROAD_MAP.md` with `ROADMAP.md` in 13 `.opencode/` files (commands, skills, docs, context, agents, extensions)
- Added ensure-file-exists logic with default roadmap template to 6 files:
  - `.claude/skills/skill-todo/SKILL.md` (Stage 5: ScanRoadmap)
  - `.claude/commands/todo.md` (Step 3.5: Scan Roadmap)
  - `.claude/commands/review.md` (Section 2.5: Roadmap Integration)
  - `.opencode/skills/skill-todo/SKILL.md` (Stage 5: ScanRoadmap)
  - `.opencode/commands/todo.md` (Roadmap Annotation section)
  - `.opencode/commands/review.md` (Step 3: Roadmap Integration)

## Decisions

- Used bulk `sed` replacement for efficiency given the large number of files
- Excluded archived specs (historical records) from changes
- Default template follows `roadmap-format.md` structure with Phase 1 placeholder and Success Metrics section
- `reviser-agent.md` was listed in the plan but did not contain any `ROAD_MAP.md` references; skipped appropriately

## Impacts

- All `/todo`, `/review`, and related commands now reference `specs/ROADMAP.md` instead of `specs/ROAD_MAP.md`
- Commands that read the roadmap will auto-create `specs/ROADMAP.md` if it does not exist
- Both `.claude/` and `.opencode/` systems are synchronized with the new filename

## Follow-ups

- None required; the rename is complete and auto-creation handles the missing file case

## References

- `specs/395_rename_road_map_to_roadmap/reports/01_rename-roadmap-research.md`
- `specs/395_rename_road_map_to_roadmap/plans/01_rename-roadmap-plan.md`
