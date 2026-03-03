# Task Semantics for Bimodal Temporal Logic (TM)

## Overview

Logos implements **task-based semantics** for bimodal temporal logic TM, not standard Kripke semantics. This semantic framework uses temporal durations, world-histories, and task relations to model agency and temporal reasoning.

For a comparison with standard Kripke semantics, see [kripke-semantics-overview.md](kripke-semantics-overview.md).

**Key Distinction**: Unlike Kripke semantics which uses accessibility relations between worlds, task semantics uses:
- **Durations** as a totally ordered abelian group (not just discrete time points)
- **World-histories** as functions from time domains to world states
- **Task relations** connecting states via timed tasks (not simple accessibility)

This document describes the actual implementation in `Logos/Core/Semantics/`.

---

## Task Frames

### Mathematical Structure

A task frame `F = (W, T, ·)` consists of:
- **W**: Type of world states
- **T**: Totally ordered abelian group of temporal durations (`LinearOrderedAddCommGroup T`)
- **· (task_rel)**: Task relation `W × T × W → Prop`

**Paper Reference**: JPL paper "The Perpetuity Calculus of Agency" (app:TaskSemantics, def:frame, line 1835)

### LEAN 4 Definition

```lean
structure TaskFrame (T : Type*) [LinearOrderedAddCommGroup T] where
  WorldState : Type
  task_rel : WorldState → T → WorldState → Prop
  nullity : ∀ w, task_rel w 0 w
  compositionality : ∀ w u v x y, task_rel w x u → task_rel u y v → task_rel w (x + y) v
```

### Temporal Duration Group

The type `T` represents temporal durations with:
- **Additive group structure**: Zero duration (0), addition (+), inverse (-)
- **Total linear order**: Comparison (≤, <)
- **Order compatibility**: `x ≤ y → x + z ≤ y + z`

**Common Instantiations**:
- `Int`: Discrete integer time (standard temporal logic)
- `Rat`: Dense rational time (fine-grained temporal reasoning)
- `Real`: Continuous real time (physical systems)

### Task Relation

`task_rel w x u` means: **state `u` is reachable from `w` by executing a task of duration `x`**

**Constraints**:

1. **Nullity** (Identity): `task_rel w 0 w`
   - Zero-duration task is identity (reflexivity)
   - Every state is reachable from itself with no time passing

2. **Compositionality** (Transitivity): 
   ```lean
   task_rel w x u → task_rel u y v → task_rel w (x + y) v
   ```
   - Sequential tasks compose with additive time
   - If task of duration `x` takes `w` to `u`, and task of duration `y` takes `u` to `v`,
     then task of duration `x + y` takes `w` to `v`

### Example Task Frames

```lean
-- Trivial frame: all tasks always succeed
def trivial_frame {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T where
  WorldState := Unit
  task_rel := fun _ _ _ => True
  nullity := fun _ => trivial
  compositionality := fun _ _ _ _ _ _ _ => trivial

-- Identity frame: only zero-duration tasks succeed
def identity_frame (W : Type) {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T where
  WorldState := W
  task_rel := fun w x u => w = u ∧ x = 0
  nullity := fun w => ⟨rfl, rfl⟩
  compositionality := by
    intros w u v x y hwu huv
    obtain ⟨h1, h2⟩ := hwu
    obtain ⟨h3, h4⟩ := huv
    subst h1 h3
    simp [h2, h4]

-- Natural number frame: permissive task relation
def nat_frame {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T where
  WorldState := Nat
  task_rel := fun _ _ _ => True
  nullity := fun _ => trivial
  compositionality := fun _ _ _ _ _ _ _ => trivial
```

---

## World Histories

### Mathematical Structure

A world history `τ: X → W` is a function from a **convex time domain** `X ⊆ T` to world states `W`, satisfying:
- **Convexity**: Domain has no temporal gaps
- **Task respect**: History respects the task relation

**Paper Reference**: JPL paper (app:TaskSemantics, def:world-history, line 1849)

### LEAN 4 Definition

