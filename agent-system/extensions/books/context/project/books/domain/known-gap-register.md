# The Known-Gap Register

**Measured as of 2026-10-05**, against the Logos/Verification working tree at git `a07ae5f`. The
staleness handle is now the pinned `convention_version` (`manifest.json`; see
`README.md`'s "Convention version pin and staleness comparison" section) rather than this prose
SHA alone -- the SHA is retained here for the mechanical re-verification trail, not as the sole
freshness signal.

This file is a **dated projection**, not an authority. The authority for what each design
decision has and has not validated is the `- **Validated by**:` marker at the head of each
decision in `books/book-convention.md`, mechanically linted by
`books/scripts/lint-validated-by.sh`. The authority for what is in flight is that repository's
own `specs/state.json`. When this file and either authority disagree, the authority wins and this
file is stale.

Read this file **first**. Every other document here states its subject's gaps by pointing here
rather than carrying its own caveats, so a contract described elsewhere may have no live
instance, and this register is where that is recorded.

## The marker vocabulary, adopted not invented

`books/book-convention.md` carries one marker per decision in a three-form vocabulary, and this
register uses the same three forms rather than a parallel scheme:

| Form | Meaning |
|---|---|
| `none yet [-- reason]` | no instance at all; the reason is recorded when there is one |
| `partially, <instances>` | some clauses have instances; the marker names which are exercised, which are not, and which are **contradicted** |
| anything else (an instance named outright) | **binding** -- work that cannot satisfy it stops and escalates |

`books/scripts/lint-validated-by.sh` (802 lines) enforces this with four checks: CHECK 1 (marker
presence and well-formedness) and CHECK 2 (instance liveness -- every backtick path, Lean name and
bare filename in a marker line must still resolve) are **blocking**; CHECK 3 and CHECK 4 are
advisory heuristics. `books/tests/validated-by-lint/run.sh` (272 lines) pins all four.
**Marker census, measured 2026-10-03**: eighteen decisions, eighteen markers -- **two binding**
(Decision 5, Decision 14), **fifteen `partially`**, **one `none yet`** (Decision 18).

## Part A: the eighteen decisions, projected

Each row names what its own marker records. `--` means the marker names nothing in that column.

| Decision | Form | Not exercised | Contradicted |
|---|---|---|---|
| 1 Book identity and membership | partially | nothing | the Challenge-library clause, amended 2026-10-02 by owner ruling: a Challenge library carries `book_layer challenge` but is **not** a book module's direct import |
| 2 Layer vocabulary | partially | `instances.defs` and `instances.proofs` (declared, unused on the real tree) | -- |
| 3 Layer-import matrix | partially | the `laws`, `challenge` and `evidence` **rows**; the confinement rule; the `*` bridge-only cells -- no checker implements the last two | -- |
| 4 Policy assertions | partially | nothing | -- (but see the subject-placement rule below, which Decision 4's own worked example gets wrong) |
| 5 Shared support modules and the `ladder` book | **binding** | -- | -- |
| 6 Where metadata lives | partially | -- | -- |
| 7 `book.toml` v2 schema | partially | the "`[provenance]` present iff extracted" certifier check, which exists nowhere under `books/lean/BookCert/` or in `books/certifier/Certify.lean` | -- |
| 8 Computed dependencies and `book.cert.json` | partially | -- | "each package's resolved leanOptions" |
| 9 Trust unit is the export | partially | -- | the `identity` formula omits the direct dependencies' `interface_identity` input |
| 10 The certifier | partially | **any gate or CI job** -- nothing runs `books/scripts/certify.sh` automatically | the refusal set has a seventh entry, `missing-source`; amended 2026-10-03 with an eighth |
| 11 Versioning rule | partially | -- | the former claim that `S` is what `spec_digest` hashes (`spec_digest` folds `Expr`'s structural hash, not a serialisation) |
| 12 Status vocabulary and trust block | partially | the pure-Lean G1-G3 rule and the composite-trust rule -- **no checker enforces either** | the "derived display status computed once by the certifier": no `status` field is written |
| 13 Exposure policy | partially | the misplaced-`public section` fixture; `#book_requires?` (unbuilt) | -- |
| 14 Pilot go/no-go criteria | **binding** | -- | -- |
| 15 What ACL2 delivers that this design does not | partially | the ACL2 and Lean-core claims are external and unchecked here | gap 8's "the certificate binds the provider's source hash" |
| 16 Named open questions | partially | **every reserved pass** (`passes = ["reverify"]`) | -- (marker records one **stale** count) |
| 17 Documentation reconciliation and book-health signals | partially | clauses 4, 5, 6, 9, 11, 12 have no instance; clause 7's tier-one prohibition lint, clause 3's statement-splice hash and clause 10's twelve computed signals are unbuilt | -- |
| 18 Composition and consumption ergonomics | **none yet** | none of the seven mechanisms is built: zero `WithInfo` sites, no `#book_requires?`, `book_example`, `book_instantiate_as`, `book_instantiate`, discovery index or export facade | -- |

The pilot's GO was **ratified by the repository owner on 2026-10-03** with four attached
conditions, recorded in `docs/book-pilot-record.md` (808 lines). The first condition is the
tier-split ruling named in Part C below.

## Part B: named gaps, with what is measured

Each row is a gap this corpus's other documents point at. The right-hand column is what was
measured on 2026-10-03, not what a design artifact asserts.

### B1. There is no verification tier between `lake build` and the full gate

`lake build` invokes neither `interface/scripts/layer-lint.sh`, nor `books/scripts/certify.sh`,
nor the Comparator rooms. The next tier up is a fail-closed full gate at roughly ten minutes per
run. **Measured consequence: 44 `Books.Meta` layer violations sat undetected across five tagging
phases that all reported green on `lake build`.** See `domain/gate-tiers.md`. Closing this gap is
a named, NOT STARTED entry in the consuming repository's register
(`specs/178_optimize_books_gate_feedback_loop/`).

### B2. The certifier is not referenced anywhere in `full-gate.sh`

Measured 2026-10-03: `grep -n certif full-gate.sh` returns **two lines, both comments** (`:19`,
`:186`), neither invoking the certifier. So Decision 17 clause 5 has no instance, and the chain a
reader might expect -- `lake build` -> layer lint -> certifier -> full gate -> `--recheck` -- is
**two disjoint chains**, not one. Nothing mechanical catches a book whose certificate has stopped
matching its sources.

### B3. `lake shake` refuses non-`module` packages on the pin, so the shake stage is advisory

`books/scripts/certify.sh:625-651` runs `lake shake` with explicit module targets and reports
`SKIPPED` when the output contains `only works with` -- the pinned toolchain's refusal text
(`error: lake shake only works with modules currently`). The stage **never propagates its rc**.
This is advisory **by necessity, not preference**: measured on a two-book fixture, shake also
advises removing a book module's own imports, which are load-bearing membership metadata rather
than symbol use (`certify.sh:127-137`).

### B4. The regex layer lint can pass vacuously, and does not say so

`interface/scripts/layer-lint.sh` (72 lines) sources `interface/scripts/layer-rules.sh`
(nine rules: seven `LAYER_RULES` exclusions and two `LAYER_ALLOW_RULES` allow-only rules) and
applies them to every `.lean` file under each named package root. Its success line prints
`($N modules, $M imports, 7 exclusion rules, 2 allow-only rules; ...)` -- counts from which
vacuity is **inferable** but never labelled.

**Reporting a vacuous pass as vacuous is a requirement this corpus states, not a behaviour the
lint implements.** The lint does carry one narrower guard: a file with `import` lines from whose
header none were parsed is a `[FAIL]` (`layer-lint.sh:50-55`). And `books/README.md`'s
"Axis 2 -- per module" section does name the vacuous-pass domain explicitly. But the lint itself
reports `[ok]` either way.

### B5. The matrix check's coverage of the real tree, as reported in `books/README.md`, is stale

`books/README.md`'s "Agreement with the regex layer lint" section states that of 36 built module
headers, **0** carry a `book_layer`, so the matrix check's domain is empty and the two checks
cannot disagree. **That report is stale.** Measured 2026-10-03 over the working tree, excluding
`.lake/`:

| Measurement | Value |
|---|---|
| `.lean` files | 263 |
| anchored `^book_layer ` lines (one per module) | **175** |
| of those, in the four real book-bearing packages | **139** |
| `@[book_export]` occurrences | **1,003** |
| anchored `^book_requires ` lines | **356** |
| fresh `layer-lint.sh` run over all four packages | `[ok] ... (179 modules, 733 imports, 7 exclusion rules, 2 allow-only rules)`, rc=0 |

Layer-value distribution, same measurement: `refinement` 46, `impl` 36, `interface` 24,
`challenge` 23, `laws` 20, `instances` 14, `evidence` 7, `extraction` 3, `impl.proofs` 1,
`impl.defs` 1. **Ten of the twelve values are live; `instances.defs` and `instances.proofs` are
declared and unused.**

The agreement report's own *dispositions* (four reproduced, four reproduced-by-declaration, one
deliberately not reproduced) remain correct; only its measured half is out of date. Its closing
section already says so of itself: "it is **not** a demonstration that the matrix reproduces the
regex rules on real imports".

### B6. The execution-construct gate's domain is not enumerable by any script

The gate governs "every module whose import closure contains `Books.Meta`". No script, manifest
or document lists that set. It was found by the gate refusing a generated
`lean/.hashgen/Gen.lean` -- written, `#eval`'d and deleted inside one shell function -- on gate
run 2 of 4. The dispatch that hit it called an import-closure lister "the single most useful
missing tool". See `patterns/authoring-workflow.md` for the checklist caution.

### B7. `book_policy` subject placement is documented nowhere, and Decision 4's example is wrong

A `book_policy` row belongs on the book that **owns its subject**. A subject that is not a member
of the certifying book resolves to nothing and certifies as `"outcome": "holds"` with
`"checked_modules": []` -- reported as a pass. Three independent sources specified it the same
wrong way: a task description, its plan, and **Decision 4's own worked example**. The elaborator
deliberately does not resolve the subject, which the `POLICY-ADMIT` fixture case in
`books/tests/manifest/run.sh:447-458` records as a **boundary, not a defence**.
See `standards/metadata-split.md` (the rule) and `standards/forgery-probe-discipline.md` (the
grounding instance).

### B8. Zero real books carry a `book.record.json`, and no writer script exists

Measured 2026-10-03: **two** `book.record.json` files in the whole tree, both fixtures
(`books/tests/certify/fixtures/books/pt/`, `typst/tests/book-template/probe/`). **Zero real
books.** The approval writer named in Decision 17 clause 9 -- `books/tool/approve-guarantees.sh`
-- is **absent**. So is `books/tool/book-health.sh`.

The landed record is a **different** one: `book.read.json`, the read test, six keys
(`book`, `by`, `date`, `reader`, `marks{does_what,assumes_what,could_go_wrong}`), sole writer
`books/tool/record-read-test.sh` (163 lines), **five** real instances, and all five record
`"by": "agent"` -- a pre-check, not a reader run. The two records are not the same artifact; see
`domain/certificate-ledger-and-records.md`.

### B9. No real book has a Typst document, and the template cannot render a real certificate

Measured 2026-10-03: **two** `book.typ` files in the tree -- the library itself
(`typst/lib/book.typ`, now **462 lines**) and the test probe. **Zero real books.** Of the 27 real
manifests, **25** declare `[docs] entry = "docs/book.md"` and **two**
(`components/distsys/books/{link,two_phase_commit}/`) declare `entry = "book.typ"` for a file that
does not exist.

Worse, the library reads top-level certificate names the writer does not emit:
`certificate.version` (`book.typ:138`), `certificate.status.derived`/`.authored` (`:101`, `:141`,
`:142`), `certificate.trust` (`:268`) and `certificate.exports` (`:343`, `:401`, `:409`, `:446`).
A real certificate's top level carries none of those four -- it carries
`judgments.fields["book.version"]`, `judgments.fields["book.status"]`,
`judgments.fields["trust.G*"]` and `export_ledger`. **So a real certificate cannot currently
render.** Reconciling this is a live, `researched` entry in the consuming repository's register
(`specs/186_reconcile_book_typ_certificate_reads/`). See `tools/typst-template-contract.md`.

### B10. The four reserved certifier passes are named and unbuilt

A real certificate records `passes: ["reverify"]` and
`reserved_passes: ["meta_import_ledger", "leanchecker", "exported_view_replay", "trust_scope"]`.
`reverify` is the only implemented pass. The four reserved names are the deferred certifier
passes, fixed in shape and not run.

### B11. The pending `books/` -> `bookkit/` rename threatens every path citation in this corpus

`specs/170_rename_root_books_tooling_dir_to_bookkit/` is NOT STARTED in the consuming
repository's register. Every path in this corpus is written **full**
(`books/scripts/certify.sh`, never a bare directory reference standing alone) precisely so that
the rename is a mechanical find-and-replace rather than a re-reading. When the rename lands, this
corpus's citations are the change, and this row is the marker for it.

### B12. The certifier's closing line, and a killed run, both misreport

`books/scripts/certify.sh:706` prints
`[ok] %d book(s) certified, dependencies first: %s` over `${#order[@]}` and `${order[*]}` -- the
**discovered** order, regardless of how many certified. The line therefore warrants that the
driver completed, and nothing more; cross-check `book.cert.json` files on disk.

Separately, `certify.sh` carries no timing or memory instrumentation, so a run killed by
`earlyoom` (measured: `FramedChannelAeneas.Book.Crc8` at ~16-18 GiB RSS, twice) logs a bare
`!! book 'X' was REFUSED` with no `[REFUSE]` detail lines -- visually indistinguishable from a
genuine refusal. Instrumenting it is a NOT STARTED entry
(`specs/175_instrument_certifier_and_classify_outcomes/`). See `tools/certify-guide.md`.

### B13. Two commonly-repeated "not yet landed" claims are themselves stale

Both are recorded here because a reader who inherits them will under-trust what is built.

- **"Certifier phases 13-23 of 23 are not landed -- the certificate writer,
  `books/schema/book-cert-v2.md`, the shell driver and the acceptance suite."** All four exist,
  measured 2026-10-03: `books/schema/book-cert-v2.md` (689 lines),
  `books/lean/BookCert/Writer.lean`, `books/scripts/certify.sh` (711 lines) and
  `books/tests/certify/run.sh` (1,338 lines). What is genuinely deferred is narrower: the four
  `reserved_passes` of B10, and the clauses named in Decision 17's marker.
- **"The provider-side trust defences are in flight."** They are landed, and
  `books/lean/Books/Meta.lean:50-88` enumerates five mechanisms with the refuses-versus-reports
  distinction stated per mechanism. See `domain/layer-vocabulary-and-matrix.md`.

Three further stale figures are corrected in the document that owns each subject rather than
here: `Books.Meta`'s line count and the tooling directory's shape in
`tools/tooling-inventory.md`; the reference implementation's scale in
`patterns/authoring-workflow.md`; and `typst/lib/book.typ`'s line count and reads in
`tools/typst-template-contract.md`.

## Part C: the live in-flight register

Projected from the consuming repository's `specs/state.json` on **2026-10-03**. Thirty
books-related entries of forty-eight active. Listed below are those that define or block a
contract this corpus describes; six further `hold`/`researching` documentation and survey entries
(`124`, `143`, `145`, `152`, `174`, `181`, `182`, `184` by directory prefix) carry no contract of
their own and are omitted.

| Entry directory | Status | What it tells this register |
|---|---|---|
| `specs/178_optimize_books_gate_feedback_loop/` | not started | the cheap pre-gate verification tier does not exist (B1) |
| `specs/189_wire_certifier_into_full_gate/` | not started | the certifier is not in the full gate (B2) |
| `specs/188_build_book_health_computed_signals/` | not started | `book-health.sh` absent; the twelve signals have no producer (B8) |
| `specs/186_reconcile_book_typ_certificate_reads/` | **researched** | the Typst library cannot render a real certificate (B9) |
| `specs/175_instrument_certifier_and_classify_outcomes/` | not started | no timing/memory instrumentation; a killed run reads as a refusal (B12) |
| `specs/170_rename_root_books_tooling_dir_to_bookkit/` | not started | the `books/` -> `bookkit/` rename (B11) |
| `specs/180_rule_on_tier_split_for_book_bearing_packages/` | not started | the Mathlib-free-tier promise is unmeasured for the framed_channel family; the pilot GO's first condition |
| `specs/168_complete_the_distsys_book_gate/` | planning | three older distsys books still carry warnings |
| `specs/157_add_deferred_book_certifier_passes/` | not started | the four `reserved_passes` (B10) |
| `specs/164_add_reconcile_command_to_agent_system/` | not started | the `/reconcile` command is planned agent-system-side; it would consume `standards/reconciliation-contract.md` |
| `specs/144_document_books_in_three_tiers/` | hold | held until the books it documents carry certificates |
| `specs/173_convert_distsys_book_md_to_certificate_backed_book_typ/` | hold | held until the certifier's docs stage exists |
| `specs/176_measure_framed_channel_book_family_cost/` | not started | the family's cost is not yet measured a second time (see the measured-once caveat) |
| `specs/179_refuse_vacuous_book_policy/` | **completed** | the vacuous-policy refusal and its forgery probe landed (B7's fix) |
| `specs/177_research_build_and_certification_efficiency/` | **completed** | the `dag-v2` sharing-aware serialiser; see `domain/identity-and-versioning.md` |
| `specs/169_define_the_health_record_and_docs_stage/` | **completed** | `books/tool/docs-stage.sh` and `book.read.json` |
| `specs/121_bring_framed_channel_into_book_graph/` | **completed** | the thirteen-book family; the evidence base for documents 12-16 of this corpus |
| `specs/120_pilot_books_on_interface_and_rle_codec/` | **completed** | the pilot and its ratified GO |

## The measured-once caveat, carried forward

Every quantitative claim in `domain/gate-tiers.md` and `patterns/gate-collision-ledger.md` comes
from **one implement dispatch on one component family**
(`specs/121_bring_framed_channel_into_book_graph/`), recorded in
`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md`, whose own
Executive Summary states: "**This report is a seed, not a diagnosis.** Every quantitative claim
below is from a single dispatch on a single component family. The diagnostics phase must
establish whether these costs reproduce before any optimization is designed." That diagnostics
phase has **not run**. Read those two documents as **measured once**, not as measured.

## How to refresh this file

Re-read the eighteen `- **Validated by**:` markers and rebuild Part A (project them, do not
re-judge them); re-run the censuses in B5; re-project Part C from `specs/state.json`; then update
the `Measured as of` date at the top. A figure without a date in this corpus is a defect.
