---
name: skill-distill
description: Memory vault analysis and maintenance - scoring, health reporting, purge/merge/compress/refine/gc/auto, and telemetry-sourced review/revise/meta/learn/dream sub-modes. Invoke for /distill command operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Distill Skill (Direct Execution)

Direct execution skill for memory vault analysis and maintenance. Handles the `/distill` command's sub-modes: the seven existing hygiene sub-modes (`report`/`purge`/`merge`/`compress`/`refine`/`gc`/`auto`) plus five new or redefined telemetry-sourced sub-modes (`--revise`/`--meta`/`--review`/`--learn`/`--dream`). Memory *creation* is a separate concern owned by the sibling `skill-learn` skill.

## Context References

Reference (do not load eagerly):
- Path: `@.memory/memory-index.json` - Machine-queryable memory index
- Path: `@.claude/context/project/memory/distill-usage.md` - Usage guide
- Path: `@.claude/context/project/memory/telemetry-guardrails.md` - Binding design constraints for the telemetry-sourced sub-modes (four-tier source model, evaluator-outside-the-loop rule, six failure modes, `gen_ai.*` borrowing rule, cross-repo invocation discipline)
- Path: `@.claude/skills/skill-learn/SKILL.md` - the sibling skill this file was split from. Its "Validate-on-Read" and "JSON Index Maintenance" sections are the shared procedures this file's body cites as "above" or "below" throughout -- both skills operate on the same `.memory/memory-index.json`, and those two procedures were not duplicated by the split; they live in `skill-learn/SKILL.md` only.

---

## Mode: distill

Memory vault distillation: scoring, health reporting, and maintenance operations. Invoked by `/distill` command with `mode=distill`.

### Prerequisites

**Validate-on-Read**: Before scoring, run the validate-on-read procedure from the "Validate-on-Read" section above to ensure `memory-index.json` is consistent with the filesystem. If stale, regenerate using the "JSON Index Maintenance" procedure before proceeding.

### Sub-Mode Dispatch

| Sub-Mode | Description | Status |
|----------|-------------|--------|
| `report` | Generate health report with scoring | Available |
| `purge` | Tombstone stale/zero-retrieval memories | Available |
| `merge` | Combine memories with duplicate score > 0.6 | Available |
| `compress` | Summarize memories with size penalty > 0.5 | Available |
| `refine` | Improve memory quality (keywords, tags) | Available |
| `gc` | Hard-delete tombstoned memories past grace period | Available |
| `auto` | Automated distillation (Tier 1 refine only) | Available |
| `revise` | Event-and-OTel-correlated memory refactoring proposals | Available |
| `meta` | Cross-repo agent-system improvement proposals | Available |
| `review` | Read-only ad hoc inquiry over the vault and all four source tiers | Available |
| `learn` | Retroactive batch harvest across already-completed tasks | Available |
| `dream` | Speculative direction-finding over `history.jsonl`'s recurring themes | Available |

All 12 sub-modes are now available. No placeholder responses needed.

### Scoring Engine

The scoring engine computes a composite maintenance score for each memory in the vault. Higher scores indicate memories that are better candidates for maintenance operations.

#### Input

Read all entries from `.memory/memory-index.json` after validate-on-read. Each entry provides:
- `created` (ISO date)
- `modified` (ISO date)
- `last_retrieved` (ISO date or null)
- `retrieval_count` (number)
- `token_count` (number)
- `keywords` (array of strings)

#### Component 1: Staleness Score (weight: 0.3)

Measures how long since the memory was last useful.

```
days_since_last = days_between(today, last_retrieved or created)

staleness = min(1.0, days_since_last / 90)

# FSRS adjustment: reduce staleness for actively retrieved old memories
if retrieval_count > 0 AND days_since_created > 60:
  staleness = max(0, staleness - 0.3)
```

- Range: 0.0 (fresh) to 1.0 (90+ days stale)
- FSRS adjustment rewards memories that have proven useful over time

#### Component 2: Zero-Retrieval Penalty (weight: 0.25)

Penalizes memories that have never been retrieved after a grace period.

```
if topic starts_with "email/preferences/":
  zero_retrieval = 0.0   # reserved-namespace exemption (email-to-memory-preferences.md design
                          # §5.1) -- these memories are intentionally never read back by
                          # /research /plan /implement auto-retrieval (see memory-retrieve.sh's
                          # topic-prefix pre-filter), so a zero retrieval_count is expected, not
                          # a staleness signal
elif retrieval_count == 0 AND days_since_created > 30:
  zero_retrieval = 1.0
else:
  zero_retrieval = 0.0
```

- Binary: 0.0 (has retrievals, too new, or `email/preferences/*` exempt) or 1.0 (never retrieved,
  older than 30 days, and not in the exempt namespace)

#### Component 3: Size Penalty (weight: 0.2)

Penalizes oversized memories that may benefit from compression.

```
size_penalty = max(0, (token_count - 600) / 600)
```

- Range: 0.0 (600 tokens or fewer) to unbounded (linear above 600)
- A 1200-token memory scores 1.0; a 300-token memory scores 0.0

#### Component 4: Duplicate Score (weight: 0.25)

