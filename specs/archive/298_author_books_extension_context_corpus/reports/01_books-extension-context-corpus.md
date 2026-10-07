# Research Report: Author the books extension domain context corpus

- **Task**: 298 - author_books_extension_context_corpus
- **Started**: 2026-10-03T00:00:00Z
- **Completed**: 2026-10-03T00:00:00Z
- **Effort**: ~1 research dispatch (6 parallel exploration subagents + direct measurement)
- **Dependencies**: 297 (scaffold_books_extension_routing_and_agents) — `completed`
- **Sources/Inputs**:
  - Agent-system source store: `agent-system/extensions/books/**` (the landed wiring),
    `agent-system/extensions/core/scripts/validate-context-*.sh`,
    `agent-system/extensions/core/context/standards/context-tier-semantics.md`,
    `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh`
  - Consuming repository (`/home/benjamin/Projects/Logos/Verification`): `docs/book-convention.md`,
    `docs/architecture-decisions.md`, `docs/book-pilot-record.md`,
    `docs/documentation-architecture.md`, `docs/trust-model.md`, `docs/development.md`,
    `books/schema/book-toml-v2.md`, `books/schema/book-cert-v2.md`, `books/README.md`,
    `books/lean/Books/Meta.lean`, `books/lean/lakefile.toml`, `books/tool/lakefile.toml`,
    `books/tool/docs-stage.sh`, `books/scripts/certify.sh`, `books/scripts/lint-validated-by.sh`,
    `interface/scripts/layer-lint.sh`, `full-gate.sh`, `typst/lib/book.typ`
  - Live measurement over that tree: `grep`/`find` censuses, a fresh
    `interface/scripts/layer-lint.sh` run, and verbatim reads of real `book.toml`,
    `book.cert.json`, `book.read.json` and `docs/book.md` files
  - That repository's own task artifacts: `specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`,
    `specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md`,
    `specs/TODO.md`, `specs/state.json`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, return-metadata-file.md

## Project Context

- **Upstream Dependencies**: `agent-system/extensions/books/` wiring (manifest, four agents, six
  skills, two commands, `rules/books.md`, `scripts/books-certify.sh`) — all landed and read.
  `agent-system/extensions/books/context/project/books/README.md` is the 19-line navigation stub
  this corpus replaces and extends.
- **Downstream Dependents**: `books-research-agent`, `books-implementation-agent` and their
  `--hard` pair (all four name `context/project/books/README.md` as their only domain pointer);
  `rules/books.md:69`; `skill-books-research`/`-implementation` and their hard variants;
  `EXTENSION.md:51`; `README.md:102`.
- **Alternative Paths**: none — the corpus is the only place the extension's domain knowledge can
  live, since `rules/books.md` is capped at non-negotiables and the agents carry no inline
  domain content.
- **Potential Extensions**: a `/reconcile` command and its skill (named as planned work in the
  consuming repository's own register) would consume `standards/reconciliation-contract.md`
  directly; a books verification tier at implement dispatch would consume `domain/gate-tiers.md`.

## Executive Summary

- **The corpus has a clean, unambiguous structural home and a proven size model.** Files land at
  `agent-system/extensions/books/context/project/books/{domain,patterns,standards,tools}/*.md`
  and deploy to `.claude/context/project/books/` via `provides.context: ["project/books"]`
  (already declared in `manifest.json`), which names the *directory* — no manifest edit is needed
  for new files. Comparable corpora run 4,700–5,000 lines over 24–36 files
  (`lean/context/project/lean4/`, `typst/context/project/typst/`), with individual files at
  100–380 lines and a 29–36-line `README.md` index. Target for 16 documents plus a rewritten
  README: **~3,200–3,900 lines over 17 files**.
- **The task description's technical substance is largely right but its *measured* claims are
  systematically stale, and one of its central premises is refuted.** The known-gap register's
  headline — "of 36 built module headers, 0 carry a `book_layer`, so the matrix check and the
  regex layer lint cannot yet disagree" — is false today: **188 `book_layer` lines across 155
  files, 1,003 `@[book_export]` occurrences, 27 real books across four packages, 26 of them
  carrying a `book.cert.json`**. The register must be rebuilt from measurement, not copied. A
  full staleness ledger is in Finding 3 (eleven entries).
- **The repository already owns the honesty machinery the corpus is being asked to supply, and
  the corpus should derive from it rather than invent a parallel one.**
  `docs/book-convention.md` carries a `- **Validated by**:` marker at the head of each of its 18
  decisions, in a three-form vocabulary (`none yet [-- reason]` / `partially, <instances>` /
  binding), mechanically linted by `books/scripts/lint-validated-by.sh` (802 lines, four checks,
  two blocking). `domain/known-gap-register.md` should be a faithful, dated projection of those
  18 markers plus the consuming repository's live `specs/TODO.md` register, not a fresh judgment.
- **Three of the sixteen documents describe contracts with zero live instances, and the corpus
  must say so in its own voice.** No book in the consuming repository has a Typst document;
  `typst/lib/book.typ` **cannot render a real certificate** because it reads
  `certificate.version`, `certificate.status`(`.derived`), `certificate.trust` and
  `certificate.exports`, none of which the writer emits (it emits
  `judgments.fields["book.*"]`/`["trust.*"]` and `export_ledger`). All 25 real book documents are
  Markdown (`[docs] entry = "docs/book.md"`), in three competing section skeletons. Zero real
  books carry a `book.record.json`. The certifier is **not referenced anywhere in
  `full-gate.sh`**, so the "tier chain" document 12 describes is two disjoint chains, not one.
- **The five evidence-grounded documents (12–16) have an exceptionally strong, first-hand source
  and should be written against it almost verbatim.**
  `specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` and
  `specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`
  carry the 75-of-127-minute measurement, the six collisions *with their cheapest possible
  catcher*, the 44-violations-across-five-phases finding, the exact `grep | sed` convergence
  pipeline, and the `certify.sh` closing-line misreport — all with anchors.
- **One genuine scope ambiguity needs a decision, and it is small enough to decide in planning
  rather than escalate.** `index-entries.json` sits at the extension root, outside this task's
  stated `context/project/books/**` scope, yet it is the only place the new files can be
  registered — and the dependency task that owned it is `completed`. Recommendation D2 below
  resolves it by treating registration as an inseparable part of authoring a context file.

## Context & Scope

### What was researched

Two questions, in order:

1. **Where do these files go and what must they satisfy?** The agent-system's own structural
   contract for a domain context corpus: directory convention, `index-entries.json` entry schema,
   the derived-tier/budget model, the validators and lints that will run, the deploy path, and
   the size model set by comparable corpora.
2. **What is true today about the books convention?** Each of the sixteen documents' subject
   matter was traced to one of three sources, in this priority order: the design record
   (normative but may describe what is not built), the live tree (ground truth for what runs),
   and the consuming repository's own task artifacts (measured cost). Every figure the task
   description asserts was re-measured.

### Constraints that shaped the research

- **Source store only, `context/project/books/**` only.** The wiring (manifest, agents, skills,
  commands, rules, scripts/tests) belongs to the dependency task and was read, never edited.
  Nothing under `.claude/**` is hand-authored (`rules/source-store-deploy-boundary.md`).
- **No task-number references in anything written into the source store**
  (`rules/no-task-references-in-deliverables.md`). This report is under `specs/**` and is
  exempt; the corpus files are not. Finding 6 records exactly what the lint matches.
- **Concurrency.** One sibling dispatch runs this cycle, scoped to seven `extensions/core/`
  orchestrate files. There is **zero overlap** with this task's scope. No file in this task's
  scope was touched by research (research wrote only this report and `.return-meta.json`).

### Explicit non-goals

- Authoring the corpus. This is the research phase; the output is a per-document specification a
  plan can phase.
- Changing the consuming repository. It was read-only throughout. The one command run against it
  (`interface/scripts/layer-lint.sh`) requires no build, no network and writes nothing.
- Re-litigating the books convention's design. The 18 decisions are taken as given.

## Findings

### Finding 1: the extension-side structural contract [SETTLED]

**Directory convention.** Every mature corpus uses a flat set of role directories under
`context/project/<domain>/`, with a `README.md` index at the root. Observed across the source
store: `domain/`, `patterns/`, `standards/`, `tools/`, plus occasional `templates/`,
`processes/`, `operations/`, `agents/`. The five pre-named documents (12–16) already use
`domain/`, `patterns/`, `standards/` and `tools/` — so those four suffice for all sixteen and no
fifth directory is needed.

**Size model** (measured, `wc -l` over `agent-system/extensions/*/context/project/*/`):

| Corpus | Lines | Files |
|---|---|---|
| `founder/context/project/founder/` | 8,353 | 53 |
| `present/context/project/present/` | 8,032 | 48 |
| `web/context/project/web/` | 5,664 | 24 |
| `typst/context/project/typst/` | 5,027 | 28 |
| `nvim/context/project/neovim/` | 4,982 | 24 |
| `lean/context/project/lean4/` | 4,728 | 36 |
| `books/context/project/books/` (today) | **19** | **1** |

Per-file distribution in the two closest siblings: `typst` ranges 36–359 lines (README 36);
`lean4` ranges 9–379 (README 29). **Target: 150–250 lines per document, README 60–90** (the books
README needs a 16-row navigation table, so it runs longer than the 29–36-line precedent).

**Deploy path.** `manifest.json`'s `provides.context` already reads `["project/books"]` — a
*directory*, so new files under it deploy with no manifest edit. Confirmed against the two
existing books context consumers: the loader copies the declared directory wholesale.

**Registration and the tier model** — the single most consequential structural finding.
`validate-context-budgets.sh:89-97` derives a tier from `load_when` shape, first match wins:

| Tier | Predicate | Loading behaviour |
|---|---|---|
| 1 | `always == true` | every session |
| 2 | `agents` non-empty | every dispatch of a listed agent |
| 3 | `commands` or `task_types` non-empty | every run of a listed command / every task of a listed type |
| 4 | all hooks empty | never auto-loaded; grep or explicit `Read` only |

The existing stub entry carries **both** `load_when.agents` (four books agents) **and**
`load_when.task_types: ["books"]`, which makes it **Tier 2** — eagerly loaded into every books
agent dispatch. That is correct for a 19-line navigation stub and **wrong for sixteen
150–250-line documents**: registering all seventeen at Tier 2 would inject ~3,500 lines
(~45k tokens) into every books dispatch. The corpus must therefore be **tiered deliberately**:
the README stays Tier 2; the sixteen documents go to **Tier 4 with `on_demand: true`**, reachable
through the README's navigation table (`context-tier-semantics.md`'s decision rule: set
`on_demand` iff all three arrays are empty *by deliberate design*; leaving it unset on an
all-empty entry is exactly the condition the Dead Entry Check catches).

