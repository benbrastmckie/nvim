# Books Extension

Authoring, certifying and documenting **lean books** per the Logos/Verification repository's
`docs/book-convention.md` design record: a certified unit inside a Lake package, named by a
`book <Name>` command in its own book module, whose metadata splits facts (Lean annotations)
from judgments (`book.toml`) with everything else computed by the certifier into
`book.cert.json`.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `books` | books-research-agent | Books research |
| `books` | books-implementation-agent | Books implementation (also serves `books:certify`) |
| `books` (`--hard`) | books-research-hard-agent | Hard-mode books research |
| `books` (`--hard`) | books-implementation-hard-agent | Hard-mode books implementation |

## Installation

Loaded via the extension picker. Once loaded, `books` becomes a recognized task type, with a
`books:certify` compound sub-route sharing the same base agents (the `lean4:lake` precedent).

## Directory Map

```
books/
├── manifest.json               # task_type, dependencies, provides, routing, keyword_overrides
├── agents/                     # four agents (base pair + --hard pair, all model: sonnet)
├── skills/                     # four lifecycle skills + two direct-execution skills
├── commands/                   # /book, /certify
├── rules/                      # books.md -- the non-negotiables
├── scripts/                    # books-certify.sh (the one declared passthrough script) + tests
└── context/project/books/      # the domain corpus: README.md index + sixteen documents
```

## Commands

| Command | Usage | Description |
|---------|-------|--------------|
| `/book` | `/book <name> [--lib DIR]` | Single-book developer loop: resolve the named book's `book.toml`, build its module scope, run the manifest validator, then the environment-walk check. Documentation reconciliation is explicitly out of its scope. |
| `/certify` | `/certify [OPTIONS] [ROOT]...` | Thin passthrough over the certify driver via `books-certify.sh`: graph-wide, dependency-ordered certification over every book under ROOT. |

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-books-research | books-research-agent | Books research |
| skill-books-implementation | books-implementation-agent | Books implementation (also serves `books:certify`) |
| skill-books-research-hard | books-research-hard-agent | Hard-mode books research |
| skill-books-implementation-hard | books-implementation-hard-agent | Hard-mode books implementation |
| skill-books-build | (direct execution) | `/book` |
| skill-books-certify | (direct execution) | `/certify` |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `books` | Read, Grep, Glob, Bash | Read, Write, Edit, Bash (`lake build`, `books-tool`, `books-certify.sh`) |

## Book Directory Layout (flattened)

```
<package-dir>/books/<name>/
├── book.toml        # judgments: name, module, version, status, maintainers, trust/provenance
├── book.cert.json   # the certifier's only non-Lean input/output; generated, never hand-edited
└── book.typ         # the book's own document, flattened beside the manifest, no docs/ segment
```

See `rules/books.md` for the full six-item non-negotiable set (facts-in-Lean/judgments-in-TOML,
the certificate boundary, the flattened layout, explicit lakefile globs, the licence-header line
order, and the never-hand-edit-a-generated-artifact rule).

## Twelve `book_layer` Values

The eight layers `interface | laws | extraction | impl | instances | refinement | challenge |
evidence` plus the four opt-in split tiers `impl.defs`, `impl.proofs`, `instances.defs`,
`instances.proofs`. A may-import matrix replaces a total order, enforced at elaboration over
direct imports and at certification over the computed graph.

## Common Operations

```bash
books-tool validate <book.toml> [--lib DIR]...     # manifest validator
books-tool check [--lib DIR]... [--only PREFIX]...  # module-grain environment walk + layer check
books-tool levels <module.olean>                    # per-module layer report
```

- `/book <name>` runs the single-book loop above end to end.
- `/certify` forwards to the consuming repository's own graph-wide certifier driver.

## Landed vs. Planned (re-verify before relying on either)

Landed: `books/lean` (the metadata provider), `books/tool` (`books-tool`), `books/tests` (the
fixture suite). Planned-only as of this extension's authoring: the certifier's docs stage, the
guarantee-approval script, and the book-health script — do not assume any of the three without
re-checking the live tree.

## References

- `docs/book-convention.md` and `books/schema/book-toml-v2.md` (consuming-repository design
  record; normative)
- `context/project/books/README.md` (the domain corpus's navigation index; start at
  `domain/known-gap-register.md`)
