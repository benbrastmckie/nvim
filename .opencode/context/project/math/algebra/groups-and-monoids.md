# Groups and Monoids in LEAN 4

## Overview
Groups and monoids are fundamental algebraic structures in mathlib4. This file covers their definitions, key theorems, and common patterns for working with them in LEAN 4.

## Core Definitions

### Monoid
A monoid is a set with an associative binary operation and an identity element.

```lean
import Mathlib.Algebra.Group.Defs

class Monoid (M : Type*) extends Semigroup M, MulOneClass M where
  -- mul_assoc : ∀ a b c : M, (a * b) * c = a * (b * c)  -- from Semigroup
  -- one_mul : ∀ a : M, 1 * a = a                        -- from MulOneClass
  -- mul_one : ∀ a : M, a * 1 = a                        -- from MulOneClass
```

### Group
A group is a monoid where every element has an inverse.

```lean
class Group (G : Type*) extends Monoid G, Inv G where
  inv_mul_cancel : ∀ a : G, a⁻¹ * a = 1
```

### Abelian (Commutative) Group
```lean
class CommGroup (G : Type*) extends Group G, CommSemigroup G where
  -- mul_comm : ∀ a b : G, a * b = b * a  -- from CommSemigroup
```

## Key Theorems

### Monoid Theorems
```lean
-- Identity uniqueness
theorem one_unique {M : Type*} [Monoid M] {e : M} 
    (h : ∀ a : M, e * a = a ∧ a * e = a) : e = 1

-- Power laws
theorem pow_zero {M : Type*} [Monoid M] (a : M) : a ^ 0 = 1
theorem pow_succ {M : Type*} [Monoid M] (a : M) (n : ℕ) : 
    a ^ (n + 1) = a * a ^ n
theorem pow_add {M : Type*} [Monoid M] (a : M) (m n : ℕ) : 
    a ^ (m + n) = a ^ m * a ^ n
```

### Group Theorems
```lean
-- Inverse properties
theorem mul_inv_cancel {G : Type*} [Group G] (a : G) : a * a⁻¹ = 1
theorem inv_inv {G : Type*} [Group G] (a : G) : (a⁻¹)⁻¹ = a
theorem inv_mul {G : Type*} [Group G] (a b : G) : (a * b)⁻¹ = b⁻¹ * a⁻¹

-- Cancellation
theorem mul_left_cancel {G : Type*} [Group G] {a b c : G} 
    (h : a * b = a * c) : b = c
theorem mul_right_cancel {G : Type*} [Group G] {a b c : G} 
    (h : b * a = c * a) : b = c

-- Equation solving
theorem eq_mul_inv_of_mul_eq {G : Type*} [Group G] {a b c : G} 
    (h : a * b = c) : a = c * b⁻¹
theorem eq_inv_mul_of_mul_eq {G : Type*} [Group G] {a b c : G} 
    (h : a * b = c) : b = a⁻¹ * c
```

## Common Patterns

### Proving Group Properties
```lean
-- Pattern: Show something is a group
example : Group ℤ where
  mul := (· + ·)
  mul_assoc := Int.add_assoc
  one := 0
  one_mul := Int.zero_add
  mul_one := Int.add_zero
  inv := Int.neg
  inv_mul_cancel := Int.neg_add_cancel
```

### Working with Subgroups
```lean
import Mathlib.GroupTheory.Subgroup.Basic

-- Define a subgroup
def evenIntegers : Subgroup ℤ where
  carrier := {n : ℤ | Even n}
  mul_mem' := fun ha hb => Even.add ha hb
  one_mem' := Even.zero
  inv_mem' := fun ha => Even.neg ha

-- Subgroup membership
example (H : Subgroup G) (a b : G) (ha : a ∈ H) (hb : b ∈ H) : 
    a * b ∈ H := H.mul_mem ha hb
```