```lean
structure WorldHistory {T : Type*} [LinearOrderedAddCommGroup T] (F : TaskFrame T) where
  domain : T → Prop
  convex : ∀ (x z : T), domain x → domain z → ∀ (y : T), x ≤ y → y ≤ z → domain y
  states : (t : T) → domain t → F.WorldState
  respects_task : ∀ (s t : T) (hs : domain s) (ht : domain t),
    s ≤ t → F.task_rel (states s hs) (t - s) (states t ht)
```

### Convexity Constraint

**Definition**: A domain is convex if whenever `x, z ∈ domain` with `x ≤ z`, then all times `y` with `x ≤ y ≤ z` are also in the domain.

**Intuition**: Histories have no "gaps" in time. If a history exists at times `x` and `z`, it exists at all times between them.

**Example**:
- `domain = {t | 0 ≤ t ≤ 10}` is convex (closed interval)
- `domain = {t | t < 0 ∨ t > 5}` is NOT convex (gap from 0 to 5)

### Task Respect Constraint

For any times `s ≤ t` in the domain, the states at `s` and `t` must be related by the task relation with duration `t - s`:

```lean
F.task_rel (states s hs) (t - s) (states t ht)
```

**Intuition**: The history must be consistent with possible task executions. The state at time `t` must be reachable from the state at time `s` by a task of duration `t - s`.

### Example World Histories

```lean
-- Trivial history (full domain, constant state)
def trivial : WorldHistory (TaskFrame.trivial_frame (T := T)) where
  domain := fun _ => True
  convex := by intros x z hx hz y hxy hyz; exact True.intro
  states := fun _ _ => ()
  respects_task := by intros s t hs ht hst; exact True.intro

-- Universal history for reflexive frames
def universal (F : TaskFrame T) (w : F.WorldState)
    (h_refl : ∀ d : T, F.task_rel w d w) : WorldHistory F where
  domain := fun _ => True
  convex := by intros x z hx hz y hxy hyz; exact True.intro
  states := fun _ _ => w
  respects_task := by
    intros s t hs ht hst
    exact h_refl (t - s)
```

### Time-Shift Construction

**Key Semantic Operation**: Given history `σ` and shift offset `Δ = y - x`, construct shifted history `τ` where:
- `τ.domain z ↔ σ.domain (z + Δ)`
- `τ.states z = σ.states (z + Δ)`

```lean
def time_shift (σ : WorldHistory F) (Δ : T) : WorldHistory F where
  domain := fun z => σ.domain (z + Δ)
  convex := by
    intros x z hx hz y hxy hyz
    have hxy' : x + Δ ≤ y + Δ := add_le_add_right hxy Δ
    have hyz' : y + Δ ≤ z + Δ := add_le_add_right hyz Δ
    exact σ.convex (x + Δ) (z + Δ) hx hz (y + Δ) hxy' hyz'
  states := fun z hz => σ.states (z + Δ) hz
  respects_task := by
    intros s t hs ht hst
    have h_shifted : s + Δ ≤ t + Δ := add_le_add_right hst Δ
    have h_duration : (t + Δ) - (s + Δ) = t - s := by
      rw [add_sub_add_right_eq_sub]
    rw [← h_duration]
    exact σ.respects_task (s + Δ) (t + Δ) hs ht h_shifted
```

**Usage**: Time-shift is fundamental to proving MF and TF axioms (modal-future and temporal-future interaction).

---

## Truth Evaluation

### Semantic Configuration

Truth is evaluated at a **model-history-time triple** `(M, τ, t)`:
- **M**: Task model (frame + valuation)
- **τ**: World history
- **t**: Time point in `τ.domain`

### LEAN 4 Definition

```lean
def truth_at (M : TaskModel F) (τ : WorldHistory F) (t : T) (ht : τ.domain t) :
    Formula → Prop
  | Formula.atom p => M.valuation (τ.states t ht) p
  | Formula.bot => False
  | Formula.imp φ ψ => truth_at M τ t ht φ → truth_at M τ t ht ψ
  | Formula.box φ => ∀ (σ : WorldHistory F) (hs : σ.domain t), truth_at M σ t hs φ
  | Formula.all_past φ => ∀ (s : T) (hs : τ.domain s), s < t → truth_at M τ s hs φ
  | Formula.all_future φ => ∀ (s : T) (hs : τ.domain s), t < s → truth_at M τ s hs φ
```

