# Rings and Fields

## Overview

Rings extend groups with a second operation. Fields add multiplicative inverses. These structures are fundamental to algebra and number theory.

## Rings

### Definition

A ring (R, +, *, 0, 1) consists of:
- Abelian group (R, +, 0)
- Monoid (R, *, 1)
- Distributivity laws

### Axioms

- (R, +, 0) is abelian group
- (R, *, 1) is monoid
- **Left distributivity**: a * (b + c) = a * b + a * c
- **Right distributivity**: (a + b) * c = a * c + b * c

### Lean 4 Definition

```lean
class Ring (R : Type) extends AddCommGroup R, Monoid R where
  left_distrib : forall a b c, a * (b + c) = a * b + a * c
  right_distrib : forall a b c, (a + b) * c = a * c + b * c
```

## Commutative Rings

### Definition

A ring where multiplication commutes:
- a * b = b * a

### Examples

- Integers Z
- Polynomials R[x]
- Residue rings Z/nZ

## Fields

### Definition

A commutative ring where every nonzero element has multiplicative inverse:
- For a != 0: exists b, a * b = 1

### Lean 4 Definition

```lean
class Field (F : Type) extends CommRing F, Inv F where
  mul_inv_cancel : forall a, a != 0 -> a * a^(-1) = 1
  inv_zero : (0 : F)^(-1) = 0  -- convention
```

### Examples

- Rationals Q
- Reals R
- Complex numbers C
- Finite fields F_p

## Ring Homomorphisms

### Definition

f: R -> S is a ring homomorphism if:
- f(a + b) = f(a) + f(b)
- f(a * b) = f(a) * f(b)
- f(1) = 1

### Ideals

An ideal I of R:
- I is additive subgroup
- r * a in I for all r in R, a in I

### Quotient Rings

R/I inherits ring structure when I is ideal.

## Key Theorems

### Ring Theorems

```lean
-- Zero annihilates
theorem zero_mul {a : R} : 0 * a = 0

-- Negation distributes
theorem neg_mul {a b : R} : (-a) * b = -(a * b)
```

### Field Theorems

```lean
-- No zero divisors
theorem mul_eq_zero {a b : F} : a * b = 0 <-> a = 0 or b = 0

-- Division
theorem div_mul_cancel {a b : F} : b != 0 -> a / b * b = a
```

## Integral Domains

### Definition

A commutative ring with no zero divisors:
- a * b = 0 implies a = 0 or b = 0

### Properties

- Every field is an integral domain
- Not every integral domain is a field

## Mathlib Imports

```lean
import Mathlib.Algebra.Ring.Basic
import Mathlib.Algebra.Field.Basic
import Mathlib.RingTheory.Ideal.Basic
```

## Common Patterns

### Proving Ring Properties

1. Verify abelian group structure
2. Verify monoid structure
3. Check distributivity

### Working with Fields

1. Handle zero case separately
2. Use multiplicative inverses
3. Apply division properties

## References

- Abstract Algebra (Dummit and Foote)
- Commutative Algebra (Atiyah and MacDonald)
- Mathlib documentation
