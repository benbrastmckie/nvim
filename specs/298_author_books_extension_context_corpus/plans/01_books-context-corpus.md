# Implementation Plan: Author the books extension domain context corpus

- **Task**: 298 - author_books_extension_context_corpus
- **Status**: [IMPLEMENTING]
- **Effort**: 12 hours
- **Dependencies**: 297 (scaffold_books_extension_routing_and_agents) - `completed`
- **Research Inputs**: `specs/298_author_books_extension_context_corpus/reports/01_books-extension-context-corpus.md`
- **Artifacts**: plans/01_books-context-corpus.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author sixteen domain context documents plus a rewritten navigation `README.md` under
`agent-system/extensions/books/context/project/books/`, and register all seventeen in
`agent-system/extensions/books/index-entries.json`. The extension's wiring (manifest, four
agents, six skills, two commands, `rules/books.md`, `scripts/`) is already landed and is not
touched; every one of its consumers points at `context/project/books/README.md` and "any further
corpus files it points to", so the README's navigation table is the sole discovery mechanism and
the document filenames are free to be the ones this plan fixes. Definition of done: seventeen
files on disk, seventeen index entries with the tiering of D3, every mechanical gate green, and
every quantitative claim in the corpus dated and marked measured rather than inherited.

### Research Integration

The research report is the plan's specification. Four of its findings drive the phase structure:

- **Finding 1** settles the structural contract: four role directories (`domain/`, `patterns/`,
  `standards/`, `tools/`); `provides.context: ["project/books"]` already names the *directory*, so
  no `manifest.json` edit is needed; the derived-tier table at
  `agent-system/extensions/core/scripts/validate-context-budgets.sh:89-97`; a target of
  150-250 lines per document and a longer-than-precedent README (16-row navigation table).
- **Finding 3** is the eleven-entry staleness ledger. The dispatch description's own measured
  claims are systematically stale, and its headline known-gap bullet ("0 of 36 module headers
  carry a `book_layer`") is refuted by measurement (188 `book_layer` lines over 155 files; 27 real
  books; 26 certificates). The corpus is written against the ledger's right-hand column, never
  against the description's left-hand column.
- **Finding 4** supplies the register's structure: a dated projection of the eighteen
  `- **Validated by**:` markers in `docs/book-convention.md`, in that marker vocabulary
  (`none yet [-- reason]` / `partially, <instances>` / binding), plus the consuming repository's
  live in-flight register, with the markers named as the authority and the register as a
  projection.
- **Finding 5** is a per-document source map with primary sources, `file:line` anchors and
  content budgets for all sixteen documents. Each phase below cites its Finding 5 items rather
  than restating them; **the implementer reads Finding 5's entry for a document before writing
  it.**

One research precondition is **resolved in planning and needs no implementation step**:
`check-extension-docs.sh` Rule E (`check_referenced_scripts_declared`) selects its inputs from
exactly `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md` and `EXTENSION.md` (the
`for f in ...` loop inside that function). **It does not reach `context/`.** The corpus may
therefore name `certify.sh`, `layer-lint.sh`, `check-spdx.sh`, `docs-stage.sh` and the rest by
bare filename. D8 still applies for a different reason (rename survivability), so path-prefixed
citations remain the house style.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation was
performed and no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Sixteen domain documents under `agent-system/extensions/books/context/project/books/` at the
  paths fixed in the Document Register below, each 150-250 lines.
- A rewritten `README.md` navigation index whose table names all sixteen documents with a
  one-line "read this when" for each.
- Seventeen `index-entries.json` entries: the README at Tier 2, the sixteen documents at Tier 4
  with `on_demand: true` (D3).
- Every figure in the corpus dated and marked measured; every pointer a plain backticked path,
  never an eager `@`-import; every citation a durable anchor and never a task number.
- Every mechanical gate that reaches these files green (Phase 9).

**Non-Goals**:
- Any edit to `manifest.json`, `agents/`, `skills/`, `commands/`, `rules/` or `scripts/tests/` -
  the dependency task owns those and they are already landed.
- Any hand-authored file under `.claude/**` (`rules/source-store-deploy-boundary.md`); each repo
  regenerates its own `.claude/` through the loader picker. No deploy is run by this task.
- Any change to the consuming repository `/home/benjamin/Projects/Logos/Verification`. It is
  **read-only** for every phase; the only command run against it is
  `interface/scripts/layer-lint.sh`, which needs no build, no network, and writes nothing.
- Re-litigating the books convention's eighteen decisions, or building any of the named gaps.
- A seventeenth document (`patterns/local-path-require-obligations.md`) and the two agent-system
  guide edits the research recommends - recorded as follow-ups, not in scope.

## Document Register (paths fixed here; Phase 1's README table must match exactly)

| # | Path | Phase | Primary source (Finding 5) |
|---|------|-------|-----------------------------|
| 11 | `domain/known-gap-register.md` | 1 | eighteen `Validated by` markers + live register |
| - | `README.md` | 1 | navigation index |
| 1 | `domain/layer-vocabulary-and-matrix.md` | 2 | Decisions 2, 3; `Books.Meta` |
| 6 | `standards/metadata-split.md` | 2 | Decision 6; `Books.Meta` docstring |
| 2 | `domain/book-toml-v2.md` | 3 | `books/schema/book-toml-v2.md`; Decision 7 |
| 3 | `domain/certificate-ledger-and-records.md` | 3 | `books/schema/book-cert-v2.md`; Decisions 8, 9, 11 |
| 4 | `domain/identity-and-versioning.md` | 4 | Decisions 9, 11; `BookCert/*` |
| 5 | `domain/status-and-trust-vocabularies.md` | 4 | Decision 12; `docs/trust-model.md` |
| 12 | `domain/gate-tiers.md` | 5 | `specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` |
| 14 | `patterns/gate-collision-ledger.md` | 5 | same, plus the framed_channel family summary |
| 13 | `patterns/warning-driven-convergence.md` | 6 | the framed_channel family summary |
| 15 | `standards/forgery-probe-discipline.md` | 6 | `books/tests/manifest/run.sh` + probe fixtures |
| 16 | `tools/certify-guide.md` | 6 | `books/scripts/certify.sh`; `commands/certify.md` |
| 7 | `patterns/authoring-workflow.md` | 7 | the AUTHOR/BUILD/CERTIFY/DOCUMENT narrative, re-grounded |
| 10 | `tools/tooling-inventory.md` | 7 | `books/README.md`; both lakefiles; four test suites |
| 8 | `tools/typst-template-contract.md` | 8 | `typst/lib/book.typ`; `typst/tests/book-template/run.sh` |
| 9 | `standards/reconciliation-contract.md` | 8 | Decision 17 |

All paths are relative to `agent-system/extensions/books/context/project/books/`.

## Standing Rules (apply to every authoring phase)

These are not restated per phase. A phase that violates one is not green.

1. **Write against measurement, not against the dispatch description** (D4). Every figure carries
   a measured marker and a date. Re-measure at the start of each authoring phase for the figures
   that phase asserts - the consuming repository is under active development and a Phase 1 figure
   may be stale by Phase 8. The Appendix of the research report lists the exact measurement
   commands; reuse them verbatim rather than inventing new ones.
