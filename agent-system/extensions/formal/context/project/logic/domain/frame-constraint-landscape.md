# The Frame-Constraint Landscape

How the four constraints on a task frame relate to one another, why one of them behaves
differently from the other three, and which machine-checked witnesses pin each claim down.
Every Lean name below is fully qualified and lives in the ProofChecker (BimodalLogic) tree.

## The primitives, and what may be said in them

A task frame is a triple `⟨W, D, ⇒⟩`: a state set `W`, a temporal/duration order `D`, and a
ternary task relation `w ⇒_x v` with `x : D`. A *frame constraint* may quantify over these three
things and nothing else. Conditions phrased in objects the theory builds from them — partial
histories, world histories, the extension order on histories, fibres and segments as a
*classification* of subsets of `W` — belong in lemmas and theorems as emergent properties. They
are not admissible as constraints on the primitive, because the primitive is what they are
defined from.

This criterion is not stylistic. It decides which of two candidate conditions may serve as a
frame constraint at all, and it is the reason the landscape below splits the way it does.

## Time-indexed versus ball-indexed quantifiers

The load-bearing distinction in this area, and the one that explains three otherwise unrelated
results:

- A **time-indexed** condition quantifies over a family of states indexed by *times* — a set
  `X ⊆ D` and a family `{w_t}_{t ∈ X}` coherent under the task relation. The family's members
  are therefore ordered by `D`, and the constraint each member imposes at a new time `z` is
  ordered the same way.
- A **ball-indexed** condition quantifies over a family of *subsets of `W`* — fibres
  `Fib(w, x) = {v : w ⇒_x v}` and segments — ordered only by inclusion. Nothing ties a member to
  a time.

**Time-indexed quantifiers collapse over an order with nearest times; ball-indexed ones never
do.** If `D` has a nearest member of `X` on each side of `z` (true of `ℤ`, false of `ℚ` and `ℝ`),
then the constraint imposed by that nearest time is the `⊆`-least one, and the infinite
intersection reduces to a single membership — no completeness of `W` is needed. A `⊇`-directed
family of *balls* has no such reduction available: its members are not indexed by anything that
`D`'s discreteness could bound, so the family can shrink onto a cut of `W` however discrete the
durations are.

Everything below is a consequence of that one asymmetry.

## The four constraints

Stated as bare-relation predicates in `FormalSystem/Semantics/TaskFrame.lean`, over
`R : W → D → W → Prop`:

| Constraint | Predicate | Shape |
|---|---|---|
| *Seriality* | `FormalSystem.Semantics.TaskFrame.Serial` | pointwise |
| *Compositionality* | `FormalSystem.Semantics.TaskFrame.Compositional` | pointwise (biconditional) |
| *Limit* | `FormalSystem.Semantics.TaskFrame.Limit` | pointwise |
| *Saturation* | `FormalSystem.Semantics.TaskFrame.Saturation` | **ball-indexed** |

and, as the proposed replacement for the fourth:

| Candidate | Predicate | Shape |
|---|---|---|
| *Completion* | `FormalSystem.Semantics.TaskFrame.Completion` | **time-indexed** |

*Saturation* is the only one of the four that is not stated in the primitives alone: it needs the
fibre and segment classification (`TaskFrame.IsFiber`, `TaskFrame.IsSegment`) to pick out eligible
members, and its directedness side condition is stated in subset inclusion with no reference to
the task relation at all. *Completion* needs neither: an index set inside `D`, a family of states
coherent under `⇒`, and a target time. It is therefore the candidate that meets the
primitives criterion, and the pointwise three plus *Completion* is a constraint list in which
every clause mentions only `W`, `D` and `⇒`.

## The independence matrix

Each of the four constraints has a compiled witness satisfying the other three and failing it.
All four witnesses are bare-relation certificates — the level the constraints are stated at —
rather than `FrameOver`-wrapped frames, for the two `ℚ`-carrier rows.

| Fails | Witness | Satisfies | Refutes |
|---|---|---|---|
| *Seriality* | void frame (empty relation on `Bool` over `ℤ`) | `StateTopology.voidFrame_compositional`, `StateTopology.voidFrame_limit`, `StateTopology.voidFrame_saturation` | `StateTopology.voidFrame_not_serial` |
| *Compositionality* | bump frame (identity, then total at `±1`, then identity) | `StateTopology.bumpFrame_serial`, `StateTopology.bumpFrame_limit`, `StateTopology.bumpFrame_saturation` | `StateTopology.bumpFrame_not_compositional` |
| *Limit* | four-state funnel | `StateTopology.funnel_serial`, `StateTopology.funnel_compositional`, `StateTopology.funnel_saturation` | `StateTopology.funnel_not_limit` |
| *Saturation* | rational two-origin relation | `StateTopology.RationalTwoOrigins.rel_serial`, `.rel_compositional`, `.rel_limit` | `StateTopology.RationalTwoOrigins.not_rel_saturation` |

