# Proof Theory Concepts

## Overview
Core proof-theoretic concepts for bimodal logic systems, including axioms, inference rules, and derived rules. This file covers the syntactic aspects of formal proof systems.

## Bimodal Logic Proof System

### Axioms
- **K Axiom (Necessity)**: □(p → q) → (□p → □q)
- **K Axiom (Possibility)**: ◇(p → q) → (◇p → ◇q)
- **Dual Axioms**: □p ↔ ¬◇¬p, ◇p ↔ ¬□¬p
- **Distribution**: Modal operators distribute over logical connectives

### Inference Rules
- **Modus Ponens**: From p and p → q, infer q
- **Necessitation**: From ⊢ p, infer ⊢ □p
- **Uniform Substitution**: Replace propositional variables uniformly

### Derived Rules
- **Modal Modus Ponens**: From □p and □(p → q), infer □q
- **Modal Transitivity**: From □p → □q and □q → □r, infer □p → □r

## LEAN 4 Representation

### Axiom Encoding
```lean
-- Propositional variables
inductive PropVar : Type
  | mk : String → PropVar

-- Modal formulas
inductive Formula : Type
  | var : PropVar → Formula
  | bot : Formula
  | imp : Formula → Formula → Formula
  | box1 : Formula → Formula  -- First modality
  | box2 : Formula → Formula  -- Second modality

-- Derived connectives
def neg (φ : Formula) : Formula := φ.imp Formula.bot
def and (φ ψ : Formula) : Formula := neg (φ.imp (neg ψ))
def or (φ ψ : Formula) : Formula := (neg φ).imp ψ
def diamond1 (φ : Formula) : Formula := neg (Formula.box1 (neg φ))
def diamond2 (φ : Formula) : Formula := neg (Formula.box2 (neg φ))

-- K axiom for first modality
axiom K_axiom_1 (φ ψ : Formula) : 
  Formula.box1 (φ.imp ψ) .imp ((Formula.box1 φ).imp (Formula.box1 ψ))

-- K axiom for second modality
axiom K_axiom_2 (φ ψ : Formula) : 
  Formula.box2 (φ.imp ψ) .imp ((Formula.box2 φ).imp (Formula.box2 ψ))

-- Dual axioms
axiom dual_box_diamond_1 (φ : Formula) : 
  Formula.box1 φ ↔ neg (diamond1 (neg φ))

axiom dual_box_diamond_2 (φ : Formula) : 
  Formula.box2 φ ↔ neg (diamond2 (neg φ))
```

### Inference Rule Encoding
```lean
-- Provability relation
inductive Provable : Formula → Prop
  | modus_ponens {φ ψ : Formula} : 
      Provable φ → Provable (φ.imp ψ) → Provable ψ
  | necessitation_1 {φ : Formula} : 
      Provable φ → Provable (Formula.box1 φ)
  | necessitation_2 {φ : Formula} : 
      Provable φ → Provable (Formula.box2 φ)
  | axiom {φ : Formula} : 
      IsAxiom φ → Provable φ

-- Axiom predicate
def IsAxiom (φ : Formula) : Prop :=
  -- Include all tautologies and modal axioms
  IsTautology φ ∨ IsModalAxiom φ
```

### Proof Trees
```lean
-- Proof tree structure
inductive ProofTree : Formula → Type
  | axiom {φ : Formula} (h : IsAxiom φ) : ProofTree φ
  | modus_ponens {φ ψ : Formula} : 
      ProofTree φ → ProofTree (φ.imp ψ) → ProofTree ψ
  | necessitation_1 {φ : Formula} : 
      ProofTree φ → ProofTree (Formula.box1 φ)
  | necessitation_2 {φ : Formula} : 
      ProofTree φ → ProofTree (Formula.box2 φ)

-- Extract provability from proof tree
theorem proofTree_implies_provable {φ : Formula} : 
    ProofTree φ → Provable φ := by
  intro h
  induction h with
  | axiom h => exact Provable.axiom h
  | modus_ponens _ _ ih1 ih2 => exact Provable.modus_ponens ih1 ih2
  | necessitation_1 _ ih => exact Provable.necessitation_1 ih
  | necessitation_2 _ ih => exact Provable.necessitation_2 ih
```

## Normal Forms

### Negation Normal Form (NNF)
```lean
-- Convert to NNF (negations only on atoms)
def toNNF : Formula → Formula
  | Formula.var p => Formula.var p
  | Formula.bot => Formula.bot
  | Formula.imp φ ψ => or (toNNF (neg φ)) (toNNF ψ)
  | Formula.box1 φ => Formula.box1 (toNNF φ)
  | Formula.box2 φ => Formula.box2 (toNNF φ)

-- NNF preserves equivalence
theorem toNNF_equiv (φ : Formula) : φ ↔ toNNF φ
```

### Conjunctive Normal Form (CNF)
```lean
-- Clause (disjunction of literals)
def Clause := List Formula

-- CNF (conjunction of clauses)
def CNF := List Clause

-- Convert to CNF
def toCNF (φ : Formula) : CNF :=
  -- Implementation using distribution laws
  sorry
```

## Proof Strategies