2. **Where the design record describes something unbuilt, say so in the same breath** (D6).
   Documents 8, 9 and the DOCUMENT half of document 7 must open with what is not true yet: no real
   book has a Typst document; `typst/lib/book.typ` reads four top-level names the certificate
   writer never emits, so a real certificate cannot currently render; zero real books carry a
   `book.record.json`. A document that presents these contracts as operative is false.
3. **Defer to the register, do not re-caveat.** `domain/known-gap-register.md` exists from Phase 1
   onward. A later document states its subject's gaps by pointing at the register, and adds only
   the gap detail specific to itself.
4. **Durable anchors only, never a task number** (D7, `rules/no-task-references-in-deliverables.md`).
   Cite file paths, `file:line`, decision numbers, script names, and the consuming repository's
   `specs/<dir>/...` artifact paths (which contain no lint match because the digits are not
   preceded by the token `task`). The write-time hook `hooks/validate-no-task-references.sh` is
   blocking, so a violation fails the Write, not a later gate.
5. **Full paths, never a bare directory reference standing alone** (D8), so the pending
   `books/` -> `bookkit/` rename is a mechanical find-and-replace.
6. **Plain backticked pointers, never eager `@`-imports**, for every cross-reference inside the
   corpus. Plain ASCII punctuation, no emoji, no box drawing (`CLAUDE.md` policies).
7. **150-250 lines per document.** A document materially over 250 lines is either carrying content
   that belongs in another register row or duplicating a sibling; a document materially under 150
   is probably paraphrasing where it should transcribe.
8. **Transcribe enumerations, do not paraphrase them.** Key lists, flag sets, word lists and the
   matrix rows come across verbatim from the schema documents and the implementation.
9. **Read-only against the consuming repository** (see Non-Goals).
10. **Concurrency discipline.** One sibling dispatch runs this cycle on seven
    `agent-system/extensions/core/` orchestrate files - zero overlap with this task. Still:
    re-read any file immediately before editing it, stage only this task's own hunks with an
    explicit file list (never `git add -A`, never a directory or glob pathspec), and never run
    `git-snapshot.sh` in its reverting default mode. See `context/contracts/territory.md`
    (Cross-Task Territory).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The corpus is stale the day it lands (four of six bullets in the dispatch's own register already were) | H | H | Standing Rule 1 + D5: every figure dated and marked measured; the register is a declared projection of the `Validated by` markers, with the markers named as the authority, so a refresh is a re-projection |
| Tiering mistake silently inflates every books dispatch (all-Tier-2 would inject ~3,500 lines) | H | M | D3; the books agents are absent from `validate-context-budgets.sh`'s `CAPS` table so no cap would fire - Phase 9 reads back each new entry's *derived* tier explicitly rather than trusting the gate |
| `tools/typst-template-contract.md` is obsoleted mid-authoring (the four-certificate-read reconciliation is live research in the consuming repository) | M | M | Phase 8 last; re-verify against `typst/lib/book.typ` at authoring time; write the design contract plus a dated measured-state note, so only the note needs updating |
| The `books/` -> `bookkit/` rename invalidates every path citation | M | M | D8: full paths only; the register names the rename as a pending change to the corpus's own citations |
| The five evidence documents over-generalize from one dispatch on one component family | M | M | Carry the source report's own "this is a seed, not a diagnosis" caveat verbatim into `domain/gate-tiers.md` and `patterns/gate-collision-ledger.md`; write measured-once, not measured |
| Scope creep into the wiring (a books verification tier, a `/reconcile` command, Rule E handling all suggest wiring work) | M | M | Non-Goals; they land as register rows and follow-up recommendations. The one out-of-glob edit taken (D2) is declared with its justification in Phase 9 |
| A sibling's in-flight edit is mistaken for a regression | L | L | Standing Rule 10; if a foreign commit or foreign uncommitted modification appears, STOP and report after checking `git log`, rather than proceeding |
| Documents drift into duplicating each other (sixteen documents, overlapping sources) | M | M | The Document Register fixes one primary source per document; Phase 9 includes a cross-document duplication read-through |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8 | 1 |
| 3 | 9 | 1, 2, 3, 4, 5, 6, 7, 8 |

Phases within the same wave can execute in parallel. Wave 2 is genuinely parallel: Phase 1 fixes
every path in the Document Register and authors the README naming all sixteen, so no wave-2 phase
needs to edit a file another wave-2 phase owns, and a wave-2 document may cite a sibling
document's path before that document exists. Each wave-2 phase owns exactly the files named in
its own **Files to modify** list and touches no other file.

---

### Phase 1: The frame - known-gap register and README navigation index [COMPLETED]

**Goal**: Land the two files every other document depends on: the dated known-gap register that
later documents defer to instead of re-caveating, and the navigation index that is the corpus's
only discovery mechanism.

**Tasks**:
- [x] Measure, in the consuming repository, read-only: read all eighteen
      `- **Validated by**:` markers in `docs/book-convention.md` and record each one's form
      (`none yet [-- reason]` / `partially, <instances>` / binding) together with what it names as
      exercised, not exercised, and contradicted.
- [x] Re-measure the live in-flight register from that repository's `specs/TODO.md` and
      `specs/state.json`, recording each relevant entry's directory path and current status.
      Research measured twelve relevant entries; confirm the set and the statuses rather than
      copying them.
- [x] Re-run the censuses in the research report's Appendix (book population, annotation census,
      layer-value distribution, authored-field census, the `layer-lint.sh` run) and record each
      figure with today's date.
- [x] Write `domain/known-gap-register.md` in three parts per D5: (a) the eighteen markers
      projected into a table with exercised / not exercised / contradicted columns, (b) the live
      in-flight register, (c) a dated "measured as of" header that names the markers in
      `docs/book-convention.md` as the authority and this file as a projection. Adopt the marker
      vocabulary; invent no parallel scheme.
- [x] Include as named register rows, at minimum: the absence of any verification tier between
      `lake build` and the full gate; `lake shake` refusing non-`module` packages so the
      certifier's shake stage reports SKIPPED and never propagates its rc; the regex layer lint's
      ability to pass vacuously and the fact that **reporting a vacuous pass as vacuous is a
      requirement this corpus states, not a behaviour the lint implements**; the certifier not
      being referenced anywhere in `full-gate.sh`; `books/tool/approve-guarantees.sh` and
      `books/tool/book-health.sh` being absent; zero real `book.record.json`; no real book
      carrying a Typst document; the execution-construct gate's domain ("every module whose import
      closure contains `Books.Meta`") having no enumerating script; the four
      `reserved_passes` named in a real certificate; and the pending `books/` -> `bookkit/` rename
      as a risk to this corpus's own citations.
- [x] Explicitly correct, in the register or in the document whose subject it is, every entry of
      Finding 3's eleven-row staleness ledger. Do not reproduce the dispatch description's
      register text.
