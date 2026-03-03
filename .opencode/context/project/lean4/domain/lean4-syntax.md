# LEAN 4 Syntax

## Overview
This file covers advanced LEAN 4 syntax relevant to expert users, focusing on metaprogramming, tactics, and custom notation.

## Key Syntactic Features

### Metaprogramming
LEAN 4's metaprogramming framework allows for writing custom tactics and manipulating expressions at compile time.

- **`MetaM` Monad**: The core of LEAN 4's metaprogramming, providing access to the compiler's internals.
- **`Expr`**: The data structure representing LEAN 4 expressions.
- **`Lean.Elab`**: The namespace for elaboration, the process of converting surface syntax into `Expr`.

### Tactic Framework
The tactic framework is used to write custom proof automation.

- **`TacticM` Monad**: A specialized version of `MetaM` for writing tactics.
- **`Lean.Parser.Tactic`**: The namespace for parsing tactic syntax.
- **`liftM`**: Lifts a `MetaM` computation into `TacticM`.

### Custom Notation
LEAN 4 allows for defining custom notation to make code more readable.

- **`notation`**: The command for defining new notation.
- **`infix`, `prefix`, `postfix`**: Keywords for defining the type of notation.

## Examples

### Basic Declarations

#### Definition
```lean
/-- Natural number addition -/
def add (n m : Nat) : Nat :=
  match m with
  | 0 => n
  | m' + 1 => (add n m') + 1
```

#### Theorem
```lean
/-- Addition is commutative -/
theorem add_comm (n m : Nat) : add n m = add m n := by
  induction m with
  | zero => simp [add]
  | succ m' ih => simp [add, ih]
```

#### Lemma
```lean
/-- Zero is the right identity for addition -/
lemma add_zero (n : Nat) : add n 0 = n := by
  rfl
```

### Structure Definitions

#### Simple Structure
```lean
/-- A point in 2D space -/
structure Point where
  x : Float
  y : Float
  deriving Repr

-- Usage
def origin : Point := ⟨0.0, 0.0⟩
```

#### Structure with Methods
```lean
/-- A formula in propositional logic -/
structure Formula where
  atoms : List String
  complexity : Nat
  deriving DecidableEq

namespace Formula

/-- Check if formula is atomic -/
def isAtomic (φ : Formula) : Bool :=
  φ.complexity = 0

end Formula
```

### Inductive Definitions

#### Simple Inductive Type
```lean
/-- Binary tree -/
inductive Tree (α : Type) where
  | leaf : α → Tree α
  | node : Tree α → Tree α → Tree α
  deriving Repr
```

#### Inductive Predicate
```lean
/-- Derivability relation for Hilbert-style proof system -/
inductive Derivable : List Formula → Formula → Prop where
  | axiom : Axiom φ → Derivable Γ φ
  | assume : φ ∈ Γ → Derivable Γ φ
  | mp : Derivable Γ (φ.imp ψ) → Derivable Γ φ → Derivable Γ ψ
```

### Tactic Proofs

#### Simple Tactic Proof
```lean
theorem imp_refl (φ : Formula) : Derivable [] (φ.imp φ) := by
  apply Derivable.axiom
  exact Axiom.prop_s φ φ
```

#### Multi-Step Tactic Proof
```lean
theorem conjunction_elim_left (φ ψ : Formula) : 
    Derivable [φ.and ψ] φ := by
  -- Unfold conjunction definition
  unfold Formula.and
  -- Apply modus ponens
  apply Derivable.mp
  · apply Derivable.axiom
    exact Axiom.prop_k φ ψ
  · apply Derivable.assume
    simp
```

#### Proof with Induction
```lean
theorem list_length_append (xs ys : List α) :
    (xs ++ ys).length = xs.length + ys.length := by
  induction xs with
  | nil => simp
  | cons x xs' ih =>
    simp [List.length, List.append]
    rw [ih]
```

### Custom Tactic
```lean
import Lean

open Lean Elab Tactic

elab "my_tactic" : tactic => do
  let goal ← getMainGoal
  goal.withContext do
    let target ← getMainTarget
    logInfo m!"Current target: {target}"
```

### Custom Notation
```lean
-- Infix notation for implication
notation:50 φ " ⇒ " ψ => Formula.imp φ ψ

-- Prefix notation for box modality
prefix:75 "□" => Formula.box

-- Postfix notation for complexity
postfix:max "†" => Formula.complexity
```

## Examples from Logos Codebase

### Formula Definition (from Logos/Core/Syntax/Formula.lean)

```lean
/-- Formula type for bimodal logic TM -/
inductive Formula : Type where
  | atom : String → Formula
  | bot : Formula
  | imp : Formula → Formula → Formula
  | box : Formula → Formula
  | all_past : Formula → Formula
  | all_future : Formula → Formula
  deriving Repr, DecidableEq

namespace Formula

/-- Structural complexity of a formula -/
def complexity : Formula → Nat
  | atom _ => 1
  | bot => 1
  | imp φ ψ => 1 + φ.complexity + ψ.complexity
  | box φ => 1 + φ.complexity
  | all_past φ => 1 + φ.complexity
  | all_future φ => 1 + φ.complexity

/-- Negation as derived operator: φ → ⊥ -/
def neg (φ : Formula) : Formula := φ.imp bot

/-- Conjunction as derived operator: ¬(φ → ¬ψ) -/
def and (φ ψ : Formula) : Formula := (φ.imp ψ.neg).neg
```

### Theorem Proof (from Logos/Core/Theorems/Propositional.lean)

```lean
/-- Law of Excluded Middle: ⊢ A ∨ ¬A -/
def lem (A : Formula) : ⊢ A.or A.neg := by
  -- A ∨ ¬A = ¬A → ¬A (by definition of disjunction)
  unfold Formula.or
  -- Now goal is: ⊢ A.neg.imp A.neg
  exact identity A.neg

/-- Peirce's Law: ⊢ ((φ → ψ) → φ) → φ -/
def peirce_axiom (φ ψ : Formula) : ⊢ ((φ.imp ψ).imp φ).imp φ :=
  DerivationTree.axiom [] _ (Axiom.peirce φ ψ)
```

### Complex Proof with Modus Ponens (from Logos/Core/Theorems/Combinators.lean)

```lean
/-- Implication transitivity: (φ → ψ) → ((ψ → χ) → (φ → χ)) -/
theorem imp_trans (φ ψ χ : Formula) : 
    Derivable [] ((φ.imp ψ).imp ((ψ.imp χ).imp (φ.imp χ))) := by
  apply Derivable.mp
  · apply Derivable.mp
    · apply Derivable.axiom
      exact Axiom.prop_k (ψ.imp χ) ψ χ
    · apply Derivable.axiom
      exact Axiom.prop_s φ ψ χ
  · apply Derivable.axiom
    exact Axiom.prop_k φ (ψ.imp χ) (φ.imp χ)
```