All names are under `FormalSystem.Semantics.`. The first three rows live in
`FormalSystem/Semantics/StateTopology/ConstraintWitnesses.lean` and
`FormalSystem/Semantics/StateTopology/Counterexamples.lean`.

## Separation 1: *Completion* is strictly weaker than *Saturation*

*Saturation* implies *Completion*, and only through one site: the Step Lemma
(`FormalSystem.Semantics.PartialHistory.step`) is the sole place in the development where
*Saturation* is eliminated into a conclusion not mentioning it, and
`FormalSystem.Semantics.PartialHistory.completion_of_isRegular` is the resulting implication.

The converse is **false**, unconditionally. The witness is unit-speed drift on a rationally
incomplete carrier over discrete time — `W = ℚ`, `D = ℤ`, `w ⇒_x v` iff `|v − w| ≤ |x|`:

- `FormalSystem.Semantics.StateTopology.SeparatingFrame.srel_serial`
- `FormalSystem.Semantics.StateTopology.SeparatingFrame.srel_compositional`
- `FormalSystem.Semantics.StateTopology.SeparatingFrame.srel_limit`
- `FormalSystem.Semantics.StateTopology.SeparatingFrame.srel_completion`
- `FormalSystem.Semantics.StateTopology.SeparatingFrame.not_srel_saturation`

*Completion* holds because `ℤ` has nearest times — the time-indexed collapse. *Saturation* fails
because the `⊇`-directed family of rational intervals straddling the cut
`{q : q² < 2} | {q : 2 < q²}` shrinks onto a point `ℚ` does not have, and nothing about `ℤ`'s
discreteness reaches that family, because its members are balls and not times. The separation is
the time-indexed/ball-indexed asymmetry exhibited at a single relation.

Two consequences worth keeping:

- The separating frame must refute mixed-sign composition, because the converse *does* hold
  under mixed-sign composition plus *Limit*. It does:
  `FormalSystem.Semantics.StateTopology.SeparatingFrame.not_srel_totalComp` is the consistency
  check, not a stray result.
- The separation is realised over `ℤ`-time, exactly where
  `FormalSystem.Semantics.PartialHistory.extension_of_isZTime` already shows *Saturation* is
  redundant for the extension theorem. So *Saturation* excludes ordinary discrete-time frames
  with a dense state space, and the extension theorem has no need of that exclusion.

## Separation 2: dense time cannot separate them

The obvious probe — reuse the rational two-origin relation, which already fails *Saturation* —
does not work, and the reason generalises. That relation fails *Completion* too
(`FormalSystem.Semantics.StateTopology.RationalTwoOrigins.not_rel_completion`): a coherent family
at times accumulating at `z` from below, carrying positions that converge to `√2`, has empty
fibre intersection at `z`.

The argument is not specific to that relation. Over a **dense** temporal order, a coherent family
whose times accumulate at `z` forces the witness position to the single real number `lim φ(t)`,
because position nondecreasing and position-minus-time nonincreasing pinch the admissible
interval shut. So **no dense-time frame with a continuous-drift relation separates *Completion*
from *Saturation***, and the separation is a discreteness phenomenon. Searching for a dense-time
separator is wasted effort.

## The infinitary quantifier in *Completion* is essential

*Completion*'s quantification over an arbitrary index set cannot be traded for a finite or
two-point version:

- The **finitary** form is a consequence of *Compositionality* and *Seriality* alone:
  `FormalSystem.Semantics.PartialHistory.completion_of_finite_domain`, via the pointwise
  nearest-times predicate `FormalSystem.Semantics.PartialHistory.NearestAt` and
  `FormalSystem.Semantics.PartialHistory.completion_of_nearest_at`.
- The rational two-origin relation satisfies *Compositionality*
  (`StateTopology.RationalTwoOrigins.rel_compositional`) and fails *Completion*.

Hence no condition implied by *Compositionality* can be equivalent to *Completion* — in
particular no finitary or two-point form can be. (The two-point case for `s ≤ z ≤ t` is
`FormalSystem.Semantics.TaskFrame.Interpolates`, which is one half of *Compositionality*.) The
infinitary quantifier carries all of the completeness content.

## Where the two forms of *Completion* sit

`FormalSystem.Semantics.TaskFrame.Completion` is the bare-relation predicate of record.
`FormalSystem.Semantics.PartialHistory.CoherentCompletion` is definitionally that predicate at a
frame's task relation (`PartialHistory.coherentCompletion_iff_rel`), and
`FormalSystem.Semantics.PartialHistory.Completion` is the `PartialHistory`-shaped spelling,
bridged by `PartialHistory.completion_iff_coherentCompletion`. Both bridges carry **zero** frame
constraints, so the history-shaped form is a recognition lemma, never a definitional dependency:
the condition can be stated before histories exist.

## The strength table, and what is settled versus open

Four relations, and only four. Any prose about this area is checked against this table before it
is written; nothing here licenses a claim outside it.

