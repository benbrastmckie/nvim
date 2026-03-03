# Partial Orders in LEAN 4

## Overview
Order theory provides the foundation for studying ordered structures. Mathlib4 has extensive support for partial orders, lattices, and order-preserving functions.

## Core Definitions

### Preorder
A preorder is a reflexive and transitive relation.

```lean
import Mathlib.Order.Basic

class Preorder (α : Type*) extends LE α, LT α where
  le_refl : ∀ a : α, a ≤ a
  le_trans : ∀ a b c : α, a ≤ b → b ≤ c → a ≤ c
  lt := fun a b => a ≤ b ∧ ¬b ≤ a
  lt_iff_le_not_le : ∀ a b : α, a < b ↔ a ≤ b ∧ ¬b ≤ a
```

### Partial Order
A partial order adds antisymmetry to a preorder.

```lean
class PartialOrder (α : Type*) extends Preorder α where
  le_antisymm : ∀ a b : α, a ≤ b → b ≤ a → a = b
```

### Linear Order (Total Order)
A linear order is a partial order where any two elements are comparable.

```lean
class LinearOrder (α : Type*) extends PartialOrder α, Min α, Max α where
  le_total : ∀ a b : α, a ≤ b ∨ b ≤ a
  decidableLE : DecidableRel (· ≤ · : α → α → Prop)
  decidableEq : DecidableEq α
  decidableLT : DecidableRel (· < · : α → α → Prop)
```

## Key Theorems

### Basic Order Properties
```lean
-- Reflexivity
theorem le_refl {α : Type*} [Preorder α] (a : α) : a ≤ a

-- Transitivity
theorem le_trans {α : Type*} [Preorder α] {a b c : α} 
    (hab : a ≤ b) (hbc : b ≤ c) : a ≤ c

-- Antisymmetry
theorem le_antisymm {α : Type*} [PartialOrder α] {a b : α} 
    (hab : a ≤ b) (hba : b ≤ a) : a = b

-- Totality
theorem le_total {α : Type*} [LinearOrder α] (a b : α) : 
    a ≤ b ∨ b ≤ a
```

### Strict Order
```lean
-- Strict order is irreflexive
theorem lt_irrefl {α : Type*} [Preorder α] (a : α) : ¬a < a

-- Strict order is transitive
theorem lt_trans {α : Type*} [Preorder α] {a b c : α} 
    (hab : a < b) (hbc : b < c) : a < c

-- Strict order is asymmetric
theorem lt_asymm {α : Type*} [PartialOrder α] {a b : α} 
    (hab : a < b) : ¬b < a

-- Relationship between ≤ and <
theorem lt_iff_le_not_le {α : Type*} [PartialOrder α] {a b : α} :
    a < b ↔ a ≤ b ∧ ¬b ≤ a

theorem le_of_lt {α : Type*} [Preorder α] {a b : α} (hab : a < b) : 
    a ≤ b
```

### Minimum and Maximum
```lean
-- Minimum
theorem min_le_left {α : Type*} [LinearOrder α] (a b : α) : 
    min a b ≤ a

theorem min_le_right {α : Type*} [LinearOrder α] (a b : α) : 
    min a b ≤ b

theorem le_min {α : Type*} [LinearOrder α] {a b c : α} :
    a ≤ min b c ↔ a ≤ b ∧ a ≤ c

-- Maximum
theorem le_max_left {α : Type*} [LinearOrder α] (a b : α) : 
    a ≤ max a b

theorem le_max_right {α : Type*} [LinearOrder α] (a b : α) : 
    b ≤ max a b

theorem max_le {α : Type*} [LinearOrder α] {a b c : α} :
    max a b ≤ c ↔ a ≤ c ∧ b ≤ c
```

## Bounded Orders

### Top and Bottom Elements
```lean
-- Order with top element
class OrderTop (α : Type*) [LE α] extends Top α where
  le_top : ∀ a : α, a ≤ ⊤

-- Order with bottom element
class OrderBot (α : Type*) [LE α] extends Bot α where
  bot_le : ∀ a : α, ⊥ ≤ a

-- Bounded order
class BoundedOrder (α : Type*) [LE α] extends OrderTop α, OrderBot α
```

### Theorems
```lean
-- Top element is greatest
theorem le_top {α : Type*} [LE α] [OrderTop α] (a : α) : a ≤ ⊤

-- Bottom element is least
theorem bot_le {α : Type*} [LE α] [OrderBot α] (a : α) : ⊥ ≤ a

-- Top and bottom are unique
theorem top_unique {α : Type*} [PartialOrder α] [OrderTop α] 
    {a : α} (h : ∀ b, b ≤ a) : a = ⊤

theorem bot_unique {α : Type*} [PartialOrder α] [OrderBot α] 
    {a : α} (h : ∀ b, a ≤ b) : a = ⊥
```

## Order-Preserving Functions

### Monotone Functions
```lean
-- Monotone (order-preserving)
def Monotone {α β : Type*} [Preorder α] [Preorder β] (f : α → β) : Prop :=
  ∀ a b, a ≤ b → f a ≤ f b

-- Strictly monotone
def StrictMono {α β : Type*} [Preorder α] [Preorder β] (f : α → β) : Prop :=
  ∀ a b, a < b → f a < f b

-- Antitone (order-reversing)
def Antitone {α β : Type*} [Preorder α] [Preorder β] (f : α → β) : Prop :=
  ∀ a b, a ≤ b → f b ≤ f a
```