- [x] Rewrite `README.md` as the navigation index: a short framing paragraph (what a lean book is,
      and that the design record in the consuming repository is normative and owned there), then a
      table with one row per document - path, one-line subject, and an explicit "read this when"
      - naming all sixteen documents at the Document Register's exact paths. State in the README
      that every document is reachable on demand only, and that the register is the file to read
      first for what is not built.
- [x] Verify the README table's sixteen paths match the Document Register character for
      character (a mismatch makes a document unreachable and trips Phase 9's reconciliation).
      *(completed: 16/16 exact match)*

**Timing**: 1.5-2 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: eighteen `Validated by` markers and roughly twelve relevant live register
entries. Confirm by counting the markers in `docs/book-convention.md` and by reading that
repository's `specs/state.json` directly; write the counts found, not the counts asserted here.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/domain/known-gap-register.md` - new, ~230 lines
- `agent-system/extensions/books/context/project/books/README.md` - rewritten from the 19-line stub, ~90 lines

**Verification**:
- Both files exist and are non-empty; `wc -l` within the 150-250 / 60-110 bands.
- The README's sixteen paths match the Document Register exactly (diff the two lists).
- Every figure in the register carries a date and a measured marker; no figure traceable to the
  dispatch description alone.
- No task-number citation (the write-time hook enforces this; confirm the Writes succeeded).

---

### Phase 2: The spine - layer vocabulary, the may-import matrix, and the metadata split [COMPLETED]

**Goal**: The two documents every other document points back to: what a layer is and what it
licenses, and where each piece of metadata is allowed to live.

**Tasks**:
- [x] Write `domain/layer-vocabulary-and-matrix.md` per Finding 5 item 1: the twelve `book_layer`
      values with their live-usage counts (re-measured), noting that `instances.defs` and
      `instances.proofs` are declared and unused on the real tree; `baseLayer` tier stripping; the
      `mayImport` matrix reproduced row by row from `books/lean/Books/Meta.lean:139-152`, including
      the `challenge` row's conditional cells and the bridge-package condition; `book_layer`
      enforcing over DIRECT imports at elaboration versus the computed graph at certification;
      `challenge` and `evidence` terminal; and the two universal rules that stand outside the
      matrix (Mathlib/Aeneas confinement, terminal layers) **with the reason** `book_layer` cannot
      enforce confinement - bridge-package-ness is not a layer fact, and confinement is a claim
      about the import closure's packages, not about direct imports' layers
      (`Books.Meta:92-99`).
- [x] Add to that document the restricted/unrestricted split and the fail-closed
      execution-construct gate, which the dispatch's document 1 omits entirely: `interface`,
      `laws`, `refinement`, `challenge` restricted; `extraction`, `impl`, `instances`, `evidence`
      unrestricted; `.defs`/`.proofs` inheriting through `baseLayer`; ten refused core command
      kinds; a module stating no layer is refused (`Books.Meta:592`, `:595`); the
      `isUnsafe`/`@[implemented_by]`/`@[extern]` refusal at the `@[book_export]` handler
      (`:435`) and its advisory `Linter` twin, which "cannot be otherwise" because `lintersRef` is
      a clearable public `IO.Ref`.
- [x] Write `standards/metadata-split.md` per Finding 5 item 6: facts in Lean, judgments in TOML,
      everything else computed (Decision 6); in a code module exactly two things (`@[book_export]`
      with no kind argument - kind derived from `getOriginalConstKind?` - and one `book_layer`
      line); in the book module everything else with each command's exact syntax (`book`,
      `book_assume "<id>" "<text>" [<anchor>]`, `book_not_claimed`, `book_axioms`, `book_policy`,
      `book_requires`), all read back by `#book_ledger`; a `book_*` command in a code module WARNS
      and the build succeeds.
- [x] Add the two things the design record does not carry: the mutual-exclusion guard (`book`,
      `book_layer`, `@[book_export]` refusing each other in all three directions, each guard
      naming itself) and - prominently, as the document's highest-severity rule - the
      **`book_policy` subject-placement rule**: a policy row belongs on the book that owns its
      subject, because a subject that is not a member of the certifying book resolves to nothing
      and certifies as `"outcome": "holds"` with `"checked_modules": []`. Record that this rule is
      documented nowhere in Decision 4's text and that Decision 4's own worked example
      contradicts it, and cross-reference `standards/forgery-probe-discipline.md` as the document
      whose grounding instance this is.
- [x] Point both documents at `domain/known-gap-register.md` for gap claims instead of carrying
      their own caveats.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: the matrix is twelve values with `mayImport` at `Books.Meta:139-152` and the
layer-value counts measured in research (`refinement` 46, `impl` 38, `challenge` 29,
`interface` 24, `laws` 22, `instances` 14, `evidence` 7, `extraction` 3, `impl.proofs` 2,
`impl.defs` 2). Confirm by re-running the layer-value distribution command from the research
Appendix and by reading `Books.Meta` at the cited lines before transcribing.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/domain/layer-vocabulary-and-matrix.md` - new, ~220 lines
- `agent-system/extensions/books/context/project/books/standards/metadata-split.md` - new, ~180 lines

**Verification**:
- Both files exist, within the line band.
- Every matrix row and every refused command kind traceable to a cited `file:line`.
- The `book_policy` subject-placement rule present, prominent, and cross-referenced.
- Every anchor cited resolves (spot-check each `Books.Meta:NNN` against the file).

---

### Phase 3: The authored manifest and the computed certificate [COMPLETED]

**Goal**: What a person authors in `book.toml`, and what the certifier computes into
`book.cert.json` - with the two different records kept distinct.

**Tasks**:
- [x] Write `domain/book-toml-v2.md` per Finding 5 item 2: `schema = 2`; the
      `[book]`/`[trust]`/`[provenance]`/`[docs]` tables; the seventeen keys, confirmed against a
      real certificate's `judgments.fields`; the fields-versus-keys distinction with the design
      record's "twelve fields" headline named as a historical name the schema document corrects;
      the `status` enum {draft, certified, deprecated} and the four trust verdicts {verified,
      validated, trusted, not_applicable}; `stale` DERIVED and never authored; the
      computed-never-authored list (`[layers]`, `[exports]`, `[[depends]]`, `[external]`,
      `[axioms]`, the summary - which is the book module's docstring - and packages).
- [x] Add, from the real manifests: an absent `[trust]` table means all six ground classes
      `not_applicable` and is the honest record for a draft book; all 27 real manifests declare
      `status = "draft"`; first certification is `draft` because the certifier refuses `certified`
      with no `--prev` to bump against, refusal reason `stale-certified`
      (`books/certifier/Certify.lean:808-835`); `"<absent>"` is the literal recorded value for an
      unauthored key; the enforced word lists live at `books/tool/Books/Manifest.lean:33-38`.
- [x] Write `domain/certificate-ledger-and-records.md` per Finding 5 item 3 *(deviation: altered -- landed at 275 lines, justified overrun; six mandated enumerations)*: the certificate sits
      **directly** in the book directory and never in a `certificate/` subdirectory, because the
      framed_channel export tooling treats every `certificate` directory as a discovery root; it
      is THE ONLY INPUT of every non-Lean tool (Decisions 8, 9, 11); the full top-level key list
      and the `export_ledger` row shape, both transcribed from the real certificate recorded in
      Finding 2 (`interface/books/result/book.cert.json`); `passes` versus the four named
      `reserved_passes`; the `docs` block with its four `context_pack_bytes` keys and
      `counts{missing,orphaned,reconciled,stale}`.
- [x] In the same document, keep separate the **two records the dispatch description conflates**:
      `book.record.json` (reconciliation - guarantee text hash bound to its export's ledger
      digest, with who signed and when; non-digested by construction; **zero real instances**, the
      only two in the tree being a certify fixture and the Typst probe) and `book.read.json` (the
      read test - six keys `book`/`by`/`date`/`reader`/`marks{does_what,assumes_what,could_go_wrong}`,
      sole writer `books/tool/record-read-test.sh`, five real instances, one of which records
      `"by": "agent"`).
- [x] Defer gap claims to `domain/known-gap-register.md`.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: seventeen `judgments.fields` keys (`schema`, six `book.*`, six `trust.G*`,
three `provenance.*`, `docs.entry`) and the top-level certificate key list recorded in Finding 2.
Confirm by reading a real `book.cert.json` verbatim (`interface/books/result/book.cert.json`) and
`books/schema/book-cert-v2.md` before transcribing; if the live shape differs, write the live
shape and add a deviation note.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/domain/book-toml-v2.md` - new, ~190 lines
- `agent-system/extensions/books/context/project/books/domain/certificate-ledger-and-records.md` - new, ~240 lines

