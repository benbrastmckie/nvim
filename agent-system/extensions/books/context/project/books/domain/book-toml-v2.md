# `book.toml` v2: What Is Authored, and What Is Computed Instead

`book.toml` holds **judgments only**: a field belongs in it exactly when a human decides it and no
elaborator can check it. Everything derivable belongs in the book module and is computed by the
certifier into `book.cert.json`.

**Normative source**: `books/schema/book-toml-v2.md` (324 lines). **Design record**:
`books/book-convention/07-book-toml-v2-schema.md` (Decision 7). **Validator**:
`books-tool validate`, over
`books/tool/Books/Manifest.lean`. Gap claims defer to `domain/known-gap-register.md`.

## Fifteen fields across seventeen keys -- and what happened to "twelve"

`books/schema/book-toml-v2.md:48-85` is titled "The fifteen fields / seventeen keys" and
enumerates them with types. Transcribed:

| # | Key | Type | Required | Notes |
|---|---|---|---|---|
| 1 | `schema` | nonnegative integer | yes | exactly `2` for this version |
| 2 | `book.name` | string | yes | equals the `book` command's argument |
| 3 | `book.module` | string | yes | the book module's Lean module name; **the only Lean path in the file** |
| 4 | `book.version` | string | yes | semver of the **exported interface** |
| 5 | `book.status` | string | yes | one of the three status words |
| 6 | `book.license` | string | yes | licence identifier (this repository: `UNLICENSED`) |
| 7 | `book.maintainers` | array of string | yes | `"Name <email>"` entries |
| 8-13 | `trust.G0_checker` through `trust.G5_binding` | string | no | one of the four verdict words; omitted means `not_applicable` |
| 14 | `provenance.rust_crate` | string | bridged books only | with the next two, the **one** `[provenance]` field |
| 15 | `provenance.rust_paths` | array of string | bridged books only | idem |
| 16 | `provenance.extractor` | string | bridged books only | **a pointer to a pin file, never a copied revision** |
| 17 | `docs.entry` | string | yes | path to the book's documentation entry point |

**The count, because the design record's headline is wrong about its own enumeration.** Decision
7's sentence reads: "Twelve fields: `schema`; six under `[book]`; the six ground classes under
`[trust]`; `[provenance]` with its three keys for bridged books only; and `[docs] entry`" --
which, counting `[provenance]` as one field with three keys, gives `1 + 6 + 6 + 1 + 1 = 15`, not
twelve. The schema document records **fifteen fields / seventeen keys** as what the schema holds
and keeps **"twelve fields" only as the historical name** of the schema in the design record. It
is a name, not a count; do not try to reconcile it.

**Confirmed independently against a real certificate.** `judgments.fields` in
`interface/books/result/book.cert.json` carries exactly **seventeen** keys, measured 2026-10-03:
`schema`, six `book.*`, six `trust.G*`, three `provenance.*`, and `docs.entry`. The validator
decodes and checks all seventeen; **it asserts no count**.

## The vocabularies, enforced

Both word lists are enforced from `books/tool/Books/Manifest.lean:33-38`:

```lean
def statusWords  : Array String := #["draft", "certified", "deprecated"]
def verdictWords : Array String := #["verified", "validated", "trusted", "not_applicable"]
def trustKeys    : Array Name   := #[`G0_checker, `G1_translation, `G2_ir_faithfulness,
                                     `G3_models, `G4_specification, `G5_binding]
```

What each word licenses and forbids is `domain/status-and-trust-vocabularies.md`'s subject. Two
defaulting rules matter here:

- An **omitted** `[trust]` key defaults to `not_applicable`.
- An **absent `[trust]` table** means all six ground classes are `not_applicable` -- and that is
  the documented **honest record for a draft book with no verdict yet**, not an omission.
  Measured 2026-10-03: **none** of the 27 real manifests carries a `[trust]` table.

## What a real manifest looks like

