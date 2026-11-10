# skill-distill

Memory vault analysis and maintenance skill for the `/distill` command.

## Purpose

Vault health analysis and maintenance via `/distill` command. Invoked with `mode=distill`.
Memory *creation* is a separate concern owned by the sibling `skill-learn` skill.

## Sub-Modes

| Sub-Mode | Flag | Description |
|----------|------|-------------|
| auto | `--auto` | Automated Tier 1 refine only (non-interactive, local vault) |
| revise | `--revise` | Event-and-OTel-correlated review of hosted knowledge objects (interactive) |
| learn | `--learn` | Retroactive, batch harvest across already-completed tasks (interactive, writes to hosted knowledge objects) |

A bare `/distill` (no sub-mode flag) prints usage and exits -- there is no default sub-mode.
`report`, `--purge`, `--merge`, `--compress`, `--refine`, and `--gc` provide no local
equivalent: the hosted Sapience knowledge store already performs consolidation and compaction,
staleness re-confirmation, and conflict detection server-side -- see
`context/project/memory/distill-usage.md` for the full reasoning. `--meta`, `--review`, and
`--dream` moved to `/telemetry` -- see `skill-telemetry/SKILL.md` (core extension).

See `SKILL.md`'s Shared Sub-Mode Skeleton and per-sub-mode sections for the full specification
of each, and `context/standards/telemetry-guardrails.md` for the binding design constraints
shared by the telemetry-sourced sub-modes.

## Scoring Engine

Each memory is scored on four components to compute a composite maintenance score (0.0-1.0):

| Component | Weight | Description |
|-----------|--------|-------------|
| Staleness | 0.30 | Days since last retrieval (or creation), capped at 90 days. FSRS adjustment for actively retrieved old memories. |
| Zero-retrieval | 0.25 | Binary penalty: 1.0 if never retrieved and older than 30 days, else 0.0 |
| Size penalty | 0.20 | Linear penalty above 600 tokens: `max(0, (token_count - 600) / 600)` |
| Duplicate | 0.25 | Maximum keyword overlap with any other memory in the vault |

**Composite**: `(staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)`, clamped to [0, 1].

The composite score and its weighted components are retained verbatim because `auto` recomputes
and writes `health_score` from them on every run -- see `SKILL.md`'s Health Score Formula and
Health Status Thresholds. There is no local candidate-classification table any more:
classification against a composite-score band (what the four now-absent sub-modes once acted
on) has no local action to recommend since those sub-modes have no local equivalent.

## Tombstone Field (historical)

`status: tombstoned` / `tombstoned_at` / `tombstone_reason` remain a valid frontmatter shape for
any already-tombstoned memory on disk, but no surviving sub-mode writes a new one: that
lifecycle (soft-delete, hard-delete past a grace period) moved to the hosted Sapience store,
which performs its own conflict surfacing and stale-position re-confirmation server-side.

## Distill Log

`auto`'s own operations are logged to `.memory/distill-log.json` (type: `refine`) with pre/post
metrics, affected memories, and session ID. `revise` and `learn` append their own run records to
`specs/events.jsonl` via `events-append.sh` instead -- see `SKILL.md`'s Run Record subsections.

## Additional Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would happen without making changes |
| `--verbose` | Show detailed scoring breakdown per memory |

## Validate-on-Read

Before scoring, `memory-index.json` is validated against the filesystem. This procedure (and the paired JSON Index Maintenance procedure) is defined once in the sibling `skill-learn/SKILL.md` and cited by name throughout this skill's `SKILL.md` -- it was not duplicated by the split.

## Files

- `SKILL.md` - Skill definition and execution flow (distill sub-modes)

## Navigation

- [Parent Directory](../README.md)
