# Soundness and Completeness for Bimodal Logic

## Overview
Metatheoretic properties connecting proof theory and semantics. Soundness states that provability implies validity; completeness is the converse.

## Soundness

### Statement
If a formula is provable, then it is valid in all models.

```lean
-- Soundness theorem
theorem soundness (φ : Formula) : Provable φ → valid φ := by
  intro h
  induction h with
  | axiom h_ax =>
      -- Show all axioms are valid
      intro M w
      sorry
  | modus_ponens h_φ h_imp ih_φ ih_imp =>
      -- Show modus ponens preserves validity
      intro M w
      have h1 := ih_φ M w
      have h2 := ih_imp M w
      simp [satisfies] at h2
      exact h2 h1
  | necessitation_1 h_φ ih =>
      -- Show necessitation preserves validity
      intro M w
      simp [satisfies]
      intro w' _
      exact ih M w'
  | necessitation_2 h_φ ih =>
      intro M w
      simp [satisfies]
      intro w' _
      exact ih M w'
```

### Axiom Validity

Each axiom schema must be shown to be valid:

```lean
-- K axiom is valid
theorem K_axiom_valid (φ ψ : Formula) :
    valid (Formula.box1 (φ.imp ψ) .imp ((Formula.box1 φ).imp (Formula.box1 ψ))) := by
  intro M w
  simp [satisfies]
  intro h_box_imp h_box_φ w' h_R
  exact h_box_imp w' h_R (h_box_φ w' h_R)

-- Dual axiom is valid
theorem dual_axiom_valid (φ : Formula) :
    valid (Formula.box1 φ .imp (neg (diamond1 (neg φ)))) := by
  intro M w
  simp [satisfies, neg, diamond1]
  intro h_box
  push_neg
  intro w' h_R
  exact h_box w' h_R

-- Propositional tautologies are valid
theorem tautology_valid (φ : Formula) (h : IsTautology φ) : valid φ := by
  sorry
```

### Soundness for Frame Classes

Soundness can be strengthened for specific frame classes:

```lean
-- T axiom is valid on reflexive frames
theorem T_axiom_valid_on_reflexive :
    ∀ (M : KripkeModel), Reflexive M.R1 →
    validInModel M (Formula.box1 (Formula.var p) .imp (Formula.var p)) := by
  intro M h_refl w
  simp [satisfies]
  intro h_box
  exact h_box w (h_refl w)

-- 4 axiom is valid on transitive frames
theorem four_axiom_valid_on_transitive :
    ∀ (M : KripkeModel), Transitive M.R1 →
    validInModel M (Formula.box1 (Formula.var p) .imp 
      (Formula.box1 (Formula.box1 (Formula.var p)))) := by
  intro M h_trans w
  simp [satisfies]
  intro h_box w' h_R1 w'' h_R2
  exact h_box w'' (h_trans w w' w'' h_R1 h_R2)
```

## Completeness

### Statement
If a formula is valid in all models, then it is provable.

```lean
-- Completeness theorem (strong form)
theorem completeness (φ : Formula) : valid φ → Provable φ := by
  sorry  -- Requires canonical model construction
```

### Canonical Model Construction

The key to proving completeness is constructing a canonical model:

```lean
-- Maximal consistent set
def MaximalConsistentSet (Γ : Set Formula) : Prop :=
  Consistent Γ ∧ ∀ φ, φ ∉ Γ → ¬Consistent (insert φ Γ)

-- Consistent set
def Consistent (Γ : Set Formula) : Prop :=
  ¬∃ φ, Provable_from Γ φ ∧ Provable_from Γ (neg φ)

-- Canonical model
def CanonicalModel : KripkeModel where
  World := {Γ : Set Formula | MaximalConsistentSet Γ}
  R1 := fun Γ Δ => ∀ φ, Formula.box1 φ ∈ Γ → φ ∈ Δ
  R2 := fun Γ Δ => ∀ φ, Formula.box2 φ ∈ Γ → φ ∈ Δ
  V := fun p Γ => Formula.var p ∈ Γ.val
```

### Truth Lemma

The crucial step in completeness is the truth lemma:

```lean
-- Truth lemma: formula is in maximal consistent set iff satisfied
theorem truth_lemma (φ : Formula) (Γ : CanonicalModel.World) :
    φ ∈ Γ.val ↔ CanonicalModel, Γ ⊨ φ := by
  induction φ with
  | var p => rfl
  | bot =>
      constructor
      · intro h
        exfalso
        -- Γ is consistent, so ⊥ ∉ Γ
        sorry
      · intro h
        exact h
  | imp φ ψ ih_φ ih_ψ =>
      constructor
      · intro h
        simp [satisfies]
        intro h_φ
        -- If φ → ψ ∈ Γ and φ ∈ Γ, then ψ ∈ Γ by modus ponens
        sorry
      · intro h
        -- If φ → ψ ∉ Γ, then φ ∈ Γ and ψ ∉ Γ (by maximality)
        -- This contradicts h
        sorry
  | box1 φ ih =>
      constructor
      · intro h
        simp [satisfies]
        intro Δ h_R
        exact ih.mp (h_R φ h)
      · intro h
        -- If □φ ∉ Γ, construct Δ with Γ R Δ and φ ∉ Δ
        -- This contradicts h
        sorry
  | box2 φ ih =>
      sorry
```

