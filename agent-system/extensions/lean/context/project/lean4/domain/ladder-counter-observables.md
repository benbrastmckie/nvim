# Ladder Counter Observables: Why Clipping the Counters Cannot Index a Cell

This file records the six mechanisms now known to defeat a clipped-coordinate index of a
deadline-ladder cell, and the gate each one implies. It exists so the next index candidate is
checked against all six BEFORE a proof is attempted, rather than rediscovering them. Three of the
mechanisms refute index SHAPES; the other three refute the ORIGIN of the index's parameters, and
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

## What the counters constrain

Everything a ladder datum must know about the counters is finite arithmetic on region lengths and
idle lengths. Every item below is COMPILED as a theorem of a wired probe; each entry names the
theorem and the probe that carries it.

- **COMPILED: no forward `Rlad` ray is pending forever.** `Count true true` forces `c' + 1 = c`
  along every pending step, so from a state with countdown `c₀` an idle state is reached within
  `c₀ + 1` steps (`exists_idle_of_rlad_ray`, with the contrapositive
  `no_rlad_ray_of_pending_forever`; wired probe
  `specs/evidence/seam-gluing-ray-product/no-pending-forever-ray.lean`). `c₀ + 1` is a count of
  steps.
- **COMPILED: the forward window.** From pending `(q, c, n)` the next region starts after an idle
  run of `j ≥ 1` states, with length `L` the deadline at the last idle state, and `|L - n| ≤ c + j`;
  the achievable `(j, L)` pairs are exactly those. `n` enters the cell only through these windows
  (and their mirror). `forward_window` in
  `specs/evidence/seam-gluing-ray-product/counter-lift-gates.lean`.
- **COMPILED: the backward constraint.** If the current region started `s` steps ago then
  `n ∈ [c - 1, c + 2s + 1]`; so a state with `n < c - 1` has only pending-forever pasts
  (admissible: `gPast_isPath`), and a large gap `n - c` forces a far region start.
  `backward_constraint` in the same probe.
- **COMPILED: the region-doubling inequality.** `L_{k+1} ≤ 2 L_k + j_k + 1` for every consecutive
  pair of regions (backward, `L_k ≥ (L_{k+1} - j_k - 1)/2`): region lengths at most roughly double
  per region plus the idle length, and read backward at most roughly halve. `region_doubling` in
  the same probe, with the bound attained at `j = 1` by `doubling_attained` and iterated by
  `iter_doubling` to `a k + J + 1 ≤ 2^k (a 0 + J + 1)`.
- **COMPILED: the pin lemma, both halves.** Its SOUNDNESS half is the three items above — what the
  counters of an admissible ladder history must satisfy at the pins. Its LIFT half is two
  theorems of the same probe: `drift_extension_of_pins` (a family of pins that is pairwise
  `1`-Lipschitz-compatible extends to a `Drift` deadline function through every pin — the McShane
  extension, least `a + |t - s|` over the pins) and `exists_rlad_hist_of_walk` (an object walk
  along `step` whose countdown is idle-zero, counts down inside a region, is exhausted at a region
  end, and whose region-start values are pairwise compatible, lifts to a full `Rlad` history with a
  prescribed deadline at the origin). This pair is the boundary of what counter arithmetic
  contributes to a lift: everything the counters owe the completeness clause is discharged by it,
  and what remains is a chain-replacement argument on the TYPE sequence, which no counter bound
  supplies.

Two hazards follow from this arithmetic, and both are run as gates BEFORE any sufficiency attempt
on a class-level datum. GAP SHIFT UNDER PUMPING: lengthening the current region by `P` raises `c`
at every earlier position by `P`, so the gap there drops by `P` unless `n` is pumped in step, which
only the previous idle run can absorb. Its gate verdict is COLLISION (`gap_shift_cell_eq`, an
EQUALITY of `cellAt` values on the pair `(c, n)` / `(c + 4, n + 4)` at a fixture of product period
four), with the absorber exhibited as its own theorem `absorber4`: the past ray is an admissible
ladder ray for every countdown at fixed region age, letters and idle-run shape, because the
previous region — which the closure does not pin — may be pending forever with its deadline
unconstrained, or may be an idle-forever run. SHORT IDLE RUNS CANNOT ABSORB: after a short region
and a short idle run the next region's length is fixed by exact small arithmetic, so a class-level
chain must carry enough of `(L_k, j_k)` exactly, which may force the threshold above the
formula-derived depth and must be computed, not guessed. Its gate verdict is SEPARATION
(`short_idle_cell_ne`), with the companion class-collision statement on the index BODY as a SHAPE
(`short_idle_shape_collides`) and both at once (`short_idle_threshold_refuted`). Neither hazard is
a mechanism beyond the six below: both verdicts are compiled, and a gate probing one coordinate
certifies one coordinate.

