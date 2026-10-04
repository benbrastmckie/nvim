# Distill Usage Guide

Usage guide for the `/distill` command and memory vault maintenance.

## Quick Reference

```
/distill                  # Health report (read-only)
/distill --purge          # Tombstone stale memories
/distill --merge          # Combine duplicate memories
/distill --compress       # Summarize oversized memories
/distill --refine         # Improve metadata quality
/distill --gc             # Hard-delete tombstoned memories
/distill --auto           # Automated Tier 1 maintenance

# Telemetry-sourced sub-modes (see skill-distill/SKILL.md's Shared Sub-Mode Skeleton and
# context/project/memory/telemetry-guardrails.md for the shared design constraints):
/distill --revise         # Event-and-OTel-correlated memory refactoring proposals
/distill --meta           # Cross-repo agent-system improvement proposals
/distill --review "<q>"   # Read-only ad hoc inquiry over the vault and all four source tiers
/distill --learn          # Retroactive batch harvest across already-completed tasks
/distill --dream          # Speculative direction-finding over history.jsonl's recurring themes

# Modifier flags (combinable with any sub-mode):
/distill --purge --dry-run    # Preview without changes
/distill --merge --verbose    # Show detailed scoring
```

## Sub-Mode Workflows

### Health Report (bare `/distill`)

Run with no arguments to get a vault health overview:
- Overview metrics (total memories, tokens, oldest/newest)
- Category distribution table
- Topic cluster analysis
- Retrieval statistics (never retrieved, most retrieved)
- Maintenance candidates (purge, merge, compress, review)
- Tombstoned memories section
- Health score (0-100) with status label

The report is read-only -- no files are modified.

### Purge (`/distill --purge`)

Identifies memories that are stale (staleness >0.8) or have zero retrievals past 30 days. Workflow:

1. Scoring engine runs on all non-tombstoned memories
2. Candidates sorted by category TTL and composite score
3. Interactive selection via AskUserQuestion (multiSelect)
4. Selected memories get tombstone frontmatter (`status: tombstoned`)
5. Link-scan warns about stale `[[MEM-*]]` references
6. Index regenerated, state.json updated

Tombstoned memories remain on disk for 7 days before `--gc` can remove them.

### Merge (`/distill --merge`)

Combines memories with >60% keyword overlap within topic clusters. Workflow:

1. Pairwise keyword overlap computed within each topic cluster
2. Pairs above 60% threshold presented per cluster
3. User selects pairs to merge
4. Primary determined by retrieval count (then age, then alphabetical)
5. Primary rewritten with merged content; secondary tombstoned
6. Keyword superset guarantee enforced (merge aborts if violated)
7. Cross-references updated (`[[secondary]]` -> `[[primary]]`)

### Compress (`/distill --compress`)

Reduces oversized memories (>900 tokens, size_penalty >0.5) to key points. Workflow:

1. Candidates identified by size penalty
2. User selects memories to compress
3. Key points extracted, code blocks preserved, prose reduced
4. Original content moved to `## History > ### Pre-Compression` section
5. Keywords checked and preserved in compressed content
6. Token count recalculated

Target: ~60% reduction (soft guideline).

### Refine (`/distill --refine`)

Two-tier metadata quality improvement:

**Tier 1 (automatic, no interaction)**:
- Keyword deduplication (case-insensitive)
- Summary generation for memories with empty summaries
- Topic normalization (lowercase, clean separators)

**Tier 2 (interactive, requires confirmation)**:
- Keyword enrichment (add suggested keywords when <4 present)
- Category reclassification (when content does not match tag)
- Topic path correction (when inconsistent with cluster patterns)

### GC (`/distill --gc`)

Hard-deletes tombstoned memories past the 7-day grace period:

1. Scans for tombstoned memories where `days_since_tombstoned >= 7`
2. Presents eligible memories for selection
3. Permanently removes .md files from disk
4. Removes entries from memory-index.json
5. Regenerates all indexes

This is the only destructive operation in the memory system.

### Auto (`/distill --auto`)

Non-interactive automated maintenance. Runs only Tier 1 refine fixes:
- Keyword deduplication
- Summary generation
- Topic normalization

Explicitly excludes: compress (needs AI review), purge, merge, Tier 2 refine, and all five
telemetry-sourced sub-modes below. Suitable for routine maintenance without human oversight.

### Revise (`/distill --revise`)

Event-and-OTel-correlated memory refactoring proposals. Interactive by default (never runs under
`--auto`). Workflow:

1. Validate-on-read, then gate on vault emptiness
2. Cheap event-count gate: `events-query.sh --format summary-counts [--since {last_revise}]`
   -- if `specs/events.jsonl` does not exist yet (`total_events: 0`), this is a normal,
   first-class outcome, not an error: revise continues using vault scoring alone
   (staleness/duplicate/size) and reports zero correlations
3. Pull deviation/blocker events and reflection events via `events-query.sh
   --category deviation|blocker` / `--event-type reflection --format json-array` (producer-status
   note: the `reflection` event type has no live producer any more -- see
   `context/formats/events-format.md` -- so this pull surfaces only historical rows written
   before that retirement)
4. **New**: for events carrying a `cc_session_id`, join against OTel outcome records from that
   same Claude Code session (`cc_session_id == session.id`); if `CLAUDE_CODE_ENABLE_TELEMETRY=1`
   is unset, this is a first-class degraded path, announced explicitly, not silent
5. Correlate events to memories: task-number substring match first, keyword/topic overlap
   fallback (same formula `/distill --merge` uses)
6. Classify each correlated memory as corroborated / contradicted / gap; a pattern needs
   3+ occurrences at the same checkpoint/event_type to count as contradicted or a gap
7. Interactive selection via AskUserQuestion -- corroborated memories are noted only;
   contradicted memories offer UPDATE (with the proposed new body shown for review) /
   TOMBSTONE (`tombstone_reason: "revise_superseded"`) / SKIP; gaps offer CREATE (if durable
   knowledge) or escalate to `--meta` (if a system change)
8. Index regenerated as a batch; operation logged to `.memory/revise-log.json`; state.json
   updated (`last_revise`, `revise_count`)

### Meta (`/distill --meta`)

Cross-repo agent-system improvement proposals. Interactive by default (never runs under
`--auto`). Consumes the existing `$GLOBAL_ROOT` / `--local` mechanism verbatim -- does not invent
a parallel resolver. Workflow:

1. Resolve `target_root` ($GLOBAL_ROOT by default, or the invoking repo with `--local`)
2. Surface recurring (three-strikes) deviation/blocker or reflection patterns pointing at a
   named skill/hook/rule/checkpoint
3. Present via AskUserQuestion (Create as task / Note in report only / Skip), with an explicit
   "Yes, create tasks" confirmation gate
4. Task creation delegates to `meta-builder-agent` -- `--meta` never reimplements the `/task`
   primitive. Extension targeting inherits `meta-builder-agent`'s own known limitation (defaults
   to `core`, extension-scoped proposals need human correction at the confirmation step)
5. States the single-repo signal limitation explicitly: `events.jsonl` is per-repo, so `--meta`
   sees only `target_root`'s own event store
6. Operation logged to `.memory/meta-log.json`

### Review (`/distill --review "<question>"`)

Strictly read-only ad hoc inquiry spanning all four source tiers (OTel, `events.jsonl`,
`history.jsonl`, transcripts), driven by the user's free-text question. No mutation, so no
`AskUserQuestion` gate is needed -- this exemption is stated explicitly, not a silent omission.
Any actionable finding funnels to `--meta`, `--revise`, or `/learn`; `--review` never acts
directly.

### Learn (`/distill --learn`)

Retroactive, batch harvest across already-archived tasks whose `memory_candidates` were never
harvested. Distinct from `/learn --task N` (single task, any time) and from `/todo`'s
archive-time harvest (automatic, only at archival). Sources from the task's transcript within
the 30-day replay window, falling back to `history.jsonl` plus the task's own archived `specs/`
artifacts beyond it. Proposes via AskUserQuestion; never auto-creates memories. Operation logged
to `.memory/learn-harvest-log.json`.

### Dream (`/distill --dream`)

Speculative direction-finding over the user's own prompt history (`history.jsonl`), redefined
from its prior event-correlation role (now `--revise`) and improvement-proposal role (now
`--meta`). No event-correlation machinery of its own. Workflow:

1. Locate `history.jsonl` (global), slice to this repo via each line's `project` field
2. Cluster prompts by keyword/topic overlap (same formula `/distill --merge` uses), applying the
   same three-strikes recurrence threshold `--revise` uses
3. For each recurring cluster, check whether an existing memory or open task already covers the
   theme; only uncovered themes surface as candidates
