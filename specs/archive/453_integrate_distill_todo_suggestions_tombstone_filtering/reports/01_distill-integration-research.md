# Research Report: Task #453

**Task**: 453 - Integrate /distill with /todo suggestions and retrieval tombstone filtering
**Started**: 2026-04-16T19:39:23Z
**Completed**: 2026-04-16T19:45:00Z
**Effort**: medium
**Dependencies**: Tasks #447, #452
**Sources/Inputs**: Codebase exploration (skill-todo SKILL.md, skill-memory SKILL.md, memory-retrieve.sh, distill.md, state.json, memory-index.json)
**Artifacts**: specs/453_integrate_distill_todo_suggestions_tombstone_filtering/reports/01_distill-integration-research.md
**Standards**: report-format.md

## Executive Summary

- Three independent integration points need implementation: (1) /todo conditional suggestions, (2) memory-retrieve.sh tombstone filtering, (3) memory_health state tracking consistency
- skill-todo SKILL.md currently has NO reference to distill or memory_health -- the suggestion logic must be added as a new stage or appended to Stage 16 (OutputResults)
- memory-retrieve.sh has NO tombstone filtering -- a single jq filter addition at the scoring phase (line 98) will exclude tombstoned entries
- memory-index.json schema already supports the `status` field (documented in skill-memory SKILL.md), but the current sole entry lacks it (defaults to "active" when absent)
- state.json already has `memory_health` at top-level with correct structure; /distill auto sub-mode already documents updating it

## Context & Scope

Task 453 connects two subsystems that were built independently:
1. **Self-learning memory** (tasks 444-448): /learn, memory-retrieve.sh, memory_candidates in /todo harvest
2. **Distillation** (tasks 449-452): /distill scoring, purge/tombstone, merge, compress, refine, gc

The integration has three work items:
- Wire /todo output to suggest /distill based on memory_health conditions
- Filter tombstoned memories from retrieval (memory-retrieve.sh)
- Ensure memory_health updates are consistent across all /distill sub-modes

## Findings

### 1. skill-todo SKILL.md -- Output Section Analysis

**Current Stage 16 (OutputResults)** displays archival counts only:
- Archived tasks (completed/abandoned)
- Directory operations (orphans tracked/misplaced moved)
- Updates applied (roadmap/readme/changelog)
- Memory harvest with tier breakdown
- Active tasks remaining

**Gap**: No "Next Steps" or conditional suggestions section exists. The task description specifies adding numbered suggestions after the summary output.

**Insertion point**: After Stage 16's existing display, add a new sub-section "Suggested Next Steps" that:
1. Reads `memory_health` from state.json (the field already exists at top-level)
2. Applies conditional logic per task description thresholds
3. Formats as numbered list

**Key thresholds from task description**:
- Always: suggest reviewing the archive
- `total_memories >= 10`: suggest `/distill --report`
- `total_memories >= 30` OR `never_retrieved/total_memories > 0.5` (when >= 5) OR `last_distilled` null/stale (>30d when >= 10): suggest `/distill`
- `total_memories < 5`: suppress all /distill suggestions

### 2. memory-retrieve.sh -- Tombstone Filtering Gap

**Current retrieval flow** (memory-retrieve.sh):
1. Phase 0: Validate index exists
2. Phase 1: Extract keywords, score entries via jq (keyword overlap + topic bonus)
3. Phase 2: Greedy selection within token budget, read files, output `<memory-context>` block

**Gap**: The jq scoring query on lines 74-99 iterates ALL `.entries` without filtering by status. Tombstoned entries will be scored and potentially returned.

**Fix location**: Line 98 in the jq pipeline. Currently:
```
) | map(select(.score >= 1)) | sort_by(-.score)
```

Needs to become:
```
) | map(select(.score >= 1 and (.status == "tombstoned" | not))) | sort_by(-.score)
```

This is a single-line change. Uses the safe `| not` pattern per the jq escaping workaround documented in CLAUDE.md.

**Alternative**: Add a pre-filter before scoring:
```
.entries // [] | map(select((.status // "active") == "active")) | map(...)
```

The pre-filter approach is cleaner (avoids scoring work on tombstoned entries).

### 3. memory-index.json Schema -- Status Field

**Current schema** (from skill-memory SKILL.md JSON Index Maintenance section, line 514):
```
| status | string | Frontmatter `status` (default: "active" when absent; "tombstoned" for purged memories) |
```

The schema already defines the `status` field. The index regeneration logic in skill-memory SKILL.md (lines 473-484) already reads `status` from frontmatter and defaults to "active" when absent.

**Current memory-index.json** (1 entry): Does not include `status` field explicitly. This is correct -- the skill-memory docs say "default: active when absent."

