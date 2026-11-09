# Memory Extension

Extension for an Obsidian-compatible memory vault. Stores knowledge as markdown files and
retrieves it on demand during research.

## Loading the Extension

```
Extension picker -> select "memory"
```

---

## The Three Commands

Everything in this extension comes down to three operations:

| Operation | Command | When to use |
|-----------|---------|-------------|
| **Write** | `/learn <input>` | After finishing work, to capture what you learned |
| **Read** | Automatic during the research, plan, and implement phases | Relevant memories injected into agent context |
| **Maintain** | `/distill` | Periodically, to assess vault health and run maintenance |

**Note**: When this extension is loaded, memory retrieval is automatic. The research, plan,
and implement preflight stages (dispatched via `/orchestrate`) call `memory-retrieve.sh` to inject relevant memories into
agent context. Use the `--clean` flag to suppress auto-retrieval for a specific invocation.

**`/distill` now spans 12 sub-modes**, not only vault-hygiene maintenance: the seven original
sub-modes (`report`/`purge`/`merge`/`compress`/`refine`/`gc`/`auto`) are joined by five
telemetry-sourced sub-modes -- `--revise` (event-and-OTel-correlated memory refactoring),
`--meta` (cross-repo agent-system improvement proposals), `--review` (read-only inquiry over the
vault and all four source tiers), `--learn` (retroactive batch harvest across already-completed
tasks), and a redefined `--dream` (speculative direction-finding over `history.jsonl`). See
`skills/skill-distill/SKILL.md`'s Shared Sub-Mode Skeleton for the common shape, and
`context/project/memory/telemetry-guardrails.md` for the binding design constraints the five
telemetry-sourced sub-modes share.

---

## Writing Memories

### Quick Example

```bash
/learn "Always use pcall() in Lua for safe function calls when the function might fail"
```

### Input Modes

| Mode | Command | Best for |
|------|---------|----------|
| Text | `/learn "quoted text"` | Quick notes, single concepts, patterns you want to remember |
| File | `/learn /path/to/file.md` | Existing documentation, code files, external notes |
| Directory | `/learn /path/to/dir/` | Importing a knowledge base or project docs |
| Task | `/learn --task N` | Extracting learnings from a completed task |

### What Happens When You Write

For each input, the extension:
1. Segments the content by topic
2. Searches for related existing memories
3. Recommends an operation (UPDATE, EXTEND, or CREATE)
4. **Stops and asks you to confirm** before writing anything

You always see what it wants to do and can override or skip any segment.

### The Three Write Operations

| Overlap with existing memory | Operation | Effect |
|------------------------------|-----------|--------|
| >60% | **UPDATE** | Replaces memory content (old version preserved in History section) |
| 30-60% | **EXTEND** | Appends a dated section to the existing memory |
| <30% | **CREATE** | Creates a new memory file |

---

## Reading Memories

### Automatic Retrieval

When this extension is loaded, memory retrieval happens automatically during the research,
plan, and implement phases. The preflight stage calls `memory-retrieve.sh` to search the
vault for memories relevant to the current task and injects them into the agent context
under a `<memory-context>` section.

To suppress auto-retrieval for a specific invocation, pass the `--clean` flag:

```bash
/orchestrate N --research --clean    # Skip memory injection
```

### Manual Access

Since memories are plain markdown files, you can also:
- Open `.memory/10-Memories/` in Obsidian to browse and search visually
- Read individual files directly with any text editor
- Use grep: `grep -rl "keyword" .memory/10-Memories/`
- Consult the index: `.memory/20-Indices/index.md`

There is no `/recall` command. Outside of auto-retrieval, manual access is through the filesystem.

---

## Storage Details

### Vault Location

```
.memory/
+-- .obsidian/           # Obsidian app configuration
+-- 00-Inbox/            # Quick capture (reserved for future use)
+-- 10-Memories/         # Memory files (MEM-*.md)
+-- 20-Indices/          # index.md with category and topic sections
+-- 30-Templates/        # memory-template.md
+-- README.md
```

### Memory File Format

Each memory is a markdown file with YAML frontmatter:

