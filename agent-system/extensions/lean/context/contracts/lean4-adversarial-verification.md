# Adversarial Verification Contract (H4) — Lean4 Parity Copy

This is the lean-extension parity copy of the core H4 contract, so lean-only deployments
(no core extension loaded) still have the contract available. Content mirrors
`@.claude/context/contracts/adversarial-verification.md`; the lean4 domain note is inlined
below rather than cross-referenced.

## Claim Verification Bar

A load-bearing claim ships as **VERIFIED** only when ALL of the following hold:

1. **Claim stated verbatim**: The claim is written out as a specific, checkable statement
   (not paraphrased or gestured at).
2. **Concrete source quoted/cited OR a tested counterexample**: Either a direct quotation
   with citation (page/section/theorem number, or `lean_hover_info` output), or a
   counterexample that was actually run/searched, not merely imagined.
3. **Verification method named**: The specific tool, search, or read that produced the
   evidence is named (e.g., `lean_hover_info` at `Foo.bar:12`, `lean_local_search` result,
   `lean_leansearch` result, BibKey lookup in `references.bib`).
4. **Confidence level assigned**: One of the three tags from the Confidence Level
   Taxonomy below.

Missing any of the four elements downgrades the claim to **UNVERIFIED**. An UNVERIFIED
claim must be explicitly caveated in the report — it may not be presented as settled.

This bar composes with the H3 lean4 Source-Coverage Minimums (see
`@.claude/context/contracts/lean4-reference-grounding.md#source-coverage-minimums-lean4`):
element 2 of this bar is satisfied only when the coverage minimum for the claim's tier has
already been met (e.g., a Tier 2 Mathlib claim resting on a single ambiguous docstring has
not cleared H3 coverage, and therefore cannot be tagged High confidence here).

## Confidence Level Taxonomy

Every load-bearing claim in a research report carries exactly one confidence tag:

- **High**: 2+ independent sources agree (e.g., `lean_local_search` hit AND
  `lean_hover_info`-confirmed signature), OR a directly-read authoritative source was
  checked with no conflicting evidence found (and the search for conflicts is itself
  documented).
- **Medium**: A single authoritative source, not cross-checked against a second source;
  or a Mathlib pattern confirmed via only one search tool.
- **Low**: Inferred from convention or instinct ("mathlib likely has this"), not directly
  verified against `lean_local_search` or a rate-limited search tool.

## Contradiction Resolution Protocol

When independent sources disagree on a load-bearing claim (e.g., a search tool result
conflicts with `lean_hover_info` output, or a paper's proof sketch conflicts with the
Mathlib formalization), attempt resolution via precedence BEFORE writing the finding:

1. Directly-read Lean source (`lean_hover_info` / `lean_declaration_file`) > search-tool
   snippet summaries
2. Current Mathlib/CSLib source > stale docs or comments
3. Test-suite / example-file usage > assumed usage
4. Primary paper source > secondary summary or instinct

Only if resolution genuinely fails after applying this ranking may the report state:

```
UNRESOLVED CONTRADICTION: <A> vs <B>
Downstream risk: <what breaks if the wrong side is trusted>
Resolving check: <the specific search/read that would resolve it, not yet performed>
```

`UNRESOLVED CONTRADICTION` is a valid terminal state provided the risk and the resolving
check are both stated. Silently picking one side without applying the precedence ranking,
or omitting the contradiction entirely, is a contract violation.

## Forbidden Verification Outputs

The following are NOT acceptable in a `## Adversarial Self-Verification` section:

1. **"Sources agree"** — without naming which sources (which search tools/declarations).
2. **"Well documented" / "commonly known"** — without a citation or `lean_hover_info` link.
3. **"No conflicting information found"** — without stating what was searched (which
   search tools, how many results) and how many independent sources were checked.
4. **A contradiction noted with no resolution attempt** — every contradiction must show
   the precedence ranking was applied before it may be marked `UNRESOLVED CONTRADICTION`.
5. **"Mathlib likely has this"** — without a `lean_local_search` or `lean_leansearch` call
   backing it (this is also a Forbidden Conclusion under the H2 lean4 override).

## Domain Specialization (Lean4)

- A `lean_hover_info`-confirmed type signature is a valid "Verification Method" value for
  Mathlib/CSLib API claims.
- `lean_local_search` confirmation is the minimum bar for "does X exist locally" claims;
  it must be attempted before any rate-limited search tool (`lean_leansearch`,
  `lean_loogle`, `lean_leanfinder`, `lean_state_search`, `lean_hammer_premise`).
- For cslib-adjacent lean4 tasks, BibKey verification against `references.bib` is a valid
  "Verification Method" value for literature claims (see
  `@.claude/extensions/cslib/context/project/cslib/standards/citation-conventions.md`).
- This file is the lean-extension parity copy; the canonical core file lives at
  `@.claude/context/contracts/adversarial-verification.md`.