**No schema changes needed**: The status field is already defined. The only change is in memory-retrieve.sh to filter on it.

### 4. skill-memory SKILL.md -- Distill State Integration

**Auto sub-mode** (lines 1857-1879) already documents:
```
5. Update memory_health in state.json:
   - Recalculate health_score
   - Update last_distilled timestamp
   - Increment distill_count
```

**State Integration section** (lines 2000-2017) documents the memory_health update after "each distill operation."

**Gap analysis**: The task description says to "ensure `/distill` updates `memory_health` in state.json after every invocation." The SKILL.md already has the State Integration section documenting this. However, the `distill_count` increment should only happen "for non-bare invocations that perform operations" (not for `report` sub-mode). This nuance needs to be made explicit.

**Specific clarification needed**: The task says `distill_count` should increment "only for non-bare invocations that perform operations." Currently the State Integration section says "after each distill operation" without distinguishing report-only vs. mutating operations. This needs a conditional:
```
if sub_mode != "report":
  increment distill_count
```

### 5. state.json -- Current memory_health State

Current value:
```json
"memory_health": {
  "last_distilled": null,
  "distill_count": 0,
  "total_memories": 1,
  "never_retrieved": 1,
  "health_score": 100,
  "status": "healthy"
}
```

This is consistent with the schema in SKILL.md. The `never_retrieved` count of 1 is actually incorrect (the sole memory has `retrieval_count: 2`), but fixing stale data is outside this task's scope -- the fix is to ensure /distill updates it correctly.

### 6. Retrieval Exclusion -- Already Documented in SKILL.md

The skill-memory SKILL.md already has detailed "Retrieval Exclusion" sections (lines 2256-2318) for:
- MCP Search Path Exclusion (post-filter)
- Grep Fallback Path Exclusion (frontmatter check)
- Scoring Engine Exclusion (skip before computing)

However, these are documented **within skill-memory** (for the /learn and /distill workflows). The **memory-retrieve.sh script** (used by skill-researcher, skill-planner, skill-implementer) does NOT implement these filters. This is the actual gap.

### 7. Files to Modify (Confirmed)

Per the task description and research:

| File | Change Type | Description |
|------|------------|-------------|
| `.claude/skills/skill-todo/SKILL.md` | Add section | New "Suggested Next Steps" logic in Stage 16 |
| `.claude/scripts/memory-retrieve.sh` | Modify | Add tombstone filter to jq scoring query |
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Clarify | Make `distill_count` increment conditional on sub_mode |

**Not needed** (already correct):
- `memory-index.json` schema: status field already defined
- `state.json` structure: memory_health already exists
- Index regeneration: already reads status from frontmatter

## Decisions

1. **Tombstone filter placement**: Pre-filter approach (before scoring) rather than post-filter, to avoid unnecessary computation on tombstoned entries
2. **Suggestion placement in skill-todo**: Append to Stage 16 output rather than creating a separate new stage, keeping the change minimal
3. **No memory-index.json schema changes**: The status field is already fully documented

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| jq `| not` pattern may behave unexpectedly with null status | Low | Use `(.status // "active") == "active"` pattern instead of `(.status == "tombstoned" \| not)` to handle both absent and explicit values |
| memory_health values in state.json may be stale when /todo reads them | Low | /todo reads whatever is current -- /distill is responsible for keeping it updated |
| Threshold logic in /todo may be confusing with nested conditions | Medium | Document the decision tree clearly as a comment block in the SKILL.md |

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/skills/skill-todo/SKILL.md` -- Full 748-line skill definition, 16 stages
- `/home/benjamin/.config/nvim/.claude/scripts/memory-retrieve.sh` -- 165-line bash script, two-phase retrieval
- `/home/benjamin/.config/nvim/.claude/extensions/memory/skills/skill-memory/SKILL.md` -- 2466-line skill with distill mode
- `/home/benjamin/.config/nvim/.claude/extensions/memory/commands/distill.md` -- Command routing for /distill
- `/home/benjamin/.config/nvim/.memory/memory-index.json` -- Current index with 1 entry
- `/home/benjamin/.config/nvim/specs/state.json` -- Current state with memory_health field
- `/home/benjamin/.config/nvim/specs/TODO.md` -- Full task description for 453

### Key Code Locations

- **memory-retrieve.sh line 98**: jq `map(select(.score >= 1))` -- needs tombstone filter
- **skill-todo SKILL.md Stage 16**: OutputResults -- needs suggestion append
- **skill-memory SKILL.md lines 2000-2017**: State Integration section -- needs distill_count conditional
- **skill-memory SKILL.md line 514**: status field schema definition (already correct)
