## Books Extension

This project includes lean-book authoring, certification and documentation support via the
books extension, following the Logos/Verification repository's `docs/book-convention.md`
design record.

### Scope

This extension covers authoring `book_layer`/`@[book_export]` facts, writing book modules (the
`book`/`book_assume`/`book_not_claimed`/`book_axioms`/`book_policy`/`book_requires` fact
commands and `#book_ledger`), authoring `book.toml` judgments, and running `books-tool`/the
certify driver, plus reviewing and revising the convention itself from accumulated observation
evidence (`/books`). **Originating or verifying new Lean content is out of scope** — routes to
`lean4`/`cslib`/`formal` instead; `books` owns the metadata layer and its own convention's health,
not the content itself. **Detection note**: a `books` task naming a `.lean` file, or
`mathlib`/`lean4`, is captured by the `lean4` strong anchor first and will NOT auto-route to
`books` — use an explicit `--task-type books` at `/task` creation.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `books` | Read, Grep, Glob, Bash | Read, Write, Edit, Bash (`lake build`, `books-tool`, `books-certify.sh`) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-books-research | books-research-agent | Books research |
| skill-books-implementation | books-implementation-agent | Books implementation (also serves `books:certify`) |
| skill-books-research-hard | books-research-hard-agent | Hard-mode books research |
| skill-books-implementation-hard | books-implementation-hard-agent | Hard-mode books implementation |
| skill-books-build | (direct execution) | `/book` single-book developer loop |
| skill-books-certify | (direct execution) | `/certify` graph-wide passthrough |
| skill-books-review | (direct execution) | `/books --review`/`--revise` convention health |

### Commands

| Command | Usage | Description |
|---------|-------|--------------|
| `/book` | `/book <name> [--lib DIR]` | Single-book developer loop: resolve, build, validate, environment-check |
| `/certify` | `/certify [OPTIONS] [ROOT]...` | Thin passthrough over the certify driver (graph-wide, dependency-ordered) |
| `/books` | `/books --review` / `/books --revise [--dry-run] [--verbose]` | Read-only convention performance review, or interactive research-and-revision task proposal |

### Book Directory Layout (flattened)

`<package-dir>/books/<name>/` holds `book.toml`, `book.cert.json` and `book.typ` side by side —
never a `docs/` subdirectory. See `rules/books.md` for the full non-negotiable set.

### Observer

`books-observe` (`scripts/books-observe.sh`, `manifest.json`'s `observers` block, advisory and
non-blocking) writes one OBSERVATION record per books-topic task
(`specs/{NNN}_{SLUG}/book.observation.json`), joining `issues.jsonl`/`metrics.jsonl` with
books-specific facts. See `context/project/books/standards/observation-record.md` (schema) and
`context/project/books/patterns/signal-tagging.md` (how agents feed it).

### Context Pointers

- `context/project/books/README.md` — navigation index of the domain corpus (twenty docs), reachable on demand