Measures keyword overlap with the most similar other memory in the vault.

```
for each other_memory in vault:
  overlap = |memory.keywords intersect other_memory.keywords| / |memory.keywords|

duplicate = max(overlap across all other memories)
```

- Range: 0.0 (no keyword overlap) to 1.0 (complete keyword subset)
- Uses Jaccard-like ratio: intersection size divided by the memory's own keyword count

#### Composite Score

```
composite = (staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)
composite = clamp(composite, 0, 1)
```

- Weights sum to 1.0 (0.3 + 0.25 + 0.2 + 0.25)
- Range: 0.0 (healthy memory) to 1.0 (strong maintenance candidate)

#### Topic-Cluster Grouping

Group memories by topic cluster for the health report. The cluster key is the first path segment of the memory's `topic` field:

```
cluster_key = topic.split("/")[0]

# Example:
# topic "python/libs/requests" -> cluster "python"
# topic "lua/patterns" -> cluster "lua"
# topic "" or null -> cluster "uncategorized"
```

### Maintenance Candidate Classification

Based on composite scores, classify each memory:

| Composite Score | Classification | Recommended Action |
|-----------------|----------------|-------------------|
| >= 0.7 | Purge candidate | Remove (--purge) |
| >= 0.5 | Merge/compress candidate | Merge duplicates (--merge) or compress (--compress) |
| >= 0.3 | Review candidate | May benefit from refinement (--refine) |
| < 0.3 | Healthy | No action needed |

Additionally, flag specific conditions:
- `duplicate > 0.6` -> Merge candidate regardless of composite
- `size_penalty > 0.5` -> Compress candidate regardless of composite
- `zero_retrieval == 1.0` -> Review for relevance

### Health Report Template

The `report` sub-mode generates a formatted health report displayed to the user. Template:

```
## Memory Vault Health Report

**Generated**: {today}
**Vault**: .memory/

---

### Overview

| Metric | Value |
|--------|-------|
| Total memories | {total_count} |
| Total tokens | {total_tokens} |
| Average tokens/memory | {avg_tokens} |
| Oldest memory | {oldest_date} ({oldest_id}) |
| Newest memory | {newest_date} ({newest_id}) |

---

### Category Distribution

| Category | Count | Tokens | Avg Score |
|----------|-------|--------|-----------|
| {category_1} | {count} | {tokens} | {avg_composite} |
| {category_2} | {count} | {tokens} | {avg_composite} |
| ... | ... | ... | ... |

---

### Topic Clusters

| Cluster | Memories | Avg Staleness | Avg Duplicate |
|---------|----------|---------------|---------------|
| {cluster_1} | {count} | {avg_staleness} | {avg_duplicate} |
| {cluster_2} | {count} | {avg_staleness} | {avg_duplicate} |
| ... | ... | ... | ... |

---

### Retrieval Statistics

| Metric | Value |
|--------|-------|
| Never retrieved | {never_retrieved_count} ({never_retrieved_pct}%) |
| Retrieved 1-3 times | {low_retrieval_count} |
| Retrieved 4+ times | {high_retrieval_count} |
| Most retrieved | {most_retrieved_id} ({most_retrieved_count} times) |

---

### Maintenance Candidates

#### Purge Candidates (score >= 0.7)
{purge_list or "None"}

#### Merge Candidates (duplicate > 0.6)
{merge_list or "None"}

#### Compress Candidates (size > 0.5)
{compress_list or "None"}

#### Review Candidates (score 0.3-0.7)
{review_list or "None"}

---

### Health Score

**Score**: {health_score}/100
**Status**: {status_emoji} {status_label}

Formula: `100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)`

| Threshold | Status |
|-----------|--------|
| 80-100 | Healthy |
| 60-79 | Manageable |
| 40-59 | Concerning |
| 0-39 | Critical |

---

### Recommended Actions

{action_list based on candidates found}
```

#### Health Score Formula

```
health_score = 100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)
health_score = clamp(health_score, 0, 100)
```

Where:
- `purge_count` = number of memories with composite score >= 0.7
- `merge_count` = number of memories with duplicate score > 0.6
- `compress_count` = number of memories with size_penalty > 0.5

#### Health Status Thresholds

| Score Range | Status | Description |
|-------------|--------|-------------|
| 80-100 | healthy | Vault is well-maintained |
| 60-79 | manageable | Some maintenance recommended |
| 40-59 | concerning | Significant maintenance needed |
| 0-39 | critical | Urgent maintenance required |

These thresholds mirror `repository_health.status` vocabulary in state.json.

## Shared Sub-Mode Skeleton

Every mutating `/distill` sub-mode below (`purge`, `gc`, `merge`, `compress`, `refine`, `auto`,
and the telemetry-sourced sub-modes added after them) follows the same seven-step shape. This
section states that shape once, with named, generic placeholders; each sub-mode's own section
below states only its deltas from this skeleton -- its specific candidate logic, prompts,
execution steps, and log payload -- rather than restating the shape itself. This generalizes a
convention this file already used once for the `dream` section's `### Overlap Scoring`
cross-reference ("reference the section by name -- do not restate or fork the formula") into a
file-wide rule.

