# Adversarial Verification Contract (H4) — CSLib Override

This is cslib's domain-prefixed override of the core H4 contract, deployed alongside (never
clobbering) core's own `context/contracts/adversarial-verification.md` — cslib declares
`"contracts"` in its own `provides.context` and this file's basename carries the mandatory
domain prefix (see `context/guides/manifest-routing-schema.md`'s "Override Contract Placement
Convention" subsection). A `--hard` dispatch of `task_type: cslib` reaches this file through
cslib's manifest `hard_contracts.cslib` `replace:` directive, not through any directory-merge
collision.

This file does **not** specialize into cslib-only H4 behavior: content below the title is kept
identical to the canonical core file — `@.claude/context/contracts/adversarial-verification.md`
— because cslib was never found to need cslib-specific H4 wording of its own. If cslib ever
needs genuinely cslib-only H4 behavior, that content belongs in a new, additively-composed
section rather than replacing the shared baseline here.

## Claim Verification Bar

A load-bearing claim ships as **VERIFIED** only when ALL of the following hold:

1. **Claim stated verbatim**: The claim is written out as a specific, checkable statement
   (not paraphrased or gestured at).
2. **Concrete source quoted/cited OR a tested counterexample**: Either a direct quotation
   with citation (page/section/URL/file:line), or a counterexample that was actually
   executed/searched, not merely imagined.
3. **Verification method named**: The specific tool, search, or read that produced the
   evidence is named (e.g., `lean_hover_info` at `Foo.bar:12`, `WebFetch` on the official
   docs page, `Grep` across N call sites, BibKey lookup in `references.bib`).
4. **Confidence level assigned**: One of the three tags from the Confidence Level
   Taxonomy below.

Missing any of the four elements downgrades the claim to **UNVERIFIED**. An UNVERIFIED
claim must be explicitly caveated in the report — it may not be presented as settled.

This bar composes with the H3 Source-Coverage Minimums (see
`@.claude/context/contracts/reference-grounding.md#source-coverage-minimums`): element 2
of this bar is satisfied only when the coverage minimum for the claim's tier has already
been met (e.g., a Tier 2 claim resting on a single ambiguous doc page has not cleared H3
coverage, and therefore cannot be tagged High confidence here regardless of citation
formatting).

## Confidence Level Taxonomy

Every load-bearing claim in a research report carries exactly one confidence tag:

- **High**: 2+ independent sources agree, OR a directly-read authoritative source was
  checked with no conflicting evidence found (and the search for conflicts is itself
  documented — see Forbidden Verification Outputs).
- **Medium**: A single authoritative source, not cross-checked against a second source;
  or a pattern confirmed in only one location/call site.
- **Low**: Inferred from convention or instinct, not directly verified against a source
  or counterexample.

Confidence tags are not optional decoration — they are read downstream by planning and
implementation agents to decide which claims need re-verification before being acted on.

## Contradiction Resolution Protocol

When independent sources disagree on a load-bearing claim, attempt resolution via
precedence BEFORE writing the finding into the report. Reuse the H3 Authoritative
resolution ranking:

1. Official docs > community posts / forum answers
2. Current code > stale docs / stale comments
3. Test-suite behavior > assumed behavior
4. Directly-read primary source > secondary summary or instinct

Only if resolution genuinely fails after applying this ranking may the report state:

```
UNRESOLVED CONTRADICTION: <A> vs <B>
Downstream risk: <what breaks if the wrong side is trusted>
Resolving check: <the specific search/read that would resolve it, not yet performed>
```

`UNRESOLVED CONTRADICTION` is a valid terminal state — it is not a failure of the
research dispatch — provided the risk and the resolving check are both stated. Silently
picking one side of a contradiction without applying the precedence ranking, or omitting
the contradiction entirely, is a contract violation.

## Forbidden Verification Outputs

The following are NOT acceptable in a `## Adversarial Self-Verification` section:

1. **"Sources agree"** — without naming which sources.
2. **"Well documented" / "commonly known"** — without a citation.
3. **"No conflicting information found"** — without stating what was searched and how
   many independent sources were checked.
4. **A contradiction noted with no resolution attempt** — every contradiction must show
   the precedence ranking was applied before it may be marked `UNRESOLVED CONTRADICTION`.

These are verification-paralysis-adjacent signatures: they read as due diligence but
carry no checkable content. An agent that produces them has failed Stage 4.5.

## Domain Specialization

This is the domain-agnostic baseline. Domain-specific "Verification Method" values plug
into element 3 of the Claim Verification Bar without altering the bar itself:

- **cslib**: BibKey verification against `references.bib` (see
  `@.claude/extensions/cslib/context/project/cslib/standards/citation-conventions.md`)
  is a valid "Verification Method" value for literature claims; reuse-completeness
  (all 5 Reuse Check Protocol steps exhausted) and zero-debt compliance checks are
  additional cslib-specific verification passes layered on top of this bar.
- **lean4**: A `lean_hover_info`-confirmed type signature is a valid "Verification
  Method" value for Mathlib/CSLib API claims; `lean_local_search` confirmation is the
  minimum bar for "does X exist" claims (see
  `@.claude/context/contracts/lean4-adversarial-verification.md` for the
  parity copy used by lean-only deployments).
- Extension overrides live in
  `.claude/context/contracts/{domain}-adversarial-verification.md` (a flat,
  domain-prefixed basename under the shared directory -- never a nested or
  extension-namespaced path).

This file is the cslib-extension mirror copy; the canonical core file lives at
`@.claude/context/contracts/adversarial-verification.md`.
