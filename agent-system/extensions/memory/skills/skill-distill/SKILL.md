---
name: skill-distill
description: Memory vault analysis and maintenance - auto scoring/refine, and telemetry-sourced revise/learn sub-modes against the hosted knowledge store. Invoke for /distill command operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Distill Skill (Direct Execution)

Direct execution skill for memory vault analysis and maintenance. Handles the `/distill`
command's three surviving sub-modes: `auto` (automated, non-interactive Tier 1 refine fixes
against the local vault's scoring engine) and two telemetry-sourced sub-modes retargeted onto the
hosted Sapience knowledge store (`--revise`/`--learn`). Consolidation and compaction, staleness
re-confirmation of load-bearing positions, and active conflict detection between a person's own
notes are performed server-side by the hosted store, so `/distill` provides none of those
operations locally any more -- see `context/project/memory/distill-usage.md` for the full
reasoning. `--meta`, `--review`, and `--dream` touch no vault store and are dispatched by
`/telemetry` instead -- see `skill-telemetry/SKILL.md` (core extension). Memory *creation* is a
separate concern owned by the sibling `skill-learn` skill.

## Context References

Reference (do not load eagerly):
- Path: `@.memory/memory-index.json` - Machine-queryable memory index
- Path: `@.claude/context/project/memory/distill-usage.md` - Usage guide
- Path: `@.claude/context/standards/telemetry-guardrails.md` - Binding design constraints for the telemetry-sourced sub-modes (four-tier source model, evaluator-outside-the-loop rule, six failure modes, `gen_ai.*` borrowing rule, cross-repo invocation discipline)
- Path: `@.claude/skills/skill-learn/SKILL.md` - the sibling skill this file was split from. Its "Validate-on-Read" and "JSON Index Maintenance" sections are the shared procedures this file's body cites as "above" or "below" throughout -- both skills operate on the same `.memory/memory-index.json`, and those two procedures were not duplicated by the split; they live in `skill-learn/SKILL.md` only.

---

## Mode: distill

Memory vault distillation: scoring, health reporting, and maintenance operations. Invoked by `/distill` command with `mode=distill`.

### Prerequisites

**Validate-on-Read**: Before scoring, run the validate-on-read procedure from the "Validate-on-Read" section above to ensure `memory-index.json` is consistent with the filesystem. If stale, regenerate using the "JSON Index Maintenance" procedure before proceeding.

### Sub-Mode Dispatch

| Sub-Mode | Description | Status |
|----------|-------------|--------|
| `auto` | Automated distillation (Tier 1 refine only) | Available |
| `revise` | Event-and-OTel-correlated hosted-knowledge-object review | Available |
| `learn` | Retroactive batch harvest across already-completed tasks | Available |

Three sub-modes are available. `report`, `purge`, `merge`, `compress`, `refine`, and `gc` provide
no local equivalent, because the hosted Sapience store already performs consolidation and
compaction, staleness re-confirmation, and conflict detection server-side -- see
`context/project/memory/distill-usage.md`. `--meta`, `--review`, and `--dream` are dispatched by
`/telemetry` instead -- see `skill-telemetry/SKILL.md` (core extension).

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
                          # research/plan/implement-phase auto-retrieval (that path reads the
                          # hosted Sapience store, not this local vault, at all), so a zero
                          # retrieval_count is expected, not a staleness signal
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

Every mutating `/distill` sub-mode (`auto`, and the telemetry-sourced sub-modes `revise` and
`learn`) follows the same seven-step shape. This section states that shape once, with named,
generic placeholders; each sub-mode's own specification -- inline below for `auto`, or in its
extracted `distill-<submode>-submode.md` file (reached via the stub pointer at that sub-mode's
heading below) for `revise` and `learn` -- states only its deltas from this skeleton: its
specific candidate logic, prompts, execution steps, and log payload, rather than restating the
shape itself.

1. **Edge Case Checks** -- Validate preconditions before identifying candidates (e.g. run
   validate-on-read, confirm a minimum count of eligible memories, or -- for `revise` -- the
   hosted-store reachability probe). If a precondition fails, display a specific message and
   return early without further action.
2. **Candidate Identification** -- Compute the sub-mode's specific candidate set from scored or
   otherwise-derived data. If a shared dependency like validate-on-read or the Scoring Engine is
   used, cite it by name rather than re-deriving it.
3. **Dry-Run** -- When `--dry-run` is active, display what the sub-mode would do (the specific
   candidate list, with sub-mode-relevant fields) and return early. No file is modified and no
   knowledge object is written.
