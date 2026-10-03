# Operating the Certifier

`books/scripts/certify.sh` (711 lines, measured 2026-10-03) certifies **a graph of books, not a
book**: it discovers books from `book.toml` files under the given roots, works out each book's
owning Lake package, builds the module-grain dependency graph, certifies **dependencies first in
topological order**, and refuses the whole run when any book is refused.

This document is about running it **economically** and **not being misled by its output**. For
what comes out, see `domain/certificate-ledger-and-records.md`. Gap claims defer to
`domain/known-gap-register.md`.

## Rule 1: scope to the COMPONENT root, never the repository root and never one book directory

The driver's own header states it: "Pass the **COMPONENT** root, never a single book directory --
the driver discovers the core, bridge and recheck packages from the root and passes every
non-owning one as `--extra-pkg-dir`; a narrower ROOT makes a cross-package member module refuse
with `missing-source`."

And the measured consequence of going the other way: **a repository-root run discovers 22 books
and fails the pre-launch check on two unrelated things** -- a Typst fixture (`Probe`, whose book
module is under no package root) and a stale `Distsys.Book.Quorum`. Every run on a real family has
to be scoped. **Nothing documents this** in the consuming repository, which is why it is here.

```bash
bash books/scripts/certify.sh --check components/framed_channel   # right
bash books/scripts/certify.sh --check .                            # discovers 22, fails
bash books/scripts/certify.sh --check components/framed_channel/books/crc8   # too narrow
```

## Rule 2: run `--check` FIRST

`--check` is the **pre-launch check**: it runs discovery, then four points, and **certifies
nothing**. Exit 0 when every point passes, 1 otherwise.

| Point | What it probes |
|---|---|
| 1 | **memory headroom** -- `MemAvailable >= 7 GiB` ("a reader needs ~4.7 GiB RSS"), plus `lake-build-guard.sh preflight` exit 0 when that script exists. A missing guard is **skipped with a note**, not failed |
| 2 | **freshness** -- `lake build --no-build` for every discovered book module in its owning package, **and in the provider**. It **probes and never builds**: `--no-build` exits non-zero on a stale tree, in 0.2-1 s per package |
| 3 | **roots and packages** -- the ROOT(s), every discovered package, and the exact **`--extra-pkg-dir` list each book will receive** |
| 4 | **the reader budget and scope** that would apply |

**Measured payoff**: on a thirteen-book family it surfaced every book module's freshness, the
reader budget (`12582 MiB (MemAvailable 14630 MiB - 2048, floor 6144)`) and the exact per-book
`--extra-pkg-dir` list in **~90 seconds** -- which is what made `--no-build` usable **instead of
1,803 build jobs per run**.

It also emits one note worth reading on a single-package discovery: "one package discovered; a book
module importing a module of another package would refuse with `missing-source` -- pass the
component root if it has more than one package" (`certify.sh:416`). That note is the scoping
mistake of Rule 1, caught before the run.

## Rule 3: `--no-build` economics, and the trap inside them

`--no-build` certifies against whatever is already built. **Use it only when the tree is known
current** -- the driver's own warning: "a stale `.olean` certifies a book that is not the one in
the source." That is what `--check`'s freshness point is for; the two flags are a pair.

**The trap**: `certify.sh` builds every **DISCOVERED** book's module targets **even under
`--only`**. So an unrelated warning anywhere in the discovered set can abort a narrowly scoped
run. `--only NAME` narrows **what is certified**, not **what is built**. Combining `--only` with
`--no-build` is what actually narrows a run.

Note also that the builds run at `--fail-level=error` with a book-module warning scan, so
**skipping them with `--no-build` also skips that scan**.

## The landed flag set

From `agent-system/extensions/books/commands/certify.md`'s Options table and the driver's own help
block, both read 2026-10-03:

| Flag | Effect |
|---|---|
| `--check` | the pre-launch check above; certifies nothing |
| `--no-build` | do not run `lake build` for the books' module targets |
| `--no-shake` | skip the advisory `lake shake` stage entirely |
| `--no-write` | print each certificate to stdout and **write nothing** -- for a determinism check that must not touch the tree |
| `--no-docs-stage` | skip the per-book docs stage and pass no `--docs-report`. The certificate's `docs` field is then all-unknown with zeroed `context_pack_bytes` -- "**exactly what absent documentation claims**". The stage is **also skipped per book, with a note, when it exits non-zero**, so a tool-less environment certifies without this flag |
| `--only NAME` | certify only the named book (**and, still, its dependencies first**); repeatable |
| `--prev FILE` | the previous certificate to bump against; the driver passes an existing `book.cert.json` automatically when there is one |
| `-h`, `--help` | the driver's own help block |

Exit codes: **0** every book certified, **1** a book was refused or a build failed, **2** usage
error.

**`--graph-from FILE` is acceptance-suite-only and the extension's wrapper refuses it**
(loud failure, exit 2, before any forwarding). It exists for exactly one reason: a dependency
**cycle** among books is **unconstructible in Lean source**, because a book's dependency edge is a
module import and Lean's import graph is acyclic by construction. The cycle detection is still
worth having -- as a guard for a future grain and for a bug in the graph computation -- but it can
only be exercised by feeding the ordering a graph.

`--no-docs-stage` is in the driver but **not** in the extension command's Options table as read
2026-10-03; use the driver's help block as the authority on flags.

## Reading the output: what it does and does not warrant

### Misreport 1: the closing line counts DISCOVERED books, not certified ones

```
[ok] N book(s) certified, dependencies first: <names>
```

`certify.sh:706` prints `${#order[@]}` and `${order[*]}` -- **the discovered topological order,
regardless of how many certified.** Measured instance: `[ok] 13 book(s) certified` with the full
discovered list, on a run where that was not the count.