### Homomorphisms
```lean
import Mathlib.Algebra.Group.Hom.Defs

-- Group homomorphism
structure MonoidHom (M : Type*) (N : Type*) [Monoid M] [Monoid N] where
  toFun : M → N
  map_one' : toFun 1 = 1
  map_mul' : ∀ x y, toFun (x * y) = toFun x * toFun y

-- Example: absolute value as monoid homomorphism
def absHom : MonoidHom ℤ ℕ where
  toFun := Int.natAbs
  map_one' := rfl
  map_mul' := Int.natAbs_mul
```

## Mathlib Imports

### Basic Definitions
```lean
import Mathlib.Algebra.Group.Defs           -- Core group definitions
import Mathlib.Algebra.Group.Basic          -- Basic group theorems
import Mathlib.Algebra.Group.Commute        -- Commuting elements
import Mathlib.Algebra.Group.Units          -- Units in monoids
```

### Advanced Topics
```lean
import Mathlib.GroupTheory.Subgroup.Basic   -- Subgroups
import Mathlib.GroupTheory.QuotientGroup    -- Quotient groups
import Mathlib.GroupTheory.Coset            -- Cosets
import Mathlib.Algebra.Group.Hom.Defs       -- Homomorphisms
import Mathlib.GroupTheory.GroupAction.Defs -- Group actions
```

## Common Tactics

### For Monoid/Group Proofs
- `group` - Normalize group expressions
- `ring` - For commutative rings (includes abelian groups)
- `abel` - For abelian groups
- `simp [mul_assoc, mul_comm, mul_left_comm]` - Simplify with associativity/commutativity

### Examples
```lean
example {G : Type*} [Group G] (a b c : G) : 
    a * (b * c⁻¹) * c = a * b := by
  group

example {G : Type*} [CommGroup G] (a b c : G) : 
    a * b * c = c * a * b := by
  abel
```

## Standard Examples

### Integers under Addition
```lean
instance : Group ℤ where
  mul := (· + ·)
  mul_assoc := Int.add_assoc
  one := 0
  one_mul := Int.zero_add
  mul_one := Int.add_zero
  inv := Int.neg
  inv_mul_cancel := Int.neg_add_cancel
```

### Permutation Groups
```lean
import Mathlib.GroupTheory.Perm.Basic

-- Symmetric group on n elements
def Sym (n : ℕ) := Equiv.Perm (Fin n)

instance (n : ℕ) : Group (Sym n) := inferInstance
```

### Matrix Groups
```lean
import Mathlib.LinearAlgebra.Matrix.GeneralLinearGroup

-- General linear group GL(n, R)
def GL (n : ℕ) (R : Type*) [CommRing R] := 
  (Matrix (Fin n) (Fin n) R)ˣ

instance (n : ℕ) (R : Type*) [CommRing R] : Group (GL n R) := 
  inferInstance
```

## Business Rules

1. **Always use typeclasses**: Define group structures using `instance` for automatic inference
2. **Prefer bundled homomorphisms**: Use `MonoidHom`, `GroupHom` rather than raw functions
3. **Use `@[to_additive]`**: When defining multiplicative groups, use this attribute to auto-generate additive versions
4. **Subgroup membership**: Use `∈` notation for subgroup membership, not manual predicates

## Common Pitfalls

1. **Mixing multiplicative and additive notation**: Be consistent within a proof
2. **Forgetting to import**: Many group theorems require explicit imports
3. **Not using `group` tactic**: Manual group manipulations are tedious
4. **Confusing `Subgroup` and `Set`**: Subgroups have additional structure

## Relationships

- **Extends**: Semigroup, MulOneClass
- **Used by**: Ring theory, linear algebra, representation theory
- **Related**: Monoid actions, group cohomology, Sylow theorems

## References

- Mathlib docs: `Mathlib.Algebra.Group`
- Mathematics in Lean: Chapter 9 (Groups and Rings)
- Theorem Proving in Lean 4: Chapter on Type Classes
