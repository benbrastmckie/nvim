# Books Domain Context

A **lean book** is a certified unit inside a Lake package, named by a `book <Name>` command in
its own book module. Its metadata splits three ways: **facts** are declared in Lean
(`@[book_export]`, `book_layer`), **judgments** are authored in `book.toml`, and **everything
else is computed** by the certifier into `book.cert.json`. That split, and the eighteen decisions
that follow from it, are the books convention.

**The normative design record is owned by the consuming repository, not by this extension.** It
was split: `docs/book-convention.md` is now a **slim index** (343 lines, measured 2026-10-05 at
git `a07ae5f`) over one file per decision under `docs/book-convention/NN-slug.md` (eighteen
accepted decisions) plus its paired exercise-history evidence under
`docs/book-convention-evidence/NN-slug.md`, with `books/schema/book-toml-v2.md` and
`books/schema/book-cert-v2.md` as its normative schemas, plus `docs/architecture-decisions.md`.
This corpus explains, grounds and dates that record for an agent working inside it; where the
two disagree, the record wins and this corpus is stale.

**Read `domain/known-gap-register.md` first.** Large parts of the design record describe
contracts with no live instance. The register is the dated projection of what is and is not
built, and every document below defers its gap claims to it rather than re-caveating.

Every document here is reachable **on demand only** -- by the path in the table below, or by
grep. None is auto-loaded into a dispatch. This README is the only entry point.

## Navigation

| Document | Subject | Read this when |
|---|---|---|
| `domain/known-gap-register.md` | Dated projection of the eighteen `Validated by` markers, twelve named gaps, and the live in-flight register | Always, first -- and before trusting any contract described anywhere else here |
| `domain/layer-vocabulary-and-matrix.md` | The twelve `book_layer` values, the may-import matrix row by row, restricted layers and the fail-closed execution-construct gate | Assigning a layer to a module, or diagnosing a matrix refusal |
| `domain/book-toml-v2.md` | `book.toml` v2: fifteen fields across seventeen keys, the vocabularies, and what is computed instead of authored | Authoring or reviewing a `book.toml` |
| `domain/certificate-ledger-and-records.md` | `book.cert.json`'s twenty top-level keys and sixteen-key ledger rows; and the two different side records | Reading a certificate, or deciding which record an artifact is |
| `domain/identity-and-versioning.md` | Per-export Merkle digests, the three identities, chaining, and the version bump table | Deciding whether a change needs a version bump, or reading an identity diff |
| `domain/status-and-trust-vocabularies.md` | The three `status` words and four trust verdicts, what each licenses and forbids, and the six ground classes | Setting `status` or a `[trust]` verdict, or reading one |
| `domain/gate-tiers.md` | Each verification tier: what it checks, what it does NOT check, and the cheapest catcher per error class | Choosing which check to run, or explaining a green build that the gate then refused |
| `patterns/authoring-workflow.md` | The AUTHOR -> BUILD/TEST -> CERTIFY -> DOCUMENT checklist, end to end | Bringing a new book or a new component into the book graph |
| `patterns/warning-driven-convergence.md` | Driving `book_requires` off the compiler's own warning stream instead of off a human reading the source | Facing a wall of `book-requires-undeclared` or `axiom-outside-book-axioms` output |
| `patterns/gate-collision-ledger.md` | Six measured collisions between the books convention and a component's pre-existing gate, with fixes | Before integrating books into a component that already has a gate |
| `standards/metadata-split.md` | Where each piece of metadata is allowed to live; the exact command syntax; the `book_policy` subject-placement rule | Writing a code module or a book module, or reviewing one |
| `standards/forgery-probe-discipline.md` | Every gate predicate gets a forgery probe; a predicate shipped without one is a reviewable defect | Adding or reviewing any gate predicate, in Lean or in shell |
| `standards/reconciliation-contract.md` | What a documentation reconciliation may read and write; agents write prose, people write records | Updating a book's prose after a certification changed a digest |
| `tools/tooling-inventory.md` | What each piece of the tooling directory reads and writes, and what to consume rather than reimplement | Looking for an existing tool, or about to write a new one |
| `tools/typst-template-contract.md` | The three-tier Typst template: tiers, modes, the certificate-only data input, label mechanics, pins | Authoring or compiling a book's Typst document |
| `tools/certify-guide.md` | Operating the certifier economically, and what its output does and does not warrant | Running `books/scripts/certify.sh`, or reading a run that looks green |
| `standards/observation-record.md` | The OBSERVATION record schema `books-observe.sh` writes: the seven dimensions, paired burdens, vacuous passes, omit-never-zero, and the digest-is-a-pointer rule | Reading or reasoning about `book.observation.json`, or writing anything that consumes it |
| `patterns/signal-tagging.md` | How working agents populate `tags.dimension`/`tags.polarity`/`tags.burden` on an `issues.jsonl` entry, with one worked example per dimension | Tagging a signal mid-dispatch so it survives into the observation record |
| `patterns/books-review-submode.md` | The complete and only specification for `/books --review`: per-dimension figures and trends, WHAT IS UNMEASURED, cost/issue-class/burden reporting, and the funnel to `--revise` | Running or modifying `/books --review` |
| `patterns/books-revise-submode.md` | The complete and only specification for `/books --revise`: the mandatory decision-record research step, the binding-clause research-and-escalate fork, backlog reconciliation, lead-session-only gates, and the watermark | Running or modifying `/books --revise` |

