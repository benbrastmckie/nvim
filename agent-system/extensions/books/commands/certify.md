---
description: Thin passthrough over the certify driver -- graph-wide, dependency-ordered book certification
allowed-tools: Bash
argument-hint: "[OPTIONS] [ROOT]..."
---

# /certify Command

Thin passthrough over `books-certify.sh`, the extension's resolve-and-invoke wrapper around the
consuming repository's own book certification driver.

**Why a separate command from `/book`**: certification is a graph-wide, dependency-ordered
operation over potentially many books — it discovers every `book.toml` under ROOT, builds the
module-grain dependency graph, and certifies dependencies first in topological order, refusing
the whole run if any book is refused. `/book` is a single-book developer loop; this is the
graph-wide gate. The same shape of justification keeps `/lake` and `/lean` as two separate
commands rather than one.

## Syntax

```
/certify [OPTIONS] [ROOT]...
```

`ROOT` defaults to the repository root when omitted. Every `book.toml` at or under a `ROOT` is a
book.

## Options

| Flag | Description |
|------|-------------|
| `--no-build` | Do not run `lake build` for the books' module targets; certify against whatever is already built. Use only when the tree is known current. |
| `--no-shake` | Skip the advisory `lake shake` stage entirely. |
| `--no-write` | Print each certificate to stdout and write nothing — for a determinism check that must not touch the tree. |
| `--only NAME` | Certify only the named book (and, still, its dependencies first); repeatable. |
| `--check` | The pre-launch check: run discovery and the driver's own readiness checks (memory headroom, freshness, root/package resolution, reader budget/scope), then exit without certifying anything. Run this before a real run. |
| `-h`, `--help` | Print the driver's own help block. |

The acceptance-suite-only graph-injection flag is deliberately **not** exposed here — see
`books-certify.sh`'s own header comment for why.

## Execution

**EXECUTE NOW**: Follow all steps in sequence.

---

### STEP 1: Run the pre-launch check first, unless already confirmed fresh

**EXECUTE NOW**: Before a real certification run, recommend (and, unless the caller explicitly
passed `--check` already or opted out, run) the pre-launch check:

```bash
bash .claude/scripts/books-certify.sh --check "$@"
```

If this exits non-zero, report its findings and **STOP** — do not proceed to a real run against
a tree that failed its own readiness check.

**On success**: **IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Invoke the real driver with the caller's arguments

**EXECUTE NOW**: Forward every argument verbatim.

```bash
bash .claude/scripts/books-certify.sh "$@"
```

Report the exit code and the full output: `0` means every book was certified, `1` means a book
was refused or a build failed, `2` is a usage error, `3` means the wrapper could not find the
real driver in this repository (books tooling absent).

---

## Error Recovery

### Driver not found (exit 3)
Report the wrapper's own actionable message verbatim — the repository may not carry the `books/`
tooling tree.

### A book was refused (exit 1)
Report the refusal verbatim, distinguishing a genuine refusal (a verdict was reached and printed)
from a resource failure (the reader did not reach a verdict — raise the reader memory budget or
free memory and re-run), per the driver's own classification.

### Usage error (exit 2)
Report the message and the corrected syntax from the Options table above.