### Lindenbaum's Lemma

Every consistent set can be extended to a maximal consistent set:

```lean
-- Lindenbaum's lemma
theorem lindenbaum (Γ : Set Formula) (h : Consistent Γ) :
    ∃ Δ, Γ ⊆ Δ ∧ MaximalConsistentSet Δ := by
  sorry  -- Requires Zorn's lemma or similar
```

### Completeness Proof Sketch

```lean
theorem completeness_proof_sketch (φ : Formula) (h : valid φ) : Provable φ := by
  -- Proof by contradiction
  by_contra h_not_prov
  
  -- If φ is not provable, then {¬φ} is consistent
  have h_cons : Consistent {neg φ} := by sorry
  
  -- Extend to maximal consistent set
  obtain ⟨Γ, h_sub, h_max⟩ := lindenbaum {neg φ} h_cons
  
  -- In canonical model, Γ satisfies ¬φ
  have h_sat : CanonicalModel, ⟨Γ, h_max⟩ ⊨ neg φ := by
    exact truth_lemma (neg φ) ⟨Γ, h_max⟩ |>.mp (h_sub rfl)
  
  -- But φ is valid, so Γ should satisfy φ
  have h_valid : CanonicalModel, ⟨Γ, h_max⟩ ⊨ φ := h CanonicalModel ⟨Γ, h_max⟩
  
  -- Contradiction
  simp [satisfies, neg] at h_sat
  exact h_sat h_valid
```

## Decidability

### Statement
There exists an algorithm to determine if a formula is provable.

```lean
-- Decidability (for finite models)
def decidable_satisfiable (φ : Formula) : Bool :=
  -- Check all finite models up to some bound
  sorry

-- Decidability theorem (for K)
theorem decidable_K : ∀ φ : Formula, Decidable (Provable φ) := by
  sorry
```

### Finite Model Property

Many modal logics have the finite model property:

```lean
-- Finite model property
theorem finite_model_property (φ : Formula) :
    satisfiable φ → ∃ (M : KripkeModel), Finite M.World ∧ satisfiableInModel M φ := by
  intro ⟨M, w, h⟩
  -- Use filtration to construct finite model
  sorry
```

## Consistency

### Statement
There is no formula φ such that both φ and ¬φ are provable.

```lean
-- Consistency
theorem consistency : ¬∃ φ, Provable φ ∧ Provable (neg φ) := by
  intro ⟨φ, h_prov, h_prov_neg⟩
  -- Use soundness
  have h_valid := soundness φ h_prov
  have h_valid_neg := soundness (neg φ) h_prov_neg
  -- Construct trivial model
  let M : KripkeModel := {
    World := Unit
    R1 := fun _ _ => True
    R2 := fun _ _ => True
    V := fun _ _ => True
  }
  -- φ and ¬φ can't both be valid
  have h1 := h_valid M ()
  have h2 := h_valid_neg M ()
  simp [satisfies, neg] at h2
  exact h2 h1
```

## Compactness

### Statement
If every finite subset of a set of formulas is satisfiable, then the whole set is satisfiable.

```lean
-- Compactness theorem
theorem compactness (Γ : Set Formula) :
    (∀ Δ : Finset Formula, ↑Δ ⊆ Γ → satisfiable (⋀ φ ∈ Δ, φ)) →
    ∃ M : KripkeModel, ∃ w, ∀ φ ∈ Γ, M, w ⊨ φ := by
  sorry  -- Follows from completeness
```

## Interpolation

### Craig Interpolation
If φ → ψ is valid, there exists an interpolant using only common variables.

```lean
-- Craig interpolation
theorem craig_interpolation (φ ψ : Formula) (h : valid (φ.imp ψ)) :
    ∃ χ : Formula, 
      (vars χ ⊆ vars φ ∩ vars ψ) ∧
      valid (φ.imp χ) ∧
      valid (χ.imp ψ) := by
  sorry
```

## Business Rules

1. **Prove soundness first**: Always easier than completeness
2. **Use canonical models**: Standard technique for completeness
3. **Check frame correspondence**: Different axioms need different frames
4. **Use filtration**: For finite model property
5. **Apply compactness**: For infinite satisfiability arguments

## Common Pitfalls

1. **Forgetting maximality**: Lindenbaum extension is crucial
2. **Not checking consistency**: Canonical model requires consistent sets
3. **Ignoring frame properties**: Completeness depends on frame class
4. **Assuming decidability**: Not all modal logics are decidable
5. **Confusing strong/weak completeness**: Different notions exist

## Relationships

- **Uses**: Proof theory, semantics
- **Related**: Model theory, recursion theory
- **Applications**: Verification, knowledge representation

## References

- Modal Logic (Blackburn, de Rijke, Venema) - Chapter 4
- Handbook of Modal Logic - Completeness sections
- Computability and Logic (Boolos, Burgess, Jeffrey)
