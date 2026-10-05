# Status and Trust Vocabularies: What Each Word Licenses and Forbids

Two vocabularies, three words and four words, both authored in `book.toml` and **never written by
Lean code**. Each word licenses something specific and forbids something specific, and the gaps
between them are where a consumer over-reads a certificate.

**Design record**: Decision 12 (`docs/book-convention/12-status-vocabulary-and-trust-block.md`).
**Enforced word lists**: `books/tool/Books/Manifest.lean:33-38`. Gap claims defer to
`domain/known-gap-register.md`.

## Why judgments are never written by Lean code

Decision 12's first addition, and the reason both vocabularies live in TOML rather than in a
`book_status` or `book_trust` command: **a verdict written by a Lean command into a `.olean` would
be forgeable by the same route as a forged export row and -- worse -- would read as "checked by
Lean" to a consumer inspecting the artifact.**

So verdicts, status, version, provenance, licence and maintainers are authored in `book.toml` and
nowhere else; the certifier copies them into `book.cert.json` marked `source: authored`, "so a
reader of the certificate can tell a judgment from a re-verified fact". Decision 12 explicitly
rejected a `status` or `[trust]` command in the book module as "forgeable and misleading".

**No such command exists or is planned.** The provider has no extension that could carry one, and
that absence is deliberate (`books/schema/book-cert-v2.md`, "The authored half").

## The three authored `status` words

`#["draft", "certified", "deprecated"]` (`Manifest.lean:33`).

| Word | Licenses | Forbids |
|---|---|---|
| `draft` | saying the manifest exists and the book is **not yet certified**. A draft book's certification run **only reports** -- it does not assert a verified state | claiming any pass ran and passed. A reader may not treat a draft book's certificate as evidence of certification |
| `certified` | claiming that **the passes the certificate names** ran and passed -- at present, `reverify` -- plus whichever recheck legs `docs/trust-model.md` requires for the package | claiming immunity to the pinned toolchain's known kernel bugs (below). Also: a `certified` status whose recorded `identity` **fails to recompute** is a **certifier failure, not a display nuance** -- the book is refused and no certificate is written |
| `deprecated` | recording that the book is **superseded but still certifiable** | implying the book no longer certifies. Deprecation is an authoring judgment about relevance, not a verdict about soundness |

**First certification is necessarily `draft`.** The certifier refuses `certified` with no `--prev`
certificate to bump against, with refusal reason `stale-certified`
(`books/certifier/Certify.lean:978-1003`, measured 2026-10-03). Measured the same day: **all 27
real manifests declare `status = "draft"`**.

### What `certified` does NOT attest, stated in the record

Decision 12's second addition, carried here because a consumer reading only the word would miss
it. `certified` does **not** attest immunity to the pinned toolchain's known kernel bugs. The
pinned kernel (v4.31.0) is affected by:

- **CVE-2026-72711** -- an opaque declaration with an unbound free variable proves `False`;
  `leanchecker --fresh` **accepts the exploit**, because it replays with the same kernel;
- **CVE-2026-72844** -- an adversarial metaprogram adds declarations that ordinary code then uses
  to prove `False`.

Both are fixed in Lean 4.32.2. Whether the repository's `lean4lean` recheck leg rejects either
exploit is **UNVERIFIED**.

**The owner's ruling** (recorded in Decision 12): `certified` means checked by the pinned kernel
and the recheck legs as they stand; **no independent-kernel precondition is added**; the exposure
is stated in the record and in the certificate's toolchain field, and it clears when the Aeneas
pin (`docs/architecture-decisions.md` decision 4) moves the toolchain past 4.32.2 -- a bump the
owner takes with that pin, not separately. Decision 16's OQ5 records the residual and the
extension point (the reserved `leanchecker` pass name).

The rejected alternative is worth knowing: **silence about the CVEs until the bump was rejected**,
on the record's own honesty rule.

## The derived fourth word: `stale`

The **effective, displayed** status is a four-word vocabulary -- `draft`, `certified`, `stale`,
`deprecated` -- that is **derived, never authored**. `stale` is what a `certified` book becomes
when its recorded `identity` does not match a fresh recomputation. **No `book.toml` ever says
it**, and Decision 12 explicitly rejected storing `stale` as a fourth authored status: "staleness
is a relation between a certificate and the tree, not an author's decision."

**Measured contradiction, recorded in Decision 12's own marker.** The decision describes the
derived display status as "computed once by the certifier and consumed by the doc-drift and
diagram tooling". That is **contradicted**: **no `status` field is written** to the certificate,
and the only renderer reads `certificate.status.derived`, which exists **only in the test probe**.
See `domain/known-gap-register.md` Part A and B9, and `tools/typst-template-contract.md`.

