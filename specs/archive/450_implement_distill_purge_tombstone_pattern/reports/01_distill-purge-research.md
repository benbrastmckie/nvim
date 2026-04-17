# Research Report: Task #450

**Task**: 450 - Implement distill purge operation with tombstone pattern
**Started**: 2026-04-16T22:00:00Z
**Completed**: 2026-04-16T22:30:00Z
**Effort**: medium
**Dependencies**: Task #449 (completed)
**Sources/Inputs**: Codebase exploration (distill.md command, SKILL.md mode=distill, memory-index.json, memory frontmatter, distill-log.json, task 449 research/plan)
**Artifacts**: specs/450_implement_distill_purge_tombstone_pattern/reports/01_distill-purge-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The scoring engine and health report from task 449 are fully implemented in SKILL.md `mode=distill`; the purge sub-mode is listed as a placeholder returning "not yet implemented"
- The purge operation requires four distinct components: candidate identification (scoring-based), interactive selection (AskUserQuestion multiSelect), tombstone application (frontmatter mutation), and `--gc` hard deletion (file removal after grace period)
- Tombstone pattern adds three frontmatter fields (`status: tombstoned`, `tombstoned_at`, `tombstone_reason`) without deleting files or removing index entries -- retrieval must be updated to skip tombstoned entries
- The `--gc` flag is a separate sub-mode that scans for tombstoned memories past a 7-day grace period and performs hard deletion with index regeneration
- A link-scan step must warn about `[[MEM-{slug}]]` references in non-tombstoned memories' Connections sections pointing to tombstoned entries
- All changes are confined to three files: SKILL.md (purge + gc sub-modes), distill.md (remove purge/gc placeholders), and distill-log.json (operation logging)

## Context & Scope

Task 450 extends the distill infrastructure created by task 449. The scoring engine already computes composite scores for each memory; this task uses those scores to identify purge candidates, present them interactively, and implement a soft-delete (tombstone) pattern. The `--gc` flag provides eventual hard deletion after a grace period.

### Scope Boundaries

**In scope**:
- Purge candidate identification using existing scoring engine output
- Category-aware TTL advisory thresholds for ranking
- Interactive selection via AskUserQuestion
- Tombstone frontmatter pattern (soft delete)
- Retrieval exclusion of tombstoned memories
- `--gc` sub-mode for hard deletion after 7-day grace period
- Link-scan for stale `[[MEM-{slug}]]` references
- Distill-log.json logging for purge and gc operations

**Out of scope**:
- Merge operation (task 451)
- Compress/refine operations (task 452)
- Integration with /todo (task 453)

## Findings

### 1. Current Distill Infrastructure (Task 449 Output)

The following infrastructure is already in place:

**distill.md command** (`.claude/extensions/memory/commands/distill.md`):
- Parses `--purge`, `--gc`, `--dry-run`, `--verbose` flags
- Routes to skill-memory `mode=distill, sub_mode={purge|gc|...}`
- Purge and gc are listed in the sub-mode dispatch table as "Placeholder (task 450)"
- Currently returns "not yet implemented" message for these sub-modes

**SKILL.md mode=distill section**:
- Scoring engine with four components: staleness (0.3), zero-retrieval (0.25), size (0.2), duplicate (0.25)
- Sub-mode dispatch table lists `purge` as placeholder for task 450 and `gc` as placeholder for task 452
- Maintenance candidate classification: composite >= 0.7 = purge candidate
- Health report template already displays purge candidates section

**distill-log.json** (`.memory/distill-log.json`):
- Schema supports `purge` and `gc` operation types
- Has `pre_metrics` / `post_metrics` structure for before/after tracking
- `affected_memories` array for recording which memories were affected
- Summary tracks `total_purged` counter

**memory-index.json** (`.memory/memory-index.json`):
- Contains all fields needed for scoring: created, modified, last_retrieved, retrieval_count, token_count, keywords
- Currently has 1 entry (MEM-plan-delegation-required)
- Validate-on-read pattern ensures consistency before scoring