### Forward Reasoning
```lean
-- Apply modus ponens forward
def applyModusPonens (φ ψ : Formula) 
    (h1 : Provable φ) (h2 : Provable (φ.imp ψ)) : Provable ψ :=
  Provable.modus_ponens h1 h2

-- Apply necessitation forward
def applyNecessitation1 (φ : Formula) (h : Provable φ) : 
    Provable (Formula.box1 φ) :=
  Provable.necessitation_1 h
```

### Backward Reasoning
```lean
-- Goal-directed proof search
def proveByBackwardReasoning (φ : Formula) : Option (ProofTree φ) :=
  match φ with
  | Formula.var _ => 
      if IsAxiom φ then some (ProofTree.axiom sorry) else none
  | Formula.box1 ψ =>
      match proveByBackwardReasoning ψ with
      | some proof => some (ProofTree.necessitation_1 proof)
      | none => none
  | Formula.imp ψ χ =>
      -- Try to prove ψ and ψ → χ
      sorry
  | _ => none
```

## Deduction Theorem

### Statement
```lean
-- Deduction theorem for modal logic
theorem deduction_theorem (Γ : List Formula) (φ ψ : Formula) :
    (Provable_from (φ :: Γ) ψ) → 
    (Provable_from Γ (φ.imp ψ)) := by
  sorry
```

### Limitations
The deduction theorem does NOT hold for necessitation:
- From Γ, φ ⊢ ψ we cannot always conclude Γ ⊢ φ → □ψ
- Necessitation requires ⊢ ψ (no assumptions)

## Proof Complexity

### Proof Length
```lean
-- Length of a proof tree
def proofLength : {φ : Formula} → ProofTree φ → ℕ
  | _, ProofTree.axiom _ => 1
  | _, ProofTree.modus_ponens p1 p2 => 
      1 + proofLength p1 + proofLength p2
  | _, ProofTree.necessitation_1 p => 1 + proofLength p
  | _, ProofTree.necessitation_2 p => 1 + proofLength p

-- Minimal proof length
def minimalProofLength (φ : Formula) : ℕ :=
  Nat.find (exists_proof_of_length φ)
```

### Proof Optimization
```lean
-- Remove redundant steps
def optimizeProof : {φ : Formula} → ProofTree φ → ProofTree φ
  | _, proof => 
      -- Remove unnecessary detours
      -- Combine adjacent applications
      sorry
```

## Sequent Calculus

### Sequent Definition
```lean
-- Sequent: Γ ⊢ Δ
structure Sequent where
  antecedent : List Formula  -- Γ
  consequent : List Formula  -- Δ

-- Sequent rules
inductive SequentProvable : Sequent → Prop
  | axiom {φ : Formula} : 
      SequentProvable ⟨[φ], [φ]⟩
  | left_imp {Γ Δ φ ψ : _} :
      SequentProvable ⟨Γ, φ :: Δ⟩ →
      SequentProvable ⟨ψ :: Γ, Δ⟩ →
      SequentProvable ⟨(φ.imp ψ) :: Γ, Δ⟩
  | right_imp {Γ Δ φ ψ : _} :
      SequentProvable ⟨φ :: Γ, ψ :: Δ⟩ →
      SequentProvable ⟨Γ, (φ.imp ψ) :: Δ⟩
  | left_box1 {Γ Δ φ : _} :
      SequentProvable ⟨[φ], Δ⟩ →
      SequentProvable ⟨[Formula.box1 φ], Δ⟩
  | right_box1 {Γ Δ φ : _} :
      SequentProvable ⟨Γ, [φ]⟩ →
      SequentProvable ⟨Γ, [Formula.box1 φ]⟩
```

## Cut Elimination

### Cut Rule
```lean
-- Cut rule (admissible in sequent calculus)
axiom cut_rule {Γ Δ φ : _} :
    SequentProvable ⟨Γ, φ :: Δ⟩ →
    SequentProvable ⟨φ :: Γ, Δ⟩ →
    SequentProvable ⟨Γ, Δ⟩

-- Cut elimination theorem
theorem cut_elimination {s : Sequent} :
    SequentProvable s → 
    ∃ (proof : SequentProvable s), CutFree proof := by
  sorry
```

## Business Rules

1. **Use inductive types**: Define formulas and proofs inductively
2. **Separate syntax and semantics**: Keep proof theory distinct from model theory
3. **Implement proof search**: Provide both forward and backward reasoning
4. **Optimize proofs**: Remove redundant steps
5. **Use sequent calculus**: For structural proof theory

## Common Pitfalls

1. **Confusing ⊢ and ⊨**: Provability vs validity
2. **Applying necessitation incorrectly**: Requires no assumptions
3. **Forgetting uniform substitution**: Must replace all occurrences
4. **Not checking axiom instances**: Verify axiom schemas properly instantiated
5. **Ignoring proof complexity**: Some proofs are exponentially longer

## Relationships

- **Used by**: Semantics (soundness), metalogic (completeness)
- **Related**: Sequent calculus, natural deduction, tableau methods
- **Extends**: Propositional logic, first-order logic

## References

- Modal Logic textbooks (Blackburn, de Rijke, Venema)
- Proof Theory (Troelstra, Schwichtenberg)
- Handbook of Modal Logic (Blackburn et al.)