```yaml
---
title: "Lua pcall for safe function calls"
created: 2026-03-15
tags: lua, error-handling, patterns
topic: "python/patterns"
source: "user input"
modified: 2026-03-15
---

# Lua pcall for safe function calls

Use pcall() in Lua for safe function calls when the function might fail.
Returns two values: success (boolean) and result (or error message).

## Example

```lua
local ok, result = pcall(require, "optional_module")
if not ok then
  return  -- Module not available, graceful exit
end
```

## Connections
<!-- Links to related memories using [[MEM-filename]] syntax -->
```

### Naming Convention

Files follow the `MEM-{semantic-slug}.md` pattern:

- `MEM-lua-pcall-safe-calls.md`
- `MEM-requests-retry-patterns.md`
- `MEM-http-session-config.md`

The `MEM-` prefix keeps files grep-discoverable. Slugs are derived from topic and title.
Collision handling appends `-2`, `-3`, etc.

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Memory title (from summary or first line) |
| `created` | date | Original creation date (YYYY-MM-DD) |
| `tags` | list | Comma-separated keywords |
| `topic` | string | Hierarchical path, e.g. `python/libs/requests` |
| `source` | string | Origin: "user input", "file: /path", etc. |
| `modified` | date | Last modification date |
| `keywords` | list | 3-5 significant terms used for retrieval-scoring keyword overlap |
| `summary` | string | 1-2 sentence summary, shown in `<memory-context>` retrieval output |
| `retrieval_count` | number | How many times auto-retrieval has selected this memory (starts at 0) |
| `last_retrieved` | date/null | Date of the most recent auto-retrieval selection (`null` until first retrieval) |
| `status` | string | Absent (defaults to `active`) or `tombstoned` — see Tombstoning below |
| `tombstoned_at` | date | Present only when `status: tombstoned` — the date the tombstone was applied |
| `tombstone_reason` | string | Present only when `status: tombstoned` — e.g. `"merged_into:{id}"`, `"user_revoked"` |
| `category` | string | Optional. When present, takes priority over the tags-derived category heuristic used by `memory-index.json` regeneration and `/distill`. First real use: `category: preference` for `email/preferences/*` memories (see Reserved Topic Namespaces below) |

#### Tombstoning

Memories are never hard-deleted by `/distill --purge` or `/distill --merge`; instead their
frontmatter gains `status: tombstoned`, `tombstoned_at`, and `tombstone_reason`. Tombstoned
memories are excluded from active listings (`index.md`, retrieval scoring) but retained in
`memory-index.json` with their tombstoned status, and are hard-deleted only by `/distill --gc`
after a 7-day grace period.

#### Reserved Topic Namespaces

`email/preferences/{account}/{key}` is a reserved topic namespace, grounded in the design at
`.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md`:
sender/domain-aggregated preference memories written by `skill-email-cleanup`'s opt-in Stage 7
harvest, evolving via CREATE/EXTEND/UPDATE tally arithmetic instead of full-content
replacement. Memories in this namespace carry `category: preference` and get special treatment
across `skill-learn` and `skill-distill`:

- **Exact-key dedup**: an exact `topic ==` match short-circuits classification straight to
  UPDATE/EXTEND, bypassing the fuzzy keyword-overlap thresholds used elsewhere.
- **Retrieval exclusion**: `memory-retrieve.sh` excludes this namespace from general
  research/plan/implement-phase auto-retrieval (a topic-prefix pre-filter), so these memories
  never leak into unrelated task context.
- **Purge/scoring exemption**: `/distill`'s zero-retrieval penalty and purge candidate selection
  both exempt this namespace — a low `retrieval_count` is expected here (auto-retrieval never
  selects it), not a staleness signal.
- **Hashed local-part**: the domain stays plaintext, but the local-part of an address is
  replaced by a stable, non-reversible `sha256(local-part)[:12]` hash before it is ever written
  into a stored key, title, or body — plaintext email addresses are never written into the
  vault. This is defense-in-depth against the keyword-overlap retrieval path (rather than a
  training-data-anonymization guarantee): debugging only needs hash *consistency* (same input ->
  same hash), not reversibility.

