# Reference Grounding Contract (H3) — Lean4 Override

This file overrides the core `reference-grounding.md` contract for Lean4 tasks.
It adds lean4-specific requirements: lemma-level source mapping tables, sorry-inventory
cross-references, and PDF section citation format.

Base contract: `@.claude/context/contracts/reference-grounding.md`

## Lean4 Tier 1: Literature-Backed Tasks

**Applies when**: task involves formalizing theorems from research papers, textbooks, or
proof sketches from other proof assistants (Isabelle, Coq, Agda).

### Lemma-Level Mapping Table (Mandatory)

For Lean4 Tier 1 tasks, the mapping table MUST use the following 5-column format:

| Source | Prop/Location | Lean Identifier | Type Signature | Status |
|--------|---------------|-----------------|----------------|--------|
| [Author YYYY] | Theorem 3.2, p.47 | `Ns.mainResult` | `∀ x, P x → Q x` | transcribed |
| [Author YYYY] | Lemma 4.1, p.52 | `Ns.helperLemma` | `P a → P b` | pending |
| [Author YYYY] | Corollary 5.1, p.60 | `Ns.consequence` | `Q x ↔ R x` | sorry |

**Column definitions**:
- **Source**: Author lastname, year (e.g., "Smith 2019")
- **Prop/Location**: Theorem/Lemma/Corollary number AND page number (both required)
- **Lean Identifier**: Fully qualified name in the project namespace
- **Type Signature**: The Lean 4 type expression (not the natural language description)
- **Status**: One of `transcribed` (fully proved), `pending` (not yet attempted),
  `sorry` (placeholder — must appear in sorry inventory), or `blocked` (escalated)

### PDF Section Citation Requirement

All load-bearing claims MUST cite page and proposition number:
- REQUIRED: "Smith 2019, Proposition 3.2, p. 47"
- NOT SUFFICIENT: "Smith 2019"
- NOT SUFFICIENT: "see the main theorem"

### Transcription Discipline

The source wins over instinct. If the source proof uses technique X and instinct suggests
technique Y, implement X first. Instinct-driven divergence from the source requires explicit
justification citing either:
1. A known error in the source proof, OR
2. A domain mismatch (e.g., classical vs. constructive logic)

Document any divergence in the plan's "Literature Proof Structure" section.

## Sorry-Inventory Cross-Reference

The Lean4 mapping table STATUS column must stay synchronized with the sorry inventory in
the implementation agent's handoff JSON. Specifically:

- Any identifier with `Status: sorry` MUST appear in `sorry_inventory` in the handoff
- Any identifier removed from `sorry_inventory` (because the sorry was resolved) MUST
  have its status updated to `transcribed` in the mapping table
- Leaf sub-sorries (internal helper steps that will never be exported) are tracked
  separately with a `leaf:` prefix in the identifier column

## Lean4 Tier 2 and Tier 3

For documentation-backed and implementation-backed lean4 tasks, the standard Tier 2 and
Tier 3 rules from the core contract apply without modification.

## Source-Coverage Minimums (Lean4)

No single-source conclusions. This overrides/extends the core contract's Source-Coverage
Minimums subsection with lean4-specific detail (see H4 `adversarial-verification.md`
Claim Verification Bar for how this feeds into confidence tagging):

- **Tier 1 (Literature-Backed)**: The 5-column mapping table row's `Source` citation is
  mandatory. For safety- or design-critical theorems, a second corroborating source
  (another passage, a second paper, or an independent proof-sketch/formalization in
  another proof assistant) is required — no single-passage conclusions for load-bearing
  main theorems.
- **Tier 2 (Documentation-Backed)**: Mathlib source (via `lean_hover_info` /
  `lean_declaration_file`) is the minimum. If the declaration's docstring is ambiguous or
  silent, a second independent source (a second search tool result, the Mathlib changelog,
  or the test/example file using the declaration) is required before concluding.
- **Tier 3 (Implementation-Backed)**: Reading an existing Lean file without checking
  whether it has corresponding tests/examples in the repo is insufficient; both required.
- **Tier-agnostic lean4 convention rule**: an "this is the CSLib/Mathlib convention" claim
  requires confirmation at 2+ independent declarations/files via `lean_local_search`, not
  a single hit.

## Graceful Degradation

When no reference materials are identified:
1. Document: "No literature source identified; using first-principles lean4 development."
2. Apply the standard Lean4 proof structure from `lean-research-flow.md`
3. The 5-column mapping table is still encouraged for tracking proof status across lemmas

## Enforcement

Agents MUST include the 5-column mapping table in research reports and plans for Tier 1 tasks.
Plans without the table for a literature-backed lean4 task are NON-CONFORMING and should be
revised before implementation begins.
