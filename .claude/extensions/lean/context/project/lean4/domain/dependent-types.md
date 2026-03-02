# Dependent Type Theory in Lean 4

## Overview

Lean 4 is based on the Calculus of Inductive Constructions (CIC), a dependent type theory. This file covers the foundations of dependent types and their use in Lean 4.

## Type Universe Hierarchy

### Universes

Lean 4 has a hierarchy of type universes to avoid paradoxes.

```lean
-- Type universes
#check Type      -- Type 0
#check Type 1    -- Type 1
#check Type 2    -- Type 2

-- Universe polymorphism
universe u v w

#check Type u
#check Type (max u v)
```

### Universe Levels

```lean
-- Prop is at the bottom
#check Prop      -- Type of propositions

-- Sort is the general form
#check Sort 0    -- Same as Prop
#check Sort 1    -- Same as Type
#check Sort 2    -- Same as Type 1

-- Universe variables
variable {α : Type u} {β : Type v}

#check α → β     -- Type (max u v)
```

## Dependent Function Types (Pi-types)

### Basic Dependent Functions

```lean
-- Non-dependent function type
#check Nat → Bool    -- Nat → Bool : Type

-- Dependent function type
#check (n : Nat) → Fin n    -- (n : Nat) → Fin n : Type

-- Explicit Pi-type notation
#check ∀ (n : Nat), Fin n   -- Same as above

-- Vector type (length-indexed)
def Vector (α : Type u) (n : Nat) : Type u :=
  Fin n → α

-- Head of a vector (requires n > 0)
def Vector.head {α : Type u} {n : Nat} (v : Vector α (n + 1)) : α :=
  v 0
```

### Curry-Howard Correspondence

Propositions are types, proofs are terms.

```lean
-- Implication is function type
example : (P → Q) = (P → Q) := rfl

-- Universal quantification is dependent function
example : (∀ x : α, P x) = ((x : α) → P x) := rfl

-- Modus ponens is function application
theorem modus_ponens {P Q : Prop} (h1 : P → Q) (h2 : P) : Q :=
  h1 h2
```

## Dependent Pair Types (Sigma-types)

### Sigma Types

```lean
-- Dependent pair type
#check (n : Nat) × Fin n    -- Σ n : Nat, Fin n

-- Explicit Σ-type notation
#check Σ (n : Nat), Fin n   -- Same as above

-- Existential quantification
#check ∃ (n : Nat), n > 0   -- Σ n : Nat, n > 0

-- Constructing dependent pairs
example : Σ n : Nat, Fin n := ⟨3, 2⟩

-- Projections
example (p : Σ n : Nat, Fin n) : Nat := p.1
example (p : Σ n : Nat, Fin n) : Fin p.1 := p.2
```

### Subtype

A special case of Sigma-types for predicates:

```lean
-- Subtype notation
#check {x : Nat // x > 0}    -- Subtype of Nat

-- Constructing subtypes
example : {x : Nat // x > 0} := ⟨1, by norm_num⟩

-- Coercion to base type
example (x : {n : Nat // n > 0}) : Nat := x.val

-- Accessing proof
example (x : {n : Nat // n > 0}) : x.val > 0 := x.property
```

## Inductive Types

### Basic Inductive Types

```lean
-- Natural numbers
inductive Nat : Type where
  | zero : Nat
  | succ : Nat → Nat

-- Lists
inductive List (α : Type u) : Type u where
  | nil : List α
  | cons : α → List α → List α

-- Binary trees
inductive Tree (α : Type u) : Type u where
  | leaf : Tree α
  | node : α → Tree α → Tree α → Tree α
```

### Indexed Inductive Types

```lean
-- Vectors (length-indexed lists)
inductive Vector (α : Type u) : Nat → Type u where
  | nil : Vector α 0
  | cons : {n : Nat} → α → Vector α n → Vector α (n + 1)

-- Equality type
inductive Eq {α : Type u} : α → α → Prop where
  | refl (a : α) : Eq a a
```

## Propositions as Types

### Prop vs Type

```lean
-- Prop is proof-irrelevant
example (p : Prop) (h1 h2 : p) : h1 = h2 := rfl

-- Prop lives in Sort 0
#check Prop      -- Prop : Type

-- Impredicativity of Prop
#check ∀ (α : Type), α → α    -- Type 1
#check ∀ (p : Prop), p → p    -- Prop (stays in Prop!)
```

### Logical Connectives as Types

```lean
-- Conjunction is product type
example {P Q : Prop} : P ∧ Q = P × Q := rfl

-- Disjunction is sum type
example {P Q : Prop} : P ∨ Q = Sum P Q := rfl

-- Negation is function to False
example {P : Prop} : ¬P = (P → False) := rfl
```

## Common Pitfalls

1. **Universe inconsistency**: Type : Type leads to paradox
2. **Confusing Prop and Bool**: Different purposes
3. **Forgetting proof irrelevance**: Prop proofs are all equal
4. **Not using dependent types**: Missing type-level guarantees
5. **Overusing classical axioms**: Lose constructive content

## References

- Theorem Proving in Lean 4
- Type Theory and Formal Proof (Nederpelt & Geuvers)
- Lean 4 documentation