Note that `validate-context-budgets.sh:104-115`'s `CAPS` table lists ten agents and **does not
include the books agents**, so no budget cap currently fires for them. That is an argument for
getting the tiering right by design rather than relying on the gate: the gate would not catch it.

**`index-entries.json` location.** The file is at the **extension root**
(`agent-system/extensions/books/index-entries.json`), not under `context/project/books/`. It is
therefore outside this task's stated scope glob, and it is also not in the dependency task's
owned list (`manifest.json`, `agents/`, `skills/`, `commands/`, `rules/`, `scripts/tests/`). See
Decision D2.

**Line counts are machine-maintained.** `agent-system/extensions/core/scripts/generate-context-line-counts.sh`
regenerates `line_count` in the source store; `validate-context-index.sh` warns on drift. Entries
should be written with a placeholder count and then regenerated, never hand-counted.

### Finding 2: ground truth for the books convention, measured [LANDED]

Every figure below was measured against `/home/benjamin/Projects/Logos/Verification` during this
dispatch, excluding `.lake/` and test fixtures unless stated.

**The book population** — 27 real `book.toml` manifests across four packages (plus two certify
fixtures and one Typst probe):

| Package | Books | Layered modules | `@[book_export]` | `book_requires` | `book_policy` | `book_assume` | `book_not_claimed` | `book_axioms` |
|---|---|---|---|---|---|---|---|---|
| `interface/` | 4 | 4 | 7 | 2 | 0 | 0 | 0 | 4 |
| `components/rle_codec/` | 1 | 3 | 8 | 3 | 0 | 1 | 0 | 1 |
| `components/distsys/` | 9 | 32 | 286 | 150 | 26 | 3 | 7 | 9 |
| `components/framed_channel/` | 13 | 105 | 647 | 193 | 12 | 0 | 0 | 13 |
| **total** | **27** | **144** | **948** | **348** | **38** | **4** | **7** | **27** |

`book_axioms` appears exactly once per book. Whole-repo counts including `books/lean` and the
fixture suites: 188 `book_layer` lines over 155 files, 1,003 `@[book_export]`, 356 `book_requires`.

**Layer-value usage** — eleven of the twelve values are live:
`refinement` 46, `impl` 38, `challenge` 29, `interface` 24, `laws` 22, `instances` 14,
`evidence` 7, `extraction` 3, `impl.proofs` 2, `impl.defs` 2. `instances.defs` and
`instances.proofs` are declared in the vocabulary and **unused on the real tree**.

**Certificates and records.** 26 of 27 real books carry a `book.cert.json`
(`components/framed_channel/books/ladder/` does not). **Zero** real books carry a
`book.record.json` — the only two in the tree are `books/tests/certify/fixtures/books/pt/` and
`typst/tests/book-template/probe/`. **Five** books carry a `book.read.json` (the four
`interface/books/*` plus `components/rle_codec/books/rle_codec/`).

**Status and trust, as authored.** All 27 real manifests declare `status = "draft"`. **None**
carries a `[trust]` table (an absent table means all six ground classes are `not_applicable` —
the documented honest record for a book with no trust verdict yet). 11 of 27 carry
`[provenance]`. The certifier refuses `status = "certified"` with no `--prev` certificate to bump
against, with refusal reason `stale-certified` (`books/certifier/Certify.lean:808-835`, cited from
`docs/book-convention.md:1501`).

**Documentation, as authored.** 25 of 27 declare `[docs] entry = "docs/book.md"`; two
(`components/distsys/books/{link,two_phase_commit}/`) declare `entry = "book.typ"` for a file that
does not exist. **No real book has a `book.typ`** — the only two in the tree are the library
itself (`typst/lib/book.typ`) and the test probe. The 25 Markdown documents run 16–149 lines in
**three competing section skeletons**: `What this book does / What it assumes / What could still
go wrong` (the 5 pilot books), `Scope / Exported surface / Decisions a reader needs / ...` (the
distsys family), and a thin 16–21-line stub carrying only `## Status` or no headings at all (most
of framed_channel).

**A real certificate's shape** (`interface/books/result/book.cert.json`, 2,382 bytes, read
verbatim). Top level: `schema: 2`, `serialisation_format: "dag-v2"`, `book{name,module}`,
`modules[]{name,layer,imports,meta_imports,is_module}`, `export_ledger[]`, `depends[]`,
`assumptions[]`, `not_claimed[]`, `policies[]`, `observed_layer_relation[]`, `judgments{fields,source}`,
`identity`, `interface_identity`, **`proof_identity`**, `stale: false`,
`passes: ["reverify"]`, `reserved_passes: ["meta_import_ledger","leanchecker","exported_view_replay","trust_scope"]`,
`toolchain{toolchain,githash,lean_options_seed,externals_reached}`, and a `docs` block:
`{context_pack_bytes{consumer_full,consumer_overview,documenter,maintainer}, counts{missing,orphaned,reconciled,stale}, names_resolved, per_export, tier_compile}`.

Three facts follow directly and matter for the corpus:
- There are **three** identities, not two (`interface_identity`, `identity`, `proof_identity`).
- `judgments.fields` carries exactly **seventeen keys** — `schema`, six `book.*`, six `trust.G*`,
  three `provenance.*`, `docs.entry` — with an absent authored key recorded as the literal string
  `"<absent>"`, under `judgments.source: "authored"`. This independently confirms the
  "seventeen keys" figure.
- `passes` lists one implemented pass; `reserved_passes` **names the four deferred certifier
  passes**, which the task description refers to only obliquely as "the deferred certifier
  passes".