**Verification**:
- Both files exist, within the line band (the certificate document may reach ~250).
- The seventeen keys enumerated, not summarized; the key count stated as measured.
- `book.record.json` and `book.read.json` described as two different artifacts with two different
  writers and two different instance counts.

---

### Phase 4: Identity, versioning, status and trust [NOT STARTED]

**Goal**: How a book's identity is computed and when it must bump; and what each status value and
trust verdict licenses and forbids.

**Tasks**:
- [ ] Write `domain/identity-and-versioning.md` per Finding 5 item 4: per-export Merkle digests
      over the statement cone with axiom sets; the roll-up into **three** identities -
      `interface_identity`, `identity` and `proof_identity` (not two, as the dispatch description
      has it); chaining per export through dependencies' certificates;
      `serialisation_format: "dag-v2"` and why sharing-awareness matters, with the measured
      instance (a 9,263,152,983-node unshared tree serialising to 420,646 chars, turning a
      35-minute-then-killed certification into under two minutes); the versioning rule keyed on
      canonical statement serialisation with **no bump on a Lean toolchain bump alone**; and the
      identity exclusions as `books/schema/book-cert-v2.md` states them.
- [ ] Write `domain/status-and-trust-vocabularies.md` per Finding 5 item 5: the three `status`
      values and the four verdicts, each with what it licenses and what it forbids; the six ground
      classes G0_checker, G1_translation, G2_ir_faithfulness, G3_models, G4_specification,
      G5_binding; a `certified` book whose record is not fully reconciled FAILS the docs stage and
      is not certified; a `draft` book only reports.
- [ ] Record in that document, from Decision 12's own marker, what is contradicted: the "derived
      display status computed once by the certifier" is contradicted because no `status` field is
      written and the only renderer reads `certificate.status.derived`, which exists only in the
      probe. Record that the pure-Lean G1-G3 rule and the composite-trust rule have **no
      checker**, while the never-more-trusted-than-its-least-trusted-part clause was enforced
      mechanically for the first time through the permitted-axiom set - the framed_channel
      composite refused eight times with `axiom-outside-book-axioms` until it declared the two
      `bv_decide` native helper axioms its parts mint.
- [ ] Defer gap claims to `domain/known-gap-register.md`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: three identities and six ground classes; the `dag-v2` sharing measurement as
recorded in the design record. Confirm the identity names against a real `book.cert.json`'s top
level and the word lists against `books/tool/Books/Manifest.lean:33-38` before writing.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/domain/identity-and-versioning.md` - new, ~170 lines
- `agent-system/extensions/books/context/project/books/domain/status-and-trust-vocabularies.md` - new, ~160 lines

**Verification**:
- Both files exist, within the line band.
- Three identities named, with the dispatch description's two-identity framing corrected.
- Each status value and each verdict states both what it licenses and what it forbids.

---

### Phase 5: Gate tiers and the collision ledger [NOT STARTED]

**Goal**: The two highest-value evidence documents: what each verification tier does and does not
check, and the six integration collisions a next books integration should read instead of
rediscover.

**Tasks**:
- [ ] Write `domain/gate-tiers.md` per Finding 5 item 12. For **each** tier record three things -
      what it checks, what it does NOT check, and the cheapest tier that catches each error class:
      `lake build` (compiles; runs the elaboration-time matrix check over direct imports and the
      execution-construct gate; invokes neither the layer lint nor the certifier nor the
      Comparator rooms); `interface/scripts/layer-lint.sh` (nine rules over `.lean` sources; no
      build, no network, no toolchain; cannot see the computed graph; 179 modules / 733 imports in
      the measured run, with its three call sites at `components/framed_channel/check.sh:468`,
      `components/distsys/check.sh:195`, `components/rle_codec/check.sh:125`);
      `books/scripts/certify.sh` (the per-export ledger, `reverify`, computed `depends`, the
      identities, the version check - and an ADVISORY shake stage that reports SKIPPED because
      `lake shake` refuses non-`module` packages on the pin); `full-gate.sh` (a route resolver and
      consent-gating launcher around a component's `check.sh`; **contains no certifier
      reference**); `--recheck` (the independent Comparator/kernel-replay legs, prebuilt route
      only).
- [ ] State the motivating measurement plainly: **44 layer violations sat undetected across five
      tagging phases that all reported green on `lake build`**, because `lake build` invokes none
      of the above. State the finding the document exists to make: **there is today no
      verification tier between `lake build` and the full gate**, and closing that gap is named,
      dated and NOT STARTED in the consuming repository's register. Correct the dispatch
      description's "chain": it is two disjoint chains, not one.
- [ ] Record the vacuous-pass rule as a rule the corpus states, not a behaviour the lint
      implements: the lint's success line prints counts from which vacuity is inferable but never
      labels it; it does carry a narrower guard (a file with `import` lines from whose header none
      were parsed is a `[FAIL]`, `interface/scripts/layer-lint.sh:50-55`); and
      `books/README.md` names the vacuous-pass domain explicitly. Point at the register row.
- [ ] Carry the source report's own caveat verbatim: every quantitative claim comes from one
      dispatch on one component family, and the diagnostics phase has not run.
- [ ] Write `patterns/gate-collision-ledger.md` per Finding 5 item 14: the measured cost (one
      implement dispatch spending **75 of 127 minutes in a single phase**, 59% of the dispatch, 262
      tool calls, while the five phases doing the task's stated work took 33 minutes between them;
      and five of six collisions discoverable only by running the ten-minute fail-closed full
      gate), then the six rows as a table with symptom / root cause / fix / cheapest possible
      catcher, exactly as Finding 5 item 14 tabulates them.
- [ ] Close that document with the adjacent finding it exists to pre-empt: adding one local-path
      `require` obliged **six edits across three files**, none referenced from the lakefile and
      none checked by anything until the gate ran. Record the dedicated checklist
      (`patterns/local-path-require-obligations.md`) as a named follow-up, not as content here.
- [ ] Carry the same measured-once caveat into this document.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 44 violations across five phases; 75 of 127 minutes; six collisions; nine
layer-lint rules; 179 modules / 733 imports. Every one of these is a measured-once figure from
`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` and the
framed_channel family summary - cite them to those artifacts by path and label them measured-once
rather than re-deriving them; re-run `layer-lint.sh` to date its own two figures.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/domain/gate-tiers.md` - new, ~240 lines
- `agent-system/extensions/books/context/project/books/patterns/gate-collision-ledger.md` - new, ~210 lines

