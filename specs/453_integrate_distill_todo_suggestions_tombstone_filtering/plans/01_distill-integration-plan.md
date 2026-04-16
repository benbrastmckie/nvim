# Implementation Plan: Integrate /distill with /todo Suggestions and Retrieval Tombstone Filtering

- **Task**: 453 - Integrate /distill with /todo suggestions and retrieval tombstone filtering
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: Tasks #447, #452
- **Research Inputs**: specs/453_integrate_distill_todo_suggestions_tombstone_filtering/reports/01_distill-integration-research.md
- **Artifacts**: plans/01_distill-integration-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task connects the distillation subsystem (tasks 449-452) with the /todo output and memory retrieval pipeline. Three independent integration points need implementation: (1) conditional /distill suggestions appended to /todo Stage 16 output based on memory_health thresholds, (2) tombstone filtering in memory-retrieve.sh to exclude purged memories from retrieval scoring, and (3) a clarification in skill-memory SKILL.md to make distill_count increment conditional on non-report sub-modes.

### Research Integration

Research identified that all three changes are small and well-isolated. The key findings are: skill-todo SKILL.md has no existing suggestion mechanism (new logic needed in Stage 16), memory-retrieve.sh has no status filtering (single jq pre-filter addition), and the memory-index.json schema already supports the status field. The pre-filter approach for tombstone exclusion is preferred over post-filter to avoid scoring work on tombstoned entries.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is part of the memory system integration chain (tasks 444-454) which is infrastructure work.

## Goals & Non-Goals

**Goals**:
- Add conditional /distill suggestions to /todo output after archival summary
- Filter tombstoned memories from retrieval scoring in memory-retrieve.sh
- Clarify distill_count increment logic to exclude report-only invocations

**Non-Goals**:
- Fixing stale memory_health values in state.json (that is /distill's responsibility)
- Changing the memory-index.json schema (status field already exists)
- Adding new memory-index.json entries or modifying index regeneration logic (already handles status)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq null handling for absent status field | M | L | Use `(.status // "active") == "active"` pattern to default absent status to active |
| Nested threshold conditions in /todo may be hard to follow | M | M | Document the decision tree as a clear if/else block with inline comments |
| memory_health may not exist in state.json for older repos | L | L | Use `// {}` fallback when reading memory_health, suppress suggestions if absent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Tombstone Filtering in memory-retrieve.sh [COMPLETED]

**Goal**: Prevent tombstoned memories from being scored and returned during retrieval.

**Tasks**:
- [ ] Add a pre-filter stage in memory-retrieve.sh jq pipeline to exclude entries where status is "tombstoned"
- [ ] Use the safe pattern: `map(select((.status // "active") == "active"))` before the scoring map
- [ ] Verify the filter handles entries with no status field (defaults to "active")

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/memory-retrieve.sh` - Add pre-filter before scoring jq query (around line 74-98)

**Verification**:
- The jq pipeline includes a status filter before scoring
- Entries without a status field are treated as active (not filtered)
- Entries with `status: "tombstoned"` are excluded before scoring

---

### Phase 2: Conditional /distill Suggestions in skill-todo [COMPLETED]

**Goal**: Append numbered "Suggested Next Steps" to /todo output based on memory_health state.

**Tasks**:
- [ ] Add a new sub-section to Stage 16 (OutputResults) in skill-todo SKILL.md after existing display
- [ ] Document reading memory_health from state.json with fallback for absent field
- [ ] Implement threshold-based suggestion logic:
  - Always suggest reviewing the archive (unconditional)
  - Suppress all /distill suggestions when total_memories < 5
  - Suggest `/distill --report` when total_memories >= 10
  - Suggest `/distill` (full interactive) when ANY of: total_memories >= 30, never_retrieved/total_memories > 0.5 (and >= 5 memories), last_distilled null/stale > 30d (and >= 10 memories)
- [ ] Format as numbered list with memory vault stats: `N. Run /distill to maintain memory vault ({N} memories, {health_score}/100 health)`

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add "Suggested Next Steps" logic to Stage 16

**Verification**:
- Stage 16 includes the new suggestion sub-section
- Threshold logic matches task description exactly
- Suggestions are suppressed when total_memories < 5
- memory_health absence is handled gracefully (no suggestions, no error)

---

### Phase 3: Distill State Tracking Clarification and Validation [COMPLETED]

**Goal**: Make distill_count increment conditional on non-report sub-modes and validate all three integration points.

**Tasks**:
- [ ] Update the State Integration section in skill-memory SKILL.md to add conditional: `distill_count` increments only when sub_mode is not "report"
- [ ] Add explicit note that bare `/distill` (health report only) updates last_distilled timestamp but does NOT increment distill_count
- [ ] Cross-verify: confirm memory-retrieve.sh tombstone filter is consistent with the Retrieval Exclusion sections already documented in skill-memory SKILL.md
- [ ] Cross-verify: confirm /todo suggestion thresholds match the memory_health schema fields in state.json

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Clarify distill_count conditional in State Integration section (around lines 2000-2017)

**Verification**:
- State Integration section explicitly states distill_count does not increment for report sub-mode
- The three integration points (retrieve filter, /todo suggestions, state tracking) are internally consistent
- No contradictions between skill-memory SKILL.md and the changes in phases 1-2

## Testing & Validation

- [ ] Read memory-retrieve.sh and confirm the pre-filter excludes tombstoned entries
- [ ] Read skill-todo SKILL.md Stage 16 and confirm suggestion logic matches all threshold conditions
- [ ] Read skill-memory SKILL.md State Integration section and confirm distill_count conditional
- [ ] Verify jq pattern uses safe `// "active"` fallback (not bare `.status` comparison)
- [ ] Verify no `!=` operator usage in any jq additions (use `| not` pattern)

## Artifacts & Outputs

- `specs/453_integrate_distill_todo_suggestions_tombstone_filtering/plans/01_distill-integration-plan.md` (this file)
- `specs/453_integrate_distill_todo_suggestions_tombstone_filtering/summaries/01_distill-integration-summary.md` (after implementation)

## Rollback/Contingency

All changes are additive to SKILL.md documentation and a single jq filter addition to memory-retrieve.sh. Reverting is straightforward: remove the added sections from skill-todo SKILL.md, remove the pre-filter line from memory-retrieve.sh, and revert the State Integration clarification in skill-memory SKILL.md. No destructive operations or schema changes are involved.
