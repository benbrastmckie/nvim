# Lattices in LEAN 4

## Overview
Lattices are ordered structures where any two elements have a least upper bound (join) and greatest lower bound (meet). Mathlib4 provides comprehensive lattice theory support.

## Core Definitions

### Semilattice Sup (Join-Semilattice)
```lean
import Mathlib.Order.Lattice

class SemilatticeSup (α : Type*) extends PartialOrder α, Sup α where
  le_sup_left : ∀ a b : α, a ≤ a ⊔ b
  le_sup_right : ∀ a b : α, b ≤ a ⊔ b
  sup_le : ∀ a b c : α, a ≤ c → b ≤ c → a ⊔ b ≤ c
```

### Semilattice Inf (Meet-Semilattice)
```lean
class SemilatticeInf (α : Type*) extends PartialOrder α, Inf α where
  inf_le_left : ∀ a b : α, a ⊓ b ≤ a
  inf_le_right : ∀ a b : α, a ⊓ b ≤ b
  le_inf : ∀ a b c : α, a ≤ b → a ≤ c → a ≤ b ⊓ c
```

### Lattice
A lattice has both joins and meets.

```lean
class Lattice (α : Type*) extends SemilatticeSup α, SemilatticeInf α
```

### Distributive Lattice
```lean
class DistribLattice (α : Type*) extends Lattice α where
  le_sup_inf : ∀ a b c : α, (a ⊔ b) ⊓ (a ⊔ c) ≤ a ⊔ (b ⊓ c)
```

### Complemented Lattice
```lean
class ComplementedLattice (α : Type*) extends Lattice α, BoundedOrder α where
  exists_compl : ∀ a : α, ∃ b : α, a ⊔ b = ⊤ ∧ a ⊓ b = ⊥
```

### Boolean Algebra
```lean
class BooleanAlgebra (α : Type*) extends DistribLattice α, ComplementedLattice α where
  compl : α → α
  inf_compl_le_bot : ∀ a : α, a ⊓ compl a ≤ ⊥
  top_le_sup_compl : ∀ a : α, ⊤ ≤ a ⊔ compl a
```

## Key Theorems

### Lattice Properties
```lean
-- Idempotence
theorem sup_idem {α : Type*} [Lattice α] (a : α) : a ⊔ a = a
theorem inf_idem {α : Type*} [Lattice α] (a : α) : a ⊓ a = a

-- Commutativity
theorem sup_comm {α : Type*} [Lattice α] (a b : α) : a ⊔ b = b ⊔ a
theorem inf_comm {α : Type*} [Lattice α] (a b : α) : a ⊓ b = b ⊓ a

-- Associativity
theorem sup_assoc {α : Type*} [Lattice α] (a b c : α) : 
    a ⊔ (b ⊔ c) = (a ⊔ b) ⊔ c
theorem inf_assoc {α : Type*} [Lattice α] (a b c : α) : 
    a ⊓ (b ⊓ c) = (a ⊓ b) ⊓ c

-- Absorption
theorem sup_inf_self {α : Type*} [Lattice α] (a b : α) : 
    a ⊔ (a ⊓ b) = a
theorem inf_sup_self {α : Type*} [Lattice α] (a b : α) : 
    a ⊓ (a ⊔ b) = a
```

### Distributive Lattice Properties
```lean
-- Distributivity
theorem inf_sup_left {α : Type*} [DistribLattice α] (a b c : α) :
    a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)

theorem inf_sup_right {α : Type*} [DistribLattice α] (a b c : α) :
    (a ⊔ b) ⊓ c = (a ⊓ c) ⊔ (b ⊓ c)

theorem sup_inf_left {α : Type*} [DistribLattice α] (a b c : α) :
    a ⊔ (b ⊓ c) = (a ⊔ b) ⊓ (a ⊔ c)

theorem sup_inf_right {α : Type*} [DistribLattice α] (a b c : α) :
    (a ⊓ b) ⊔ c = (a ⊔ c) ⊓ (b ⊔ c)
```

### Boolean Algebra Properties
```lean
-- Complement laws
theorem inf_compl_eq_bot {α : Type*} [BooleanAlgebra α] (a : α) :
    a ⊓ aᶜ = ⊥

theorem sup_compl_eq_top {α : Type*} [BooleanAlgebra α] (a : α) :
    a ⊔ aᶜ = ⊤

-- De Morgan's laws
theorem compl_sup {α : Type*} [BooleanAlgebra α] (a b : α) :
    (a ⊔ b)ᶜ = aᶜ ⊓ bᶜ

theorem compl_inf {α : Type*} [BooleanAlgebra α] (a b : α) :
    (a ⊓ b)ᶜ = aᶜ ⊔ bᶜ

-- Double complement
theorem compl_compl {α : Type*} [BooleanAlgebra α] (a : α) :
    aᶜᶜ = a
```

## Complete Lattices

### Definition
```lean
class CompleteLattice (α : Type*) extends Lattice α, SupSet α, InfSet α where
  le_sSup : ∀ s a, a ∈ s → a ≤ sSup s
  sSup_le : ∀ s a, (∀ b ∈ s, b ≤ a) → sSup s ≤ a
  sInf_le : ∀ s a, a ∈ s → sInf s ≤ a
  le_sInf : ∀ s a, (∀ b ∈ s, a ≤ b) → a ≤ sInf s
```