| Relation | Status | Evidence |
|---|---|---|
| *Saturation* → *Completion* | **settled true** | `FormalSystem.Semantics.PartialHistory.completion_of_isRegular` |
| *Completion* → *Saturation* | **settled false** | `StateTopology.SeparatingFrame.srel_completion` + `not_srel_saturation` |
| `S₁ᵈ` → `S₁` | **settled true** | `FormalSystem.Semantics.TaskFrame.nestSaturation_of_saturation` |
| `S₁` → `S₁ᵈ` | **OPEN** | no witness exists; both existing `¬ Saturation` witnesses fail `S₁` too |

`S₁` is the standard nest condition (spherical completeness) of the Ćmiel–Kuhlmann–Kuhlmann
ball-space hierarchy; `S₁ᵈ` is its `⊇`-directed strengthening, which is what `def:frame`'s
*Saturation* clause states. The general order theory lives in
`FormalSystem/ForMathlib/Order/BallSpace.lean` (`Order.IsNest`, `Order.SphericallyComplete`,
`Order.HasCofinalNest`, `Order.sInter_nonempty_of_sphericallyComplete`) and is instantiated at the
frame's own ball space by `TaskFrame.NestSaturation`, with
`nestSaturation_iff_sphericallyComplete` recording the identification by `Iff.rfl`.

**Do not restore "strictly stronger" in the ball-space footnote's rendering.** The in-source
instruction at `FormalSystem/Semantics/TaskFrame.lean`'s *Saturation* region is the authority and
is copied forward verbatim, never paraphrased. The `S₁`-sufficiency result below weakens the case
for strictness rather than supporting it: `S₁ᵈ` is **stronger**, and whether it is *strictly*
stronger is the open row.

**The directedness is not forced.** Over any history with countably many times — automatic for
`ℤ`-time and for `ℚ`-time, since every subset of `ℤ` or `ℚ` is countable — `S₁` buys exactly what
`S₁ᵈ` buys at `lem:step`
(`FormalSystem.Semantics.PartialHistory.sInter_constraints_nonempty_of_countable`). *Saturation*
is kept in the `⇒`-directed form on the **naturalness** criterion, not because a theorem extracts
it. A genuine failure of `HasCofinalNest` would need mismatched one-sided cofinal characters, so
a non-archimedean `D` of uncountable coinitiality; nothing in the development instantiates one.

**Never state a frame-level `S₁ → Saturation`.** It is not available: a `⊇`-directed family of
balls need not reduce to a nest, since a maximal chain in a directed poset need not be cofinal.
The sufficiency result is a property of the constraint family `Constraints τ z` at one history
and one target, and must be stated that way.

## The carrier-hypothesis pattern

When a result needs a property of the temporal order, **state that property directly, about the
object that has it**, in the idiom of `PartialHistory.NearestAt` / `HasNearest`. Do not route it
through a Mathlib structure class.

Concretely: `hasCofinalNest_of_countable` takes
`hcount : {t : F.Duration | τ.domain t}.Countable` — a property of *the history's own domain* —
and no hypothesis on `D` at all. The tempting alternative, `Archimedean D`, is unavailable:
discharging it for a general duration order needs a Hölder embedding, and **Mathlib has no
Hölder embedding**. A condition on `D` smuggled into the frame would also be the wrong shape, for
the same reason a condition about histories may not be a frame constraint.

The same pattern already governs `NearestAt`: the argument consumes its nearest-times hypothesis
at exactly one set and one target, so the hypothesis is stated pointwise, and the finitary
corollary then falls out for free over *any* linear order.

## The siting rule: `ForMathlib/` versus the consuming tree

When a project fills a genuine Mathlib gap with mathematics that **mentions no project notion**,
the material belongs in `FormalSystem/ForMathlib/`, not in the consuming tree. The split line is
mechanical, not a judgement call:

```
grep -rn '^import FormalSystem' FormalSystem/ForMathlib/
```

must stay empty. Everything under that directory imports Mathlib only.

`BallSpace.lean` is the worked example: nests, `S₁` and the cofinal-nest reduction are stated over
an arbitrary ball predicate `P : Set W → Prop`, with no relation, frame or duration type in sight,
so they upstream as they stand. The *instantiation* at a task relation's ball space necessarily
mentions `TaskFrame.IsFiber` and `TaskFrame.IsSegment`, so it lives in
`FormalSystem/Semantics/TaskFrame.lean` instead — and likewise `PartialHistory.HasCofinalNest`,
which is a property of one constraint family, stays in the semantics tree.

A new module under `ForMathlib/` carries **four registration obligations, all landing in the same
phase as the module itself**, never deferred: invariant C8 (the aggregator import), C24 (the
recorded `FormalSystem.Init` exception, listed in `scripts/CheckInitImportsMain.lean` and
documented in `FormalSystem/Init.lean`), C33, and the generated inventory blocks in the directory
READMEs. A module that lands without them is a broken build or a silent lint failure, not a
follow-up.
