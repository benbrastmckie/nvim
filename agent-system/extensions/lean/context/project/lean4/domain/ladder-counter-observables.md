# Ladder Counter Observables: Why Clipping the Counters Cannot Index a Cell

This file records the three mechanisms now known to defeat a clipped-coordinate index of a
deadline-ladder cell, and the gate each one implies. It exists so the next index candidate is
checked against all three BEFORE a proof is attempted, rather than rediscovering them.

The subject is the admissible ladder carrier `LadderState Q pend := {x : Q × ℕ × ℕ // x.2.1 ∈
Adm pend x.1}` of `FormalSystem/Metalogic/Decidability/RaySummary/LadderModel.lean`, whose states
are `(q, c, n)`: an object state, a current deadline (countdown) and a next deadline. The realized
cells of `ladderModel` are `cellAt`, and the open question is a computable INDEX through which
`cellAt` factors — a `Fintype I` and a map `LadderState Q pend → I` with
`index x = index y → cellAt … x = cellAt … y`.

## The structural fact that makes every "clip the counters" proposal fail

`Count`'s no-early-discharge clause (`Count true true c n c'` forces `c' + 1 = c`) runs a pending
region's countdown down to `0` exactly. So the region's FIRST IDLE STATE sits at distance exactly
`c + 1` — an unbounded distance, determined by the countdown alone.

The step relation is independent of the counters. It is therefore free to compute anything it
likes along a region and deposit the result on the state that ends it. Whatever it deposits is
visible to a formula at the region's start under a single `untl`, at distance `c + 1`. Clipping
`c` destroys exactly the information that locates that state.

Two corollaries worth stating separately. The idle interval between regions may be of ANY length
(`Count false false` pins the countdown at `0`) while `Drift` moves the next deadline by one per
step in either direction, so every next-deadline value is reachable before the following region
starts, and `Count false true` hands that value to the new region as its length. And a gap rises
by at most two per pending step and is at most one at a region start, so a state with a large gap
has its region start proportionally far back.

## The three mechanisms

**(1) The gap at the first idle state.** `Count`'s region-start clause reads `c' = n`, so the gap
`n - c` is observable through a formula of the shape `p U (r ∧ X(p ∧ X r))` (with `X χ := ⊥ U χ`).
Settled by `cell_ne`, `exhibited_form_refuted` and `exists_form_refuted` of the probe
`specs/evidence/seam-gluing-ray-product/ladder-cell-refutation.lean`: an index on the counter pair
`(min c B, min n B)` alone fails at every bound, because bounding each counter bounds nothing the
cells depend on. This mechanism kills a SMALL gap at LARGE counters — it is genuinely gap-shaped,
and a gap coordinate is the right response to it.

**(2) The object state at the region end — the countdown residue.** Independently of (1), the step
relation may alternate a tag on every pending step and copy it onto the idle state ending the
region; an atom reading that tag under `p U (r ∧ a)` reads `c mod 2` at distance `c + 1`. Settled
by `truth_phiP`, `cell_succ_ne`, `index_collide` and `ladderIndex_not_factoring` of the probe
`specs/evidence/seam-gluing-ray-product/ladder-cell-index-obstructions.lean`: the cells at
`(q, c, n)` and `(q, c+1, n)` differ for EVERY `c` and `n` with `n` held FIXED, so no index whose
countdown coordinate has finite range is sound. The witnessing pair carries EQUAL next-deadlines
and two gaps that both saturate the clip, so mechanism (1) is not what is firing — the countdown
coordinate is. In general what is observable at the region end is `step`-reachability in `c + 1`
steps, which is eventually periodic (`iterate_eventually_periodic`,
`reachN_eventually_periodic`), so the response to this mechanism is a RESIDUE coordinate beside
the threshold one, taken at the object's own threshold and period.

**(3) Finite width.** The alternative to indexing the carrier is bounding it — replacing the
carrier by its deadline-bounded sub-carrier, which is a `Fintype` outright. That sub-carrier is
indeed finite (`bounded_ladder_finite`), and on a finite carrier the run layer's finite-branching
frame constructor is definitionally the sliced-step one (`finBranch_eq_ofSlicedStep`, by `rfl` —
the two differ only in which proof discharges `Saturation`, and proof irrelevance is
definitional). But then every model on such a frame validates the finite-width non-validity
(`bounded_width_validates_Phi_neg`), which is not valid over integer time
(`Phi_neg_not_valid`). The route's premise — that every refutable formula has a refuting ladder
object with bounded deadlines — is therefore false, and the same probe carries the closure. The
narrow carve-out: a bounded carrier remains available for a target that DOES have a finite-width
countermodel, per `not_finite_width_fmp`'s own disclaimer. What is refuted is the bounded-carrier
route as the GENERAL route, not the bounded carrier as a device. `RunLayer.lean`'s own design
decision against capping the counters records the same obstruction.

## The three-part falsification gate, to run BEFORE any proof attempt

For each candidate index, exhibit the separation (or the collision) on each of these pairs, as a
compiled theorem, before attempting sufficiency:

| Gate | Pair | What it probes |
|------|------|----------------|
| 1 | counters `(B, B+1)` against `(B, B+2)` | mechanism (1): does the candidate keep a small gap apart at large counters? |
| 2 | counters `(2B, 4B+2)` against `(2B+1, 4B+2)` — equal next-deadlines, both gaps saturating the clip | mechanism (2): does the candidate keep consecutive countdowns apart? |
| 3 | one region further out, and in the past direction | whether the candidate's coordinates survive a second region boundary and a `snce`-reachable region start |

**The lesson that makes this a three-part gate: a gate probing one coordinate certifies one
coordinate.** The candidate refuted by mechanism (2) had passed a sound, non-vacuous one-part gate
on mechanism (1) (`gate_separates` separates that pair for every clip bound of at least two;
`gate_collides_below_two` shows it collides below two). Passing one gate says only that one
mechanism does not lift.

## The parameter-origin rule

A candidate of the form `(q, min c T, c % (P+1), min n T, n % (P+1), clip (n - c) [-B, B])` has
three parameters, and they come from DIFFERENT places. Never cross them:

- **`B`, the gap clip, comes from the FORMULA** — its `X`-nesting depth, or `|cl φ|`, and (the
  past-direction refinement) its `snce`-nesting depth as well. It must exceed the gaps the formula
  can see, which is why `gate_collides_below_two` is a LOWER bound on `B` rather than a defect.
- **`T` and `P`, the threshold and period, come from the OBJECT** — exhibited by
  `reachN_eventually_periodic` as the threshold and period of the object's own reachability map,
  not assumed and not derived from the formula.
- Deriving the gap clip from the counters, or the threshold and period from the formula, is the
  error this rule exists to prevent.

## What is still open

**The positive factorization lemma — for any index, in any shape — is OPEN.** It is claimed
nowhere. The gated residue-carrying candidate above survives all three gates on the fixture family
those gates are built from; that is evidence that the known mechanisms and the nearest unknown one
do not lift, and it is NOT a proof that the candidate suffices.

What is NOT open, and must not be re-attacked as though it were: the SET of cells is finite and
bounded (`anchorCells_finite`, `anchorCells_ncard_le`), untouched by any of this; only the
computable INDEX is absent. And the `box`/`stab` acceptance clause rides on that same index
(`stab_mem_tpOf_iff` is the stab letter of THAT cell), so nothing above licenses dropping the
clause to make a realization structure writable — a same-named weaker statement is the one defect
this record exists to prevent.

If the gated candidate falls in turn, the direction on record is a different presentation of a
cell — a set-valued per-state datum over a quotient — and not a wider tuple.