4. **Interactive Selection (MANDATORY STOP)** -- Present candidates via `AskUserQuestion`
   (`multiSelect: true` for any sub-mode selecting among multiple candidates). **This step is
   non-negotiable in every sub-mode that mutates the vault or writes a hosted knowledge object: no
   mutation may proceed without an explicit, user-confirmed selection at this step.** If no
   candidates exist, or the user selects none, display a specific message and exit without
   changes.
5. **Execution** -- Apply the confirmed operation. This step's actual content is the most
   sub-mode-specific of the seven and is stated in full in each sub-mode's own section -- it is
   never usefully reduced to a generic placeholder, since the refine/SUPERSEDE/CREATE mechanics
   differ in every case.
6. **Batch Index Regeneration** -- For `auto` only, after the entire batch of confirmed operations
   completes (not after each individual one), regenerate `memory-index.json` (via the "JSON Index
   Maintenance" procedure in `skill-learn/SKILL.md`), `index.md`, and
   `.memory/10-Memories/README.md`. `revise` and `learn` write hosted knowledge objects directly
   and need no local index regeneration at all -- see each sub-mode's own Run Record subsection.
7. **Log Entry** -- For `auto`, log the operation to `.memory/distill-log.json` per the Distill
   Log Schema below, and update the relevant `summary` counter, then update `memory_health` in
   `specs/state.json` per the State Integration section below. `revise` and `learn` instead append
   one `specs/events.jsonl` event per run via `events-append.sh` and touch neither
   `.memory/distill-log.json` nor `memory_health` -- see each sub-mode's own Run Record
   subsection.

**`auto`** does not carry step 4's mandatory stop, because it runs only safe, non-interactive
Tier 1 fixes by design. This exemption is stated explicitly, rather than left as a silent
omission, in its own inline specification below.

### Sub-Mode: auto

Automated non-interactive maintenance that runs only safe Tier 1 refine fixes. The auto mode is designed for routine maintenance without human oversight -- it explicitly excludes compress (requires AI-generated summaries that need review), purge, and merge. Its steps are a restricted delta against the Shared Sub-Mode Skeleton above: it has no Interactive Selection step by design (that is the whole point of "automated non-interactive"), so this is one of the sanctioned MANDATORY-STOP exemptions alongside `report`.

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

### Sub-Mode: learn

READ .claude/context/project/memory/patterns/distill-learn-submode.md now and follow it exactly.

`--meta`, `--review`, and `--dream` are dispatched by `/telemetry` instead -- see
`skill-telemetry/SKILL.md` (core extension) for their stub pointers.

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
      "type": "refine",
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
    "total_refined": 0,
    "last_operation": null
  }
}
```

#### Operation Types

| Type | Description | Log File |
|------|-------------|----------|
| `refine` | `auto` mode's Tier 1 fixes (keyword dedup, summary generation, topic normalization) | `.memory/distill-log.json` |

`refine` is the only surviving type in this shared enum: `report`, `purge`, `merge`, `compress`,
and `gc` provide no local equivalent, because the hosted Sapience store already performs
consolidation and compaction, staleness re-confirmation, and conflict detection server-side -- see
`context/project/memory/distill-usage.md`. `revise` and `learn` operate against hosted knowledge
objects rather than `.memory/`, and log their own run records as `specs/events.jsonl` events via
`events-append.sh` instead of a dedicated `.memory/` file -- see each sub-mode's own Run Record
subsection above -- so they are not part of this shared enum either. `--meta`, `--review`, and
`--dream` log to `specs/telemetry/` instead -- see `skill-telemetry/SKILL.md`'s Telemetry Log
Schemas (core extension).

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
    "status": "healthy"
  }
}
```

The `memory_health` field is a top-level sibling of `repository_health` in state.json. `auto` is
the only sub-mode that updates it now. There is no `last_dream`/`dream_count` coupling here any
more: `--dream` moved to `/telemetry` and its own log file (`specs/telemetry/dream-log.json`) is
its sole `--since` cursor, with no `state.json` coupling at all.

**Field update rules**:

| Field | auto |
|-------|--------|
| `last_distilled` | Updated |
| `distill_count` | Incremented |
| `total_memories` | Updated |
| `never_retrieved` | Updated |
| `health_score` | Updated |
| `status` | Updated |

**Rationale**: Neither `--revise` nor `--learn` touches `memory_health` at all: both operate
against hosted knowledge objects, not `.memory/`, and each tracks its own run record as a
`specs/events.jsonl` event instead (see each sub-mode's own Run Record subsection), which is why
both are absent from this table. `--meta`, `--review`, and `--dream` moved to `/telemetry` and
track their own run bookkeeping in `specs/telemetry/` log files -- see
`skill-telemetry/SKILL.md` -- not in this table at all.

