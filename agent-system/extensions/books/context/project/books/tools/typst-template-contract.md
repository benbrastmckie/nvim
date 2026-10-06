# The Three-Tier Typst Template Contract

## Measured state, 2026-10-03 -- read this before the contract

**This is a design contract, not an exercised one.** Four facts, measured against the
Logos/Verification tree at git `7281c81`:

1. **No real book has a Typst document.** The only two `book.typ` files in the whole tree are the
   library itself (`typst/lib/book.typ`) and the test probe
   (`typst/tests/book-template/probe/book.typ`). Of the 27 real manifests, **25** declare
   `[docs] entry = "docs/book.md"` and **two** declare `entry = "book.typ"` for a file that **does
   not exist**.
2. **A real certificate cannot currently render.** `typst/lib/book.typ` reads four top-level
   certificate names the writer does not emit:

   | The library reads | At | The writer emits instead |
   |---|---|---|
   | `certificate.version` | `:138` | `judgments.fields["book.version"]` |
   | `certificate.status.derived` / `.authored` | `:101`, `:141`, `:142` | **nothing** -- no `status` field is written |
   | `certificate.trust` | `:268` | `judgments.fields["trust.G*"]` |
   | `certificate.exports` | `:343`, `:401`, `:409`, `:446` | `export_ledger` |

   Measured in the design record itself: "a minimal document loading
   `books/tests/certify/fixtures/books/pt/book.cert.json` fails with
   `error: dictionary does not contain key "version"`". That is why the `pt` fixture carries no
   `book.typ`.
3. **`typst/lib/book.typ` is 462 lines**, not 183. A figure of 183 is describing a much earlier
   state; the one divergence of this class that has already **closed** is the `docs` field -- the
   template's three reconciliation reads now read `docs.per_export`, the writer's shape, guarded
   by a shape case in `typst/tests/book-template/run.sh`.
4. **Zero real books carry a `book.record.json`**, and its writer is unbuilt.

Reconciling the four reads is a live, `researched` entry in the consuming repository's register
(`specs/186_reconcile_book_typ_certificate_reads/`). **Re-measure the four reads before acting on
anything below.** The contract body that follows is stable; this section is what a refresh
touches. Gap claims defer to `domain/known-gap-register.md` B9.

---

## What the library is

`typst/lib/book.typ` is **the per-book document template**: one source, three reader tiers, two
inclusion modes.

| Input | Values | Default |
|---|---|---|
| `--input tier=` | `overview` \| `full` \| `reference` | `full` |
| `--input mode=` | `standalone` \| `embedded` | `standalone` |

Read as `sys.inputs.at("tier", default: "full")` / `.at("mode", default: "standalone")`
(`book.typ:60-61`); both arrive as **strings** regardless of how `--input` was spelled, and both
defaults match the wrapper's own (`typst/scripts/build.sh`).

Tier gating is **one function taking the tiers a block applies to**
(`#let for-tier(tiers, body) = if tier in tiers { body }`, `:68`), not three separate wrappers --
so a block can belong to more than one tier without duplicating its body. `overview` selects tier
one; `full` selects all three; `reference` selects tier three plus the title.