4. Terminal-only narrative output, like the bare `/distill` health report -- no dated report
   file is written to disk. No `AskUserQuestion` mutation gate (nothing mutates) -- this
   exemption is stated explicitly. Any resulting action funnels to `--meta` or `/learn`
5. Operation logged to `.memory/dream-log.json`; state.json updated (`last_dream`, `dream_count`)

## Scoring Formula

Each memory receives a composite score from four weighted components:

```
composite = (staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)
```

| Component | Range | Interpretation |
|-----------|-------|----------------|
| Staleness | 0.0-1.0 | Days since last retrieval / 90, with FSRS adjustment |
| Zero-retrieval | 0.0 or 1.0 | Binary: never retrieved and older than 30 days |
| Size penalty | 0.0+ | Linear above 600 tokens: (tokens - 600) / 600 |
| Duplicate | 0.0-1.0 | Max keyword overlap with any other memory |

Health score formula: `100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)`

| Score | Status |
|-------|--------|
| 80-100 | healthy |
| 60-79 | manageable |
| 40-59 | concerning |
| 0-39 | critical |

## Recommended Maintenance Cadence

| Action | Frequency | Command |
|--------|-----------|---------|
| Health check | Weekly | `/distill` |
| Auto maintenance | After every 5-10 new memories | `/distill --auto` |
| Full refine | Monthly | `/distill --refine` |
| Purge review | Monthly or when health <60 | `/distill --purge` |
| Merge check | When duplicate score >0.6 appears | `/distill --merge` |
| Compress check | When size penalty >0.5 appears | `/distill --compress` |
| GC cleanup | After purge, when 7+ days elapsed | `/distill --gc` |
| Revise review | Periodically, or after a burst of deviations/blockers/reflections | `/distill --revise` |
| Meta proposals | Periodically, or after a burst of recurring friction | `/distill --meta` |
| Learn harvest | Occasionally, to catch declined/predating candidates | `/distill --learn` |
| Dream direction-finding | Periodically, for open-ended prompt-history review | `/distill --dream` |

## Memory Lifecycle

```
Create          Use               Capture           Maintain
------          ---               -------           --------
/learn    ->    auto-retrieval    ->    /todo        ->    /distill
                in /research,           harvests           scores,
                /plan, /implement       memory             reports,
                                        candidates         and maintains
```

## Telemetry-Sourced Sub-Mode Log Files

Each telemetry-sourced sub-mode logs to its own file rather than sharing
`.memory/distill-log.json`'s closed `type` enum -- see each sub-mode's own Log Schema subsection
in `skill-distill/SKILL.md` for the full shape:

| Sub-Mode | Log File |
|----------|----------|
| `--revise` | `.memory/revise-log.json` |
| `--meta` | `.memory/meta-log.json` |
| `--review` | `.memory/distill-log.json` (optional, audit only) |
| `--learn` | `.memory/learn-harvest-log.json` |
| `--dream` | `.memory/dream-log.json` |

Example `--revise` log entry (mirrors the general Distill Log Schema's `version`/`operations[]`/
`summary` shape, with revise-specific fields including the new OTel join):

```json
{
  "id": "revise_{timestamp}",
  "timestamp": "ISO8601",
  "type": "revise",
  "since": "ISO8601 or null (first run)",
  "events_ingested": {"total_events": 0, "deviation": 0, "blocker": 0, "reflection": 0},
  "otel_joins": {"sessions_with_cc_session_id": 0, "otel_enabled": true, "outcome_records_matched": 0},
  "classification": {"corroborated": 0, "contradicted": 0, "gap": 0},
  "affected_memories": [{"id": "MEM-...", "classification": "contradicted", "action": "updated"}]
}
```

Example (redefined) `--dream` log entry -- narrower than before, since dream no longer
classifies memories or creates tasks itself:

```json
{
  "id": "dream_{timestamp}",
  "timestamp": "ISO8601",
  "type": "dream",
  "since": "ISO8601 or null (first run)",
  "prompts_scanned": 0,
  "themes_surfaced": 0,
  "themes_with_existing_coverage_skipped": 0
}
```

## --dry-run and --verbose

- `--dry-run`: Available on all maintenance sub-modes (purge, merge, compress, refine, gc,
  revise, meta, learn) and accepted (as a no-op) on the two read-only sub-modes (review, dream).
  Shows what would happen without writing any files. Useful for previewing before committing to
  changes.
- `--verbose`: Shows detailed per-memory scoring breakdown including individual component values (staleness, zero_retrieval, size_penalty, duplicate) alongside the composite score.
