# Lean 4 Syntax

## Overview

This file covers advanced Lean 4 syntax relevant to expert users, focusing on metaprogramming, tactics, and custom notation.

## Key Syntactic Features

### Metaprogramming

Lean 4's metaprogramming framework allows for writing custom tactics and manipulating expressions at compile time.

- **`MetaM` Monad**: The core of Lean 4's metaprogramming, providing access to the compiler's internals.
- **`Expr`**: The data structure representing Lean 4 expressions.
- **`Lean.Elab`**: The namespace for elaboration, the process of converting surface syntax into `Expr`.

### Tactic Framework

The tactic framework is used to write custom proof automation.

- **`TacticM` Monad**: A specialized version of `MetaM` for writing tactics.
- **`Lean.Parser.Tactic`**: The namespace for parsing tactic syntax.
- **`liftM`**: Lifts a `MetaM` computation into `TacticM`.

### Custom Notation

Lean 4 allows for defining custom notation to make code more readable.

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

### Structure Definitions

```lean
/-- A point in 2D space -/
structure Point where
  x : Float
  y : Float
  deriving Repr

-- Usage
def origin : Point := ⟨0.0, 0.0⟩
```

### Inductive Definitions

```lean
/-- Binary tree -/
inductive Tree (α : Type) where
  | leaf : α → Tree α
  | node : Tree α → Tree α → Tree α
  deriving Repr
```

### Tactic Proofs

#### Simple Tactic Proof

```lean
theorem imp_refl (φ : Formula) : Derivable [] (φ.imp φ) := by
  apply Derivable.axiom
  exact Axiom.identity φ
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
notation:50 φ " => " ψ => Formula.imp φ ψ

-- Prefix notation for box modality
prefix:75 "[]" => Formula.box

-- Postfix notation for complexity
postfix:max "+" => Formula.complexity
```
