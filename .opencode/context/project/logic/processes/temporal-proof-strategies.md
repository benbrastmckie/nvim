# Temporal Proof Strategies (Linear Temporal Logic)

## Overview

This document describes seven core proof strategies for linear temporal logic in the Logos/Theory LEAN 4 codebase. These strategies demonstrate how to construct proofs involving temporal operators (G, H, F, P, △, ▽) using axioms, temporal duality, and composition patterns.

## When to Use

- When proving theorems involving temporal operators (G, H, F, P, △, ▽)
- When working with temporal axioms (T4, TA, TL)
- When exploiting temporal duality to derive past theorems from future theorems
- When reasoning about linear time structure

## Prerequisites

- Understanding of linear temporal logic semantics (total ordering on times)
- Familiarity with temporal axioms:
  - **T4** (future transitivity): `Gφ → GGφ`
  - **TA** (connectedness): `φ → G(Pφ)`
  - **TL** (perpetuity introspection): `△φ → G(Hφ)`
- Knowledge of temporal duality: `swap_temporal` function and involution property
- Understanding of helper lemmas: `imp_trans`, `identity`
- Basic LEAN 4 proof tactics

## Context Dependencies

- `lean4/domain/lean4-syntax.md` - LEAN 4 syntax reference
- `lean4/standards/proof-conventions.md` - Proof style conventions
- `logic/processes/modal-proof-strategies.md` - Modal proof patterns
- `logic/processes/proof-construction.md` - General proof workflow

---

## Strategy 1: Future Iteration (T4 Axiom)

### Pattern

Build arbitrarily long future chains using the T4 axiom (`Gφ → GGφ`), analogous to M4 for modal necessity. This demonstrates temporal transitivity.

### Core Technique

Use `imp_trans` from Perpetuity.lean to chain T4 applications.

### Example: Two-Step Future Chain (`Gφ → GGGφ`)

```lean
example (φ : Formula) : ⊢ φ.all_future.imp φ.all_future.all_future.all_future := by
  -- Step 1: First T4 application (Gφ → GGφ)
  have h1 : ⊢ φ.all_future.imp φ.all_future.all_future :=
    Derivable.axiom [] _ (Axiom.temp_4 φ)
  
  -- Step 2: Second T4 application (GGφ → GGGφ)
  have h2 : ⊢ φ.all_future.all_future.imp φ.all_future.all_future.all_future :=
    Derivable.axiom [] _ (Axiom.temp_4 φ.all_future)
  
  -- Step 3: Compose using transitivity (Gφ → GGφ → GGGφ)
  exact imp_trans h1 h2
```

### Semantic Intuition

If φ holds at all future times from t, then at any future time s > t, φ holds at all times after s (because all those times are also after t). This reflects the transitive structure of the temporal ordering.

### When to Use

- Proving theorems with nested future operators
- Building `GG...Gφ` from `Gφ`
- Demonstrating unbounded future property

### Related Strategies

- **Temporal Duality** (Strategy 2) - For deriving past iteration from future iteration
- **Frame Properties** (Strategy 6) - For demonstrating linear time structure

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 82-92

---

## Strategy 2: Temporal Duality (Past/Future Symmetry)

### Pattern

Convert past theorems to future theorems and vice versa using the temporal duality rule. This is one of the most powerful techniques in temporal logic.

### Core Technique

Use `Derivable.temporal_duality` to swap `all_future` ↔ `all_past` throughout a formula.

### Temporal Duality Rule

If `⊢ φ` then `⊢ swap_temporal φ`

### Involution Property

`swap_temporal (swap_temporal φ) = φ`

This means swapping twice gives back the original formula.

### Example: Past Iteration via Duality (`Hφ → HHφ`)