## The six mechanisms

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
exhibited period `1` (moduli `1` and `2`) under the instantiation convention the
parameter-origin rule below states. Settled by `reach5_eventually_constant`, `walk_mod3`,
`period_collision`, `cell5_ne` and `reach_period_refuted` of the same probe. The modulus must
therefore be a multiple of the period of every letter-definable sub-object of the object; the
reach-set period of the full graph does not. That exhibited period is not even canonical:
`reachN_eventually_periodic`'s `(T, P)` depends on the start set — period `2` from the pending
singleton of the two-state fixture, period `1` from `univ` — and its statement is satisfied by
any multiple of a period, which is a second, independent reason the modulus cannot be read off
the object.

**(6) The period against a sub-object the formula's LETTERS cannot name.** Mechanism (5) forces
the modulus to cover the periods of the sub-objects a formula carves out, and the natural reading
of "carves out" is "forbids a letter of". That reading is too narrow, and the gap is not a corner
case: a formula can forbid a PATTERN instead of a letter, and a pattern can cut out a sub-object no
set of atoms cuts out. On the SAME coprime-cycle object as mechanism (5) with `d` given the letter
of `b`, no atom whatsoever distinguishes the pending state `d` from the pending state `b`
(`lab6_d_eq_b`), so every letter-restricted sub-object keeps `d` exactly when it keeps `b`
(`lab6_keep_d_iff_b`); the 3-cycle `{a, b, c}` is cut out by no set of atoms
(`cycle_not_letter_definable`); wherever a letter restriction keeps the 3-cycle it keeps the 2-cycle
beside it, so the shortest `a`-to-`a` return in any letter-definable sub-object is `2`
(`letter_definable_keeps_two_cycle`); and the full graph's exhibited period is `1`
(`reach5_eventually_constant`). So the letter-definable reading of the modulus clause admits
`P + 1 = 2` on that object. Yet the letter-FREE pattern `(p ∧ ℓ_a) ∧ X X (p ∧ ℓ_a)` — a pending `a`
with a pending `a` exactly two instants later, which the 2-cycle exhibits and the 3-cycle does not —
forbidden at every position by `χ := ¬ψ₂ ∧ ¬(⊤ U ψ₂)`, forces the walk onto the 3-cycle (`pred_of_d`,
`succ_of_d`, `chi_forces_dfree`), and the type containing `endA ∧ χ` is realized at `(a, C, n)` for
`3 ∣ C` and at no history through `(a, C + (P+1), n)` when `3 ∤ P + 1`. Settled by
`period_collision`, `exists_cell_not_phi6`, `phi6_mem_of_mem_cell`, `cell6_ne`,
`joint_parameters_refuted` and `rule_derived_parameters_refuted` of the probe
`specs/evidence/seam-gluing-ray-product/ladder-joint-index-refutation.lean`, the last of these at
the rule's OWN parameters (`T = thrJ φ`, `B = clipJ φ`, `P + 1 = 2`) with `RuleParams` discharged.
The response is to strengthen the modulus clause from the formula's LETTERS to the formula's
CLOSURE — the period of the object-closure product — which is where the clause now stands, and
which turns the first of the four standing proof obligations into a NECESSARY condition rather
than merely a step a proof would take.

Mechanisms (4), (5) and (6) sit entirely inside the FIRST region, where the countdown is deterministic;
neither uses `Drift`, and `n` is held equal across every witnessing pair. The idle drift freedom
that dissolves any "achievable window" at the second region is respected as a constraint, not
argued around.

**The region-interior scope of the certificate rounds' relations.** `coh` and `cohBi` of the
countdown-profile and certificate probes require `pend` at BOTH endpoints
(`step ∧ pend x ∧ pend y ∧ …`), so `certBiInf` and `Realizes` quantify over all-pending
bi-infinite object walks; by the compiled item above (`no_rlad_ray_of_pending_forever`) no such
walk is the object projection of any `Rlad` history. Hence `realizes_of_certAdm_cohBi` is
sufficiency for the INTERIOR of one region: it transfers to the region segments of a ladder
history, and the composition of regions through idle runs — the two `pend` conjuncts dropped in
favour of `Count`/`Drift` clauses on the counter classes — is what the ladder datum still owes.

