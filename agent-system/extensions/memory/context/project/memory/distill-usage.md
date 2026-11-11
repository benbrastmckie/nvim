# Distill Usage Guide

Usage guide for the `/distill` command and memory vault maintenance.

## Quick Reference

```
/distill --auto           # Automated Tier 1 maintenance (local vault)

# Telemetry-sourced sub-modes (see skill-distill/SKILL.md's Shared Sub-Mode Skeleton and
# context/standards/telemetry-guardrails.md for the shared design constraints). Both operate
# against the hosted Sapience knowledge store, never `.memory/`:
/distill --revise         # Event-and-OTel-correlated review of hosted knowledge objects
/distill --learn          # Retroactive batch harvest across already-completed tasks

# Modifier flags (combinable with any sub-mode):
/distill --auto --dry-run     # Preview without changes
/distill --auto --verbose     # Show detailed scoring
```

A bare `/distill` (no sub-mode flag) prints this usage and exits; there is no default sub-mode,
because every surviving sub-mode either mutates the vault (`auto`) or requires an interactive
gate (`revise`, `learn`).

`--meta`, `--review`, and `--dream` moved to `/telemetry --meta|--review|--dream` -- they touch
no vault store and live in core now. See `skill-telemetry/SKILL.md`.

## Why `report`, `--purge`, `--merge`, `--compress`, `--refine`, and `--gc` Are Not Here

Vault maintenance at the scale those six sub-modes once addressed -- consolidation and
compaction of accumulated knowledge, staleness re-confirmation of load-bearing positions, and
active conflict detection between a person's own notes -- is performed server-side by the hosted
Sapience knowledge store. `/distill` therefore provides none of those operations locally: porting
them would duplicate a service the store already supplies. This capability was observed directly
in a session briefing against the hosted store (reporting consolidated knowledge-object counts,
a stale-position re-confirmation prompt, and open conflicts awaiting resolution); the exact
figures from that one observation are a snapshot of the store's state at that moment, not a
standing fact about the store's current contents, and are not restated here.

`auto`'s local Tier 1 refine fixes are unaffected by this: they are genuinely local
(`.memory/10-Memories/*.md` frontmatter hygiene) and have no hosted-store equivalent to defer to.

## Sub-Mode Workflows

### Auto (`/distill --auto`)

Non-interactive automated maintenance against the local vault. Runs only Tier 1 refine fixes:
- Keyword deduplication
- Summary generation
- Topic normalization

Suitable for routine maintenance without human oversight. Does not touch the hosted knowledge
store.

### Revise (`/distill --revise`)

Event-and-OTel-correlated review of hosted knowledge objects. Interactive by default (never runs
under `--auto`). Workflow:

1. Cheap event-count gate: `events-query.sh --format summary-counts [--since {last_revise}]`
   -- if `specs/events.jsonl` does not exist yet (`total_events: 0`), this is a normal,
   first-class outcome, not an error: revise has nothing to cluster and reports zero
   correlations
2. Pull deviation/blocker events and reflection events via `events-query.sh
   --category deviation|blocker` / `--event-type reflection --format json-array` (producer-status
   note: the `reflection` event type has no live producer any more -- see
   `context/formats/events-format.md` -- so this pull surfaces only historical rows written
   before that retirement)
3. For events carrying a `cc_session_id`, join against OTel outcome records from that same
   Claude Code session (`cc_session_id == session.id`); if `CLAUDE_CODE_ENABLE_TELEMETRY=1` is
   unset, this is a first-class degraded path, announced explicitly, not silent
4. Cluster events into recurring patterns: task-number substring match first, keyword/topic
   overlap fallback; a cluster needs 3+ occurrences at the same checkpoint/event_type to cross
   the three-strikes threshold
