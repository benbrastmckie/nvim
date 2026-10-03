# Purge Sub-Mode

This file is the COMPLETE and ONLY specification for skill-distill's `--purge` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Purge Sub-Mode` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--purge` is dispatched. The `Link-Scan Procedure`, `Retrieval Exclusion`, and `Health Report -- Tombstoned Memories Section` subsections immediately following Purge in `skill-distill/SKILL.md` are shared with the `gc` sub-mode (confirmed by direct read of GC's own cross-reference) and stay there -- they are NOT part of this file.

The purge sub-mode identifies stale or zero-retrieval memories, presents candidates interactively, and applies a tombstone pattern (frontmatter mutation) rather than deleting files. Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below.

## Purge Candidate Identification

After scoring all memories via the Scoring Engine, select purge candidates using an OR condition:

```
purge_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.topic starts_with "email/preferences/":
    skip  # reserved-namespace purge exemption (email-to-memory-preferences.md design §5.1) --
          # gates the WHOLE OR-condition below, not just the zero-retrieval leg (Component 2 of
          # skill-distill/SKILL.md's Scoring Engine already zeroes zero_retrieval_penalty for
          # this namespace; this second,
          # independent gate is defense-in-depth so a high staleness_score alone can never purge
          # one of these memories either)
  if memory.zero_retrieval_penalty == 1.0 OR memory.staleness_score > 0.8:
    purge_candidates.append(memory)
```

**Edge Case**: If `purge_candidates` is empty, display:
```
No purge candidates found. All memories are healthy or already tombstoned.
```
Then exit the purge sub-mode without further action.

## Category-Aware TTL Advisory Thresholds

Category TTL thresholds affect **ranking only**, not automatic selection. Memories past their category TTL are sorted to the top of the candidate list.

| Category | TTL (days) | Description |
|----------|-----------|-------------|
| CONFIG | 180 | Configuration knowledge becomes stale fastest |
| WORKFLOW | 365 | Processes evolve but have longer relevance |
| PATTERN | 540 | Design patterns remain relevant longest |
| TECHNIQUE | 270 | Methods need periodic refresh |
| INSIGHT | none | Insights have no TTL (never auto-prioritized) |

## TTL-Based Ranking

Sort purge candidates for presentation:

```
for each candidate in purge_candidates:
  category = candidate.category
  ttl = TTL_THRESHOLDS[category]  # from table above
  days_since_created = days_between(today, candidate.created)

  if ttl is not None AND days_since_created > ttl:
    candidate.past_ttl = true
    candidate.ttl_excess_days = days_since_created - ttl
  else:
    candidate.past_ttl = false
    candidate.ttl_excess_days = 0

# Sort: past-TTL memories first (by excess days descending), then by composite score descending
purge_candidates.sort(key=lambda c: (-int(c.past_ttl), -c.ttl_excess_days, -c.composite_score))
```

## Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT tombstone any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to tombstone (purge). Tombstoned memories are excluded from retrieval but preserved on disk for 7 days before gc can hard-delete them.",
  "header": "Purge Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Score: {composite_score:.2f} | Created: {created} | Retrievals: {retrieval_count} | Tokens: {token_count} | Category: {category}{ttl_warning}"
    }
  ]
}
```

Where `{ttl_warning}` is:
- ` | PAST TTL by {ttl_excess_days}d` if `past_ttl == true`
- empty string if `past_ttl == false`

If the user selects no memories, display:
```
No memories selected for purge. Operation cancelled.
```
Then exit without changes.

## Dry-Run Behavior

When `--dry-run` is active, show the candidate list and scores but skip tombstone application:

```
[DRY RUN] Would tombstone {count} memories:
  - {memory.id} (score: {composite_score:.2f}, category: {category})
  - ...

No changes made.
```

Exit after displaying the dry-run summary.

## Tombstone Application

For each selected memory, apply the tombstone by mutating its YAML frontmatter:

```
1. Read the memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse YAML frontmatter (between --- delimiters)
3. Add three fields after the `summary` field (before `token_count` if present):
   status: tombstoned
   tombstoned_at: {ISO8601 date, e.g., 2026-04-16}
   tombstone_reason: "purge"
4. Write the updated file back to disk
5. Update memory-index.json: set the entry's `status` to "tombstoned"
```

**Frontmatter Example (before)**:
```yaml
---
title: "HTTP request retry patterns"
created: 2026-01-15
tags: [PATTERN]
topic: "python/libs/requests"
source: "user input"
modified: 2026-01-15
summary: "HTTP retry with exponential backoff"
retrieval_count: 0
last_retrieved:
---
```

**Frontmatter Example (after)**:
```yaml
---
title: "HTTP request retry patterns"
created: 2026-01-15
tags: [PATTERN]
topic: "python/libs/requests"
source: "user input"
modified: 2026-01-15
summary: "HTTP retry with exponential backoff"
status: tombstoned
tombstoned_at: 2026-04-16
tombstone_reason: "purge"
retrieval_count: 0
last_retrieved:
---
```

## Purge Log Entry

After tombstoning, log the operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "purge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 65,
    "purge_candidates": 4,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "post_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 78,
    "purge_candidates": 1,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "affected_memories": ["MEM-slug-1", "MEM-slug-2", "MEM-slug-3"],
  "notes": "Tombstoned 3 memories. Link-scan warnings: [list or 'none']"
}
```

**Key semantics**: `total_memories` and `total_tokens` remain unchanged in post_metrics because tombstoning preserves files on disk. `purge_candidates` decreases because tombstoned memories are excluded from future scoring. `health_score` improves as maintenance candidates are addressed.

Update the distill-log.json `summary.total_purged` counter by incrementing it by the number of tombstoned memories.

