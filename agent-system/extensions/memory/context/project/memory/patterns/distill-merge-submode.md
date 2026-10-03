# Sub-Mode: merge

This file is the COMPLETE and ONLY specification for skill-distill's `--merge` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: merge` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--merge` is dispatched.

Combine duplicate memories with high keyword overlap. The merge operation identifies pairwise duplicate candidates within topic clusters, presents them for interactive selection, merges content with a keyword superset guarantee, tombstones the absorbed secondary, updates cross-references, and regenerates indexes. Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below. (Its Interactive Selection step below does not restate the MANDATORY STOP language verbatim -- see that step's own text for the exact wording used at this call site.)

## Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If fewer than 2 non-tombstoned memories:
   Display: "Merge requires at least 2 active memories. Vault has {count}."
   Return early.
```

## Pairwise Keyword Overlap Algorithm

Compute pairwise overlap within each topic cluster:

```
1. Group non-tombstoned memories by topic cluster:
   cluster_key = topic.split("/")[0]
   If topic is empty or null: cluster_key = "uncategorized"

2. For each cluster with 2+ memories, compute pairwise overlap:
   for each pair (A, B) in cluster:
     overlap_ab = |A.keywords intersect B.keywords| / |A.keywords|
     overlap_ba = |A.keywords intersect B.keywords| / |B.keywords|
     pair_overlap = max(overlap_ab, overlap_ba)

   Note: Use max of both asymmetric directions so that a small memory
   with all keywords contained in a larger memory is detected.

3. Handle empty keyword arrays:
   If either A.keywords or B.keywords is empty: pair_overlap = 0.0
   (Cannot merge memories with no keyword basis for comparison)

4. Filter pairs where pair_overlap >= 0.6 (60% threshold)

5. Sort candidate pairs by pair_overlap descending within each cluster
```

## Dry-Run Mode

When `--dry-run` is set, compute and display candidates without writing any files:

```
Display per cluster:
  ## Merge Candidates (Dry Run)

  ### Cluster: {cluster_key}

  | Primary | Secondary | Overlap | Shared Keywords |
  |---------|-----------|---------|-----------------|
  | {A.id} | {B.id} | {pair_overlap}% | {shared_keywords} |

  {total_pairs} merge candidate pair(s) found across {cluster_count} cluster(s).
  Run /distill --merge without --dry-run to execute.

Return early after display. No files are modified.
```

## Interactive Selection (AskUserQuestion)

Present merge candidates per topic cluster for user selection:

```
For each cluster with candidates:
  AskUserQuestion({
    "question": "Select pairs to merge in cluster '{cluster_key}':",
    "header": "Merge Candidates: {cluster_key}",
    "multiSelect": true,
    "options": [
      {
        "label": "{A.title} + {B.title}",
        "description": "{pair_overlap}% overlap | Shared: {shared_keywords} | Retrievals: {A.retrieval_count}, {B.retrieval_count}"
      }
    ]
  })
```

If no pairs above threshold in any cluster:
```
Display: "No merge candidates found (no pairs with >= 60% keyword overlap)."
Return early.
```

If user selects no pairs across all clusters:
```
Display: "No pairs selected. No merges performed."
Return early.
```

## Primary Determination

For each selected pair, determine which memory is primary (target) and which is secondary (absorbed):

```
Primary selection rules (first match wins):
1. Higher retrieval_count -> primary
2. If retrieval_count equal: older created date -> primary
3. If both equal: alphabetically first id -> primary (deterministic tiebreaker)
```

## Merged Content Template

The primary memory file is rewritten with merged content:

**Frontmatter merging rules**:
```
title:            primary.title (unchanged)
created:          min(primary.created, secondary.created) -- earliest
modified:         today (ISO date)
tags:             union(primary.tags, secondary.tags) -- deduplicated
topic:            primary.topic (unchanged)
source:           primary.source (unchanged)
keywords:         union(primary.keywords, secondary.keywords) -- deduplicated, sorted
summary:          primary.summary (unchanged)
retrieval_count:  primary.retrieval_count + secondary.retrieval_count
last_retrieved:   max(primary.last_retrieved, secondary.last_retrieved) -- most recent, skip nulls
token_count:      recomputed after merge (word_count * 1.3, rounded down)
status:           omit (active is default when absent)
```

**Content structure**:
```markdown
---
{merged frontmatter}
---

# {primary.title}

{primary existing content - everything between title heading and first ## section}

## Merged From {secondary.id}

**Original Title**: {secondary.title}
**Merged**: {today}
**Overlap Score**: {pair_overlap}%

{secondary content - everything between title heading and ## Connections in secondary}

## Connections
{union of both connection sections, with [[{secondary.id}]] references replaced by [[{primary.id}]]}
```

## Keyword Superset Guarantee

**CRITICAL INVARIANT**: Before writing the merged file, verify:

```
required_keywords = union(primary.keywords, secondary.keywords)
merged_keywords = merged_frontmatter.keywords

assertion: set(merged_keywords) >= set(required_keywords)

If assertion fails:
  Log error: "KEYWORD SUPERSET VIOLATION: missing keywords: {required - merged}"
  Abort this merge pair (do not write file)
  Preserve both original files unchanged
  Continue with remaining pairs
  Report violation in operation summary
```

This guarantee ensures no keyword coverage is lost during merging.

## Tombstone Application

After successful merge, tombstone the secondary memory:

```
Add to secondary's frontmatter (preserve all existing fields):
  status: tombstoned
  tombstoned_at: {today ISO8601}
  tombstone_reason: "merged_into:{primary.id}"

Do NOT delete the file.
Do NOT remove from index (index regeneration will include tombstone status).
```

The tombstone fields are identical to those used by the Purge Sub-Mode
(`distill-purge-submode.md`):
- `status: tombstoned`
- `tombstoned_at: {ISO8601 date}`
- `tombstone_reason: "{reason}"` -- for merge, reason is `"merged_into:{primary_id}"`

## Cross-Reference Update

After tombstoning, update wiki-link references across all non-tombstoned memories:

```
1. Scan all .memory/10-Memories/*.md files
2. For each file that is NOT tombstoned:
   Search for [[{secondary.id}]] references
   Replace with [[{primary.id}]]
3. Log all replacements: "{file}: replaced [[{secondary.id}]] -> [[{primary.id}]]"
```

## Index Regeneration

After ALL merges in the batch are complete (not after each individual merge):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Include tombstoned memories with status: "tombstoned"
2. Regenerate index.md using "Index Regeneration Pattern"
   - Exclude tombstoned memories from active listings
3. Regenerate .memory/10-Memories/README.md
   - Exclude tombstoned memories from the listing
```

## Distill Log Entry

Log each merge operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "merge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "primary": "{primary.id}",
      "secondary": "{secondary.id}",
      "overlap_score": 0.75,
      "keywords_before": [5, 4],
      "keywords_after": 7,
      "keyword_superset_verified": true,
      "action": "merged"
    }
  ],
  "notes": "Merged {N} pair(s) across {M} cluster(s)"
}
```

The `keywords_before` array contains `[primary_keyword_count, secondary_keyword_count]`. The `keywords_after` value is the merged keyword count. The `keyword_superset_verified` boolean confirms the superset guarantee held for this pair.

