# Rings and Fields in LEAN 4

## Overview
Rings and fields are fundamental algebraic structures that combine additive and multiplicative operations. This file covers their definitions, key theorems, and usage patterns in mathlib4.

## Core Definitions

### Semiring
A semiring has addition and multiplication with distributivity, but no additive inverses.

```lean
import Mathlib.Algebra.Ring.Defs

class Semiring (R : Type*) extends AddCommMonoid R, Monoid R, Distrib R where
  -- Addition is commutative monoid
  -- Multiplication is monoid
  -- left_distrib : ∀ a b c : R, a * (b + c) = a * b + a * c
  -- right_distrib : ∀ a b c : R, (a + b) * c = a * c + b * c
  zero_mul : ∀ a : R, 0 * a = 0
  mul_zero : ∀ a : R, a * 0 = 0
```

### Ring
A ring adds additive inverses to a semiring.

```lean
class Ring (R : Type*) extends AddCommGroup R, Monoid R, Distrib R where
  -- All semiring axioms plus additive inverses
```

### Commutative Ring
```lean
class CommRing (R : Type*) extends Ring R, CommSemigroup R where
  -- mul_comm : ∀ a b : R, a * b = b * a
```

### Field
A field is a commutative ring where every nonzero element has a multiplicative inverse.

```lean
class Field (F : Type*) extends CommRing F, DivisionRing F where
  -- Every nonzero element has multiplicative inverse
  inv_zero : (0 : F)⁻¹ = 0
```

## Key Theorems

### Ring Theorems
```lean
-- Multiplication by zero
theorem zero_mul {R : Type*} [Ring R] (a : R) : 0 * a = 0
theorem mul_zero {R : Type*} [Ring R] (a : R) : a * 0 = 0

-- Negation and multiplication
theorem neg_mul {R : Type*} [Ring R] (a b : R) : (-a) * b = -(a * b)
theorem mul_neg {R : Type*} [Ring R] (a b : R) : a * (-b) = -(a * b)
theorem neg_mul_neg {R : Type*} [Ring R] (a b : R) : (-a) * (-b) = a * b

-- Subtraction
theorem sub_eq_add_neg {R : Type*} [Ring R] (a b : R) : a - b = a + (-b)
theorem sub_self {R : Type*} [Ring R] (a : R) : a - a = 0

-- Distributivity
theorem mul_add {R : Type*} [Ring R] (a b c : R) : 
    a * (b + c) = a * b + a * c
theorem add_mul {R : Type*} [Ring R] (a b c : R) : 
    (a + b) * c = a * c + b * c
```

### Field Theorems
```lean
-- Division
theorem div_self {F : Type*} [Field F] {a : F} (ha : a ≠ 0) : a / a = 1
theorem mul_div_cancel {F : Type*} [Field F] {a b : F} (hb : b ≠ 0) : 
    a * b / b = a
theorem div_mul_cancel {F : Type*} [Field F] {a b : F} (hb : b ≠ 0) : 
    a / b * b = a

-- Field properties
theorem mul_eq_zero {F : Type*} [Field F] {a b : F} : 
    a * b = 0 ↔ a = 0 ∨ b = 0
theorem div_eq_iff {F : Type*} [Field F] {a b c : F} (hc : c ≠ 0) : 
    a / c = b ↔ a = b * c
```

## Common Patterns

### Proving Ring Properties
```lean
-- Pattern: Show something is a ring
instance : Ring ℤ where
  add := (· + ·)
  add_assoc := Int.add_assoc
  zero := 0
  zero_add := Int.zero_add
  add_zero := Int.add_zero
  neg := Int.neg
  add_left_neg := Int.add_left_neg
  add_comm := Int.add_comm
  mul := (· * ·)
  mul_assoc := Int.mul_assoc
  one := 1
  one_mul := Int.one_mul
  mul_one := Int.mul_one
  left_distrib := Int.mul_add
  right_distrib := Int.add_mul
```

### Working with Ideals
```lean
import Mathlib.RingTheory.Ideal.Basic

-- Define an ideal
def evenIntegers : Ideal ℤ where
  carrier := {n : ℤ | Even n}
  add_mem' := fun ha hb => Even.add ha hb
  zero_mem' := Even.zero
  smul_mem' := fun c n hn => Even.mul_of_right hn

-- Ideal operations
example (I J : Ideal R) : Ideal R := I + J  -- Sum of ideals
example (I J : Ideal R) : Ideal R := I * J  -- Product of ideals
example (I J : Ideal R) : Ideal R := I ⊓ J  -- Intersection
```

### Ring Homomorphisms
```lean
import Mathlib.Algebra.Ring.Hom.Defs

structure RingHom (R : Type*) (S : Type*) [Ring R] [Ring S] where
  toFun : R → S
  map_one' : toFun 1 = 1
  map_mul' : ∀ x y, toFun (x * y) = toFun x * toFun y
  map_zero' : toFun 0 = 0
  map_add' : ∀ x y, toFun (x + y) = toFun x + toFun y

-- Example: complex conjugation
def conjHom : RingHom ℂ ℂ where
  toFun := Complex.conj
  map_one' := Complex.conj_one
  map_mul' := Complex.conj_mul
  map_zero' := Complex.conj_zero
  map_add' := Complex.conj_add
```

