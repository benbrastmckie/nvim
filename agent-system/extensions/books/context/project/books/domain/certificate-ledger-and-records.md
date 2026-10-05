# The Certificate, the Ledger, and the Two Side Records

`book.cert.json` is the computed half of a book's metadata, and **the only input of every non-Lean
tool**. Beside it sit two further JSON files that are easy to conflate and are not the same
artifact at all.

**Normative source**: `books/schema/book-cert-v2.md` (689 lines). **Design record**: Decisions 8,
9, 11 -- `docs/book-convention/08-computed-dependencies-and-book-cert-json.md`,
`docs/book-convention/09-trust-unit-is-the-export.md`,
`docs/book-convention/11-versioning-rule.md`. Every figure below was measured 2026-10-03 against
the Logos/Verification tree at git `7281c81`. Gap claims defer to
`domain/known-gap-register.md`.

## Where the certificate lives, and the one placement that corrupts a different tool

**Directly in the book directory, beside `book.toml`** -- per
`docs/architecture-decisions.md` decision 2, with `DEPENDS.md` generated beside it for the
documentation tier. **Never in a `certificate/` subdirectory**: the reason is mechanical, not
stylistic -- the framed_channel export tooling treats **every** directory named `certificate` as a
discovery root, so nesting a certificate under one corrupts that discovery (`rules/books.md`
item 2).

**It is the only non-Lean input.** `books-tool`, the certify driver, and any future reconciliation
or book-health tooling read `book.cert.json` and nothing else as their record of truth (Decisions
8, 9, 11). A tool reaching for `book.toml`, Lean source, or `book.record.json` instead is reaching
outside the contract. And per `docs/architecture-decisions.md` decision 10, **any edit to an input
an existing certificate digests regenerates that certificate in the same commit** -- a toolchain
bump is such an edit.

## The certificate is a fixed point, and byte-stable

**Every field is a function of the loaded environment and the workspace, and of nothing else. The
writer does not read the previous certificate.** That is what makes "an unchanged tree regenerates
byte for byte" true in the form that matters -- regenerating twice in a row yields identical
bytes, rather than bytes that converge after a second run.

Two fields were initially written from the previous certificate and **both were removed or
pinned**, because each made the certificate non-idempotent for exactly one generation (measured:
the first regeneration after any edit disagreed with the second on an unchanged tree). There is no
`version_bump_required` field -- the required bump is a property of a *pair* of ledgers, not of
this tree, and is **reported** by the reader's `version-check` subcommand and by the driver. And
`stale` is always written `false` -- staleness is a **reader's verdict about an existing
certificate**, reached by recomputing `identity` from the recorded inputs. A consumer wanting
either **runs the certifier and reads its report**; neither is a fact about the tree alone.

Byte-stability rules: keys sorted; arrays sorted by their declared natural key; no insignificant
whitespace; UTF-8; LF; **exactly one** trailing newline; **no timestamp and no commit hash** (the
only 40-hex-looking value that is not a digest prefix is the recorded toolchain `githash`). Name
ordering is by `Name.toString`, **not** `Name.quickLt`, because `quickLt` orders by internal
structure rather than the order a reader or an external recomputation expects.

## The twenty top-level keys

Measured verbatim from `interface/books/result/book.cert.json` (2,382 bytes). `C` = computed,
`A` = authored-and-copied.

| Key | Type | | Notes |
|---|---|---|---|
| `schema` | integer | C | exactly `2` |
| `serialisation_format` | string | C | `dag-v2`. An absent field means the replaced `tree-v1` encoding |
| `book` | `{name, module}` | C | `name` comes from the `book` **command**, not from `book.toml` |
| `passes` | array | C | exactly `["reverify"]` in this implementation |
| `reserved_passes` | array | C | the four reserved names, so a reader sees what is unimplemented without consulting the schema |
| `export_ledger` | array | C | one object per export, sorted by `name` |
| `modules` | array | C | the **derived** module list, sorted by `name` |
| `observed_layer_relation` | array of `{row, imports}` | C | the layer relation read off the **computed** import graph |
| `depends` | array | C | one entry per direct dependency book, sorted by `book` |
| `policies` | array | C | `book_policy` assertions with their outcomes |
| `toolchain` | object | C | `{toolchain, githash, lean_options_seed, externals_reached}` |
| `judgments` | object | **A** | `{source: "authored", fields: {<dotted key>: <value>}}` |
| `assumptions` | array of `{id, text, anchor}` | C | the `book_assume` items with **re-verified** anchors; `anchor` is `null` when none was given |
| `not_claimed` | array of string | C | the `book_not_claimed` items |
| `docs` | object | C | written by the docs stage; **never authored** |
| `stale` | boolean | C | always `false`, per above |
| `interface_identity` | string | C | **the chaining key** |
| `proof_identity` | string | C | **informational; never the chaining key** |
| `identity` | string | C | the book's own freshness key |