**The may-import matrix is implemented, and findable.** `books/lean/Books/Meta.lean:139-152`
(`mayImport`), with the twelve values at `:113-115` (`layerNames`) and the tier-stripping at
`:118-121` (`baseLayer`). The module docstring at `:1-99` is itself a near-complete context
document: it states the code-module/book-module split, why the provider is a private import, the
five defence mechanisms with *what each refuses versus only reports*, and — at `:92-99` — the two
universal rules that stand outside the matrix, with the reason `book_layer` cannot enforce
Mathlib/Aeneas confinement (bridge-package-ness is not a layer fact, and confinement is a claim
about the import *closure*'s packages, not about direct imports' layers).

**A landed defence the task description lists as merely "in flight": restricted layers.**
`interface`, `laws`, `refinement`, `challenge` are **restricted**; `extraction`, `impl`,
`instances`, `evidence` are **unrestricted**; `.defs`/`.proofs` tiers inherit through
`baseLayer`. The execution-construct gate **refuses ten core command kinds** (`run_cmd`,
`run_elab`, `run_meta`, `#eval`, `#eval!`, `initialize`, `elab`, `elab_rules`, `macro`,
`macro_rules`) in a restricted layer, and is **fail-closed**: a module stating no layer is
refused (`Meta.lean:592`, `:595`). `isUnsafe`/`@[implemented_by]`/`@[extern]` refuse at the
`@[book_export]` handler in a restricted layer (`:435`), and ship again as an **advisory**
`Linter` that "cannot be otherwise" because `lintersRef` is a clearable public `IO.Ref`.

**A fresh layer-lint measurement, dated this dispatch:**

```
bash interface/scripts/layer-lint.sh interface components/framed_channel components/rle_codec components/distsys
-> [ok] layer import rule (179 modules, 733 imports, 7 exclusion rules, 2 allow-only rules;
        queue models derived: RingBuffer VecQueue; package roots: ...)   rc=0
```

All three component gates call it (`components/framed_channel/check.sh:468`,
`components/distsys/check.sh:195`, `components/rle_codec/check.sh:125`), so every
book-bearing package is in its domain.

**Tooling inventory, measured.** `books/` holds six subdirectories, not three:
`books/lean/` (package `books`; roots `Books` — one module `Books.Meta`, **771 lines** — and
`BookCert` — eleven modules), `books/tool/` (package `booksTool`; the `books-tool` `lean_exe` over
`Books.Manifest`/`EnvWalk`/`LayerCheck`, plus `docs-stage.sh` 245 lines and
`record-read-test.sh` 163 lines), `books/certifier/Certify.lean` (1,141 lines),
`books/schema/` (`book-toml-v2.md` 324, `book-cert-v2.md` 689), `books/scripts/`
(`certify.sh` 711, `lint-validated-by.sh` 802), `books/tests/` (four suites:
`manifest/run.sh` 521, `certify/run.sh` 1,338, `validated-by-lint/run.sh` 272, plus
`fixtures/probes/` with twenty probe fixtures). `books/README.md` is 210 lines.

Both lakefiles were read verbatim and confirm the explicit-globs rule and its exact failure text
(`error: Books: some modules have bad imports` / `bad import 'Books.Meta'`), and `books/lean`
declares no `require` while `books/tool` declares exactly one (`books` by path `../lean`).
`books/lean/lakefile.toml` also sets `[leanOptions] autoImplicit = false`, which is what the
certificate's `lean_options_seed: ["autoImplicit=false"]` records, and declares a `certify`
`lean_exe` whose `root`/`srcDir` point at `books/certifier/Certify.lean` — **one certifier
source, two execution paths**, with `CERTIFY_INTERPRETED=1` in `certify.sh` selecting the
interpreted fallback.

### Finding 3: the staleness ledger — where the task description must be corrected [CRITICAL]

Eleven entries. Each is a claim in the dispatch description that measurement refutes or revises.
The corpus must be written against the right-hand column.

| # | Task description says | Measurement says | Evidence |
|---|---|---|---|
| 1 | "of 36 built module headers, 0 carry a `book_layer`. So the matrix check and the regex layer lint CANNOT yet disagree" | 188 `book_layer` lines over 155 files; 144 layered modules across the four real packages; 11 of 12 layer values live | grep census; `books/README.md`'s own agreement report is the stale source and is itself out of date |
| 2 | reference implementation is "nine layer-assigned code modules, four book modules, four `book.toml` manifests, four docs entries" over `components/distsys/lean/` | 27 books over four packages; distsys alone has 9 books / 32 layered modules / 286 exports; framed_channel has 13 / 105 / 647 | Finding 2's table |
| 3 | `Books.Meta` is "413 lines" | **771 lines** | `wc -l books/lean/Books/Meta.lean` |
| 4 | `typst/lib/book.typ` is "183 lines" and "its ONLY data input is the book's `book.cert.json`" | the library reads four top-level names the writer never emits (`certificate.version`, `certificate.status`/`.derived`, `certificate.trust`, `certificate.exports`), so **no real certificate can render**; reconciling them is live research in the consuming repository | `specs/state.json`, entry 186 (`researching`), verbatim |
| 5 | `book.cert.json` → `docs/book.typ`, three tiers, `[docs] entry` | 25 of 27 real books declare `entry = "docs/book.md"`; zero real `book.typ`; the extension's own `rules/books.md:3` meanwhile mandates flattened `book.typ` beside the manifest and calls `docs/book.md` "legacy-and-held" | `grep '^entry' `; `rules/books.md` |
| 6 | "`books/schema/book-cert-v2.md`, the certificate writer, the shell driver and the acceptance suite" are NOT yet landed (certifier phases 13–23 of 23) | all four exist: `book-cert-v2.md` (689 lines), `BookCert/Writer.lean`, `books/scripts/certify.sh` (711 lines), `books/tests/certify/run.sh` (1,338 lines) | `find`/`wc -l` |
| 7 | `books/tool/approve-guarantees.sh` is "the only writer of `book.record.json`"; `books/tool/book-health.sh --json` is planned | **both are absent**. The landed record is a *different* one: `book.read.json`, six keys (`book`,`by`,`date`,`reader`,`marks{does_what,assumes_what,could_go_wrong}`), sole writer `books/tool/record-read-test.sh`, five instances on disk, and one of them records `"by": "agent"` | `find`; `interface/books/queue/book.read.json` verbatim |
| 8 | the tier chain is `lake build` → `layer-lint.sh` → `certify.sh` → `full-gate.sh` → `--recheck` | **`full-gate.sh` contains no certifier reference at all** — "its only two occurrences of the string 'certif' are both comments". The chain is two disjoint chains; nothing mechanical catches a book whose certificate stopped matching its sources | `specs/state.json`, entry 189, verbatim |
| 9 | "provider-side trust defences" are in flight | **landed**: five named mechanisms, with the refuses/reports distinction stated per mechanism, in `Books.Meta`'s own docstring | `books/lean/Books/Meta.lean:50-88` |
| 10 | the certifier's misreporting is a closing line that "can report success while an earlier stage reported SKIPPED" | the measured misreport is a **wrong count**: `[ok] 13 book(s) certified, dependencies first: <every discovered name>` prints every *discovered* book regardless of how many certified. Separately, a certifier **killed by `earlyoom`** (Crc8, ~16–18 GiB RSS, twice) logs a bare refusal line indistinguishable from a genuine refusal, because `certify.sh` carries no timing or memory instrumentation | `specs/121/summaries/02_*.md`; `specs/state.json` entries 175, 178 |
| 11 | "the matrix check and the regex layer lint run beside each other during the pilot… 4 reproduced / 4 reproduced-by-declaration / 1 not reproduced" | the 4/4/1 split is **correct and fully tabulated** in `books/README.md`, with the nine rules named (7 `LAYER_RULES` exclusions + 2 `LAYER_ALLOW_RULES`) — but the surrounding agreement report's *measured* half is stale per row 1 | `books/README.md` "Agreement with the regex layer lint" |

Two further corrections are refinements rather than contradictions:

- **The layer lint does not report a vacuous pass as vacuous.** Its success line prints
  `($N modules, $M imports, 7 exclusion rules, 2 allow-only rules)` — counts from which vacuity is
  *inferable*, never labelled. It does carry a narrower guard: a file with `import` lines from
  whose header none were parsed is a `[FAIL]` (`layer-lint.sh:50-55`). So "a vacuous pass must be
  reported as vacuous" is a **requirement the corpus states, not a behaviour it documents** — and
  the corpus must say which it is. `books/README.md` does name the vacuous-pass domain explicitly
  (10 of 116 files at the time: `components/rle_codec/lean/` 2, `components/framed_channel/tests/ladder/` 8).
