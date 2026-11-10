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

`--hard` dispatches the SAME standard cslib skills/agents (`skill-cslib-research` /
`cslib-research-agent`, `skill-cslib-implementation` / `cslib-implementation-agent`) as standard
mode -- there is no separate `-hard`-suffixed skill or agent any more. The behavioral difference
is provided by manifest.json's `hard_contracts.cslib` block, which injects the following into
the dispatch prompt as a `<hard-mode-contracts>` list (see
`context/guides/manifest-routing-schema.md`'s "The `hard_contracts` Block" section for the
mechanism):

| Contract | Effect |
|----------|--------|
| H2 (anti-analysis) | Strict read budget -- first proof write within 20% of tool calls (core's generic contract; cslib declares no H2 override) |
| H3 (reference grounding) | BibKey verification against `references.bib` for all cited theorems (core's generic contract) |
| H4 (adversarial verification) | Self-verification pass challenging every recommendation (cslib's own `cslib-adversarial-verification.md` override -- content identical to core's generic version, deployed under a domain-prefixed basename) |
| H7 (territory contracts) | Explicit file ownership for parallel implementation phases (core's generic contract) |
| H9 (wrap-up discipline) | `sorry_inventory` in every orchestrator handoff JSON (core's generic contract) |
| Goal-state context hygiene | Targeted `lean_goal` queries, bounded file reads, hypothesis pruning -- a deliberate cross-extension additive dependency on lean's `lean4-context-hygiene.md`, since cslib's `--hard` dispatches edit Lean theorem files too |

See `standards/citation-conventions.md` for the BibKey format and the `references.bib`
verification procedure that H3 depends on, and `patterns/lint-fix-wave-assignment.md` for the
conflict matrix used when H7 territory contracts partition parallel work.

## Cost Impact

`--hard` multiplies token cost roughly 3-5x over the standard cslib skills. Reserve it for
formally complex or previously-deflected tasks; it is not a default quality upgrade.
