# ℤ-Time Has No Finite-Carrier Finite Model Property — and No Finite-Width One Either

This note exists so that one fact is never rediscovered a third time. Two independent
certificate-design rounds (`specs/703_lplus_compression_and_completeness/reports/02_semantics-first-compression-research.md`
and `specs/706_lplus_finite_model_property_and_completeness/reports/01_lplus-finite-model-property-research.md`)
each had to re-derive the same fact's consequence for certificate design, and in both cases the
re-derivation happened only *after* a certificate type had been specified against the wrong
assumption. Until then the fact lived in an archived probe and one paragraph of
`FormalSystem/Metalogic/Decidability/BiLasso/README.md`, neither of which is on any path a
design round reads. What it records: (1) the finite-**carrier** finite model property fails for
L and L⁺ over ℤ-time, so a ℤ-time certificate class must present an infinite, finitely presented
carrier; (2) that rule is **necessary but not sufficient**, because the finite-**width** property
fails too (section 6) — no class presenting finite per-time fibres is complete for any target
carrying `⊡`; (3) the published counterpart of both the obstruction and the remedy; and (4) the
warning that FMP failure is *not* an undecidability result. Every Lean name below is fully
qualified and lives in the ProofChecker (BimodalLogic) tree or in the named probe file.

## 1. The fact

Let `p` be a sentence letter, `Fp := ⊤ U p` and `Pp := ⊤ S p`. The witness is

```
θ := □(p ∨ Fp ∨ Pp) ∧ □(p → ¬Pp)
```

Read without the stability modal: *every history meets `p` somewhere, and never twice from the
left* (a `p`-time has no earlier `p`-time on the same history). `θ` is `⊡`-free — it is
`ofFormula` of an L formula — so the following holds already for L, not only for L⁺:

- `θ.neg` is a genuine ℤ-time non-validity: `θ` holds on the ℤ-carrier shift set with `p` true
  exactly at state `0`.
- `θ` has **no model on any regular ℤ-frame with a finite world-state carrier**, at any history
  and any time. So `θ.neg` has no finite countermodel.

The CTL-like-fragment variant, in which every `⊡` and every `□` governs a state formula or a
single temporal operator over state formulas, fails the same way:

```
θ' := □(p ∨ ⊡Fp ∨ ⊡Pp) ∧ □(p → ⊡¬Pp)
```

In primitive syntax (`⊤ := ⊥ → ⊥`, `Fp := untl ⊤ p`, `Pp := snce ⊤ p`):

```
A  := □(¬p → (¬Fp → Pp))          C  := □(p → (Pp → ⊥))          θ  := ¬(A → ¬C)
A' := □(¬p → (¬⊡Fp → ⊡Pp))        C' := □(p → ⊡(Pp → ⊥))         θ' := ¬(A' → ¬C')
```

Both are satisfied on the shift set with carrier `ℤ`, `sh w d = w + d`, and `p` true exactly at
`0`, at the point `(S.hist 0, 0)`.

## 2. The machine-checked source

The source is the sorry-free probe
`specs/706_lplus_finite_model_property_and_completeness/probes/NoFiniteCarrierModel.lean`,
compiled from the repository root with

```
lake env lean specs/706_lplus_finite_model_property_and_completeness/probes/NoFiniteCarrierModel.lean
```

Its `#print axioms` lines all read `[propext, Classical.choice, Quot.sound]`.

| Declaration (namespace `Probe706`) | Statement |
|---|---|
| `θ_eq_ofFormula` | `θ = ofFormula ψL`, by `decide` — the witness is `⊡`-free |
| `not_plusValidZTime_neg_θ` | `¬ PlusValidZTime θ.neg` |
| `no_finite_carrier_sat` | for every regular ℤ-frame `F` with `[Finite F.WorldState]`, every model `M`, history `τ` and time `t`: `¬ PlusTruthAt M τ t θ` |
| `no_ofStep_sat` | the same at `FrameOver.ofStep R fwd bwd` for any `[Finite W] [Nonempty W]` and any bi-serial `R` |
| `not_finite_carrier_fmp` | `¬ ∀ φ, ¬ PlusValidZTime φ → ∃ F regular, Finite F.WorldState, M, τ, t, ¬ PlusTruthAt M τ t φ` |
| `not_plusValidZTime_neg_θ'`, `no_finite_carrier_sat'`, `not_finite_carrier_fmp_fragment` | the same three for `θ'`, i.e. inside the CTL-like fragment |

