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

Every mutating `/distill` sub-mode (`purge`, `gc`, `merge`, `compress`, `refine`, `auto`,
and the telemetry-sourced sub-modes added after them) follows the same seven-step shape. This
section states that shape once, with named, generic placeholders; each sub-mode's own
specification -- inline below for `gc` and `auto`, or in its extracted
`distill-<submode>-submode.md` file (reached via the stub pointer at that sub-mode's heading
below) for `purge`, `merge`, `compress`, `refine`, `revise`, `meta`, `review`, `learn`, and
`dream` -- states only its deltas from this skeleton: its specific candidate logic, prompts,
execution steps, and log payload, rather than restating the shape itself. This generalizes a
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

**Non-mutating sub-modes** (`report`, and `--review`) do not carry step 4's mandatory stop,
since nothing is proposed for the user to confirm -- each such sub-mode states this exemption
explicitly, rather than leaving it as a silent omission, in `report`'s inline specification below
or (for `--review`) in `distill-review-submode.md`, reached via the "Sub-Mode: review" stub
pointer below.

### Purge Sub-Mode

READ .claude/context/project/memory/patterns/distill-purge-submode.md now and follow it exactly.

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

The gc sub-mode performs hard deletion of tombstoned memories that have passed the 7-day grace period. Follows the Shared Sub-Mode Skeleton above; deltas below. Its logical pair is the Purge Sub-Mode (`distill-purge-submode.md`; the "Purge Sub-Mode" stub pointer above dispatches there), with only the Link-Scan/Retrieval-Exclusion/health-report infrastructure immediately below (shared between purge and gc, staying inline here) between them, no other sub-mode -- gc hard-deletes what purge has already tombstoned once the grace period elapses.

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

READ .claude/context/project/memory/patterns/distill-merge-submode.md now and follow it exactly.

### Sub-Mode: compress

READ .claude/context/project/memory/patterns/distill-compress-submode.md now and follow it exactly.

### Sub-Mode: refine

READ .claude/context/project/memory/patterns/distill-refine-submode.md now and follow it exactly.

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