### Theorems
```lean
-- Supremum properties
theorem le_sSup {α : Type*} [CompleteLattice α] {s : Set α} {a : α} 
    (ha : a ∈ s) : a ≤ sSup s

theorem sSup_le {α : Type*} [CompleteLattice α] {s : Set α} {a : α} 
    (h : ∀ b ∈ s, b ≤ a) : sSup s ≤ a

-- Infimum properties
theorem sInf_le {α : Type*} [CompleteLattice α] {s : Set α} {a : α} 
    (ha : a ∈ s) : sInf s ≤ a

theorem le_sInf {α : Type*} [CompleteLattice α] {s : Set α} {a : α} 
    (h : ∀ b ∈ s, a ≤ b) : a ≤ sInf s
```

## Common Patterns

### Defining Lattices
```lean
-- Pattern: Define lattice structure
instance : Lattice (Set α) where
  sup := (· ∪ ·)
  le_sup_left := Set.subset_union_left
  le_sup_right := Set.subset_union_right
  sup_le := fun _ _ _ => Set.union_subset
  inf := (· ∩ ·)
  inf_le_left := Set.inter_subset_left
  inf_le_right := Set.inter_subset_right
  le_inf := fun _ _ _ => Set.subset_inter
```

### Proving Lattice Properties
```lean
-- Pattern: Use lattice laws
example {α : Type*} [Lattice α] (a b c : α) 
    (h : a ≤ b) : a ⊓ c ≤ b ⊓ c := by
  apply le_inf
  · exact le_trans inf_le_left h
  · exact inf_le_right

-- Using absorption
example {α : Type*} [Lattice α] (a b : α) : 
    (a ⊔ b) ⊓ a = a := by
  rw [inf_comm, inf_sup_self]
```

### Working with Complete Lattices
```lean
-- Pattern: Use supremum/infimum
example {α : Type*} [CompleteLattice α] (s : Set α) (a : α) 
    (h : ∀ b ∈ s, b ≤ a) : sSup s ≤ a :=
  sSup_le h

-- Knaster-Tarski fixed point theorem
theorem knasterTarski {α : Type*} [CompleteLattice α] 
    (f : α → α) (hf : Monotone f) :
    ∃ x, f x = x ∧ ∀ y, f y = y → x ≤ y
```

## Mathlib Imports

### Basic Lattices
```lean
import Mathlib.Order.Lattice                -- Core lattice definitions
import Mathlib.Order.BooleanAlgebra         -- Boolean algebras
import Mathlib.Order.CompleteLattice        -- Complete lattices
import Mathlib.Order.FixedPoints            -- Fixed point theorems
```

### Advanced Topics
```lean
import Mathlib.Order.GaloisConnection       -- Galois connections
import Mathlib.Order.ModularLattice         -- Modular lattices
import Mathlib.Order.Heyting.Basic          -- Heyting algebras
```

## Common Tactics

### For Lattice Proofs
- `simp [sup_comm, inf_comm]` - Simplify with commutativity
- `rw [sup_inf_self]` - Apply absorption
- `apply le_sup_left` - Show element ≤ join
- `apply inf_le_left` - Show meet ≤ element

### Examples
```lean
example {α : Type*} [Lattice α] (a b c : α) :
    a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c) := by
  sorry  -- Requires distributivity

example {α : Type*} [BooleanAlgebra α] (a : α) :
    a ⊓ aᶜ = ⊥ := by
  exact inf_compl_eq_bot a
```

## Standard Examples

### Sets
```lean
instance {α : Type*} : CompleteLattice (Set α) where
  sup := (· ∪ ·)
  inf := (· ∩ ·)
  sSup := ⋃₀
  sInf := ⋂₀
  -- ... (axioms)
```

### Propositions
```lean
instance : CompleteLattice Prop where
  sup := Or
  inf := And
  sSup := fun s => ∃ p ∈ s, p
  sInf := fun s => ∀ p ∈ s, p
  -- ... (axioms)
```

### Booleans
```lean
instance : BooleanAlgebra Bool where
  sup := or
  inf := and
  compl := not
  -- ... (axioms)
```

## Business Rules

1. **Use lattice operations**: Prefer ⊔ and ⊓ over custom operations
2. **Check distributivity**: Not all lattices are distributive
3. **Use complete lattices**: When working with arbitrary joins/meets
4. **Apply fixed point theorems**: For recursive definitions
5. **Import lattice theory**: Don't redefine lattice concepts

## Common Pitfalls

1. **Assuming distributivity**: Not all lattices distribute
2. **Confusing ⊔/⊓ with ∪/∩**: Different operations (though related for sets)
3. **Forgetting completeness**: sSup/sInf need CompleteLattice
4. **Not using absorption**: Manual proofs miss simplifications
5. **Ignoring Boolean algebra**: Many results need complement structure

## Applications

### Order Theory
- Galois connections
- Fixed point theorems
- Closure operators

### Logic
- Propositional logic (Boolean algebras)
- Intuitionistic logic (Heyting algebras)
- Modal logic (modal algebras)

### Topology
- Open sets form complete lattice
- Closed sets form complete lattice

### Computer Science
- Domain theory
- Dataflow analysis
- Type systems

## Relationships

- **Extends**: Partial orders
- **Used by**: Topology, logic, domain theory
- **Related**: Boolean algebras, Heyting algebras, complete lattices

## References

- Mathlib docs: `Mathlib.Order.Lattice`
- Lattice theory textbooks (Grätzer, Davey & Priestley)
- Boolean algebra references
