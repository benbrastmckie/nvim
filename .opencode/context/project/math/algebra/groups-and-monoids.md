# Groups and Monoids

## Overview

Foundational algebraic structures for formal mathematics. Monoids and groups appear throughout logic, category theory, and formalization.

## Monoids

### Definition

A monoid (M, *, e) consists of:
- Set M
- Binary operation *: M x M -> M
- Identity element e in M

### Axioms

- **Associativity**: (a * b) * c = a * (b * c)
- **Left identity**: e * a = a
- **Right identity**: a * e = a

### Lean 4 Definition

```lean
class Monoid (M : Type) extends Mul M, One M where
  mul_assoc : forall a b c, (a * b) * c = a * (b * c)
  one_mul : forall a, 1 * a = a
  mul_one : forall a, a * 1 = a
```

## Groups

### Definition

A group (G, *, e, inv) extends a monoid with:
- Inverse operation inv: G -> G

### Axioms

- All monoid axioms
- **Left inverse**: inv(a) * a = e
- **Right inverse**: a * inv(a) = e

### Lean 4 Definition

```lean
class Group (G : Type) extends Monoid G, Inv G where
  inv_mul : forall a, a^(-1) * a = 1
  mul_inv : forall a, a * a^(-1) = 1
```

## Commutative Variants

### Commutative Monoid

Adds: a * b = b * a

### Abelian Group

Adds commutativity to group axioms.

## Key Theorems

### Monoid Theorems

```lean
-- Identity is unique
theorem one_unique {a : M} : (forall x, a * x = x) -> a = 1

-- Cancellation (in groups)
theorem mul_left_cancel {a b c : G} : a * b = a * c -> b = c
```

### Group Theorems

```lean
-- Inverse is unique
theorem inv_unique {a b : G} : a * b = 1 -> b = a^(-1)

-- Inverse of product
theorem inv_mul_rev {a b : G} : (a * b)^(-1) = b^(-1) * a^(-1)

-- Double inverse
theorem inv_inv {a : G} : (a^(-1))^(-1) = a
```

## Group Actions

### Definition

A group action of G on X:
- act: G -> X -> X
- act(e, x) = x
- act(g, act(h, x)) = act(g * h, x)

### Applications

- Symmetry groups
- Permutation groups
- Automorphism groups

## Monoid Homomorphisms

### Definition

f: M -> N is a monoid homomorphism if:
- f(a * b) = f(a) * f(b)
- f(1) = 1

### Kernel and Image

- Kernel: ker(f) = {a | f(a) = 1}
- Image: im(f) = {f(a) | a in M}

## Mathlib Imports

```lean
import Mathlib.Algebra.Group.Basic
import Mathlib.Algebra.Group.Hom.Basic
import Mathlib.GroupTheory.GroupAction.Basic
```

## Common Patterns

### Proving Group Properties

1. Check associativity
2. Verify identity
3. Construct inverses

### Using Group Actions

1. Define action function
2. Verify action axioms
3. Apply group theory results

## References

- Abstract Algebra (Dummit and Foote)
- Mathlib documentation
- Algebra (Lang)