**Verification**:
- Both files exist, within the line band.
- Every tier row carries all three columns (checks / does not check / cheapest catcher) - a row
  missing the middle column defeats the document's purpose.
- The no-intermediate-tier finding stated plainly, not buried.
- The measured-once caveat present in both files.

---

### Phase 6: Convergence, forgery probes, and operating the certifier [NOT STARTED]

**Goal**: Three operational documents: the warning-driven convergence loop, the forgery-probe
discipline, and how to run the certifier economically without being misled by its output.

**Tasks**:
- [ ] Write `patterns/warning-driven-convergence.md` per Finding 5 item 13: the loop shape
      verbatim (the `grep -oP`/`sed` pipeline that generated **179 `book_requires` lines with zero
      guesses** and converged to zero on the next run); why the warning stream is the correct
      oracle (every `book-requires-undeclared` warning names the exact missing export, so the
      compiler, not a human reading the source, is the authority); the termination condition (a
      run with zero such warnings). Generalize to the second instance in the evidence base:
      `[REFUSE] axiom-outside-book-axioms` names both the axiom and the reaching declaration,
      which is what let eight composite refusals identify exactly two `bv_decide` native axioms to
      declare. Record that framed_channel now carries 193 such lines (the 179 are the loop's
      output, not the current count) and that a `--emit-requires` certifier mode would remove the
      loop entirely and is named but unbuilt.
- [ ] Write `standards/forgery-probe-discipline.md` per Finding 5 item 15: the rule - every gate
      predicate gets a forgery probe, and a gate predicate shipped **without** one is a REVIEWABLE
      DEFECT, not a gap to be noted. Ground it in the collision-1 instance: a deliberately
      violated `book_policy` probe certified clean at zero refusals, and nothing in the
      certificate, the log or `DEPENDS.md` distinguished "checked and held" from "checked
      nothing"; it was caught only because the plan carried an explicit verification line.
- [ ] Generalize from the **landed** probe family rather than the dispatch's FORGE-A..D framing,
      which is narrower than what is on disk: enumerate the probe fixtures actually present under
      `books/tests/manifest/` (research measured twenty) and state the pattern each pair
      instantiates - a refusal probe AND a complementary admit probe, so a probe that silently
      never runs is itself detectable. Cross-reference `standards/metadata-split.md`'s
      subject-placement rule.