### Index Structure

`.memory/20-Indices/index.md` organizes memories two ways:

- **By Category**: grouped by tags (error-handling, patterns, config, ...)
- **By Topic**: hierarchical tree (python/libs/requests, ...)

The index regenerates from filesystem state on each write, so it stays accurate even if
you manually add or delete files.

---

## Configuration

### Lifecycle Hooks (unused)

`manifest.json` declares `"hooks": {}` — the extension lifecycle-hook slot (preflight,
context_injection, verification, postflight scripts run via `skill-base.sh`) is schema-ready but
intentionally unused. This was evaluated and explicitly rejected as an email-preference-harvest
dependency (email-to-memory-preferences.md design §1.3): neither this extension nor the email
extension has ever exercised this
slot, so its failure-isolation contract is unproven; the harvest instead reads/writes the vault
directly from `skill-email-cleanup`'s Stage 7 via Bash/jq. JSON cannot carry an inline comment,
so this note documents the empty object's intent in prose. Revisit only if a second real hook
consumer emerges.

### MCP Server Setup

The extension uses an MCP server for enhanced memory search. Without it, a grep-based
fallback provides basic search.

Two MCP server options:

| Server | Connection | Requirements |
|--------|------------|--------------|
| obsidian-claude-code-mcp | WebSocket :22360 | Obsidian desktop + plugin |
| obsidian-cli-rest-mcp | HTTP REST :27124 | Obsidian + Local REST API plugin |

**The WebSocket option is NOT a spawnable server and is not declared anywhere in
`manifest.json`.** `obsidian-claude-code-mcp` names an Obsidian desktop plugin, reached through
Claude Code's native `/ide` integration command, not through `.mcp.json` or `~/.claude.json` --
no npx package, no `command`/`args` entry, and no extension-declared `merge_targets.mcp` fragment
participates in this connection at all. (An extension CAN now register a real, spawnable MCP
server via `merge_targets.mcp` -- see
[Extension System Architecture](../core/docs/architecture/extension-system.md)'s "MCP Server
Registration" section, including its two user-visible gotchas, for the mechanism this extension
does NOT currently use.)

**Prerequisites**:
1. Obsidian desktop app installed and open
2. The companion Obsidian plugin installed and the `.memory/` vault open in Obsidian
3. Connect via Claude Code's `/ide` command (not via any MCP server configuration)

**Tool surface NOT verified**: this plugin's actual MCP tool names were NOT enumerated against
a running server. The npm package name sometimes associated with it
(`@anthropic-ai/obsidian-claude-code-mcp`) does not exist on the npm registry (confirmed
404), so no server could be started to query `tools/list` against. Treat any `mcp__obsidian*`
tool name as unverified until confirmed against an actually running connection.

### Graceful Degradation

When MCP is unavailable, the extension falls back to grep-based search:

```bash
grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
```

Memory creation and retrieval still work without MCP; you lose Obsidian graph and
backlinks integration but not core functionality.

---

## Troubleshooting

### "No memories found" during auto-retrieval

1. Is the vault empty? Check: `ls .memory/10-Memories/MEM-*.md`
2. Are search terms too specific? Try broader terms
3. Is MCP connected? Check Obsidian is open with the vault

### MCP connection issues

Symptom: "MCP search unavailable. Using grep-based fallback."

1. Is Obsidian running with `.memory/` open?
2. Is port 22360 in use by something else? `lsof -i :22360`

### Memories not appearing in Obsidian

Obsidian needs to re-index after new files are added externally. Go to
Settings > Files & Links > Detect all file extensions, or close and reopen the vault.

### Directory scan: "too many files"

Limit is 200 files. Narrow the path or run multiple `/learn` invocations.

---

## Best Practices

### When to Write

- After completing a task: `/learn --task N` to capture what you learned
- After figuring out a non-obvious pattern: `/learn "..."`
- When you find documentation you'll want again: `/learn /path/to/file.md`

### When to Read

- Memory retrieval is automatic when this extension is loaded -- just run `/orchestrate N --research`
- When manually starting work on something familiar: browse `.memory/20-Indices/index.md`

