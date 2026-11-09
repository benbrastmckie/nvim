# skill-distill

Memory vault analysis and maintenance skill for the `/distill` command.

## Purpose

Vault health analysis and maintenance via `/distill` command. Invoked with `mode=distill`.
Memory *creation* is a separate concern owned by the sibling `skill-learn` skill.

## Sub-Modes

| Sub-Mode | Flag | Description |
|----------|------|-------------|
| report | (bare) | Generate health report with scoring engine analysis |
| purge | `--purge` | Tombstone stale/zero-retrieval memories (interactive) |
| merge | `--merge` | Combine memories with >60% keyword overlap (interactive) |
| compress | `--compress` | Summarize memories with size penalty >0.5 to key points |
| refine | `--refine` | Improve metadata quality: Tier 1 (auto) + Tier 2 (interactive) |
| gc | `--gc` | Hard-delete tombstoned memories past 7-day grace period |
| auto | `--auto` | Automated Tier 1 refine only (non-interactive) |
| revise | `--revise` | Event-and-OTel-correlated memory refactoring proposals |
| learn | `--learn` | Retroactive, batch harvest across already-completed tasks |

`--meta`, `--review`, and `--dream` moved to `/telemetry` -- see `skill-telemetry/SKILL.md`
(core extension).

See `SKILL.md`'s Shared Sub-Mode Skeleton and per-sub-mode sections for the full specification
of each, and `context/standards/telemetry-guardrails.md` for the binding design constraints
shared by the telemetry-sourced sub-modes that remain.

## Scoring Engine

Each memory is scored on four components to compute a composite maintenance score (0.0-1.0):

| Component | Weight | Description |
|-----------|--------|-------------|
| Staleness | 0.30 | Days since last retrieval (or creation), capped at 90 days. FSRS adjustment for actively retrieved old memories. |
| Zero-retrieval | 0.25 | Binary penalty: 1.0 if never retrieved and older than 30 days, else 0.0 |
| Size penalty | 0.20 | Linear penalty above 600 tokens: `max(0, (token_count - 600) / 600)` |
| Duplicate | 0.25 | Maximum keyword overlap with any other memory in the vault |

**Composite**: `(staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)`, clamped to [0, 1].

## Maintenance Classification

| Composite Score | Classification | Recommended Action |
|-----------------|----------------|-------------------|
| >= 0.7 | Purge candidate | Tombstone via `--purge` |
| >= 0.5 | Merge/compress candidate | `--merge` or `--compress` |
| >= 0.3 | Review candidate | `--refine` |
| < 0.3 | Healthy | No action needed |

## Tombstone Pattern

Purge and merge operations use soft-delete via frontmatter mutation (not file deletion):
- `status: tombstoned`
- `tombstoned_at: {ISO date}`
- `tombstone_reason: "purge"` or `"merged_into:{primary_id}"`

The `--gc` sub-mode performs hard deletion of tombstoned memories past the 7-day grace period.

## Distill Log

All operations are logged to `.memory/distill-log.json` with pre/post metrics, affected memories, and session ID. The log tracks `total_purged`, `total_merged`, `total_compressed`, `total_refined`, and `total_gc_deleted` counters.

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