- [ ] Write `tools/certify-guide.md` per Finding 5 item 16: component-root scoping is mandatory (a
      repository-root run discovers 22 books and fails the pre-launch check on a Typst fixture
      whose book module is under no package root, and on a stale module - and nothing documents
      this); run `--check` FIRST (it surfaced every book module's freshness, the reader budget and
      the exact per-book `--extra-pkg-dir` list in ~90 seconds, which is what made `--no-build`
      usable instead of 1,803 build jobs per run); the `--no-build` economics, including that
      `certify.sh` builds every DISCOVERED book's module targets even under `--only`, so an
      unrelated warning anywhere in the tree can abort a narrowly scoped run; the full landed flag
      set from `agent-system/extensions/books/commands/certify.md` (`--no-build`, `--no-shake`,
      `--no-write`, `--only NAME`, `--check`, `--prev`, and the acceptance-suite-only
      `--graph-from` that the extension's wrapper refuses).
- [ ] Record the misreporting precisely, both forms: the closing line
      `[ok] N book(s) certified, dependencies first: <names>` prints every DISCOVERED book
      regardless of how many certified, so it warrants that the driver completed and nothing more
      - cross-check `book.cert.json` files on disk; and the worse one, that `certify.sh` carries no
      timing or memory instrumentation, so a run killed by `earlyoom` (measured:
      `FramedChannelAeneas.Book.Crc8` at ~16-18 GiB RSS, twice) logs a bare
      `!! book 'X' was REFUSED` with no `[REFUSE]` detail lines, visually indistinguishable from a
      genuine refusal.
- [ ] Record the reader mechanics in the same document: a reader script run under `lake env lean`
      inside the certified package's workspace works at the `.private` olean level, where
      `loadExts := true` after `enableInitializersExecution` is MANDATORY and SILENT when omitted;
      `CERTIFY_INTERPRETED=1` selects the interpreted certifier instead of the compiled `certify`
      exe; and the advisory shake stage (SKIPPED, rc never propagated).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 179 then 193 `book_requires` lines; twenty probe fixtures; the certify flag
set as `commands/certify.md`'s Options table lists it; 22 books discovered at repository root;
1,803 build jobs. Confirm the probe-fixture inventory by listing
`books/tests/manifest/fixtures/probes/` and the flag set by reading `commands/certify.md`; label
the timing and memory figures measured-once and cite them to their artifacts by path.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/warning-driven-convergence.md` - new, ~150 lines
- `agent-system/extensions/books/context/project/books/standards/forgery-probe-discipline.md` - new, ~160 lines
- `agent-system/extensions/books/context/project/books/tools/certify-guide.md` - new, ~190 lines

**Verification**:
- Three files exist, within the line band.
- The convergence loop reproduced as a runnable pipeline, not described in prose.
- The probe inventory matches what is on disk (state the count as measured on today's date).
- Both forms of certifier misreport recorded, with what the closing line does and does not
  warrant stated explicitly.

---

### Phase 7: The authoring workflow and the tooling inventory [NOT STARTED]

**Goal**: The executable end-to-end checklist, and a map of what each tooling piece reads and
writes - with the repo-side machinery marked as not-to-be-duplicated.

**Tasks**:
- [ ] Write `patterns/authoring-workflow.md` per Finding 5 item 7 as an executable checklist in
      four stages. AUTHOR: licence header on line 1 and `module` on line 2 (structural, because a
      comment parses ahead of the `module` keyword); one `book_layer` per code module;
      `@[book_export]` on each intended export; added **by hand** to the lakefile's explicit globs
      list. Then the book module: a PLAIN (private) import of the provider, PUBLIC imports of its
      own code modules (which is what makes a cross-book dependency declaration resolvable), a
      module docstring that IS the summary, `book <Name>`, `book_axioms [...]`, per-layer
      `book_policy` confinement lines **placed on the book that owns each subject** (pointing at
      `standards/metadata-split.md`), `book_assume` with its discharging anchor,
      `book_not_claimed`, and `book_requires` for cross-book hypotheses (checked transitively
      against statement cones, so naming a constant whose declaring module is in the closure is
      correct and sufficient). Then `book.toml` v2 and the `docs/` entry.
- [ ] BUILD/TEST: the full audit list - clean build green from an empty `.lake/` with no network
      and wall time recorded; zero-`sorry` census; no `native_decide`, no search tactic, no
      vacuously-true definition; axiom audit against the declared budget with choice absent and
      the number of SOURCES distinguished from the number of carrying declarations; universe audit;
      Mathlib-freedom audit (no require, no import, no mention, in any module or lakefile);
      `#book_ledger` reporting every code module layered, the book module carrying no layer, every
      intended export rowed with the right derived kind and no forged-row flag;
      `books-tool validate` (it decodes and checks all seventeen keys - a stronger check than
      counting files); `books-tool check --lib` reporting zero unassigned and zero doubly-assigned
      modules; a rebuild-isolation spot check; a declaration-inventory diff signature by signature;
      `check-spdx.sh`; the regex layer lint with a vacuous pass recorded AS vacuous; and the
      task-reference lint. State the rule: every figure recorded as LANDED, never inherited from
      the design artifact, and a deviation written as a deviation note rather than silently
      absorbed.
- [ ] Add the step the evidence makes mandatory and point at `domain/gate-tiers.md` for why: run
      `interface/scripts/layer-lint.sh` at the end of **any** tagging phase, because `lake build`
      never invokes it and that omission is what let 44 violations sit across five phases. Add the
      caution that the execution-construct gate's domain is not enumerable by any existing script
      (register row).
- [ ] CERTIFY: point at `tools/certify-guide.md` for operation and keep only the sequence here -
      dependencies first in topological order, `reverify`, the advisory shake, computed `depends`,
      the per-export ledger, `interface_identity`/`identity`/`proof_identity`, the version check as
      a ledger diff, the authored judgments copied in with `source: authored`
      (`books/lean/BookCert/Writer.lean:264-270`), then the docs stage; and the byte-stability
      property (an unchanged tree regenerates the certificate byte for byte).
- [ ] DOCUMENT: point at `tools/typst-template-contract.md` and open this sub-section with the
      measured state - no real book has a Typst document; 25 of 27 real books declare
      `[docs] entry = "docs/book.md"`; two declare a `book.typ` that does not exist - so this
      stage is a design contract today, not an exercised one. Note that `rules/books.md` mandates
      the flattened `book.typ` form and calls `docs/book.md` legacy-and-held, and that the rule
      file is the extension's own non-negotiable while the measured tree is the opposite; state
      both facts rather than choosing one silently.
- [ ] Write `tools/tooling-inventory.md` per Finding 5 item 10: `books/` is a tooling directory,
      not a component - nothing there is digested, carries a certificate, or is depended on by a
      component gate. Per piece, what it reads, what it writes, and whether the extension CONSUMES
      it or merely names it: `books/lean/` (package `books`, roots `Books` with the single
      `Books.Meta` module - **measured at 771 lines, not the 413 the dispatch description states**
      - and `BookCert` with eleven modules; declares no `require`; `[leanOptions] autoImplicit =
      false`, which is what a certificate's `lean_options_seed` records); `books/tool/` (package
      `booksTool`, the `books-tool` lean_exe over `Books.Manifest`/`EnvWalk`/`LayerCheck`, with
      **three** subcommands `validate`, `check` and `levels`, plus `docs-stage.sh` and
      `record-read-test.sh`); `books/certifier/Certify.lean`; `books/schema/`; `books/scripts/`
      (`certify.sh`, `lint-validated-by.sh`); `books/tests/` (four suites, including
      `validated-by-lint/`, which the dispatch's inventory omits).
- [ ] Record the three authoring rules under `books/` (header within the first three lines with
      the comment-before-`module` order, enforced by
      `components/framed_channel/scripts/check-spdx.sh`; explicit per-module lakefile globs and
      NEVER `Books.+`, because both `books/lean` and `books/tool` use the root `Books` so a
      wildcard glob makes each claim the other's modules - with the exact failure text
      `error: Books: some modules have bad imports` / `bad import 'Books.Meta'`; fixture packages
      using library roots distinct from `Books`), and the two structural reasons (why `BookCert`
      lives in the provider package per Decision 10 - imports resolve structurally under
      `lake env lean` in any consumer's workspace, no `LEAN_PATH` surgery; and why `Certify.lean`
      is a non-`module` script - a `module` library cannot reach another package's private
      `.olean` level, since `import all` is same-package only).
- [ ] Close with the repo-side documentation machinery to know about and NOT duplicate:
      `typst/manual/generated/` (every file generated, never hand-edited),
      `typst-component-doc.sh`, `typst-component-index.sh`, `status-counts.sh`,
      `script-reference.sh`, `certificate-export.sh`, `typst-manual-sync-check.sh`
      (regenerate-and-diff; exits non-zero naming the file and its exact regeneration command),
      `chapter-drift.sh` (non-blocking by design, `--mark` left to the person) and
      `name-resolution-check.sh`; plus the typst extension's own `typst-element-lint.sh` and
      `chapter-quality-check.sh`.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: `Books.Meta` at 771 lines; `books/` holding six subdirectories; four test
suites; `books-tool` with three subcommands; 25 of 27 manifests declaring `docs/book.md`. Confirm
each by `wc -l`, `ls` and `grep -h '^entry'` over the real manifests before writing, and write
what is found with today's date.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/authoring-workflow.md` - new, ~260 lines
- `agent-system/extensions/books/context/project/books/tools/tooling-inventory.md` - new, ~230 lines

**Verification**:
- Both files exist; the workflow document may reach ~270 given its four stages.
- The workflow is a checklist (checkable steps), not a narrative.
- The inventory's every row names what the piece reads and what it writes.
- Every line count and subdirectory claim re-measured today, with the dispatch description's
  413-line figure explicitly corrected.

---

### Phase 8: The documentation contracts [NOT STARTED]

**Goal**: The Typst template contract and the reconciliation contract - both written as design
contracts with a dated measured-state note, because neither is exercised today.

**Tasks**:
- [ ] Re-verify `typst/lib/book.typ` at authoring time (the reconciliation of its four certificate
      reads is live research in the consuming repository and may have landed), then write
      `tools/typst-template-contract.md` per Finding 5 item 8 **opening with what is not true
      yet**: no real book has a Typst document, and the library reads `certificate.version`,
      `certificate.status`(`.derived`), `certificate.trust` and `certificate.exports`, none of
      which the writer emits (it emits `judgments.fields["book.*"]`/`["trust.*"]` and
      `export_ledger`), so a real certificate cannot currently render. If the live library has
      changed, write the live state and note the change.
- [ ] Then the contract itself: tiers `overview | full | reference` via `--input tier=` and modes
      `standalone | embedded` via `--input mode=`; the certificate as the only data input, loaded
      by the book DOCUMENT (`json("book.cert.json")`, a path relative to itself) and handed in via
      `#show: book.with(certificate: ...)`; the mechanism reason - a relative
      `json()`/`read()`/`image()` path resolves against the file whose SOURCE TEXT contains the
      call, so a shared library cannot read a different certificate per book - and therefore that
      the library never calls `json()` for a certificate, never reads `book.toml`, never reads
      `book.record.json` and never reads Lean source; `typst/lib/phrases.toml` as the one
      root-absolute read.
- [ ] Record the label mechanics: every label book-id-prefixed from a `state()` so labels cannot
      collide once several books are embedded in one build; a label built in a SEPARATE `context`
      block and placed after already-realized content SILENTLY fails to attach, so labelled
      content and its label must be constructed together inside ONE `context` block (the
      `tagged`/`tagged-metadata` helpers); every `metadata` value carrying an explicit `kind`
      field so a generic `typst query <file> 'metadata'` returns every tagged element from every
      embedded book and the consumer filters on `.value.kind`.
- [ ] Record the compile root and the pins: the compile root is the REPOSITORY root (`--root .`,
      architecture Decision 9) through `bash typst/scripts/build.sh`, so a book's `docs/` outside
      `typst/` compiles standalone AND embeds in the manual; thmbox 0.3.0, fletcher 0.5.8,
      cetz 0.3.4 on Typst 0.14.2, with these marked as VERIFIED on that version rather than
      assumed. Then the test suite `typst/tests/book-template/run.sh` against
      `typst/tests/book-template/probe/` (book.toml, book.cert.json, book.record.json,
      docs/book.typ): three standalone tier compiles, one embedded compile, `typst query` for
      `<lean-decl>`/`<guarantee>`/`<book-meta>` metadata, and tier=overview containing no backtick
      span and no math.
- [ ] Record the tier-one content bar: no symbols, no Lean identifiers, no tool names; every
      guarantee names an export and every export has a guarantee; assumptions and not-claimed items
      rendered FROM the certificate, never retyped; a book that cannot support a section carries a
      scope note naming what is missing; a reworded guarantee needs re-approval exactly as a
      changed statement does; and a mechanical tier-one prohibition lint is part of the docs stage.
- [ ] Write `standards/reconciliation-contract.md` per Finding 5 item 9: reconciliation triggered
      by CERTIFICATION, never by file save or commit; a proof-only edit changes no digest and
      touches no guarantee; an interface change always does, once. The contract: inputs limited to
      the documenter pack (certificate + tiers one and two + the phrase table + the record);
      writes limited to `docs/book.typ` of the NAMED book; only guarantees whose digests changed
      are touched; every tier compiled and the docs stage and lints green before finishing; and the
      record, `book.toml`, approvals and book module NEVER edited. The summary names each
      guarantee touched with old and new digest. **Agents write prose; PEOPLE write records** - the
      command prints the signing invocation and never runs it.
- [ ] Add the distinctions the measured tree forces: the approval record (`book.record.json`) is
      people-written and has **no writer script yet** (`approve-guarantees.sh` is absent), while
      the read-test record (`book.read.json`) has a landed sole writer and one instance records
      `"by": "agent"`; and the docs stage exists in a split form - `books/tool/docs-stage.sh`
      measures the document and file pack and emits JSON on stdout (never committed), the
      certifier combines it with the three inputs only it has, a non-tiered Markdown document is
      stat'd once and reported under both tier keys with `non_tiered` true and
      `tier_compile: "unknown"` rather than a fabricated `ok`, and **absent documentation is not a
      finding** (Decision 17 clause 4), because per-book content is held until certificates exist.
- [ ] Both documents defer their gap claims to `domain/known-gap-register.md`, and both carry a
      dated measured-state note distinct from their contract body, so a future refresh touches
      only the note.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: `typst/lib/book.typ` at 183 lines reading four names the writer does not
emit; zero real `book.typ`; zero real `book.record.json`. Re-measure all four at authoring time
(`wc -l`, `grep` for the four reads, `find -name book.typ`, `find -name book.record.json`) and
write the measured values; the 183-line figure in particular is from the dispatch description and
is in the staleness ledger's domain.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/tools/typst-template-contract.md` - new, ~230 lines
- `agent-system/extensions/books/context/project/books/standards/reconciliation-contract.md` - new, ~200 lines

**Verification**:
- Both files exist, within the line band.
- Each opens with its not-yet-true framing before any contract text; a reader cannot mistake
  either contract for an exercised one.
- The measured-state note is separable from the contract body (its own heading).

---

### Phase 9: Registration, reconciliation and the mechanical gates [NOT STARTED]

**Goal**: Register all seventeen files with the tiering of D3, reconcile the README against what
actually landed, and take every mechanical gate that reaches these files green.

**Tasks**:
- [ ] Re-read `agent-system/extensions/books/index-entries.json` immediately before editing
      (Standing Rule 10), then replace its single stub entry with seventeen entries:
      `project/books/README.md` keeping its existing Tier 2 hooks (`load_when.agents` = the four
      books agents, `load_when.task_types: ["books"]`) with its summary updated from
      "navigation stub ... separate, dependent task" to its landed role; and one entry per document
      with `load_when: {"agents": [], "task_types": []}` plus **`"on_demand": true`** (Tier 4).
- [ ] For each entry use only the fields `index.schema.json` permits (`additionalProperties` is
      false): `path`, `domain` (`project`), `subdomain` (`books`), `topics`, `keywords`, `summary`
      (**max 200 characters**), `line_count`, `load_when`, `on_demand`. No `description`, no
      `tags`, no `tier`.
- [ ] Record the out-of-glob edit in the implementation summary with its one-line justification
      (D2): `index-entries.json` sits at the extension root, outside this task's stated
      `context/project/books/**` glob and outside the dependency task's owned list; leaving
      seventeen context files unregistered would make them invisible to the index and to every
      discovery path, so registration is an inseparable part of authoring a context file. The edit
      is additive, touches no other extension's file, and collides with no sibling's scope.
- [ ] Fill `line_count` mechanically, never by hand:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`,
      then re-run with `--check` and require exit 0.
- [ ] Verify the tiering by derivation, not by inspection:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/validate-context-budgets.sh --index agent-system/extensions/books/index-entries.json`
      and require `Dead entries ... 0 -- OK` plus a derived tier of 2 for the README and 4 for each
      of the sixteen. (The books agents are absent from that script's `CAPS` table, so no budget
      cap fires - the derived-tier read-back is the real check here.)
- [ ] Validate the entry schema and the extension's docs:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      and require no failure attributable to the books extension (Rule T schema, Rule R line-count
      accuracy in particular).
- [ ] Reconcile the README against what landed: every one of the sixteen paths exists on disk,
      every file on disk has a README row, and no row points at a path that was renamed during
      authoring. Fix the README, not the paths, if they diverged.
- [ ] Read through all sixteen documents once for cross-document duplication: a claim stated in
      two documents should be stated in the one its Document Register row owns and pointed at from
      the other.
- [ ] Verify every cross-reference inside the corpus resolves (each backticked corpus-relative
      path exists; each `file:line` anchor into the consuming repository still points at what it
      claims - spot-check, do not re-verify all).
- [ ] Stage only this task's own files with an explicit file list (the seventeen corpus files plus
      `index-entries.json`, and `EXTENSION.md`/`README.md` if the optional step below was taken),
      then run `bash agent-system/extensions/core/scripts/check-task-references.sh` and require
      exit 0. **Staging first is load-bearing**: that lint scans git-tracked files via
      `git ls-files`, so an untracked new file is skipped and a violation would go unreported.