### Polynomial Rings
```lean
import Mathlib.Data.Polynomial.Basic

-- Polynomial ring R[X]
def PolyRing (R : Type*) [CommRing R] := Polynomial R

-- Polynomial evaluation
example {R : Type*} [CommRing R] (p : Polynomial R) (x : R) : R :=
  p.eval x

-- Polynomial operations
example {R : Type*} [CommRing R] (p q : Polynomial R) : Polynomial R :=
  p + q  -- Addition

example {R : Type*} [CommRing R] (p q : Polynomial R) : Polynomial R :=
  p * q  -- Multiplication
```

## Mathlib Imports

### Basic Definitions
```lean
import Mathlib.Algebra.Ring.Defs            -- Core ring definitions
import Mathlib.Algebra.Ring.Basic           -- Basic ring theorems
import Mathlib.Algebra.Field.Defs           -- Field definitions
import Mathlib.Algebra.Field.Basic          -- Basic field theorems
```

### Advanced Topics
```lean
import Mathlib.RingTheory.Ideal.Basic       -- Ideals
import Mathlib.RingTheory.Ideal.Operations  -- Ideal operations
import Mathlib.RingTheory.Ideal.Quotient    -- Quotient rings
import Mathlib.Data.Polynomial.Basic        -- Polynomials
import Mathlib.RingTheory.Polynomial.Basic  -- Polynomial theory
import Mathlib.FieldTheory.Finite.Basic     -- Finite fields
```

## Common Tactics

### For Ring Proofs
- `ring` - Normalize ring expressions and prove ring identities
- `ring_nf` - Normalize ring expressions without closing goal
- `field_simp` - Simplify field expressions (clear denominators)
- `linear_combination` - Prove linear combinations

### Examples
```lean
example {R : Type*} [CommRing R] (a b c : R) : 
    (a + b) * (a - b) = a^2 - b^2 := by
  ring

example {F : Type*} [Field F] (a b c : F) (hb : b ≠ 0) (hc : c ≠ 0) : 
    a / b + a / c = a * (b + c) / (b * c) := by
  field_simp
  ring
```

## Standard Examples

### Integers
```lean
instance : CommRing ℤ := inferInstance
```

### Rationals
```lean
instance : Field ℚ := inferInstance
```

### Real Numbers
```lean
instance : Field ℝ := inferInstance
```

### Complex Numbers
```lean
import Mathlib.Data.Complex.Basic

instance : Field ℂ := inferInstance
```

### Polynomial Rings
```lean
instance {R : Type*} [CommRing R] : CommRing (Polynomial R) := 
  inferInstance
```

### Matrix Rings
```lean
import Mathlib.Data.Matrix.Basic

instance {n : ℕ} {R : Type*} [CommRing R] : 
    Ring (Matrix (Fin n) (Fin n) R) := inferInstance
```

### Quotient Rings
```lean
import Mathlib.RingTheory.Ideal.Quotient

-- R / I for ideal I
instance {R : Type*} [CommRing R] (I : Ideal R) : 
    CommRing (R ⧸ I) := inferInstance
```

## Business Rules

1. **Use `ring` tactic**: Don't manually prove ring identities
2. **Prefer bundled homomorphisms**: Use `RingHom` not raw functions
3. **Handle division carefully**: Always prove denominators are nonzero in fields
4. **Use `CommRing` when possible**: Commutativity enables more tactics
5. **Import polynomial theory**: Don't redefine polynomial operations

## Common Pitfalls

1. **Forgetting commutativity**: `Ring` vs `CommRing` matters for tactics
2. **Division by zero**: Always handle the `≠ 0` condition
3. **Not using `ring` tactic**: Manual proofs are unnecessarily complex
4. **Confusing `Ideal` and `Subring`**: Different algebraic structures
5. **Missing imports**: Many ring theorems require explicit imports

## Advanced Topics

### Integral Domains
```lean
class IsDomain (R : Type*) [Ring R] : Prop where
  eq_zero_or_eq_zero_of_mul_eq_zero : 
    ∀ {a b : R}, a * b = 0 → a = 0 ∨ b = 0
```

### Principal Ideal Domains (PIDs)
```lean
class IsPrincipalIdealRing (R : Type*) [CommRing R] : Prop where
  principal : ∀ (I : Ideal R), ∃ a : R, I = Ideal.span {a}
```

### Unique Factorization Domains (UFDs)
```lean
import Mathlib.RingTheory.UniqueFactorizationDomain
```

### Field Extensions
```lean
import Mathlib.FieldTheory.Tower
import Mathlib.FieldTheory.Separable
import Mathlib.FieldTheory.Galois
```

## Relationships

- **Extends**: Group (additive), Monoid (multiplicative)
- **Used by**: Module theory, linear algebra, algebraic geometry
- **Related**: Ideals, quotient rings, polynomial rings, field extensions

## References

- Mathlib docs: `Mathlib.Algebra.Ring`, `Mathlib.Algebra.Field`
- Mathematics in Lean: Chapter 9 (Groups and Rings)
- Abstract Algebra textbooks (Dummit & Foote, Lang)