### Theorems
```lean
-- Identity is monotone
theorem monotone_id {α : Type*} [Preorder α] : Monotone (id : α → α)

-- Composition of monotone functions
theorem Monotone.comp {α β γ : Type*} [Preorder α] [Preorder β] [Preorder γ]
    {g : β → γ} {f : α → β} (hg : Monotone g) (hf : Monotone f) :
    Monotone (g ∘ f)

-- Strictly monotone implies monotone
theorem StrictMono.monotone {α β : Type*} [Preorder α] [Preorder β]
    {f : α → β} (hf : StrictMono f) : Monotone f
```

## Common Patterns

### Defining Orders
```lean
-- Pattern: Define partial order on custom type
structure Point where
  x : ℝ
  y : ℝ

instance : PartialOrder Point where
  le p q := p.x ≤ q.x ∧ p.y ≤ q.y
  le_refl p := ⟨le_refl p.x, le_refl p.y⟩
  le_trans p q r hpq hqr := 
    ⟨le_trans hpq.1 hqr.1, le_trans hpq.2 hqr.2⟩
  le_antisymm p q hpq hqp := by
    cases p; cases q
    simp at hpq hqp
    exact ⟨le_antisymm hpq.1 hqp.1, le_antisymm hpq.2 hqp.2⟩
```

### Proving Monotonicity
```lean
-- Pattern: Prove function is monotone
example : Monotone (fun x : ℕ => 2 * x) := by
  intro a b hab
  exact Nat.mul_le_mul_left 2 hab

-- Using monotone lemmas
example {f g : ℕ → ℕ} (hf : Monotone f) (hg : Monotone g) :
    Monotone (fun x => f x + g x) := by
  intro a b hab
  exact add_le_add (hf hab) (hg hab)
```

## Well-Founded Orders

### Definition
```lean
-- Well-founded relation
def WellFounded {α : Type*} (r : α → α → Prop) : Prop :=
  ∀ a, Acc r a

-- Accessible elements
inductive Acc {α : Type*} (r : α → α → Prop) : α → Prop where
  | intro : ∀ x, (∀ y, r y x → Acc r y) → Acc r x
```

### Well-Founded Induction
```lean
-- Induction principle
theorem WellFounded.induction {α : Type*} {r : α → α → Prop} 
    (hwf : WellFounded r) {P : α → Prop}
    (h : ∀ x, (∀ y, r y x → P y) → P x) : ∀ a, P a
```

### Examples
```lean
-- Natural numbers are well-founded under <
theorem Nat.lt_wf : WellFounded (· < · : ℕ → ℕ → Prop)

-- Well-founded recursion
def factorial : ℕ → ℕ
  | 0 => 1
  | n + 1 => (n + 1) * factorial n
```

## Mathlib Imports

### Basic Order Theory
```lean
import Mathlib.Order.Basic              -- Core definitions
import Mathlib.Order.Monotone.Basic     -- Monotone functions
import Mathlib.Order.MinMax             -- Min and max
import Mathlib.Order.BoundedOrder       -- Bounded orders
```

### Advanced Topics
```lean
import Mathlib.Order.WellFounded        -- Well-founded orders
import Mathlib.Order.Chain              -- Chains and antichains
import Mathlib.Order.Zorn               -- Zorn's lemma
import Mathlib.Order.FixedPoints        -- Fixed point theorems
```

## Common Tactics

### For Order Proofs
- `exact le_refl a` - Prove reflexivity
- `exact le_trans hab hbc` - Prove transitivity
- `exact le_antisymm hab hba` - Prove antisymmetry
- `omega` - Solve linear arithmetic inequalities
- `linarith` - Linear arithmetic

### Examples
```lean
example {α : Type*} [PartialOrder α] (a b c : α) 
    (hab : a ≤ b) (hbc : b ≤ c) (hca : c ≤ a) : a = b ∧ b = c := by
  constructor
  · exact le_antisymm hab (le_trans hbc hca)
  · exact le_antisymm hbc (le_trans hca hab)

example (a b : ℕ) (h : a ≤ b) : a + 1 ≤ b + 1 := by
  omega
```

## Standard Examples

### Natural Numbers
```lean
instance : LinearOrder ℕ := inferInstance
instance : OrderBot ℕ where
  bot := 0
  bot_le := Nat.zero_le
```

### Integers
```lean
instance : LinearOrder ℤ := inferInstance
```

### Real Numbers
```lean
instance : LinearOrder ℝ := inferInstance
```

### Subsets (Inclusion Order)
```lean
instance {α : Type*} : PartialOrder (Set α) where
  le := (· ⊆ ·)
  le_refl := Set.Subset.refl
  le_trans := Set.Subset.trans
  le_antisymm := Set.Subset.antisymm
```

## Business Rules

1. **Use appropriate order type**: Preorder vs PartialOrder vs LinearOrder
2. **Prefer monotone lemmas**: Don't manually prove monotonicity
3. **Use well-founded recursion**: For recursive definitions on ordered types
4. **Check decidability**: LinearOrder requires decidable relations
5. **Import order theory**: Don't redefine order concepts

## Common Pitfalls

1. **Confusing ≤ and <**: Remember strict vs non-strict
2. **Forgetting antisymmetry**: PartialOrder needs it, Preorder doesn't
3. **Not using `omega`**: Manual arithmetic proofs are tedious
4. **Missing decidability**: LinearOrder needs decidable instances
5. **Ignoring well-foundedness**: Needed for termination proofs

## Relationships

- **Used by**: Lattice theory, topology, analysis
- **Related**: Lattices, complete lattices, Galois connections
- **Extends**: Relations, set theory

## References

- Mathlib docs: `Mathlib.Order`
- Order theory textbooks (Davey & Priestley)
- Lattice theory references