- [ ] **Optional, declared, strictly bounded**: three sentences outside the corpus now read as
      false - `agent-system/extensions/books/EXTENSION.md:51` and
      `agent-system/extensions/books/README.md:33` and `:102` each describe the corpus as "a
      separate, dependent task". Update those three sentence-level references to name the landed
      corpus and the README as its index. Keep `EXTENSION.md` within its 60-line limit
      (`check-extension-docs.sh` Rule U). If the change would exceed three sentence-level edits or
      require restructuring either file, **defer it** and record it as a follow-up instead; do not
      expand this step. `rules/books.md:69` is owned by the dependency task and is left untouched
      (its "navigation stub into the fuller domain corpus" phrasing stays accurate).

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6, 7, 8

**Verification Tier**: local

**Scope Hypothesis**: seventeen entries (one README + sixteen documents) and three stale
sentence-level references outside the corpus. Confirm the entry count against the files actually
on disk under `context/project/books/` (`find ... -name '*.md' | wc -l`), and re-grep for the
stale phrasing rather than trusting the three line numbers above.

**Files to modify**:
- `agent-system/extensions/books/index-entries.json` - stub entry replaced by seventeen entries
- `agent-system/extensions/books/EXTENSION.md` - optional, one sentence (line ~51)
- `agent-system/extensions/books/README.md` - optional, two sentences (lines ~33, ~102)
- `agent-system/extensions/books/context/project/books/README.md` - reconciliation fixes only, if any