`mode` is an **explicit input, never inferred**: `embedded` suppresses the document-level
`set`/`show` rules (which would otherwise fail the including manual's build outright) and demotes
the book's own heading levels so its top heading nests under the including chapter's.

## The ONE data input, and the mechanism that forces it

**The book's `book.cert.json`, loaded by the book DOCUMENT and handed in:**

```typst
#import "/typst/lib/book.typ": book
#show: book.with(certificate: json("book.cert.json"))
```

`json("book.cert.json")` is a path **relative to the document itself**, and the dictionary is
passed into `book.with(certificate: ...)`.

**The library never calls `json()` for a certificate, never reads `book.toml`, never reads
`book.record.json` and never reads Lean source.** That is not a style rule; it is forced by a
Typst resolution rule, verified on 0.14.2 and recorded in the library's own DATA FLOW note
(`book.typ:9-16`):

> **A relative `json()`/`read()`/`image()` path resolves against the file whose SOURCE TEXT
> contains the call.** A library function's own `json("x")` always resolves relative to the
> library.

So a shared library **cannot** read a different certificate per book. The only way to give each
book its own data is for each book's document to load it and pass it in.

`typst/lib/phrases.toml` is **the one other file the library reads**, and it is read
**root-absolutely** (`toml("/typst/lib/phrases.toml")`, `book.typ:55`) precisely because the
relative rule would otherwise resolve it against the including document. Its size is a moving
figure and should be re-measured rather than quoted: `8,564` bytes per the design record, and
`8,478` bytes measured on an uncommitted working tree on 2026-10-03. Treat it as "roughly 8.5 KB
of phrase table", and re-measure if a pack-size calculation depends on it.

The library imports **no preview package**: only `typst/manual/template.typ` does, in exactly two
lines (thmbox, fletcher), and the tier functions reuse that template's existing pieces
(`not-claimed-list`, `thmbox-sans-fonts`).

## Label mechanics: three rules, each from a measured failure

### 1. Every label is book-id-prefixed, from a `state()`

The book id is read from `book-id-state`, a `state()` updated **once** by `book()`
(`book.typ:131`), rather than threaded as an explicit parameter through every tier function --
which would force every call site in every book document to repeat it.

A label is therefore `<probe:guarantee:Probe.Pair.swap_swap>`, **never** a bare
`<guarantee:...>`, so labels **cannot collide once several books are embedded in one build**.

### 2. A label built in a SEPARATE `context` block SILENTLY fails to attach

The sharp constraint, verified empirically on 0.14.2 and stated in the library's own comment:

> A label constructed by a **separate** `context` block and placed as a sibling **after**
> already-realized plain content **does NOT attach** to that content -- Typst's "attach a label to
> the preceding element" resolution happens at an earlier, syntactic stage than `context` resolves
> at. **It compiles with no error** and the label is simply **absent from every later
> `typst query`**.

The resolution: **labelled content and its label must be constructed TOGETHER inside ONE `context`
block.** Two helpers do exactly that, and every tier function that emits a label goes through one
of them -- never through a bare `label(...)` call placed after independently-realized content:

```typst
#let tagged(key, body) = context {
  let id = book-id-state.get()
  [#body#label(id + ":" + key)]
}

#let tagged-metadata(key, kind-name, data) = context {
  let id = book-id-state.get()
  let tagged-data = data + (kind: kind-name)
  [#metadata(tagged-data)#label(id + ":" + key)]
}
```

A silent query miss is the signature of this failure. It is not a data problem.

### 3. Every `metadata` value carries an explicit `kind`

**Query convention.** Because every label is book-id-prefixed, a consumer **cannot** query a bare
`<guarantee>`/`<lean-decl>`/`<book-meta>` selector across an embedded manual and expect it to
match every book at once. So every `metadata` value the library emits carries an explicit `kind`
field (`"book-meta"`, `"guarantee"`, `"lean-decl"`, ...), and:

- a generic `typst query <file> 'metadata'` returns **every tagged element from every embedded
  book in one pass**, and the consumer **filters on `.value.kind`** rather than on label text;
- a per-book label remains queryable **directly by its exact, known text** when the book id is
  known ahead of time, which is what the probe suite does.

`tagged-metadata` takes `kind-name` separately from `key` precisely because they differ: key
`"guarantee:Probe.Pair.swap_swap"`, kind `"guarantee"`.

## The compile root and the pins

**The compile root is the REPOSITORY root** (`--root .`,
`docs/records/architecture-decisions.md` decision 9), passed through
`bash typst/scripts/build.sh` -- **the sole caller of `typst compile`** in the tree. It resolves
the repository root from its own location and passes it to `--root` as an **explicit
command-line flag only**; it deliberately does **not** export `TYPST_ROOT`, because doing so would
make `typst compile`'s own root resolution silently depend on an environment variable.

That root is what lets a book's document live **outside `typst/`** and still both compile
standalone **and** embed in the manual: root-absolute imports (`/typst/lib/book.typ`) resolve
either way.

**Pins, VERIFIED rather than assumed.** Measured 2026-10-03: `typst --version` reports
**`typst 0.14.2 (b33de9de)`**, and the only two preview packages imported anywhere in
`typst/lib/` or `typst/manual/` are **`thmbox:0.3.0`** and **`fletcher:0.5.8`**. The design record
also pins **cetz 0.3.4**; it is not imported by the book template's own dependency path on this
tree, so treat 0.3.4 as the declared pin and the two above as the measured imports.

## The test suite and the probe

`typst/tests/book-template/run.sh` (185 lines) runs against
`typst/tests/book-template/probe/`, which holds exactly four files: `book.toml`,
`book.cert.json`, `book.record.json`, `book.typ`.

| Case | What it asserts |
|---|---|
| 1 | **three standalone tier compiles** -- `tier=overview`, `tier=full`, `tier=reference`, each at `mode=standalone`, **exit 0 and empty stderr** |
| 2 | **one embedded compile** -- `tier=full`, `mode=embedded`, the probe included in the manual |
| 3 | **`typst query` returns the metadata** -- a `<book-meta>` entry, **exactly four** `<guarantee>` entries, and a `<lean-decl>` entry that is **book-id-prefixed** (`book == "Probe"`) and **carries a digest** |
| 4 | **`tier=overview` output contains no backtick span and no math symbol** |
| 5 | the `docs`-field shape, including the four `context_pack_bytes` keys, with the **retired** variants (`guarantees[]{export,state}`, `aggregate_counts`, `context_pack_sizes`, `orphaned`) asserted **absent** |

Compiles go through `typst compile --root "$REPO_ROOT" --input "tier=$tier" --input "mode=..."`,
exactly as a real book's would.

## The tier-one content bar

Tier one is written for a reader who will not read Lean. The bar:

- **No symbols, no Lean identifiers, no tool names.**
- **Every guarantee names an export, and every export has a guarantee.**
- **Assumptions and not-claimed items are rendered FROM the certificate, never retyped** -- they
  come from `certificate.assumptions` and `certificate.not_claimed` (`book.typ:213`, `:236`).
- **A book that cannot support a section carries a scope note naming what is missing**, rather
  than omitting the section silently.
- **A reworded guarantee needs re-approval exactly as a changed statement does** -- the approval
  record binds a hash of the *text* as well as the statement digest. See
  `standards/reconciliation-contract.md`.
- **The one technical element tier one permits is the status badge** (Decision 12), which renders
  the passes the certificate names and the recheck legs those passes themselves name -- and
  **never claims more**.

**The mechanical lint is part of the docs stage, and is PARTIALLY built.** Clause 7 of Decision 17
specifies that tier-one text containing a dotted Lean identifier, a bare mathematical span, or a
tool name **fails the docs stage**. Measured: `typst/tests/book-template/run.sh` lints **backtick
spans and math symbols** on the rendered overview (case 4 above); **dotted identifiers and tool
names are not yet linted**, and `books/tool/docs-stage.sh` reports `tier_one_lint` by name under
`unknown` rather than guessing. So two of the three prohibitions are currently enforced by review,
not by a check.

## The three context packs the tiers feed

Reported by the docs stage in bytes and approximate tokens:

| Pack | Purpose | Contents |
|---|---|---|
| consumer | use the book from another book or crate | `book.cert.json`; the document rendered at `tier=overview` **and** at `tier=full` |
| documenter | reconcile prose | consumer pack, plus the phrase table and `book.record.json` |
| maintainer | change a statement or proof | documenter pack, plus the book module and the code modules of one layer |

**Pack sizes are measured on the RENDERED document, not on its source**, because the tiers
interleave in one file and no file on disk corresponds to "tiers one and two". A Typst document is
compiled at `tier=overview` and at `tier=full` and the **extracted text** of each render is sized
with `pdftotext` -- extracted text, not PDF bytes, because a PDF carries a ~43 KB embedded-font
floor that swamps the signal. **A failing compile reports that tier's size as absent and
`tier_compile` as failed for it -- never a hard-coded number.**

Measured consequence for the five real books: the documenter pack is a **lower bound** for them,
because `book.record.json` is absent. The counter-instance proves the mechanism --
`books/tests/certify/fixtures/books/pt/` carries a record, and its documenter pack is **strictly
larger** than its consumer pack (11,457 B against 10,283 B), asserted by a case in
`books/tests/certify/run.sh`.

## Related

- `standards/reconciliation-contract.md` -- who may edit a `book.typ`, and when.
- `domain/certificate-ledger-and-records.md` -- what the certificate actually carries, including
  the `docs` block the template reads.
- `tools/tooling-inventory.md` -- `typst/scripts/build.sh` and the repo-side machinery not to
  duplicate.
- `domain/known-gap-register.md` -- B9.