```lean
example (φ : Formula) : ⊢ φ.all_past.imp φ.all_past.all_past := by
  -- Step 1: Apply swap_temporal twice to φ (involution property)
  have φ_eq : φ = φ.swap_temporal.swap_temporal :=
    (Formula.swap_temporal_involution φ).symm
  
  -- Step 2: Get T4 axiom for swap_temporal φ
  have h1 : ⊢ φ.swap_temporal.all_future.imp φ.swap_temporal.all_future.all_future :=
    Derivable.axiom [] _ (Axiom.temp_4 φ.swap_temporal)
  
  -- Step 3: Apply temporal duality to swap G ↔ H
  have h2 : ⊢ (φ.swap_temporal.all_future.imp φ.swap_temporal.all_future.all_future).swap_temporal :=
    Derivable.temporal_duality _ h1
  
  -- Step 4: Simplify using swap_temporal definition
  simp [Formula.swap_temporal] at h2
  rw [φ_eq] at h2
  simp [Formula.swap_temporal_involution] at h2
  exact h2
```

### Semantic Intuition

The task semantics has a symmetric structure where swapping past and future preserves validity. This is formalized by the `swap_temporal` function on formulas.

### When to Use

- Deriving past theorems from future theorems (or vice versa)
- Exploiting symmetry in temporal reasoning
- Avoiding duplicate proofs for past and future

### Key Insight

**Temporal duality is a meta-level theorem transformation technique**: For any future theorem `⊢ Gφ → ψ`, we automatically get the corresponding past theorem by applying duality. This cuts proof effort in half!

### Related Strategies

- **Future Iteration** (Strategy 1) - Provides theorems to transform via duality
- **Combined Past-Future Reasoning** (Strategy 7) - For mixing both directions

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 153-173

---

## Strategy 3: Eventually/Sometimes Proofs (Negation Duality)

### Pattern

Work with "eventually" operator `Fφ` (some_future) defined as `¬G¬φ` and "sometimes past" operator `Pφ` (some_past) defined as `¬H¬φ`.

### Core Technique

Use definitional equality to convert between forms.

### Key Definitions

```lean
def some_future (φ : Formula) : Formula := neg (Formula.all_future (neg φ))
-- Fφ = ¬G¬φ (φ will eventually be true)

def some_past (φ : Formula) : Formula := neg (Formula.all_past (neg φ))
-- Pφ = ¬H¬φ (φ was sometimes true)

def always (φ : Formula) : Formula := 
  (Formula.all_past φ).and (φ.and (Formula.all_future φ))
-- △φ = Hφ ∧ φ ∧ Gφ (φ holds at all times: past, present, future)

def sometimes (φ : Formula) : Formula := neg (always (neg φ))
-- ▽φ = ¬△¬φ (φ holds at some time: past, present, or future)
```

### Example: Definitional Equality

```lean
example (φ : Formula) : φ.some_future = φ.neg.all_future.neg := rfl
example (φ : Formula) : φ.some_past = φ.neg.all_past.neg := rfl
example (φ : Formula) : φ.always = φ.all_past.and (φ.and φ.all_future) := rfl
example (φ : Formula) : φ.sometimes = φ.neg.always.neg := rfl
```

### Semantic Intuition

"φ will eventually be true" means "it's not the case that φ will always be false", which is `¬G¬φ`. This captures the duality between universal (G, H, △) and existential (F, P, ▽) temporal quantifiers.

### When to Use

- Working with existential temporal quantifiers
- Converting between universal and existential forms
- Reasoning about temporal possibility

### Related Strategies

- **Temporal Duality** (Strategy 2) - For converting F ↔ P
- **Connectedness** (Strategy 4) - For reasoning about temporal reachability

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 260-290

---

## Strategy 4: Connectedness (Temporal A Axiom)

### Pattern

Use the TA axiom (`φ → G(Pφ)`) to express temporal connectedness: if φ is true now, then at all future times, there exists a past time where φ was true (namely, now).

### Core Technique

Apply TA directly and chain with temporal operators.

### Example: Temporal A Direct Application

```lean
example (φ : Formula) : ⊢ φ.imp φ.some_past.all_future := by
  exact Derivable.axiom [] _ (Axiom.temp_a φ)
```

### Example: Connectedness with T4 (`φ → GGG(Pφ)`)

