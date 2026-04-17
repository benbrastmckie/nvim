# Research Report: Task #451

**Task**: 451 - Implement distill combine operation with keyword superset guarantee
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:00:00Z
**Effort**: large
**Dependencies**: Task #449 (completed)
**Sources/Inputs**: Codebase exploration (distill.md, SKILL.md, memory-index.json, memory files, distill-log.json, TODO.md)
**Artifacts**: specs/451_implement_distill_combine_keyword_superset_guarantee/reports/01_distill-combine-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The merge sub-mode (`/distill --merge`) is currently a placeholder that returns "not yet implemented"
- All supporting infrastructure exists: the scoring engine (Component 4: Duplicate Score), distill-log.json schema, memory-index.json with keyword data, and the command dispatch framework
- The vault currently has only 1 memory, so merge logic must handle the edge case of insufficient memories gracefully
- The tombstone pattern from task 450 (sibling task, also RESEARCHING) is needed for secondary memory disposal; implementation should define the tombstone frontmatter independently since task 450 may not be completed first
- Keyword superset guarantee is the core invariant: `union(primary.keywords, secondary.keywords)` must be a subset of the merged memory's keywords field

## Context & Scope

Task 451 implements the COMBINE/MERGE operation for the `/distill --merge` command. This is one of four maintenance sub-modes (purge, merge, compress, refine) planned for the memory distillation system. The merge operation targets memories with high duplicate scores (keyword overlap > 60%) and combines them while preserving all keyword coverage.

The scope includes:
1. Merge candidate identification using pairwise keyword overlap
2. Interactive selection via AskUserQuestion per topic cluster
3. Merge execution with keyword superset enforcement
4. Tombstone pattern for secondary (absorbed) memories
5. Cross-reference updates across remaining memories
6. Index regeneration (memory-index.json, index.md, 10-Memories/README.md)
7. Logging to distill-log.json

## Findings

### Codebase Patterns

#### 1. Scoring Engine (Duplicate Score - Component 4)

Located in SKILL.md lines 1009-1019. The duplicate score is already computed during the `report` sub-mode:

```
for each other_memory in vault:
  overlap = |memory.keywords intersect other_memory.keywords| / |memory.keywords|
duplicate = max(overlap across all other memories)
```

Key observations:
- The overlap formula is asymmetric: `|A intersect B| / |A.keywords|` -- it measures what fraction of memory A's keywords appear in memory B. This means a small memory can have high overlap with a large memory but not vice versa.
- The merge threshold is `duplicate > 0.6` (from line 1057).
- For merge candidate identification, we need pairwise overlap, not just the max. The task description specifies computing pairwise overlap within each topic cluster.

#### 2. Memory Frontmatter Structure

From the existing memory file (`MEM-plan-delegation-required.md`), the frontmatter fields are:
- `title`, `created`, `tags`, `topic`, `source`, `modified`
- `retrieval_count`, `last_retrieved`
- `keywords` (array of strings)
- `summary`, `token_count`

The memory template at `.memory/30-Templates/memory-template.md` confirms the base structure but lacks the `keywords`, `summary`, and `token_count` fields that were added later.

#### 3. Topic-Cluster Grouping

Already defined in SKILL.md (lines 1033-1043):
```
cluster_key = topic.split("/")[0]
```
This is used for the health report and should be reused for merge candidate grouping.

#### 4. Distill Command Dispatch

The command file at `.claude/extensions/memory/commands/distill.md` shows the dispatch pattern:
- Argument parsing extracts `sub_mode` (line 39: `--merge` maps to `sub_mode = "merge"`)
- Currently returns placeholder message for unimplemented sub-modes (lines 76-80)
- Delegates to `skill-memory mode=distill, sub_mode={sub_mode}`
- State management reads/writes are documented (lines 155-167)

#### 5. Tombstone Pattern (from Task 450 Description)

Task 450 defines the tombstone approach:
- Add `status: tombstoned`, `tombstoned_at: ISO8601`, `tombstone_reason: "purge"` to frontmatter
- Do NOT delete file; do NOT remove from index
- Tombstoned memories excluded from retrieval

