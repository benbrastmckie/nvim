# Implementation Summary: Task #393

- **Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
- **Status**: [COMPLETED]
- **Started**: 2026-04-10T17:00:00Z
- **Completed**: 2026-04-10T18:30:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**:
  - [01_team-research.md](../reports/01_team-research.md)
  - [01_unify-routing-field.md](../plans/01_unify-routing-field.md)
  - [01_unify-routing-summary.md](01_unify-routing-summary.md)
- **Standards**: summary-format.md, status-markers.md, artifact-management.md

## Overview

Renamed the `language` routing field to `task_type` throughout the entire agent system, simultaneously merging the old secondary `task_type` field into it. The unified `task_type` field uses bare values (`meta`, `general`, `neovim`) for core/simple types and compound format (`present:grant`, `founder:deck`) for extension sub-routing. Added backward compatibility shim (`.task_type // .language // "general"`) to support legacy tasks.

## What Changed

- Renamed `"language"` key to `"task_type"` in state.json for all 13 active projects
- Renamed `**Language**:` label to `**Task Type**:` in TODO.md for all tasks
- Updated CLAUDE.md: renamed Language-Based Routing to Task-Type-Based Routing, updated state.json example, updated context discovery jq queries
- Updated state-management-schema.md: merged language and task_type field documentation into unified task_type field
- Updated state-management.md rule: renamed language references
- Updated 8 core command files (task.md, research.md, plan.md, implement.md, todo.md, spawn.md, review.md, meta.md) with task_type routing and backward compat shim
- Updated skill-orchestrator routing description
- Updated 9 core skill files and 7 core agent files
- Updated 14 extension manifest.json files (top-level `"language"` to `"task_type"`)
- Updated 15 extension command files, 46 extension skill files, 31 extension agent files
- Renamed `load_when.languages` to `load_when.task_types` in index.json (96 entries)
- Updated 42 context files, 2 rules files, 17 docs files
- Updated validate-wiring.sh, validate-index.sh, install-extension.sh
- Updated .claude/README.md routing references

## Decisions

- Backward compat shim uses `.task_type // .language // "general"` pattern -- reads task_type first, falls back to language, defaults to general
- Shim removal is tracked as task 394 (created prior to this implementation)
- Context files with English prose "language" (e.g., "natural language", "language server") left unchanged
- Routing keys inside manifest.json routing objects (e.g., `"founder:deck"`) remain unchanged -- these are lookup values, not field names

## Impacts

- All commands now read `task_type` from state.json instead of `language`
- Context discovery queries use `load_when.task_types` instead of `load_when.languages`
- Extension manifests use `"task_type"` as the top-level field
- Legacy tasks with old `language` field continue to work via backward compat shim until task 394

## Follow-ups

- Task 394: Remove backward compatibility shim once all legacy tasks are archived

## References

- `specs/393_unify_routing_field_language_task_type/reports/01_team-research.md`
- `specs/393_unify_routing_field_language_task_type/plans/01_unify-routing-field.md`
- `.claude/context/reference/state-management-schema.md`