## The six-part falsification gate, to run BEFORE any proof attempt

For each candidate index, exhibit the separation (or the collision) on each of these pairs, as a
compiled theorem, before attempting sufficiency:

| Gate | Pair | What it probes |
|------|------|----------------|
| 1 | counters `(B, B+1)` against `(B, B+2)` | mechanism (1): does the candidate keep a small gap apart at large counters? |
| 2 | counters `(2B, 4B+2)` against `(2B+1, 4B+2)` — equal next-deadlines, both gaps saturating the clip | mechanism (2): does the candidate keep consecutive countdowns apart? |
| 3 | one region further out, and in the past direction | whether the candidate's coordinates survive a second region boundary and a `snce`-reachable region start |
| 4 | `(q, T, n)` against `(q, T + (P+1), n)` at `n = T + (P+1) + B`, under the depth-`(T+1)` next-chain `X^(T+1) r` | mechanism (4): is the threshold at least the formula's `untl`-nesting depth? A threshold fixed before the formula collides here for EVERY `(T, P, B)` |
| 5 | on the coprime-cycle object, `(a, 3(P+1)(T+1), n)` against `(a, 3(P+1)(T+1) + (P+1), n)` at `n = 3(P+1)(T+1) + (P+1) + B`, under `p U (r ∧ ℓ_a)` with `⊤ U ℓ_d` in the closure | mechanism (5): is the modulus a multiple of the period of the letter-restricted sub-object? The full-graph reach-set period `1` collides here at every modulus coprime to `3` |
| 6 | the same pair on the same object with `d` RELABELLED to `b`'s letter, under `endA ∧ χ` with `χ` forbidding the letter-free pattern `(p ∧ ℓ_a) ∧ X X (p ∧ ℓ_a)` | mechanism (6): is the modulus a multiple of the period of every sub-object the formula's CLOSURE carves out, and not merely of every one its LETTERS name? A modulus admitted by the letter-definable reading collides here at every modulus coprime to `3` |

**Gates 4, 5 and 6 are REFUTATIONS of the exhibited parameters, not separations the candidate
passes.** The six-coordinate residue-carrying candidate survives gates 1–3 and fails gates 4 and 5
at BOTH of its object-exhibited parameters, uniformly in the clip bound. The SAME candidate at
parameters derived from the object and the formula jointly, with the modulus read off the
letter-definable sub-objects, survives gates 1–3, DISARMS gates 4 and 5 (`gate4_disarmed`,
`gate4_diagonal_escapes`, `gate5_disarmed` of the sixteenth probe — in each case by exhibiting the
separation failing, not by observing a hypothesis go unsatisfiable) and fails gate 6. A candidate
whose modulus is derived from the object-closure product is what gate 6 is to be run against;
nothing above says such a candidate passes it.

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
- **`T` has a THIRD source besides the formula and semantic periodicity: the CASCADE BOUND** — the
  largest region countdown a rigid (all-exact) past can force. Its arithmetic is `iter_doubling`:
  `a k + J + 1 ≤ 2^k (a 0 + J + 1)` from `a (k+1) ≤ 2 a k + J + 1`, so a chain of `k` pinned
  regions with idle runs of length at most `J` forces the current countdown EXPONENTIALLY in `k`
  and not linearly. The threshold must therefore dominate the cascade bound as well, and that
  bound is a count read off `Count`/`Drift` — never a complexity claim and never an upper bound on
  anything. This clause, like the two above, constrains a COORDINATE of the carrier and not an
  index: see the carrier-coordinate clause below.
- **`P + 1`, the modulus, must be a multiple of the period of every sub-object the formula's
  CLOSURE can carve out** — equivalently, of the period of the product of the object with the
  closure. Two weaker readings are refuted. The reach-set period of the full step graph, which
  `reachN_eventually_periodic` exhibits, does not suffice: mechanism (5) refutes it on an object
  with two pending cycles of coprime lengths. Neither does the period of every LETTER-DEFINABLE
  sub-object: mechanism (6) refutes that on the same object with two states made label-identical,
  where a formula forbidding a pattern rather than a letter carves out a sub-object no set of atoms
  carves out. So this clause couples the modulus to the object AND the formula's whole closure, not
  merely its letters. The clause is a DIVISIBILITY condition rather than a magnitude one:
  `reach_period_refuted` and `cell6_ne` both have hypothesis `3 ∤ P + 1`, so a modulus of `100`
  exceeds `3` and is refuted all the same.
