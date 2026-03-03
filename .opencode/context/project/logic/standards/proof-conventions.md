# Modal Logic Proof Conventions

## Overview

Canonical proof style conventions for modal and temporal logic. Lean-specific overlays (syntax/tooling/readability) live in `project/lean4/standards/proof-conventions-lean.md`; keep proof principles and notation canonical here.

## When to Use

- When writing new proofs involving modal or temporal operators
- When refactoring existing proofs for clarity
- When reviewing proof contributions
- When teaching modal logic proof techniques

## Prerequisites

- Understanding of S5 modal logic (MT, M4, MB axioms)
- Understanding of temporal logic (T4, TA, TL axioms)
- Familiarity with LEAN 4 proof tactics
- Knowledge of the TM proof system (axioms and inference rules)

## Context Dependencies

- `logic/standards/notation-standards.md` - Notation conventions
- `logic/processes/modal-proof-strategies.md` - Proof strategies
- `logic/processes/proof-construction.md` - General proof workflow
- `lean4/patterns/tactic-patterns.md` - Tactic usage patterns

---

## Proof Structure

### Basic Proof Template

```lean
/--
[Theorem description with semantic interpretation]

[Proof strategy or key insight]
-/
theorem theorem_name (φ ψ : Formula) : ⊢ (φ.box.imp ψ.box) := by
  -- Step 1: [Description of first step]
  have h1 : ⊢ ... := by
    [tactic proof]
  
  -- Step 2: [Description of second step]
  have h2 : ⊢ ... := by
    [tactic proof]
  
  -- Step 3: [Combine steps to reach conclusion]
  exact [final expression using h1, h2, ...]
```

### Proof Style Guidelines

**1. Use Descriptive Step Comments**

```lean
-- Good: Descriptive comments
theorem modal_k_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by
  -- Step 1: Apply modal K axiom
  have h1 : ⊢ □(φ → ψ) → (□φ → □ψ) := 
    Derivable.axiom [] _ (Axiom.modal_k_dist φ ψ)
  exact h1

-- Avoid: No comments or cryptic comments
theorem modal_k_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by
  -- h1
  have h1 : ⊢ □(φ → ψ) → (□φ → □ψ) := 
    Derivable.axiom [] _ (Axiom.modal_k_dist φ ψ)
  exact h1
```

**2. Use Intermediate `have` Statements**

```lean
-- Good: Intermediate steps with names
theorem example (φ : Formula) : ⊢ (□φ → □□□φ) := by
  -- First M4 application: □φ → □□φ
  have h1 : ⊢ φ.box.imp φ.box.box :=
    Derivable.axiom [] _ (Axiom.modal_4 φ)
  
  -- Second M4 application: □□φ → □□□φ
  have h2 : ⊢ φ.box.box.imp φ.box.box.box :=
    Derivable.axiom [] _ (Axiom.modal_4 φ.box)
  
  -- Compose using transitivity
  exact imp_trans h1 h2

-- Avoid: Single-line proof without intermediate steps
theorem example (φ : Formula) : ⊢ (□φ → □□□φ) := by
  exact imp_trans (Derivable.axiom [] _ (Axiom.modal_4 φ)) 
                  (Derivable.axiom [] _ (Axiom.modal_4 φ.box))
```

**3. Name Hypotheses Meaningfully**

```lean
-- Good: Meaningful hypothesis names
theorem soundness (Γ : Context) (φ : Formula) (h_deriv : Γ ⊢ φ) : Γ ⊨ φ := by
  induction h_deriv with
  | axiom Γ φ h_ax => sorry
  | assumption Γ φ h_mem => sorry
  | modus_ponens Γ φ ψ h_imp h_φ ih_imp ih_φ => sorry

-- Avoid: Generic names
theorem soundness (Γ : Context) (φ : Formula) (h : Γ ⊢ φ) : Γ ⊨ φ := by
  induction h with
  | axiom Γ φ h1 => sorry
  | assumption Γ φ h2 => sorry
  | modus_ponens Γ φ ψ h3 h4 ih1 ih2 => sorry
```

---

## Axiom Application Patterns

### Direct Axiom Application

```lean
-- Pattern: Apply axiom directly
theorem modal_t_instance (φ : Formula) : ⊢ (φ.box.imp φ) := by
  apply Derivable.axiom
  apply Axiom.modal_t
```

**Compressed Form** (acceptable for simple cases):
```lean
theorem modal_t_instance (φ : Formula) : ⊢ (φ.box.imp φ) :=
  Derivable.axiom [] _ (Axiom.modal_t φ)
```