5. Run the mandatory reachability probe -- one query known to match an existing `[repo:nvim]`
   knowledge object -- before any classification. `sapience-retrieve.sh` splits its failure exit
   code (1 benign no-match, 2 genuine transport/HTTP failure -- see the script's own header),
   but both are non-zero and the probe treats either as a failure uniformly; on probe failure,
   revise announces the degraded path and classifies nothing as a gap
6. Query the hosted store once per surviving cluster via `sapience-retrieve.sh`; classify as
   corroborated / contradicted / gap
7. Interactive selection via AskUserQuestion -- corroborated clusters are noted only;
   contradicted clusters offer SUPERSEDE (one `sapience-remember.sh` write carrying both the
   corrected guidance and the guidance it corrects, shown for review) / SKIP; gaps offer CREATE
   (if durable knowledge, via `sapience-remember.sh`) or escalate to `/telemetry --meta` (if a
   system change)
8. Run record appended to `specs/events.jsonl` via `events-append.sh`; no `memory_health` update,
   no file under `.memory/` touched

### Learn (`/distill --learn`)

Retroactive, batch harvest across already-archived tasks whose `memory_candidates` were never
harvested. Distinct from `/learn --task N` (single task, any time) and from `/todo`'s
archive-time harvest (automatic, only at archival). Sources from the task's transcript within
the 30-day replay window, falling back to `history.jsonl` plus the task's own archived `specs/`
artifacts beyond it. Proposes via AskUserQuestion; never auto-creates a knowledge object; writes
confirmed candidates via `sapience-remember.sh`, bounded to 3-8 notes per archived task. Run
record appended to `specs/events.jsonl` via `events-append.sh`; no `memory_health` update, no
file under `.memory/` touched.

`--meta`, `--review`, and `--dream` moved to `/telemetry --meta|--review|--dream` -- see
`skill-telemetry/SKILL.md` (core extension) for their workflows.

## Scoring Formula (`--auto` only)

Each memory receives a composite score from four weighted components -- used by `auto` to
recalculate `health_score`:

```
composite = (staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)
```

| Component | Range | Interpretation |
|-----------|-------|----------------|
| Staleness | 0.0-1.0 | Days since last retrieval / 90, with FSRS adjustment |
| Zero-retrieval | 0.0 or 1.0 | Binary: never retrieved and older than 30 days |
| Size penalty | 0.0+ | Linear above 600 tokens: (tokens - 600) / 600 |
| Duplicate | 0.0-1.0 | Max keyword overlap with any other memory |

Health score formula: `100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)`, where
`purge_count`/`merge_count`/`compress_count` are composite-score bands (see
`skill-distill/SKILL.md`'s Health Score Formula), not operations performed -- `auto` recalculates
and writes `health_score` without itself purging, merging, or compressing anything.

| Score | Status |
|-------|--------|
| 80-100 | healthy |
| 60-79 | manageable |
| 40-59 | concerning |
| 0-39 | critical |

## Recommended Maintenance Cadence

| Action | Frequency | Command |
|--------|-----------|---------|
| Auto maintenance | After every 5-10 new memories | `/distill --auto` |
| Revise review | Periodically, or after a burst of deviations/blockers/reflections | `/distill --revise` |
| Learn harvest | Occasionally, to catch declined/predating candidates | `/distill --learn` |

`--meta` (improvement proposals) and `--dream` (prompt-history direction-finding) moved to
`/telemetry` -- see its own command reference for cadence guidance.

## Memory Lifecycle

```
Create          Use               Capture           Maintain
------          ---               -------           --------
/learn    ->    auto-retrieval    ->    /todo        ->    /distill
                in the research,        harvests           --auto scores/refines the
                plan, and implement     memory             local vault; --revise/--learn
                phases                  candidates         write hosted knowledge objects
```

## Telemetry-Sourced Sub-Mode Run Records

Each telemetry-sourced sub-mode appends its own run record to `specs/events.jsonl` via
`events-append.sh`, rather than sharing `.memory/distill-log.json`'s closed `type` enum (which
`auto` alone still uses) or writing a dedicated file under `.memory/` -- see each sub-mode's own
Run Record subsection in `skill-distill/SKILL.md` for the full shape:

| Sub-Mode | Run Record |
|----------|------------|
| `--revise` | `specs/events.jsonl` event, `--event-type distill-revise` |
| `--learn` | `specs/events.jsonl` event, `--event-type distill-learn-harvest` |

`--meta`, `--review`, and `--dream` log to `specs/telemetry/` instead -- see
`skill-telemetry/SKILL.md`'s Telemetry Log Schemas (core extension).

Example `--revise` detail payload (passed as `events-append.sh --detail-json`):

```json
{
  "since": "ISO8601 or null (first run)",
  "events_ingested": {"total_events": 0, "deviation": 0, "blocker": 0, "reflection": 0},
  "otel_joins": {"sessions_with_cc_session_id": 0, "otel_enabled": true, "outcome_records_matched": 0},
  "reachability_probe": "ok|unreachable",
  "classification": {"corroborated": 0, "contradicted": 0, "gap": 0},
  "affected_clusters": [{"cluster_label": "...", "classification": "contradicted", "action": "superseded"}]
}
```

## --dry-run and --verbose

- `--dry-run`: Available on all three surviving sub-modes (`auto`, `revise`, `learn`). Shows
  what would happen without writing any file or hosted knowledge object. Useful for previewing
  before committing to changes. (`--meta`, `--review`, and `--dream` carry their own `--dry-run`
  behavior at `/telemetry` -- see `skill-telemetry/SKILL.md`.)
- `--verbose`: Shows detailed per-memory scoring breakdown including individual component values
  (staleness, zero_retrieval, size_penalty, duplicate) alongside the composite score (`--auto`
  only).