For merge, the tombstone_reason would be `"merged_into:{primary_id}"` as specified in the task description.

#### 6. Index Maintenance Pattern

Three indexes must be updated after merge operations:
1. `.memory/memory-index.json` -- regenerated from filesystem (SKILL.md lines 458-493)
2. `.memory/20-Indices/index.md` -- regenerated from filesystem (SKILL.md lines 433-449)
3. `.memory/10-Memories/README.md` -- regenerated listing (SKILL.md lines 418-429)

All use the "regenerate from filesystem" pattern rather than incremental updates, which is important for merge operations since multiple files change.

#### 7. Distill Log Schema

The distill-log.json schema (SKILL.md lines 1183-1220) supports a `merge` operation type. The `affected_memories` array can hold the list of merged pairs. Pre/post metrics track `merge_candidates` count.

#### 8. Validate-on-Read

Before any scoring operation, the validate-on-read procedure (SKILL.md lines 512-527) ensures memory-index.json matches the filesystem. This must run before merge candidate identification.

### Current Vault State

- 1 memory file: `MEM-plan-delegation-required.md`
- Keywords: `["delegation", "artifact", "skill", "bypass-prevention", "enforcement"]`
- Topic: `agent-system`
- The vault is too small for any merge operations -- the implementation must handle this gracefully with a "No merge candidates found" message.

### Task Description Requirements

From the TODO.md task description, the merge operation has these explicit requirements:

1. **Candidate identification**: Pairwise keyword overlap within topic clusters, threshold > 60%, ranked by overlap descending
2. **Interactive selection**: AskUserQuestion per topic cluster with pair details
3. **Primary determination**: Higher retrieval_count wins; if equal, older memory is primary
4. **Content merge**: Primary content + `## Merged From {secondary}` section
5. **Keyword superset guarantee**: `merged_keywords = union(primary.keywords, secondary.keywords)`, verify length, fail merge if not satisfied
6. **Frontmatter updates**: `modified = today`, combined `retrieval_count`, earliest `created`
7. **Tombstone secondary**: Same pattern as purge with `tombstone_reason: "merged_into:{primary_id}"`
8. **Cross-reference cleanup**: Scan all memories for `[[{secondary_id}]]`, replace with `[[{primary_id}]]`
9. **Index regeneration**: After all merges complete
10. **Logging**: primary, secondary, overlap_score, keywords_before/after, keyword_superset_verified flag

## Decisions

1. **Overlap computation for merge**: Use symmetric pairwise overlap rather than the asymmetric duplicate_score formula. For merge candidates, compute `|A intersect B| / |A union B|` (Jaccard similarity) to avoid the directionality issue. However, the task description specifies `overlap > 60%` using the existing formula. Decision: follow the task description and use the existing asymmetric formula, but compute it in both directions and take the maximum for each pair.

2. **Tombstone independence**: Implement the tombstone frontmatter fields (`status: tombstoned`, `tombstoned_at`, `tombstone_reason`) directly in the merge code without depending on task 450. Both tasks define the same pattern; whichever lands first establishes it.

3. **Dry-run support**: The `--dry-run` flag is already parsed in the command file. The merge sub-mode should respect it by computing candidates and displaying what would happen without writing any files.

4. **Edge case -- single memory**: When the vault has fewer than 2 memories, display "No merge candidates found (need at least 2 memories)" and exit cleanly.

5. **Edge case -- no candidates above threshold**: When no pairs exceed 60% overlap, display "No merge candidates found (no pairs with keyword overlap > 60%)" and exit.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Keyword superset guarantee violated by bug | High | Explicit assertion check before writing; fail merge and roll back if violated |
| Cross-reference scan misses references | Medium | Use grep across all `.memory/10-Memories/*.md` files for `[[{secondary_id}]]` pattern |
| Tombstone pattern conflicts with task 450 implementation | Low | Both tasks define identical tombstone fields; reconcile during review |
| Index regeneration fails mid-operation | Medium | Run all merges first, then regenerate indexes in a single pass |
| Large vault with many pairwise comparisons (O(n^2)) | Low | Current vault is tiny; for future-proofing, only compare within topic clusters |

