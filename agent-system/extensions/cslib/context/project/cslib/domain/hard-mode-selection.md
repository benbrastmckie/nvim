# When to Use `--hard` for CSLib Tasks

Selection criteria, added contracts, and cost profile for hard-mode CSLib dispatch. Hard mode is
per-invocation only: pass `--hard` explicitly on each `/orchestrate` call, combined with
`--research`, `--plan`, or `--implement`.

## Selection Criteria

Use `/orchestrate N --research --hard`, `--plan --hard`, or `--implement --hard` when one or more
of the following apply to a CSLib task:

1. **Previous research produced analysis-only output** with no actionable proof direction --
   no Lean code sketches, no Mathlib lemma candidates, no reuse check results.
2. **Task involves faithful transcription of a published CS paper** into Lean 4
   (literature-backed: bisimulation theorems, operational semantics rules, type system proofs).
3. **Task has been in [IMPLEMENTING] for 2+ dispatch cycles** without completing any phase.
4. **Proof requires BibKey citation traceability** against CSLib's `references.bib`.
5. **Task involves multiple parallel proof obligations** requiring territory contracts (H7) to
   prevent file conflicts between agents.

None of these are individually decisive. Criterion 2 alone justifies hard mode; criteria 1 and 3
are deflection signals and are strongest in combination.

## What Hard Mode Adds

Over the standard cslib skills (`skill-cslib-research`, `skill-cslib-implementation`), the hard
variants (`skill-cslib-research-hard`, `skill-cslib-implementation-hard`) add:

| Contract | Effect |
|----------|--------|
| H2 (anti-analysis) | Strict read budget -- first proof write within 20% of tool calls |
| H3 (reference grounding) | BibKey verification against `references.bib` for all cited theorems |
| H4 (adversarial verification) | Self-verification pass challenging every recommendation |
| H7 (territory contracts) | Explicit file ownership for parallel implementation phases |
| H9 (wrap-up discipline) | `sorry_inventory` in every orchestrator handoff JSON |

See `standards/citation-conventions.md` for the BibKey format and the `references.bib`
verification procedure that H3 depends on, and `patterns/lint-fix-wave-assignment.md` for the
conflict matrix used when H7 territory contracts partition parallel work.

## Cost Impact

`--hard` multiplies token cost roughly 3-5x over the standard cslib skills. Reserve it for
formally complex or previously-deflected tasks; it is not a default quality upgrade.
