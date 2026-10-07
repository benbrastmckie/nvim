# Implementation Summary: Task #298

- **Task**: 298 - Author the books extension domain context corpus
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T19:40:20Z
- **Completed**: 2026-10-03T20:30:00Z
- **Effort**: ~50 minutes (one dispatch, nine phases)
- **Dependencies**: 297 (scaffold_books_extension_routing_and_agents) - `completed`
- **Artifacts**: plans/01_books-context-corpus.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Authored the sixteen-document domain context corpus for the `books` extension under
`agent-system/extensions/books/context/project/books/`, replaced the 19-line navigation stub with
an 84-line navigation index, and registered all seventeen files in
`agent-system/extensions/books/index-entries.json` with deliberate Tier 2 / Tier 4 tiering.
**3,483 lines over 17 files**, inside the research report's 3,200-3,900-line target band.

Every quantitative claim in the corpus was re-measured against the Logos/Verification tree at git
`7281c81` on 2026-10-03 and carries a date, rather than being inherited from the dispatch
description -- whose own measured claims were systematically stale. All nine phases are
`[COMPLETED]`, every plan checklist item is checked, and every mechanical gate that reaches these
files is green.

## What Changed

All paths relative to `agent-system/extensions/books/`.

- `context/project/books/README.md` - rewritten from a 19-line stub into an 84-line navigation
  index: a 16-row table with a "read this when" per document, three reading orders by task, and
  the corpus's own conventions
- `context/project/books/domain/known-gap-register.md` - created, 275 lines. The eighteen
  `Validated by` markers projected into a table, thirteen named gaps (B1-B13) with measurements,
  and the live in-flight register
- `context/project/books/domain/layer-vocabulary-and-matrix.md` - created, 230 lines
- `context/project/books/domain/book-toml-v2.md` - created, 187 lines
- `context/project/books/domain/certificate-ledger-and-records.md` - created, 275 lines
- `context/project/books/domain/identity-and-versioning.md` - created, 237 lines
- `context/project/books/domain/status-and-trust-vocabularies.md` - created, 163 lines
- `context/project/books/domain/gate-tiers.md` - created, 194 lines
- `context/project/books/patterns/authoring-workflow.md` - created, 213 lines
- `context/project/books/patterns/warning-driven-convergence.md` - created, 174 lines
- `context/project/books/patterns/gate-collision-ledger.md` - created, 198 lines
- `context/project/books/standards/metadata-split.md` - created, 180 lines
- `context/project/books/standards/forgery-probe-discipline.md` - created, 171 lines
- `context/project/books/standards/reconciliation-contract.md` - created, 231 lines
- `context/project/books/tools/tooling-inventory.md` - created, 213 lines
- `context/project/books/tools/typst-template-contract.md` - created, 244 lines
- `context/project/books/tools/certify-guide.md` - created, 214 lines
- `index-entries.json` - single stub entry replaced by seventeen entries
- `EXTENSION.md` - one sentence (line 51): the corpus is no longer "a separate, dependent task"
- `README.md` - two sentences (lines 33, 102): same correction

## Decisions

- **The declared out-of-glob edit (plan D2): `index-entries.json`.** It sits at the extension
  root, outside this task's stated `context/project/books/**` scope and outside the dependency
  task's owned list. Leaving seventeen context files unregistered would make them invisible to the
  index and to every discovery path -- the corpus would exist on disk and nowhere else. The edit is
  **additive**, touches no other extension's file, and collided with no sibling's declared scope.
- **Tiering verified by derivation, not by inspection (plan D3).** `validate-context-budgets.sh`
  reports `Tier 2: 1, Tier 4: 16`, `Dead entries ... 0 -- OK`, `Violations: 0`. This mattered
  because the books agents are **absent** from that script's `CAPS` table, so an all-Tier-2
  registration would have injected ~3,500 lines into every books dispatch and **fired no cap**.
  The derived-tier read-back was the only real check available.
