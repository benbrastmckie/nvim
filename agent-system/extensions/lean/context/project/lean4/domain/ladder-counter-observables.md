# Ladder Counter Observables: Why Clipping the Counters Cannot Index a Cell

This file records the five mechanisms now known to defeat a clipped-coordinate index of a
deadline-ladder cell, and the gate each one implies. It exists so the next index candidate is
checked against all five BEFORE a proof is attempted, rather than rediscovering them. Three of the
mechanisms refute index SHAPES; the other two refute the ORIGIN of the index's parameters, and
they are the reason the parameter-origin rule below reads as it does.

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

## The five mechanisms

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

**(4) The threshold against the formula's depth.** `PlusTruthAt`'s `untl` clause is strict in both
bounds, so over integer time `⊥ U χ` is exactly "`χ` at the next instant", and `T + 1` nested
nexts ending in the idle letter read whether the region's forced first idle state sits at distance
EXACTLY `T + 1`. With the threshold `T` fixed before the formula is, the pair `(q, T, n)` against
`(q, T + (P+1), n)` at `n = T + (P+1) + B` collides in the six-coordinate index for EVERY
`(T, P, B)` — both countdowns saturate the threshold, both residues agree, `n` is shared, both
gaps clip — while the depth-`(T+1)` next-chain separates their cells. Settled by `truth_nextPow`,
`depth_collision`, `cell_depth_ne` and `object_only_parameters_refuted` of the probe
`specs/evidence/seam-gluing-ray-product/ladder-residue-index-refutation.lean`, on the same
two-state fixture as mechanism (2), with the forced run stated generically in the object
(`pending_run_gen`, `idle_at_gen`: only `Count` is used). The threshold must therefore be at least
the formula's `untl`-nesting depth — formula-derived, like `B`.

**(5) The reach-set period against a letter-restricted sub-object.** The period exhibited by
`reachN_eventually_periodic` is the period of the reach-SET iteration of the FULL step relation.
But a formula can forbid a letter, and a forbidden letter restricts the object to a sub-object
whose pending cycle structure has a different period. On the object whose pending part is a
3-cycle `a → b → c → a` and a 2-cycle `a → d → a` sharing `a`, the reach sets from `a` are
CONSTANT from threshold `4` on (period `1`, exhibited in exactly the shape
`reachN_eventually_periodic` returns, and minimal), yet every `d`-free pending walk from `a` back
to `a` has length `0 mod 3`. Under `p U (r ∧ ℓ_a)` with `⊤ U ℓ_d` in the closure, the type
containing the first and lacking the second is realized at `(a, C, n)` for `3 ∣ C` and at no
history through `(a, C + (P+1), n)` whenever `3 ∤ P + 1` — which covers BOTH readings of the
exhibited period `1` under the unrecorded `P` versus `P + 1` instantiation convention (moduli `2`
and `1`). Settled by `reach5_eventually_constant`, `walk_mod3`, `period_collision`, `cell5_ne` and
`reach_period_refuted` of the same probe. The modulus must therefore dominate the period of every
letter-definable sub-object of the object; the reach-set period of the full graph does not.

Both (4) and (5) sit entirely inside the FIRST region, where the countdown is deterministic;
neither uses `Drift`, and `n` is held equal across every witnessing pair. The idle drift freedom
that dissolves any "achievable window" at the second region is respected as a constraint, not
argued around.

## The five-part falsification gate, to run BEFORE any proof attempt

For each candidate index, exhibit the separation (or the collision) on each of these pairs, as a
compiled theorem, before attempting sufficiency:

| Gate | Pair | What it probes |
|------|------|----------------|
| 1 | counters `(B, B+1)` against `(B, B+2)` | mechanism (1): does the candidate keep a small gap apart at large counters? |
| 2 | counters `(2B, 4B+2)` against `(2B+1, 4B+2)` — equal next-deadlines, both gaps saturating the clip | mechanism (2): does the candidate keep consecutive countdowns apart? |
| 3 | one region further out, and in the past direction | whether the candidate's coordinates survive a second region boundary and a `snce`-reachable region start |
| 4 | `(q, T, n)` against `(q, T + (P+1), n)` at `n = T + (P+1) + B`, under the depth-`(T+1)` next-chain `X^(T+1) r` | mechanism (4): is the threshold at least the formula's `untl`-nesting depth? A threshold fixed before the formula collides here for EVERY `(T, P, B)` |
| 5 | on the coprime-cycle object, `(a, 3(P+1)(T+1), n)` against `(a, 3(P+1)(T+1) + (P+1), n)` at `n = 3(P+1)(T+1) + (P+1) + B`, under `p U (r ∧ ℓ_a)` with `⊤ U ℓ_d` in the closure | mechanism (5): does the modulus dominate the period of the letter-restricted sub-object? The full-graph reach-set period `1` collides here at every modulus coprime to `3` |