`interface/books/result/book.toml`, verbatim and complete (the comment block is the file's own):

```toml
schema = 2

[book]
name        = "Result"
module      = "Interface.Book.Result"
version     = "0.1.0"
status      = "draft"
license     = "UNLICENSED"
maintainers = ["Benjamin Brast-McKie <benjamin@logos-labs.ai>"]

[docs]
entry = "docs/book.md"
```

A bridged book adds `[provenance]` and nothing else
(`components/framed_channel/books/stuff/book.toml`):

```toml
[provenance]
rust_crate = "framed_channel"
rust_paths = ["rust/src/stuff.rs"]
extractor  = "pins: nix/aeneas-pin.json"
```

Note `extractor` is **a pointer to a pin file**, never a copied revision string -- a copied
revision drifts silently from the pin it was copied from.

### Measured authoring practice, 2026-10-03

Over the 27 real manifests in the Logos/Verification tree at git `7281c81`:

| Measurement | Value |
|---|---|
| `status = "draft"` | **27 of 27** |
| carries a `[trust]` table | **0 of 27** |
| carries a `[provenance]` table | **11 of 27** |
| `entry = "docs/book.md"` | **25 of 27** |
| `entry = "book.typ"` | **2 of 27**, for a file that **does not exist** |

The two `book.typ` declarations are `components/distsys/books/{link,two_phase_commit}/`. The
extension's own `rules/books.md` item 3 mandates the flattened `book.typ` form beside `book.toml`
and calls `docs/book.md` legacy-and-held; the measured tree is the opposite. **Both facts are
true**; see `patterns/authoring-workflow.md`'s DOCUMENT stage and
`domain/known-gap-register.md` B9.

### Why every real book is `draft`, and it is not laziness

The certifier **refuses** `status = "certified"` with no `--prev` certificate to bump against,
with refusal reason `stale-certified`
(`books/certifier/Certify.lean:978-1003`, measured 2026-10-03). So **first certification is
necessarily `draft`**, and `certified` is reachable only on a subsequent run with the previous
certificate in hand. A manifest authored `certified` on day one does not certify.

### `"<absent>"` is a recorded value, not a missing key

An absent **optional** authored key is recorded in the certificate as the literal string
`"<absent>"` rather than omitted, "so the field list stays positional"
(`books/schema/book-cert-v2.md`, "The authored half"). Measured in
`interface/books/result/book.cert.json`: all six `trust.G*` keys and all three `provenance.*` keys
read `"<absent>"`. A consumer looking for a missing verdict looks for that string, not for a
missing key.

## `stale` is DERIVED, and never authored

`stale` is a certificate field, written **always `false`**, present "for a reader to record its
own verdict in". It is not a `book.toml` key, the provider has no extension that could carry one,
and nothing in the writer reads a staleness claim from the environment. Authoring it is not
possible; asserting it is the reader's act, not the author's.

## What is computed, and must never be authored

Reproduced from `books/schema/book-toml-v2.md:104-123`, which reproduces it from Decision 7 so
that a reader can see *why* each table is absent:

| Not authored in `book.toml` | Where it lives instead |
|---|---|
| `[book].packages` | derived from the book module's package |
| `[book].summary` | **the book module's docstring** |
| `[layers]` (and `.defs`/`.proofs` sub-lists) | `book_layer` lines per module; membership from the book module's imports |
| `[[layers.<layer>.narrow]]` | `book_policy` lines in the book module |
| `[exports]` | `@[book_export]` attributes; kinds derived from `getOriginalConstKind?` |
| `[[depends]]` (`book`, `layers`, `from`, `version`) | computed by the certifier into `book.cert.json`'s `depends`; composition hypotheses as `book_requires` |
| `[external]` | computed from the import closure per layer |
| `[axioms].permitted`, `[[axioms.flagged]]` | `book_axioms [...]` in the book module; per-export axiom sets computed |
| `[assumptions]`, `[not_claimed]` | `book_assume`, `book_not_claimed` in the book module |

**The summary is the book module's docstring.** That is worth stating twice, because it is the one
item on this list that reads like prose someone would naturally put in a manifest. It is not a
manifest field; it is a Lean module docstring, and the certifier is what connects them.

`rules/books.md` item 6 states the prohibition as a non-negotiable: never author a field in
`book.toml` that the certifier computes from the module graph.

## What the validator checks

`books-tool validate <manifest> --lib <dir>` (`books/tool/Books/Manifest.lean`):

1. **Shape and types.** Every key decodes at its declared type. A missing required key, a wrong
   type, or an unknown vocabulary word is an error **naming the key with a source position**.
   Errors **accumulate** -- one run reports every offending key, not the first -- and are printed
   sorted.
2. **Vocabularies** (`:150-170`), against the three word lists above.
3. **Name-equals-book**: `book.name` must equal the `book` command's argument.
4. **Module-resolves** (`:200-221`): `book.module` must name a real module.

**This is a stronger check than counting files.** `books-tool validate` decodes and checks all
seventeen keys; a file-count or a `grep` over the manifest establishes neither types nor
vocabularies. Use it, and treat a passing `grep` as no evidence.

Decision 7's own `Validated by` marker records one validator obligation as **not exercised**: the
"`[provenance]` present iff extracted" check "exists nowhere under `books/lean/BookCert/` or in
`books/certifier/Certify.lean`". So a non-bridged book that authors `[provenance]`, or a bridged
book that omits it, is not currently caught. See `domain/known-gap-register.md`, Part A.

## Related

- `domain/certificate-ledger-and-records.md` -- the computed half, key by key.
- `domain/status-and-trust-vocabularies.md` -- what each status word and verdict licenses.
- `standards/metadata-split.md` -- the three places metadata may live, and the commands.
- `patterns/authoring-workflow.md` -- where `book.toml` sits in the end-to-end sequence.