### `passes` versus the four `reserved_passes`

Measured: `passes: ["reverify"]` and
`reserved_passes: ["meta_import_ledger", "leanchecker", "exported_view_replay", "trust_scope"]`.
`reverify` is the **only implemented pass**; the four reserved names are the deferred certifier
passes, fixed in shape and not run. Decision 16's own marker records "every reserved pass" as not
exercised. See `domain/known-gap-register.md` B10. A consumer must read `passes`, not assume.

## The export ledger row: sixteen fields

One row per export. Measured 2026-10-03 on `interface/books/result/book.cert.json`: **sixteen
keys**. Field notes from `books/schema/book-cert-v2.md:278-325`:

| Field | Notes |
|---|---|
| `name` | the exported constant |
| `kind` | from `getOriginalConstKind?`, **never from the row** |
| `is_instance` | a **separate flag, never an alternative kind** -- an instance export can be a theorem, measured on `RleCodec.instCodecLaws` (kind `thm`, `isInstance = true`) |
| `serialisation` | `S(type)` -- Decision 11's versioning key, a term-table string |
| `own_value_serialisation` | `S(value)`, or `"-"` for a theorem and for a constant with no value |
| `text` | the pretty-printed statement, under exactly `pp.fullNames := true`, `pp.unicode.fun := false`, `format.width := 100`. **For humans and diffs only** -- two statements with identical text can have different digests, because an implicit binder kind does not always show |
| `doc` | the docstring, read at `OLeanLevel.private`; **absent at `.exported` and `.server`** |
| `axioms` | the transitive axiom set, sorted |
| `digest` | the statement digest. The documentation-reconciliation signer reads this field as `statement_digest`; **the name here stays `digest`** and no second field is added |
| `statement_key` | the export's own content, with no cone and no axioms |
| `cone_key` | the statement cone's contents, with no axioms |
| `proof_digest` | recorded **beside** `digest`, never instead of it |
| `statement_cone_size` | the cost model's record; measured 187-490 on real composites |
| `proof_cone_size` | measured 1,700-2,900 on real composites |
| `foreign_nonexports` | `{name, declaring_module, book}` triples (below) |
| `trust_scope_violations` | **`[]` until the trust-scope predicates are adopted**; present from day one so the shape is fixed |

The `statement_key` / `cone_key` / `axioms` split is what lets the version check **attribute** a
change rather than guess at it; see `domain/identity-and-versioning.md`.

### `foreign_nonexports`, and why it exists

The constants of **other books** that this export's **statement** cone reaches and that carry
**no export row**. Decision 13 settles the trust question: an operation another book's statement
mentions is **not** thereby required to carry `@[book_export]`. A composite stated over a part's
exposed operation depends at statement level on constants the part marked `@[expose]` for
*computability* without marking them for *trust*. The declined alternative -- requiring an export
row for each -- would make one book's trust marking, ledger size and `interface_identity` follow
from **another book's phrasing choices**.

Two narrowings keep the field meaningful rather than full of noise:

- **"Another book" is narrower than "not one of our modules."** Core Lean and `Std` are not books,
  so `Nat`, `True` and `Eq` never appear; nor does a constant whose declaring module is assigned to
  *no* book (an unassigned module in a package that declares books is Decision 1's own violation,
  which the module-grain walker reports).