- **`books-tool` has three subcommands, not two**: `validate`, `check` and `levels`
  (`docs/book-convention.md:1935`; `books-research-agent.md:17`). The landed call shapes are
  `books-tool validate <manifest> --lib <dir>` and `books-tool check --lib <dir> [--only <module>]`
  (`commands/book.md` STEP 3–4), and `--lib` is repeatable.

### Finding 4: the honesty machinery already exists, and the register should project it [DESIGN]

`docs/book-convention.md` installs, via Decision 17, a `- **Validated by**:` line at the head of
each of its 18 decisions, in a three-form vocabulary: `none yet` (optionally `-- <reason>`),
`partially, <instance text>`, or anything else (binding). `books/scripts/lint-validated-by.sh`
(802 lines) enforces it with four checks — CHECK 1 (marker presence and well-formedness) and
CHECK 2 (instance liveness: every backtick path, Lean name and bare filename in the marker line
must still resolve) are **blocking**; CHECK 3 and CHECK 4 are **advisory** heuristics over task
descriptions. `books/tests/validated-by-lint/run.sh` pins all four against eleven record
fixtures.

Current marker census (all 18 read): **two binding** (Decision 5, Decision 14), **fifteen
`partially`**, **one `none yet`** (Decision 18, with the reason recorded: the two-tier law-class
pattern exists but none of its seven mechanisms is built). Each `partially` marker already names
what is *exercised* and what is *not exercised*, and three of them name what is **contradicted**
(Decision 12's marker, for example, records that "derived display status computed once by the
certifier" is contradicted because no `status` field is written and the only renderer reads
`certificate.status.derived`, which exists only in the probe).

Alongside it, the consuming repository's live `specs/TODO.md` + `specs/state.json` carry a dated,
owner-maintained register of what is in flight. Read this dispatch:

| Entry | Status | What it tells the register |
|---|---|---|
| `178_optimize_books_gate_feedback_loop` | NOT STARTED | the cheap pre-gate verification tier does not exist |
| `189_wire_the_book_certifier_into_full_gate` | NOT STARTED | the certifier is not in the full gate; Decision 17 clause 5 has no instance |
| `188_build_the_twelve_computed_health_signals` | NOT STARTED | `book-health.sh` absent; the twelve signals have no producer |
| `186_reconcile_book_typ_certificate_reads` | RESEARCHING | the Typst library cannot render a real certificate |
| `144_document_books_in_three_tiers` | HOLD | held until the books it documents carry certificates |
| `173_convert_distsys_book_md_to_book_typ` | HOLD | held until the certifier's docs stage exists |
| `170_rename_books_to_bookkit` | NOT STARTED | a planned rename of the `books/` tooling directory |
| `164_add_a_reconcile_command` | NOT STARTED | the `/reconcile` command is planned on the agent-system side |
| `180_rule_on_the_tier_split` | NOT STARTED | the Mathlib-free-tier promise is unmeasured for the framed_channel family |
| `168_complete_the_distsys_book_gate` | PLANNING | three older distsys books still carry 16, 10 and 16 warnings |
| `175_instrument_the_book_certifier` | NOT STARTED | no timing/memory instrumentation; a killed run reads as a refusal |
| `179_refuse_vacuous_book_policy` | **completed** | the vacuous-policy refusal and its forgery probe landed |

The pilot's GO was **ratified by the repository owner on 2026-10-03** with four attached
conditions (`docs/book-pilot-record.md`), the first of which is entry 180 above.

**Design consequence**: `domain/known-gap-register.md` should be structured as (a) the 18
`Validated by` markers projected into a table with their exercised / not-exercised / contradicted
content, (b) the live in-flight register above, and (c) a dated "measured as of" header. It should
adopt the `none yet` / `partially` / binding vocabulary rather than inventing one, and it should
state its own staleness mechanism — that the authority is the marker in the design record, not
this projection.

### Finding 5: per-document source map [SPECIFICATION]

The sixteen documents, with the proposed path, the primary source, and the specific content a
planner should budget for. Paths for 12–16 are given by the dispatch; 1–11 are proposed here.

**1. `domain/layer-vocabulary-and-matrix.md`** (~220 lines). Primary: `docs/book-convention.md`
Decisions 2 (`:245-326`) and 3 (`:327-424`); implementation at `books/lean/Books/Meta.lean:113-152`.
Content: the twelve values with their live-usage counts from Finding 2; `baseLayer` tier
stripping; the `mayImport` matrix reproduced from the implementation (row-by-row, including the
`challenge` row's three conditional cells and the `*` cells' bridge-package condition); direct-
imports-only at elaboration versus the computed graph at certification; `challenge` and
`evidence` terminal; the two universal rules outside the matrix with the *reason*
`book_layer` cannot enforce confinement (`Meta.lean:92-99`). **Add** the restricted/unrestricted
split and the fail-closed execution-construct gate — this is a layer fact the dispatch's
document 1 omits entirely, and it is the most consequential layer consequence in the provider.

