# Monoidal Categories

## Overview

Monoidal categories are categories equipped with a tensor product operation. They provide categorical semantics for resource-sensitive logics and concurrent computation.

## Definition

### Monoidal Category

A monoidal category (C, tensor, I, alpha, lambda, rho) consists of:
- Category C
- Bifunctor tensor: C x C -> C
- Unit object I
- Associator alpha: (A tensor B) tensor C -> A tensor (B tensor C)
- Left unitor lambda: I tensor A -> A
- Right unitor rho: A tensor I -> A

### Coherence Conditions

Pentagon identity for associators.
Triangle identity for unitors.

### Lean 4 Definition

```lean
class MonoidalCategory (C : Type) extends Category C where
  tensorObj : C -> C -> C
  tensorHom : Hom A B -> Hom C D -> Hom (tensorObj A C) (tensorObj B D)
  tensorUnit : C
  associator : forall A B C, Iso (tensorObj (tensorObj A B) C) (tensorObj A (tensorObj B C))
  leftUnitor : forall A, Iso (tensorObj tensorUnit A) A
  rightUnitor : forall A, Iso (tensorObj A tensorUnit) A
  pentagon : -- coherence
  triangle : -- coherence
```

## Variants

### Symmetric Monoidal

Has a natural isomorphism: A tensor B -> B tensor A (braiding/symmetry).

### Braided Monoidal

Has braiding without requiring symmetry.

### Cartesian Monoidal

Tensor is categorical product; unit is terminal object.

### Closed Monoidal

Has internal hom: [A, B] with adjunction A tensor - -| [A, -].

## Examples

### Set

- Tensor: Cartesian product
- Unit: Singleton set
- Symmetric, cartesian, closed

### Vect_k

- Tensor: Vector space tensor product
- Unit: k
- Symmetric, closed

### Rel

- Tensor: Cartesian product of sets
- Unit: Singleton
- Symmetric monoidal

### Endofunctors

- Tensor: Composition
- Unit: Identity functor

## Applications

### Linear Logic

- Multiplicative conjunction: tensor
- Linear implication: internal hom
- Resource semantics

### Quantum Computation

- Tensor: Parallel composition
- Quantum protocols

### Concurrency

- Tensor: Parallel processes
- Unit: Null process

## Key Theorems

### Coherence Theorem

Every diagram in a monoidal category built from associators and unitors commutes.

### Strict Monoidal Categories

Every monoidal category is equivalent to a strict one (where alpha, lambda, rho are identities).

## Monoid Objects

### Definition

A monoid in (C, tensor, I) is an object M with:
- Multiplication: mu: M tensor M -> M
- Unit: eta: I -> M

### Coherence

Associativity and unit laws hold.

### Examples

- Monoids in Set are ordinary monoids
- Monoids in Vect are algebras

## Mathlib Imports

```lean
import Mathlib.CategoryTheory.Monoidal.Basic
import Mathlib.CategoryTheory.Monoidal.Braided.Basic
import Mathlib.CategoryTheory.Monoidal.Closed.Basic
import Mathlib.CategoryTheory.Monoidal.Mon_
```

## References

- Mac Lane: Categories for the Working Mathematician
- Etingof et al.: Tensor Categories
- Heunen and Vicary: Categories for Quantum Theory