**So the closing line warrants that the driver completed, and nothing more.** Cross-check
`book.cert.json` files on disk -- which is what the dispatch that hit this did instead of trusting
the line. Making the driver report the real count is recommendation 9 of
`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md`; unbuilt.

### Misreport 2, the worse one: a killed run reads as a genuine refusal

`certify.sh` carries **no timing and no memory instrumentation**. So a run killed by `earlyoom`
logs a bare

```
!! book 'X' was REFUSED
```

with **no `[REFUSE]` detail lines** -- **visually indistinguishable from a genuine refusal.**
Measured instance: `FramedChannelAeneas.Book.Crc8` at ~16-18 GiB RSS, **twice**.

**How to tell them apart**: a genuine refusal carries `[REFUSE] <reason>` lines naming one of the
reason strings (`matrix-violation`, `policy-vacuous`, `policy-violated`, `stale-certified`,
`missing-source`, `axiom-outside-book-axioms`, `self-check`, `serial-check`,
`serialisation-refused`, `prev-unparseable`, `version-check`, `write-cert`,
`docs-report-unreadable`). A bare `was REFUSED` with no detail is the signature of a kill. Check
`dmesg`/`journalctl` for `earlyoom`, and check the reader budget the run printed.

Instrumenting this is `specs/175_instrument_certifier_and_classify_outcomes/`, NOT STARTED. Both
misreports are recorded as `domain/known-gap-register.md` B12.

### The shake stage reports SKIPPED, and its rc never propagates

`certify.sh:625-651` runs `lake shake` with explicit module targets as an **ADVISORY** stage. On
the pin, `lake shake` refuses a non-`module` package outright with
`error: lake shake only works with modules currently`; the driver greps for `only works with` and
reports **`SKIPPED`**. A real finding reports `FINDING (advisory, does not affect the exit
status)`.

**It is advisory by necessity, not preference.** Measured on a two-book fixture, shake advises
removing a **book module's own imports** -- which are load-bearing **membership** metadata, not
symbol use (`certify.sh:127-137`). Shake measures symbol use; a book module's imports declare its
members.

So: **a green `certify.sh` run tells you nothing about import minimality**, and a `SKIPPED` shake
line is the expected output rather than a problem to fix. See `domain/known-gap-register.md` B3.

## The reader budget, and the two execution paths

The certifier's work happens in a **reader** run under `lake env lean` inside the certified
package's workspace, at the **`OLeanLevel.private`** level.

**The budget** (`certify.sh:202-219`): `CERTIFY_READER_MEM_MIB` when set, else `MemAvailable`
(from `/proc/meminfo`) **minus 2048 MiB, floored at 6144 MiB**. `lean -M` takes MiB. The budget is
printed as a `note`, naming its source -- read that line before blaming a kill on the book.

**Two paths, one source.** `books/lean/lakefile.toml` declares a `certify` `lean_exe` whose
`root`/`srcDir` point at `books/certifier/Certify.lean`, so there is **exactly one certifier
source** compiled once as an executable, with `CERTIFY_INTERPRETED=1` selecting the interpreted
fallback (`lean -M <MiB> --run <reader>`) instead of the compiled exe. If the exe was not
produced, the driver says so and names the environment variable rather than silently switching.

### The two reader mechanics that are MANDATORY and SILENT when omitted

Both are worth knowing because each failure mode looks like a data problem rather than a setup
problem:

- **`loadExts := true` after `enableInitializersExecution`.** Without it the provider's
  environment extensions are not loaded, so `isInstance` reads `false` for a known instance. The
  certifier's own `probe` subcommand names this signature explicitly
  (`books/certifier/Certify.lean:264-267`): "A probe that reports `isInstance = false` for a known
  instance is **the signature of a missing `loadExts := true`**."
- **Importing at `OLeanLevel.private`.** At `.exported` or `.server` an imported theorem carries
  **no value**, docstrings are absent, and `depends[].exports_used[].statement_level` would be a
  constant `true`. The same probe names that signature too: "one that reports `value? = none` for
  a theorem is **the signature of an import at the wrong `OLeanLevel`**."

If you write a reader script of your own against this environment, use `probe` to confirm the four
environment facts **before** trusting anything it computes.

## A working sequence

```bash
# 1. Pre-launch check, scoped to the component root. Read the budget and the --extra-pkg-dir list.
bash books/scripts/certify.sh --check components/framed_channel

# 2. If freshness failed, build through the build guard, then re-check.

# 3. Determinism check that touches nothing (optional, and the cheapest real run).
bash books/scripts/certify.sh --no-build --no-write components/framed_channel

# 4. The real run. Omit --no-build if the tree is not known current.
bash books/scripts/certify.sh --no-build components/framed_channel

# 5. Verify the CLAIM, not the closing line.
find components/framed_channel -name book.cert.json -newermt '-10 minutes' | wc -l
```

Step 5 is not optional defensiveness; it is the documented way to read the result (Misreport 1).

Through the extension, the same driver is reached as `books-certify.sh`, a
resolve-and-passthrough wrapper that forwards every argument verbatim **except `--graph-from`**.
Its exit codes add one: **3** -- the real driver could not be found under the resolved repository
root, meaning the extension is loaded in a repository with no books tooling.

## Related

- `domain/certificate-ledger-and-records.md` -- what a certificate contains, and the refusal set.
- `domain/identity-and-versioning.md` -- the version check as a ledger diff.
- `domain/gate-tiers.md` -- what this tier checks, and what it does not.
- `patterns/warning-driven-convergence.md` -- converging `book_requires` across runs.
- `domain/known-gap-register.md` -- B3 (the shake stage), B12 (both misreports).