**2. `domain/book-toml-v2.md`** (~190 lines). Primary: `books/schema/book-toml-v2.md` (normative,
324 lines); Decision 7 (`:799-906`). Content: `schema = 2`; the `[book]`/`[trust]`/`[provenance]`/
`[docs]` tables; the seventeen keys confirmed against a real certificate's `judgments.fields`;
the fields-versus-keys distinction with the historical "twelve fields" headline named as
historical; the `status` enum and the four trust verdicts; `stale` derived never authored; the
computed-never-authored list (`[layers]`, `[exports]`, `[[depends]]`, `[external]`, `[axioms]`,
the summary = the book module's docstring, packages). **Add**, from the real manifests: an absent
`[trust]` table means all six classes `not_applicable` and is the honest record for a draft book;
`status = "draft"` on first certification because the certifier refuses `certified` with no
`--prev` (`stale-certified`); `"<absent>"` as the literal recorded value for an unauthored key.

**3. `domain/certificate-ledger-and-records.md`** (~240 lines). Primary:
`books/schema/book-cert-v2.md` (689 lines); Decisions 8 (`:907-1092`), 9, 11. Content: the
certificate sits **directly** in the book directory, never a `certificate/` subdirectory, because
the framed_channel export tooling treats every `certificate` directory as a discovery root; it is
the only input of every non-Lean tool; the full top-level key list and the seventeen-field
`export_ledger` row shape, both transcribed from the real certificate in Finding 2; `passes`
versus the four named `reserved_passes`; the `docs` block including the four `context_pack_bytes`
keys and `counts{missing,orphaned,reconciled,stale}`. Then the **two separate records**, which
the dispatch conflates: `book.record.json` (reconciliation — guarantee text hash bound to export
ledger digest, with signer and timestamp; **zero real instances**; non-digested by construction)
and `book.read.json` (the read test — six keys, sole writer `books/tool/record-read-test.sh`,
five real instances, `by` may be `agent`).

**4. `domain/identity-and-versioning.md`** (~170 lines). Primary: Decision 9 (`:1093-1213`),
Decision 11 (`:1367-1497`); `BookCert/{Cone,Serial,Identity,VersionCheck}.lean`. Content:
per-export Merkle digests over the statement cone with axiom sets; the roll-up into
`interface_identity`, `identity` and **`proof_identity`** (three, not two); chaining per export
through dependencies' certificates; `serialisation_format: "dag-v2"` and why sharing-awareness
matters (`S(crc8_step_linear)`: a measured 9,263,152,983-node unshared tree became 420,646
chars, turning a 35-minute-then-killed certification into under two minutes); the versioning rule
keyed on canonical statement serialisation with **no bump on a toolchain bump alone**; the
identity exclusions from `book-cert-v2.md`.

**5. `domain/status-and-trust-vocabularies.md`** (~160 lines). Primary: Decision 12
(`:1498-1575`); `docs/trust-model.md` (151 lines); `books/tool/Books/Manifest.lean:33-38` (the
enforced word lists). Content: the three `status` values and four verdicts, each with what it
licenses and what it forbids; the six ground classes G0–G5; a `certified` book whose record is not
fully reconciled fails the docs stage; a `draft` book only reports. **Must record** from Decision
12's own marker: the "derived display status" is *contradicted* — no `status` field is written;
and the pure-Lean G1–G3 rule and the composite-trust rule have **no checker**, while the
never-more-trusted-than-its-least-trusted-part clause *was* enforced mechanically for the first
time through the permitted-axiom set (the framed_channel composite refused 8 times with
`axiom-outside-book-axioms` until it declared the two `bv_decide` native helper axioms its parts
mint).

**6. `standards/metadata-split.md`** (~180 lines). Primary: Decision 6 (`:610-798`);
`Books.Meta`'s docstring (`:9-20`). Content: facts in Lean, judgments in TOML, everything else
computed; in a code module exactly two things (`@[book_export]` with no kind argument — kind
derived from `getOriginalConstKind?` — and one `book_layer` line); in the book module everything
else, with each command's exact syntax; all read back by `#book_ledger`; a `book_*` command in a
code module **warns and the build succeeds**. **Add** the mutual-exclusion guard (`book`,
`book_layer`, `@[book_export]` refuse each other in all three directions, each guard naming
itself) and the `book_policy` **subject-placement rule**: a policy row belongs on the book that
owns its subject, because a subject that is not a member of the certifying book resolves to
nothing and certifies as `"outcome": "holds"` with `"checked_modules": []`. That rule is
documented nowhere in the design record's Decision 4 text — Decision 4's own worked example
contradicts it — and is the single highest-severity trust finding in the evidence base.

**7. `patterns/authoring-workflow.md`** (~260 lines). Primary: the AUTHOR / BUILD-TEST / CERTIFY /
DOCUMENT narrative in the task description, re-grounded on the measured tree. Content: an
executable checklist. Authoring: licence header line 1 and `module` line 2 (structural, because a
comment parses ahead of `module`); one `book_layer` per code module; `@[book_export]` per intended
export; **added by hand** to the lakefile's explicit globs. Then the book module: a plain
(private) import of the provider, public imports of its own code modules (which is what makes a
cross-book dependency declaration resolvable), a module docstring that *is* the summary, `book
<Name>`, `book_axioms`, per-layer `book_policy`, `book_assume` with its discharging anchor,
`book_not_claimed`, `book_requires` (checked transitively against statement cones, so naming a
constant whose declaring module is in the closure is correct and sufficient). Then `book.toml` v2
and the docs entry. Build/test: the full audit list from the dispatch — clean build from empty
`.lake/` with no network and wall time recorded; zero-`sorry` census; no `native_decide`, no
search tactic, no vacuously-true definition; axiom audit against the declared budget with choice
absent and **sources distinguished from carrying declarations**; universe audit; Mathlib-freedom
audit (no require, no import, no mention, in any module or lakefile); `#book_ledger` reporting
every code module layered, the book module carrying no layer, every intended export rowed with
the right derived kind and no forged-row flag; `books-tool validate` (decodes all seventeen keys —
a stronger check than counting files); `books-tool check --lib` with zero unassigned and zero
doubly-assigned; a rebuild-isolation spot check; a declaration-inventory diff signature by
signature; `check-spdx.sh`; the regex layer lint with vacuous passes recorded as vacuous; the
task-reference lint. **Every figure recorded as LANDED, never inherited; a deviation written as a
deviation note.** **Add** the step the evidence makes mandatory: run `interface/scripts/layer-lint.sh`
at the end of any tagging phase — `lake build` never invokes it, and that omission is what let 44
violations sit across five phases.

**8. `tools/typst-template-contract.md`** (~230 lines). Primary: `typst/lib/book.typ`,
`typst/tests/book-template/run.sh`, `typst/scripts/build.sh`, Decision 17. Content: the tier and
mode inputs; the certificate-only data input loaded by the book **document** (`json("book.cert.json")`,
relative to itself) and handed in via `#show: book.with(certificate: ...)`; the mechanism reason —
a relative `json()`/`read()`/`image()` path resolves against the file whose *source text* contains
the call, so a shared library cannot read a different certificate per book; `typst/lib/phrases.toml`
as the one root-absolute read; the label mechanics (book-id prefixing from a `state()`; labelled
content and its label constructed together inside **one** `context` block, because a label built
in a separate block and placed after already-realized content silently fails to attach; every
`metadata` value carrying an explicit `kind` so a generic `typst query 'metadata'` returns
everything and the consumer filters on `.value.kind`); the repository-root compile root
(`--root .`, architecture Decision 9) through `typst/scripts/build.sh`; the package pins on Typst
0.14.2; the probe fixture and the test suite's checks; the tier-one content bar and the mechanical
prohibition lint. **This document must open by stating what is not true yet**: no real book has a
Typst document, and the library reads four top-level names the writer does not emit, so a real
certificate cannot currently render. Written any other way the document is false.

**9. `standards/reconciliation-contract.md`** (~200 lines). Primary: Decision 17
(`:2182-2728`). Content: reconciliation triggered by **certification**, never by file save or
commit; a proof-only edit changes no digest and touches no guarantee; an interface change always
does, once. The contract: inputs limited to the documenter pack (certificate + tiers one and two
+ the phrase table + the record); writes limited to the named book's document; only guarantees
whose digests changed are touched; every tier compiled and the docs stage and lints green before
finishing; the record, `book.toml`, approvals and book module **never** edited; the summary names
each guarantee touched with old and new digest. Agents write prose, **people write records** — the
command prints the signing invocation and never runs it. **Add** the distinction the measured tree
forces: the *approval* record (`book.record.json`) is people-written and has no writer script yet;
the *read-test* record (`book.read.json`) has a landed sole writer and one instance records
`"by": "agent"`. And record that the docs stage exists in a split form —
`books/tool/docs-stage.sh` measures the document and file pack and emits JSON on stdout (never
committed), and the certifier combines it with the three inputs only it has; a non-tiered Markdown
document is stat'd once and reported under both tier keys with `non_tiered` true and
`tier_compile: "unknown"` rather than a fabricated `ok`; and **absent documentation is not a
finding** (clause 4), because per-book content is held until certificates exist.

**10. `tools/tooling-inventory.md`** (~230 lines). Primary: `books/README.md` (210 lines), both
lakefiles, the four test suites. Content: `books/` is a tooling directory, not a component —
nothing there is digested, carries a certificate, or is depended on by a component gate. Per
piece: what it reads, what it writes, and whether the extension **consumes** it or merely names
it. The three authoring rules under `books/` (header within the first three lines and the comment-
before-`module` order; explicit per-module globs and never `Books.+`, with the exact failure text;
fixture packages using roots distinct from `Books`). Why `BookCert` lives in the provider package
(Decision 10: imports resolve structurally under `lake env lean` in any consumer's workspace — no
`LEAN_PATH` surgery, no per-consumer lakefile edit, no generated `lean_lib`) and why
`Certify.lean` is a non-`module` *script* (a `module` library cannot reach another package's
private `.olean` level, since `import all` is same-package only, and the exported level hides the
theorem kinds and docstrings the certifier needs). Then the repo-side documentation machinery to
know about and **not duplicate**, with `typst/manual/generated/` marked every-file-generated. Add
the two `books/tool` shell scripts (`docs-stage.sh`, `record-read-test.sh`) and the
`validated-by-lint` suite, which the dispatch's inventory omits.

**11. `domain/known-gap-register.md`** (~230 lines). Primary: the 18 `Validated by` markers; the
consuming repository's live register; Finding 3's ledger. Structure per Finding 4. **Must not**
reproduce the dispatch's register text, four of whose six bullets are stale.

**12. `domain/gate-tiers.md`** (~240 lines). Primary:
`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` (325 lines).
Content: per tier — what it checks, what it does **not** check, and the cheapest tier that catches
each error class. `lake build`: compiles; runs the elaboration-time matrix check over direct
imports and the execution-construct gate; invokes neither the layer lint nor the certifier nor the
Comparator rooms. `interface/scripts/layer-lint.sh`: 9 rules over `.lean` *sources*; no build, no
network, no toolchain; cannot see the computed graph; 179 modules / 733 imports in the measured
run. `books/scripts/certify.sh`: the per-export ledger, `reverify`, computed `depends`, the
identities, the version check — and an **advisory** shake stage that reports SKIPPED because
`lake shake` refuses non-`module` packages on the pin. `full-gate.sh`: a route resolver and
consent-gating launcher around a component's `check.sh` (framed_channel's is 1,669 lines);
**contains no certifier reference**. `--recheck`: the independent Comparator/kernel-replay legs,
prebuilt route only. The motivating measurement, stated plainly: **44 layer violations sat
undetected across five tagging phases that all reported green on `lake build`**, because
`lake build` invokes none of the above — and **there is today no verification tier between
`lake build` and the full gate**; closing that gap is named, dated and NOT STARTED in the
consuming repository's register. Plus the vacuous-pass rule from Finding 3's refinement.
**Carry the source report's own caveat**: every quantitative claim is from one dispatch on one
component family and the diagnostics phase has not run.

