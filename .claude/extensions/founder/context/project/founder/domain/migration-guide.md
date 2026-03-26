# Founder Extension Migration Guide

## Breaking Changes from v2.x

1. **`/project` no longer generates timelines directly** - Use `/research N -> /plan N -> /implement N` for the full lifecycle. The `/project` command now creates a task and optionally runs research only.
2. **TRACK and REPORT modes move to `/implement` phase** - These modes are now handled during implementation, not directly by the `/project` command.
3. **project-agent output is now a research report** - Previously generated a Typst timeline file directly. Now creates a research report at `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`.
4. **skill-project sets `researched` status** - Previously set `planned`. Now follows the standard research -> plan -> implement lifecycle.

## Migration from v2.1

| v2.1 Pattern | v3.0 Equivalent |
|--------------|-----------------|
| `/project 234` -> generates timeline directly | `/project 234` -> research only, then `/plan 234` -> `/implement 234` |
| project-agent creates Typst file | project-agent creates research report |
| TRACK/REPORT via `/project {N}` | TRACK/REPORT via `/implement {N}` |
| skill-project -> status: planned | skill-project -> status: researched |

## Migration from v2.0

| v2.0 Pattern | v3.0 Equivalent |
|--------------|-----------------|
| `/market "fintech"` -> task created -> /research asks questions | `/market "fintech"` -> questions asked -> task created with data |
| No task_type field | task_type: "market", "analyze", "strategy", "legal", or "project" |
| `/research` uses language routing | `/research` uses task_type routing when available |
| forcing_data gathered during research | forcing_data gathered at command invocation (STAGE 0) |

## Migration from v1.0

| v1.0 Pattern | v3.0 Equivalent |
|--------------|-----------------|
| `/market fintech` | `/market --quick fintech` (standalone) |
| | `/market "fintech analysis"` (task workflow with pre-task questions) |
| Artifact in `founder/` | Artifact in `strategy/` (task) or `founder/` (--quick) |
| No task tracking | Full task lifecycle with forcing_data storage |