**state.json memory_health field**:
- Already exists as top-level field with: last_distilled, distill_count, total_memories, never_retrieved, health_score, status

### 2. Purge Candidate Identification

The task description specifies two selection criteria:

```
Condition 1: zero_retrieval_penalty == 1.0
  (retrieval_count == 0 AND days_since_created > 30)

Condition 2: staleness_score > 0.8
  (days_since_last_retrieval > 72 days, pre-FSRS adjustment)
```

These are OR conditions -- a memory matching either is a purge candidate.

**Category-aware TTL advisory thresholds** (for ranking, not automatic action):

| Category | Advisory TTL | Rationale |
|----------|-------------|-----------|
| CONFIG | 180 days | Config knowledge becomes stale with version changes |
| WORKFLOW | 365 days | Process knowledge changes slowly |
| PATTERN | 540 days | Design patterns are long-lived |
| TECHNIQUE | 270 days | Techniques evolve moderately |
| INSIGHT | no TTL | Insights are timeless |

These thresholds modify the presentation order: memories closer to or past their category TTL are ranked higher in the interactive selection. They do NOT trigger automatic purging.

**Implementation note**: The category field is derived from the first tag in the memory's frontmatter `tags` array (already available in memory-index.json as `category`). The INSIGHT category has no TTL, meaning those memories are always ranked lower among purge candidates.

### 3. Interactive Selection Pattern

The task requires AskUserQuestion with multiSelect. Based on existing patterns in SKILL.md (directory mode file selection, task mode artifact selection):

```
AskUserQuestion({
  "question": "Select memories to tombstone:",
  "header": "Purge Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "MEM-{slug}",
      "description": "Score: {composite} | Created: {date} | Retrievals: {count} | Tokens: {tokens} | Category: {cat}"
    }
  ]
})
```

Options should be sorted by composite score descending (highest maintenance need first), with TTL-exceeded memories grouped at the top.

### 4. Tombstone Pattern Design

The tombstone pattern adds three fields to the memory's YAML frontmatter:

```yaml
status: tombstoned
tombstoned_at: 2026-04-16T22:00:00Z
tombstone_reason: "purge"
```

**Key design decisions**:

1. **File preserved**: The .md file stays in `.memory/10-Memories/` -- it is NOT moved or deleted
2. **Index preserved**: The entry stays in `memory-index.json` -- the index entry must be updated to reflect the tombstoned status
3. **Retrieval exclusion**: The scoring/retrieval pipeline must filter out entries where `status == "tombstoned"`

**Frontmatter field placement**: The `status`, `tombstoned_at`, and `tombstone_reason` fields should be added after the existing `summary` field and before `token_count`. This keeps metadata fields grouped logically.

**memory-index.json schema extension**: The index entry needs a `status` field. Currently the schema (from SKILL.md JSON Index Maintenance section) does not include `status`. This is a schema addition:

```json
{
  "id": "MEM-plan-delegation-required",
  "path": ".memory/10-Memories/MEM-plan-delegation-required.md",
  "status": "active",
  ...
}
```

Default value for existing entries without explicit status: `"active"`. Tombstoned entries get `"tombstoned"`.

### 5. Retrieval Exclusion Updates

Two retrieval paths need tombstone filtering:

1. **MCP Search Path** (SKILL.md Memory Search section): After results are returned, filter out any result whose memory-index.json entry has `status: "tombstoned"`. This is a post-filter, not a pre-filter.

2. **Grep Fallback Path** (SKILL.md Memory Search section): After grep finds matching files, check each file's frontmatter for `status: tombstoned` and exclude from results.

3. **Health Report** (SKILL.md mode=distill report sub-mode): Tombstoned memories should be listed separately, not mixed with active memories in the health report. Add a "Tombstoned Memories" section showing count and list.

4. **Scoring Engine**: Tombstoned memories should be excluded from composite scoring (they are already "resolved" maintenance candidates).

### 6. GC (Garbage Collection) Sub-Mode

The `--gc` flag implements hard deletion for tombstoned memories past the grace period.

