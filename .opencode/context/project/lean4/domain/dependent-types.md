# Dependent Type Theory in LEAN 4

## Overview
LEAN 4 is based on the Calculus of Inductive Constructions (CIC), a dependent type theory. This file covers the foundations of dependent types and their use in LEAN 4.

## Type Universe Hierarchy

### Universes
LEAN 4 has a hierarchy of type universes to avoid paradoxes.

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

## Dependent Function Types (Π-types)

### Basic Dependent Functions
```lean
-- Non-dependent function type
#check Nat → Bool    -- Nat → Bool : Type

-- Dependent function type
#check (n : Nat) → Fin n    -- (n : ℕ) → Fin n : Type

-- Explicit Π-type notation
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

## Dependent Pair Types (Σ-types)

### Sigma Types
```lean
-- Dependent pair type
#check (n : Nat) × Fin n    -- Σ n : ℕ, Fin n

-- Explicit Σ-type notation
#check Σ (n : Nat), Fin n   -- Same as above

-- Existential quantification
#check ∃ (n : Nat), n > 0   -- Σ n : ℕ, n > 0

-- Constructing dependent pairs
example : Σ n : Nat, Fin n := ⟨3, 2⟩

-- Projections
example (p : Σ n : Nat, Fin n) : Nat := p.1
example (p : Σ n : Nat, Fin n) : Fin p.1 := p.2
```

### Subtype
A special case of Σ-types for predicates:

```lean
-- Subtype notation
#check {x : Nat // x > 0}    -- Subtype of Nat