### Axiom Composition

```lean
-- Pattern: Compose multiple axioms using helper lemmas
theorem necessity_chain (φ : Formula) : ⊢ (□φ → □□□φ) := by
  -- M4 gives us: □φ → □□φ
  have m4_first : ⊢ φ.box.imp φ.box.box :=
    Derivable.axiom [] _ (Axiom.modal_4 φ)
  
  -- M4 again gives us: □□φ → □□□φ
  have m4_second : ⊢ φ.box.box.imp φ.box.box.box :=
    Derivable.axiom [] _ (Axiom.modal_4 φ.box)
  
  -- Compose using implication transitivity
  exact imp_trans m4_first m4_second
```

---

## Inference Rule Patterns

### Modus Ponens

```lean
-- Pattern: Apply modus ponens with explicit premises
theorem example (φ ψ : Formula) (h_imp : ⊢ φ → ψ) (h_φ : ⊢ φ) : ⊢ ψ := by
  apply Derivable.modus_ponens [] φ ψ
  · exact h_imp
  · exact h_φ
```

**Alternative** (using `exact` directly):
```lean
theorem example (φ ψ : Formula) (h_imp : ⊢ φ → ψ) (h_φ : ⊢ φ) : ⊢ ψ :=
  Derivable.modus_ponens [] φ ψ h_imp h_φ
```

### Necessitation

```lean
-- Pattern: Apply necessitation to theorems (empty context)
theorem box_identity (φ : Formula) : ⊢ □(φ → φ) := by
  -- First prove the theorem
  have h_id : ⊢ (φ → φ) := identity φ
  
  -- Apply necessitation
  apply Derivable.necessitation
  exact h_id
```

**Important**: Necessitation only applies to theorems (empty context `[]`), not to derivations from assumptions.

### Modal K Rule

```lean
-- Pattern: Apply modal K to lift derivations
theorem modal_k_example (φ ψ : Formula) : [□φ, □(φ → ψ)] ⊢ □ψ := by
  -- Step 1: Derive ψ from [φ, φ → ψ]
  have deriv_ψ : [φ, φ.imp ψ] ⊢ ψ := by
    apply Derivable.modus_ponens [φ, φ.imp ψ] φ ψ
    · exact Derivable.assumption [φ, φ.imp ψ] (φ.imp ψ) (by simp)
    · exact Derivable.assumption [φ, φ.imp ψ] φ (by simp)
  
  -- Step 2: Apply modal K: [φ, φ → ψ] ⊢ ψ gives [□φ, □(φ → ψ)] ⊢ □ψ
  exact Derivable.modal_k [φ, φ.imp ψ] ψ deriv_ψ
```

### Temporal Necessitation

```lean
-- Pattern: Apply temporal necessitation to theorems
theorem future_identity (φ : Formula) : ⊢ G(φ → φ) := by
  -- First prove the theorem
  have h_id : ⊢ (φ → φ) := identity φ
  
  -- Apply temporal necessitation
  apply Derivable.temporal_necessitation
  exact h_id
```

### Temporal Duality

```lean
-- Pattern: Apply temporal duality to swap past/future
theorem duality_example (φ : Formula) (h : ⊢ Gφ) : ⊢ Hφ := by
  -- Apply temporal duality to swap G ↔ H
  apply Derivable.temporal_duality
  exact h
```

---

## Context Management

### Weakening

```lean
-- Pattern: Add unused assumptions using weakening
theorem weakening_example (φ ψ : Formula) (h : ⊢ φ) : [ψ] ⊢ φ := by
  apply Derivable.weakening [] [ψ] φ h
  -- Prove [] ⊆ [ψ]
  intro x h_mem
  simp at h_mem
```

### Assumption Elimination

```lean
-- Pattern: Eliminate assumptions using deduction theorem
theorem assumption_elim (φ ψ : Formula) (h : [φ] ⊢ ψ) : ⊢ (φ → ψ) := by
  -- Use deduction theorem (when available)
  exact deduction_theorem [] φ ψ h
```

---

## Proof by Induction

### Structural Induction on Formulas