- **Written against measurement, not against the dispatch description.** All eleven entries of the
  research report's staleness ledger are corrected in the corpus. The largest: the dispatch's
  headline gap claim ("of 36 built module headers, 0 carry a `book_layer`") is refuted -- measured
  **175** anchored `^book_layer ` lines, 139 of them in the four real book-bearing packages. Other
  corrections: `Books.Meta` is **771** lines not 413; `typst/lib/book.typ` is **462** lines not
  183; the export-ledger row has **sixteen** keys not seventeen; all four "not yet landed"
  certifier artifacts exist; `book.record.json` and `book.read.json` are **two different
  artifacts** with different writers and different instance counts (zero and five).
- **Line-band overruns declared rather than absorbed.** Fourteen of sixteen documents are inside
  the 150-250 band. `domain/certificate-ledger-and-records.md` (275) and
  `domain/known-gap-register.md` (275) are justified: the first carries six mandated enumerations
  in one document, the second carries an eighteen-row marker table plus thirteen gap rows plus the
  live register. Both were trimmed twice by compressing prose, with **no enumeration dropped** --
  cutting further would mean paraphrasing an enumeration, which the plan's Standing Rule 8 forbids.
- **One non-ASCII character retained deliberately**: the Lean `->` arrow in the verbatim
  `baseLayer` transcription in `domain/layer-vocabulary-and-matrix.md:50`. It is inside a fenced
  `lean` block and is the actual source syntax; replacing it would make the transcription wrong.
  The emoji policy forbids decorative Unicode, which this is not. One genuine violation (a `...`
  ellipsis in a table) was found and fixed.

## Plan Deviations