## Reading order, by what you are doing

Not every document is relevant to every dispatch. Three starting sets, each beginning with the
register:

- **Authoring a book, or tagging a component's modules.**
  `domain/known-gap-register.md`, then `standards/metadata-split.md`,
  `domain/layer-vocabulary-and-matrix.md`, `domain/book-toml-v2.md`, and
  `patterns/authoring-workflow.md` as the checklist to work through. Read
  `domain/gate-tiers.md` before declaring a tagging phase green -- a green `lake build` is not
  one.
- **Integrating books into a component that already has a gate.**
  `domain/known-gap-register.md`, then `patterns/gate-collision-ledger.md` and
  `domain/gate-tiers.md` before writing anything, then
  `patterns/warning-driven-convergence.md` when the warnings start.
  `patterns/gate-collision-ledger.md` exists so that the six collisions in it are read rather
  than rediscovered at ten minutes per gate run.
- **Certifying, or reading a certificate.**
  `domain/known-gap-register.md`, then `tools/certify-guide.md` for operation,
  `domain/certificate-ledger-and-records.md` for what comes out, and
  `domain/identity-and-versioning.md` plus `domain/status-and-trust-vocabularies.md` for what it
  means.

`tools/tooling-inventory.md` is the reference to consult whenever the question is "does something
already do this?"; `standards/forgery-probe-discipline.md` applies whenever a gate predicate is
added or changed. The two documentation contracts
(`tools/typst-template-contract.md`, `standards/reconciliation-contract.md`) describe a stage
that **no real book exercises today** -- read their opening measured-state notes before acting on
either.

## Conventions this corpus follows

- **Every figure carries a date and a measured marker.** A figure without one is a defect. The
  consuming repository is under active development, so a figure measured in one document may be
  stale in another; the date is what makes that detectable.
- **Paths are always full** (`books/scripts/certify.sh`), never a bare directory reference
  standing alone, so the pending `books/` -> `bookkit/` rename is a mechanical replacement.
- **Cross-references inside this corpus are plain backticked paths**, never eager `@`-imports.
- **Citations are durable anchors**: a file path, a `file:line`, a decision number, a script name,
  or a consuming-repository artifact path. Never an ephemeral task reference.
- **Where the design record describes something unbuilt, the document says so in the same
  breath**, and points at `domain/known-gap-register.md` for the detail.