### Critical Semantic Distinctions

**Box Operator (□φ)**: Quantifies over **ALL histories** at current time `t`
```lean
∀ (σ : WorldHistory F) (hs : σ.domain t), truth_at M σ t hs φ
```
- Modal necessity: φ must hold at all possible histories at this time
- Changes the history, keeps the time fixed

**Past Operator (Pφ)**: Quantifies over **earlier times** in **same history** `τ`
```lean
∀ (s : T) (hs : τ.domain s), s < t → truth_at M τ s hs φ
```
- Temporal necessity: φ must hold at all past times in this history
- Keeps the history, changes the time (backward)

**Future Operator (Fφ)**: Quantifies over **later times** in **same history** `τ`
```lean
∀ (s : T) (hs : τ.domain s), t < s → truth_at M τ s hs φ
```
- Temporal necessity: φ must hold at all future times in this history
- Keeps the history, changes the time (forward)

### Domain Restriction

**Critical**: Temporal operators only quantify over times **in the history's domain**.

- `Pφ` at `(M, τ, t)` checks φ at all `s < t` **where `s ∈ τ.domain`**
- `Fφ` at `(M, τ, t)` checks φ at all `s > t` **where `s ∈ τ.domain`**

This is essential for correct temporal semantics with partial histories.

### Paper Alignment

**JPL Paper** (app:TaskSemantics, def:BL-semantics, lines 1857-1866):
- `M,τ,x ⊨ p` iff `τ(x) ∈ V(p)` → `M.valuation (τ.states t ht) p`
- `M,τ,x ⊨ ⊥` is false → `False`
- `M,τ,x ⊨ φ → ψ` iff `M,τ,x ⊨ φ` implies `M,τ,x ⊨ ψ` → material conditional
- `M,τ,x ⊨ □φ` iff `M,σ,x ⊨ φ` for all σ ∈ Ω → quantify over all histories
- `M,τ,x ⊨ Past φ` iff `M,τ,y ⊨ φ` for all y < x → quantify over past times
- `M,τ,x ⊨ Future φ` iff `M,τ,y ⊨ φ` for all y > x → quantify over future times

**Implementation**: Exact match with paper specification.

---

## Task Models

### Definition

A task model adds a valuation function to a task frame:

```lean
structure TaskModel (F : TaskFrame T) where
  valuation : F.WorldState → String → Prop
```

**Valuation**: Maps (world state, proposition) pairs to truth values.

### Example Models

```lean
-- All-false model
def all_false {T : Type*} [LinearOrderedAddCommGroup T] (F : TaskFrame T) : TaskModel F where
  valuation := fun _ _ => False

-- All-true model
def all_true {T : Type*} [LinearOrderedAddCommGroup T] (F : TaskFrame T) : TaskModel F where
  valuation := fun _ _ => True

-- Model from list of true propositions
def from_list {T : Type*} [LinearOrderedAddCommGroup T] 
    (F : TaskFrame T) (w : F.WorldState) (props : List String) : TaskModel F where
  valuation := fun w' p => w = w' ∧ p ∈ props
```

---

## Validity

### Definition

A formula `φ` is **valid** if it is true at all model-history-time triples:

```lean
def is_valid (φ : Formula) : Prop :=
  ∀ (T : Type*) [LinearOrderedAddCommGroup T] 
    (F : TaskFrame T) (M : TaskModel F) 
    (τ : WorldHistory F) (t : T) (ht : τ.domain t),
    truth_at M τ t ht φ
```

**Notation**: `⊨ φ` (semantic entailment)

### Soundness

The TM proof system is **sound**: If `⊢ φ` (syntactically derivable), then `⊨ φ` (semantically valid).

```lean
theorem soundness : ∀ φ, Derivable [] φ → is_valid φ
```

**Status**: Proven in `Logos/Core/Metalogic/Soundness.lean`

---

## Key Theorems