- **Compiler-generated auxiliaries never appear**, via a two-halved attribution predicate: the
  name test (`match_`, `eq_`, `proof_`, `_`-prefixed, numeric components) **plus** structural
  attribution of constructors, recursors, projections, and `def`s whose longest strict name prefix
  names an inductive or structure. **Both halves are needed**: measured, the cross-book slice of a
  real statement cone carries **zero** `match_n`/`eq_n` names and still collapses 13 -> 3,
  15 -> 3, 12 -> 3, 10 -> 3 under attribution; the noise is `.mk`, the projections, `.casesOn` and
  `.rec`.

## `modules[]`, and why the list is derived

Fields: `name`, `layer` (string or `null` when the module states none), `is_module` (the
module-system tier, free from the header), `meta_imports`, `imports` (both with `Init` excluded).

**The list is derived, per Decision 1**: a book's modules are its book module's direct imports,
**less `Init`**, **less the provider** (a private import of every code module and a member of no
book), and **less any other book module** -- importing one of those is how a cross-book
*dependency* is declared, which is the opposite of membership.

`meta_imports` is recorded from day one and **never refused here** (refusal is the reserved
`meta_import_ledger` pass), and it is **not** a complete trace of a forged export row: a `module`
file with a **plain** (non-`meta`) import of the provider can write the provider's extensions
directly, with no error and no `isMeta` flag, because they are declared `meta` inside a
`public section` and a `meta` declaration needs only a plain import at the use site. What stops
such a row reaching a certificate is the `reverify` pass's recording-equals-declaring refusal,
not this field.

## `depends[]` and `policies[]`

`depends[]`: `book`, `exports_used[].{name, digest, statement_level}`, and
`layers: {our_layer: [their_layers]}`. **`statement_level` is computable only because the
certifier imports at `OLeanLevel.private`**, where an imported theorem carries its value; at
`.exported` or `.server` both cones coincide and the flag would be a constant `true`.

`policies[]`: `subject`, `never_imports` (a module-name **prefix**, deliberately unresolved),
`checked_modules`, `outcome`, `violations[].{module, import}`. **The `checked_modules`
invariant: non-empty in every written certificate.** A subject matching neither a `book_layer` a
member states nor a member module name resolves to the empty set, which is a `policy-vacuous`
refusal -- and **no certificate is written for a refused book**. `outcome` therefore stays a
**two-word** vocabulary (`holds` / `violated`) with no third word for "checked nothing". A
consumer reading `holds` knows the assertion was checked against at least one module; the
authoring rule this protects is in `standards/metadata-split.md`.

## The `docs` block

Written by the certifier's docs stage and **never authored**. Measured shape:

```
docs: { context_pack_bytes: {consumer_full, consumer_overview, documenter, maintainer},
        counts: {missing, orphaned, reconciled, stale},
        names_resolved, per_export, tier_compile }
```

Measured on `interface/books/result/book.cert.json`: four non-zero `context_pack_bytes`
(4322 / 4322 / 4322 / 6808), all four `counts` zero, `names_resolved: "unknown"`,
`per_export: []`, `tier_compile: "unknown"`. The `unknown` values are **reported by name as
unknown rather than guessed** -- see `standards/reconciliation-contract.md` for the split between
`books/tool/docs-stage.sh` and the certifier, and which halves are unbuilt.

## The toolchain field, and three deliberate exclusions

`{toolchain, githash, lean_options_seed, externals_reached}`. `toolchain` and `githash` are
**in-process constants** (`Lean.toolchain`, `Lean.githash`) -- no subprocess, no
`lean --version` parse.

- **No host triple**: it would make the identity differ between a Linux and a macOS checkout of an
  identical tree, which is not a fact about the book.
- **`lean_options_seed` is the resolved seed only, not a guarantee.** Lake `--setup` *seeds* the
  option state and a file's own `set_option` still wins, so an option cannot be locked per
  library. Measured here: `["autoImplicit=false"]`, exactly what `books/lean/lakefile.toml` asks
  for. The seed is read from the certified package's own lakefile and **from no other** --
  recording a dependency's options would stale every book on a provider-lakefile edit.
- **`externals_reached` is filtered by a stated rule**: a `lake-manifest.json` entry counts as
  reached when its normalised package name equals the normalised root component of at least one
  loaded module. On this repository the set is **empty**, correctly -- every `require` is a local
  path and no package requires Mathlib.

## The two side records, which are NOT the same artifact