### Writing Effective Memories

- Be specific: "Lua pcall for error handling" > "Lua patterns"
- Include a code example: it makes the memory actionable
- One concept per memory: the overlap-scoring works best on focused content
- Accept UPDATE recommendations: they keep your vault clean

### Topic Hierarchy

Use 2-3 levels. Examples:
- `python/patterns`
- `python/libs/requests`
- `meta/commands`

Avoid 4+ levels. The index becomes hard to navigate.

### Vault Maintenance

The extension is optimized for under 1000 memories. Periodically:
- Run `/distill` to see a health report with maintenance recommendations
- Accept UPDATE/EXTEND over CREATE when content overlaps
- Use `/distill --purge` to remove low-value memories (when available)
- Use `/distill --merge` to combine duplicate memories (when available)
- Run `/learn --task N` on recent tasks to consolidate learnings

---

## Bootstrap Harvest Scripts (one-shot, historical)

`scripts/` contains a one-shot, read-only mining pipeline that distills the Claude Code
transcript corpus (`~/.claude/projects/`) and the durable prompt spine (`~/.claude/history.jsonl`)
into a pointer-based dataset. This is **not** a scheduled or repeatedly-run pipeline — the
transcript format is undocumented and unversioned, and the transcript window itself is a rolling
~30-day cliff. The scripts exist as a deployable, reusable substrate for a future dataset
refresh, not as ongoing automation.

| Script | Role |
|--------|------|
| `bootstrap-harvest.sh` | Orchestrator: runs the three passes below, joins their output on `session_id`, computes the `inferred_outcome` label, and writes the manifest |
| `bootstrap-harvest-transcripts.sh` | Perishable pass: one row per top-level transcript session with `is_error` statistics and resolved repo path |
| `bootstrap-harvest-history.sh` | Durable pass: one row per `sessionId` from `history.jsonl`, using a skip-and-continue decode so an embedded raw-newline record cannot abort the whole read |
| `bootstrap-harvest-attribution.sh` | Join pass: maps `.meta.json` subagent sidecars to a parent session and a best-effort task number extracted from the sidecar description |

**Read-only contract (binding)**: every pass reads under `~/.claude/` using only `jq`/`find`/
`cat`/`python3` raw-decode — never `rm`/`mv`/`>`/`>>`/truncate against that tree. All output is
written to caller-supplied paths outside `~/.claude/` (JSONL to stdout, redirected by the
orchestrator).

**Self-exclusion**: each pass reads `$CLAUDE_CODE_SESSION_ID` once at start and excludes that
session (and its subagent sidecars) from every count, so the harvest never counts its own
execution as corpus data.

**Usage**:
```bash
CLAUDE_CODE_SESSION_ID="$CLAUDE_CODE_SESSION_ID" bash scripts/bootstrap-harvest.sh \
  sessions.jsonl history-spine.jsonl harvest-manifest.json \
  [projects_root] [history_jsonl_path]
```

The `inferred_outcome` label (`trivial`/`clean`/`mixed`/`high_error`) is an explicit modeling
decision documented in the orchestrator's header comment, not an extraction — there is no
session-level success/failure field in the source data. Every output row retains its raw
`is_error`/`tool_result_count` numerator and denominator so the label can be recomputed later
without re-mining the corpus.

---

## Subdirectories

- `commands/` - `/learn` and `/distill` command implementations
- `skills/` - `skill-learn` and `skill-distill` skill definitions
- `context/` - Extended usage guides
- `scripts/` - One-shot bootstrap harvest pipeline (see "Bootstrap Harvest Scripts" above)

### Context Documentation

- [Learn Usage Guide](context/project/memory/learn-usage.md) - Detailed `/learn` examples
- [Memory Setup](context/project/memory/memory-setup.md) - MCP configuration details
- [Memory Troubleshooting](context/project/memory/memory-troubleshooting.md) - Extended troubleshooting
- [Knowledge Capture Usage](context/project/memory/knowledge-capture-usage.md) - Example workflows

---

## Navigation

- [Parent Directory](../README.md)
