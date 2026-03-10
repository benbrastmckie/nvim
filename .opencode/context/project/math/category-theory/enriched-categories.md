# Enriched Categories

## Overview

Enriched categories generalize ordinary categories by replacing hom-sets with objects from a monoidal category. This enables metric spaces, order-enriched categories, and linear categories.

## Definition

### V-Enriched Category

Given a monoidal category (V, tensor, I), a V-enriched category C consists of:
- **Objects**: Collection Ob(C)
- **Hom objects**: For each pair A, B, an object C(A,B) in V
- **Composition**: C(B,C) tensor C(A,B) -> C(A,C)
- **Identity**: I -> C(A,A)

### Axioms

Associativity and unit laws in V.

### Lean 4 Approach

```lean
structure EnrichedCategory (V : Type) [MonoidalCategory V] where
  Obj : Type
  Hom : Obj -> Obj -> V
  comp : forall A B C, Hom B C tensor Hom A B -> Hom A C
  id : forall A, I -> Hom A A
  assoc : -- diagram commutes
  left_unit : -- diagram commutes
  right_unit : -- diagram commutes
```

## Examples

### Sets (2-Enriched)

- V = 2 (two-element set with and/or)
- Recovers preorders

### Ab (Abelian Groups)

- Hom objects are abelian groups
- Recovers preadditive categories

### Cat (Categories)

- 2-categories: categories enriched in Cat

### Met (Extended Metric Spaces)

- V = ([0, infinity], >=, +, 0)
- Lawvere metric spaces

## V-Functors

### Definition

A V-functor F: C -> D consists of:
- Object map: F(A) for each object A
- Hom map: C(A,B) -> D(F(A),F(B)) in V

### Axioms

Preserves composition and identity.

## V-Natural Transformations

### Definition

A V-natural transformation alpha: F => G consists of:
- Components: I -> D(F(A), G(A)) for each A

### Naturality

Expressed as commuting diagram in V.

## Weighted Limits

### Definition

Generalization of limits for enriched categories:
- Weight: Functor W: J^op -> V
- Limit: Universal weighted cone

### Examples

- Ordinary limits: Weight is constant functor
- Products: Discrete diagram
- Equalizers: Parallel pair

## Applications

### Metric Spaces as Categories

Lawvere's observation:
- Objects: Points
- C(x,y) = d(x,y)
- Composition: d(y,z) + d(x,y) >= d(x,z)
- Identity: 0 = d(x,x)

### Linear Logic

Categories enriched in vector spaces or sup-lattices.

### 2-Categories

Categories enriched in Cat:
- Objects: 0-cells
- Hom-categories: 1-cells and 2-cells

## Key Theorems

### Enriched Yoneda Lemma

V-natural transformations from C(A,-) correspond to elements of F(A).

### Enriched Adjunctions

Adjunctions in the enriched setting:
- Unit and counit as V-natural transformations

## References

- Kelly: Basic Concepts of Enriched Category Theory
- Borceux: Handbook of Categorical Algebra
- Lawvere: Metric Spaces, Generalized Logic, and Closed Categories