- **The instantiation convention for that modulus.** `P` is a modulus minus one — both residue
  coordinates are taken modulo `P + 1` — so an instantiation is specified by naming the modulus
  `m` with `1 ≤ m` and setting `P := m - 1`, and a period `p` from `reachN_eventually_periodic`
  (which gives `1 ≤ p`) enters as `m := p`. `2 ≤ m` is forced: at `m = 1` both residue
  coordinates are constant and the index collapses to the clipped-coordinate candidate already
  refuted at the countdown coordinate.
- Deriving the gap clip from the counters, or the threshold and the modulus from the OBJECT
  ALONE, is the error this rule exists to prevent.
- **The completeness clause the rule serves must PUMP, and cannot be positionwise.** This is
  compiled, not conjectured: `no_positionwise_lift` (in
  `specs/evidence/seam-gluing-ray-product/counter-lift-gates.lean`) shows that for EVERY finite
  quotient `K`, every `κ : ℕ × ℕ → K`, and every relation on `Bool × K` that is SOUND for a
  two-state object, some chain over `K` is the projection of no admissible ladder history. Its
  mechanism is a Lipschitz-tight history (a length-one region pinning `0`, an idle climb to `m`, a
  region of countdown `m` pinning `m`), a class repeat along the climb by pigeonhole, and the cut
  chain whose two pins sit at distance `< m`, which `Drift` forbids. So the completeness half of
  any lift over a quotient of the counters is to be stated in PUMPING form — loops inserted or
  deleted in saturated zones with the state at the origin kept — and a positionwise clause is not
  to be filed at any parameters. The refutation is of a STATEMENT SHAPE, not of the datum: it says
  the lift must pump, not that no lift exists.
- **Carrier coordinate versus index.** A tuple of this shape is a coordinate `K` of the carrier
  `Q × ClType φ × K` over which a set-valued datum `D` is computed, and `D` — not `K` — is what
  factors `cellAt`. `K`'s parameters are outputs of the counter-lift lemma (the first repeat of the
  realizable-type iteration on the object-closure product), and when they are, the three clauses
  above are satisfied by construction rather than exhibited. Stating `K` as an index of cells at
  any parameters is the refuted claim and is not to be filed.

## What is still open

**The positive factorization lemma — for any index, in any shape — is OPEN.** It is claimed
nowhere. The residue-carrying candidate at its object-exhibited parameters is REFUTED (mechanisms
(4) and (5)); the SAME candidate at parameters derived from the object and the formula jointly with
the modulus read off the LETTER-DEFINABLE sub-objects is REFUTED too (mechanism (6)), which is the
reason the modulus clause above now reads "closure" and not "letters". What is left open is a
modulus derived from the object-closure product, and that is a DIFFERENT candidate: it has not been
gated, let alone proved, and nothing on record says such a modulus is computable or would suffice.
The proof obligations a successor would meet, named so they are not rediscovered: eventual
periodicity of the realizable types in the countdown over the product of the object with the
closure — which mechanism (6) promotes from a step a proof would take to a NECESSARY condition on
the modulus itself; a region-length pumping lemma for `untl`/`snce`-depth-bounded formulas; the next
deadline's coupling through `Drift`; and the `box`/`stab` letters through the anchor-layer
equations.

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

The direction is CHOSEN: presentation (a), the set-valued per-state datum — `D`, the maximum
`certAdm`-certified subset of the carrier `Q × ClType φ × K`, with the realization theorem the
fibre equation and the factorization lemma for `K` its corollary. The open problem on which it
rests is the COUNTER-LIFT LEMMA: soundness and completeness of the class-level `Count`/`Drift`
relation over that carrier (every `RladAdm` history projects to a class-level chain; every such
chain lifts), gated by gates 1, 2 and 9 and the two hazards above before any sufficiency attempt;
`certStab` must be rebuilt per `(q, κ)`. A seventh mechanism resistant to every `K` of the forced
shape would close the ladder route for BOTH presentations, on evidence. No tuple index is to be
stated at any parameters: the refutations above add a necessary condition on any index's
parameters, and the decision adds that `K` is a carrier coordinate, not an index.
