# Lattices

## Overview

Lattices are ordered structures where any two elements have a least upper bound (join) and greatest lower bound (meet). Mathlib4 provides comprehensive lattice theory support.

## Core Definitions

### Semilattice Sup (Join-Semilattice)

```lean
class SemilatticeSup (A : Type) extends PartialOrder A, Sup A where
  le_sup_left : forall a b, a <= a sup b
  le_sup_right : forall a b, b <= a sup b
  sup_le : forall a b c, a <= c -> b <= c -> a sup b <= c
```

### Semilattice Inf (Meet-Semilattice)

```lean
class SemilatticeInf (A : Type) extends PartialOrder A, Inf A where
  inf_le_left : forall a b, a inf b <= a
  inf_le_right : forall a b, a inf b <= b
  le_inf : forall a b c, a <= b -> a <= c -> a <= b inf c
```

### Lattice

A lattice has both joins and meets:

```lean
class Lattice (A : Type) extends SemilatticeSup A, SemilatticeInf A
```

### Distributive Lattice

```lean
class DistribLattice (A : Type) extends Lattice A where
  le_sup_inf : forall a b c, (a sup b) inf (a sup c) <= a sup (b inf c)
```

## Key Theorems

### Lattice Properties

```lean
-- Idempotence
theorem sup_idem {a : A} : a sup a = a
theorem inf_idem {a : A} : a inf a = a

-- Commutativity
theorem sup_comm {a b : A} : a sup b = b sup a
theorem inf_comm {a b : A} : a inf b = b inf a

-- Associativity
theorem sup_assoc {a b c : A} : a sup (b sup c) = (a sup b) sup c
theorem inf_assoc {a b c : A} : a inf (b inf c) = (a inf b) inf c

-- Absorption
theorem sup_inf_self {a b : A} : a sup (a inf b) = a
theorem inf_sup_self {a b : A} : a inf (a sup b) = a
```

### Distributive Properties

```lean
theorem inf_sup_left {a b c : A} : a inf (b sup c) = (a inf b) sup (a inf c)
theorem sup_inf_left {a b c : A} : a sup (b inf c) = (a sup b) inf (a sup c)
```

## Complete Lattices

### Definition

```lean
class CompleteLattice (A : Type) extends Lattice A, SupSet A, InfSet A where
  le_sSup : forall s a, a in s -> a <= sSup s
  sSup_le : forall s a, (forall b in s, b <= a) -> sSup s <= a
  sInf_le : forall s a, a in s -> sInf s <= a
  le_sInf : forall s a, (forall b in s, a <= b) -> a <= sInf s
```

### Fixed Point Theorem

```lean
-- Knaster-Tarski
theorem knasterTarski {f : A -> A} (hf : Monotone f) :
    exists x, f x = x and forall y, f y = y -> x <= y
```

## Boolean Algebra

```lean
class BooleanAlgebra (A : Type) extends DistribLattice A, HasCompl A where
  inf_compl_eq_bot : forall a, a inf compl a = bot
  sup_compl_eq_top : forall a, a sup compl a = top
```

### De Morgan's Laws

```lean
theorem compl_sup {a b : A} : compl (a sup b) = compl a inf compl b
theorem compl_inf {a b : A} : compl (a inf b) = compl a sup compl b
```

## Standard Examples

### Sets

```lean
instance {A : Type} : CompleteLattice (Set A) where
  sup := union
  inf := inter
  sSup := sUnion
  sInf := sInter
```

### Propositions

```lean
instance : CompleteLattice Prop where
  sup := Or
  inf := And
  sSup := fun s => exists p in s, p
  sInf := fun s => forall p in s, p
```

## Mathlib Imports

```lean
import Mathlib.Order.Lattice
import Mathlib.Order.BooleanAlgebra
import Mathlib.Order.CompleteLattice
import Mathlib.Order.FixedPoints
```

## Applications

- Logic: Propositional algebras
- Topology: Open/closed sets
- Domain theory: Scott domains
- Order theory: Closure operators

## References

- Davey and Priestley: Introduction to Lattices and Order
- Mathlib documentation
- Gratzer: Lattice Theory