1. **Edge Case Checks** -- Validate preconditions before identifying candidates (e.g. run
   validate-on-read, confirm a minimum count of eligible memories). If a precondition fails,
   display a specific message and return early without further action.
2. **Candidate Identification** -- Compute the sub-mode's specific candidate set from scored or
   otherwise-derived memory data. If a shared dependency like validate-on-read or the Scoring
   Engine is used, cite it by name rather than re-deriving it.
3. **Dry-Run** -- When `--dry-run` is active, display what the sub-mode would do (the specific
   candidate list, with sub-mode-relevant fields) and return early. No file is modified.
4. **Interactive Selection (MANDATORY STOP)** -- Present candidates via `AskUserQuestion`
   (`multiSelect: true` for any sub-mode selecting among multiple candidates). **This step is
   non-negotiable in every sub-mode that mutates the vault: no mutation may proceed without an
   explicit, user-confirmed selection at this step.** If no candidates exist, or the user selects
   none, display a specific message and exit without changes.
5. **Execution** -- Apply the confirmed operation. This step's actual content is the most
   sub-mode-specific of the seven and is stated in full in each sub-mode's own section -- it is
   never usefully reduced to a generic placeholder, since the tombstone/merge/compress/refine/
   delete mechanics differ in every case.
6. **Batch Index Regeneration** -- After the entire batch of confirmed operations completes (not
   after each individual one), regenerate `memory-index.json` (via the "JSON Index Maintenance"
   procedure in `skill-learn/SKILL.md`), `index.md`, and `.memory/10-Memories/README.md`.
7. **Log Entry** -- Log the operation to `.memory/distill-log.json` per the Distill Log Schema
   below, and update the relevant `summary` counter. Also update `memory_health` in
   `specs/state.json` per the State Integration section below.

**Non-mutating sub-modes** (`report`, and later `--review`) do not carry step 4's mandatory stop,
since nothing is proposed for the user to confirm -- each such sub-mode states this exemption
explicitly in its own section rather than leaving it as a silent omission.

### Purge Sub-Mode

The purge sub-mode identifies stale or zero-retrieval memories, presents candidates interactively, and applies a tombstone pattern (frontmatter mutation) rather than deleting files. Follows the Shared Sub-Mode Skeleton above; deltas below.

#### Purge Candidate Identification

After scoring all memories via the Scoring Engine, select purge candidates using an OR condition:

```
purge_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.topic starts_with "email/preferences/":
    skip  # reserved-namespace purge exemption (email-to-memory-preferences.md design §5.1) --
          # gates the WHOLE OR-condition below, not just the zero-retrieval leg (Component 2
          # above already zeroes zero_retrieval_penalty for this namespace; this second,
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

#### Category-Aware TTL Advisory Thresholds

Category TTL thresholds affect **ranking only**, not automatic selection. Memories past their category TTL are sorted to the top of the candidate list.

| Category | TTL (days) | Description |
|----------|-----------|-------------|
| CONFIG | 180 | Configuration knowledge becomes stale fastest |
| WORKFLOW | 365 | Processes evolve but have longer relevance |
| PATTERN | 540 | Design patterns remain relevant longest |
| TECHNIQUE | 270 | Methods need periodic refresh |
| INSIGHT | none | Insights have no TTL (never auto-prioritized) |

#### TTL-Based Ranking

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

#### Interactive Selection -- MANDATORY STOP

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

#### Dry-Run Behavior

When `--dry-run` is active, show the candidate list and scores but skip tombstone application:

```
[DRY RUN] Would tombstone {count} memories:
  - {memory.id} (score: {composite_score:.2f}, category: {category})
  - ...

No changes made.
```

Exit after displaying the dry-run summary.

#### Tombstone Application

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

#### Purge Log Entry

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

### Link-Scan Procedure

After tombstone application, scan for stale `[[MEM-{slug}]]` references in non-tombstoned memories.

#### Link-Scan Execution

```bash
# For each tombstoned memory slug
for slug in "${affected_slugs[@]}"; do
  # Search non-tombstoned memories for references
  grep -l "\[\[MEM-${slug}\]\]" .memory/10-Memories/MEM-*.md 2>/dev/null | while read ref_file; do
    # Check if the referencing file is itself tombstoned
    ref_status=$(grep -m1 "^status:" "$ref_file" | sed 's/^status: *//')
    if [ "$ref_status" == "tombstoned" ]; then
      continue  # Skip tombstoned files
    fi
    echo "WARNING: ${ref_file} references tombstoned [[MEM-${slug}]]"
  done
done
```

#### Warning Display

Display link-scan warnings to the user (no automatic modification):

```
## Link-Scan Warnings

The following active memories reference tombstoned memories:
- .memory/10-Memories/MEM-http-patterns.md -> [[MEM-requests-retry-patterns]] (tombstoned)
- .memory/10-Memories/MEM-library-setup.md -> [[MEM-requests-retry-patterns]] (tombstoned)

