# The Reconciliation Contract

## Measured state, 2026-10-03 -- read this before the contract

**The contract is settled in specification and unbuilt.** Decision 17's own classification table
reads, for clause 9: **"the eight-clause reconciliation contract | none | well specified,
unbuilt"**. Measured against the Logos/Verification tree at git `7281c81`:

- **Zero real books carry a `book.record.json`.** The only two in the tree are fixtures
  (`books/tests/certify/fixtures/books/pt/`, `typst/tests/book-template/probe/`).
- **The approval writer `books/tool/approve-guarantees.sh` is ABSENT.** Its *interface* is settled
  (below); settling an interface is not a claim that it is exercised.
- **No real book has a Typst document**, so there is nothing for a reconciliation dispatch to
  write. See `tools/typst-template-contract.md`.
- **The docs stage exists in a split form**, with four of its halves reported by name as
  `unknown`.
- **Clause 4's blocking policy is unbuilt**, so the one hard interaction between this contract and
  certification has never fired.

The contract body below is stable; this section is what a refresh touches. Gap claims defer to
`domain/known-gap-register.md` B8.

---

## The trigger is CERTIFICATION, never a file save and never a commit

Stated in Decision 17 with the reason for each rejection:

> **The trigger is certification, never a file save or a commit**: a save is **too early** (the
> proof may not compile) and **too noisy** (one dispatch touches many files); a commit is the
> **wrong grain** (it does not know which exports changed). **Only the certifier knows which
> exports' digests moved**, so the docs stage runs wherever certification runs.

Two consequences follow directly from the digest machinery, reused rather than reinvented
(`domain/identity-and-versioning.md`):

- **A proof-only edit changes no digest and so touches no guarantee.**
- **An interface change always changes the digest, exactly once, and stales every guarantee that
  names it.**

That asymmetry is the whole economic argument for the contract: prose work is proportional to
interface change, not to commit volume.

**And it has a consequence for mechanism design, which the design record names as an open
choice**: the reconciliation gate has to be, explicitly, either a git hook or something else --
and today it is neither, because nothing runs the certifier automatically
(`domain/known-gap-register.md` B2).

## The eight clauses

A dispatch that reconciles a book's documentation must satisfy **all eight** or its result is
**refused**. Transcribed from Decision 17 clause 9:

1. **Inputs are the documenter pack and nothing else; no `.lean` source, ever.**
2. **Writes are allowed to `book.typ` of the named book and nowhere else.**
3. For a guarantee **stale by digest**, it may rewrite **only** the guarantee whose export's digest
   changed, **citing the new statement**; guarantees whose digests match are **untouched**.
4. For a **missing** guarantee, it writes one, **keyed to the export name**, in the tier-one
   register.
5. For an **orphaned** guarantee, it **removes it and says so in its summary**.
6. Before finishing, **every tier must compile**, and **the docs stage and the tier-one lint must
   be green** -- and **the dispatch's own postflight re-runs both and refuses the result
   otherwise**.
7. **`book.record.json`, `book.toml`, `approvals.yaml` and the book module are NEVER edited** by
   this dispatch.
8. Its summary **names every guarantee touched, with the OLD and NEW digest**, and marks the work
   **`by: agent`** -- the source of the process signals in clause 10.

The **documenter pack** that clause 1 limits inputs to is a defined object, not a phrase: the
consumer pack (`book.cert.json` plus the document rendered at `tier=overview` **and** at
`tier=full`), **plus the phrase table and `book.record.json`**. The reconciliation agent "is
dispatched with the documenter pack and **nothing else**". Notably it does **not** include the
book module or the code modules -- those are the *maintainer* pack, for a dispatch that changes a
statement or a proof.

## Agents write prose; PEOPLE write records

This is the contract's hardest boundary, and clause 7 is where it bites.

**A person closes the loop with `books/tool/approve-guarantees.sh`, the only writer of
`book.record.json`.** The command **prints the signing invocation and never runs it.** A
reconciliation dispatch that writes a record entry has violated clause 7, whatever the quality of
its prose.

