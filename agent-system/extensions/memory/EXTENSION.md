## Memory Extension

Knowledge capture and retrieval via the memory vault. Supports text, file, directory, and task-based memory creation with MCP-backed search and deduplication. Includes vault distillation for scoring, health reporting, and automated maintenance.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-learn | (direct execution) | Memory creation |
| skill-distill | (direct execution) | Memory vault distillation and management |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/learn` | `/learn "text"` | Add text as memory (with content mapping and deduplication) |
| `/learn` | `/learn /path/to/file` | Add file content as memory |
| `/learn` | `/learn /path/to/dir/` | Scan directory for learnable content |
| `/learn` | `/learn --task N` | Review task artifacts and create memories |
| `/distill` | `--auto\|--revise\|--learn` | Local `--auto` refine; `--revise`/`--learn` against the hosted store, which already handles vault maintenance server-side -- see `context/project/memory/distill-usage.md`. `--meta`/`--review`/`--dream` -> `/telemetry` |

### Memory-Augmented Research

Memory retrieval is automatic: when the memory extension is loaded, the research, plan, and implement preflight stages (dispatched via `/orchestrate`) call `memory-retrieve.sh` to inject relevant memories as `<memory-context>` into the agent context. The `--clean` flag suppresses auto-retrieval.

### Literature-Augmented Research

The `--lit` flag is the complementary context-injection mechanism to memory retrieval. While `--clean` suppresses memory retrieval, `--lit` adds literature file injection from `specs/literature/`. The two flags are independent and combinable: `--clean --lit` suppresses memory but still injects literature; `--lit` alone injects both memory (if available) and literature. See the "Literature Mode (`--lit`)" section in CLAUDE.md for full details on `specs/literature/` conventions, token budget, and composability with other flags.

### Memory Lifecycle

Create (`/learn`) -> Use (auto-retrieval in the research, plan, and implement phases) -> Capture
(`/todo` harvests memory candidates) -> Maintain (`/distill` scores, reports, maintains). See
`context/project/memory/distill-usage.md`'s own Memory Lifecycle diagram for the full rendering.

### Validate-on-Read

There is no `--reindex` command. The memory system uses validate-on-read: before any scoring or retrieval operation, `memory-index.json` is compared against the filesystem. If stale (missing entries or orphaned entries), the index is automatically regenerated. This provides self-healing index consistency without explicit user intervention.
