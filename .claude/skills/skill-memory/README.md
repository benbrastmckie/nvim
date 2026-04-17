# skill-memory

Memory vault management skill for the /learn and /distill commands.

## Purpose

Handles memory creation, similarity search, classification, index maintenance, and vault distillation for the Obsidian-compatible memory vault.

## Modes

### Standard Mode

Add text or file content as memory:
- Parse input (text vs file)
- Generate unique memory ID
- Search for similar existing memories
- Present preview with options
- Create memory file with YAML frontmatter
- Update index

### Task Mode

Review task artifacts and create classified memories:
- Locate task directory
- Scan artifact files
- Present interactive selection
- Classify each artifact (TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT, SKIP)
- Create categorized memories
- Update index with category grouping

### Distill Mode

Vault health analysis and maintenance via `/distill` command. Invoked with `mode=distill`.

#### Sub-Modes

| Sub-Mode | Flag | Description |
|----------|------|-------------|
| report | (bare) | Generate health report with scoring engine analysis |
| purge | `--purge` | Tombstone stale/zero-retrieval memories (interactive) |
| merge | `--merge` | Combine memories with >60% keyword overlap (interactive) |
| compress | `--compress` | Summarize memories with size penalty >0.5 to key points |
| refine | `--refine` | Improve metadata quality: Tier 1 (auto) + Tier 2 (interactive) |
| gc | `--gc` | Hard-delete tombstoned memories past 7-day grace period |
| auto | `--auto` | Automated Tier 1 refine only (non-interactive) |

#### Scoring Engine

Each memory is scored on four components to compute a composite maintenance score (0.0-1.0):

| Component | Weight | Description |
|-----------|--------|-------------|
| Staleness | 0.30 | Days since last retrieval (or creation), capped at 90 days. FSRS adjustment for actively retrieved old memories. |
| Zero-retrieval | 0.25 | Binary penalty: 1.0 if never retrieved and older than 30 days, else 0.0 |
| Size penalty | 0.20 | Linear penalty above 600 tokens: `max(0, (token_count - 600) / 600)` |
| Duplicate | 0.25 | Maximum keyword overlap with any other memory in the vault |

**Composite**: `(staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)`, clamped to [0, 1].

#### Maintenance Classification

| Composite Score | Classification | Recommended Action |
|-----------------|----------------|-------------------|
| >= 0.7 | Purge candidate | Tombstone via `--purge` |
| >= 0.5 | Merge/compress candidate | `--merge` or `--compress` |
| >= 0.3 | Review candidate | `--refine` |
| < 0.3 | Healthy | No action needed |

#### Tombstone Pattern

Purge and merge operations use soft-delete via frontmatter mutation (not file deletion):
- `status: tombstoned`
- `tombstoned_at: {ISO date}`
- `tombstone_reason: "purge"` or `"merged_into:{primary_id}"`

The `--gc` sub-mode performs hard deletion of tombstoned memories past the 7-day grace period.

#### Distill Log

All operations are logged to `.memory/distill-log.json` with pre/post metrics, affected memories, and session ID. The log tracks `total_purged`, `total_merged`, `total_compressed`, `total_refined`, and `total_gc_deleted` counters.

#### Additional Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would happen without making changes |
| `--verbose` | Show detailed scoring breakdown per memory |

## Auto-Retrieval

Memory retrieval is automatic: `/research`, `/plan`, and `/implement` preflight stages call `memory-retrieve.sh` to inject relevant memories into agent context. The `--clean` flag on these commands suppresses auto-retrieval. No explicit opt-in flag is needed.

## Validate-on-Read

Before scoring or retrieval, `memory-index.json` is validated against the filesystem. Stale indexes (missing or orphaned entries) are automatically regenerated. There is no `--reindex` command; validate-on-read provides the equivalent functionality.

## Files

- `SKILL.md` - Skill definition and execution flow (learn modes + distill mode)

## Navigation

- [Parent Directory](../README.md)