-- Equivalent to Σ-type
example : {x : Nat // x > 0} = Σ x : Nat, x > 0 := rfl

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

-- Less-than relation
inductive LT : Nat → Nat → Prop where
  | base (n : Nat) : LT n (n + 1)
  | step {m n : Nat} : LT m n → LT m (n + 1)
```

### Recursive Functions on Inductive Types
```lean
-- Addition on natural numbers
def Nat.add : Nat → Nat → Nat
  | m, Nat.zero => m
  | m, Nat.succ n => Nat.succ (Nat.add m n)

-- Length of a vector
def Vector.length {α : Type u} {n : Nat} : Vector α n → Nat
  | Vector.nil => 0
  | Vector.cons _ v => 1 + Vector.length v

-- Append vectors
def Vector.append {α : Type u} {m n : Nat} : 
    Vector α m → Vector α n → Vector α (m + n)
  | Vector.nil, v2 => v2
  | Vector.cons x v1, v2 => Vector.cons x (Vector.append v1 v2)
```

## Propositions as Types

### Prop vs Type
```lean
-- Prop is proof-irrelevant
example (p : Prop) (h1 h2 : p) : h1 = h2 := rfl

-- Type is not proof-irrelevant
example : (true : Bool) ≠ (false : Bool) := by decide

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

-- Bi-implication is product of implications
example {P Q : Prop} : (P ↔ Q) = (P → Q) × (Q → P) := rfl
```

## Equality and Identity Types

### Propositional Equality
```lean
-- Equality is an inductive type
#check @Eq      -- {α : Type u} → α → α → Prop

-- Reflexivity
example (a : α) : a = a := rfl

-- Symmetry
example {a b : α} (h : a = b) : b = a := h.symm

-- Transitivity
example {a b c : α} (h1 : a = b) (h2 : b = c) : a = c := 
  h1.trans h2

-- Substitution (transport)
example {a b : α} (P : α → Prop) (h : a = b) (ha : P a) : P b :=
  h ▸ ha
```

### Heterogeneous Equality
```lean
-- HEq for equality across types
#check @HEq     -- {α : Sort u} → α → {β : Sort u} → β → Prop

-- Notation
example {α β : Type} (a : α) (b : β) : HEq a b := by
  sorry  -- Only provable if α = β and a = b
```

## Quotient Types

### Quotient Construction
```lean
-- Quotient by equivalence relation
variable {α : Type u} (r : α → α → Prop)
variable (h_equiv : Equivalence r)

#check Quotient (Setoid.mk r h_equiv)

-- Quotient map
#check @Quotient.mk     -- Quotient s → α

-- Quotient lift
#check @Quotient.lift   -- Lift function respecting equivalence

-- Quotient induction
#check @Quotient.ind    -- Induction principle for quotients
```

### Example: Integers from Natural Numbers
```lean
-- Define integers as quotient of ℕ × ℕ
def IntRel : (Nat × Nat) → (Nat × Nat) → Prop :=
  fun ⟨a, b⟩ ⟨c, d⟩ => a + d = b + c

-- This is an equivalence relation
theorem IntRel.equiv : Equivalence IntRel := by
  constructor
  · intro ⟨a, b⟩; rfl
  · intro ⟨a, b⟩ ⟨c, d⟩ h; exact h.symm
  · intro ⟨a, b⟩ ⟨c, d⟩ ⟨e, f⟩ h1 h2
    sorry  -- Prove transitivity

-- Integer type
def MyInt := Quotient (Setoid.mk IntRel IntRel.equiv)
```

## Type Classes

### Type Class Definition
```lean
-- Type class for types with addition
class Add (α : Type u) where
  add : α → α → α

-- Instance for natural numbers
instance : Add Nat where
  add := Nat.add

-- Using type class
def double {α : Type u} [Add α] (x : α) : α :=
  Add.add x x
```

### Dependent Type Classes
```lean
-- Type class depending on a value
class Vector.Inhabited (α : Type u) (n : Nat) where
  default : Vector α n

-- Instance for any n
instance {α : Type u} [Inhabited α] (n : Nat) : 
    Vector.Inhabited α n where
  default := Vector.replicate n (Inhabited.default)
```

## Proof Irrelevance

### Prop is Proof-Irrelevant
```lean
-- All proofs of a proposition are equal
theorem proof_irrel {p : Prop} (h1 h2 : p) : h1 = h2 := rfl

-- Subsingleton for Prop
example (p : Prop) : Subsingleton p := inferInstance

-- Not true for Type
example : ¬∀ (α : Type) [Nonempty α], Subsingleton α := by
  intro h
  have : Subsingleton Bool := h Bool
  have : (true : Bool) = false := Subsingleton.elim true false
  contradiction
```

## Axioms in LEAN 4

### Classical Logic
```lean
-- Law of excluded middle
#check Classical.em     -- ∀ (p : Prop), p ∨ ¬p

-- Choice
#check Classical.choice -- {α : Sort u} → Nonempty α → α

-- Propositional extensionality
#check propext          -- {p q : Prop} → (p ↔ q) → p = q

-- Quotient soundness
#check Quot.sound       -- {r : α → α → Prop} → r a b → ⟦a⟧ = ⟦b⟧
```

## Business Rules

1. **Use universe polymorphism**: Make definitions universe-polymorphic when possible
2. **Leverage dependent types**: Use indexed types for invariants
3. **Understand Prop vs Type**: Know when to use each
4. **Use type classes**: For ad-hoc polymorphism
5. **Avoid axioms when possible**: Constructive proofs are preferable

## Common Pitfalls

1. **Universe inconsistency**: Type : Type leads to paradox
2. **Confusing Prop and Bool**: Different purposes
3. **Forgetting proof irrelevance**: Prop proofs are all equal
4. **Not using dependent types**: Missing type-level guarantees
5. **Overusing classical axioms**: Lose constructive content

## Relationships

- **Foundation**: Calculus of Inductive Constructions
- **Related**: Homotopy type theory, cubical type theory
- **Applications**: Theorem proving, program verification

## References

- Theorem Proving in Lean 4
- Type Theory and Formal Proof (Nederpelt & Geuvers)
- Homotopy Type Theory book
- LEAN 4 documentation
