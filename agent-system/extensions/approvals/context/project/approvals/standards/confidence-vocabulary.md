# Confidence Vocabulary

Exactly two confidence values exist for an `/approve` recommendation: `MEASURED` and
`INFERENCE`. There is no third tier and no numeric or graded scale. This vocabulary is derived
from, and cites, an existing precedent in this repository rather than inventing a parallel scale
that would then need to be kept reconciled with it.

## Precedent

The repository already draws exactly the distinction this command needs, in the Logos/
Verification repository's book-certification design:

- `books/convention/09-trust-unit-is-the-export.md` (Decision 9) states: "the completeness
  direction is marked INFERENCE for cost on the real composite; the cone walk is measured."
  `book_requires` completeness (did the book module state every composition hypothesis the
  cones actually reach) is judged by the certifier without an independent mechanical check and
  is marked `INFERENCE`; the cone walk itself (whether the declared hypotheses are actually
  reached) is computed directly and is `MEASURED`.
- `books/lean/BookCert/Depends.lean` uses the identical vocabulary in its own implementation
  comments ("Decision 9 marks `book_requires` completeness as INFERENCE — the cone walk is
  measured").

This is explicitly **derived from** that precedent, not a parallel scale: the same two words,
the same meaning (a measured value is the direct output of a mechanical check; an inference is
a judgment the agent makes without one), reused here for a different but structurally identical
problem — classifying a diff rather than a dependency declaration.

**Citation note**: the task description's citation path `docs/book-convention.md` is stale; the
convention document is now split into `books/convention/01..19-*.md`, and the specific decision
is `09-trust-unit-is-the-export.md`.

## Definitions

- **`MEASURED`**: the claim is the direct output of a mechanical check `/approve` itself ran.
  Exactly two cases qualify:
  - The diff against the commit that recorded the last approval is literally empty (the
    `identical` evidence kind — see `approve-classify.sh`).
  - The declaration-name delta (`decl_added`, `decl_removed`, `decl_restated`) computed
    mechanically from the diff's own added/removed header lines.
- **`INFERENCE`**: the agent read a hunk and judged it non-semantic (pure boilerplate: blank
  lines, comments, licence headers, attribute-only lines) without an independent mechanical
  check beyond the closed boilerplate-pattern list, or there is no diff evidence at all
  (`never-approved`, `uncommitted-approval`).

A confidence value the agent assigns "by feel" is worse than none, because it launders a guess
as a measurement. `INFERENCE` is not a lower-confidence `MEASURED` — it names a different kind
of evidence, not a smaller number.

## Summary Contract

The owner-facing summary `/approve` presents (built before `AskUserQuestion` is ever called)
carries, per item:

- the item id,
- its class (`mechanical` / `declaration-level` / `needs-full-text`),
- the measured declaration delta **by name** (which declaration was added, removed, or
  restated — never a bare count),
- a recommendation (`approve` / `decline` / `read-full-text`),
- a confidence value (`MEASURED` or `INFERENCE`),
- the artifact path (so Escape 2 — opening the file directly — is always available).

And nothing else. The full classified diff is **never** shown inline; it is at the artifact path
from `approval-artifact-convention.md`, for anyone who wants it.

**Discrepancies are named, never averaged.** Every discrepancy is called out explicitly rather
than folded into a verdict: if two specifications disagree, or a record disagrees with the
tree, the owner is told so by name in a Discrepancies block at the head of the question — not
smoothed into a single confidence number. A rollup over several items (for the bulk triage
gate) takes `min()` over confidence, never a mean: one `INFERENCE` item in a batch makes the
whole batch's rollup `INFERENCE`. Any item whose declaration set changed, or whose record
disagrees with the tree, is listed by name in that Discrepancies block and is never eligible for
the bulk gate — see `approve-interaction-design.md`'s option-availability gating.