- **Every `agent-system/extensions/core/scripts/` gate invocation the plan names** was run from
  the **deployed** `.claude/scripts/` copy instead. The source-store copies of
  `validate-context-budgets.sh`, `check-extension-docs.sh` and `check-task-references.sh` **refuse
  to run** from `agent-system/extensions/core/scripts/` with an explicit error ("must run from a
  deployed scripts/ tree ... where `../..` resolves to a bogus repo root"). The plan's invocations
  as written cannot execute; no gate was skipped.
- **Phase 2** altered: layer-value counts re-measured lower than the plan's Scope Hypothesis
  (`impl` 36 not 38, `challenge` 23 not 29, `laws` 20 not 22, `impl.defs`/`impl.proofs` 1 each not
  2; 139 layered modules in the four real packages, not 144). Written as measured.
- **Phase 3** altered: the export-ledger row is **sixteen** keys, not the seventeen the plan's
  hypothesis cites. The `stale-certified` refusal is at `books/certifier/Certify.lean:978-1003`,
  not `:808-835`.
- **Phase 4** altered: `docs/trust-model.md` is **not** the source for the six G0-G5 ground
  classes -- it states the component-level trust model (badges, platform matrix, recheck legs). The
  ground classes came from Decision 12 and the enforced word lists from
  `books/tool/Books/Manifest.lean:33-38`.
- **Phase 6** altered: the certify driver carries `--no-docs-stage`, which the extension's
  `commands/certify.md` Options table does **not** list (grep count 0). The document names the
  driver's help block as the authority on flags and states the discrepancy.
- **Phase 7** altered: the reference-implementation scale re-measured at a different order of
  magnitude from the dispatch's "nine modules, four books" -- 27 real books tree-wide.
- **Phase 8** altered: `typst/lib/book.typ` at 462 lines (not 183), with the four diverging
  certificate reads **re-verified as still present** by grep with line anchors. `cetz 0.3.4` is
  recorded as the declared pin but **not** as a measured import, because the only preview imports
  found anywhere in `typst/lib/` and `typst/manual/` are `thmbox:0.3.0` and `fletcher:0.5.8`. The
  tier-one prohibition lint is recorded as **partially** built (backtick spans and math symbols
  linted; dotted identifiers and tool names not).
- **Phase 9** altered: `patterns/local-path-require-obligations.md` was being cited as a
  backticked corpus path in `patterns/gate-collision-ledger.md` while not existing. Reworded to
  name it as a proposed filename and state explicitly that no such document exists yet, so the
  cross-reference check is clean and no reader follows a dead pointer.

## Observation: a concurrent foreign writer in the consuming repository

Reported rather than acted on, per the Observation Duty and
`context/patterns/dispatch-report-not-termination.md`. **No action was taken and none is
recommended from this task** -- the consuming repository is read-only for it.

This dispatch was strictly read-only against `/home/benjamin/Projects/Logos/Verification`: every
command was a read (`cat`, `sed -n`, `grep`, `find`, `wc`, `ls`, `stat`, `python3` JSON loads,
`typst --version`) plus one `interface/scripts/layer-lint.sh` run, which its own header documents
as requiring no build, no network and writing nothing.

At **2026-10-03 20:08:09 UTC** -- 28 minutes into this dispatch (started 19:40:20 UTC) -- **ten
files outside `specs/` were modified there in a single sub-100-millisecond batch**:
`CONTRIBUTING.md`, `books/tool/lakefile.toml`, `books/tests/certify/fixtures/lakefile.toml`,
`books/tests/manifest/fixtures/lakefile.toml`, `typst/lib/phrases.toml`, and the `README.md` files
of `components/distsys`, `components/distsys/certificate`, `components/fault_tolerance`,
`components/rle_codec` and `components/rle_codec/certificate`. The working tree there went from 12
modified files to 25. `git log` in that repository confirms the work is not this dispatch's --
its last five commits are that repository's own research commits.

**What the batch did**, on inspection of two samples: it **removed the proprietary licence header
line** from `books/tool/lakefile.toml` and reduced `typst/lib/phrases.toml` by one line. That is
the exact rule `components/framed_channel/scripts/check-spdx.sh` enforces and that this corpus
documents as authoring rule 1 in `tools/tooling-inventory.md`, so those files now contradict a
rule this corpus states as enforced. Whether the removal is an intentional relicensing change or a
defect is **not determinable from here**.

**Impact on this task's deliverable, checked file by file**: `books/lean/lakefile.toml` and
`books/README.md` are **unmodified**, so every transcription from them stands.
`books/tool/lakefile.toml`'s `globs` and its one `require` are **unchanged** -- only the header
line went -- so that transcription stands too. The one figure invalidated was
`typst/lib/phrases.toml`'s byte size: cited as 8,564 bytes (the design record's figure) and now
8,478 on the modified tree. `tools/typst-template-contract.md` was corrected to give both numbers
with their provenance and to instruct re-measurement rather than quotation.

Also observed, and benign: the declared concurrent sibling (`task 326`) committed twice to this
repository during the dispatch, both within its declared `file_scope`
(`agent-system/extensions/books/agents/`, `.../skills/`, `agent-system/extensions/core/scripts/`).
Its commits **added pointers to `context/project/books/domain/gate-tiers.md` and
`context/project/books/tools/certify-guide.md`** -- two paths this task authored at exactly those
names, so the sibling's pointers resolve. No scope overlap occurred.

## Verification

- Build: N/A (markdown and JSON only)
- Tests: N/A
- Files verified: **Yes** - 17 files on disk, 17 `git ls-files` entries, 17 index entries
- `generate-context-line-counts.sh --check`: **PASS** ("all line_count values are exact", 559
  entries)
- `validate-context-budgets.sh --index <books>`: **PASS** - `Total entries: 17`,
  `Derived tier distribution: Tier 2: 1, Tier 4: 16`, `Dead entries ... 0 -- OK`,
  `Double-Loading ... 0`, `Violations: 0`
- `check-extension-docs.sh`: **books PASS**. The run exits 1 overall on seven `core` FAILs, all
  "deployed script content drift" on `orchestrate-build-dispatch.sh`, `orchestrate-cycle-plan.sh`,
  `parse-command-args.sh`, their tests, and `validate-state.sh`/`test-validate-state.sh` -- the
  first five are the **declared sibling's** `file_scope`, the last two were already dirty in the
  working tree before this dispatch began. **None is attributable to this task**, which touched no
  `core` file.