**Grace period**: 7 days from `tombstoned_at` timestamp.

**Workflow**:
1. Scan memory-index.json for entries with `status: "tombstoned"`
2. Filter to those where `tombstoned_at` is older than 7 days
3. Present eligible memories via AskUserQuestion for confirmation (not multiSelect -- a single yes/no confirmation for the batch)
4. On confirmation:
   a. Delete the `.md` file from `.memory/10-Memories/`
   b. Remove the entry from `memory-index.json`
   c. Regenerate `index.md` and `.memory/10-Memories/README.md`
   d. Update `memory_health` in state.json (decrement total_memories)
5. Log to distill-log.json with type "gc"

**Design question -- gc confirmation pattern**: The task says "Present list via AskUserQuestion for confirmation." This could be:
- (a) Single yes/no confirmation for the entire batch
- (b) multiSelect to choose which tombstoned memories to permanently delete

Recommendation: Use (b) multiSelect for consistency with the purge selection pattern. Users may want to keep some tombstoned memories in grace period longer.

**Note on --gc scope**: The task description says `--gc` is for purge-related garbage collection only. Task 452 lists gc as "purge + merge + compress" combined. The task 450 implementation should handle gc for purge (tombstone cleanup) only. Task 452 can extend gc to also run merge and compress.

### 7. Link-Scan Step

After tombstoning, scan all non-tombstoned memories for references to the newly tombstoned memories.

**Pattern to search**: `[[MEM-{affected-slug}]]` in `## Connections` sections.

**Implementation**:
```bash
for slug in ${tombstoned_slugs}; do
  grep -l "\[\[${slug}\]\]" .memory/10-Memories/MEM-*.md 2>/dev/null | \
    while read file; do
      # Check if the referencing file is NOT tombstoned itself
      if ! grep -q "^status: tombstoned" "$file"; then
        echo "Warning: ${file} references tombstoned memory ${slug}"
      fi
    done
done
```

Warnings should be displayed to the user after the tombstone operation completes. No automatic modification of the referencing files.

### 8. Distill-Log Entries for Purge and GC

**Purge operation log entry**:
```json
{
  "id": "distill_{timestamp}",
  "timestamp": "2026-04-16T22:00:00Z",
  "type": "purge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 3000,
    "health_score": 65,
    "purge_candidates": 3,
    "merge_candidates": 1,
    "compress_candidates": 0
  },
  "post_metrics": {
    "total_memories": 10,
    "total_tokens": 3000,
    "health_score": 65,
    "purge_candidates": 0,
    "merge_candidates": 1,
    "compress_candidates": 0
  },
  "affected_memories": ["MEM-stale-config", "MEM-old-technique"],
  "notes": "Tombstoned 2 memories. Stale links found: MEM-related-pattern references MEM-stale-config"
}
```

Note: For purge (tombstone), `total_memories` and `total_tokens` remain unchanged in post_metrics since files are not deleted. The `purge_candidates` count drops because tombstoned memories are excluded from scoring.

**GC operation log entry**:
```json
{
  "id": "distill_{timestamp}",
  "timestamp": "2026-04-16T22:00:00Z",
  "type": "gc",
  "session_id": "sess_...",
  "pre_metrics": { "total_memories": 10, "total_tokens": 3000, ... },
  "post_metrics": { "total_memories": 8, "total_tokens": 2400, ... },
  "affected_memories": ["MEM-stale-config", "MEM-old-technique"],
  "notes": "Hard-deleted 2 tombstoned memories past 7-day grace period"
}
```

### 9. Files to Modify

| File | Change | Scope |
|------|--------|-------|
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Add purge sub-mode, gc sub-mode, tombstone pattern, retrieval exclusion, link-scan | Major (new sections in mode=distill) |
| `.claude/extensions/memory/commands/distill.md` | Update purge and gc from "Placeholder" to "Available (task 450)" in dispatch table | Minor (status update) |
| `.memory/memory-index.json` | Add `status` field to schema (default: "active") | Minor (schema extension) |