This is the single most common conflation in descriptions of this system.

| | `book.record.json` | `book.read.json` |
|---|---|---|
| **What it is** | the **reconciliation / approval** record | the **non-expert read test** record |
| **Binds** | each guarantee's text hash to its export's ledger digest, with who signed and when | three human marks about one book's document |
| **Schema** | `schema`, `guarantees[].{export, guarantee_sha256, statement_digest, by, date}` | six keys: `book`, `by`, `date`, `reader`, `marks{does_what, assumes_what, could_go_wrong}` |
| **Writer** | `books/tool/approve-guarantees.sh` -- **ABSENT**, not built | `books/tool/record-read-test.sh` (163 lines), the **sole** writer |
| **Real instances, 2026-10-03** | **ZERO.** The only two in the tree are fixtures: `books/tests/certify/fixtures/books/pt/` and `typst/tests/book-template/probe/` | **five**: the four `interface/books/*` plus `components/rle_codec/books/rle_codec/` |
| **Digested?** | **No -- non-digested by construction**, and confirmed by measurement | **No** -- writing all five left every one of the five certificates' `identity` unchanged |
| **Written by** | **people** | the writer script; `by` records which, valued `reader` or `agent` |

Both are **excluded from `identity`** -- see the exclusion table in
`domain/identity-and-versioning.md`.

A real `book.read.json`, verbatim (`interface/books/queue/book.read.json`):

```json
{
 "book": "Queue",
 "by": "agent",
 "date": "2026-10-03",
 "marks": { "assumes_what": "pass", "could_go_wrong": "pass", "does_what": "pass" },
 "reader": "non-Lean software engineer (simulated)"
}
```

**All five real read-test records carry `"by": "agent"`.** Decision 17's own marker states what
that means: the first run is a `by: agent` **PRE-CHECK and not a reader run**, carrying a stated
conflict of interest (the same agent wrote the five documents and then marked them). It produced
one real defect -- a document claiming "four theorems" and "an instance" where the certificate's
ledger has six theorem-kinded exports and two instances -- and the document was corrected against
the certificate. **A human non-Lean reader's run, with a second person marking, is still owed.**
Settling the record is not running the test.

The `book.record.json` fixtures are explicitly marked provisional in their own `_provisional`
field, which also records a contract worth carrying: **`typst/lib/book.typ` must never read that
file directly** -- every guarantee's reconciliation state is read from the certificate's own `docs`
field, which the docs stage computes from the record against the ledger. See
`tools/typst-template-contract.md`.

## The refusal set: when no certificate is written

From `books/schema/book-cert-v2.md`, "The refusal set". A book is refused and **no certificate is
written** on:

a failed re-verification (a forged row, an unresolvable anchor or name, an unknown kind); a
**matrix violation** read off the computed import graph -- the **record of truth**, because the
elaboration-time `book_layer` check is only as trustworthy as the provider a module compiled
against; a **failed policy assertion**; an **axiom outside `book_axioms`**; a **`sorry` outside a
`challenge` module** (a module with no layer row gets no benefit of the doubt); a **`certified`
status whose `identity` fails to recompute**; and a **missing source file** for one of the book's
own modules.

Measured 2026-10-03, the reason strings in `books/certifier/Certify.lean` are wider than that
list: `docs-report-unreadable`, `matrix-violation`, `missing-source`, `policy-vacuous`,
`policy-violated`, `prev-unparseable`, `self-check`, `serial-check`, `serialisation-refused`,
`stale-certified`, `version-check`, `write-cert`. Decision 10's marker records the set as
contradicted -- it "has a seventh entry, `missing-source`", amended 2026-10-03 with an eighth.
**Read the implementation's reason strings, not a prose list, when diagnosing a refusal.**

**Warnings never fail a run**: a `book_*` command in a code module, a stale or undeclared
`book_requires` line, and the version check's one-predicate note.

## Related

- `domain/book-toml-v2.md` -- the authored half.
- `domain/identity-and-versioning.md` -- how the digests roll up, and the exclusion list.
- `domain/status-and-trust-vocabularies.md` -- what `judgments.fields`' status and verdicts mean.
- `tools/certify-guide.md` -- how to produce a certificate, and what the run output warrants.