**13. `patterns/warning-driven-convergence.md`** (~150 lines). Primary:
`specs/121/summaries/02_framed-channel-book-family-summary.md`. Content: the loop shape, verbatim —

```
grep -oP "book \`X\` depends on \`\K[^\`]+" | sort -u | sed 's/^/book_requires /'
```

— which produced **179 `book_requires` lines with zero guesses** and converged to zero on the next
run. Why the warning stream is the correct oracle: every `book-requires-undeclared` warning names
the exact missing export, so the compiler, not a human reading the source, is the authority; the
termination condition is a run with zero such warnings. Generalize to the second instance in the
evidence base: `[REFUSE] axiom-outside-book-axioms` names both the axiom and the reaching
declaration, which is what let eight composite refusals identify exactly two `bv_decide` native
axioms to declare. Record that `framed_channel` now carries 193 such lines (the 179 are the loop's
output, not the current count), and that a `--emit-requires` certifier mode would remove the loop
entirely and is named but unbuilt.

**14. `patterns/gate-collision-ledger.md`** (~210 lines). Primary: the same two artifacts.
Content: the measured cost — one implement dispatch spent **75 of 127 minutes in a single phase**
(59% of the dispatch; 262 tool calls; the five phases doing the task's stated work took 33 minutes
between them), and **five of six collisions were discoverable only by running the ten-minute
fail-closed full gate** (four `full-gate.sh --yes` runs plus two `--recheck` runs, each failing on
something different). Then the six rows, each symptom / root cause / fix / cheapest possible
catcher:

| # | Symptom | Root cause | Cheapest catcher |
|---|---|---|---|
| 1 | 12 `book_policy` rows certified `"holds"` with `checked_modules: []`; a deliberately violated probe certified clean | the policy subject was not a member of the certifying book; the task description, the plan **and Decision 4's own worked example** all placed the rows wrongly | `checkPolicies` itself (Lean) — now landed |
| 2 | 44 `Books.Meta` violations surfaced at the family's first full-gate run, after five green-on-`lake build` phases | both allow-only rules refuse `Books.Meta` — the import without which `book_layer` does not exist | `layer-lint.sh` (already exists, fast) |
| 3 | Exclusion 6 refused the composite's import of its own `evidence`-layer member | Decision 5 *requires* that import; three of the nine rules have no concept of a book module | `layer-lint.sh` |
| 4 | the execution-construct gate refused a generated `lean/.hashgen/Gen.lean` on gate run 2 of 4 | the gate's domain is "every module whose import closure contains `Books.Meta`", and that set is not enumerable | an import-closure lister (does not exist) |
| 5 | a stale `set_option warn.sorry false` broke `check.sh`'s sorry count | the workaround was correct when written and became wrong silently when `certify.sh` was fixed; 23 comment blocks recorded *why* but not *when it would stop being needed* | an expiry annotation on the workaround |
| 6 | `require books` broke the Comparator clean rooms two independent ways (a Lake configuration error, then `permission denied (error code: 13)` from inside a sandbox) | a local-path require is reachable in a room only if its sources are digested **and** its path matches a hand-written per-config regex **and** it has a landrun grant in two separate places | a lakefile-vs-room staging check |

Close with the adjacent finding the ledger exists to pre-empt: adding one local-path `require`
obliged **six edits across three files**, none referenced from the lakefile and none checked by
anything until the gate ran.

**15. `standards/forgery-probe-discipline.md`** (~160 lines). Primary: `books/tests/manifest/run.sh`
and `books/tests/manifest/fixtures/probes/` (twenty probe fixtures, measured). Content: the rule —
every gate predicate gets a forgery probe, and a gate predicate shipped without one is a
**reviewable defect**, not a gap to be noted. The grounding instance is collision 1: a
deliberately violated `book_policy` probe certified **clean** at zero refusals, and nothing in the
certificate, the log or `DEPENDS.md` distinguished "checked and held" from "checked nothing". It
was caught only because the plan carried an explicit verification line — "prove the assertions are
live, not vacuous by construction". Generalize from the landed probe family, which is richer than
the dispatch's FORGE-A..D framing: `ForgeBook`, `ForgeBookExport`, `ForgeBookReverse`,
`ForgePlain` (forged rows), `HijackRunCmd`, `HijackUnrestricted` (the execution gate),
`TrustScopeAdmit`, `TrustScopeExport`, `TrustScopeImplBy`, `TrustScopeLint` (the trust-scope
checks, with the admit case as the complementary probe), `PolicyVacuous`, `CodeModuleFact`,
`LayerLate`, `BadAnchor`, `AttrImported`, `SilenceLinter`, `GateFallThrough`, `OwnBookRequires`,
`WfLedger`, `FgLedger`. State the pattern each probe pair instantiates: a refusal probe **and** a
complementary admit probe, so a probe that silently never runs is itself detectable.