The L-side twin is `Probe476.fmp_false` in
`specs/archive/476_box_faithful_small_model_theorem/evidence/fmp-hypothesis-is-false.lean`
(guarded by `scripts/check-evidence-probes.sh`), which refutes the finite-`IntPresentation`
candidate-list hypothesis for `Formula` with the same witness.

**These declarations are probe-level, not library-level.** None of them is landed under
`FormalSystem/` or listed in `docs/theorem-index.md`. Whoever lands them (the natural home is
beside `FormalSystem/Metalogic/Decidability/PlusWitnessFamily/Incompleteness.lean`) should
update this section to cite the landed names.

## 3. The pumping argument

In the order the probe runs it:

1. `□` is history- and time-independent
   (`FormalSystem.Metalogic.Decidability.plusBox_const`), so the first conjunct `A` says that
   *every* history meets `p` somewhere and the second conjunct `C` says that a `p`-time has no
   earlier `p`-time on the same history — both read at every time, by shifting.
2. Take the history `τ` at which `θ` is supposed to hold. By `A` it meets `p` at some time `a`.
   By `C`, every time `b < a` on `τ` is `p`-free.
3. Pigeonhole (`Finite.exists_ne_map_eq_of_infinite`, Mathlib) on the states
   `τ.state (a - 1 - i)` for `i : ℕ` gives two times `x < y ≤ a - 1` with `τ.state x = τ.state y`.
4. The cycle between `x` and `y`, repeated bi-infinitely, is a bi-infinite step path; over ℤ a
   bi-infinite step path *is* a history
   (`FormalSystem.Semantics.FrameOver.mem_HF_iff_adjacent`, constructed by
   `FormalSystem.Semantics.FrameOver.worldHistoryOfStepPath`). That history never meets `p`,
   contradicting `A`.

Nothing about `⊡` enters. The only facts used are limit closure over ℤ (every step path is a
history) and finiteness of the carrier. The positive half is the `ShiftSet` on carrier `ℤ` with
`p` at `0` only; the fragment variant `θ'` additionally uses
`FormalSystem.Semantics.ShiftSet.total_eq_orbit` to collapse each `⊡` on that single-history
frame.

## 4. Why this is the certificate type, not a bound

`FormalSystem.Semantics.FrameOver.ofStep` (`FormalSystem/Semantics/IntNormalForm.lean`) takes
a bi-serial relation on a type `W` and requires `[Finite W]`; it discharges *Saturation* through
`FormalSystem.Semantics.TaskFrame.saturation_of_finite`. Any certificate whose soundness
presents its frame as `FrameOver.ofStep` on `Fin n` therefore presents a finite carrier by
construction, and `Probe706.no_ofStep_sat` says such a frame satisfies `θ` **nowhere** — for
every `n`, every relation, every valuation, every history and every time. There is no `n` in the
statement to enlarge, no checker clause to add, and no liveness formulation to switch to: the
defect is in the *type* of object presented, and that alone is fatal.

The three readings this guards against, each wrong:

- "the fmp fails, so a finite graph with a large enough `n` will do" — wrong in kind, as above;
- "the fmp fails, so decidability is hopeless" — wrong by published example, see section 9;
- "retreat to an abstract fmp" — unavailable here, see section 9.

## 5. The design rule and its landed embodiment

A ℤ-TIME CERTIFICATE CLASS MUST PRESENT AN INFINITE, FINITELY PRESENTED CARRIER — `ℤ × Fin n`
WITH FINITE FIBRES, VIA `TaskFrame.saturation_of_fib_finite` — NEVER A FINITE ONE VIA
`FrameOver.ofStep`.

**This rule is necessary but not sufficient.** Section 6 records the second refutation: a class
that satisfies this rule to the letter, presenting `ℤ × Fin n`, is still incomplete for any
target carrying `⊡`. Do not record, cite, or design against the carrier rule alone.

The rule's landed embodiment, all under `FormalSystem/`:

| What | Lean name | Where |
|---|---|---|
| The frame constructor on the infinite carrier `ℤ × W` | `FormalSystem.Semantics.FrameOver.ofSlicedStep` | `Semantics/SlicedFrame.lean` |
| Its carrier is not finite — proved, not asserted | `FormalSystem.Semantics.FrameOver.ofSlicedStep_not_finite_worldState` | `Semantics/SlicedFrame.lean` |
| The same, restated at a certificate `G` | `FormalSystem.Metalogic.Decidability.PlusSlicedCertificate.frame_worldState_not_finite` | `Metalogic/Decidability/PlusSlicedCertificate/Frame.lean` |
| *Saturation* from finite fibres (no finite carrier needed) | `FormalSystem.Semantics.TaskFrame.saturation_of_fib_finite` | `Semantics/TaskFrame.lean` |
| *Limit* from the successor order on ℤ | `FormalSystem.Semantics.TaskFrame.limit_of_succOrder` | `Semantics/TaskFrame.lean` |
| Histories of the presented frame are exactly the sliced step paths | `FormalSystem.Metalogic.Decidability.PlusSlicedCertificate.mem_HF_iff_slicedPath` | `Metalogic/Decidability/PlusSlicedCertificate/Frame.lean` |
| The finite-graph special case, exhibited rather than asserted | `FormalSystem.Metalogic.Decidability.PlusSlicedCertificate.onePointCertificate` | `Metalogic/Decidability/PlusSlicedCertificate/Basic.lean` |