```lean
-- Pattern: Induction on formula structure
theorem formula_property (φ : Formula) : P φ := by
  induction φ with
  | atom p =>
    -- Base case: atoms
    sorry
  | bot =>
    -- Base case: bottom
    sorry
  | imp φ ψ ih_φ ih_ψ =>
    -- Inductive case: implication
    -- ih_φ : P φ
    -- ih_ψ : P ψ
    sorry
  | box φ ih =>
    -- Inductive case: box
    -- ih : P φ
    sorry
  | all_past φ ih =>
    -- Inductive case: all_past
    sorry
  | all_future φ ih =>
    -- Inductive case: all_future
    sorry
```

### Induction on Derivations

```lean
-- Pattern: Induction on derivation structure
theorem derivation_property (Γ : Context) (φ : Formula) (d : Γ ⊢ φ) : P Γ φ := by
  induction d with
  | axiom Γ φ h_ax =>
    -- Base case: axiom
    sorry
  | assumption Γ φ h_mem =>
    -- Base case: assumption
    sorry
  | modus_ponens Γ φ ψ d_imp d_φ ih_imp ih_φ =>
    -- Inductive case: modus ponens
    -- ih_imp : P Γ (φ → ψ)
    -- ih_φ : P Γ φ
    sorry
  | necessitation φ d ih =>
    -- Inductive case: necessitation
    -- ih : P [] φ
    sorry
  | temporal_necessitation φ d ih =>
    -- Inductive case: temporal necessitation
    sorry
  | temporal_duality φ d ih =>
    -- Inductive case: temporal duality
    sorry
  | weakening Γ Δ φ d h_sub ih =>
    -- Inductive case: weakening
    sorry
```

---

## Helper Lemma Usage

### Implication Transitivity

```lean
-- Pattern: Chain implications using imp_trans
theorem chain_example (φ ψ χ : Formula) 
    (h1 : ⊢ φ → ψ) (h2 : ⊢ ψ → χ) : ⊢ (φ → χ) := by
  exact imp_trans h1 h2
```

### Identity

```lean
-- Pattern: Use identity lemma for φ → φ
theorem use_identity (φ : Formula) : ⊢ (φ → φ) := by
  exact identity φ
```

### Combine Implications to Conjunction

```lean
-- Pattern: Combine two implications into conjunction
theorem combine_example (φ ψ χ : Formula)
    (h1 : ⊢ φ → ψ) (h2 : ⊢ φ → χ) : ⊢ (φ → (ψ ∧ χ)) := by
  exact combine_imp_conj h1 h2
```

---

## Modal-Specific Patterns

### S5 Characteristic Theorems

```lean
-- Pattern: Prove S5-specific properties using MT, M4, MB
theorem s5_property (φ : Formula) : ⊢ (φ → □◇φ) := by
  -- This is exactly the MB axiom
  exact Derivable.axiom [] _ (Axiom.modal_b φ)
```

### Necessity Chains

```lean
-- Pattern: Build nested necessity using M4
theorem nested_necessity (φ : Formula) : ⊢ (□φ → □□□φ) := by
  -- Apply M4 twice with transitivity
  exact imp_trans
    (Derivable.axiom [] _ (Axiom.modal_4 φ))
    (Derivable.axiom [] _ (Axiom.modal_4 φ.box))
```

### Possibility Proofs

```lean
-- Pattern: Work with possibility using definitional equality
theorem possibility_example (φ : Formula) : φ.diamond = φ.neg.box.neg := by
  -- Definitional equality
  rfl
```

---

## Temporal-Specific Patterns

### Temporal Chains

```lean
-- Pattern: Build nested temporal operators using T4
theorem nested_future (φ : Formula) : ⊢ (Gφ → GGGφ) := by
  -- Apply T4 twice with transitivity
  exact imp_trans
    (Derivable.axiom [] _ (Axiom.temp_4 φ))
    (Derivable.axiom [] _ (Axiom.temp_4 φ.all_future))
```

### Perpetuity Principles

```lean
-- Pattern: Prove perpetuity principles (□ ↔ △)
theorem perpetuity_1 (φ : Formula) : ⊢ (□φ → △φ) := by
  -- Necessity implies eternal truth
  sorry  -- Requires composition of modal and temporal axioms
```

---

## Proof Documentation

### Theorem Docstrings

**Required Elements**:
1. Theorem statement in natural language
2. Semantic interpretation
3. Proof strategy or key insight
4. References (if applicable)

**Example**:
```lean
/--
Modal K Distribution: `□(φ → ψ) → (□φ → □ψ)`.

If it is necessary that φ implies ψ, then if φ is necessary, ψ must also be necessary.

**Proof Strategy**: Direct application of modal K distribution axiom.

**Semantic Interpretation**: In Kripke semantics, if φ → ψ holds at all accessible
worlds and φ holds at all accessible worlds, then ψ must hold at all accessible worlds.
-/
theorem modal_k_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) :=
  Derivable.axiom [] _ (Axiom.modal_k_dist φ ψ)
```