These references will become stale. Consider manually updating the Connections section
in the above files to remove or replace the references.
```

If no stale references are found:
```
Link-scan: No stale references found.
```

#### Link-Scan in Log

Include link-scan warnings in the purge operation's `notes` field in distill-log.json:

```
"notes": "Tombstoned 3 memories. Link-scan warnings: MEM-http-patterns.md->MEM-slug-1, MEM-library-setup.md->MEM-slug-1"
```

Or if none:
```
"notes": "Tombstoned 3 memories. Link-scan warnings: none"
```

### Retrieval Exclusion

Tombstoned memories must be excluded from all retrieval paths.

#### MCP Search Path Exclusion

After MCP search returns results, post-filter to exclude tombstoned entries:

```
For each segment in content_map.segments:
  query = segment.key_terms.join(" ")
  results = execute("search", {
    "query": query,
    "vault": ".memory",
    "limit": 5
  })

  # Post-filter: exclude tombstoned memories
  filtered_results = []
  for result in results:
    id = derive_id_from_result(result)
    index_entry = memory_index.entries[id]
    if index_entry.status == "tombstoned":
      continue  # Skip tombstoned memory
    filtered_results.append(result)
  results = filtered_results
```

#### Grep Fallback Path Exclusion

When using grep-based search, check frontmatter status before including in results:

```bash
# For each segment
for keyword in $key_terms; do
  grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
done | sort | uniq -c | sort -rn | head -10 | while read count file; do
  # Check if memory is tombstoned
  status=$(grep -m1 "^status:" "$file" | sed 's/^status: *//')
  if [ "$status" == "tombstoned" ]; then
    continue  # Skip tombstoned memory
  fi
  echo "$count $file"
done | head -5
```

#### Scoring Engine Exclusion

In the scoring engine, skip tombstoned memories before computing scores:

```
for each entry in memory_index.entries:
  if entry.status == "tombstoned":
    skip  # Do not score tombstoned memories
  # Proceed with scoring...
```

This ensures tombstoned memories do not appear in:
- Purge candidates (already addressed)
- Merge candidates
- Compress candidates
- Health report statistics (except in a dedicated "Tombstoned Memories" section)

### Health Report -- Tombstoned Memories Section

Add a "Tombstoned Memories" section to the health report template, placed after the "Maintenance Candidates" section:

```
---

### Tombstoned Memories

| Memory | Tombstoned Date | Reason | Days Until GC |
|--------|----------------|--------|---------------|
| {memory.id} | {tombstoned_at} | {tombstone_reason} | {7 - days_since_tombstoned} |
| ... | ... | ... | ... |

**Total tombstoned**: {tombstoned_count}
**Eligible for GC**: {gc_eligible_count} (past 7-day grace period)
```

If no tombstoned memories exist:
```
### Tombstoned Memories

None.
```

### GC Sub-Mode

The gc sub-mode performs hard deletion of tombstoned memories that have passed the 7-day grace period. Follows the Shared Sub-Mode Skeleton above; deltas below. Its logical pair is the Purge Sub-Mode above (with only its own tombstone-related Link-Scan/Retrieval-Exclusion/health-report infrastructure between them, no other sub-mode) -- gc hard-deletes what purge has already tombstoned once the grace period elapses.

#### Grace Period Scan

Identify tombstoned memories eligible for garbage collection:

```
gc_candidates = []
for each entry in memory_index.entries:
  if entry.status == "tombstoned":
    tombstoned_at = parse_date(entry.tombstoned_at or read from frontmatter)
    days_since_tombstoned = days_between(today, tombstoned_at)
    if days_since_tombstoned >= 7:
      gc_candidates.append(entry)
