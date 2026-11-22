# The Half-Line Test

A one-reading triage test for a proposed transport or index condition stated in terms of the
open modals `▷`/`◁` (or an equivalent half-line relaxation of a two-sided agreement condition).
Apply it before attempting a proof or commissioning a new probe: if the test already decides the
proposal, no fresh refutation effort is needed.

## The Test

Any proposal of this shape must answer two questions:

1. Which half-line is the **counter** read from?
2. Which half-line is the **formula** read from?

**Decision rule**: if both answers are "forward," the proposal is already decided. Do not
restate the refuted shape in a half-line form and call it new.

## Why Both-Forward Is Decided

One mechanism per direction, and nothing more:

- **Frozen-future (`◁`) direction** dies to `Probe855O.cntAt_eq_of_pend_eq_fwd`. The countdown at
  a position is determined by the pend profile at or above it, so freeing the entire past buys
  nothing. The headline `Probe855O.futAtomPreservingCountMove_refutedO` carries no hypotheses
  left standing.
- **Freed-future (`▷`) direction** dies to `Probe761S.splice_type_invariance_refuted`. The
  `▷`-shaped count move already exists as the landed splice, and it does not preserve the
  realized stab-free type, because a nested counting formula counts occurrences at unbounded
  forward distance.

There is no third option: the biconditional `⊡φ ↔ ▷◁φ ↔ ◁▷φ` composes exactly these two
projections and introduces nothing else.

## The Pincer

The counter and the closure's eventualities are read from the same forward half-line, so
freezing the future leaves nothing to transport and freeing it loses the type.

## How to Answer the Two Questions

A short procedure:

1. Name the quantity the condition's freedom is read over.
2. Decide whether the counter is forward-determined (reads only at or above the compared
   position).
3. Decide whether the formula's eventuality reach is forward and unbounded.

**Why the test is sharp, not just plausible**: the one-sided forms this test triages are genuine
RELAXATIONS of the refuted two-sided schema, not restatements of it. Refuting a one-sided form is
therefore strictly stronger than the already-recorded two-sided refutation — so a both-forward
proposal is not merely similar to a decided case, it is a weaker case than one already decided.

## The Boundary

This test is a triage, not a blanket refusal. It decides the both-forward region only:

- A genuinely **past-read counter** falls outside the decided region.
- A **`snce`-bearing formula** (the past-looking twin of the forward eventuality) falls outside
  the decided region.

For either, the honest answer is "not decided here," not "refuted" — the past-looking twin is
paper-level and not machine-checked.

## What This Test Does Not Decide

- No decidability consequence is claimed, in either direction.
- No finite-fibre and no finite-width assumption is made; `not_finite_width_fmp` stands
  untouched.
- No recorded Challenge statement is weakened by this test.
- The tight (doubling) chain gap in the ladder-chain decidability route is **not** a
  one-sidedness gap, and this test says nothing about closing it.

## Pointers

- Probe evidence: `specs/evidence/seam-gluing-ray-product/one-sided-count-move-refutation.lean`
  (the half-line test's own statement and both killing mechanisms) and
  `specs/evidence/seam-gluing-ray-product/ladder-splice-type-refutation.lean` (the freed-future
  killing mechanism, `splice_type_invariance_refuted`).
- Sibling: `domain/ladder-counter-observables.md` enumerates the mechanisms defeating a
  clipped-coordinate index — a different job, applied AFTER a candidate survives this test, not
  a restatement of it. Its own six probe citations are not the same six probes this test's
  originating measurement cites; the two "six" sets overlap only partially and neither is a
  subset of the other, so apply this test on its own terms rather than assuming either
  enumeration already covers it.