### Proof Step Comments

**Pattern**: Use `-- Step N: [Description]` for multi-step proofs.

```lean
theorem multi_step_example (φ ψ : Formula) : ⊢ (□φ → □ψ) := by
  -- Step 1: Get the implication φ → ψ
  have h1 : ⊢ (φ → ψ) := sorry
  
  -- Step 2: Apply necessitation to get □(φ → ψ)
  have h2 : ⊢ □(φ → ψ) := by
    apply Derivable.necessitation
    exact h1
  
  -- Step 3: Apply modal K distribution
  have h3 : ⊢ (□(φ → ψ) → (□φ → □ψ)) :=
    Derivable.axiom [] _ (Axiom.modal_k_dist φ ψ)
  
  -- Step 4: Apply modus ponens to get □φ → □ψ
  exact Derivable.modus_ponens [] □(φ → ψ) (□φ → □ψ) h3 h2
```

---

## Common Pitfalls

### Pitfall 1: Applying Necessitation to Assumptions

**Wrong**:
```lean
-- This is INVALID: necessitation only applies to theorems (empty context)
theorem invalid_example (φ : Formula) : [φ] ⊢ □φ := by
  apply Derivable.necessitation  -- ERROR: context must be empty
  exact Derivable.assumption [φ] φ (by simp)
```

**Correct**:
```lean
-- Use modal K rule instead
theorem valid_example (φ : Formula) : [φ] ⊢ □φ := by
  -- Derive φ from [φ]
  have h : [φ] ⊢ φ := Derivable.assumption [φ] φ (by simp)
  
  -- Apply modal K: [φ] ⊢ φ gives [□φ] ⊢ □φ
  -- But we want [φ] ⊢ □φ, which requires deduction theorem
  sorry  -- This actually requires more complex reasoning
```

### Pitfall 2: Confusing Derivability and Validity

**Wrong**:
```lean
-- Confusing ⊢ (derivability) with ⊨ (validity)
theorem confused (φ : Formula) : ⊢ φ := by
  -- Cannot prove arbitrary φ is derivable!
  sorry
```

**Correct**:
```lean
-- Prove specific theorems, not arbitrary formulas
theorem identity_derivable (φ : Formula) : ⊢ (φ → φ) := by
  exact identity φ
```

### Pitfall 3: Ignoring Context Constraints

**Wrong**:
```lean
-- Ignoring that modal K requires boxed context
theorem wrong_modal_k (φ : Formula) : [φ] ⊢ □φ := by
  -- This doesn't work: modal K requires [□φ] ⊢ φ, not [φ] ⊢ φ
  apply Derivable.modal_k [φ] φ
  exact Derivable.assumption [φ] φ (by simp)
```

**Correct**:
```lean
-- Respect context constraints
theorem correct_modal_k (φ : Formula) : [□φ] ⊢ □φ := by
  -- Derive φ from [φ]
  have h : [φ] ⊢ φ := Derivable.assumption [φ] φ (by simp)
  
  -- Apply modal K: [φ] ⊢ φ gives [□φ] ⊢ □φ
  exact Derivable.modal_k [φ] φ h
```

---

## Success Criteria

You've successfully applied these proof conventions when:
- [ ] All proofs have descriptive step comments
- [ ] Intermediate `have` statements are used for clarity
- [ ] Hypotheses have meaningful names
- [ ] Axiom applications are explicit and documented
- [ ] Inference rules are applied correctly with proper context management
- [ ] Helper lemmas are used to simplify proofs
- [ ] Theorem docstrings include semantic interpretation
- [ ] Common pitfalls are avoided (necessitation, context constraints)

---

## Related Documentation

- **Notation Standards**: `logic/standards/notation-standards.md`
- **Modal Proof Strategies**: `logic/processes/modal-proof-strategies.md`
- **Temporal Proof Strategies**: `logic/processes/temporal-proof-strategies.md`
- **Proof Construction Workflow**: `logic/processes/proof-construction.md`
- **LEAN 4 Style Guide**: `lean4/standards/lean4-style-guide.md`
- **Derivation System**: `Logos/Core/ProofSystem/Derivation.lean`
- **Helper Lemmas**: `Logos/Core/Theorems/Perpetuity/Helpers.lean`