### 10. Memory Template Considerations

The memory template at `.memory/30-Templates/memory-template.md` currently has these frontmatter fields:
```yaml
title, created, tags, topic, source, modified,
retrieval_count, last_retrieved, keywords, summary, token_count
```

The tombstone fields (`status`, `tombstoned_at`, `tombstone_reason`) are NOT part of the template because they are added only during purge operations, not during memory creation. New memories default to `status: active` implicitly (absence of status field = active).

However, the validate-on-read and index regeneration procedures should handle the absence of `status` gracefully: if `status` is not present in frontmatter, treat as "active".

## Decisions

1. **Tombstone over move-to-trash**: The task explicitly specifies tombstone-in-place (frontmatter mutation) rather than moving files to a trash directory. This preserves file paths and simplifies the gc step (just delete the file).

2. **memory-index.json status field**: Add `status` field to index entries. Default "active" for entries without explicit status. Tombstoned entries get "tombstoned". This enables O(1) filtering without reading each .md file.

3. **GC uses multiSelect**: Use multiSelect for gc confirmation (consistent with purge pattern) rather than batch yes/no.

4. **GC scope limited to purge cleanup**: Task 450 gc only handles tombstone cleanup. Task 452 extends gc to include merge and compress operations.

5. **Category TTL is advisory only**: TTL thresholds affect ranking in the selection list, not automatic purging. INSIGHT category has no TTL.

6. **Retrieval exclusion is post-filter**: Rather than modifying the search algorithms, tombstoned memories are filtered out of results after search completes. This is simpler and less invasive.

7. **Link warnings are display-only**: Stale link warnings are shown to the user but no automatic modification of referencing memories occurs.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tombstoned memory accidentally retrieved | User gets stale/irrelevant content | Post-filter on status field in both MCP and grep search paths |
| Index regeneration drops status field | Tombstone state lost | Update JSON Index Maintenance procedure to include status field |
| Grace period too short (7 days) | User regrets hard deletion | Grace period is enforced; gc requires explicit confirmation |
| Link-scan misses non-standard reference formats | Stale links not detected | Only `[[MEM-{slug}]]` format is scanned; document this limitation |
| Large vault makes pairwise scoring slow during purge | Slow candidate identification | Scoring is already computed by the existing engine; purge just filters results |

## Context Extension Recommendations

- **Topic**: Memory tombstone lifecycle
- **Gap**: No documentation exists for the tombstone state transitions (active -> tombstoned -> deleted)
- **Recommendation**: After implementation, the tombstone lifecycle should be documented in the memory extension's context files for future reference by agents performing retrieval

## Appendix

### Search Queries Used

1. `Read .claude/extensions/memory/commands/distill.md` -- Current command file with placeholder sub-modes
2. `Read .claude/extensions/memory/skills/skill-memory/SKILL.md` -- Full skill with mode=distill scoring engine
3. `Read .memory/memory-index.json` -- Current index schema and entries
4. `Read .memory/10-Memories/MEM-plan-delegation-required.md` -- Memory frontmatter structure
5. `Read .memory/30-Templates/memory-template.md` -- Template fields
6. `Read .memory/distill-log.json` -- Current log schema (empty operations)
7. `Read .memory/20-Indices/index.md` -- Index structure
8. `Read specs/449_create_distill_command_scoring_engine_health_report/reports/01_distill-command-research.md` -- Task 449 research findings
9. `Read specs/449_create_distill_command_scoring_engine_health_report/plans/01_distill-command-plan.md` -- Task 449 implementation plan
10. `Grep TODO.md for task 450` -- Full task description and dependency chain

### Downstream Dependencies

```
449 (completed) -- scoring engine, health report
  |
  +-- 450 (this task) -- purge + tombstone + gc
  |     |
  |     +-- 452 -- extends gc to include merge + compress
  |
  +-- 451 -- combine/merge
```

Task 453 (integrate with /todo) depends on tombstone filtering being in place so that /todo memory harvest suggestions exclude tombstoned memories.