**16. `tools/certify-guide.md`** (~190 lines). Primary: `books/scripts/certify.sh` (711 lines),
`books/certifier/Certify.lean` (1,141 lines), `commands/certify.md`, plus the measured economics.
Content: **component-root scoping is mandatory** — a repository-root run discovers 22 books and
fails the pre-launch check on a Typst fixture (`Probe`, whose book module is under no package
root) and a stale module; "nothing documents this". **Run `--check` first**: it surfaced every
book module's freshness, the reader budget
(`12582 MiB (MemAvailable 14630 MiB - 2048, floor 6144)`) and the exact per-book
`--extra-pkg-dir` list in ~90 seconds, which is what made `--no-build` usable instead of 1,803
build jobs per run. **`--no-build` economics**: use only when the tree is known current; note that
`certify.sh` builds every *discovered* book's module targets **even under `--only`**, so an
unrelated warning anywhere in the tree can abort a narrowly scoped run. The full landed flag set
from `commands/certify.md`: `--no-build`, `--no-shake`, `--no-write`, `--only NAME`, `--check`,
plus `--prev` and the acceptance-suite-only `--graph-from` (refused by the extension's wrapper).
**The misreporting closing line, stated precisely**: `[ok] N book(s) certified, dependencies
first: <names>` prints every *discovered* book regardless of how many certified — so the closing
line warrants that the driver completed, not that N certificates were written; cross-check
`book.cert.json` files on disk. And the second, worse misreport: `certify.sh` carries no timing or
memory instrumentation, so a run killed by `earlyoom` (measured: `FramedChannelAeneas.Book.Crc8`
at ~16–18 GiB RSS, twice) logs a bare `!! book 'X' was REFUSED` with no `[REFUSE]` detail lines,
visually **indistinguishable from a genuine refusal**. Also record the advisory shake stage
(SKIPPED, rc never propagated) and the reader mechanics: a reader script run under
`lake env lean` inside the certified package's workspace works at the `.private` olean level,
where `loadExts := true` after `enableInitializersExecution` is mandatory and silent when
omitted; `CERTIFY_INTERPRETED=1` selects the interpreted certifier instead of the compiled
`certify` exe.

### Finding 6: the lints and validators that will run against the new files [CONSTRAINTS]

- **Task-reference lint** (`scripts/check-task-references.sh` repo-wide; `hooks/validate-no-task-references.sh`
  write-time, blocking). `TASK_PATTERN` is `\b[Tt]asks?([[:space:]]+#?|[-_#])[0-9]+(-[0-9]+)?\b`
  and `PHASE_PATTERN` is the task-qualified compound form only; `is_exempt_path` exempts
  `specs/*` and `*/specs/*` and **nothing else**. The corpus is under `agent-system/**` and is
  **not exempt**. Consequence: cite the consuming repository's evidence by **path**
  (`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` contains no
  match, because the digits are not preceded by the token `task`), never as "task 178". A bare
  `Phase 12` with no adjacent task token is deliberately not matched and is safe.
- **`validate-context-index.sh`** (193 lines): JSON syntax; every entry's `path` exists;
  required fields present; `line_count` approximately accurate (warning); `domain` in
  `core|project|system`; deprecated entries resolve. It validates index → file, so a context file
  with **no** entry is not caught here.
- **`validate-context-budgets.sh`** (471 lines): derives the tier, sums per-agent token loads
  against `CAPS`, runs a Double-Loading Check and a Dead Entry Check. The books agents are not in
  `CAPS`, so no cap fires — but the Dead Entry Check **does** fire on an all-hooks-empty entry
  lacking `on_demand: true`. Every Tier 4 entry must carry it.
- **`check-extension-docs.sh`** (1,572 lines). Its Rule E
  (`check_referenced_scripts_declared`) hard-fails on any bare `<name>.sh` token in
  agents/skills/commands/`README.md`/`EXTENSION.md` that no extension declares in
  `provides.scripts`/`provides.hooks`. That rule is why `scripts/books-certify.sh` exists at all
  (its own header says so). **It is scoped to those five doc locations, not to `context/`** — so
  the corpus may name `certify.sh`, `layer-lint.sh`, `check-spdx.sh`, `docs-stage.sh` and the rest
  freely. This must be confirmed before authoring; if Rule E does reach `context/`, every one of
  documents 10, 12 and 16 would trip it, and the mitigation is to name consuming-repository
  scripts with a path prefix (`books/scripts/certify.sh`) rather than bare.
- **Emoji/encoding policy** and the box-drawing guide apply (`CLAUDE.md`); the corpus uses plain
  ASCII punctuation and no emoji.
- **Plain-backtick pointers, never eager `@`-imports** for cross-file references inside the
  corpus — the system-wide rule, restated in `CLAUDE.md`'s Important Notes.

## Decisions

- **D1 — Four role directories, seventeen files.** `domain/` (6), `patterns/` (3), `standards/`
  (3), `tools/` (3), plus a rewritten `README.md` index. Paths for documents 12–16 are taken
  verbatim from the dispatch; paths for 1–11 are as proposed in Finding 5. Note for the record
  that the originating recommendation in the consuming repository proposed
  `patterns/gate-tiers.md`; the dispatch's `domain/gate-tiers.md` governs.
- **D2 — `index-entries.json` registration is part of authoring, and in scope.** The file sits at
  the extension root, outside the literal `context/project/books/**` glob, and the dependency
  task that owned the extension root is `completed`. Leaving seventeen context files unregistered
  would make them invisible to the index, to `validate-context-index.sh` and to every discovery
  path — the corpus would exist on disk and nowhere else. The edit is additive (seventeen entries
  replacing one), touches no other extension's file, and collides with no sibling's scope. **This
  is a decision taken in research, not a user decision**: the artifacts determine it, since an
  unregistered corpus does not satisfy the task's own purpose. It should be called out explicitly
  in the plan as a declared out-of-glob edit with its one-line justification.
- **D3 — Tier the corpus deliberately: README at Tier 2, the sixteen documents at Tier 4 with
  `on_demand: true`.** Registering all seventeen at Tier 2 would inject roughly 3,500 lines into
  every books dispatch. The README's navigation table is the discovery mechanism.
- **D4 — Write against measurement, with the design record as the normative frame.** Every figure
  in the corpus carries a "measured" marker and a date; no figure is inherited from the task
  description or from `books/README.md`'s agreement report, both of which are stale (Finding 3).
  Where the design record describes something unbuilt, the corpus says so in the same breath.
- **D5 — Derive the known-gap register from the `Validated by` markers, and adopt their
  vocabulary** (`none yet [-- reason]` / `partially, <instances>` / binding) rather than inventing
  a parallel scheme. The register states that the markers in the design record are the authority
  and that the register is a dated projection.
- **D6 — Documents 8, 9 and the Typst half of document 7 open with what is not true yet.** No
  real book has a Typst document; the library cannot render a real certificate; zero real books
  carry a `book.record.json`. A document that describes these contracts as operative is false, and
  the extension's own research agent is instructed never to assume a finished certifier.
- **D7 — Cite by durable anchor and never by task number.** File paths, `file:line`, decision
  numbers, script names, and the consuming repository's `specs/<dir>/...` artifact paths (which
  contain no lint match). This satisfies `rules/no-task-references-in-deliverables.md` without
  losing the evidence trail.
- **D8 — Record the `books/` → `bookkit/` rename as a known, dated risk in the register**, and
  write path citations so a rename is a mechanical find-and-replace: always the full path
  (`books/scripts/certify.sh`), never a bare directory reference standing alone.

## Recommendations

Ordered as a plan. Each phase is one agent run producing 2–4 files, which keeps every phase inside
the 100–500-line output band and lets the corpus land incrementally and green.

1. **Phase 1 — The spine (documents 1, 6, 11 + README).** `domain/layer-vocabulary-and-matrix.md`,
   `standards/metadata-split.md`, `domain/known-gap-register.md`, and the rewritten `README.md`
   navigation index. These three are the files every other document points back to, and the
   register has to exist early so later documents can defer to it rather than each carrying their
   own caveats. Verify: the README's navigation table names all sixteen eventual files and is
   updated at the end of every later phase.
2. **Phase 2 — The authored and computed artifacts (documents 2, 3, 4, 5).**
   `domain/book-toml-v2.md`, `domain/certificate-ledger-and-records.md`,
   `domain/identity-and-versioning.md`, `domain/status-and-trust-vocabularies.md`. Transcribe the
   real certificate's key list and the real manifests' conventions; do not paraphrase the schema
   documents' enumerations.
3. **Phase 3 — The evidence-grounded five (documents 12, 13, 14, 15, 16).** `domain/gate-tiers.md`,
   `patterns/warning-driven-convergence.md`, `patterns/gate-collision-ledger.md`,
   `standards/forgery-probe-discipline.md`, `tools/certify-guide.md`. Source material is
   first-hand and quotable; this is the highest value-per-line phase and the least likely to
   require fresh investigation. Carry the source report's single-data-point caveat into
   `domain/gate-tiers.md` explicitly.
4. **Phase 4 — Workflow and tooling (documents 7, 10).** `patterns/authoring-workflow.md`,
   `tools/tooling-inventory.md`. The workflow document should be written last among the
   process documents so it can point at the gate-tier and convergence documents rather than
   restating them.
5. **Phase 5 — The documentation contracts (documents 8, 9).**
   `tools/typst-template-contract.md`, `standards/reconciliation-contract.md`. Both require the
   not-yet-true framing of D6, and document 8's measured half should be re-verified against
   `typst/lib/book.typ` at authoring time, because the reconciliation of its four certificate
   reads is live research in the consuming repository and may land first.
6. **Phase 6 — Registration and validation.** Seventeen `index-entries.json` entries per D2/D3;
   run `generate-context-line-counts.sh` to fill `line_count`; then
   `validate-context-index.sh`, `validate-context-budgets.sh`, `check-extension-docs.sh`,
   `check-task-references.sh`. Confirm `check-extension-docs.sh` Rule E's scope **before** Phase 3
   rather than after, since documents 10, 12 and 16 are the ones at risk (Finding 6).

Two preconditions worth doing in Phase 1 rather than discovering later:

- **Confirm Rule E's document scope.** One grep of `check-extension-docs.sh` for how
  `check_referenced_scripts_declared` selects its inputs. If it reaches `context/`, switch every
  consuming-repository script citation to a path-prefixed form.
- **Re-measure before writing each phase's figures.** The consuming repository is under active
  development (one books-related entry moved to `completed` and three are `researching` as of this
  dispatch), so a figure measured in Phase 1 may be stale by Phase 5. The register's dated
  "measured as of" header is the mitigation.

## Risks & Mitigations

- **Risk: the corpus is stale the day it lands.** Four of six bullets in the dispatch's own
  known-gap register were already stale when written, and the consuming repository's
  `books/README.md` agreement report is stale too. *Mitigation*: D4 and D5 — every figure dated
  and marked measured; the register a declared projection of the `Validated by` markers, with the
  markers named as the authority. A future refresh is then a re-projection, not a re-reading.
- **Risk: the `books/` → `bookkit/` rename invalidates every path citation.** The rename is a
  live, NOT STARTED entry in the consuming repository's register. *Mitigation*: D8 — full paths
  only, so the rename is a mechanical replacement; and the register names the rename as a pending
  change to the corpus's own citations.