**Gates 4 and 5 are REFUTATIONS of the exhibited parameters, not separations the candidate
passes.** The six-coordinate residue-carrying candidate survives gates 1–3 and fails gates 4 and 5
at BOTH of its object-exhibited parameters, uniformly in the clip bound. A candidate whose
threshold and modulus are formula-derived in the sense of the rule below is what gates 4 and 5
are to be run against; nothing above says such a candidate passes them.

**The lesson that makes this a multi-part gate: a gate probing one coordinate certifies one
coordinate.** The candidate refuted by mechanism (2) had passed a sound, non-vacuous one-part gate
on mechanism (1) (`gate_separates` separates that pair for every clip bound of at least two;
`gate_collides_below_two` shows it collides below two), and the candidate refuted by mechanisms
(4) and (5) had passed gates 1–3. Passing a gate says only that one mechanism does not lift.

## The parameter-origin rule

A candidate of the form `(q, min c T, c % (P+1), min n T, n % (P+1), clip (n - c) [-B, B])` has
three parameters. The rule below is NECESSARY — each clause is proved by a refutation — and its
sufficiency is OPEN:

- **`B`, the gap clip, comes from the FORMULA** — its `X`-nesting depth, or `|cl φ|`, and (the
  past-direction refinement) its `snce`-nesting depth as well. It must exceed the gaps the formula
  can see, which is why `gate_collides_below_two` is a LOWER bound on `B` rather than a defect.
- **`T`, the threshold, comes from the FORMULA as well** — at least its `untl`-nesting depth.
  Mechanism (4) refutes every threshold fixed independently of the formula: the exact distance to
  the forced first idle state is observable to the formula's depth, and no object-exhibited
  threshold bounds that depth.
- **`P + 1`, the modulus, must dominate the period of every letter-definable sub-object of the
  OBJECT** — the reach-set period of the full step graph, which `reachN_eventually_periodic`
  exhibits, does not. Mechanism (5) refutes the full-graph period on an object with two pending
  cycles of coprime lengths; which periods a formula can carve out depends on which letters it can
  forbid, so this clause couples the modulus to the object AND the formula's letters jointly.
- Deriving the gap clip from the counters, or the threshold and the modulus from the OBJECT
  ALONE, is the error this rule exists to prevent.

## What is still open

**The positive factorization lemma — for any index, in any shape — is OPEN.** It is claimed
nowhere. The residue-carrying candidate at its object-exhibited parameters is REFUTED (mechanisms
(4) and (5)); the candidate with parameters depending on the object and the formula jointly, as the
rule above requires, is the open one, and it has not been gated, let alone proved. The proof
obligations a successor would meet, named so they are not rediscovered: eventual periodicity of
the realizable types in the countdown over the product of the object with the closure; a
region-length pumping lemma for `untl`/`snce`-depth-bounded formulas; the next deadline's coupling
through `Drift`; and the `box`/`stab` letters through the anchor-layer equations.

What IS proved positively is fixture-level only. On the two-state object, where every history
through a pending state is forced onto one object path (`qp_forced_path`), the cell at a pending
state is a singleton determined by the object state, the countdown's parity, and whether the
countdown is at least a formula-derived threshold `thr φ` — two per `untl` nesting, nothing per
`snce` — for box/stab-free `φ` and ANY next deadlines (`qp_cell_eq_of_depth_parity`, with
`qp_truth_of_objPath` and `qp_type_shift`, in the same probe as mechanisms (4) and (5)). That is
the one-path special case: the general object has region restarts, so its histories through a
pending state do not share an object path, and that is exactly the gap between this theorem and
the lemma.

What is NOT open, and must not be re-attacked as though it were: the SET of cells is finite and
bounded (`anchorCells_finite`, `anchorCells_ncard_le`), untouched by any of this; only the
computable INDEX is absent. And the `box`/`stab` acceptance clause rides on that same index
(`stab_mem_tpOf_iff` is the stab letter of THAT cell), so nothing above licenses dropping the
clause to make a realization structure writable — a same-named weaker statement is the one defect
this record exists to prevent.

The direction on record for a successor is a different presentation of a cell — a set-valued
per-state datum over a quotient — and not a wider tuple; the refutations above add a necessary
condition on any index's parameters and choose no successor.