### The settled interface of the writer that does not exist yet

Recorded because a dispatch must print the right invocation, and because the three residuals this
interface once held are closed:

```
bash books/tool/approve-guarantees.sh BOOK_DIR \
  --export NAME \
  --by (person:<name>|agent:<name>) \
  [--date YYYY-MM-DD]
```

- `--export` **repeats once per guarantee signed**. `--json` is the read-back path; `--help` prints
  the header contract. Exit codes follow the house contract: **0** written or read back, **1** a
  check failed, **2** usage error.
- The command line **mirrors `books/tool/record-read-test.sh`**, the sibling record's writer, "so a
  person who has run one can run the other".
- **The exact hashed input** is the **queried guarantee text** -- what `typst query` returns for
  that export's `guarantee` metadata -- hashed as `guarantee_sha256`. **Never a `repr()` of Typst
  content**, which is not stable across versions.
- **`statement_digest` is read verbatim** from the certifier's freshly regenerated
  `book.cert.json`, indexed by export name, field `digest`, **as the certifier's current `digest`
  resolved it**. **Neither value is typed by a person.**
- **An orphaned entry is refused, never signed.** Clause 9.5 makes removing an orphan the
  *reconciliation dispatch's* job; the writer's role is to sign what the certificate names, so an
  `--export` naming no export in the current `book.cert.json` **exits 1 with that export named**.
  The writer never creates, rewrites or silently drops a record entry whose export is absent.

Whether a declared agent may **ever** be the one who signs is **reserved, not decided** (clause
12). The record's `by` field makes either choice visible on the badge without a schema change.

### Why a reworded guarantee needs re-approval exactly as a changed statement does

Because the record binds **two** hashes per guarantee: `guarantee_sha256` over the **text**, and
`statement_digest` over the **export**. Rewriting the prose moves the first; changing the
statement moves the second. Either leaves the pair unreconciled, which is the same state. There is
no "cosmetic edit" path through the record.

## The two records, which are not the same artifact

| | `book.record.json` | `book.read.json` |
|---|---|---|
| **Role** | the **approval / reconciliation** record this contract governs | the **non-expert read test** record |
| **Shape** | `schema`, `guarantees[].{export, guarantee_sha256, statement_digest, by, date}` | six keys: `book`, `by`, `date`, `reader`, `marks{does_what, assumes_what, could_go_wrong}` |
| **Writer** | `books/tool/approve-guarantees.sh` -- **ABSENT** | `books/tool/record-read-test.sh` (163 lines) -- **landed, and the sole writer** |
| **Real instances** | **ZERO** | **five** |
| **Who writes it** | **a person** | the script; `by` records `reader` or `agent`, and **all five real records carry `"by": "agent"`** |

Both are **non-digested** -- confirmed by measurement, not only by construction: writing all five
read-test records left every one of the five certificates' `identity` unchanged, as
`BookCert.Identity.gather` (`books/lean/BookCert/Identity.lean:330-340`) predicts. See
`domain/certificate-ledger-and-records.md`.

**And the template must never read either one.** The probe's own `book.record.json` carries a
`_provisional` field saying so: every guarantee's reconciliation state is read from
`book.cert.json`'s `docs` field, which the docs stage computes from the record against the ledger.
The invariant that `book.cert.json` is the only input of every non-Lean tool holds for
reconciliation state exactly as for everything else.

## The docs stage, split in two -- and what each half reports

`books/tool/docs-stage.sh` (245 lines) is the **pack-measurement half only**. It emits the
docs-stage JSON report **on stdout and NEVER commits it** -- "the same posture as
`typst/scripts/chapter-drift.sh --json`". The certifier reads it through its own `--docs-report`
flag and combines it with **the three inputs only the certifier has**: the certificate's own
canonical bytes, the module-to-source-path map, and layer membership from `modules[].layer`.

That split is also why clause 6's purpose is unharmed: the measurement half is **a plain script a
person runs with no agent system installed**.

**Five halves the stage reports as `unknown` BY NAME rather than guessing**, so that the work
building them extends this script instead of creating a second one:

