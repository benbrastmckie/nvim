# Research Report: Task #339

**Task**: 339 - Record the tabular-presentation convention in the typst extension context
**Started**: 2026-10-05
**Completed**: 2026-10-05
**Effort**: small (two short additions, one recorded decision)
**Dependencies**: None (prose prerequisite: upstream Verification-repo ruling, confirmed present)
**Sources/Inputs**: - `~/Projects/Logos/Verification/typst/manual/template.typ` (read-only, upstream ruling)
  - `~/Projects/Logos/Verification/typst/manual/LogosVerificationManual.typ` (read-only, breakable-rule placement)
  - `agent-system/extensions/typst/context/project/typst/patterns/tables-and-figures.md` (edited)
  - `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md` (edited)
  - `agent-system/extensions/typst/scripts/typst-element-lint.sh` (read-only, decision input)
**Artifacts**: - this report
  - `agent-system/extensions/typst/context/project/typst/patterns/tables-and-figures.md` (modified)
  - `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md` (modified)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The upstream ruling named by the dispatch exists and is fully worked out in
  `~/Projects/Logos/Verification/typst/manual/template.typ` (its `obligation-list`/`data-table`/
  `data-list` helpers and the "Convention ruling" comment at that file's lines ~507-549), so the
  task was not left at `not_started` — the prerequisite was read and transcribed faithfully.
- Recorded the convention in both target files: a new "Pagination and Element Choice" section in
  `patterns/tables-and-figures.md` (figure non-breakability, the `#show figure.where(kind: table):
  set block(breakable: true)` mechanism and where it must live, header-repeat and caption-position
  as settled decisions), and a new "Tabular / Key-Value Data" Per-Element Semantics entry in
  `standards/semantic-element-usage.md` (grid-vs-description-list choice rule, consistent with the
  Universal Placement Rule).
- Ruled explicitly NOT to extend `typst-element-lint.sh` with a mechanical check for the
  grid-vs-list choice: the choice test is rendering-dependent (cell line count at column width),
  not a structural grep the way heading-adjacency placement is, and no real-corpus defect of this
  kind has been observed yet (unlike the placement rule, which already codifies an observed
  defect). Recorded in `tables-and-figures.md` under "Mechanical Check: Not Added".
- No deployed `.claude/` file touched; nothing in `~/Projects/Logos/Verification` touched — both
  edits landed only in the source store (`agent-system/extensions/typst/**`), per
  `rules/source-store-deploy-boundary.md`.

## Context & Scope

This task records, in the typst extension's context files, a tabular-presentation convention
that a manual-formatting task in the `~/Projects/Logos/Verification` repository already adopted —
so the ruling survives beyond the one document that forced it. The task does not invent the
convention; it transcribes an existing upstream ruling faithfully into two context files and
rules on one open mechanical-check question. Per the dispatch, the task was gated on the upstream
ruling existing before any wording could be synthesized; that gate was checked first (see
Findings) and found satisfied, so the work proceeded.

Scope is deliberately narrow: two short additions plus one recorded decision, not a general
formatting framework. Out of scope (confirmed untouched): thmbox/theorem-environment guidance,
fletcher diagram patterns, `standards/chapter-quality.md` and `chapter-quality-check.sh`, any file
in `~/Projects/Logos/Verification`, and any file under a deployed `.claude/` tree.

## Findings

### Upstream Ruling (Gate Check)

Read `~/Projects/Logos/Verification/typst/manual/template.typ` in full around the relevant region
(roughly lines 340-654). The ruling is explicit and complete:

- **Already-established background** (confirmed matches the dispatch's summary): `obligation-list`
  (line 353) is a description-list helper for coverage obligations, with a backwards-compatible
  alias `#let obligation-table = obligation-list` (line 388) whose comment names "the table-to-list
  change." Two alternatives are recorded as already-abandoned: `par(hanging-indent:)` is a silent
  no-op inside a nested block in Typst 0.14.2, and a two-column grid flattens to the same uniform
  inset as the list (both at lines 368-372, repeated at 528-531).
- **The generalized convention** (lines 507-549, "Convention ruling: grid vs. description-list for
  tabular/key-value content"): generalizes two existing precedents — `component-index-list`'s grid
  branch ("short, uniform, and genuinely tabular," line 475) and `obligation-list`'s list branch
  (long unhyphenatable identifiers or multi-sentence prose collapse a fixed column). The operational
  test: stay a grid when every cell renders in ~2 lines or fewer at its own column width and the
  whole table fits on one page; become a description-list when the content is genuinely key-value,
  or a fixed column would collapse the measure.
- **Breakability and its placement** (lines 521, 533-549): the backstop `#show
  figure.where(kind: table): set block(breakable: true)` must live at the top level of
  `LogosVerificationManual.typ` itself (confirmed at that file's line 112), never inside the
  `template.typ` helper function — verified broken there with `error: cannot reference styled`
  when tried inside the function wrapping the figure.
- **Header-repeat and caption-position as settled decisions, not inherited defaults** (lines
  533-540): `grid.header(repeat: true, ...)` is written explicitly even though `repeat` already
  defaults to `true` in Typst 0.14.2 (confirmed at `data-table`'s own call, line 587); caption
  placement for a breakable figure is confirmed (verified on both a synthetic probe and the real
  manual, per the comment) to render once, after the last chunk, with no per-page repetition and
  no overlap — the 0.14.2 default, so nothing extra is added to produce it.
- Two concrete helpers instantiate the two branches: `data-table` (lines 564-594, the grid branch)
  and `data-list` (lines 608-654, the description-list branch), both wrapped in the same
  `figure(kind: table, supplement: [Table], ...)` so a shape conversion between the two never
  touches `@tbl-xxx` labels or "Table N" numbering.

### Gap in Target Files (re-measured 2026-10-05, matches dispatch's 2026-10-04 measurement)

- `patterns/tables-and-figures.md` (170 lines before this task) was confirmed to be generic
  upstream-Typst boilerplate with zero mention of breakable/pagination/overflow, and no statement
  of when a grid is the wrong element.
- `standards/semantic-element-usage.md` (281 lines before this task) was confirmed to have
  Per-Element Semantics entries for Definition through `rule-list`, with no tabular/key-value
  entry.
- Re-ran the grep for `breakable|overflow|paginat` across the typst context tree: still only the
  two incidental thmbox-breakable lines in `standards/document-structure.md` and
  `standards/typst-style-guide.md` (out of scope, confirmed untouched).

### Mechanical-Check Question

Read `agent-system/extensions/typst/scripts/typst-element-lint.sh` in full. It is a text-only line
scanner: check 1 (blocking) detects a semantic element as the first body line after a heading by
inspecting only the single line immediately following each heading; checks 2-4 are advisory
counts (remark item count, remark-vs-theorem ratio, zero-element presence). None of its existing
mechanics evaluate rendered cell width or line-wrap behavior — the grid-vs-list operational test
("does each cell render in ~2 lines or fewer at its own column width") is not expressible in that
scanning model without actually compiling and measuring rendered output, a materially heavier
mechanism than the script's current approach. This, combined with the absence of any observed
real-corpus defect of this specific kind (contrast the placement rule, which was added only after
an observed defect), is the basis for the "not added" ruling recorded in the Decisions section
below.

## Decisions

- **Convention transcribed, not invented**: both additions are a faithful transcription of the
  upstream `template.typ` ruling, not a new design. No alternative phrasing or additional
  structural options were introduced beyond what the upstream comment already states.
- **Placement in `tables-and-figures.md`**: added as a new `## Pagination and Element Choice`
  top-level section, positioned after the existing `## Figures` section (where the structural
  defect — a grid-wrapped figure overflowing a page — is most directly relevant) and before
  `## Diagrams (cetz)`, so it reads as a natural continuation of the figure-with-table material
  immediately above it.
- **Placement in `semantic-element-usage.md`**: added as a new `### Tabular / Key-Value Data`
  entry after the existing `rule-list` entry (the last Per-Element Semantics entry) and before
  `## Where Tracking Content Belongs`, keeping the file's existing entry ordering (one subsection
  per element, in the order they were introduced) intact. The entry explicitly notes it governs a
  structural choice *within* one figure kind rather than which element to reach for, so it does
  not misrepresent itself as parallel to Definition/Theorem/etc. in kind — only in format (three
  labeled subsections: "What it is for," "Expected density," "Legal placement").
- **Mechanical check: ruled NOT to add.** Recorded in `tables-and-figures.md` under a new
  `### Mechanical Check: Not Added` subsection, with the reasoning from Findings above (rendering-
  dependent judgment vs. text-only scanning; no observed real-corpus defect yet). This satisfies
  the dispatch's requirement to rule explicitly rather than silently skip the question; adding the
  check itself was explicitly stated as not required.
- **No script edit**: `typst-element-lint.sh` itself was left untouched, consistent with the
  "not added" ruling — there is nothing to add, so nothing was changed there.

## Risks & Mitigations

- **Risk**: a future editor might assume the mechanical-check question was simply overlooked.
  **Mitigation**: the ruling and its reasoning are recorded in-line in `tables-and-figures.md`
  rather than only in this report, so it is visible at the point a reader would naturally ask the
  question (next to the pagination material the lint script would have to check).
- **Risk**: the new `Tabular / Key-Value Data` entry could be read as applying the Universal
  Placement Rule's "never first after a heading" restriction to the grid-vs-list *content* choice
  itself (which would be a misreading — placement and shape-choice are orthogonal).
  **Mitigation**: the entry's "Legal placement" subsection explicitly states the two are
  orthogonal, not conflated.

## Context Extension Recommendations

None. Both target files already exist and are the correct, sufficient homes for this material —
no new context file or directory is warranted for a two-addition, single-ruling task of this
size.

## Recommendations

- Proceed directly to `/plan 339` (or orchestrator auto-advance) — the additions are already
  complete prose, and a planning phase would add no value beyond what this report captures. If
  the orchestrator's phase gate still requires a plan artifact before implementation, the plan can
  point back to this report's Findings/Decisions verbatim rather than re-deriving them.
- No further research is needed: the upstream ruling was read in full, both target files were
  edited to match their own existing format, and the mechanical-check question was explicitly
  resolved.

## Appendix

- Search queries / commands used:
  - `grep -n "obligation-list\|obligation-table\|table-to-list" template.typ`
  - `grep -n "breakable: true\|kind: table\|kind: \"thmbox\"" LogosVerificationManual.typ`
  - `grep -n "339" specs/TODO.md` (status confirmation)
  - `cat agent-system/extensions/typst/scripts/typst-element-lint.sh` (header/check inventory)
- References: `~/Projects/Logos/Verification/typst/manual/template.typ` (lines ~340-654),
  `~/Projects/Logos/Verification/typst/manual/LogosVerificationManual.typ` (lines ~95-112),
  `agent-system/extensions/typst/scripts/typst-element-lint.sh` (full file header/comments).