```

**Edge Case**: If no tombstoned memories are past the grace period, display:
```
No tombstoned memories past the 7-day grace period.
{tombstoned_count} tombstoned memories are still within the grace period.
```
Then exit without further action.

#### GC Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT delete any memories without explicit user confirmation.**

Present eligible memories via AskUserQuestion multiSelect:

```json
{
  "question": "Select tombstoned memories to permanently delete. This action cannot be undone.",
  "header": "GC Candidates ({count} past 7-day grace period)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tombstoned: {tombstoned_at} | Reason: {tombstone_reason} | Original score: {composite_score:.2f} | Tokens: {token_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for deletion. GC cancelled.
```
Then exit without changes.

#### Dry-Run Behavior

When `--dry-run` is active, show eligible memories without deleting:

```
[DRY RUN] Would permanently delete {count} memories:
  - {memory.id} (tombstoned: {tombstoned_at}, reason: {tombstone_reason})
  - ...

No changes made.
```

#### GC Deletion Sequence

For each selected memory, perform hard deletion in this order:

```
1. Delete the .md file:
   rm .memory/10-Memories/MEM-{slug}.md

2. Remove the entry from memory-index.json:
   - Filter out the entry with matching id
   - Decrement entry_count
   - Subtract the entry's token_count from total_tokens
   - Write updated memory-index.json

3. Regenerate index.md:
   - Use the Index Regeneration Pattern (existing procedure)
   - Tombstoned+deleted entries will be absent from filesystem scan

4. Regenerate .memory/10-Memories/README.md:
   - Use the existing README regeneration procedure
   - Deleted files will be absent from the ls scan

5. Update memory_health in specs/state.json:
   - Decrement total_memories by the number of deleted memories
   - Recalculate health_score after removal
```

#### GC Log Entry

Log the gc operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "gc",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 78,
    "purge_candidates": 1,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "post_metrics": {
    "total_memories": 7,
    "total_tokens": 3500,
    "health_score": 85,
    "purge_candidates": 1,
    "merge_candidates": 1,
    "compress_candidates": 1
  },
  "affected_memories": ["MEM-slug-1", "MEM-slug-2", "MEM-slug-3"],
  "notes": "Hard-deleted 3 tombstoned memories"
}
```

**Key semantics**: `total_memories` and `total_tokens` are decremented in post_metrics because gc removes files from disk. `health_score` is recalculated after deletion.
### Sub-Mode: merge

Combine duplicate memories with high keyword overlap. The merge operation identifies pairwise duplicate candidates within topic clusters, presents them for interactive selection, merges content with a keyword superset guarantee, tombstones the absorbed secondary, updates cross-references, and regenerates indexes. Follows the Shared Sub-Mode Skeleton above; deltas below. (Its Interactive Selection step below does not restate the MANDATORY STOP language verbatim -- see that step's own text for the exact wording used at this call site.)

#### Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If fewer than 2 non-tombstoned memories:
   Display: "Merge requires at least 2 active memories. Vault has {count}."
   Return early.
```

#### Pairwise Keyword Overlap Algorithm

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

#### Dry-Run Mode

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

#### Interactive Selection (AskUserQuestion)

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

#### Primary Determination

For each selected pair, determine which memory is primary (target) and which is secondary (absorbed):

```
Primary selection rules (first match wins):
1. Higher retrieval_count -> primary
2. If retrieval_count equal: older created date -> primary
3. If both equal: alphabetically first id -> primary (deterministic tiebreaker)
```

#### Merged Content Template

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

#### Keyword Superset Guarantee

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

#### Tombstone Application

After successful merge, tombstone the secondary memory:

```
Add to secondary's frontmatter (preserve all existing fields):
  status: tombstoned
  tombstoned_at: {today ISO8601}
  tombstone_reason: "merged_into:{primary.id}"

Do NOT delete the file.
Do NOT remove from index (index regeneration will include tombstone status).
```

The tombstone fields are identical to those used by the Purge Sub-Mode above:
- `status: tombstoned`
- `tombstoned_at: {ISO8601 date}`
- `tombstone_reason: "{reason}"` -- for merge, reason is `"merged_into:{primary_id}"`

#### Cross-Reference Update

After tombstoning, update wiki-link references across all non-tombstoned memories:

```
1. Scan all .memory/10-Memories/*.md files
2. For each file that is NOT tombstoned:
   Search for [[{secondary.id}]] references
   Replace with [[{primary.id}]]
3. Log all replacements: "{file}: replaced [[{secondary.id}]] -> [[{primary.id}]]"
```

#### Index Regeneration

After ALL merges in the batch are complete (not after each individual merge):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Include tombstoned memories with status: "tombstoned"
2. Regenerate index.md using "Index Regeneration Pattern"
   - Exclude tombstoned memories from active listings
3. Regenerate .memory/10-Memories/README.md
   - Exclude tombstoned memories from the listing
```

#### Distill Log Entry

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

### Sub-Mode: compress

Reduce oversized memories to key points while preserving essential information. The compress operation identifies memories with high size penalty, presents them interactively, generates compressed versions, preserves originals in a History section, and ensures keyword preservation. Follows the Shared Sub-Mode Skeleton above; deltas below.

#### Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to compress."
   Return early.
```

#### Compress Candidate Identification

After scoring all memories via the Scoring Engine, select compress candidates:

```
compress_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.size_penalty > 0.5:  # token_count > 900
    compress_candidates.append(memory)

Sort by size_penalty descending (largest memories first)
```

**Edge Case**: If `compress_candidates` is empty, display:
```
No compress candidates found. All memories are within size limits (token_count <= 900).
```
Then exit the compress sub-mode without further action.

#### Dry-Run Behavior

When `--dry-run` is active, show candidates with estimates without writing any files:

```
## Compress Candidates (Dry Run)

| Memory | Tokens | Size Penalty | Topic | Est. Compressed |
|--------|--------|-------------|-------|-----------------|
| {id} | {token_count} | {size_penalty:.2f} | {topic} | ~{token_count * 0.4} |

{count} compress candidate(s) found.
Run /distill --compress without --dry-run to execute.
```

Return early after display. No files are modified.

#### Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT compress any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to compress. Original content will be preserved in a History section.",
  "header": "Compress Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tokens: {token_count} | Size penalty: {size_penalty:.2f} | Topic: {topic} | Retrievals: {retrieval_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for compression. Operation cancelled.
```
Then exit without changes.

#### Compression Execution

For each selected memory, compress following these steps:

```
1. Read the full memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse frontmatter and content sections
3. Extract original keywords from frontmatter

4. Generate compressed content:
   - Extract key points as bullet list
   - Preserve code blocks and examples verbatim
   - Remove redundant prose, verbose explanations, and filler
   - Target ~60% reduction (soft guideline, not enforced)
   - Maintain the core information and actionable details

5. Move original content to History section:
   - Insert before ## Connections section (if present), or at end of file
   - Use heading: ## History > ### Pre-Compression ({today})
   - Include full original content (between title heading and ## Connections)

6. Write compressed content as main body (between title heading and ## History)

7. Update frontmatter:
   - Recalculate token_count: word_count * 1.3, rounded down
   - Update modified to today (ISO date)
   - Preserve all other frontmatter fields unchanged

8. Keyword preservation check:
   original_keywords = set(memory.keywords)
   compressed_keywords = extract_keywords(compressed_content)
   missing = original_keywords - keywords_in_compressed_content

   If missing keywords found:
     - Add missing keywords explicitly to the compressed content
       (append "**Keywords**: {missing_keywords}" line if needed)
     - Log: "Keyword preservation: added {N} missing keywords to compressed content"

9. Write the updated memory file
```

#### Compressed Content Template

```markdown
---
{preserved frontmatter with updated token_count and modified}
---

# {title}

{compressed content - key points as bullet list, preserved code blocks}

## History

### Pre-Compression ({today})

{original content that was between title heading and ## Connections}

## Connections
{preserved connections section}
```

#### Batch Index Regeneration

After ALL compressions in the batch are complete (not after each individual compression):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Updated token_count values will be reflected
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Compress Log Entry

Log the compress operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "compress",
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
      "id": "{memory.id}",
      "tokens_before": N,
      "tokens_after": N,
      "compression_ratio": 0.42,
      "keywords_preserved": true,
      "action": "compressed"
    }
  ],
  "notes": "Compressed {N} memories. Total tokens saved: {tokens_saved}"
}
```

The `compression_ratio` is `tokens_after / tokens_before` (lower means more compression). The `keywords_preserved` boolean confirms all original keywords are present in the compressed content.

Update the distill-log.json `summary.total_compressed` counter by incrementing it by the number of compressed memories.

### Sub-Mode: refine

Improve memory metadata quality through two tiers of fixes. Tier 1 fixes are safe automatic corrections that require no user interaction. Tier 2 fixes are interactive improvements that require user confirmation via AskUserQuestion. Follows the Shared Sub-Mode Skeleton above; deltas below. (Tier 1 has no Interactive Selection step by design -- see Tier 1 below for the exemption.)

#### Edge Case Checks

Before candidate scanning, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to refine."
   Return early.
```

#### Quality Issue Scanning

Iterate all non-tombstoned memories and scan for quality issues:

```
tier1_fixes = []   # Automatic, no confirmation needed
tier2_fixes = []   # Interactive, require AskUserQuestion

for each memory in non_tombstoned_memories:
  # Read full memory file for content analysis

  # --- Tier 1: Automatic Fixes ---

  # 1. Keyword deduplication
  if memory.keywords has duplicates (case-insensitive):
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "keyword_dedup",
      "description": "Remove duplicate keywords (case-insensitive, keep first occurrence)",
      "before": memory.keywords,
      "after": deduplicated_keywords
    })

  # 2. Summary generation
  if memory.summary is empty or missing:
    generated_summary = first_line_of_content[:100]  # Truncate to ~100 chars
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "summary_gen",
      "description": "Generate summary from first line of content",
      "before": "",
      "after": generated_summary
    })

  # 3. Topic normalization
  if memory.topic has uppercase letters OR missing "/" separators OR trailing slashes:
    normalized_topic = memory.topic.lower().strip("/")
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "topic_normalize",
      "description": "Normalize topic path (lowercase, clean separators)",
      "before": memory.topic,
      "after": normalized_topic
    })

  # --- Tier 2: Interactive Fixes ---

  # 4. Keyword enrichment
  if len(memory.keywords) < 4:
    suggested_keywords = extract_keywords_from_content(memory.content, 5)
    new_keywords = [k for k in suggested_keywords if k not in memory.keywords]
    if new_keywords:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "keyword_enrich",
        "description": "Add suggested keywords based on content analysis",
        "current_keywords": memory.keywords,
        "suggested_additions": new_keywords[:5]
      })

  # 5. Category reclassification
  # Skip entirely when the memory has an explicit frontmatter `category:` field
  # (email-to-memory-preferences.md design §3.4) -- an explicit category is authoritative and
  # never content-inferred; this
  # only fires for the tags-derivation fallback path (pre-822 memories, and any future memory
  # without a `category:` field).
  if not memory.has_explicit_category_field:
    content_category = infer_category_from_content(memory.content)
    if content_category != memory.category:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "category_reclassify",
        "description": "Category may not match content",
        "current_category": memory.category,
        "suggested_category": content_category
      })

  # 6. Topic path correction
  cluster_topics = get_topic_patterns_from_cluster(memory.topic)
  if memory.topic not consistent with cluster_topics:
    tier2_fixes.append({
      "memory": memory.id,
      "fix": "topic_correct",
      "description": "Topic path inconsistent with cluster patterns",
      "current_topic": memory.topic,
      "suggested_topic": corrected_topic
    })
```

#### "No Issues Found" Early Return

If both `tier1_fixes` and `tier2_fixes` are empty:
```
No quality issues found. All memories have clean metadata.
```
Then exit without further action.

#### Tier 1 Execution (Automatic)

Tier 1 fixes run without user interaction:

```
1. Display summary of Tier 1 fixes to be applied:
   ## Tier 1 Automatic Fixes

   | Memory | Fix | Description |
   |--------|-----|-------------|
   | {id} | keyword_dedup | Removed {N} duplicate keywords |
   | {id} | summary_gen | Generated summary from content |
   | {id} | topic_normalize | Normalized topic path |

2. Apply each fix:
   - keyword_dedup: Rewrite keywords array in frontmatter (case-insensitive dedup, keep first)
   - summary_gen: Add/update summary field in frontmatter
   - topic_normalize: Update topic field in frontmatter

3. Update modified date to today for each affected memory
```

#### Tier 2 Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step), if Tier 2 fixes exist. Do NOT apply Tier 2 fixes without explicit user selection.**

If `tier2_fixes` is not empty, present via AskUserQuestion multiSelect:

```json
{
  "question": "Select quality improvements to apply (Tier 2 - interactive fixes):",
  "header": "Refine Candidates ({count} issues found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}: {fix_type}",
      "description": "{description} | Current: {current_value} | Suggested: {suggested_value}"
    }
  ]
}
```

If the user selects no fixes, display:
```
No Tier 2 fixes selected. Only Tier 1 automatic fixes were applied.
```

#### Tier 2 Execution

For each selected Tier 2 fix:

```
- keyword_enrich: Append suggested keywords to frontmatter keywords array
- category_reclassify: Update first tag in frontmatter tags array
- topic_correct: Update topic field in frontmatter

Update modified date to today for each affected memory.
```

#### Batch Index Regeneration

After ALL fixes (Tier 1 and Tier 2) are complete:

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Refine Log Entry

Log the refine operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
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
      "id": "{memory.id}",
      "fixes_applied": ["keyword_dedup", "summary_gen"],
      "action": "refined"
    }
  ],
  "notes": "Refined {N} memories. Tier 1: {T1_count} fixes, Tier 2: {T2_count} fixes"
}
```

Update the distill-log.json `summary.total_refined` counter by incrementing it by the number of refined memories.

### Sub-Mode: auto

Automated non-interactive maintenance that runs only safe Tier 1 refine fixes. The auto mode is designed for routine maintenance without human oversight -- it explicitly excludes compress (requires AI-generated summaries that need review), purge, and merge. Its steps are a restricted delta against the Shared Sub-Mode Skeleton above: it has no Interactive Selection step by design (that is the whole point of "automated non-interactive"), so this is one of the sanctioned MANDATORY-STOP exemptions alongside `report` and (once specified) `--review`.

#### Auto Execution Flow

```
1. Run validate-on-read:
   - Check memory-index.json consistency with filesystem
   - Regenerate if stale

2. Run Tier 1 refine fixes ONLY (no AskUserQuestion calls):
   - Keyword deduplication: remove duplicate keywords (case-insensitive, keep first)
   - Summary generation: for memories with empty/missing summary, generate from first line of content (~100 chars)
   - Topic normalization: lowercase all topic paths, ensure "/" separators, no trailing slashes

3. For each fix applied:
   - Update the memory file frontmatter
   - Update modified date to today

4. Rebuild memory-index.json from filesystem state:
   - Use "JSON Index Maintenance" procedure
   - Regenerate index.md and .memory/10-Memories/README.md

5. Update memory_health in state.json:
   - Recalculate health_score
   - Update last_distilled timestamp
   - Increment distill_count

6. Skip ALL interactive operations:
   - No AskUserQuestion calls
   - No Tier 2 refine fixes
   - No compress operations
   - No purge operations
   - No merge operations
   - No dream operations
```

#### Explicitly Excluded Operations

| Operation | Reason for Exclusion |
|-----------|---------------------|
| Compress | AI-generated summaries require human review |
| Purge | Tombstoning decisions need user judgment |
| Merge | Content combination needs user oversight |
| Tier 2 Refine | Interactive fixes require user selection |
| Dream | Event-evidence-driven revision is a judgment call requiring human review |

#### Change Summary Display

After auto mode completes, display a summary of changes:

```
## Auto Distill Complete

| Fix Type | Count | Details |
|----------|-------|---------|
| Keyword dedup | {N} | Removed duplicates in {N} memories |
| Summary gen | {N} | Generated summaries for {N} memories |
| Topic normalize | {N} | Normalized topics in {N} memories |

**Total fixes**: {total_count} across {memory_count} memories
**Health score**: {score}/100 ({status})
```

#### "No Changes Needed" Edge Case

If no Tier 1 fixes are applicable:
```
Auto distill: No changes needed. All memories have clean metadata.
Health score: {score}/100 ({status})
```

#### Auto Log Entry

Log the auto operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
  "session_id": "sess_...",
  "pre_metrics": { ... },
  "post_metrics": { ... },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "fixes_applied": ["keyword_dedup"],
      "action": "refined"
    }
  ],
  "notes": "auto mode - Tier 1 fixes only. Applied {N} fixes to {M} memories"
}
```

Note: Auto mode uses `type: "refine"` (not a separate type) with `"notes"` containing `"auto mode"` to distinguish from interactive refine operations.

### Sub-Mode: revise

READ .claude/context/project/memory/patterns/distill-revise-submode.md now and follow it exactly.

### Sub-Mode: meta

READ .claude/context/project/memory/patterns/distill-meta-submode.md now and follow it exactly.

### Sub-Mode: review

READ .claude/context/project/memory/patterns/distill-review-submode.md now and follow it exactly.

### Sub-Mode: learn

READ .claude/context/project/memory/patterns/distill-learn-submode.md now and follow it exactly.

### Sub-Mode: dream

READ .claude/context/project/memory/patterns/distill-dream-submode.md now and follow it exactly.

### Distill Log Schema

Operations are logged to `.memory/distill-log.json` for tracking maintenance history.

#### Schema

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "distill_{timestamp}",
      "timestamp": "ISO8601",
      "type": "report|purge|merge|compress|refine|gc|review",
      "session_id": "sess_...",
      "pre_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100,
        "purge_candidates": 0,
        "merge_candidates": 0,
        "compress_candidates": 0
      },
      "post_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100,
        "purge_candidates": 0,
        "merge_candidates": 0,
        "compress_candidates": 0
      },
      "affected_memories": [],
      "notes": ""
    }
  ],
  "summary": {
    "total_operations": 0,
    "total_purged": 0,
    "total_merged": 0,
    "total_compressed": 0,
    "total_refined": 0,
    "total_gc_deleted": 0,
    "total_reviewed": 0,
    "last_operation": null
  }
}
```

#### Operation Types

| Type | Description | Log File |
|------|-------------|----------|
| `report` | Health report generated (read-only) | `.memory/distill-log.json` |
| `purge` | Memories removed via tombstone pattern | `.memory/distill-log.json` |
| `merge` | Duplicate memories combined | `.memory/distill-log.json` |
| `compress` | Oversized memories summarized | `.memory/distill-log.json` |
| `refine` | Memory quality improved | `.memory/distill-log.json` |
| `gc` | Hard-delete tombstoned memories past grace period | `.memory/distill-log.json` |

`revise`, `meta`, `learn`, and `dream` log to their own dedicated files
(`.memory/revise-log.json`, `.memory/meta-log.json`, `.memory/learn-harvest-log.json`,
`.memory/dream-log.json` respectively -- see each sub-mode's own Log Schema subsection above) and
are not part of this shared enum. `review` is optionally logged here for audit purposes only
(see the `--review` sub-mode's own Log Entry subsection).

For `report` operations, `pre_metrics` and `post_metrics` are identical (no changes made).

### State Integration

After each distill operation, update `memory_health` in `specs/state.json`:

```json
{
  "memory_health": {
    "last_distilled": "ISO8601 timestamp",
    "distill_count": 1,
    "total_memories": 5,
    "never_retrieved": 2,
    "health_score": 85,
    "status": "healthy",
    "last_dream": "ISO8601 timestamp or null (never dreamed)",
    "dream_count": 0
  }
}
```

The `memory_health` field is a top-level sibling of `repository_health` in state.json. Update it after every distill operation (including report-only operations).

**Field update rules by sub-mode**:

| Field | report / dream (redefined) / review | purge/merge/compress/refine/gc/auto/revise | dream (pre-redefinition, historical) |
|-------|--------------------------------------|---------------------------------------------|----------------------------------------|
| `last_distilled` | Updated | Updated | Updated |
| `distill_count` | NOT incremented | Incremented | Incremented |
| `total_memories` | Updated | Updated | Updated |
| `never_retrieved` | Updated | Updated | Updated |
| `health_score` | Updated | Updated | Updated |
| `status` | Updated | Updated | Updated |
| `last_dream` | Updated (dream only; NOT updated by report/review) | NOT updated | Updated |
| `dream_count` | Incremented (dream only; NOT incremented by report/review) | NOT incremented | Incremented |

**Rationale**: The redefined `dream` and `report`/`--review` are read-only with respect to the
memory vault -- none of the three modifies any `.memory/10-Memories/*.md` file, so none
increments `distill_count` (which tracks maintenance operations that actually changed the
vault). `--revise` inherited the old `dream`'s vault-mutating role and is grouped with the other
mutating sub-modes for `distill_count` purposes. The `last_distilled` timestamp is still updated
by every sub-mode listed because it tracks when the vault was last assessed at all (a lightweight
existing-coverage check counts as an assessment), not only when it was last modified.
`last_dream`/`dream_count` mirror `last_distilled`/`distill_count` but scoped to `dream` runs
specifically (still updated by the redefined `dream`, which retains its own `--since {last_dream}`
incremental-scan bookkeeping over `history.jsonl` even though it no longer mutates memories) --
they are untouched by every other sub-mode, including `report` and `--review`, since those never
run `dream`'s own history-ingestion logic. `--meta`, `--review`, and `--learn` track their own
run bookkeeping in their own log files (`meta-log.json`, and optionally `distill-log.json` for
`--review`, `learn-harvest-log.json` for `--learn`) rather than in this shared table, since none
of the three is a vault-scoring/maintenance operation in the sense this table was designed for.