**Verification**:
- `python3 -c "import json;json.load(open('agent-system/extensions/books/index-entries.json'))"` parses; 17 entries.
- `generate-context-line-counts.sh --check` exits 0.
- `validate-context-budgets.sh --index <that file>` reports 0 dead entries; derived tier 2 for the
  README, 4 for all sixteen documents.
- `check-extension-docs.sh` reports no books-extension failure.
- `check-task-references.sh` exits 0 with the corpus staged.
- Every README row resolves to a file on disk and every file on disk has a README row.
- `.claude/**` untouched: `git status --short -- .claude/` is empty for these changes.

---

## Testing & Validation

- [ ] Seventeen files exist under
      `agent-system/extensions/books/context/project/books/` at the Document Register's exact paths.
- [ ] Each of the sixteen documents is 150-250 lines (a justified overrun to ~270 is acceptable for
      `patterns/authoring-workflow.md`); the README 60-110 lines.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
      exits 0.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/validate-context-budgets.sh --index agent-system/extensions/books/index-entries.json`
      reports 0 dead entries, with the derived tiers of D3.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      reports no failure for the books extension.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0, run with the
      corpus staged.
- [ ] No file under `.claude/**` was written by this task.
- [ ] No file under `agent-system/extensions/books/{manifest.json,agents,skills,commands,rules,scripts}`
      was modified.
- [ ] The consuming repository `/home/benjamin/Projects/Logos/Verification` has no modification:
      `git -C /home/benjamin/Projects/Logos/Verification status --porcelain` shows nothing this
      task caused.
- [ ] Every figure in the corpus carries a date and a measured marker; spot-check five figures
      against their stated measurement command.
- [ ] Each of Finding 3's eleven staleness-ledger entries is addressed somewhere in the corpus
      (register row or the owning document's text), with the measured value, not the dispatch
      description's.

## Artifacts & Outputs

- `agent-system/extensions/books/context/project/books/README.md` (rewritten navigation index)
- `agent-system/extensions/books/context/project/books/domain/known-gap-register.md`
- `agent-system/extensions/books/context/project/books/domain/layer-vocabulary-and-matrix.md`
- `agent-system/extensions/books/context/project/books/domain/book-toml-v2.md`
- `agent-system/extensions/books/context/project/books/domain/certificate-ledger-and-records.md`
- `agent-system/extensions/books/context/project/books/domain/identity-and-versioning.md`
- `agent-system/extensions/books/context/project/books/domain/status-and-trust-vocabularies.md`
- `agent-system/extensions/books/context/project/books/domain/gate-tiers.md`
- `agent-system/extensions/books/context/project/books/patterns/authoring-workflow.md`
- `agent-system/extensions/books/context/project/books/patterns/warning-driven-convergence.md`
- `agent-system/extensions/books/context/project/books/patterns/gate-collision-ledger.md`
- `agent-system/extensions/books/context/project/books/standards/metadata-split.md`
- `agent-system/extensions/books/context/project/books/standards/forgery-probe-discipline.md`
- `agent-system/extensions/books/context/project/books/standards/reconciliation-contract.md`
- `agent-system/extensions/books/context/project/books/tools/tooling-inventory.md`
- `agent-system/extensions/books/context/project/books/tools/typst-template-contract.md`
- `agent-system/extensions/books/context/project/books/tools/certify-guide.md`
- `agent-system/extensions/books/index-entries.json` (seventeen entries)
- `specs/298_author_books_extension_context_corpus/summaries/01_*-summary.md`

Follow-ups recorded, not produced: `patterns/local-path-require-obligations.md`; one sentence in
`context/guides/extension-development.md` stating Rule E's document scope (now known: it does not
reach `context/`).

## Rollback/Contingency

Every change is additive new markdown plus one JSON edit; nothing is deleted and no build artifact
is produced, so rollback is cheap and per-phase.

- **Per phase**: each authoring phase is independent and commits its own files. To undo one, `git
  revert` that phase's commit, or delete the phase's new files and remove their entries from
  `index-entries.json`. The README's rows for the removed files must be removed in the same change
  or Phase 9's reconciliation check fails.
- **Whole task**: `git revert` the task's commits in reverse order. The pre-task state is the
  19-line `README.md` stub plus the single-entry `index-entries.json`, both still in history.
- **If a rollback must discard uncommitted work**: that is the one case needing a snapshot first -
  use the rollback rung in `context/contracts/recovery.md` for the exact invocation shape
  (including its out-of-scope override flag). Do not emit a bare reverting `git-snapshot.sh` as a
  routine checkpoint; for an ordinary defensive checkpoint before a large authoring phase use
  `--no-revert`, which is durable without touching the working tree.
- **If the consuming repository changes mid-task** (its books work is active): the corpus's dated
  measured markers localize the damage - the fix is to re-measure and update the dated note, never
  to rewrite a contract body.