```lean
example (φ : Formula) : ⊢ φ.imp φ.some_past.all_future.all_future.all_future := by
  -- Step 1: Get TA (φ → G(Pφ))
  have ta : ⊢ φ.imp φ.some_past.all_future :=
    Derivable.axiom [] _ (Axiom.temp_a φ)
  
  -- Step 2: Get T4 for Pφ (G(Pφ) → GGG(Pφ))
  have t4_chain : ⊢ φ.some_past.all_future.imp φ.some_past.all_future.all_future.all_future :=
    imp_trans
      (Derivable.axiom [] _ (Axiom.temp_4 φ.some_past))
      (Derivable.axiom [] _ (Axiom.temp_4 φ.some_past.all_future))
  
  -- Step 3: Chain TA with T4 (φ → G(Pφ) → GGG(Pφ))
  exact imp_trans ta t4_chain
```

### Semantic Intuition

The present is always in the past of all future times. This expresses the connectedness property of linear time: for any times t < s, we have t in the past of s.

### Semantic Reading

If φ at time t, then for all times s > t, there exists a time r < s where φ (namely r = t).

### When to Use

- Reasoning about temporal reachability
- Connecting present to future via past
- Demonstrating linear time structure

### Related Strategies

- **Future Iteration** (Strategy 1) - For chaining with T4
- **Frame Properties** (Strategy 6) - For linear time properties

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 313-367

---

## Strategy 5: Temporal L Axiom (Always-Future-Past Pattern)

### Pattern

Use the TL axiom (`△φ → G(Hφ)`) to express: if φ holds at all times, then at all future times, φ holds at all past times.

### Core Technique

Use TL for reasoning about perpetual truths.

### Example: Temporal L Direct Application

```lean
example (φ : Formula) : ⊢ φ.always.imp φ.all_past.all_future := by
  exact Derivable.axiom [] _ (Axiom.temp_l φ)
```

### Semantic Intuition

If φ is eternal (always true), then from any future time, looking back to all past times, φ holds (because φ holds everywhere).

### Semantic Reading

If always φ, then for all s, for all t < s, we have φ at t.

### When to Use

- Reasoning about perpetual truths (△φ)
- Connecting always operator with future-past combinations
- Demonstrating eternal properties

### Related Strategies

- **Eventually/Sometimes Proofs** (Strategy 3) - For working with △ and ▽
- **Combined Past-Future Reasoning** (Strategy 7) - For mixing temporal operators

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 390-411

---

## Strategy 6: Temporal Frame Properties

### Pattern

Demonstrate frame properties of linear temporal logic:
- **Linear time**: Total ordering on times
- **Unbounded future**: No maximum time
- **Connectedness**: Present accessible from all future times

### Core Technique

Use T4 and TA to demonstrate frame constraints.

### Example: Unbounded Future Property (`Gφ → GGφ`)

```lean
example (φ : Formula) : ⊢ φ.all_future.imp φ.all_future.all_future := by
  exact Derivable.axiom [] _ (Axiom.temp_4 φ)
```

### Example: Linear Time Property (Present in Past of Future)

```lean
example (φ : Formula) : ⊢ φ.imp φ.some_past.all_future := by
  exact Derivable.axiom [] _ (Axiom.temp_a φ)
```

### Semantic Properties

1. **Unbounded Future**: For any time t, there exists a time s > t (T4 validity)
2. **Unbounded Past**: For any time t, there exists a time s < t (dual of T4)
3. **Linear Ordering**: For any times t, s, either t < s, t = s, or s < t
4. **Connectedness**: For any times t < s, we have t in the past of s (TA validity)

### When to Use

- Demonstrating linear time structure
- Proving frame-dependent properties
- Exploiting temporal ordering

### Related Strategies

- **Future Iteration** (Strategy 1) - Demonstrates unbounded future
- **Connectedness** (Strategy 4) - Demonstrates linear ordering

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 449-462

---

## Strategy 7: Combined Past-Future Reasoning

### Pattern

Combine past and future operators in a single proof, using both T4 and temporal duality.

### Core Technique

Apply duality to convert between past and future, then use axioms and chain results.

### Example: Symmetric Temporal Iteration