`FrameOver.ofSlicedStep`'s own docstring says it: this is *not* `FrameOver.ofStep` at a different
carrier and is not reducible to it, because `ofStep` requires `[Finite W]` on the whole carrier,
which is exactly what is given up. `PlusSlicedCertificate/Sound.lean`'s header states the
obstruction in prose ("a certificate presenting a finite-carrier frame cannot certify it; the
finite data lives in the *fibres*"), and `PlusSlicedCertificate.lean`'s module docstring carries
it as its bullet **the finite carrier**.

Two rows of `docs/theorem-index.md` bracket what the sliced class does and does not achieve:

- `FormalSystem.Metalogic.Decidability.PlusSharingWitnessFamily.not_exists_plusCertifies_pumpTarget`
  — the earlier sharing class is incomplete and no bound repairs it (a *different* obstruction;
  see section 7);
- `FormalSystem.Metalogic.Decidability.WitnessFamily.exists_plusSlicedCertificate_of_not_plusValidZTime_ofFormula`
  — every ℤ-time non-validity of an embedded L formula admits an accepted sliced certificate, so
  the sliced class is complete on `⊡`-free targets. Section 6 is about what happens off them.

## 6. Finite width fails too

The carrier rule of section 5 is satisfied by `ℤ × Fin n`. That is not enough. The sorry-free
probe `specs/710_sliced_class_incompleteness_characterization/probes/NoFiniteWidthModel.lean`,
compiled with

```
lake env lean specs/710_sliced_class_incompleteness_characterization/probes/NoFiniteWidthModel.lean
```

(four `#print axioms` lines, each `[propext, Classical.choice, Quot.sound]`), shows that **no
class presenting finite per-time fibres is complete, whatever its clauses**. The witness, inside
the CTL-like fragment, is

```
Φ := θ' ∧ □(⊡Fp → ¬⊡¬Xp)        with   Xp := ⊥ U p
```

`Xp` is "`p` at the next time". Call a state *pre* if every history through it still has `p`
strictly ahead, and *post* if every history through it has `p` strictly behind. `θ'` says every
history meets `p` exactly once; the new conjunct `D := □(⊡Fp → ¬⊡¬Xp)` says that at every
*pre* state, some history reaches `p` at the very next time.

| Declaration (namespace `Probe710`) | Statement |
|---|---|
| `not_plusValidZTime_neg_Φ` | `¬ PlusValidZTime Φ.neg` — the positive half, on a *countable, finitely branching, time-homogeneous* regular ℤ-frame with carrier `Node = {pre k} ∪ {x k} ∪ {post k j}` and steps `pre (k+1) → pre k`, `pre k → x k`, `x k → post k 0`, `post k j → post k (j+1)`; `p` holds exactly at the `x k` |
| `no_finite_width_sat` | for every `[Finite W]`, every time-indexed bi-serial `R : ℤ → W → W → Prop`, every model `M` on `FrameOver.ofSlicedStep R fwd bwd`, history `τ` and time `t`: `¬ PlusTruthAt M τ t Φ` |
| `not_certifies` | for every `G : PlusSlicedCertificate [] [Φ.neg]`, `¬ G.Certifies` |
| `not_sliced_complete` | `¬ ∀ ψ, ¬ PlusValidZTime ψ → ∃ G : PlusSlicedCertificate [] [ψ], G.Certifies` — the time-sliced class is incomplete for L⁺ over ℤ-time |
| `not_finite_width_fmp` | `¬ ∀ φ, ¬ PlusValidZTime φ → ∃ W, Finite W, Nonempty W, R, fwd, bwd, M, τ, t, ¬ PlusTruthAt M τ t φ` over `FrameOver.ofSlicedStep R fwd bwd` — no finite-width sliced frame hosts a countermodel to `Φ.neg` |

The argument, in the probe's order (its `PreN` / `PostN` / `core_false` section):

1. Every state is a `p` state, *pre*, or *post*; predecessors of a `p` state are pre, so `D`
   forces `p` states at every time `≤ a` once a `p` state sits at time `a`.
2. Successors of `p` states and of post states are post.
3. A post state has **no infinite backward path of post states**: such a path, pasted with any
   forward path through the state, is a history that never meets `p`, contradicting `A'`.
4. Each state has finitely many predecessors (the fibre is finite), so by König the backward
   post-chains into any given post state have bounded length.
5. But the forward post-chains from the `p` states at times `a - n - 1` reach time `a` as
   backward post-chains of **every** length `n`, and the fibre at time `a` is finite — pigeonhole
   gives one post state at time `a` with backward post-chains of unbounded length, contradicting 4.

**The two obstructions are different.** The carrier failure (sections 1-4) is about the *size*
of the carrier: a finite graph can never host a countermodel to `θ.neg`, and `ℤ × Fin n` repairs
it. The width failure is about **limit closure plus finite fibres**: a countermodel to `Φ.neg`
can be countable and finitely branching — the positive half above is one — but it must have
infinitely many states at some single time. Limit closure (every step path is a history) is what
turns "bounded backward chains" into a contradiction via König; finite fibres are what make the
pigeonhole bite. The second obstruction is strictly stronger for certificate design, because
`ℤ × Fin n` satisfies the carrier rule and still fails it.

The strengthened rule:

A ℤ-TIME CERTIFICATE CLASS MUST PRESENT AN INFINITE, FINITELY PRESENTED CARRIER, AND, IF ITS
PER-TIME FIBRES ARE FINITE, IT IS STILL INCOMPLETE FOR ANY TARGET CARRYING `⊡`. A SUCCESSOR
CLASS MUST PRESENT INFINITE FIBRES — FOR INSTANCE THE ROOT PATHS OF A FINITE CLASS GRAPH — FOR
WHICH NO CHECKER PRECEDENT EXISTS IN THIS TREE.

Three consequences to keep straight:

- The `⊡`-free flagship is **unaffected**: `θ` and `θ'` are the `⊡`-free and fragment witnesses
  for the *carrier* failure, and
  `WitnessFamily.exists_plusSlicedCertificate_of_not_plusValidZTime_ofFormula` (section 5)
  stands — the sliced class is complete on embedded L formulas. `Φ` needs `⊡` under `□` in an
  essential way.
- Decidability of full L⁺ ℤ-time validity **does not follow by the sliced route**, and section 9
  says why that is not the same as "does not follow at all".
- `Probe710`'s declarations are probe-level, like `Probe706`'s; the same landing note as in
  section 2 applies.

## 7. ℤ-time semantics as a time-sliced graph semantics

An earlier certificate-design round
(`specs/703_lplus_compression_and_completeness/reports/02_semantics-first-compression-research.md`,
§1.1) recorded five facts about regular ℤ-frames. All five are **true**, all five are landed or
checked, and all five are **time-homogeneous** statements:

| Fact | Content | Lean name |
|---|---|---|
| S1 | Over ℤ the all-pairs history condition is the adjacent-pairs condition: histories are exactly the bi-infinite step paths, and a bi-serial relation on a finite nonempty carrier generates a regular ℤ-frame | `FormalSystem.Semantics.FrameOver.mem_HF_iff_adjacent`, `FormalSystem.Semantics.FrameOver.taskRel_eq_iter`, `FormalSystem.Semantics.FrameOver.ofStep` |
| S2 | Truth is shift invariant: `(σ, t)` and `(σ shifted by t, 0)` satisfy the same formulas | `FormalSystem.PlusLanguage.plusTruthAt_timeShift` |
| S3 | `⊡` is state determined, at any two times; `□χ` holds iff `⊡χ` holds at every state | `FormalSystem.PlusLanguage.stab_state_only`, `FormalSystem.PlusLanguage.box_stab_iff` |
| S4 | Fusion closure (`paste` splices two histories at a shared state) and limit closure (by S1, every step path is a history) | `FormalSystem.PlusLanguage.paste` |
| S5 | Type-preserving pasting: a label row can be cut and rejoined exactly where state **and** type agree | `truth_paste_of_type_eq` in `specs/703_lplus_compression_and_completeness/probes/TypePreservingPaste.lean` |

From these that round concluded (§1.3) that "the right joint object has period one and no time
origin. By S1 and S2 the model is a time-homogeneous graph."

**The diagnosis.** That conclusion is exactly what `θ` forbids. S1-S5 say that the *semantics*
is time-homogeneous; they say nothing about whether a *countermodel* to a given target can be.
A countermodel to `θ.neg` must have a time at which something happens once — `p` holds at some
time on the target history and at no earlier time on it — so its state space cannot be both
time-homogeneous and finite. A finite time-homogeneous graph is a finite carrier, and section 2
says no finite carrier will do. So the graph a ℤ-time countermodel is read as must be
**time-sliced**, not time-homogeneous: a carrier `ℤ × W` whose one-step relation
`R : ℤ → W → W → Prop` may depend on the time. That is what `FrameOver.ofSlicedStep` presents,
and section 6 says that even this is not enough once `W` is finite.

**Three obstructions, not one.** They are routinely conflated and must be kept apart:

| Obstruction | Witness | Machine-checked statement | Answered by |
|---|---|---|---|
| Carrier **size** — a finite graph hosts no countermodel | `θ`, `θ'` | `Probe706.no_ofStep_sat`, `Probe706.not_finite_carrier_fmp` | `ℤ × Fin n` via `FrameOver.ofSlicedStep` (section 5) |
| **All-threads fulfilment** — a finite, eventually periodic presentation makes every reachable cycle a thread, so a pending eventuality fulfilled by *leaving* a cycle is read as unfulfilled | `pumpTarget p` | `FormalSystem.Metalogic.Decidability.PlusSharingWitnessFamily.not_exists_plusCertifies_pumpTarget` | liveness as a *fixpoint over live positions* rather than a demand on every thread (`PlusSlicedCertificate.lean` header, first bullet) |
| Finite **width** — limit closure plus finite fibres contradicts König | `Φ` | `Probe710.not_finite_width_fmp`, `Probe710.not_sliced_complete` | **not answered by any landed class** |

The first two were both repaired by the sliced class; the third is open and is the reason
section 6's strengthened rule ends with "no checker precedent exists".

**A gap this note does not fill.** The second obstruction deserves its own note —
`limit-closure-and-fairness.md`, on why a finite, fulfilment-closed structure cannot present a
limit-closed branching model with a pending eventuality. It does not exist yet. Whoever writes it
should start from `FormalSystem/Metalogic/Decidability/PlusWitnessFamily/Limits/NoCertificate.lean`,
whose header carries the seven-step argument.

## 8. The published counterpart

The design rule of section 5 is in print. Gabbay, Kurucz, Wolter and Zakharyaschev,
*Many-Dimensional Modal Logics* (2003), printed p. 234 **[verified-pdf]**: "If L does not enjoy
the fmp, then we can try to show that it is characterized by (in general) infinite models having
a certain 'regular structure', say, constructed from repeating finite pieces." And p. 236: "we
may be bound to deal with infinite models. The question then is how to represent these infinite
models as 'regular structures of repeating finite pieces,' if this is at all possible."

The concrete form is the **quasimodel over `⟨ℤ, <⟩`** of Hodkinson, Wolter and Zakharyaschev,
"Decidable fragments of first-order temporal logics", APAL 106 (2000) **[literature]**. The next
designer should reach for this named object rather than invent one. The correspondence with the
landed sliced certificate, Definition by Definition:

| HWZ 2000 | Where | Sliced-certificate counterpart |
|---|---|---|
| type | Def. 5 | the label at a position |
| state candidate — a set of types agreeing on the state formulas; `♯(φ)` bounds the realizable ones | Def. 6 | a fibre (slice) |
| state function `f : W → state candidates` over the flow `W` | Def. 10 | the per-slice labelling |
| run — `r(w) ∈ f(w)` with the `U`/`S` clauses holding along `r` | Def. 11 | the target path |
| quasimodel `⟨f, R⟩`, every type on some run; Theorem 14: satisfiable in a model on the flow iff satisfied in a quasimodel over it | Def. 12 | the time-sliced certificate |
| splice — if `f(n) = f(m)`, `n < m`, then `f^{≤n} ∗ f^{>m}` is again a quasimodel | Lemma 17 | the pumping argument of section 3 |
| bounded realisation — repeated quasistates deleted until every `U`-formula is realised within a bounded distance | Lemma 21 | forward/backward-dead position pruning |
| ultimately periodic form `f₁ ∗ f₂^ω` with bounded `|f₁|`, `|f₂|` | Lemma 23, Theorem 24 | tail stability |

**Correspondence, not identity.** HWZ's object is first-order temporal and has no `□` and no
`⊡`; the quantifier that makes `Φ` bite (section 6) has no counterpart there. The table says
what to read, not that the problems coincide.

HWZ give three decidability routes off the same structure: (1) express "a quasimodel satisfying
`φ` exists" as a monadic second-order sentence over the flow and discharge it by Büchi/Rabin —
covers `⟨ℕ, <⟩`, `⟨ℤ, <⟩` and `⟨ℚ, <⟩`, non-elementary, and needs **no Safra construction**;
(2) the explicit elementary analysis over `⟨ℕ, <⟩` ("the case of `⟨ℤ, <⟩` is similar");
(3) a composition method for `⟨ℝ, <⟩`. `⟨ℤ, <⟩` — this repository's time domain — is in scope
throughout.

**The technique was in the corpus the whole time.** GKWZ Chapter 11 carries the method in book
form **[literature]**: §11.3 defines the state function, run and K-quasimodel and proves Lemma
11.22 (satisfiable iff a K-quasimodel exists) and Theorem 11.21 by translation into MSO; §11.4
opens with the periodic-state-function idea and its Lemmas 11.27 and 11.29 are HWZ's Lemmas 17
and 21 restated; §13.2's Theorem 13.6 gives the MSO route for PTL × S5. The book was ingested
into the global literature corpus on 2026-08-18 (registered in this repository's sub-index on
2026-08-26) for a representation sweep, and was never read for this purpose before the
certificate-design rounds that reinvented it. A corpus search for "quasimodel" returns more
hits in it than in HWZ itself. The failure was not an absent source; it was an unread one.

## 9. FMP failure is not undecidability

Krommes, "The Complexity of the Product Logics K4 × S5 and S4 × S5 and of the Logic SSL of
Subset Spaces" (2020) **[literature]**, Theorem 1.1: K4 × S5, S4 × S5 and SSL are
**EXPSPACE-complete**. The same paper lists, among its transfer results, that K4 × S5 and
S4 × S5 "both lack the finite product model property [GKWZ Theorem 5.32], but are decidable. In
fact, they are in coN2EXPTIME [GKWZ Theorem 5.28]."

Both theorem numbers were verified against the GKWZ source PDF **[verified-pdf]**:

- **Theorem 5.28**, printed p. 244: for `L ∈ {K_n, T_n, D_n, K4_n, S4_n, KD45_n, S5_n}`, the
  decision problem for `L × S5` is in coN2EXPTIME. It is a corollary of Theorem 5.27, which gives
  `L × S5` the 2-exponential **abstract** fmp. The book adds that no filtration argument is known
  to the authors for products in which neither component is S5.
- **Theorem 5.32**, printed p. 246: if `C` is a class of transitive frames at least one of which
  contains an ascending ω-type chain, and `L` is a Kripke complete unimodal logic with an
  infinite frame having a point that sees every other point, then `Log C × L` lacks the
  **product** fmp. The book's lead-in names K4 × S5 and S4 × S5 as its instances. The
  countermodel puts `p` true exactly on the diagonal of an ω-type chain against an infinite
  `L`-frame — structurally the same trick as `θ` (something true exactly once along an
  ω-chain, so that any finite quotient repeats and breaks it), and no more is claimed, because
  the proof formula is OCR-garbled in every available extraction and is deliberately **not**
  transcribed here; Figure 5.9's caption reads "φ is not satisfiable in any finite product frame,
  where the first component is transitive."

The distinction that matters is **product fmp versus abstract fmp**: K4 × S5 loses the former
(5.32), keeps the latter (5.27), and its decidability bound (5.28) comes from the latter. That
retreat is **unavailable here**: `FormalSystem.PlusLanguage.PlusValidZTime` quantifies over
regular ℤ-frames only, and the refuted property (sections 2 and 6) is the fmp relative to that
very class. What survives is GKWZ's other route — the finitely presented infinite carrier of
sections 5 and 8.

So both over-corrections are wrong. "The fmp is refuted, so a large enough `n` will do" is wrong
in kind (section 4). "The fmp is refuted, so decidability is hopeless" is wrong by published
example. **This note states no complexity bound for L or L⁺ over ℤ-time**: Krommes's result is
about K4 × S5, which this logic is not, and the two questions — fmp and decidability — are
independent.

## 10. Secondary literature

Halpern, van der Meyden and Vardi, "Complete Axiomatizations for Reasoning About Knowledge and
Time" (2004) **[literature]** is the nearest published family to an S5-like modality over a
discrete linear flow. Its own contribution is axiomatizability under four parameters (unique
initial state, synchrony, perfect recall, no learning), not all settings of which are recursively
axiomatizable. The complexity picture it is usually cited for is its §2 and Table 1, which
*summarise* Halpern and Vardi (1989): perfect recall and no learning are the knob that moves the
decision problem from PSPACE through non-elementary to co-r.e. and Π¹₁. Cite it as that summary,
not as the origin.

Hampson, Kikot, Kurucz and Marcelino, "Non-finitely axiomatisable modal product logics with
infinite canonical axiomatisations" (2019) **[literature]** shows that Diff × Diff is not finitely
axiomatisable but is axiomatisable by infinitely many Sahlqvist axioms — what an axiomatisation
of a product-like system can look like. It is cited by analogy only: **this logic is not a
product.** GKWZ's product quasimodels presuppose commutativity and Church-Rosser, which the
stability modal lacks (the earlier design round's Part 1 is titled "The semantics, which is not a
product logic").

## 11. Sources and fidelity

| Source | Corpus id | What was read | Label |
|---|---|---|---|
| `NoFiniteCarrierModel.lean`, `NoFiniteWidthModel.lean` | (probes, `specs/706_...`, `specs/710_...`) | whole files; `#print axioms` lines | **[checked]** |
| `fmp-hypothesis-is-false.lean` | (archived evidence, `specs/archive/476_...`) | header, `fmp_false` | **[archived]** |
| GKWZ 2003 | `gabbay_kurucz_wolter_zakharyaschev_2003_many_dimensional_modal_logics` | Thms 5.27, 5.28, 5.32 and pp. 234/236 in the source PDF; Ch. 11, §13.2 from the extract | **[verified-pdf]** for the theorems and quotes; otherwise **[literature]** (`unverified_conversion`) |
| HWZ 2000 | `hodkinson_wolter_zakharyaschev_2000_decidable_fragments_fotl` | Defs 5-12, Lemmas 17, 21, 23, Thms 14, 24, introduction | **[literature]** (`unverified_conversion`; angle brackets dropped in the extract) |
| Krommes 2020 | `krommes_2020_complexity_k4xs5_s4xs5_subset_spaces` | Thm 1.1, transfer-results list | **[literature]** (`unverified_conversion`) |
| HVV 2004 | `halpern_vandermeyden_vardi_2004_axiomatizations_knowledge_and_time` | abstract, §2, Table 1 | **[literature]** (`unverified_conversion`) |
| HKKM 2019 | `hampson_kikot_kurucz_marcelino_2019_non_finitely_axiomatisable_product_logics` | abstract | **[literature]** (`unverified_conversion`) |

To repeat the GKWZ verification: the global literature index's `metadata.json` for that entry
names the staging PDF under `~/Documents/literature-staging/gabbay_2003/`; run
`pdftotext -layout` on it and grep the output for the theorem numbers, reading the printed
running heads for page numbers.