| Reported `unknown` | What it would compute |
|---|---|
| `reconciliation_diff` | the `book.record.json`-against-certificate diff that computes each export's `per_export` state (clause 2's four conditions) |
| `splice_hash` | the statement-splice hash over the `guarantee` metadata (clause 3) |
| `tier_one_lint` | the tier-one prohibition lint (clause 7) |
| `blocking_policy` | the `certified`-book refusal (clause 4) |
| `queue` | the reconciliation queue (clause 9) |

Reporting each by name is the honest posture this corpus's measured-marker convention exists for:
an `unknown` is distinguishable from a zero.

### The non-tiered document case, and why it is not a fabricated `ok`

Every real book today declares a **Markdown** entry, which has no tier blocks and no renderer. The
stage handles it explicitly:

> A **non-tiered** document is **stat'd ONCE** and the one size is reported under **BOTH** tier
> keys, with **`non_tiered` true** and **`tier_compile` `unknown`** rather than a fabricated `ok`.

And `typst/lib/phrases.toml` -- a documenter-pack component the Typst template loads -- is
reported **not applicable** for a non-tiered document, "never as absent-and-zero, so the two cases
stay distinguishable".

### ABSENT DOCUMENTATION IS NOT A FINDING

Clause 4's own semantics, and the one rule most likely to be got wrong by a well-meaning check:

> An **absent document** -- a `[docs] entry` naming a file that does not exist, or no
> `[docs] entry` at all -- reports both sizes 0, the declared path named under `absent`,
> `tier_compile` and `names_resolved` `unknown`, and **NO WARNING. ABSENT DOCUMENTATION IS NOT A
> FINDING** (clause 4), because per-book Typst content is **held** until certificates exist, so a
> warning here would fire indefinitely for every held book and **make a zero-warning gate
> unreachable by construction.**

A declared-but-absent pack component likewise **contributes 0 and is named under `absent`, never
refused**.

## The one blocking interaction, and the fact that it has never fired

> A book whose `book.toml` sets **`status = "certified"`** must have **every export covered by a
> record entry that is neither stale nor missing**, or the docs stage **fails and the certifier
> refuses to certify the book**. A **`draft`** book only reports.

That is clause 4. It is **unbuilt** (`blocking_policy` is reported `unknown`), and it could not
have fired anyway: measured 2026-10-03, **all 27 real manifests declare `status = "draft"`** and
**zero** carry a record. It is a contract, not an observed behaviour. See
`domain/status-and-trust-vocabularies.md`.

## Running a reconciliation, as the contract would have it

1. **Certify.** Only the certifier knows which digests moved
   (`tools/certify-guide.md`).
2. **Read the stage's report** for the per-export reconciliation state. Today that means reading
   `book.cert.json`'s `docs.per_export` -- and knowing it is `[]` on every real certificate,
   because `reconciliation_diff` is unbuilt.
3. **Take the documenter pack and nothing else.** No `.lean` source. Ever.
4. **Write only `book.typ` of the named book.** Only the guarantees whose digests changed; add one
   per missing export keyed to the export name; remove each orphan and say so.
5. **Compile every tier**, standalone and embedded, through `bash typst/scripts/build.sh`; run the
   docs stage and the tier-one lint; **re-run both in postflight** and refuse the result if either
   is not green.
6. **Write the summary**: every guarantee touched, with **old and new digest**, marked
   `by: agent`.
7. **Print the signing invocation. Do not run it.** Editing `book.record.json`, `book.toml`,
   `approvals.yaml` or the book module is a clause-7 violation.

## Related

- `tools/typst-template-contract.md` -- what a `book.typ` is and how its tiers compile.
- `domain/certificate-ledger-and-records.md` -- the `docs` block, and the two records compared.
- `domain/status-and-trust-vocabularies.md` -- the `certified`/`draft` distinction clause 4 keys
  on.
- `tools/tooling-inventory.md` -- `books/tool/docs-stage.sh` and what is absent beside it.
- `domain/known-gap-register.md` -- B8, B9.