- **Risk: document 8 is obsoleted mid-authoring.** The reconciliation of `typst/lib/book.typ`'s
  four certificate reads is `researching` right now, and resolving it changes the library.
  *Mitigation*: Phase 5 last; re-verify at authoring time; write the contract as the *design*
  contract plus a dated measured-state note, so only the note needs updating.
- **Risk: tiering mistake silently inflates every books dispatch.** The budget gate does not cover
  the books agents, so an all-Tier-2 registration would not be caught mechanically.
  *Mitigation*: D3, plus an explicit Phase 6 verification step that reads back the derived tier of
  each new entry.
- **Risk: the five evidence documents over-generalize from one dispatch.** Every quantitative
  claim in the source report comes from one implement dispatch on one component family, and the
  diagnostics work that would reproduce it is NOT STARTED. *Mitigation*: carry the source's own
  caveat verbatim into `domain/gate-tiers.md` and `patterns/gate-collision-ledger.md`; state
  measured-once rather than measured.
- **Risk: scope creep into the wiring.** Several findings suggest wiring changes (a books
  verification tier, a `/reconcile` command, Rule E handling). *Mitigation*: none of them is in
  scope; they are recorded as Context Extension Recommendations and as register entries, and the
  one out-of-glob edit this task does take (D2) is declared and justified.
- **Risk: a sibling dispatch's edits are mistaken for a regression.** One sibling runs this cycle
  on seven `extensions/core/` orchestrate files. *Mitigation*: zero scope overlap; per the
  territory contract, re-read before editing, stage only this task's own hunks with an explicit
  file list, and never use the reverting default mode of the snapshot script.

## Context Extension Recommendations

- **Topic**: Obligations of a local-path `require` in a multi-package verification repository.
  **Gap**: Adding one `require` obliged six edits across three files, none referenced from the
  lakefile and none checked by anything until a ten-minute gate ran; the discovery path for all
  six was a failing gate. This is adjacent to document 14 but is a distinct checklist.
  **Recommendation**: a seventeenth corpus document,
  `patterns/local-path-require-obligations.md`, or a named section inside
  `patterns/gate-collision-ledger.md`. Not in this task's sixteen; recorded for a follow-up.
- **Topic**: The `book_policy` subject-placement rule.
  **Gap**: The rule — a policy row belongs on the book that owns its subject — is documented
  nowhere in the design record's Decision 4 text, and Decision 4's own worked example contradicts
  it. Three independent sources specified it the same wrong way.
  **Recommendation**: state it prominently in `standards/metadata-split.md` (document 6) and
  cross-reference it from `standards/forgery-probe-discipline.md`, since it is that document's
  grounding instance.
- **Topic**: Enumerating the execution-construct gate's domain.
  **Gap**: The gate governs "every module whose import closure contains `Books.Meta`", and there
  is no script, manifest or document that lists that set. It was called "the single most useful
  missing tool" by the dispatch that hit it.
  **Recommendation**: record it as a named gap in `domain/known-gap-register.md` and as a
  checklist caution in `patterns/authoring-workflow.md`.
- **Topic**: The agent-system's own `check-extension-docs.sh` Rule E scope.
  **Gap**: Whether Rule E's bare-`<name>.sh` requirement reaches `context/` files is not stated in
  the extension-development guide, and it materially constrains how three of these documents can
  cite consuming-repository scripts.
  **Recommendation**: once determined, add one sentence to
  `context/guides/extension-development.md`. Outside this task's scope; recorded for a follow-up.

## Appendix

### Measurement commands used

All run read-only against `/home/benjamin/Projects/Logos/Verification`, excluding `.lake/`:

- Book population: `find . -name book.toml -not -path '*/.lake/*'`, with `grep -v '/tests/'` for
  the real set; the same for `book.cert.json`, `book.record.json`, `book.read.json`, `book.md`,
  `book.typ`.
- Annotation census: `grep -rn 'book_layer' --include='*.lean'`, `grep -rn '@\[book_export\]'`,
  and `grep -rn '^book_requires'` / `'^book_policy'` / `'^book_assume'` / `'^book_not_claimed'` /
  `'^book_axioms'`, each filtered per package root.
- Layer-value distribution: `grep -rhno 'book_layer [a-z.]*' --include='*.lean' | sed 's/^[0-9]*://' | sort | uniq -c`.
- Authored-field census: `grep -h '^status'`, `grep -c '^\[trust\]'`, `grep -l '^\[provenance\]'`,
  `grep -h '^entry'` over the 27 real manifests (anchored patterns, because the manifests'
  comments mention `[trust]` and `[provenance]` in prose).
- Live gate measurement: `bash interface/scripts/layer-lint.sh interface components/framed_channel components/rle_codec components/distsys`
  (no build, no network, writes nothing).
- Corpus size model: `wc -l` over `agent-system/extensions/*/context/project/*/**.md`.

### Key anchors, by subject

| Subject | Anchor |
|---|---|
| the twelve layer values | `books/lean/Books/Meta.lean:113-115` (`layerNames`) |
| tier stripping | `books/lean/Books/Meta.lean:118-121` (`baseLayer`) |
| the may-import matrix | `books/lean/Books/Meta.lean:139-152` (`mayImport`) |
| the two universal rules outside the matrix | `books/lean/Books/Meta.lean:92-99` |
| the five provider defences, refuses vs reports | `books/lean/Books/Meta.lean:50-88` |
| restricted layers / the execution-construct gate | `books/lean/Books/Meta.lean:58-60`, `:592`, `:595` |
| the trust-scope refusal at `@[book_export]` | `books/lean/Books/Meta.lean:435` |
| explicit globs, with the exact failure text | `books/lean/lakefile.toml`, `books/tool/lakefile.toml`, `books/README.md` |
| why `BookCert` lives in the provider package | `books/lean/lakefile.toml` (the `BookCert` comment block); `books/README.md` |
| the vacuous-policy predicate | `books/lean/BookCert/Writer.lean:183-201` (`checkPolicies`) |
| judgments copied with `source: authored` | `books/lean/BookCert/Writer.lean:264-270` |
| the `stale-certified` refusal | `books/certifier/Certify.lean:808-835` |
| the enforced status/verdict word lists | `books/tool/Books/Manifest.lean:33-38` |
| manifest shape/vocabulary/name-equals-book checks | `books/tool/Books/Manifest.lean:150-170`, `:200-221` |
| the docs stage's pack measurement and the non-tiered case | `books/tool/docs-stage.sh:14-40` |
| the `Validated by` marker vocabulary and its lint | `books/scripts/lint-validated-by.sh:1-45` |
| the regex layer lint's success line and silent-parser guard | `interface/scripts/layer-lint.sh:50-55`, `:71` |
| the nine rules' 4/4/1 disposition against the matrix | `books/README.md`, "Axis 1 — per rule" |
| the named vacuous-pass domain | `books/README.md`, "Axis 2 — per module" |
| the layer lint's three call sites | `components/framed_channel/check.sh:468`, `components/distsys/check.sh:195`, `components/rle_codec/check.sh:125` |
| the certify driver's flag set | `agent-system/extensions/books/commands/certify.md` (Options table) |
| the reserved-flag refusal in the extension wrapper | `agent-system/extensions/books/scripts/books-certify.sh` (header) |
| the derived-tier rule table | `agent-system/extensions/core/scripts/validate-context-budgets.sh:89-97` |
| the `on_demand` decision rule | `agent-system/extensions/core/context/standards/context-tier-semantics.md` |
| the task-reference patterns | `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` |

### Evidence artifacts in the consuming repository

- `specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` (325 lines)
  — the six collisions with cheapest catchers, the 75/127 timing table, the verification-tier gap,
  the diagnosis-quality defects, and its own "this is a seed, not a diagnosis" caveat.
- `specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`
  — the first-hand retrospective: what helped, what got in the way, what was expected and absent,
  eleven recommendations with uncertainty flagged.
- `docs/book-pilot-record.md` (808 lines) — the pilot's measurements and its GO, ratified by the
  repository owner on 2026-10-03 with four attached conditions.
- `docs/documentation-architecture.md` (715 lines) — the repo-side documentation machinery whose
  scripts document 10 must name without duplicating.
- `specs/TODO.md` and `specs/state.json` — the live, dated in-flight register projected in
  Finding 4.