## Recommendations

### Implementation Approach

The implementation should modify two files:

1. **SKILL.md** (`/.claude/extensions/memory/skills/skill-memory/SKILL.md`): Add a new `### Sub-Mode: merge` section after the existing distill mode documentation. This section should contain:
   - Merge candidate identification algorithm (pairwise overlap within clusters)
   - Interactive selection template (AskUserQuestion format)
   - Merge execution steps with keyword superset verification
   - Tombstone application for secondary memories
   - Cross-reference update procedure
   - Extended distill-log entry schema for merge operations

2. **distill.md** (`/.claude/extensions/memory/commands/distill.md`): Update the sub-mode availability table to mark `merge` as "Available" and update the placeholder check to allow `merge` through.

### Key Implementation Details

**Pairwise Overlap Algorithm**:
```
For each topic_cluster:
  memories = cluster_memories
  pairs = []
  for i in range(len(memories)):
    for j in range(i+1, len(memories)):
      a_keywords = set(memories[i].keywords)
      b_keywords = set(memories[j].keywords)
      overlap_a = len(a_keywords & b_keywords) / len(a_keywords) if a_keywords else 0
      overlap_b = len(a_keywords & b_keywords) / len(b_keywords) if b_keywords else 0
      overlap = max(overlap_a, overlap_b)
      if overlap > 0.6:
        pairs.append((memories[i], memories[j], overlap))
  pairs.sort(by=overlap, descending)
```

**Keyword Superset Guarantee Check**:
```
merged_keywords = union(primary.keywords, secondary.keywords)
# After building merged memory, verify:
assert set(merged_memory.keywords) >= merged_keywords
# If assertion fails, abort this merge, log failure, continue with next pair
```

**Merge Content Template**:
```markdown
---
title: "{primary.title}"
created: {min(primary.created, secondary.created)}
tags: {union(primary.tags, secondary.tags)}
topic: "{primary.topic}"
source: "{primary.source}, {secondary.source}"
modified: {today}
retrieval_count: {primary.retrieval_count + secondary.retrieval_count}
last_retrieved: {max(primary.last_retrieved, secondary.last_retrieved)}
keywords: {union(primary.keywords, secondary.keywords)}
summary: "{primary.summary}"
token_count: {recomputed after merge}
---

# {primary.title}

{primary.content}

## Merged From {secondary.id}

**Original Title**: {secondary.title}
**Merged**: {today}
**Overlap Score**: {overlap}%

{secondary.content}

## Connections
{union of both connection sections, with secondary references updated}
```

**Tombstone for Secondary**:
```markdown
---
status: tombstoned
tombstoned_at: {ISO8601}
tombstone_reason: "merged_into:{primary.id}"
{... preserve remaining original frontmatter ...}
---
```

## Appendix

### Files Examined

| File | Purpose |
|------|---------|
| `.claude/extensions/memory/commands/distill.md` | Command dispatch and sub-mode routing |
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Scoring engine, index maintenance, memory operations |
| `.memory/memory-index.json` | Current vault state (1 entry) |
| `.memory/distill-log.json` | Empty operation log |
| `.memory/10-Memories/MEM-plan-delegation-required.md` | Only existing memory, reference for frontmatter structure |
| `.memory/30-Templates/memory-template.md` | Base memory template |
| `.memory/20-Indices/index.md` | Human-readable index |
| `.claude/extensions/memory/manifest.json` | Extension manifest |
| `specs/TODO.md` | Task 451 and 450 descriptions |

### Key Sections in SKILL.md

| Section | Lines | Relevance |
|---------|-------|-----------|
| Scoring Engine | 955-1028 | Duplicate score computation |
| Topic-Cluster Grouping | 1033-1043 | Cluster key derivation |
| Maintenance Candidate Classification | 1048-1060 | Merge threshold (duplicate > 0.6) |
| Distill Log Schema | 1183-1220 | Log entry structure for merge operations |
| JSON Index Maintenance | 458-493 | Post-merge index regeneration |
| Validate-on-Read | 512-527 | Pre-operation validation |
| Index Regeneration Pattern | 433-449 | Filesystem-based regeneration |