- `check-task-references.sh`: **PASS**, 0 occurrences, run with all 17 corpus files git-tracked
  (staging-first was load-bearing: the lint scans via `git ls-files`). Confirmed independently by
  a direct `TASK_PATTERN` grep over all 20 touched files - 0 matches.
- JSON schema: 17 entries, every entry within the `additionalProperties: false` whitelist, every
  required field present, **max summary length 199** against the 200-character cap
- README reconciliation: `diff` of the README's 16 table paths against the 16 files on disk -
  **exact match**; every README row resolves and every file has a row
- Cross-references: all 16 distinct corpus-relative backticked paths resolve
- Encoding: pure ASCII except one deliberately retained Lean arrow in a verbatim code block
- Scope: `git status --short -- .claude/` **empty**; no file under
  `books/{manifest.json,agents,skills,commands,rules,scripts}` modified by this task

## Impacts

- The four books agents and the six books skills now have a real domain corpus behind the single
  pointer they each carry. `books-implementation-agent`, `books-implementation-hard-agent` and
  both implementation skills additionally point at `domain/gate-tiers.md` and
  `tools/certify-guide.md`, which now exist.
- Tier 4 + `on_demand: true` on all sixteen documents means **no books dispatch pays for the
  corpus by default**; the README's table is the discovery mechanism, and the README alone
  (84 lines) is what loads eagerly.
- `domain/known-gap-register.md` is now the single place a books dispatch can check whether a
  contract it is about to rely on has a live instance. Thirteen gaps are named with measurements,
  including three that would otherwise be discovered by a failing gate.
- `patterns/gate-collision-ledger.md` and `domain/gate-tiers.md` make the 75-of-127-minute
  integration cost readable instead of rediscoverable, and both carry the source report's own
  "seed, not a diagnosis" caveat verbatim so the figures are not over-trusted.

## Follow-ups

- **`patterns/local-path-require-obligations.md`** - the seventeenth document the research
  recommends: a checklist for the six edits across three files that one local-path `require`
  obliges. Named in `patterns/gate-collision-ledger.md` as a follow-up that does not yet exist.
- **One sentence for `context/guides/extension-development.md`** recording
  `check-extension-docs.sh` Rule E's document scope - now known: `check_referenced_scripts_declared`
  selects from exactly `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md` and
  `EXTENSION.md`, and **does not reach `context/`**. Outside this task's scope.
- **The plan's gate invocations should be corrected at the source** to name the deployed
  `.claude/scripts/` copies, since the source-store copies refuse to run. This affects any future
  plan that copies those command lines.
- **`rules/books.md:69`** still says "navigation stub into the fuller domain corpus". It is owned
  by the dependency task and was deliberately left untouched; the phrasing is now understated
  rather than wrong.
- **The consuming repository's licence-header removal batch** (Observation section) wants a human
  decision: intentional relicensing, or a defect to revert. Not this task's to make.
- **`rules/books.md` item 3 versus the measured tree** - the rule mandates flattened `book.typ`
  while 25 of 27 real manifests declare `docs/book.md`. Both facts are now stated in
  `patterns/authoring-workflow.md`; reconciling them is a decision for the convention's owner.

## References

- `specs/298_author_books_extension_context_corpus/plans/01_books-context-corpus.md`
- `specs/298_author_books_extension_context_corpus/reports/01_books-extension-context-corpus.md`
- `specs/298_author_books_extension_context_corpus/progress/phase-{1..9}-progress.json`
- Consuming repository (read-only): `docs/book-convention.md`, `docs/architecture-decisions.md`,
  `books/schema/book-{toml,cert}-v2.md`, `books/lean/Books/Meta.lean`, `books/README.md`,
  `books/scripts/certify.sh`, `typst/lib/book.typ`,
  `specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md`,
  `specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`
