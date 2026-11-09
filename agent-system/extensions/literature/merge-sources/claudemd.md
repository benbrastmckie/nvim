## Literature Extension

Version 2.0.0. Unified management of the global Literature/ repository (`~/Projects/Literature/`)
and per-repo sub-indices (`specs/literature-index.json`): source discovery, PDF/DJVU conversion,
FTS5-backed search, agent context briefing, and Zotero integration.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-literature | (direct execution) | Scan, convert, validate, index, discover, and integrate literature |
| skill-cite | (direct execution) | Verify citation claims against Literature/ and Zotero |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/literature` | `/literature` | Show status and index health (Mode B) |
| `/literature` | `/literature N` | Discover sources relevant to task N (Mode A) |
| `/literature` | `/literature "query"` | Discover sources matching a query (Mode A) |
| `/literature` | `/literature ~/path/to/file.pdf` | Ingest a specific PDF/DJVU (Mode B) |
| `/literature` | `/literature ~/dir/` | Ingest all PDFs in a directory (Mode B) |
| `/literature` | `/literature --validate` | Validate the sub-index against the global index |
| `/literature` | `/literature --index FILE` | Add/update index entry for existing markdown file |
| `/literature` | `/literature --convert [FILE]` | Convert PDF/DJVU to markdown with chunking |
| `/cite` | `/cite N` | Verify all citations in task N artifacts |
| `/cite` | `/cite N --gaps` | Also flag citations found in Zotero but lacking a PDF |

### Context Pointers

- `context/project/literature/domain/literature-index.md` — global/per-repo index schemas, repo layout
- `context/project/literature/patterns/literature-command-modes.md` — two-mode `/literature`, discovery tiers
- `context/project/literature/patterns/agent-exploration.md` — `--lit` briefing+tools pattern, corpus navigation
- `context/project/literature/tools/zotero-scripts.md` — Zotero script inventory, setup, and related pointers
- `context/project/literature/domain/format-decision.md` — markdown retained as the sole convert/chunk/index format

## Literature Mode (`--lit`)

Literature mode produces a live, navigate-on-demand `<literature-briefing>` block for agent
prompts — never a static content dump. Use this when a task involves implementing from a paper,
specification, or reference document.

The resolver directives, the four interactive sub-index setup options, sparse-coverage
re-prompting, and the `orchestrator_mode` dual-consumer contract are canonically defined in
`context/patterns/lit-stage4a-flow.md` — the single executable Stage 4a block that
`skill-orchestrate` and every domain research/implementation skill import directly and execute
verbatim, rather than each maintaining its own copy. Read that file for the full mechanics; this
section is a pointer, not a second copy.

Outside an `/orchestrate --lit` dispatch (with `--research`/`--plan`/`--implement`), a conversational request to
consult "the literature" is handled by the primary/root session via
`context/project/literature/patterns/adhoc-navigation-directive.md`, which surfaces the same
interactive options defined in `lit-stage4a-flow.md`.

### specs/literature/ Directory Convention

The `specs/literature/` directory is user-maintained and not task-scoped:
- Place paper summaries, specification documents, algorithm descriptions, or reference PDFs
  (converted to .md/.txt) here
- All files in the directory are available to any task when `--lit` is active
- The directory is not created automatically — create it before using `--lit`
- Suitable content: academic paper summaries, RFC/spec excerpts, algorithm pseudocode,
  mathematical definitions the agent should treat as ground truth

### When to Use `--lit`

- Task requires implementing from a paper or formal specification
- Agent needs stable reference material beyond what is in memory
- Using `--hard` with H3 reference grounding tier "literature"
- Task description mentions "paper to code", "spec to implementation", or cites a specific document

### Relationship to `--clean`

The two flags are independent:

| Flag combination | Memory retrieval | Literature injection |
|------------------|-----------------|---------------------|
| (neither)        | active          | inactive            |
| `--clean`        | suppressed      | inactive            |
| `--lit`          | active          | active              |
| `--clean --lit`  | suppressed      | active              |

### Composability

- `--lit` works with `--hard`, `--fast`, and model flags
- `--lit` is threaded through all dispatch contexts in skill-orchestrate
- Per-invocation only: no sticky state in state.json

### Per-Invocation Only

`--lit` has no persistent state. Each `/orchestrate` invocation (whichever of `--research`,
`--plan`, or `--implement` it carries) must explicitly pass `--lit` to activate literature injection.