```lean
example (φ : Formula) : (⊢ φ.all_future.imp φ.all_future.all_future) ∧
                         (⊢ φ.all_past.imp φ.all_past.all_past) := by
  constructor
  · -- Future direction: Direct T4 application
    exact Derivable.axiom [] _ (Axiom.temp_4 φ)
  · -- Past direction: T4 + temporal duality
    have φ_eq : φ = φ.swap_temporal.swap_temporal :=
      (Formula.swap_temporal_involution φ).symm
    have h : ⊢ φ.swap_temporal.all_future.imp φ.swap_temporal.all_future.all_future :=
      Derivable.axiom [] _ (Axiom.temp_4 φ.swap_temporal)
    have h2 : ⊢ (φ.swap_temporal.all_future.imp φ.swap_temporal.all_future.all_future).swap_temporal :=
      Derivable.temporal_duality _ h
    simp [Formula.swap_temporal] at h2
    rw [φ_eq] at h2
    simp [Formula.swap_temporal_involution] at h2
    exact h2
```

### Semantic Intuition

The symmetric structure of linear time means that past and future reasoning are dual. Any theorem about the future has a corresponding theorem about the past.

### When to Use

- Proving theorems involving both past and future operators
- Exploiting temporal symmetry
- Building complex temporal derivations

### Related Strategies

- **Temporal Duality** (Strategy 2) - Core technique for symmetry
- **Future Iteration** (Strategy 1) - Provides future theorems to transform

### Source Reference

`Archive/TemporalProofStrategies.lean` lines 506-525

---

## Summary Table

| Strategy | Core Axiom | Helper Technique | Primary Use Case |
|----------|-----------|------------------|------------------|
| Future Iteration | T4 | `imp_trans` | Nested future operators |
| Temporal Duality | Duality rule | `swap_temporal` | Past from future theorems |
| Eventually/Sometimes | Definitions | Definitional equality | Existential temporal quantifiers |
| Connectedness | TA | Axiom chaining | Temporal reachability |
| Temporal L | TL | Perpetuity reasoning | Eternal truths |
| Frame Properties | T4, TA | Direct application | Linear time structure |
| Combined Reasoning | All axioms | Duality + chaining | Mixed past-future proofs |

---

## Key Takeaways

1. **Temporal Duality is Powerful**: The ability to transform future theorems into past theorems (and vice versa) cuts proof effort in half. Always look for opportunities to use duality.

2. **Involution Property**: `swap_temporal (swap_temporal φ) = φ` is essential for simplifying duality proofs. Use it to cancel nested swaps.

3. **Linear Time Structure**: T4 and TA axioms encode the linear time structure (unbounded future, connectedness). Understanding these frame properties helps guide proof construction.

4. **Composition Patterns**: Like modal proofs, temporal proofs are built by composing axiom applications using `imp_trans` and other helper lemmas.

5. **Universal vs Existential**: Understanding the duality between universal (G, H, △) and existential (F, P, ▽) temporal quantifiers is crucial for many proofs.

---

## Temporal Duality Workflow

**Standard Pattern for Deriving Past Theorems**:

1. **Identify future theorem**: `⊢ Gφ → ψ`
2. **Apply to swapped formula**: `⊢ G(swap_temporal φ) → swap_temporal ψ`
3. **Apply temporal duality**: `⊢ swap_temporal(G(swap_temporal φ) → swap_temporal ψ)`
4. **Simplify**: `⊢ H(swap_temporal (swap_temporal φ)) → swap_temporal (swap_temporal ψ)`
5. **Use involution**: `⊢ Hφ → ψ`

This workflow appears in 5+ examples throughout the codebase and is the standard technique for exploiting temporal symmetry.

---

## Success Criteria

You've successfully applied these strategies when:
- [ ] You can build future chains of arbitrary length using T4
- [ ] You can derive past theorems from future theorems using temporal duality
- [ ] You can work with existential temporal quantifiers (F, P, ▽)
- [ ] You can apply TA axiom for temporal connectedness
- [ ] You can use TL axiom for perpetuity reasoning
- [ ] You can demonstrate linear time frame properties
- [ ] You can combine past and future operators in a single proof

---

## Related Documentation

- **Modal Proof Strategies**: `logic/processes/modal-proof-strategies.md`
- **Proof Construction Workflow**: `logic/processes/proof-construction.md`
- **Helper Lemmas Reference**: `Logos/Core/Theorems/Perpetuity/Helpers.lean`
- **Temporal Axioms**: `Logos/Core/ProofSystem/Axioms.lean`
- **Archive Examples**: `Archive/TemporalProofStrategies.lean`