What *is* written is the `stale` boolean, always `false`, present for a reader to record its own
verdict in -- see `domain/certificate-ledger-and-records.md`. Staleness is therefore a **reader's
verdict about an existing certificate**, reached by recomputing `identity` from the recorded
inputs, not a field to read off the file.

## The four trust verdicts

`#["verified", "validated", "trusted", "not_applicable"]` (`Manifest.lean:35`). Each applies to
one ground class, never to a book.

| Verdict | Licenses | Forbids |
|---|---|---|
| `verified` | the strongest claim available for that ground class | **being applied to a whole book, except via `G5_binding`.** Decision 12 states this restriction outright |
| `validated` | a checked-but-not-machine-verified claim for that class | being read as `verified` |
| `trusted` | an accepted assumption, recorded as such | being read as checked. `trusted` is the word for "we depend on this and did not verify it" |
| `not_applicable` | recording that the class does not apply to this book | being read as absence of a judgment. It **is** a judgment, and it is the correct one for a pure-Lean book's G1-G3 |

Two composition rules:

- **A pure-Lean book (no `[provenance]`) sets G1-G3 to `not_applicable`.**
- **A composite is never more trusted, on any ground class, than its least-trusted part.**

Defaulting: an **omitted** `[trust]` key defaults to `not_applicable`, and an **absent `[trust]`
table** means all six ground classes are `not_applicable` -- the documented honest record for a
draft book with no verdict yet. Measured 2026-10-03: **none of the 27 real manifests carries a
`[trust]` table**, so every real book's six verdicts are `not_applicable`, recorded in the
certificate as the literal `"<absent>"`.

## The six ground classes

`#[G0_checker, G1_translation, G2_ir_faithfulness, G3_models, G4_specification, G5_binding]`
(`Manifest.lean:37-38`). The classes themselves come from `docs/trust-model.md`;
**`book.toml` carries the verdict, never the argument for it**
(`books/schema/book-toml-v2.md`, "Vocabularies").

| Class | The question it answers |
|---|---|
| `G0_checker` | do you trust the proof checker that accepted this? |
| `G1_translation` | do you trust the translation from the source language into Lean? |
| `G2_ir_faithfulness` | does the intermediate representation faithfully represent the original? |
| `G3_models` | do the models the proofs are stated over represent the real artifact? |
| `G4_specification` | does the specification say the right thing? |
| `G5_binding` | does the verified artifact bind to the one actually shipped? |

G1-G3 are the bridged-code classes; a pure-Lean book sets them `not_applicable`. G4 is the one no
machine can settle -- `docs/trust-model.md` states it for the component case: "that the approved
statement says the right thing (that is a human judgment, recorded separately)".

## What has no checker, and what was enforced for the first time

Decision 12's marker is precise about which of its clauses are mechanical and which are not.

**No checker, recorded as not exercised**: the **pure-Lean G1-G3 rule** and the
**composite-trust rule**. Neither is enforced over any real book's authored `[trust]` table --
which on this tree is moot, since no real book authors one, but becomes live the moment one does.

**Enforced mechanically for the first time**: the
never-more-trusted-than-its-least-trusted-part clause, **through the permitted-axiom set rather
than through the `[trust]` table**. The measured instance: the framed_channel composite was
refused **eight times** with `[REFUSE] axiom-outside-book-axioms` until it declared the two
`bv_decide` native helper axioms its parts mint. Each refusal named both the axiom **and the
reaching declaration**, which is what made eight refusals converge rather than eight guesses --
see `patterns/warning-driven-convergence.md`.

That is the clause "doing real work, not ceremony": a composite cannot quietly inherit a part's
axiom without declaring it, because the axiom set is an input to every `digest`.

## The one blocking interaction with documentation

**A `certified` book whose record is not fully reconciled FAILS the docs stage and is not
certified.** A `draft` book only reports.

That is Decision 17's clause 4 blocking policy -- and `domain/known-gap-register.md` records it as
**unbuilt**: Decision 17's marker lists clause 4's blocking policy for `certified` books among the
clauses with no instance, and `books/tool/docs-stage.sh` reports `blocking_policy` by name under
`unknown` rather than guessing. Combined with the measured facts that **zero** real books carry a
`book.record.json` and **all 27** are `draft`, the interaction has never fired. It is a contract,
not an observed behaviour. See `standards/reconciliation-contract.md`.

## Related

- `domain/book-toml-v2.md` -- where these words are authored, and the defaulting rules.
- `domain/identity-and-versioning.md` -- how `stale` is computed, and the axiom rule.
- `domain/certificate-ledger-and-records.md` -- `judgments.fields`, `"<absent>"`, and the
  refusal set.
- `standards/reconciliation-contract.md` -- the docs stage this vocabulary gates.