### Time-Shift Preservation

Truth is preserved under time-shift transformations:

```lean
theorem time_shift_preserves_truth (M : TaskModel F) (σ : WorldHistory F) (x y : T)
    (hx : (time_shift σ (y - x)).domain x) (hy : σ.domain y) (φ : Formula) :
    truth_at M (time_shift σ (y - x)) x hx φ ↔ truth_at M σ y hy φ
```

**Intuition**: Truth at `(σ, y)` equals truth at `(shifted_σ, x)` where shift amount is `y - x`.

**Usage**: Fundamental to proving MF and TF axioms.

### Temporal Duality

Validity is preserved under swapping past and future operators:

```lean
theorem derivable_implies_swap_valid :
    ∀ {φ : Formula}, DerivationTree [] φ → is_valid φ.swap_past_future
```

**Intuition**: The temporal structure is symmetric under time reversal (via group inverse).

**Usage**: Enables the temporal duality inference rule.

---

## Comparison with Kripke Semantics

| Aspect | Kripke Semantics | Task Semantics |
|--------|------------------|----------------|
| **Worlds** | Discrete possible worlds | World states in histories |
| **Time** | Implicit or discrete points | Totally ordered abelian group |
| **Accessibility** | Binary relation `R ⊆ W × W` | Task relation `W × T × W` |
| **Histories** | Not present | Functions from time domains to states |
| **Modal Box** | `∀w'. R w w' → φ at w'` | `∀σ. σ.domain t → φ at (σ, t)` |
| **Temporal** | Not standard | `∀s < t. s ∈ τ.domain → φ at (τ, s)` |
| **Convexity** | Not applicable | Required for history domains |
| **Compositionality** | Transitivity of R | `task_rel w x u ∧ task_rel u y v → task_rel w (x+y) v` |

**Key Difference**: Task semantics explicitly models temporal duration and task execution, while Kripke semantics uses abstract accessibility relations.

---

## Business Rules

1. **Use task frames**: Define frames with `LinearOrderedAddCommGroup T` for temporal durations
2. **Enforce convexity**: History domains must have no temporal gaps
3. **Respect task relation**: Histories must satisfy `respects_task` constraint
4. **Distinguish operators**: Box quantifies over histories, Past/Future quantify over times
5. **Check domain membership**: Temporal operators only quantify over times in domain
6. **Use time-shift**: For proving temporal axioms (MF, TF)
7. **Verify soundness**: All derivable formulas must be valid in task semantics

---

## Common Pitfalls

1. **Confusing box and temporal operators**: Box changes history, Past/Future change time
2. **Ignoring domain restrictions**: Temporal quantification is restricted to `τ.domain`
3. **Forgetting convexity**: History domains must be convex (no gaps)
4. **Assuming discrete time**: `T` can be `Int`, `Rat`, `Real`, or any ordered group
5. **Mixing Kripke and task semantics**: These are different semantic frameworks
6. **Ignoring task respect**: Histories must satisfy `respects_task` constraint
7. **Forgetting nullity**: Zero-duration task must be identity

---

## Relationships

- **Implements**: JPL paper "The Perpetuity Calculus of Agency" task semantics
- **Used by**: Soundness proofs, validity checking, semantic reasoning
- **Related**: Proof system (syntax), metalogic (soundness/completeness)
- **Extends**: Modal logic semantics with temporal durations and task relations

---

## References

### Implementation Files
- `Logos/Core/Semantics/TaskFrame.lean` - Task frame structure
- `Logos/Core/Semantics/WorldHistory.lean` - World history structure
- `Logos/Core/Semantics/TaskModel.lean` - Task model structure
- `Logos/Core/Semantics/Truth.lean` - Truth evaluation
- `Logos/Core/Semantics/Validity.lean` - Validity definition

### Documentation
- `docs/user-guide/methodology.md` - TM logic specification
- JPL Paper "The Perpetuity Calculus of Agency" (app:TaskSemantics)

### Related Concepts
- Modal logic semantics (Kripke frames)
- Temporal logic (LTL, CTL)
- Possible worlds semantics
- Abelian group theory
