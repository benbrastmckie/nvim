# Summary Artifact Standard

**Scope:** Implementation summaries, plan summaries, research summaries, and project rollups produced by /implement, /plan, /research, /review, and related agents.

## Metadata (required)
- **Task**: `{id} - {title}`
- **Status**: `[NOT STARTED]` | `[IN PROGRESS]` | `[BLOCKED]` | `[ABANDONED]` | `[COMPLETED]`
- **Started**: `{ISO8601}` when summary drafting begins
- **Completed**: `{ISO8601}` when published
- **Effort**: `{estimate}` (time to produce summary)
- **Priority**: `High | Medium | Low`
- **Dependencies**: `{list or None}`
- **Artifacts**: list of linked artifacts summarized
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file

## Structure
1. **Overview** – 2-3 sentences on scope and context.
2. **What Changed** – bullets of key changes/deltas.
3. **Decisions** – bullets of decisions made.
4. **Impacts** – bullets on downstream effects.
5. **Follow-ups** – bullets with owners/due dates if applicable.
6. **References** – paths to artifacts informing the summary.

## Status Marker Usage
- Mark summary status and include Started/Completed timestamps.
- Avoid emojis; rely on text markers only.

## Writing Guidance
- Keep concise (<= 1 page).
- Use bullet lists for clarity.
- Reflect status of underlying work accurately.
- Lazy directory creation: create `summaries/` only when writing this file.

## Example Skeleton
```
# Implementation Summary: {title}
- **Task**: {id} - {title}
- **Status**: [COMPLETED]
- **Started**: 2025-12-22T10:00:00Z
- **Completed**: 2025-12-22T10:20:00Z
- **Artifacts**: plans/implementation-001.md

## Overview
...

## What Changed
- ...

## Decisions
- ...

## Impacts
- ...

## Follow-ups
- ...

## References
- ...
```
